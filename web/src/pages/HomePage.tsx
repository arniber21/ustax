import { ArrowRight, Check, ClipboardList, Cpu, Minus, Scale } from 'lucide-react';
import { Link } from 'react-router';
import { ButtonLink } from '../components/Button';
import { useDraft } from '../draft';
import { TAGLINE } from '../layout/AppShell';
import { WIZARD_STEPS } from '../layout/steps';
import { TierBadge } from '../trust/TierBadge';
import { AS_OF, CATALA, EXTRA, MAIN, SCOPE_INCLUDED, SCOPE_NOT_INCLUDED, TESTED, type ClaimStatus } from '../trust/facts';

/** Kept for callers that show one claim's status. */
export function StatusBadge({ status }: { status: ClaimStatus }) {
  return <TierBadge status={status} />;
}

const HOW = [
  {
    icon: ClipboardList,
    title: 'Answer plain questions',
    text: `${WIZARD_STEPS.length} short steps, with your running estimate beside you. Answers stay in this browser.`,
  },
  {
    icon: Cpu,
    title: 'A verified calculator does the math',
    text: `Lean code with ${MAIN.theorems.length + EXTRA.theorems.length} machine-checked theorems, tested against the IRS’s own Direct File engine.`,
  },
  {
    icon: Scale,
    title: 'Every line shows its law and proof',
    text: 'Open any Form 1040 line to see the statute, the Catala rule that encodes it, and what is proved about it.',
  },
];

