// Writes assets/images/medicine/products/NAMES.txt: the exact file name to use
// for each medicine's product picture, straight from the live catalogue.
//
//   node tool/generate_medicine_names.js
//
// Reads SUPABASE_URL / SUPABASE_ANON_KEY from app/.env (the drugs table is
// public-read, so the public anon key is enough). Keep the slug() rule in sync
// with medicineSlug() in lib/data/models/medicine_category.dart.
const fs = require('fs');
const path = require('path');

const env = Object.fromEntries(
  fs
    .readFileSync(path.join(__dirname, '..', '.env'), 'utf8')
    .split(/\r?\n/)
    .filter((l) => l.includes('=') && !l.trim().startsWith('#'))
    .map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim()]),
);

const slug = (s) =>
  s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');

function category(form) {
  const f = (form || '').toLowerCase();
  if (!f) return 'other';
  if (/eye|ear|nasal|drop|spray|inhaler/.test(f)) return 'drops';
  if (f.includes('tablet')) return 'tablets';
  if (f.includes('capsule')) return 'capsules';
  if (/syrup|sachet|suspension|solution|liquid/.test(f)) return 'syrups';
  if (/cream|lotion|gel|ointment|topical/.test(f)) return 'creams';
  if (/inject|infusion|\biv\b/.test(f)) return 'injections';
  return 'other';
}

(async () => {
  const res = await fetch(
    `${env.SUPABASE_URL}/rest/v1/drugs?select=generic_name,form,requires_prescription&order=generic_name&limit=1000`,
    { headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${env.SUPABASE_ANON_KEY}` } },
  );
  if (!res.ok) throw new Error(`Supabase said ${res.status}: ${await res.text()}`);
  const drugs = await res.json();

  const count = {};
  for (const d of drugs) count[slug(d.generic_name)] = (count[slug(d.generic_name)] || 0) + 1;

  const lines = [
    'PRODUCT PICTURE FILE NAMES',
    '==========================',
    'Save a picture in this folder (png / jpg / webp) named exactly as shown below.',
    'Where a medicine comes in more than one form, use the form-specific name to',
    'give each form its own picture, or the plain name to use one picture for all.',
    '',
    'Regenerate this list any time with:  node tool/generate_medicine_names.js',
    '',
  ];
  for (const d of drugs) {
    const base = slug(d.generic_name);
    const withForm = `${base}-${slug(d.form || 'other')}`;
    const rx = d.requires_prescription ? '  [Rx]' : '';
    const dup = count[base] > 1;
    lines.push(
      `${(dup ? withForm : base).padEnd(52)} ${d.generic_name} (${d.form || 'no form'}) -> ${category(d.form)}${rx}` +
        (dup ? `\n${' '.repeat(52)} (or just "${base}" to share one picture across forms)` : ''),
    );
  }
  const out = path.join(__dirname, '..', 'assets', 'images', 'medicine', 'products', 'NAMES.txt');
  fs.writeFileSync(out, lines.join('\n') + '\n');
  console.log(`Wrote ${drugs.length} names to ${path.relative(process.cwd(), out)}`);
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
