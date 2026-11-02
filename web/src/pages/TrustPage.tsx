import { ExternalLink, Scale } from 'lucide-react';
import { Page, PageHeader, PageSection } from '../layout/Page';
import { Badge } from '../components/ui/badge';
import { Button } from '../components/ui/button';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/table';
import { githubBlobUrl } from '../docs/config';
import { ProvenanceProvider, useOpenProvenance } from '../provenance';
import { AS_OF, BUGS, CATALA, EXTRA, MAIN, NOT_COVERED, OTHER_PROOFS, PROOF_CHECKS, TESTED, TRUSTED, type ProofSet } from '../trust/facts';
import { TierBadge, TierLegend } from '../trust/TierBadge';

/** Opens "The rule" pane of the provenance drawer for a Form 1040 line. */
function OpenRule({ line, what }: { line: string; what: string }) {
  const open = useOpenProvenance();
  if (!open) return null;
  return (
    <Button variant="outline" size="sm" className="h-7 rounded-full px-2.5 text-xs" onClick={() => open(line)} aria-label={`Open the Catala rule for ${what}`}>
      <Scale aria-hidden="true" className="size-3.5" />
      Open the rule
    </Button>
  );
}

/** Tier 2: the Catala rules and how they are checked against IRS Direct File. */
function CatalaTier() {
  return (
    <>
      <ul className="m-0 mb-5 grid list-none gap-2 p-0 text-sm sm:grid-cols-2">
        {CATALA.checks.map((c) => (
          <li key={c} className="rounded-lg border bg-muted/40 px-3 py-2">
            {c}
          </li>
        ))}
      </ul>
      <ul className="m-0 grid list-none divide-y rounded-xl border bg-card p-0 shadow-xs">
        {CATALA.items.map((it) => (
          <li key={it.file} className="grid gap-2 px-4 py-4 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center sm:px-5">
            <div className="grid min-w-0 gap-1">
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-sm font-semibold">{it.title}</span>
                <TierBadge status="tested" />
              </div>
              <p className="m-0 text-sm text-muted-foreground">{it.result}.</p>
              <a href={githubBlobUrl(it.file)} target="_blank" rel="noopener noreferrer" className="inline-flex w-fit items-center gap-1 text-xs">
                <code>{it.file}</code>, scope <code>{it.scope}</code>
                <ExternalLink aria-hidden="true" className="size-3" />
                <span className="sr-only">(opens in a new tab)</span>
              </a>
            </div>
            {'line' in it && it.line && <OpenRule line={it.line} what={it.title} />}
          </li>
        ))}
      </ul>
      <p className="mt-4 mb-0 text-sm text-muted-foreground">
        {CATALA.moduleFiles} Catala rule files in <code className="text-xs">catala/</code>, {CATALA.testFiles} test files in{' '}
        <code className="text-xs">catala/tests/</code>, {CATALA.mappings} differential-test mappings in{' '}
        <code className="text-xs">difftest/mappings/</code>. {CATALA.caveat}
      </p>
    </>
  );
}

function Bullets({ items }: { items: readonly string[] }) {
  return (
    <ul className="m-0 grid list-disc gap-2 pl-5 text-sm leading-relaxed marker:text-muted-foreground">
      {items.map((s) => (
        <li key={s}>{s}</li>
      ))}
    </ul>
  );
}

/** `UsTax.Main.foo` -> `foo`, shown beside the namespace so the full name stays copyable. */
function Name({ full }: { full: string }) {
  const i = full.lastIndexOf('.');
  return (
    <code className="text-xs break-all sm:break-normal">
      <span className="text-muted-foreground">{full.slice(0, i + 1)}</span>
      {full.slice(i + 1)}
    </code>
  );
}

