import { useCallback, useEffect, useRef, useState } from 'react';
import {
  calculate,
  type CalculateError,
  type CalculateRequest,
  type CalculateSuccess,
  type ClientOptions,
  type UnsupportedReason,
} from '../api';

/** What the screen can be in. `previous` keeps the last good answer visible (dimmed) while recalculating. */
export type LiveState =
  | { status: 'loading'; previous: CalculateSuccess | null }
  | { status: 'ok'; data: CalculateSuccess }
  | { status: 'knockout'; reasons: readonly UnsupportedReason[] }
  | { status: 'error'; error: CalculateError; previous: CalculateSuccess | null };

export interface LiveOptions {
  /** Wait this long after the last change before calling. Default 250 ms. The first call is immediate. */
  debounceMs?: number;
  /** Passed to the typed client (tests inject fetch). */
  client?: ClientOptions;
  /** Set false to skip calculating (e.g. a disabled what-if). */
  enabled?: boolean;
}

export interface Live {
  state: LiveState;
  /** Run the calculation again right now (the "try again" button). */
  retry: () => void;
}

/**
 * POST /calculate for `request`, debounced. A newer request aborts the one in flight, and a late
 * answer to an old request is ignored even if the transport does not honour the abort.
 * Memoize `request`: it is compared by reference.
 */
export function useLiveCalculation(request: CalculateRequest, opts: LiveOptions = {}): Live {
  const { debounceMs = 250, client, enabled = true } = opts;
  const [state, setState] = useState<LiveState>({ status: 'loading', previous: null });
  const [attempt, setAttempt] = useState(0);
  const retry = useCallback(() => setAttempt((n) => n + 1), []);
  const clientRef = useRef(client);
  clientRef.current = client;
  const lastGood = useRef<CalculateSuccess | null>(null);
  const ran = useRef(false);
  const lastAttempt = useRef(0);

  useEffect(() => {
    if (!enabled) return;
    const ctl = new AbortController();
    setState({ status: 'loading', previous: lastGood.current });
    const run = () => {
      ran.current = true;
      calculate(request, { ...clientRef.current, signal: ctl.signal }).then((r) => {
        if (ctl.signal.aborted) return;
        if (r.kind === 'ok') {
          lastGood.current = r.data;
          setState({ status: 'ok', data: r.data });
        } else if (r.kind === 'knockout') {
          lastGood.current = null;
          setState({ status: 'knockout', reasons: r.data.reasons });
        } else {
          setState({ status: 'error', error: r.error, previous: lastGood.current });
        }
      });
    };
    const immediate = !ran.current || attempt !== lastAttempt.current;
    lastAttempt.current = attempt;
    let timer: ReturnType<typeof setTimeout> | undefined;
    if (immediate) run();
    else timer = setTimeout(run, debounceMs);
    return () => {
      ctl.abort();
      if (timer !== undefined) clearTimeout(timer);
    };
  }, [request, attempt, enabled, debounceMs]);

  return { state, retry };
}
