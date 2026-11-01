import { useId } from 'react';
import { formatCents, type Lines, type Outcome } from '../api';
import { cn } from '@/lib/utils';

export type FlowKind = 'amount' | 'less' | 'result-good' | 'result-bad';

export interface FlowStep {
  key: string;
  label: string;
  /** Form 1040 line, shown muted. */
  line: string;
  cents: number;
  kind: FlowKind;
}

/**
 * "Where your money went": the chain income -> deductions -> tax -> credits -> payments -> result, as
 * bars on one scale. Pure, so the ordering and signs are unit tested. Zero reductions are skipped.
 */
export function flowSteps(lines: Lines, outcome: Outcome): FlowStep[] {
  const steps: FlowStep[] = [
    { key: 'total_income', label: 'Total income', line: '9', cents: lines.total_income, kind: 'amount' },
    { key: 'adjustments_to_income', label: 'Adjustments', line: '10', cents: lines.adjustments_to_income, kind: 'less' },
    { key: 'total_deductions', label: 'Deductions', line: '14', cents: lines.total_deductions, kind: 'less' },
    { key: 'taxable_income', label: 'Taxable income', line: '15', cents: lines.taxable_income, kind: 'amount' },
    { key: 'total_tentative_tax', label: 'Tax before credits', line: '18', cents: lines.total_tentative_tax, kind: 'amount' },
    { key: 'non_refundable_credits', label: 'Credits', line: '21', cents: lines.non_refundable_credits, kind: 'less' },
    { key: 'total_tax', label: 'Total tax', line: '24', cents: lines.total_tax, kind: 'amount' },
    { key: 'total_payments', label: 'Payments and credits', line: '33', cents: lines.total_payments, kind: 'amount' },
  ];
  const kept = steps.filter((s) => s.kind !== 'less' || s.cents !== 0);
  if (outcome === 'refund') kept.push({ key: 'overpayment', label: 'Your refund', line: '34', cents: lines.overpayment, kind: 'result-good' });
  if (outcome === 'balance_due') kept.push({ key: 'balance_due', label: 'You owe', line: '37', cents: lines.balance_due, kind: 'result-bad' });
  return kept;
}

/** Bar width in percent of the largest step (at least a sliver for non-zero values, so they stay visible). */
export function barPercent(cents: number, max: number): number {
  if (max <= 0 || cents <= 0) return 0;
  return Math.max(1.5, Math.round((cents / max) * 1000) / 10);
}

const BAR: Record<FlowKind, string> = {
  amount: 'bg-primary/85',
  less: 'bg-[repeating-linear-gradient(135deg,var(--muted-foreground)_0_2px,transparent_2px_6px)] opacity-45',
  'result-good': 'bg-success',
  'result-bad': 'bg-destructive',
};

/** The horizontal bar chart. Each row is a labelled figure, so the chart is readable without colour. */
export function MoneyFlow({ lines, outcome }: { lines: Lines; outcome: Outcome }) {
  const id = useId();
  const steps = flowSteps(lines, outcome);
  const max = Math.max(...steps.map((s) => s.cents), 1);
  return (
    <section aria-labelledby={`${id}-h`} className="rounded-xl border bg-card p-5 shadow-xs sm:p-6">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 id={`${id}-h`} className="m-0 text-base font-semibold tracking-tight">
          Where your money went
        </h2>
        <p className="m-0 flex items-center gap-3 text-xs text-muted-foreground" aria-hidden="true">
          <span className="inline-flex items-center gap-1.5">
            <span className="inline-block size-2.5 rounded-sm bg-primary/85" /> amount
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span className="inline-block size-2.5 rounded-sm bg-[repeating-linear-gradient(135deg,var(--muted-foreground)_0_2px,transparent_2px_4px)] opacity-60" />{' '}
            taken off
          </span>
        </p>
      </div>
      <ol className="m-0 mt-4 grid list-none gap-2.5 p-0">
        {steps.map((s) => (
          <li key={s.key} className="grid grid-cols-[minmax(0,9.5rem)_minmax(0,1fr)_auto] items-center gap-3 text-sm sm:grid-cols-[minmax(0,13rem)_minmax(0,1fr)_7rem]">
            <span className={cn('truncate', s.kind === 'less' ? 'text-muted-foreground' : 'font-medium')}>
              {s.kind === 'less' && <span aria-hidden="true">− </span>}
              {s.label} <span className="text-xs font-normal text-muted-foreground">({s.line})</span>
            </span>
            <span className="h-2.5 overflow-hidden rounded-full bg-muted" aria-hidden="true">
              <span
                className={cn('block h-full rounded-full transition-[width] duration-700 ease-out motion-reduce:transition-none', BAR[s.kind])}
                style={{ width: `${barPercent(s.cents, max)}%` }}
              />
            </span>
            <span
              className={cn(
                'text-right font-medium tabular-nums',
                s.kind === 'less' && 'text-muted-foreground',
                s.kind === 'result-good' && 'font-semibold text-success',
                s.kind === 'result-bad' && 'font-semibold text-destructive',
              )}
            >
              {s.kind === 'less' ? `−${formatCents(s.cents, { showCents: false })}` : formatCents(s.cents, { showCents: false })}
            </span>
          </li>
        ))}
      </ol>
    </section>
  );
}
