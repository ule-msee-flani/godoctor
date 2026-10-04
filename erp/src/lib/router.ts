import { useEffect, useState } from 'react';

/** Pages live in the address after "#", e.g. #/doctors/123 — works on
 * GitHub Pages and keeps every page linkable and back-button friendly. */
export interface Route {
  path: string[];
  query: URLSearchParams;
}

function read(): Route {
  const raw = window.location.hash.replace(/^#\/?/, '');
  const [p, q] = raw.split('?');
  return {
    path: p.split('/').filter(Boolean).map(decodeURIComponent),
    query: new URLSearchParams(q ?? ''),
  };
}

export function useRoute(): Route {
  const [route, setRoute] = useState(read);
  useEffect(() => {
    const on = () => setRoute(read());
    window.addEventListener('hashchange', on);
    return () => window.removeEventListener('hashchange', on);
  }, []);
  return route;
}

export function navigate(to: string) {
  window.location.hash = to.startsWith('#') ? to : `#${to}`;
}

/** Link target for a record of [type] with [id]. */
export function recordHref(type: string | null | undefined, id: string | null | undefined): string | null {
  if (!type || !id) return null;
  const base: Record<string, string> = {
    patient: 'patients',
    doctor: 'doctors',
    pharmacy: 'pharmacies',
    chemist: 'pharmacies',
    consultation: 'consultations',
    order: 'orders',
    ticket: 'support',
    staff: 'staff',
    payout: 'finance/payouts',
  };
  const b = base[type];
  if (!b) return null;
  return type === 'payout' ? `#/${b}` : `#/${b}/${id}`;
}
