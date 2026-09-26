-- Prescribing during the (mock) video call.
--
-- The doctor sends a prescription while the call is still going; the patient
-- sees it appear live on their call screen and can order the medicines from
-- a suggested chemist straight away.

------------------------------------------------------------------
-- 1. Live prescriptions: the patient's call screen listens for new rows.
--    RLS still applies to realtime, so patients only receive their own.
------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.prescriptions;
exception when duplicate_object then null;
end $$;

------------------------------------------------------------------
-- 2. issue_prescription: header + items in one transaction, so the patient
--    never sees a prescription without its medicines.
--
--    p_items: [{drug_id?, free_text_name?, dosage?, quantity?, instructions?}]
------------------------------------------------------------------
create or replace function public.issue_prescription(
  p_consultation_id uuid,
  p_items jsonb,
  p_valid_days int default 30
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_c record;
  v_id uuid;
  v_item jsonb;
  v_drug uuid;
  v_text text;
  v_doctor_name text;
begin
  select id, patient_id, doctor_id, status, ended_at into v_c
  from public.consultations
  where id = p_consultation_id;

  if v_c.id is null or v_c.doctor_id is distinct from auth.uid() then
    raise exception 'not your consultation';
  end if;

  -- During the call, or shortly after it ended (doctor finishing paperwork).
  if not (
    v_c.status in ('matched', 'in_progress')
    or (v_c.status = 'completed' and v_c.ended_at > now() - interval '12 hours')
  ) then
    raise exception 'consultation_not_active';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'prescription_empty';
  end if;
  if jsonb_array_length(p_items) > 20 then
    raise exception 'prescription_too_long';
  end if;

  insert into public.prescriptions (
    consultation_id, patient_id, doctor_id, source, valid_until
  ) values (
    v_c.id, v_c.patient_id, auth.uid(), 'app',
    current_date + greatest(1, least(coalesce(p_valid_days, 30), 90))
  ) returning id into v_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_drug := nullif(v_item ->> 'drug_id', '')::uuid;
    v_text := nullif(btrim(coalesce(v_item ->> 'free_text_name', '')), '');
    if v_drug is null and v_text is null then
      raise exception 'prescription_item_invalid';
    end if;

    insert into public.prescription_items (
      prescription_id, drug_id, free_text_name, dosage, quantity, instructions
    ) values (
      v_id,
      v_drug,
      case when v_drug is null then left(v_text, 200) end,
      left(nullif(btrim(coalesce(v_item ->> 'dosage', '')), ''), 200),
      greatest(1, least(coalesce((v_item ->> 'quantity')::int, 1), 1000)),
      left(nullif(btrim(coalesce(v_item ->> 'instructions', '')), ''), 500)
    );
  end loop;

  select nullif(name, '') into v_doctor_name
  from public.doctor_profiles where user_id = auth.uid();

  perform public.notify(
    v_c.patient_id,
    'prescription_issued',
    'Your prescription is ready',
    coalesce(v_doctor_name, 'Your doctor')
      || ' sent you a prescription. You can order the medicines now.',
    jsonb_build_object('prescription_id', v_id, 'consultation_id', v_c.id)
  );

  return v_id;
end;
$$;

revoke all on function public.issue_prescription(uuid, jsonb, int) from public, anon;
grant execute on function public.issue_prescription(uuid, jsonb, int) to authenticated;

------------------------------------------------------------------
-- 3. Stock for several medicines at once (for "order your prescription").
--    Same visibility as the existing per-drug lookup: verified chemists,
--    quantity > 0. Returned through the table API, so no function needed;
--    just make sure the lookup is indexed.
------------------------------------------------------------------
create index if not exists chemist_inventory_drug_idx
  on public.chemist_inventory (drug_id) where quantity > 0;
