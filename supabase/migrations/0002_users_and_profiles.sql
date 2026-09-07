-- 0002_users_and_profiles.sql
-- Base `users` table (mirrors auth.users) plus one profile table per role.

create table if not exists public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  phone text unique,
  email text unique,
  role user_role not null,
  status user_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger users_set_updated_at
  before update on public.users
  for each row execute function set_updated_at();

-- Populate public.users automatically whenever someone signs up via Supabase Auth.
-- The role is passed through `raw_user_meta_data` at sign-up time (see auth flow).
create or replace function public.handle_new_auth_user()
returns trigger as $$
declare
  chosen_role user_role;
begin
  chosen_role := coalesce(
    (new.raw_user_meta_data ->> 'role')::user_role,
    'patient'
  );

  insert into public.users (id, phone, email, role)
  values (new.id, new.phone, new.email, chosen_role)
  on conflict (id) do nothing;

  if chosen_role = 'patient' then
    insert into public.patient_profiles (user_id, name)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''))
    on conflict (user_id) do nothing;
  elsif chosen_role = 'doctor' then
    insert into public.doctor_profiles (user_id, name)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''))
    on conflict (user_id) do nothing;
  elsif chosen_role = 'chemist' then
    insert into public.chemist_profiles (user_id, business_name)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''))
    on conflict (user_id) do nothing;
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- Trigger is created at the bottom of this file (after profile tables exist).

create table if not exists public.patient_profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  name text not null default '',
  date_of_birth date,
  location_lat double precision,
  location_lng double precision,
  allergies text,
  current_medications text,
  chronic_conditions text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger patient_profiles_set_updated_at
  before update on public.patient_profiles
  for each row execute function set_updated_at();

create table if not exists public.doctor_profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  name text not null default '',
  specialties text[] not null default '{}',
  license_number text,
  license_verified boolean not null default false,
  license_expiry date,
  verification_documents text[] not null default '{}', -- storage object paths
  status doctor_status not null default 'offline',
  rating_avg numeric(3, 2) not null default 0,
  last_available_at timestamptz, -- drives "longest idle time" matching rank
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger doctor_profiles_set_updated_at
  before update on public.doctor_profiles
  for each row execute function set_updated_at();

create table if not exists public.chemist_profiles (
  user_id uuid primary key references public.users (id) on delete cascade,
  business_name text not null default '',
  location_lat double precision,
  location_lng double precision,
  registration_number text,
  verified boolean not null default false,
  verification_documents text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger chemist_profiles_set_updated_at
  before update on public.chemist_profiles
  for each row execute function set_updated_at();

-- Now that profile tables exist, wire the signup trigger.
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- Admin-only RPC to flip verification flags (never directly writable by the
-- doctor/chemist themselves -- see RLS policies in 0007).
create or replace function public.admin_set_doctor_verified(target_user_id uuid, verified boolean)
returns void as $$
begin
  if (select role from public.users where id = auth.uid()) is distinct from 'admin' then
    raise exception 'only admins may verify doctors';
  end if;

  update public.doctor_profiles
  set license_verified = verified
  where user_id = target_user_id;
end;
$$ language plpgsql security definer set search_path = public;

create or replace function public.admin_set_chemist_verified(target_user_id uuid, verified boolean)
returns void as $$
begin
  if (select role from public.users where id = auth.uid()) is distinct from 'admin' then
    raise exception 'only admins may verify chemists';
  end if;

  update public.chemist_profiles
  set verified = verified
  where user_id = target_user_id;
end;
$$ language plpgsql security definer set search_path = public;
