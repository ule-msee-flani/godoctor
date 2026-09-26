-- Fix: uploads to the public image buckets failed with a StorageException
-- ("new row violates row-level security policy").
--
-- Supabase Storage inserts the object row and reads it back (INSERT ...
-- RETURNING, and a lookup for upsert). Postgres only returns rows the caller
-- may SELECT, so a bucket with INSERT/UPDATE rules but no SELECT rule
-- rejects every upload. avatars, inventory-photos and drug-images are public
-- buckets (anyone can already fetch their files by URL), so reading their
-- object rows is safe.

drop policy if exists avatars_public_read on storage.objects;
create policy avatars_public_read on storage.objects
  for select to public
  using (bucket_id = 'avatars');

drop policy if exists inventory_photos_public_read on storage.objects;
create policy inventory_photos_public_read on storage.objects
  for select to public
  using (bucket_id = 'inventory-photos');

drop policy if exists drug_images_public_read on storage.objects;
create policy drug_images_public_read on storage.objects
  for select to public
  using (bucket_id = 'drug-images');

-- Profile photos: images only, 5 MB max (the app sends ~800px JPEGs).
update storage.buckets
set allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'],
    file_size_limit = 5242880
where id = 'avatars';
