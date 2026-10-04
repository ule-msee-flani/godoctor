-- Security fix: sign-up used to take the account type from whatever the app
-- sent, so anyone with the public app key could create an account as
-- "admin". Now sign-up can only make patients, doctors and pharmacies;
-- anything else becomes a patient. Admin and staff accounts are made only
-- from GoDoctor HQ (the company console), by the erp-staff function.
--
-- Also adds the "staff" account type for company staff (their role inside
-- HQ -- operations, finance, support... -- lives in public.erp_staff).

alter type user_role add value if not exists 'staff';

create or replace function public.handle_new_auth_user()
returns trigger as $$
declare
  requested text := new.raw_user_meta_data ->> 'role';
  chosen_role user_role;
begin
  chosen_role := case
    when requested in ('patient', 'doctor', 'chemist') then requested::user_role
    else 'patient'
  end;

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
