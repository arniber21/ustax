import { describe, expect, it, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { calculate, contractProblems, mockFetch } from './index';
import type { CalculateRequest } from './index';

const apiDir = join(__dirname, '../../../api');
const read = (rel: string): unknown => JSON.parse(readFileSync(join(apiDir, rel), 'utf8'));

interface Entry {
  name: string;
  method: string;
  path: string;
  status: number;
  request?: string;
  response: string;
}
const fixtures = (read('fixtures/manifest.json') as { fixtures: Entry[] }).fixtures;
const calcFixtures = fixtures.filter((f) => f.method === 'POST' && f.path === '/calculate');

const respondWith = (status: number, body: unknown): typeof fetch =>
  async () => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

const anyRequest = read('examples/single-w2-50k.request.json') as CalculateRequest;

describe('manifest coverage', () => {
  it('has supported, knockout and error fixtures', () => {
    const statuses = new Set(calcFixtures.map((f) => f.status));
    for (const s of [200, 422, 400, 413, 415, 500]) expect(statuses.has(s)).toBe(true);
  });
});

describe.each(calcFixtures)('calculate: $name (HTTP $status)', (f) => {
  const body = read(f.response);
  const req = (f.request ? read(f.request) : anyRequest) as CalculateRequest;

  it('maps the server response to the right variant', async () => {
    const r = await calculate(req, { fetch: respondWith(f.status, body) });
    if (f.status === 200) {
      expect(r.kind).toBe('ok');
      if (r.kind === 'ok') expect(r.data).toEqual(body);
    } else if (f.status === 422) {
      expect(r.kind).toBe('knockout');
      if (r.kind === 'knockout') expect(r.data.reasons.length).toBeGreaterThan(0);
    } else {
      expect(r.kind).toBe('error');
      if (r.kind === 'error') {
        expect(r.error.type).toBe('http');
        if (r.error.type === 'http') {
          expect(r.error.status).toBe(f.status);
          expect(r.error.body).toEqual(body);
        }
      }
    }
  });

  if (f.request && f.status !== 415 && f.status !== 500) {
    it('is served by mock mode for its request', async () => {
      const r = await calculate(req, { mock: true });
      expect(r.kind === 'ok' || r.kind === 'knockout' || r.kind === 'error').toBe(true);
      if (f.status === 200) expect(r).toMatchObject({ kind: 'ok', data: body });
      else if (f.status === 422) expect(r).toMatchObject({ kind: 'knockout', data: body });
      else expect(r).toMatchObject({ kind: 'error', error: { type: 'http', status: f.status, body } });
    });
  }
});

describe('mock mode transport errors', () => {
  it('415 for a non-JSON content type', async () => {
    const res = await mockFetch('http://x/calculate', { method: 'POST', headers: { 'Content-Type': 'text/plain' }, body: '{}' });
    expect(res.status).toBe(415);
  });
  it('400 invalid_json for a broken body', async () => {
    const res = await mockFetch('http://x/calculate', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{bad' });
    expect(res.status).toBe(400);
  });
  it('405 and 404', async () => {
    expect((await mockFetch('http://x/calculate')).status).toBe(405);
    expect((await mockFetch('http://x/nope')).status).toBe(404);
  });
  it('an unmatched request is a labelled 400', async () => {
    const r = await calculate({ ...anyRequest, filing_status: 'HeadOfHousehold' }, { mock: true });
    expect(r).toMatchObject({ kind: 'error', error: { type: 'http', status: 400 } });
  });
});

describe('GET fixtures satisfy the contract', () => {
  it.each(fixtures.filter((f) => f.method === 'GET' && f.status === 200))('$name', async (f) => {
    const res = await mockFetch(`http://x${f.path}`);
    expect(res.status).toBe(200);
    const type = f.path === '/health' ? 'HealthResponse' : 'VersionResponse';
    expect(contractProblems(type, await res.json())).toEqual([]);
  });
});

describe('request and base URL', () => {
  it('POSTs JSON to baseUrl/calculate', async () => {
    const spy = vi.fn(respondWith(200, read('examples/single-w2-50k.response.json')));
    await calculate(anyRequest, { fetch: spy, baseUrl: 'http://example.test:9/' });
    const [url, init] = spy.mock.calls[0]!;
    expect(url).toBe('http://example.test:9/calculate');
    expect(init?.method).toBe('POST');
    expect(JSON.parse(String(init?.body))).toEqual(anyRequest);
  });
  it('defaults to http://localhost:8080', async () => {
    const spy = vi.fn(respondWith(200, read('examples/single-w2-50k.response.json')));
    await calculate(anyRequest, { fetch: spy });
    expect(spy.mock.calls[0]![0]).toBe('http://localhost:8080/calculate');
  });
});

describe('failures surface as typed values', () => {
  const quiet = () => vi.spyOn(console, 'error').mockImplementation(() => {});

  it('network failure', async () => {
    const r = await calculate(anyRequest, {
      fetch: async () => {
        throw new TypeError('Failed to fetch');
      },
    });
    expect(r).toEqual({ kind: 'error', error: { type: 'network', message: 'Failed to fetch' } });
  });
  it('contract drift in a 200 body', async () => {
    const spy = quiet();
    const bad = { ...(read('examples/single-w2-50k.response.json') as object), outcome: 'maybe' };
    const r = await calculate(anyRequest, { fetch: respondWith(200, bad) });
    expect(r).toMatchObject({ kind: 'error', error: { type: 'contract', status: 200 } });
    expect(spy).toHaveBeenCalled();
    spy.mockRestore();
  });
  it('a float in a money line is rejected', async () => {
    const spy = quiet();
    const good = read('examples/single-w2-50k.response.json') as { lines: Record<string, number> };
    const bad = { ...good, lines: { ...good.lines, agi: 12.5 } };
    const r = await calculate(anyRequest, { fetch: respondWith(200, bad) });
    expect(r).toMatchObject({ kind: 'error', error: { type: 'contract' } });
    spy.mockRestore();
  });
  it('non-JSON body and unexpected status', async () => {
    const spy = quiet();
    const html: typeof fetch = async () => new Response('<html>', { status: 502 });
    expect(await calculate(anyRequest, { fetch: html })).toMatchObject({ kind: 'error', error: { type: 'contract', status: 502 } });
    expect(await calculate(anyRequest, { fetch: respondWith(503, { x: 1 }) })).toMatchObject({
      kind: 'error',
      error: { type: 'contract', status: 503 },
    });
    spy.mockRestore();
  });
  it('a malformed 422 body is drift', async () => {
    const spy = quiet();
    const r = await calculate(anyRequest, { fetch: respondWith(422, { api_version: 1 }) });
    expect(r).toMatchObject({ kind: 'error', error: { type: 'contract', status: 422 } });
    spy.mockRestore();
  });
});

describe('contractProblems', () => {
  it('validates requests, including the examples', () => {
    expect(contractProblems('CalculateRequest', anyRequest)).toEqual([]);
    expect(contractProblems('CalculateRequest', { ...anyRequest, typo: 1 }).length).toBeGreaterThan(0);
  });
});
