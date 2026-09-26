-- Super-admin backend: a live activity log of every write to the database,
-- dashboard metrics, user management (suspend = real sign-in ban), lists of
-- consultations / orders / payments / sessions, database health, a
-- read-only table browser, announcements and admin overrides.
--
-- Every function here checks the caller is an admin first.

create or replace function public.assert_admin() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.current_role_is('admin') then
    raise exception 'admins_only';
  end if;
end $$;

------------------------------------------------------------------
-- 1. Activity log: who wrote what, where, when (values are not copied --
--    only the table, operation, row id and which columns changed).
------------------------------------------------------------------
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor_id uuid,          -- auth.uid(); null = the system (cron, server jobs)
  table_name text not null,
  op text not null check (op in ('INSERT', 'UPDATE', 'DELETE')),
  row_id text,
  changed text[]          -- UPDATE only: the columns that changed
);
create index if not exists audit_log_at_idx on public.audit_log (at desc);
create index if not exists audit_log_table_idx on public.audit_log (table_name, at desc);
create index if not exists audit_log_actor_idx on public.audit_log (actor_id, at desc);

alter table public.audit_log enable row level security;
create policy audit_log_admin_read on public.audit_log
  for select to authenticated using (public.current_role_is('admin'));

create or replace function public.audit_row() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_new jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) end;
  v_old jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) end;
  v_row jsonb := coalesce(v_new, v_old);
  v_changed text[];
begin
  if tg_op = 'UPDATE' then
    select array_agg(n.key order by n.key) into v_changed
    from jsonb_each(v_new) n
    where n.value is distinct from (v_old -> n.key)
      and n.key not in ('updated_at', 'last_seen_at', 'last_updated_at');
    -- Only housekeeping columns moved (e.g. the presence ping): skip.
    if v_changed is null then return null; end if;
  end if;

  insert into public.audit_log (actor_id, table_name, op, row_id, changed)
  values (
    auth.uid(), tg_table_name, tg_op,
    coalesce(
      v_row ->> 'id',
      v_row ->> 'user_id',
      case when v_row ? 'chemist_id' and v_row ? 'drug_id'
           then (v_row ->> 'chemist_id') || ':' || (v_row ->> 'drug_id') end,
      v_row ->> 'consultation_id'
    ),
    v_changed
  );
  return null;
end $$;

