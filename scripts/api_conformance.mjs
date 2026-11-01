#!/usr/bin/env node
// Cross-check of the Lean request validator (lean/UsTax/Api, `ustax api-parse`) against
// api/schema.json via ajv (issue #51). TEST-ONLY and UNTRUSTED: nothing here is part of the
// verified or trusted code; a pass is evidence, a failure is a bug in Lean, the schema, or this
// script.
//
// Corpus: every api/examples and api/fixtures request, a minimal and a "full" instance generated
// from the schema (every property present, a distinct integer in every money box), and mutants of
// the full instance at every property: wrong type, over/under the cap, float and exponent
// literals, bad enum, unknown field, missing required property, one item too many, wrong
// version/year, truncated text. For each case Lean and ajv must agree, except for the documented
// places where Lean is deliberately stricter (the schema cannot say these):
//   - integer-valued float literals (100.0, 1e2) in a money box (ajv's `integer` admits them),
//   - cross-field rules (SecondaryFiler on a non-joint return), impossible calendar dates.
// The same holds for the schema 1.2.0 cross-field rules (withheld list no longer than net_benefits,
// a secondary-filer HSA distribution on a non-joint return) and for bounded counts (months).
// Those must be rejected by Lean with the right code and accepted by ajv. Also checked: the error
// code and the first detail's path/code for each mutant, the 400 fixtures' bodies, and that every
// distinct integer in the "full" instance appears in Lean's reading (no field silently dropped).
//
// Usage: node scripts/api_conformance.mjs [--bin lean/.lake/build/bin/ustax]
// Needs: `cd lean && lake build ustax`, and `cd api && npm ci --ignore-scripts` (ajv 8.17.1).
import { createRequire } from 'node:module';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const bin = args.includes('--bin') ? args[args.indexOf('--bin') + 1] : join(root, 'lean/.lake/build/bin/ustax');
if (!existsSync(bin)) { console.error(`missing ${bin}: run \`cd lean && lake build ustax\``); process.exit(2); }
const require = createRequire(join(root, 'api/package.json'));
let Ajv2020;
try { Ajv2020 = require('ajv/dist/2020.js'); } catch { console.error('missing ajv: run `cd api && npm ci --ignore-scripts`'); process.exit(2); }

const schema = JSON.parse(readFileSync(join(root, 'api/schema.json'), 'utf8'));
const ajv = new Ajv2020({ strict: true, allErrors: true });
ajv.addSchema(schema);
const validate = ajv.getSchema(`${schema.$id}#/$defs/CalculateRequest`);
const CAP = 10 ** 13;

