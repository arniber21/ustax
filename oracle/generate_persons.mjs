// Per-person Direct File oracle for the household modules (issue #16 and later).
//
// Usage: node generate_persons.mjs [--direct-file DIR] [--out FILE]
//   Same engine and DIR default as generate.mjs. Writes oracle/persons.csv (default).
//
// oracle/facts.csv (generate.mjs) holds only non-collection derived facts, so per-person facts
// such as /familyAndHousehold/*/qualifyingChild are not in it. This script runs the same
// engine on the same scenarios and writes one pseudo-scenario per household member:
//   scenario  = <scenario>~<person uuid>
//   rows      = that person's writable facts and the derived facts in PERSON_FACTS, under the
//               path /familyAndHousehold/*/<fact>, plus the scenario-level facts in SCENARIO_FACTS.
// The CSV format is that of facts.csv, so difftest/run.mjs reads it with --oracle oracle/persons.csv.
//
// The engine setup (XML -> digest -> dictionary) is copied from generate.mjs, which runs at
// module top level and cannot be imported.
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
const OUT = path.resolve(arg('--out', path.join(here, 'persons.csv')));
const TAX_YEAR = '2024';

const bundle = path.join(DF, 'df-client/js-factgraph-scala/src/main.js');
const taxDir = path.join(DF, 'backend/src/main/resources/tax');
const scenDir = path.join(DF, 'backend/src/test/resources/scenarios');
for (const p of [bundle, taxDir, scenDir]) {
  if (!fs.existsSync(p)) {
    console.error(`missing ${p}; set DIRECT_FILE or --direct-file to the direct-file/direct-file checkout`);
    process.exit(2);
  }
}
const sfg = createRequire(import.meta.url)(bundle);

// ---------- fact dictionary: XML -> digest (same as generate.mjs) ----------
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
const wrapped = readRawFacts().map((r) => ({
  path: r['@path'],
  writable: r.Writable ? processWritable(r.Writable) : null,
  derived: r.Derived ? processDerived(r.Derived) : null,
  placeholder: r.Placeholder ? processDerived(r.Placeholder) : null,
}));
const meta = new sfg.DigestMetaWrapper(TAX_YEAR).toNative();
const digest = wrapped.map((f) =>
  sfg.DigestNodeWrapperFactory.toNative(new sfg.DigestNodeWrapper(f.path, f.writable, f.derived, f.placeholder))
);
const dictionary = sfg.FactDictionaryFactory.fromConfig(sfg.FactDictionaryConfig.create(meta, digest));

