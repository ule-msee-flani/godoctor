-- 0017_drug_info.sql
-- Patient-facing information for each medicine, imported from free public
-- sources (RxNorm for matching, openFDA drug labels for the text) by
-- app/tool/import_drug_info.js. Kept separate from `drugs` so the catalogue
-- stays lean and the source can later be swapped (e.g. a paid Kenyan API)
-- without touching orders, inventory or prescriptions.

create table if not exists public.drug_info (
  drug_id uuid primary key references public.drugs (id) on delete cascade,
  rxcui text,                 -- RxNorm concept id of the matched ingredient
  matched_name text,          -- name it was matched to (e.g. acetaminophen)
  uses text,                  -- "What it is used for"
  how_to_take text,
  warnings text,
  side_effects text,
  interactions text,
  source text not null default 'openFDA',
  source_url text,            -- full label (DailyMed)
  fetched_at timestamptz not null default now()
);

alter table public.drug_info enable row level security;

-- Same visibility as the drugs catalogue itself: anyone can read.
create policy drug_info_public_read on public.drug_info
  for select using (true);
create policy drug_info_admin_write on public.drug_info
  for all using (public.current_role_is('admin'))
  with check (public.current_role_is('admin'));
