import { useCallback, useEffect, useState } from 'react';
import { Bell, Send } from 'lucide-react';
import { useAuth } from '../lib/auth';
import { rpc, supabase } from '../lib/supabase';
import type { Route } from '../lib/router';
import { ago, date, dateTime, label, shortId } from '../lib/format';
import { DataTable, type Column, type Row } from '../components/DataTable';
import { History, Notes } from '../components/RecordExtras';
import {
  Avatar, Button, Empty, Facts, Field, PageHeader, Pill, Postbox, Spinner, useDialog, useNotice,
} from '../components/ui';

const PROFILE_PATH: Record<string, string> = { patient: 'patients', doctor: 'doctors', chemist: 'pharmacies' };
const ROLE_NAME: Record<string, string> = { patient: 'Patient', doctor: 'Doctor', chemist: 'Pharmacy', staff: 'Staff', admin: 'Admin' };

export function TicketsPage({ route }: { route: Route }) {
  const { me, can } = useAuth();
  const notice = useNotice();
  const [refresh, setRefresh] = useState(0);

  const update = async (r: Row, patch: Record<string, unknown>, done: string) => {
    try {
      await rpc('erp_ticket_update', { p_id: r.id, ...patch });
      notice.success(done);
      setRefresh((n) => n + 1);
    } catch (e) {
      notice.error((e as Error).message);
    }
  };

  const columns: Column[] = [
    {
      key: 'subject', label: 'Ticket', primary: true,
      render: (r) => (
        <span className="stack">
          <span>{r.subject}</span>
          <small className="muted">{label(r.kind)} · #{shortId(r.id)}</small>
        </span>
      ),
    },
    {
      key: 'user_name', label: 'From',
      render: (r) => (
        <span className="stack">
          {PROFILE_PATH[r.user_role] ? <a href={`#/${PROFILE_PATH[r.user_role]}/${r.user_id}`}>{r.user_name}</a> : r.user_name}
          <small className="muted">{ROLE_NAME[r.user_role] ?? r.user_role}</small>
        </span>
      ),
    },
    { key: 'status', label: 'Status', render: (r) => <Pill value={r.status} /> },
    { key: 'priority', label: 'Priority', render: (r) => <Pill value={r.priority} /> },
    { key: 'assignee_name', label: 'Assigned to', render: (r) => r.assignee_name || <span className="muted">Nobody yet</span> },
    {
      key: 'last_message_at', label: 'Last message',
      render: (r) => (
        <span className="stack">
          <span>{ago(r.last_message_at)}</span>
          <small className={r.last_from_staff ? 'muted' : 'warn-text'}>
            {r.last_from_staff ? 'We replied' : r.status === 'closed' ? '' : 'Waiting for us'}
          </small>
        </span>
      ),
      csv: (r) => r.last_message_at,
    },
  ];

  return (
    <>
      <PageHeader title="Support">Questions and problems from patients, doctors and pharmacies.</PageHeader>
      <DataTable
        view="erp_tickets" columns={columns}
        search={['subject', 'user_name']} searchLabel="Search tickets"
        initialFilter={route.query.get('filter')}
        filters={[
          { key: 'open', label: 'Open', apply: (q) => q.eq('status', 'open') },
          { key: 'mine', label: 'Assigned to me', apply: (q) => q.eq('assigned_to', me!.id).neq('status', 'closed') },
          { key: 'unassigned', label: 'Unassigned', apply: (q) => q.is('assigned_to', null).neq('status', 'closed') },
          { key: 'answered', label: 'Answered', apply: (q) => q.eq('status', 'answered') },
          { key: 'closed', label: 'Closed', apply: (q) => q.eq('status', 'closed') },
          { key: 'all', label: 'All' },
        ]}
        defaultSort={{ key: 'last_message_at', asc: false }}
        rowHref={(r) => `#/support/${r.id}`}
        rowActions={(r) => [
          { label: 'Open', href: `#/support/${r.id}` },
          ...(can('support.manage') && r.assigned_to !== me?.id
            ? [{ label: 'Assign to me', onClick: () => update(r, { p_assignee: me!.id }, 'Assigned to you.') }]
            : []),
          ...(can('support.manage') && r.status !== 'closed'
            ? [{ label: 'Close', onClick: () => update(r, { p_status: 'closed' }, 'Ticket closed.') }]
            : []),
        ]}
        exportName="support-tickets" refreshKey={refresh}
        emptyText="No tickets here."
      />
    </>
  );
}

