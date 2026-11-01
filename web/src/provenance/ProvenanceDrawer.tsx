import { useEffect, useRef, useState, type ReactNode } from 'react';
import { ExternalLink, Scale } from 'lucide-react';
import { StatusChip } from './StatusChip';
import { lineStatus } from './status';
import { Badge } from '@/components/ui/badge';
import { Sheet, SheetContent, SheetDescription, SheetTitle } from '@/components/ui/sheet';
import { loadProvenance } from './load';
import { SourcePane, windowAround } from './SourcePane';
import type { Citation, DifftestEntry, FileEntry, Provenance, ProvLine } from './types';

/** The label under "The rule". Catala is a readable specification, never a proof. */
export const RULE_LABEL = 'Readable rule, validated by differential testing against IRS Direct File. Not a proof.';
export const NO_THEOREM = 'No theorem covers this line yet. It is checked by tests.';

const KIND_TITLES: Record<string, string> = { statute: 'Statute and regulation', irs_form: 'IRS forms and instructions' };

function Section({ title, id, children }: { title: string; id: string; children: ReactNode }) {
  return (
    <section aria-labelledby={id} className="prov-section grid gap-3 border-t pt-5 first:border-t-0 first:pt-0">
      <h3 id={id} className="m-0 text-base font-semibold">
        {title}
      </h3>
      {children}
    </section>
  );
}

function CitationItem({ c }: { c: Citation }) {
  return (
    <li className="grid gap-0.5 text-sm">
      <span>
        <a href={c.url} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1 font-medium text-primary underline underline-offset-2">
          {c.label}
          <ExternalLink aria-hidden="true" className="size-3" />
          <span className="sr-only">(opens in a new tab)</span>
        </a>
        {c.origin === 'curated' && (
          <Badge variant="outline" className="ml-2">
            statutory basis (editorial)
          </Badge>
        )}
      </span>
      {c.local && (
        <span className="text-xs text-muted-foreground">
          Local copy: <code>{c.local.path}</code>
          {c.local.page ? `, page ${c.local.page}` : ''}
        </span>
      )}
      {c.found_in.length > 0 && (
        <span className="text-xs text-muted-foreground">
          Quoted in the rule at {c.found_in.map((f) => `${f.file}:${f.line}`).join(', ')}
        </span>
      )}
    </li>
  );
}

/** Plain English for one differential test mapping (difftest/mappings/*). */
export function describeDifftest(t: DifftestEntry): string {
  const what =
    t.role === 'module'
      ? `compares the Catala module ${t.catala_scope} with IRS Direct File`
      : `runs whole tax returns through the Catala scope ${t.catala_scope} and compares the answers with IRS Direct File`;
  return `${what}.${t.report_only ? ' Report only: differences are listed but do not fail the build.' : ' A difference fails the build.'}`;
}

