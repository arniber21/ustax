// Dump Direct File reference-engine values for every backend scenario.
//
// Usage: node generate.mjs [--direct-file DIR] [--out FILE] [--scenario-dir SCENARIOS]
//   DIR defaults to $DIRECT_FILE, else ../../direct-file/direct-file relative to the repo root
//   (the directory that contains backend/ and df-client/).
//
// Engine: the pre-built Scala.js bundle df-client/js-factgraph-scala/src/main.js (CommonJS),
// driven exactly as df-client-app's InterceptingFactGraph does: fact dictionary XML ->
// DigestNodeWrapper digest -> FactDictionaryFactory.fromConfig -> JSPersister -> GraphFactory.
// The XML -> digest step is a port of
// df-client-app/src/fact-dictionary/generate-src/{readRawFacts,processFactsToDigestWrapper}.ts.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { XMLParser, XMLValidator } from 'fast-xml-parser';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const arg = (name, dflt) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : dflt;
};
const DF = path.resolve(
  arg('--direct-file', process.env.DIRECT_FILE || path.join(here, '../../direct-file/direct-file'))
);
const OUT = path.resolve(arg('--out', path.join(here, 'facts.csv')));
const TAX_YEAR = '2024';

const bundle = path.join(DF, 'df-client/js-factgraph-scala/src/main.js');
const taxDir = path.join(DF, 'backend/src/main/resources/tax');
// --scenario-dir: another directory of scenario JSON files (issue #20: the 28 filing-status fact graphs of
// direct-file/docs/testing/fact-graphs, written to oracle/fact_graphs.csv). A file is either a backend scenario
// ({ "facts": {...} }) or a bare fact graph ({ "/path": {...} }).
const scenDir = path.resolve(arg('--scenario-dir', path.join(DF, 'backend/src/test/resources/scenarios')));
for (const p of [bundle, taxDir, scenDir]) {
  if (!fs.existsSync(p)) {
    console.error(`missing ${p}; set DIRECT_FILE or --direct-file to the direct-file/direct-file checkout`);
    process.exit(2);
  }
}
const sfg = createRequire(import.meta.url)(bundle);

// ---------- fact dictionary: XML -> digest (port of the TS generator) ----------
const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '@',
  ignoreDeclaration: true,
  trimValues: true,
  parseAttributeValue: false,
});

function readRawFacts() {
  const all = [];
  for (const f of fs.readdirSync(taxDir).filter((f) => f.endsWith('.xml')).sort()) {
    const xml = fs.readFileSync(path.join(taxDir, f), 'utf-8');
    if (XMLValidator.validate(xml, { allowBooleanAttributes: true }) !== true) throw new Error(`bad XML ${f}`);
    const doc = parser.parse(xml);
    if (!doc.FactDictionaryModule) throw new Error(`${f}: no FactDictionaryModule`);
    all.push(...[].concat(doc.FactDictionaryModule.Facts.Fact));
  }
  return all;
}

