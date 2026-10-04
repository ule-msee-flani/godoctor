import { useEffect, useMemo, useState } from 'react';
import { Printer } from 'lucide-react';
import { useAuth } from '../lib/auth';
import { rpc, supabase } from '../lib/supabase';
import type { Route } from '../lib/router';
import { compact, date, dateTime, label, money, payoutNumber, shortId } from '../lib/format';
import { BarList, ColumnChart } from '../components/Charts';
import { DataTable, type Column, type Row } from '../components/DataTable';
import {
  Button, Empty, Field, Modal, PageHeader, Pill, Postbox, Spinner, useDialog, useNotice,
} from '../components/ui';

interface Settings {
  company?: { name?: string; legal_name?: string; kra_pin?: string; email?: string; phone?: string; address?: string };
  commission?: { consultation_pct?: number; order_pct?: number };
  payouts?: { schedule?: string; minimum?: number };
}

export function useSettings() {
  const [s, setS] = useState<Settings | null>(null);
  useEffect(() => {
    rpc<Settings>('erp_settings_get').then(setS).catch(() => setS({}));
  }, []);
  return s;
}

function dayLabel(d: string) {
  return new Date(`${d}T12:00:00`).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
}

export function FinancePage() {
  const settings = useSettings();
  const [days, setDays] = useState(30);
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const [dash, setDash] = useState<any>(null);
  const [payments, setPayments] = useState<Row[] | null>(null);
  const [paidOut, setPaidOut] = useState<number>(0);

  useEffect(() => {
    const from = new Date(Date.now() - (days - 1) * 86400000);
    from.setHours(0, 0, 0, 0);
    rpc('erp_dashboard', { p_days: days }).then(setDash);
    supabase.from('erp_payments').select('amount,status,kind,created_at').gte('created_at', from.toISOString()).limit(10000)
      .then(({ data }) => setPayments(data ?? []));
    supabase.from('erp_payout_list').select('net').eq('status', 'paid').gte('paid_at', from.toISOString()).limit(10000)
      .then(({ data }) => setPaidOut((data ?? []).reduce((s, r) => s + Number(r.net), 0)));
  }, [days]);

  const totals = useMemo(() => {
    const t = { consultation: 0, order: 0, refunded: 0, pending: 0, failed: 0 };
    for (const p of payments ?? []) {
      const a = Number(p.amount);
      if (p.status === 'succeeded') t[p.kind as 'consultation' | 'order'] += a;
      else if (p.status === 'refunded') t.refunded += a;
      else if (p.status === 'pending') t.pending += a;
      else if (p.status === 'failed') t.failed += a;
    }
    return t;
  }, [payments]);

  const cPct = Number(settings?.commission?.consultation_pct ?? 15);
  const oPct = Number(settings?.commission?.order_pct ?? 8);
  const commission = (totals.consultation * cPct + totals.order * oPct) / 100;

  return (
    <>
      <PageHeader title="Finance">Money in, GoDoctor’s share, and what is owed to doctors and pharmacies.</PageHeader>
      <div className="filters-row">
        <span className="muted">Period</span>
        {[7, 30, 90].map((d) => (
          <button key={d} type="button" className={`chip ${days === d ? 'chip-on' : ''}`} onClick={() => setDays(d)}>
            Last {d} days
          </button>
        ))}
      </div>
      {!dash || !payments ? (
        <Spinner />
      ) : (
        <>
          <div className="tiles">
            <div className="tile"><span className="tile-label">Payments received</span><span className="tile-value">{money(totals.consultation + totals.order)}</span><span className="tile-sub">{payments.filter((p) => p.status === 'succeeded').length} payments</span></div>
            <div className="tile"><span className="tile-label">GoDoctor commission (est.)</span><span className="tile-value">{money(commission)}</span><span className="tile-sub">{cPct}% of visits · {oPct}% of orders</span></div>
            <div className="tile"><span className="tile-label">Held in escrow</span><span className="tile-value">{money(dash.escrow_held)}</span><span className="tile-sub">Orders not yet delivered</span></div>
            <a className="tile" href="#/finance/payouts"><span className="tile-label">Payouts waiting</span><span className="tile-value">{money(dash.payouts_pending)}</span><span className="tile-sub">{money(paidOut)} paid in this period</span></a>
            <a className="tile" href="#/finance/payments?filter=refunded"><span className="tile-label">Refunded</span><span className="tile-value">{money(totals.refunded)}</span><span className="tile-sub">{money(totals.failed)} failed · {money(totals.pending)} pending</span></a>
          </div>
          <div className="dash-grid">
            <div className="dash-main">
              <Postbox title={`Payments received per day (KES) · last ${days} days`}>
                <ColumnChart
                  title="Payments (KES)" format={(n) => compact(n)}
                  points={dash.series.map((s: { day: string; revenue: number | null }) => ({ label: dayLabel(s.day), value: Number(s.revenue ?? 0) }))}
                />
              </Postbox>
            </div>
            <div className="dash-side">
              <Postbox title="Where the money came from">
                <BarList
                  format={(n) => money(n)}
                  items={[
                    { name: 'Consultations', value: totals.consultation },
                    { name: 'Medicine orders', value: totals.order },
                  ]}
                />
              </Postbox>
              <Postbox title="Shortcuts">
                <ul className="attention">
                  <li><a href="#/finance/payments">All payments</a></li>
                  <li><a href="#/finance/payouts">Payout statements</a></li>
                  <li><a href="#/settings">Commission rates</a></li>
                </ul>
              </Postbox>
            </div>
          </div>
        </>
      )}
    </>
  );
}

