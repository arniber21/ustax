#!/usr/bin/env node
// Three-way differential test: Direct File oracle / Catala (clerk run) / Lean (`ustax run`).
//   node difftest/lean.mjs --scope tax_rates [--scenario NAME] [--verbose] [--no-build]
//   make lean-difftest SCOPE=tax_rates
//
// A Lean port adds NOTHING here except a line in `UsTax.Cli.scopes` (lean/UsTax/Cli.lean): the scenario
// input, the oracle-path -> Catala-output mapping and the knownDivergence list are the ones of the Catala
// runner (difftest/mappings/<scope>.mjs, difftest/run.mjs). The Lean driver reads the very same input JSON
// text the Catala runner writes (_build/difftest/<scope>/<scenario>.input.json).
//
// TRUST: this file and the JSON handling of the scenario subset are test-only code and are NOT trusted
// (the Lean side only sees `Lean.Json.parse` in lean/UsTax/Cli.lean; there is no JSON parsing script for Lean).
// A mismatch is a finding; a pass is evidence, not proof.
//
// Per fact (a mapped output of an unknocked scenario) three values are compared, all exactly (money in cents):
//   D = Direct File oracle (only if its row is Complete), C = Catala, L = Lean.
//   agree3        D = C = L
//   unchecked     oracle row Incomplete/Placeholder: only L = C is checked (never counted as agreement with D)
//   knownDivergence  C differs from D and the mapping lists it (law vs Direct File): L must equal C
//   FAIL          anything else. Counted separately as lean!=catala or catala!=oracle.
// Outputs listed in the mapping's `extraOutputs` have no oracle fact; only L = C is checked.
// Knocked-out scenarios (oracle /flowIsKnockedOut = true) and scenarios a mapping excludes (`appliesTo`)
// are skipped and listed.
//
// Negative control: LEAN_DIFFTEST_PERTURB=1 adds one cent / 1 / negation to every Lean output; every
// check must then fail (exit status 1).
// Needs `clerk` (and ninja) on PATH (export PATH=$HOME/.opam/default/bin:$PATH) and the Lean toolchain.

import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { loadOracle, isKnockedOut, parseCatalaResult, parseCatalaValue, parseOracleValue, showValue,
  buildInput, inputFileText } from './lib.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf(n); return i < 0 ? d : args[i + 1]; };
const flag = (n) => args.includes(n);
const names = (opt('--scope', process.env.SCOPE || '')).split(',').filter(Boolean);
const only = opt('--scenario', null);
const verbose = flag('--verbose');
const perturb = process.env.LEAN_DIFFTEST_PERTURB === '1';
const oracleFile = resolve(root, opt('--oracle', 'oracle/facts.csv'));
if (names.length === 0) { console.error('usage: lean.mjs --scope NAME[,NAME] (a file in difftest/mappings)'); process.exit(2); }

if (!flag('--no-build')) {
  const r = spawnSync('lake', ['build', 'ustax'], { cwd: join(root, 'lean'), encoding: 'utf8' });
  if (r.status !== 0) { console.error(r.stdout, r.stderr); process.exit(2); }
}
const ustax = join(root, 'lean/.lake/build/bin/ustax');

/** Lean JSON output value -> canonical typed value (same canonical forms as lib.mjs). */
function leanValue(type, v) {
  switch (type) {
    case 'money': return parseOracleValue('money', String(v));
    case 'int': return BigInt(v);
    case 'bool': if (typeof v !== 'boolean') throw new Error(`bad bool ${JSON.stringify(v)}`); return v;
    default: return String(v);
  }
}
const perturbed = (type, v) => (type === 'money' || type === 'int' ? v + 1n : type === 'bool' ? !v : v + '~');

const oracle = loadOracle(oracleFile);
let exitCode = 0;

