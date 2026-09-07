-- keml_subset.sql
-- Starter drug catalog: a curated subset of the Kenya Essential Medicines List
-- (KEML) covering common categories. Not exhaustive -- intended as enough data
-- to build/demo search, prescribing, and inventory against. Extend via the
-- Supabase table editor or additional INSERTs as needed.
--
-- requires_prescription is a simplification for demo purposes (e.g. most
-- antibiotics/controlled items = true, common OTC analgesics/vitamins = false)
-- -- review against actual KEML/Pharmacy & Poisons Board schedules before
-- relying on this for real prescribing gates.

insert into public.drugs (generic_name, brand_names, form, requires_prescription, category) values
-- Analgesics / antipyretics
('Paracetamol', '{Panadol,Hedex}', 'tablet', false, 'Analgesic'),
('Paracetamol', '{Calpol}', 'syrup', false, 'Analgesic'),
('Ibuprofen', '{Brufen}', 'tablet', false, 'Analgesic/NSAID'),
('Diclofenac', '{Voltaren}', 'tablet', true, 'Analgesic/NSAID'),
('Diclofenac', '{Voltaren Gel}', 'topical gel', false, 'Analgesic/NSAID'),
('Aspirin', '{Disprin}', 'tablet', false, 'Analgesic'),
('Tramadol', '{Tramal}', 'capsule', true, 'Analgesic (opioid)'),
('Morphine', '{}', 'injection', true, 'Analgesic (opioid)'),

-- Antibiotics
('Amoxicillin', '{Amoxil}', 'capsule', true, 'Antibiotic'),
('Amoxicillin-Clavulanate', '{Augmentin}', 'tablet', true, 'Antibiotic'),
('Flucloxacillin', '{}', 'capsule', true, 'Antibiotic'),
('Erythromycin', '{}', 'tablet', true, 'Antibiotic'),
('Azithromycin', '{Zithromax}', 'tablet', true, 'Antibiotic'),
('Ciprofloxacin', '{Ciprobay}', 'tablet', true, 'Antibiotic'),
('Doxycycline', '{Vibramycin}', 'capsule', true, 'Antibiotic'),
('Metronidazole', '{Flagyl}', 'tablet', true, 'Antibiotic/Antiprotozoal'),
('Ceftriaxone', '{Rocephin}', 'injection', true, 'Antibiotic'),
('Gentamicin', '{}', 'injection', true, 'Antibiotic'),
('Cotrimoxazole', '{Septrin}', 'tablet', true, 'Antibiotic'),
('Benzylpenicillin', '{}', 'injection', true, 'Antibiotic'),

-- Antimalarials
('Artemether-Lumefantrine', '{Coartem}', 'tablet', true, 'Antimalarial'),
('Quinine', '{}', 'tablet', true, 'Antimalarial'),
('Sulfadoxine-Pyrimethamine', '{Fansidar}', 'tablet', true, 'Antimalarial'),
('Artesunate', '{}', 'injection', true, 'Antimalarial'),

-- Antihypertensives / cardiovascular
('Amlodipine', '{Norvasc}', 'tablet', true, 'Antihypertensive'),
('Nifedipine', '{Adalat}', 'tablet', true, 'Antihypertensive'),
('Losartan', '{Cozaar}', 'tablet', true, 'Antihypertensive'),
('Enalapril', '{}', 'tablet', true, 'Antihypertensive'),
('Atenolol', '{Tenormin}', 'tablet', true, 'Antihypertensive/Beta-blocker'),
('Hydrochlorothiazide', '{}', 'tablet', true, 'Diuretic'),
('Furosemide', '{Lasix}', 'tablet', true, 'Diuretic'),
('Atorvastatin', '{Lipitor}', 'tablet', true, 'Statin'),
('Simvastatin', '{Zocor}', 'tablet', true, 'Statin'),
('Aspirin', '{Cardiprin}', 'tablet (low-dose)', false, 'Cardiovascular'),

-- Diabetes
('Metformin', '{Glucophage}', 'tablet', true, 'Antidiabetic'),
('Glibenclamide', '{}', 'tablet', true, 'Antidiabetic'),
('Insulin (soluble)', '{Actrapid}', 'injection', true, 'Antidiabetic'),
('Insulin (isophane/NPH)', '{Insulatard}', 'injection', true, 'Antidiabetic'),
('Gliclazide', '{Diamicron}', 'tablet', true, 'Antidiabetic'),

-- Respiratory
('Salbutamol', '{Ventolin}', 'inhaler', true, 'Bronchodilator'),
('Salbutamol', '{Ventolin syrup}', 'syrup', false, 'Bronchodilator'),
('Beclomethasone', '{Becotide}', 'inhaler', true, 'Corticosteroid (inhaled)'),
('Prednisolone', '{}', 'tablet', true, 'Corticosteroid'),
('Dextromethorphan', '{Robitussin}', 'syrup', false, 'Antitussive'),
('Chlorpheniramine', '{Piriton}', 'tablet', false, 'Antihistamine'),
('Cetirizine', '{Zyrtec}', 'tablet', false, 'Antihistamine'),
('Loratadine', '{Clarityne}', 'tablet', false, 'Antihistamine'),

