-- Ideas from Zocdoc: open slots per day on doctor cards, a fuller rating
-- breakdown, "My doctors" (seen before + saved) and the Well guide
-- (preventive checks the patient keeps up to date).

------------------------------------------------------------------
-- 1. Open appointment slots per day for a list of doctors (cards show
--    "Today 3 · Tomorrow 5 · ..."). Nairobi days.
------------------------------------------------------------------
create or replace function public.doctor_slot_counts(
  p_doctors uuid[], p_days integer default 7
) returns table (doctor_id uuid, day date, slots integer)
language sql stable security definer set search_path = public as $$
  select d.id,
         (s.slot_start at time zone 'Africa/Nairobi')::date,
         count(*)::integer
  from unnest(p_doctors[1:50]) as d(id)
  cross join lateral public.doctor_open_slots(
    d.id,
    (now() at time zone 'Africa/Nairobi')::date,
    (now() at time zone 'Africa/Nairobi')::date + least(greatest(p_days, 1), 14) - 1
  ) s
  group by 1, 2;
$$;

------------------------------------------------------------------
-- 2. Reviews: optional "on time" and "bedside manner" stars for doctors,
--    and the full breakdown for profiles.
------------------------------------------------------------------
alter table public.reviews
  add column if not exists on_time smallint check (on_time between 1 and 5),
  add column if not exists manner smallint check (manner between 1 and 5);

drop function if exists public.submit_review(uuid, integer, text);
create function public.submit_review(
  p_consultation_id uuid, p_rating integer, p_comment text default null,
  p_on_time integer default null, p_manner integer default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_c public.consultations;
  v_id uuid;
begin
  select * into v_c from public.consultations where id = p_consultation_id;
  if v_c.id is null or v_c.patient_id is distinct from auth.uid() then
    raise exception 'not your consultation';
  end if;
  if v_c.status <> 'completed' then
    raise exception 'you can review a consultation only after it is completed';
  end if;
  if exists (select 1 from public.reviews where consultation_id = p_consultation_id) then
    raise exception 'already reviewed';
  end if;
  if p_rating is null or p_rating not between 1 and 5
     or (p_on_time is not null and p_on_time not between 1 and 5)
     or (p_manner is not null and p_manner not between 1 and 5) then
    raise exception 'invalid_rating';
  end if;
  insert into public.reviews
    (consultation_id, author_id, rating, comment, flagged_for_review, on_time, manner)
  values (p_consultation_id, auth.uid(), p_rating,
          nullif(left(btrim(coalesce(p_comment, '')), 500), ''), p_rating <= 2,
          p_on_time, p_manner)
  returning id into v_id;
  return v_id;
end $$;

-- Overall average, the count of each star, and the sub-scores. Works for a
-- doctor (consultation reviews) or a pharmacy (order reviews).
create or replace function public.rating_breakdown(p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  with r as (
    select rv.rating, rv.on_time, rv.manner
    from public.reviews rv
    join public.consultations c on c.id = rv.consultation_id
    where c.doctor_id = p_user
    union all
    select rv.rating, rv.on_time, rv.manner
    from public.reviews rv
    join public.orders o on o.id = rv.order_id
    where o.chemist_id = p_user
  )
  select jsonb_build_object(
    'average', coalesce(round(avg(rating)::numeric, 2), 0),
    'count', count(*),
    'on_time', round(avg(on_time)::numeric, 2),
    'manner', round(avg(manner)::numeric, 2),
    'stars', jsonb_build_object(
      '5', count(*) filter (where rating = 5),
      '4', count(*) filter (where rating = 4),
      '3', count(*) filter (where rating = 3),
      '2', count(*) filter (where rating = 2),
      '1', count(*) filter (where rating = 1)
    )
  ) from r;
$$;

------------------------------------------------------------------
-- 3. My doctors: the ones I've seen and the ones I saved.
------------------------------------------------------------------
create table if not exists public.favorite_doctors (
  patient_id uuid not null references public.users (id) on delete cascade,
  doctor_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (patient_id, doctor_id)
);
alter table public.favorite_doctors enable row level security;
drop policy if exists favorite_doctors_own on public.favorite_doctors;
create policy favorite_doctors_own on public.favorite_doctors
  for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());

create or replace function public.my_doctors()
returns table (
  user_id uuid, name text, specialties text[], consultation_fee numeric,
  languages text[], gender text, years_experience integer, avatar_url text,
  rating_avg numeric, rating_count integer, available_now boolean,
  visits bigint, last_visit timestamptz, favorite boolean
) language sql stable security definer set search_path = public as $$
  with mine as (
    select c.doctor_id, count(*) as visits,
           max(coalesce(c.scheduled_for, c.started_at, c.created_at)) as last_visit
    from public.consultations c
    where c.patient_id = auth.uid() and c.status = 'completed'
      and c.doctor_id is not null
    group by c.doctor_id
  ),
  ids as (
    select doctor_id from mine
    union
    select f.doctor_id from public.favorite_doctors f where f.patient_id = auth.uid()
  )
  select dp.user_id, dp.name, dp.specialties, dp.consultation_fee, dp.languages,
         dp.gender, dp.years_experience, dp.avatar_url, dp.rating_avg,
         dp.rating_count, (dp.status = 'available'),
         coalesce(m.visits, 0), m.last_visit,
         exists (select 1 from public.favorite_doctors f
                 where f.patient_id = auth.uid() and f.doctor_id = dp.user_id)
  from ids
  join public.doctor_profiles dp on dp.user_id = ids.doctor_id and dp.license_verified
  join public.users u on u.id = dp.user_id and u.status = 'active'
  left join mine m on m.doctor_id = dp.user_id
  order by 14 desc, m.last_visit desc nulls last, dp.name
  limit 30;
$$;

------------------------------------------------------------------
-- 4. Well guide: when the patient last had each preventive check.
------------------------------------------------------------------
create table if not exists public.preventive_checks (
  patient_id uuid not null references public.users (id) on delete cascade,
  check_key text not null check (check_key ~ '^[a-z_]{2,30}$'),
  last_done date not null check (last_done <= current_date + 1),
  updated_at timestamptz not null default now(),
  primary key (patient_id, check_key)
);
alter table public.preventive_checks enable row level security;
drop policy if exists preventive_checks_own on public.preventive_checks;
create policy preventive_checks_own on public.preventive_checks
  for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());

------------------------------------------------------------------
-- 5. Privileges.
------------------------------------------------------------------
revoke all on function
  public.doctor_slot_counts(uuid[], integer),
  public.submit_review(uuid, integer, text, integer, integer),
  public.rating_breakdown(uuid),
  public.my_doctors()
from public, anon;
grant execute on function
  public.doctor_slot_counts(uuid[], integer),
  public.submit_review(uuid, integer, text, integer, integer),
  public.rating_breakdown(uuid),
  public.my_doctors()
to authenticated;
grant select, insert, update, delete on public.favorite_doctors, public.preventive_checks
  to authenticated;
