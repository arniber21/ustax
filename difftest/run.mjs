#!/usr/bin/env node
// Differential test runner: Catala scope outputs vs oracle/facts.csv. See catala/DIFFTEST.md.
//   node difftest/run.mjs --scope smoke [--scenario NAME] [--verbose] [--emit-only]
//   node difftest/run.mjs --scope all
// Needs `clerk` on PATH (export PATH=$HOME/.opam/default/bin:$PATH). Exit 1 on any fail/error.

import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { loadOracle, isKnockedOut, parseCatalaResult, compareOutputs, parseCatalaValue } from './lib.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf(n); return i < 0 ? d : args[i + 1]; };
const flag = (n) => args.includes(n);
const scopeArg = opt('--scope', process.env.SCOPE || 'smoke');
const only = opt('--scenario', null);
const verbose = flag('--verbose');
const emitOnly = flag('--emit-only');
const oracleFile = resolve(root, opt('--oracle', 'oracle/facts.csv'));
// Negative self-check: DIFFTEST_PERTURB=1 adds $1 to every money output, so every check must fail.
const perturb = process.env.DIFFTEST_PERTURB === '1';

const mapDir = join(root, 'difftest/mappings');
const available = readdirSync(mapDir).filter((f) => f.endsWith('.mjs')).map((f) => f.slice(0, -4)).sort();
// A mapping with `reportOnly: true` is excluded from `--scope all` and never sets the exit code.
const reportOnly = new Set();
for (const n of available) if ((await import(pathToFileURL(join(mapDir, `${n}.mjs`)))).default.reportOnly) reportOnly.add(n);
const names = scopeArg === 'all' ? available.filter((n) => !reportOnly.has(n)) : scopeArg.split(',');
for (const n of names) if (!available.includes(n)) { console.error(`unknown scope '${n}'; available: ${available.join(', ')}`); process.exit(2); }

const oracle = loadOracle(oracleFile);
let exitCode = 0;

for (const name of names) {
  const mapping = (await import(pathToFileURL(join(mapDir, `${name}.mjs`)))).default;
  const outDir = join(root, '_build/difftest', name);
  mkdirSync(outDir, { recursive: true });
  const c = { scenarios: 0, knockedOut: [], outOfScope: [], pass: 0, fail: 0, error: 0, unchecked: 0, diverge: 0, scenFail: [], scenPass: 0, scenNoChecks: 0 };
  const failures = [];
  const knownDiv = [];

  for (const [scenario, facts] of oracle) {
    if (only && scenario !== only) continue;
    // A mapping with `includeKnockedOut: true` (knockout aggregation, #36) also runs the knocked-out scenarios.
    if (isKnockedOut(facts) && !mapping.includeKnockedOut) { c.knockedOut.push(scenario); continue; }
    const applies = mapping.appliesTo(facts);
    if (applies !== true) { c.outOfScope.push(`${scenario} (${applies})`); continue; }
    c.scenarios++;

    let input;
    try {
      input = Object.fromEntries(Object.entries(mapping.inputs).map(([k, f]) => [k, f(facts)]));
    } catch (e) {
      failures.push({ scenario, path: '(input mapping)', expected: '-', actual: String(e.message) });
      c.error++; c.scenFail.push(scenario); continue;
    }
    const inFile = join(outDir, `${scenario}.input.json`);
    writeFileSync(inFile, JSON.stringify(input, null, 1) + '\n');
    if (emitOnly) continue;

    const r = spawnSync('clerk', ['run', '-s', mapping.scope, `--input=${inFile}`, '--color=never', join(root, mapping.file)],
      { cwd: root, encoding: 'utf8' });
    const out = parseCatalaResult((r.stdout || '') + '\n' + (r.stderr || ''));
    if (perturb) {
      for (const o of mapping.outputs) {
        if (o.type === 'money' && out.has(o.catala)) {
          out.set(o.catala, `$${(Number(parseCatalaValue('money', out.get(o.catala))) / 100 + 1).toFixed(2)}`);
        }
      }
    }
    if (r.status !== 0 && out.size === 0) {
      const why = ((r.stderr || '') + '\n' + (r.stdout || '')).split('\n').filter((l) => /ERROR|│/.test(l)).slice(0, 4).join(' ').trim();
      failures.push({ scenario, path: '(catala run)', expected: '-', actual: `clerk exit ${r.status}: ${why}` });
      c.error++; c.scenFail.push(scenario); continue;
    }
    const results = compareOutputs(mapping, facts, out);
    let bad = false, good = 0;
    for (const x of results) {
      // A mismatch listed in the mapping's `knownDivergence` ({scenario, path, bug, note}) is the formalization
      // following the law where Direct File does not (CONVENTIONS section 8). Reported separately, never as pass.
      const kd = x.status === 'fail' && (mapping.knownDivergence || []).find((d) => d.scenario === scenario && d.path === x.path);
      if (kd) { x.status = 'diverge'; knownDiv.push(`${scenario} ${x.path} expected(DF)=${x.expected} actual(law)=${x.actual} [${kd.bug}]`); }
      c[x.status]++;
      if (x.status === 'pass') good++;
      else if (x.status === 'fail' || x.status === 'error') { bad = true; failures.push({ scenario, ...x }); }
      if (verbose) console.log(`  ${x.status.toUpperCase().padEnd(9)} ${scenario} ${x.path} expected=${x.expected} actual=${x.actual}`);
    }
    if (bad) c.scenFail.push(scenario); else if (good > 0) c.scenPass++; else c.scenNoChecks++;
  }

  console.log(`\n=== difftest scope '${name}' (Catala scope ${mapping.scope}, ${mapping.file}) ===`);
  for (const f of failures) {
    console.log(`FAIL scenario=${f.scenario} path=${f.path} expected=${f.expected} actual=${f.actual}`);
    if (f.path.startsWith('/')) {
      console.log(`     reproduce: clerk run -s ${mapping.scope} --input=${join(root, '_build/difftest', name, f.scenario + '.input.json')} ${mapping.file}`);
    }
  }
  for (const d of knownDiv) console.log(`KNOWN DIVERGENCE ${d}`);
  const list = (a) => (a.length ? ` [${a.join(', ')}]` : '');
  console.log(`oracle scenarios total:      ${oracle.size}`);
  console.log(`skipped, knocked out:        ${c.knockedOut.length}${list(c.knockedOut)}`);
  console.log(`skipped, outside module:     ${c.outOfScope.length}${list(c.outOfScope)}`);
  console.log(`scenarios run:               ${c.scenarios}${emitOnly ? ` (emit-only: inputs in _build/difftest/${name})` : ''}`);
  if (!emitOnly) {
    console.log(`scenarios all-pass:          ${c.scenPass}`);
    console.log(`scenarios with failures:     ${c.scenFail.length}`);
    console.log(`scenarios with no checks:    ${c.scenNoChecks} (every mapped oracle row Incomplete/Placeholder)`);
    console.log(`fact checks: pass=${c.pass} fail=${c.fail} error=${c.error} unchecked(oracle not Complete)=${c.unchecked} knownDivergence=${c.diverge}`);
    const bad = c.fail + c.error;
    console.log(`RESULT ${name}: ${bad === 0 ? 'OK' : 'FAILED'} ${c.pass}/${c.pass + bad} fact checks passed in ${c.scenPass}/${c.scenarios} scenarios`);
    if (bad > 0 && !mapping.reportOnly) exitCode = 1;
  }
}
process.exit(exitCode);
