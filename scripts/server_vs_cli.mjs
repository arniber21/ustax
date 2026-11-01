// Differential test of the HTTP server against the Lean CLI and, optionally, the Catala ApiCalculator
// (issues #52, #48). Test-only.
//
//   node scripts/server_vs_cli.mjs <base-url> <path to ustax binary> [cases=300]
//   CATALA_CASES=n  also compare the first n cases with `clerk run -s ApiCalculator` (needs clerk on PATH;
//                   slow, a few seconds per case; default 0)
//
// Every 200/422 request of api/fixtures/manifest.json and `cases` seeded random requests (W-2s, 1099-INT,
// 1099-G, SSA-1099, estimated payments, dependents, filing answers, legacy flags) are sent to the server
// and to `ustax api-calc` (the endpoint minus sockets: `UsTax.Api.calculate`). Status and body must be
// equal (JSON, key order ignored): this checks the HTTP framing, routing and serialisation of the server.
// With CATALA_CASES, the reference is also the Catala scope ApiCalculator on the same request (decoded by
// scripts/api_decode.mjs, encoded by scripts/api_catala.mjs): an independent implementation of the
// mapping and the whole return.
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const api = join(dirname(fileURLToPath(import.meta.url)), '..', 'api');
const base = (process.argv[2] ?? 'http://127.0.0.1:8080').replace(/\/$/, '');
const cli = process.argv[3] ?? join(api, '..', 'lean/.lake/build/bin/ustax');
const N = Number(process.argv[4] ?? 300);
const CATALA_CASES = Number(process.env.CATALA_CASES ?? 0);

// --- cases: every 200/422 request of the manifest, then seeded random ones ---
let seed = 20241031;
const rnd = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 2 ** 32);
const pick = (a) => a[Math.floor(rnd() * a.length)];
const amt = (max) => (rnd() < 0.15 ? 0 : Math.floor(rnd() * max));
const STATUSES = ['Single', 'MarriedFilingJointly', 'MarriedFilingSeparately', 'HeadOfHousehold', 'QualifyingSurvivingSpouse'];
function randomRequest() {
  const fs = pick(STATUSES), joint = fs === 'MarriedFilingJointly';
  const roles = joint ? ['PrimaryFiler', 'SecondaryFiler'] : ['PrimaryFiler'];
  const r = { api_version: 1, tax_year: 2024, filing_status: fs, w2s: [], interest_reports: [] };
  for (let i = 0, n = Math.floor(rnd() * 4); i < n; i++) {
    const wages = amt(15_000_000);
    const w = { filer: pick(roles), wages, federal_withholding: Math.floor(wages * rnd() * 0.3) };
    if (rnd() < 0.3) { w.oasdi_wages = wages; w.medicare_wages = wages; w.medicare_withholding = Math.floor(wages * 0.0145); }
    if (rnd() < 0.3) w.box12 = { [pick(['D', 'E', 'W', 'DD', 'C', 'Q', 'A', 'AA'])]: amt(2_000_000) };
    if (rnd() < 0.05) w.statutory_employee = true;
    if (rnd() < 0.05) w.allocated_tips = amt(500_000);
    r.w2s.push(w);
  }
  for (let i = 0, n = Math.floor(rnd() * 3); i < n; i++) {
    const t = { filer: pick(roles), has_1099: rnd() < 0.9, interest_income: amt(500_000) };
    if (rnd() < 0.1) t.federal_tax_withheld = amt(100_000);
    if (rnd() < 0.05) t.foreign_tax_paid = 5000;
    r.interest_reports.push(t);
  }
  if (rnd() < 0.15) r.form_1099g = [{ filer: pick(roles), unemployment_compensation: amt(1_000_000), federal_tax_withheld: amt(100_000) }];
  if (rnd() < 0.15) r.social_security = { net_benefits: [amt(3_000_000)] };
  if (rnd() < 0.15) r.estimated_payments = { paid_estimated_taxes_or_from_last_year: true, amount: amt(500_000) };
  // dependents: children (HoH and QSS need one)
  const kids = fs === 'HeadOfHousehold' || fs === 'QualifyingSurvivingSpouse' ? 1 + Math.floor(rnd() * 2) : (rnd() < 0.4 ? Math.floor(rnd() * 3) : 0);
  if (kids > 0) {
    r.dependents = [];
    for (let i = 0; i < kids; i++) {
      r.dependents.push({ relationship: pick(['BiologicalChild', 'AdoptedChild', 'StepChild']),
        date_of_birth: `${2006 + Math.floor(rnd() * 18)}-0${1 + Math.floor(rnd() * 9)}-15`, tin_type: 'Ssn',
        tp_paid_most_of_home_upkeep: true });
    }
  }
  if (fs === 'QualifyingSurvivingSpouse') r.filing_answers = { year_of_spouse_death: 'DiedTaxYearMinusOne', can_file_jointly_year_of_spouse_death: true };
  const f = {};
  if (rnd() < 0.3) f.primary = { is_blind: rnd() < 0.5, age65_or_older: rnd() < 0.5, can_be_claimed_as_dependent: rnd() < 0.1 };
  if (joint && rnd() < 0.3) f.secondary = { is_blind: rnd() < 0.5, age65_or_older: rnd() < 0.5 };
  if (Object.keys(f).length) r.filers = f;
  const d = {};
  if (rnd() < 0.05) d.has_foreign_accounts_or_trusts = true;
  if (fs === 'MarriedFilingSeparately' && rnd() < 0.5) d.mfs_spouse_65_or_older = true;
  if (rnd() < 0.1) d.treat_as_mfs = fs === 'MarriedFilingSeparately';
  if (Object.keys(d).length) r.filing_details = d;
  return r;
}

