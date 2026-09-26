// Sends one in-app notification to the person's phones/browsers through
// Firebase Cloud Messaging (HTTP v1).
//
// Called by the `notifications_push` database trigger (pg_net) with
// { record: <notifications row> } and the shared secret in `x-push-secret`.
// Secrets: FCM_SERVICE_ACCOUNT (service-account JSON), FCM_PROJECT_ID,
// PUSH_WEBHOOK_SECRET. SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are
// provided by the platform.
import { createClient } from 'npm:@supabase/supabase-js@2';

type NotificationRow = {
  id: string;
  user_id: string;
  kind: string;
  title: string;
  body: string | null;
  data: Record<string, unknown> | null;
};

// Category decides the Android channel (sound/importance) and which
// switch in Settings can mute it. Urgent can't be muted.
const CATEGORY: Record<string, string> = {
  patient_selected: 'urgent',
  patient_paid: 'urgent',
  patient_waiting: 'urgent',
  doctor_ready: 'urgent',
  payment_window_ending: 'urgent',
  family_session_invite: 'urgent',
  order_new: 'urgent',

  appointment_booked: 'consultations',
  appointment_cancelled: 'consultations',
  appointment_rescheduled: 'consultations',
  appointment_reminder: 'consultations',
  consultation_completed: 'consultations',
  consultation_cancelled: 'consultations',
  request_expired: 'consultations',
  patient_cancelled: 'consultations',
  family_joined: 'consultations',
  review_new: 'consultations',

  chat_message: 'chat',

  dose_due: 'reminders',

  prescription_issued: 'orders',
  order_confirmed: 'orders',
  order_ready: 'orders',
  order_completed: 'orders',
  order_disputed: 'orders',
  order_refunded: 'orders',
  payment_receipt: 'orders',

  family_invite: 'family',
  family_accepted: 'family',

  support_reply: 'support',
  support_new: 'support',
  support_user_reply: 'support',

  verification_approved: 'account',
  verification_removed: 'account',
  verification_submitted: 'account',
  emergency_flagged: 'account',
  announcement: 'account',
  test_push: 'account',
};

const SECRET = Deno.env.get('PUSH_WEBHOOK_SECRET') ?? '';
const SERVICE_ACCOUNT = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT') ?? '{}');
const PROJECT = Deno.env.get('FCM_PROJECT_ID') ?? SERVICE_ACCOUNT.project_id;

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false } },
);

// ---------------------------------------------------------------------------
// Google OAuth token from the service account (cached ~55 min)
// ---------------------------------------------------------------------------
let cached: { token: string; expires: number } | null = null;

function b64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === 'string'
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function accessToken(): Promise<string> {
  if (cached && Date.now() < cached.expires) return cached.token;
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(JSON.stringify({
    iss: SERVICE_ACCOUNT.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const pem = (SERVICE_ACCOUNT.private_key as string)
    .replace(/-----[A-Z ]+-----/g, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${header}.${claims}.${b64url(signature)}`,
    }),
  });
  const json = await res.json();
  if (!json.access_token) throw new Error(`oauth failed: ${res.status}`);
  cached = { token: json.access_token, expires: Date.now() + 55 * 60 * 1000 };
  return cached.token;
}

// ---------------------------------------------------------------------------
// Send
// ---------------------------------------------------------------------------
function message(n: NotificationRow, token: string, category: string) {
  const urgent = category === 'urgent';
  // FCM data values must be strings.
  const data: Record<string, string> = {
    notification_id: n.id,
    kind: n.kind,
    category,
  };
  for (const [k, v] of Object.entries(n.data ?? {})) {
    if (v !== null && v !== undefined) data[k] = typeof v === 'string' ? v : JSON.stringify(v);
  }
  return {
    message: {
      token,
      notification: { title: n.title, body: n.body ?? '' },
      data,
      android: {
        priority: urgent ? 'HIGH' : 'NORMAL',
        ttl: urgent ? '600s' : '86400s',
        notification: {
          channel_id: category,
          icon: 'ic_stat_godoctor',
          color: '#1B63F2',
          sound: 'default',
          tag: n.id,
        },
      },
      webpush: {
        headers: { Urgency: urgent ? 'high' : 'normal', TTL: urgent ? '600' : '86400' },
        notification: { icon: '/icons/Icon-192.png', badge: '/icons/Icon-192.png', tag: n.id },
      },
    },
  };
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('method not allowed', { status: 405 });
  if (!SECRET || req.headers.get('x-push-secret') !== SECRET) {
    return new Response('unauthorized', { status: 401 });
  }

  let n: NotificationRow;
  try {
    n = (await req.json()).record;
  } catch {
    return new Response('bad request', { status: 400 });
  }
  if (!n?.user_id || !n?.title) return new Response('bad request', { status: 400 });

  const category = CATEGORY[n.kind] ?? 'account';

  // Respect muted categories (urgent always goes through).
  if (category !== 'urgent') {
    const { data: settings } = await supabase
      .from('user_settings')
      .select('push_off')
      .eq('user_id', n.user_id)
      .maybeSingle();
    if ((settings?.push_off ?? []).includes(category)) {
      return Response.json({ skipped: 'muted', category });
    }
  }

  const { data: devices, error } = await supabase
    .from('device_tokens')
    .select('token, platform')
    .eq('user_id', n.user_id);
  if (error) return Response.json({ error: error.message }, { status: 500 });
  if (!devices?.length) return Response.json({ skipped: 'no devices' });

  const bearer = await accessToken();
  const results = await Promise.all(
    devices.map(async (d) => {
      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${PROJECT}/messages:send`,
        {
          method: 'POST',
          headers: { authorization: `Bearer ${bearer}`, 'content-type': 'application/json' },
          body: JSON.stringify(message(n, d.token, category)),
        },
      );
      if (res.ok) return 'sent';
      const body = await res.json().catch(() => ({}));
      const code = body?.error?.details?.find?.((x: { errorCode?: string }) => x.errorCode)?.errorCode
        ?? body?.error?.status;
      // App uninstalled / token expired: forget this device.
      if (res.status === 404 || code === 'UNREGISTERED' || code === 'INVALID_ARGUMENT') {
        await supabase.from('device_tokens').delete().eq('token', d.token);
        return 'removed';
      }
      console.error('fcm error', res.status, code);
      return 'failed';
    }),
  );

  if (results.includes('sent')) {
    await supabase.from('notifications').update({ push_sent_at: new Date().toISOString() }).eq('id', n.id);
  }
  return Response.json({ category, results });
});
