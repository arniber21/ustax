import { useEffect, useRef } from 'react';
import { ChevronUp, CircleAlert, Info, ShieldCheck } from 'lucide-react';
import { toast } from 'sonner';
import { formatCents, type CalculateRequest, type ClientOptions, type CalculateSuccess, type Lines } from '../api';
import { useDraft } from '../draft';
import { useLiveCalculation, type LiveState } from '../results/useLiveCalculation';
import { Badge } from '../components/ui/badge';
import { Button } from '../components/ui/button';
import { Sheet, SheetContent, SheetDescription, SheetTitle, SheetTrigger } from '../components/ui/sheet';
import { Skeleton } from '../components/ui/skeleton';
import { cn } from '@/lib/utils';

/** What the running estimate shows. Derived from the live calculation state; pure, so it is unit tested. */
export type Estimate =
  | { kind: 'empty' }
  | { kind: 'loading' }
  | { kind: 'ok'; data: CalculateSuccess; updating: boolean; stale: boolean }
  | { kind: 'knockout' }
  | { kind: 'needs-income' }
  | { kind: 'unavailable' };

/** The calculator knocks out a return with no payments at all; early in the wizard that just means "no income yet". */
const NOTHING_YET = 'KnockoutHasNoPaymentsOrCredits';

export function toEstimate(request: CalculateRequest | null, state: LiveState): Estimate {
  if (request === null) return { kind: 'empty' };
  if (state.status === 'ok') return { kind: 'ok', data: state.data, updating: false, stale: false };
  if (state.status === 'knockout') return state.reasons.length > 0 && state.reasons.every((r) => r.code === NOTHING_YET) ? { kind: 'needs-income' } : { kind: 'knockout' };
  if (state.status === 'loading') return state.previous ? { kind: 'ok', data: state.previous, updating: true, stale: false } : { kind: 'loading' };
  return state.previous ? { kind: 'ok', data: state.previous, updating: false, stale: true } : { kind: 'unavailable' };
}

/** The headline of an estimate: label, amount and tone. */
export function headline(data: CalculateSuccess): { label: string; cents: number; tone: 'good' | 'bad' | 'even' } {
  if (data.outcome === 'refund') return { label: 'Estimated refund so far', cents: data.lines.overpayment, tone: 'good' };
  if (data.outcome === 'balance_due') return { label: 'Estimated amount owed so far', cents: data.lines.balance_due, tone: 'bad' };
  return { label: 'Estimated result so far', cents: 0, tone: 'even' };
}

const ROWS: { key: keyof Lines; label: string }[] = [
  { key: 'total_income', label: 'Total income' },
  { key: 'total_deductions', label: 'Deductions' },
  { key: 'taxable_income', label: 'Taxable income' },
  { key: 'total_tax', label: 'Total tax' },
  { key: 'total_payments', label: 'Payments and credits' },
];

const PLACEHOLDER: CalculateRequest = { filing_status: 'Single' } as CalculateRequest;

/**
 * The running estimate for the wizard: POST /calculate on the current draft, debounced (700 ms), with
 * the last good answer kept while a new one is on its way. A calculator error is toasted once.
 */
export function useEstimate(opts: { client?: ClientOptions; debounceMs?: number } = {}): Estimate {
  const { request } = useDraft();
  const { state } = useLiveCalculation(request ?? PLACEHOLDER, { enabled: request !== null, debounceMs: opts.debounceMs ?? 700, client: opts.client });
  const toasted = useRef(false);
  const offline = state.status === 'error' && state.error.type === 'network';
  useEffect(() => {
    if (offline && !toasted.current) {
      toasted.current = true;
      toast.error('The calculator can’t be reached', { description: 'Your answers are saved. The estimate will update when it is back.' });
    }
  }, [offline]);
  return toEstimate(request, state);
}

function Amount({ e, size }: { e: Estimate; size: 'lg' | 'sm' }) {
  if (e.kind === 'loading') return <Skeleton className={size === 'lg' ? 'h-9 w-36' : 'h-6 w-24'} />;
  if (e.kind !== 'ok') return <span className="text-muted-foreground">—</span>;
  const h = headline(e.data);
  return (
    <span
      className={cn(
        'font-semibold tracking-tight tabular-nums transition-opacity',
        size === 'lg' ? 'text-[2rem] leading-none' : 'text-lg leading-none',
        h.tone === 'good' && 'text-success',
        h.tone === 'bad' && 'text-destructive',
        (e.updating || e.stale) && 'opacity-60',
      )}
    >
      {formatCents(h.cents, { showCents: false })}
    </span>
  );
}

function label(e: Estimate) {
  return e.kind === 'ok' ? headline(e.data).label : 'Estimated refund so far';
}

