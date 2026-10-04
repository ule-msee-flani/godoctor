import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { ChevronDown, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight, ChevronUp, Download, Search } from 'lucide-react';
import { supabase, friendlyError } from '../lib/supabase';
import { downloadCsv } from '../lib/csv';
import { Button, useNotice } from './ui';

// The query builder's types are deep generics; modifiers just pass it along.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Query = any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Row = Record<string, any>;

export interface Column {
  key: string;
  label: string;
  render?: (row: Row) => ReactNode;
  /** Sort by this column (default: yes). */
  sortable?: boolean;
  align?: 'right' | 'center';
  /** Value in the CSV export (default: the raw column). */
  csv?: (row: Row) => string | number | null | undefined;
  /** The title column: a link, with the row actions under it. */
  primary?: boolean;
  width?: string;
  /** Keep the cell on one line (default: numbers and dates). */
  nowrap?: boolean;
}

export interface Filter {
  key: string;
  label: string;
  apply?: (q: Query) => Query;
}

export interface RowAction {
  label: string;
  onClick?: () => void;
  href?: string;
  danger?: boolean;
}

export interface BulkAction {
  label: string;
  run: (rows: Row[]) => Promise<void> | void;
}

interface Props {
  view: string;
  columns: Column[];
  /** Text columns to search in. */
  search?: string[];
  searchLabel?: string;
  filters?: Filter[];
  initialFilter?: string | null;
  defaultSort?: { key: string; asc?: boolean };
  /** Always applied, e.g. only this patient's orders. */
  scope?: (q: Query) => Query;
  rowHref?: (row: Row) => string | null;
  rowActions?: (row: Row) => RowAction[];
  bulkActions?: BulkAction[];
  /** CSV file name (without .csv); no export button when missing. */
  exportName?: string;
  pageSize?: number;
  /** Change it to reload. */
  refreshKey?: number;
  /** Inside a record page: no search or filter tabs. */
  embedded?: boolean;
  emptyText?: string;
  idKey?: string;
}

const oneLine = (c: Column) => c.nowrap ?? (c.align === 'right' || /(_at|_expiry)$/.test(c.key));

function clean(term: string) {
  return term.replace(/[,()*%\\]/g, ' ').trim();
}

