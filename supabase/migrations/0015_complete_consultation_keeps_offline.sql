-- 0015_complete_consultation_keeps_offline.sql
-- complete_consultation() always set the doctor to 'available'. That is right
-- after an on-demand consult (they were 'busy'), but wrong after a scheduled
-- appointment: a doctor who chose to stay offline for on-demand offers would
-- suddenly start receiving them. Only reset doctors who were actually busy.

create or replace function public.complete_consultation(p_consultation_id uuid)
returns void as $$
declare
  v_doctor uuid;
begin
  select doctor_id into v_doctor
  from public.consultations
  where id = p_consultation_id;

  if v_doctor is distinct from auth.uid() then
    raise exception 'not your consultation';
  end if;

  update public.consultations
  set status = 'completed', ended_at = now()
  where id = p_consultation_id;

  update public.doctor_profiles
  set status = 'available', last_available_at = now()
  where user_id = v_doctor and status = 'busy';
end;
$$ language plpgsql security definer set search_path = public;
