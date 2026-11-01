import { useId, useState, type ReactNode } from 'react';
import { ChevronRight, Plus, Trash2, type LucideIcon } from 'lucide-react';
import { Button } from '../components';
import { FieldMessage } from '../components/Field';
import { Checkbox } from '../components/ui/checkbox';
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '../components/ui/collapsible';
import { Empty, EmptyContent, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle } from '../components/ui/empty';
import { RadioGroup, RadioGroupItem } from '../components/ui/radio-group';
import { Switch } from '../components/ui/switch';
import type { Role } from '../draft';
import { useStepError } from './stepErrors';
import { cn } from '@/lib/utils';

/** Step title block: "Step n of 7", the h1, a short plain intro. */
export function StepHeader({ eyebrow, title, intro }: { eyebrow: string; title: string; intro?: ReactNode }) {
  return (
    <header className="mb-8">
      <p className="m-0 mb-2 hidden text-xs font-semibold tracking-wide text-primary uppercase lg:block">{eyebrow}</p>
      <h1 className="m-0 text-[1.75rem] leading-tight font-semibold tracking-tight sm:text-3xl">{title}</h1>
      {intro && <p className="mt-3 mb-0 max-w-2xl text-base leading-relaxed text-muted-foreground">{intro}</p>}
    </header>
  );
}

/** A group of related questions inside a step: a card with a heading, an optional note, then fields. */
export function FormSection({
  title,
  note,
  icon: Icon,
  children,
  ...rest
}: {
  title: string;
  note?: ReactNode;
  icon?: LucideIcon;
  children: ReactNode;
  'aria-label'?: string;
}) {
  const id = useId();
  return (
    <section
      aria-labelledby={rest['aria-label'] ? undefined : id}
      className="mb-6 rounded-xl border bg-card shadow-xs"
      {...rest}
    >
      <div className="flex items-start gap-3 border-b px-5 py-4 sm:px-6">
        {Icon && (
          <span aria-hidden="true" className="mt-0.5 grid size-8 shrink-0 place-items-center rounded-lg bg-primary/10 text-primary">
            <Icon className="size-4" />
          </span>
        )}
        <div className="grid gap-0.5">
          <h2 id={id} className="m-0 text-base font-semibold tracking-tight">
            {title}
          </h2>
          {note && <p className="m-0 text-sm text-muted-foreground">{note}</p>}
        </div>
      </div>
      <div className="grid gap-7 px-5 py-6 sm:px-6">{children}</div>
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
    <div className="mb-2" data-error>
      <FieldMessage>{children}</FieldMessage>
    </div>
  );
}

interface YesNoProps {
  legend: string;
  hint?: ReactNode;
  value: boolean;
  onChange: (v: boolean) => void;
}

