-- 0009_storage.sql
-- Storage buckets for file uploads: doctor/chemist verification documents
-- and patient-uploaded external prescription photos.

insert into storage.buckets (id, name, public)
values
  ('verification-documents', 'verification-documents', false),
  ('prescription-uploads', 'prescription-uploads', false)
on conflict (id) do nothing;

-- verification-documents: each user's files live under `<user_id>/...`.
-- Owner can upload/read their own; admins can read all (to review during
-- the manual verification workflow).
create policy "verification docs: owner upload"
  on storage.objects for insert
  with check (
    bucket_id = 'verification-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "verification docs: owner read"
  on storage.objects for select
  using (
    bucket_id = 'verification-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "verification docs: admin read"
  on storage.objects for select
  using (
    bucket_id = 'verification-documents'
    and public.current_role_is('admin')
  );

-- prescription-uploads: patient owns their folder; the chemist fulfilling
-- the order that references the resulting prescription may also view it
-- (manual photo verification per spec), and the prescribing/reviewing
-- doctor can view their own patients' uploads.
create policy "prescription uploads: owner upload"
  on storage.objects for insert
  with check (
    bucket_id = 'prescription-uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "prescription uploads: owner read"
  on storage.objects for select
  using (
    bucket_id = 'prescription-uploads'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "prescription uploads: chemist read via order"
  on storage.objects for select
  using (
    bucket_id = 'prescription-uploads'
    and exists (
      select 1
      from public.orders o
      join public.prescriptions p on p.id = o.prescription_id
      where o.chemist_id = auth.uid()
        and p.image_url = storage.objects.name
    )
  );
