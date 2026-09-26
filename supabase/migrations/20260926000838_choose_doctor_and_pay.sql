-- "See a doctor" is now: describe the problem -> choose from the doctors who
-- are online -> pay -> consultation starts.
--
--   request_doctor()            patient picks a doctor; the doctor is reserved
--                               (status busy) for 10 minutes while they pay
--   pay_for_consultation()      SIMULATED M-Pesa payment; starts the consult
--   cancel_consultation_request() patient backs out; doctor released
--   process_scheduled_appointments() (cron, every minute) now also releases
--                               doctors whose patient never paid
--
-- The old automatic matching (request_consultation / offers) is left in place
-- but is no longer used by the app.

alter table public.consultations add column if not exists payment_due_at timestamptz;

------------------------------------------------------------------
-- Patient chooses a doctor
------------------------------------------------------------------
create or replace function public.request_doctor(
  p_doctor_id uuid,
  p_specialty text,
  p_symptoms text,
  p_flagged_emergency boolean default false
) returns uuid as $$
declare
  v_id uuid;
  v_fee numeric;
  v_ok boolean;
  v_patient_name text;
begin
  if (select role from public.users where id = auth.uid()) is distinct from 'patient' then
    raise exception 'only patients can request a doctor';
  end if;

  -- Emergency hard stop: recorded for audit, never sent to a doctor.
  if p_flagged_emergency then
    insert into public.consultations (patient_id, specialty_requested, symptom_summary, status)
    values (auth.uid(), p_specialty, coalesce(p_symptoms, ''), 'cancelled')
    returning id into v_id;
    insert into public.intake_forms (consultation_id, symptoms, flagged_emergency)
    values (v_id, coalesce(p_symptoms, ''), true);
    return v_id;
  end if;

  if exists (
    select 1 from public.consultations
    where patient_id = auth.uid() and mode = 'on_demand'
      and status in ('awaiting_payment', 'matched', 'in_progress')
  ) then
    raise exception 'active_consultation_exists';
  end if;

  -- Lock the doctor's row so two patients can't reserve the same doctor.
  select dp.consultation_fee,
         dp.license_verified and dp.status = 'available' and u.status = 'active'
  into v_fee, v_ok
  from public.doctor_profiles dp
  join public.users u on u.id = dp.user_id
  where dp.user_id = p_doctor_id
  for update of dp;

  if not coalesce(v_ok, false) then
    raise exception 'doctor_unavailable';
  end if;

  insert into public.consultations
    (patient_id, doctor_id, specialty_requested, symptom_summary, status, mode,
     fee_amount, payment_due_at)
  values
    (auth.uid(), p_doctor_id, p_specialty, coalesce(p_symptoms, ''),
     'awaiting_payment', 'on_demand', v_fee, now() + interval '10 minutes')
  returning id into v_id;

  insert into public.intake_forms (consultation_id, symptoms, flagged_emergency)
  values (v_id, coalesce(p_symptoms, ''), false);

  update public.doctor_profiles set status = 'busy' where user_id = p_doctor_id;

  select name into v_patient_name from public.patient_profiles where user_id = auth.uid();
  perform public.notify(
    p_doctor_id, 'patient_selected', 'A patient chose you',
    coalesce(nullif(v_patient_name, ''), 'A patient') || ' is paying now. Stay online; the consultation starts as soon as they pay.',
    jsonb_build_object('consultation_id', v_id)
  );
  return v_id;
end;
$$ language plpgsql security definer set search_path = public;

------------------------------------------------------------------
-- Payment (SIMULATED until M-Pesa Daraja is wired up)
------------------------------------------------------------------
create or replace function public.pay_for_consultation(p_id uuid) returns void as $$
declare
  v_c public.consultations;
begin
  select * into v_c from public.consultations
  where id = p_id and patient_id = auth.uid()
  for update;

  if v_c.id is null then
    raise exception 'not your consultation';
  end if;
  if v_c.status <> 'awaiting_payment' then
    raise exception 'consultation_not_awaiting_payment';
  end if;
  if v_c.payment_due_at < now() then
    raise exception 'payment_window_expired';
  end if;

  insert into public.payments (consultation_id, amount, provider, status, is_simulated)
  values (p_id, coalesce(v_c.fee_amount, 0), 'mpesa', 'succeeded', true);

  update public.consultations
  set status = 'in_progress', started_at = now(), payment_due_at = null
  where id = p_id;

  perform public.notify(
    v_c.doctor_id, 'patient_paid', 'Payment received',
    'Your patient has paid. Join the consultation now.',
    jsonb_build_object('consultation_id', p_id)
  );
end;
$$ language plpgsql security definer set search_path = public;

------------------------------------------------------------------
-- Patient backs out before paying
------------------------------------------------------------------
create or replace function public.cancel_consultation_request(p_id uuid) returns void as $$
declare
  v_c public.consultations;
begin
  update public.consultations set status = 'cancelled', payment_due_at = null
  where id = p_id and patient_id = auth.uid() and status = 'awaiting_payment'
  returning * into v_c;

  if v_c.id is null then
    raise exception 'request cannot be cancelled';
  end if;

  update public.doctor_profiles set status = 'available', last_available_at = now()
  where user_id = v_c.doctor_id and status = 'busy';

  perform public.notify(
    v_c.doctor_id, 'patient_cancelled', 'Patient cancelled',
    'The patient cancelled before paying. You are available again.',
    jsonb_build_object('consultation_id', p_id)
  );
end;
$$ language plpgsql security definer set search_path = public;

------------------------------------------------------------------
-- Cron: also release doctors whose patient never paid
------------------------------------------------------------------
create or replace function public.expire_unpaid_consultations() returns void as $$
declare
  rec record;
begin
  for rec in
    update public.consultations set status = 'cancelled', payment_due_at = null
    where status = 'awaiting_payment' and payment_due_at < now()
    returning id, doctor_id, patient_id
  loop
    update public.doctor_profiles set status = 'available', last_available_at = now()
    where user_id = rec.doctor_id and status = 'busy';
    perform public.notify(rec.doctor_id, 'patient_cancelled', 'Request expired',
      'The patient did not pay in time. You are available again.',
      jsonb_build_object('consultation_id', rec.id));
    perform public.notify(rec.patient_id, 'request_expired', 'Request expired',
      'Your doctor reservation expired because payment was not completed. You can choose a doctor again.',
      jsonb_build_object('consultation_id', rec.id));
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

do $$ begin
  perform cron.schedule('expire-unpaid-consultations', '* * * * *', 'select public.expire_unpaid_consultations()');
end $$;

------------------------------------------------------------------
-- Payments for consultations are only ever written by pay_for_consultation;
-- patients may still insert (simulated) ORDER payments from the app.
------------------------------------------------------------------
drop policy if exists payments_patient_insert on public.payments;
create policy payments_patient_insert on public.payments
  for insert with check (
    consultation_id is null
    and exists (select 1 from public.orders o
                where o.id = payments.order_id and o.patient_id = auth.uid())
  );

------------------------------------------------------------------
-- Privileges
------------------------------------------------------------------
revoke all on function
  public.request_doctor(uuid, text, text, boolean),
  public.pay_for_consultation(uuid),
  public.cancel_consultation_request(uuid)
from public, anon;
grant execute on function
  public.request_doctor(uuid, text, text, boolean),
  public.pay_for_consultation(uuid),
  public.cancel_consultation_request(uuid)
to authenticated;
revoke all on function public.expire_unpaid_consultations() from public, anon, authenticated;
