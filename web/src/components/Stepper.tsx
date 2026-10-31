export interface StepperStep {
  id: string;
  label: string;
}

export interface StepperProps {
  steps: readonly StepperStep[];
  /** Index of the current step. */
  current: number;
}

/** "Step 2 of 5" progress: a labelled list plus a filling bar. Completed steps get a check. */
export function Stepper({ steps, current }: StepperProps) {
  const pct = Math.round(((current + 1) / steps.length) * 100);
  return (
    <nav aria-label="Progress" className="stepper">
      <p className="stepper__summary">
        Step {current + 1} of {steps.length}: <strong>{steps[current]?.label}</strong>
      </p>
      <div
        className="progress"
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={steps.length}
        aria-valuenow={current + 1}
        aria-label="Progress through your return"
      >
        <div className="progress__fill" style={{ width: `${pct}%` }} />
      </div>
      <ol className="stepper__list">
        {steps.map((s, i) => (
          <li
            key={s.id}
            className={`stepper__item${i < current ? ' is-done' : ''}${i === current ? ' is-current' : ''}`}
            aria-current={i === current ? 'step' : undefined}
          >
            <span className="stepper__dot" aria-hidden="true">
              {i < current ? '✓' : i + 1}
            </span>
            <span className="stepper__label">{s.label}</span>
          </li>
        ))}
      </ol>
    </nav>
  );
}

/** Just the bar, for places that don't need the step list. */
export function ProgressBar({ value, max, label }: { value: number; max: number; label: string }) {
  return (
    <div className="progress" role="progressbar" aria-valuemin={0} aria-valuemax={max} aria-valuenow={value} aria-label={label}>
      <div className="progress__fill" style={{ width: `${Math.round((value / max) * 100)}%` }} />
    </div>
  );
}
