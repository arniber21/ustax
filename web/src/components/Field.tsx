import { useId, type ReactNode } from 'react';
import { Label } from './ui/label';

/** Props to spread on the control so label, hint and error are wired up for assistive tech. */
export interface FieldControlProps {
  id: string;
  'aria-describedby'?: string;
  'aria-invalid'?: true;
}

export interface FieldProps {
  label: string;
  /** Muted help under the label, e.g. where to find the number on the form. Always visible. */
  hint?: ReactNode;
  /** When set, the field is invalid and the message is announced. */
  error?: string;
  /** Draft path of the value (e.g. `w2.abc.wages`); lets the wizard's error summary jump here. */
  path?: string;
  children: (control: FieldControlProps) => ReactNode;
}

/** Label + hint + error around any control. Render-prop so the control gets the right ids. */
export function Field({ label, hint, error, path, children }: FieldProps) {
  const id = useId();
  const hintId = `${id}-hint`;
  const errId = `${id}-err`;
  const describedBy = [hint ? hintId : null, error ? errId : null].filter(Boolean).join(' ');
  return (
    <div
      className={`grid gap-1.5 ${error ? 'border-l-4 border-destructive pl-3' : ''}`}
      data-path={path}
      data-invalid={error ? true : undefined}
    >
      <Label htmlFor={id} className="text-[0.9375rem] font-semibold">
        {label}
      </Label>
      {hint && (
        <p className="m-0 max-w-prose text-sm text-muted-foreground" id={hintId}>
          {hint}
        </p>
      )}
      {error && (
        <p className="field-error m-0 text-sm font-semibold text-destructive" id={errId} role="alert">
          {error}
        </p>
      )}
      {children({
        id,
        ...(describedBy ? { 'aria-describedby': describedBy } : {}),
        ...(error ? { 'aria-invalid': true as const } : {}),
      })}
    </div>
  );
}
