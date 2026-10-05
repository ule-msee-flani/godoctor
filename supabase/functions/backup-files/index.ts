// Lists every stored file (licences, documents, photos) with a download link
// that works for 10 minutes, for the weekly backup (.github/workflows/
// backup.yml). Only a caller with the shared secret gets an answer, and it
// can only read: nothing here changes or deletes a file.
//
//   POST /functions/v1/backup-files
//   x-backup-token: <BACKUP_FILES_TOKEN>
//     -> { files: [{ bucket, path, size, url }] }
//
// Secret: BACKUP_FILES_TOKEN (also a repository secret for the workflow).
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided by the platform.
// Deployed with --no-verify-jwt: the token is the check.
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

const URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const TOKEN = Deno.env.get('BACKUP_FILES_TOKEN') ?? '';

type Item = { bucket: string; path: string; size: number | null };

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

/** Compares without giving away how much of the token was right. */
function tokenMatches(given: string): boolean {
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(TOKEN);
  let diff = a.length ^ b.length;
  for (let i = 0; i < b.length; i++) diff |= (a[i] ?? 0) ^ b[i];
  return diff === 0;
}

/** Every file under `prefix`, going into folders (entries without an id). */
async function walk(admin: SupabaseClient, bucket: string, prefix: string, out: Item[]) {
  for (let offset = 0; ; offset += 100) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, {
      limit: 100,
      offset,
      sortBy: { column: 'name', order: 'asc' },
    });
    if (error) throw new Error(`${bucket}/${prefix}: ${error.message}`);
    for (const entry of data) {
      const path = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.id === null) await walk(admin, bucket, path, out);
      else out.push({ bucket, path, size: entry.metadata?.size ?? null });
    }
    if (data.length < 100) return;
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'POST only' });
  // Without a long token set, nobody gets in.
  if (TOKEN.length < 32 || !tokenMatches(req.headers.get('x-backup-token') ?? '')) {
    return json(401, { error: 'unauthorized' });
  }

  const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
  try {
    const { data: buckets, error } = await admin.storage.listBuckets();
    if (error) throw new Error(`buckets: ${error.message}`);

    const files: (Item & { url: string })[] = [];
    for (const { name: bucket } of buckets) {
      const items: Item[] = [];
      await walk(admin, bucket, '', items);
      for (let i = 0; i < items.length; i += 100) {
        const batch = items.slice(i, i + 100);
        const { data: signed, error: signError } = await admin.storage
          .from(bucket)
          .createSignedUrls(batch.map((f) => f.path), 600);
        if (signError) throw new Error(`${bucket}: ${signError.message}`);
        batch.forEach((f, j) => {
          const url = signed[j]?.signedUrl;
          if (!url) throw new Error(`${bucket}/${f.path}: no download link`);
          files.push({ ...f, url });
        });
      }
    }
    return json(200, { files });
  } catch (e) {
    return json(500, { error: (e as Error).message });
  }
});
