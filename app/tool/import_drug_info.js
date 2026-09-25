// Imports patient-facing medicine information from FREE public sources into
// supabase/seed/drug_info.sql (then load that file into the database).
//
//   node tool/import_drug_info.js            # all medicines
//   node tool/import_drug_info.js paracetamol # just the ones matching a word
//
// How it works, per medicine in our catalogue:
//  1. RxNorm (US National Library of Medicine, free, no key) turns our name
//     into a standard concept, e.g. "Paracetamol" -> acetaminophen (rxcui 161).
//  2. openFDA (free; set OPENFDA_API_KEY in app/.env only if you hit limits)
//     gives the official US drug label for that ingredient. We pick the label
//     whose ingredients and route best match our product.
//  3. The label sections are cleaned and shortened for patients.
//
// Limits to be aware of: these are US labels. Brands, strengths and doses may
// differ from what Kenyan chemists stock, which is why the app does not show
// US dosing to patients and always shows the source. When budget allows,
// replace this importer with a Kenyan source (e.g. Pharmacy and Poisons Board)
// -- the app reads the drug_info table and doesn't care where it came from.
const fs = require('fs');
const path = require('path');

const env = Object.fromEntries(
  fs
    .readFileSync(path.join(__dirname, '..', '.env'), 'utf8')
    .split(/\r?\n/)
    .filter((l) => l.includes('=') && !l.trim().startsWith('#'))
    .map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim()]),
);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/// Products whose catalogue name isn't an ingredient RxNorm can resolve.
/// Value = the ingredient(s) to look up, or null to skip (no sensible US label).
const OVERRIDES = {
  'combined oral contraceptive': 'levonorgestrel / ethinyl estradiol',
  'progestin-only pill': 'norethindrone',
  'emergency contraceptive pill': 'levonorgestrel',
  'cotrimoxazole': 'sulfamethoxazole / trimethoprim',
  'cotrimoxazole prophylaxis': 'sulfamethoxazole / trimethoprim',
  'normal saline 0.9%': 'sodium chloride',
  'dextrose 5%': 'dextrose',
  "ringer's lactate": 'calcium chloride / potassium chloride / sodium chloride / sodium lactate',
  'insulin (isophane/nph)': 'insulin isophane, human',
  'insulin (soluble)': 'insulin regular, human',
  'adrenaline (epinephrine)': 'epinephrine',
  'benzylpenicillin': 'penicillin G',
  'glibenclamide': 'glyburide',
  'vitamin c': 'ascorbic acid',
  'amoxicillin-clavulanate': 'amoxicillin / clavulanate',
  'artemether-lumefantrine': 'artemether / lumefantrine',
  'sulfadoxine-pyrimethamine': 'sulfadoxine / pyrimethamine',
  'rifampicin-isoniazid-pyrazinamide-ethambutol': null, // no US fixed-dose label
  'tenofovir-lamivudine-dolutegravir': 'dolutegravir / lamivudine / tenofovir disoproxil',
  'multivitamin': null,
  'vitamin b complex': null,
  'oral rehydration salts': null,
};

/// Words in our product names that describe the form, not the ingredient.
const FORM_WORDS = /\b(cream|eye drops|eye ointment|nasal drops|injection|prophylaxis)\b/gi;

/// Our dosage form -> openFDA routes that fit it.
function routesFor(form) {
  const f = (form || '').toLowerCase();
  if (/eye/.test(f)) return ['OPHTHALMIC'];
  if (/nasal/.test(f)) return ['NASAL'];
  if (/inhaler/.test(f)) return ['RESPIRATORY (INHALATION)', 'INHALATION'];
  if (/cream|lotion|gel|ointment|topical/.test(f)) return ['TOPICAL'];
  if (/inject|infusion|iv/.test(f)) return ['INTRAVENOUS', 'INTRAMUSCULAR', 'SUBCUTANEOUS'];
  return ['ORAL'];
}

async function getJson(url) {
  for (let attempt = 0; attempt < 3; attempt++) {
    const res = await fetch(url);
    if (res.status === 404) return null;
    if (res.status === 429) {
      await sleep(3000 * (attempt + 1));
      continue;
    }
    if (!res.ok) throw new Error(`${res.status} for ${url}`);
    return res.json();
  }
  throw new Error(`rate limited: ${url}`);
}

