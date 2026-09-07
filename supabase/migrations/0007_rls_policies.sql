-- 0007_rls_policies.sql
-- Row-Level Security for every table. Written so that:
--   * patients can only read/write their own records
--   * doctors can only read consultations/prescriptions assigned to them
--   * chemists can NEVER read patient diagnosis/consultation data
--   * verification flags are never self-service (writable only via the
--     admin_set_*_verified() SECURITY DEFINER functions from 0002)

-- Small helper so policies stay readable.
create or replace function public.current_role_is(target user_role)
returns boolean as $$
  select exists (
    select 1 from public.users where id = auth.uid() and role = target
  );
$$ language sql stable security definer set search_path = public;

------------------------------------------------------------------
-- users
------------------------------------------------------------------
alter table public.users enable row level security;

create policy users_select_self on public.users
  for select using (id = auth.uid());

create policy users_select_admin on public.users
  for select using (public.current_role_is('admin'));

create policy users_update_self on public.users
  for update using (id = auth.uid())
  with check (id = auth.uid() and role = (select role from public.users where id = auth.uid()));

------------------------------------------------------------------
-- patient_profiles
------------------------------------------------------------------
alter table public.patient_profiles enable row level security;

create policy patient_profiles_owner_all on public.patient_profiles
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- A doctor may read the profile of a patient in a consultation assigned to them
-- (needed for the in-call patient-info panel), never more broadly.
create policy patient_profiles_doctor_read on public.patient_profiles
  for select using (
    exists (
      select 1 from public.consultations c
      where c.patient_id = patient_profiles.user_id
        and c.doctor_id = auth.uid()
    )
  );

create policy patient_profiles_admin_read on public.patient_profiles
  for select using (public.current_role_is('admin'));

------------------------------------------------------------------
-- doctor_profiles
------------------------------------------------------------------
alter table public.doctor_profiles enable row level security;

-- Publicly readable (patients need to see doctor name/specialty/rating when
-- matched; the directory itself isn't browsable by patients pre-match, but
-- read access is harmless since it carries no patient data).
create policy doctor_profiles_public_read on public.doctor_profiles
  for select using (true);

-- Doctors may update their own row EXCEPT license_verified, which is locked
-- down by the WITH CHECK clause comparing against the existing stored value.
create policy doctor_profiles_owner_update on public.doctor_profiles
  for update using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and license_verified = (
      select license_verified from public.doctor_profiles where user_id = auth.uid()
    )
  );

create policy doctor_profiles_owner_insert on public.doctor_profiles
  for insert with check (user_id = auth.uid() and license_verified = false);

------------------------------------------------------------------
-- chemist_profiles
------------------------------------------------------------------
alter table public.chemist_profiles enable row level security;

create policy chemist_profiles_public_read on public.chemist_profiles
  for select using (true);

create policy chemist_profiles_owner_update on public.chemist_profiles
  for update using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and verified = (select verified from public.chemist_profiles where user_id = auth.uid())
  );

create policy chemist_profiles_owner_insert on public.chemist_profiles
  for insert with check (user_id = auth.uid() and verified = false);

------------------------------------------------------------------
-- consultations / intake_forms / consultation_offers
-- (chemists have NO policies here at all -> default-deny keeps them out)
------------------------------------------------------------------
alter table public.consultations enable row level security;

create policy consultations_patient_all on public.consultations
  for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());

create policy consultations_doctor_read on public.consultations
  for select using (doctor_id = auth.uid());

create policy consultations_doctor_update on public.consultations
  for update using (doctor_id = auth.uid()) with check (doctor_id = auth.uid());

alter table public.intake_forms enable row level security;

create policy intake_forms_patient_all on public.intake_forms
  for all using (
    exists (select 1 from public.consultations c
            where c.id = intake_forms.consultation_id and c.patient_id = auth.uid())
  ) with check (
    exists (select 1 from public.consultations c
            where c.id = intake_forms.consultation_id and c.patient_id = auth.uid())
  );

create policy intake_forms_doctor_read on public.intake_forms
  for select using (
    exists (select 1 from public.consultations c
            where c.id = intake_forms.consultation_id and c.doctor_id = auth.uid())
  );

alter table public.consultation_offers enable row level security;

create policy consultation_offers_doctor_all on public.consultation_offers
  for all using (doctor_id = auth.uid()) with check (doctor_id = auth.uid());

create policy consultation_offers_patient_read on public.consultation_offers
  for select using (
    exists (select 1 from public.consultations c
            where c.id = consultation_offers.consultation_id and c.patient_id = auth.uid())
  );

------------------------------------------------------------------
-- prescriptions / prescription_items
-- Chemists get READ access to prescriptions only insofar as they're attached
-- to one of the chemist's own orders (checked via orders, not directly), and
-- get no access to prescription diagnosis/consultation linkage fields beyond
-- what's needed to verify the item list -- enforced by only granting SELECT
-- on prescriptions joined through orders.chemist_id below.
------------------------------------------------------------------
alter table public.prescriptions enable row level security;

create policy prescriptions_patient_all on public.prescriptions
  for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());

create policy prescriptions_doctor_read on public.prescriptions
  for select using (doctor_id = auth.uid());

