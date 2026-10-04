// GoDoctor HQ: staff accounts. Creating a sign-in needs the service key, so
// the console calls this function; it checks the caller may manage staff
// (erp_can('staff.manage')) using their own session first.
//
//   POST /functions/v1/erp-staff
//   Authorization: Bearer <the staff member's access token>
//   { "action": "create", "email": "...", "full_name": "...", "role": "support",
//     "job_title": "...", "department": "...", "phone": "..." }
//     -> { user_id, temporary_password }
//   { "action": "reset_password", "user_id": "..." }
//     -> { temporary_password }
//
// The temporary password is shown once in HQ for the administrator to pass
// on; the staff member changes it from their profile. Deployed with
// --no-verify-jwt: it verifies the caller itself.
import { createClient } from 'npm:@supabase/supabase-js@2';

const URL = Deno.env.get('SUPABASE_URL')!;
const ANON = Deno.env.get('SUPABASE_ANON_KEY')!;
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** 14 characters that are easy to read out and type (no 0/O, 1/l/I). */
function temporaryPassword(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(14));
  const s = [...bytes].map((b) => chars[b % chars.length]).join('');
  return `${s.slice(0, 5)}-${s.slice(5, 10)}-${s.slice(10)}`;
}

const clean = (v: unknown, max = 120) =>
  typeof v === 'string' ? v.trim().slice(0, max) : '';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json(405, { error: 'POST only' });

  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return json(401, { error: 'Sign in to HQ first.' });

  // The caller, as themselves.
  const asCaller = createClient(URL, ANON, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false },
  });
  const { data: who, error: whoError } = await asCaller.auth.getUser(token);
  if (whoError || !who.user) return json(401, { error: 'Your session has ended. Sign in again.' });
  const { data: allowed } = await asCaller.rpc('erp_can', { p_permission: 'staff.manage' });
  if (allowed !== true) return json(403, { error: 'You don’t have permission to manage staff.' });

  const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: 'Invalid request.' });
  }

  if (body.action === 'create') {
    const email = clean(body.email, 200).toLowerCase();
    const fullName = clean(body.full_name);
    const role = clean(body.role, 40);
    if (!EMAIL.test(email)) return json(400, { error: 'Enter a valid email address.' });
    if (fullName.length < 2) return json(400, { error: 'Enter their full name.' });
    const { data: roleRow } = await admin.from('erp_roles').select('key').eq('key', role).maybeSingle();
    if (!roleRow) return json(400, { error: 'Choose a role.' });

    const password = temporaryPassword();
    const { data: created, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name: fullName },
    });
    if (error || !created.user) {
      const taken = /already|registered|exists/i.test(error?.message ?? '');
      return json(400, {
        error: taken
          ? 'That email already has a GoDoctor account. Use a different email for staff.'
          : `Couldn’t create the account: ${error?.message ?? 'unknown error'}`,
      });
    }
    const id = created.user.id;

    // Sign-up makes everyone a patient; turn this account into staff.
    const steps = [
      await admin.from('users').update({ role: 'staff' }).eq('id', id),
      await admin.from('patient_profiles').delete().eq('user_id', id),
      await admin.from('erp_staff').insert({
        user_id: id,
        full_name: fullName,
        role,
        job_title: clean(body.job_title),
        department: clean(body.department),
        phone: clean(body.phone, 40) || null,
        created_by: who.user.id,
      }),
      await admin.from('erp_log').insert({
        actor_id: who.user.id,
        action: 'staff.created',
        entity_type: 'staff',
        entity_id: id,
        summary: `Added ${fullName} as ${role}`,
      }),
    ];
    const failed = steps.find((s) => s.error);
    if (failed) {
      await admin.auth.admin.deleteUser(id);
      return json(500, { error: `Couldn’t set up the account: ${failed.error!.message}` });
    }
    return json(200, { user_id: id, temporary_password: password });
  }

  if (body.action === 'reset_password') {
    const id = clean(body.user_id, 60);
    if (!UUID.test(id)) return json(400, { error: 'Unknown staff member.' });
    if (id === who.user.id) {
      return json(400, { error: 'Change your own password from My profile.' });
    }
    const { data: staff } = await admin
      .from('erp_staff')
      .select('full_name, role')
      .eq('user_id', id)
      .maybeSingle();
    if (!staff) return json(400, { error: 'That account isn’t a staff member.' });

    const password = temporaryPassword();
    const { error } = await admin.auth.admin.updateUserById(id, { password });
    if (error) return json(500, { error: `Couldn’t reset the password: ${error.message}` });
    await admin.from('erp_log').insert({
      actor_id: who.user.id,
      action: 'staff.password_reset',
      entity_type: 'staff',
      entity_id: id,
      summary: `Reset the password of ${staff.full_name}`,
    });
    return json(200, { temporary_password: password });
  }

  return json(400, { error: 'Unknown action.' });
});
