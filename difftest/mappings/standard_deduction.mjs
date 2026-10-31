// Mapping for catala/standard_deduction.catala_en (scope StandardDeduction): Form 1040 line 12.
// Run: make difftest SCOPE=standard_deduction
//
// Inputs that the oracle does not export (blind / 65+ flags per filer, /treatFilersAsDependents) are
// rebuilt as follows; the limits are stated here so the pass count is read honestly.
//  - The oracle exports /additionalStandardDeductionItems (n). It is fed back as n flags in the order
//    primary blind, primary 65+, secondary blind, secondary 65+. The spouse-gating rules (MFJ, MFS with
//    an eligible spouse) therefore are NOT independently tested here; they are covered by the unit
//    tests in catala/tests/test_standard_deduction.catala_en. A single filer can never exceed n = 2
//    in the data, so a wrong gating for Single/HoH would still show as a failure of /standardDeduction.
//  - treat_filers_as_dependents is approximated from the raw facts: a filer with /filers/*/canBeClaimed
//    and /filers/*/potentialClaimerMustFile both true (filers.xml
//    /primaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits). The oracle's four
//    reduced-deduction scenarios are exactly these.
import { collectionIds } from '../lib.mjs';

const FS = {
  single: 'Single',
  marriedFilingJointly: 'MarriedFilingJointly',
  marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold',
  qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};
const val = (facts, p) => facts.get(p)?.value;
const items = (facts) => Number(val(facts, '/additionalStandardDeductionItems') ?? '0');

export default {
  name: 'standard_deduction',
  scope: 'StandardDeduction',
  file: 'catala/standard_deduction.catala_en',
  appliesTo: () => true,
  inputs: {
    filing_status: (f) => FS[val(f, '/filingStatus')],
    treat_as_mfs: (f) => val(f, '/filingStatus') === 'marriedFilingSeparately',
    primary_filer_is_blind: (f) => items(f) >= 1,
    primary_filer_age65_or_older: (f) => items(f) >= 2,
    secondary_filer_is_blind: (f) => items(f) >= 3,
    secondary_filer_age65_or_older: (f) => items(f) >= 4,
    is_widowed_in_tax_year: () => false,
    mfj_deceased_spouse_reached_age65: () => false,
    mfs_spouse_65_or_older: (f) => items(f) >= 4,
    mfs_spouse_provides_no_benefits: () => false,
    treat_filers_as_dependents: (f) =>
      collectionIds(f, '/filers').some(
        (id) => val(f, `/filers/#${id}/canBeClaimed`) === 'true' &&
                val(f, `/filers/#${id}/potentialClaimerMustFile`) === 'true'),
    employer_income_subtotal: (f) => Number(val(f, '/employerIncomeSubtotal') ?? '0'),
  },
  outputs: [
    { oracle: '/standardDeduction', catala: 'standard_deduction', type: 'money' },
    { oracle: '/additionalStandardDeductionItems', catala: 'additional_standard_deduction_items', type: 'int' },
  ],
};