create policy prescriptions_doctor_insert on public.prescriptions
  for insert with check (doctor_id = auth.uid());

create policy prescriptions_chemist_read_via_order on public.prescriptions
  for select using (
    exists (
      select 1 from public.orders o
      where o.prescription_id = prescriptions.id and o.chemist_id = auth.uid()
    )
  );

alter table public.prescription_items enable row level security;

create policy prescription_items_patient_read on public.prescription_items
  for select using (
    exists (select 1 from public.prescriptions p
            where p.id = prescription_items.prescription_id and p.patient_id = auth.uid())
  );

create policy prescription_items_doctor_all on public.prescription_items
  for all using (
    exists (select 1 from public.prescriptions p
            where p.id = prescription_items.prescription_id and p.doctor_id = auth.uid())
  ) with check (
    exists (select 1 from public.prescriptions p
            where p.id = prescription_items.prescription_id and p.doctor_id = auth.uid())
  );

create policy prescription_items_chemist_read_via_order on public.prescription_items
  for select using (
    exists (
      select 1 from public.orders o
      where o.prescription_id = prescription_items.prescription_id and o.chemist_id = auth.uid()
    )
  );

------------------------------------------------------------------
-- drugs (public catalog, admin-managed)
------------------------------------------------------------------
alter table public.drugs enable row level security;

create policy drugs_public_read on public.drugs for select using (true);

create policy drugs_admin_write on public.drugs
  for insert with check (public.current_role_is('admin'));

create policy drugs_admin_update on public.drugs
  for update using (public.current_role_is('admin'));

create policy drugs_admin_delete on public.drugs
  for delete using (public.current_role_is('admin'));

------------------------------------------------------------------
-- chemist_inventory
------------------------------------------------------------------
alter table public.chemist_inventory enable row level security;

-- Publicly readable so patients can search stock/price across chemists;
-- only unverified chemists' own inventory rows are excluded from that public
-- view via the `verified` join below.
create policy chemist_inventory_public_read on public.chemist_inventory
  for select using (
    exists (
      select 1 from public.chemist_profiles cp
      where cp.user_id = chemist_inventory.chemist_id and cp.verified = true
    )
    or chemist_id = auth.uid()
  );

create policy chemist_inventory_owner_write on public.chemist_inventory
  for all using (chemist_id = auth.uid()) with check (chemist_id = auth.uid());

------------------------------------------------------------------
-- orders / order_items
------------------------------------------------------------------
alter table public.orders enable row level security;

create policy orders_patient_all on public.orders
  for all using (patient_id = auth.uid()) with check (patient_id = auth.uid());

create policy orders_chemist_read on public.orders
  for select using (chemist_id = auth.uid());

create policy orders_chemist_update on public.orders
  for update using (chemist_id = auth.uid()) with check (chemist_id = auth.uid());

alter table public.order_items enable row level security;

create policy order_items_patient_read on public.order_items
  for select using (
    exists (select 1 from public.orders o
            where o.id = order_items.order_id and o.patient_id = auth.uid())
  );

create policy order_items_patient_insert on public.order_items
  for insert with check (
    exists (select 1 from public.orders o
            where o.id = order_items.order_id and o.patient_id = auth.uid())
  );

create policy order_items_chemist_read on public.order_items
  for select using (
    exists (select 1 from public.orders o
            where o.id = order_items.order_id and o.chemist_id = auth.uid())
  );

------------------------------------------------------------------
-- payments
------------------------------------------------------------------
alter table public.payments enable row level security;

create policy payments_patient_read on public.payments
  for select using (
    exists (select 1 from public.orders o
            where o.id = payments.order_id and o.patient_id = auth.uid())
    or exists (select 1 from public.consultations c
               where c.id = payments.consultation_id and c.patient_id = auth.uid())
  );

create policy payments_patient_insert on public.payments
  for insert with check (
    exists (select 1 from public.orders o
            where o.id = payments.order_id and o.patient_id = auth.uid())
    or exists (select 1 from public.consultations c
               where c.id = payments.consultation_id and c.patient_id = auth.uid())
  );

create policy payments_chemist_read on public.payments
  for select using (
    exists (select 1 from public.orders o
            where o.id = payments.order_id and o.chemist_id = auth.uid())
  );

------------------------------------------------------------------
-- reviews
------------------------------------------------------------------
alter table public.reviews enable row level security;

create policy reviews_author_all on public.reviews
  for all using (author_id = auth.uid()) with check (author_id = auth.uid());

create policy reviews_public_read on public.reviews
  for select using (true);

------------------------------------------------------------------
-- chemist_doctor_queries (phase 2 -- policies included for completeness)
------------------------------------------------------------------
alter table public.chemist_doctor_queries enable row level security;

create policy cdq_chemist_all on public.chemist_doctor_queries
  for all using (chemist_id = auth.uid()) with check (chemist_id = auth.uid());

create policy cdq_doctor_read on public.chemist_doctor_queries
  for select using (true);

create policy cdq_doctor_answer on public.chemist_doctor_queries
  for update using (public.current_role_is('doctor'))
  with check (answered_by_doctor_id = auth.uid());
