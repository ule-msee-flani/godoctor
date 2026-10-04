import { useCallback, useEffect, useMemo, useState } from 'react';
import { Check, Copy, KeyRound, Lock, ShieldCheck, UserPlus } from 'lucide-react';
import { FunctionsHttpError } from '@supabase/supabase-js';
import { useAuth } from '../lib/auth';
import { rpc, supabase } from '../lib/supabase';
import { recordHref, type Route } from '../lib/router';
import { ago, date, dateTime, label, shortId } from '../lib/format';
import { DataTable, type Column, type Row } from '../components/DataTable';
import {
  Avatar, Button, Field, Modal, PageHeader, Pill, Postbox, Spinner, useDialog, useNotice,
} from '../components/ui';
import { useSettings } from './Finance';

interface RoleRow { key: string; name: string; description: string; sort: number; locked: boolean; permissions: string[]; staff: number }
interface PermRow { key: string; area: string; label: string; sort: number }

export const PERMISSION_LABELS: Record<string, string> = {
  'dashboard.view': 'See the dashboard',
  'patients.view': 'See patient records',
  'patients.health': 'Open patient health details',
  'patients.manage': 'Suspend and restore patients',
  'providers.view': 'See doctors and pharmacies',
  'providers.verify': 'Verify licences and documents',
  'providers.manage': 'Suspend and restore providers',
  'consultations.view': 'See consultations',
  'consultations.manage': 'Cancel consultations',
  'prescriptions.view': 'See prescriptions',
  'orders.view': 'See orders',
  'orders.manage': 'Change order status',
  'finance.view': 'See payments and payouts',
  'finance.manage': 'Pay out statements and record refunds',
  'support.view': 'See support tickets',
  'support.manage': 'Reply to and manage tickets',
  'reviews.moderate': 'Hide and restore reviews',
  'broadcast.send': 'Send announcements',
  'staff.view': 'See staff',
  'staff.manage': 'Add staff and change permissions',
  'audit.view': 'See the activity log',
  'settings.manage': 'Change company settings',
};

const DEPARTMENTS = ['Management', 'Operations', 'Clinical', 'Pharmacy', 'Finance', 'Customer support', 'Compliance', 'Technology', 'Marketing'];

function useRoles() {
  const [roles, setRoles] = useState<RoleRow[]>([]);
  const load = useCallback(async () => {
    const { data } = await supabase.from('erp_role_list').select('*').order('sort');
    setRoles((data ?? []) as RoleRow[]);
  }, []);
  useEffect(() => {
    load();
  }, [load]);
  return { roles, reload: load };
}

async function callStaffFunction(body: Record<string, unknown>): Promise<{ temporary_password: string; user_id?: string }> {
  const { data, error } = await supabase.functions.invoke('erp-staff', { body });
  if (error) {
    if (error instanceof FunctionsHttpError) {
      const j = await error.context.json().catch(() => null);
      throw new Error(j?.error ?? 'Something went wrong.');
    }
    throw new Error(error.message);
  }
  return data;
}

function PasswordReveal({ name, password, onClose, isNew }: { name: string; password: string; onClose: () => void; isNew: boolean }) {
  const [copied, setCopied] = useState(false);
  const link = window.location.href.split('#')[0];
  return (
    <Modal title={isNew ? `${name} has been added` : `New password for ${name}`} onClose={onClose}
      footer={<Button variant="primary" onClick={onClose}>Done</Button>}>
      <p className="modal-message">
        Give {name.split(' ')[0]} this temporary password privately (in person or by phone, not in a group chat). It’s shown only
        once. They sign in at <b>{link}</b> and change it under <b>My profile</b>.
      </p>
      <div className="secret">
        <KeyRound size={18} />
        <code>{password}</code>
        <Button
          onClick={async () => {
            await navigator.clipboard.writeText(password);
            setCopied(true);
          }}
        >
          {copied ? <><Check size={14} /> Copied</> : <><Copy size={14} /> Copy</>}
        </Button>
      </div>
    </Modal>
  );
}