function RefundModal({ row, onClose, onDone }: { row: Row; onClose: () => void; onDone: () => void }) {
  const notice = useNotice();
  const [reason, setReason] = useState('');
  const [reference, setReference] = useState('');
  const [busy, setBusy] = useState(false);
  return (
    <Modal
      title={`Refund ${money(row.amount)}?`}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button
            variant="danger" busy={busy} disabled={reason.trim().length < 3}
            onClick={async () => {
              setBusy(true);
              try {
                await rpc('erp_record_refund', { p_payment: row.id, p_reference: reference.trim() || null, p_reason: reason.trim() });
                notice.success('Refund recorded. The patient has been told.');
                onDone();
              } catch (e) {
                notice.error((e as Error).message);
              } finally {
                setBusy(false);
              }
            }}
          >
            Record refund
          </Button>
        </>
      }
    >
      <p className="modal-message">
        Send the money back in M-Pesa first, then record it here. The payment is marked refunded
        {row.kind === 'order' ? ', the order closed and its escrow released back to the patient' : ''}.
      </p>
      <Field label="M-Pesa reference of the refund (optional)">
        <input value={reference} onChange={(e) => setReference(e.target.value)} placeholder="e.g. TJK8H2LM4Q" />
      </Field>
      <Field label="Reason">
        <textarea rows={3} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Saved in the activity log" />
      </Field>
    </Modal>
  );
}

