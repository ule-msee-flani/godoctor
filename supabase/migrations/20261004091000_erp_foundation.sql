-- GoDoctor HQ: the company console (ERP).
--
--   * Staff accounts, each with a role (Administrator, Operations, Medical
--     director, Pharmacy relations, Finance, Support, Compliance) made of
--     permissions an administrator can change.
--   * A permanent, append-only log of what staff did and which records they
--     opened (opening a patient's health details needs a reason).
--   * Company settings, provider payouts with their line items, internal
--     notes on any record, support ticket assignment, licence expiry for
--     pharmacies, and hiding a review's text.
--   * Read-only views of the records, each limited to the staff who have
--     the matching permission (anyone else gets no rows), and functions for
--     every action, each checking the permission and writing to the log.
--
-- Accounts with users.role = 'admin' are always administrators here.

------------------------------------------------------------------
-- 1. Roles and permissions
------------------------------------------------------------------
create table if not exists public.erp_roles (
  key text primary key,
  name text not null,
  description text not null default '',
  sort smallint not null default 0,
  locked boolean not null default false  -- always has every permission
);

create table if not exists public.erp_permissions (
  key text primary key,
  area text not null,
  label text not null,
  sort smallint not null default 0
);

create table if not exists public.erp_role_permissions (
  role text not null references public.erp_roles (key) on delete cascade,
  permission text not null references public.erp_permissions (key) on delete cascade,
  primary key (role, permission)
);

insert into public.erp_roles (key, name, description, sort, locked) values
  ('administrator', 'Administrator', 'Runs GoDoctor HQ: every page and setting, staff and permissions.', 1, true),
  ('operations', 'Operations', 'Keeps consultations and orders moving; verifies providers.', 2, false),
  ('medical', 'Medical director', 'Clinical oversight: doctors, prescriptions, patient health details when needed.', 3, false),
  ('pharmacy', 'Pharmacy relations', 'Onboards and supports pharmacies; handles order problems.', 4, false),
  ('finance', 'Finance', 'Payments, revenue, refunds and provider payouts.', 5, false),
  ('support', 'Support', 'Answers patients, doctors and pharmacies; moderates reviews.', 6, false),
  ('auditor', 'Compliance', 'Read-only: the activity log, staff and finances, for audits.', 7, false)
on conflict (key) do update
  set name = excluded.name, description = excluded.description,
      sort = excluded.sort, locked = excluded.locked;

insert into public.erp_permissions (key, area, label, sort) values
  ('dashboard.view', 'General', 'See the dashboard', 1),
  ('patients.view', 'Patients', 'See patient records (without health details)', 10),
  ('patients.health', 'Patients', 'Open health details (logged, with a reason)', 11),
  ('patients.manage', 'Patients', 'Suspend and restore patient accounts', 12),
  ('providers.view', 'Doctors & pharmacies', 'See doctor and pharmacy records', 20),
  ('providers.verify', 'Doctors & pharmacies', 'Verify licences and documents', 21),
  ('providers.manage', 'Doctors & pharmacies', 'Suspend and restore doctors and pharmacies', 22),
  ('consultations.view', 'Care', 'See consultations', 30),
  ('consultations.manage', 'Care', 'Cancel consultations', 31),
  ('prescriptions.view', 'Care', 'See prescriptions', 32),
  ('orders.view', 'Orders', 'See medicine orders', 40),
  ('orders.manage', 'Orders', 'Change order status and resolve disputes', 41),
  ('finance.view', 'Finance', 'See payments, revenue and payouts', 50),
  ('finance.manage', 'Finance', 'Create and pay out statements, record refunds', 51),
  ('support.view', 'Support', 'See support tickets', 60),
  ('support.manage', 'Support', 'Reply to, assign and close tickets', 61),
  ('reviews.moderate', 'Support', 'Hide and restore review comments', 62),
  ('broadcast.send', 'Support', 'Send announcements to users', 63),
  ('staff.view', 'Company', 'See staff', 70),
  ('staff.manage', 'Company', 'Add staff and change roles and permissions', 71),
  ('audit.view', 'Company', 'See the activity log', 72),
  ('settings.manage', 'Company', 'Change company settings', 73)
on conflict (key) do update
  set area = excluded.area, label = excluded.label, sort = excluded.sort;

insert into public.erp_role_permissions (role, permission)
select r, p from (values
  ('operations', 'dashboard.view'), ('operations', 'patients.view'),
  ('operations', 'providers.view'), ('operations', 'providers.verify'),
  ('operations', 'consultations.view'), ('operations', 'consultations.manage'),
  ('operations', 'prescriptions.view'), ('operations', 'orders.view'),
  ('operations', 'orders.manage'), ('operations', 'support.view'),
  ('operations', 'reviews.moderate'), ('operations', 'broadcast.send'),

  ('medical', 'dashboard.view'), ('medical', 'patients.view'),
  ('medical', 'patients.health'), ('medical', 'providers.view'),
  ('medical', 'providers.verify'), ('medical', 'providers.manage'),
  ('medical', 'consultations.view'), ('medical', 'prescriptions.view'),
  ('medical', 'reviews.moderate'),

  ('pharmacy', 'dashboard.view'), ('pharmacy', 'providers.view'),
  ('pharmacy', 'providers.verify'), ('pharmacy', 'orders.view'),
  ('pharmacy', 'orders.manage'), ('pharmacy', 'prescriptions.view'),
  ('pharmacy', 'support.view'),

  ('finance', 'dashboard.view'), ('finance', 'finance.view'),
  ('finance', 'finance.manage'), ('finance', 'consultations.view'),
  ('finance', 'orders.view'), ('finance', 'providers.view'),
  ('finance', 'audit.view'),

  ('support', 'dashboard.view'), ('support', 'patients.view'),
  ('support', 'providers.view'), ('support', 'consultations.view'),
  ('support', 'orders.view'), ('support', 'support.view'),
  ('support', 'support.manage'), ('support', 'reviews.moderate'),

  ('auditor', 'dashboard.view'), ('auditor', 'audit.view'),
  ('auditor', 'staff.view'), ('auditor', 'finance.view'),
  ('auditor', 'providers.view')
) as v (r, p)
on conflict do nothing;

------------------------------------------------------------------
-- 2. Staff
------------------------------------------------------------------
create table if not exists public.erp_staff (
  user_id uuid primary key references public.users (id) on delete cascade,
  full_name text not null default '',
  job_title text not null default '',
  department text not null default '',
  role text not null references public.erp_roles (key),
  status text not null default 'active' check (status in ('active', 'suspended')),
  phone text,
  created_by uuid,
  created_at timestamptz not null default now(),
  last_active_at timestamptz
);

-- Today's admin accounts are administrators.
insert into public.erp_staff (user_id, full_name, job_title, department, role)
select u.id, coalesce(nullif(split_part(u.email, '@', 1), ''), 'Administrator'),
       'Administrator', 'Management', 'administrator'
from public.users u
where u.role = 'admin'
on conflict (user_id) do nothing;

-- May the signed-in person do [p_permission] in HQ?
create or replace function public.erp_can(p_permission text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.users u
    left join public.erp_staff s on s.user_id = u.id
    where u.id = auth.uid()
      and u.status = 'active'
      and coalesce(s.status, 'active') = 'active'
      and (
        u.role = 'admin'
        or s.role = 'administrator'
        or exists (
          select 1 from public.erp_role_permissions rp
          where rp.role = s.role and rp.permission = p_permission
        )
      )
      and (u.role = 'admin' or s.user_id is not null)
  );
$$;

create or replace function public.erp_assert(p_permission text) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.erp_can(p_permission) then
    raise exception 'not_allowed: %', p_permission using errcode = '42501';
  end if;
end $$;

------------------------------------------------------------------
-- 3. The log: permanent and append-only
------------------------------------------------------------------
create table if not exists public.erp_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor_id uuid,
  action text not null,            -- e.g. doctor.verified, patient.health_viewed
  entity_type text,
  entity_id text,
  summary text not null default '',
  reason text,
  detail jsonb not null default '{}'::jsonb
);
create index if not exists erp_log_at_idx on public.erp_log (at desc);
create index if not exists erp_log_entity_idx on public.erp_log (entity_type, entity_id, at desc);
create index if not exists erp_log_actor_idx on public.erp_log (actor_id, at desc);

