import * as React from 'react';
import { CalendarIcon } from 'lucide-react';
import { cn } from '@/lib/utils';
import { fromLocalDate, parseIso, parseUs, toIso, toLocalDate, toLong, toUs } from '@/lib/isoDate';
import { Button } from './button';
// react-day-picker loads with the first opened calendar; typing a date needs none of it.
const Calendar = React.lazy(() => import('./calendar').then((m) => ({ default: m.Calendar })));
import { Input } from './input';
import { Popover, PopoverAnchor, PopoverContent, PopoverTrigger } from './popover';

export interface DatePickerProps {
  /** `YYYY-MM-DD`, or `''` for no date. Text that is not a valid in-range date is kept as typed. */
  value: string;
  onChange: (iso: string) => void;
  /** Earliest / latest allowed date, `YYYY-MM-DD`. */
  min?: string;
  max?: string;
  id?: string;
  'aria-describedby'?: string;
  'aria-invalid'?: boolean;
  /** Name for the calendar button, e.g. `Choose date of birth`. */
  calendarLabel?: string;
  placeholder?: string;
  className?: string;
}

const inRange = (iso: string, min?: string, max?: string) => (!min || iso >= min) && (!max || iso <= max);

/**
 * shadcn/ui Date Picker ("Input with calendar"): type `MM/DD/YYYY` or open the calendar. The calendar
 * has month and year dropdowns, so a birth date does not take dozens of clicks. The value is always
 * `YYYY-MM-DD`, built from calendar components (never through a UTC `Date`).
 */
export function DatePicker({
  value,
  onChange,
  min = '1900-01-01',
  max,
  id,
  calendarLabel = 'Choose date',
  placeholder = 'MM/DD/YYYY',
  className,
  'aria-invalid': ariaInvalid,
  'aria-describedby': describedBy,
}: DatePickerProps) {
  const [open, setOpen] = React.useState(false);
  const [touched, setTouched] = React.useState(false);
  const errId = React.useId();
  const parts = parseIso(value);
  const [text, setText] = React.useState(parts ? toUs(parts) : value);
  // Follow outside changes (restored draft, reset), but not the echo of our own onChange.
  const lastEmitted = React.useRef(value);
  if (value !== lastEmitted.current) {
    lastEmitted.current = value;
    setText(parts ? toUs(parts) : value);
  }

  const emit = (v: string) => {
    lastEmitted.current = v;
    onChange(v);
  };
  const minParts = parseIso(min);
  const maxParts = max ? parseIso(max) : null;
  const typed = parseUs(text) ?? parseIso(text.trim());
  const problem =
    text.trim() === ''
      ? null
      : !typed
        ? 'Enter the date as MM/DD/YYYY, for example 04/12/1986.'
        : !inRange(toIso(typed), min, max)
          ? `Enter a date ${minParts ? `from ${toUs(minParts)} ` : ''}${maxParts ? `to ${toUs(maxParts)}` : ''}.`.replace(' .', '.')
          : null;
  const shownProblem = touched && !ariaInvalid ? problem : null;

  const onType = (t: string) => {
    setText(t);
    const p = parseUs(t) ?? parseIso(t.trim());
    if (t.trim() === '') emit('');
    else if (p && inRange(toIso(p), min, max)) emit(toIso(p));
    else emit(t.trim());
  };

  const selected = parts ? toLocalDate(parts) : undefined;
  const invalid = ariaInvalid || shownProblem !== null;

  return (
    <div className={cn('grid gap-1.5', className)}>
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverAnchor asChild>
          <div className="relative flex max-w-48 items-center">
            <Input
              id={id}
              value={text}
              inputMode="numeric"
              autoComplete="off"
              placeholder={placeholder}
              aria-invalid={invalid || undefined}
              aria-describedby={[describedBy, shownProblem ? errId : null].filter(Boolean).join(' ') || undefined}
              className="pr-10"
              onChange={(e) => onType(e.target.value)}
              onBlur={() => setTouched(true)}
              onKeyDown={(e) => {
                if (e.key === 'ArrowDown' && e.altKey) {
                  e.preventDefault();
                  setOpen(true);
                }
              }}
            />
            <PopoverTrigger asChild>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                className="absolute right-1 size-8"
                aria-label={parts ? `${calendarLabel}, selected ${toLong(parts)}` : calendarLabel}
              >
                <CalendarIcon aria-hidden />
              </Button>
            </PopoverTrigger>
          </div>
        </PopoverAnchor>
        <PopoverContent>
          <React.Suspense fallback={<div className="grid h-72 w-64 place-items-center text-sm text-muted-foreground">Loading calendar…</div>}>
          <Calendar
            mode="single"
            captionLayout="dropdown"
            startMonth={minParts ? toLocalDate(minParts) : new Date(1900, 0, 1)}
            endMonth={maxParts ? toLocalDate(maxParts) : new Date(new Date().getFullYear() + 1, 11, 31)}
            defaultMonth={selected ?? (maxParts ? toLocalDate(maxParts) : undefined)}
            selected={selected}
            disabled={[...(minParts ? [{ before: toLocalDate(minParts) }] : []), ...(maxParts ? [{ after: toLocalDate(maxParts) }] : [])]}
            onSelect={(dt) => {
              if (!dt) return;
              const ymd = fromLocalDate(dt);
              setText(toUs(ymd));
              emit(toIso(ymd));
              setOpen(false);
            }}
            autoFocus
          />
          </React.Suspense>
        </PopoverContent>
      </Popover>
      <p className="m-0 text-sm text-muted-foreground empty:hidden" aria-live="polite">
        {parts ? toLong(parts) : null}
      </p>
      {shownProblem && (
        <p id={errId} role="alert" className="m-0 text-sm font-semibold text-destructive">
          {shownProblem}
        </p>
      )}
    </div>
  );
}
