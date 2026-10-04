import { useCallback, useEffect, useState } from 'react';
import { ExternalLink, FileCheck2, Star } from 'lucide-react';
import { useAuth } from '../lib/auth';
import { rpc, supabase } from '../lib/supabase';
import type { Route } from '../lib/router';
import { ago, count, date, dateTime, money, payoutNumber, relDays } from '../lib/format';
import { DataTable, type Column, type Filter, type Row } from '../components/DataTable';
import { AccountBox, History, Notes } from '../components/RecordExtras';
import {
  Avatar, Button, Empty, Facts, Field, PageHeader, Pill, Postbox, Spinner, useDialog, useNotice,
} from '../components/ui';
import { consultationColumns, orderColumns } from './Care';

type Kind = 'doctor' | 'pharmacy';
const VIEW: Record<Kind, string> = { doctor: 'erp_doctors', pharmacy: 'erp_pharmacies' };
const PATH: Record<Kind, string> = { doctor: 'doctors', pharmacy: 'pharmacies' };

function Licence({ r }: { r: Row }) {
  return (
    <span className="stack">
      <Pill value={r.licence_state} />
      {r.license_expiry && <small className="muted">{date(r.license_expiry)} · {relDays(r.license_expiry)}</small>}
    </span>
  );
}

function Rating({ avg, n }: { avg: number | null; n?: number | null }) {
  if (!avg) return <span className="muted">—</span>;
  return (
    <span className="rating">
      <Star size={13} aria-hidden /> {Number(avg).toFixed(1)}{n ? <span className="muted"> ({n})</span> : null}
    </span>
  );
}

function useProviderActions(kind: Kind, onDone: () => void) {
  const dialog = useDialog();
  const notice = useNotice();
  const verify = async (r: Row, verified: boolean) => {
    const reason = await dialog.ask(
      verified
        ? {
            title: `Verify ${r.name || 'this provider'}?`,
            message: kind === 'doctor'
              ? 'Only verify after checking the licence on the KMPDC register and the uploaded documents. They can then take consultations.'
              : 'Only verify after checking the Pharmacy and Poisons Board licence and the uploaded documents. They can then receive orders.',
            confirm: 'Verify', reason: 'optional', reasonLabel: 'Note',
            reasonPlaceholder: 'e.g. Licence checked on the register on 5 Oct',
          }
        : {
            title: `Remove verification from ${r.name || 'this provider'}?`,
            message: 'They’ll be hidden from patients until verified again.',
            confirm: 'Remove verification', danger: true, reason: 'required',
          },
    );
    if (reason === null) return false;
    try {
      await rpc('erp_verify_provider', { p_user: r.id, p_verified: verified, p_note: reason });
      notice.success(verified ? `${r.name || 'Provider'} verified.` : 'Verification removed.');
      onDone();
      return true;
    } catch (e) {
      notice.error((e as Error).message);
      return false;
    }
  };
  const setStatus = async (r: Row, status: 'active' | 'suspended') => {
    const reason = await dialog.ask(
      status === 'suspended'
        ? { title: `Suspend ${r.name || 'this account'}?`, message: 'They’ll be signed out, taken off the rota and can’t sign in until restored.', confirm: 'Suspend', danger: true, reason: 'required' }
        : { title: `Restore ${r.name || 'this account'}?`, confirm: 'Restore', reason: 'optional' },
    );
    if (reason === null) return;
    try {
      await rpc('erp_set_account_status', { p_user: r.id, p_status: status, p_reason: reason });
      notice.success(status === 'suspended' ? 'Account suspended.' : 'Account restored.');
      onDone();
    } catch (e) {
      notice.error((e as Error).message);
    }
  };
  return { verify, setStatus };
}

const providerFilters: Filter[] = [
  { key: 'all', label: 'All' },
  { key: 'pending', label: 'Waiting for verification', apply: (q) => q.eq('verified', false) },
  { key: 'verified', label: 'Verified', apply: (q) => q.eq('verified', true) },
  { key: 'licence', label: 'Licence needs attention', apply: (q) => q.in('licence_state', ['expired', 'expiring']) },
  { key: 'suspended', label: 'Suspended', apply: (q) => q.eq('account_status', 'suspended') },
];

