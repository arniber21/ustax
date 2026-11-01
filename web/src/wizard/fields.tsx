import type { ReactNode } from 'react';
import { Field, MoneyInput, Select, type MoneyInputProps, type SelectProps } from '../components';
import { Input } from '../components/ui/input';
import { useStepError } from './stepErrors';

/** `MoneyInput` that shows the step's validation message for `path` once the person tries to continue. */
export function MoneyField({ path, ...rest }: Omit<MoneyInputProps, 'error'> & { path?: string }) {
  const error = useStepError(path);
  return <MoneyInput {...rest} path={path} error={error} />;
}

/** `Select` that shows the step's validation message for `path`. */
export function SelectField<V extends string>({ path, ...rest }: Omit<SelectProps<V>, 'error'> & { path?: string }) {
  const error = useStepError(path);
  return <Select {...rest} path={path} error={error} />;
}

/**
 * A date (`YYYY-MM-DD`) in a native date input: phones get their date picker, keyboards can type it.
 * Dates cannot be later than the end of the tax year; the draft keeps the ISO text as typed.
 */
export function DateField({
  label,
  hint,
  value,
  onChange,
  path,
}: {
  label: string;
  hint?: ReactNode;
  value: string;
  onChange: (iso: string) => void;
  path?: string;
}) {
  const error = useStepError(path);
  return (
    <Field label={label} hint={hint} error={error} path={path}>
      {(control) => (
        <Input
          {...control}
          type="date"
          className="max-w-48"
          min="1900-01-01"
          max="2024-12-31"
          value={value}
          onChange={(e) => onChange(e.target.value)}
        />
      )}
    </Field>
  );
}