/** A yes/no question: a two-option segmented RadioGroup (arrow keys move between the two). */
export function YesNo({ legend, hint, value, onChange }: YesNoProps) {
  const id = useId();
  return (
    <fieldset className="m-0 min-w-0 border-0 p-0">
      <Legend>{legend}</Legend>
      {hint ? <Hint>{hint}</Hint> : <div className="h-2" />}
      <RadioGroup
        className="inline-grid grid-cols-2 gap-1 rounded-lg border bg-muted p-1"
        value={value ? 'yes' : 'no'}
        onValueChange={(v) => onChange(v === 'yes')}
      >
        {(['yes', 'no'] as const).map((v) => (
          <div
            key={v}
            className="relative flex min-w-24 items-center gap-2.5 rounded-md px-4 py-2 transition-colors hover:bg-background/60 has-[[data-state=checked]]:bg-background has-[[data-state=checked]]:shadow-sm has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-ring"
          >
            <RadioGroupItem value={v} id={`${id}-${v}`} className="focus-visible:outline-none" />
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

/** A checkbox with its label and optional muted help (shadcn/ui Checkbox). The whole row is the hit area. */
export function Check({ label, hint, checked, onChange }: CheckProps) {
  const id = useId();
  return (
    <div className="group/check relative -mx-2 flex items-start gap-3 rounded-lg px-2 py-1.5 transition-colors hover:bg-accent/60">
      <Checkbox
        id={id}
        className="mt-0.5"
        checked={checked}
        onCheckedChange={(c) => onChange(c === true)}
        aria-describedby={hint ? `${id}-hint` : undefined}
      />
      <div className="grid gap-0.5">
        <label htmlFor={id} className="cursor-pointer text-[0.9375rem] leading-snug font-medium after:absolute after:inset-0">
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

/** An on/off setting with a description (shadcn/ui Switch), for choices that read as a setting, not a fact. */
export function Toggle({ label, hint, checked, onChange }: CheckProps) {
  const id = useId();
  return (
    <div className="flex items-start justify-between gap-6 rounded-lg border px-4 py-3">
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
      <Switch id={id} checked={checked} onCheckedChange={onChange} aria-describedby={hint ? `${id}-hint` : undefined} className="mt-0.5" />
    </div>
  );
}

export interface CardOption<V extends string> {
  value: V;
  label: string;
  desc: ReactNode;
}

/** Pick-one list where each option explains itself: radio cards with a description. */
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
    <fieldset className="m-0 min-w-0 border-0 p-0" data-path={errorPath} data-invalid={error ? true : undefined}>
      <Legend>{legend}</Legend>
      <div className="h-2" />
      {error && <ErrorText>{error}</ErrorText>}
      <RadioGroup value={value ?? ''} onValueChange={(v) => onChange(v as V)} className="gap-2.5">
        {options.map((o) => (
          <div
            key={o.value}
            className={cn(
              'relative flex items-start gap-3 rounded-lg border bg-background px-4 py-3.5 transition-[border-color,background-color,box-shadow] hover:border-foreground/30',
              'has-[[data-state=checked]]:border-primary has-[[data-state=checked]]:bg-primary/[0.04] has-[[data-state=checked]]:shadow-[0_0_0_1px_var(--primary)]',
              error && 'border-destructive/60',
            )}
          >
            <RadioGroupItem value={o.value} id={`${id}-${o.value}`} className="mt-0.5" aria-invalid={error ? true : undefined} />
            <label htmlFor={`${id}-${o.value}`} className="grid cursor-pointer gap-0.5 after:absolute after:inset-0">
              <span className="text-[0.9375rem] font-semibold">{o.label}</span>
              <span className="text-sm leading-relaxed text-muted-foreground">{o.desc}</span>
            </label>
          </div>
        ))}
      </RadioGroup>
    </fieldset>
  );
}

/** Whose form is it? Only joint returns have two people. A segmented choice, not a dropdown: there are two answers. */
export function WhoSelect({ value, onChange }: { value: Role; onChange: (r: Role) => void }) {
  const id = useId();
  const options = [
    { value: 'PrimaryFiler', label: 'Mine' },
    { value: 'SecondaryFiler', label: 'My spouse’s' },
  ] as const;
  return (
    <fieldset className="m-0 min-w-0 border-0 p-0">
      <Legend>Whose form is this?</Legend>
      <div className="h-2" />
      <RadioGroup
        className="inline-grid grid-cols-2 gap-1 rounded-lg border bg-muted p-1"
        value={value}
        onValueChange={(v) => onChange(v as Role)}
      >
        {options.map((o) => (
          <div
            key={o.value}
            className="relative flex items-center gap-2.5 rounded-md px-4 py-2 transition-colors hover:bg-background/60 has-[[data-state=checked]]:bg-background has-[[data-state=checked]]:shadow-sm has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-ring"
          >
            <RadioGroupItem value={o.value} id={`${id}-${o.value}`} className="focus-visible:outline-none" />
            <label htmlFor={`${id}-${o.value}`} className="cursor-pointer text-sm font-medium whitespace-nowrap after:absolute after:inset-0">
              {o.label}
            </label>
          </div>
        ))}
      </RadioGroup>
    </fieldset>
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
  /** The empty-state sentence. */
  empty: ReactNode;
  /** Icon for the empty state. */
  emptyIcon?: LucideIcon;
  errorPath?: string;
  /** Button text when the list is empty / not empty. Default: "Add a {noun}" / "Add another {noun}". */
  addLabel?: string;
  addAnotherLabel?: string;
  /** Shown on each card's header next to the title (e.g. the person's name). */
  titleFor?: (item: T, index: number) => ReactNode;
}

/** A list of repeatable forms with add and remove, and a designed empty state. */
export function Repeater<T extends { id: string }>({
  noun,
  items,
  max,
  onAdd,
  onRemove,
  render,
  empty,
  emptyIcon: EmptyIcon,
  errorPath,
  addLabel,
  addAnotherLabel,
  titleFor,
}: RepeaterProps<T>) {
  const error = useStepError(errorPath);
  const addButton = (
    <Button variant={items.length === 0 ? 'primary' : 'secondary'} disabled={items.length >= max} onClick={onAdd}>
      <Plus aria-hidden="true" />
      {items.length === 0 ? (addLabel ?? `Add a ${noun}`) : (addAnotherLabel ?? `Add another ${noun}`)}
    </Button>
  );
  return (
    <div className="grid gap-4" data-path={errorPath} data-invalid={error ? true : undefined}>
      {items.length === 0 && (
        <Empty className="gap-4 border border-dashed bg-muted/50 p-6 md:p-8">
          <EmptyHeader>
            {EmptyIcon && (
              <EmptyMedia variant="icon" className="bg-background text-muted-foreground shadow-xs">
                <EmptyIcon aria-hidden="true" />
              </EmptyMedia>
            )}
            <EmptyTitle className="text-sm font-semibold">No {noun} added</EmptyTitle>
            <EmptyDescription className="text-sm">{empty}</EmptyDescription>
          </EmptyHeader>
          <EmptyContent>{addButton}</EmptyContent>
        </Empty>
      )}
      {items.map((item, i) => (
        <section
          key={item.id}
          className="animate-in rounded-lg border bg-background shadow-xs fade-in-0 slide-in-from-top-1 duration-200"
          aria-label={`${noun} ${i + 1}`}
        >
          <div className="flex items-center justify-between gap-3 rounded-t-lg border-b bg-muted/70 px-4 py-2 sm:px-5">
            <h3 className="m-0 flex items-center gap-2 text-sm font-semibold">
              <span className="grid size-5 place-items-center rounded-full bg-primary/10 text-[0.6875rem] text-primary tabular-nums">{i + 1}</span>
              {titleFor ? titleFor(item, i) : `${noun} #${i + 1}`}
            </h3>
            <Button
              variant="ghost"
              aria-label={`Remove ${noun} ${i + 1}`}
              onClick={() => onRemove(item.id)}
              className="h-8 px-2 text-muted-foreground hover:text-destructive"
            >
              <Trash2 aria-hidden="true" />
              Remove
            </Button>
          </div>
          <div className="grid gap-7 px-4 py-5 sm:px-5">{render(item, i)}</div>
        </section>
      ))}
      {error && <ErrorText>{error}</ErrorText>}
      {items.length > 0 && <div>{addButton}</div>}
    </div>
  );
}

/** Optional extra fields, collapsed by default (shadcn/ui Collapsible, keyboard accessible). */
export function More({ summary, children }: { summary: string; children: ReactNode }) {
  const [open, setOpen] = useState(false);
  return (
    <Collapsible open={open} onOpenChange={setOpen} className="rounded-lg border" data-more>
      <CollapsibleTrigger asChild>
        <button
          type="button"
          className="flex w-full cursor-pointer items-center gap-2 rounded-lg bg-transparent px-4 py-3 text-left text-sm font-medium text-primary hover:bg-accent/60"
        >
          <ChevronRight aria-hidden="true" className={cn('size-4 transition-transform', open && 'rotate-90')} />
          {summary}
        </button>
      </CollapsibleTrigger>
      <CollapsibleContent forceMount hidden={!open} className="grid gap-7 border-t px-4 py-5">
        {children}
      </CollapsibleContent>
    </Collapsible>
  );
}
