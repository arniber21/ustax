import { ArrowDownLeft, ArrowUpRight, ShieldCheck } from 'lucide-react';
import { Link } from 'react-router';
import { formatCents } from '../api';
import type { Lines, Outcome } from '../api';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

export interface ResultsHeroProps {
  outcome: Outcome;
  lines: Lines;
  /** Dim the numbers while a fresh calculation is in flight. */
  stale?: boolean;
  /** Filing status in words, shown as a chip. */
  filingStatus?: string;
}

/** Plain-language label for the outcome, used as the summary heading. */
export function outcomeLabel(outcome: Outcome): string {
  return outcome === 'refund' ? 'Your refund' : outcome === 'balance_due' ? 'Amount you owe' : 'No refund and nothing owed';
}

export const KEY_FIGURES: { key: keyof Lines; label: string; line: string }[] = [
  { key: 'total_income', label: 'Total income', line: '9' },
  { key: 'agi', label: 'Adjusted gross income', line: '11' },
  { key: 'taxable_income', label: 'Taxable income', line: '15' },
  { key: 'total_tax', label: 'Total tax', line: '24' },
  { key: 'total_payments', label: 'Total payments', line: '33' },
];

/**
 * The result summary: refund or amount owed as one large figure with its label, the filing status, the
 * key 1040 figures, and a link to what is verified. No count-up animation: the final amount is shown at once.
 */
export function ResultsHero({ outcome, lines, stale = false, filingStatus }: ResultsHeroProps) {
  const refund = outcome === 'refund';
  const owe = outcome === 'balance_due';
  const amount = refund ? lines.overpayment : owe ? lines.balance_due : 0;
  const label = outcomeLabel(outcome);
  const sub = refund
    ? 'Your payments (line 33) are more than your total tax (line 24). Form 1040, line 34.'
    : owe
      ? 'Your total tax (line 24) is more than your payments (line 33). Due April 15, 2025. Form 1040, line 37.'
      : 'Your payments equal your total tax.';
  const Icon = refund ? ArrowDownLeft : ArrowUpRight;
  return (
    <section
      aria-labelledby="result-label"
      aria-busy={stale}
      className={cn(
        'relative grid overflow-hidden rounded-2xl border bg-card shadow-sm transition-opacity md:grid-cols-[minmax(0,1fr)_minmax(0,22rem)]',
        stale && 'opacity-60',
      )}
    >
      <div
        aria-hidden="true"
        className={cn(
          'pointer-events-none absolute inset-x-0 top-0 h-1',
          refund ? 'bg-success' : owe ? 'bg-destructive' : 'bg-primary',
        )}
      />
      <div className="grid content-start gap-3 p-6 sm:p-8">
        <div className="flex flex-wrap items-center gap-2">
          <span
            aria-hidden="true"
            className={cn(
              'grid size-8 place-items-center rounded-full',
              refund ? 'bg-success-soft text-success' : owe ? 'bg-destructive-soft text-destructive' : 'bg-muted text-muted-foreground',
            )}
          >
            <Icon className="size-4" />
          </span>
          <p id="result-label" className="m-0 text-sm font-semibold text-muted-foreground">
            {label}
          </p>
          {filingStatus && (
            <Badge variant="secondary" className="ml-1">
              {filingStatus}
            </Badge>
          )}
          <Badge variant="outline">Tax year 2024</Badge>
        </div>
        <p
          className={cn(
            'result-amount m-0 text-5xl leading-none font-semibold tracking-tight tabular-nums sm:text-6xl',
            refund && 'text-success',
            owe && 'text-destructive',
          )}
        >
          {formatCents(amount)}
        </p>
        <p className="m-0 max-w-md text-sm leading-relaxed text-muted-foreground">{sub}</p>
        <Link
          to="/trust"
          className="mt-2 inline-flex w-fit items-center gap-2 rounded-full border border-success/30 bg-success-soft px-3 py-1.5 text-sm font-medium text-success no-underline hover:underline"
        >
          <ShieldCheck aria-hidden="true" className="size-4" />
          Key properties proven in Lean: see what is verified
        </Link>
      </div>
      <dl className="m-0 grid content-center divide-y border-t bg-muted/60 md:border-t-0 md:border-l">
        {KEY_FIGURES.map((f) => (
          <div key={f.key} className="flex items-baseline justify-between gap-4 px-6 py-3">
            <dt className="text-sm text-muted-foreground">
              {f.label} <span className="text-xs">(line {f.line})</span>
            </dt>
            <dd className="m-0 text-sm font-semibold tabular-nums">{formatCents(lines[f.key] ?? 0)}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