-- Attach to every app table (not to the log itself, notifications -- which
-- are written by the triggers being logged anyway -- or bulk reference data).
do $$
declare t text;
begin
  for t in
    select tablename from pg_tables
    where schemaname = 'public'
      and tablename not in ('audit_log', 'notifications', 'drug_info')
  loop
    execute format('drop trigger if exists zz_audit on public.%I', t);
    execute format(
      'create trigger zz_audit after insert or update or delete on public.%I
         for each row execute function public.audit_row()', t);
  end loop;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.audit_log;
exception when duplicate_object then null; end $$;

-- Keep 30 days.
do $$ begin
  perform cron.schedule(
    'prune-audit-log', '15 3 * * *',
    $q$delete from public.audit_log where at < now() - interval '30 days'$q$
  );
end $$;

-- Log rows with the actor's name and role, newest first.
create or replace function public.admin_activity(
  p_table text default null, p_op text default null, p_actor uuid default null,
  p_limit int default 100, p_before bigint default null
) returns table (
  id bigint, at timestamptz, actor_id uuid, actor_name text, actor_role text,
  table_name text, op text, row_id text, changed text[]
) language plpgsql stable security definer set search_path = public as $$
begin
  perform public.assert_admin();
  return query
    select a.id, a.at, a.actor_id,
           case when a.actor_id is null then 'System' else public.display_name(a.actor_id) end,
           coalesce(u.role::text, 'system'),
           a.table_name, a.op, a.row_id, a.changed
    from public.audit_log a
    left join public.users u on u.id = a.actor_id
    where (p_table is null or a.table_name = p_table)
      and (p_op is null or a.op = p_op)
      and (p_actor is null or a.actor_id = p_actor)
      and (p_before is null or a.id < p_before)
    order by a.id desc
    limit least(greatest(p_limit, 1), 500);
end $$;

------------------------------------------------------------------
-- 2. Dashboard overview for the last p_days (Nairobi calendar days),
--    compared with the p_days before that.
------------------------------------------------------------------
create or replace function public.admin_overview(p_days int default 30)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_days int := greatest(1, least(coalesce(p_days, 30), 365));
  v_from timestamptz := date_trunc('day', now() at time zone 'Africa/Nairobi') at time zone 'Africa/Nairobi'
                        - make_interval(days => v_days - 1);
  v_prev timestamptz := v_from - make_interval(days => v_days);
  v jsonb;
begin
  perform public.assert_admin();

  select jsonb_build_object(
    'days', v_days,
    'users_total', (select count(*) from users),
    'users_by_role', (select coalesce(jsonb_object_agg(role, n), '{}') from
                        (select role::text, count(*) n from users group by role) x),
    'users_new', (select count(*) from users where created_at >= v_from),
    'users_new_prev', (select count(*) from users where created_at >= v_prev and created_at < v_from),
    'users_suspended', (select count(*) from users where status = 'suspended'),
    'online_now', (select count(*) from users where last_seen_at > now() - interval '2 minutes'),
    'sessions_active', (select count(*) from auth.sessions
                        where coalesce(refreshed_at, updated_at, created_at) > now() - interval '24 hours'),
    'doctors_available', (select count(*) from doctor_profiles where status = 'available' and license_verified),
    'doctors_busy', (select count(*) from doctor_profiles where status = 'busy'),
    'consults_live', (select count(*) from consultations where status = 'in_progress'),
    'consults_awaiting_payment', (select count(*) from consultations where status = 'awaiting_payment'),
    'consults', (select count(*) from consultations where created_at >= v_from),
    'consults_prev', (select count(*) from consultations where created_at >= v_prev and created_at < v_from),
    'consults_by_status', (select coalesce(jsonb_object_agg(status, n), '{}') from
                            (select status::text, count(*) n from consultations
                             where created_at >= v_from group by status) x),
    'revenue', (select coalesce(sum(amount), 0) from payments where status = 'succeeded' and created_at >= v_from),
    'revenue_prev', (select coalesce(sum(amount), 0) from payments
                     where status = 'succeeded' and created_at >= v_prev and created_at < v_from),
    'revenue_consults', (select coalesce(sum(amount), 0) from payments
                         where status = 'succeeded' and consultation_id is not null and created_at >= v_from),
    'revenue_orders', (select coalesce(sum(amount), 0) from payments
                       where status = 'succeeded' and order_id is not null and created_at >= v_from),
    'orders', (select count(*) from orders where created_at >= v_from),
    'orders_prev', (select count(*) from orders where created_at >= v_prev and created_at < v_from),
    'orders_by_status', (select coalesce(jsonb_object_agg(status, n), '{}') from
                          (select status::text, count(*) n from orders
                           where created_at >= v_from group by status) x),
    'prescriptions', (select count(*) from prescriptions where issued_at >= v_from),
    'pending_doctors', (select count(*) from doctor_profiles
                        where not license_verified and coalesce(license_number, '') <> ''),
    'pending_chemists', (select count(*) from chemist_profiles
                         where not verified and coalesce(registration_number, '') <> ''),
    'tickets_open', (select count(*) from support_tickets where status = 'open'),
    'rating_avg', (select round(avg(stars)::numeric, 2) from app_ratings),
    'rating_count', (select count(*) from app_ratings),
    'writes_24h', (select count(*) from audit_log where at > now() - interval '24 hours'),
    'db_size_bytes', pg_database_size(current_database()),
    'series', (
      select jsonb_agg(jsonb_build_object(
        'day', to_char(d.day, 'YYYY-MM-DD'),
        'signups', (select count(*) from users u
                    where (u.created_at at time zone 'Africa/Nairobi')::date = d.day),
        'consults', (select count(*) from consultations c
                     where (c.created_at at time zone 'Africa/Nairobi')::date = d.day),
        'orders', (select count(*) from orders o
                   where (o.created_at at time zone 'Africa/Nairobi')::date = d.day),
        'revenue', (select coalesce(sum(p.amount), 0) from payments p
                    where p.status = 'succeeded'
                      and (p.created_at at time zone 'Africa/Nairobi')::date = d.day),
        'writes', (select count(*) from audit_log a
                   where (a.at at time zone 'Africa/Nairobi')::date = d.day)
      ) order by d.day)
      from (
        select generate_series(
          (v_from at time zone 'Africa/Nairobi')::date,
          (now() at time zone 'Africa/Nairobi')::date,
          interval '1 day'
        )::date as day
      ) d
    )
  ) into v;
  return v;
end $$;

------------------------------------------------------------------
-- 3. Users
------------------------------------------------------------------
create or replace function public.admin_users(
  p_search text default null, p_role text default null, p_status text default null,
  p_limit int default 50, p_offset int default 0
) returns table (
  id uuid, name text, email text, phone text, role text, status text,
  avatar_url text, verified boolean, created_at timestamptz,
  last_seen_at timestamptz, last_sign_in_at timestamptz, total_count bigint
) language plpgsql stable security definer set search_path = public as $$
declare v_q text := nullif(lower(btrim(coalesce(p_search, ''))), '');
begin
  perform public.assert_admin();
  return query
    with base as (
      select u.id, public.display_name(u.id) as name, u.email,
             coalesce(u.phone, u.contact_phone) as phone,
             u.role::text as role, u.status::text as status, u.avatar_url,
             case u.role
               when 'doctor' then (select dp.license_verified from doctor_profiles dp where dp.user_id = u.id)
               when 'chemist' then (select cp.verified from chemist_profiles cp where cp.user_id = u.id)
               else null end as verified,
             u.created_at, u.last_seen_at, au.last_sign_in_at
      from users u
      left join auth.users au on au.id = u.id
      where (p_role is null or u.role::text = p_role)
        and (p_status is null or u.status::text = p_status)
    )
    select b.*, count(*) over () as total_count
    from base b
    where v_q is null
       or lower(b.name) like '%' || v_q || '%'
       or lower(coalesce(b.email, '')) like '%' || v_q || '%'
       or coalesce(b.phone, '') like '%' || v_q || '%'
       or b.id::text = v_q
    order by b.created_at desc
    limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0);
