import { CircleAlert, ClipboardCopy, Pencil, Printer, TriangleAlert } from 'lucide-react';
import { toast } from 'sonner';
import type { CalculateError, CalculateRequest, CalculateSuccess, ClientOptions, FilingStatus, Warning } from '../api';
import { Button, ButtonLink } from '../components';
import { Alert, AlertDescription, AlertTitle } from '../components/ui/alert';
import { Skeleton } from '../components/ui/skeleton';
import { UnsupportedView } from '../knockout/UnsupportedView';
import { Page, PageHeader } from '../layout/Page';
import { ResultsHero } from '../pages/ResultsHero';
import { FILING_STATUS_OPTIONS } from '../wizard/AboutStep';
import { ProvenanceProvider } from '../provenance';
import { HowCalculated, LineWalk } from './LineWalk';
import { MoneyFlow } from './MoneyFlow';
import { ProvenanceCallout, useProvenanceTour } from './ProvenanceTour';
import { summaryText } from './summaryText';
import { WhatIf } from './WhatIf';
import { useLiveCalculation } from './useLiveCalculation';

/** Words for each way a calculation can fail. Never shows a status code or a stack trace. */
export function describeError(error: CalculateError): { title: string; body: string; canRetry: boolean; fixAnswers: boolean } {
  if (error.type === 'network') {
    const offline = typeof navigator !== 'undefined' && navigator.onLine === false;
    return offline
      ? { title: 'You’re offline', body: 'Your answers are saved in this browser. Reconnect and try again.', canRetry: true, fixAnswers: false }
      : { title: 'The calculator can’t be reached', body: 'This may be temporary. Your answers are saved. Try again in a moment.', canRetry: true, fixAnswers: false };
  }
  if (error.type === 'http' && error.status === 400) {
    return { title: 'One of your answers was not accepted', body: 'Go back and check your entries, especially the amounts. The result updates once they are fixed.', canRetry: false, fixAnswers: true };
  }
  return { title: 'Something went wrong on our end', body: 'The result could not be calculated. This is not caused by your answers, which are saved. Please try again.', canRetry: true, fixAnswers: false };
}

/** Plain names for request sections the server may report as accepted but not used (`section_not_used`). */
const SECTION_NAMES: Record<string, string> = {
  '/form_1099g': 'Unemployment (Form 1099-G)',
  '/form_1099misc': 'Form 1099-MISC',
  '/form_1099r': 'Retirement distributions (Form 1099-R)',
  '/social_security': 'Social Security benefits (SSA-1099)',
  '/adjustments/educator_expenses': 'Teacher expenses',
  '/adjustments/student_loan_interest': 'Student loan interest',
  '/adjustments': 'Adjustments to income',
  '/estimated_payments': 'Estimated tax payments',
};

const statusName = (fs?: FilingStatus) => FILING_STATUS_OPTIONS.find((o) => o.value === fs)?.label;

/** The API's optional `warnings`, as one alert listing what was not counted. */
export function WarningsAlert({ warnings }: { warnings: readonly Warning[] }) {
  const unused = warnings.filter((w) => w.code === 'section_not_used');
  const other = warnings.filter((w) => w.code !== 'section_not_used');
  return (
    <Alert variant="warning" role="note">
      <TriangleAlert aria-hidden="true" />
      <AlertTitle>Some answers were not used in this result</AlertTitle>
      <AlertDescription>
        {unused.length > 0 && (
          <>
            <p>These parts of your return are accepted but not yet part of the calculation, so the result does not include them:</p>
            <ul className="m-0 grid list-disc gap-0.5 pl-5">
              {unused.map((w) => (
                <li key={w.path}>{SECTION_NAMES[w.path] ?? w.message}</li>
              ))}
            </ul>
          </>
        )}
        {other.map((w) => (
          <p key={`${w.code}${w.path}`}>{w.message}</p>
        ))}
      </AlertDescription>
    </Alert>
  );
}

