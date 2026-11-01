import { Fragment, useId } from 'react';
import { formatCents, type FilingStatus, type Lines } from '../api';
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '../components/ui/accordion';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/table';
import { cn } from '@/lib/utils';
import { WALK } from './walkData';

/** Lines printed in bold: the subtotals people look for. */
const EMPHASIS = new Set(['total_income', 'agi', 'taxable_income', 'total_tax', 'total_payments', 'overpayment', 'balance_due']);

/** The Form 1040 lines from the API, grouped as on the form: line, description, amount. */
export function LineWalk({ lines }: { lines: Lines; filingStatus?: FilingStatus }) {
  const id = useId();
  return (
    <section aria-labelledby={`${id}-h`}>
      <h2 id={`${id}-h`} className="m-0 text-xl font-semibold tracking-tight">
        Form 1040, line by line
      </h2>
      <p className="mt-1 mb-4 text-sm text-muted-foreground">Amounts in U.S. dollars, in the order the form adds them up.</p>
      <div className="rounded-lg border bg-card">
        <Table aria-labelledby={`${id}-h`}>
          <TableHeader>
            <TableRow>
              <TableHead scope="col" className="w-16 pl-4 sm:w-20 sm:pl-5">
                Line
              </TableHead>
              <TableHead scope="col">Description</TableHead>
              <TableHead scope="col" className="pr-4 text-right sm:pr-5">
                Amount
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {WALK.map((g) => (
              <Fragment key={g.id}>
                <TableRow className="bg-muted">
                  <TableHead scope="colgroup" colSpan={3} className="h-9 pl-4 text-foreground sm:pl-5">
                    {g.title}
                  </TableHead>
                </TableRow>
                {g.lines.map((l) => {
                  const strong = EMPHASIS.has(l.key);
                  return (
                    <TableRow key={l.key}>
                      <TableCell className="pl-4 text-muted-foreground tabular-nums sm:pl-5">{l.line}</TableCell>
                      <TableCell className={cn(strong && 'font-semibold')}>{l.label}</TableCell>
                      <TableCell className={cn('pr-4 text-right whitespace-nowrap tabular-nums sm:pr-5', strong && 'font-semibold')}>
                        {formatCents(lines[l.key] ?? 0)}
                      </TableCell>
                    </TableRow>
                  );
                })}
              </Fragment>
            ))}
          </TableBody>
        </Table>
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
      <div className="mt-4 rounded-lg border bg-card px-4 sm:px-5">
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
              </AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </section>
  );
}
