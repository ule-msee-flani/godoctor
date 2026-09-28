// Lets a pharmacy's own stock system (ERP / point of sale) keep its
// GoDoctor stock up to date.
//
//   POST /functions/v1/inventory-sync
//   Authorization: Bearer gdk_...   (a connection key made in the app)
//   { "items": [ { "name": "Panadol 500mg", "quantity": 240, "price": 5 },
//                { "drug_id": "<catalogue id>", "quantity": 0, "price": 12 } ] }
//
// Replies { saved, not_matched: [names], invalid: [indexes] }. Names are
// matched to the catalogue with public.match_drugs. Only the key's own
// pharmacy is touched. Deployed with --no-verify-jwt: the connection key is
// the credential (only its sha256 is stored).
import { createClient } from 'npm:@supabase/supabase-js@2';

const MAX_ITEMS = 2000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type Item = { name?: unknown; drug_id?: unknown; quantity?: unknown; price?: unknown };

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

async function sha256Hex(text: string): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'use_post' });

  const key = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '').trim();
  if (!/^gdk_[0-9a-f]{48}$/.test(key)) return json(401, { error: 'invalid_key' });

  const db = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  const { data: apiKey } = await db
    .from('chemist_api_keys')
    .select('id, chemist_id')
    .eq('key_hash', await sha256Hex(key))
    .is('revoked_at', null)
    .maybeSingle();
  if (!apiKey) return json(401, { error: 'invalid_key' });

  const { data: pharmacy } = await db
    .from('chemist_profiles')
    .select('verified')
    .eq('user_id', apiKey.chemist_id)
    .maybeSingle();
  if (!pharmacy?.verified) return json(403, { error: 'pharmacy_not_verified' });

  let body: { items?: unknown };
  try {
    body = await req.json();
  } catch {
    return json(400, { error: 'invalid_json' });
  }
  if (!Array.isArray(body?.items)) return json(400, { error: 'items_required' });
  const items = body.items as Item[];
  if (items.length > MAX_ITEMS) return json(413, { error: 'too_many_items', max: MAX_ITEMS });

  // Names -> catalogue ids.
  const nameOf = (it: Item) => (typeof it?.name === 'string' ? it.name.trim() : '');
  const names = [...new Set(items.filter((it) => typeof it?.drug_id !== 'string').map(nameOf))]
    .filter((n) => n.length > 0 && n.length <= 200);
  const byName = new Map<string, string | null>();
  for (let i = 0; i < names.length; i += 400) {
    const { data, error } = await db.rpc('match_drugs', { p_names: names.slice(i, i + 400) });
    if (error) return json(500, { error: 'match_failed' });
    for (const r of (data ?? []) as { name: string; drug_id: string | null }[]) {
      byName.set(r.name, r.drug_id);
    }
  }

  // Catalogue ids sent directly must exist.
  const direct = [...new Set(items.map((it) => it?.drug_id).filter(
    (id): id is string => typeof id === 'string' && UUID.test(id),
  ))];
  const known = new Set<string>();
  for (let i = 0; i < direct.length; i += 200) {
    const { data } = await db.from('drugs').select('id').in('id', direct.slice(i, i + 200));
    for (const d of data ?? []) known.add(d.id as string);
  }

  const rows = new Map<string, { chemist_id: string; drug_id: string; quantity: number; price: number }>();
  const notMatched: string[] = [];
  const invalid: number[] = [];
  items.forEach((it, index) => {
    const quantity = Number(it?.quantity);
    const price = Number(it?.price);
    if (!Number.isFinite(quantity) || quantity < 0 || !Number.isFinite(price) || price < 0) {
      invalid.push(index);
      return;
    }
    const drugId = typeof it?.drug_id === 'string'
      ? (known.has(it.drug_id) ? it.drug_id : null)
      : byName.get(nameOf(it)) ?? null;
    if (!drugId) {
      notMatched.push(nameOf(it) || String(it?.drug_id ?? ''));
      return;
    }
    // The same medicine twice: the last line wins.
    rows.set(drugId, {
      chemist_id: apiKey.chemist_id,
      drug_id: drugId,
      quantity: Math.min(100000, Math.round(quantity)),
      price: Math.min(1000000, Math.round(price * 100) / 100),
    });
  });

  if (rows.size > 0) {
    const { error } = await db
      .from('chemist_inventory')
      .upsert([...rows.values()], { onConflict: 'chemist_id,drug_id' });
    if (error) return json(500, { error: 'save_failed' });
  }
  await db.from('chemist_api_keys').update({ last_used_at: new Date().toISOString() }).eq('id', apiKey.id);

  return json(200, { saved: rows.size, not_matched: notMatched, invalid });
});
