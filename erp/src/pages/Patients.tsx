import { useCallback, useEffect, useState } from 'react';
import { HeartPulse, ShieldAlert } from 'lucide-react';
import { useAuth } from '../lib/auth';
import { rpc } from '../lib/supabase';
import type { Route } from '../lib/router';
import { ago, count, date, dateTime, label, money } from '../lib/format';
import { downloadCsv } from '../lib/csv';
import { DataTable, type Column, type Row } from '../components/DataTable';
import { AccountBox, History, Notes } from '../components/RecordExtras';
import {
  Avatar, Button, Empty, Facts, PageHeader, Pill, Postbox, Spinner, useDialog, useNotice,
} from '../components/ui';
import { consultationColumns, orderColumns } from './Care';

export function PatientsPage({ route }: { route: Route }) {
  const { can } = useAuth();
  const dialog = useDialog();
  const notice = useNotice();
  const [refresh, setRefresh] = useState(0);

  const columns: Column[] = [
    {
      key: 'name', label: 'Name', primary: true,
      render: (r) => (
        <span className="who">
          <Avatar name={r.name} size={28} />
          <span>{r.name || <span className="muted">(no name yet)</span>}</span>
        </span>
      ),
    },
    { key: 'email', label: 'Email' },
    { key: 'phone', label: 'Phone' },
    { key: 'gender', label: 'Gender', render: (r) => label(r.gender) },
    { key: 'age', label: 'Age', align: 'right' },
    { key: 'location', label: 'Location' },
    { key: 'consultations', label: 'Visits', align: 'right', render: (r) => count(r.consultations) },
    { key: 'orders', label: 'Orders', align: 'right', render: (r) => count(r.orders) },
    { key: 'spent', label: 'Spent', align: 'right', render: (r) => money(r.spent) },
    { key: 'joined_at', label: 'Joined', render: (r) => date(r.joined_at), csv: (r) => r.joined_at },
    { key: 'status', label: 'Status', render: (r) => <Pill value={r.status} /> },
  ];

  const setStatus = async (r: Row, status: 'active' | 'suspended') => {
    const reason = await dialog.ask(
      status === 'suspended'
        ? { title: `Suspend ${r.name || 'this patient'}?`, message: 'They’ll be signed out and can’t sign in until restored.', confirm: 'Suspend', danger: true, reason: 'required' }
        : { title: `Restore ${r.name || 'this patient'}?`, confirm: 'Restore', reason: 'optional' },
    );
    if (reason === null) return;
    try {
      await rpc('erp_set_account_status', { p_user: r.id, p_status: status, p_reason: reason });
      notice.success(status === 'suspended' ? 'Patient suspended.' : 'Patient restored.');
      setRefresh((n) => n + 1);
    } catch (e) {
      notice.error((e as Error).message);
    }
  };

  return (
    <>
      <PageHeader title="Patients">
        Everyone who uses GoDoctor to see a doctor or order medicine. Health details stay hidden here.
      </PageHeader>
      <DataTable
        view="erp_patients"
        columns={columns}
        search={['name', 'email', 'phone', 'location']}
        searchLabel="Search patients"
        initialFilter={route.query.get('filter')}
        filters={[
          { key: 'all', label: 'All' },
          { key: 'active', label: 'Active', apply: (q) => q.eq('status', 'active') },
          { key: 'suspended', label: 'Suspended', apply: (q) => q.eq('status', 'suspended') },
        ]}
        defaultSort={{ key: 'joined_at', asc: false }}
        rowHref={(r) => `#/patients/${r.id}`}
        rowActions={(r) => [
          { label: 'View', href: `#/patients/${r.id}` },
          ...(can('patients.manage')
            ? [r.status === 'suspended'
                ? { label: 'Restore', onClick: () => setStatus(r, 'active') }
                : { label: 'Suspend', danger: true, onClick: () => setStatus(r, 'suspended') }]
            : []),
        ]}
        bulkActions={[
          {
            label: 'Export selected',
            run: (rows) =>
              downloadCsv(
                'patients-selected.csv',
                columns.map((c) => c.label),
                rows.map((r) => columns.map((c) => (c.csv ? c.csv(r) : r[c.key]))),
              ),
          },
        ]}
        exportName="patients"
        refreshKey={refresh}
      />
    </>
  );
}

interface Patient {
  id: string; name: string; email: string | null; phone: string | null; gender: string | null;
  date_of_birth: string | null; county: string | null; location: string | null; status: string;
  joined_at: string; last_seen_at: string | null; heard_from: string | null; health_cover: string | null;
  onboarded_at: string | null;
}

interface Health {
  allergies: string | null; current_medications: string | null; chronic_conditions: string | null;
  blood_group: string | null; height_cm: number | null; weight_kg: number | null;
  emergency_contact_name: string | null; emergency_contact_phone: string | null;
  readings: { kind: string; value: number; value2: number | null; taken_at: string }[];
}

const REASONS = ['Patient asked for help', 'Clinical review', 'Complaint investigation', 'Safety concern', 'Legal request'];

