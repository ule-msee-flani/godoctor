-- 0011_doctor_directory_and_scheduling.sql
-- Certified-doctor directory, scheduled appointments, verified-only reviews,
-- in-app notifications, and the security hardening those features depend on.
-- Requires 0010 (enum values + btree_gist).

------------------------------------------------------------------
-- 1. Doctor public-profile fields (shown in the directory)
------------------------------------------------------------------
alter table public.doctor_profiles
  add column if not exists bio text,
  add column if not exists consultation_fee numeric(10, 2)
    check (consultation_fee is null or consultation_fee >= 0),
  add column if not exists languages text[] not null default '{}',
  add column if not exists gender text check (gender in ('female', 'male', 'other')),
  add column if not exists years_experience integer
    check (years_experience is null or years_experience between 0 and 70),
  add column if not exists avatar_url text,
  add column if not exists rating_count integer not null default 0;

------------------------------------------------------------------
-- 2. Clients may only edit the profile fields that are theirs to edit.
--    Previously a doctor could UPDATE their own rating_avg/status directly.
--    (Verification and availability go through SECURITY DEFINER functions.)
------------------------------------------------------------------
revoke update on public.doctor_profiles from authenticated, anon;
grant update (
  name, specialties, license_number, license_expiry, verification_documents,
  bio, consultation_fee, languages, gender, years_experience, avatar_url
) on public.doctor_profiles to authenticated;

------------------------------------------------------------------
-- 3. Stop publishing every doctor row (incl. license numbers and unverified
--    doctors) to anyone holding the public anon key. The directory reads
--    through search_doctors()/get_public_doctor(), which expose only safe
--    columns for license-verified doctors.
------------------------------------------------------------------
drop policy if exists doctor_profiles_public_read on public.doctor_profiles;

create policy doctor_profiles_select on public.doctor_profiles
  for select using (
    user_id = auth.uid()
    or public.current_role_is('admin')
    or exists (
      select 1 from public.consultations c
      where c.doctor_id = doctor_profiles.user_id
        and c.patient_id = auth.uid()
    )
  );

------------------------------------------------------------------
-- 4. Weekly availability + time off
------------------------------------------------------------------
create table if not exists public.doctor_availability (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.users (id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 7), -- ISO: 1=Mon .. 7=Sun
  start_time time not null,
  end_time time not null,
  slot_minutes smallint not null default 30 check (slot_minutes in (15, 20, 30, 45, 60)),
  created_at timestamptz not null default now(),
  check (end_time > start_time)
);
create index if not exists doctor_availability_doctor_idx
  on public.doctor_availability (doctor_id, weekday);

