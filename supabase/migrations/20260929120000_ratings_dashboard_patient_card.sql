-- Pharmacy ratings and reviews, the pharmacy dashboard, and the patient
-- card doctors and pharmacies can open for their own patients.

------------------------------------------------------------------
-- 1. Pharmacy reviews: a patient rates a pharmacy once per fulfilled order.
--    The rating shown is the plain average of every review.
------------------------------------------------------------------
create unique index if not exists reviews_one_per_order
  on public.reviews (order_id) where order_id is not null;

create or replace function public.submit_order_review(
  p_order uuid, p_rating integer, p_comment text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_o public.orders;
  v_id uuid;
begin
  select * into v_o from public.orders where id = p_order;
  if v_o.id is null or v_o.patient_id is distinct from auth.uid() then
    raise exception 'not your order';
  end if;
  if v_o.status <> 'fulfilled' then
    raise exception 'order_not_fulfilled';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'invalid_rating';
  end if;
  if exists (select 1 from public.reviews where order_id = p_order) then
    raise exception 'already reviewed';
  end if;
  insert into public.reviews (order_id, author_id, rating, comment, flagged_for_review)
  values (p_order, auth.uid(), p_rating,
          nullif(left(btrim(coalesce(p_comment, '')), 500), ''), p_rating <= 2)
  returning id into v_id;
  return v_id;
end $$;

-- Public list of a pharmacy's reviews. No author identity is exposed.
create or replace function public.chemist_reviews(
  p_chemist uuid, p_limit integer default 20, p_offset integer default 0
) returns table (id uuid, rating integer, comment text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.rating, r.comment, r.created_at
  from public.reviews r
  join public.orders o on o.id = r.order_id
  where o.chemist_id = p_chemist
  order by r.created_at desc
  limit least(greatest(p_limit, 1), 50) offset greatest(p_offset, 0);
$$;

-- The pharmacy hears about new reviews too (doctors already do).
create or replace function public.review_notifications() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_to uuid;
begin
  if new.consultation_id is not null then
    select doctor_id into v_to from consultations where id = new.consultation_id;
    if v_to is not null then
      perform public.notify(v_to, 'review_new',
        'New ' || new.rating || '-star review',
        coalesce('"' || nullif(left(btrim(new.comment), 120), '') || '"',
                 'A patient rated their consultation with you.'),
        jsonb_build_object('consultation_id', new.consultation_id));
    end if;
  elsif new.order_id is not null then
    select chemist_id into v_to from orders where id = new.order_id;
    if v_to is not null then
      perform public.notify(v_to, 'review_new',
        'New ' || new.rating || '-star review',
        coalesce('"' || nullif(left(btrim(new.comment), 120), '') || '"',
                 'A patient rated their order from you.'),
        jsonb_build_object('order_id', new.order_id));
    end if;
  end if;
  return new;
end $$;

-- Public pharmacy pages now carry the average rating (worked out from the
-- reviews each time, so it's always the true average).
drop function if exists public.chemist_public_profile(uuid);
create function public.chemist_public_profile(p_chemist uuid)
returns table (
  user_id uuid, business_name text, avatar_url text, contact_phone text,
  location_name text, location_lat double precision,
  location_lng double precision, member_since timestamptz,
  medicines_in_stock bigint, orders_filled bigint,
  rating_avg numeric, rating_count bigint
) language sql stable security definer set search_path = public as $$
  select cp.user_id, cp.business_name, u.avatar_url, u.contact_phone,
         cp.location_name,
         cp.location_lat::double precision, cp.location_lng::double precision,
         u.created_at,
         (select count(*) from public.chemist_inventory ci
          where ci.chemist_id = cp.user_id and ci.quantity > 0),
         (select count(*) from public.orders o
          where o.chemist_id = cp.user_id and o.status = 'fulfilled'),
         coalesce(rv.avg, 0), coalesce(rv.n, 0)
  from public.chemist_profiles cp
  join public.users u on u.id = cp.user_id and u.status = 'active'
  left join lateral (
    select round(avg(r.rating)::numeric, 2) as avg, count(*) as n
    from public.reviews r join public.orders o on o.id = r.order_id
    where o.chemist_id = cp.user_id
  ) rv on true
  where cp.user_id = p_chemist and cp.verified;
$$;

drop function if exists public.public_chemists();
create function public.public_chemists()
returns table (
  user_id uuid, business_name text, avatar_url text, contact_phone text,
  location_name text, location_lat double precision,
  location_lng double precision, member_since timestamptz,
  medicines_in_stock bigint, orders_filled bigint,
  rating_avg numeric, rating_count bigint
) language sql stable security definer set search_path = public as $$
  select cp.user_id, cp.business_name, u.avatar_url, u.contact_phone,
         cp.location_name,
         cp.location_lat::double precision, cp.location_lng::double precision,
         u.created_at,
         (select count(*) from public.chemist_inventory ci
          where ci.chemist_id = cp.user_id and ci.quantity > 0),
         (select count(*) from public.orders o
          where o.chemist_id = cp.user_id and o.status = 'fulfilled'),
         coalesce(rv.avg, 0), coalesce(rv.n, 0)
  from public.chemist_profiles cp
  join public.users u on u.id = cp.user_id and u.status = 'active'
  left join lateral (
    select round(avg(r.rating)::numeric, 2) as avg, count(*) as n
    from public.reviews r join public.orders o on o.id = r.order_id
    where o.chemist_id = cp.user_id
  ) rv on true
  where cp.verified
  order by cp.business_name
  limit 300;
$$;

------------------------------------------------------------------
-- 2. The pharmacy dashboard: sales, orders, stock health and what to
--    restock. Days are counted in Nairobi time.
------------------------------------------------------------------
create or replace function public.chemist_dashboard()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'Africa/Nairobi')::date;
  v_from timestamptz := ((now() at time zone 'Africa/Nairobi')::date - 60)::timestamp
                        at time zone 'Africa/Nairobi';
  v_out jsonb;
begin
  if v_me is null or not public.current_role_is('chemist') then
    raise exception 'chemists_only';
  end if;

  with sales as (
    -- Orders that count as sales: everything except refunds and disputes.
    select o.id, o.status, o.total_amount,
           (o.created_at at time zone 'Africa/Nairobi')::date as day
    from public.orders o
    where o.chemist_id = v_me
      and o.status in ('placed', 'confirmed', 'ready', 'fulfilled')
      and o.created_at >= v_from
  ),
  sold as (
    select oi.drug_id, sum(oi.quantity)::int as units,
           sum(oi.quantity * oi.unit_price) as revenue, max(s.day) as last_sold
    from public.order_items oi join sales s on s.id = oi.order_id
    where s.day > v_today - 30
    group by oi.drug_id
  ),
  stock as (
    select ci.drug_id, ci.quantity, ci.price, ci.last_updated_at,
           d.generic_name || coalesce(' (' || d.brand_names[1] || ')', '') as name,
           coalesce(so.units, 0) as units_30d, so.last_sold
    from public.chemist_inventory ci
    join public.drugs d on d.id = ci.drug_id
    left join sold so on so.drug_id = ci.drug_id
    where ci.chemist_id = v_me
  ),
  daily as (
    select day, sum(total_amount) as revenue, count(*) as n from sales group by day
  )
  select jsonb_build_object(
    'revenue', jsonb_build_object(
      'today', coalesce((select sum(total_amount) from sales where day = v_today), 0),
      'week', coalesce((select sum(total_amount) from sales where day > v_today - 7), 0),
      'month', coalesce((select sum(total_amount) from sales where day > v_today - 30), 0),
      'prev_month', coalesce((select sum(total_amount) from sales
                              where day <= v_today - 30 and day > v_today - 60), 0),
      'released', coalesce((select sum(total_amount) from sales
                            where day > v_today - 30 and status = 'fulfilled'), 0),
      'held', coalesce((select sum(total_amount) from public.orders
                        where chemist_id = v_me
                          and status in ('placed', 'confirmed', 'ready')), 0)
    ),
    'orders', jsonb_build_object(
      'today', (select count(*) from sales where day = v_today),
      'month', (select count(*) from sales where day > v_today - 30),
      'waiting', (select count(*) from public.orders where chemist_id = v_me and status = 'placed'),
      'preparing', (select count(*) from public.orders where chemist_id = v_me and status = 'confirmed'),
      'ready', (select count(*) from public.orders where chemist_id = v_me and status = 'ready'),
      'disputed', (select count(*) from public.orders where chemist_id = v_me and status = 'disputed')
    ),
    'daily', (
      select jsonb_agg(jsonb_build_object(
               'day', g::date, 'revenue', coalesce(x.revenue, 0), 'orders', coalesce(x.n, 0))
             order by g)
      from generate_series((v_today - 13)::timestamp, v_today::timestamp, interval '1 day') g
      left join daily x on x.day = g::date
    ),
    'stock', jsonb_build_object(
      'listed', (select count(*) from stock),
      'in_stock', (select count(*) from stock where quantity > 0),
      'low', (select count(*) from stock where quantity between 1 and 5),
      'out', (select count(*) from stock where quantity = 0),
      'value', coalesce((select sum(quantity * price) from stock), 0)
    ),
    'top', coalesce((
      select jsonb_agg(t) from (
        select so.drug_id,
               d.generic_name || coalesce(' (' || d.brand_names[1] || ')', '') as name,
               so.units, so.revenue, coalesce(ci.quantity, 0) as quantity
        from sold so
        join public.drugs d on d.id = so.drug_id
        left join public.chemist_inventory ci
          on ci.chemist_id = v_me and ci.drug_id = so.drug_id
        order by so.units desc, so.revenue desc
        limit 5
      ) t), '[]'::jsonb),
    'low_stock', coalesce((
      select jsonb_agg(t) from (
        select drug_id, name, quantity, units_30d,
               case when units_30d > 0
                    then floor(quantity / (units_30d / 30.0))::int end as days_left
        from stock
        where quantity > 0
          and (quantity <= 5 or (units_30d > 0 and quantity / (units_30d / 30.0) < 7))
        order by quantity / greatest(units_30d / 30.0, 0.01), quantity
        limit 10
      ) t), '[]'::jsonb),
    'out_of_stock', coalesce((
      select jsonb_agg(t) from (
        select drug_id, name, units_30d, last_sold, last_updated_at as since
        from stock
        where quantity = 0
        order by units_30d desc, last_updated_at desc
        limit 20
      ) t), '[]'::jsonb),
    'slow', coalesce((
      select jsonb_agg(t) from (
        select drug_id, name, quantity, (quantity * price) as value
        from stock
        where quantity > 0 and units_30d = 0
        order by quantity * price desc
        limit 5
      ) t), '[]'::jsonb)
  ) into v_out;
  return v_out;
end $$;

------------------------------------------------------------------
-- 3. Patient card: what a doctor or pharmacy needs to know about their
--    own patient (photo, age, allergies, conditions, medicines) -- and
--    only for patients they've seen or served. No contact details.
------------------------------------------------------------------
create or replace function public.patient_card(p_patient uuid)
returns table (
  user_id uuid, name text, avatar_url text, age integer, gender text,
  blood_group text, allergies text, chronic_conditions text,
  current_medications text, member_since timestamptz,
  visits_with_me bigint, orders_with_me bigint
) language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
begin
  if v_me is null or not (
       exists (select 1 from public.consultations c
               where c.patient_id = p_patient and c.doctor_id = v_me)
    or exists (select 1 from public.orders o
               where o.patient_id = p_patient and o.chemist_id = v_me)
    or public.current_role_is('admin')
  ) then
    raise exception 'not_your_patient';
  end if;

  return query
  select pp.user_id, pp.name, u.avatar_url,
         case when pp.date_of_birth is null then null
              else extract(year from age(pp.date_of_birth))::integer end,
         pp.gender, pp.blood_group, pp.allergies, pp.chronic_conditions,
         pp.current_medications, u.created_at,
         (select count(*) from public.consultations c
          where c.patient_id = p_patient and c.doctor_id = v_me
            and c.status = 'completed'),
         (select count(*) from public.orders o
          where o.patient_id = p_patient and o.chemist_id = v_me
            and o.status <> 'refunded')
  from public.patient_profiles pp
  join public.users u on u.id = pp.user_id
  where pp.user_id = p_patient;
end $$;

------------------------------------------------------------------
-- 4. Privileges: signed-in users only.
------------------------------------------------------------------
revoke all on function
  public.submit_order_review(uuid, integer, text),
  public.chemist_reviews(uuid, integer, integer),
  public.chemist_public_profile(uuid),
  public.public_chemists(),
  public.chemist_dashboard(),
  public.patient_card(uuid)
from public, anon;
grant execute on function
  public.submit_order_review(uuid, integer, text),
  public.chemist_reviews(uuid, integer, integer),
  public.chemist_public_profile(uuid),
  public.public_chemists(),
  public.chemist_dashboard(),
  public.patient_card(uuid)
to authenticated;