create or replace function public.erp_log_locked() returns trigger
language plpgsql as $$
begin
  raise exception 'The activity log can''t be changed or deleted';
end $$;
drop trigger if exists erp_log_append_only on public.erp_log;
create trigger erp_log_append_only before update or delete on public.erp_log
  for each row execute function public.erp_log_locked();

create or replace function public.erp_log_write(
  p_action text, p_entity_type text, p_entity_id text,
  p_summary text, p_reason text default null, p_detail jsonb default '{}'::jsonb
) returns void
language sql security definer set search_path = public as $$
  insert into public.erp_log (actor_id, action, entity_type, entity_id, summary, reason, detail)
  values (auth.uid(), p_action, p_entity_type, p_entity_id, coalesce(p_summary, ''),
          nullif(btrim(coalesce(p_reason, '')), ''), coalesce(p_detail, '{}'::jsonb));
$$;

------------------------------------------------------------------
-- 4. Settings, payouts, notes; extra columns on existing tables
------------------------------------------------------------------
create table if not exists public.erp_settings (
  key text primary key,
  value jsonb not null,
  updated_by uuid,
  updated_at timestamptz not null default now()
);
insert into public.erp_settings (key, value) values
  ('company', jsonb_build_object(
    'name', 'GoDoctor', 'legal_name', '', 'kra_pin', '', 'email', '',
    'phone', '', 'address', 'Nairobi, Kenya', 'website', '')),
  ('commission', jsonb_build_object('consultation_pct', 15, 'order_pct', 8)),
  ('payouts', jsonb_build_object('schedule', 'weekly', 'minimum', 500))
on conflict (key) do nothing;

create table if not exists public.erp_payouts (
  id uuid primary key default gen_random_uuid(),
  number bigint generated always as identity,
  payee_id uuid not null references public.users (id),
  payee_kind text not null check (payee_kind in ('doctor', 'pharmacy')),
  period_start date not null,
  period_end date not null,
  gross numeric(12, 2) not null,
  commission numeric(12, 2) not null,
  net numeric(12, 2) not null,
  items integer not null,
  status text not null default 'pending' check (status in ('pending', 'paid', 'cancelled')),
  reference text,
  paid_at timestamptz,
  paid_by uuid,
  note text,
  created_by uuid,
  created_at timestamptz not null default now()
);
create index if not exists erp_payouts_payee_idx on public.erp_payouts (payee_id, created_at desc);

-- Each consultation or order is paid out once.
create table if not exists public.erp_payout_items (
  payout_id uuid not null references public.erp_payouts (id) on delete cascade,
  source text not null check (source in ('consultation', 'order')),
  source_id uuid not null,
  amount numeric(12, 2) not null,
  primary key (source, source_id)
);

