import { useEffect, useState, type ReactNode } from 'react';
import {
  BadgeCheck, ChevronDown, CircleUser, FileText, IdCard, LayoutDashboard, LifeBuoy, LogOut,
  Megaphone, Menu, PanelLeftClose, PanelLeftOpen, Plus, ScrollText, Settings, ShoppingBag,
  Star, Stethoscope, Store, UserCog, Users, Video, Wallet, type LucideIcon,
} from 'lucide-react';
import { useAuth } from '../lib/auth';
import { supabase } from '../lib/supabase';
import { Avatar } from './ui';
import type { Query } from './DataTable';

interface Item {
  href: string;
  label: string;
  icon: LucideIcon;
  perm: string;
  badge?: 'verify' | 'tickets' | 'disputes' | 'licences';
  children?: { href: string; label: string; perm?: string }[];
}

const MENU: (Item | 'sep')[] = [
  { href: '', label: 'Dashboard', icon: LayoutDashboard, perm: 'dashboard.view' },
  'sep',
  { href: 'patients', label: 'Patients', icon: Users, perm: 'patients.view' },
  { href: 'doctors', label: 'Doctors', icon: Stethoscope, perm: 'providers.view' },
  { href: 'pharmacies', label: 'Pharmacies', icon: Store, perm: 'providers.view' },
  { href: 'verification', label: 'Verification', icon: BadgeCheck, perm: 'providers.verify', badge: 'verify' },
  { href: 'licences', label: 'Licences', icon: IdCard, perm: 'providers.view', badge: 'licences' },
  'sep',
  { href: 'consultations', label: 'Consultations', icon: Video, perm: 'consultations.view' },
  { href: 'orders', label: 'Orders', icon: ShoppingBag, perm: 'orders.view', badge: 'disputes' },
  { href: 'prescriptions', label: 'Prescriptions', icon: FileText, perm: 'prescriptions.view' },
  'sep',
  {
    href: 'finance', label: 'Finance', icon: Wallet, perm: 'finance.view',
    children: [
      { href: 'finance', label: 'Overview' },
      { href: 'finance/payments', label: 'Payments' },
      { href: 'finance/payouts', label: 'Payouts' },
    ],
  },
  { href: 'support', label: 'Support', icon: LifeBuoy, perm: 'support.view', badge: 'tickets' },
  { href: 'reviews', label: 'Reviews', icon: Star, perm: 'reviews.moderate' },
  { href: 'announcements', label: 'Announcements', icon: Megaphone, perm: 'broadcast.send' },
  'sep',
  {
    href: 'staff', label: 'Staff', icon: UserCog, perm: 'staff.view',
    children: [
      { href: 'staff', label: 'All staff' },
      { href: 'staff/roles', label: 'Roles & permissions' },
    ],
  },
  {
    href: 'activity', label: 'Activity log', icon: ScrollText, perm: 'audit.view',
    children: [
      { href: 'activity', label: 'Staff actions' },
      { href: 'activity/changes', label: 'Data changes' },
    ],
  },
  { href: 'settings', label: 'Settings', icon: Settings, perm: 'settings.manage' },
];

function useBadges(can: (p: string) => boolean, path: string) {
  const [b, setB] = useState<Record<string, number>>({});
  useEffect(() => {
    let live = true;
    const head = async (view: string, f: (q: Query) => Query) => {
      const { count } = await f(supabase.from(view).select('*', { count: 'exact', head: true }));
      return (count as number | null) ?? 0;
    };
    (async () => {
      const out: Record<string, number> = {};
      if (can('providers.view')) {
        const pending = (q: Query) => q.eq('verified', false).eq('account_status', 'active');
        const attention = (q: Query) => q.in('licence_state', ['expired', 'expiring']);
        out.verify = (await head('erp_doctors', pending)) + (await head('erp_pharmacies', pending));
        out.licences = (await head('erp_doctors', attention)) + (await head('erp_pharmacies', attention));
      }
      if (can('support.view')) out.tickets = await head('erp_tickets', (q) => q.eq('status', 'open'));
      if (can('orders.view')) out.disputes = await head('erp_orders', (q) => q.eq('status', 'disputed'));
      if (live) setB(out);
    })();
    return () => {
      live = false;
    };
  }, [can, path]);
  return b;
}

