import { useMemo, useState } from 'react';

// One series per chart (the title names it, so no legend), thin columns
// with rounded tops, a 2px gap between them, hairline grid, a tooltip on
// every column and a table view of the same numbers.

const BLUE = '#1B63F2';

function niceMax(v: number): number {
  if (v <= 0) return 4;
  const pow = 10 ** Math.floor(Math.log10(v));
  for (const m of [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) {
    if (m * pow >= v) return m * pow;
  }
  return 10 * pow;
}

export interface Point {
  label: string;      // e.g. "5 Oct"
  value: number;
}

export function ColumnChart({
  points, format = (n: number) => n.toLocaleString('en-KE'), height = 180, title,
}: {
  points: Point[];
  format?: (n: number) => string;
  height?: number;
  title: string;
}) {
  const [hover, setHover] = useState<number | null>(null);
  const [table, setTable] = useState(false);
  const max = useMemo(() => niceMax(Math.max(0, ...points.map((p) => p.value))), [points]);

  const W = 640, H = height, padL = 44, padB = 22, padT = 8, padR = 6;
  const plotW = W - padL - padR, plotH = H - padT - padB;
  const slot = plotW / Math.max(points.length, 1);
  const barW = Math.min(24, Math.max(2, slot - 2));
  const ticks = [0, max / 2, max];
  const labelEvery = Math.max(1, Math.ceil(points.length / 7));

  if (table) {
    return (
      <div>
        <table className="wp-table compact-table">
          <thead>
            <tr><th>Day</th><th style={{ textAlign: 'right' }}>{title}</th></tr>
          </thead>
          <tbody>
            {points.map((p) => (
              <tr key={p.label}><td>{p.label}</td><td style={{ textAlign: 'right' }} className="num">{format(p.value)}</td></tr>
            ))}
          </tbody>
        </table>
        <button type="button" className="link-btn" onClick={() => setTable(false)}>Show as a chart</button>
      </div>
    );
  }

  return (
    <div className="chart">
      <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label={`${title}, by day`} preserveAspectRatio="none">
        {ticks.map((t) => {
          const y = padT + plotH - (t / max) * plotH;
          return (
            <g key={t}>
              <line x1={padL} x2={W - padR} y1={y} y2={y} stroke="#E3E7EE" strokeWidth={1} />
              <text x={padL - 8} y={y + 4} textAnchor="end" className="axis">{format(t)}</text>
            </g>
          );
        })}
        {points.map((p, i) => {
          const h = (p.value / max) * plotH;
          const x = padL + i * slot + (slot - barW) / 2;
          const y = padT + plotH - h;
          const r = Math.min(4, barW / 2, h);
          return (
            <g key={p.label}>
              {h > 0 && (
                <path
                  d={`M${x},${y + h} L${x},${y + r} Q${x},${y} ${x + r},${y} L${x + barW - r},${y} Q${x + barW},${y} ${x + barW},${y + r} L${x + barW},${y + h} Z`}
                  fill={BLUE}
                  opacity={hover === null || hover === i ? 1 : 0.55}
                />
              )}
              {/* The hit area is the whole slot, not just the painted bar. */}
              <rect
                x={padL + i * slot}
                y={padT}
                width={slot}
                height={plotH}
                fill="transparent"
                onPointerEnter={() => setHover(i)}
                onPointerLeave={() => setHover(null)}
              />
              {i % labelEvery === 0 && (
                <text x={padL + i * slot + slot / 2} y={H - 6} textAnchor="middle" className="axis">
                  {p.label}
                </text>
              )}
            </g>
          );
        })}
        <line x1={padL} x2={W - padR} y1={padT + plotH} y2={padT + plotH} stroke="#C9D0DC" strokeWidth={1} />
      </svg>
      {hover !== null && points[hover] && (
        <div
          className="chart-tip"
          style={{ left: `${((padL + hover * slot + slot / 2) / W) * 100}%` }}
          role="status"
        >
          <strong>{format(points[hover].value)}</strong>
          <span>{points[hover].label}</span>
        </div>
      )}
      <button type="button" className="link-btn" onClick={() => setTable(true)}>Show as a table</button>
    </div>
  );
}

/** Horizontal bars for a few categories, value at the tip. */
export function BarList({ items, format = (n: number) => n.toLocaleString('en-KE') }: {
  items: { name: string; value: number }[];
  format?: (n: number) => string;
}) {
  const max = Math.max(1, ...items.map((i) => i.value));
  if (!items.length) return <p className="muted">No data yet.</p>;
  return (
    <ul className="barlist">
      {items.map((i) => (
        <li key={i.name} title={`${i.name}: ${format(i.value)}`}>
          <span className="barlist-name">{i.name}</span>
          <span className="barlist-track">
            <span className="barlist-bar" style={{ width: `${(i.value / max) * 100}%`, background: BLUE }} />
          </span>
          <span className="barlist-value num">{format(i.value)}</span>
        </li>
      ))}
    </ul>
  );
}