create table if not exists public.erp_notes (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id text not null,
  author_id uuid not null default auth.uid(),
  body text not null check (length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index if not exists erp_notes_entity_idx on public.erp_notes (entity_type, entity_id, created_at desc);

alter table public.support_tickets
  add column if not exists assigned_to uuid references public.users (id),
  add column if not exists priority text not null default 'normal';
do $$ begin
  alter table public.support_tickets
    add constraint support_tickets_priority_check
    check (priority in ('low', 'normal', 'high', 'urgent'));
exception when duplicate_object then null; end $$;

alter table public.chemist_profiles add column if not exists license_expiry date;

alter table public.reviews
  add column if not exists hidden_at timestamptz,
  add column if not exists hidden_by uuid,
  add column if not exists hidden_reason text;

-- A hidden review keeps its stars, but its words no longer show.
create or replace function public.doctor_reviews(
  p_doctor_id uuid, p_limit integer default 20, p_offset integer default 0
) returns table (id uuid, rating integer, comment text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.rating, case when r.hidden_at is null then r.comment end, r.created_at
  from public.reviews r
  join public.consultations c on c.id = r.consultation_id
  where c.doctor_id = p_doctor_id
  order by r.created_at desc
  limit least(greatest(p_limit, 1), 50) offset greatest(p_offset, 0);
$$;

create or replace function public.chemist_reviews(
  p_chemist uuid, p_limit integer default 20, p_offset integer default 0
) returns table (id uuid, rating integer, comment text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.rating, case when r.hidden_at is null then r.comment end, r.created_at
  from public.reviews r
  join public.orders o on o.id = r.order_id
  where o.chemist_id = p_chemist
  order by r.created_at desc
  limit least(greatest(p_limit, 1), 50) offset greatest(p_offset, 0);
$$;

-- HQ tables are reached only through the views and functions below.
alter table public.erp_roles enable row level security;
alter table public.erp_permissions enable row level security;
alter table public.erp_role_permissions enable row level security;
alter table public.erp_staff enable row level security;
alter table public.erp_log enable row level security;
alter table public.erp_settings enable row level security;
alter table public.erp_payouts enable row level security;
alter table public.erp_payout_items enable row level security;
alter table public.erp_notes enable row level security;
revoke all on public.erp_roles, public.erp_permissions, public.erp_role_permissions,
  public.erp_staff, public.erp_log, public.erp_settings, public.erp_payouts,
  public.erp_payout_items, public.erp_notes
  from anon, authenticated;

-- Staff with providers.verify can open licence documents.
drop policy if exists "verification docs: HQ read" on storage.objects;
create policy "verification docs: HQ read" on storage.objects
  for select to authenticated
  using (bucket_id = 'verification-documents' and public.erp_can('providers.verify'));

------------------------------------------------------------------
-- 5. Views (each returns rows only to staff with the permission)
------------------------------------------------------------------
create or replace view public.erp_patients as
select u.id, p.name, u.email, coalesce(u.contact_phone, u.phone) as phone, p.gender,
       date_part('year', age(p.date_of_birth))::int as age,
       coalesce(nullif(p.county, ''), p.location_name) as location,
       u.status::text as status, u.created_at as joined_at, u.last_seen_at,
       (select count(*) from public.consultations c where c.patient_id = u.id)::int as consultations,
       (select count(*) from public.orders o where o.patient_id = u.id)::int as orders,
       coalesce((
         select sum(pm.amount) from public.payments pm
         left join public.consultations c on c.id = pm.consultation_id
         left join public.orders o on o.id = pm.order_id
         where pm.status = 'succeeded' and coalesce(c.patient_id, o.patient_id) = u.id
       ), 0)::numeric as spent
from public.users u
join public.patient_profiles p on p.user_id = u.id
where u.role = 'patient' and (select public.erp_can('patients.view'));

create or replace view public.erp_doctors as
select u.id, d.name, u.email, coalesce(u.contact_phone, u.phone) as phone,
       array_to_string(d.specialties, ', ') as specialties,
       d.license_number, d.license_expiry, d.license_verified as verified,
       case
         when d.license_verified is not true then 'pending'
         when d.license_expiry is null then 'no_expiry'
         when d.license_expiry < current_date then 'expired'
         when d.license_expiry < current_date + 60 then 'expiring'
         else 'valid'
       end as licence_state,
       d.status::text as availability, u.status::text as account_status,
       d.rating_avg, coalesce(d.rating_count, 0) as rating_count, d.consultation_fee,
       d.practice_facility, d.practice_county, d.years_experience,
       coalesce(array_length(d.verification_documents, 1), 0) as documents,
       d.attested_at,
       (select count(*) from public.consultations c
         where c.doctor_id = u.id and c.status = 'completed')::int as consultations,
       coalesce((select sum(c.fee_amount) from public.consultations c
         where c.doctor_id = u.id and c.status = 'completed'), 0)::numeric as earned,
       u.created_at as joined_at, u.last_seen_at
from public.users u
join public.doctor_profiles d on d.user_id = u.id
where u.role = 'doctor' and (select public.erp_can('providers.view'));

create or replace view public.erp_pharmacies as
select u.id, cp.business_name as name, cp.pharmacist_name, u.email,
       coalesce(u.contact_phone, u.phone) as phone,
       cp.registration_number, cp.license_expiry, cp.verified,
       case
         when cp.verified is not true then 'pending'
         when cp.license_expiry is null then 'no_expiry'
         when cp.license_expiry < current_date then 'expired'
         when cp.license_expiry < current_date + 60 then 'expiring'
         else 'valid'
       end as licence_state,
       cp.location_name, cp.offers_delivery, cp.mpesa_till,
       u.status::text as account_status,
       coalesce(array_length(cp.verification_documents, 1), 0) as documents,
       cp.attested_at,
       (select count(*) from public.orders o
         where o.chemist_id = u.id and o.status = 'fulfilled')::int as orders,
       coalesce((select sum(o.total_amount) from public.orders o
         where o.chemist_id = u.id and o.status = 'fulfilled'), 0)::numeric as revenue,
       (select round(avg(r.rating)::numeric, 1) from public.reviews r
         join public.orders o on o.id = r.order_id where o.chemist_id = u.id) as rating,
       (select count(*) from public.chemist_inventory i
         where i.chemist_id = u.id and i.quantity > 0)::int as in_stock,
       (select count(*) from public.chemist_inventory i
         where i.chemist_id = u.id and i.quantity = 0)::int as out_of_stock,
       u.created_at as joined_at, u.last_seen_at
from public.users u
join public.chemist_profiles cp on cp.user_id = u.id
where u.role = 'chemist' and (select public.erp_can('providers.view'));

create or replace view public.erp_consultations as
select c.id, c.created_at, c.patient_id, pp.name as patient_name,
       c.doctor_id, dp.name as doctor_name, c.specialty_requested as specialty,
       c.status::text as status, c.mode::text as mode, c.fee_amount,
       c.scheduled_for, c.started_at, c.ended_at,
       (select pm.status::text from public.payments pm
         where pm.consultation_id = c.id order by pm.created_at desc limit 1) as payment_status,
       exists (select 1 from public.prescriptions pr where pr.consultation_id = c.id) as prescribed,
       coalesce((select f.flagged_emergency from public.intake_forms f
         where f.consultation_id = c.id), false) as emergency,
       (select r.rating from public.reviews r where r.consultation_id = c.id limit 1) as rating
from public.consultations c
left join public.patient_profiles pp on pp.user_id = c.patient_id
left join public.doctor_profiles dp on dp.user_id = c.doctor_id
where (select public.erp_can('consultations.view'));

create or replace view public.erp_orders as
select o.id, o.created_at, o.patient_id, pp.name as patient_name,
       o.chemist_id, cp.business_name as pharmacy_name,
       o.status::text as status, o.total_amount, o.escrow_status::text as escrow_status,
       o.fulfillment_type::text as fulfillment, o.problem_note,
       (select count(*) from public.order_items i where i.order_id = o.id)::int as items,
       o.prescription_id is not null as with_prescription,
       (select pm.status::text from public.payments pm
         where pm.order_id = o.id order by pm.created_at desc limit 1) as payment_status,
       o.confirmed_at, o.ready_at, o.fulfilled_at
from public.orders o
left join public.patient_profiles pp on pp.user_id = o.patient_id
left join public.chemist_profiles cp on cp.user_id = o.chemist_id
where (select public.erp_can('orders.view'));

create or replace view public.erp_payments as
select pm.id, pm.created_at, pm.amount, pm.provider::text as provider,
       pm.status::text as status, pm.is_simulated as test,
       pm.mpesa_receipt_number as receipt, pm.escrow_release_at,
       case when pm.consultation_id is not null then 'consultation' else 'order' end as kind,
       coalesce(pm.consultation_id, pm.order_id) as source_id,
       coalesce(pc.name, po.name) as payer_name,
       coalesce(c.patient_id, o.patient_id) as payer_id,
       coalesce(dp.name, cp.business_name) as payee_name,
       coalesce(c.doctor_id, o.chemist_id) as payee_id
from public.payments pm
left join public.consultations c on c.id = pm.consultation_id
left join public.orders o on o.id = pm.order_id
left join public.patient_profiles pc on pc.user_id = c.patient_id
left join public.patient_profiles po on po.user_id = o.patient_id
left join public.doctor_profiles dp on dp.user_id = c.doctor_id
left join public.chemist_profiles cp on cp.user_id = o.chemist_id
where (select public.erp_can('finance.view'));

create or replace view public.erp_prescriptions as
select pr.id, pr.issued_at, pr.patient_id, pp.name as patient_name,
       pr.doctor_id, dp.name as doctor_name, pr.source::text as source, pr.valid_until,
       pr.consultation_id,
       (select count(*) from public.prescription_items i where i.prescription_id = pr.id)::int as items,
       exists (select 1 from public.orders o where o.prescription_id = pr.id) as ordered
from public.prescriptions pr
left join public.patient_profiles pp on pp.user_id = pr.patient_id
left join public.doctor_profiles dp on dp.user_id = pr.doctor_id
where (select public.erp_can('prescriptions.view'));

create or replace view public.erp_tickets as
select t.id, t.created_at, t.user_id,
       coalesce(nullif(pp.name, ''), nullif(dp.name, ''), nullif(cp.business_name, ''), u.email) as user_name,
       u.role::text as user_role, t.kind, t.subject, t.status, t.priority,
       t.assigned_to, s.full_name as assignee_name, t.last_message_at,
       t.related_consultation_id, t.related_order_id,
       (select count(*) from public.support_messages m where m.ticket_id = t.id)::int as messages,
       coalesce((select m.from_staff from public.support_messages m
         where m.ticket_id = t.id order by m.created_at desc limit 1), false) as last_from_staff
from public.support_tickets t
join public.users u on u.id = t.user_id
left join public.patient_profiles pp on pp.user_id = t.user_id
left join public.doctor_profiles dp on dp.user_id = t.user_id
left join public.chemist_profiles cp on cp.user_id = t.user_id
left join public.erp_staff s on s.user_id = t.assigned_to
where (select public.erp_can('support.view'));

create or replace view public.erp_ticket_messages as
select m.id, m.ticket_id, m.created_at, m.body, m.from_staff, m.sender_id,
       case when m.from_staff then coalesce(s.full_name, 'GoDoctor support')
            else coalesce(nullif(pp.name, ''), nullif(dp.name, ''), nullif(cp.business_name, ''), 'User')
       end as sender_name
from public.support_messages m
left join public.erp_staff s on s.user_id = m.sender_id
left join public.patient_profiles pp on pp.user_id = m.sender_id
left join public.doctor_profiles dp on dp.user_id = m.sender_id
left join public.chemist_profiles cp on cp.user_id = m.sender_id
where (select public.erp_can('support.view'));

create or replace view public.erp_reviews as
select r.id, r.created_at, r.rating, r.comment, r.hidden_at is not null as hidden,
       r.hidden_reason, r.author_id, pa.name as author_name,
       case when r.consultation_id is not null then 'doctor' else 'pharmacy' end as target_kind,
       coalesce(dp.name, cp.business_name) as target_name,
       coalesce(c.doctor_id, o.chemist_id) as target_id
from public.reviews r
left join public.consultations c on c.id = r.consultation_id
left join public.orders o on o.id = r.order_id
left join public.patient_profiles pa on pa.user_id = r.author_id
left join public.doctor_profiles dp on dp.user_id = c.doctor_id
left join public.chemist_profiles cp on cp.user_id = o.chemist_id
where (select public.erp_can('reviews.moderate') or public.erp_can('providers.view'));

create or replace view public.erp_staff_list as
select s.user_id as id, s.full_name, u.email, s.phone, s.job_title, s.department,
       s.role, r.name as role_name, s.status, u.status::text as account_status,
       s.created_at, s.last_active_at, cb.full_name as added_by
from public.erp_staff s
join public.users u on u.id = s.user_id
join public.erp_roles r on r.key = s.role
left join public.erp_staff cb on cb.user_id = s.created_by
where (select public.erp_can('staff.view') or public.erp_can('support.manage'));

create or replace view public.erp_role_list as
select r.key, r.name, r.description, r.sort, r.locked,
       coalesce(array(select rp.permission from public.erp_role_permissions rp
                      where rp.role = r.key order by rp.permission), '{}') as permissions,
       (select count(*) from public.erp_staff s where s.role = r.key)::int as staff
from public.erp_roles r
where (select public.erp_can('staff.view'));

create or replace view public.erp_permission_list as
select p.key, p.area, p.label, p.sort
from public.erp_permissions p
where (select public.erp_can('staff.view'));

create or replace view public.erp_activity as
select l.id, l.at, l.actor_id, coalesce(s.full_name, 'System') as actor_name,
       r.name as actor_role, l.action, l.entity_type, l.entity_id, l.summary, l.reason
from public.erp_log l
left join public.erp_staff s on s.user_id = l.actor_id
left join public.erp_roles r on r.key = s.role
where (select public.erp_can('audit.view'));

-- Every change to app data (the last 30 days), with who made it.
create or replace view public.erp_data_changes as
select a.id, a.at, a.actor_id,
       coalesce(nullif(s.full_name, ''), nullif(pp.name, ''), nullif(dp.name, ''),
                nullif(cp.business_name, ''), u.email,
                case when a.actor_id is null then 'System' end) as actor_name,
       u.role::text as actor_role, a.table_name, a.op, a.row_id, a.changed
from public.audit_log a
left join public.users u on u.id = a.actor_id
left join public.erp_staff s on s.user_id = a.actor_id
left join public.patient_profiles pp on pp.user_id = a.actor_id
left join public.doctor_profiles dp on dp.user_id = a.actor_id
left join public.chemist_profiles cp on cp.user_id = a.actor_id
where (select public.erp_can('audit.view'));

create or replace view public.erp_payout_list as
select p.id, p.number, p.payee_id, p.payee_kind,
       coalesce(dp.name, cp.business_name) as payee_name,
       coalesce(cp.mpesa_till, u.contact_phone, u.phone) as pay_to,
       p.period_start, p.period_end, p.gross, p.commission, p.net, p.items,
       p.status, p.reference, p.paid_at, p.note, p.created_at,
       pb.full_name as paid_by_name, cb.full_name as created_by_name
from public.erp_payouts p
join public.users u on u.id = p.payee_id
left join public.doctor_profiles dp on dp.user_id = p.payee_id
left join public.chemist_profiles cp on cp.user_id = p.payee_id
left join public.erp_staff pb on pb.user_id = p.paid_by
left join public.erp_staff cb on cb.user_id = p.created_by
where (select public.erp_can('finance.view'));

create or replace view public.erp_note_list as
select n.id, n.entity_type, n.entity_id, n.body, n.created_at, n.author_id,
       coalesce(s.full_name, 'Staff') as author_name
from public.erp_notes n
left join public.erp_staff s on s.user_id = n.author_id
where (select public.erp_can('dashboard.view'));

do $$
declare v text;
begin
  foreach v in array array[
    'erp_patients', 'erp_doctors', 'erp_pharmacies', 'erp_consultations',
    'erp_orders', 'erp_payments', 'erp_prescriptions', 'erp_tickets',
    'erp_ticket_messages', 'erp_reviews', 'erp_staff_list', 'erp_role_list',
    'erp_permission_list', 'erp_activity', 'erp_data_changes',
    'erp_payout_list', 'erp_note_list'
  ] loop
    execute format('revoke all on public.%I from public, anon', v);
    execute format('grant select on public.%I to authenticated', v);
  end loop;
end $$;

------------------------------------------------------------------
-- 6. Functions: who I am, the dashboard, record details
------------------------------------------------------------------
create or replace function public.erp_me() returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_staff record; v_user record; v_perms text[];
begin
  select * into v_user from users where id = auth.uid();
  if v_user.id is null or v_user.status <> 'active' then return null; end if;
  select * into v_staff from erp_staff where user_id = auth.uid();
  if v_staff.user_id is null and v_user.role <> 'admin' then return null; end if;
  if v_staff.user_id is not null and v_staff.status <> 'active' then return null; end if;

  if v_user.role = 'admin' or v_staff.role = 'administrator' then
    select array_agg(key order by sort) into v_perms from erp_permissions;
  else
    select array_agg(permission order by permission) into v_perms
    from erp_role_permissions where role = v_staff.role;
  end if;

  update erp_staff set last_active_at = now() where user_id = auth.uid();

  return jsonb_build_object(
    'id', v_user.id,
    'email', v_user.email,
    'full_name', coalesce(nullif(v_staff.full_name, ''), split_part(coalesce(v_user.email, ''), '@', 1)),
    'job_title', coalesce(v_staff.job_title, ''),
    'department', coalesce(v_staff.department, ''),
    'role', coalesce(v_staff.role, 'administrator'),
    'role_name', coalesce((select name from erp_roles where key = coalesce(v_staff.role, 'administrator')), 'Administrator'),
    'permissions', coalesce(to_jsonb(v_perms), '[]'::jsonb)
  );
end $$;

create or replace function public.erp_dashboard(p_days int default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 7), 365);
  v_from timestamptz := date_trunc('day', now()) - make_interval(days => v_days - 1);
  v_finance boolean := public.erp_can('finance.view');
  v_result jsonb;
begin
  perform public.erp_assert('dashboard.view');
  select jsonb_build_object(
    'days', v_days,
    'patients', (select count(*) from users where role = 'patient'),
    'patients_new', (select count(*) from users where role = 'patient' and created_at >= v_from),
    'doctors', (select count(*) from doctor_profiles where license_verified),
    'doctors_pending', (select count(*) from doctor_profiles d join users u on u.id = d.user_id
                        where not d.license_verified and u.status = 'active'),
    'doctors_online', (select count(*) from doctor_profiles where status in ('available', 'offered', 'busy')),
    'pharmacies', (select count(*) from chemist_profiles where verified),
    'pharmacies_pending', (select count(*) from chemist_profiles c join users u on u.id = c.user_id
                           where not c.verified and u.status = 'active'),
    'consultations', (select count(*) from consultations where created_at >= v_from),
    'consultations_completed', (select count(*) from consultations where created_at >= v_from and status = 'completed'),
    'consultations_live', (select count(*) from consultations where status in ('matched', 'in_progress')),
    'orders', (select count(*) from orders where created_at >= v_from),
    'orders_open', (select count(*) from orders where status in ('placed', 'confirmed', 'ready')),
    'orders_disputed', (select count(*) from orders where status = 'disputed'),
    'tickets_open', (select count(*) from support_tickets where status <> 'closed'),
    'licences_attention', (
      (select count(*) from doctor_profiles where license_verified and license_expiry < current_date + 60)
      + (select count(*) from chemist_profiles where verified and license_expiry < current_date + 60)),
    'revenue', case when v_finance then (select coalesce(sum(amount), 0) from payments
                     where status = 'succeeded' and created_at >= v_from) end,
    'escrow_held', case when v_finance then (select coalesce(sum(total_amount), 0) from orders
                     where escrow_status = 'held' and status not in ('refunded')) end,
    'payouts_pending', case when v_finance then (select coalesce(sum(net), 0) from erp_payouts
                     where status = 'pending') end,
    'series', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'day', to_char(d, 'YYYY-MM-DD'),
        'consultations', (select count(*) from consultations c
                          where c.created_at >= d and c.created_at < d + interval '1 day'),
        'orders', (select count(*) from orders o
                   where o.created_at >= d and o.created_at < d + interval '1 day'),
        'revenue', case when v_finance then (select coalesce(sum(amount), 0) from payments pm
                   where pm.status = 'succeeded' and pm.created_at >= d
                     and pm.created_at < d + interval '1 day') end
      ) order by d), '[]'::jsonb)
      from generate_series(v_from, date_trunc('day', now()), interval '1 day') d
    ),
    'specialties', (
      select coalesce(jsonb_agg(jsonb_build_object('name', s, 'count', n) order by n desc), '[]'::jsonb)
      from (select specialty_requested s, count(*) n from consultations
            where created_at >= v_from group by 1 order by 2 desc limit 6) x
    )
  ) into v_result;
  return v_result;