function processOptions(rawNode) {
  const buf = {};
  for (const attr of Object.keys(rawNode).filter((k) => k.startsWith('@') || k === '#text')) {
    buf[attr.startsWith('@') ? attr.replace('@', '') : 'value'] = rawNode[attr];
  }
  return buf;
}
function processLimits(rawNode) {
  if (rawNode === undefined) return [];
  return (Array.isArray(rawNode) ? rawNode : [rawNode]).map((node) => {
    const typeName = Object.keys(node).filter((n) => !n.startsWith('@'))[0];
    if (typeName === 'Dependency') {
      return {
        operation: node['@type'],
        level: 'Error',
        node: { typeName, options: { path: String(node.Dependency['@path']) }, children: [] },
      };
    }
    return {
      operation: node['@type'],
      level: 'Error',
      node: { typeName, options: { value: String(node[typeName]) }, children: [] },
    };
  });
}
function processWritable(w) {
  const typeName = Object.keys(w)[0];
  const defaultOptions = processOptions(w[typeName]);
  return {
    typeName,
    options: typeName === 'CollectionItem' ? {} : defaultOptions,
    collectionItemAlias: typeName === 'CollectionItem' ? defaultOptions.collection : null,
    limits: processLimits(w['Limit']),
  };
}
function processDerived(rawNode) {
  const inner = (cur, typeName) => {
    if (Array.isArray(cur)) return cur.map((n) => inner(n, typeName));
    if (typeof cur === 'object') {
      const keys = Object.keys(cur);
      const defaultOptions = processOptions(cur);
      const hasValueChild = typeof cur[typeName] !== 'object';
      const options = hasValueChild && cur[typeName] ? { value: String(cur[typeName]) } : defaultOptions;
      const children = keys
        .filter((k) => !k.startsWith('@') && !k.startsWith('#'))
        .flatMap((k) => inner(cur[k], k));
      return { typeName, options, children };
    }
    return { typeName, options: { value: String(cur) }, children: [] };
  };
  const typeName = Object.keys(rawNode)[0];
  return inner(rawNode[typeName], typeName);
}
const wrap = (rawFacts) =>
  rawFacts.map((r) => ({
    path: r['@path'],
    writable: r.Writable ? processWritable(r.Writable) : null,
    derived: r.Derived ? processDerived(r.Derived) : null,
    placeholder: r.Placeholder ? processDerived(r.Placeholder) : null,
  }));

const rawFacts = readRawFacts();
const wrapped = wrap(rawFacts);
const meta = new sfg.DigestMetaWrapper(TAX_YEAR).toNative();
const digest = wrapped.map((f) =>
  sfg.DigestNodeWrapperFactory.toNative(new sfg.DigestNodeWrapper(f.path, f.writable, f.derived, f.placeholder))
);
const dictionary = sfg.FactDictionaryFactory.fromConfig(sfg.FactDictionaryConfig.create(meta, digest));

// ---------- which derived facts to read ----------
const REQUIRED = [
  '/agi', '/totalIncome', '/taxableIncome', '/totalTax', '/totalPayments', '/overpayment', '/balanceDue',
  '/standardDeduction', '/earnedIncomeCredit', '/totalCtcAndOdc', '/additionalCtc', '/cdccTotalCredit',
  '/qualifiedSaverCreditAmount', '/totalEdc', '/netPtcAmount', '/flowIsKnockedOut',
];
const derivedPaths = new Set(wrapped.filter((f) => f.derived).map((f) => f.path));
const missing = REQUIRED.filter((p) => !derivedPaths.has(p));
if (missing.length) throw new Error(`required paths not derived facts in dictionary: ${missing}`);
// every non-collection derived fact exported to MeF, in addition
const mefPaths = rawFacts
  .filter((r) => r.Export && r.Export['@mef'] === 'true' && r.Derived && !r['@path'].includes('*'))
  .map((r) => r['@path'])
  .filter((p) => !REQUIRED.includes(p))
  .sort();
// Further non-MeF derived facts read by later modules, appended after the MeF ones (so the rows above keep their
// order). Append only. Issue #20: filing-status eligibility and recommendation (filingStatus.xml, filers.xml).
const EXTRA = [
  '/maritalStatusAllowsFilingMarried', '/eligibleForMFJ', '/eligibleForMFS', '/eligibleForSingle', '/eligibleForHoh',
  '/eligibleForQss', '/filerCouldQualifyForHoh', '/filerCouldQualifyForQss', '/isFilingStatusValid',
  '/hasMultipleEligibleFilingStatuses', '/recommendedFilingStatus', '/treatAsMFJ', '/treatAsMFS', '/treatAsHoh',
].filter((p) => !REQUIRED.includes(p) && !mefPaths.includes(p));
const missingExtra = EXTRA.filter((p) => !derivedPaths.has(p));
if (missingExtra.length) throw new Error(`extra paths not derived facts in dictionary: ${missingExtra}`);
const OUTPUTS = [...REQUIRED, ...mefPaths, ...EXTRA];