/// RxNorm: our name -> { rxcui, name } of the ingredient concept.
async function rxnormMatch(term) {
  const approx = await getJson(
    `https://rxnav.nlm.nih.gov/REST/approximateTerm.json?term=${encodeURIComponent(term)}&maxEntries=5`,
  );
  const cands = approx?.approximateGroup?.candidate ?? [];
  for (const c of cands) {
    const props = await getJson(`https://rxnav.nlm.nih.gov/REST/rxcui/${c.rxcui}/properties.json`);
    const p = props?.properties;
    if (!p) continue;
    if (['IN', 'MIN', 'PIN'].includes(p.tty)) return { rxcui: p.rxcui, name: p.name };
    // A product concept: step down to its ingredient(s).
    const rel = await getJson(`https://rxnav.nlm.nih.gov/REST/rxcui/${c.rxcui}/related.json?tty=MIN+IN`);
    const groups = rel?.relatedGroup?.conceptGroup ?? [];
    const min = groups.find((g) => g.tty === 'MIN')?.conceptProperties?.[0];
    const ins = groups.find((g) => g.tty === 'IN')?.conceptProperties ?? [];
    if (min) return { rxcui: min.rxcui, name: min.name };
    if (ins.length) return { rxcui: ins[0].rxcui, name: ins.map((i) => i.name).join(' / ') };
  }
  return null;
}

const ingredientsOf = (name) =>
  name.toLowerCase().split(/\s*\/\s*|\s+and\s+/).map((s) => s.trim()).filter(Boolean);

/// openFDA: best-matching label for these ingredients and routes.
async function findLabel(ingredients, routes) {
  const key = env.OPENFDA_API_KEY ? `&api_key=${env.OPENFDA_API_KEY}` : '';
  const q = ingredients.map((i) => `openfda.generic_name:"${i}"`).join('+AND+');
  const data = await getJson(`https://api.fda.gov/drug/label.json?search=${q}&limit=25${key}`);
  const results = data?.results ?? [];
  if (!results.length) return null;

  const score = (l) => {
    const names = (l.openfda?.generic_name ?? []).join(' ').toLowerCase();
    const route = l.openfda?.route ?? [];
    let s = 0;
    // Prefer labels that contain exactly our ingredients (not extra ones).
    const extra = names.split(/,| and /).filter((p) => p.trim() && !ingredients.some((i) => p.includes(i.split(' ')[0])));
    s -= extra.length * 5;
    if (route.some((r) => routes.includes(r))) s += 10;
    for (const f of ['indications_and_usage', 'warnings', 'warnings_and_cautions', 'adverse_reactions', 'drug_interactions', 'purpose']) {
      if (l[f]) s += 1;
    }
    return s;
  };
  // Never use a label for a different way of taking the medicine (e.g. an IV
  // injection label for eye drops): its warnings would be wrong for the
  // patient. No information is safer than the wrong information.
  const sameRoute = results.filter((l) => (l.openfda?.route ?? []).some((r) => routes.includes(r)));
  if (!sameRoute.length) return null;
  return sameRoute.sort((a, b) => score(b) - score(a))[0];
}

