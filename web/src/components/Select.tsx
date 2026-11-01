import type { ReactNode } from 'react';
import { ChevronDown } from 'lucide-react';
import { Field } from './Field';
import { cn } from '@/lib/utils';

export interface SelectOption<V extends string> {
  value: V;
  label: string;
}

export interface SelectProps<V extends string> {
  label: string;
  hint?: ReactNode;
  error?: string;
  value: V | '';
  options: readonly SelectOption<V>[];
  onChange: (value: V) => void;
  /** Shown as a disabled first option while nothing is chosen. */
  placeholder?: string;
  /** Draft path, for the wizard's error summary. */
  path?: string;
  className?: string;
}

/**
 * A native select styled like shadcn/ui's NativeSelect: best on phones and free keyboard support.
 */
export function Select<V extends string>({
  label,
  hint,
  error,
  value,
  options,
  onChange,
  placeholder = 'Choose one',
  path,
  className,
}: SelectProps<V>) {
  return (
    <Field label={label} hint={hint} error={error} path={path}>
      {(control) => (
        <div className={cn('relative w-full max-w-sm', className)}>
          <select
            {...control}
            className="h-10 w-full cursor-pointer appearance-none rounded-md border border-input bg-background py-2 pr-9 pl-3 text-base text-foreground focus-visible:border-ring focus-visible:outline-2 focus-visible:outline-offset-0 focus-visible:outline-ring aria-invalid:border-destructive"
            value={value}
            onChange={(e) => onChange(e.target.value as V)}
          >
            {value === '' && (
              <option value="" disabled>
                {placeholder}
              </option>
            )}
            {options.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
          <ChevronDown
            aria-hidden="true"
            className="pointer-events-none absolute top-1/2 right-3 size-4 -translate-y-1/2 text-muted-foreground"
          />
        </div>
      )}
    </Field>
  );
}
