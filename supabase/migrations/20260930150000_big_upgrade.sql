-- The big upgrade: mood check-ins, health readings (blood pressure, sugar,
-- weight), the GoDoctor health card (a short-lived QR code a doctor or
-- pharmacy scans), the appointments list, and pharmacy delivery / hours
-- on the public pharmacy pages.

------------------------------------------------------------------
-- 1. "How are you feeling today?"
------------------------------------------------------------------
create table if not exists public.mood_checkins (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.users (id) on delete cascade,
  mood text not null check (mood in ('great', 'good', 'okay', 'low', 'unwell')),
  created_at timestamptz not null default now()
);
create index if not exists mood_checkins_patient_idx
  on public.mood_checkins (patient_id, created_at desc);
alter table public.mood_checkins enable row level security;
drop policy if exists mood_checkins_own on public.mood_checkins;
create policy mood_checkins_own on public.mood_checkins
  for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());

------------------------------------------------------------------
-- 2. Health readings the patient logs.
------------------------------------------------------------------
create table if not exists public.health_readings (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.users (id) on delete cascade,
  kind text not null check (kind in ('bp', 'sugar', 'weight')),
  -- bp: systolic; sugar: mmol/L; weight: kg
  value numeric(6, 1) not null check (value > 0 and value < 1000),
  -- bp: diastolic
  value2 numeric(6, 1) check (value2 is null or (value2 > 0 and value2 < 400)),
  -- sugar: fasting / after_meal / random
  context text check (context is null or context in ('fasting', 'after_meal', 'random')),
  note text check (note is null or length(note) <= 200),
  taken_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists health_readings_patient_idx
  on public.health_readings (patient_id, kind, taken_at desc);
alter table public.health_readings enable row level security;
drop policy if exists health_readings_own on public.health_readings;
create policy health_readings_own on public.health_readings
  for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());

------------------------------------------------------------------
-- 3. The patient card, now with the latest readings, opened either by the
--    patient's own doctor/pharmacy or with a code from their health card.
------------------------------------------------------------------
create or replace function public._patient_card_row(p_patient uuid, p_viewer uuid)
returns table (
  user_id uuid, name text, avatar_url text, age integer, gender text,
  blood_group text, allergies text, chronic_conditions text,
  current_medications text, member_since timestamptz,
  visits_with_me bigint, orders_with_me bigint,
  bp_sys numeric, bp_dia numeric, bp_at timestamptz,
  sugar numeric, sugar_at timestamptz,
  weight numeric, weight_at timestamptz
) language sql stable security definer set search_path = public as $$
  select pp.user_id, pp.name, u.avatar_url,
         case when pp.date_of_birth is null then null
              else extract(year from age(pp.date_of_birth))::integer end,
         pp.gender, pp.blood_group, pp.allergies, pp.chronic_conditions,
         pp.current_medications, u.created_at,
         (select count(*) from public.consultations c
          where c.patient_id = p_patient and c.doctor_id = p_viewer
            and c.status = 'completed'),
         (select count(*) from public.orders o
          where o.patient_id = p_patient and o.chemist_id = p_viewer
            and o.status <> 'refunded'),
         bp.value, bp.value2, bp.taken_at,
         sg.value, sg.taken_at,
         wt.value, wt.taken_at
  from public.patient_profiles pp
  join public.users u on u.id = pp.user_id
  left join lateral (select value, value2, taken_at from public.health_readings
                     where patient_id = p_patient and kind = 'bp'
                     order by taken_at desc limit 1) bp on true
  left join lateral (select value, taken_at from public.health_readings
                     where patient_id = p_patient and kind = 'sugar'
                     order by taken_at desc limit 1) sg on true
  left join lateral (select value, taken_at from public.health_readings
                     where patient_id = p_patient and kind = 'weight'
                     order by taken_at desc limit 1) wt on true
  where pp.user_id = p_patient;
$$;
revoke all on function public._patient_card_row(uuid, uuid) from public, anon, authenticated;

