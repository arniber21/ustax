/**
 * Mock mode: a `fetch` stand-in that serves api/fixtures (api/fixtures/manifest.json), so the UI can be
 * built before the backend exists. Enabled with VITE_API_MOCK=1. A POST /calculate request matches the
 * fixture whose request body is deeply equal; anything else gets a clearly labelled 400.
 */
import manifestJson from '../../../api/fixtures/manifest.json';

const files = import.meta.glob('../../../api/{examples,fixtures}/*.json', {
  eager: true,
  import: 'default',
}) as Record<string, unknown>;

interface Entry {
  name: string;
  method: string;
  path: string;
  status: number;
  request?: string;
  response: string;
  content_type?: string;
}

const entries = manifestJson.fixtures as Entry[];

const load = (rel: string): unknown => {
  const hit = Object.entries(files).find(([k]) => k.endsWith(`/api/${rel}`));
  if (!hit) throw new Error(`mock: fixture file api/${rel} not bundled`);
  return hit[1];
};

function canon(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(canon).join(',')}]`;
  if (v && typeof v === 'object') {
    const o = v as Record<string, unknown>;
    return `{${Object.keys(o)
      .sort()
      .map((k) => `${JSON.stringify(k)}:${canon(o[k])}`)
      .join(',')}}`;
  }
  return JSON.stringify(v);
}

const json = (status: number, body: unknown): Response =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });

const byName = (name: string): Entry => {
  const e = entries.find((x) => x.name === name);
  if (!e) throw new Error(`mock: no fixture ${name}`);
  return e;
};
const reply = (e: Entry): Response => json(e.status, load(e.response));

/** `fetch`-compatible handler backed by the fixtures. */
export const mockFetch: typeof fetch = async (input, init) => {
  const url = new URL(typeof input === 'string' ? input : input instanceof URL ? input.href : input.url);
  const method = (init?.method ?? 'GET').toUpperCase();
  const path = url.pathname;

  if (path === '/calculate') {
    if (method !== 'POST') return reply(byName('error-405-method-not-allowed'));
    const headers = new Headers(init?.headers);
    if (!(headers.get('Content-Type') ?? '').startsWith('application/json')) {
      return reply(byName('error-415-unsupported-media-type'));
    }
    let body: unknown;
    try {
      body = JSON.parse(String(init?.body ?? ''));
    } catch {
      return reply(byName('error-400-invalid-json'));
    }
    const want = canon(body);
    // 415 and 500 fixtures reuse a valid request; they are not the answer to it.
    const hit = entries.find(
      (e) =>
        e.method === 'POST' &&
        e.path === '/calculate' &&
        e.request &&
        e.status !== 415 &&
        e.status !== 500 &&
        canon(load(e.request)) === want,
    );
    if (hit) return reply(hit);
    return json(400, {
      api_version: 1,
      error: {
        code: 'invalid_request',
        message: 'mock mode: no fixture matches this request (see api/fixtures/manifest.json)',
      },
    });
  }
  const known = entries.find((e) => e.method === method && e.path === path && e.status < 300 && !e.request);
  if (known) return reply(known);
  return reply(byName('error-404-not-found'));
};
