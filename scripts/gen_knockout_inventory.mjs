#!/usr/bin/env node
// Writes docs/knockout-inventory.md: every member of Direct File's flow.xml /flowIsKnockedOut, its owner and its
// status in this repository (issue #36). Also checks that every Catala name it cites exists in catala/*.catala_en.
//   node scripts/gen_knockout_inventory.mjs [--flow <path to flow.xml>]   (default: $DIRECT_FILE/backend/src/main/resources/tax/flow.xml)
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { MODULES, KOS, LOCAL } from './knockout_income_table.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const i = process.argv.indexOf('--flow');
const flowFile = i > 0 ? process.argv[i + 1]
  : join(process.env.DIRECT_FILE || join(root, '../../direct-file/direct-file'), 'backend/src/main/resources/tax/flow.xml');
const xml = readFileSync(flowFile, 'utf8');
const body = xml.slice(xml.indexOf('<Fact path="/flowIsKnockedOut">'));
const any = body.slice(body.indexOf('<Any>'), body.indexOf('</Any>'));

// Members in file order: [module|null, path, negated]
const members = [];
const re = /<(Not)>|<\/Not>|<Dependency\s+(?:module="(\w+)"\s+)?path="([^"]+)"/g;
let neg = false, m;
while ((m = re.exec(any))) {
  if (m[1]) neg = true;
  else if (m[0] === '</Not>') neg = false;
  else members.push([m[2] || null, m[3], neg]);
}

const catalaSrc = readdirSync(join(root, 'catala')).filter((f) => f.endsWith('.catala_en'))
  .map((f) => readFileSync(join(root, 'catala', f), 'utf8')).join('\n');
const koSrc = readFileSync(join(root, 'catala/knockouts_income.catala_en'), 'utf8');

const byPath = new Map();
for (const [mod, name, path, ctor] of KOS.map((k) => [k[0], k[1], k[2], k[3]])) if (path) byPath.set(path, { kind: 'module', mod, name, ctor });
for (const [name, path, ctor] of LOCAL.map((l) => [l[0], l[1], l[2]])) byPath.set(path, { kind: 'local', name, ctor });

