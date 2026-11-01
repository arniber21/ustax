import type { ReactNode } from 'react';
import { Link } from 'react-router';
import { formatCents } from '../api';
import { Button, Callout, Card } from '../components';
import { isJoint, useDraft, validateDraft, type Cents, type Draft } from '../draft';
import { WIZARD_STEPS, stepPath, type WizardStepId } from '../layout/steps';
import { FILING_STATUS_OPTIONS } from './AboutStep';
import { StepHeader } from './ui';

const money = (c: Cents) => (c === null ? '$0' : formatCents(c, { showCents: c % 100 !== 0 }));
const stepLabel = (id: WizardStepId) => WIZARD_STEPS.find((s) => s.id === id)?.label ?? id;

function Row({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="sum__row">
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  );
}

function Block({ title, step, children }: { title: string; step: WizardStepId; children: ReactNode }) {
  return (
    <Card as="section" aria-label={title}>
      <div className="doc__head">
        <h2>{title}</h2>
        <Link to={stepPath(step)} className="edit-link" aria-label={`Edit ${title}`}>
          Edit
        </Link>
      </div>
      {children}
    </Card>
  );
}

function flagList(f: { age65: boolean; blind: boolean; canBeClaimed: boolean }): string {
  const out = [f.age65 && '65 or older', f.blind && 'blind', f.canBeClaimed && 'can be claimed as a dependent'].filter(Boolean);
  return out.length ? out.join(', ') : 'None of these';
}

function Empty() {
  return <p className="muted">Nothing added.</p>;
}

/** Step 5: everything we heard, in plain words, with a way back to fix any of it. */
export function ReviewStep() {
  const { draft: d, reset } = useDraft();
  const problems = validateDraft(d);
  const bad = (Object.keys(problems) as WizardStepId[]).filter((k) => Object.keys(problems[k]).length > 0);
  const status = FILING_STATUS_OPTIONS.find((o) => o.value === d.filingStatus);

  return (
    <>
      <StepHeader
        eyebrow="Step 5 of 5"
        title="Ready? Here’s what you told us."
        intro="Give it a quick once-over. Tap Edit on anything that looks off."
      />

      {bad.length > 0 && (
        <Callout tone="warn" title="A few things need your attention first">
          <ul>
            {bad.map((k) => (
              <li key={k}>
                <Link to={stepPath(k)}>{stepLabel(k)}</Link>: {Object.keys(problems[k]).length === 1 ? 'one answer is' : 'some answers are'} missing or
                look off.
              </li>
            ))}
          </ul>
        </Callout>
      )}

      <Block title="About you" step="about">
        <dl className="sum">
          <Row label="Filing status" value={status?.label ?? 'Not chosen yet'} />
          <Row label="You" value={flagList(d.primary)} />
          {isJoint(d) && <Row label="Your spouse" value={flagList(d.spouse)} />}
        </dl>
      </Block>

      <Block title="Household" step="household">
        <dl className="sum">
          <Row label="Dependents" value={d.hasDependents ? 'Yes (not included in the math yet)' : 'None'} />
          <Row label="Accounts outside the U.S." value={d.foreignAccounts ? 'Yes' : 'No'} />
        </dl>
      </Block>

      <Block title="Income" step="income">
        <IncomeSummary d={d} />
      </Block>

      <Block title="Adjustments & credits" step="adjustments">
        <dl className="sum">
          <Row label="Teacher expenses" value={d.educator.primary || (isJoint(d) && d.educator.spouse) ? money((d.educator.primary ? (d.educator.primaryExpenses ?? 0) : 0) + (isJoint(d) && d.educator.spouse ? (d.educator.spouseExpenses ?? 0) : 0)) : 'None'} />
          <Row label="Student loan interest" value={d.studentLoan.hadPayments ? money(d.studentLoan.interest) : 'None'} />
          <Row label="Tax you paid on your own" value={d.estimated.paid ? money(d.estimated.amount) : 'None'} />
        </dl>
      </Block>

      <p className="muted small">
        Your answers stay on this device until you clear them.{' '}
        <Button variant="ghost" onClick={reset}>
          Start over
        </Button>
      </p>
    </>
  );
}

function IncomeSummary({ d }: { d: Draft }) {
  const none = d.w2s.length + d.interest.length + d.unemployment.length + d.retirement.length + d.ssa.length === 0;
  if (none) return <Empty />;
  return (
    <dl className="sum">
      {d.w2s.map((w, i) => (
        <Row key={w.id} label={`W-2 #${i + 1}`} value={`${money(w.wages)} wages, ${money(w.withholding)} withheld`} />
      ))}
      {d.interest.map((x, i) => (
        <Row key={x.id} label={`1099-INT #${i + 1}`} value={`${money(x.interest)} interest`} />
      ))}
      {d.unemployment.map((x, i) => (
        <Row key={x.id} label={`1099-G #${i + 1}`} value={`${money(x.amount)} unemployment`} />
      ))}
      {d.retirement.map((x, i) => (
        <Row key={x.id} label={`1099-R #${i + 1}`} value={`${money(x.gross)} taken out, ${x.taxableBlank ? 'taxable part blank' : `${money(x.taxable)} taxable`}`} />
      ))}
      {d.ssa.map((x, i) => (
        <Row key={x.id} label={`SSA-1099 #${i + 1}`} value={`${money(x.netBenefits)} net benefits`} />
      ))}
    </dl>
  );
}
