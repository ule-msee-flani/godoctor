-- Push notifications (Firebase Cloud Messaging) and the full set of
-- notifications each role needs.
--
-- Flow: anything that matters inserts a row into public.notifications (the
-- in-app inbox). A trigger hands that row to the `push` Edge Function via
-- pg_net; the function looks up the person's devices and sends it through
-- FCM, respecting the categories they muted. The shared secret lives in
-- Vault (database side) and in Edge Function secrets (function side).

create extension if not exists pg_net with schema extensions;

------------------------------------------------------------------
-- 1. Devices that can receive pushes (one person, many devices)
------------------------------------------------------------------
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index if not exists device_tokens_user_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;
create policy device_tokens_owner_read on public.device_tokens
  for select to authenticated using (user_id = auth.uid());
create policy device_tokens_owner_delete on public.device_tokens
  for delete to authenticated using (user_id = auth.uid());

-- Register this device for the signed-in user. If the same phone was used
-- by someone else before (shared phone, switched accounts), it moves over.
create or replace function public.register_device(p_token text, p_platform text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if length(coalesce(p_token, '')) < 20 then raise exception 'invalid token'; end if;
  insert into public.device_tokens (user_id, token, platform)
  values (auth.uid(), p_token, p_platform)
  on conflict (token) do update
    set user_id = auth.uid(), platform = excluded.platform, last_seen_at = now();
end $$;

create or replace function public.unregister_device(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from public.device_tokens where token = p_token and user_id = auth.uid();
$$;

------------------------------------------------------------------
-- 2. Per-person push preferences: categories they turned off.
--    (Urgent consultation alerts can't be turned off; see the function.)
------------------------------------------------------------------
alter table public.user_settings
  add column if not exists push_off text[] not null default '{}';

alter table public.notifications
  add column if not exists push_sent_at timestamptz;

------------------------------------------------------------------
-- 3. Every new notification -> push Edge Function
------------------------------------------------------------------
create or replace function public.push_notification() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_secret text;
begin
  -- No registered devices: nothing to push (the inbox still has it).
  if not exists (select 1 from public.device_tokens where user_id = new.user_id) then
    return new;
  end if;
  select decrypted_secret into v_secret
  from vault.decrypted_secrets where name = 'push_webhook_secret';
  if v_secret is null then return new; end if;

  perform net.http_post(
    url := 'https://yokkwnwfnxlbfdmqftlc.supabase.co/functions/v1/push',
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-push-secret', v_secret
    ),
    body := jsonb_build_object('record', to_jsonb(new)),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  -- A push problem must never block the action that created the notification.
  return new;
end $$;

drop trigger if exists notifications_push on public.notifications;
create trigger notifications_push
  after insert on public.notifications
  for each row execute function public.push_notification();

-- Tell every active admin.
create or replace function public.notify_admins(
  p_kind text, p_title text, p_body text, p_data jsonb default '{}'::jsonb
) returns void language sql security definer set search_path = public as $$
  insert into public.notifications (user_id, kind, title, body, data)
  select u.id, p_kind, p_title, p_body, coalesce(p_data, '{}'::jsonb)
  from public.users u
  where u.role = 'admin' and u.status = 'active';
$$;

-- "Send me a test notification" (profile settings).
create or replace function public.send_test_notification()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  perform public.notify(
    auth.uid(), 'test_push', 'Notifications are working',
    'This is a test from GoDoctor. You will get alerts like this for your consultations, orders and more.',
    '{}'::jsonb
  );
end $$;

------------------------------------------------------------------
-- 4. Orders: chemist hears about new orders; patient follows progress
------------------------------------------------------------------
create or replace function public.order_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_code text := upper(left(new.id::text, 8));
  v_chemist text := public.display_name(new.chemist_id);
  v_patient text := public.display_name(new.patient_id);
  v_data jsonb := jsonb_build_object('order_id', new.id);
begin
  if tg_op = 'INSERT' then
    perform public.notify(
      new.chemist_id, 'order_new', 'New order from ' || v_patient,
      initcap(new.fulfillment_type::text) || ' · KES ' || to_char(new.total_amount, 'FM999,999,990')
        || case when new.prescription_id is not null
                then ' · prescription attached, please check it' else '' end,
      v_data
    );
    return new;
  end if;

  if new.status is not distinct from old.status then return new; end if;

  case new.status
    when 'confirmed' then
      perform public.notify(new.patient_id, 'order_confirmed', 'Order accepted',
        v_chemist || ' is preparing your order ' || v_code || '.', v_data);
    when 'ready' then
      perform public.notify(new.patient_id, 'order_ready',
        case when new.fulfillment_type = 'delivery' then 'Your order is on its way'
             else 'Ready for pickup' end,
        case when new.fulfillment_type = 'delivery'
             then v_chemist || ' has sent out order ' || v_code || '. Confirm when it arrives.'
             else 'Order ' || v_code || ' is ready at ' || v_chemist || '. Confirm once you collect it.' end,
        v_data);
    when 'fulfilled' then
      perform public.notify(new.chemist_id, 'order_completed', 'Order completed',
        v_patient || ' confirmed receiving order ' || v_code || '. KES '
          || to_char(new.total_amount, 'FM999,999,990') || ' is released to you.', v_data);
    when 'disputed' then
      perform public.notify(new.chemist_id, 'order_disputed', 'Order disputed',
        'Order ' || v_code || ' has been flagged. GoDoctor support will contact you.', v_data);
      perform public.notify_admins('order_disputed', 'Order disputed',
        'Order ' || v_code || ' (' || v_patient || ' / ' || v_chemist || ') needs review.', v_data);
    when 'refunded' then
      perform public.notify(new.patient_id, 'order_refunded', 'Order refunded',
        'Your payment for order ' || v_code || ' has been refunded.', v_data);
      perform public.notify(new.chemist_id, 'order_refunded', 'Order refunded',
        'Order ' || v_code || ' was refunded to the patient.', v_data);
    else null;
  end case;
  return new;
end $$;

drop trigger if exists orders_notify on public.orders;
create trigger orders_notify
  after insert or update of status on public.orders
  for each row execute function public.order_notifications();

-- The admin override used to send its own generic message; the trigger
-- above now covers it with specific ones.
create or replace function public.admin_set_order_status(p_order uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
declare v_o record;
begin
  perform public.assert_admin();
  select * into v_o from orders where id = p_order;
  if v_o.id is null then raise exception 'order not found'; end if;
  update orders
  set status = p_status::order_status,
      escrow_status = case p_status when 'refunded' then 'refunded'::escrow_status
                                    when 'fulfilled' then 'released'::escrow_status
                                    else escrow_status end
  where id = p_order;
  if p_status = 'refunded' then
    update payments set status = 'refunded' where order_id = p_order;
  end if;
end $$;

------------------------------------------------------------------
-- 5. Payment receipts (patients)
------------------------------------------------------------------
create or replace function public.payment_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_payer uuid; v_what text;
begin
  if new.status <> 'succeeded' then return new; end if;
  if new.consultation_id is not null then
    select patient_id into v_payer from consultations where id = new.consultation_id;
    v_what := 'your consultation';
  else
    select patient_id into v_payer from orders where id = new.order_id;
    v_what := 'your medicine order';
  end if;
  if v_payer is null then return new; end if;
  perform public.notify(v_payer, 'payment_receipt',
    'Payment received: KES ' || to_char(new.amount, 'FM999,999,990'),
    'Thank you. We received your payment for ' || v_what
      || case when new.is_simulated then ' (test payment).' else '.' end,
    jsonb_build_object('payment_id', new.id, 'consultation_id', new.consultation_id,
                       'order_id', new.order_id));
  return new;
end $$;

drop trigger if exists payments_notify on public.payments;
create trigger payments_notify
  after insert on public.payments
  for each row execute function public.payment_notifications();

------------------------------------------------------------------
-- 6. Consultations: doctor is ready, consultation finished
------------------------------------------------------------------
create or replace function public.consultation_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_doctor text := case when new.doctor_id is null then 'Your doctor'
                        else public.display_name(new.doctor_id) end;
  v_data jsonb := jsonb_build_object('consultation_id', new.id, 'mode', new.mode);
begin
  if new.status is not distinct from old.status then return new; end if;

  -- A booked appointment has been opened: call in whoever isn't there yet.
  if new.status = 'in_progress' and old.status = 'scheduled' then
    if auth.uid() is not distinct from new.patient_id then
      perform public.notify(new.doctor_id, 'patient_waiting',
        public.display_name(new.patient_id) || ' is waiting',
        'Your appointment has started. Tap to join the video call.', v_data);
    else
      perform public.notify(new.patient_id, 'doctor_ready', v_doctor || ' is ready for you',
        'Your appointment has started. Tap to join the video call.', v_data);
    end if;
  end if;

  if new.status = 'completed' then
    perform public.notify(new.patient_id, 'consultation_completed', 'Consultation finished',
      'How was your consultation with ' || v_doctor || '? Tap to rate your doctor.', v_data);
  end if;
  return new;
end $$;

drop trigger if exists consultations_notify on public.consultations;
create trigger consultations_notify
  after update of status on public.consultations
  for each row execute function public.consultation_notifications();

-- Admin cancellation: specific wording and kind.
create or replace function public.admin_cancel_consultation(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_c record;
begin
  perform public.assert_admin();
  select * into v_c from consultations where id = p_id;
  if v_c.id is null then raise exception 'consultation not found'; end if;
  if v_c.status in ('completed', 'cancelled') then raise exception 'already finished'; end if;
  update consultations set status = 'cancelled', ended_at = now() where id = p_id;
  if v_c.doctor_id is not null then
    update doctor_profiles set status = 'available', last_available_at = now()
    where user_id = v_c.doctor_id and status = 'busy';
    perform public.notify(v_c.doctor_id, 'consultation_cancelled', 'Consultation cancelled',
      'GoDoctor support cancelled a consultation with ' || public.display_name(v_c.patient_id) || '.',
      jsonb_build_object('consultation_id', p_id));
  end if;
  perform public.notify(v_c.patient_id, 'consultation_cancelled', 'Consultation cancelled',
    'GoDoctor support cancelled your consultation. Contact support if you have questions.',
    jsonb_build_object('consultation_id', p_id));
end $$;

-- "Your doctor is still reserved: pay within 3 minutes" (once per request).
alter table public.consultations
  add column if not exists payment_reminder_sent boolean not null default false;

create or replace function public.remind_unpaid_consultations()
returns void language plpgsql security definer set search_path = public as $$
declare rec record;
begin
  for rec in
    select id, patient_id, doctor_id from public.consultations
    where status = 'awaiting_payment'
      and not payment_reminder_sent
      and payment_due_at > now()
      and payment_due_at <= now() + interval '3 minutes'
  loop
    perform public.notify(rec.patient_id, 'payment_window_ending',
      'Your doctor is waiting',
      public.display_name(rec.doctor_id)
        || ' is reserved for you for 3 more minutes. Pay now to start the consultation.',
      jsonb_build_object('consultation_id', rec.id));
    update public.consultations set payment_reminder_sent = true where id = rec.id;
  end loop;
end $$;

do $$ begin
  perform cron.schedule('remind-unpaid-consultations', '* * * * *',
                        'select public.remind_unpaid_consultations()');
end $$;

------------------------------------------------------------------
-- 7. Doctors: reviews, family listeners joining
------------------------------------------------------------------
create or replace function public.review_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_doctor uuid;
begin
  if new.consultation_id is null then return new; end if;
  select doctor_id into v_doctor from consultations where id = new.consultation_id;
  if v_doctor is null then return new; end if;
  perform public.notify(v_doctor, 'review_new',
    'New ' || new.rating || '-star review',
    coalesce('"' || nullif(left(btrim(new.comment), 120), '') || '"',
             'A patient rated their consultation with you.'),
    jsonb_build_object('consultation_id', new.consultation_id));
  return new;
end $$;

drop trigger if exists reviews_notify on public.reviews;
create trigger reviews_notify
  after insert on public.reviews
  for each row execute function public.review_notifications();

create or replace function public.participant_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_doctor uuid;
begin
  if new.status = 'joined' and old.status is distinct from 'joined' then
    select doctor_id into v_doctor from consultations where id = new.consultation_id;
    if v_doctor is not null then
      perform public.notify(v_doctor, 'family_joined', 'A family member joined',
        public.display_name(new.user_id) || ' is listening in on your consultation with '
          || public.display_name(new.invited_by) || '.',
        jsonb_build_object('consultation_id', new.consultation_id));
    end if;
  end if;
  return new;
end $$;

drop trigger if exists participants_notify on public.consultation_participants;
create trigger participants_notify
  after update of status on public.consultation_participants
  for each row execute function public.participant_notifications();

------------------------------------------------------------------
-- 8. Verification: applicants hear the outcome; admins hear of new ones
------------------------------------------------------------------
create or replace function public.doctor_verification_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.license_verified and not old.license_verified then
    perform public.notify(new.user_id, 'verification_approved', 'You are verified',
      'Your licence has been checked. Switch to Available to start seeing patients.', '{}'::jsonb);
  elsif old.license_verified and not new.license_verified then
    perform public.notify(new.user_id, 'verification_removed', 'Verification removed',
      'Your verification was removed, so patients can''t book you. Contact support for details.',
      '{}'::jsonb);
  end if;
  if coalesce(old.license_number, '') = '' and coalesce(new.license_number, '') <> ''
     and not new.license_verified then
    perform public.notify_admins('verification_submitted', 'Doctor waiting for verification',
      coalesce(nullif(new.name, ''), 'A doctor') || ' submitted licence ' || new.license_number || '.',
      jsonb_build_object('user_id', new.user_id, 'role', 'doctor'));
  end if;
  return new;
end $$;

drop trigger if exists doctor_profiles_notify on public.doctor_profiles;
create trigger doctor_profiles_notify
  after update of license_verified, license_number on public.doctor_profiles
  for each row execute function public.doctor_verification_notifications();

create or replace function public.chemist_verification_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.verified and not old.verified then
    perform public.notify(new.user_id, 'verification_approved', 'Your pharmacy is verified',
      'Patients can now find your stock and order from you.', '{}'::jsonb);
  elsif old.verified and not new.verified then
    perform public.notify(new.user_id, 'verification_removed', 'Verification removed',
      'Your pharmacy is hidden from patients for now. Contact support for details.', '{}'::jsonb);
  end if;
  if coalesce(old.registration_number, '') = '' and coalesce(new.registration_number, '') <> ''
     and not new.verified then
    perform public.notify_admins('verification_submitted', 'Pharmacy waiting for verification',
      coalesce(nullif(new.business_name, ''), 'A pharmacy') || ' submitted registration '
        || new.registration_number || '.',
      jsonb_build_object('user_id', new.user_id, 'role', 'chemist'));
  end if;
  return new;
end $$;

drop trigger if exists chemist_profiles_notify on public.chemist_profiles;
create trigger chemist_profiles_notify
  after update of verified, registration_number on public.chemist_profiles
  for each row execute function public.chemist_verification_notifications();

------------------------------------------------------------------
-- 9. Admins: support, complaints, deletion requests, emergencies
------------------------------------------------------------------
create or replace function public.ticket_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.notify_admins('support_new',
    case new.kind
      when 'complaint' then 'New complaint'
      when 'account_deletion' then 'Account deletion request'
      when 'feedback' then 'New feedback'
      else 'New help request' end,
    public.display_name(new.user_id) || ': ' || new.subject,
    jsonb_build_object('ticket_id', new.id));
  return new;
end $$;

drop trigger if exists support_tickets_notify on public.support_tickets;
create trigger support_tickets_notify
  after insert on public.support_tickets
  for each row execute function public.ticket_notifications();

-- Existing message trigger, extended: a user's follow-up reaches admins.
create or replace function public.support_message_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_ticket record;
begin
  select * into v_ticket from public.support_tickets where id = new.ticket_id;
  update public.support_tickets
  set last_message_at = new.created_at,
      status = case when new.from_staff then 'answered' else 'open' end
  where id = new.ticket_id;
  if new.from_staff then
    perform public.notify(
      v_ticket.user_id, 'support_reply', 'GoDoctor support replied',
      left(new.body, 140),
      jsonb_build_object('ticket_id', new.ticket_id)
    );
  elsif (select count(*) from public.support_messages
         where ticket_id = new.ticket_id and not from_staff) > 1 then
    -- (The first message arrives with the ticket, which already notified.)
    perform public.notify_admins('support_user_reply',
      public.display_name(v_ticket.user_id) || ' replied',
      left(new.body, 140), jsonb_build_object('ticket_id', new.ticket_id));
  end if;
  return new;
end $$;

create or replace function public.intake_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.flagged_emergency then
    perform public.notify_admins('emergency_flagged', 'Emergency symptoms reported',
      'A patient described emergency symptoms and was told to call 999. Review if follow-up is needed.',
      jsonb_build_object('consultation_id', new.consultation_id));
  end if;
  return new;
end $$;

drop trigger if exists intake_forms_notify on public.intake_forms;
create trigger intake_forms_notify
  after insert on public.intake_forms
  for each row execute function public.intake_notifications();

------------------------------------------------------------------
-- 10. Privileges
------------------------------------------------------------------
revoke all on function
  public.register_device(text, text),
  public.unregister_device(text),
  public.send_test_notification(),
  public.push_notification(),
  public.notify_admins(text, text, text, jsonb),
  public.order_notifications(),
  public.payment_notifications(),
  public.consultation_notifications(),
  public.remind_unpaid_consultations(),
  public.review_notifications(),
  public.participant_notifications(),
  public.doctor_verification_notifications(),
  public.chemist_verification_notifications(),
  public.ticket_notifications(),
  public.intake_notifications()
from public, anon, authenticated;
grant execute on function
  public.register_device(text, text),
  public.unregister_device(text),
  public.send_test_notification()
to authenticated;
