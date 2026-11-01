import { ArrowRight, Check, Minus } from 'lucide-react';
import { Link } from 'react-router';
import { ButtonLink } from '../components';
import { Badge } from '../components/ui/badge';
import { DotGlobe } from '../components/brand/DotGlobe';
import { TAGLINE } from '../layout/AppShell';
import { AS_OF, SCOPE_INCLUDED, SCOPE_NOT_INCLUDED, STATUS_CLAIMS, type ClaimStatus } from '../trust/facts';

export function StatusBadge({ status }: { status: ClaimStatus }) {
  return status === 'proven' ? <Badge variant="success">Proven</Badge> : <Badge variant="secondary">Tested</Badge>;
}

/** Welcome: what this is, what is verified, one way in. */
export function HomePage() {
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
        <div className="max-w-xl [text-shadow:0_0_5px_var(--background),0_0_12px_var(--background),0_0_22px_var(--background)]">
          <p className="m-0 text-sm font-medium text-muted-foreground">Tax year 2024 · Federal income tax</p>
          <h1 className="mt-3 mb-0 text-4xl leading-[1.1] font-semibold tracking-tight sm:text-5xl">{TAGLINE}</h1>
          {/* translucent card: keeps the body text and buttons readable over the globe while it still shows through */}
          <div className="mt-6 rounded-xl border border-white/60 bg-white/20 p-5 shadow-lg ring-1 ring-black/5 backdrop-blur-[3px] [text-shadow:none] sm:p-6 dark:border-white/10 dark:bg-slate-900/40 dark:ring-white/5">
            <p className="m-0 text-lg leading-relaxed font-medium text-foreground/85">
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
              <ButtonLink size="lg" variant="secondary" to="/docs">
                Go to docs
              </ButtonLink>
            </div>
            <p className="mt-4 mb-0 text-sm font-medium text-foreground/75">
              Five short steps. Answers are saved in this browser only. Nothing is filed.
            </p>
          </div>
        </div>

        <section aria-labelledby="status-h" className="rounded-lg border bg-card">
          <div className="flex items-baseline justify-between gap-4 border-b px-5 py-4">
            <h2 id="status-h" className="m-0 text-base font-semibold">
              Verification status
            </h2>
            <span className="text-xs text-muted-foreground">As of {AS_OF}</span>
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
            <Link to="/trust">Theorems, tests, trusted base and bugs found</Link>
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
              {SCOPE_INCLUDED.map((s) => (
                <li key={s} className="flex gap-2.5">
                  <Check aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-success" />
                  {s}
                </li>
              ))}
            </ul>
          </div>
          <div>
            <h3 className="m-0 text-sm font-semibold">Not included</h3>
            <ul className="mt-3 mb-0 grid list-none gap-2 p-0 text-sm text-muted-foreground">
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
      </section>
      </div>
    </div>
  );
}
