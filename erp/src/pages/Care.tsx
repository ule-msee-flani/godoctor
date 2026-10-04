import { useCallback, useEffect, useState } from 'react';
import { ShieldAlert, Siren } from 'lucide-react';
import { useAuth } from '../lib/auth';
import { rpc, supabase } from '../lib/supabase';
import type { Route } from '../lib/router';
import { date, dateTime, label, money, shortId } from '../lib/format';
import { DataTable, type Column } from '../components/DataTable';
import { History, Notes } from '../components/RecordExtras';
import {
  Button, Empty, Facts, PageHeader, Pill, Postbox, Spinner, useDialog, useNotice,
} from '../components/ui';

const link = (href: string, text: string | null | undefined) =>
  text ? <a href={href}>{text}</a> : <span className="muted">—</span>;

export function consultationColumns(): Column[] {
  return [
    {
      key: 'specialty', label: 'Consultation', primary: true,
      render: (r) => (
        <span className="stack">
          <span>{r.specialty || 'Consultation'}</span>
          <small className="muted">#{shortId(r.id)}</small>
        </span>
      ),
    },
    { key: 'patient_name', label: 'Patient', render: (r) => link(`#/patients/${r.patient_id}`, r.patient_name) },
    { key: 'doctor_name', label: 'Doctor', render: (r) => link(`#/doctors/${r.doctor_id}`, r.doctor_name) },
    { key: 'status', label: 'Status', render: (r) => <Pill value={r.status} /> },
    { key: 'mode', label: 'Type', render: (r) => (r.mode === 'scheduled' ? 'Booked' : 'On demand') },
    { key: 'fee_amount', label: 'Fee', align: 'right', render: (r) => money(r.fee_amount) },
    { key: 'payment_status', label: 'Payment', render: (r) => <Pill value={r.payment_status} /> },
    {
      key: 'emergency', label: 'Flags', sortable: false,
      render: (r) => (
        <span className="flags">
          {r.emergency && <span className="flag flag-bad"><Siren size={12} /> Emergency</span>}
          {r.prescribed && <span className="flag">Prescription</span>}
          {r.rating && <span className="flag">★ {r.rating}</span>}
        </span>
      ),
      csv: (r) => [r.emergency && 'emergency', r.prescribed && 'prescription'].filter(Boolean).join(' '),
    },
    { key: 'created_at', label: 'Requested', render: (r) => dateTime(r.created_at), csv: (r) => r.created_at },
  ];
}

export function orderColumns(): Column[] {
  return [
    {
      key: 'id', label: 'Order', primary: true,
      render: (r) => (
        <span className="stack">
          <span>#{shortId(r.id)}</span>
          <small className="muted">{r.items} item{r.items === 1 ? '' : 's'}{r.with_prescription ? ' · with prescription' : ''}</small>
        </span>
      ),
    },
    { key: 'patient_name', label: 'Patient', render: (r) => link(`#/patients/${r.patient_id}`, r.patient_name) },
    { key: 'pharmacy_name', label: 'Pharmacy', render: (r) => link(`#/pharmacies/${r.chemist_id}`, r.pharmacy_name) },
    { key: 'status', label: 'Status', render: (r) => <Pill value={r.status} /> },
    { key: 'total_amount', label: 'Total', align: 'right', render: (r) => money(r.total_amount) },
    { key: 'escrow_status', label: 'Escrow', render: (r) => <Pill value={r.escrow_status} /> },
    { key: 'fulfillment', label: 'Delivery', render: (r) => label(r.fulfillment) },
    { key: 'created_at', label: 'Placed', render: (r) => dateTime(r.created_at), csv: (r) => r.created_at },
  ];
}

export function ConsultationsPage({ route }: { route: Route }) {
  return (
    <>
      <PageHeader title="Consultations">Every video consultation, live and past. Clinical notes open separately, with a reason.</PageHeader>
      <DataTable
        view="erp_consultations"
        columns={consultationColumns()}
        search={['patient_name', 'doctor_name', 'specialty']}
        searchLabel="Search consultations"
        initialFilter={route.query.get('filter')}
        filters={[
          { key: 'all', label: 'All' },
          { key: 'live', label: 'Live', apply: (q) => q.in('status', ['matched', 'in_progress']) },
          { key: 'booked', label: 'Booked', apply: (q) => q.eq('status', 'scheduled') },
          { key: 'awaiting', label: 'Awaiting payment', apply: (q) => q.eq('status', 'awaiting_payment') },
          { key: 'completed', label: 'Completed', apply: (q) => q.eq('status', 'completed') },
          { key: 'cancelled', label: 'Cancelled', apply: (q) => q.in('status', ['cancelled', 'unmatched']) },
          { key: 'emergency', label: 'Emergency flags', apply: (q) => q.eq('emergency', true) },
        ]}
        defaultSort={{ key: 'created_at', asc: false }}
        rowHref={(r) => `#/consultations/${r.id}`}
        exportName="consultations"
      />
    </>
  );
}

