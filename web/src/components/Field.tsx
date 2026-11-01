import { useId, type ReactNode } from 'react';
import { CircleAlert } from 'lucide-react';
import { WithBoundField } from '../forms/DraftForm';
import { Field as UiField, FieldDescription, FieldError, FieldLabel } from './ui/field';
import { cn } from '@/lib/utils';

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
  /** Draft path of the value (e.g. `w2.abc.wages`); lets the wizard's error summary jump here, and binds the field to the step's form. */
  path?: string;
  /** Extra content on the label row, right-aligned (e.g. a definition tooltip). */
  labelAside?: ReactNode;
  className?: string;
  children: (control: FieldControlProps) => ReactNode;
}

/** A field's error line: icon plus text, announced when it appears. */
export function FieldMessage({ id, children }: { id?: string; children: ReactNode }) {
  return (
    <FieldError id={id} className="field-error flex items-start gap-1.5 font-medium">
      <CircleAlert aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
      <span>{children}</span>
    </FieldError>
  );
}

/**
 * Label + description + control + message (shadcn/ui Field). Render-prop so the control gets the right
 * ids. Inside a wizard step the field is also bound to react-hook-form: leaving it marks it touched and
 * the contract schema reports on it inline; a step error (after Next) takes precedence.
 */
export function Field({ label, hint, error, path, labelAside, className, children }: FieldProps) {
  const id = useId();
  const hintId = `${id}-hint`;
  const errId = `${id}-err`;
  return (
    <WithBoundField path={path}>
      {(bound) => {
        const shown = error ?? bound.error;
        const describedBy = [hint ? hintId : null, shown ? errId : null].filter(Boolean).join(' ');
        return (
          <UiField
            role={undefined}
            className={cn('gap-2 data-[invalid=true]:text-foreground', className)}
            data-path={path}
            data-invalid={shown ? true : undefined}
            onBlur={bound.onBlur}
          >
            <div className="flex items-baseline justify-between gap-3">
              <FieldLabel htmlFor={id} className="text-[0.9375rem] font-semibold">
                {label}
              </FieldLabel>
              {labelAside}
            </div>
            {hint && (
              <FieldDescription id={hintId} className="-mt-1 max-w-prose">
                {hint}
              </FieldDescription>
            )}
            {children({
              id,
              ...(describedBy ? { 'aria-describedby': describedBy } : {}),
              ...(shown ? { 'aria-invalid': true as const } : {}),
            })}
            {shown && <FieldMessage id={errId}>{shown}</FieldMessage>}
          </UiField>
        );
      }}
    </WithBoundField>
  );
}