function Body({ line, fileOf }: { line: ProvLine; fileOf: (p: string) => FileEntry | undefined }) {
  const [openFeed, setOpenFeed] = useState<string | null>(null);
  const r = line.rule;
  const kinds = [...new Set(line.citations.map((c) => c.kind))];
  const theorems = line.proofs.theorems;
  const nonReport = line.tests.difftest.filter((t) => !t.report_only).length;
  return (
    <div className="grid gap-5">
      <Section id="prov-law" title="The law">
        {kinds.length === 0 && <p className="m-0 text-sm text-muted-foreground">No citation is recorded for this line.</p>}
        {kinds.map((k) => (
          <div key={k} className="grid gap-1.5">
            <h4 className="m-0 text-xs font-semibold tracking-wide text-muted-foreground uppercase">{KIND_TITLES[k] ?? k}</h4>
            <ul className="m-0 grid list-none gap-2.5 p-0">
              {line.citations
                .filter((c) => c.kind === k)
                .map((c) => (
                  <CitationItem key={c.id} c={c} />
                ))}
            </ul>
          </div>
        ))}
      </Section>

      <Section id="prov-rule" title="The rule">
        <p className="m-0 rounded-md border bg-muted px-3 py-2 text-sm font-medium">{RULE_LABEL}</p>
        {r.heading && (
          <p className="m-0 text-sm text-muted-foreground">
            Section: <span className="text-foreground">{r.heading.title}</span> (lines {r.heading.start} to {r.heading.end})
          </p>
        )}
        <SourcePane
          path={r.file}
          mark={r.definition}
          window={windowAround(r.definition, r.heading)}
          expectedLines={fileOf(r.file)?.lines}
          label={`Catala rule for ${line.form.label}`}
        />
        {r.feeds.length > 0 && (
          <div className="grid gap-2">
            <h4 className="m-0 text-xs font-semibold tracking-wide text-muted-foreground uppercase">Also feeds this line</h4>
            {r.feeds.map((f) => {
              const k = `${f.file}:${f.definition.start}`;
              return (
                <details key={k} onToggle={(e) => setOpenFeed((cur) => (e.currentTarget.open ? k : cur === k ? null : cur))} open={openFeed === k}>
                  <summary className="cursor-pointer text-sm">
                    <code>{f.variable}</code> in <code>{f.file}</code>
                  </summary>
                  {openFeed === k && (
                    <div className="mt-2 grid gap-2">
                      {f.heading && <p className="m-0 text-sm text-muted-foreground">Section: {f.heading.title}</p>}
                      <SourcePane
                        path={f.file}
                        mark={f.definition}
                        window={windowAround(f.definition, f.heading)}
                        expectedLines={fileOf(f.file)?.lines}
                        label={`Catala rule ${f.variable}`}
                      />
                    </div>
                  )}
                </details>
              );
            })}
          </div>
        )}
      </Section>

      <Section id="prov-proved" title="What is proved">
        {theorems.length === 0 ? (
          <p className="m-0 text-sm">{NO_THEOREM}</p>
        ) : (
          <>
            <p className="m-0 text-sm text-muted-foreground">
              Machine-checked Lean theorems. Each covers only what its sentence says; none states that the rule above matches the law.
            </p>
            <ul className="m-0 grid list-none gap-4 p-0">
              {theorems.map((t) => (
                <li key={t.qualified} className="grid gap-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <code className="text-sm font-semibold">{t.name}</code>
                    <Badge variant="success">proved in Lean</Badge>
                  </div>
                  <p className="m-0 text-sm">{t.covers}</p>
                  <p className="m-0 text-xs text-muted-foreground">
                    <code>
                      {t.file}:{t.start}
                    </code>
                  </p>
                  <SourcePane
                    path={t.file}
                    mark={{ start: t.start, end: t.end }}
                    window={{ start: Math.max(1, t.start - 2), end: t.end + 2 }}
                    expectedLines={fileOf(t.file)?.lines}
                    label={`Lean source of ${t.name}`}
                  />
                </li>
              ))}
            </ul>
          </>
        )}
        <p className="m-0 text-xs text-muted-foreground">
          Lean code that computes this line: <code>{line.lean.definition}</code> (
          <code>
            {line.lean.file}:{line.lean.binding.start}
          </code>
          ).
        </p>
      </Section>

      <Section id="prov-tested" title="How it is tested">
        {line.tests.difftest.length === 0 ? (
          <p className="m-0 text-sm text-muted-foreground">No differential test mentions this line.</p>
        ) : (
          <>
            <p className="m-0 text-sm text-muted-foreground">
              {nonReport} differential test{nonReport === 1 ? '' : 's'} compare the calculator with IRS Direct File on example returns. This is evidence, not a proof.
            </p>
            <ul className="m-0 grid list-disc gap-1.5 pl-5 text-sm">
              {line.tests.difftest.map((t) => (
                <li key={t.mapping}>
                  <code>{t.mapping}</code> {describeDifftest(t)}
                </li>
              ))}
            </ul>
          </>
        )}
      </Section>

      <Section id="prov-fact" title="Direct File fact">
        {line.direct_file_fact ? (
          <p className="m-0 text-sm">
            IRS Direct File computes this line as the fact <code>{line.direct_file_fact.path}</code>
            {line.direct_file_fact.source && (
              <>
                , noted in <code>{`${line.direct_file_fact.source.file}:${line.direct_file_fact.source.line}`}</code>
              </>
            )}
            .
          </p>
        ) : (
          <p className="m-0 text-sm text-muted-foreground">No Direct File fact is recorded for this line.</p>
        )}
      </Section>
    </div>
  );
}

