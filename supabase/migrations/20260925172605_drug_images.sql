-- 0016_drug_images.sql
-- Optional product photo per medicine, shown in the "Order medicine" gallery.
--
-- To add one: upload the picture to the public `drug-images` storage bucket
-- (Supabase dashboard > Storage) and set drugs.image_path to its path in the
-- bucket, e.g. 'paracetamol.png'. Medicines without a photo fall back to a
-- picture for their category (bundled in the app), then to an illustration.

alter table public.drugs add column if not exists image_path text;

insert into storage.buckets (id, name, public)
values ('drug-images', 'drug-images', true)
on conflict (id) do nothing;

-- Public bucket => anyone can view. Only admins may change the pictures
-- (the dashboard uses the service role and is not affected by these).
create policy drug_images_admin_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'drug-images' and public.current_role_is('admin'));
create policy drug_images_admin_update on storage.objects
  for update to authenticated
  using (bucket_id = 'drug-images' and public.current_role_is('admin'));
create policy drug_images_admin_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'drug-images' and public.current_role_is('admin'));
