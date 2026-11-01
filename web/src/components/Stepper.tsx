import { Check } from 'lucide-react';
import { Link } from 'react-router';
import { Progress } from './ui/progress';
import { cn } from '@/lib/utils';

export interface StepperStep {
  id: string;
  label: string;
}

export interface StepperProps {
  steps: readonly StepperStep[];
  /** Index of the current step. */
  current: number;
  /** When given, every step except the current one links here, so people can jump to any step in any order. */
  hrefFor?: (id: string) => string;
}

/**
 * Step list. On wide screens a vertical list (completed steps ticked, current one marked);
 * on narrow screens "Step 2 of 5" plus a thin progress bar. One DOM, switched with CSS.
 */
export function Stepper({ steps, current, hrefFor }: StepperProps) {
  return (
    <nav aria-label="Progress" className="grid gap-3">
      <p className="m-0 text-sm text-muted-foreground lg:hidden">
        Step {current + 1} of {steps.length}: <strong className="font-semibold text-foreground">{steps[current]?.label}</strong>
      </p>
      <Progress
        className="lg:hidden"
        value={current + 1}
        max={steps.length}
        aria-label="Progress through your return"
      />
      <ol className="m-0 hidden list-none gap-1 border-l p-0 lg:grid">
        {steps.map((s, i) => {
          const done = i < current;
          const here = i === current;
          const label = <span className="stepper-label">{s.label}</span>;
          return (
            <li
              key={s.id}
              aria-current={here ? 'step' : undefined}
              className={cn(
                '-ml-px flex items-center gap-3 border-l-2 border-transparent py-1.5 pl-4 text-sm',
                here && 'border-primary font-semibold text-foreground',
                !here && 'text-muted-foreground',
              )}
            >
              <span
                aria-hidden="true"
                className={cn(
                  'grid size-6 shrink-0 place-items-center rounded-full border text-xs tabular-nums',
                  done && 'border-primary bg-primary text-primary-foreground',
                  here && 'border-primary text-primary',
                  !done && !here && 'border-input/60',
                )}
              >
                {done ? <Check className="size-3.5" strokeWidth={3} /> : i + 1}
              </span>
              {!here && hrefFor ? (
                <Link to={hrefFor(s.id)} className={cn('no-underline hover:underline', done ? 'text-foreground' : 'text-muted-foreground hover:text-foreground')}>
                  {label}
                  {done && <span className="sr-only"> (completed)</span>}
                </Link>
              ) : (
                label
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