end $$;

-- A patient's record (no health details); opening it is logged.
create or replace function public.erp_patient(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  perform public.erp_assert('patients.view');
  select jsonb_build_object(
    'id', u.id, 'name', p.name, 'email', u.email,
    'phone', coalesce(u.contact_phone, u.phone), 'gender', p.gender,
    'date_of_birth', p.date_of_birth, 'county', p.county, 'location', p.location_name,
    'status', u.status, 'joined_at', u.created_at, 'last_seen_at', u.last_seen_at,
    'avatar_url', u.avatar_url, 'heard_from', p.heard_from,
    'health_cover', p.health_cover, 'onboarded_at', u.onboarded_at
  ) into v
  from users u join patient_profiles p on p.user_id = u.id
  where u.id = p_id;
  if v is null then raise exception 'not_found'; end if;
  perform public.erp_log_write('patient.opened', 'patient', p_id::text,
    'Opened the record of ' || coalesce(nullif(v ->> 'name', ''), 'a patient'));
  return v;
end $$;

-- Health details: only with patients.health, and always with a reason.
create or replace function public.erp_patient_health(p_id uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v jsonb;
begin
  perform public.erp_assert('patients.health');
  if length(btrim(coalesce(p_reason, ''))) < 3 then raise exception 'reason_required'; end if;
  select jsonb_build_object(
    'allergies', p.allergies, 'current_medications', p.current_medications,
    'chronic_conditions', p.chronic_conditions, 'blood_group', p.blood_group,
    'height_cm', p.height_cm, 'weight_kg', p.weight_kg,
    'emergency_contact_name', p.emergency_contact_name,
    'emergency_contact_phone', p.emergency_contact_phone,
    'readings', coalesce((
      select jsonb_agg(jsonb_build_object('kind', r.kind, 'value', r.value,
        'value2', r.value2, 'taken_at', r.taken_at) order by r.taken_at desc)
      from (select * from health_readings h where h.patient_id = p_id
            order by h.taken_at desc limit 6) r), '[]'::jsonb)
  ) into v
  from patient_profiles p where p.user_id = p_id;
  if v is null then raise exception 'not_found'; end if;
  perform public.erp_log_write('patient.health_viewed', 'patient', p_id::text,
    'Opened health details of ' || coalesce((select nullif(name, '') from patient_profiles where user_id = p_id), 'a patient'),
    p_reason);
  return v;
end $$;

-- A consultation's clinical notes (symptoms, summary, prescription lines).
create or replace function public.erp_consultation_clinical(p_id uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v jsonb; v_patient uuid;
begin
  perform public.erp_assert('patients.health');
  if length(btrim(coalesce(p_reason, ''))) < 3 then raise exception 'reason_required'; end if;
  select patient_id into v_patient from consultations where id = p_id;
  if v_patient is null then raise exception 'not_found'; end if;
  select jsonb_build_object(
    'symptoms', c.symptom_summary, 'summary', c.summary_for_patient,
    'red_flags', c.red_flags, 'follow_up_on', c.follow_up_on,
    'intake', (select jsonb_build_object('symptoms', f.symptoms, 'duration', f.duration,
               'severity', f.severity, 'emergency', f.flagged_emergency)
               from intake_forms f where f.consultation_id = c.id),
    'prescriptions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'issued_at', pr.issued_at, 'valid_until', pr.valid_until,
        'items', (select coalesce(jsonb_agg(jsonb_build_object(
                    'name', coalesce(d.generic_name, i.free_text_name),
                    'dosage', i.dosage, 'quantity', i.quantity, 'instructions', i.instructions)), '[]'::jsonb)
                  from prescription_items i left join drugs d on d.id = i.drug_id
                  where i.prescription_id = pr.id)))
      from prescriptions pr where pr.consultation_id = c.id), '[]'::jsonb)
  ) into v
  from consultations c where c.id = p_id;
  perform public.erp_log_write('consultation.clinical_viewed', 'consultation', p_id::text,
    'Opened clinical notes of a consultation', p_reason, jsonb_build_object('patient_id', v_patient));
  return v;
