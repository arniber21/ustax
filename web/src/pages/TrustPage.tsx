import { Page, PageHeader, PageSection } from '../layout/Page';
import { Badge } from '../components/ui/badge';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/table';
import { NOT_COVERED, OTHER_PROOFS, TESTED, THEOREMS, TRUSTED } from '../trust/claims';

function Bullets({ items }: { items: readonly string[] }) {
  return (
    <ul className="m-0 grid list-disc gap-2 pl-5 text-sm leading-relaxed marker:text-muted-foreground">
      {items.map((s) => (
        <li key={s}>{s}</li>
      ))}
    </ul>
  );
}

/** Route /trust: what is proven, what is tested, and what you still have to trust. Facts only. */
export function TrustPage() {
  return (
    <Page narrow>
      <PageHeader
        eyebrow="Verification"
        title="What is verified, and what is not"
        lead="The calculator is written in Lean 4, a language with a proof checker. Some properties are proven for every possible return; the rest is checked by testing. This page lists both, and what you have to take on trust."
      />

      <nav aria-label="On this page" className="mb-10 rounded-lg border bg-muted px-5 py-4 text-sm">
        <p className="m-0 mb-2 font-semibold">On this page</p>
        <ol className="m-0 grid list-decimal gap-1 pl-5">
          <li>
            <a href="#proven">Proven</a>
          </li>
          <li>
            <a href="#tested">Tested, not proven</a>
          </li>
          <li>
            <a href="#trusted">Trusted base</a>
          </li>
          <li>
            <a href="#not-covered">Not covered</a>
          </li>
        </ol>
      </nav>

      <PageSection
        id="proven"
        title="Proven"
        intro="Each theorem below is checked by the Lean kernel and by lake comparator against a fixed statement file. Names are in the namespace UsTax.Main (lean/UsTax/Comparator/Challenge.lean)."
      >
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
              {THEOREMS.map((t) => (
                <TableRow key={t.name}>
                  <TableCell className="w-0">
                    <code className="text-xs break-all sm:break-normal sm:whitespace-nowrap">{t.name}</code>
                  </TableCell>
                  <TableCell>
                    {t.states}
                    <span className="mt-1 block text-muted-foreground sm:hidden">{t.scope}</span>
                  </TableCell>
                  <TableCell className="hidden text-muted-foreground sm:table-cell">{t.scope}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
        <h3 className="mt-6 mb-2 text-sm font-semibold">Also proven</h3>
        <ul className="m-0 grid list-none gap-2 p-0 text-sm">
          {OTHER_PROOFS.map((p) => (
            <li key={p.name}>
              <code className="text-xs">{p.name}</code>: {p.states}
            </li>
          ))}
        </ul>
      </PageSection>

      <PageSection
        id="tested"
        title="Tested, not proven"
        intro="Differential testing runs the same inputs through independent implementations and compares every output. It finds disagreements; it cannot rule them out."
      >
        <Bullets items={TESTED} />
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
        <p className="mt-6 mb-0 flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
          <Badge variant="outline">Sources</Badge>
          docs/spec-surface.md, docs/audit.md and lean/README.md in the repository.
        </p>
      </PageSection>
    </Page>
  );
}
