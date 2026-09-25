-- Same text clean-up as tool/import_drug_info.js, applied to rows already
-- loaded. Safe to run repeatedly.
create or replace function pg_temp.tidy(t text) returns text language sql as $$
  select nullif(trim(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(
    t,
    '\[\s*see [^\]]*\]', '', 'gi'),
    '\[\s*see (the )?(Boxed Warning|Warnings and Precautions|Adverse Reactions|Clinical Pharmacology|Drug Interactions|Use in Specific Populations|Contraindications|Dosage and Administration)( and (Boxed Warning|Warnings and Precautions|Adverse Reactions))?\s*', '', 'gi'),
    'The following [^:.]{0,90}(described|discussed)[^:.]*label(ing)?:?', '', 'gi'),
    '\s+([.,;:])', '\1', 'g'),
    '\s{2,}', ' ', 'g')), '')
$$;

update public.drug_info set
  uses = pg_temp.tidy(uses),
  warnings = pg_temp.tidy(warnings),
  side_effects = pg_temp.tidy(side_effects),
  interactions = pg_temp.tidy(interactions);
