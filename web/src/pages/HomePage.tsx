import { ArrowRight, Check, Minus } from 'lucide-react';
import { Link } from 'react-router';
import { ButtonLink } from '../components';
import { Badge } from '../components/ui/badge';
import { TAGLINE } from '../layout/AppShell';
import { STATUS_CLAIMS, type ClaimStatus } from '../trust/claims';

export function StatusBadge({ status }: { status: ClaimStatus }) {
  return status === 'proven' ? <Badge variant="success">Proven</Badge> : <Badge variant="secondary">Tested</Badge>;
}

const INCLUDED = [
  'W-2 wages and federal tax withheld',
  'Bank interest (Form 1099-INT)',
  'Standard deduction, including age 65+, blindness and dependent rules',
  'All five filing statuses',
];

const NOT_YET = [
  'Unemployment, retirement and Social Security income (accepted, not yet counted)',
  'Dependents and the credits that depend on them',
  'Itemized deductions, self-employment, investments, state tax',
];

/** Welcome: what this is, what is verified, one way in. */
export function HomePage() {
  return (
    <div className="mx-auto max-w-6xl px-4 sm:px-6">
      <section className="grid items-start gap-10 py-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,28rem)] lg:gap-16 lg:py-20">
        <div className="max-w-xl">
          <p className="m-0 text-sm font-medium text-muted-foreground">Tax year 2024 · Federal income tax</p>
          <h1 className="mt-3 mb-0 text-4xl leading-[1.1] font-semibold tracking-tight sm:text-5xl">{TAGLINE}</h1>
          <p className="mt-6 mb-0 text-lg leading-relaxed text-muted-foreground">
            Calculates your 2024 federal income tax. The arithmetic is checked by a machine-verified proof; here is exactly
            what is and is not covered.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <ButtonLink size="lg" to="/start/about">
              Start your return
              <ArrowRight aria-hidden="true" />
            </ButtonLink>
            <ButtonLink size="lg" variant="secondary" to="/trust">
              What is verified
            </ButtonLink>
          </div>
          <p className="mt-4 mb-0 text-sm text-muted-foreground">
            Five short steps. Answers are saved in this browser only. Nothing is filed.
          </p>
        </div>

        <section aria-labelledby="status-h" className="rounded-lg border bg-card">
          <div className="flex items-baseline justify-between gap-4 border-b px-5 py-4">
            <h2 id="status-h" className="m-0 text-base font-semibold">
              Verification status
            </h2>
            <span className="text-xs text-muted-foreground">Lean 4 proofs and tests</span>
          </div>
          <ul className="m-0 list-none divide-y p-0">
            {STATUS_CLAIMS.map((c) => (
              <li key={c.title} className="grid gap-1.5 px-5 py-4">
                <div className="flex items-start justify-between gap-3">
                  <span className="text-sm font-semibold leading-snug">{c.title}</span>
                  <StatusBadge status={c.status} />
                </div>
                <p className="m-0 text-sm text-muted-foreground">{c.detail}</p>
              </li>
            ))}
          </ul>
          <div className="border-t px-5 py-3 text-sm">
            <Link to="/trust">Theorems, tests and trusted base</Link>
          </div>
        </section>
      </section>

      <section aria-labelledby="scope-h" className="border-t py-12">
        <h2 id="scope-h" className="m-0 text-xl font-semibold tracking-tight">
          What it calculates today
        </h2>
        <div className="mt-6 grid gap-8 md:grid-cols-2">
          <div>
            <h3 className="m-0 text-sm font-semibold">Included in the result</h3>
            <ul className="mt-3 mb-0 grid list-none gap-2 p-0 text-sm">
              {INCLUDED.map((s) => (
                <li key={s} className="flex gap-2.5">
                  <Check aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-success" />
                  {s}
                </li>
              ))}
            </ul>
          </div>
          <div>
            <h3 className="m-0 text-sm font-semibold">Not yet included</h3>
            <ul className="mt-3 mb-0 grid list-none gap-2 p-0 text-sm text-muted-foreground">
              {NOT_YET.map((s) => (
                <li key={s} className="flex gap-2.5">
                  <Minus aria-hidden="true" className="mt-0.5 size-4 shrink-0" />
                  {s}
                </li>
              ))}
            </ul>
            <p className="mt-4 mb-0 text-sm text-muted-foreground">
              If your return needs something unsupported, US Tax tells you which part and stops, rather than guessing.
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}