end $$;

create or replace function public.admin_user_detail(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_u record; v jsonb;
begin
  perform public.assert_admin();
  select * into v_u from users where id = p_user;
  if v_u.id is null then return null; end if;

  select jsonb_build_object(
    'user', to_jsonb(v_u) || jsonb_build_object('name', public.display_name(p_user)),
    'auth', (select jsonb_build_object(
               'last_sign_in_at', au.last_sign_in_at,
               'email_confirmed_at', au.email_confirmed_at,
               'phone_confirmed_at', au.phone_confirmed_at,
               'banned_until', au.banned_until,
               'created_at', au.created_at)
             from auth.users au where au.id = p_user),
    'profile', case v_u.role
      when 'patient' then (select to_jsonb(p) from patient_profiles p where p.user_id = p_user)
      when 'doctor' then (select to_jsonb(d) from doctor_profiles d where d.user_id = p_user)
      when 'chemist' then (select to_jsonb(c) from chemist_profiles c where c.user_id = p_user)
      else null end,
    'stats', jsonb_build_object(
      'consultations_as_patient', (select count(*) from consultations where patient_id = p_user),
      'consultations_as_doctor', (select count(*) from consultations where doctor_id = p_user),
      'orders_placed', (select count(*) from orders where patient_id = p_user),
      'orders_received', (select count(*) from orders where chemist_id = p_user),
      'spent', (select coalesce(sum(p.amount), 0) from payments p
                left join orders o on o.id = p.order_id
                left join consultations c on c.id = p.consultation_id
                where p.status = 'succeeded' and (o.patient_id = p_user or c.patient_id = p_user)),
      'prescriptions_issued', (select count(*) from prescriptions where doctor_id = p_user),
      'prescriptions_received', (select count(*) from prescriptions where patient_id = p_user),
      'family_links', (select count(*) from family_links
                       where status = 'accepted' and p_user in (requester_id, member_id)),
      'tickets', (select count(*) from support_tickets where user_id = p_user),
      'writes_30d', (select count(*) from audit_log where actor_id = p_user)
    ),
    'sessions', (select coalesce(jsonb_agg(jsonb_build_object(
                    'created_at', s.created_at,
                    'last_active', coalesce(s.refreshed_at, s.updated_at, s.created_at),
                    'user_agent', s.user_agent,
                    'ip', host(s.ip)) order by coalesce(s.refreshed_at, s.updated_at, s.created_at) desc), '[]')
                 from auth.sessions s where s.user_id = p_user),
    'consultations', (select coalesce(jsonb_agg(x order by x.created_at desc), '[]') from (
        select c.id, c.created_at, c.status, c.specialty_requested, c.mode,
               public.display_name(case when c.patient_id = p_user then c.doctor_id else c.patient_id end) as other
        from consultations c
        where p_user in (c.patient_id, c.doctor_id)
        order by c.created_at desc limit 10) x),
    'orders', (select coalesce(jsonb_agg(x order by x.created_at desc), '[]') from (
        select o.id, o.created_at, o.status, o.total_amount,
               public.display_name(case when o.patient_id = p_user then o.chemist_id else o.patient_id end) as other
        from orders o
        where p_user in (o.patient_id, o.chemist_id)
        order by o.created_at desc limit 10) x),
    'activity', (select coalesce(jsonb_agg(x order by x.id desc), '[]') from (
        select a.id, a.at, a.table_name, a.op, a.row_id, a.changed
        from audit_log a where a.actor_id = p_user order by a.id desc limit 25) x)
  ) into v;
  return v;
end $$;

-- Suspend = real ban: blocks sign-in and token refresh, and ends sessions.
create or replace function public.admin_set_user_status(p_user uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
declare v_role user_role;
begin
  perform public.assert_admin();
  if p_status not in ('active', 'suspended') then raise exception 'invalid status'; end if;
  select role into v_role from users where id = p_user;
  if v_role is null then raise exception 'user not found'; end if;
  if p_user = auth.uid() then raise exception 'cannot_change_own_account'; end if;
  if v_role = 'admin' then raise exception 'cannot_suspend_admin'; end if;

  update users set status = p_status::user_status where id = p_user;
  if p_status = 'suspended' then
    update auth.users set banned_until = 'infinity' where id = p_user;
    delete from auth.sessions where user_id = p_user;
    -- Take a suspended doctor off the rota.
    update doctor_profiles set status = 'offline' where user_id = p_user and status = 'available';
  else
    update auth.users set banned_until = null where id = p_user;
    perform public.notify(p_user, 'announcement', 'Your account is active again',
                          'You can use GoDoctor as normal.', '{}'::jsonb);
  end if;
end $$;

------------------------------------------------------------------
-- 4. Consultations, orders, payments, sessions
------------------------------------------------------------------
create or replace function public.admin_consultations(
  p_search text default null, p_status text default null,
  p_limit int default 50, p_offset int default 0
) returns table (
  id uuid, created_at timestamptz, status text, mode text, specialty text,
  patient_id uuid, patient_name text, doctor_id uuid, doctor_name text,
  fee numeric, paid boolean, started_at timestamptz, ended_at timestamptz,
  prescriptions bigint, family bigint, total_count bigint
) language plpgsql stable security definer set search_path = public as $$
declare v_q text := nullif(lower(btrim(coalesce(p_search, ''))), '');
begin
  perform public.assert_admin();
  return query
    with base as (
      select c.id, c.created_at, c.status::text as status, c.mode::text as mode,
             c.specialty_requested as specialty,
             c.patient_id, public.display_name(c.patient_id) as patient_name,
             c.doctor_id,
             case when c.doctor_id is null then null else public.display_name(c.doctor_id) end as doctor_name,
             c.fee_amount::numeric as fee,
             exists (select 1 from payments p where p.consultation_id = c.id and p.status = 'succeeded') as paid,
             c.started_at, c.ended_at,
             (select count(*) from prescriptions r where r.consultation_id = c.id) as prescriptions,
             (select count(*) from consultation_participants cp
              where cp.consultation_id = c.id and cp.status = 'joined') as family
      from consultations c
      where (p_status is null or c.status::text = p_status)
    )
    select b.*, count(*) over () from base b
    where v_q is null
       or lower(b.patient_name) like '%' || v_q || '%'
       or lower(coalesce(b.doctor_name, '')) like '%' || v_q || '%'
       or lower(b.specialty) like '%' || v_q || '%'
       or b.id::text = v_q
    order by b.created_at desc
    limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0);
end $$;

create or replace function public.admin_orders(
  p_search text default null, p_status text default null,
  p_limit int default 50, p_offset int default 0
) returns table (
  id uuid, created_at timestamptz, status text, escrow text, fulfillment text,
  total numeric, patient_id uuid, patient_name text, chemist_id uuid, chemist_name text,
  items bigint, has_prescription boolean, total_count bigint
) language plpgsql stable security definer set search_path = public as $$
declare v_q text := nullif(lower(btrim(coalesce(p_search, ''))), '');
begin
  perform public.assert_admin();
  return query
    with base as (
      select o.id, o.created_at, o.status::text as status, o.escrow_status::text as escrow,
             o.fulfillment_type::text as fulfillment, o.total_amount::numeric as total,
             o.patient_id, public.display_name(o.patient_id) as patient_name,
             o.chemist_id, public.display_name(o.chemist_id) as chemist_name,
             (select count(*) from order_items i where i.order_id = o.id) as items,
             o.prescription_id is not null as has_prescription
      from orders o
      where (p_status is null or o.status::text = p_status)
    )
    select b.*, count(*) over () from base b
    where v_q is null
       or lower(b.patient_name) like '%' || v_q || '%'
       or lower(b.chemist_name) like '%' || v_q || '%'
       or b.id::text = v_q
    order by b.created_at desc
    limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0);
