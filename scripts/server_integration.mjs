// Integration tests for the Lean HTTP server (issue #57). Test-only; no dependencies, node >= 18.
//
//   node scripts/server_integration.mjs [base-url]      (default http://127.0.0.1:8080, or $BASE_URL)
//
// Runs every entry of api/fixtures/manifest.json against a live server and compares status and body
// with the fixture (JSON equality, key order ignored), then CORS and extra error cases. The fixtures were
// generated from the Catala ApiCalculator (`make api-examples`); since the Lean Calculator (issue #48) the
// server computes the whole return, so every one of them (credits, dependents, household knockouts) is
// expected to match exactly. An entry is reported SKIP, with the reason, only when it cannot be
// reproduced over HTTP (500); a skip is never counted as a pass. The summary lists every skip.
// Exit 1 on any failure.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const api = join(dirname(fileURLToPath(import.meta.url)), '..', 'api');
const base = (process.argv[2] ?? process.env.BASE_URL ?? 'http://127.0.0.1:8080').replace(/\/$/, '');
const ORIGIN = process.env.ALLOW_ORIGIN?.split(',')[0] ?? 'http://localhost:5173';
const read = (p) => JSON.parse(readFileSync(join(api, p), 'utf8'));
const readText = (p) => readFileSync(join(api, p), 'utf8');

let pass = 0, fail = 0, skip = 0;
const skippedNames = [];
const ok = (name) => { pass++; console.log(`PASS ${name}`); };
const bad = (name, why) => { fail++; console.log(`FAIL ${name}: ${why}`); };
const skipped = (name, why) => { skip++; skippedNames.push(name); console.log(`SKIP ${name}: ${why}`); };

// Key-order-insensitive canonical form.
const canon = (v) => Array.isArray(v) ? v.map(canon)
  : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, canon(v[k])])) : v;
const same = (a, b) => JSON.stringify(canon(a)) === JSON.stringify(canon(b));

async function call(method, path, { body, type = 'application/json', headers = {} } = {}) {
  const h = { ...headers };
  if (body !== undefined && type) h['Content-Type'] = type;
  const res = await fetch(base + path, { method, headers: h, body });
  const text = await res.text();
  let json; try { json = JSON.parse(text); } catch { json = undefined; }
  return { status: res.status, headers: res.headers, text, json };
}

function expectBody(name, r, status, want) {
  if (r.status !== status) return bad(name, `status ${r.status}, want ${status}: ${r.text.slice(0, 200)}`);
  if (want !== undefined && !same(r.json, want)) {
    return bad(name, `body differs\n  got  ${r.text.slice(0, 600)}\n  want ${JSON.stringify(want).slice(0, 600)}`);
  }
  if (!(r.headers.get('content-type') ?? '').startsWith('application/json')) return bad(name, 'content-type is not application/json');
  ok(name);
}

// ---- 1. every fixture of the manifest ----
for (const e of read('fixtures/manifest.json').fixtures) {
  const name = `fixture ${e.name}`;
  const want = read(e.response);
  try {
    if (e.status === 500) { skipped(name, 'server fault cannot be provoked from a request'); continue; }
    if (e.path === '/version') {
      const r = await call('GET', '/version');
      const { calculator_version: _a, ...got } = r.json ?? {};
      const { calculator_version: _b, ...exp } = want;
      if (r.status === 200 && same(got, exp) && typeof r.json.calculator_version === 'string') ok(name); else bad(name, r.text);
    } else if (e.name === 'error-400-invalid-json') {
      const r = await call('POST', '/calculate', { body: '{bad' });
      if (r.status !== 400 || r.json?.error?.code !== 'invalid_json' || r.json?.api_version !== 1) bad(name, r.text); else ok(name);
    } else if (e.name === 'error-413-payload-too-large') {
      const r = await call('POST', '/calculate', { body: ' '.repeat(262145) });
      expectBody(name, r, 413, want);
    } else if (e.method === 'GET') {
      expectBody(name, await call('GET', e.path), e.status, want);
    } else {
      const body = readText(e.request);
      const r = await call('POST', e.path, { body, type: e.content_type ?? 'application/json' });
      expectBody(name, r, e.status, want);
    }
  } catch (err) { bad(name, String(err)); }
}

// ---- 2. error classes not covered by a fixture ----
const small = readText('examples/single-w2-50k.request.json');
{
  const exact = ' '.repeat(262144 - small.length) + small; // exactly the cap: accepted
  expectBody('body of exactly 262144 bytes is accepted', await call('POST', '/calculate', { body: exact }), 200);
}
expectBody('415 for a missing content type', await call('POST', '/calculate', { body: small, type: null }), 415);
expectBody('charset parameter on application/json is accepted',
  await call('POST', '/calculate', { body: small, type: 'application/json; charset=utf-8' }), 200);
{
  const r = await call('POST', '/calculate', { body: new Uint8Array([0x7b, 0xff, 0xfe, 0x7d]) });
  if (r.status === 400 && r.json?.error?.code === 'invalid_json') ok('invalid UTF-8 body is 400 invalid_json'); else bad('invalid UTF-8 body', `${r.status} ${r.text}`);
}
for (const m of ['PUT', 'DELETE']) {
  expectBody(`${m} /calculate is 405`, await call(m, '/calculate'), 405);
}
expectBody('POST /health is 405', await call('POST', '/health', { body: '{}' }), 405);
expectBody('GET / is 404', await call('GET', '/'), 404);
expectBody('GET /calculate/extra is 404', await call('GET', '/calculate/extra'), 404);
{
  const r = await call('GET', '/health');
  if (!r.text.includes('Internal') && r.json?.status === 'ok') ok('GET /health'); else bad('GET /health', r.text);
}