interface Clinical {
  symptoms: string | null; summary: string | null; red_flags: string | null; follow_up_on: string | null;
  intake: { symptoms: string | null; duration: string | null; severity: string | null; emergency: boolean } | null;
  prescriptions: { issued_at: string; valid_until: string | null; items: { name: string; dosage: string | null; quantity: number | null; instructions: string | null }[] }[];
}

const CLINICAL_REASONS = ['Clinical review', 'Complaint investigation', 'Safety concern', 'Patient asked for help', 'Legal request'];

export function ConsultationPage({ id }: { id: string }) {
  const { can } = useAuth();
  const dialog = useDialog();
  const notice = useNotice();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const [c, setC] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [clinical, setClinical] = useState<Clinical | null>(null);
  const [refresh, setRefresh] = useState(0);

  const load = useCallback(async () => {
    const { data, error: e } = await supabase.from('erp_consultations').select('*').eq('id', id).maybeSingle();
    if (e) setError(e.message);
    else if (!data) setError('This consultation doesn’t exist, or you can’t see it.');
    else setC(data);
  }, [id]);
  useEffect(() => {
    load();
  }, [load, refresh]);

  if (error) return <Empty title="Couldn’t open this consultation">{error}</Empty>;
  if (!c) return <Spinner />;

  const openClinical = async () => {
    const reason = await dialog.ask({
      title: 'Open clinical notes?',
      message: 'Symptoms, the doctor’s summary and the prescription are confidential. Opening them is recorded with your reason.',
      confirm: 'Open notes', reason: 'required', reasonLabel: 'Why do you need them?', choices: CLINICAL_REASONS,
    });
    if (reason === null) return;
    try {
      setClinical(await rpc<Clinical>('erp_consultation_clinical', { p_id: id, p_reason: reason }));
      setRefresh((n) => n + 1);
    } catch (e) {
      notice.error((e as Error).message);
    }
  };

  const cancel = async () => {
    const reason = await dialog.ask({
      title: 'Cancel this consultation?',
      message: 'The patient and doctor are told straight away.',
      confirm: 'Cancel consultation', danger: true, reason: 'required',
    });
    if (reason === null) return;
    try {
      await rpc('erp_cancel_consultation', { p_id: id, p_reason: reason });
      notice.success('Consultation cancelled.');
      setRefresh((n) => n + 1);
    } catch (e) {
      notice.error((e as Error).message);
    }
  };

  const open = !['completed', 'cancelled', 'unmatched'].includes(c.status);

  return (
    <>
      <a href="#/consultations" className="back">← Consultations</a>
      <div className="record-head">
        <div>
          <h1>{c.specialty} consultation <span className="muted">#{shortId(c.id)}</span></h1>
          <div className="record-meta">
            <Pill value={c.status} /> {c.emergency && <span className="flag flag-bad"><Siren size={12} /> Emergency flagged</span>}
            <span>Requested {dateTime(c.created_at)}</span>
          </div>
        </div>
      </div>
      <div className="record-grid">
        <div className="record-main">
          <Postbox title="Details">
            <Facts rows={[
              ['Patient', link(`#/patients/${c.patient_id}`, c.patient_name)],
              ['Doctor', link(`#/doctors/${c.doctor_id}`, c.doctor_name)],
              ['Type', c.mode === 'scheduled' ? 'Booked appointment' : 'On demand'],
              ['Booked for', c.scheduled_for ? dateTime(c.scheduled_for) : null],
              ['Started', c.started_at ? dateTime(c.started_at) : null],
              ['Ended', c.ended_at ? dateTime(c.ended_at) : null],
              ['Fee', money(c.fee_amount)],
              ['Payment', <Pill value={c.payment_status} />],
              ['Prescription sent', c.prescribed ? 'Yes' : 'No'],
              ['Patient’s rating', c.rating ? `${c.rating} of 5` : null],
            ]} />
          </Postbox>
          <Postbox title="Clinical notes">
            {clinical ? (
              <>
                <div className="sensitive-banner"><ShieldAlert size={16} /> Confidential. Your access has been recorded.</div>
                <Facts rows={[
                  ['What the patient said', clinical.symptoms],
                  ['Intake', clinical.intake ? [clinical.intake.symptoms, clinical.intake.duration && `for ${clinical.intake.duration}`, clinical.intake.severity && `severity: ${clinical.intake.severity}`].filter(Boolean).join(' · ') : null],
                  ['Doctor’s summary', clinical.summary],
                  ['Warning signs given', clinical.red_flags],
                  ['Follow-up', clinical.follow_up_on ? date(clinical.follow_up_on) : null],
                ]} />
                {clinical.prescriptions.map((p, i) => (
                  <div key={i} className="rx">
                    <h3>Prescription · {dateTime(p.issued_at)}</h3>
                    <ol>
                      {p.items.map((it, j) => (
                        <li key={j}>
                          <b>{it.name}</b> {it.dosage && `— ${it.dosage}`} {it.quantity ? `× ${it.quantity}` : ''}
                          {it.instructions && <div className="muted small">{it.instructions}</div>}
                        </li>
                      ))}
                    </ol>
                  </div>
                ))}
                <Button variant="link" onClick={() => setClinical(null)}>Hide clinical notes</Button>
              </>
            ) : can('patients.health') ? (
              <div className="locked">
                <p>Hidden until you need them.</p>
                <Button onClick={openClinical}>Open clinical notes…</Button>
              </div>
            ) : (
              <p className="muted">Only staff with health access can open clinical notes.</p>
            )}
          </Postbox>
          {can('finance.view') && (
            <Postbox title="Payments" pad={false}>
              <DataTable
                embedded
                view="erp_payments"
                columns={paymentColumnsLite}
                scope={(q) => q.eq('source_id', id)}
                defaultSort={{ key: 'created_at', asc: false }}
                emptyText="No payments."
              />
            </Postbox>
          )}
        </div>
        <aside className="record-side">
          {can('consultations.manage') && open && (
            <Postbox title="Actions">
              <Button variant="danger" onClick={cancel}>Cancel consultation</Button>
            </Postbox>
          )}
          <Notes type="consultation" id={id} />
          <History id={id} refreshKey={refresh} />
        </aside>
      </div>
    </>
  );
}

