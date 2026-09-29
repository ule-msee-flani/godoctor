-- The welcome path (a few questions after sign-up, before the dashboard),
-- the "my details are genuine" declaration on registration, and clearer
-- verification messages.

------------------------------------------------------------------
-- 1. What the welcome path collects.
------------------------------------------------------------------
alter table public.users
  add column if not exists onboarded_at timestamptz;

alter table public.patient_profiles
  add column if not exists county text check (county is null or length(county) <= 60),
  add column if not exists health_cover text
    check (health_cover is null or health_cover in ('sha', 'private', 'both', 'none')),
  add column if not exists heard_from text check (heard_from is null or length(heard_from) <= 60);

alter table public.doctor_profiles
  add column if not exists practice_facility text
    check (practice_facility is null or length(practice_facility) <= 120),
  add column if not exists practice_county text
    check (practice_county is null or length(practice_county) <= 60),
  add column if not exists focus_areas text[] not null default '{}',
  add column if not exists consult_times text[] not null default '{}',
  add column if not exists attested_at timestamptz;

alter table public.chemist_profiles
  add column if not exists pharmacist_name text
    check (pharmacist_name is null or length(pharmacist_name) <= 120),
  add column if not exists open_days text[] not null default '{}',
  add column if not exists opening_hours text
    check (opening_hours is null or length(opening_hours) <= 40),
  add column if not exists offers_delivery boolean,
  add column if not exists delivery_radius_km integer
    check (delivery_radius_km is null or delivery_radius_km between 1 and 100),
  add column if not exists services text[] not null default '{}',
  add column if not exists mpesa_till text
    check (mpesa_till is null or mpesa_till ~ '^[0-9]{5,10}$'),
  add column if not exists attested_at timestamptz;