const DEAD = {
  '/has1099rFormsAndFeatureIsNotEnabled': 'constant `False` in `form1099Rs.xml` line 41; no condition',
  '/flowKnockoutRetirementQualifiedEarlyDistribution': 'dead code in DF (codes 1 and 3 are stripped before the test), see `catala/form1099_rs.catala_en`; no condition',
  '/knockoutDisabilityAndAnotherCode': 'dead code in DF (same reason); no condition',
};
// Owners of the facts that are not income / HSA / process (issue #37 finishes them).
const HOUSEHOLD = {
  filers: ['Filers (#15)', 'covered', 'Filers.ko_*; not aggregated yet (#37)'],
  familyAndHousehold: ['Qualifying child / HOH (#16, #19)', 'uncovered', '#37'],
  dependentsBenefitSplit: ['Benefit split (#18)', 'uncovered', '#37'],
  ptc: ['PTC (#32 to #34)', 'uncovered', '#37'],
  saversCredits: ['Saver\'s credit (#29)', 'uncovered', '#37'],
  cdcc: ['CDCC (#28)', 'uncovered', '#37'],
  taxCalculations: ['Form 1040 (#14)', 'covered', '`Form1040.ko_knockout_has_no_payments_or_credits`; an input of `KnockoutsIncome`'],
};
const camel = (s) => s.replace(/^\//, '').split('/').pop();
const snake = (s) => camel(s).replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();

const rows = [];
const problems = [];
for (const [mod, path, negated] of members) {
  let owner, status, catala;
  const hit = byPath.get(path);
  if (hit && hit.kind === 'module') {
    owner = `${MODULES[hit.mod].title.split(' (')[0]} module`; status = 'covered';
    catala = `\`KnockoutsIncome.${MODULES[hit.mod].field}.${hit.name === 'repayment_over_3k' ? 'ko_social_security_repayment_over_3k' : hit.name}\` (reason \`${hit.ctor}\`)`;
    const sub = { interest: 'interest', w2s: 'form_w2s', unemployment: 'unemployment', misc: 'form1099_misc', rs: 'form1099_rs', ss: 'social_security', ep: 'estimated_payments', hsa: 'hsa' }[hit.mod];
    const text = readFileSync(join(root, `catala/${sub}.catala_en`), 'utf8');
    if (!new RegExp(`\\b${hit.name}\\b`).test(text)) problems.push(`${hit.name} not in ${sub}.catala_en`);
  } else if (hit) {
    owner = 'this module (#36)'; status = 'covered';
    catala = `\`KnockoutsIncome.local_knockouts.${hit.name}\` (reason \`${hit.ctor}\`)`;
    if (!koSrc.includes(hit.name)) problems.push(`${hit.name} not in knockouts_income.catala_en`);
  } else if (DEAD[path]) {
    owner = mod === 'form1099Rs' ? 'Form 1099-R module (#22)' : 'n/a'; status = 'covered (constant false)'; catala = DEAD[path];
  } else if (mod && HOUSEHOLD[mod]) {
    [owner, status, catala] = HOUSEHOLD[mod];
    if (mod === 'filers' && !catalaSrc.includes(snake(path))) problems.push(`Filers: ${snake(path)} missing`);
  } else if (path === '/saversCreditKnockouts' || path === '/isTooLateToFileOrResubmit') {
    if (path === '/saversCreditKnockouts') { owner = 'Saver\'s credit (#29)'; status = 'uncovered'; catala = '#37'; }
  } else {
    problems.push(`unclassified flow member ${mod} ${path}`);
    continue;
  }
  rows.push({ mod: mod || '(flow.xml)', path, negated, owner, status, catala });
}

const lines = [];
const L = (s = '') => lines.push(s);
const count = (p) => rows.filter(p).length;
const isInc = (r) => !(r.owner.startsWith('Filers') || r.owner.startsWith('Qualifying') || r.owner.startsWith('Benefit') || r.owner.startsWith('PTC')
  || r.owner.startsWith('Saver') || r.owner.startsWith('CDCC'));
L('# Knockout inventory: `flow.xml` `/flowIsKnockedOut`');
L();
L('Generated by `scripts/gen_knockout_inventory.mjs` from `flow.xml` of the Direct File dump (issue #36). Do not edit by hand.');
L();
L(`\`/flowIsKnockedOut\` is the \`Any\` of ${rows.length} facts below (\`flow.xml\` lines 11 to 119); a \`Not\` marks a fact whose negation knocks out.`);
L('The oracle holds `/flowIsKnockedOut` Complete only for the 4 knocked-out scenarios; the other 157 are a Placeholder `false` (`oracle/README.md`).');
L();
L('Status: `covered` = a Catala condition exists and is aggregated by `KnockoutsIncome` (`catala/knockouts_income.catala_en`, output `unsupported_income_or_hsa`, reasons in `fired_knockouts`);');
L('`covered (constant false)` = the DF fact is dead code or a constant, so no condition is needed; `uncovered` = no Catala condition yet (owner finishes it in #37, aggregation in #38).');
L();
L('## Summary');
L();
L('| Category | Facts | covered | uncovered |');
L('|---|---|---|---|');
const cat = (name, f) => L(`| ${name} | ${count(f)} | ${count((r) => f(r) && r.status.startsWith('covered'))} | ${count((r) => f(r) && r.status === 'uncovered')} |`);
cat('Income, HSA and process (this issue, #36)', (r) => isInc(r));
cat('Household, credit and PTC (#37)', (r) => !isInc(r));
cat('All', () => true);
L();
L('Besides these, `KnockoutsIncome` also aggregates three knockouts of merged modules that DF does not list in `/flowIsKnockedOut`: `ExtraNonPfd1099Misc`, `ExtraHsaDistributionsWithoutActivity`, `ExtraHsaDistributionsSecondaryFilerWithoutMfj` (block-submission validations).');
L();
L('## Every member, in `flow.xml` order');
L();
L('| # | DF module | DF fact | Owner | Status | Catala |');
L('|---|---|---|---|---|---|');
rows.forEach((r, k) => L(`| ${k + 1} | ${r.mod} | ${r.negated ? 'Not ' : ''}\`${r.path}\` | ${r.owner} | ${r.status} | ${r.catala} |`));
L();
L('## Checks that back this table');
L();
L('- `catala/tests/test_knockouts_income.catala_en`: a clean return fires nothing; one representative knockout per merged module and each knockout defined in `knockouts_income.catala_en` fires alone with exactly its reason. The remaining knockouts of each merged module are tested in that module\'s own test file.');
L('- `make difftest SCOPE=knockouts_income`: `unsupported_income_or_hsa` against the oracle\'s `/flowIsKnockedOut` on all 161 scenarios; the 4 knocked-out ones are DF-BUG-8 (see `docs/direct-file-bugs.md`).');
writeFileSync(join(root, 'docs/knockout-inventory.md'), lines.join('\n') + '\n');
console.log(`members=${rows.length} problems=${problems.length}`);
for (const p of problems) console.error('PROBLEM', p);
process.exit(problems.length ? 1 : 0);
