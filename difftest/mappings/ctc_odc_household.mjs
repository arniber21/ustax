// Mapping for catala/tests/difftest_ctc_odc.catala_en (scope CtcOdcFromHousehold): Ctc_odc.CtcOdcDependents
// feeding Ctc_odc.Schedule8812, issue #27. Run: make difftest SCOPE=ctc_odc_household
//
// The household members are built from oracle/persons.csv (oracle/generate_persons.mjs), with the same
// person/answers mapping as qualifying_child.mjs and qualifying_relative.mjs, plus the CTC answer
// ssnEmploymentValidity. The filer facts /minimumFilerDateOfBirth, /treatFilersAsDependents and
// /eitherFilerUSCitizenOrNational are DF's own values from persons.csv (as in qualifying_relative.mjs).
// The return figures are the oracle values of ctc_odc.mjs.
//
// ssnEmploymentValidity missing: Neither. In the oracle it is missing for 39 persons; of those with an
// SSN who are claimed, none is a qualifying child (checked when writing this mapping), so the value
// is never read by eligibleCtc.
import { collectionIds, loadOracle } from '../lib.mjs';
import { person } from './qualifying_child.mjs';
import { answers } from './qualifying_relative.mjs';
import { scheduleInputs } from './ctc_odc.mjs';

const P = '/familyAndHousehold/*/';
const upper = (s) => s.charAt(0).toUpperCase() + s.slice(1);

// The runner passes only the facts of a scenario, not its name, and the same person uuid occurs in
// several scenarios (with different answers), so the scenario is found by comparing the facts with
// oracle/facts.csv row by row.
let persons;
let scenarios;
function scenarioName(f) {
  if (!scenarios) scenarios = loadOracle(new URL('../../oracle/facts.csv', import.meta.url).pathname);
  for (const [name, g] of scenarios) {
    if (g.size !== f.size) continue;
    let same = true;
    for (const [p, r] of f) {
      const q = g.get(p);
      if (!q || q.value !== r.value || q.completeness !== r.completeness) { same = false; break; }
    }
    if (same) return name;
  }
  throw new Error('scenario not found in oracle/facts.csv');
}
function personFacts(scenario, id) {
  if (!persons) persons = loadOracle(new URL('../../oracle/persons.csv', import.meta.url).pathname);
  const p = persons.get(`${scenario}~${id}`);
  if (!p) throw new Error(`no per-person oracle for ${scenario}~${id}: make oracle-persons`);
  return p;
}
function members(f) {
  const ids = collectionIds(f, '/familyAndHousehold');
  if (ids.length === 0) return [];
  const s = scenarioName(f);
  return ids.map((id) => personFacts(s, id));
}

export function householdMember(pf) {
  return {
    member: { person: person(pf), answers: answers(pf) },
    ssn_employment_validity: upper(pf.get(P + 'ssnEmploymentValidity')?.value || 'neither'),
  };
}

// A filer fact from the first member's per-person rows; with no household members it is never read.
const filerFact = (path, dflt) => (f) => {
  const ms = members(f);
  if (ms.length === 0) return dflt;
  const r = ms[0].get(path);
  if (!r || r.completeness !== 'Complete') throw new Error(`oracle fact ${path} not Complete`);
  return typeof dflt === 'boolean' ? r.value === 'true' : r.value;
};

const i = (o, c) => ({ oracle: `/${o}`, catala: c, type: 'int' });
const m = (o, c) => ({ oracle: `/${o}`, catala: c, type: 'money' });

export default {
  name: 'ctc_odc_household',
  scope: 'CtcOdcFromHousehold',
  file: 'catala/tests/difftest_ctc_odc.catala_en',
  appliesTo: () => true,
  inputs: {
    household_members: (f) => members(f).map(householdMember),
    minimum_filer_date_of_birth: filerFact('/minimumFilerDateOfBirth', '1980-01-01'),
    treat_filers_as_dependents: filerFact('/treatFilersAsDependents', false),
    either_filer_us_citizen_or_national: filerFact('/eitherFilerUSCitizenOrNational', true),
    ...scheduleInputs,
  },
  outputs: [
    i('ctcEligibleDependents', 'ctc_eligible_dependents'),
    i('odcEligibleDependents', 'odc_eligible_dependents'),
    m('totalPotentialCtc', 'total_potential_ctc'),
    m('totalPotentialOdc', 'total_potential_odc'),
    m('totalCtcAndOdc', 'total_ctc_and_odc'),
    m('totalPotentialActc', 'total_potential_actc'),
    { oracle: '/threeOrMoreCtcEligibleDependents', catala: 'three_or_more_ctc_eligible_dependents', type: 'bool' },
    m('additionalCtc', 'additional_ctc'),
  ],
  knownDivergence: [],
};
