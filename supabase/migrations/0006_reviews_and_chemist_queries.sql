-- 0006_reviews_and_chemist_queries.sql
-- Reviews, plus the phase-2 chemist<->doctor Q&A table (created now, unused until phase 2).

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  consultation_id uuid references public.consultations (id) on delete cascade,
  order_id uuid references public.orders (id) on delete cascade,
  author_id uuid not null references public.users (id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text,
  flagged_for_review boolean not null default false,
  created_at timestamptz not null default now(),
  constraint reviews_target_check check (
    consultation_id is not null or order_id is not null
  )
);

create index if not exists reviews_consultation_idx on public.reviews (consultation_id);
create index if not exists reviews_order_idx on public.reviews (order_id);

-- Keep doctor_profiles.rating_avg in sync with consultation reviews.
create or replace function public.refresh_doctor_rating()
returns trigger as $$
declare
  target_doctor uuid;
begin
  if new.consultation_id is null then
    return new;
  end if;

  select doctor_id into target_doctor
  from public.consultations
  where id = new.consultation_id;

  if target_doctor is not null then
    update public.doctor_profiles
    set rating_avg = (
      select coalesce(avg(r.rating), 0)
      from public.reviews r
      join public.consultations c on c.id = r.consultation_id
      where c.doctor_id = target_doctor
    )
    where user_id = target_doctor;
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists reviews_refresh_doctor_rating on public.reviews;
create trigger reviews_refresh_doctor_rating
  after insert on public.reviews
  for each row execute function public.refresh_doctor_rating();

-- Phase 2 (not exposed in the UI yet): async clinical Q&A between chemists and doctors.
create table if not exists public.chemist_doctor_queries (
  id uuid primary key default gen_random_uuid(),
  chemist_id uuid not null references public.users (id) on delete cascade,
  question text not null,
  answered_by_doctor_id uuid references public.users (id) on delete set null,
  answer text,
  created_at timestamptz not null default now()
);