end $$;

create or replace function public.admin_payments(
  p_status text default null, p_limit int default 50, p_offset int default 0
) returns table (
  id uuid, created_at timestamptz, amount numeric, provider text, status text,
  is_simulated boolean, kind text, payer_name text, reference uuid, total_count bigint
) language plpgsql stable security definer set search_path = public as $$
begin
  perform public.assert_admin();
  return query
    select p.id, p.created_at, p.amount::numeric, p.provider::text, p.status::text,
           p.is_simulated,
           case when p.consultation_id is not null then 'consultation' else 'order' end,
           public.display_name(coalesce(c.patient_id, o.patient_id)),
           coalesce(p.consultation_id, p.order_id),
           count(*) over ()
    from payments p
    left join consultations c on c.id = p.consultation_id
    left join orders o on o.id = p.order_id
    where (p_status is null or p.status::text = p_status)
    order by p.created_at desc
    limit least(greatest(p_limit, 1), 200) offset greatest(p_offset, 0);
end $$;

-- Signed-in devices across the app (auth sessions), most recently active first.
create or replace function public.admin_sessions(p_limit int default 100)
returns table (
  user_id uuid, name text, role text, created_at timestamptz,
  last_active timestamptz, user_agent text, ip text
) language plpgsql stable security definer set search_path = public as $$
begin
  perform public.assert_admin();
  return query
    select s.user_id, public.display_name(s.user_id), u.role::text, s.created_at,
           coalesce(s.refreshed_at, s.updated_at, s.created_at)::timestamptz,
           s.user_agent, host(s.ip)
    from auth.sessions s
    left join users u on u.id = s.user_id
    order by coalesce(s.refreshed_at, s.updated_at, s.created_at) desc
    limit least(greatest(p_limit, 1), 500);