interface Message { id: string; created_at: string; body: string; from_staff: boolean; sender_name: string }

export function TicketPage({ id }: { id: string }) {
  const { me, can } = useAuth();
  const notice = useNotice();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const [t, setT] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [staff, setStaff] = useState<{ id: string; full_name: string }[]>([]);
  const [reply, setReply] = useState('');
  const [busy, setBusy] = useState(false);
  const [refresh, setRefresh] = useState(0);

  const load = useCallback(async () => {
    const [{ data, error: e }, { data: m }] = await Promise.all([
      supabase.from('erp_tickets').select('*').eq('id', id).maybeSingle(),
      supabase.from('erp_ticket_messages').select('*').eq('ticket_id', id).order('created_at', { ascending: true }),
    ]);
    if (e) setError(e.message);
    else if (!data) setError('This ticket doesn’t exist, or you can’t see it.');
    else setT(data);
    setMessages((m ?? []) as Message[]);
  }, [id]);

  useEffect(() => {
    load();
    const timer = setInterval(load, 20000);
    return () => clearInterval(timer);
  }, [load, refresh]);

  useEffect(() => {
    supabase.from('erp_staff_list').select('id, full_name').eq('status', 'active').order('full_name')
      .then(({ data }) => setStaff((data ?? []) as { id: string; full_name: string }[]));
  }, []);

  if (error) return <Empty title="Couldn’t open this ticket">{error}</Empty>;
  if (!t) return <Spinner />;

  const update = async (patch: Record<string, unknown>) => {
    try {
      await rpc('erp_ticket_update', { p_id: id, ...patch });
      setRefresh((n) => n + 1);
    } catch (e) {
      notice.error((e as Error).message);
    }
  };

  return (
    <>
      <a href="#/support" className="back">← Support</a>
      <div className="record-head">
        <div>
          <h1>{t.subject}</h1>
          <div className="record-meta">
            <Pill value={t.status} /> <Pill value={t.priority} /> <span>{label(t.kind)}</span>
            <span>Opened {dateTime(t.created_at)}</span>
          </div>
        </div>
      </div>
      <div className="record-grid">
        <div className="record-main">
          <Postbox title="Conversation">
            <ul className="thread">
              {messages.map((m) => (
                <li key={m.id} className={m.from_staff ? 'from-us' : ''}>
                  <Avatar name={m.sender_name} size={30} />
                  <div className="bubble">
                    <div className="bubble-meta"><b>{m.sender_name}</b> <span title={dateTime(m.created_at)}>{ago(m.created_at)}</span></div>
                    <p>{m.body}</p>
                  </div>
                </li>
              ))}
              {messages.length === 0 && <p className="muted">No messages yet.</p>}
            </ul>
            {can('support.manage') && (
              <form
                className="reply"
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!reply.trim()) return;
                  setBusy(true);
                  try {
                    await rpc('erp_ticket_reply', { p_id: id, p_body: reply.trim() });
                    setReply('');
                    notice.success(`Reply sent. ${t.user_name} gets a notification.`);
                    setRefresh((n) => n + 1);
                  } catch (err) {
                    notice.error((err as Error).message);
                  } finally {
                    setBusy(false);
                  }
                }}
              >
                <textarea
                  rows={4} value={reply} onChange={(e) => setReply(e.target.value)}
                  placeholder={`Reply to ${t.user_name}… (they see it in the app, signed “GoDoctor support”)`}
                />
                <div className="reply-actions">
                  <Button type="submit" variant="primary" busy={busy} disabled={!reply.trim()}><Send size={15} /> Send reply</Button>
                </div>
              </form>
            )}
          </Postbox>
        </div>
        <aside className="record-side">
          <Postbox title="Ticket">
            <Facts rows={[
              ['From', PROFILE_PATH[t.user_role] ? <a href={`#/${PROFILE_PATH[t.user_role]}/${t.user_id}`}>{t.user_name}</a> : t.user_name],
              ['Account', ROLE_NAME[t.user_role] ?? t.user_role],
              ['About', t.related_consultation_id ? <a href={`#/consultations/${t.related_consultation_id}`}>A consultation</a>
                : t.related_order_id ? <a href={`#/orders/${t.related_order_id}`}>An order</a> : null],
            ]} />
            {can('support.manage') && (
              <div className="stack-form">
                <Field label="Status">
                  <select value={t.status} onChange={(e) => update({ p_status: e.target.value })}>
                    {['open', 'answered', 'closed'].map((s) => <option key={s} value={s}>{label(s)}</option>)}
                  </select>
                </Field>
                <Field label="Priority">
                  <select value={t.priority} onChange={(e) => update({ p_priority: e.target.value })}>
                    {['low', 'normal', 'high', 'urgent'].map((s) => <option key={s} value={s}>{label(s)}</option>)}
                  </select>
                </Field>
                <Field label="Assigned to">
                  <select
                    value={t.assigned_to ?? ''}
                    onChange={(e) => update(e.target.value ? { p_assignee: e.target.value } : { p_unassign: true })}
                  >
                    <option value="">Nobody</option>
                    {staff.map((s) => <option key={s.id} value={s.id}>{s.full_name}{s.id === me?.id ? ' (me)' : ''}</option>)}
                  </select>
                </Field>
              </div>
            )}
          </Postbox>
          <Notes type="ticket" id={id} />
          <History id={id} refreshKey={refresh} />
        </aside>
      </div>
    </>
  );
}

