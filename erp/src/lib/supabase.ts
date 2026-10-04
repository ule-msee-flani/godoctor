import { createClient } from '@supabase/supabase-js';

export const configured = Boolean(__SUPABASE_URL__ && __SUPABASE_ANON_KEY__);

/** The same database as the GoDoctor app. Staff sign in with their own
 * account; every view and function checks their permissions on the server. */
export const supabase = createClient(
  __SUPABASE_URL__ || 'https://invalid.local',
  __SUPABASE_ANON_KEY__ || 'missing',
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      storageKey: 'godoctor-hq-auth',
    },
  },
);

/** Calls a database function and throws a friendly error on failure. */
export async function rpc<T = unknown>(name: string, params?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(name, params);
  if (error) throw new Error(friendlyError(error.message));
  return data as T;
}

const MESSAGES: Record<string, string> = {
  not_allowed: 'You don’t have permission to do that.',
  reason_required: 'Please give a reason (at least 3 characters).',
  reference_required: 'Please enter the payment reference.',
  not_found: 'That record no longer exists.',
  cannot_change_own_account: 'You can’t change your own account here.',
  cannot_suspend_admin: 'Administrator accounts can’t be suspended.',
  cannot_change_own_role: 'You can’t change your own role.',
  last_administrator: 'GoDoctor needs at least one administrator.',
  already_finished: 'That consultation has already finished.',
  already_refunded: 'That payment was already refunded.',
  not_paid: 'Only successful payments can be refunded.',
  not_pending: 'Only pending payouts can be changed.',
  invalid_period: 'Choose a valid period (the end can’t be before the start).',
  role_locked: 'The Administrator role always has every permission.',
  not_a_provider: 'That account isn’t a doctor or pharmacy.',
  empty_message: 'Write a message first.',
  not_staff: 'That person isn’t an active staff member.',
};

export function friendlyError(message: string): string {
  for (const [code, text] of Object.entries(MESSAGES)) {
    if (message.includes(code)) return text;
  }
  if (/JWT|token/i.test(message)) return 'Your session has ended. Please sign in again.';
  if (/fetch|network/i.test(message)) return 'Couldn’t reach the server. Check your connection.';
  return message;
}