create table if not exists public.doctor_time_off (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.users (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index if not exists doctor_time_off_doctor_idx
  on public.doctor_time_off (doctor_id, starts_at);

alter table public.doctor_availability enable row level security;
alter table public.doctor_time_off enable row level security;

create policy doctor_availability_owner_all on public.doctor_availability
  for all using (doctor_id = auth.uid()) with check (doctor_id = auth.uid());
create policy doctor_availability_admin_read on public.doctor_availability
  for select using (public.current_role_is('admin'));

create policy doctor_time_off_owner_all on public.doctor_time_off
  for all using (doctor_id = auth.uid()) with check (doctor_id = auth.uid());

------------------------------------------------------------------
-- 5. Scheduled appointments live on `consultations`
------------------------------------------------------------------
alter table public.consultations
  add column if not exists mode consultation_mode not null default 'on_demand',
  add column if not exists scheduled_for timestamptz,
  add column if not exists scheduled_end timestamptz,
  add column if not exists fee_amount numeric(10, 2),
  add column if not exists reminder_24h_sent boolean not null default false,
  add column if not exists reminder_1h_sent boolean not null default false;

do $$ begin
  alter table public.consultations add constraint consultations_scheduled_check
    check (
      mode = 'on_demand'
      or (scheduled_for is not null and scheduled_end is not null
          and scheduled_end > scheduled_for and doctor_id is not null)
    );
exception when duplicate_object then null; end $$;

-- A doctor can never hold two live appointments that overlap in time.
do $$ begin
  alter table public.consultations add constraint consultations_no_double_booking
    exclude using gist (
      doctor_id with =,
      tstzrange(scheduled_for, scheduled_end, '[)') with &&
    ) where (mode = 'scheduled' and status in ('scheduled', 'in_progress'));
exception when duplicate_object then null; end $$;

create index if not exists consultations_scheduled_idx
  on public.consultations (doctor_id, scheduled_for) where mode = 'scheduled';
create index if not exists consultations_patient_idx
  on public.consultations (patient_id, created_at desc);

-- Consultation state is only ever changed by the SECURITY DEFINER functions
-- (request_consultation, book_appointment, respond_to_offer, ...). Clients
-- used to be able to write these rows directly (e.g. mark their own
-- consultation "completed"), which would let anyone forge a "verified"
-- review. Reads are unchanged.
drop policy if exists consultations_patient_all on public.consultations;
drop policy if exists consultations_doctor_update on public.consultations;
create policy consultations_patient_select on public.consultations
  for select using (patient_id = auth.uid());
revoke insert, update, delete on public.consultations from authenticated, anon;

------------------------------------------------------------------
-- 6. In-app notifications (delivery by push/SMS plugs in later by reading
--    this table). Only the server writes rows; users read and mark read.
------------------------------------------------------------------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;
create policy notifications_owner_select on public.notifications
  for select using (user_id = auth.uid());
create policy notifications_owner_update on public.notifications
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
revoke insert, update, delete on public.notifications from authenticated, anon;
grant update (read_at) on public.notifications to authenticated;

do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; end $$;

create or replace function public.notify(
  p_user uuid, p_kind text, p_title text, p_body text, p_data jsonb default '{}'::jsonb
) returns void as $$
  insert into public.notifications (user_id, kind, title, body, data)
  values (p_user, p_kind, p_title, p_body, coalesce(p_data, '{}'::jsonb));
$$ language sql security definer set search_path = public;
revoke all on function public.notify(uuid, text, text, text, jsonb) from public, anon, authenticated;

------------------------------------------------------------------
-- 7. Open slots (weekly windows in Africa/Nairobi, minus booked + time off)
------------------------------------------------------------------
create or replace function public.doctor_open_slots(
  p_doctor_id uuid, p_from date, p_to date
) returns table (slot_start timestamptz, slot_end timestamptz)
language sql stable security definer set search_path = public as $$
  with days as (
    select d::date as day
    from generate_series(
      p_from::timestamp, least(p_to, p_from + 30)::timestamp, interval '1 day'
    ) d
  ),
  raw as (
    select
      ((days.day + a.start_time + (n * a.slot_minutes) * interval '1 minute')
        at time zone 'Africa/Nairobi') as s,
      a.slot_minutes
    from days
    join public.doctor_availability a
      on a.doctor_id = p_doctor_id
     and a.weekday = extract(isodow from days.day)::int
    cross join lateral generate_series(
      0, ((extract(epoch from (a.end_time - a.start_time)) / 60)::int / a.slot_minutes) - 1
    ) n
  )
  select distinct r.s, r.s + r.slot_minutes * interval '1 minute'
  from raw r
  where exists (
      select 1
      from public.doctor_profiles dp
      join public.users u on u.id = dp.user_id
      where dp.user_id = p_doctor_id and dp.license_verified and u.status = 'active'
    )
    and r.s >= now() + interval '30 minutes'
    and not exists (
      select 1 from public.consultations c
      where c.doctor_id = p_doctor_id
        and c.mode = 'scheduled'
        and c.status in ('scheduled', 'in_progress')
        and tstzrange(c.scheduled_for, c.scheduled_end, '[)')
            && tstzrange(r.s, r.s + r.slot_minutes * interval '1 minute', '[)')
    )
    and not exists (
      select 1 from public.doctor_time_off t
      where t.doctor_id = p_doctor_id
        and tstzrange(t.starts_at, t.ends_at, '[)')
            && tstzrange(r.s, r.s + r.slot_minutes * interval '1 minute', '[)')
    )
  order by 1;
$$;

------------------------------------------------------------------
-- 8. Booking, cancelling, rescheduling, starting
------------------------------------------------------------------
create or replace function public.book_appointment(
  p_doctor_id uuid,
  p_start timestamptz,
  p_specialty text,
  p_reason text,
  p_flagged_emergency boolean default false
) returns uuid as $$
declare
  v_slot_end timestamptz;
  v_fee numeric;
  v_specialty text;
  v_id uuid;
  v_day date := (p_start at time zone 'Africa/Nairobi')::date;
  v_patient_name text;
begin
  if (select role from public.users where id = auth.uid()) is distinct from 'patient' then
    raise exception 'only patients can book appointments';
  end if;

  select consultation_fee, coalesce(nullif(p_specialty, ''), specialties[1], 'General Practice')
  into v_fee, v_specialty
  from public.doctor_profiles where user_id = p_doctor_id;

  -- Emergency hard-stop path: recorded for audit only, never booked.
  if p_flagged_emergency then
    insert into public.consultations
      (patient_id, doctor_id, specialty_requested, symptom_summary, status, mode,
       scheduled_for, scheduled_end)
    values
      (auth.uid(), p_doctor_id, coalesce(v_specialty, 'General Practice'), p_reason,
       'cancelled', 'scheduled', p_start, p_start + interval '30 minutes')
    returning id into v_id;
    insert into public.intake_forms (consultation_id, symptoms, flagged_emergency)
    values (v_id, p_reason, true);
    return v_id;
  end if;

  select s.slot_end into v_slot_end
  from public.doctor_open_slots(p_doctor_id, v_day, v_day) s
  where s.slot_start = p_start;
  if v_slot_end is null then
    raise exception 'slot_unavailable';
  end if;

  if (select count(*) from public.consultations
      where patient_id = auth.uid() and status = 'scheduled'
        and scheduled_for > now()) >= 10 then
    raise exception 'too_many_upcoming_appointments';
  end if;

  begin
    insert into public.consultations
      (patient_id, doctor_id, specialty_requested, symptom_summary, status, mode,
       scheduled_for, scheduled_end, fee_amount)
    values
      (auth.uid(), p_doctor_id, v_specialty, coalesce(p_reason, ''), 'scheduled', 'scheduled',
       p_start, v_slot_end, v_fee)
    returning id into v_id;
  exception when exclusion_violation then
    raise exception 'slot_unavailable';
  end;

  insert into public.intake_forms (consultation_id, symptoms, flagged_emergency)
  values (v_id, coalesce(p_reason, ''), false);

  select name into v_patient_name from public.patient_profiles where user_id = auth.uid();
  perform public.notify(
    p_doctor_id, 'appointment_booked', 'New appointment',
    coalesce(nullif(v_patient_name, ''), 'A patient') || ' booked '
      || to_char(p_start at time zone 'Africa/Nairobi', 'Dy DD Mon, HH24:MI'),
    jsonb_build_object('consultation_id', v_id)
  );
  perform public.notify(
    auth.uid(), 'appointment_booked', 'Appointment confirmed',
    'Your appointment is on '
      || to_char(p_start at time zone 'Africa/Nairobi', 'Dy DD Mon, HH24:MI') || ' (EAT).',
    jsonb_build_object('consultation_id', v_id)
  );
  return v_id;
end;
$$ language plpgsql security definer set search_path = public;

create or replace function public.cancel_appointment(p_id uuid) returns void as $$
declare
  v_c public.consultations;
begin
  update public.consultations
  set status = 'cancelled'
  where id = p_id and mode = 'scheduled' and status = 'scheduled'
    and scheduled_for > now()
    and (patient_id = auth.uid() or doctor_id = auth.uid())
  returning * into v_c;

  if v_c.id is null then
    raise exception 'appointment cannot be cancelled';
  end if;

  perform public.notify(
    case when auth.uid() = v_c.patient_id then v_c.doctor_id else v_c.patient_id end,
    'appointment_cancelled', 'Appointment cancelled',
    'The appointment on '
      || to_char(v_c.scheduled_for at time zone 'Africa/Nairobi', 'Dy DD Mon, HH24:MI')
      || ' was cancelled.',
    jsonb_build_object('consultation_id', v_c.id)
  );
end;
$$ language plpgsql security definer set search_path = public;

create or replace function public.reschedule_appointment(
  p_id uuid, p_new_start timestamptz
) returns void as $$
declare
  v_c public.consultations;
  v_slot_end timestamptz;
  v_day date := (p_new_start at time zone 'Africa/Nairobi')::date;
begin
  select * into v_c from public.consultations
  where id = p_id and patient_id = auth.uid() and mode = 'scheduled'
    and status = 'scheduled' and scheduled_for > now();
  if v_c.id is null then
    raise exception 'appointment cannot be rescheduled';
  end if;

  select s.slot_end into v_slot_end
  from public.doctor_open_slots(v_c.doctor_id, v_day, v_day) s
  where s.slot_start = p_new_start;
  if v_slot_end is null then
    raise exception 'slot_unavailable';
  end if;

  begin
    update public.consultations
    set scheduled_for = p_new_start, scheduled_end = v_slot_end,
        reminder_24h_sent = false, reminder_1h_sent = false
    where id = p_id;
  exception when exclusion_violation then
    raise exception 'slot_unavailable';
  end;

  perform public.notify(
    v_c.doctor_id, 'appointment_rescheduled', 'Appointment rescheduled',
    'Moved to ' || to_char(p_new_start at time zone 'Africa/Nairobi', 'Dy DD Mon, HH24:MI') || ' (EAT).',
    jsonb_build_object('consultation_id', p_id)
  );
end;
$$ language plpgsql security definer set search_path = public;

-- Either party can open the session from 10 minutes before the start.
create or replace function public.start_appointment(p_id uuid) returns void as $$
begin
  update public.consultations
  set status = 'in_progress', started_at = coalesce(started_at, now())
  where id = p_id and mode = 'scheduled' and status in ('scheduled', 'in_progress')
    and (patient_id = auth.uid() or doctor_id = auth.uid())
    and now() >= scheduled_for - interval '10 minutes'
    and now() <= scheduled_end + interval '30 minutes';
  if not found then
    raise exception 'appointment cannot be started yet';
  end if;
end;
$$ language plpgsql security definer set search_path = public;

------------------------------------------------------------------
-- 9. Doctor directory (safe columns only, license-verified doctors only)
------------------------------------------------------------------
create or replace function public.search_doctors(
  p_query text default null,
  p_specialty text default null,
  p_max_fee numeric default null,
  p_language text default null,
  p_gender text default null,
  p_available_now boolean default false,
  p_limit integer default 20,
  p_offset integer default 0
) returns table (
  user_id uuid, name text, specialties text[], bio text, consultation_fee numeric,
  languages text[], gender text, years_experience integer, avatar_url text,
  rating_avg numeric, rating_count integer, available_now boolean, next_slot timestamptz
) language sql stable security definer set search_path = public as $$
  select dp.user_id, dp.name, dp.specialties, dp.bio, dp.consultation_fee,
         dp.languages, dp.gender, dp.years_experience, dp.avatar_url,
         dp.rating_avg, dp.rating_count, (dp.status = 'available') as available_now,
         ns.next_slot
  from public.doctor_profiles dp
  join public.users u on u.id = dp.user_id and u.status = 'active'
  left join lateral (
    select min(s.slot_start) as next_slot
    from public.doctor_open_slots(
      dp.user_id,
      (now() at time zone 'Africa/Nairobi')::date,
      (now() at time zone 'Africa/Nairobi')::date + 14
    ) s
  ) ns on true
  where dp.license_verified
    and (coalesce(p_query, '') = ''
         or dp.name ilike '%' || p_query || '%'
         or exists (select 1 from unnest(dp.specialties) sp where sp ilike '%' || p_query || '%'))
    and (p_specialty is null or p_specialty = any (dp.specialties))
    and (p_max_fee is null or (dp.consultation_fee is not null and dp.consultation_fee <= p_max_fee))
    and (p_language is null or p_language = any (dp.languages))
    and (p_gender is null or dp.gender = p_gender)
    and (not p_available_now or dp.status = 'available')
  order by (dp.status = 'available') desc, dp.rating_avg desc, ns.next_slot asc nulls last, dp.name
  limit least(greatest(p_limit, 1), 50) offset greatest(p_offset, 0);
$$;

create or replace function public.get_public_doctor(p_id uuid)
returns table (
  user_id uuid, name text, specialties text[], bio text, consultation_fee numeric,
  languages text[], gender text, years_experience integer, avatar_url text,
  rating_avg numeric, rating_count integer, available_now boolean, next_slot timestamptz
) language sql stable security definer set search_path = public as $$
  select dp.user_id, dp.name, dp.specialties, dp.bio, dp.consultation_fee,
         dp.languages, dp.gender, dp.years_experience, dp.avatar_url,
         dp.rating_avg, dp.rating_count, (dp.status = 'available') as available_now,
         ns.next_slot
  from public.doctor_profiles dp
  join public.users u on u.id = dp.user_id and u.status = 'active'
  left join lateral (
    select min(s.slot_start) as next_slot
    from public.doctor_open_slots(
      dp.user_id,
      (now() at time zone 'Africa/Nairobi')::date,
      (now() at time zone 'Africa/Nairobi')::date + 14
    ) s
  ) ns on true
  where dp.user_id = p_id and dp.license_verified;
$$;

------------------------------------------------------------------
-- 10. Verified-only reviews
------------------------------------------------------------------
create unique index if not exists reviews_one_per_consultation
  on public.reviews (consultation_id) where consultation_id is not null;

drop policy if exists reviews_author_all on public.reviews;
drop policy if exists reviews_public_read on public.reviews;
create policy reviews_select on public.reviews
  for select using (
    author_id = auth.uid()
    or public.current_role_is('admin')
    or exists (select 1 from public.consultations c
               where c.id = reviews.consultation_id and c.doctor_id = auth.uid())
    or exists (select 1 from public.orders o
               where o.id = reviews.order_id and o.chemist_id = auth.uid())
  );
-- Reviews are created only through submit_review() so the "completed
-- consultation, by its patient, once" rule can't be bypassed.
revoke insert, update, delete on public.reviews from authenticated, anon;

create or replace function public.submit_review(
  p_consultation_id uuid, p_rating integer, p_comment text default null
) returns uuid as $$
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

  insert into public.reviews (consultation_id, author_id, rating, comment, flagged_for_review)
  values (p_consultation_id, auth.uid(), p_rating, nullif(trim(p_comment), ''), p_rating <= 2)
  returning id into v_id;
  return v_id;
end;
$$ language plpgsql security definer set search_path = public;

-- Public list of a doctor's reviews. No author identity is exposed.
create or replace function public.doctor_reviews(
  p_doctor_id uuid, p_limit integer default 20, p_offset integer default 0
) returns table (id uuid, rating integer, comment text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.rating, r.comment, r.created_at
  from public.reviews r
  join public.consultations c on c.id = r.consultation_id
  where c.doctor_id = p_doctor_id
  order by r.created_at desc
  limit least(greatest(p_limit, 1), 50) offset greatest(p_offset, 0);
$$;

-- Keep the rating summary in sync (now including the count).
create or replace function public.refresh_doctor_rating()
returns trigger as $$
declare
  target_doctor uuid;
begin
  if new.consultation_id is null then
    return new;
  end if;
  select doctor_id into target_doctor from public.consultations where id = new.consultation_id;
  if target_doctor is not null then
    update public.doctor_profiles
    set rating_avg = (
          select coalesce(round(avg(r.rating)::numeric, 2), 0)
          from public.reviews r join public.consultations c on c.id = r.consultation_id
          where c.doctor_id = target_doctor),
        rating_count = (
          select count(*) from public.reviews r join public.consultations c on c.id = r.consultation_id
          where c.doctor_id = target_doctor)
    where user_id = target_doctor;
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

------------------------------------------------------------------
-- 11. Doctor avatars (public read; each doctor writes only their own folder)
------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy avatars_owner_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

------------------------------------------------------------------
-- 12. Function privileges: signed-in users only, never anon
------------------------------------------------------------------
revoke all on function
  public.doctor_open_slots(uuid, date, date),
  public.book_appointment(uuid, timestamptz, text, text, boolean),
  public.cancel_appointment(uuid),
  public.reschedule_appointment(uuid, timestamptz),
  public.start_appointment(uuid),
  public.search_doctors(text, text, numeric, text, text, boolean, integer, integer),
  public.get_public_doctor(uuid),
  public.submit_review(uuid, integer, text),
  public.doctor_reviews(uuid, integer, integer)
from public, anon;
grant execute on function
  public.doctor_open_slots(uuid, date, date),
  public.book_appointment(uuid, timestamptz, text, text, boolean),
  public.cancel_appointment(uuid),
  public.reschedule_appointment(uuid, timestamptz),
  public.start_appointment(uuid),
  public.search_doctors(text, text, numeric, text, text, boolean, integer, integer),
  public.get_public_doctor(uuid),
  public.submit_review(uuid, integer, text),
  public.doctor_reviews(uuid, integer, integer)
to authenticated;