export interface ProvenanceDrawerProps {
  /** API `lines` key, or null when closed. */
  lineKey: string | null;
  onOpenChange: (open: boolean) => void;
  /** The formatted amount for this line, shown in the header. */
  amount?: string;
}

/** "How was this calculated?": from the number to the law, the rule, the proofs and the tests (data: api/provenance.json). */
export function ProvenanceDrawer({ lineKey, onOpenChange, amount }: ProvenanceDrawerProps) {
  const [data, setData] = useState<Provenance | null>(null);
  const [failed, setFailed] = useState(false);
  const open = lineKey !== null;
  const opener = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!open || data) return;
    let live = true;
    setFailed(false);
    loadProvenance()
      .then((d) => live && setData(d))
      .catch(() => live && setFailed(true));
    return () => {
      live = false;
    };
  }, [open, data]);

  const line = lineKey && data ? data.lines[lineKey] : undefined;
  const title = line ? `Line ${line.form.line}: ${line.form.label}` : 'How was this calculated?';

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        aria-describedby="prov-desc"
        // Plain buttons open the drawer; preserve their focus across the modal.
        initialFocus={() => {
          opener.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
          return true;
        }}
        finalFocus={() => opener.current ?? true}
      >
        <div className="grid gap-1 border-b px-5 py-4 pr-12">
          <p className="m-0 flex items-center gap-1.5 text-xs font-semibold tracking-wide text-primary uppercase">
            <Scale aria-hidden="true" className="size-3.5" />
            Law &amp; proof
          </p>
          <div className="flex flex-wrap items-center gap-2">
            <SheetTitle>{title}</SheetTitle>
            {line && <StatusChip status={lineStatus(line)!} />}
          </div>
          <SheetDescription id="prov-desc">
            {line ? line.description : 'How was this calculated? The trail from this number to the law.'}
            {amount ? ` Your amount: ${amount}.` : ''}
          </SheetDescription>
          {line && (
            <nav aria-label="Sections" className="prov-noprint mt-2 flex flex-wrap gap-1.5">
              {[
                ['prov-law', 'The law'],
                ['prov-rule', 'Catala rule'],
                ['prov-proved', 'Proofs'],
                ['prov-tested', 'Tests'],
              ].map(([id, text]) => (
                <a
                  key={id}
                  href={`#${id}`}
                  className="rounded-full border px-2.5 py-0.5 text-xs font-medium text-muted-foreground no-underline hover:border-primary/40 hover:text-foreground"
                  onClick={(e) => {
                    e.preventDefault();
                    document.getElementById(id!)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
                  }}
                >
                  {text}
                </a>
              ))}
            </nav>
          )}
        </div>
        <div className="prov-scroll min-h-0 flex-1 overflow-y-auto px-5 py-5">
          {failed ? (
            <p role="alert" className="m-0 text-sm">
              The source trail for this line could not be loaded. The number above is unaffected. Reload the page to try again.
            </p>
          ) : !data ? (
            <p className="m-0 text-sm text-muted-foreground" role="status">
              Loading…
            </p>
          ) : !line ? (
            <p className="m-0 text-sm" role="status">
              No source trail is recorded for this line yet. Its value is still computed by the same rules and checked by the tests.
            </p>
          ) : (
            <Body line={line} fileOf={(p) => data.files.find((f) => f.path === p)} />
          )}
        </div>
      </SheetContent>
    </Sheet>
  );
}
