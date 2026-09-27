-- "Could not find a relationship between 'chemist_inventory' and
-- 'chemist_profiles'" (and the same for orders): both tables point their
-- chemist_id at users(id), so the API can't join them to the chemist's
-- profile (name, location, verified). That broke "chemists that have this
-- medicine", ordering a prescription, and order history.
--
-- Add a second foreign key to chemist_profiles(user_id). Every chemist has
-- a profile row (created with the account), and no rows are orphaned.

alter table public.chemist_inventory
  add constraint chemist_inventory_chemist_profile_fkey
  foreign key (chemist_id) references public.chemist_profiles (user_id)
  on delete cascade;

alter table public.orders
  add constraint orders_chemist_profile_fkey
  foreign key (chemist_id) references public.chemist_profiles (user_id)
  on delete cascade;

-- Let the API see the new relationships straight away.
notify pgrst, 'reload schema';