export function PaymentsPage({ route }: { route: Route }) {
  const { can } = useAuth();
  const [refund, setRefund] = useState<Row | null>(null);
  const [refresh, setRefresh] = useState(0);
  const columns: Column[] = [
    {
      key: 'created_at', label: 'Payment', primary: true,
      render: (r) => (
        <span className="stack">
          <span>{dateTime(r.created_at)}</span>
          <small className="muted">#{shortId(r.id)}</small>
        </span>
      ),
      csv: (r) => r.created_at,
    },
    {
      key: 'kind', label: 'For',
      render: (r) => <a href={`#/${r.kind === 'order' ? 'orders' : 'consultations'}/${r.source_id}`}>{r.kind === 'order' ? 'Medicine order' : 'Consultation'}</a>,
    },
    { key: 'payer_name', label: 'Paid by', render: (r) => (r.payer_name ? <a href={`#/patients/${r.payer_id}`}>{r.payer_name}</a> : '—') },
    {
      key: 'payee_name', label: 'Paid to',
      render: (r) => (r.payee_name ? <a href={`#/${r.kind === 'order' ? 'pharmacies' : 'doctors'}/${r.payee_id}`}>{r.payee_name}</a> : '—'),
    },
    { key: 'amount', label: 'Amount', align: 'right', render: (r) => money(r.amount) },
    { key: 'provider', label: 'Method', render: (r) => (r.provider === 'mpesa' ? 'M-Pesa' : label(r.provider)) },
    { key: 'status', label: 'Status', render: (r) => <Pill value={r.status} /> },
    { key: 'receipt', label: 'Receipt', render: (r) => r.receipt || (r.test ? <span className="muted">Test payment</span> : '—') },
  ];
  return (
    <>
      <PageHeader title="Payments">Every payment patients made, with receipts. Refunds are recorded here after sending the money back.</PageHeader>
      <DataTable
        view="erp_payments" columns={columns}
        search={['payer_name', 'payee_name', 'receipt']} searchLabel="Search payments"
        initialFilter={route.query.get('filter')}
        filters={[
          { key: 'all', label: 'All' },
          { key: 'succeeded', label: 'Succeeded', apply: (q) => q.eq('status', 'succeeded') },
          { key: 'pending', label: 'Pending', apply: (q) => q.eq('status', 'pending') },
          { key: 'failed', label: 'Failed', apply: (q) => q.eq('status', 'failed') },
          { key: 'refunded', label: 'Refunded', apply: (q) => q.eq('status', 'refunded') },
          { key: 'test', label: 'Test payments', apply: (q) => q.eq('test', true) },
        ]}
        defaultSort={{ key: 'created_at', asc: false }}
        rowActions={(r) => [
          { label: r.kind === 'order' ? 'View order' : 'View consultation', href: `#/${r.kind === 'order' ? 'orders' : 'consultations'}/${r.source_id}` },
          ...(can('finance.manage') && r.status === 'succeeded' ? [{ label: 'Refund', danger: true, onClick: () => setRefund(r) }] : []),
        ]}
        exportName="payments" refreshKey={refresh}
      />
      {refund && (
        <RefundModal row={refund} onClose={() => setRefund(null)} onDone={() => { setRefund(null); setRefresh((n) => n + 1); }} />
      )}
    </>
  );
}

function lastWeek(): [string, string] {
  const now = new Date();
  const day = (now.getDay() + 6) % 7; // Monday = 0
  const end = new Date(now);
  end.setDate(now.getDate() - day - 1);
  const start = new Date(end);
  start.setDate(end.getDate() - 6);
  const iso = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  return [iso(start), iso(end)];
}

function PaidModal({ row, onClose, onDone }: { row: Row; onClose: () => void; onDone: () => void }) {
  const notice = useNotice();
  const [reference, setReference] = useState('');
  const [busy, setBusy] = useState(false);
  return (
    <Modal
      title={`Mark ${payoutNumber(row.number)} as paid`}
      onClose={onClose}
      footer={
        <>
          <Button onClick={onClose}>Cancel</Button>
          <Button
            variant="primary" busy={busy} disabled={reference.trim().length < 3}
            onClick={async () => {
              setBusy(true);
              try {
                await rpc('erp_payout_paid', { p_id: row.id, p_reference: reference.trim() });
                notice.success(`${payoutNumber(row.number)} marked as paid. ${row.payee_name} has been told.`);
                onDone();
              } catch (e) {
                notice.error((e as Error).message);
              } finally {
                setBusy(false);
              }
            }}
          >
            Mark as paid
          </Button>
        </>
      }
    >
      <p className="modal-message">
        Send <b>{money(row.net)}</b> to <b>{row.payee_name}</b>{row.pay_to ? <> on <b>{row.pay_to}</b></> : ''}, then enter the
        M-Pesa or bank reference.
      </p>
      <Field label="Payment reference">
        <input autoFocus value={reference} onChange={(e) => setReference(e.target.value)} placeholder="e.g. TJK8H2LM4Q" />
      </Field>
    </Modal>
  );
}

