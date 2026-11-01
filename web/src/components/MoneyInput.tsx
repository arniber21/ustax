import { useState, type ReactNode } from 'react';
import { centsToDollarString, parseDollars, type Cents } from '../api/money';
import { Field } from './Field';

export interface MoneyInputProps {
  label: string;
  hint?: ReactNode;
  /** Controlled value in integer cents; null means empty. */
  value: Cents | null;
  onChange: (cents: Cents | null) => void;
  /** Disallow negatives (default true: most tax inputs are never negative). */
  nonNegative?: boolean;
  /** Problem found by step validation (shown when the typed text itself parses fine). */
  error?: string;
}

const show = (c: Cents | null) => (c === null ? '' : centsToDollarString(c));

/**
 * Dollar input that speaks integer cents. The user types "$1,234.5"; the parent only ever sees
 * 123450 or null. Invalid text is never silently rounded: it shows a message and reports null.
 */
export function MoneyInput({ label, hint, value, onChange, nonNegative = true, error: outerError }: MoneyInputProps) {
  const [text, setText] = useState(show(value));
  const [error, setError] = useState<string | undefined>();

  const commit = (raw: string) => {
    if (raw.trim() === '') {
      setError(undefined);
      onChange(null);
      return null;
    }
    const cents = parseDollars(raw);
    if (cents === null) {
      setError('Use numbers only, with at most two decimals, like 1,234.56.');
      onChange(null);
      return null;
    }
    if (nonNegative && cents < 0) {
      setError('This can’t be negative.');
      onChange(null);
      return null;
    }
    setError(undefined);
    onChange(cents);
    return cents;
  };

  return (
    <Field label={label} hint={hint} error={error ?? outerError}>
      {(control) => (
        <div className="money">
          <span className="money__sign" aria-hidden="true">
            $
          </span>
          <input
            {...control}
            className="input money__input num"
            inputMode="decimal"
            autoComplete="off"
            value={text}
            placeholder="0.00"
            onChange={(e) => {
              setText(e.target.value);
              commit(e.target.value);
            }}
            onBlur={() => {
              const c = commit(text);
              if (c !== null) setText(centsToDollarString(c));
            }}
          />
        </div>
      )}
    </Field>
  );
}
