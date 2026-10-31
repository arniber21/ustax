// make api-check: validate api/examples and api/fixtures against api/schema.json
// and cross-check them with the Catala-derived files. Needs `npm ci` in api/.
import Ajv2020 from 'ajv/dist/2020.js';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const api = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => JSON.parse(readFileSync(join(api, p), 'utf8'));
let failures = 0;
const fail = (msg) => { failures++; console.error('FAIL ' + msg); };

const schema = read('schema.json');
const ajv = new Ajv2020({ strict: true, allErrors: true });
ajv.addSchema(schema);
const validator = (name) => ajv.getSchema(`${schema.$id}#/$defs/${name}`);
const V = Object.fromEntries(
  ['CalculateRequest', 'CalculateSuccess', 'CalculateUnsupported', 'ErrorResponse', 'HealthResponse', 'VersionResponse']
    .map((n) => [n, validator(n)]),
);
const must = (name, file, doc) => {
  if (!V[name](doc)) fail(`${file} is not a valid ${name}: ${ajv.errorsText(V[name].errors)}`);
};

// Generated and hand-kept companions of the schema.
if (spawnSync('node', [join(api, 'scripts/gen-reasons.mjs'), '--check'], { stdio: 'inherit' }).status !== 0) failures++;
const reasons = read('knockout-reasons.json');
const byCode = new Map(reasons.reasons.map((r) => [r.code, r]));
const sameSet = (a, b) => a.length === b.length && a.every((x) => b.includes(x));
if (!sameSet(schema.$defs.ReasonCategory.enum, reasons.categories)) fail('schema ReasonCategory enum differs from knockout-reasons.json categories');
const catalogKeys = read('line-catalog.json').lines.map((l) => l.key);
if (!sameSet(schema.$defs.Lines.required, catalogKeys)) fail('schema Lines.required differs from line-catalog.json keys');

const checkSuccess = (file, d) => {
  const l = d.lines;
  const eq = (a, b, what) => { if (a !== b) fail(`${file}: ${what} (${a} != ${b})`); };
  eq(l.agi, l.total_income - l.adjustments_to_income, 'agi = total_income - adjustments_to_income');
  eq(l.taxable_income, Math.max(0, l.agi - l.total_deductions), 'taxable_income = max(0, agi - total_deductions)');
  eq(l.overpayment, Math.max(0, l.total_payments - l.total_tax), 'overpayment = max(0, payments - tax)');
  eq(l.balance_due, Math.max(0, l.total_tax - l.total_payments), 'balance_due = max(0, tax - payments)');
  eq(l.total_payments, l.total_withholding + l.total_other_payments_refundable_credits, 'total_payments = withholding + other (no estimated payments in fixtures)');
  eq(d.outcome, l.overpayment > 0 ? 'refund' : l.balance_due > 0 ? 'balance_due' : 'even', 'outcome');
  for (const [k, v] of Object.entries(l)) if (v < 0) fail(`${file}: line ${k} is negative`);
};

const manifest = read('fixtures/manifest.json').fixtures;
const names = new Set();
const statuses = new Set();
for (const e of manifest) {
  if (names.has(e.name)) fail(`duplicate fixture name ${e.name}`);
  names.add(e.name);
  const resp = read(e.response);
  const req = e.request ? read(e.request) : undefined;
  if (e.path === '/health') must('HealthResponse', e.response, resp);
  else if (e.path === '/version') must('VersionResponse', e.response, resp);
  else if (e.status === 200) { must('CalculateSuccess', e.response, resp); checkSuccess(e.response, resp); }
  else if (e.status === 422) must('CalculateUnsupported', e.response, resp);
  else must('ErrorResponse', e.response, resp);
  if (e.status >= 400 && e.status !== 422 && resp.error) {
    const want = { 400: ['invalid_json', 'invalid_request', 'unknown_field', 'unsupported_api_version', 'unsupported_tax_year'], 404: ['not_found'], 405: ['method_not_allowed'], 413: ['payload_too_large'], 415: ['unsupported_media_type'], 500: ['internal_error'] }[e.status];
    if (!want?.includes(resp.error.code)) fail(`${e.name}: error code ${resp.error.code} does not belong to HTTP ${e.status}`);
  }
  if (req) {
    const valid = V.CalculateRequest(req);
    if (e.status === 400 && !e.semantic_error) {
      if (valid) fail(`${e.request} should violate the schema (HTTP 400) but is valid`);
    } else if (e.status === 400 || e.status === 415 || e.status === 500 || e.status === 200 || e.status === 422) {
      if (!valid) fail(`${e.request} is not a valid CalculateRequest: ${ajv.errorsText(V.CalculateRequest.errors)}`);
    }
  }
  for (const r of resp.reasons ?? []) {
    const known = byCode.get(r.code);
    if (!known) fail(`${e.name}: reason ${r.code} is not in knockout-reasons.json`);
    else if (known.category !== r.category) fail(`${e.name}: reason ${r.code} has category ${r.category}, expected ${known.category}`);
  }
  statuses.add(e.status);
}

// Every example file is in the manifest; one example per filing status.
const examples = readdirSync(join(api, 'examples')).filter((f) => f.endsWith('.request.json'));
for (const f of examples) if (!manifest.some((e) => e.request === `examples/${f}`)) fail(`examples/${f} is not in fixtures/manifest.json`);
const statusesCovered = new Set(examples.map((f) => read(`examples/${f}`).filing_status));
for (const fs of schema.$defs.FilingStatus.enum) if (!statusesCovered.has(fs)) fail(`no example for filing status ${fs}`);
for (const need of [200, 400, 413, 422]) if (!statuses.has(need)) fail(`no fixture with HTTP ${need}`);

if (failures) { console.error(`api-check: ${failures} failure(s)`); process.exit(1); }
console.log(`api-check ok: ${manifest.length} fixtures, ${examples.length} example requests, ${reasons.reasons.length} reason codes`);
