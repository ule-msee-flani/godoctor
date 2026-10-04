const kes = new Intl.NumberFormat('en-KE', { maximumFractionDigits: 0 });

/** "KES 1,500" */
export function money(v: number | string | null | undefined): string {
  if (v === null || v === undefined || v === '') return '—';
  const n = typeof v === 'string' ? Number(v) : v;
  if (!Number.isFinite(n)) return '—';
  return `KES ${kes.format(n)}`;
}

/** 1,284 / 12.9K / 4.2M */
export function compact(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  if (Math.abs(n) >= 1_000_000) return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, '')}M`;
  if (Math.abs(n) >= 10_000) return `${(n / 1000).toFixed(1).replace(/\.0$/, '')}K`;
  return kes.format(n);
}

export function count(n: number | null | undefined): string {
  return n === null || n === undefined ? '—' : kes.format(n);
}

/** "5 Oct 2026" */
export function date(v: string | null | undefined): string {
  if (!v) return '—';
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
}

/** "5 Oct 2026, 14:20" */
export function dateTime(v: string | null | undefined): string {
  if (!v) return '—';
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return '—';
  return `${date(v)}, ${d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })}`;
}

/** "3 min ago", "yesterday", "12 Sep" */
export function ago(v: string | null | undefined): string {
  if (!v) return '—';
  const d = new Date(v);
  const s = (Date.now() - d.getTime()) / 1000;
  if (s < 0) return dateTime(v);
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  if (s < 172800) return 'yesterday';
  if (s < 604800) return `${Math.floor(s / 86400)} days ago`;
  return date(v);
}

/** "in 12 days" / "3 days ago" for a date. */
export function relDays(v: string | null | undefined): string {
  if (!v) return '';
  const days = Math.round((new Date(v).getTime() - Date.now()) / 86400000);
  if (days === 0) return 'today';
  if (days > 0) return `in ${days} day${days === 1 ? '' : 's'}`;
  return `${-days} day${days === -1 ? '' : 's'} ago`;
}

export function initials(name: string | null | undefined): string {
  const parts = (name ?? '').replace(/^Dr\.?\s+/i, '').split(/\s+/).filter(Boolean);
  if (!parts.length) return '?';
  return parts.slice(0, 2).map((p) => p[0]!.toUpperCase()).join('');
}

/** "in_progress" -> "In progress" */
export function label(v: string | null | undefined): string {
  if (!v) return '—';
  const s = v.replace(/_/g, ' ');
  return s.charAt(0).toUpperCase() + s.slice(1);
}

export function shortId(id: string | null | undefined): string {
  return id ? id.slice(0, 8).toUpperCase() : '—';
}

export function payoutNumber(n: number | null | undefined): string {
  return n ? `PO-${String(n).padStart(4, '0')}` : '—';
}