end $$;

-- The licence documents a provider uploaded (paths in the private bucket).
create or replace function public.erp_provider_documents(p_id uuid) returns text[]
language plpgsql stable security definer set search_path = public as $$
declare v text[];
begin
  perform public.erp_assert('providers.verify');
  select coalesce(d.verification_documents, c.verification_documents, '{}') into v
  from users u
  left join doctor_profiles d on d.user_id = u.id
  left join chemist_profiles c on c.user_id = u.id
  where u.id = p_id;
  return coalesce(v, '{}');
end $$;

------------------------------------------------------------------
-- 7. Actions
------------------------------------------------------------------
create or replace function public.erp_set_account_status(p_user uuid, p_status text, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_role user_role; v_name text;
begin
  if p_status not in ('active', 'suspended') then raise exception 'invalid_status'; end if;
  select role into v_role from users where id = p_user;
  if v_role is null then raise exception 'not_found'; end if;
  if p_user = auth.uid() then raise exception 'cannot_change_own_account'; end if;
  if v_role = 'admin' then raise exception 'cannot_suspend_admin'; end if;
  perform public.erp_assert(case v_role
    when 'patient' then 'patients.manage'
    when 'staff' then 'staff.manage'
    else 'providers.manage' end);
  if p_status = 'suspended' and length(btrim(coalesce(p_reason, ''))) < 3 then
    raise exception 'reason_required';
  end if;

  update users set status = p_status::user_status where id = p_user;
  if p_status = 'suspended' then
    update auth.users set banned_until = 'infinity' where id = p_user;
    delete from auth.sessions where user_id = p_user;
    update doctor_profiles set status = 'offline' where user_id = p_user and status = 'available';
  else
    update auth.users set banned_until = null where id = p_user;
    if v_role <> 'staff' then
      perform public.notify(p_user, 'announcement', 'Your account is active again',
                            'You can use GoDoctor as normal.', '{}'::jsonb);
    end if;
  end if;
  if v_role = 'staff' then
    update erp_staff set status = p_status where user_id = p_user;
  end if;

  select coalesce(nullif(s.full_name, ''), nullif(p.name, ''), nullif(d.name, ''), nullif(c.business_name, ''), u.email)
  into v_name
  from users u
  left join erp_staff s on s.user_id = u.id
  left join patient_profiles p on p.user_id = u.id
  left join doctor_profiles d on d.user_id = u.id
  left join chemist_profiles c on c.user_id = u.id
  where u.id = p_user;
  perform public.erp_log_write(
    case when p_status = 'suspended' then 'account.suspended' else 'account.restored' end,
    v_role::text, p_user::text,
    case when p_status = 'suspended' then 'Suspended ' else 'Restored ' end || coalesce(v_name, 'an account'),
    p_reason);
end $$;

create or replace function public.erp_verify_provider(p_user uuid, p_verified boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_role user_role; v_name text;
begin
  perform public.erp_assert('providers.verify');
  select role into v_role from users where id = p_user;
  if v_role = 'doctor' then
    update doctor_profiles set license_verified = p_verified where user_id = p_user
    returning name into v_name;
  elsif v_role = 'chemist' then
    update chemist_profiles as cp set verified = p_verified where cp.user_id = p_user
    returning business_name into v_name;
  else
    raise exception 'not_a_provider';
  end if;
  perform public.erp_log_write(
    case when p_verified then 'provider.verified' else 'provider.unverified' end,
    case when v_role = 'doctor' then 'doctor' else 'pharmacy' end, p_user::text,
    case when p_verified then 'Verified ' else 'Removed verification from ' end || coalesce(nullif(v_name, ''), 'a provider'),
    p_note);
end $$;

create or replace function public.erp_set_licence(p_user uuid, p_number text, p_expiry date)
returns void language plpgsql security definer set search_path = public as $$
declare v_role user_role; v_name text;
begin
  perform public.erp_assert('providers.verify');
  select role into v_role from users where id = p_user;
  if v_role = 'doctor' then
    update doctor_profiles set license_number = nullif(btrim(p_number), ''), license_expiry = p_expiry
    where user_id = p_user returning name into v_name;
  elsif v_role = 'chemist' then
    update chemist_profiles set registration_number = nullif(btrim(p_number), ''), license_expiry = p_expiry
    where user_id = p_user returning business_name into v_name;
  else
    raise exception 'not_a_provider';
  end if;
  perform public.erp_log_write('provider.licence_updated',
    case when v_role = 'doctor' then 'doctor' else 'pharmacy' end, p_user::text,
    'Updated the licence of ' || coalesce(nullif(v_name, ''), 'a provider'), null,
    jsonb_build_object('number', p_number, 'expiry', p_expiry));
end $$;

create or replace function public.erp_cancel_consultation(p_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_c record;
begin
  perform public.erp_assert('consultations.manage');
  if length(btrim(coalesce(p_reason, ''))) < 3 then raise exception 'reason_required'; end if;
  select * into v_c from consultations where id = p_id;
  if v_c.id is null then raise exception 'not_found'; end if;
  if v_c.status in ('completed', 'cancelled') then raise exception 'already_finished'; end if;
  update consultations set status = 'cancelled', ended_at = now() where id = p_id;
  if v_c.doctor_id is not null then
    update doctor_profiles set status = 'available', last_available_at = now()
    where user_id = v_c.doctor_id and status = 'busy';
    perform public.notify(v_c.doctor_id, 'announcement', 'Consultation cancelled',
      'GoDoctor cancelled a consultation.', jsonb_build_object('consultation_id', p_id));
  end if;
  perform public.notify(v_c.patient_id, 'announcement', 'Consultation cancelled',
    'GoDoctor cancelled your consultation. Contact support if you have questions.',
    jsonb_build_object('consultation_id', p_id));
  perform public.erp_log_write('consultation.cancelled', 'consultation', p_id::text,
    'Cancelled a ' || coalesce(v_c.specialty_requested, '') || ' consultation', p_reason);
end $$;

create or replace function public.erp_set_order_status(p_id uuid, p_status text, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_o record;
begin
  perform public.erp_assert('orders.manage');
  if p_status not in ('placed', 'confirmed', 'ready', 'fulfilled', 'disputed', 'refunded') then
    raise exception 'invalid_status';
  end if;
  if p_status = 'refunded' then perform public.erp_assert('finance.manage'); end if;
  select * into v_o from orders where id = p_id;
  if v_o.id is null then raise exception 'not_found'; end if;
  update orders
  set status = p_status::order_status,
      escrow_status = case p_status when 'refunded' then 'refunded'::escrow_status
                                    when 'fulfilled' then 'released'::escrow_status
                                    else escrow_status end,
      fulfilled_at = case when p_status = 'fulfilled' then coalesce(fulfilled_at, now()) else fulfilled_at end
  where id = p_id;
  if p_status = 'refunded' then
    update payments set status = 'refunded' where order_id = p_id and status = 'succeeded';
  end if;
  perform public.notify(v_o.patient_id, 'announcement', 'Order update',
    'Your order is now ' || replace(p_status, '_', ' ') || '.', jsonb_build_object('order_id', p_id));
  perform public.erp_log_write('order.status_changed', 'order', p_id::text,
    'Changed an order from ' || v_o.status || ' to ' || p_status, p_reason);
end $$;

create or replace function public.erp_record_refund(p_payment uuid, p_reference text, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v_p record; v_payer uuid;
begin
  perform public.erp_assert('finance.manage');
  if length(btrim(coalesce(p_reason, ''))) < 3 then raise exception 'reason_required'; end if;
  select * into v_p from payments where id = p_payment;
  if v_p.id is null then raise exception 'not_found'; end if;
  if v_p.status = 'refunded' then raise exception 'already_refunded'; end if;
  if v_p.status <> 'succeeded' then raise exception 'not_paid'; end if;
  update payments set status = 'refunded' where id = p_payment;
  if v_p.order_id is not null then
    update orders set status = 'refunded', escrow_status = 'refunded' where id = v_p.order_id
    returning patient_id into v_payer;
  else
    select patient_id into v_payer from consultations where id = v_p.consultation_id;
  end if;
  if v_payer is not null then
    perform public.notify(v_payer, 'announcement', 'Refund on its way',
      'GoDoctor has refunded KES ' || to_char(v_p.amount, 'FM999,999,990') || ' to you.',
      jsonb_build_object('payment_id', p_payment));
  end if;
  perform public.erp_log_write('payment.refunded', 'payment', p_payment::text,
    'Recorded a refund of KES ' || to_char(v_p.amount, 'FM999,999,990'), p_reason,
    jsonb_build_object('reference', p_reference));
end $$;

-- Statements for doctors and pharmacies: everything earned in the period
-- that hasn't been paid out yet, less GoDoctor's commission.
create or replace function public.erp_generate_payouts(p_from date, p_to date)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_cpct numeric := coalesce(((select value from erp_settings where key = 'commission') ->> 'consultation_pct')::numeric, 15);
  v_opct numeric := coalesce(((select value from erp_settings where key = 'commission') ->> 'order_pct')::numeric, 8);
  v_payee record; v_id uuid; v_count int := 0;
begin
  perform public.erp_assert('finance.manage');
  if p_from is null or p_to is null or p_to < p_from then raise exception 'invalid_period'; end if;

  create temporary table _earned on commit drop as
  select 'consultation'::text as source, c.id as source_id, c.doctor_id as payee_id,
         'doctor'::text as payee_kind, c.fee_amount::numeric as amount, v_cpct as pct
  from consultations c
  where c.status = 'completed' and c.doctor_id is not null and coalesce(c.fee_amount, 0) > 0
    and coalesce(c.ended_at, c.updated_at)::date between p_from and p_to
    and exists (select 1 from payments pm where pm.consultation_id = c.id and pm.status = 'succeeded')
    and not exists (select 1 from erp_payout_items i where i.source = 'consultation' and i.source_id = c.id)
  union all
  select 'order', o.id, o.chemist_id, 'pharmacy', o.total_amount, v_opct
  from orders o
  where o.status = 'fulfilled' and o.chemist_id is not null and coalesce(o.total_amount, 0) > 0
    and coalesce(o.fulfilled_at, o.updated_at)::date between p_from and p_to
    and not exists (select 1 from erp_payout_items i where i.source = 'order' and i.source_id = o.id);

  for v_payee in
    select payee_id, payee_kind, sum(amount) as gross,
           round(sum(amount * pct / 100), 2) as commission, count(*) as n
    from _earned group by payee_id, payee_kind
  loop
    insert into erp_payouts (payee_id, payee_kind, period_start, period_end,
                             gross, commission, net, items, created_by)
    values (v_payee.payee_id, v_payee.payee_kind, p_from, p_to, v_payee.gross,
            v_payee.commission, v_payee.gross - v_payee.commission, v_payee.n, auth.uid())
    returning id into v_id;
    insert into erp_payout_items (payout_id, source, source_id, amount)
    select v_id, source, source_id, amount from _earned where payee_id = v_payee.payee_id;
    v_count := v_count + 1;
  end loop;

  perform public.erp_log_write('payouts.generated', 'payout', null,
    'Created ' || v_count || ' payout statement' || case when v_count = 1 then '' else 's' end
      || ' for ' || to_char(p_from, 'DD Mon') || ' – ' || to_char(p_to, 'DD Mon YYYY'));
  return v_count;
end $$;

create or replace function public.erp_payout_paid(p_id uuid, p_reference text)
returns void language plpgsql security definer set search_path = public as $$
declare v record;
begin
  perform public.erp_assert('finance.manage');
  if length(btrim(coalesce(p_reference, ''))) < 3 then raise exception 'reference_required'; end if;
  update erp_payouts set status = 'paid', reference = btrim(p_reference), paid_at = now(), paid_by = auth.uid()
  where id = p_id and status = 'pending'
  returning * into v;
  if v.id is null then raise exception 'not_pending'; end if;
  perform public.notify(v.payee_id, 'announcement', 'Payout sent',
    'GoDoctor sent you KES ' || to_char(v.net, 'FM999,999,990') || ' (ref ' || btrim(p_reference) || ').',
    jsonb_build_object('payout_id', p_id));
  perform public.erp_log_write('payout.paid', 'payout', p_id::text,
    'Paid out KES ' || to_char(v.net, 'FM999,999,990') || ' (PO-' || lpad(v.number::text, 4, '0') || ')',
    null, jsonb_build_object('reference', p_reference));
end $$;

create or replace function public.erp_payout_cancel(p_id uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare v record;
begin
  perform public.erp_assert('finance.manage');
  update erp_payouts set status = 'cancelled', note = p_reason
  where id = p_id and status = 'pending' returning * into v;
  if v.id is null then raise exception 'not_pending'; end if;
  -- Its items can go on a new statement.
  delete from erp_payout_items where payout_id = p_id;
  perform public.erp_log_write('payout.cancelled', 'payout', p_id::text,
    'Cancelled PO-' || lpad(v.number::text, 4, '0'), p_reason);
end $$;

create or replace function public.erp_ticket_update(
  p_id uuid, p_status text default null, p_priority text default null,
  p_assignee uuid default null, p_unassign boolean default false
) returns void language plpgsql security definer set search_path = public as $$
declare v record;
begin
  perform public.erp_assert('support.manage');
  if p_status is not null and p_status not in ('open', 'answered', 'closed') then raise exception 'invalid_status'; end if;
  if p_priority is not null and p_priority not in ('low', 'normal', 'high', 'urgent') then raise exception 'invalid_priority'; end if;
  if p_assignee is not null and not exists (select 1 from erp_staff where user_id = p_assignee and status = 'active') then
    raise exception 'not_staff';
  end if;
  update support_tickets set
    status = coalesce(p_status, status),
    priority = coalesce(p_priority, priority),
    assigned_to = case when p_unassign then null else coalesce(p_assignee, assigned_to) end
  where id = p_id returning * into v;
  if v.id is null then raise exception 'not_found'; end if;
  perform public.erp_log_write('ticket.updated', 'ticket', p_id::text,
    'Updated ticket "' || left(v.subject, 60) || '"', null,
    jsonb_strip_nulls(jsonb_build_object('status', p_status, 'priority', p_priority, 'assignee', p_assignee)));
end $$;

create or replace function public.erp_ticket_reply(p_id uuid, p_body text)
returns void language plpgsql security definer set search_path = public as $$
declare v record;
begin
  perform public.erp_assert('support.manage');
  if length(btrim(coalesce(p_body, ''))) = 0 then raise exception 'empty_message'; end if;
  select * into v from support_tickets where id = p_id;
  if v.id is null then raise exception 'not_found'; end if;
  insert into support_messages (ticket_id, sender_id, from_staff, body)
  values (p_id, auth.uid(), true, btrim(p_body));
  update support_tickets set status = 'answered', last_message_at = now(),
         assigned_to = coalesce(assigned_to, auth.uid())
  where id = p_id;
  perform public.notify(v.user_id, 'support_reply', 'GoDoctor support replied',
    left(btrim(p_body), 140), jsonb_build_object('ticket_id', p_id));
  perform public.erp_log_write('ticket.replied', 'ticket', p_id::text,
    'Replied to "' || left(v.subject, 60) || '"');
end $$;

create or replace function public.erp_review_hide(p_id uuid, p_hidden boolean, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.erp_assert('reviews.moderate');
  if p_hidden and length(btrim(coalesce(p_reason, ''))) < 3 then raise exception 'reason_required'; end if;
  update reviews set
    hidden_at = case when p_hidden then now() end,
    hidden_by = case when p_hidden then auth.uid() end,
    hidden_reason = case when p_hidden then btrim(p_reason) end
  where id = p_id;
  if not found then raise exception 'not_found'; end if;
  perform public.erp_log_write(case when p_hidden then 'review.hidden' else 'review.restored' end,
    'review', p_id::text, case when p_hidden then 'Hid a review''s comment' else 'Restored a review''s comment' end,
    p_reason);
end $$;

create or replace function public.erp_add_note(p_entity_type text, p_entity_id text, p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public.erp_assert('dashboard.view');
  insert into erp_notes (entity_type, entity_id, author_id, body)
  values (p_entity_type, p_entity_id, auth.uid(), btrim(p_body))
  returning id into v_id;
  perform public.erp_log_write('note.added', p_entity_type, p_entity_id, 'Added an internal note');
  return v_id;
end $$;

create or replace function public.erp_staff_save(
  p_user uuid, p_full_name text, p_job_title text, p_department text, p_role text, p_phone text default null
) returns void language plpgsql security definer set search_path = public as $$
declare v_old record;
begin
  perform public.erp_assert('staff.manage');
  if not exists (select 1 from erp_roles where key = p_role) then raise exception 'invalid_role'; end if;
  select * into v_old from erp_staff where user_id = p_user;
  if v_old.user_id is null then raise exception 'not_staff'; end if;
  if p_user = auth.uid() and p_role <> v_old.role then raise exception 'cannot_change_own_role'; end if;
  if v_old.role = 'administrator' and p_role <> 'administrator'
     and (select count(*) from erp_staff where role = 'administrator' and status = 'active') <= 1 then
    raise exception 'last_administrator';
  end if;
  update erp_staff set full_name = btrim(p_full_name), job_title = btrim(coalesce(p_job_title, '')),
         department = btrim(coalesce(p_department, '')), role = p_role, phone = nullif(btrim(coalesce(p_phone, '')), '')
  where user_id = p_user;
  perform public.erp_log_write('staff.updated', 'staff', p_user::text,
    'Updated ' || btrim(p_full_name) || case when p_role <> v_old.role
      then ' (role ' || v_old.role || ' → ' || p_role || ')' else '' end);
end $$;

-- My own name, title and phone (any staff member).
create or replace function public.erp_profile_save(p_full_name text, p_job_title text, p_phone text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from erp_staff where user_id = auth.uid() and status = 'active') then
    raise exception 'not_staff';
  end if;
  update erp_staff set full_name = btrim(p_full_name), job_title = btrim(coalesce(p_job_title, '')),
         phone = nullif(btrim(coalesce(p_phone, '')), '')
  where user_id = auth.uid();
end $$;

create or replace function public.erp_role_set_permissions(p_role text, p_permissions text[])
returns void language plpgsql security definer set search_path = public as $$
declare v_locked boolean; v_name text;
begin
  perform public.erp_assert('staff.manage');
  select locked, name into v_locked, v_name from erp_roles where key = p_role;
  if v_locked is null then raise exception 'invalid_role'; end if;
  if v_locked then raise exception 'role_locked'; end if;
  delete from erp_role_permissions where role = p_role;
  insert into erp_role_permissions (role, permission)
  select p_role, p from unnest(coalesce(p_permissions, '{}')) p
  where p in (select key from erp_permissions)
  on conflict do nothing;
  perform public.erp_log_write('role.permissions_changed', 'role', p_role,
    'Changed what ' || v_name || ' can do', null, jsonb_build_object('permissions', p_permissions));
end $$;

create or replace function public.erp_settings_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.erp_assert('dashboard.view');
  return (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from erp_settings);
end $$;

create or replace function public.erp_settings_set(p_key text, p_value jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.erp_assert('settings.manage');
  if p_key not in ('company', 'commission', 'payouts') then raise exception 'invalid_setting'; end if;
  if jsonb_typeof(p_value) <> 'object' then raise exception 'invalid_value'; end if;
  insert into erp_settings (key, value, updated_by, updated_at)
  values (p_key, p_value, auth.uid(), now())
  on conflict (key) do update set value = excluded.value, updated_by = excluded.updated_by, updated_at = now();
  perform public.erp_log_write('settings.changed', 'settings', p_key, 'Changed the ' || p_key || ' settings',
    null, p_value);
end $$;

create or replace function public.erp_broadcast(p_role text, p_title text, p_body text)
returns int language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  perform public.erp_assert('broadcast.send');
  if p_role not in ('all', 'patient', 'doctor', 'chemist') then raise exception 'invalid_audience'; end if;
  if length(btrim(coalesce(p_title, ''))) = 0 or length(btrim(coalesce(p_body, ''))) = 0 then
    raise exception 'empty_message';
  end if;
  insert into notifications (user_id, kind, title, body, data)
  select u.id, 'announcement', btrim(p_title), btrim(p_body), jsonb_build_object('from', 'godoctor')
  from users u
  where u.status = 'active' and u.role in ('patient', 'doctor', 'chemist')
    and (p_role = 'all' or u.role::text = p_role);
  get diagnostics v_count = row_count;
  perform public.erp_log_write('broadcast.sent', 'broadcast', p_role,
    'Sent "' || left(btrim(p_title), 60) || '" to ' || v_count || ' ' ||
      case p_role when 'all' then 'users' when 'chemist' then 'pharmacies' else p_role || 's' end);
  return v_count;
end $$;

------------------------------------------------------------------
-- 8. Privileges: signed-in callers only; each function checks itself.
------------------------------------------------------------------
do $$
declare f text;
begin
  foreach f in array array[
    'erp_can(text)', 'erp_me()', 'erp_dashboard(int)', 'erp_patient(uuid)',
    'erp_patient_health(uuid, text)', 'erp_consultation_clinical(uuid, text)',
    'erp_provider_documents(uuid)', 'erp_set_account_status(uuid, text, text)',
    'erp_verify_provider(uuid, boolean, text)', 'erp_set_licence(uuid, text, date)',
    'erp_cancel_consultation(uuid, text)', 'erp_set_order_status(uuid, text, text)',
    'erp_record_refund(uuid, text, text)', 'erp_generate_payouts(date, date)',
    'erp_payout_paid(uuid, text)', 'erp_payout_cancel(uuid, text)',
    'erp_ticket_update(uuid, text, text, uuid, boolean)', 'erp_ticket_reply(uuid, text)',
    'erp_review_hide(uuid, boolean, text)', 'erp_add_note(text, text, text)',
    'erp_staff_save(uuid, text, text, text, text, text)', 'erp_profile_save(text, text, text)',
    'erp_role_set_permissions(text, text[])', 'erp_settings_get()',
    'erp_settings_set(text, jsonb)', 'erp_broadcast(text, text, text)'
  ] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;

-- Internal helpers: not callable from the app.
revoke all on function public.erp_log_write(text, text, text, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.erp_assert(text) from public, anon, authenticated;
revoke all on function public.erp_log_locked() from public, anon, authenticated;