end $$;

------------------------------------------------------------------
-- 5. Database health and a read-only table browser
------------------------------------------------------------------
create or replace function public.admin_db_stats()
returns jsonb language plpgsql stable security definer set search_path = public, extensions as $$
begin
  perform public.assert_admin();
  return jsonb_build_object(
    'db_size_bytes', pg_database_size(current_database()),
    'postgres_version', current_setting('server_version'),
    'connections', (select coalesce(jsonb_object_agg(coalesce(state, 'background'), n), '{}') from
                      (select state, count(*) n from pg_stat_activity
                       where datname = current_database() group by state) x),
    'cache_hit_ratio', (select round(sum(heap_blks_hit)::numeric
                                     / nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0), 4)
                        from pg_statio_user_tables),
    'tables', (select coalesce(jsonb_agg(jsonb_build_object(
                  'name', s.relname,
                  'rows', s.n_live_tup,
                  'size_bytes', pg_total_relation_size(s.relid),
                  'inserts', s.n_tup_ins,
                  'updates', s.n_tup_upd,
                  'deletes', s.n_tup_del,
                  'seq_scans', s.seq_scan,
                  'index_scans', coalesce(s.idx_scan, 0),
                  'last_vacuum', greatest(s.last_vacuum, s.last_autovacuum)
                ) order by pg_total_relation_size(s.relid) desc), '[]')
               from pg_stat_user_tables s where s.schemaname = 'public'),
    'top_queries', (select coalesce(jsonb_agg(x), '[]') from (
        select left(regexp_replace(q.query, '\s+', ' ', 'g'), 400) as query,
               q.calls, round(q.total_exec_time::numeric, 1) as total_ms,
               round(q.mean_exec_time::numeric, 2) as mean_ms, q.rows
        from extensions.pg_stat_statements q
        join pg_database d on d.oid = q.dbid and d.datname = current_database()
        where q.query not ilike '%pg_stat_statements%'
        order by q.total_exec_time desc
        limit 20) x)
  );