function StaffForm({
  initial, roles, isNew, onClose, onSaved,
}: {
  initial: Row | null; roles: RoleRow[]; isNew: boolean; onClose: () => void;
  onSaved: (result?: { name: string; password: string }) => void;
}) {
  const notice = useNotice();
  const [f, setF] = useState({
    email: initial?.email ?? '',
    full_name: initial?.full_name ?? '',
    job_title: initial?.job_title ?? '',
    department: initial?.department ?? '',
    role: initial?.role ?? 'support',
    phone: initial?.phone ?? '',
  });
  const [busy, setBusy] = useState(false);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const role = roles.find((r) => r.key === f.role);

  const save = async () => {
    setBusy(true);
    try {
      if (isNew) {
        const res = await callStaffFunction({ action: 'create', ...f });
        onSaved({ name: f.full_name, password: res.temporary_password });
      } else {
        await rpc('erp_staff_save', {
          p_user: initial!.id, p_full_name: f.full_name, p_job_title: f.job_title,
          p_department: f.department, p_role: f.role, p_phone: f.phone,
        });
        notice.success('Saved.');
        onSaved();
      }
    } catch (e) {
      notice.error((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal
      title={isNew ? 'Add a staff member' : `Edit ${initial?.full_name}`}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button variant="primary" busy={busy} disabled={f.full_name.trim().length < 2 || (isNew && !f.email.includes('@'))} onClick={save}>
            {isNew ? <><UserPlus size={15} /> Add staff member</> : 'Save'}
          </Button>
        </>
      }
    >
      <div className="form-grid">
        {isNew && (
          <Field label="Work email" hint="They sign in with this. It can’t already have a GoDoctor account.">
            <input type="email" value={f.email} onChange={set('email')} autoFocus />
          </Field>
        )}
        <Field label="Full name"><input value={f.full_name} onChange={set('full_name')} /></Field>
        <Field label="Job title"><input value={f.job_title} onChange={set('job_title')} placeholder="e.g. Support lead" /></Field>
        <Field label="Department">
          <input list="departments" value={f.department} onChange={set('department')} />
          <datalist id="departments">{DEPARTMENTS.map((d) => <option key={d} value={d} />)}</datalist>
        </Field>
        <Field label="Phone"><input value={f.phone} onChange={set('phone')} /></Field>
        <Field label="Role" hint={role?.description}>
          <select value={f.role} onChange={set('role')}>
            {roles.map((r) => <option key={r.key} value={r.key}>{r.name}</option>)}
          </select>
        </Field>
      </div>
    </Modal>
  );
}

export function StaffPage({ route }: { route: Route }) {
  const { me, can } = useAuth();
  const dialog = useDialog();
  const notice = useNotice();
  const { roles } = useRoles();
  const [refresh, setRefresh] = useState(0);
  const [editing, setEditing] = useState<Row | 'new' | null>(route.query.get('new') && can('staff.manage') ? 'new' : null);
  const [reveal, setReveal] = useState<{ name: string; password: string; isNew: boolean } | null>(null);

  const reset = async (r: Row) => {
    const ok = await dialog.ask({
      title: `Reset ${r.full_name}’s password?`,
      message: 'Their old password stops working. You’ll get a temporary one to give them.',
      confirm: 'Reset password', danger: true,
    });
    if (ok === null) return;
    try {
      const res = await callStaffFunction({ action: 'reset_password', user_id: r.id });
      setReveal({ name: r.full_name, password: res.temporary_password, isNew: false });
    } catch (e) {
      notice.error((e as Error).message);
    }
  };

  const setStatus = async (r: Row, status: 'active' | 'suspended') => {
    const reason = await dialog.ask(
      status === 'suspended'
        ? { title: `Suspend ${r.full_name}?`, message: 'They’re signed out straight away and can’t sign in to HQ.', confirm: 'Suspend', danger: true, reason: 'required', choices: ['Left GoDoctor', 'On leave', 'Security concern'] }
        : { title: `Restore ${r.full_name}?`, confirm: 'Restore', reason: 'optional' },
    );
    if (reason === null) return;
    try {
      await rpc('erp_set_account_status', { p_user: r.id, p_status: status, p_reason: reason });
      notice.success(status === 'suspended' ? 'Staff member suspended.' : 'Staff member restored.');
      setRefresh((n) => n + 1);
    } catch (e) {
      notice.error((e as Error).message);
    }
  };

  const columns: Column[] = [
    {
      key: 'full_name', label: 'Name', primary: true,
      render: (r) => (
        <span className="who">
          <Avatar name={r.full_name} size={30} />
          <span className="stack">
            <span>{r.full_name}{r.id === me?.id ? <span className="muted"> (you)</span> : null}</span>
            <small className="muted">{r.job_title || '—'}</small>
          </span>
        </span>
      ),
    },
    { key: 'email', label: 'Email' },
    { key: 'department', label: 'Department' },
    { key: 'role_name', label: 'Role', render: (r) => <span className="role-tag">{r.role_name}</span> },
    { key: 'status', label: 'Status', render: (r) => <Pill value={r.status} /> },
    { key: 'last_active_at', label: 'Last active', render: (r) => (r.last_active_at ? ago(r.last_active_at) : <span className="muted">Never</span>), csv: (r) => r.last_active_at },
    { key: 'created_at', label: 'Added', render: (r) => <span className="stack"><span>{date(r.created_at)}</span>{r.added_by && <small className="muted">by {r.added_by}</small>}</span>, csv: (r) => r.created_at },
  ];

  return (
    <>
      <PageHeader
        title="Staff"
        action={can('staff.manage') && <Button variant="secondary" onClick={() => setEditing('new')}><UserPlus size={15} /> Add New</Button>}
      >
        Everyone who works at GoDoctor and can sign in to HQ. What each person can do comes from their role.
      </PageHeader>
      <DataTable
        view="erp_staff_list" columns={columns}
        search={['full_name', 'email', 'job_title', 'department']} searchLabel="Search staff"
        filters={[
          { key: 'active', label: 'Active', apply: (q) => q.eq('status', 'active') },
          { key: 'suspended', label: 'Suspended', apply: (q) => q.eq('status', 'suspended') },
          { key: 'all', label: 'All' },
        ]}
        defaultSort={{ key: 'full_name', asc: true }}
        rowActions={(r) => can('staff.manage') ? [
          { label: 'Edit', onClick: () => setEditing(r) },
          ...(r.id !== me?.id ? [{ label: 'Reset password', onClick: () => reset(r) }] : []),
          ...(r.id !== me?.id && r.account_status !== undefined
            ? [r.status === 'suspended'
                ? { label: 'Restore', onClick: () => setStatus(r, 'active') }
                : { label: 'Suspend', danger: true, onClick: () => setStatus(r, 'suspended') }]
            : []),
        ] : []}
        exportName="staff" refreshKey={refresh}
      />
      {editing && (
        <StaffForm
          initial={editing === 'new' ? null : editing}
          isNew={editing === 'new'}
          roles={roles}
          onClose={() => setEditing(null)}
          onSaved={(res) => {
            setEditing(null);
            setRefresh((n) => n + 1);
            if (res) setReveal({ ...res, isNew: true });
          }}
        />
      )}
      {reveal && <PasswordReveal name={reveal.name} password={reveal.password} isNew={reveal.isNew} onClose={() => setReveal(null)} />}
    </>
  );
}

export function RolesPage() {
  const { can } = useAuth();
  const notice = useNotice();
  const { roles, reload } = useRoles();
  const [perms, setPerms] = useState<PermRow[]>([]);
  const [draft, setDraft] = useState<Record<string, Set<string>>>({});
  const [busy, setBusy] = useState(false);
  const editable = can('staff.manage');

  useEffect(() => {
    supabase.from('erp_permission_list').select('*').order('sort').then(({ data }) => setPerms((data ?? []) as PermRow[]));
  }, []);
  useEffect(() => {
    setDraft(Object.fromEntries(roles.map((r) => [r.key, new Set(r.permissions)])));
  }, [roles]);

  const changed = useMemo(
    () => roles.filter((r) => !r.locked && draft[r.key] && (draft[r.key]!.size !== r.permissions.length || r.permissions.some((p) => !draft[r.key]!.has(p)))),
    [roles, draft],
  );

  const areas = useMemo(() => {
    const m = new Map<string, PermRow[]>();
    for (const p of perms) m.set(p.area, [...(m.get(p.area) ?? []), p]);
    return [...m.entries()];
  }, [perms]);

  if (!roles.length || !perms.length) return <Spinner />;

  return (
    <>
      <PageHeader title="Roles & permissions">
        Each staff member has one role. Tick what each role can do; changes apply the next time they open a page.
        Administrators can always do everything.
      </PageHeader>
      <div className="role-cards">
        {roles.map((r) => (
          <div key={r.key} className="role-card">
            <div className="role-card-head">
              {r.locked ? <Lock size={14} /> : <ShieldCheck size={14} />}
              <b>{r.name}</b>
              <span className="muted">{r.staff} staff</span>
            </div>
            <p>{r.description}</p>
          </div>
        ))}
      </div>
      <div className="table-wrap">
        <table className="wp-table matrix">
          <thead>
            <tr>
              <th>Permission</th>
              {roles.map((r) => <th key={r.key} className="center">{r.name}</th>)}
            </tr>
          </thead>
          <tbody>
            {areas.map(([area, list]) => (
              <FragmentRows key={area} area={area} list={list} roles={roles} draft={draft} editable={editable}
                onToggle={(role, perm) =>
                  setDraft((d) => {
                    const n = new Set(d[role]);
                    if (n.has(perm)) n.delete(perm);
                    else n.add(perm);
                    return { ...d, [role]: n };
                  })
                } />
            ))}
          </tbody>
        </table>
      </div>
      {editable && (
        <div className="save-bar">
          <span className="muted">{changed.length ? `Unsaved changes for ${changed.map((r) => r.name).join(', ')}` : 'No changes'}</span>
          <Button onClick={() => setDraft(Object.fromEntries(roles.map((r) => [r.key, new Set(r.permissions)])))} disabled={!changed.length}>Undo</Button>
          <Button
            variant="primary" busy={busy} disabled={!changed.length}
            onClick={async () => {
              setBusy(true);
              try {
                for (const r of changed) {
                  await rpc('erp_role_set_permissions', { p_role: r.key, p_permissions: [...draft[r.key]!] });
                }
                notice.success('Permissions saved.');
                await reload();
              } catch (e) {
                notice.error((e as Error).message);
              } finally {
                setBusy(false);
              }
            }}
          >
            Save changes
          </Button>
        </div>
      )}
    </>
  );
}

function FragmentRows({
  area, list, roles, draft, editable, onToggle,
}: {
  area: string; list: PermRow[]; roles: RoleRow[]; draft: Record<string, Set<string>>; editable: boolean;
  onToggle: (role: string, perm: string) => void;
}) {
  return (
    <>
      <tr className="group-row"><td colSpan={roles.length + 1}>{area}</td></tr>
      {list.map((p) => (
        <tr key={p.key}>
          <td>{p.label}</td>
          {roles.map((r) => (
            <td key={r.key} className="center">
              <input
                type="checkbox"
                aria-label={`${r.name}: ${p.label}`}
                checked={r.locked || Boolean(draft[r.key]?.has(p.key))}
                disabled={r.locked || !editable}
                onChange={() => onToggle(r.key, p.key)}
              />
            </td>
          ))}
        </tr>
      ))}
    </>
  );
}

const ACTION_LABELS: Record<string, string> = {
  'patient.opened': 'Opened a patient record',
  'patient.health_viewed': 'Opened health details',
  'consultation.clinical_viewed': 'Opened clinical notes',
  'account.suspended': 'Suspended an account',
  'account.restored': 'Restored an account',
  'provider.verified': 'Verified a provider',
  'provider.unverified': 'Removed verification',
  'provider.licence_updated': 'Updated a licence',
  'consultation.cancelled': 'Cancelled a consultation',
  'order.status_changed': 'Changed an order',
  'payment.refunded': 'Recorded a refund',
  'payouts.generated': 'Created payout statements',
  'payout.paid': 'Paid out a statement',
  'payout.cancelled': 'Cancelled a statement',
  'ticket.updated': 'Updated a ticket',
  'ticket.replied': 'Replied to a ticket',
  'review.hidden': 'Hid a review',
  'review.restored': 'Restored a review',
  'note.added': 'Added a note',
  'staff.created': 'Added a staff member',
  'staff.updated': 'Edited a staff member',
  'staff.password_reset': 'Reset a password',
  'role.permissions_changed': 'Changed permissions',
  'settings.changed': 'Changed settings',
  'broadcast.sent': 'Sent an announcement',
};

export function ActivityPage({ route }: { route: Route }) {
  const columns: Column[] = [
    { key: 'at', label: 'When', primary: true, render: (r) => <span title={dateTime(r.at)}>{dateTime(r.at)}</span>, csv: (r) => r.at },
    {
      key: 'actor_name', label: 'Who',
      render: (r) => <span className="stack"><span>{r.actor_name}</span><small className="muted">{r.actor_role ?? ''}</small></span>,
    },
    { key: 'action', label: 'Action', render: (r) => ACTION_LABELS[r.action] ?? label(r.action) },
    {
      key: 'summary', label: 'What', sortable: false,
      render: (r) => {
        const href = recordHref(r.entity_type, r.entity_id);
        return href ? <a href={href}>{r.summary}</a> : r.summary;
      },
    },
    { key: 'reason', label: 'Reason', sortable: false, render: (r) => r.reason || <span className="muted">—</span> },
  ];
  return (
    <>
      <PageHeader title="Activity log">
        Everything staff do in HQ, including every time someone opens health information. Entries can’t be edited or deleted.
      </PageHeader>
      <DataTable
        view="erp_activity" columns={columns}
        search={['summary', 'actor_name', 'reason']} searchLabel="Search the log"
        initialFilter={route.query.get('filter')}
        filters={[
          { key: 'all', label: 'All' },
          { key: 'health', label: 'Health information opened', apply: (q) => q.in('action', ['patient.health_viewed', 'consultation.clinical_viewed']) },
          { key: 'records', label: 'Records opened', apply: (q) => q.eq('action', 'patient.opened') },
          { key: 'accounts', label: 'Accounts & verification', apply: (q) => q.or('action.like.account.*,action.like.provider.*') },
          { key: 'money', label: 'Money', apply: (q) => q.or('action.like.payment.*,action.like.payout*') },
          { key: 'company', label: 'Staff & settings', apply: (q) => q.or('action.like.staff.*,action.like.role.*,action.eq.settings.changed') },
        ]}
        defaultSort={{ key: 'at', asc: false }}
        idKey="id" exportName="activity-log"
        emptyText="Nothing logged yet."
      />
    </>
  );
}

const TABLE_NAMES: Record<string, string> = {
  users: 'Accounts', patient_profiles: 'Patient profiles', doctor_profiles: 'Doctor profiles',
  chemist_profiles: 'Pharmacy profiles', consultations: 'Consultations', orders: 'Orders',
  payments: 'Payments', prescriptions: 'Prescriptions', prescription_items: 'Prescription lines',
  chemist_inventory: 'Pharmacy stock', support_tickets: 'Support tickets', support_messages: 'Support messages',
  reviews: 'Reviews', intake_forms: 'Intake forms', consultation_messages: 'Chat messages',
};

export function ChangesPage() {
  const columns: Column[] = [
    { key: 'at', label: 'When', primary: true, render: (r) => dateTime(r.at), csv: (r) => r.at },
    { key: 'actor_name', label: 'Who', render: (r) => <span className="stack"><span>{r.actor_name ?? 'System'}</span><small className="muted">{label(r.actor_role)}</small></span> },
    { key: 'table_name', label: 'Where', render: (r) => TABLE_NAMES[r.table_name] ?? label(r.table_name) },
    { key: 'op', label: 'Change', render: (r) => ({ INSERT: 'Added', UPDATE: 'Changed', DELETE: 'Deleted' } as Record<string, string>)[r.op] ?? r.op },
    { key: 'row_id', label: 'Record', render: (r) => <code>{shortId(r.row_id)}</code> },
    { key: 'changed', label: 'Fields', sortable: false, render: (r) => (r.changed?.length ? r.changed.map(label).join(', ') : <span className="muted">—</span>), csv: (r) => (r.changed ?? []).join(' ') },
  ];
  return (
    <>
      <PageHeader title="Data changes">
        Every change made to GoDoctor’s data in the app or HQ over the last 30 days: who changed what, and when (values aren’t copied).
      </PageHeader>
      <DataTable
        view="erp_data_changes" columns={columns}
        search={['table_name', 'actor_name']} searchLabel="Search changes"
        filters={[
          { key: 'all', label: 'All' },
          { key: 'insert', label: 'Added', apply: (q) => q.eq('op', 'INSERT') },
          { key: 'update', label: 'Changed', apply: (q) => q.eq('op', 'UPDATE') },
          { key: 'delete', label: 'Deleted', apply: (q) => q.eq('op', 'DELETE') },
        ]}
        defaultSort={{ key: 'at', asc: false }} exportName="data-changes"
      />
    </>
  );
}

export function SettingsPage() {
  const notice = useNotice();
  const loaded = useSettings();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const [s, setS] = useState<any>(null);
  const [busy, setBusy] = useState<string | null>(null);
  useEffect(() => {
    if (loaded) setS(JSON.parse(JSON.stringify(loaded)));
  }, [loaded]);
  if (!s) return <Spinner />;

  const set = (group: string, key: string) => (e: { target: { value: string } }) =>
    setS((x: Record<string, Record<string, unknown>>) => ({ ...x, [group]: { ...(x[group] ?? {}), [key]: e.target.value } }));

  const save = async (group: string, value: Record<string, unknown>) => {
    setBusy(group);
    try {
      await rpc('erp_settings_set', { p_key: group, p_value: value });
      notice.success('Settings saved.');
    } catch (e) {
      notice.error((e as Error).message);
    } finally {
      setBusy(null);
    }
  };

  const c = s.company ?? {};
  const k = s.commission ?? {};
  const p = s.payouts ?? {};
  return (
    <>
      <PageHeader title="Settings">GoDoctor’s company details, commission and payout rules.</PageHeader>
      <div className="settings">
        <Postbox title="Company">
          <div className="form-grid">
            <Field label="Trading name"><input value={c.name ?? ''} onChange={set('company', 'name')} /></Field>
            <Field label="Registered (legal) name"><input value={c.legal_name ?? ''} onChange={set('company', 'legal_name')} /></Field>
            <Field label="KRA PIN" hint="Printed on payout statements."><input value={c.kra_pin ?? ''} onChange={set('company', 'kra_pin')} /></Field>
            <Field label="Email"><input type="email" value={c.email ?? ''} onChange={set('company', 'email')} /></Field>
            <Field label="Phone"><input value={c.phone ?? ''} onChange={set('company', 'phone')} /></Field>
            <Field label="Address"><input value={c.address ?? ''} onChange={set('company', 'address')} /></Field>
            <Field label="Website"><input value={c.website ?? ''} onChange={set('company', 'website')} /></Field>
          </div>
          <Button variant="primary" busy={busy === 'company'} onClick={() => save('company', s.company)}>Save company details</Button>
        </Postbox>
        <Postbox title="Commission">
          <p className="small muted">GoDoctor’s share, taken off payout statements. Changes apply to new statements only.</p>
          <div className="form-grid">
            <Field label="Of consultation fees (%)"><input type="number" min={0} max={100} step={0.5} value={k.consultation_pct ?? 15} onChange={set('commission', 'consultation_pct')} /></Field>
            <Field label="Of medicine orders (%)"><input type="number" min={0} max={100} step={0.5} value={k.order_pct ?? 8} onChange={set('commission', 'order_pct')} /></Field>
          </div>
          <Button variant="primary" busy={busy === 'commission'}
            onClick={() => save('commission', { consultation_pct: Number(k.consultation_pct ?? 15), order_pct: Number(k.order_pct ?? 8) })}>
            Save commission
          </Button>
        </Postbox>
        <Postbox title="Payouts">
          <div className="form-grid">
            <Field label="How often">
              <select value={p.schedule ?? 'weekly'} onChange={set('payouts', 'schedule')}>
                <option value="weekly">Weekly</option>
                <option value="fortnightly">Every two weeks</option>
                <option value="monthly">Monthly</option>
              </select>
            </Field>
            <Field label="Minimum payout (KES)" hint="Smaller balances wait for the next statement.">
              <input type="number" min={0} step={50} value={p.minimum ?? 500} onChange={set('payouts', 'minimum')} />
            </Field>
          </div>
          <Button variant="primary" busy={busy === 'payouts'}
            onClick={() => save('payouts', { schedule: p.schedule ?? 'weekly', minimum: Number(p.minimum ?? 500) })}>
            Save payout rules
          </Button>
        </Postbox>
      </div>
    </>
  );
}

export function ProfilePage() {
  const { me, reload } = useAuth();
  const notice = useNotice();
  const [name, setName] = useState(me?.full_name ?? '');
  const [title, setTitle] = useState(me?.job_title ?? '');
  const [phone, setPhone] = useState('');
  const [pw, setPw] = useState('');
  const [pw2, setPw2] = useState('');
  const [busy, setBusy] = useState<string | null>(null);
  if (!me) return null;

  return (
    <>
      <PageHeader title="My profile" />
      <div className="record-grid">
        <div className="record-main">
          <Postbox title="About me">
            <div className="form-grid">
              <Field label="Full name"><input value={name} onChange={(e) => setName(e.target.value)} /></Field>
              <Field label="Job title"><input value={title} onChange={(e) => setTitle(e.target.value)} /></Field>
              <Field label="Phone"><input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="Optional" /></Field>
              <Field label="Email (sign-in)"><input value={me.email ?? ''} disabled /></Field>
            </div>
            <Button
              variant="primary" busy={busy === 'me'} disabled={name.trim().length < 2}
              onClick={async () => {
                setBusy('me');
                try {
                  await rpc('erp_profile_save', { p_full_name: name, p_job_title: title, p_phone: phone });
                  await reload();
                  notice.success('Profile saved.');
                } catch (e) {
                  notice.error((e as Error).message);
                } finally {
                  setBusy(null);
                }
              }}
            >
              Save profile
            </Button>
          </Postbox>
          <Postbox title="Change password">
            <div className="form-grid">
              <Field label="New password" hint="At least 10 characters."><input type="password" autoComplete="new-password" value={pw} onChange={(e) => setPw(e.target.value)} /></Field>
              <Field label="Type it again"><input type="password" autoComplete="new-password" value={pw2} onChange={(e) => setPw2(e.target.value)} /></Field>
            </div>
            {pw2 && pw !== pw2 && <p className="bad-text small">The two passwords don’t match.</p>}
            <Button
              variant="primary" busy={busy === 'pw'} disabled={pw.length < 10 || pw !== pw2}
              onClick={async () => {
                setBusy('pw');
                const { error } = await supabase.auth.updateUser({ password: pw });
                setBusy(null);
                if (error) notice.error(error.message);
                else {
                  setPw('');
                  setPw2('');
                  notice.success('Password changed.');
                }
              }}
            >
              Change password
            </Button>
          </Postbox>
        </div>
        <aside className="record-side">
          <Postbox title="My role">
            <p><span className="role-tag">{me.role_name}</span> {me.department && <span className="muted">· {me.department}</span>}</p>
            <ul className="perm-list">
              {me.permissions.map((p) => <li key={p}><Check size={13} /> {PERMISSION_LABELS[p] ?? p}</li>)}
            </ul>
          </Postbox>
        </aside>
      </div>
    </>
  );
}