export function ReviewsPage() {
  const dialog = useDialog();
  const notice = useNotice();
  const [refresh, setRefresh] = useState(0);
  const toggle = async (r: Row) => {
    const hide = !r.hidden;
    const reason = await dialog.ask(
      hide
        ? {
            title: 'Hide this comment?',
            message: 'The stars still count, but the words stop showing on the public profile.',
            confirm: 'Hide comment', danger: true, reason: 'required',
            choices: ['Offensive language', 'Personal information', 'Spam or advertising', 'Not about the service'],
          }
        : { title: 'Show this comment again?', confirm: 'Restore', reason: 'optional' },
    );
    if (reason === null) return;
    try {
      await rpc('erp_review_hide', { p_id: r.id, p_hidden: hide, p_reason: reason });
      notice.success(hide ? 'Comment hidden.' : 'Comment restored.');
      setRefresh((n) => n + 1);
    } catch (e) {
      notice.error((e as Error).message);
    }
  };
  const columns: Column[] = [
    {
      key: 'rating', label: 'Rating', primary: true,
      render: (r) => <span className="stars" aria-label={`${r.rating} of 5`}>{'★'.repeat(r.rating)}<span className="muted">{'★'.repeat(5 - r.rating)}</span></span>,
    },
    { key: 'comment', label: 'Comment', sortable: false, render: (r) => r.comment || <span className="muted">(no comment)</span> },
    { key: 'target_name', label: 'About', render: (r) => <a href={`#/${r.target_kind === 'doctor' ? 'doctors' : 'pharmacies'}/${r.target_id}`}>{r.target_name}</a> },
    { key: 'author_name', label: 'From' },
    { key: 'hidden', label: 'Shown', render: (r) => (r.hidden ? <Pill value="hidden" text="Hidden" /> : <Pill value="active" text="Public" />) },
    { key: 'created_at', label: 'Date', render: (r) => date(r.created_at), csv: (r) => r.created_at },
  ];
  return (
    <>
      <PageHeader title="Reviews">What patients say about doctors and pharmacies. Hide comments that break the rules.</PageHeader>
      <DataTable
        view="erp_reviews" columns={columns}
        search={['comment', 'target_name', 'author_name']} searchLabel="Search reviews"
        filters={[
          { key: 'all', label: 'All' },
          { key: 'low', label: 'Low ratings', apply: (q) => q.lte('rating', 2) },
          { key: 'hidden', label: 'Hidden', apply: (q) => q.eq('hidden', true) },
        ]}
        defaultSort={{ key: 'created_at', asc: false }}
        rowActions={(r) => [{ label: r.hidden ? 'Show comment' : 'Hide comment', danger: !r.hidden, onClick: () => toggle(r) }]}
        exportName="reviews" refreshKey={refresh}
      />
    </>
  );
}

