import { useEffect, useState } from 'react';
import {
  BadgeCheck, CircleAlert, IdCard, LifeBuoy, ShoppingBag, Video, Wallet,
} from 'lucide-react';
import { useAuth } from '../lib/auth';
import { rpc, supabase } from '../lib/supabase';
import { recordHref } from '../lib/router';
import { ago, compact, count, money } from '../lib/format';
import { BarList, ColumnChart } from '../components/Charts';
import { Empty, PageHeader, Postbox, Spinner } from '../components/ui';

interface Dash {
  days: number;
  patients: number; patients_new: number;
  doctors: number; doctors_pending: number; doctors_online: number;
  pharmacies: number; pharmacies_pending: number;
  consultations: number; consultations_completed: number; consultations_live: number;
  orders: number; orders_open: number; orders_disputed: number;
  tickets_open: number; licences_attention: number;
  revenue: number | null; escrow_held: number | null; payouts_pending: number | null;
  series: { day: string; consultations: number; orders: number; revenue: number | null }[];
  specialties: { name: string; count: number }[];
}

interface Activity {
  id: number; at: string; actor_name: string; summary: string;
  entity_type: string | null; entity_id: string | null;
}

function dayLabel(d: string) {
  return new Date(`${d}T12:00:00`).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
}

export function DashboardPage() {
  const { me, can } = useAuth();
  const [days, setDays] = useState(30);
  const [data, setData] = useState<Dash | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [activity, setActivity] = useState<Activity[]>([]);

  useEffect(() => {
    let live = true;
    rpc<Dash>('erp_dashboard', { p_days: days })
      .then((d) => live && setData(d))
      .catch((e) => live && setError(e.message));
    return () => {
      live = false;
    };
  }, [days]);

  useEffect(() => {
    if (!can('audit.view')) return;
    supabase.from('erp_activity').select('*').order('at', { ascending: false }).limit(8)
      .then(({ data: d }) => setActivity((d ?? []) as Activity[]));
  }, [can]);

  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
  const finance = can('finance.view');

  const attention = data
    ? [
        can('providers.verify') && data.doctors_pending + data.pharmacies_pending > 0 && {
          icon: BadgeCheck, href: '#/verification',
          text: `${data.doctors_pending + data.pharmacies_pending} provider${data.doctors_pending + data.pharmacies_pending === 1 ? '' : 's'} waiting for verification`,
        },
        can('providers.view') && data.licences_attention > 0 && {
          icon: IdCard, href: '#/licences',
          text: `${data.licences_attention} licence${data.licences_attention === 1 ? '' : 's'} expired or expiring within 60 days`,
        },
        can('orders.view') && data.orders_disputed > 0 && {
          icon: CircleAlert, href: '#/orders?filter=disputed',
          text: `${data.orders_disputed} disputed order${data.orders_disputed === 1 ? '' : 's'}`,
        },
        can('support.view') && data.tickets_open > 0 && {
          icon: LifeBuoy, href: '#/support',
          text: `${data.tickets_open} open support ticket${data.tickets_open === 1 ? '' : 's'}`,
        },
        can('consultations.view') && data.consultations_live > 0 && {
          icon: Video, href: '#/consultations?filter=live',
          text: `${data.consultations_live} consultation${data.consultations_live === 1 ? '' : 's'} happening now`,
        },
        finance && (data.payouts_pending ?? 0) > 0 && {
          icon: Wallet, href: '#/finance/payouts',
          text: `${money(data.payouts_pending)} in payouts waiting to be sent`,
        },
        can('orders.view') && data.orders_open > 0 && {
          icon: ShoppingBag, href: '#/orders?filter=open',
          text: `${data.orders_open} order${data.orders_open === 1 ? '' : 's'} being prepared`,
        },
      ].filter(Boolean) as { icon: typeof Video; href: string; text: string }[]
    : [];

  return (
    <>
      <PageHeader title="Dashboard" />

      <section className="welcome">
        <div>
          <h2>{greeting}, {me?.full_name.split(' ')[0]}.</h2>
          <p>
            You’re signed in to GoDoctor HQ as <b>{me?.role_name}</b>
            {me?.department ? ` in ${me.department}` : ''}. Here’s how GoDoctor is doing.
          </p>
        </div>
        <div className="welcome-links">
          {can('providers.verify') && <a href="#/verification">Verify providers</a>}
          {can('support.view') && <a href="#/support">Answer support</a>}
          {finance && <a href="#/finance/payouts">Payouts</a>}
          {can('staff.view') && <a href="#/staff">Staff</a>}
        </div>
      </section>

      <div className="filters-row">
        <span className="muted">Period</span>
        {[7, 30, 90].map((d) => (
          <button
            key={d}
            type="button"
            className={`chip ${days === d ? 'chip-on' : ''}`}
            onClick={() => {
              setDays(d);
            }}
          >
            Last {d} days
          </button>
        ))}
      </div>

      {error && <Empty title="Couldn’t load the dashboard">{error}</Empty>}
      {!data && !error && <Spinner />}
      {data && (
        <>
          <div className="tiles">
            <Tile label="Patients" value={compact(data.patients)} sub={`+${count(data.patients_new)} in ${data.days} days`} href="#/patients" />
            <Tile label="Verified doctors" value={compact(data.doctors)} sub={`${count(data.doctors_online)} online now`} href="#/doctors" />
            <Tile label="Verified pharmacies" value={compact(data.pharmacies)} sub={`${count(data.pharmacies_pending)} waiting`} href="#/pharmacies" />
            <Tile label="Consultations" value={compact(data.consultations)} sub={`${count(data.consultations_completed)} completed`} href="#/consultations" />
            <Tile label="Orders" value={compact(data.orders)} sub={`${count(data.orders_open)} open`} href="#/orders" />
            {finance && (
              <Tile label="Revenue" value={money(data.revenue)} sub={`Escrow held ${money(data.escrow_held)}`} href="#/finance" />
            )}
          </div>

          <div className="dash-grid">
            <div className="dash-main">
              <Postbox title={`Consultations per day · last ${data.days} days`}>
                <ColumnChart
                  title="Consultations"
                  points={data.series.map((s) => ({ label: dayLabel(s.day), value: s.consultations }))}
                />
              </Postbox>
              <Postbox title={`Orders per day · last ${data.days} days`}>
                <ColumnChart
                  title="Orders"
                  points={data.series.map((s) => ({ label: dayLabel(s.day), value: s.orders }))}
                />
              </Postbox>
              {finance && (
                <Postbox title={`Revenue per day (KES) · last ${data.days} days`}>
                  <ColumnChart
                    title="Revenue (KES)"
                    format={(n) => compact(n)}
                    points={data.series.map((s) => ({ label: dayLabel(s.day), value: Number(s.revenue ?? 0) }))}
                  />
                </Postbox>
              )}
            </div>
            <div className="dash-side">
              <Postbox title="Needs attention">
                {attention.length === 0 ? (
                  <p className="muted">All clear. Nothing is waiting on you.</p>
                ) : (
                  <ul className="attention">
                    {attention.map((a) => (
                      <li key={a.href + a.text}>
                        <a href={a.href}>
                          <a.icon size={16} aria-hidden />
                          <span>{a.text}</span>
                        </a>
                      </li>
                    ))}
                  </ul>
                )}
              </Postbox>
              <Postbox title={`Most requested · last ${data.days} days`}>
                <BarList items={data.specialties.map((s) => ({ name: s.name, value: s.count }))} />
              </Postbox>
              {can('audit.view') && (
                <Postbox title="Recent activity" actions={<a href="#/activity">See all</a>}>
                  {activity.length === 0 ? (
                    <p className="muted">No staff activity yet.</p>
                  ) : (
                    <ul className="feed">
                      {activity.map((a) => {
                        const href = recordHref(a.entity_type, a.entity_id);
                        return (
                          <li key={a.id}>
                            <span className="feed-when">{ago(a.at)}</span>
                            <span>
                              <b>{a.actor_name}</b> · {href ? <a href={href}>{a.summary}</a> : a.summary}
                            </span>
                          </li>
                        );
                      })}
                    </ul>
                  )}
                </Postbox>
              )}
            </div>
          </div>
        </>
      )}
    </>
  );
}

function Tile({ label, value, sub, href }: { label: string; value: string; sub?: string; href?: string }) {
  const body = (
    <>
      <span className="tile-label">{label}</span>
      <span className="tile-value">{value}</span>
      {sub && <span className="tile-sub">{sub}</span>}
    </>
  );
  return href ? <a className="tile" href={href}>{body}</a> : <div className="tile">{body}</div>;
}
