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
    <div className="grid gap-0.5 bg-card px-4 py-3">
      <dt className="text-xs font-medium text-muted-foreground">{label}</dt>
      <dd className="m-0 text-lg font-semibold tabular-nums">{formatCents(cents, { showCents })}</dd>
      {note && <dd className="m-0 text-xs text-muted-foreground">{note}</dd>}
    </div>
  );
}

/** Wrap Stats in this so the dt/dd structure is valid. Renders a bordered row of figures. */
export function StatGroup({ children }: { children: ReactNode }) {
  return (
    <dl className="m-0 grid grid-cols-1 gap-px overflow-hidden rounded-lg border bg-border sm:grid-cols-3">{children}</dl>
  );
}
