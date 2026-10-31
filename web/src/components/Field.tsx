import { useId, type ReactNode } from 'react';

/** Props to spread on the control so label, hint and error are wired up for assistive tech. */
export interface FieldControlProps {
  id: string;
  'aria-describedby'?: string;
  'aria-invalid'?: true;
}

export interface FieldProps {
  label: string;
  /** Friendly one-liner under the label, e.g. where to find the number. */
  hint?: ReactNode;
  /** When set, the field is invalid and the message is announced. */
  error?: string;
  children: (control: FieldControlProps) => ReactNode;
}

/** Label + hint + error around any control. Render-prop so the control gets the right ids. */
export function Field({ label, hint, error, children }: FieldProps) {
  const id = useId();
  const hintId = `${id}-hint`;
  const errId = `${id}-err`;
  const describedBy = [hint ? hintId : null, error ? errId : null].filter(Boolean).join(' ');
  return (
    <div className={`field${error ? ' field--error' : ''}`}>
      <label className="field__label" htmlFor={id}>
        {label}
      </label>
      {hint && (
        <p className="field__hint" id={hintId}>
          {hint}
        </p>
      )}
      {children({
        id,
        ...(describedBy ? { 'aria-describedby': describedBy } : {}),
        ...(error ? { 'aria-invalid': true as const } : {}),
      })}
      {error && (
        <p className="field__error" id={errId} role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
