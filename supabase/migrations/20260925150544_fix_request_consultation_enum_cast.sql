-- 0014_fix_request_consultation_enum_cast.sql
-- request_consultation() inserted `case when ... then 'cancelled' else
-- 'requested' end` into an enum column. That CASE resolves to text, so every
-- call failed with "column status is of type consultation_status but
-- expression is of type text" -- the on-demand flow could never start.

create or replace function public.request_consultation(
  p_specialty text,
  p_symptom_summary text,
  p_symptoms text,
  p_duration text,
  p_severity text,
  p_flagged_emergency boolean
)
returns uuid as $$
declare
  v_consultation_id uuid;
begin
  if (select role from public.users where id = auth.uid()) is distinct from 'patient' then
    raise exception 'only patients may request a consultation';
  end if;

  insert into public.consultations (patient_id, specialty_requested, symptom_summary, status)
  values (
    auth.uid(),
    p_specialty,
    p_symptom_summary,
    case when p_flagged_emergency
      then 'cancelled'::consultation_status
      else 'requested'::consultation_status
    end
  )
  returning id into v_consultation_id;

  -- Always written, even on the emergency hard-stop path, for audit purposes.
  insert into public.intake_forms
    (consultation_id, symptoms, duration, severity, flagged_emergency)
  values
    (v_consultation_id, p_symptoms, p_duration, p_severity, p_flagged_emergency);

  if not p_flagged_emergency then
    perform public.offer_next_candidate(v_consultation_id);
  end if;

  return v_consultation_id;
end;
$$ language plpgsql security definer set search_path = public;
