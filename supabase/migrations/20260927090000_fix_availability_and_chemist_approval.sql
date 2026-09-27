-- Two bugs found in use:
--
-- 1. Doctors could not go online: the CASE in set_doctor_availability()
--    produced text, and text can't be assigned to the doctor_status enum
--    ("column status is of type doctor_status but expression is of type
--    text").
-- 2. Approving a chemist failed with 'column reference "verified" is
--    ambiguous': the function's parameter has the same name as the column.
--    (Parameter names can't change without breaking callers, so the body
--    uses $2.)

create or replace function public.set_doctor_availability(p_available boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_verified boolean;
begin
  select license_verified into v_verified
  from public.doctor_profiles where user_id = auth.uid();

  if v_verified is not true and p_available then
    raise exception 'doctor is not yet verified';
  end if;

  update public.doctor_profiles
  set status = (case when p_available then 'available' else 'offline' end)::public.doctor_status,
      last_available_at = case when p_available then now() else last_available_at end
  where user_id = auth.uid();
end;
$$;

create or replace function public.admin_set_chemist_verified(target_user_id uuid, verified boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select role from public.users where id = auth.uid()) is distinct from 'admin' then
    raise exception 'only admins may verify chemists';
  end if;

  update public.chemist_profiles as cp
  set verified = $2
  where cp.user_id = $1;
end;
$$;
