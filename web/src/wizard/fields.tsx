import type { ReactNode } from 'react';
import { ChoiceSelect, Field, MoneyInput, Select, type MoneyInputProps, type SelectProps } from '../components';
import { DatePicker } from '../components/ui/date-picker';
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

/** `ChoiceSelect` (shadcn/ui Select) that shows the step's validation message for `path`. */
export function ChoiceSelectField<V extends string>({ path, ...rest }: Omit<SelectProps<V>, 'error'> & { path?: string }) {
  const error = useStepError(path);
  return <ChoiceSelect {...rest} path={path} error={error} />;
}

/**
 * A date (`YYYY-MM-DD`) in the shadcn Date Picker: type MM/DD/YYYY or pick from a calendar with
 * month and year dropdowns. Dates cannot be later than the end of the tax year; text that is not a
 * valid date yet stays in the draft as typed, and validation reports it.
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
        <DatePicker
          {...control}
          min="1900-01-01"
          max="2024-12-31"
          calendarLabel={`Choose ${label.toLowerCase()}`}
          value={value}
          onChange={onChange}
        />
      )}
    </Field>
  );
}
