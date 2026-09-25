// Finds FREE medicine pictures for testing, from Openverse (openly licensed
// images), restricted to CC0 / public-domain only, so they can be used with no
// licence obligations. Each candidate is downloaded for review and logged with
// its source and licence.
//
//   node tool/find_medicine_images.js search <outDir> <slot> "<query>" [n]
//   node tool/find_medicine_images.js pick <candidateFile> <assetPath>
//
// "pick" copies a reviewed candidate into assets/ and appends its credit to
// assets/images/medicine/CREDITS.md.
//
// These are placeholders for testing. For launch, prefer photos chemists
// upload of the exact packs they sell (the app already supports that).
const fs = require('fs');
const path = require('path');

const CREDITS = path.join(__dirname, '..', 'assets', 'images', 'medicine', 'CREDITS.md');

async function search(outDir, slot, query, n = 6) {
  fs.mkdirSync(outDir, { recursive: true });
  const url =
    'https://api.openverse.org/v1/images/?' +
    new URLSearchParams({
      q: query,
      license: 'cc0,pdm',
      page_size: String(Math.max(n * 2, 10)),
      mature: 'false',
      ...(process.env.SOURCES ? { source: process.env.SOURCES } : {}),
    });
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Openverse ${res.status}`);
  const results = (await res.json()).results.filter(
    (r) => r.width >= 500 && r.height >= 400 && /jpe?g|png/i.test(r.filetype || r.url),
  );
  const picked = [];
  for (const r of results) {
    if (picked.length >= n) break;
    const img = await fetch(r.url);
    if (!img.ok) continue;
    const buf = Buffer.from(await img.arrayBuffer());
    if (buf.length > 1_500_000 || buf.length < 8_000) continue;
    const ext = /png/i.test(img.headers.get('content-type') || '') ? 'png' : 'jpg';
    const file = path.join(outDir, `${slot}_${picked.length + 1}.${ext}`);
    fs.writeFileSync(file, buf);
    fs.writeFileSync(
      file + '.json',
      JSON.stringify(
        {
          title: r.title,
          creator: r.creator,
          license: r.license,
          license_url: r.license_url,
          source: r.foreign_landing_url,
          provider: r.provider,
          size: `${r.width}x${r.height}`,
        },
        null,
        2,
      ),
    );
    picked.push(`${path.basename(file)}  ${r.license}  ${r.width}x${r.height}  ${(buf.length / 1024).toFixed(0)}KB  "${r.title}"`);
  }
  console.log(`${slot}: ${picked.length} candidates\n  ` + picked.join('\n  '));
}

/// Wikimedia Commons directly: much better medical photos than the Openverse
/// index. Accepts only public domain, CC0 or CC BY (credit recorded).
async function commons(outDir, slot, query, n = 4) {
  fs.mkdirSync(outDir, { recursive: true });
  const url =
    'https://commons.wikimedia.org/w/api.php?' +
    new URLSearchParams({
      action: 'query',
      format: 'json',
      generator: 'search',
      gsrnamespace: '6',
      gsrsearch: `${query} filetype:bitmap`,
      gsrlimit: '30',
      prop: 'imageinfo',
      iiprop: 'url|size|extmetadata',
      iiurlwidth: '900',
    });
  const res = await fetch(url, { headers: { 'User-Agent': 'GoDoctor-dev/1.0 (image sourcing for testing)' } });
  const pages = Object.values((await res.json()).query?.pages ?? {}).sort((a, b) => a.index - b.index);
  const picked = [];
  for (const p of pages) {
    if (picked.length >= n) break;
    const ii = p.imageinfo?.[0];
    const meta = ii?.extmetadata ?? {};
    const lic = (meta.LicenseShortName?.value ?? '').trim();
    const ok = /^(public domain|pd|cc0|cc by \d|cc-by-\d)/i.test(lic) && !/sa/i.test(lic);
    if (!ok || !ii.thumburl || ii.width < 500) continue;
    const img = await fetch(ii.thumburl, { headers: { 'User-Agent': 'GoDoctor-dev/1.0' } });
    if (!img.ok) continue;
    const buf = Buffer.from(await img.arrayBuffer());
    const file = path.join(outDir, `${slot}_${picked.length + 1}.jpg`);
    fs.writeFileSync(file, buf);
    const strip = (s) => (s ?? '').replace(/<[^>]+>/g, '').trim();
    fs.writeFileSync(
      file + '.json',
      JSON.stringify(
        {
          title: p.title.replace(/^File:/, ''),
          creator: strip(meta.Artist?.value) || 'unknown',
          license: lic,
          license_url: meta.LicenseUrl?.value ?? '',
          source: ii.descriptionurl,
          provider: 'wikimedia',
          size: `${ii.width}x${ii.height}`,
        },
        null,
        2,
      ),
    );
    picked.push(`${path.basename(file)}  ${lic}  ${ii.width}x${ii.height}  "${p.title}"`);
  }
  console.log(`${slot}: ${picked.length} candidates\n  ` + picked.join('\n  '));
}

function pick(candidate, assetPath) {
  const meta = JSON.parse(fs.readFileSync(candidate + '.json', 'utf8'));
  const dest = path.join(__dirname, '..', assetPath + path.extname(candidate));
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(candidate, dest);
  if (!fs.existsSync(CREDITS)) {
    fs.writeFileSync(
      CREDITS,
      '# Medicine picture credits\n\n' +
        'Placeholder pictures for testing, from [Openverse](https://openverse.org), all\n' +
        'CC0 or public domain (free for any use, attribution not required but given\n' +
        'here anyway). Replace with chemist-uploaded or your own photos before launch.\n\n' +
        '| File | Title | Creator | Licence | Source |\n|---|---|---|---|---|\n',
    );
  }
  const rel = path.relative(path.join(__dirname, '..'), dest).replace(/\\/g, '/');
  fs.appendFileSync(
    CREDITS,
    `| \`${rel}\` | ${meta.title || ''} | ${meta.creator || 'unknown'} | ${meta.license.toUpperCase()} | ${meta.source} |\n`,
  );
  console.log(`picked ${rel}`);
}

const [cmd, ...args] = process.argv.slice(2);
(cmd === 'search' ? search(...args) : cmd === 'commons' ? commons(...args) : Promise.resolve(pick(...args))).catch((e) => {
  console.error(e.message);
  process.exit(1);
});