export function AnnouncementsPage() {
  const { can } = useAuth();
  const dialog = useDialog();
  const notice = useNotice();
  const [audience, setAudience] = useState('patient');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const [refresh, setRefresh] = useState(0);
  const who: Record<string, string> = { all: 'everyone', patient: 'all patients', doctor: 'all doctors', chemist: 'all pharmacies' };

  return (
    <>
      <PageHeader title="Announcements">Send a notification to patients, doctors or pharmacies. It appears in their GoDoctor app.</PageHeader>
      <div className="record-grid">
        <div className="record-main">
          <Postbox title="New announcement">
            <form
              className="stack-form"
              onSubmit={async (e) => {
                e.preventDefault();
                const ok = await dialog.ask({
                  title: `Send to ${who[audience]}?`,
                  message: 'It can’t be taken back once sent.',
                  confirm: 'Send now',
                });
                if (ok === null) return;
                setBusy(true);
                try {
                  const n = await rpc<number>('erp_broadcast', { p_role: audience, p_title: title, p_body: body });
                  notice.success(`Sent to ${n} ${n === 1 ? 'person' : 'people'}.`);
                  setTitle('');
                  setBody('');
                  setRefresh((x) => x + 1);
                } catch (err) {
                  notice.error((err as Error).message);
                } finally {
                  setBusy(false);
                }
              }}
            >
              <Field label="Send to">
                <select value={audience} onChange={(e) => setAudience(e.target.value)}>
                  <option value="patient">All patients</option>
                  <option value="doctor">All doctors</option>
                  <option value="chemist">All pharmacies</option>
                  <option value="all">Everyone</option>
                </select>
              </Field>
              <Field label="Title"><input maxLength={80} value={title} onChange={(e) => setTitle(e.target.value)} /></Field>
              <Field label="Message" hint={`${body.length}/300`}>
                <textarea rows={4} maxLength={300} value={body} onChange={(e) => setBody(e.target.value)} />
              </Field>
              <Button type="submit" variant="primary" busy={busy} disabled={!title.trim() || !body.trim()}>
                <Send size={15} /> Send announcement
              </Button>
            </form>
          </Postbox>
        </div>
        <aside className="record-side">
          <Postbox title="Preview">
            <div className="push-preview">
              <Bell size={18} />
              <div>
                <b>{title || 'Your title'}</b>
                <p>{body || 'Your message shows here, just like in the app.'}</p>
              </div>
            </div>
          </Postbox>
          {can('audit.view') && (
            <Postbox title="Sent recently" pad={false}>
              <DataTable
                embedded view="erp_activity"
                columns={[
                  { key: 'at', label: 'When', render: (r) => ago(r.at) },
                  { key: 'summary', label: 'Announcement', sortable: false },
                  { key: 'actor_name', label: 'By' },
                ]}
                scope={(q) => q.eq('action', 'broadcast.sent')}
                defaultSort={{ key: 'at', asc: false }}
                pageSize={8} refreshKey={refresh} emptyText="None sent yet."
              />
            </Postbox>
          )}
        </aside>
      </div>
    </>
  );
}
