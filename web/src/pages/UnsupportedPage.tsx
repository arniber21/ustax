import { ButtonLink, Callout, Card } from '../components';
import type { ReasonCategory, UnsupportedReason } from '../api';
import { EXAMPLES } from '../examples';
import { useCalculation } from '../useCalculation';

/** Plain-language names for the API's reason categories. Final copy is reviewed in #80. */
export const CATEGORY_TITLES: Record<ReasonCategory, string> = {
  credits: 'Tax credits',
  estimated_payments: 'Estimated tax payments',
  filers: 'Who is filing',
  health_coverage: 'Health coverage',
  household: 'Your household',
  hsa: 'Health savings accounts',
  income: 'Types of income',
  interest: 'Interest and investments',
  process: 'How you file',
  retirement: 'Retirement accounts',
  social_security: 'Social Security',
  state: 'State taxes',
  unemployment: 'Unemployment',
  w2: 'Your W-2',
};

/** Things we do handle, so nobody leaves wondering. */
const SUPPORTED = [
  'Jobs paid on a W-2',
  'Bank interest (1099-INT)',
  'The standard deduction',
  'Single, married, head of household and more',
  'The child tax credit',
];

/** The friendly "not yet" screen: why, what to do instead, and what we can do. */
export function UnsupportedView({ reasons }: { reasons: readonly UnsupportedReason[] }) {
  return (
    <div className="container narrow">
      <p className="eyebrow">Not yet</p>
      <h1>This one’s beyond what we can do right now.</h1>
      <p className="lead">
        Your situation includes something Sumsure doesn’t handle yet. We’d rather tell you now than guess and give you a
        wrong number.
      </p>

      <Card>
        <h2>What we spotted</h2>
        <ul className="reasons">
          {reasons.map((r) => (
            <li key={r.code}>
              <span className="reasons__cat">{CATEGORY_TITLES[r.category] ?? 'Something else'}</span>
              <span>{r.message}</span>
            </li>
          ))}
        </ul>
      </Card>

      <Callout tone="info" title="What to do instead">
        You can file with the IRS Direct File service or other tax software, or on paper with Form 1040. Nothing you
        entered here has been sent anywhere.
      </Callout>

      <Card>
        <h2>What we can do</h2>
        <ul className="ticks">
          {SUPPORTED.map((s) => (
            <li key={s}>{s}</li>
          ))}
        </ul>
      </Card>

      <div className="row">
        <ButtonLink variant="secondary" to="/start/about">
          ← Change my answers
        </ButtonLink>
        <ButtonLink variant="ghost" to="/">
          Home
        </ButtonLink>
      </div>
    </div>
  );
}

/** Route: until the wizard feeds real answers, shows the bond-interest knockout example. */
export function UnsupportedPage() {
  const calc = useCalculation(EXAMPLES.bonds);
  if (calc.status === 'done' && calc.result.kind === 'knockout') return <UnsupportedView reasons={calc.result.data.reasons} />;
  if (calc.status === 'loading') return <p role="status" className="container">Checking…</p>;
  return (
    <div className="container narrow">
      <Callout tone="warn" title="Nothing to show">
        We have no unsupported situation to explain right now.
      </Callout>
    </div>
  );
}