// ---------- which facts to read ----------
// Derived per-person facts (familyAndHousehold.xml, dependentsRelationship.xml). Add more here as
// later household modules (#17, #18, #19) need them; append only, so existing rows never change.
const PERSON_FACTS = [
  'relationship', 'age', 'ageAtFirstHalfOfYear', 'qcRelationshipTest', 'studentStatusMayAffectBenefits',
  'isAStudentUnder24', 'disabilityStatusMayAffectBenefits', 'ageTest', 'residencyTest', 'jointReturn',
  'requiredToFile', 'filingOnlyForRefund', 'qcSupportTest', 'jointReturnTest', 'qualifyingChild',
  'couldBeQualifyingChildOfAnother', 'qcOfAnotherButNot', 'isQualifyingChildOfAnother',
  // Issue #17: qualifying relative and eligible dependent.
  'askAboutQCOfAnother', 'notQualifyingChildTest', 'qrRelationshipTest', 'memberOfHouseholdTest',
  'relationshipMemberOfHouseholdTest', 'qrSupportTest', 'qualifyingRelativeMinusNotQcTest', 'qualifyingRelative',
  'usResident', 'usNational', 'canadaMexicoResident', 'childIsAdopted', 'adoptedChildException',
  'citizenOrUsResidentTest', 'citizenOrResidentTest', 'qcOrQr', 'eligibleDependentMinusFilerInformation',
  'eligibleDependent', 'isClaimedDependent', 'isClaimedIfClaimable',
  // dependentsBenefitSplit.xml (issue #18), read by eligibleDependentMinusFilerInformation.
  'tpCanClaimSplitBenefitsHohEitcCdcc', 'disqualifiedDueToParentalCustody',
  // Issue #18: the rest of dependentsBenefitSplit.xml (per-person facts, file order).
  'childMayQualifyForBenefitSplit', 'tpIsParent', 'tpIsNotParent', 'parentalSomeParentNotClaiming',
  'primaryFilerNotClaiming', 'bothFilersNotClaiming', 'otherParentNotClaiming', 'hadEqualNumberOfNightsWithParents',
  'parentsAreDivorcedSeparatedOrLivingApart', 'tpIsCustodialParent', 'contradictory8832TPIsCustodialParent',
  'contradictory8832TPNotCustodialParent', 'contradictory8832Knockout', 'causesNoncustodialParentBenefitSplitKnockout',
  'eligibleForBenefitSplit', 'reachedNonParentalBenefitSplit',
  // Issue #27: CTC and ODC per person.
  'ssnValidForEmployment', 'eligibleCtc', 'eligibleOdc',
  // Issue #19: HoH and QSS qualifying persons (familyAndHousehold.xml, dependentsRelationship.xml).
  'marriedHohRelationshipTest', 'qssPersonResidencyTest', 'isBiologicalAdoptedFosterOrStepchild',
  'flowAddPersonKeepingUpHome', 'flowAddPersonKeepingUpParentsHome', 'hohQualifyingPerson', 'qssQualifyingPerson',
  'personQualifiesTPforHoH', 'personQualifiesTPforQss',
];
const SCENARIO_FACTS = [
  '/flowIsKnockedOut', '/minimumFilerDateOfBirth', '/treatAsMFJ',
  // Issue #17: filers.xml facts read by eligibleDependent and adoptedChildException.
  '/treatFilersAsDependents', '/eitherFilerUSCitizenOrNational',
  // Issue #18: the household benefit-split knockouts (dependentsBenefitSplit.xml, read by flow.xml).
  '/knockedOutByContradictory8832', '/knockedOutByNonCustodialParentBenefitSplit',
  // Issue #19: filers.xml and filingStatus.xml facts read by the HoH and QSS person tests, and the
  // household HoH/QSS facts of familyAndHousehold.xml and filingStatus.xml.
  '/eligibleForMFJ', '/filerCouldQualifyForHoh', '/filerCouldQualifyForQss', '/mfsFilerCouldBeConsiderUnmarriedForCdcc',
  '/hasHohQualifyingParent', '/hasHohQualifyingChild', '/qssQualifyingClaimedDependentCount', '/eligibleForHoh',
  '/eligibleForQss',
];
const known = new Set(wrapped.map((f) => f.path));
for (const f of PERSON_FACTS) {
  if (!known.has(`/familyAndHousehold/*/${f}`)) throw new Error(`not in dictionary: /familyAndHousehold/*/${f}`);
}

// ---------- helpers (same as generate.mjs) ----------
const csv = (s) => (/[",\n\r]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s);
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
  let r;
  try { r = graph.get(p); } catch (e) { return [`ERROR: ${e.message}`, 'Error']; }
  if (r.complete) return [String(r.get), 'Complete'];
  if (r.hasValue) return [String(r.get), 'Placeholder'];
  return ['', 'Incomplete'];
}

// ---------- run ----------
const files = fs.readdirSync(scenDir).filter((f) => f.endsWith('.json')).sort();
const rows = ['scenario,path,value,completeness'];
let persons = 0, scenariosWithPersons = 0;
for (const file of files) {
  const name = file.replace(/\.json$/, '');
  const facts = JSON.parse(fs.readFileSync(path.join(scenDir, file), 'utf-8')).facts;
  const coll = facts['/familyAndHousehold'];
  const ids = coll ? coll.item.items : [];
  if (!ids.length) continue;
  scenariosWithPersons++;
  const graph = sfg.GraphFactory.apply(dictionary, sfg.JSPersister.create(JSON.stringify(facts)));
  const scen = SCENARIO_FACTS.map((p) => [p, ...read(graph, p)]);
  const fs0 = facts['/filingStatus'];
  if (fs0) scen.push(['/filingStatus', flattenItem(fs0), 'Complete']);
  for (const id of ids) {
    persons++;
    const sc = `${name}~${id}`;
    for (const [p, v, c] of scen) rows.push([sc, p, v, c].map(csv).join(','));
    const prefix = `/familyAndHousehold/#${id}/`;
    for (const [p, w] of Object.entries(facts)) {
      if (p.startsWith(prefix)) {
        rows.push([sc, `/familyAndHousehold/*/${p.slice(prefix.length)}`, flattenItem(w), 'Complete'].map(csv).join(','));
      }
    }
    for (const f of PERSON_FACTS) {
      const [v, c] = read(graph, `${prefix}${f}`);
      rows.push([sc, `/familyAndHousehold/*/${f}`, v, c].map(csv).join(','));
    }
  }
}
const text = rows.join('\n') + '\n';
fs.writeFileSync(OUT, text);
const sha = crypto.createHash('sha256').update(text).digest('hex');
console.log(JSON.stringify({ scenariosWithPersons, persons, rows: rows.length - 1, bytes: text.length, sha256: sha }));
