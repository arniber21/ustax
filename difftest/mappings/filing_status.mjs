// Mapping for catala/filing_status.catala_en (scope FilingStatusReturn: Filers, then the household HoH/QSS
// counts, then the filing-status check). Issue #20.
// Run: make difftest SCOPE=filing_status                (oracle/facts.csv, the 161 backend scenarios)
//      make difftest-filing-status-graphs               (oracle/fact_graphs.csv, the 27 filing-status fact graphs
//                                                         of direct-file/docs/testing/fact-graphs)
//
// Inputs are the scenario's writable facts. The Filers inputs and their defaults for unasked facts are those of
// filers.mjs (same reasons). The household is /familyAndHousehold: each member's writable facts are read through
// the per-person helpers of qualifying_child.mjs, qualifying_relative.mjs and dependents_benefit_split.mjs (which
// read `/familyAndHousehold/*/<fact>`), applied to a view of the scenario that maps `*` to that member's id.
// tpPaidMostOfHomeUpkeep and tpPaidMostOfParentHomeUpkeep default to false, as in hoh_qss_persons.mjs.
//
// Oracle facts (generate.mjs EXTRA list, issue #20): /maritalStatusAllowsFilingMarried, /eligibleFor{MFJ,MFS,Single,
// Hoh,Qss}, /filerCouldQualifyFor{Hoh,Qss}, /isFilingStatusValid, /hasMultipleEligibleFilingStatuses,
// /recommendedFilingStatus, /treatAs{MFJ,MFS,Hoh}. The Enum /recommendedFilingStatus is compared as five booleans
// `/recommendedFilingStatus=<option>` (one per DF option) that this mapping adds to the scenario's oracle rows,
// with the completeness of the DF row, because the runner reads scalar Catala outputs only.
import filers from './filers.mjs';
import { person } from './qualifying_child.mjs';
import { answers } from './qualifying_relative.mjs';
import { splitAnswers } from './dependents_benefit_split.mjs';

const P = '/familyAndHousehold/*/';
const val = (f, p) => f.get(p)?.value;

// One household member: the scenario facts with `/familyAndHousehold/*/x` read from `/familyAndHousehold/#id/x`.
function memberView(f, id) {
  const real = (p) => (p.startsWith(P) ? `/familyAndHousehold/#${id}/${p.slice(P.length)}` : p);
  return { get: (p) => f.get(real(p)), has: (p) => f.has(real(p)) };
}

function members(f) {
  const c = f.get('/familyAndHousehold');
  const ids = c && c.value !== '' ? c.value.split(';') : [];
  return ids.map((id) => {
    const m = memberView(f, id);
    return {
      dependent: { person: person(m), answers: answers(m), split: splitAnswers(m) },
      upkeep: {
        tp_paid_most_of_home_upkeep: val(m, P + 'tpPaidMostOfHomeUpkeep') === 'true',
        tp_paid_most_of_parent_home_upkeep: val(m, P + 'tpPaidMostOfParentHomeUpkeep') === 'true',
      },
    };
  });
}

const OPTIONS = {
  single: 'recommended_is_single', marriedFilingJointly: 'recommended_is_mfj',
  marriedFilingSeparately: 'recommended_is_mfs', headOfHousehold: 'recommended_is_hoh',
  qualifiedSurvivingSpouse: 'recommended_is_qss',
};
// Adds the five `/recommendedFilingStatus=<option>` rows (see the header). Idempotent.
function addRecommendationRows(f) {
  const r = f.get('/recommendedFilingStatus');
  if (!r) return;
  for (const o of Object.keys(OPTIONS)) {
    f.set(`/recommendedFilingStatus=${o}`, { value: String(r.value === o), completeness: r.completeness });
  }
}

// The Filers inputs of filers.mjs, without the two that only FilersStandardDeduction takes and without
// eligible_for_hoh, which FilingStatusReturn computes.
const { eligible_for_hoh, mfs_spouse_65_or_older, employer_income_subtotal, ...filersInputs } = filers.inputs;

const b = (oracle, catala) => ({ oracle, catala, type: 'bool' });

// Single stays selectable for an unmarried filer who is also eligible for HoH or QSS (issue #20 decision), so
// /eligibleForSingle, /hasMultipleEligibleFilingStatuses and /isFilingStatusValid follow DF there.
//
// DF-BUG-19 (issue #19, docs/direct-file-bugs.md): a married filer living apart is "considered unmarried" (IRC 7703(b))
// only through a child the filer is entitled to claim under section 151. In these two fact graphs the only child is
// a 4-year-old biological son who is not a citizen, resident or national (fails 152(b)(3)), so he is not a dependent:
// DF makes the filer a head of household, we do not, and the chosen HoH status is knocked out here.
const knownDivergence = ['considered_unmarried_for_HOH_nondependent_hoh-qp_1940_TN',
  'considered_unmarried_for_HOH_nondependent_hoh-qp_1995_TN']
  .flatMap((scenario) => ['/eligibleForHoh', '/isFilingStatusValid'].map((path) => ({
    bug: 'DF-BUG-19', scenario, path,
    note: 'married, lived apart, only child fails the citizen or resident test: IRC 7703(b)(1) needs a claimable child',
  })));

export default {
  name: 'filing_status',
  scope: 'FilingStatusReturn',
  file: 'catala/filing_status.catala_en',
  appliesTo: (f) => {
    if (!f.has('/eligibleForMFJ')) return 'oracle has no filing-status rows (regenerate: make oracle)';
    addRecommendationRows(f);
    return true;
  },
  inputs: { ...filersInputs, members },
  outputs: [
    b('/maritalStatusAllowsFilingMarried', 'marital_status_allows_filing_married'),
    b('/eligibleForMFJ', 'eligible_for_mfj'),
    b('/eligibleForMFS', 'eligible_for_mfs'),
    b('/eligibleForSingle', 'eligible_for_single'),
    b('/eligibleForHoh', 'eligible_for_hoh'),
    b('/eligibleForQss', 'eligible_for_qss'),
    b('/filerCouldQualifyForHoh', 'filer_could_qualify_for_hoh'),
    b('/filerCouldQualifyForQss', 'filer_could_qualify_for_qss'),
    b('/isFilingStatusValid', 'is_filing_status_valid'),
    b('/hasMultipleEligibleFilingStatuses', 'has_multiple_eligible_filing_statuses'),
    ...Object.entries(OPTIONS).map(([o, c]) => b(`/recommendedFilingStatus=${o}`, c)),
    b('/treatAsMFJ', 'treat_as_mfj'),
    b('/treatAsMFS', 'treat_as_mfs'),
    b('/treatAsHoh', 'treat_as_hoh'),
  ],
  knownDivergence,
};