/** The results screen for a request: summary, Form 1040 table, explanations, what-if, or the knockout / error experience. */
export function ResultsView({ request, client, debounceMs }: { request: CalculateRequest; client?: ClientOptions; debounceMs?: number }) {
  const { state, retry } = useLiveCalculation(request, { client, debounceMs });
  const tour = useProvenanceTour();

  if (state.status === 'knockout') return <UnsupportedView reasons={state.reasons} />;

  const shown = state.status === 'ok' ? state.data : state.previous;
  const fs = statusName(request.filing_status);

  return (
    <Page>
      <PageHeader
        crumbs={[{ label: 'Home', to: '/' }, { label: 'Your return', to: '/start/review' }, { label: 'Result' }]}
        eyebrow="Tax year 2024 · Form 1040"
        title="Your federal income tax"
        lead={fs ? `Filing status: ${fs}.` : undefined}
        actions={
          <>
            <ButtonLink variant="secondary" to="/start/review">
              <Pencil aria-hidden="true" />
              Change answers
            </ButtonLink>
            {shown && <CopySummary data={shown} filingStatus={fs} />}
            <Button variant="ghost" onClick={() => window.print()}>
              <Printer aria-hidden="true" />
              Print
            </Button>
          </>
        }
      />

      {state.status === 'loading' && shown === null && <ResultsSkeleton />}

      {state.status === 'error' && <ErrorNotice error={state.error} onRetry={retry} hasPrevious={shown !== null} />}

      {shown && (
        <ProvenanceProvider lines={shown.lines}>
          <div className="grid gap-8 [&>*]:animate-in [&>*]:fade-in-0 [&>*]:fill-mode-backwards [&>*]:duration-300 [&>:nth-child(2)]:delay-50 [&>:nth-child(3)]:delay-100 [&>:nth-child(n+4)]:delay-150">
            <ResultsHero outcome={shown.outcome} lines={shown.lines} stale={state.status !== 'ok'} filingStatus={fs} />
            {tour.show && <ProvenanceCallout onDismiss={tour.dismiss} onShowMe={tour.replay} />}
            {shown.warnings && shown.warnings.length > 0 && <WarningsAlert warnings={shown.warnings} />}
            <MoneyFlow lines={shown.lines} outcome={shown.outcome} />
            <LineWalk lines={shown.lines} filingStatus={request.filing_status} tour={tour.pulse} />
            <div className="grid gap-8 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)] lg:items-start">
              <HowCalculated lines={shown.lines} filingStatus={request.filing_status} />
              <WhatIf request={request} client={client} />
            </div>
          </div>
        </ProvenanceProvider>
      )}
    </Page>
  );
}

/** "Copy summary": the outcome and key lines as plain text, with a toast either way. */
function CopySummary({ data, filingStatus }: { data: CalculateSuccess; filingStatus?: string }) {
  return (
    <Button
      variant="ghost"
      onClick={() => {
        const text = summaryText(data, filingStatus);
        const done = () => toast.success('Summary copied', { description: 'The outcome and key Form 1040 lines, as plain text.' });
        const fail = () => toast.error('Could not copy', { description: 'Your browser blocked the clipboard. Use Print instead.' });
        if (!navigator.clipboard?.writeText) return fail();
        navigator.clipboard.writeText(text).then(done, fail);
      }}
    >
      <ClipboardCopy aria-hidden="true" />
      Copy summary
    </Button>
  );
}

/** Placeholder with the shape of the result while the first answer is on its way (no layout jump). */
function ResultsSkeleton() {
  return (
    <div className="grid gap-8" aria-busy="true">
      <p role="status" className="sr-only">
        Calculating…
      </p>
      <div className="grid overflow-hidden rounded-2xl border bg-card md:grid-cols-[minmax(0,1fr)_minmax(0,22rem)]">
        <div className="grid gap-4 p-6 sm:p-8">
          <Skeleton className="h-5 w-40" />
          <Skeleton className="h-14 w-56" />
          <Skeleton className="h-4 w-full max-w-md" />
          <Skeleton className="h-8 w-72 max-w-full rounded-full" />
        </div>
        <div className="grid gap-4 border-t bg-muted/60 p-6 md:border-t-0 md:border-l">
          {[0, 1, 2, 3, 4].map((i) => (
            <div key={i} className="flex justify-between gap-4">
              <Skeleton className="h-4 w-32" />
              <Skeleton className="h-4 w-20" />
            </div>
          ))}
        </div>
      </div>
      <div className="grid gap-3 rounded-xl border bg-card p-6">
        <Skeleton className="h-5 w-48" />
        {[90, 70, 55, 40, 25].map((w) => (
          <Skeleton key={w} className="h-2.5" style={{ width: `${w}%` }} />
        ))}
      </div>
      <div className="grid gap-2 rounded-xl border bg-card p-4">
        {Array.from({ length: 8 }, (_, i) => (
          <Skeleton key={i} className="h-8 w-full" />
        ))}
      </div>
    </div>
  );
}

function ErrorNotice({ error, onRetry, hasPrevious }: { error: CalculateError; onRetry: () => void; hasPrevious: boolean }) {
  const d = describeError(error);
  return (
    <Alert variant="destructive" className="mb-8">
      <CircleAlert aria-hidden="true" />
      <AlertTitle>{d.title}</AlertTitle>
      <AlertDescription>
        <p>{d.body}</p>
        {hasPrevious && <p className="text-muted-foreground">The figures below are from before and may be out of date.</p>}
        <div className="mt-2 flex flex-wrap gap-2">
          {d.canRetry && <Button onClick={onRetry}>Try again</Button>}
          {d.fixAnswers && <ButtonLink to="/start/review">Check my answers</ButtonLink>}
          <ButtonLink variant="ghost" to="/">
            Home
          </ButtonLink>
        </div>
      </AlertDescription>
    </Alert>
  );
}