// ---- schema walking -------------------------------------------------------------------------
const resolveRef = (n) => {
  while (n.$ref) {
    const target = schema.$defs[n.$ref.replace('#/$defs/', '')];
    const { $ref, ...rest } = n;
    n = { ...target, ...rest };
  }
  return n;
};
const kindOf = (n) => n.const !== undefined ? 'const' : n.enum ? 'enum' : n.type;
const ptr = (path) => path.map((s) => '/' + String(s).replace(/~/g, '~0').replace(/\//g, '~1')).join('');

let counter = 7000;
// Build a full instance. `sites` lists every value position with its resolved schema node.
function build(node0, path, sites, opts) {
  const node = resolveRef(node0);
  const kind = kindOf(node);
  const site = { path, node, kind };
  sites.push(site);
  switch (kind) {
    case 'object': {
      const o = {};
      for (const [k, sub] of Object.entries(node.properties ?? {})) o[k] = build(sub, [...path, k], sites, opts);
      return o;
    }
    case 'array': return [build(node.items, [...path, 0], sites, opts)];
    case 'integer': return node.maximum !== undefined && node.maximum < CAP ? node.maximum : ++counter; // bounded counts (months) take their maximum
    case 'boolean': return true;
    case 'const': return node.const;
    case 'enum': return opts.enumPick(path, node.enum);
    case 'string': return '2000-01-31'; // the only string-typed request property is a date
    default: throw new Error(`unhandled schema node ${JSON.stringify(node)}`);
  }
}
const fullOpts = { enumPick: (path, vals) => (path.join('/') === 'filing_status' ? 'MarriedFilingJointly' : vals[vals.length - 1]) };
const sites = [];
const full = build({ $ref: '#/$defs/CalculateRequest' }, [], sites, fullOpts);
const siteOf = new Map(sites.map((s) => [ptr(s.path), s]));

function minimal() {
  const req = schema.$defs.CalculateRequest.required;
  return Object.fromEntries(req.map((k) => [k, k === 'filing_status' ? 'Single' : k === 'api_version' ? 1 : 2024]));
}

const RAW = '__RAW__';
const raw = (t) => `${RAW}${t}${RAW}`;
const clone = (x) => JSON.parse(JSON.stringify(x));
const getAt = (o, path) => path.reduce((a, k) => a[k], o);
function setAt(o, path, v) { if (path.length === 0) return v; getAt(o, path.slice(0, -1))[path.at(-1)] = v; return o; }
function delAt(o, path) { delete getAt(o, path.slice(0, -1))[path.at(-1)]; return o; }
const text = (o) => JSON.stringify(o).replace(new RegExp(`"${RAW}(.*?)${RAW}"`, 'g'), '$1');

// ---- corpus ---------------------------------------------------------------------------------
// A case: { name, text, expect: 'accept' | 'reject' | 'stricter', status?, code?, path?, fcode? }.
const cases = [];
const add = (c) => cases.push(c);
const accept = (name, o) => add({ name, text: typeof o === 'string' ? o : text(o), expect: 'accept' });
const reject = (name, o, code, path, fcode) =>
  add({ name, text: typeof o === 'string' ? o : text(o), expect: 'reject', code, path, fcode });
const stricter = (name, o, code, path, fcode) =>
  add({ name, text: typeof o === 'string' ? o : text(o), expect: 'stricter', code, path, fcode });

accept('minimal', minimal());
accept('full', full);
accept('full, pretty-printed', JSON.stringify(full, null, 2).replace(/\n\s*/g, ' '));

for (const s of sites) {
  const p = ptr(s.path);
  const label = p || '(root)';
  const mut = (v) => setAt(clone(full), s.path, v);
  if (s.path.length > 0 && s.path.join('/') !== 'api_version' && s.path.join('/') !== 'tax_year') {
    const k = s.kind;
    if (k === 'integer') {
      const signed = (s.node.minimum ?? 0) < 0;
      const hi = s.node.maximum ?? CAP, lo = s.node.minimum ?? 0; // schema 1.2.0 has bounded counts (months 0..12, coverage months 1..12)
      const inv = (name, v, code, fcode) => reject(`${label}: ${name}`, mut(v), code ?? 'invalid_request', p, fcode);
      inv(hi === CAP ? 'over cap' : `over max ${hi}`, hi + 1, 'invalid_request', 'range');
      inv(signed ? 'below -cap' : hi === CAP ? 'negative' : `below min ${lo}`, signed ? -CAP - 1 : lo - 1, 'invalid_request', 'range');
      if (hi !== CAP) add({ name: `${label}: at min ${lo}`, text: text(mut(lo)), expect: 'accept' });
      inv('string', '5', 'invalid_request', 'type');
      inv('null', null, 'invalid_request', 'type');
      inv('boolean', true, 'invalid_request', 'type');
      inv('decimal 1.5', raw('1.5'), 'invalid_request', 'not_integer');
      add({ name: `${label}: at ${hi === CAP ? 'cap' : 'max'}`, text: text(mut(hi)), expect: 'accept' });
      stricter(`${label}: 5.0`, mut(raw('5.0')), 'invalid_request', p, 'not_integer');
      stricter(`${label}: ${hi === CAP ? '1e2' : hi + 'e0'}`, mut(raw(hi === CAP ? '1e2' : hi + 'e0')), 'invalid_request', p, 'not_integer');
    } else if (k === 'boolean') {
      reject(`${label}: 1 for boolean`, mut(1), 'invalid_request', p, 'type');
      reject(`${label}: "true"`, mut('true'), 'invalid_request', p, 'type');
      accept(`${label}: false`, mut(false));
    } else if (k === 'enum') {
      reject(`${label}: bad enum`, mut('Bogus'), 'invalid_request', p, 'enum');
      reject(`${label}: enum as number`, mut(5), 'invalid_request', p, 'type');
      if (p !== '/filing_status') for (const v of s.node.enum) accept(`${label}: ${v}`, mut(v));
    } else if (k === 'string') {
      reject(`${label}: bad date format`, mut('2000/01/01'), 'invalid_request', p, 'type');
      reject(`${label}: date as number`, mut(20000131), 'invalid_request', p, 'type');
      stricter(`${label}: 2023-02-30`, mut('2023-02-30'), 'invalid_request', p, 'invalid_date');
      accept(`${label}: leap day`, mut('2024-02-29'));
    } else if (k === 'array') {
      reject(`${label}: array as object`, mut({}), 'invalid_request', p, 'type');
      const n = (s.node.maxItems ?? 20) + 1;
      const items = Array.from({ length: n }, () => clone(getAt(full, s.path)[0]));
      reject(`${label}: ${n} items`, mut(items), 'invalid_request', p, 'too_many_items');
      // cross-field rule (docs/api.md): federal_tax_withheld is no longer than net_benefits, so emptying
      // net_benefits must empty it too to stay schema-valid.
      if (p === '/social_security/net_benefits') accept(`${label}: empty`, delAt(mut([]), ['social_security', 'federal_tax_withheld']));
      else accept(`${label}: empty`, mut([]));
    } else if (k === 'object') {
      reject(`${label}: object as array`, mut([]), 'invalid_request', p, 'type');
      const u = clone(getAt(full, s.path)); u.zz_unknown = 1;
      reject(`${label}: unknown field`, setAt(clone(full), s.path, u), 'unknown_field', `${p}/zz_unknown`, 'unknown_field');
      for (const r of s.node.required ?? []) {
        if (s.path.length === 0 && ['api_version', 'tax_year'].includes(r)) continue;
        reject(`${label}: missing ${r}`, delAt(clone(full), [...s.path, r]), 'invalid_request', `${p}/${r}`, 'required');
      }
      if (s.path.length > 0) accept(`${label}: empty object`, mut(Object.fromEntries((s.node.required ?? []).map((r) => [r, getAt(full, s.path)[r]]))));
    }
  }
}
reject('api_version 2', { ...minimal(), api_version: 2 }, 'unsupported_api_version', '/api_version', 'enum');
reject('api_version 1.5', { ...minimal(), api_version: raw('1.5') }, 'invalid_request', '/api_version', 'not_integer');
reject('api_version "1"', { ...minimal(), api_version: '1' }, 'invalid_request', '/api_version', 'type');
reject('tax_year 2023', { ...minimal(), tax_year: 2023 }, 'unsupported_tax_year', '/tax_year', 'enum');
reject('tax_year 2025', { ...full, tax_year: 2025 }, 'unsupported_tax_year', '/tax_year', 'enum');
reject('tax_year string', { ...minimal(), tax_year: '2024' }, 'invalid_request', '/tax_year', 'type');
// Lean is stricter than ajv for the integer-valued float literals of the two constants.
stricter('api_version 1.0', { ...minimal(), api_version: raw('1.0') }, 'invalid_request', '/api_version', 'not_integer');
stricter('tax_year 2024.0', { ...minimal(), tax_year: raw('2024.0') }, 'invalid_request', '/tax_year', 'not_integer');
// Cross-field: every role is SecondaryFiler in `full`; on a non-joint return Lean must refuse.
stricter('secondary roles on Single', { ...full, filing_status: 'Single' }, 'invalid_request', undefined, 'filer_not_allowed');
// Cross-field (schema 1.2.0): more withheld amounts than benefit amounts; and an HSA distribution of the
// secondary filer on a return that is not joint.
stricter('federal_tax_withheld longer than net_benefits', setAt(clone(full), ['social_security', 'federal_tax_withheld'], [1, 2]),
  'invalid_request', '/social_security/federal_tax_withheld', 'range');
stricter('SecondaryFiler HSA distribution on Single', { ...minimal(), adjustments: { hsa: { hsa_distributions: [getAt(full, ['adjustments', 'hsa', 'hsa_distributions', 0])] } } },
  'invalid_request', '/adjustments/hsa/hsa_distributions/0/filer', 'filer_not_allowed');
stricter('filers.secondary on Single', { ...minimal(), filers: { secondary: { date_of_birth: '1980-01-01' } } },
  'invalid_request', '/filers/secondary', 'filer_not_allowed');
const full_text = text(full);
for (const n of [0, 1, 2, 5, 17, 100, 333, 1000, Math.floor(full_text.length / 2), full_text.length - 1]) {
  add({ name: `truncated at ${n}`, text: full_text.slice(0, n), expect: 'reject', code: 'invalid_json' });
}
add({ name: 'trailing garbage', text: full_text + ' x', expect: 'reject', code: 'invalid_json' });
add({ name: 'array at top level', text: '[]', expect: 'reject', code: 'invalid_request', path: '', fcode: 'type' });
add({ name: 'string at top level', text: '"x"', expect: 'reject', code: 'invalid_request', path: '', fcode: 'type' });
add({ name: 'duplicate key (Lean rejects, JSON.parse keeps last)', text: '{"api_version":1,"api_version":1}', expect: 'lean-only-reject', code: 'invalid_json' });

// ---- examples and fixtures ------------------------------------------------------------------
const examplesDir = join(root, 'api/examples');
for (const f of readdirSync(examplesDir).filter((f) => f.endsWith('.request.json'))) {
  add({ name: `example ${f}`, text: JSON.stringify(JSON.parse(readFileSync(join(examplesDir, f), 'utf8'))), expect: 'accept' });
}
const manifest = JSON.parse(readFileSync(join(root, 'api/fixtures/manifest.json'), 'utf8')).fixtures;
for (const e of manifest) {
  if (!e.request || e.path !== '/calculate') continue;
  const reqText = JSON.stringify(JSON.parse(readFileSync(join(root, 'api', e.request), 'utf8').length ? readFileSync(join(root, 'api', e.request), 'utf8') : '{}'));
  const resp = JSON.parse(readFileSync(join(root, 'api', e.response), 'utf8'));
  if (e.status === 400) add({ name: `fixture ${e.name}`, text: reqText, expect: e.semantic_error ? 'stricter-fixture' : 'reject', fixture: resp, code: resp.error.code });
  else if (e.status === 200 || e.status === 422) add({ name: `fixture ${e.name}`, text: reqText, expect: 'accept' });
}

// ---- the 422 reason table of the binary vs api/knockout-reasons.json ---------------------------
const reasonsRun = spawnSync(bin, ['api-reasons'], { encoding: 'utf8' });
if (reasonsRun.status !== 0) { console.error(reasonsRun.stderr); process.exit(2); }
const leanReasons = JSON.parse(reasonsRun.stdout);
const jsonReasons = JSON.parse(readFileSync(join(root, 'api/knockout-reasons.json'), 'utf8')).reasons.map(({ code, category, message }) => ({ code, category, message }));
const reasonSchema = schema.$defs.ReasonCategory.enum;

// ---- run ------------------------------------------------------------------------------------
const lines = cases.map((c) => { if (c.text.includes('\n')) throw new Error(`newline in case ${c.name}`); return c.text; });
const run = spawnSync(bin, ['api-parse'], { input: lines.join('\n') + '\n', encoding: 'utf8', maxBuffer: 1 << 28 });
if (run.status !== 0) { console.error(run.stderr); process.exit(2); }
const out = run.stdout.split('\n').filter((l) => l.length);
if (out.length !== cases.length) { console.error(`Lean answered ${out.length} lines for ${cases.length} cases`); process.exit(2); }

const counts = { cases: cases.length, 'agree: accept': 0, 'agree: reject': 0, 'lean stricter (documented)': 0, 'lean-only reject': 0, 'fixture bodies matched': 0 };
const failures = [];
const fail = (c, why) => failures.push(`${c.name}: ${why}\n    ${c.text.slice(0, 160)}`);
let droppedChecks = 0;
cases.forEach((c, i) => {
  const [status, body] = [Number(out[i].split('\t')[0]), out[i].slice(out[i].indexOf('\t') + 1)];
  let parsed; try { parsed = JSON.parse(c.text); } catch { parsed = undefined; }
  const ajvOk = parsed !== undefined && validate(parsed);
  const err = status === 400 ? JSON.parse(body) : undefined;
  const firstDetail = err?.error?.details?.[0];
  const checkShape = () => {
    if (c.code && err?.error?.code !== c.code) fail(c, `error.code ${err?.error?.code}, want ${c.code}`);
    if (c.path !== undefined || c.fcode) {
      const hit = (err?.error?.details ?? []).some((d) => (c.path === undefined || d.path === c.path) && (!c.fcode || d.code === c.fcode));
      if (!hit) fail(c, `no detail with path ${c.path} code ${c.fcode}; got ${JSON.stringify(err?.error?.details)}`);
    }
  };
  switch (c.expect) {
    case 'accept':
      if (status !== 200) fail(c, `Lean rejected (${body.slice(0, 200)})`);
      else if (!ajvOk) fail(c, 'Lean accepted but ajv rejects');
      else counts['agree: accept']++;
      break;
    case 'reject':
      if (status !== 400) fail(c, `Lean answered ${status}, want 400`);
      else if (ajvOk) fail(c, 'ajv accepts but expected rejection');
      else { counts['agree: reject']++; checkShape(); }
      break;
    case 'stricter':
      if (status !== 400) fail(c, `Lean answered ${status}, want 400`);
      else if (!ajvOk) fail(c, 'expected ajv to accept (documented stricter case)');
      else { counts['lean stricter (documented)']++; checkShape(); }
      break;
    case 'stricter-fixture':
      if (status !== 400) fail(c, `Lean answered ${status}, want 400`);
      else if (!ajvOk) fail(c, 'expected ajv to accept');
      else counts['lean stricter (documented)']++;
      break;
    case 'lean-only-reject':
      if (status !== 400) fail(c, `Lean answered ${status}, want 400`); else { counts['lean-only reject']++; checkShape(); }
      break;
  }
  if (c.fixture) {
    // Byte-for-byte modulo key order: deep equality of the parsed bodies.
    if (JSON.stringify(sortKeys(err)) === JSON.stringify(sortKeys(c.fixture))) counts['fixture bodies matched']++;
    else fail(c, `body differs from fixture:\n    lean:    ${body}\n    fixture: ${JSON.stringify(c.fixture)}`);
  }
  if (c.name === 'full' && status === 200) {
    const seen = new Set(body.match(/-?\d+/g));
    for (const s of sites) if (s.kind === 'integer' && !(s.node.maximum < CAP)) {
      const v = String(getAt(full, s.path));
      droppedChecks++;
      if (!seen.has(v)) fail(c, `field ${ptr(s.path)} (value ${v}) is missing from Lean's reading: silently dropped`);
    }
  }
});
function sortKeys(x) {
  if (Array.isArray(x)) return x.map(sortKeys);
  if (x && typeof x === 'object') return Object.fromEntries(Object.keys(x).sort().map((k) => [k, sortKeys(x[k])]));
  return x;
}
counts['money boxes found in Lean output'] = droppedChecks;
counts['knockout reasons in Lean table'] = leanReasons.length;
if (JSON.stringify(leanReasons) !== JSON.stringify(jsonReasons)) {
  failures.push(`Lean reason table (${leanReasons.length}) differs from api/knockout-reasons.json (${jsonReasons.length}): run python3 scripts/gen_lean_api_reasons.py and rebuild`);
}
for (const r of leanReasons) if (!reasonSchema.includes(r.category)) failures.push(`reason ${r.code}: category ${r.category} is not in schema ReasonCategory`);
console.log(JSON.stringify(counts, null, 2));
if (failures.length) {
  console.error(`\n${failures.length} FAILURE(S):`);
  for (const f of failures.slice(0, 40)) console.error('  - ' + f);
  process.exit(1);
}
console.log('api_conformance: all cases agree');
