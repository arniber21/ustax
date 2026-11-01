import { useId, type ReactNode } from 'react';
import { Plus, Trash2 } from 'lucide-react';
import { Button, Select } from '../components';
import { Checkbox } from '../components/ui/checkbox';
import { RadioGroup, RadioGroupItem } from '../components/ui/radio-group';
import type { Role } from '../draft';
import { useStepError } from './stepErrors';
import { cn } from '@/lib/utils';

/** Step title block: "Step n of 7", the h1, a short plain intro. */
export function StepHeader({ eyebrow, title, intro }: { eyebrow: string; title: string; intro?: ReactNode }) {
  return (
    <header className="mb-8">
      <p className="m-0 mb-2 hidden text-sm font-medium text-muted-foreground lg:block">{eyebrow}</p>
      <h1 className="m-0 text-3xl leading-tight font-semibold tracking-tight">{title}</h1>
      {intro && <p className="mt-3 mb-0 max-w-2xl text-base leading-relaxed text-muted-foreground">{intro}</p>}
    </header>
  );
}

/** A group of related questions inside a step: a heading, an optional note, then fields. */
export function FormSection({ title, note, children, ...rest }: { title: string; note?: ReactNode; children: ReactNode; 'aria-label'?: string }) {
  return (
    <section className="border-t py-8 first-of-type:border-t-0 first-of-type:pt-0" {...rest}>
      <h2 className="m-0 text-lg font-semibold">{title}</h2>
      {note && <p className="mt-1 mb-0 text-sm text-muted-foreground">{note}</p>}
      <div className="mt-5 grid gap-6">{children}</div>
    </section>
  );
}

/** Where a number is printed on the form. Shown inline as muted help text, never hidden behind a tooltip. */
export function Where({ children }: { children: ReactNode }) {
  return <span className="where">Where to find it: {children}</span>;
}

function Legend({ children }: { children: ReactNode }) {
  return <legend className="mb-1 p-0 text-[0.9375rem] font-semibold">{children}</legend>;
}

function Hint({ children }: { children: ReactNode }) {
  return <p className="m-0 mb-3 max-w-prose text-sm text-muted-foreground">{children}</p>;
}

function ErrorText({ children }: { children: ReactNode }) {
  return (
    <p className="field-error m-0 mb-2 text-sm font-semibold text-destructive" role="alert" data-error>
      {children}
    </p>
  );
}

interface YesNoProps {
  legend: string;
  hint?: ReactNode;
  value: boolean;
  onChange: (v: boolean) => void;
}

/** A yes/no question (shadcn/ui RadioGroup, arrow keys move between the two). */
export function YesNo({ legend, hint, value, onChange }: YesNoProps) {
  const id = useId();
  return (
    <fieldset className="m-0 min-w-0 border-0 p-0">
      <Legend>{legend}</Legend>
      {hint ? <Hint>{hint}</Hint> : <div className="h-2" />}
      <RadioGroup
        className="flex gap-3"
        value={value ? 'yes' : 'no'}
        onValueChange={(v) => onChange(v === 'yes')}
      >
        {(['yes', 'no'] as const).map((v) => (
          <div
            key={v}
            className="relative flex min-w-24 items-center gap-2.5 rounded-md border border-input/50 px-4 py-2.5 has-[[data-state=checked]]:border-primary has-[[data-state=checked]]:bg-info-soft"
          >
            <RadioGroupItem value={v} id={`${id}-${v}`} />
            <label htmlFor={`${id}-${v}`} className="cursor-pointer text-sm font-medium after:absolute after:inset-0">
              {v === 'yes' ? 'Yes' : 'No'}
            </label>
          </div>
        ))}
      </RadioGroup>
    </fieldset>
  );
}

interface CheckProps {
  label: ReactNode;
  hint?: ReactNode;
  checked: boolean;
  onChange: (v: boolean) => void;
}

/** A checkbox with its label and optional muted help (shadcn/ui Checkbox). */
export function Check({ label, hint, checked, onChange }: CheckProps) {
  const id = useId();
  return (
    <div className="flex items-start gap-3">
      <Checkbox
        id={id}
        className="mt-0.5"
        checked={checked}
        onCheckedChange={(c) => onChange(c === true)}
        aria-describedby={hint ? `${id}-hint` : undefined}
      />
      <div className="grid gap-0.5">
        <label htmlFor={id} className="cursor-pointer text-[0.9375rem] leading-snug font-medium">
          {label}
        </label>
        {hint && (
          <span id={`${id}-hint`} className="text-sm text-muted-foreground">
            {hint}
          </span>
        )}
      </div>
    </div>
  );
}

export interface CardOption<V extends string> {
  value: V;
  label: string;
  desc: ReactNode;
}

