-- 0004_prescriptions_and_drugs.sql
-- Drug catalog, prescriptions, and chemist inventory.

create table if not exists public.drugs (
  id uuid primary key default gen_random_uuid(),
  generic_name text not null,
  brand_names text[] not null default '{}',
  form text, -- tablet, syrup, injection, etc.
  requires_prescription boolean not null default false,
  category text,
  created_at timestamptz not null default now()
);

create index if not exists drugs_generic_name_trgm_idx
  on public.drugs using gin (generic_name gin_trgm_ops);

create table if not exists public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  consultation_id uuid references public.consultations (id) on delete set null,
  patient_id uuid not null references public.users (id) on delete cascade,
  doctor_id uuid references public.users (id) on delete set null,
  source prescription_source not null default 'app',
  image_url text, -- storage path, used when source = external_upload
  issued_at timestamptz not null default now(),
  valid_until date,
  created_at timestamptz not null default now()
);

create index if not exists prescriptions_patient_idx on public.prescriptions (patient_id);
create index if not exists prescriptions_doctor_idx on public.prescriptions (doctor_id);

create table if not exists public.prescription_items (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions (id) on delete cascade,
  drug_id uuid references public.drugs (id) on delete set null,
  free_text_name text, -- used when the drug wasn't found in the structured catalog
  dosage text,
  quantity integer not null default 1,
  instructions text,
  constraint prescription_items_drug_or_text check (
    drug_id is not null or free_text_name is not null
  )
);

create index if not exists prescription_items_prescription_idx
  on public.prescription_items (prescription_id);

create table if not exists public.chemist_inventory (
  chemist_id uuid not null references public.users (id) on delete cascade,
  drug_id uuid not null references public.drugs (id) on delete cascade,
  quantity integer not null default 0,
  price numeric(10, 2) not null default 0,
  last_updated_at timestamptz not null default now(),
  primary key (chemist_id, drug_id)
);

create index if not exists chemist_inventory_drug_idx on public.chemist_inventory (drug_id);

create or replace function chemist_inventory_touch()
returns trigger as $$
begin
  new.last_updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger chemist_inventory_set_updated_at
  before update on public.chemist_inventory
  for each row execute function chemist_inventory_touch();
