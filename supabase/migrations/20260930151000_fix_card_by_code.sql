-- Qualify columns that clash with the function's output names.
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
       exists (select 1 from public.doctor_profiles d where d.user_id = v_me and d.license_verified)
    or exists (select 1 from public.chemist_profiles c where c.user_id = v_me and c.verified)
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
