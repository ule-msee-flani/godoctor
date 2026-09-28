-- Descriptive public profiles, so patients can see exactly who they're
-- dealing with: a doctor's track record, and a pharmacy's page (photo,
-- area, how many orders it has filled, what it stocks). Only for verified
-- doctors and chemists, and only safe columns.

-- Doctor: consultations completed and patients seen (the rest comes from
-- get_public_doctor).
create or replace function public.doctor_public_stats(p_doctor uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'consultations', (select count(*) from public.consultations
                      where doctor_id = p_doctor and status = 'completed'),
    'patients', (select count(distinct patient_id) from public.consultations
                 where doctor_id = p_doctor and status = 'completed'),
    'member_since', (select created_at from public.users where id = p_doctor)
  )
  where exists (select 1 from public.doctor_profiles
                where user_id = p_doctor and license_verified);
$$;

-- Pharmacy page.
create or replace function public.chemist_public_profile(p_chemist uuid)
returns table (
  user_id uuid, business_name text, avatar_url text, contact_phone text,
  location_name text, location_lat double precision,
  location_lng double precision, member_since timestamptz,
  medicines_in_stock bigint, orders_filled bigint
) language sql stable security definer set search_path = public as $$
  select cp.user_id, cp.business_name, u.avatar_url, u.contact_phone,
         cp.location_name,
         cp.location_lat::double precision, cp.location_lng::double precision,
         u.created_at,
         (select count(*) from public.chemist_inventory ci
          where ci.chemist_id = cp.user_id and ci.quantity > 0),
         (select count(*) from public.orders o
          where o.chemist_id = cp.user_id and o.status = 'fulfilled')
  from public.chemist_profiles cp
  join public.users u on u.id = cp.user_id and u.status = 'active'
  where cp.user_id = p_chemist and cp.verified;
$$;

revoke all on function public.doctor_public_stats(uuid), public.chemist_public_profile(uuid)
  from public, anon;
grant execute on function public.doctor_public_stats(uuid), public.chemist_public_profile(uuid)
  to authenticated;