end $$;

create or replace function public.admin_table_rows(
  p_table text, p_limit int default 50, p_offset int default 0
) returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_cols jsonb;
  v_rows jsonb;
  v_total bigint;
  v_order text := '';
begin
  perform public.assert_admin();
  if not exists (select 1 from pg_tables where schemaname = 'public' and tablename = p_table) then
    raise exception 'unknown table';
  end if;

  select jsonb_agg(jsonb_build_object('name', column_name, 'type', data_type) order by ordinal_position)
  into v_cols
  from information_schema.columns
  where table_schema = 'public' and table_name = p_table;

  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = p_table and column_name = 'created_at') then
    v_order := 'order by created_at desc';
  elsif p_table = 'audit_log' then
    v_order := 'order by id desc';
  end if;

  execute format('select count(*) from public.%I', p_table) into v_total;
  execute format(
    'select coalesce(jsonb_agg(t), ''[]''::jsonb) from (select * from public.%I %s limit %s offset %s) t',
    p_table, v_order, least(greatest(p_limit, 1), 200), greatest(p_offset, 0)
  ) into v_rows;

  return jsonb_build_object('columns', v_cols, 'rows', v_rows, 'total', v_total);
end $$;

------------------------------------------------------------------
-- 6. Admin actions
------------------------------------------------------------------
-- Announcement to everyone, or to one role. Returns how many were sent.
create or replace function public.admin_broadcast(p_role text, p_title text, p_body text)
returns int language plpgsql security definer set search_path = public as $$
declare v_n int;
begin
  perform public.assert_admin();
  if length(btrim(coalesce(p_title, ''))) = 0 then raise exception 'title required'; end if;
  insert into notifications (user_id, kind, title, body, data)
  select u.id, 'announcement', left(btrim(p_title), 120), left(coalesce(p_body, ''), 1000),
         jsonb_build_object('from', 'admin')
  from users u
  where u.status = 'active' and u.role <> 'admin'
    and (p_role is null or u.role::text = p_role);
  get diagnostics v_n = row_count;
  return v_n;
