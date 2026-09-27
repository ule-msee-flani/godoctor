-- Gender for the patient's health details, shown on prescriptions
-- ("Patient / Age / Gender") the way a paper prescription has it.
alter table public.patient_profiles
  add column if not exists gender text
  check (gender in ('female', 'male', 'other'));

notify pgrst, 'reload schema';
