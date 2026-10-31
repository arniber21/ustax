import type { CalculateRequest, CalculateSuccess, CalculateUnsupported, ErrorResponse } from './types.gen';
import { contractProblems } from './validate';
import { mockFetch } from './mock';

export const DEFAULT_API_URL = 'http://localhost:8080';

/** Why a call produced no result. Every variant is a value; `calculate` does not throw. */
export type CalculateError =
  /** The server answered 400/404/405/413/415/500 with a contract-conformant ErrorResponse. */
  | { type: 'http'; status: number; body: ErrorResponse }
  /** No usable HTTP response (offline, CORS, DNS, aborted). */
  | { type: 'network'; message: string }
  /** The response broke the contract (wrong shape, non-JSON body, unexpected status): drift, report it. */
  | { type: 'contract'; status: number; problems: string[]; body: unknown };

/** Discriminated union over what POST /calculate can mean. */
export type CalculateResult =
  | { kind: 'ok'; status: 200; data: CalculateSuccess }
  | { kind: 'knockout'; status: 422; data: CalculateUnsupported }
  | { kind: 'error'; error: CalculateError };

export interface ClientOptions {
  /** Defaults to VITE_API_URL, then http://localhost:8080. */
  baseUrl?: string;
  /** Force mock mode on or off. Defaults to VITE_API_MOCK === '1'. */
  mock?: boolean;
  /** Inject a fetch (tests). Overrides mock. */
  fetch?: typeof fetch;
  signal?: AbortSignal;
}

const env = import.meta.env;

function resolveFetch(opts: ClientOptions): typeof fetch {
  if (opts.fetch) return opts.fetch;
  const mock = opts.mock ?? env.VITE_API_MOCK === '1';
  return mock ? mockFetch : (input, init) => fetch(input, init);
}

const contractError = (status: number, problems: string[], body: unknown): CalculateResult => {
  console.error(`API contract violation (HTTP ${status}):`, problems, body);
  return { kind: 'error', error: { type: 'contract', status, problems, body } };
};

/** POST /calculate. Money fields are integer cents. */
export async function calculate(request: CalculateRequest, opts: ClientOptions = {}): Promise<CalculateResult> {
  const baseUrl = (opts.baseUrl ?? env.VITE_API_URL ?? DEFAULT_API_URL).replace(/\/+$/, '');
  let res: Response;
  try {
    res = await resolveFetch(opts)(`${baseUrl}/calculate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify(request),
      signal: opts.signal,
    });
  } catch (e) {
    return { kind: 'error', error: { type: 'network', message: e instanceof Error ? e.message : String(e) } };
  }

  let body: unknown;
  try {
    body = await res.json();
  } catch {
    return contractError(res.status, ['response body is not JSON'], undefined);
  }

  if (res.status === 200) {
    const problems = contractProblems('CalculateSuccess', body);
    return problems.length ? contractError(200, problems, body) : { kind: 'ok', status: 200, data: body as CalculateSuccess };
  }
  if (res.status === 422) {
    const problems = contractProblems('CalculateUnsupported', body);
    return problems.length
      ? contractError(422, problems, body)
      : { kind: 'knockout', status: 422, data: body as CalculateUnsupported };
  }
  if ([400, 404, 405, 413, 415, 500].includes(res.status)) {
    const problems = contractProblems('ErrorResponse', body);
    return problems.length
      ? contractError(res.status, problems, body)
      : { kind: 'error', error: { type: 'http', status: res.status, body: body as ErrorResponse } };
  }
  return contractError(res.status, [`status ${res.status} is not in the contract`], body);
}