export function PatientPage({ id }: { id: string }) {
  const { can } = useAuth();
  const dialog = useDialog();
  const notice = useNotice();
  const [p, setP] = useState<Patient | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [health, setHealth] = useState<Health | null>(null);
  const [refresh, setRefresh] = useState(0);

  const load = useCallback(() => {
    rpc<Patient>('erp_patient', { p_id: id }).then(setP).catch((e) => setError(e.message));
  }, [id]);
  useEffect(load, [load, refresh]);

  if (error) return <Empty title="Couldn’t open this patient">{error}</Empty>;
  if (!p) return <Spinner />;

  const openHealth = async () => {
    const reason = await dialog.ask({
      title: 'Open health details?',
      message: (
        <>
          Health information is confidential under Kenya’s Data Protection Act. Opening it is recorded with your
          name and the reason you give.
        </>
      ),
      confirm: 'Open health details',
      reason: 'required',
      reasonLabel: 'Why do you need it?',
      choices: REASONS,
    });
    if (reason === null) return;
    try {
      setHealth(await rpc<Health>('erp_patient_health', { p_id: id, p_reason: reason }));
      setRefresh((n) => n + 1);
    } catch (e) {
      notice.error((e as Error).message);
    }
  };

  return (
    <>
      <a href="#/patients" className="back">← Patients</a>
      <div className="record-head">
        <Avatar name={p.name} size={56} />
        <div>
          <h1>{p.name || '(no name yet)'}</h1>
          <div className="record-meta">
            <Pill value={p.status} /> <span>Patient since {date(p.joined_at)}</span>
            <span>Last seen {ago(p.last_seen_at)}</span>
          </div>
        </div>
      </div>

      <div className="record-grid">
        <div className="record-main">
          <Postbox title="Profile">
            <Facts rows={[
              ['Email', p.email],
              ['Phone', p.phone],
              ['Gender', label(p.gender)],
              ['Date of birth', p.date_of_birth ? date(p.date_of_birth) : null],
              ['County', p.county],
              ['Location', p.location],
              ['Health cover', p.health_cover],
              ['Heard about GoDoctor from', p.heard_from],
              ['Finished sign-up', p.onboarded_at ? dateTime(p.onboarded_at) : 'Not yet'],
            ]} />
          </Postbox>

          <Postbox title={<><HeartPulse size={16} /> Health details</>}>
            {health ? (
              <>
                <div className="sensitive-banner">
                  <ShieldAlert size={16} /> Confidential. Your access has been recorded.
                </div>
                <Facts rows={[
                  ['Allergies', health.allergies],
                  ['Current medicines', health.current_medications],
                  ['Long-term conditions', health.chronic_conditions],
                  ['Blood group', health.blood_group],
                  ['Height', health.height_cm ? `${health.height_cm} cm` : null],
                  ['Weight', health.weight_kg ? `${health.weight_kg} kg` : null],
                  ['Emergency contact', [health.emergency_contact_name, health.emergency_contact_phone].filter(Boolean).join(' · ')],
                  ['Latest readings', health.readings.length
                    ? health.readings.map((r) => `${label(r.kind)} ${r.value}${r.value2 ? `/${r.value2}` : ''} (${date(r.taken_at)})`).join(' · ')
                    : null],
                ]} />
                <Button variant="link" onClick={() => setHealth(null)}>Hide health details</Button>
              </>
            ) : can('patients.health') ? (
              <div className="locked">
                <p>Allergies, conditions, medicines and readings are hidden until you need them.</p>
                <Button onClick={openHealth}>Open health details…</Button>
              </div>
            ) : (
              <p className="muted">Only staff with health access (for example the Medical director) can open these.</p>
            )}
          </Postbox>

          {can('consultations.view') && (
            <Postbox title="Consultations" pad={false}>
              <DataTable
                embedded
                view="erp_consultations"
                columns={consultationColumns().filter((c) => c.key !== 'patient_name')}
                scope={(q) => q.eq('patient_id', id)}
                defaultSort={{ key: 'created_at', asc: false }}
                rowHref={(r) => `#/consultations/${r.id}`}
                pageSize={8}
                emptyText="No consultations yet."
              />
            </Postbox>
          )}
          {can('orders.view') && (
            <Postbox title="Medicine orders" pad={false}>
              <DataTable
                embedded
                view="erp_orders"
                columns={orderColumns().filter((c) => c.key !== 'patient_name')}
                scope={(q) => q.eq('patient_id', id)}
                defaultSort={{ key: 'created_at', asc: false }}
                rowHref={(r) => `#/orders/${r.id}`}
                pageSize={8}
                emptyText="No orders yet."
              />
            </Postbox>
          )}
        </div>
        <aside className="record-side">
          <AccountBox userId={p.id} status={p.status} perm="patients.manage" onChanged={() => setRefresh((n) => n + 1)} />
          <Notes type="patient" id={p.id} />
          <History id={p.id} refreshKey={refresh} />
        </aside>
      </div>
    </>
  );
}
