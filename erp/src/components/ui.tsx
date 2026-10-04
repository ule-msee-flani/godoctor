import {
  createContext, useCallback, useContext, useEffect, useRef, useState,
  type ButtonHTMLAttributes, type ReactNode,
} from 'react';
import { CircleAlert, CircleCheck, Info, LoaderCircle, X } from 'lucide-react';
import { initials, label } from '../lib/format';

// ---------------------------------------------------------------------------
// Buttons, pills, small pieces
// ---------------------------------------------------------------------------

type Variant = 'primary' | 'secondary' | 'danger' | 'link' | 'ghost';

export function Button({
  variant = 'secondary', busy, children, className = '', ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; busy?: boolean }) {
  return (
    <button
      type="button"
      {...rest}
      disabled={rest.disabled || busy}
      className={`btn btn-${variant} ${className}`}
    >
      {busy && <LoaderCircle size={15} className="spin" aria-hidden />}
      {children}
    </button>
  );
}

const TONES: Record<string, string> = {
  active: 'good', verified: 'good', valid: 'good', completed: 'good', fulfilled: 'good',
  succeeded: 'good', paid: 'good', released: 'good', answered: 'good', available: 'good',
  pending: 'warn', awaiting_payment: 'warn', placed: 'warn', confirmed: 'warn', ready: 'warn',
  expiring: 'warn', held: 'warn', open: 'warn', scheduled: 'info', matched: 'info',
  in_progress: 'info', requested: 'info', offered: 'info', busy: 'info', high: 'warn',
  suspended: 'bad', cancelled: 'bad', failed: 'bad', disputed: 'bad', expired: 'bad',
  refunded: 'bad', urgent: 'bad', unmatched: 'bad', hidden: 'bad',
  closed: 'muted', no_expiry: 'muted', offline: 'muted', low: 'muted', normal: 'muted',
};

const PILL_TEXT: Record<string, string> = {
  no_expiry: 'No expiry set',
  awaiting_payment: 'Awaiting payment',
  expiring: 'Expiring soon',
};

/** A status, always as words (never colour alone). */
export function Pill({ value, text, tone }: { value?: string | null; text?: string; tone?: string }) {
  if (!value && !text) return <span className="muted">—</span>;
  const t = tone ?? TONES[value ?? ''] ?? 'muted';
  return <span className={`pill pill-${t}`}>{text ?? PILL_TEXT[value ?? ''] ?? label(value)}</span>;
}

export function Avatar({ name, size = 32 }: { name?: string | null; size?: number }) {
  return (
    <span className="avatar" style={{ width: size, height: size, fontSize: size * 0.38 }} aria-hidden>
      {initials(name)}
    </span>
  );
}

export function Spinner({ text = 'Loading…' }: { text?: string }) {
  return (
    <div className="spinner-row">
      <LoaderCircle size={18} className="spin" aria-hidden /> {text}
    </div>
  );
}

export function Empty({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="empty">
      <strong>{title}</strong>
      {children && <p>{children}</p>}
    </div>
  );
}

/** A WordPress-style box with a title bar. */
export function Postbox({
  title, actions, children, pad = true, className = '',
}: { title?: ReactNode; actions?: ReactNode; children: ReactNode; pad?: boolean; className?: string }) {
  return (
    <section className={`postbox ${className}`}>
      {(title || actions) && (
        <header className="postbox-head">
          <h2>{title}</h2>
          {actions && <div className="postbox-actions">{actions}</div>}
        </header>
      )}
      <div className={pad ? 'postbox-body' : ''}>{children}</div>
    </section>
  );
}

/** Label / value rows. */
export function Facts({ rows }: { rows: [string, ReactNode][] }) {
  return (
    <dl className="facts">
      {rows.map(([k, v]) => (
        <div key={k}>
          <dt>{k}</dt>
          <dd>{v === null || v === undefined || v === '' ? <span className="muted">—</span> : v}</dd>
        </div>
      ))}
    </dl>
  );
}