function rowActions(kind: Kind, can: (p: string) => boolean, act: ReturnType<typeof useProviderActions>) {
  return (r: Row) => [
    { label: 'View', href: `#/${PATH[kind]}/${r.id}` },
    ...(can('providers.verify')
      ? [r.verified
          ? { label: 'Unverify', onClick: () => act.verify(r, false) }
          : { label: 'Verify', onClick: () => act.verify(r, true) }]
      : []),
    ...(can('providers.manage')
      ? [r.account_status === 'suspended'
          ? { label: 'Restore', onClick: () => act.setStatus(r, 'active') }
          : { label: 'Suspend', danger: true, onClick: () => act.setStatus(r, 'suspended') }]
      : []),
  ];
}

export function DoctorsPage({ route }: { route: Route }) {
  const { can } = useAuth();
  const [refresh, setRefresh] = useState(0);
  const act = useProviderActions('doctor', () => setRefresh((n) => n + 1));
  const columns: Column[] = [
    {
      key: 'name', label: 'Doctor', primary: true,
      render: (r) => (
        <span className="who">
          <Avatar name={r.name} size={28} />
          <span className="stack">
            <span>{r.name || <span className="muted">(no name yet)</span>}</span>
            <small className="muted">{r.specialties || 'No specialty yet'}</small>
          </span>
        </span>
      ),
    },
    { key: 'license_number', label: 'Licence no.' },
    { key: 'licence_state', label: 'Licence', render: (r) => <Licence r={r} />, csv: (r) => `${r.licence_state} ${r.license_expiry ?? ''}` },
    { key: 'rating_avg', label: 'Rating', render: (r) => <Rating avg={r.rating_avg} n={r.rating_count} /> },
    { key: 'consultation_fee', label: 'Fee', align: 'right', render: (r) => money(r.consultation_fee) },
    { key: 'consultations', label: 'Visits', align: 'right', render: (r) => count(r.consultations) },
    { key: 'availability', label: 'Now', render: (r) => <Pill value={r.availability} /> },
    { key: 'account_status', label: 'Account', render: (r) => <Pill value={r.account_status} /> },
    { key: 'joined_at', label: 'Joined', render: (r) => date(r.joined_at), csv: (r) => r.joined_at },
  ];
  return (
    <>
      <PageHeader title="Doctors">Every doctor on GoDoctor: licences, ratings and their work.</PageHeader>
      <DataTable
        view="erp_doctors"
        columns={columns}
        search={['name', 'email', 'specialties', 'license_number', 'practice_county']}
        searchLabel="Search doctors"
        initialFilter={route.query.get('filter')}
        filters={providerFilters}
        defaultSort={{ key: 'joined_at', asc: false }}
        rowHref={(r) => `#/doctors/${r.id}`}
        rowActions={rowActions('doctor', can, act)}
        bulkActions={can('providers.verify') ? [{
          label: 'Verify selected',
          run: async (rows) => {
            for (const r of rows.filter((x) => !x.verified)) {
              if (!(await act.verify(r, true))) break;
            }
          },
        }] : undefined}
        exportName="doctors"
        refreshKey={refresh}
      />
    </>
  );
}

