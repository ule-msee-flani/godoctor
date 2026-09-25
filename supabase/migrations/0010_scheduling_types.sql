-- 0010_scheduling_types.sql
-- Types needed by scheduled appointments. Kept in its own migration because a
-- newly added enum value can't be used until the transaction that adds it
-- has committed (0011 uses 'scheduled').

-- Lets an exclusion constraint combine uuid equality with time-range overlap
-- (the "one doctor can't be double-booked" guarantee in 0011).
create extension if not exists btree_gist with schema extensions;

alter type consultation_status add value if not exists 'scheduled';

do $$ begin
  create type consultation_mode as enum ('on_demand', 'scheduled');
exception when duplicate_object then null; end $$;