const paymentColumnsLite: Column[] = [
  { key: 'created_at', label: 'Date', render: (r) => dateTime(r.created_at) },
  { key: 'amount', label: 'Amount', align: 'right', render: (r) => money(r.amount) },
  { key: 'status', label: 'Status', render: (r) => <Pill value={r.status} /> },
  { key: 'receipt', label: 'Receipt', render: (r) => r.receipt || (r.test ? 'Test payment' : '—') },
];

export function OrdersPage({ route }: { route: Route }) {
  return (
    <>
      <PageHeader title="Orders">Medicine orders from pharmacies, from placed to delivered.</PageHeader>
      <DataTable
        view="erp_orders"
        columns={orderColumns()}
        search={['patient_name', 'pharmacy_name']}
        searchLabel="Search orders"
        initialFilter={route.query.get('filter')}
        filters={[
          { key: 'all', label: 'All' },
          { key: 'open', label: 'Open', apply: (q) => q.in('status', ['placed', 'confirmed', 'ready']) },
          { key: 'disputed', label: 'Disputed', apply: (q) => q.eq('status', 'disputed') },
          { key: 'fulfilled', label: 'Fulfilled', apply: (q) => q.eq('status', 'fulfilled') },
          { key: 'refunded', label: 'Refunded', apply: (q) => q.eq('status', 'refunded') },
        ]}
        defaultSort={{ key: 'created_at', asc: false }}
        rowHref={(r) => `#/orders/${r.id}`}
        exportName="orders"
      />
    </>
  );
}

const ORDER_STEPS = ['placed', 'confirmed', 'ready', 'fulfilled', 'disputed', 'refunded'];