/// Label section -> short, readable patient text.
function clean(sections, max = 520) {
  if (!sections || !sections.length) return null;
  let t = sections.join(' ');
  t = t
    .replace(/\[\s*see [^\]]*\]/gi, '')
    // Cross-references whose closing bracket was lost in the source label.
    .replace(
      /\[\s*see (the )?(Boxed Warning|Warnings and Precautions|Adverse Reactions|Clinical Pharmacology|Drug Interactions|Use in Specific Populations|Contraindications|Dosage and Administration)( and (Boxed Warning|Warnings and Precautions|Adverse Reactions))?\s*/gi,
      '',
    )
    .replace(/\s+([.,;:])/g, '$1')
    .replace(/The following [^:.]{0,90}?(described|discussed)[^:.]*?label(ing)?:?/gi, '')
    .replace(/\(\s*\d+(?:\.\d+)*(?:\s*,\s*\d+(?:\.\d+)*)*\s*\)/g, '')
    // US-specific boilerplate that means nothing to a Kenyan patient.
    .replace(/To report SUSPECTED ADVERSE REACTIONS.*?(www\.fda\.gov\/medwatch|$)\.?/gi, '')
    .replace(
      /The following (clinically significant |serious )?adverse reactions are (described|discussed) (elsewhere|in (greater )?detail)( in (other sections of )?the label(ing)?)?:?/gi,
      '',
    )
    .replace(/\s+/g, ' ')
    .trim();
  // Drop the leading section heading ("1 INDICATIONS AND USAGE", "Uses", "WARNINGS").
  t = t.replace(/^(\d+(\.\d+)*\s+)?[A-Z0-9 &,/()'-]{3,}?(?=\s+[A-Z]?[a-z])/, '').trim();
  t = t.replace(/^(uses|use|warnings|directions|purpose)\b[:\s]*/i, '').trim();
  t = t.replace(/^\d+(\.\d+)+\s+/, '');
  if (!t) return null;
  t = t.charAt(0).toUpperCase() + t.slice(1);
  if (t.length <= max) return t;
  const cut = t.slice(0, max);
  const end = Math.max(cut.lastIndexOf('. '), cut.lastIndexOf('; '));
  return (end > max * 0.5 ? cut.slice(0, end + 1) : cut.replace(/\s+\S*$/, '')) + ' …';
}

const pick = (label, ...fields) => {
  for (const f of fields) if (label[f]?.length) return label[f];
  return null;
};

function sqlText(v) {
  if (v === null || v === undefined) return 'null';
  const tag = '$t$';
  if (String(v).includes(tag)) return `'${String(v).replace(/'/g, "''")}'`;
  return `${tag}${v}${tag}`;
}

(async () => {
  const filter = (process.argv[2] || '').toLowerCase();
  const res = await fetch(
    `${env.SUPABASE_URL}/rest/v1/drugs?select=id,generic_name,form&order=generic_name&limit=1000`,
    { headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${env.SUPABASE_ANON_KEY}` } },
  );
  if (!res.ok) throw new Error(`Supabase said ${res.status}`);
  const drugs = (await res.json()).filter((d) => d.generic_name.toLowerCase().includes(filter));

  const rows = [];
  const report = [];
  for (const d of drugs) {
    const key = d.generic_name.toLowerCase();
    try {
      let term = key in OVERRIDES ? OVERRIDES[key] : d.generic_name.replace(FORM_WORDS, '').replace(/-/g, ' / ').trim();
      if (term === null) {
        report.push(`SKIP  ${d.generic_name} (${d.form}) - no suitable public label`);
        continue;
      }
      const rx = await rxnormMatch(term.replace(/ \/ /g, ' '));
      // For hand-mapped products, show the mapping we chose rather than
      // whatever broader concept RxNorm's fuzzy search returned.
      const matched = key in OVERRIDES ? term : rx?.name ?? term;
      const label = await findLabel(ingredientsOf(key in OVERRIDES ? term : matched), routesFor(d.form));
      await sleep(250);
      if (!label) {
        report.push(`MISS  ${d.generic_name} (${d.form}) -> ${matched} - no openFDA label for this form`);
        continue;
      }
      const setId = label.set_id;
      rows.push({
        drug_id: d.id,
        rxcui: rx?.rxcui ?? null,
        matched_name: matched,
        uses: clean(pick(label, 'indications_and_usage', 'purpose')),
        how_to_take: clean(pick(label, 'dosage_and_administration')),
        warnings: clean(pick(label, 'boxed_warning', 'warnings_and_cautions', 'warnings', 'precautions')),
        side_effects: clean(pick(label, 'adverse_reactions', 'stop_use')),
        interactions: clean(pick(label, 'drug_interactions', 'ask_doctor_or_pharmacist')),
        source_url: setId ? `https://dailymed.nlm.nih.gov/dailymed/lookup.cfm?setid=${setId}` : null,
      });
      report.push(`OK    ${d.generic_name} (${d.form}) -> ${matched}${rx ? ` [rxcui ${rx.rxcui}]` : ''} | ${(label.openfda?.route ?? []).join(',')}`);
    } catch (e) {
      report.push(`ERR   ${d.generic_name}: ${e.message}`);
    }
  }

  const cols = ['drug_id', 'rxcui', 'matched_name', 'uses', 'how_to_take', 'warnings', 'side_effects', 'interactions', 'source_url'];
  const sql = [
    '-- Generated by app/tool/import_drug_info.js from RxNorm + openFDA (public domain US labels).',
    '-- Re-run the tool to refresh. Safe to apply repeatedly.',
    ...rows.map(
      (r) =>
        `insert into public.drug_info (${cols.join(', ')}, fetched_at) values (${cols
          .map((c) => sqlText(r[c]))
          .join(', ')}, now())\n  on conflict (drug_id) do update set ${cols
          .slice(1)
          .map((c) => `${c} = excluded.${c}`)
          .join(', ')}, fetched_at = now();`,
    ),
  ].join('\n');

  const out = path.join(__dirname, '..', '..', 'supabase', 'seed', 'drug_info.sql');
  fs.writeFileSync(out, sql + '\n');
  fs.writeFileSync(out.replace(/\.sql$/, '_report.txt'), report.join('\n') + '\n');
  console.log(report.join('\n'));
  console.log(`\n${rows.length} of ${drugs.length} medicines matched. Wrote ${path.relative(process.cwd(), out)}`);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