-- Gastrointestinal
('Omeprazole', '{Losec}', 'capsule', false, 'Antacid/PPI'),
('Ranitidine', '{Zantac}', 'tablet', false, 'Antacid/H2-blocker'),
('Magnesium Trisilicate', '{}', 'tablet', false, 'Antacid'),
('Metoclopramide', '{Plasil}', 'tablet', false, 'Antiemetic'),
('Oral Rehydration Salts', '{ORS}', 'sachet', false, 'Rehydration'),
('Zinc Sulphate', '{}', 'tablet', false, 'Supplement (diarrhoea adjunct)'),
('Loperamide', '{Imodium}', 'capsule', false, 'Antidiarrhoeal'),
('Bisacodyl', '{Dulcolax}', 'tablet', false, 'Laxative'),
('Mebendazole', '{Vermox}', 'tablet', false, 'Anthelmintic'),
('Albendazole', '{}', 'tablet', false, 'Anthelmintic'),

-- Vitamins / supplements
('Ferrous Sulphate', '{}', 'tablet', false, 'Supplement (iron)'),
('Folic Acid', '{}', 'tablet', false, 'Supplement'),
('Multivitamin', '{Surbex}', 'tablet', false, 'Supplement'),
('Vitamin C', '{}', 'tablet', false, 'Supplement'),
('Calcium Carbonate', '{}', 'tablet', false, 'Supplement'),
('Vitamin B Complex', '{Neurobion}', 'tablet', false, 'Supplement'),

-- Dermatological
('Hydrocortisone Cream', '{}', 'topical cream', false, 'Dermatological'),
('Betamethasone Cream', '{Betnovate}', 'topical cream', true, 'Dermatological'),
('Clotrimazole Cream', '{Canesten}', 'topical cream', false, 'Antifungal'),
('Benzyl Benzoate', '{}', 'topical lotion', false, 'Antiparasitic (scabies)'),
('Permethrin Cream', '{}', 'topical cream', false, 'Antiparasitic (scabies)'),
('Silver Sulfadiazine', '{Flamazine}', 'topical cream', true, 'Burns/Antiseptic'),

-- Reproductive health / contraceptives
('Combined Oral Contraceptive', '{Microgynon}', 'tablet', true, 'Contraceptive'),
('Progestin-only Pill', '{Ovrette}', 'tablet', true, 'Contraceptive'),
('Emergency Contraceptive Pill', '{Postinor-2}', 'tablet', false, 'Contraceptive'),
('Medroxyprogesterone', '{Depo-Provera}', 'injection', true, 'Contraceptive'),
('Misoprostol', '{}', 'tablet', true, 'Reproductive health'),

-- Eye / ENT
('Chloramphenicol Eye Drops', '{}', 'eye drops', false, 'Ophthalmic antibiotic'),
('Tetracycline Eye Ointment', '{}', 'eye ointment', false, 'Ophthalmic antibiotic'),
('Sodium Chloride Nasal Drops', '{}', 'nasal drops', false, 'ENT'),
('Xylometazoline', '{Otrivin}', 'nasal spray', false, 'Decongestant'),

-- HIV/TB (common chronic-disease program drugs)
('Tenofovir-Lamivudine-Dolutegravir', '{TLD}', 'tablet', true, 'Antiretroviral'),
('Isoniazid', '{}', 'tablet', true, 'Antitubercular'),
('Rifampicin-Isoniazid-Pyrazinamide-Ethambutol', '{RHZE}', 'tablet', true, 'Antitubercular'),
('Cotrimoxazole Prophylaxis', '{Septrin}', 'tablet', true, 'Antiretroviral adjunct'),

-- IV fluids / emergency
('Normal Saline 0.9%', '{}', 'IV infusion', true, 'IV fluid'),
('Ringer''s Lactate', '{}', 'IV infusion', true, 'IV fluid'),
('Dextrose 5%', '{}', 'IV infusion', true, 'IV fluid'),
('Adrenaline (Epinephrine)', '{}', 'injection', true, 'Emergency/Anaphylaxis'),
('Hydrocortisone Injection', '{}', 'injection', true, 'Emergency/Corticosteroid'),
('Diazepam', '{Valium}', 'tablet', true, 'Anticonvulsant/Sedative'),
('Diazepam', '{Valium}', 'injection', true, 'Anticonvulsant/Sedative'),
('Magnesium Sulphate', '{}', 'injection', true, 'Emergency (eclampsia)')
on conflict do nothing;
