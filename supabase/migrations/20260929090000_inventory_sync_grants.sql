-- The inventory-sync edge function (service role) matches a pharmacy
-- system's medicine names to the catalogue.
grant execute on function public.match_drugs(text[]) to service_role;
