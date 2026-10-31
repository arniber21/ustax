#!/usr/bin/env node
// Differential test of the Lean rate schedule (lean/UsTax/TaxRates.lean, issue #41) against
//   (1) the Catala scope Tax_rates.TentativeTax, run by `clerk run` (one run, batched through
//       catala/tests/difftest_tax_rates_batch.catala_en), on a few thousand incomes x 5 statuses,
//       comparing all three outputs;
//   (2) the Direct File oracle (oracle/facts.csv): /tentativeTaxFromTaxableIncome on every
//       scenario that is not knocked out (157), with /taxableIncome and /filingStatus as inputs.
//
//   node difftest/lean_rates.mjs [--no-build] [--perturb] [--verbose] [--dense STEP_CENTS MAX_DOLLARS]
//
// Default incomes (2,402): every Tax Table row edge kind, every bracket bound +-1 cent and +-$1,
// the $1-trillion sentinel, and 900 seeded pseudo-random cent amounts up to $31 million.
// `--dense 100 1000000` instead sweeps every dollar from -$5 to $1,000,000 (issue #41's range).
// Needs `clerk` on PATH (export PATH=$HOME/.opam/default/bin:$PATH) and the Lean toolchain (elan).
// `--perturb` adds one cent to every Lean output: a negative control, every check must fail.
// Exit status 1 on any mismatch or error. See lean/README.md, "Pattern for Lean modules".

import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadOracle, isKnockedOut, parseMoney, showValue } from './lib.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const flag = (n) => args.includes(n);
const verbose = flag('--verbose');
const perturb = flag('--perturb');
const outDir = join(root, '_build/difftest/lean_rates');
mkdirSync(outDir, { recursive: true });

const STATUSES = ['Single', 'MarriedFilingJointly', 'MarriedFilingSeparately', 'HeadOfHousehold',
  'QualifyingSurvivingSpouse'];