export function PharmaciesPage({ route }: { route: Route }) {
  const { can } = useAuth();
  const [refresh, setRefresh] = useState(0);
  const act = useProviderActions('pharmacy', () => setRefresh((n) => n + 1));
  const columns: Column[] = [
    {
      key: 'name', label: 'Pharmacy', primary: true,
      render: (r) => (
        <span className="who">
          <Avatar name={r.name} size={28} />
          <span className="stack">
            <span>{r.name || <span className="muted">(no name yet)</span>}</span>
            <small className="muted">{r.location_name || 'No location yet'}</small>
          </span>
        </span>
      ),
    },
    { key: 'registration_number', label: 'Licence no.' },
    { key: 'licence_state', label: 'Licence', render: (r) => <Licence r={r} />, csv: (r) => `${r.licence_state} ${r.license_expiry ?? ''}` },
    { key: 'rating', label: 'Rating', render: (r) => <Rating avg={r.rating} /> },
    { key: 'orders', label: 'Orders', align: 'right', render: (r) => count(r.orders) },
    { key: 'in_stock', label: 'In stock', align: 'right', render: (r) => count(r.in_stock) },
    { key: 'out_of_stock', label: 'Out', align: 'right', render: (r) => (r.out_of_stock ? <b className="bad-text">{r.out_of_stock}</b> : '0') },
    { key: 'account_status', label: 'Account', render: (r) => <Pill value={r.account_status} /> },
    { key: 'joined_at', label: 'Joined', render: (r) => date(r.joined_at), csv: (r) => r.joined_at },
  ];
  return (
    <>
      <PageHeader title="Pharmacies">Every pharmacy on GoDoctor: licences, stock and orders.</PageHeader>
      <DataTable
        view="erp_pharmacies"
        columns={columns}
        search={['name', 'pharmacist_name', 'email', 'registration_number', 'location_name']}
        searchLabel="Search pharmacies"
        initialFilter={route.query.get('filter')}
        filters={providerFilters}
        defaultSort={{ key: 'joined_at', asc: false }}
        rowHref={(r) => `#/pharmacies/${r.id}`}
        rowActions={rowActions('pharmacy', can, act)}
        bulkActions={can('providers.verify') ? [{
          label: 'Verify selected',
          run: async (rows) => {
            for (const r of rows.filter((x) => !x.verified)) {
              if (!(await act.verify(r, true))) break;
            }
          },
        }] : undefined}
        exportName="pharmacies"
        refreshKey={refresh}
      />
    </>
  );
}

function Documents({ id }: { id: string }) {
  const [docs, setDocs] = useState<{ name: string; url: string | null }[] | null>(null);
  useEffect(() => {
    (async () => {
      try {
        const paths = await rpc<string[]>('erp_provider_documents', { p_id: id });
        const out = await Promise.all(
          paths.map(async (p) => {
            const { data } = await supabase.storage.from('verification-documents').createSignedUrl(p, 600);
            return { name: p.split('/').pop() ?? p, url: data?.signedUrl ?? null };
          }),
        );
        setDocs(out);
      } catch {
        setDocs([]);
      }
    })();
  }, [id]);
  if (docs === null) return <p className="muted small">Loading documents…</p>;
  if (!docs.length) return <p className="muted small">No documents uploaded yet.</p>;
  return (
    <ul className="docs">
      {docs.map((d, i) => (
        <li key={d.name + i}>
          <FileCheck2 size={15} aria-hidden />
          {d.url ? (
            <a href={d.url} target="_blank" rel="noreferrer">
              Document {i + 1} <ExternalLink size={12} />
            </a>
          ) : (
            <span className="muted">Document {i + 1} (couldn’t open)</span>
          )}
        </li>
      ))}
    </ul>
  );
}

function LicenceEditor({ r, kind, onSaved }: { r: Row; kind: Kind; onSaved: () => void }) {
  const notice = useNotice();
  const [num, setNum] = useState<string>((kind === 'doctor' ? r.license_number : r.registration_number) ?? '');
  const [exp, setExp] = useState<string>(r.license_expiry ?? '');
  const [busy, setBusy] = useState(false);
  return (
    <form
      className="stack-form"
      onSubmit={async (e) => {
        e.preventDefault();
        setBusy(true);
        try {
          await rpc('erp_set_licence', { p_user: r.id, p_number: num, p_expiry: exp || null });
          notice.success('Licence saved.');
          onSaved();
        } catch (err) {
          notice.error((err as Error).message);
        } finally {
          setBusy(false);
        }
      }}
    >
      <Field label={kind === 'doctor' ? 'KMPDC licence number' : 'PPB licence number'}>
        <input value={num} onChange={(e) => setNum(e.target.value)} />
      </Field>
      <Field label="Expires on" hint="We’ll flag it 60 days before it expires.">
        <input type="date" value={exp} onChange={(e) => setExp(e.target.value)} />
      </Field>
      <Button type="submit" busy={busy}>Save licence</Button>
    </form>
  );
}

