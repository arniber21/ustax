import { useId, useMemo, useState } from 'react';
import { formatCents, type CalculateRequest, type ClientOptions, type Outcome } from '../api';
import { Callout, Card } from '../components';
import { useLiveCalculation } from './useLiveCalculation';

/** Slider range in whole dollars of extra (or less) tax withheld from the first paycheck source. */
export const WHAT_IF = { min: -2000, max: 3000, step: 1000 } as const;

/** The request with the first W-2's withholding shifted by `deltaDollars` (never below zero). Null if there is no W-2 to shift. */
export function withWithholding(request: CalculateRequest, deltaDollars: number): CalculateRequest | null {
  const first = request.w2s?.[0];
  if (!first || !request.w2s) return null;
  const base = first.federal_withholding ?? 0;
  const next = Math.max(0, base + deltaDollars * 100);
  const w2s = request.w2s.map((w, i) => (i === 0 ? { ...w, federal_withholding: next } : w)) as typeof request.w2s;
  return { ...request, w2s };
}

const isMock = () => import.meta.env.VITE_API_MOCK === '1';

function describe(outcome: Outcome, lines: { overpayment: number; balance_due: number }) {
  if (outcome === 'refund') return `You’d get back ${formatCents(lines.overpayment, { showCents: false })}`;
  if (outcome === 'balance_due') return `You’d owe ${formatCents(lines.balance_due, { showCents: false })}`;
  return 'You’d break even';
}

/** "What if my employer held back more or less?" Recomputes live; degrades gracefully when it cannot. */
export function WhatIf({ request, client }: { request: CalculateRequest; client?: ClientOptions }) {
  const id = useId();
  const [delta, setDelta] = useState(0);
  const shifted = useMemo(() => withWithholding(request, delta), [request, delta]);
  const usable = shifted !== null;
  const { state } = useLiveCalculation(shifted ?? request, { enabled: usable && delta !== 0, client });

  const sign = delta > 0 ? '+' : delta < 0 ? '−' : '';
  const label = delta === 0 ? 'As entered' : `${sign}${formatCents(Math.abs(delta) * 100, { showCents: false })} withheld`;

  return (
    <Card tone="sun" className="whatif" aria-labelledby={`${id}-h`}>
      <h2 id={`${id}-h`}>What if…?</h2>
      {!usable ? (
        <p className="muted">Add a W-2 to your answers and you can slide the tax your employer holds back to see what it would change.</p>
      ) : (
        <>
          <label htmlFor={id} className="whatif__label">
            If your employer held back different tax: <strong>{label}</strong>
          </label>
          <input
            id={id}
            className="whatif__slider"
            type="range"
            min={WHAT_IF.min}
            max={WHAT_IF.max}
            step={WHAT_IF.step}
            value={delta}
            aria-valuetext={label}
            onChange={(e) => setDelta(Number(e.target.value))}
          />
          <div className="whatif__scale" aria-hidden="true">
            <span>{formatCents(WHAT_IF.min * -100, { showCents: false })} less</span>
            <span>{formatCents(WHAT_IF.max * 100, { showCents: false })} more</span>
          </div>
          <div className="whatif__answer" role="status" aria-live="polite">
            {delta === 0 && <span className="muted">Move the slider to try it.</span>}
            {delta !== 0 && state.status === 'ok' && <strong>{describe(state.data.outcome, state.data.lines)}</strong>}
            {delta !== 0 && state.status === 'loading' && <span className="muted">Working it out…</span>}
            {delta !== 0 && state.status === 'knockout' && <span>That change takes this return outside what we can do.</span>}
          </div>
          {delta !== 0 && state.status === 'error' && (
            <Callout tone="info" title="We can’t preview that one">
              {isMock()
                ? 'This demo only has a few ready-made scenarios. The live calculator works for any amount.'
                : 'We couldn’t reach the calculator for this preview. Your real result above is unaffected.'}
            </Callout>
          )}
          <p className="muted whatif__note">Nothing is saved. This is just for playing around.</p>
        </>
      )}
    </Card>
  );
}
