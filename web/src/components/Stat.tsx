import type { ReactNode } from 'react';
import { formatCents, type Cents } from '../api/money';

export interface StatProps {
  label: ReactNode;
  /** Integer cents; formatted with the shared money helpers. */
  cents: Cents;
  note?: ReactNode;
  showCents?: boolean;
}

/** A labelled money figure. */
export function Stat({ label, cents, note, showCents = false }: StatProps) {
  return (
    <div className="stat">
      <dt className="stat__label">{label}</dt>
      <dd className="stat__value num">{formatCents(cents, { showCents })}</dd>
      {note && <dd className="stat__note">{note}</dd>}
    </div>
  );
}

/** Wrap Stats in this so the dt/dd structure is valid. */
export function StatGroup({ children }: { children: ReactNode }) {
  return <dl className="stat-group">{children}</dl>;
}
