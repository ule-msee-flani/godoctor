-- 1. More things update live in the app (stock, reminders, reviews, family,
--    doctor status, payments), not only after a refresh.
-- 2. Ordering medicine happens in one server-side step with the chemist's
--    real prices and stock (reserved at once); patients and chemists can
--    only move an order along the proper steps.
-- 3. Visit history with the doctor's name and photo, prescriptions and
--    summary at a glance.
-- 4. A directory of verified pharmacies.
-- 5. Chemists can bring in their existing stock: a file import, or their
--    pharmacy system (ERP) pushing stock with an API key.

------------------------------------------------------------------
-- 1. Realtime
------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['chemist_inventory', 'medication_schedules', 'dose_logs',
                           'reviews', 'family_links', 'doctor_profiles', 'payments',
                           'order_items']
  loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public'
                     and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

------------------------------------------------------------------
-- 2. Orders
------------------------------------------------------------------
alter table public.orders add column if not exists problem_note text
  check (problem_note is null or length(problem_note) <= 1000);

create or replace function public.place_order(
  p_chemist uuid,
  p_prescription uuid,
  p_fulfillment text,
  p_lines jsonb
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_patient uuid := auth.uid();
  v_order uuid;
  v_total numeric(10, 2) := 0;
  v_rx record;
  v_line record;
  v_stock record;
begin
  if v_patient is null or not public.current_role_is('patient') then
    raise exception 'patients_only';
  end if;
  if p_fulfillment not in ('pickup', 'delivery') then
    raise exception 'invalid_fulfillment';
  end if;
  if not exists (select 1 from public.chemist_profiles cp
                 join public.users u on u.id = cp.user_id and u.status = 'active'
                 where cp.user_id = p_chemist and cp.verified) then
    raise exception 'chemist_unavailable';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
     or jsonb_array_length(p_lines) = 0 then
    raise exception 'order_empty';
  end if;
  if jsonb_array_length(p_lines) > 30 then
    raise exception 'order_too_long';
  end if;

  if p_prescription is not null then
    select * into v_rx from public.prescriptions
    where id = p_prescription and patient_id = v_patient;
    if not found then raise exception 'prescription_not_found'; end if;
    if v_rx.valid_until is not null and v_rx.valid_until < current_date then
      raise exception 'prescription_expired';
    end if;
  end if;

  create temp table if not exists _order_lines (
    drug_id uuid primary key, qty integer, price numeric(10, 2)
  ) on commit drop;
  delete from _order_lines;

  -- Check every line against the chemist's current stock and price (rows
  -- locked, so two patients can't buy the last pack twice).
  for v_line in
    select (l->>'drug_id')::uuid as drug_id, sum((l->>'quantity')::int) as qty
    from jsonb_array_elements(p_lines) l
    group by 1
  loop
    if v_line.drug_id is null or v_line.qty is null
       or v_line.qty < 1 or v_line.qty > 100 then
      raise exception 'invalid_quantity';
    end if;
    select ci.quantity, ci.price, d.generic_name, d.requires_prescription
      into v_stock
      from public.chemist_inventory ci
      join public.drugs d on d.id = ci.drug_id
      where ci.chemist_id = p_chemist and ci.drug_id = v_line.drug_id
      for update of ci;
    if not found then
      raise exception 'out_of_stock: this medicine';
    end if;
    if v_stock.quantity < v_line.qty then
      raise exception 'out_of_stock: %', v_stock.generic_name;
    end if;
    if v_stock.requires_prescription then
      if p_prescription is null then
        raise exception 'prescription_required: %', v_stock.generic_name;
      end if;
      if v_rx.source = 'app' and not exists (
        select 1 from public.prescription_items pi
        where pi.prescription_id = p_prescription and pi.drug_id = v_line.drug_id
      ) then
        raise exception 'prescription_mismatch: %', v_stock.generic_name;
      end if;
    end if;
    insert into _order_lines values (v_line.drug_id, v_line.qty, v_stock.price);
    v_total := v_total + v_stock.price * v_line.qty;
  end loop;

  insert into public.orders (patient_id, chemist_id, prescription_id,
                             total_amount, escrow_status, fulfillment_type)
  values (v_patient, p_chemist, p_prescription, v_total, 'held',
          p_fulfillment::public.fulfillment_type)
  returning id into v_order;

  insert into public.order_items (order_id, drug_id, quantity, unit_price)
  select v_order, drug_id, qty, price from _order_lines;

  -- Reserve the stock straight away (given back if the order is refunded).
  update public.chemist_inventory ci
  set quantity = ci.quantity - l.qty
  from _order_lines l
  where ci.chemist_id = p_chemist and ci.drug_id = l.drug_id;

  -- Test mode: M-Pesa is simulated until Daraja is connected.
  insert into public.payments (order_id, amount, provider, status, is_simulated)
  values (v_order, v_total, 'mpesa', 'succeeded', true);

  return v_order;
end $$;

-- Patient: "I've received it" releases the money to the chemist.
create or replace function public.confirm_order_received(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.orders
  set status = 'fulfilled', escrow_status = 'released', fulfilled_at = now()
  where id = p_order and patient_id = auth.uid()
    and status in ('confirmed', 'ready');
  if not found then raise exception 'order_not_ready'; end if;
  update public.payments set escrow_release_at = now() where order_id = p_order;
end $$;

-- Patient: "Report a problem" (with what went wrong).
create or replace function public.dispute_order(p_order uuid, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.orders
  set status = 'disputed', problem_note = nullif(left(trim(coalesce(p_note, '')), 1000), '')
  where id = p_order and patient_id = auth.uid()
    and status in ('placed', 'confirmed', 'ready');
  if not found then raise exception 'order_cannot_be_disputed'; end if;
end $$;

-- Chemist: accept, then mark ready, in that order only.
create or replace function public.chemist_advance_order(p_order uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_status = 'confirmed' then
    update public.orders set status = 'confirmed', confirmed_at = now()
    where id = p_order and chemist_id = auth.uid() and status = 'placed';
  elsif p_status = 'ready' then
    update public.orders set status = 'ready', ready_at = now()
    where id = p_order and chemist_id = auth.uid() and status = 'confirmed';
  else
    raise exception 'invalid_status';
  end if;
  if not found then raise exception 'order_status_changed'; end if;
end $$;

-- A refunded order's stock goes back on the shelf.
create or replace function public.orders_restock() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'refunded' and old.status is distinct from 'refunded' then
    update public.chemist_inventory ci
    set quantity = ci.quantity + oi.quantity
    from public.order_items oi
    where oi.order_id = new.id and ci.chemist_id = new.chemist_id
      and ci.drug_id = oi.drug_id;
  end if;
  return new;
end $$;

drop trigger if exists orders_restock on public.orders;
create trigger orders_restock
  after update of status on public.orders
  for each row execute function public.orders_restock();

-- Disputes tell the admins what went wrong.
create or replace function public.order_dispute_note_notify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'disputed' and old.status is distinct from 'disputed'
     and new.problem_note is not null then
    perform public.notify_admins('order_disputed', 'What went wrong',
      'Order ' || upper(left(new.id::text, 8)) || ': ' || left(new.problem_note, 200),
      jsonb_build_object('order_id', new.id));
  end if;
  return new;
end $$;

drop trigger if exists orders_dispute_note on public.orders;
create trigger orders_dispute_note
  after update of status on public.orders
  for each row execute function public.order_dispute_note_notify();

-- Orders change only through the functions above.
drop policy if exists orders_patient_all on public.orders;
drop policy if exists orders_patient_read on public.orders;
create policy orders_patient_read on public.orders
  for select using (patient_id = auth.uid());
drop policy if exists orders_chemist_update on public.orders;
drop policy if exists order_items_patient_insert on public.order_items;
drop policy if exists payments_patient_insert on public.payments;

------------------------------------------------------------------
-- 3. Visit history
------------------------------------------------------------------
create or replace function public.patient_visits()
returns table (
  consultation_id uuid, doctor_id uuid, doctor_name text, doctor_avatar text,
  specialty text, symptoms text, status text, mode text, happened_at timestamptz,
  prescriptions bigint, has_summary boolean, chat_closes_at timestamptz,
  my_rating integer
) language sql stable security definer set search_path = public as $$
  select c.id, c.doctor_id, dp.name, dp.avatar_url, c.specialty_requested,
         c.symptom_summary, c.status::text, c.mode::text,
         coalesce(c.scheduled_for, c.started_at, c.created_at),
         (select count(*) from public.prescriptions p where p.consultation_id = c.id),
         (coalesce(c.summary_for_patient, '') <> '' or coalesce(c.red_flags, '') <> ''),
         c.chat_closes_at,
         (select r.rating from public.reviews r
          where r.consultation_id = c.id and r.author_id = auth.uid() limit 1)
  from public.consultations c
  left join public.doctor_profiles dp on dp.user_id = c.doctor_id
  where c.patient_id = auth.uid()
    and c.status not in ('cancelled', 'unmatched')
  order by coalesce(c.scheduled_for, c.started_at, c.created_at) desc
  limit 300;
$$;

------------------------------------------------------------------
-- 4. Pharmacy directory
------------------------------------------------------------------
create or replace function public.public_chemists()
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
  where cp.verified
  order by cp.business_name
  limit 300;
$$;

------------------------------------------------------------------
-- 5. Bringing in existing stock
------------------------------------------------------------------
-- The catalogue medicine a name from a pharmacy system most likely means:
-- exact generic or brand name, then "starts with", then closest spelling.
create or replace function public.match_drug(p_name text)
returns uuid language sql stable security definer
set search_path = public, extensions as $$
  with n as (select lower(trim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'))) as q)
  select id from (
    select d.id, 1 as rank, 0::real as dist from public.drugs d, n
      where lower(d.generic_name) = n.q
    union all
    select d.id, 2, 0 from public.drugs d, n
      where exists (select 1 from unnest(d.brand_names) b where lower(b) = n.q)
    union all
    select d.id, 3, length(d.generic_name) from public.drugs d, n
      where length(n.q) >= 4 and lower(d.generic_name) like n.q || '%'
    union all
    select d.id, 4, 1 - similarity(lower(d.generic_name), n.q) from public.drugs d, n
      where length(n.q) >= 4 and similarity(lower(d.generic_name), n.q) > 0.45
  ) m
  order by rank, dist
  limit 1;
$$;

-- Preview for an import: each name with the medicine it matched (if any).
create or replace function public.match_drugs(p_names text[])
returns table (name text, drug_id uuid, drug_name text)
language sql stable security definer set search_path = public as $$
  select n, m.id, d.generic_name
  from unnest(p_names) n
  left join lateral (select public.match_drug(n) as id) m on true
  left join public.drugs d on d.id = m.id;
$$;

-- Save imported stock (the chemist's own rows only).
create or replace function public.import_inventory(p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_chemist uuid := auth.uid();
  v_count integer;
begin
  if v_chemist is null or not public.current_role_is('chemist') then
    raise exception 'chemists_only';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) > 2000 then
    raise exception 'import_too_large';
  end if;
  with rows as (
    select distinct on ((r->>'drug_id')::uuid)
           (r->>'drug_id')::uuid as drug_id,
           greatest(0, least(100000, (r->>'quantity')::numeric))::int as quantity,
           greatest(0, least(1000000, (r->>'price')::numeric))::numeric(10, 2) as price
    from jsonb_array_elements(p_rows) r
    where (r->>'drug_id') is not null
      and exists (select 1 from public.drugs d where d.id = (r->>'drug_id')::uuid)
  )
  insert into public.chemist_inventory (chemist_id, drug_id, quantity, price)
  select v_chemist, drug_id, quantity, price from rows
  on conflict (chemist_id, drug_id)
  do update set quantity = excluded.quantity, price = excluded.price;
  get diagnostics v_count = row_count;
  return jsonb_build_object('saved', v_count);
end $$;

-- API keys for a pharmacy's own system to push stock (see the
-- inventory-sync edge function). Only a hash is stored; the key is shown
-- once when created.
create table if not exists public.chemist_api_keys (
  id uuid primary key default gen_random_uuid(),
  chemist_id uuid not null references public.users (id) on delete cascade,
  label text not null default 'Pharmacy system' check (length(label) <= 60),
  key_prefix text not null,
  key_hash text not null unique,
  created_at timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at timestamptz
);
create index if not exists chemist_api_keys_chemist_idx on public.chemist_api_keys (chemist_id);
alter table public.chemist_api_keys enable row level security;
drop policy if exists chemist_api_keys_own_read on public.chemist_api_keys;
create policy chemist_api_keys_own_read on public.chemist_api_keys
  for select using (chemist_id = auth.uid());

create or replace function public.create_chemist_api_key(p_label text default null)
returns text language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_key text;
begin
  if not public.current_role_is('chemist') then raise exception 'chemists_only'; end if;
  if (select count(*) from public.chemist_api_keys
      where chemist_id = auth.uid() and revoked_at is null) >= 5 then
    raise exception 'too_many_keys';
  end if;
  v_key := 'gdk_' || encode(gen_random_bytes(24), 'hex');
  insert into public.chemist_api_keys (chemist_id, label, key_prefix, key_hash)
  values (auth.uid(), coalesce(nullif(trim(p_label), ''), 'Pharmacy system'),
          left(v_key, 10), encode(digest(v_key, 'sha256'), 'hex'));
  return v_key;
end $$;

create or replace function public.revoke_chemist_api_key(p_id uuid)
returns void language sql security definer set search_path = public as $$
  update public.chemist_api_keys set revoked_at = now()
  where id = p_id and chemist_id = auth.uid() and revoked_at is null;
$$;

------------------------------------------------------------------
-- Privileges
------------------------------------------------------------------
revoke all on function
  public.place_order(uuid, uuid, text, jsonb),
  public.confirm_order_received(uuid),
  public.dispute_order(uuid, text),
  public.chemist_advance_order(uuid, text),
  public.orders_restock(),
  public.order_dispute_note_notify(),
  public.patient_visits(),
  public.public_chemists(),
  public.match_drug(text),
  public.match_drugs(text[]),
  public.import_inventory(jsonb),
  public.create_chemist_api_key(text),
  public.revoke_chemist_api_key(uuid)
from public, anon;
grant execute on function
  public.place_order(uuid, uuid, text, jsonb),
  public.confirm_order_received(uuid),
  public.dispute_order(uuid, text),
  public.chemist_advance_order(uuid, text),
  public.patient_visits(),
  public.public_chemists(),
  public.match_drugs(text[]),
  public.import_inventory(jsonb),
  public.create_chemist_api_key(text),
  public.revoke_chemist_api_key(uuid)
to authenticated;
-- match_drug is also used by the inventory-sync function (service role).
grant execute on function public.match_drug(text) to authenticated, service_role;

notify pgrst, 'reload schema';
