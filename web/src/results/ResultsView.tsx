import { CircleAlert, TriangleAlert } from 'lucide-react';
import type { CalculateError, CalculateRequest, ClientOptions, FilingStatus, Warning } from '../api';
import { Button, ButtonLink } from '../components';
import { Alert, AlertDescription, AlertTitle } from '../components/ui/alert';
import { UnsupportedView } from '../knockout/UnsupportedView';
import { Page, PageHeader } from '../layout/Page';
import { ResultsHero } from '../pages/ResultsHero';
import { FILING_STATUS_OPTIONS } from '../wizard/AboutStep';
import { HowCalculated, LineWalk } from './LineWalk';
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

  if (state.status === 'knockout') return <UnsupportedView reasons={state.reasons} />;

  const shown = state.status === 'ok' ? state.data : state.previous;
  const fs = statusName(request.filing_status);

  return (
    <Page>
      <PageHeader eyebrow="Tax year 2024 · Form 1040" title="Your federal income tax" lead={fs ? `Filing status: ${fs}.` : undefined}>
        <div className="mt-4 flex flex-wrap gap-2">
          <ButtonLink variant="secondary" to="/start/review">
            Change answers
          </ButtonLink>
        </div>
      </PageHeader>

      {state.status === 'loading' && shown === null && (
        <p role="status" className="py-16 text-center text-muted-foreground">
          Calculating…
        </p>
      )}

      {state.status === 'error' && <ErrorNotice error={state.error} onRetry={retry} hasPrevious={shown !== null} />}

      {shown && (
        <div className="grid gap-10">
          <ResultsHero outcome={shown.outcome} lines={shown.lines} stale={state.status !== 'ok'} />
          {shown.warnings && shown.warnings.length > 0 && <WarningsAlert warnings={shown.warnings} />}
          <LineWalk lines={shown.lines} filingStatus={request.filing_status} />
          <HowCalculated lines={shown.lines} filingStatus={request.filing_status} />
          <WhatIf request={request} client={client} />
        </div>
      )}
    </Page>
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