export function PageHeader({
  title, action, children,
}: { title: ReactNode; action?: ReactNode; children?: ReactNode }) {
  return (
    <div className="page-head">
      <div className="page-title">
        <h1>{title}</h1>
        {action}
      </div>
      {children && <p className="page-sub">{children}</p>}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Notices (WordPress admin notices, top of the page)
// ---------------------------------------------------------------------------

interface NoticeItem { id: number; kind: 'success' | 'error' | 'info'; text: string }
interface NoticeApi {
  success: (t: string) => void;
  error: (t: string) => void;
  info: (t: string) => void;
}
const NoticeCtx = createContext<NoticeApi | null>(null);

export function NoticeProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<NoticeItem[]>([]);
  const next = useRef(1);
  const push = useCallback((kind: NoticeItem['kind'], text: string) => {
    const id = next.current++;
    setItems((xs) => [...xs, { id, kind, text }]);
    setTimeout(() => setItems((xs) => xs.filter((x) => x.id !== id)), kind === 'error' ? 9000 : 5000);
  }, []);
  const api: NoticeApi = {
    success: (t) => push('success', t),
    error: (t) => push('error', t),
    info: (t) => push('info', t),
  };
  return (
    <NoticeCtx.Provider value={api}>
      {children}
      <div className="notices" role="status" aria-live="polite">
        {items.map((n) => (
          <div key={n.id} className={`notice notice-${n.kind}`}>
            {n.kind === 'success' ? <CircleCheck size={17} /> : n.kind === 'error' ? <CircleAlert size={17} /> : <Info size={17} />}
            <span>{n.text}</span>
            <button
              type="button"
              aria-label="Dismiss"
              onClick={() => setItems((xs) => xs.filter((x) => x.id !== n.id))}
            >
              <X size={15} />
            </button>
          </div>
        ))}
      </div>
    </NoticeCtx.Provider>
  );
}

export function useNotice(): NoticeApi {
  const v = useContext(NoticeCtx);
  if (!v) throw new Error('useNotice outside NoticeProvider');
  return v;
}

// ---------------------------------------------------------------------------
// Dialogs: confirm, ask for a reason, or any form
// ---------------------------------------------------------------------------

export function Modal({
  title, onClose, children, footer, wide,
}: { title: string; onClose: () => void; children: ReactNode; footer?: ReactNode; wide?: boolean }) {
  useEffect(() => {
    const on = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', on);
    return () => window.removeEventListener('keydown', on);
  }, [onClose]);
  return (
    <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className={`modal ${wide ? 'modal-wide' : ''}`} role="dialog" aria-modal="true" aria-label={title}>
        <header className="modal-head">
          <h2>{title}</h2>
          <button type="button" className="icon-btn" aria-label="Close" onClick={onClose}>
            <X size={18} />
          </button>
        </header>
        <div className="modal-body">{children}</div>
        {footer && <footer className="modal-foot">{footer}</footer>}
      </div>
    </div>
  );
}

interface AskOptions {
  title: string;
  message?: ReactNode;
  confirm?: string;
  danger?: boolean;
  /** Ask for a reason (written to the activity log). */
  reason?: 'required' | 'optional';
  reasonLabel?: string;
  reasonPlaceholder?: string;
  choices?: string[];
}

interface DialogApi {
  /** Resolves to the reason ('' when not asked), or null when cancelled. */
  ask: (o: AskOptions) => Promise<string | null>;
}
const DialogCtx = createContext<DialogApi | null>(null);

export function DialogProvider({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState<(AskOptions & { resolve: (v: string | null) => void }) | null>(null);
  const [text, setText] = useState('');

  const ask = useCallback(
    (o: AskOptions) =>
      new Promise<string | null>((resolve) => {
        setText('');
        setOpen({ ...o, resolve });
      }),
    [],
  );

  const close = (v: string | null) => {
    open?.resolve(v);
    setOpen(null);
  };
  const ok = !open?.reason || open.reason === 'optional' || text.trim().length >= 3;

  return (
    <DialogCtx.Provider value={{ ask }}>
      {children}
      {open && (
        <Modal
          title={open.title}
          onClose={() => close(null)}
          footer={
            <>
              <Button onClick={() => close(null)}>Cancel</Button>
              <Button
                variant={open.danger ? 'danger' : 'primary'}
                disabled={!ok}
                onClick={() => close(text.trim())}
              >
                {open.confirm ?? 'Confirm'}
              </Button>
            </>
          }
        >
          {open.message && <div className="modal-message">{open.message}</div>}
          {open.reason && (
            <label className="field">
              <span>
                {open.reasonLabel ?? 'Reason'}
                {open.reason === 'required' ? '' : ' (optional)'}
              </span>
              {open.choices && (
                <div className="chips">
                  {open.choices.map((c) => (
                    <button
                      type="button"
                      key={c}
                      className={`chip ${text === c ? 'chip-on' : ''}`}
                      onClick={() => setText(c)}
                    >
                      {c}
                    </button>
                  ))}
                </div>
              )}
              <textarea
                autoFocus
                rows={3}
                value={text}
                placeholder={open.reasonPlaceholder ?? 'This is saved in the activity log.'}
                onChange={(e) => setText(e.target.value)}
              />
            </label>
          )}
        </Modal>
      )}
    </DialogCtx.Provider>
  );
}

export function useDialog(): DialogApi {
  const v = useContext(DialogCtx);
  if (!v) throw new Error('useDialog outside DialogProvider');
  return v;
}

// ---------------------------------------------------------------------------
// Form fields
// ---------------------------------------------------------------------------

export function Field({
  label: text, hint, children,
}: { label: string; hint?: ReactNode; children: ReactNode }) {
  return (
    <label className="field">
      <span>{text}</span>
      {children}
      {hint && <small className="hint">{hint}</small>}
    </label>
  );
}
