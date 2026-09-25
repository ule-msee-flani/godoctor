-- Chemists photograph the exact pack they sell. That photo is shown to
-- patients choosing that chemist, and (the most recent one per medicine) in the
-- Order Medicine gallery, where a real photo beats any bundled placeholder.

alter table public.chemist_inventory add column if not exists image_path text;

-- Public bucket: anyone can view pack photos. A chemist can only write inside
-- their own folder: inventory-photos/<chemist user id>/...
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'inventory-photos', 'inventory-photos', true, 5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy inventory_photos_owner_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'inventory-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.current_role_is('chemist')
  );
create policy inventory_photos_owner_update on storage.objects
  for update to authenticated
  using (bucket_id = 'inventory-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy inventory_photos_owner_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'inventory-photos' and (storage.foldername(name))[1] = auth.uid()::text);

-- Latest chemist photo per medicine. security_invoker => the caller's row
-- security on chemist_inventory applies, so photos from unverified chemists
-- are never shown to patients.
create or replace view public.drug_display_photos
with (security_invoker = true) as
select distinct on (drug_id) drug_id, image_path
from public.chemist_inventory
where image_path is not null
order by drug_id, last_updated_at desc;

grant select on public.drug_display_photos to anon, authenticated;