const OUTPUTS = ['rounded_taxable_income', 'tentative_tax_from_taxable_income', 'tentative_tax_cumulative_form'];
const DF_STATUS = { single: 'Single', marriedFilingJointly: 'MarriedFilingJointly',
  marriedFilingSeparately: 'MarriedFilingSeparately', headOfHousehold: 'HeadOfHousehold',
  qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse' }; // DF spells it "qualified"

const money = (cents) => showValue('money', BigInt(cents)); // exact "1234.56"

// ---------------------------------------------------------------------------------------------
// Incomes (cents). Deterministic: edges of every Tax Table row kind and every bracket, plus a
// seeded pseudo-random sample over each range.
// ---------------------------------------------------------------------------------------------
function incomes() {
  const s = new Set();
  const dense = args.indexOf('--dense');
  if (dense >= 0) {
    // --dense STEP_CENTS MAX_DOLLARS: every STEP cents from -$5 to MAX.
    const step = Number(args[dense + 1]), max = Number(args[dense + 2]) * 100;
    if (!(step > 0 && max > 0)) { console.error('usage: --dense STEP_CENTS MAX_DOLLARS'); process.exit(2); }
    const out = [];
    for (let c = -500; c <= max; c += step) out.push(c);
    return out;
  }
  const add = (c) => s.add(c);
  // Tax Table structure: <= 0, the three small rows, $25 rows to $3,000, $50 rows to $100,000.
  for (const c of [-100_000_00, -1, 0, 1, 499, 500, 1499, 1500, 2499, 2500]) add(c);
  for (let d = 25; d <= 3000; d += 25) { add(d * 100 - 1); add(d * 100); }
  for (let d = 3000; d <= 100_000; d += 250) { add(d * 100 - 1); add(d * 100); add(d * 100 + 2500); }
  // Every bracket bound of every schedule, +-1 cent and +-$1.
  const bounds = [11_600, 16_550, 23_200, 47_150, 63_100, 94_300, 100_500, 100_525, 191_950,
    201_050, 243_700, 243_725, 365_600, 383_900, 487_450, 609_350, 731_200];
  for (const b of bounds) for (const o of [-100, -1, 0, 1, 100]) add(b * 100 + o);
  // The $1-trillion sentinel of the Catala schedules, and beyond.
  for (const o of [-1, 0, 1, 1_000_000_00]) add(1_000_000_000_000_00 + o);
  // Pseudo-random cents (xorshift32, fixed seed) in each range.
  let x = 0x9e3779b9;
  const rnd = (n) => { x ^= x << 13; x >>>= 0; x ^= x >>> 17; x ^= x << 5; x >>>= 0; return x % n; };
  for (let i = 0; i < 400; i++) add(rnd(100_000_00));
  for (let i = 0; i < 400; i++) add(100_000_00 + rnd(900_000_00));
  for (let i = 0; i < 100; i++) add(1_000_000_00 + rnd(3_000_000_000));
  return [...s].sort((a, b) => a - b);
}

// ---------------------------------------------------------------------------------------------
// Runners
// ---------------------------------------------------------------------------------------------
function buildLean() {
  if (flag('--no-build')) return;
  const r = spawnSync('lake', ['build', 'ustax'], { cwd: join(root, 'lean'), encoding: 'utf8' });
  if (r.status !== 0) { console.error(r.stdout, r.stderr); process.exit(2); }
}

/** Run `ustax run TentativeTax` on a list of Catala input objects; returns output objects. */
function runLean(queries) {
  const input = queries.map((q) => JSON.stringify(q)).join('\n') + '\n';
  const r = spawnSync(join(root, 'lean/.lake/build/bin/ustax'), ['run', 'TentativeTax'],
    { input, encoding: 'utf8', maxBuffer: 1 << 30 });
  if (r.status !== 0) { console.error(r.stderr); process.exit(2); }
  const out = r.stdout.trim().split('\n').map((l) => JSON.parse(l));
  if (out.length !== queries.length) throw new Error(`lean: ${out.length} outputs for ${queries.length} inputs`);
  if (perturb) for (const o of out) for (const k of OUTPUTS) if (k in o) o[k] = money(parseMoney(o[k]) + 1n);
  return out;
}

/** Run the Catala batch scope once; returns one object of the three outputs per query. */
function runCatala(queries, tag) {
  const inFile = join(outDir, `${tag}.input.json`);
  writeFileSync(inFile, JSON.stringify({ queries }) + '\n');
  const file = 'catala/tests/difftest_tax_rates_batch.catala_en';
  const r = spawnSync('clerk', ['run', '-s', 'TentativeTaxBatch', `--input=${inFile}`, '--color=never', file],
    { cwd: root, encoding: 'utf8', maxBuffer: 1 << 30 });
  const text = (r.stdout || '').replace(/\x1b\[[0-9;]*m/g, '');
  if (r.status !== 0) { console.error(r.stderr || text); process.exit(2); }
  // `│ name =` (the `[` on the same or the next line), then one `$1,234.00;` per line, then `]`.
  const lists = {};
  let cur = null;
  for (const line of text.split('\n')) {
    const m = /^│ ([a-z_]+) =/.exec(line);
    if (m) { cur = m[1]; lists[cur] = []; }
    if (!cur) continue;
    for (const v of line.matchAll(/-?\$[\d,]+\.\d\d/g)) lists[cur].push(money(parseMoney(v[0])));
    if (/\]\s*$/.test(line)) cur = null;
  }
  for (const k of OUTPUTS) {
    if (!lists[k] || lists[k].length !== queries.length) {
      throw new Error(`catala: output ${k} has ${lists[k]?.length} values for ${queries.length} inputs`);
    }
  }
  return queries.map((_, i) => Object.fromEntries(OUTPUTS.map((k) => [k, lists[k][i]])));
}

// ---------------------------------------------------------------------------------------------
// (1) Lean vs Catala
// ---------------------------------------------------------------------------------------------
buildLean();
let failed = 0;

const inc = incomes();
const queries = [];
for (const c of inc) for (const fs of STATUSES) queries.push({ taxable_income: money(c), filing_status: fs });
let pass = 0, fail = 0, msLean = 0, msCatala = 0;
const CHUNK = 50_000; // keeps every stdin/stdout string under node's string limit
for (let start = 0; start < queries.length; start += CHUNK) {
  const qs = queries.slice(start, start + CHUNK);
  const t0 = Date.now();
  const lean = runLean(qs);
  const t1 = Date.now();
  const catala = runCatala(qs, 'sweep');
  msLean += t1 - t0; msCatala += Date.now() - t1;
  for (let i = 0; i < qs.length; i++) {
    for (const k of OUTPUTS) {
      if (lean[i][k] === catala[i][k]) pass++;
      else {
        fail++;
        if (fail <= 20 || verbose) {
          console.log(`FAIL lean-vs-catala income=${qs[i].taxable_income} status=${qs[i].filing_status} ${k}: lean=${lean[i][k] ?? JSON.stringify(lean[i])} catala=${catala[i][k]}`);
        }
      }
    }
  }
}
console.log(`=== Lean vs Catala (TentativeTax, ${inc.length} incomes x ${STATUSES.length} statuses = ${queries.length} runs, ${OUTPUTS.length} outputs each) ===`);
console.log(`lean ${msLean} ms, clerk run ${msCatala} ms`);
console.log(`RESULT lean-vs-catala: ${fail === 0 ? 'OK' : 'FAILED'} ${pass}/${pass + fail} output checks agree`);
failed += fail;

// ---------------------------------------------------------------------------------------------
// (2) Lean (and Catala) vs the Direct File oracle
// ---------------------------------------------------------------------------------------------
const oracle = loadOracle(join(root, 'oracle/facts.csv'));
const scen = [], knocked = [];
for (const [name, facts] of oracle) {
  if (isKnockedOut(facts)) { knocked.push(name); continue; }
  const get = (p) => {
    const r = facts.get(p);
    if (!r || r.completeness !== 'Complete') throw new Error(`${name}: no Complete ${p}`);
    return r.value;
  };
  const fs = DF_STATUS[get('/filingStatus')];
  if (!fs) throw new Error(`${name}: unknown /filingStatus ${get('/filingStatus')}`);
  scen.push({ name, ti: get('/taxableIncome'), fs,
    expected: money(parseMoney(get('/tentativeTaxFromTaxableIncome'))) });
}
const oq = scen.map((s) => ({ taxable_income: s.ti, filing_status: s.fs }));
const leanO = runLean(oq);
const catalaO = runCatala(oq, 'oracle');
let opass = 0, ofail = 0, cpass = 0;
scen.forEach((s, i) => {
  const got = leanO[i].tentative_tax_from_taxable_income;
  if (catalaO[i].tentative_tax_from_taxable_income === s.expected) cpass++;
  if (got === s.expected) { opass++; if (verbose) console.log(`  PASS ${s.name} ${s.fs} ti=${s.ti} tax=${got}`); }
  else { ofail++; console.log(`FAIL lean-vs-oracle scenario=${s.name} status=${s.fs} ti=${s.ti} expected=${s.expected} lean=${got}`); }
});
console.log(`=== Lean vs Direct File oracle (/tentativeTaxFromTaxableIncome) ===`);
console.log(`oracle scenarios total: ${oracle.size}; knocked out, skipped: ${knocked.length} [${knocked.join(', ')}]`);
console.log(`RESULT lean-vs-oracle: ${ofail === 0 ? 'OK' : 'FAILED'} ${opass}/${scen.length} scenarios agree`);
console.log(`(Catala vs oracle on the same scenarios: ${cpass}/${scen.length})`);
failed += ofail;

process.exit(failed === 0 ? 0 : 1);
