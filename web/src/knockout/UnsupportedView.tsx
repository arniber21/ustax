import { useState } from 'react';
import { ArrowLeft, Check, Copy, OctagonAlert } from 'lucide-react';
import type { ReasonCategory, UnsupportedReason } from '../api';
import { Button, ButtonLink } from '../components';
import { Alert, AlertDescription, AlertTitle } from '../components/ui/alert';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/table';
import { Page, PageHeader, PageSection } from '../layout/Page';
import { PRODUCT_NAME } from '../layout/AppShell';
import { categoryCopy, friendlyReason, type FriendlyReason } from './reasonCopy';

/** Things we do handle, so nobody leaves wondering. */
const SUPPORTED = [
  'W-2 wages and federal tax withheld',
  'Bank interest (Form 1099-INT)',
  'The standard deduction, including age and blindness',
  'All five filing statuses',
];

interface Group {
  category: ReasonCategory;
  reasons: FriendlyReason[];
}

/** Group reasons by category, keeping the order in which categories first appear and dropping repeats. */
export function groupReasons(reasons: readonly UnsupportedReason[]): Group[] {
  const groups = new Map<ReasonCategory, Group>();
  for (const r of reasons) {
    const g = groups.get(r.category) ?? { category: r.category, reasons: [] };
    if (!g.reasons.some((x) => x.code === r.code)) g.reasons.push(friendlyReason(r.code, r.category));
    groups.set(r.category, g);
  }
  return [...groups.values()];
}

/** Plain-text version of the list, for a preparer or a note to self. Contains no personal numbers. */
export function summaryText(groups: Group[]): string {
  const lines = [`${PRODUCT_NAME} could not prepare my 2024 federal return because:`];
  for (const g of groups) {
    lines.push('', categoryCopy(g.category).title);
    for (const r of g.reasons) lines.push(`- ${r.what}`);
  }
  return lines.join('\n');
}

/** Stacked cells on phones: each cell shows its column name. */
const cell = 'max-md:block max-md:px-4 max-md:py-1.5 max-md:before:mb-0.5 max-md:before:block max-md:before:text-xs max-md:before:font-semibold max-md:before:text-muted-foreground max-md:before:content-[attr(data-label)]';

/** The "not supported" screen: what was found, what it means, what to do instead. Never a dead end. */
export function UnsupportedView({ reasons }: { reasons: readonly UnsupportedReason[] }) {
  const groups = groupReasons(reasons);
  const [copied, setCopied] = useState<'idle' | 'yes' | 'no'>('idle');
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(summaryText(groups));
      setCopied('yes');
    } catch {
      setCopied('no');
    }
  };

  return (
    <Page>
      <PageHeader eyebrow="Result not available" title="This return can’t be calculated yet" />

      <Alert variant="warning" className="mb-10 max-w-3xl">
        <OctagonAlert aria-hidden="true" />
        <AlertTitle>
          Your answers include {reasons.length === 1 ? 'a situation' : 'situations'} {PRODUCT_NAME} does not support
        </AlertTitle>
        <AlertDescription>
          <p>
            No tax was calculated, because a result that ignored {reasons.length === 1 ? 'it' : 'them'} could be wrong. This
            is a limit of the calculator, not a mistake in your answers.
          </p>
        </AlertDescription>
      </Alert>

      <PageSection id="ko-found" title="What was found">
        <div className="overflow-hidden rounded-lg border bg-card">
          <Table>
            <TableHeader className="max-md:hidden">
              <TableRow>
                <TableHead scope="col" className="w-48 pl-5">
                  Category
                </TableHead>
                <TableHead scope="col">What we found</TableHead>
                <TableHead scope="col">What this means</TableHead>
                <TableHead scope="col" className="pr-5">
                  What to do instead
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {groups.map((g) => {
                const cc = categoryCopy(g.category);
                return (
                  <TableRow key={g.category} aria-label={cc.title} className="max-md:block max-md:py-3">
                    <TableHead scope="row" className="h-auto py-2.5 pl-5 align-top text-sm font-semibold tracking-normal text-foreground normal-case max-md:block max-md:px-4">
                      {cc.title}
                    </TableHead>
                    <TableCell data-label="What we found" className={cell}>
                      <ul className="m-0 grid list-disc gap-1 pl-4">
                        {g.reasons.map((r) => (
                          <li key={r.code}>{r.what}</li>
                        ))}
                      </ul>
                    </TableCell>
                    <TableCell data-label="What this means" className={`${cell} text-muted-foreground`}>
                      {cc.means}
                    </TableCell>
                    <TableCell data-label="What to do instead" className={`${cell} md:pr-5`}>
                      {cc.todo}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      </PageSection>

      <div className="mt-12 grid gap-10 md:grid-cols-2">
        <PageSection id="ko-next" title="Next steps" className="mt-0">
          <ol className="m-0 grid list-decimal gap-3 pl-5 text-sm leading-relaxed">
            <li>
              <strong>IRS Free File.</strong> If your 2024 income was about $84,000 or less, guided tax software is free
              through the IRS. Start at irs.gov/freefile so you get the free version.
            </li>
            <li>
              <strong>Free File Fillable Forms.</strong> Electronic IRS forms for any income. You do the calculations
              yourself.
            </li>
            <li>
              <strong>Free help from a person.</strong> IRS-certified volunteers (VITA and TCE) prepare returns for free for
              many people. Search “VITA locator” on irs.gov.
            </li>
          </ol>
          <p className="mt-3 mb-0 text-xs text-muted-foreground">
            Names are plain text: this page makes no outside calls. Income limits change each year; irs.gov has the current
            ones.
          </p>
        </PageSection>
        <PageSection id="ko-can" title={`What ${PRODUCT_NAME} can calculate`} className="mt-0">
          <ul className="m-0 grid list-none gap-2 p-0 text-sm">
            {SUPPORTED.map((s) => (
              <li key={s} className="flex gap-2.5">
                <Check aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-success" />
                {s}
              </li>
            ))}
          </ul>
          <p className="mt-3 mb-0 text-xs text-muted-foreground">
            Your answers stay in this browser. Change an answer and the return is checked again.
          </p>
        </PageSection>
      </div>

      <div className="mt-12 flex flex-wrap items-center gap-3 border-t pt-6">
        <ButtonLink to="/start/about">
          <ArrowLeft aria-hidden="true" />
          Change my answers
        </ButtonLink>
        <Button variant="secondary" onClick={copy}>
          <Copy aria-hidden="true" />
          Copy this list for a preparer
        </Button>
        <ButtonLink variant="ghost" to="/trust">
          What is verified
        </ButtonLink>
        <ButtonLink variant="ghost" to="/">
          Home
        </ButtonLink>
      </div>
      <p role="status" className="mt-3 mb-0 text-sm text-muted-foreground">
        {copied === 'yes' && 'Copied. Paste it anywhere.'}
        {copied === 'no' && 'Your browser blocked copying. You can select the text above instead.'}
      </p>
    </Page>
  );
}
