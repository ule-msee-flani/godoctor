-- 0001_extensions_and_enums.sql
-- Extensions and shared enum types for the On-Demand Doctor app.

create extension if not exists "pgcrypto";      -- gen_random_uuid()
create extension if not exists "pg_trgm";       -- fuzzy drug-name search

-- Roles
do $$ begin
  create type user_role as enum ('patient', 'doctor', 'chemist', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type user_status as enum ('active', 'suspended');
exception when duplicate_object then null; end $$;

-- Doctor availability
do $$ begin
  create type doctor_status as enum ('available', 'offered', 'busy', 'offline');
exception when duplicate_object then null; end $$;

-- Consultation lifecycle
do $$ begin
  create type consultation_status as enum
    ('requested', 'matched', 'in_progress', 'completed', 'cancelled', 'unmatched');
exception when duplicate_object then null; end $$;

-- Consultation offer lifecycle (one row per doctor we try during matching)
do $$ begin
  create type offer_status as enum ('pending', 'accepted', 'declined', 'expired');
exception when duplicate_object then null; end $$;

-- Prescription source
do $$ begin
  create type prescription_source as enum ('app', 'external_upload');
exception when duplicate_object then null; end $$;

-- Drug form / category kept as free text (open-ended), but requires_prescription is boolean.

-- Order lifecycle
do $$ begin
  create type order_status as enum
    ('placed', 'confirmed', 'ready', 'fulfilled', 'disputed', 'refunded');
exception when duplicate_object then null; end $$;

do $$ begin
  create type escrow_status as enum ('held', 'released', 'refunded');
exception when duplicate_object then null; end $$;

do $$ begin
  create type fulfillment_type as enum ('pickup', 'delivery');
exception when duplicate_object then null; end $$;

-- Payments
do $$ begin
  create type payment_provider as enum ('mpesa', 'card');
exception when duplicate_object then null; end $$;

do $$ begin
  create type payment_status as enum ('pending', 'succeeded', 'failed', 'refunded');
exception when duplicate_object then null; end $$;

-- Shared trigger function to maintain updated_at columns.
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;
