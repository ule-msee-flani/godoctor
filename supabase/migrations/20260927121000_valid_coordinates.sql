-- Chemist sign-up used to take latitude/longitude as typed numbers, and one
-- pharmacy was saved at (15413, 64321), which isn't a place on Earth and
-- breaks "nearest chemist" sorting. The app now uses the map picker; the
-- database also refuses impossible coordinates from here on.

-- Clear the impossible ones (the chemist re-picks on the map).
update public.chemist_profiles
set location_lat = null, location_lng = null
where location_lat not between -90 and 90 or location_lng not between -180 and 180;

update public.patient_profiles
set location_lat = null, location_lng = null
where location_lat not between -90 and 90 or location_lng not between -180 and 180;

alter table public.chemist_profiles
  add constraint chemist_profiles_valid_location check (
    (location_lat is null or location_lat between -90 and 90) and
    (location_lng is null or location_lng between -180 and 180)
  );

alter table public.patient_profiles
  add constraint patient_profiles_valid_location check (
    (location_lat is null or location_lat between -90 and 90) and
    (location_lng is null or location_lng between -180 and 180)
  );
