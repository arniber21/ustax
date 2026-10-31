import { Link } from 'react-router';
import type { CalculateError, CalculateRequest, ClientOptions } from '../api';
import { Button, ButtonLink, Callout } from '../components';
import { UnsupportedView } from '../knockout/UnsupportedView';
import { ResultsHero } from '../pages/ResultsHero';
import { LineWalk } from './LineWalk';
import { WhatIf } from './WhatIf';
import { useLiveCalculation } from './useLiveCalculation';
import './results.css';

/** Words for each way a calculation can fail. Never shows a status code or a stack trace. */
export function describeError(error: CalculateError): { title: string; body: string; canRetry: boolean; fixAnswers: boolean } {
  if (error.type === 'network') {
    const offline = typeof navigator !== 'undefined' && navigator.onLine === false;
    return offline
      ? { title: 'You’re offline', body: 'Your answers are safe on this device. Reconnect and we’ll pick up right where you left off.', canRetry: true, fixAnswers: false }
      : { title: 'We can’t reach the calculator', body: 'It might be a brief hiccup. Your answers are safe. Try again in a moment.', canRetry: true, fixAnswers: false };
  }
  if (error.type === 'http' && error.status === 400) {
    return { title: 'One of your answers didn’t look right', body: 'Go back and check your entries, especially the amounts. We’ll recalculate as soon as they’re fixed.', canRetry: false, fixAnswers: true };
  }
  return { title: 'Something went wrong on our end', body: 'We couldn’t work out your result just now. It isn’t anything you did. Your answers are safe, so please try again.', canRetry: true, fixAnswers: false };
}

/** The results screen for a request: hero, line-by-line walk, what-if, or the knockout / error experience. */
export function ResultsView({ request, client, debounceMs }: { request: CalculateRequest; client?: ClientOptions; debounceMs?: number }) {
  const { state, retry } = useLiveCalculation(request, { client, debounceMs });

  if (state.status === 'knockout') return <UnsupportedView reasons={state.reasons} />;

  const shown = state.status === 'ok' ? state.data : state.previous;

  return (
    <div className="container results">
      {state.status === 'loading' && shown === null && (
        <p role="status" className="results__loading">
          Crunching the numbers…
        </p>
      )}

      {state.status === 'error' && (
        <ErrorNotice error={state.error} onRetry={retry} hasPrevious={shown !== null} />
      )}

      {shown && (
        <>
          <ResultsHero outcome={shown.outcome} lines={shown.lines} stale={state.status !== 'ok'} />
          <LineWalk lines={shown.lines} filingStatus={request.filing_status} />
          <WhatIf request={request} client={client} />
          <Callout tone="good" title="Every number here is computed, not guessed">
            The math behind this page is written as code and checked by a proof assistant.{' '}
            <Link to="/trust">See how we know it’s right.</Link>
          </Callout>
        </>
      )}
    </div>
  );
}

function ErrorNotice({ error, onRetry, hasPrevious }: { error: CalculateError; onRetry: () => void; hasPrevious: boolean }) {
  const d = describeError(error);
  return (
    <div role="alert" className="results__error">
      <Callout tone="warn" title={d.title}>
        <p>{d.body}</p>
        {hasPrevious && <p className="muted">The numbers below are from before and may be out of date.</p>}
        <div className="row">
          {d.canRetry && <Button onClick={onRetry}>Try again</Button>}
          {d.fixAnswers && <ButtonLink to="/start/review">Check my answers</ButtonLink>}
          <ButtonLink variant="ghost" to="/">
            Home
          </ButtonLink>
        </div>
      </Callout>
    </div>
  );
}