/** The body shared by the desktop card and the phone sheet. */
function SummaryBody({ e }: { e: Estimate }) {
  if (e.kind === 'empty') {
    return (
      <p className="m-0 flex gap-2 text-sm text-muted-foreground">
        <Info aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
        Choose a filing status and your estimate appears here, updating as you answer.
      </p>
    );
  }
  if (e.kind === 'needs-income') {
    return (
      <p className="m-0 flex gap-2 text-sm text-muted-foreground">
        <Info aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
        Your estimate appears once you add income or tax you paid (step 4, Income).
      </p>
    );
  }
  if (e.kind === 'knockout') {
    return (
      <p className="m-0 flex gap-2 text-sm">
        <CircleAlert aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-warning" />
        Something in your answers needs a form we can’t calculate yet. The results page will say what.
      </p>
    );
  }
  if (e.kind === 'unavailable') {
    return (
      <p className="m-0 flex gap-2 text-sm text-muted-foreground">
        <CircleAlert aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
        No estimate yet. Finish the fields on this step and it will update.
      </p>
    );
  }
  return (
    <dl className="m-0 grid gap-2.5 text-sm">
      {ROWS.map((r) => (
        <div key={r.key} className="flex items-baseline justify-between gap-3">
          <dt className="text-muted-foreground">{r.label}</dt>
          <dd className="m-0 font-medium tabular-nums">
            {e.kind === 'loading' ? <Skeleton className="h-4 w-16" /> : formatCents(e.data.lines[r.key] ?? 0, { showCents: false })}
          </dd>
        </div>
      ))}
    </dl>
  );
}

function Status({ e }: { e: Estimate }) {
  if (e.kind === 'ok' && e.updating) return <Badge variant="secondary">Updating…</Badge>;
  if (e.kind === 'ok' && e.stale) return <Badge variant="warning">Paused</Badge>;
  if (e.kind === 'ok') return <Badge variant="success">Live</Badge>;
  return null;
}

/** Desktop: a sticky card beside the step. */
export function LiveSummaryCard({ e }: { e: Estimate }) {
  return (
    <section aria-labelledby="estimate-h" className="overflow-hidden rounded-xl border bg-card shadow-sm" data-testid="live-summary">
      <div className="grid gap-3 border-b bg-muted/60 px-5 py-4">
        <div className="flex items-center justify-between gap-2">
          <h2 id="estimate-h" className="m-0 text-xs font-semibold tracking-wide text-muted-foreground uppercase">
            {label(e)}
          </h2>
          <Status e={e} />
        </div>
        <div aria-live="polite" aria-atomic="true">
          <Amount e={e} size="lg" />
        </div>
      </div>
      <div className="grid gap-4 px-5 py-4">
        <SummaryBody e={e} />
        <p className="m-0 flex gap-1.5 border-t pt-3 text-xs leading-snug text-muted-foreground">
          <ShieldCheck aria-hidden="true" className="mt-px size-3.5 shrink-0 text-success" />
          Computed by the same verified calculator as your final result, from your answers so far.
        </p>
      </div>
    </section>
  );
}

/** Phones and tablets: a bar pinned to the bottom of the screen; "Details" opens the full card. */
export function LiveSummaryBar({ e }: { e: Estimate }) {
  if (e.kind === 'empty') return null;
  return (
    <div className="fixed inset-x-0 bottom-0 z-40 border-t bg-background/95 shadow-[0_-4px_16px_rgb(15_23_42/0.06)] backdrop-blur supports-[backdrop-filter]:bg-background/80 xl:hidden" data-testid="live-summary-bar">
      <div className="mx-auto flex max-w-3xl items-center justify-between gap-3 px-4 py-2.5 sm:px-6">
        <div className="grid min-w-0 gap-1">
          <span className="truncate text-xs text-muted-foreground">
            {e.kind === 'knockout' ? 'Estimate unavailable' : e.kind === 'needs-income' ? 'Add income to see your estimate' : label(e)}
          </span>
          <Amount e={e} size="sm" />
        </div>
        <Sheet>
          <SheetTrigger asChild>
            <Button variant="outline" size="sm" className="shrink-0">
              Details
              <ChevronUp aria-hidden="true" />
            </Button>
          </SheetTrigger>
          <SheetContent side="bottom" aria-describedby="estimate-sheet-desc">
            <div className="grid gap-1 border-b px-5 py-4 pr-12">
              <SheetTitle className="text-base">{label(e)}</SheetTitle>
              <SheetDescription id="estimate-sheet-desc">From your answers so far. It updates as you type.</SheetDescription>
            </div>
            <div className="grid gap-4 overflow-y-auto px-5 py-5 pb-8">
              <Amount e={e} size="lg" />
              <SummaryBody e={e} />
            </div>
          </SheetContent>
        </Sheet>
      </div>
    </div>
  );
}
