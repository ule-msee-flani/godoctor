-- 0003_consultations.sql
-- Consultation requests, intake forms, and the per-doctor offer trail used by matching.

create table if not exists public.consultations (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.users (id) on delete cascade,
  doctor_id uuid references public.users (id) on delete set null,
  specialty_requested text not null,
  symptom_summary text not null default '',
  status consultation_status not null default 'requested',
  video_session_id text,
  started_at timestamptz,
  ended_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists consultations_patient_idx on public.consultations (patient_id);
create index if not exists consultations_doctor_idx on public.consultations (doctor_id);
create index if not exists consultations_status_idx on public.consultations (status);

create trigger consultations_set_updated_at
  before update on public.consultations
  for each row execute function set_updated_at();

create table if not exists public.intake_forms (
  consultation_id uuid primary key references public.consultations (id) on delete cascade,
  symptoms text not null default '',
  duration text,
  severity text,
  flagged_emergency boolean not null default false,
  created_at timestamptz not null default now()
);

-- One row per doctor candidate offered during the matching sequence for a
-- consultation. Lets us implement "offer to top candidate, on decline/timeout
-- move to next" with a full audit trail, and lets the doctor's app subscribe
-- to just their own pending offers via Realtime.
create table if not exists public.consultation_offers (
  id uuid primary key default gen_random_uuid(),
  consultation_id uuid not null references public.consultations (id) on delete cascade,
  doctor_id uuid not null references public.users (id) on delete cascade,
  status offer_status not null default 'pending',
  offered_at timestamptz not null default now(),
  responded_at timestamptz,
  expires_at timestamptz not null default (now() + interval '30 seconds')
);

create index if not exists consultation_offers_doctor_idx
  on public.consultation_offers (doctor_id, status);
create index if not exists consultation_offers_consultation_idx
  on public.consultation_offers (consultation_id);