function ProviderPage({ id, kind }: { id: string; kind: Kind }) {
  const { can } = useAuth();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const [r, setR] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [refresh, setRefresh] = useState(0);
  const act = useProviderActions(kind, () => setRefresh((n) => n + 1));

  const load = useCallback(async () => {
    const { data, error: e } = await supabase.from(VIEW[kind]).select('*').eq('id', id).maybeSingle();
    if (e) setError(e.message);
    else if (!data) setError('This record doesn’t exist, or you can’t see it.');
    else setR(data);
  }, [id, kind]);
  useEffect(() => {
    load();
  }, [load, refresh]);

  if (error) return <Empty title="Couldn’t open this record">{error}</Empty>;
  if (!r) return <Spinner />;
  const doctor = kind === 'doctor';

  return (
    <>
      <a href={`#/${PATH[kind]}`} className="back">← {doctor ? 'Doctors' : 'Pharmacies'}</a>
      <div className="record-head">
        <Avatar name={r.name} size={56} />
        <div>
          <h1>{r.name || '(no name yet)'}</h1>
          <div className="record-meta">
            {r.verified ? <Pill value="verified" /> : <Pill value="pending" text="Waiting for verification" />}
            <Pill value={r.account_status} />
            <span>Joined {date(r.joined_at)}</span>
            <span>Last seen {ago(r.last_seen_at)}</span>
          </div>
        </div>
      </div>
      <div className="record-grid">
        <div className="record-main">
          <Postbox title="Profile">
            <Facts rows={doctor ? [
              ['Email', r.email], ['Phone', r.phone], ['Specialties', r.specialties],
              ['Consultation fee', money(r.consultation_fee)], ['Practice', r.practice_facility],
              ['County', r.practice_county], ['Experience', r.years_experience ? `${r.years_experience} years` : null],
              ['Rating', <Rating avg={r.rating_avg} n={r.rating_count} />],
              ['Consultations completed', count(r.consultations)], ['Fees earned', money(r.earned)],
              ['Declared details genuine', r.attested_at ? dateTime(r.attested_at) : 'Not yet'],
            ] : [
              ['Pharmacist in charge', r.pharmacist_name], ['Email', r.email], ['Phone', r.phone],
              ['Location', r.location_name], ['Delivery', r.offers_delivery ? 'Delivers' : 'Pickup only'],
              ['M-Pesa till', r.mpesa_till], ['Rating', <Rating avg={r.rating} />],
              ['Orders fulfilled', count(r.orders)], ['Sales', money(r.revenue)],
              ['Stock', `${count(r.in_stock)} in stock · ${count(r.out_of_stock)} out of stock`],
              ['Declared details genuine', r.attested_at ? dateTime(r.attested_at) : 'Not yet'],
            ]} />
          </Postbox>

          {doctor && can('consultations.view') && (
            <Postbox title="Consultations" pad={false}>
              <DataTable
                embedded view="erp_consultations"
                columns={consultationColumns().filter((c) => c.key !== 'doctor_name')}
                scope={(q) => q.eq('doctor_id', id)}
                defaultSort={{ key: 'created_at', asc: false }}
                rowHref={(x) => `#/consultations/${x.id}`} pageSize={8}
                emptyText="No consultations yet."
              />
            </Postbox>
          )}
          {!doctor && can('orders.view') && (
            <Postbox title="Orders" pad={false}>
              <DataTable
                embedded view="erp_orders"
                columns={orderColumns().filter((c) => c.key !== 'pharmacy_name')}
                scope={(q) => q.eq('chemist_id', id)}
                defaultSort={{ key: 'created_at', asc: false }}
                rowHref={(x) => `#/orders/${x.id}`} pageSize={8}
                emptyText="No orders yet."
              />
            </Postbox>
          )}
          <Postbox title="Reviews" pad={false}>
            <DataTable
              embedded view="erp_reviews"
              columns={[
                { key: 'created_at', label: 'Date', render: (x) => date(x.created_at) },
                { key: 'rating', label: 'Stars', render: (x) => `★ ${x.rating}` },
                { key: 'comment', label: 'Comment', sortable: false, render: (x) => (x.hidden ? <span className="muted">(hidden) {x.comment}</span> : x.comment || <span className="muted">—</span>) },
                { key: 'author_name', label: 'From' },
              ]}
              scope={(q) => q.eq('target_id', id)}
              defaultSort={{ key: 'created_at', asc: false }}
              pageSize={6} emptyText="No reviews yet."
            />
          </Postbox>
          {can('finance.view') && (
            <Postbox title="Payouts" pad={false}>
              <DataTable
                embedded view="erp_payout_list"
                columns={[
                  { key: 'number', label: 'Statement', render: (x) => payoutNumber(x.number) },
                  { key: 'period_end', label: 'Period', render: (x) => `${date(x.period_start)} – ${date(x.period_end)}` },
                  { key: 'net', label: 'Net', align: 'right', render: (x) => money(x.net) },
                  { key: 'status', label: 'Status', render: (x) => <Pill value={x.status} /> },
                ]}
                scope={(q) => q.eq('payee_id', id)}
                defaultSort={{ key: 'created_at', asc: false }}
                pageSize={6} emptyText="No payouts yet."
              />
            </Postbox>
          )}
        </div>
        <aside className="record-side">
          <Postbox title="Verification">
            <p className="small">
              {r.verified
                ? 'Verified: visible to patients.'
                : 'Not verified yet: hidden from patients until checked.'}
            </p>
            {can('providers.verify') && (
              <>
                <h3 className="side-h">Documents</h3>
                <Documents id={id} />
                <a className="small ext" href={doctor ? 'https://kmpdc.go.ke/' : 'https://pharmacyboardkenya.org/'} target="_blank" rel="noreferrer">
                  {doctor ? 'Check the KMPDC register' : 'Check the Pharmacy and Poisons Board'} <ExternalLink size={12} />
                </a>
                <div className="side-actions">
                  {r.verified
                    ? <Button onClick={() => act.verify(r, false)}>Remove verification</Button>
                    : <Button variant="primary" onClick={() => act.verify(r, true)}>Verify</Button>}
                </div>
              </>
            )}
          </Postbox>
          <Postbox title="Licence">
            <p className="small"><Licence r={r} /></p>
            {can('providers.verify') && <LicenceEditor r={r} kind={kind} onSaved={() => setRefresh((n) => n + 1)} />}
          </Postbox>
          <AccountBox userId={id} status={r.account_status} perm="providers.manage" onChanged={() => setRefresh((n) => n + 1)} />
          <Notes type={kind} id={id} />
          <History id={id} refreshKey={refresh} />
        </aside>
      </div>
    </>
  );
}

