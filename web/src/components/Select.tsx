import type { ReactNode } from 'react';
import { Field } from './Field';

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
}

/** A native select (best on phones, free keyboard support) in the house style. */
export function Select<V extends string>({
  label,
  hint,
  error,
  value,
  options,
  onChange,
  placeholder = 'Choose one',
}: SelectProps<V>) {
  return (
    <Field label={label} hint={hint} error={error}>
      {(control) => (
        <div className="select">
          <select {...control} className="input" value={value} onChange={(e) => onChange(e.target.value as V)}>
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
        </div>
      )}
    </Field>
  );
}
