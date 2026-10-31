import { useEffect, useState } from 'react';
import { calculate, type CalculateRequest, type CalculateResult, type ClientOptions } from './api';

export type CalcState =
  | { status: 'loading'; previous: CalculateResult | null }
  | { status: 'done'; result: CalculateResult };

/**
 * Calls POST /calculate whenever `request` changes (compare by reference: memoize it).
 * While a new call is in flight the previous result stays available as `previous`, so
 * the UI can dim it instead of flashing empty. Debouncing is the caller's concern (#79).
 */
export function useCalculation(request: CalculateRequest, opts?: ClientOptions): CalcState {
  const [state, setState] = useState<CalcState>({ status: 'loading', previous: null });

  useEffect(() => {
    const ctl = new AbortController();
    setState((s) => ({ status: 'loading', previous: s.status === 'done' ? s.result : s.previous }));
    calculate(request, { ...opts, signal: ctl.signal }).then((result) => {
      if (!ctl.signal.aborted) setState({ status: 'done', result });
    });
    return () => ctl.abort();
  }, [request]);

  return state;
}
