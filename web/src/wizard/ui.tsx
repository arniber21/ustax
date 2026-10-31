import { useId, type ReactNode } from 'react';
import { Button, Select, Tooltip } from '../components';
import type { Role } from '../draft';
import { useStepError } from './stepErrors';

/** Friendly page opening: small label, big question, short reassurance. */
export function StepHeader({ eyebrow, title, intro }: { eyebrow: string; title: string; intro?: ReactNode }) {
  return (
    <header className="step-head">
      <p className="eyebrow">{eyebrow}</p>
      <h1>{title}</h1>
      {intro && <p className="lead">{intro}</p>}
    </header>
  );
}

/** "Where do I find this?" in one tap. */
export function Where({ children }: { children: ReactNode }) {
  return (
    <span className="where">
      <Tooltip content={children}>Where do I find this?</Tooltip>
    </span>
  );
}

interface YesNoProps {
  legend: string;
  hint?: ReactNode;
  value: boolean;
  onChange: (v: boolean) => void;
}

/** A two-way question that reads like a sentence: big tappable Yes / No. */
export function YesNo({ legend, hint, value, onChange }: YesNoProps) {
  const name = useId();
  return (
    <fieldset className="ask">
      <legend className="ask__legend">{legend}</legend>
      {hint && <p className="field__hint">{hint}</p>}
      <div className="chips">
        {[true, false].map((v) => (
          <label key={String(v)} className="chip">
            <input type="radio" name={name} checked={value === v} onChange={() => onChange(v)} />
            <span>{v ? 'Yes' : 'No'}</span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}

interface CheckProps {
  label: ReactNode;
  hint?: ReactNode;
  checked: boolean;
  onChange: (v: boolean) => void;
}

export function Check({ label, hint, checked, onChange }: CheckProps) {
  return (
    <label className="check">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      <span>
        <span className="check__label">{label}</span>
        {hint && <span className="check__hint">{hint}</span>}
      </span>
    </label>
  );
}

export interface CardOption<V extends string> {
  value: V;
  label: string;
  desc: ReactNode;
}

/** Pick-one list where each option explains itself. */
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
  const name = useId();
  const error = useStepError(errorPath);
  return (
    <fieldset className="ask">
      <legend className="ask__legend">{legend}</legend>
      <div className="choices">
        {options.map((o) => (
          <label key={o.value} className={`choice${value === o.value ? ' is-picked' : ''}`}>
            <input type="radio" name={name} checked={value === o.value} onChange={() => onChange(o.value)} />
            <span className="choice__label">{o.label}</span>
            <span className="choice__desc">{o.desc}</span>
          </label>
        ))}
      </div>
      {error && (
        <p className="field__error" role="alert" data-error>
          {error}
        </p>
      )}
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
}

/** A list of repeatable forms with add and remove. */
export function Repeater<T extends { id: string }>({ noun, items, max, onAdd, onRemove, render, empty, errorPath }: RepeaterProps<T>) {
  const error = useStepError(errorPath);
  return (
    <div className="repeater">
      {items.length === 0 && <p className="muted repeater__empty">{empty}</p>}
      {items.map((item, i) => (
        <section key={item.id} className="doc" aria-label={`${noun} ${i + 1}`}>
          <div className="doc__head">
            <h3>
              {noun} #{i + 1}
            </h3>
            <Button variant="ghost" aria-label={`Remove ${noun} ${i + 1}`} onClick={() => onRemove(item.id)}>
              Remove
            </Button>
          </div>
          {render(item, i)}
        </section>
      ))}
      {error && (
        <p className="field__error" role="alert" data-error>
          {error}
        </p>
      )}
      <Button variant="secondary" disabled={items.length >= max} onClick={onAdd}>
        {items.length === 0 ? `Add a ${noun}` : `Add another ${noun}`}
      </Button>
    </div>
  );
}