export function OrderPage({ id }: { id: string }) {
  const { can } = useAuth();
  const dialog = useDialog();
  const notice = useNotice();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const [o, setO] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [next, setNext] = useState('');
  const [refresh, setRefresh] = useState(0);

  const load = useCallback(async () => {
    const { data, error: e } = await supabase.from('erp_orders').select('*').eq('id', id).maybeSingle();
    if (e) setError(e.message);
    else if (!data) setError('This order doesn’t exist, or you can’t see it.');
    else setO(data);
  }, [id]);
  useEffect(() => {
    load();
  }, [load, refresh]);

  if (error) return <Empty title="Couldn’t open this order">{error}</Empty>;
  if (!o) return <Spinner />;

  const change = async () => {
    if (!next || next === o.status) return;
    const reason = await dialog.ask({
      title: `Mark this order as ${label(next).toLowerCase()}?`,
      message: next === 'refunded'
        ? 'The payment is marked refunded and the escrow released back to the patient. Send the money in M-Pesa separately.'
        : 'The patient is told straight away.',
      confirm: 'Change status', danger: next === 'refunded' || next === 'disputed', reason: 'required',
    });
    if (reason === null) return;
    try {
      await rpc('erp_set_order_status', { p_id: id, p_status: next, p_reason: reason });
      notice.success('Order updated.');
      setNext('');
      setRefresh((n) => n + 1);
    } catch (e) {
      notice.error((e as Error).message);
    }
  };

  return (
    <>
      <a href="#/orders" className="back">← Orders</a>
      <div className="record-head">
        <div>
          <h1>Order #{shortId(o.id)}</h1>
          <div className="record-meta">
            <Pill value={o.status} /> <span>Placed {dateTime(o.created_at)}</span>
          </div>
        </div>
      </div>
      <div className="record-grid">
        <div className="record-main">
          <Postbox title="Details">
            <Facts rows={[
              ['Patient', link(`#/patients/${o.patient_id}`, o.patient_name)],
              ['Pharmacy', link(`#/pharmacies/${o.chemist_id}`, o.pharmacy_name)],
              ['Items', `${o.items}${o.with_prescription ? ' (with a prescription)' : ''}`],
              ['Total', money(o.total_amount)],
              ['Escrow', <Pill value={o.escrow_status} />],
              ['Delivery', label(o.fulfillment)],
              ['Payment', <Pill value={o.payment_status} />],
              ['Confirmed by pharmacy', o.confirmed_at ? dateTime(o.confirmed_at) : null],
              ['Ready', o.ready_at ? dateTime(o.ready_at) : null],
              ['Fulfilled', o.fulfilled_at ? dateTime(o.fulfilled_at) : null],
            ]} />
            {o.problem_note && (
              <div className="problem">
                <b>Problem reported:</b> {o.problem_note}
              </div>
            )}
          </Postbox>
          {can('finance.view') && (
            <Postbox title="Payments" pad={false}>
              <DataTable
                embedded
                view="erp_payments"
                columns={paymentColumnsLite}
                scope={(q) => q.eq('source_id', id)}
                defaultSort={{ key: 'created_at', asc: false }}
                emptyText="No payments."
              />
            </Postbox>
          )}
        </div>
        <aside className="record-side">
          {can('orders.manage') && (
            <Postbox title="Change status">
              <div className="inline-form">
                <select value={next} onChange={(e) => setNext(e.target.value)} aria-label="New status">
                  <option value="">Choose…</option>
                  {ORDER_STEPS.filter((s) => s !== o.status && (s !== 'refunded' || can('finance.manage'))).map((s) => (
                    <option key={s} value={s}>{label(s)}</option>
                  ))}
                </select>
                <Button variant="primary" disabled={!next} onClick={change}>Update</Button>
              </div>
            </Postbox>
          )}
          <Notes type="order" id={id} />
          <History id={id} refreshKey={refresh} />
        </aside>
      </div>
    </>
  );
}

export function PrescriptionsPage() {
  const columns: Column[] = [
    {
      key: 'issued_at', label: 'Issued', primary: true,
      render: (r) => (
        <span className="stack">
          <span>{dateTime(r.issued_at)}</span>
          <small className="muted">#{shortId(r.id)}</small>
        </span>
      ),
      csv: (r) => r.issued_at,
    },
    { key: 'patient_name', label: 'Patient', render: (r) => link(`#/patients/${r.patient_id}`, r.patient_name) },
    { key: 'doctor_name', label: 'Doctor', render: (r) => link(`#/doctors/${r.doctor_id}`, r.doctor_name) },
    { key: 'items', label: 'Medicines', align: 'right' },
    { key: 'source', label: 'Source', render: (r) => (r.source === 'app' ? 'GoDoctor doctor' : 'Uploaded photo') },
    { key: 'valid_until', label: 'Valid until', render: (r) => date(r.valid_until) },
    { key: 'ordered', label: 'Ordered', render: (r) => (r.ordered ? 'Yes' : 'No') },
  ];
  return (
    <>
      <PageHeader title="Prescriptions">Prescriptions written in GoDoctor and those patients uploaded. The medicines themselves are in each consultation’s clinical notes.</PageHeader>
      <DataTable
        view="erp_prescriptions"
        columns={columns}
        search={['patient_name', 'doctor_name']}
        searchLabel="Search prescriptions"
        filters={[
          { key: 'all', label: 'All' },
          { key: 'app', label: 'From GoDoctor doctors', apply: (q) => q.eq('source', 'app') },
          { key: 'upload', label: 'Uploaded', apply: (q) => q.eq('source', 'external_upload') },
          { key: 'not_ordered', label: 'Not ordered yet', apply: (q) => q.eq('ordered', false) },
        ]}
        defaultSort={{ key: 'issued_at', asc: false }}
        rowHref={(r) => (r.consultation_id ? `#/consultations/${r.consultation_id}` : null)}
        exportName="prescriptions"
      />
    </>
  );
}
