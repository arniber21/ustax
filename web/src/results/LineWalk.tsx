import { Fragment, useId } from 'react';
import { formatCents, type FilingStatus, type Lines } from '../api';
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '../components/ui/accordion';
import { cn } from '@/lib/utils';
import { ProvenanceButton, useOpenProvenance } from '../provenance';
import { WALK } from './walkData';

/** Lines printed in bold: the subtotals people look for. */
const EMPHASIS = new Set(['total_income', 'agi', 'taxable_income', 'total_tax', 'total_payments', 'overpayment', 'balance_due']);

/** The line the first-visit tour points at. */
export const TOUR_LINE = 'taxable_income';

const th = 'h-10 px-3 text-left align-middle text-xs font-semibold tracking-wide text-muted-foreground uppercase';

/**
 * The Form 1040 lines from the API, grouped as on the form: line, description, "Law & proof", amount.
 * The header stays in view while scrolling (below the sticky app header); figures are tabular.
 */
export function LineWalk({ lines, tour = false }: { lines: Lines; filingStatus?: FilingStatus; tour?: boolean }) {
  const id = useId();
  const withProvenance = useOpenProvenance() !== null;
  return (
    <section aria-labelledby={`${id}-h`} id="line-by-line" className="scroll-mt-24">
      <div className="mb-4 flex flex-wrap items-end justify-between gap-x-6 gap-y-1">
        <div>
          <h2 id={`${id}-h`} className="m-0 text-xl font-semibold tracking-tight">
            Form 1040, line by line
          </h2>
          <p className="mt-1 mb-0 text-sm text-muted-foreground">Amounts in U.S. dollars, in the order the form adds them up.</p>
        </div>
        {withProvenance && (
          <p className="prov-noprint m-0 text-sm text-muted-foreground">
            Select <span className="font-medium text-foreground">Law &amp; proof</span> on any line to see where it comes from.
          </p>
        )}
      </div>
      <div className="rounded-xl border bg-card shadow-xs">
        <table aria-labelledby={`${id}-h`} className="w-full border-separate border-spacing-0 text-sm">
          <thead>
            <tr>
              <th scope="col" className={cn(th, 'sticky top-16 z-10 w-14 rounded-tl-xl border-b bg-muted/95 pl-4 backdrop-blur sm:w-20 sm:pl-5')}>
                Line
              </th>
              <th scope="col" className={cn(th, 'sticky top-16 z-10 border-b bg-muted/95 backdrop-blur')}>
                Description
              </th>
              {withProvenance && (
                <th scope="col" className={cn(th, 'prov-noprint sticky top-16 z-10 w-px border-b bg-muted/95 backdrop-blur')}>
                  <span className="max-sm:sr-only">Source</span>
                </th>
              )}
              <th scope="col" className={cn(th, 'sticky top-16 z-10 rounded-tr-xl border-b bg-muted/95 pr-4 text-right backdrop-blur sm:pr-5')}>
                Amount
              </th>
            </tr>
          </thead>
          <tbody>
            {WALK.map((g) => (
              <Fragment key={g.id}>
                <tr>
                  <th
                    scope="colgroup"
                    colSpan={withProvenance ? 4 : 3}
                    className="h-9 border-b bg-background px-4 pt-4 text-left text-[0.8125rem] font-semibold text-foreground sm:px-5"
                  >
                    {g.title}
                  </th>
                </tr>
                {g.lines.map((l) => {
                  const strong = EMPHASIS.has(l.key);
                  const result = l.key === 'overpayment' || l.key === 'balance_due';
                  const v = lines[l.key] ?? 0;
                  return (
                    <tr key={l.key} className={cn('group transition-colors hover:bg-accent/50', strong && 'bg-muted/40')}>
                      <td className="border-b py-2.5 pr-2 pl-4 align-middle text-muted-foreground tabular-nums sm:pl-5">{l.line}</td>
                      <td className={cn('border-b px-3 py-2.5 align-middle', strong && 'font-semibold')}>{l.label}</td>
                      {withProvenance && (
                        <td className="prov-noprint border-b px-2 py-2 text-right align-middle whitespace-nowrap">
                          <ProvenanceButton lineKey={l.key} lineName={`line ${l.line}, ${l.label}`} compact highlight={tour && l.key === TOUR_LINE} />
                        </td>
                      )}
                      <td
                        className={cn(
                          'border-b py-2.5 pr-4 pl-3 text-right align-middle whitespace-nowrap tabular-nums sm:pr-5',
                          strong && 'font-semibold',
                          result && v > 0 && (l.key === 'overpayment' ? 'text-success' : 'text-destructive'),
                        )}
                      >
                        {formatCents(v)}
                      </td>
                    </tr>
                  );
                })}
              </Fragment>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

/** "How this was calculated": the plain-language explanation of each key line, one accordion item per line. */
export function HowCalculated({ lines, filingStatus }: { lines: Lines; filingStatus?: FilingStatus }) {
  const id = useId();
  const items = WALK.flatMap((g) => g.lines).filter((l) => l.explain);
  return (
    <section aria-labelledby={`${id}-h`}>
      <h2 id={`${id}-h`} className="m-0 text-xl font-semibold tracking-tight">
        How this was calculated
      </h2>
      <p className="mt-1 mb-0 text-sm text-muted-foreground">The key lines in plain English, with your numbers.</p>
      <div className="mt-4 rounded-xl border bg-card px-4 shadow-xs sm:px-5">
        <Accordion type="multiple">
          {items.map((l) => (
            <AccordionItem key={l.key} value={l.key}>
              <AccordionTrigger>
                <span>
                  <span className="mr-3 inline-block w-16 text-muted-foreground tabular-nums">Line {l.line}</span>{' '}
                  {l.label}
                </span>
              </AccordionTrigger>
              <AccordionContent className="max-w-2xl pl-[4.75rem] leading-relaxed text-muted-foreground max-sm:pl-0">
                {l.explain!({ lines, filingStatus })}
                <ProvenanceButton lineKey={l.key} lineName={`line ${l.line}, ${l.label}`} className="mt-3 flex w-fit" />
              </AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </section>
  );
}