end $$;

create or replace function public.admin_set_order_status(p_order uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
declare v_o record;
begin
  perform public.assert_admin();
  select * into v_o from orders where id = p_order;
  if v_o.id is null then raise exception 'order not found'; end if;
  update orders
  set status = p_status::order_status,
      escrow_status = case p_status when 'refunded' then 'refunded'::escrow_status
                                    when 'fulfilled' then 'released'::escrow_status
                                    else escrow_status end
  where id = p_order;
  if p_status = 'refunded' then
    update payments set status = 'refunded' where order_id = p_order;
  end if;
  perform public.notify(v_o.patient_id, 'announcement', 'Order update',
    'An administrator changed your order status to ' || replace(p_status, '_', ' ') || '.',
    jsonb_build_object('order_id', p_order));
end $$;

create or replace function public.admin_cancel_consultation(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_c record;
begin
  perform public.assert_admin();
  select * into v_c from consultations where id = p_id;
  if v_c.id is null then raise exception 'consultation not found'; end if;
  if v_c.status in ('completed', 'cancelled') then raise exception 'already finished'; end if;
  update consultations set status = 'cancelled', ended_at = now() where id = p_id;
  if v_c.doctor_id is not null then
    update doctor_profiles set status = 'available', last_available_at = now()
    where user_id = v_c.doctor_id and status = 'busy';
    perform public.notify(v_c.doctor_id, 'announcement', 'Consultation cancelled',
      'An administrator cancelled a consultation.', jsonb_build_object('consultation_id', p_id));
  end if;
  perform public.notify(v_c.patient_id, 'announcement', 'Consultation cancelled',
    'An administrator cancelled your consultation. Contact support if you have questions.',
    jsonb_build_object('consultation_id', p_id));
end $$;

------------------------------------------------------------------
-- 7. Privileges: callable when signed in; each checks for admin itself.
------------------------------------------------------------------
revoke all on function
  public.assert_admin(), public.audit_row(),
  public.admin_activity(text, text, uuid, int, bigint),
  public.admin_overview(int),
  public.admin_users(text, text, text, int, int),
  public.admin_user_detail(uuid),
  public.admin_set_user_status(uuid, text),
  public.admin_consultations(text, text, int, int),
  public.admin_orders(text, text, int, int),
  public.admin_payments(text, int, int),
  public.admin_sessions(int),
  public.admin_db_stats(),
  public.admin_table_rows(text, int, int),
  public.admin_broadcast(text, text, text),
  public.admin_set_order_status(uuid, text),
  public.admin_cancel_consultation(uuid)
from public, anon;
grant execute on function
  public.admin_activity(text, text, uuid, int, bigint),
  public.admin_overview(int),
  public.admin_users(text, text, text, int, int),
  public.admin_user_detail(uuid),
  public.admin_set_user_status(uuid, text),
  public.admin_consultations(text, text, int, int),
  public.admin_orders(text, text, int, int),
  public.admin_payments(text, int, int),
  public.admin_sessions(int),
  public.admin_db_stats(),
  public.admin_table_rows(text, int, int),
  public.admin_broadcast(text, text, text),
  public.admin_set_order_status(uuid, text),
  public.admin_cancel_consultation(uuid)
to authenticated;