export function DoctorPage({ id }: { id: string }) {
  return <ProviderPage id={id} kind="doctor" />;
}

export function PharmacyPage({ id }: { id: string }) {
  return <ProviderPage id={id} kind="pharmacy" />;
}

export function VerificationPage() {
  const { can } = useAuth();
  const [refresh, setRefresh] = useState(0);
  const docAct = useProviderActions('doctor', () => setRefresh((n) => n + 1));
  const phAct = useProviderActions('pharmacy', () => setRefresh((n) => n + 1));
  const cols = (kind: Kind): Column[] => [
    {
      key: 'name', label: kind === 'doctor' ? 'Doctor' : 'Pharmacy', primary: true,
      render: (r) => (
        <span className="who">
          <Avatar name={r.name} size={28} />
          <span>{r.name || <span className="muted">(no name yet)</span>}</span>
        </span>
      ),
    },
    { key: kind === 'doctor' ? 'license_number' : 'registration_number', label: 'Licence no.' },
    { key: 'documents', label: 'Documents', align: 'right' },
    { key: 'attested_at', label: 'Declared genuine', render: (r) => (r.attested_at ? date(r.attested_at) : <span className="muted">Not yet</span>) },
    { key: 'joined_at', label: 'Signed up', render: (r) => ago(r.joined_at) },
  ];
  return (
    <>
      <PageHeader title="Verification">
        Doctors and pharmacies waiting to be checked. Open each one, look at their documents and licence, then verify.
      </PageHeader>
      <Postbox title="Doctors waiting" pad={false}>
        <DataTable
          embedded view="erp_doctors" columns={cols('doctor')}
          scope={(q) => q.eq('verified', false).eq('account_status', 'active')}
          defaultSort={{ key: 'joined_at', asc: true }}
          rowHref={(r) => `#/doctors/${r.id}`}
          rowActions={(r) => [
            { label: 'Review', href: `#/doctors/${r.id}` },
            ...(can('providers.verify') ? [{ label: 'Verify', onClick: () => docAct.verify(r, true) }] : []),
          ]}
          refreshKey={refresh} emptyText="No doctors waiting. 🎉"
        />
      </Postbox>
      <Postbox title="Pharmacies waiting" pad={false}>
        <DataTable
          embedded view="erp_pharmacies" columns={cols('pharmacy')}
          scope={(q) => q.eq('verified', false).eq('account_status', 'active')}
          defaultSort={{ key: 'joined_at', asc: true }}
          rowHref={(r) => `#/pharmacies/${r.id}`}
          rowActions={(r) => [
            { label: 'Review', href: `#/pharmacies/${r.id}` },
            ...(can('providers.verify') ? [{ label: 'Verify', onClick: () => phAct.verify(r, true) }] : []),
          ]}
          refreshKey={refresh} emptyText="No pharmacies waiting. 🎉"
        />
      </Postbox>
    </>
  );
}

