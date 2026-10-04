import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../lib/auth';
import { rpc, supabase } from '../lib/supabase';
import { ago, dateTime } from '../lib/format';
import { Avatar, Button, Postbox, useDialog, useNotice } from './ui';

interface Note { id: string; body: string; created_at: string; author_name: string }

/** Internal notes on any record: only staff see them. */
export function Notes({ type, id }: { type: string; id: string }) {
  const notice = useNotice();
  const [notes, setNotes] = useState<Note[]>([]);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const { data } = await supabase
      .from('erp_note_list')
      .select('*')
      .eq('entity_type', type)
      .eq('entity_id', id)
      .order('created_at', { ascending: false });
    setNotes((data ?? []) as Note[]);
  }, [type, id]);

  useEffect(() => {
    load();
  }, [load]);

  return (
    <Postbox title="Internal notes">
      <form
        className="note-form"
        onSubmit={async (e) => {
          e.preventDefault();
          if (!text.trim()) return;
          setBusy(true);
          try {
            await rpc('erp_add_note', { p_entity_type: type, p_entity_id: id, p_body: text.trim() });
            setText('');
            load();
          } catch (err) {
            notice.error((err as Error).message);
          } finally {
            setBusy(false);
          }
        }}
      >
        <textarea
          rows={2}
          placeholder="Add a note for the team (patients and providers never see it)"
          value={text}
          onChange={(e) => setText(e.target.value)}
        />
        <Button type="submit" busy={busy} disabled={!text.trim()}>Add note</Button>
      </form>
      {notes.length === 0 ? (
        <p className="muted small">No notes yet.</p>
      ) : (
        <ul className="notes">
          {notes.map((n) => (
            <li key={n.id}>
              <Avatar name={n.author_name} size={26} />
              <div>
                <div className="note-meta">
                  <b>{n.author_name}</b> <span title={dateTime(n.created_at)}>{ago(n.created_at)}</span>
                </div>
                <p>{n.body}</p>
              </div>
            </li>
          ))}
        </ul>
      )}
    </Postbox>
  );
}

interface Entry { id: number; at: string; actor_name: string; summary: string; reason: string | null }

/** What staff did with this record (for staff who can see the log). */
export function History({ id, refreshKey = 0 }: { id: string; refreshKey?: number }) {
  const { can } = useAuth();
  const [items, setItems] = useState<Entry[]>([]);
  useEffect(() => {
    if (!can('audit.view')) return;
    supabase
      .from('erp_activity')
      .select('*')
      .eq('entity_id', id)
      .order('at', { ascending: false })
      .limit(20)
      .then(({ data }) => setItems((data ?? []) as Entry[]));
  }, [id, can, refreshKey]);
  if (!can('audit.view')) return null;
  return (
    <Postbox title="History">
      {items.length === 0 ? (
        <p className="muted small">No staff actions on this record yet.</p>
      ) : (
        <ul className="feed">
          {items.map((e) => (
            <li key={e.id}>
              <span className="feed-when" title={dateTime(e.at)}>{ago(e.at)}</span>
              <span>
                <b>{e.actor_name}</b> · {e.summary}
                {e.reason && <span className="muted"> — “{e.reason}”</span>}
              </span>
            </li>
          ))}
        </ul>
      )}
    </Postbox>
  );
}

/** Suspend / restore an account, with a reason. */
export function AccountBox({
  userId, status, perm, onChanged,
}: { userId: string; status: string; perm: string; onChanged: () => void }) {
  const { can } = useAuth();
  const notice = useNotice();
  const [busy, setBusy] = useState(false);
  const suspended = status === 'suspended';
  return (
    <Postbox title="Account">
      <p className="small">
        {suspended
          ? 'This account is suspended: it can’t sign in, and it’s hidden from patients.'
          : 'This account is active.'}
      </p>
      {can(perm) && (
        <SuspendButton userId={userId} suspended={suspended} busy={busy} setBusy={setBusy}
          onDone={() => {
            notice.success(suspended ? 'Account restored.' : 'Account suspended.');
            onChanged();
          }}
          onError={(m) => notice.error(m)}
        />
      )}
    </Postbox>
  );
}


function SuspendButton({
  userId, suspended, busy, setBusy, onDone, onError,
}: {
  userId: string; suspended: boolean; busy: boolean; setBusy: (b: boolean) => void;
  onDone: () => void; onError: (m: string) => void;
}) {
  const dialog = useDialog();
  return (
    <Button
      variant={suspended ? 'secondary' : 'danger'}
      busy={busy}
      onClick={async () => {
        const reason = await dialog.ask(
          suspended
            ? { title: 'Restore this account?', message: 'They’ll be able to sign in again.', confirm: 'Restore', reason: 'optional' }
            : {
                title: 'Suspend this account?',
                message: 'They’ll be signed out everywhere and can’t sign in until restored.',
                confirm: 'Suspend', danger: true, reason: 'required',
              },
        );
        if (reason === null) return;
        setBusy(true);
        try {
          await rpc('erp_set_account_status', {
            p_user: userId, p_status: suspended ? 'active' : 'suspended', p_reason: reason,
          });
          onDone();
        } catch (e) {
          onError((e as Error).message);
        } finally {
          setBusy(false);
        }
      }}
    >
      {suspended ? 'Restore account' : 'Suspend account'}
    </Button>
  );
}