export function Layout({ path, children }: { path: string[]; children: ReactNode }) {
  const { me, can, signOut } = useAuth();
  const here = path.join('/');
  const top = path[0] ?? '';
  const badges = useBadges(can, here);
  const [folded, setFolded] = useState(() => {
    try {
      return localStorage.getItem('hq-folded') === '1';
    } catch {
      return false;
    }
  });
  const [mobileOpen, setMobileOpen] = useState(false);
  const [userMenu, setUserMenu] = useState(false);
  const [newMenu, setNewMenu] = useState(false);

  useEffect(() => {
    setMobileOpen(false);
    setUserMenu(false);
    setNewMenu(false);
  }, [here]);

  const fold = () => {
    setFolded((f) => {
      try {
        localStorage.setItem('hq-folded', f ? '0' : '1');
      } catch { /* private window */ }
      return !f;
    });
  };

  const newItems = [
    can('staff.manage') && { href: '#/staff?new=1', label: 'Staff member' },
    can('broadcast.send') && { href: '#/announcements', label: 'Announcement' },
    can('finance.manage') && { href: '#/finance/payouts?new=1', label: 'Payout statements' },
  ].filter(Boolean) as { href: string; label: string }[];

  return (
    <div className={`shell ${folded ? 'folded' : ''} ${mobileOpen ? 'menu-open' : ''}`}>
      <header className="adminbar">
        <button type="button" className="adminbar-burger" aria-label="Menu" onClick={() => setMobileOpen((o) => !o)}>
          <Menu size={20} />
        </button>
        <a href="#/" className="adminbar-brand">
          <img src="./icon.png" alt="" width={22} height={22} />
          <span>GoDoctor <b>HQ</b></span>
        </a>
        {newItems.length > 0 && (
          <div className="adminbar-menu">
            <button type="button" className="adminbar-item" onClick={() => setNewMenu((o) => !o)} aria-expanded={newMenu}>
              <Plus size={16} /> <span className="hide-sm">New</span>
            </button>
            {newMenu && (
              <div className="dropdown">
                {newItems.map((n) => (
                  <a key={n.href} href={n.href}>{n.label}</a>
                ))}
              </div>
            )}
          </div>
        )}
        <div className="adminbar-spacer" />
        <div className="adminbar-menu">
          <button type="button" className="adminbar-item" onClick={() => setUserMenu((o) => !o)} aria-expanded={userMenu}>
            <span className="hide-sm">Hi, {me?.full_name.split(' ')[0]}</span>
            <Avatar name={me?.full_name} size={24} />
            <ChevronDown size={14} />
          </button>
          {userMenu && (
            <div className="dropdown dropdown-right">
              <div className="dropdown-who">
                <Avatar name={me?.full_name} size={40} />
                <div>
                  <strong>{me?.full_name}</strong>
                  <span>{me?.role_name}{me?.job_title ? ` · ${me.job_title}` : ''}</span>
                  <span className="muted">{me?.email}</span>
                </div>
              </div>
              <a href="#/profile"><CircleUser size={15} /> My profile</a>
              <button type="button" onClick={signOut}><LogOut size={15} /> Sign out</button>
            </div>
          )}
        </div>
      </header>

      <nav className="sidebar" aria-label="Main menu">
        <ul>
          {MENU.map((item, i) => {
            if (item === 'sep') return <li key={`sep${i}`} className="menu-sep" aria-hidden />;
            if (!can(item.perm)) return null;
            const active = item.href === '' ? top === '' : top === item.href.split('/')[0];
            const count = item.badge ? badges[item.badge] ?? 0 : 0;
            return (
              <li key={item.href || 'dash'} className={active ? 'active' : ''}>
                <a href={`#/${item.href}`} title={folded ? item.label : undefined}>
                  <item.icon size={18} aria-hidden />
                  <span className="menu-label">{item.label}</span>
                  {count > 0 && <span className="menu-count" aria-label={`${count} waiting`}>{count}</span>}
                </a>
                {active && item.children && !folded && (
                  <ul className="submenu">
                    {item.children.map((c) => (
                      <li key={c.href} className={here === c.href ? 'current' : ''}>
                        <a href={`#/${c.href}`}>{c.label}</a>
                      </li>
                    ))}
                  </ul>
                )}
              </li>
            );
          })}
        </ul>
        <button type="button" className="fold" onClick={fold}>
          {folded ? <PanelLeftOpen size={17} /> : <PanelLeftClose size={17} />}
          <span className="menu-label">Collapse menu</span>
        </button>
      </nav>

      <main className="content">{children}</main>
      {mobileOpen && <div className="scrim" onClick={() => setMobileOpen(false)} />}
    </div>
  );
}
