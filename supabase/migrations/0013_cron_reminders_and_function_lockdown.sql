-- 0013_cron_reminders_and_function_lockdown.sql

------------------------------------------------------------------
-- 1. Scheduled jobs (pg_cron)
--    * expire_stale_offers existed but nothing ever called it, so an offer a
--      doctor ignored (closed tab, no signal) left the patient waiting forever.
--    * process_scheduled_appointments sends reminders and closes no-shows.
------------------------------------------------------------------
create extension if not exists pg_cron with schema pg_catalog;

create or replace function public.process_scheduled_appointments()
returns void as $$
declare
  rec record;
  v_when text;
begin
  -- 24-hour reminder (only for appointments booked more than 24h ahead).
  for rec in
    select id, patient_id, doctor_id, scheduled_for
    from public.consultations
    where mode = 'scheduled' and status = 'scheduled'
      and not reminder_24h_sent
      and scheduled_for - now() <= interval '24 hours'
      and scheduled_for - now() > interval '1 hour'
      and created_at <= scheduled_for - interval '24 hours'
  loop
    v_when := to_char(rec.scheduled_for at time zone 'Africa/Nairobi', 'Dy DD Mon, HH24:MI');
    perform public.notify(rec.patient_id, 'appointment_reminder', 'Appointment tomorrow',
      'Your consultation is on ' || v_when || ' (EAT).', jsonb_build_object('consultation_id', rec.id));
    perform public.notify(rec.doctor_id, 'appointment_reminder', 'Appointment tomorrow',
      'You have a consultation on ' || v_when || ' (EAT).', jsonb_build_object('consultation_id', rec.id));
    update public.consultations set reminder_24h_sent = true where id = rec.id;
  end loop;

  -- 1-hour reminder.
  for rec in
    select id, patient_id, doctor_id, scheduled_for
    from public.consultations
    where mode = 'scheduled' and status = 'scheduled'
      and not reminder_1h_sent
      and scheduled_for - now() <= interval '1 hour'
      and scheduled_for > now()
  loop
    v_when := to_char(rec.scheduled_for at time zone 'Africa/Nairobi', 'HH24:MI');
    perform public.notify(rec.patient_id, 'appointment_reminder', 'Starting soon',
      'Your consultation starts at ' || v_when || ' (EAT).', jsonb_build_object('consultation_id', rec.id));
    perform public.notify(rec.doctor_id, 'appointment_reminder', 'Starting soon',
      'Your consultation starts at ' || v_when || ' (EAT).', jsonb_build_object('consultation_id', rec.id));
    update public.consultations set reminder_1h_sent = true, reminder_24h_sent = true where id = rec.id;
  end loop;

  -- Nobody started it: close the slot's record as cancelled.
  update public.consultations
  set status = 'cancelled'
  where mode = 'scheduled' and status = 'scheduled' and scheduled_end < now();
end;
$$ language plpgsql security definer set search_path = public;

do $$ begin
  perform cron.schedule('expire-stale-offers', '10 seconds', 'select public.expire_stale_offers()');
  perform cron.schedule('process-scheduled-appointments', '* * * * *', 'select public.process_scheduled_appointments()');
end $$;

------------------------------------------------------------------
-- 2. Function privileges. Every function here is SECURITY DEFINER, and by
--    default Postgres lets PUBLIC (incl. the anonymous key) execute it.
------------------------------------------------------------------
-- Internal: only called by other definer functions, triggers, or cron.
revoke all on function
  public.match_next_doctor(uuid, text),
  public.offer_next_candidate(uuid),
  public.expire_stale_offers(),
  public.refresh_doctor_rating(),
  public.handle_new_auth_user(),
  public.process_scheduled_appointments()
from public, anon, authenticated;

-- User-facing RPCs: signed-in users only.
revoke all on function
  public.request_consultation(text, text, text, text, text, boolean),
  public.respond_to_offer(uuid, boolean),
  public.complete_consultation(uuid),
  public.set_doctor_availability(boolean),
  public.admin_set_chemist_verified(uuid, boolean),
  public.admin_set_doctor_verified(uuid, boolean),
  public.current_role_is(user_role)
from public, anon;
grant execute on function
  public.request_consultation(text, text, text, text, text, boolean),
  public.respond_to_offer(uuid, boolean),
  public.complete_consultation(uuid),
  public.set_doctor_availability(boolean),
  public.admin_set_chemist_verified(uuid, boolean),
  public.admin_set_doctor_verified(uuid, boolean),
  public.current_role_is(user_role)
to authenticated;

------------------------------------------------------------------
-- 3. Linter hygiene
------------------------------------------------------------------
alter function public.set_updated_at() set search_path = public;
alter function public.chemist_inventory_touch() set search_path = public;
alter extension pg_trgm set schema extensions;