/** Welcome: what this is, what is verified, one way in. */
export function HomePage() {
  const { draft } = useDraft();
  const hasReturn = draft.filingStatus !== null;
  const proved = MAIN.theorems.length + EXTRA.theorems.length;
  const assurances: { title: string; status: ClaimStatus; detail: string }[] = [
    { title: `${proved} properties proved in Lean`, status: 'proven', detail: 'Tax tables, refund consistency, credit bounds and more. Every theorem has an explicit scope.' },
    { title: `${TESTED.calculator.scenarios} IRS returns compared`, status: 'tested', detail: `${TESTED.calculator.factChecks.toLocaleString('en-US')} output checks against IRS Direct File. Testing is evidence, not a proof.` },
  ];
  return (
    <div className="relative overflow-x-clip">
      <div className="relative mx-auto max-w-6xl px-4 sm:px-6">
        <section className="relative z-10 grid items-start gap-10 py-14 lg:grid-cols-[minmax(0,1fr)_minmax(0,25rem)] lg:gap-20 lg:py-24">
          <div className="max-w-[38rem]">
            <p className="m-0 inline-flex items-center gap-2 text-xs font-medium tracking-wide text-muted-foreground">
              <span className="size-1.5 rounded-full bg-success" aria-hidden="true" />
              Tax year 2024 · Federal income tax
            </p>
            <h1 className="mt-5 mb-0 text-4xl leading-[1.08] font-semibold tracking-tight sm:text-[3.25rem]">{TAGLINE}</h1>
            <div className="mt-6">
              <p className="m-0 max-w-lg text-lg leading-relaxed text-muted-foreground">
                Work through your 2024 federal return, then follow every line back to the law,
                the calculation, and the properties proved in Lean.
              </p>
              <div className="mt-6 flex flex-wrap gap-3">
                <ButtonLink size="lg" to="/start/about">
                  {hasReturn ? 'Continue your return' : 'Start your return'}
                  <ArrowRight aria-hidden="true" />
                </ButtonLink>
                <ButtonLink size="lg" variant="ghost" to="/docs/verification">
                  What is verified <ArrowRight aria-hidden="true" className="size-4" />
                </ButtonLink>
              </div>
              <p className="mt-4 mb-0 text-xs text-muted-foreground">
                {hasReturn ? 'Your answers are saved in this browser. ' : `${WIZARD_STEPS.length} short steps. Answers are saved in this browser only. `}
                Nothing is filed.
              </p>
              <dl className="mt-9 grid max-w-md grid-cols-3 gap-4 border-t pt-5">
                {[
                  { v: String(proved), l: 'theorems proved' },
                  { v: TESTED.calculator.scenarios.toString(), l: 'IRS scenarios agree' },
                  { v: TESTED.calculator.factChecks.toLocaleString('en-US'), l: 'fact checks' },
                ].map((s) => (
                  <div key={s.l} className="grid content-start gap-1">
                    <dt className="order-2 text-xs text-muted-foreground">{s.l}</dt>
                    <dd className="order-1 m-0 text-lg font-semibold tracking-tight tabular-nums">{s.v}</dd>
                  </div>
                ))}
              </dl>
            </div>
          </div>

          <section aria-labelledby="status-h" className="overflow-hidden rounded-xl border bg-card">
            <div className="flex items-baseline justify-between gap-4 border-b px-5 py-4">
              <h2 id="status-h" className="m-0 text-base font-semibold">
                Verification status
              </h2>
              <span className="text-xs text-muted-foreground">As of {AS_OF}</span>
            </div>
            <ul className="m-0 list-none divide-y p-0">
              {assurances.map((c) => (
                <li key={c.title} className="grid gap-1.5 px-5 py-4">
                  <div className="flex items-start justify-between gap-3">
                    <span className="text-sm leading-snug font-semibold">{c.title}</span>
                    <StatusBadge status={c.status} />
                  </div>
                  <p className="m-0 text-sm text-muted-foreground">{c.detail}</p>
                </li>
              ))}
            </ul>
            <div className="grid gap-3 border-t px-5 py-4">
              <p className="m-0 text-xs leading-relaxed text-muted-foreground">Proofs have limits. We document what is proved, tested and still trusted.</p>
              <Link to="/docs/verification" className="inline-flex items-center gap-2 text-sm font-medium no-underline">
                Explore verification <ArrowRight aria-hidden="true" className="size-3.5" />
              </Link>
            </div>
          </section>
        </section>

        <section aria-labelledby="how-h" className="relative z-10 border-t py-12">
          <h2 id="how-h" className="m-0 text-xl font-semibold tracking-tight">
            How it works
          </h2>
          <ol className="mt-6 grid list-none gap-4 p-0 md:grid-cols-3">
            {HOW.map((h, i) => (
              <li key={h.title} className="grid content-start gap-3 border-t pt-5">
                <div className="flex items-center gap-3">
                  <span aria-hidden="true" className="grid size-8 place-items-center text-muted-foreground">
                    <h.icon className="size-4.5" />
                  </span>
                  <span className="text-xs font-semibold text-muted-foreground tabular-nums">Step {i + 1}</span>
                </div>
                <h3 className="m-0 text-base font-semibold">{h.title}</h3>
                <p className="m-0 text-sm leading-relaxed text-muted-foreground">{h.text}</p>
              </li>
            ))}
          </ol>
        </section>

        <section aria-labelledby="scope-h" className="relative z-10 border-t py-12">
          <h2 id="scope-h" className="m-0 text-xl font-semibold tracking-tight">
            What it calculates today
          </h2>
          <div className="mt-6 grid gap-4 md:grid-cols-2">
            <div className="border-t pt-5">
              <h3 className="m-0 text-sm font-semibold">Included in the result</h3>
              <ul className="mt-3 mb-0 grid list-none gap-2.5 p-0 text-sm">
                {SCOPE_INCLUDED.map((s) => (
                  <li key={s} className="flex gap-2.5">
                    <Check aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-success" />
                    {s}
                  </li>
                ))}
              </ul>
            </div>
            <div className="border-t pt-5">
              <h3 className="m-0 text-sm font-semibold">Not included</h3>
              <ul className="mt-3 mb-0 grid list-none gap-2.5 p-0 text-sm text-muted-foreground">
                {SCOPE_NOT_INCLUDED.map((s) => (
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
          <p className="mt-6 mb-0 text-xs text-muted-foreground">
            {CATALA.moduleFiles} Catala rule files, {CATALA.testFiles} Catala test files, {CATALA.mappings} differential-test mappings.
          </p>
        </section>
      </div>
    </div>
  );
}
