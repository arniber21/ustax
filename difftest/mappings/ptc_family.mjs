// Mapping for catala/ptc_family.catala_en (scope PtcFamily): Form 8962 lines 1 to 8, issue #32.
// Run: make difftest SCOPE=ptc_family
//
// Inputs come from the oracle's own derived values for the facts other modules compute:
//   filing_status                     /filingStatus
//   claimed_dependents_count          count of /familyAndHousehold/*/isClaimedDependent = true over the
//                                     scenario's people in oracle/persons.csv (facts.csv has no
//                                     /claimedDependentsCount row)
//   primary/secondary_someone_can_claim_for_tax_benefits   /primarySomeoneCanClaimForTaxBenefits, /secondary...
//   lived_in_ak                       /filerResidenceAndIncomeState = ak (lived_in_hi: Direct File offers no Hawaii)
//   agi, tax_exempt_interest          /agi, /taxExemptInterest
//   non_taxable_social_security_benefits   /socialSecurityBenefits - /taxableSocialSecurityBenefits
//                                     (socialSecurity.xml /nonTaxableSocialSecurityBenefits, not in the oracle)
// Compared: /taxFamilySize, /federalPovertyLevelThreshold, /ptcMagi, /householdIncome,
// /householdIncomeAsPercent, /ptcAnnualContributionAmount, /ptcMontlyContributionAmount.
// /applicableFigure and /federalPovertyLocation are not oracle rows; the figure is checked through line 8a/8b
// and in full against the printed Table 2 by catala/tests/test_ptc_table2.catala_en.
import { collectionIds, loadOracle } from '../lib.mjs';

const val = (f, p) => f.get(p)?.value;
const money = (f, p) => {
  const v = val(f, p);
  if (v === undefined || v === '') return 0;
  return Number(v);
};
const FS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};

// The runner passes only the facts of a scenario, so the scenario is found by comparing the facts with
// oracle/facts.csv (as difftest/mappings/ctc_odc_household.mjs does).
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
function claimedDependents(f) {
  const ids = collectionIds(f, '/familyAndHousehold');
  if (ids.length === 0) return 0;
  if (!persons) persons = loadOracle(new URL('../../oracle/persons.csv', import.meta.url).pathname);
  const s = scenarioName(f);
  let n = 0;
  for (const id of ids) {
    const p = persons.get(`${s}~${id}`);
    if (!p) throw new Error(`no per-person oracle for ${s}~${id}: make oracle-persons`);
    if (p.get('/familyAndHousehold/*/isClaimedDependent')?.value === 'true') n++;
  }
  return n;
}

export default {
  name: 'ptc_family',
  scope: 'PtcFamily',
  file: 'catala/ptc_family.catala_en',
  appliesTo: () => true,
  inputs: {
    filing_status: (f) => FS[val(f, '/filingStatus')],
    claimed_dependents_count: claimedDependents,
    primary_someone_can_claim_for_tax_benefits: (f) => val(f, '/primarySomeoneCanClaimForTaxBenefits') === 'true',
    secondary_someone_can_claim_for_tax_benefits: (f) => val(f, '/secondarySomeoneCanClaimForTaxBenefits') === 'true',
    lived_in_ak: (f) => val(f, '/filerResidenceAndIncomeState') === 'ak',
    lived_in_hi: () => false,
    agi: (f) => money(f, '/agi'),
    tax_exempt_interest: (f) => money(f, '/taxExemptInterest'),
    non_taxable_social_security_benefits: (f) =>
      Math.round((money(f, '/socialSecurityBenefits') - money(f, '/taxableSocialSecurityBenefits')) * 100) / 100,
  },
  outputs: [
    { oracle: '/taxFamilySize', catala: 'tax_family_size', type: 'int' },
    { oracle: '/federalPovertyLevelThreshold', catala: 'federal_poverty_level_threshold', type: 'money' },
    { oracle: '/ptcMagi', catala: 'ptc_magi', type: 'money' },
    { oracle: '/householdIncome', catala: 'household_income', type: 'money' },
    { oracle: '/householdIncomeAsPercent', catala: 'household_income_as_percent', type: 'int' },
    { oracle: '/ptcAnnualContributionAmount', catala: 'ptc_annual_contribution_amount', type: 'money' },
    { oracle: '/ptcMontlyContributionAmount', catala: 'ptc_monthly_contribution_amount', type: 'money' },
  ],
};
