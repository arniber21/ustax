import { lazy, Suspense, useState, type ReactNode } from 'react';
import { ChevronDown, ChevronsUpDown } from 'lucide-react';
import { Field } from './Field';
import { Button } from './ui/button';
import { Popover, PopoverContent, PopoverTrigger } from './ui/popover';
import { Select as UiSelect, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { cn } from '@/lib/utils';

// cmdk loads with the first opened combobox, not with the app.
const ComboboxList = lazy(() => import('./ComboboxList'));

export interface SelectOption<V extends string> {
  value: V;
  label: string;
  /** Second line in rich pickers (ChoiceSelect, Combobox). */
  desc?: string;
}

export interface SelectProps<V extends string> {
  label: string;
  hint?: ReactNode;
  error?: string;
  value: V | '';
  options: readonly SelectOption<V>[];
  onChange: (value: V) => void;
  /** Shown while nothing is chosen. */
  placeholder?: string;
  /** Draft path, for the wizard's error summary and the step form. */
  path?: string;
  className?: string;
}

/**
 * A native select styled like shadcn/ui's NativeSelect. Used for long lists (relationships) and
 * where the phone's own picker is the better tool; keyboard support is free.
 */
export function Select<V extends string>({ label, hint, error, value, options, onChange, placeholder = 'Choose one', path, className }: SelectProps<V>) {
  return (
    <Field label={label} hint={hint} error={error} path={path}>
      {(control) => (
        <div className={cn('relative w-full max-w-sm', className)}>
          <select
            {...control}
            className="h-10 w-full cursor-pointer appearance-none rounded-md border border-input bg-background py-2 pr-9 pl-3 text-base text-foreground shadow-xs transition-colors hover:border-foreground/50 focus-visible:border-ring focus-visible:outline-2 focus-visible:outline-offset-0 focus-visible:outline-ring aria-invalid:border-destructive sm:text-[0.9375rem]"
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
          <ChevronDown aria-hidden="true" className="pointer-events-none absolute top-1/2 right-3 size-4 -translate-y-1/2 text-muted-foreground" />
        </div>
      )}
    </Field>
  );
}

/**
 * shadcn/ui Select (Radix): a listbox with optional descriptions per option. Keyboard: Space/Enter or
 * arrows open it, type-ahead jumps, Escape closes. For short lists whose options need explaining.
 */
export function ChoiceSelect<V extends string>({ label, hint, error, value, options, onChange, placeholder = 'Choose one', path, className }: SelectProps<V>) {
  const current = options.find((o) => o.value === value);
  return (
    <Field label={label} hint={hint} error={error} path={path}>
      {(control) => (
        <UiSelect value={value || undefined} onValueChange={(v) => onChange(v as V)}>
          <SelectTrigger
            {...control}
            className={cn(
              'h-10 w-full max-w-sm bg-background text-[0.9375rem] text-foreground shadow-xs hover:border-foreground/50 focus-visible:outline-2 focus-visible:outline-offset-0 focus-visible:outline-ring focus-visible:ring-0 data-[size=default]:h-10',
              className,
            )}
          >
            <SelectValue placeholder={placeholder}>{current?.label}</SelectValue>
          </SelectTrigger>
          <SelectContent position="popper" className="max-w-[min(28rem,calc(100vw-2rem))]">
            {options.map((o) => (
              <SelectItem key={o.value} value={o.value} className="py-2">
                <span className="grid gap-0.5">
                  <span className="font-medium">{o.label}</span>
                  {o.desc && <span className="text-xs whitespace-normal text-muted-foreground">{o.desc}</span>}
                </span>
              </SelectItem>
            ))}
          </SelectContent>
        </UiSelect>
      )}
    </Field>
  );
}

/**
 * shadcn/ui Combobox (Popover + Command): a searchable picker for long coded lists, e.g. W-2 box 12
 * letters, where people know either the letter or what it means. Type to filter, arrows to move,
 * Enter to choose.
 */
export function Combobox<V extends string>({
  label,
  hint,
  error,
  value,
  options,
  onChange,
  placeholder = 'Choose one',
  path,
  className,
  searchPlaceholder = 'Search…',
  renderValue,
}: SelectProps<V> & { searchPlaceholder?: string; renderValue?: (o: SelectOption<V>) => ReactNode }) {
  const [open, setOpen] = useState(false);
  const current = options.find((o) => o.value === value);
  return (
    <Field label={label} hint={hint} error={error} path={path}>
      {(control) => (
        <Popover open={open} onOpenChange={setOpen}>
          <PopoverTrigger asChild>
            <Button
              {...control}
              type="button"
              variant="outline"
              role="combobox"
              aria-expanded={open}
              className={cn(
                'h-10 w-full max-w-sm justify-between border-input bg-background px-3 text-left font-normal shadow-xs hover:bg-background hover:border-foreground/50 aria-invalid:border-destructive',
                className,
              )}
            >
              <span className={cn('truncate', !current && 'text-muted-foreground')}>
                {current ? (renderValue ? renderValue(current) : current.label) : placeholder}
              </span>
              <ChevronsUpDown aria-hidden="true" className="text-muted-foreground" />
            </Button>
          </PopoverTrigger>
          <PopoverContent className="w-[min(24rem,calc(100vw-2rem))] p-0" align="start">
            <Suspense fallback={<p className="m-0 p-3 text-sm text-muted-foreground">Loading…</p>}>
              <ComboboxList
                label={label}
                value={value}
                options={options}
                searchPlaceholder={searchPlaceholder}
                onPick={(v) => {
                  onChange(v as V);
                  setOpen(false);
                }}
              />
            </Suspense>
          </PopoverContent>
        </Popover>
      )}
    </Field>
  );
}