/** Pick-one list where each option explains itself: radio tiles with a description. */
export function ChoiceCards<V extends string>({
  legend,
  value,
  options,
  onChange,
  errorPath,
}: {
  legend: string;
  value: V | null;
  options: readonly CardOption<V>[];
  onChange: (v: V) => void;
  errorPath?: string;
}) {
  const id = useId();
  const error = useStepError(errorPath);
  return (
    <fieldset
      className={cn('m-0 min-w-0 border-0 p-0', error && 'border-l-4 border-solid border-destructive pl-3')}
      data-path={errorPath}
      data-invalid={error ? true : undefined}
    >
      <Legend>{legend}</Legend>
      <div className="h-2" />
      {error && <ErrorText>{error}</ErrorText>}
      <RadioGroup value={value ?? ''} onValueChange={(v) => onChange(v as V)} className="gap-2">
        {options.map((o) => (
          <div
            key={o.value}
            className="relative flex items-start gap-3 rounded-md border border-input/40 px-4 py-3.5 transition-colors hover:border-input has-[[data-state=checked]]:border-primary has-[[data-state=checked]]:bg-info-soft"
          >
            <RadioGroupItem value={o.value} id={`${id}-${o.value}`} className="mt-0.5" aria-invalid={error ? true : undefined} />
            <label htmlFor={`${id}-${o.value}`} className="grid cursor-pointer gap-0.5 after:absolute after:inset-0">
              <span className="text-[0.9375rem] font-semibold">{o.label}</span>
              <span className="text-sm text-muted-foreground">{o.desc}</span>
            </label>
          </div>
        ))}
      </RadioGroup>
    </fieldset>
  );
}

/** Whose form is it? Only joint returns have two people. */
export function WhoSelect({ value, onChange }: { value: Role; onChange: (r: Role) => void }) {
  return (
    <Select
      label="Whose form is this?"
      value={value}
      options={[
        { value: 'PrimaryFiler', label: 'Mine' },
        { value: 'SecondaryFiler', label: 'My spouse’s' },
      ]}
      onChange={onChange}
    />
  );
}

interface RepeaterProps<T extends { id: string }> {
  /** Singular noun for buttons and headings, like "W-2". */
  noun: string;
  items: readonly T[];
  max: number;
  onAdd: () => void;
  onRemove: (id: string) => void;
  render: (item: T, index: number) => ReactNode;
  empty: ReactNode;
  errorPath?: string;
  /** Button text when the list is empty / not empty. Default: "Add a {noun}" / "Add another {noun}". */
  addLabel?: string;
  addAnotherLabel?: string;
}

/** A list of repeatable forms with add and remove. */
export function Repeater<T extends { id: string }>({ noun, items, max, onAdd, onRemove, render, empty, errorPath, addLabel, addAnotherLabel }: RepeaterProps<T>) {
  const error = useStepError(errorPath);
  return (
    <div className="grid gap-4" data-path={errorPath} data-invalid={error ? true : undefined}>
      {items.length === 0 && <p className="m-0 text-sm text-muted-foreground">{empty}</p>}
      {items.map((item, i) => (
        <section key={item.id} className="rounded-lg border bg-card" aria-label={`${noun} ${i + 1}`}>
          <div className="flex items-center justify-between gap-3 border-b bg-muted px-4 py-2.5 sm:px-5">
            <h3 className="m-0 text-sm font-semibold">
              {noun} #{i + 1}
            </h3>
            <Button variant="ghost" aria-label={`Remove ${noun} ${i + 1}`} onClick={() => onRemove(item.id)} className="h-8 px-2 text-muted-foreground">
              <Trash2 aria-hidden="true" />
              Remove
            </Button>
          </div>
          <div className="grid gap-6 px-4 py-5 sm:px-5">{render(item, i)}</div>
        </section>
      ))}
      {error && <ErrorText>{error}</ErrorText>}
      <div>
        <Button variant="secondary" disabled={items.length >= max} onClick={onAdd}>
          <Plus aria-hidden="true" />
          {items.length === 0 ? (addLabel ?? `Add a ${noun}`) : (addAnotherLabel ?? `Add another ${noun}`)}
        </Button>
      </div>
    </div>
  );
}

/** Optional extra fields, collapsed by default (native <details>, keyboard accessible). */
export function More({ summary, children }: { summary: string; children: ReactNode }) {
  return (
    <details className="group rounded-md border">
      <summary className="cursor-pointer list-none px-4 py-3 text-sm font-medium text-primary marker:hidden hover:underline [&::-webkit-details-marker]:hidden">
        <span aria-hidden="true" className="mr-2 inline-block transition-transform group-open:rotate-90">
          ›
        </span>
        {summary}
      </summary>
      <div className="grid gap-6 border-t px-4 py-5">{children}</div>
    </details>
  );
}