// ---------- helpers ----------
const csv = (s) => (/[",\n\r]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s);

// Flatten a persisted writable item into a single string.
function flattenItem(wrapper) {
  const t = String(wrapper.$type || '').replace('gov.irs.factgraph.persisters.', '');
  const it = wrapper.item;
  if (it === null || typeof it !== 'object') return String(it);
  switch (t) {
    case 'EnumWrapper': return it.value.join(';');
    case 'MultEnumWrapper': return it.values.join(';');
    case 'DayWrapper': return it.date;
    case 'CollectionWrapper': return it.items.join(';');
    case 'CollectionItemWrapper': return it.id;
    case 'TinWrapper': return `${it.area}-${it.group}-${it.serial}`;
    case 'EinWrapper': return `${it.prefix}-${it.serial}`;
    default: return JSON.stringify(it);
  }
}
function read(graph, p) {
  const r = graph.get(p);
  if (r.complete) return [String(r.get), 'Complete'];
  if (r.hasValue) return [String(r.get), 'Placeholder'];
  return ['', 'Incomplete'];
}

// ---------- run ----------
const files = fs.readdirSync(scenDir).filter((f) => f.endsWith('.json')).sort();
const rows = ['scenario,path,value,completeness'];
const CORE = ['/agi', '/totalIncome', '/taxableIncome', '/totalTax', '/totalPayments', '/overpayment', '/balanceDue'];
// knockedOut: /flowIsKnockedOut is Complete=true. notKnockedOut: Complete=false.
// notKnockedOutPlaceholder: engine returns the placeholder default false (some knockout input unanswered).
const summary = {
  total: 0, knockedOut: 0, notKnockedOut: 0, notKnockedOutPlaceholder: 0, coreComplete: 0,
  coreCompleteAndNotKnockedOut: 0, knockedOutScenarios: [], errors: [],
};
for (const file of files) {
  const name = file.replace(/\.json$/, '');
  const json = JSON.parse(fs.readFileSync(path.join(scenDir, file), 'utf-8'));
  const facts = json.facts ?? json;
  summary.total++;
  for (const [p, w] of Object.entries(facts)) rows.push([name, p, flattenItem(w), 'Complete'].map(csv).join(','));
  let graph;
  try {
    graph = sfg.GraphFactory.apply(dictionary, sfg.JSPersister.create(JSON.stringify(facts)));
  } catch (e) {
    summary.errors.push(`${name}: ${e.message}`);
    continue;
  }
  const out = {};
  for (const p of OUTPUTS) {
    let v, c;
    try { [v, c] = read(graph, p); } catch (e) { v = `ERROR: ${e.message}`; c = 'Error'; }
    out[p] = [v, c];
    rows.push([name, p, v, c].map(csv).join(','));
  }
  const ko = out['/flowIsKnockedOut'];
  const isKo = ko[1] === 'Complete' && ko[0] === 'true';
  if (isKo) { summary.knockedOut++; summary.knockedOutScenarios.push(name); }
  else if (ko[1] === 'Complete') summary.notKnockedOut++;
  else summary.notKnockedOutPlaceholder++;
  const core = CORE.every((p) => out[p][1] === 'Complete');
  if (core) summary.coreComplete++;
  if (core && !isKo) summary.coreCompleteAndNotKnockedOut++;
}
const text = rows.join('\n') + '\n';
fs.writeFileSync(OUT, text);
const sha = crypto.createHash('sha256').update(text).digest('hex');
console.log(JSON.stringify({ ...summary, errors: summary.errors.length, mefExtraPaths: mefPaths.length, rows: rows.length - 1, bytes: text.length, sha256: sha }, null, 1));
for (const e of summary.errors) console.error('ERROR', e);
fs.writeFileSync(OUT.replace(/\.csv$/, '') + '.summary.json', JSON.stringify({ ...summary, sha256: sha, mefExtraPaths: mefPaths.length }, null, 1) + '\n');