drop function if exists public.patient_card(uuid);
create function public.patient_card(p_patient uuid)
returns table (
  user_id uuid, name text, avatar_url text, age integer, gender text,
  blood_group text, allergies text, chronic_conditions text,
  current_medications text, member_since timestamptz,
  visits_with_me bigint, orders_with_me bigint,
  bp_sys numeric, bp_dia numeric, bp_at timestamptz,
  sugar numeric, sugar_at timestamptz,
  weight numeric, weight_at timestamptz
) language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null or not (
       exists (select 1 from public.consultations c
               where c.patient_id = p_patient and c.doctor_id = v_me)
    or exists (select 1 from public.orders o
               where o.patient_id = p_patient and o.chemist_id = v_me)
    or public.current_role_is('admin')
  ) then
    raise exception 'not_your_patient';
  end if;
  return query select * from public._patient_card_row(p_patient, v_me);
end $$;

-- Codes shown as a QR on the patient's GoDoctor health card.
create table if not exists public.patient_share_codes (
  code text primary key check (code ~ '^[A-Z0-9]{8}$'),
  patient_id uuid not null references public.users (id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
alter table public.patient_share_codes enable row level security;
-- No policies: only the functions below touch it.

create or replace function public.create_patient_share_code()
returns table (code text, expires_at timestamptz)
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_me uuid := auth.uid();
  v_code text;
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  i int;
begin
  if v_me is null or not public.current_role_is('patient') then
    raise exception 'patients_only';
  end if;
  delete from public.patient_share_codes
  where patient_id = v_me or public.patient_share_codes.expires_at < now();
  v_code := '';
  for i in 1..8 loop
    v_code := v_code || substr(v_alphabet, 1 + (get_byte(gen_random_bytes(1), 0) % 32), 1);
  end loop;
  insert into public.patient_share_codes (code, patient_id, expires_at)
  values (v_code, v_me, now() + interval '15 minutes');
  return query select v_code, now() + interval '15 minutes';
end $$;

-- A doctor or pharmacy scans the QR: the card opens while the code is
-- valid, and the patient is told who looked.
create or replace function public.patient_card_by_code(p_code text)
returns table (
  user_id uuid, name text, avatar_url text, age integer, gender text,
  blood_group text, allergies text, chronic_conditions text,
  current_medications text, member_since timestamptz,
  visits_with_me bigint, orders_with_me bigint,
  bp_sys numeric, bp_dia numeric, bp_at timestamptz,
  sugar numeric, sugar_at timestamptz,
  weight numeric, weight_at timestamptz
) language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_patient uuid;
  v_who text;
begin
  if v_me is null or not (
       exists (select 1 from public.doctor_profiles where user_id = v_me and license_verified)
    or exists (select 1 from public.chemist_profiles where user_id = v_me and verified)
  ) then
    raise exception 'verified_professionals_only';
  end if;
  select s.patient_id into v_patient from public.patient_share_codes s
  where s.code = upper(btrim(p_code)) and s.expires_at > now();
  if v_patient is null then raise exception 'card_code_expired'; end if;

  select coalesce(
    (select nullif(dp.name, '') from public.doctor_profiles dp where dp.user_id = v_me),
    (select nullif(cp.business_name, '') from public.chemist_profiles cp where cp.user_id = v_me),
    'A GoDoctor professional') into v_who;
  perform public.notify(v_patient, 'card_viewed', 'Your health card was opened',
    v_who || ' opened your GoDoctor health card.', '{}'::jsonb);

  return query select * from public._patient_card_row(v_patient, v_me);
end $$;

------------------------------------------------------------------
-- 4. The appointments list (upcoming, completed, cancelled).
------------------------------------------------------------------
create or replace function public.patient_appointments()
returns table (
  consultation_id uuid, doctor_id uuid, doctor_name text, doctor_avatar text,
  specialty text, symptoms text, status text, mode text,
  starts_at timestamptz, ends_at timestamptz, fee numeric,
  practice_facility text, my_rating integer
) language sql stable security definer set search_path = public as $$
  select c.id, c.doctor_id, dp.name, dp.avatar_url, c.specialty_requested,
         c.symptom_summary, c.status::text, c.mode::text,
         coalesce(c.scheduled_for, c.started_at, c.created_at),
         c.scheduled_end, c.fee_amount, dp.practice_facility,
         (select r.rating from public.reviews r
          where r.consultation_id = c.id and r.author_id = auth.uid() limit 1)
  from public.consultations c
  left join public.doctor_profiles dp on dp.user_id = c.doctor_id
  where c.patient_id = auth.uid()
    and c.status::text not in ('requested', 'unmatched')
  order by coalesce(c.scheduled_for, c.started_at, c.created_at) desc
  limit 300;
$$;

------------------------------------------------------------------
-- 5. Public pharmacy pages: delivery, hours and services too.
------------------------------------------------------------------
drop function if exists public.chemist_public_profile(uuid);
create function public.chemist_public_profile(p_chemist uuid)
returns table (
  user_id uuid, business_name text, avatar_url text, contact_phone text,
  location_name text, location_lat double precision,
  location_lng double precision, member_since timestamptz,
  medicines_in_stock bigint, orders_filled bigint,
  rating_avg numeric, rating_count bigint,
  offers_delivery boolean, delivery_radius_km integer,
  opening_hours text, open_days text[], services text[]
) language sql stable security definer set search_path = public as $$
  select cp.user_id, cp.business_name, u.avatar_url, u.contact_phone,
         cp.location_name,
         cp.location_lat::double precision, cp.location_lng::double precision,
         u.created_at,
         (select count(*) from public.chemist_inventory ci
          where ci.chemist_id = cp.user_id and ci.quantity > 0),
         (select count(*) from public.orders o
          where o.chemist_id = cp.user_id and o.status = 'fulfilled'),
         coalesce(rv.avg, 0), coalesce(rv.n, 0),
         cp.offers_delivery, cp.delivery_radius_km, cp.opening_hours,
         cp.open_days, cp.services
  from public.chemist_profiles cp
  join public.users u on u.id = cp.user_id and u.status = 'active'
  left join lateral (
    select round(avg(r.rating)::numeric, 2) as avg, count(*) as n
    from public.reviews r join public.orders o on o.id = r.order_id
    where o.chemist_id = cp.user_id
  ) rv on true
  where cp.user_id = p_chemist and cp.verified;
$$;

drop function if exists public.public_chemists();
create function public.public_chemists()
returns table (
  user_id uuid, business_name text, avatar_url text, contact_phone text,
  location_name text, location_lat double precision,
  location_lng double precision, member_since timestamptz,
  medicines_in_stock bigint, orders_filled bigint,
  rating_avg numeric, rating_count bigint,
  offers_delivery boolean, delivery_radius_km integer,
  opening_hours text, open_days text[], services text[]
) language sql stable security definer set search_path = public as $$
  select cp.user_id, cp.business_name, u.avatar_url, u.contact_phone,
         cp.location_name,
         cp.location_lat::double precision, cp.location_lng::double precision,
         u.created_at,
         (select count(*) from public.chemist_inventory ci
          where ci.chemist_id = cp.user_id and ci.quantity > 0),
         (select count(*) from public.orders o
          where o.chemist_id = cp.user_id and o.status = 'fulfilled'),
         coalesce(rv.avg, 0), coalesce(rv.n, 0),
         cp.offers_delivery, cp.delivery_radius_km, cp.opening_hours,
         cp.open_days, cp.services
  from public.chemist_profiles cp
  join public.users u on u.id = cp.user_id and u.status = 'active'
  left join lateral (
    select round(avg(r.rating)::numeric, 2) as avg, count(*) as n
    from public.reviews r join public.orders o on o.id = r.order_id
    where o.chemist_id = cp.user_id
  ) rv on true
  where cp.verified
  order by cp.business_name
  limit 300;
$$;

------------------------------------------------------------------
-- 6. Privileges.
------------------------------------------------------------------
revoke all on function
  public.patient_card(uuid),
  public.create_patient_share_code(),
  public.patient_card_by_code(text),
  public.patient_appointments(),
  public.chemist_public_profile(uuid),
  public.public_chemists()
from public, anon;
grant execute on function
  public.patient_card(uuid),
  public.create_patient_share_code(),
  public.patient_card_by_code(text),
  public.patient_appointments(),
  public.chemist_public_profile(uuid),
  public.public_chemists()
to authenticated;
grant select, insert, update, delete on public.mood_checkins, public.health_readings
  to authenticated;

-- Readings and mood are live on the patient's screens.
do $$
declare t text;
begin
  foreach t in array array['health_readings'] loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public'
                     and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