for (const name of names) {
  const mapPath = join(root, 'difftest/mappings', `${name}.mjs`);
  if (!existsSync(mapPath)) { console.error(`unknown scope '${name}': no difftest/mappings/${name}.mjs`); process.exit(2); }
  const mapping = (await import(pathToFileURL(mapPath))).default;
  const outDir = join(root, '_build/difftest', name);
  mkdirSync(outDir, { recursive: true });
  const outs = [...mapping.outputs, ...(mapping.extraOutputs || [])];

  const knocked = [], outOfScope = [], inputErrors = [], scen = [];
  for (const [scenario, facts] of oracle) {
    if (only && scenario !== only) continue;
    if (isKnockedOut(facts)) { knocked.push(scenario); continue; }
    const applies = mapping.appliesTo(facts);
    if (applies !== true) { outOfScope.push(`${scenario} (${applies})`); continue; }
    try {
      const file = join(outDir, `${scenario}.input.json`);
      writeFileSync(file, inputFileText(buildInput(mapping, facts)));
      scen.push({ scenario, facts, file });
    } catch (e) { inputErrors.push(`${scenario}: ${e.message}`); }
  }

  // Lean: one process, one JSON line per scenario, read back from the file the Catala runner reads.
  const lin = scen.map((s) => JSON.stringify(JSON.parse(readFileSync(s.file, 'utf8')))).join('\n') + '\n';
  const t0 = Date.now();
  const lr = spawnSync(ustax, ['run', mapping.scope], { input: lin, encoding: 'utf8', maxBuffer: 1 << 30 });
  if (lr.status !== 0) {
    console.error(`no Lean implementation of Catala scope ${mapping.scope} (add it to UsTax.Cli.scopes):\n${lr.stderr}`);
    process.exit(2);
  }
  const leanLines = lr.stdout.trim().split('\n');
  if (leanLines.length !== scen.length) throw new Error(`lean: ${leanLines.length} outputs for ${scen.length} inputs`);
  const msLean = Date.now() - t0;

  const c = { agree3: 0, unchecked: 0, uncheckedOk: 0, div: 0, leanNeCatala: 0, catalaNeOracle: 0, leanNeOracle: 0, error: 0 };
  const scenBad = new Set(), problems = [], knownDiv = [];
  const t1 = Date.now();
  scen.forEach((s, i) => {
    const r = spawnSync('clerk', ['run', '-s', mapping.scope, `--input=${s.file}`, '--color=never', join(root, mapping.file)],
      { cwd: root, encoding: 'utf8' });
    const cat = parseCatalaResult((r.stdout || '') + '\n' + (r.stderr || ''));
    if (r.status !== 0 && cat.size === 0) {
      c.error++; scenBad.add(s.scenario); problems.push(`ERROR scenario=${s.scenario} clerk exit ${r.status}`); return;
    }
    let lean;
    try { lean = JSON.parse(leanLines[i]); } catch (e) { lean = { error: `unparsable ${leanLines[i]}` }; }
    if (lean.error !== undefined) {
      c.error++; scenBad.add(s.scenario); problems.push(`ERROR scenario=${s.scenario} lean: ${lean.error}`); return;
    }
    for (const o of outs) {
      const path = o.oracle ?? `(catala ${o.catala})`;
      if (!cat.has(o.catala) || !(o.catala in lean)) {
        c.error++; scenBad.add(s.scenario);
        problems.push(`ERROR scenario=${s.scenario} ${path}: missing output ${o.catala} (catala=${cat.get(o.catala) ?? '-'} lean=${lean[o.catala] ?? '-'})`);
        continue;
      }
      const C = parseCatalaValue(o.type, cat.get(o.catala));
      let L = leanValue(o.type, lean[o.catala]);
      if (perturb) L = perturbed(o.type, L);
      const row = o.oracle ? s.facts.get(o.oracle) : undefined;
      const hasD = !!row && row.completeness === 'Complete';
      const D = hasD ? parseOracleValue(o.type, row.value) : undefined;
      const show = (v) => (v === undefined ? '-' : showValue(o.type, v));
      const line = `scenario=${s.scenario} ${path} oracle=${show(D)} catala=${show(C)} lean=${show(L)}`;
      const kd = hasD && C !== D && (mapping.knownDivergence || []).find((d) => d.scenario === s.scenario && d.path === o.oracle);
      let status;
      if (L !== C) { c.leanNeCatala++; status = 'FAIL lean!=catala'; }
      else if (!hasD) { if (o.oracle) c.unchecked++; else c.uncheckedOk++; status = 'ok (lean=catala, no Complete oracle)'; }
      else if (C === D) { c.agree3++; status = 'ok'; }
      else if (kd) { c.div++; status = 'KNOWN DIVERGENCE'; knownDiv.push(`${line} [${kd.bug}]`); }
      else { c.catalaNeOracle++; if (L !== D) c.leanNeOracle++; status = 'FAIL catala!=oracle'; }
      if (status.startsWith('FAIL')) { scenBad.add(s.scenario); problems.push(`${status} ${line}`); }
      if (verbose) console.log(`  ${status.padEnd(24)} ${line}`);
    }
  });
  const msCatala = Date.now() - t1;

  const catalaFacts = scen.length * outs.length;
  console.log(`\n=== lean-difftest scope '${name}' (Catala scope ${mapping.scope}, ${mapping.file})${perturb ? ' [PERTURBED: negative control]' : ''} ===`);
  for (const p of problems) console.log(p);
  for (const d of knownDiv) console.log(`KNOWN DIVERGENCE ${d}`);
  const list = (a) => (a.length ? ` [${a.join(', ')}]` : '');
  console.log(`oracle scenarios total:      ${oracle.size}`);
  console.log(`skipped, knocked out:        ${knocked.length}${list(knocked)}`);
  console.log(`skipped, outside module:     ${outOfScope.length}${list(outOfScope)}`);
  if (inputErrors.length) console.log(`skipped, input not mappable: ${inputErrors.length}${list(inputErrors)}`);
  console.log(`scenarios run:               ${scen.length} (lean ${msLean} ms, ${scen.length} x clerk run ${msCatala} ms)`);
  console.log(`scenarios with problems:     ${scenBad.size}`);
  console.log(`facts compared (lean vs catala): ${catalaFacts - c.error}`);
  console.log(`  three-way agree (oracle = catala = lean):       ${c.agree3}`);
  console.log(`  oracle unchecked (not Complete), lean = catala: ${c.unchecked}`);
  console.log(`  no oracle fact (extraOutputs), lean = catala:   ${c.uncheckedOk}`);
  console.log(`  knownDivergence (catala != oracle, lean = catala): ${c.div}`);
  console.log(`  FAIL lean != catala: ${c.leanNeCatala}; FAIL catala != oracle (not known): ${c.catalaNeOracle} (of which lean != oracle: ${c.leanNeOracle}); errors: ${c.error}`);
  const bad = c.leanNeCatala + c.catalaNeOracle + c.error + inputErrors.length;
  console.log(`RESULT lean-difftest ${name}: ${bad === 0 ? 'OK' : 'FAILED'} three-way agree=${c.agree3}, lean=catala only=${c.unchecked + c.uncheckedOk}, knownDivergence=${c.div}, failures=${bad}`);
  if (bad > 0) exitCode = 1;
}
process.exit(exitCode);