export function DataTable({
  view, columns, search = [], searchLabel = 'Search', filters, initialFilter, defaultSort,
  scope, rowHref, rowActions, bulkActions, exportName, pageSize = 20, refreshKey = 0,
  embedded, emptyText = 'Nothing here yet.', idKey = 'id',
}: Props) {
  const notice = useNotice();
  const [rows, setRows] = useState<Row[]>([]);
  const [total, setTotal] = useState(0);
  const [counts, setCounts] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<string>(
    (initialFilter && filters?.some((f) => f.key === initialFilter) ? initialFilter : filters?.[0]?.key) ?? '',
  );
  const [term, setTerm] = useState('');
  const [typed, setTyped] = useState('');
  const [page, setPage] = useState(0);
  const [sort, setSort] = useState(defaultSort ?? { key: columns[0]!.key, asc: true });
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [bulk, setBulk] = useState('');
  const [exporting, setExporting] = useState(false);
  const seq = useRef(0);

  // Pages pass scope, search and filters inline, so they are new on every
  // render. Keep the latest in refs and refetch only when what they mean
  // changes; otherwise each render would start another fetch, forever.
  // (Record pages remount per id, so a scope never changes underneath us.)
  const latest = useRef({ scope, search, filters });
  useLayoutEffect(() => {
    latest.current = { scope, search, filters };
  });
  const searchKey = search.join(',');
  const filterKeys = filters?.map((f) => f.key).join(',') ?? '';

  const build = useCallback(
    (q: Query, withFilter: Filter | undefined) => {
      const { scope: limit, search: cols } = latest.current;
      let out = q;
      if (limit) out = limit(out);
      const t = clean(term);
      if (t && cols.length) out = out.or(cols.map((c) => `${c}.ilike.%${t}%`).join(','));
      if (withFilter?.apply) out = withFilter.apply(out);
      return out;
    },
    [term, searchKey], // searchKey stands in for the columns kept in `latest`
  );

  const activeFilter = () => latest.current.filters?.find((f) => f.key === filter);

  const load = useCallback(async () => {
    const my = ++seq.current;
    setLoading(true);
    setError(null);
    let q = build(supabase.from(view).select('*', { count: 'exact' }), activeFilter());
    q = q.order(sort.key, { ascending: sort.asc ?? true, nullsFirst: false });
    if (sort.key !== idKey) q = q.order(idKey, { ascending: true });
    const from = page * pageSize;
    const { data, count: n, error: e } = await q.range(from, from + pageSize - 1);
    if (my !== seq.current) return;
    if (e) {
      setError(friendlyError(e.message));
      setRows([]);
      setTotal(0);
    } else {
      setRows(data ?? []);
      setTotal(n ?? 0);
    }
    setLoading(false);

    // Counts for the filter tabs.
    const tabs = latest.current.filters;
    if (tabs && !embedded) {
      const entries = await Promise.all(
        tabs.map(async (f) => {
          const { count: c } = await build(supabase.from(view).select('*', { count: 'exact', head: true }), f);
          return [f.key, c ?? 0] as const;
        }),
      );
      if (my === seq.current) setCounts(Object.fromEntries(entries));
    }
  }, [build, view, filter, filterKeys, sort, page, pageSize, embedded, idKey]);

  useEffect(() => {
    load();
  }, [load, refreshKey]);

  useEffect(() => {
    setSelected(new Set());
  }, [filter, term, page, refreshKey]);

  const pages = Math.max(1, Math.ceil(total / pageSize));
  const allOnPage = rows.length > 0 && rows.every((r) => selected.has(String(r[idKey])));
  const selectedRows = useMemo(() => rows.filter((r) => selected.has(String(r[idKey]))), [rows, selected, idKey]);

  const toggleSort = (c: Column) => {
    if (c.sortable === false) return;
    setPage(0);
    setSort((s) => (s.key === c.key ? { key: c.key, asc: !s.asc } : { key: c.key, asc: true }));
  };

  const exportCsv = async () => {
    if (!exportName) return;
    setExporting(true);
    let q = build(supabase.from(view).select('*'), activeFilter()).order(sort.key, { ascending: sort.asc ?? true });
    const { data, error: e } = await q.limit(5000);
    setExporting(false);
    if (e) return notice.error(friendlyError(e.message));
    const list = (data ?? []) as Row[];
    downloadCsv(
      `${exportName}-${new Date().toISOString().slice(0, 10)}.csv`,
      columns.map((c) => c.label),
      list.map((r) => columns.map((c) => (c.csv ? c.csv(r) : r[c.key] ?? ''))),
    );
    notice.success(`Exported ${list.length} row${list.length === 1 ? '' : 's'}.`);
  };

  const runBulk = async () => {
    const action = bulkActions?.find((b) => b.label === bulk);
    if (!action || !selectedRows.length) return;
    await action.run(selectedRows);
    setBulk('');
    setSelected(new Set());
  };

  return (
    <div className={`list ${embedded ? 'list-embedded' : ''}`}>
      {!embedded && (filters || search.length > 0) && (
        <div className="list-top">
          {filters && (
            <ul className="subsubsub">
              {filters.map((f, i) => (
                <li key={f.key}>
                  <button
                    type="button"
                    className={f.key === filter ? 'current' : ''}
                    onClick={() => {
                      setFilter(f.key);
                      setPage(0);
                    }}
                  >
                    {f.label} <span className="count">({counts[f.key] ?? '…'})</span>
                  </button>
                  {i < filters.length - 1 && <span className="sep">|</span>}
                </li>
              ))}
            </ul>
          )}
          {search.length > 0 && (
            <form
              className="search-box"
              onSubmit={(e) => {
                e.preventDefault();
                setTerm(typed);
                setPage(0);
              }}
            >
              <input
                type="search"
                value={typed}
                placeholder={searchLabel}
                aria-label={searchLabel}
                onChange={(e) => {
                  setTyped(e.target.value);
                  if (!e.target.value) {
                    setTerm('');
                    setPage(0);
                  }
                }}
              />
              <Button type="submit">
                <Search size={14} /> {searchLabel}
              </Button>
            </form>
          )}
        </div>
      )}

      {!embedded && (
        <div className="tablenav">
          {bulkActions && bulkActions.length > 0 && (
            <div className="bulk">
              <select value={bulk} onChange={(e) => setBulk(e.target.value)} aria-label="Bulk actions">
                <option value="">Bulk actions</option>
                {bulkActions.map((b) => (
                  <option key={b.label} value={b.label}>{b.label}</option>
                ))}
              </select>
              <Button onClick={runBulk} disabled={!bulk || !selectedRows.length}>Apply</Button>
              {selectedRows.length > 0 && <span className="muted">{selectedRows.length} selected</span>}
            </div>
          )}
          <div className="tablenav-right">
            {exportName && (
              <Button variant="ghost" onClick={exportCsv} busy={exporting} title="Download as a spreadsheet (CSV)">
                <Download size={14} /> Export
              </Button>
            )}
            <Pager page={page} pages={pages} total={total} onPage={setPage} />
          </div>
        </div>
      )}

      <div className={`table-wrap ${loading && rows.length ? 'refreshing' : ''}`}>
        <table className="wp-table">
          <thead>
            <tr>
              {bulkActions && !embedded && (
                <th className="check">
                  <input
                    type="checkbox"
                    aria-label="Select all"
                    checked={allOnPage}
                    onChange={() =>
                      setSelected(allOnPage ? new Set() : new Set(rows.map((r) => String(r[idKey]))))
                    }
                  />
                </th>
              )}
              {columns.map((c) => (
                <th
                  key={c.key}
                  style={{ width: c.width, textAlign: c.align }}
                  className={c.sortable === false ? '' : 'sortable'}
                  aria-sort={sort.key === c.key ? (sort.asc ? 'ascending' : 'descending') : undefined}
                >
                  {c.sortable === false ? (
                    c.label
                  ) : (
                    <button type="button" onClick={() => toggleSort(c)}>
                      {c.label}
                      {sort.key === c.key && (sort.asc ? <ChevronUp size={13} /> : <ChevronDown size={13} />)}
                    </button>
                  )}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {error && (
              <tr>
                <td colSpan={columns.length + 1} className="table-msg error">{error}</td>
              </tr>
            )}
            {!error && !loading && rows.length === 0 && (
              <tr>
                <td colSpan={columns.length + 1} className="table-msg">
                  {term ? `Nothing matches “${term}”.` : emptyText}
                </td>
              </tr>
            )}
            {!error && loading && rows.length === 0 && (
              <tr>
                <td colSpan={columns.length + 1} className="table-msg">Loading…</td>
              </tr>
            )}
            {rows.map((r) => {
              const id = String(r[idKey]);
              const href = rowHref?.(r) ?? null;
              const actions = rowActions?.(r) ?? [];
              return (
                <tr key={id} className={selected.has(id) ? 'selected' : ''}>
                  {bulkActions && !embedded && (
                    <td className="check">
                      <input
                        type="checkbox"
                        aria-label="Select row"
                        checked={selected.has(id)}
                        onChange={() =>
                          setSelected((s) => {
                            const n = new Set(s);
                            if (n.has(id)) n.delete(id);
                            else n.add(id);
                            return n;
                          })
                        }
                      />
                    </td>
                  )}
                  {columns.map((c) => {
                    const content = c.render ? c.render(r) : (r[c.key] ?? <span className="muted">—</span>);
                    return (
                      <td
                        key={c.key}
                        style={{ textAlign: c.align }}
                        className={c.primary ? 'primary' : oneLine(c) ? 'nowrap' : undefined}
                      >
                        {c.primary && href ? (
                          <a className="row-title" href={href}>{content}</a>
                        ) : (
                          content
                        )}
                        {c.primary && actions.length > 0 && (
                          <div className="row-actions">
                            {actions.map((a, i) => (
                              <span key={a.label}>
                                {a.href ? (
                                  <a href={a.href} className={a.danger ? 'danger' : ''}>{a.label}</a>
                                ) : (
                                  <button type="button" className={a.danger ? 'danger' : ''} onClick={a.onClick}>
                                    {a.label}
                                  </button>
                                )}
                                {i < actions.length - 1 && <span className="sep">|</span>}
                              </span>
                            ))}
                          </div>
                        )}
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {embedded && total > pageSize && (
        <div className="tablenav tablenav-bottom">
          <Pager page={page} pages={pages} total={total} onPage={setPage} />
        </div>
      )}
    </div>
  );
}

function Pager({ page, pages, total, onPage }: { page: number; pages: number; total: number; onPage: (p: number) => void }) {
  return (
    <div className="pager">
      <span className="muted">{total} item{total === 1 ? '' : 's'}</span>
      {pages > 1 && (
        <>
          <button type="button" aria-label="First page" disabled={page === 0} onClick={() => onPage(0)}>
            <ChevronsLeft size={15} />
          </button>
          <button type="button" aria-label="Previous page" disabled={page === 0} onClick={() => onPage(page - 1)}>
            <ChevronLeft size={15} />
          </button>
          <span>
            {page + 1} of {pages}
          </span>
          <button type="button" aria-label="Next page" disabled={page >= pages - 1} onClick={() => onPage(page + 1)}>
            <ChevronRight size={15} />
          </button>
          <button type="button" aria-label="Last page" disabled={page >= pages - 1} onClick={() => onPage(pages - 1)}>
            <ChevronsRight size={15} />
          </button>
        </>
      )}
    </div>
  );
}
