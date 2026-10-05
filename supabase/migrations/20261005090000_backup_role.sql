-- Read-only sign-in for the weekly backup (.github/workflows/backup.yml).
--
-- It can read every table, which is what a backup needs, and change nothing:
-- its only privilege is pg_read_all_data, and every transaction it starts is
-- read-only. BYPASSRLS lets the dump see all rows instead of stopping at row
-- security. The password is set outside the migrations and kept only in the
-- repo's BACKUP_DB_URL secret; until it is set the role can't sign in.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'godoctor_backup') then
    create role godoctor_backup nologin bypassrls connection limit 2;
  end if;
end $$;

grant pg_read_all_data to godoctor_backup;
alter role godoctor_backup set default_transaction_read_only = on;
