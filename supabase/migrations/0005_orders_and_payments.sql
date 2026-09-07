-- 0005_orders_and_payments.sql
-- Orders, order line items, and payments (M-Pesa integration deferred; schema only).

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.users (id) on delete cascade,
  chemist_id uuid not null references public.users (id) on delete cascade,
  prescription_id uuid references public.prescriptions (id) on delete set null,
  status order_status not null default 'placed',
  total_amount numeric(10, 2) not null default 0,
  escrow_status escrow_status not null default 'held',
  fulfillment_type fulfillment_type not null default 'pickup',
  confirmed_at timestamptz,
  ready_at timestamptz,
  fulfilled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists orders_patient_idx on public.orders (patient_id);
create index if not exists orders_chemist_idx on public.orders (chemist_id);
create index if not exists orders_status_idx on public.orders (status);

create trigger orders_set_updated_at
  before update on public.orders
  for each row execute function set_updated_at();

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  drug_id uuid not null references public.drugs (id) on delete restrict,
  quantity integer not null default 1,
  unit_price numeric(10, 2) not null default 0
);

create index if not exists order_items_order_idx on public.order_items (order_id);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders (id) on delete cascade,
  consultation_id uuid references public.consultations (id) on delete cascade,
  amount numeric(10, 2) not null,
  provider payment_provider not null default 'mpesa',
  status payment_status not null default 'pending',
  escrow_release_at timestamptz,
  -- Populated once the real Daraja integration lands; null/false for now.
  mpesa_receipt_number text,
  is_simulated boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payments_target_check check (
    order_id is not null or consultation_id is not null
  )
);

create trigger payments_set_updated_at
  before update on public.payments
  for each row execute function set_updated_at();