const requests = JSON.parse(readFileSync(join(api, 'fixtures/manifest.json'), 'utf8')).fixtures
  .filter((e) => e.method === 'POST' && e.request && (e.status === 200 || e.status === 422))
  .map((e) => ({ name: e.name, text: readFileSync(join(api, e.request), 'utf8') }));
for (let i = 0; i < N; i++) requests.push({ name: `random-${i}`, text: JSON.stringify(randomRequest()) });

// The CLI reads one body per line: compact each one (JSON text, the same request).
const run = spawnSync(cli, ['api-calc'], { input: requests.map((c) => JSON.stringify(JSON.parse(c.text))).join('\n') + '\n', encoding: 'utf8', maxBuffer: 1 << 28 });
if (run.status !== 0) { console.error('ustax api-calc failed', run.stderr); process.exit(1); }
const outs = run.stdout.trim().split('\n').map((l) => { const t = l.indexOf('\t'); return { status: Number(l.slice(0, t)), body: JSON.parse(l.slice(t + 1)) }; });
if (outs.length !== requests.length) { console.error(`ustax api-calc: ${outs.length} answers for ${requests.length} requests`); process.exit(1); }

const canon = (v) => Array.isArray(v) ? v.map(canon)
  : v && typeof v === 'object' ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, canon(v[k])])) : v;
const same = (a, b) => JSON.stringify(canon(a)) === JSON.stringify(canon(b));

let catala;
if (CATALA_CASES > 0) catala = await import('./api_catala.mjs');

let ok = 0, bad = 0, n422 = 0, nCatala = 0, catalaBad = 0;
for (let i = 0; i < requests.length; i++) {
  const { name, text } = requests[i], o = outs[i];
  const res = await fetch(base + '/calculate', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: text });
  const body = await res.json();
  let why = '';
  if (res.status !== o.status) why = `status: server ${res.status}, cli ${o.status}`;
  else if (!same(body, o.body)) why = `body: server ${JSON.stringify(body).slice(0, 300)}\n  cli ${JSON.stringify(o.body).slice(0, 300)}`;
  if (res.status === 422) n422++;
  if (!why && catala && nCatala < CATALA_CASES && (res.status === 200 || res.status === 422)) {
    nCatala++;
    const want = catala.toResponse(catala.runCatalaRequest(JSON.parse(text), `server_vs_cli_${i}`));
    const { warnings: _w, ...got } = body;
    if (!same(got, want)) { catalaBad++; why = `catala differs: ${JSON.stringify(want).slice(0, 300)}`; }
  }
  if (why) { bad++; console.log(`FAIL ${name}: ${why}\n  ${text.slice(0, 400)}`); } else ok++;
}
console.log(`server vs ustax api-calc: ${ok} agree, ${bad} differ (${requests.length} cases, ${n422} knocked out)` +
  (catala ? `; vs Catala ApiCalculator: ${nCatala - catalaBad} of ${nCatala} agree` : ''));
process.exit(bad === 0 ? 0 : 1);
