import { Check } from 'lucide-react';
import { Link } from 'react-router';
import { Progress } from './ui/progress';
import { cn } from '@/lib/utils';

export interface StepperStep {
  id: string;
  label: string;
  /** One line under the label (desktop list only). */
  blurb?: string;
}

export type StepState = 'complete' | 'current' | 'upcoming';

/** The state of step `i` when the person is on step `current`. */
export const stepState = (i: number, current: number): StepState => (i < current ? 'complete' : i === current ? 'current' : 'upcoming');

export interface StepperProps {
  steps: readonly StepperStep[];
  /** Index of the current step. */
  current: number;
  /** When given, every step except the current one links here, so people can jump to any step in any order. */
  hrefFor?: (id: string) => string;
}

/**
 * Wizard progress. Wide screens: a vertical list joined by a rail, each step marked complete (tick), current
 * (ring) or upcoming (number); every step but the current one is a link. Narrow screens: "Step 2 of 7", the step name, and a
 * progress bar. One DOM, switched with CSS.
 */
export function Stepper({ steps, current, hrefFor }: StepperProps) {
  const pct = Math.round(((current + 1) / steps.length) * 100);
  return (
    <nav aria-label="Progress" className="grid gap-3">
      <div className="grid gap-2 lg:hidden">
        <div className="flex items-baseline justify-between gap-3 text-sm">
          <p className="m-0 text-muted-foreground">
            Step {current + 1} of {steps.length}: <strong className="font-semibold text-foreground">{steps[current]?.label}</strong>
          </p>
          <span className="text-xs text-muted-foreground tabular-nums">{pct}%</span>
        </div>
        <Progress value={current + 1} max={steps.length} aria-label="Progress through your return" />
      </div>
      <ol className="m-0 hidden list-none p-0 lg:grid">
        {steps.map((s, i) => {
          const state = stepState(i, current);
          const last = i === steps.length - 1;
          const marker = (
            <span
              aria-hidden="true"
              className={cn(
                'relative z-10 grid size-7 shrink-0 place-items-center rounded-full border-2 bg-background text-xs font-semibold tabular-nums transition-colors',
                state === 'complete' && 'border-primary bg-primary text-primary-foreground',
                state === 'current' && 'border-primary text-primary shadow-[0_0_0_4px_color-mix(in_oklab,var(--primary)_18%,transparent)]',
                state === 'upcoming' && 'border-border text-muted-foreground',
              )}
            >
              {state === 'complete' ? <Check className="size-3.5" strokeWidth={3} /> : i + 1}
            </span>
          );
          const text = (
            <span className="grid min-w-0 gap-0.5 pt-1">
              <span className={cn('stepper-label text-sm leading-tight', state === 'current' ? 'font-semibold text-foreground' : state === 'complete' ? 'font-medium text-foreground' : 'text-muted-foreground')}>
                {s.label}
              </span>
              {state === 'current' && s.blurb && <span className="text-xs leading-snug text-muted-foreground">{s.blurb}</span>}
            </span>
          );
          return (
            <li key={s.id} aria-current={state === 'current' ? 'step' : undefined} data-state={state} className="relative flex gap-3 pb-5 last:pb-0">
              {!last && (
                <span
                  aria-hidden="true"
                  className={cn('absolute top-8 bottom-1 left-[13px] w-0.5 rounded-full', state === 'complete' ? 'bg-primary' : 'bg-border')}
                />
              )}
              {state !== 'current' && hrefFor ? (
                <Link
                  to={hrefFor(s.id)}
                  className="-m-1 flex min-w-0 gap-3 rounded-md p-1 no-underline hover:bg-accent [&:hover_.stepper-label]:underline"
                >
                  {marker}
                  {text}
                  {state === 'complete' && <span className="sr-only"> (completed)</span>}
                </Link>
              ) : (
                <>
                  {marker}
                  {text}
                </>
              )}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}

/** Just the bar, for places that don't need the step list. */
export function ProgressBar({ value, max, label }: { value: number; max: number; label: string }) {
  return <Progress value={value} max={max} aria-label={label} />;
}