function StatementModal({ row, settings, onClose }: { row: Row; settings: Settings | null; onClose: () => void }) {
  const c = settings?.company ?? {};
  return (
    <Modal
      title={`Statement ${payoutNumber(row.number)}`}
      onClose={onClose}
      wide
      footer={
        <>
          <Button onClick={onClose}>Close</Button>
          <Button variant="primary" onClick={() => window.print()}><Printer size={15} /> Print or save as PDF</Button>
        </>
      }
    >
      <div className="statement print-area">
        <div className="statement-head">
          <div>
            <h2>{c.legal_name || c.name || 'GoDoctor'}</h2>
            <p>{c.address}</p>
            {c.kra_pin && <p>KRA PIN: {c.kra_pin}</p>}
            <p>{[c.email, c.phone].filter(Boolean).join(' · ')}</p>
          </div>
          <div className="statement-no">
            <h3>Payout statement</h3>
            <p><b>{payoutNumber(row.number)}</b></p>
            <p>Issued {date(row.created_at)}</p>
          </div>
        </div>
        <div className="statement-to">
          <span className="muted">To</span>
          <b>{row.payee_name}</b>
          <span>{row.payee_kind === 'doctor' ? 'Doctor' : 'Pharmacy'}{row.pay_to ? ` · ${row.pay_to}` : ''}</span>
          <span>Period: {date(row.period_start)} – {date(row.period_end)}</span>
        </div>
        <table className="wp-table">
          <tbody>
            <tr><td>{row.items} {row.payee_kind === 'doctor' ? 'consultation' : 'order'}{row.items === 1 ? '' : 's'} (gross)</td><td className="num" style={{ textAlign: 'right' }}>{money(row.gross)}</td></tr>
            <tr><td>Less GoDoctor commission</td><td className="num" style={{ textAlign: 'right' }}>− {money(row.commission)}</td></tr>
            <tr className="total"><td><b>Net payable</b></td><td className="num" style={{ textAlign: 'right' }}><b>{money(row.net)}</b></td></tr>
          </tbody>
        </table>
        <p className="statement-status">
          Status: <Pill value={row.status} />
          {row.status === 'paid' && <> · Paid {dateTime(row.paid_at)} · Ref {row.reference}</>}
        </p>
      </div>
    </Modal>
  );
}

