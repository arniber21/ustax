import { useId, useState } from 'react';
import { formatCents, type FilingStatus, type Lines } from '../api';
import { Button } from '../components';
import { WALK } from './walkData';

/** Expandable, line-by-line walk through the Form 1040, with "how did we get this?" on the key lines. */
export function LineWalk({ lines, filingStatus }: { lines: Lines; filingStatus?: FilingStatus }) {
  const [open, setOpen] = useState(false);
  const panel = useId();
  return (
    <section className="walk card" aria-labelledby={`${panel}-h`}>
      <div className="walk__head">
        <div>
          <h2 id={`${panel}-h`}>Your Form 1040, line by line</h2>
          <p className="muted">Every number on the form, in plain English, in the order the IRS adds them up.</p>
        </div>
        <Button variant="secondary" aria-expanded={open} aria-controls={panel} onClick={() => setOpen((o) => !o)}>
          {open ? 'Hide the walk-through' : 'Walk me through it'}
        </Button>
      </div>
      <div id={panel} hidden={!open}>
        {WALK.map((g) => (
          <section key={g.id} className="walk__group" aria-labelledby={`${panel}-${g.id}`}>
            <h3 id={`${panel}-${g.id}`}>{g.title}</h3>
            <p className="muted walk__blurb">{g.blurb}</p>
            <ul className="walk__rows">
              {g.lines.map((l) => (
                <WalkRow key={l.key} id={`${panel}-${l.key}`} line={l.line} label={l.label} cents={lines[l.key] ?? 0} explain={l.explain?.({ lines, filingStatus })} />
              ))}
            </ul>
          </section>
        ))}
      </div>
    </section>
  );
}

function WalkRow({ id, line, label, cents, explain }: { id: string; line: string; label: string; cents: number; explain?: string }) {
  const [show, setShow] = useState(false);
  return (
    <li className="walk__row">
      <div className="walk__main">
        <span className="walk__line">Line {line}</span>
        <span className="walk__label">{label}</span>
        <span className="walk__amount num">{formatCents(cents)}</span>
      </div>
      {explain && (
        <>
          <button type="button" className="walk__why" aria-expanded={show} aria-controls={id} onClick={() => setShow((s) => !s)}>
            {show ? 'Got it' : 'How did we get this?'}
          </button>
          <p id={id} className="walk__explain" hidden={!show}>
            {explain}
          </p>
        </>
      )}
    </li>
  );
}
