-- 0012_fix_doctor_update_policy.sql
-- The original doctor_profiles_owner_update policy compared license_verified
-- against a subquery on doctor_profiles itself. Once doctor_profiles got a
-- read policy that has its own subqueries (0011), Postgres rejected every
-- doctor self-update with "infinite recursion detected in policy".
--
-- The subquery is no longer needed: 0011 revokes table-wide UPDATE and grants
-- UPDATE only on the columns a doctor may edit, so license_verified,
-- rating_avg, rating_count, status etc. simply cannot be written by clients.

drop policy if exists doctor_profiles_owner_update on public.doctor_profiles;

create policy doctor_profiles_owner_update on public.doctor_profiles
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());