export function LicencesPage() {
  const cols = (kind: Kind): Column[] => [
    { key: 'name', label: kind === 'doctor' ? 'Doctor' : 'Pharmacy', primary: true },
    { key: kind === 'doctor' ? 'license_number' : 'registration_number', label: 'Licence no.' },
    { key: 'license_expiry', label: 'Expires', render: (r) => (r.license_expiry ? `${date(r.license_expiry)} (${relDays(r.license_expiry)})` : <span className="muted">Not set</span>) },
    { key: 'licence_state', label: 'State', render: (r) => <Pill value={r.licence_state} /> },
    { key: 'phone', label: 'Phone' },
  ];
  const filters: Filter[] = [
    { key: 'attention', label: 'Expired or expiring', apply: (q) => q.in('licence_state', ['expired', 'expiring']) },
    { key: 'missing', label: 'No expiry date', apply: (q) => q.eq('licence_state', 'no_expiry') },
    { key: 'valid', label: 'Valid', apply: (q) => q.eq('licence_state', 'valid') },
  ];
  return (
    <>
      <PageHeader title="Licences">
        Verified doctors and pharmacies whose licences have expired, expire within 60 days, or have no expiry date on record.
      </PageHeader>
      <h2 className="section-h">Doctors (KMPDC)</h2>
      <DataTable
        view="erp_doctors" columns={cols('doctor')} filters={filters}
        scope={(q) => q.eq('verified', true)}
        defaultSort={{ key: 'license_expiry', asc: true }}
        rowHref={(r) => `#/doctors/${r.id}`} exportName="doctor-licences"
        emptyText="No doctors in this list."
      />
      <h2 className="section-h">Pharmacies (PPB)</h2>
      <DataTable
        view="erp_pharmacies" columns={cols('pharmacy')} filters={filters}
        scope={(q) => q.eq('verified', true)}
        defaultSort={{ key: 'license_expiry', asc: true }}
        rowHref={(r) => `#/pharmacies/${r.id}`} exportName="pharmacy-licences"
        emptyText="No pharmacies in this list."
      />
    </>
  );
}
