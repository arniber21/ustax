import { useState } from 'react';
import { Link } from 'react-router';
import { Badge, Button, ButtonLink, Callout, Card, Stat, StatGroup, Tooltip } from '../components';
import { EXAMPLES } from '../examples';
import { useCalculation } from '../useCalculation';
import { ResultsHero } from './ResultsHero';

type Which = 'refund' | 'owe';

/**
 * Results layout (#79 fills in the line-by-line view). For now it runs the canned
 * $50,000 single example through the typed client; in mock mode that is the fixture.
 */
export function ResultsPage() {
  const [which, setWhich] = useState<Which>('refund');
  const calc = useCalculation(EXAMPLES[which]);
  const shown = calc.status === 'done' ? calc.result : calc.previous;

  return (
    <div className="container results">
      <div className="results__top">
        <Badge tone="sun">Example: single, $50,000 salary</Badge>
        <div className="seg" role="group" aria-label="Try an example">
          <Button variant={which === 'refund' ? 'primary' : 'secondary'} aria-pressed={which === 'refund'} onClick={() => setWhich('refund')}>
            $5,000 withheld
          </Button>
          <Button variant={which === 'owe' ? 'primary' : 'secondary'} aria-pressed={which === 'owe'} onClick={() => setWhich('owe')}>
            $3,000 withheld
          </Button>
        </div>
      </div>

      {shown === null && (
        <p role="status" className="results__loading">
          Crunching the numbers…
        </p>
      )}

      {shown?.kind === 'ok' && (
        <>
          <ResultsHero outcome={shown.data.outcome} lines={shown.data.lines} stale={calc.status === 'loading'} />

          <Card>
            <h2>How we got there</h2>
            <StatGroup>
              <Stat label="Money you earned" cents={shown.data.lines.total_income} />
              <Stat
                label={<Tooltip content="A flat amount the IRS lets you subtract before taxing you. Everyone gets one.">Standard deduction</Tooltip>}
                cents={shown.data.lines.standard_or_itemized_deductions}
              />
              <Stat
                label={<Tooltip content="What’s left after the deduction. This is the amount that actually gets taxed.">Taxable income</Tooltip>}
                cents={shown.data.lines.taxable_income}
              />
              <Stat label="Tax on that" cents={shown.data.lines.total_tax} />
              <Stat label="Already paid in" cents={shown.data.lines.total_payments} note="Withheld from your paychecks" />
            </StatGroup>
            <p className="muted">Line-by-line view of your Form 1040, with “show me why” on every number, comes next (#79).</p>
          </Card>

          <Callout tone="good" title="Every number here is computed, not guessed">
            The math behind this page is written as code and checked by a proof assistant.{' '}
            <Link to="/trust">See how we know it’s right.</Link>
          </Callout>
        </>
      )}

      {shown?.kind === 'knockout' && (
        <Callout tone="warn" title="We can’t do this one yet">
          <ButtonLink to="/cant-do-yet" variant="secondary">
            See why
          </ButtonLink>
        </Callout>
      )}

      {shown?.kind === 'error' && (
        <Callout tone="warn" title="Something went wrong on our end">
          We couldn’t work out your result just now. Your answers are safe. Please try again in a moment.
        </Callout>
      )}
    </div>
  );
}