export function PayoutsPage({ route }: { route: Route }) {
  const { can } = useAuth();
  const dialog = useDialog();
  const notice = useNotice();
  const settings = useSettings();
  const [[from, to], setPeriod] = useState<[string, string]>(lastWeek);
  const [busy, setBusy] = useState(false);
  const [refresh, setRefresh] = useState(0);
  const [paid, setPaid] = useState<Row | null>(null);
  const [statement, setStatement] = useState<Row | null>(null);

  const generate = async () => {
    setBusy(true);
    try {
      const n = await rpc<number>('erp_generate_payouts', { p_from: from, p_to: to });
      if (n === 0) notice.info('Nothing new to pay out for that period.');
      else notice.success(`Created ${n} statement${n === 1 ? '' : 's'}.`);
      setRefresh((x) => x + 1);
    } catch (e) {
      notice.error((e as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const cancel = async (r: Row) => {
    const reason = await dialog.ask({
      title: `Cancel ${payoutNumber(r.number)}?`,
      message: 'Its consultations and orders can go on a new statement.',
      confirm: 'Cancel statement', danger: true, reason: 'required',
    });
    if (reason === null) return;
    try {
      await rpc('erp_payout_cancel', { p_id: r.id, p_reason: reason });
      notice.success('Statement cancelled.');
      setRefresh((x) => x + 1);
    } catch (e) {
      notice.error((e as Error).message);
    }
  };

  const columns: Column[] = [
    { key: 'number', label: 'Statement', primary: true, render: (r) => payoutNumber(r.number), csv: (r) => payoutNumber(r.number) },
    { key: 'payee_name', label: 'Payee', render: (r) => <a href={`#/${r.payee_kind === 'doctor' ? 'doctors' : 'pharmacies'}/${r.payee_id}`}>{r.payee_name}</a> },
    { key: 'pay_to', label: 'Pay to' },
    { key: 'period_end', label: 'Period', render: (r) => `${date(r.period_start)} – ${date(r.period_end)}`, csv: (r) => `${r.period_start} to ${r.period_end}` },
    { key: 'gross', label: 'Gross', align: 'right', render: (r) => money(r.gross) },
    { key: 'commission', label: 'Commission', align: 'right', render: (r) => money(r.commission) },
    { key: 'net', label: 'Net', align: 'right', render: (r) => <b>{money(r.net)}</b> },
    { key: 'status', label: 'Status', render: (r) => <Pill value={r.status} /> },
    { key: 'paid_at', label: 'Paid', render: (r) => (r.paid_at ? <span className="stack"><span>{date(r.paid_at)}</span><small className="muted">{r.reference}</small></span> : '—'), csv: (r) => r.reference },
  ];

  if (!settings) return <Spinner />;
  return (
    <>
      <PageHeader title="Payouts">
        What GoDoctor owes doctors and pharmacies. Create statements for a period, send the money, then mark each one paid.
      </PageHeader>
      {can('finance.manage') && (
        <Postbox title="Create payout statements" className={route.query.get('new') ? 'highlight' : ''}>
          <div className="generate">
            <Field label="From"><input type="date" value={from} onChange={(e) => setPeriod([e.target.value, to])} /></Field>
            <Field label="To"><input type="date" value={to} onChange={(e) => setPeriod([from, e.target.value])} /></Field>
            <Button variant="primary" busy={busy} onClick={generate}>Create statements</Button>
          </div>
          <p className="small muted">
            Includes paid, completed consultations and delivered orders in the period that aren’t on a statement yet.
            GoDoctor keeps {settings.commission?.consultation_pct ?? 15}% of consultation fees and {settings.commission?.order_pct ?? 8}% of
            orders (<a href="#/settings">change</a>).
          </p>
        </Postbox>
      )}
      <DataTable
        view="erp_payout_list" columns={columns}
        search={['payee_name', 'reference']} searchLabel="Search payouts"
        filters={[
          { key: 'pending', label: 'Waiting to be paid', apply: (q) => q.eq('status', 'pending') },
          { key: 'paid', label: 'Paid', apply: (q) => q.eq('status', 'paid') },
          { key: 'cancelled', label: 'Cancelled', apply: (q) => q.eq('status', 'cancelled') },
          { key: 'all', label: 'All' },
        ]}
        defaultSort={{ key: 'number', asc: false }}
        rowActions={(r) => [
          { label: 'Statement', onClick: () => setStatement(r) },
          ...(can('finance.manage') && r.status === 'pending'
            ? [{ label: 'Mark as paid', onClick: () => setPaid(r) }, { label: 'Cancel', danger: true, onClick: () => cancel(r) }]
            : []),
        ]}
        exportName="payouts" refreshKey={refresh}
        emptyText="No statements here."
      />
      {paid && <PaidModal row={paid} onClose={() => setPaid(null)} onDone={() => { setPaid(null); setRefresh((x) => x + 1); }} />}
      {statement && <StatementModal row={statement} settings={settings} onClose={() => setStatement(null)} />}
      {!can('finance.view') && <Empty title="No access" />}
    </>
  );
}