// ---- 3. every section is read; only superseded 1.0 fields warn ----
{
  const req = JSON.parse(small);
  req.form_1099g = [{ filer: 'PrimaryFiler', unemployment_compensation: 100000 }];
  req.estimated_payments = { paid_estimated_taxes_or_from_last_year: true, amount: 1000 };
  const r = await call('POST', '/calculate', { body: JSON.stringify(req) });
  const lines = read('examples/single-w2-50k.response.json').lines;
  // $1,000 of unemployment compensation (line 8) and $10 of estimated payments (line 26) are counted
  if (r.status === 200 && !('warnings' in r.json) && r.json.lines.total_income === lines.total_income + 100000
      && r.json.lines.total_payments === lines.total_payments + 1000) ok('1099-G and estimated payments are read: 200, lines include them, no warning');
  else bad('1099-G and estimated payments', r.text.slice(0, 500));
  // schema 1.2.0 sections are read (a child gives the child tax credit); the superseded flag warns
  const r2 = JSON.parse(small);
  r2.filing_details = { treat_as_mfs: false, has_foreign_accounts_or_trusts: false };
  r2.filers = { primary: { date_of_birth: '1990-01-01', is_student: true } };
  r2.dependents = [{ relationship: 'BiologicalChild', date_of_birth: '2015-05-05', tin_type: 'Ssn' }];
  r2.credits = { eitc_had_improper_claims: false };
  r2.screening = { made_ira_contributions: false };
  const a = await call('POST', '/calculate', { body: JSON.stringify(r2) });
  const got = (a.json?.warnings ?? []).map((x) => `${x.code} ${x.path}`).sort().join(', ');
  if (a.status === 200 && got === 'field_superseded /filing_details/treat_as_mfs' && a.json.lines.non_refundable_credits === 200000)
    ok('schema 1.2.0 sections: 200, child tax credit computed, only field_superseded warns');
  else bad('schema 1.2.0 sections', `${a.status} ${got} | ${a.text.slice(0, 300)}`);
  const clean = await call('POST', '/calculate', { body: small });
  if (clean.json && !('warnings' in clean.json)) ok('no warnings key when nothing is superseded'); else bad('warnings key on a clean request', clean.text.slice(0, 200));
}

// ---- 4. CORS ----
{
  const pre = await call('OPTIONS', '/calculate', { headers: { Origin: ORIGIN, 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'content-type' } });
  const h = pre.headers;
  if (pre.status === 204 && h.get('access-control-allow-origin') === ORIGIN && /POST/.test(h.get('access-control-allow-methods') ?? '')
      && /content-type/i.test(h.get('access-control-allow-headers') ?? '') && h.get('vary')?.includes('Origin')) ok('CORS preflight from the allowed origin');
  else bad('CORS preflight', `${pre.status} ${JSON.stringify([...h])}`);

  const evil = await call('OPTIONS', '/calculate', { headers: { Origin: 'http://evil.example', 'Access-Control-Request-Method': 'POST' } });
  if ([...evil.headers.keys()].some((k) => k.startsWith('access-control-'))) bad('preflight from a disallowed origin', 'has CORS headers'); else ok('preflight from a disallowed origin has no CORS headers');

  const post = await call('POST', '/calculate', { body: small, headers: { Origin: ORIGIN } });
  if (post.headers.get('access-control-allow-origin') === ORIGIN) ok('POST from the allowed origin carries Allow-Origin'); else bad('POST CORS header', JSON.stringify([...post.headers]));

  const evilPost = await call('POST', '/calculate', { body: small, headers: { Origin: 'http://evil.example' } });
  if (evilPost.headers.get('access-control-allow-origin') === null) ok('POST from a disallowed origin has no Allow-Origin'); else bad('POST from a disallowed origin', 'has Allow-Origin');

  const err = await call('GET', '/nope', { headers: { Origin: ORIGIN } });
  if (err.status === 404 && err.headers.get('access-control-allow-origin') === ORIGIN) ok('error responses carry CORS headers too'); else bad('CORS on 404', `${err.status}`);

  const none = await call('GET', '/health');
  if (none.headers.get('access-control-allow-origin') === null) ok('no Origin, no CORS headers'); else bad('CORS without Origin', 'has Allow-Origin');
}

console.log(`\n${pass} passed, ${fail} failed, ${skip} skipped`);
if (skippedNames.length) console.log(`skipped (${skippedNames.length}): ${skippedNames.join(', ')}`);
process.exit(fail === 0 ? 0 : 1);
