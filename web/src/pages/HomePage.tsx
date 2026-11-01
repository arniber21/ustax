import { ArrowRight, Check, ClipboardList, Cpu, Minus, Scale } from 'lucide-react';
import { Link } from 'react-router';
import { ButtonLink } from '../components/Button';
import { DotGlobe } from '../components/brand/DotGlobe';
import { useDraft } from '../draft';
import { TAGLINE } from '../layout/AppShell';
import { WIZARD_STEPS } from '../layout/steps';
import { TierBadge, TierLegend } from '../trust/TierBadge';
import { AS_OF, CATALA, EXTRA, MAIN, SCOPE_INCLUDED, SCOPE_NOT_INCLUDED, STATUS_CLAIMS, TESTED, type ClaimStatus } from '../trust/facts';

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
  const { request } = useDraft();
  const proved = MAIN.theorems.length + EXTRA.theorems.length;
  return (
    <div className="relative overflow-x-clip">
      <div className="relative mx-auto max-w-6xl px-4 sm:px-6">
        {/* Decorative background: a dot-matrix globe wearing the US flag, behind the headline. The header has its own
            stacking level above it, and the globe fades out toward the right so the verification card stays clean. */}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute top-0 -left-40 z-0 w-[560px] opacity-50 sm:-left-48 sm:w-[720px] sm:opacity-60 lg:-left-56 lg:w-[800px] lg:opacity-70"
          style={{
            maskImage: 'linear-gradient(to right, black 55%, transparent 100%)',
            WebkitMaskImage: 'linear-gradient(to right, black 55%, transparent 100%)',
          }}
        >
          <DotGlobe />
        </div>
        <section className="relative z-10 grid items-start gap-10 py-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,28rem)] lg:gap-16 lg:py-20">
          <div className="max-w-[40rem] [text-shadow:0_0_5px_var(--background),0_0_12px_var(--background),0_0_22px_var(--background)] [&_a]:[text-shadow:none]">
            <p className="m-0 inline-flex items-center gap-2 rounded-full border bg-background/80 px-3 py-1 text-xs font-medium text-muted-foreground shadow-xs backdrop-blur [text-shadow:none]">
              <span className="size-1.5 rounded-full bg-success" aria-hidden="true" />
              Tax year 2024 · Federal income tax
            </p>
            <h1 className="mt-5 mb-0 text-4xl leading-[1.08] font-semibold tracking-tight sm:text-[3.25rem]">{TAGLINE}</h1>
            {/* Translucent card: keeps the body text and buttons readable over the globe while it still shows through. */}
            <div className="mt-6 rounded-xl border border-white/60 bg-white/20 p-5 shadow-lg ring-1 ring-black/5 backdrop-blur-[3px] [text-shadow:none] sm:p-6 dark:border-white/10 dark:bg-slate-900/40 dark:ring-white/5">
              <p className="m-0 text-lg leading-relaxed font-medium text-foreground/85">
                Calculates your 2024 federal income tax. The arithmetic is checked by a machine-verified proof; here is exactly
                what is and is not covered.
              </p>
              <div className="mt-6 flex flex-wrap gap-3">
                <ButtonLink size="lg" to={request ? '/start/review' : '/start/about'} className="shadow-sm">
                  {request ? 'Continue your return' : 'Start your return'}
                  <ArrowRight aria-hidden="true" />
                </ButtonLink>
                <ButtonLink size="lg" variant="secondary" to="/trust">
                  What is verified
                </ButtonLink>
                <ButtonLink size="lg" variant="secondary" to="/docs">
                  Go to docs
                </ButtonLink>
              </div>
              <p className="mt-4 mb-0 text-sm font-medium text-foreground/75">
                {request ? 'Your answers are saved in this browser. ' : `${WIZARD_STEPS.length} short steps. Answers are saved in this browser only. `}
                Nothing is filed.
              </p>
              <dl className="mt-6 grid grid-cols-3 gap-px overflow-hidden rounded-lg border bg-border text-center">
                {[
                  { v: String(proved), l: 'theorems proved' },
                  { v: TESTED.calculator.scenarios.toString(), l: 'IRS scenarios agree' },
                  { v: TESTED.calculator.factChecks.toLocaleString('en-US'), l: 'fact checks' },
                ].map((s) => (
                  <div key={s.l} className="grid content-start gap-0.5 bg-background/80 px-3 py-2.5">
                    <dt className="order-2 text-xs text-muted-foreground">{s.l}</dt>
                    <dd className="order-1 m-0 text-lg font-semibold tracking-tight tabular-nums">{s.v}</dd>
                  </div>
                ))}
              </dl>
            </div>
          </div>

          <section aria-labelledby="status-h" className="overflow-hidden rounded-2xl border bg-card shadow-sm">
            <div className="flex items-baseline justify-between gap-4 border-b bg-muted/60 px-5 py-4">
              <h2 id="status-h" className="m-0 text-base font-semibold">
                Verification status
              </h2>
              <span className="text-xs text-muted-foreground">As of {AS_OF}</span>
            </div>
            <ul className="m-0 list-none divide-y p-0">
              {STATUS_CLAIMS.map((c) => (
                <li key={c.title} className="grid gap-1.5 px-5 py-4">
                  <div className="flex items-start justify-between gap-3">
                    <span className="text-sm leading-snug font-semibold">{c.title}</span>
                    <StatusBadge status={c.status} />
                  </div>
                  <p className="m-0 text-sm text-muted-foreground">{c.detail}</p>
                </li>
              ))}
            </ul>
            <div className="grid gap-3 border-t bg-muted/40 px-5 py-4">
              <TierLegend />
              <Link to="/trust" className="text-sm font-medium">
                Theorems, Catala rules, tests, trusted base and bugs found
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
              <li key={h.title} className="grid content-start gap-3 rounded-xl border bg-card p-5 shadow-xs">
                <div className="flex items-center gap-3">
                  <span aria-hidden="true" className="grid size-9 place-items-center rounded-lg bg-primary/10 text-primary">
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
            <div className="rounded-xl border bg-card p-5 shadow-xs">
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
            <div className="rounded-xl border bg-muted/40 p-5">
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