function Files({ set }: { set: ProofSet }) {
  return (
    <dl className="m-0 mb-4 grid gap-1 text-sm sm:grid-cols-[9rem_1fr]">
      <dt className="text-muted-foreground">Checked list</dt>
      <dd className="m-0">
        <code className="text-xs">{set.config}</code> ({set.theorems.length} statements)
      </dd>
      <dt className="text-muted-foreground">Statements</dt>
      <dd className="m-0">
        <code className="text-xs">{set.statementsFile}</code>
      </dd>
      <dt className="text-muted-foreground">Proofs</dt>
      <dd className="m-0">
        <code className="text-xs">{set.proofsFile}</code>
      </dd>
      <dt className="text-muted-foreground">Run with</dt>
      <dd className="m-0">
        <code className="text-xs">{set.command}</code>
        {set.inCi ? ', and in CI' : ', by hand (not in CI)'}
      </dd>
    </dl>
  );
}

/** Route /trust: what is proved, what is tested, what you still have to trust. Data: src/trust/facts.ts. */
export function TrustPage({ embedded = false }: { embedded?: boolean }) {
  return (
    <ProvenanceProvider>
    <Page narrow className={embedded ? "mx-0 max-w-none p-0 sm:p-0" : undefined}>
      <PageHeader
        crumbs={[{ label: 'Home', to: '/' }, { label: 'Docs', to: '/docs' }, { label: 'Verification' }]}
        eyebrow="Verification"
        title="What is verified, and what is not"
        lead="The calculator is written in Lean 4, a language with a proof checker. Some properties are proved for every possible return; the rest is checked by testing. This page lists both, and what you have to take on trust."
      />

      <div className="mb-6 rounded-xl border bg-card px-5 py-4 shadow-xs">
        <TierLegend />
      </div>

      <nav aria-label="On this page" className="mb-10 rounded-xl border bg-muted/50 px-5 py-4 text-sm">
        <p className="m-0 mb-2 font-semibold">On this page</p>
        <ol className="m-0 grid list-decimal gap-1 pl-5">
          <li>
            <a href="#proven">Proved in Lean</a>
          </li>
          <li>
            <a href="#catala">Verified in Catala (not a proof)</a>
          </li>
          <li>
            <a href="#tested">Tested, not proved</a>
          </li>
          <li>
            <a href="#trusted">Trusted base</a>
          </li>
          <li>
            <a href="#not-covered">Not covered</a>
          </li>
          <li>
            <a href="#bugs">Bugs we found in the IRS reference implementation</a>
          </li>
        </ol>
      </nav>

      <PageSection
        id="proven"
        title="Proved in Lean"
        badge={<TierBadge status="proven" />}
        intro={`Every statement below is proved in Lean and compared with its trusted statement by Comparator (the additional list is run by hand). ${PROOF_CHECKS.main} Allowed axioms: ${PROOF_CHECKS.axioms.join(', ')}.`}
      >
        <h3 className="m-0 mb-1 text-base font-semibold">Main statements</h3>
        <p className="mt-0 mb-3 text-sm text-muted-foreground">
          Chosen by a person; each statement and the definitions it relies on is described in <code className="text-xs">docs/spec-surface.md</code>.
        </p>
        <Files set={MAIN} />
        <div className="rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead scope="col">Theorem</TableHead>
                <TableHead scope="col">What it states</TableHead>
                <TableHead scope="col" className="hidden sm:table-cell">
                  Holds for
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {MAIN.theorems.map((t) => (
                <TableRow key={t.name}>
                  <TableCell className="w-0">
                    <Name full={t.name} />
                  </TableCell>
                  <TableCell>
                    {t.says}
                    <span className="mt-1 block text-muted-foreground sm:hidden">{t.holdsFor}</span>
                  </TableCell>
                  <TableCell className="hidden text-muted-foreground sm:table-cell">{t.holdsFor}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>

        <h3 className="mt-10 mb-1 text-base font-semibold">Additional statements</h3>
        <p className="mt-0 mb-3 text-sm text-muted-foreground">
          Module-by-module equalities with the statute, bounds, and whole-return properties.
        </p>
        <Files set={EXTRA} />
        <ul className="m-0 grid list-none gap-3 p-0 text-sm">
          {EXTRA.theorems.map((t) => (
            <li key={t.name} className="grid gap-0.5">
              <Name full={t.name} />
              <span>{t.says}</span>
            </li>
          ))}
        </ul>

        <h3 className="mt-10 mb-1 text-base font-semibold">Also proved, outside the Comparator lists</h3>
        <p className="mt-0 mb-3 text-sm text-muted-foreground">
          Built and audited (<code className="text-xs">make audit</code>), but not compared against a trusted statement file.
        </p>
        <ul className="m-0 grid list-none gap-3 p-0 text-sm">
          {OTHER_PROOFS.map((p) => (
            <li key={p.name} className="grid gap-0.5">
              <Name full={p.name} />
              <span>
                {p.says} <code className="text-xs text-muted-foreground">{p.file}</code>
              </span>
            </li>
          ))}
        </ul>
        <p className="mt-6 mb-0 text-sm text-muted-foreground">{PROOF_CHECKS.note}</p>
      </PageSection>

      <PageSection
        id="catala"
        title="Verified in Catala (not a proof)"
        badge={<TierBadge status="tested" />}
        intro={`The legal rules are also written in Catala, a language for law, and verified against the IRS Direct File engine: on all ${TESTED.calculator.scenarios} scenarios that Direct File can run, ${TESTED.calculator.factChecks.toLocaleString('en-US')} fact checks agree end to end (as of ${AS_OF}). This is evidence from testing. It is not a proof, and it is labelled differently on purpose.`}
      >
        <CatalaTier />
      </PageSection>

      <PageSection
        id="tested"
        title="Tested, not proved"
        intro={`The Catala rules and the Lean code are linked to IRS Direct File by differential testing: the same inputs go through independent implementations and every output is compared. Counts as of ${AS_OF}.`}
      >
        <Bullets items={TESTED.items} />
        <p className="mt-4 mb-0 text-sm text-muted-foreground">{TESTED.caveat}</p>
      </PageSection>

      <PageSection id="trusted" title="Trusted base" intro="A proof is only as good as what it rests on. These parts are assumed correct.">
        <dl className="m-0 divide-y rounded-lg border">
          {TRUSTED.map((t) => (
            <div key={t.what} className="grid gap-1 px-5 py-4 sm:grid-cols-[14rem_1fr] sm:gap-6">
              <dt className="text-sm font-semibold">{t.what}</dt>
              <dd className="m-0 text-sm text-muted-foreground">{t.why}</dd>
            </div>
          ))}
        </dl>
      </PageSection>

      <PageSection id="not-covered" title="Not covered">
        <Bullets items={NOT_COVERED} />
      </PageSection>

      <PageSection
        id="bugs"
        title="Bugs we found in the IRS reference implementation"
        intro={`Writing the rules next to the statute turned up places where IRS Direct File seems to disagree with the law. ${BUGS.total} entries are logged in ${BUGS.file}: ${BUGS.confirmed} confirmed by running its engine, ${BUGS.fixed} fixed in our code, ${BUGS.candidates} still candidates.`}
      >
        <ul className="m-0 grid list-none gap-4 p-0 text-sm">
          {BUGS.highlights.map((b) => (
            <li key={b.id} className="grid gap-1">
              <span className="flex items-center gap-2">
                <code className="text-xs font-semibold">{b.id}</code>
                <Badge variant="outline">{b.status}</Badge>
              </span>
              <span>{b.text}</span>
            </li>
          ))}
        </ul>
        <p className="mt-6 mb-0 text-sm text-muted-foreground">{BUGS.caveat}</p>
        <p className="mt-2 mb-0 text-sm text-muted-foreground">Found by {BUGS.credit}. Full log with law citations: {BUGS.file}.</p>
        <p className="mt-6 mb-0 flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
          <Badge variant="outline">Sources</Badge>
          docs/spec-surface.md, docs/audit.md, docs/comparator.md, and README.md in the repository.
        </p>
      </PageSection>
    </Page>
    </ProvenanceProvider>
  );
}
