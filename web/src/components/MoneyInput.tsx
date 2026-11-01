import { useLayoutEffect, useRef, useState, type ReactNode } from 'react';
import { centsToDollarString, parseDollars, type Cents } from '../api/money';
import { groupDollarString, regroupTyping } from '@/lib/moneyText';
import { cn } from '@/lib/utils';
import { Field } from './Field';
import { InputGroup, InputGroupAddon, InputGroupInput, InputGroupText } from './ui/input-group';

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
  /** Draft path, for the wizard's error summary and the step form. */
  path?: string;
  /** Right-aligned extra on the label row (e.g. a definition tooltip). */
  labelAside?: ReactNode;
  className?: string;
}

const show = (c: Cents | null) => (c === null ? '' : groupDollarString(centsToDollarString(c)));

/**
 * Dollar input that speaks integer cents (shadcn/ui InputGroup with a `$` prefix and `USD` suffix,
 * right-aligned tabular figures). Thousands separators appear while typing ("1234" shows "1,234")
 * with the caret kept in place; the parent only ever sees 123400 or null. Invalid text is never
 * silently rounded: it shows a message and reports null.
 */
export function MoneyInput({
  label,
  hint,
  value,
  onChange,
  nonNegative = true,
  error: outerError,
  path,
  labelAside,
  className,
}: MoneyInputProps) {
  const [text, setText] = useState(show(value));
  const [error, setError] = useState<string | undefined>();
  const input = useRef<HTMLInputElement>(null);
  const caret = useRef<number | null>(null);
  // Follow outside changes (a reset, a restored draft), but not the echo of our own onChange.
  const lastEmitted = useRef(value);
  if (value !== lastEmitted.current) {
    lastEmitted.current = value;
    setText(show(value));
  }

  useLayoutEffect(() => {
    const el = input.current;
    if (el && caret.current !== null && document.activeElement === el) el.setSelectionRange(caret.current, caret.current);
    caret.current = null;
  });

  const emit = (c: Cents | null) => {
    if (c === lastEmitted.current) return; // unchanged (e.g. reformatting on blur): no draft update, no recalculation
    lastEmitted.current = c;
    onChange(c);
  };

  const commit = (raw: string): Cents | null => {
    // "12." is a number on its way to "12.50": accept it rather than flash an error mid-typing.
    const clean = raw.replace(/\.$/, '');
    if (clean.trim() === '' || clean.trim() === '-') {
      setError(raw.trim() === '' ? undefined : 'Use numbers only, with at most two decimals, like 1,234.56.');
      emit(null);
      return null;
    }
    const cents = parseDollars(clean);
    if (cents === null) {
      setError('Use numbers only, with at most two decimals, like 1,234.56.');
      emit(null);
      return null;
    }
    if (nonNegative && cents < 0) {
      setError('This can’t be negative.');
      emit(null);
      return null;
    }
    setError(undefined);
    emit(cents);
    return cents;
  };

  return (
    <Field label={label} hint={hint} error={error ?? outerError} path={path} labelAside={labelAside} className={className}>
      {(control) => (
        <InputGroup role={undefined} className="w-full max-w-[17rem]">
          <InputGroupAddon aria-hidden="true">
            <InputGroupText className="font-medium text-muted-foreground">$</InputGroupText>
          </InputGroupAddon>
          <InputGroupInput
            {...control}
            ref={input}
            className={cn('text-right font-medium tabular-nums')}
            inputMode="decimal"
            autoComplete="off"
            spellCheck={false}
            value={text}
            placeholder="0.00"
            onChange={(e) => {
              const { text: next, caret: at } = regroupTyping(e.target.value, e.target.selectionStart ?? e.target.value.length);
              caret.current = at;
              setText(next);
              commit(next);
            }}
            onBlur={() => {
              const c = commit(text);
              if (c !== null) setText(show(c));
            }}
          />
          <InputGroupAddon align="inline-end" aria-hidden="true">
            <InputGroupText className="text-xs tracking-wide">USD</InputGroupText>
          </InputGroupAddon>
        </InputGroup>
      )}
    </Field>
  );
}
