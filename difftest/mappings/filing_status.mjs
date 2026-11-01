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
import { loadOracle } from '../lib.mjs';
import filers from './filers.mjs';
import { person } from './qualifying_child.mjs';
import { answers } from './qualifying_relative.mjs';
import { splitAnswers } from './dependents_benefit_split.mjs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { existsSync } from 'node:fs';

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

// DF-BUG(20-a): DF /eligibleForSingle is "not maritalStatusAllowsFilingMarried"; IRC 1(c) excludes heads of household
// and surviving spouses from the single rates (Pub 501 p 6: single only if "you don't qualify for another filing
// status"). Wherever DF has eligibleForSingle and (eligibleForHoh or eligibleForQss), we differ on:
//   /eligibleForSingle (DF true, we false);
//   /hasMultipleEligibleFilingStatuses when single was DF's second option (DF true, we false);
//   /isFilingStatusValid when the chosen status is single (DF true, we false: knocked out).
// The list is computed from the DF values of both oracle files, so it names exactly the scenarios where the bug's
// condition holds; the runner still reports each one as a divergence, never as a pass.
const here = dirname(fileURLToPath(import.meta.url));

// DF-BUG-19 (issue #19, docs/direct-file-bugs.md): a married filer living apart is "considered unmarried" (IRC 7703(b))
// only through a child the filer is entitled to claim under section 151. In these two fact graphs the only child is
// a 4-year-old biological son who is not a citizen, resident or national (fails 152(b)(3)), so he is not a dependent:
// DF makes the filer a head of household, we do not, and the chosen HoH status is knocked out here.
const DF_BUG_19 = ['considered_unmarried_for_HOH_nondependent_hoh-qp_1940_TN', 'considered_unmarried_for_HOH_nondependent_hoh-qp_1995_TN']
  .flatMap((scenario) => ['/eligibleForHoh', '/isFilingStatusValid'].map((path) => ({
    bug: 'DF-BUG-19', scenario, path,
    note: 'married, lived apart, only child fails the citizen or resident test: IRC 7703(b)(1) needs a claimable child',
  })));

let divergences = null; // computed on first use (every mapping is imported by run.mjs, even when not run)
function knownDivergence() {
  if (divergences) return divergences;
  divergences = [...DF_BUG_19];
  for (const file of ['oracle/facts.csv', 'oracle/fact_graphs.csv']) {
    const path = resolve(here, '../..', file);
    if (!existsSync(path)) continue;
    for (const [scenario, f] of loadOracle(path)) {
      const t = (p) => val(f, p) === 'true';
      if (!(t('/eligibleForSingle') && (t('/eligibleForHoh') || t('/eligibleForQss')))) continue;
      const other = t('/eligibleForHoh') ? 'HoH' : 'QSS';
      const note = `unmarried filer eligible for ${other}: IRC 1(c) and Pub 501 p 6 exclude single`;
      divergences.push({ bug: 'DF-BUG(20-a)', scenario, path: '/eligibleForSingle', note });
      const count = ['/eligibleForMFJ', '/eligibleForMFS', '/eligibleForSingle', '/eligibleForHoh', '/eligibleForQss']
        .filter(t).length;
      if (count === 2) {
        divergences.push({ bug: 'DF-BUG(20-a)', scenario, path: '/hasMultipleEligibleFilingStatuses', note });
      }
      if (val(f, '/filingStatus') === 'single') {
        divergences.push({ bug: 'DF-BUG(20-a)', scenario, path: '/isFilingStatusValid',
          note: `${note}; the return chose single, so it is knocked out (ko_filing_status_not_eligible)` });
      }
    }
  }
  return divergences;
}

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
  get knownDivergence() { return knownDivergence(); },
};