-- Saves the answers for the caller's role (only these fields) and marks
-- the welcome path done. Missing keys leave a field as it is.
create or replace function public.complete_onboarding(p jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_role text;
  v_arr text[];
begin
  select role::text into v_role from public.users where id = v_me;
  if v_role is null then raise exception 'not signed in'; end if;
  if jsonb_typeof(p) <> 'object' then raise exception 'bad answers'; end if;

  if p ? 'phone' then
    update public.users set contact_phone = nullif(left(btrim(p->>'phone'), 20), '')
    where id = v_me;
  end if;

  if v_role = 'patient' then
    update public.patient_profiles pp set
      name = case when p ? 'name' and btrim(p->>'name') <> ''
                  then left(btrim(p->>'name'), 120) else pp.name end,
      date_of_birth = case when p ? 'date_of_birth'
                           then nullif(p->>'date_of_birth', '')::date else pp.date_of_birth end,
      gender = case when p ? 'gender' then nullif(p->>'gender', '') else pp.gender end,
      location_lat = case when p ? 'location_lat' then (p->>'location_lat')::double precision else pp.location_lat end,
      location_lng = case when p ? 'location_lng' then (p->>'location_lng')::double precision else pp.location_lng end,
      location_name = case when p ? 'location_name' then left(p->>'location_name', 200) else pp.location_name end,
      county = case when p ? 'county' then nullif(left(p->>'county', 60), '') else pp.county end,
      chronic_conditions = case when p ? 'conditions' then nullif(left(p->>'conditions', 1000), '') else pp.chronic_conditions end,
      allergies = case when p ? 'allergies' then nullif(left(p->>'allergies', 1000), '') else pp.allergies end,
      current_medications = case when p ? 'medications' then nullif(left(p->>'medications', 1000), '') else pp.current_medications end,
      blood_group = case when p ? 'blood_group' then nullif(p->>'blood_group', '') else pp.blood_group end,
      emergency_contact_name = case when p ? 'emergency_name' then nullif(left(btrim(p->>'emergency_name'), 120), '') else pp.emergency_contact_name end,
      emergency_contact_phone = case when p ? 'emergency_phone' then nullif(left(btrim(p->>'emergency_phone'), 20), '') else pp.emergency_contact_phone end,
      health_cover = case when p ? 'health_cover' then nullif(p->>'health_cover', '') else pp.health_cover end,
      heard_from = case when p ? 'heard_from' then nullif(left(p->>'heard_from', 60), '') else pp.heard_from end
    where pp.user_id = v_me;

  elsif v_role = 'doctor' then
    update public.doctor_profiles dp set
      name = case when p ? 'name' and btrim(p->>'name') <> ''
                  then left(btrim(p->>'name'), 120) else dp.name end,
      gender = case when p ? 'gender' then nullif(p->>'gender', '') else dp.gender end,
      specialties = case when jsonb_typeof(p->'specialties') = 'array'
                              and jsonb_array_length(p->'specialties') > 0
                         then array(select jsonb_array_elements_text(p->'specialties'))
                         else dp.specialties end,
      years_experience = case when p ? 'years_experience'
                              then least(greatest((p->>'years_experience')::int, 0), 60)
                              else dp.years_experience end,
      languages = case when jsonb_typeof(p->'languages') = 'array'
                       then array(select jsonb_array_elements_text(p->'languages'))
                       else dp.languages end,
      practice_facility = case when p ? 'practice_facility' then nullif(left(btrim(p->>'practice_facility'), 120), '') else dp.practice_facility end,
      practice_county = case when p ? 'practice_county' then nullif(left(p->>'practice_county', 60), '') else dp.practice_county end,
      focus_areas = case when jsonb_typeof(p->'focus_areas') = 'array'
                         then array(select jsonb_array_elements_text(p->'focus_areas'))
                         else dp.focus_areas end,
      consultation_fee = case when p ? 'consultation_fee'
                              then least(greatest((p->>'consultation_fee')::numeric, 0), 100000)
                              else dp.consultation_fee end,
      consult_times = case when jsonb_typeof(p->'consult_times') = 'array'
                           then array(select jsonb_array_elements_text(p->'consult_times'))
                           else dp.consult_times end,
      bio = case when p ? 'bio' then nullif(left(btrim(p->>'bio'), 600), '') else dp.bio end
    where dp.user_id = v_me;

  elsif v_role = 'chemist' then
    update public.chemist_profiles cp set
      business_name = case when p ? 'business_name' and btrim(p->>'business_name') <> ''
                           then left(btrim(p->>'business_name'), 120) else cp.business_name end,
      location_lat = case when p ? 'location_lat' then (p->>'location_lat')::double precision else cp.location_lat end,
      location_lng = case when p ? 'location_lng' then (p->>'location_lng')::double precision else cp.location_lng end,
      location_name = case when p ? 'location_name' then left(p->>'location_name', 200) else cp.location_name end,
      pharmacist_name = case when p ? 'pharmacist_name' then nullif(left(btrim(p->>'pharmacist_name'), 120), '') else cp.pharmacist_name end,
      open_days = case when jsonb_typeof(p->'open_days') = 'array'
                       then array(select jsonb_array_elements_text(p->'open_days'))
                       else cp.open_days end,
      opening_hours = case when p ? 'opening_hours' then nullif(left(p->>'opening_hours', 40), '') else cp.opening_hours end,
      offers_delivery = case when p ? 'offers_delivery' then (p->>'offers_delivery')::boolean else cp.offers_delivery end,
      delivery_radius_km = case when p ? 'delivery_radius_km'
                                then nullif(p->>'delivery_radius_km', '')::int else cp.delivery_radius_km end,
      services = case when jsonb_typeof(p->'services') = 'array'
                      then array(select jsonb_array_elements_text(p->'services'))
                      else cp.services end,
      mpesa_till = case when p ? 'mpesa_till' then nullif(regexp_replace(p->>'mpesa_till', '\D', '', 'g'), '') else cp.mpesa_till end
    where cp.user_id = v_me;
  end if;

  update public.users set onboarded_at = coalesce(onboarded_at, now()) where id = v_me;
end $$;

------------------------------------------------------------------
-- 2. "The details I've given are genuine" -- recorded with the
--    registration, and required before it counts as submitted.
------------------------------------------------------------------
create or replace function public.attest_registration()
returns void language plpgsql security definer set search_path = public as $$
begin
  if public.current_role_is('doctor') then
    update public.doctor_profiles set attested_at = now() where user_id = auth.uid();
  elsif public.current_role_is('chemist') then
    update public.chemist_profiles set attested_at = now() where user_id = auth.uid();
  else
    raise exception 'doctors_and_pharmacies_only';
  end if;
end $$;

------------------------------------------------------------------
-- 3. Clearer outcome messages (they're also emailed, see the push
--    function).
------------------------------------------------------------------
create or replace function public.doctor_verification_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.license_verified and not old.license_verified then
    perform public.notify(new.user_id, 'verification_approved',
      'You''re verified! Welcome to GoDoctor',
      'We checked your licence and your portal is open. Go online whenever '
        || 'you''re ready and start seeing patients.', '{}'::jsonb);
  elsif old.license_verified and not new.license_verified then
    perform public.notify(new.user_id, 'verification_removed', 'Verification removed',
      'Your verification was removed, so patients can''t book you. Contact support for details.',
      '{}'::jsonb);
  end if;
  if coalesce(old.license_number, '') = '' and coalesce(new.license_number, '') <> ''
     and not new.license_verified then
    perform public.notify_admins('verification_submitted', 'Doctor waiting for verification',
      coalesce(nullif(new.name, ''), 'A doctor') || ' submitted licence '
        || new.license_number || '.',
      jsonb_build_object('user_id', new.user_id, 'role', 'doctor'));
  end if;
  return new;
end $$;

create or replace function public.chemist_verification_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.verified and not old.verified then
    perform public.notify(new.user_id, 'verification_approved',
      'Your pharmacy is verified! Welcome to GoDoctor',
      'We checked your registration and your portal is open. Patients near '
        || 'you can now find your stock and order from you.', '{}'::jsonb);
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

revoke all on function public.complete_onboarding(jsonb), public.attest_registration()
  from public, anon;
grant execute on function public.complete_onboarding(jsonb), public.attest_registration()
  to authenticated;
