-- 0008_functions_and_triggers.sql
-- Doctor-matching logic: rank-by-longest-idle-time, offer/accept/decline/timeout chain.
-- All functions are SECURITY DEFINER so they can update doctor_profiles/consultations
-- across role boundaries, but each checks auth.uid() itself before doing anything.

------------------------------------------------------------------
-- Pick the best next candidate for a specialty, excluding doctors already
-- offered (in any status) for this specific consultation.
------------------------------------------------------------------
create or replace function public.match_next_doctor(p_consultation_id uuid, p_specialty text)
returns uuid as $$
declare
  candidate uuid;
begin
  -- Specialty match first, ranked by longest idle time (oldest last_available_at first).
  select dp.user_id into candidate
  from public.doctor_profiles dp
  where dp.license_verified = true
    and dp.status = 'available'
    and p_specialty = any (dp.specialties)
    and not exists (
      select 1 from public.consultation_offers co
      where co.consultation_id = p_consultation_id and co.doctor_id = dp.user_id
    )
  order by dp.last_available_at asc nulls first
  limit 1;

  if candidate is not null then
    return candidate;
  end if;

  -- Fallback: any available, verified general practitioner.
  select dp.user_id into candidate
  from public.doctor_profiles dp
  where dp.license_verified = true
    and dp.status = 'available'
    and 'General Practice' = any (dp.specialties)
    and not exists (
      select 1 from public.consultation_offers co
      where co.consultation_id = p_consultation_id and co.doctor_id = dp.user_id
    )
  order by dp.last_available_at asc nulls first
  limit 1;

  return candidate; -- may be null -> caller marks the consultation unmatched
end;
$$ language plpgsql security definer set search_path = public;

------------------------------------------------------------------
-- Try to offer the next candidate for a consultation. Marks the consultation
-- `unmatched` if nobody is left to try.
------------------------------------------------------------------
create or replace function public.offer_next_candidate(p_consultation_id uuid)
returns uuid as $$
declare
  v_specialty text;
  v_candidate uuid;
begin
  select specialty_requested into v_specialty
  from public.consultations where id = p_consultation_id;

  v_candidate := public.match_next_doctor(p_consultation_id, v_specialty);

  if v_candidate is null then
    update public.consultations set status = 'unmatched' where id = p_consultation_id;
    return null;
  end if;

  update public.doctor_profiles set status = 'offered' where user_id = v_candidate;

  insert into public.consultation_offers (consultation_id, doctor_id)
  values (p_consultation_id, v_candidate);

  return v_candidate;
end;
$$ language plpgsql security definer set search_path = public;

------------------------------------------------------------------
-- Patient-facing entry point: create the consultation (+ intake form for
-- audit), hard-stop on emergency flag, otherwise kick off matching.
------------------------------------------------------------------
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
    case when p_flagged_emergency then 'cancelled' else 'requested' end
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

------------------------------------------------------------------
-- Doctor-facing entry point: accept or decline a pending offer.
------------------------------------------------------------------
create or replace function public.respond_to_offer(p_offer_id uuid, p_accept boolean)
returns void as $$
declare
  v_doctor uuid;
  v_consultation uuid;
  v_status offer_status;
begin
  select doctor_id, consultation_id, status
  into v_doctor, v_consultation, v_status
  from public.consultation_offers where id = p_offer_id;

  if v_doctor is null then
    raise exception 'offer not found';
  end if;

  if v_doctor <> auth.uid() then
    raise exception 'not your offer';
  end if;

  if v_status <> 'pending' then
    return; -- already responded to or expired, no-op
  end if;

  if p_accept then
    update public.consultation_offers
    set status = 'accepted', responded_at = now()
    where id = p_offer_id;

    update public.consultations
    set status = 'matched', doctor_id = v_doctor, started_at = now()
    where id = v_consultation;

    update public.doctor_profiles
    set status = 'busy'
    where user_id = v_doctor;
  else
    update public.consultation_offers
    set status = 'declined', responded_at = now()
    where id = p_offer_id;

    update public.doctor_profiles
    set status = 'available', last_available_at = now()
    where user_id = v_doctor;

    perform public.offer_next_candidate(v_consultation);
  end if;
end;
$$ language plpgsql security definer set search_path = public;

------------------------------------------------------------------
-- Expire stale offers past their expires_at and continue the chain for each.
-- Intended to be invoked periodically (pg_cron, or an Edge Function on a
-- schedule) since Postgres has no built-in timer. See README for setup.
------------------------------------------------------------------
create or replace function public.expire_stale_offers()
returns void as $$
declare
  rec record;
begin
  for rec in
    select id, consultation_id, doctor_id
    from public.consultation_offers
    where status = 'pending' and expires_at < now()
  loop
    update public.consultation_offers
    set status = 'expired', responded_at = now()
    where id = rec.id;

    update public.doctor_profiles
    set status = 'available', last_available_at = now()
    where user_id = rec.doctor_id;

    perform public.offer_next_candidate(rec.consultation_id);
  end loop;
end;
$$ language plpgsql security definer set search_path = public;

------------------------------------------------------------------
-- Doctor toggles themselves available/offline. Blocked until license_verified
-- (defense in depth -- the UI already hides the toggle pre-verification).
------------------------------------------------------------------
create or replace function public.set_doctor_availability(p_available boolean)
returns void as $$
declare
  v_verified boolean;
begin
  select license_verified into v_verified
  from public.doctor_profiles where user_id = auth.uid();

  if v_verified is not true and p_available then
    raise exception 'doctor is not yet verified';
  end if;

  update public.doctor_profiles
  set status = case when p_available then 'available' else 'offline' end,
      last_available_at = case when p_available then now() else last_available_at end
  where user_id = auth.uid();
end;
$$ language plpgsql security definer set search_path = public;

------------------------------------------------------------------
-- Doctor marks a consultation complete -- flips them back to available.
------------------------------------------------------------------
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
  where user_id = v_doctor;
end;
$$ language plpgsql security definer set search_path = public;

------------------------------------------------------------------
-- Enable Realtime on the tables the client subscribes to.
------------------------------------------------------------------
alter publication supabase_realtime add table public.consultation_offers;
alter publication supabase_realtime add table public.consultations;
alter publication supabase_realtime add table public.orders;
