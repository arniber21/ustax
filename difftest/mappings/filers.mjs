// Mapping for catala/filers.catala_en (scope FilersStandardDeduction): filers module plus the
// standard deduction it feeds. Run: make difftest SCOPE=filers
//
// Inputs are the oracle's writable facts. The oracle gives every scenario two /filers entries
// (even a single filer), exactly one with isPrimaryFiler = true. Facts DF does not store for a
// scenario (never asked) get the defaults below; each default is a value that DF's own rules
// never read in that scenario (a guard on the filing status or marital status keeps it unused),
// so none of them can mask a mismatch for a checked output. Checked outputs (DF paths):
//   /standardDeduction, /additionalStandardDeductionItems, /isSpouse65OrOlder (Complete rows only),
//   /secondaryFilerIsBlindIndicatorXml, /xmlOver65SRIndicator,
//   /primarySomeoneCanClaimForTaxBenefits, /secondarySomeoneCanClaimForTaxBenefits.
// Not provided by the oracle, so approximated: /eligibleForHoh (household module, #19/#20; here
// "filing status is HoH", it only feeds the community-property knockout which is not compared).
import { collectionIds } from '../lib.mjs';

const val = (f, p) => f.get(p)?.value;
const bool = (f, p, d = false) => { const v = val(f, p); return v === undefined || v === '' ? d : v === 'true'; };
const upper = (s) => s.charAt(0).toUpperCase() + s.slice(1);

const FS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};
const MARITAL = { single: 'NeverMarried', married: 'Married', divorced: 'Divorced', widowed: 'Widowed' };
const DEATH = {
  taxYear: 'DiedInTaxYear', taxYearMinusOne: 'DiedTaxYearMinusOne', taxYearMinusTwo: 'DiedTaxYearMinusTwo',
  beforeTaxYearMinusTwo: 'DiedBeforeTaxYearMinusTwo',
};

function filerIds(f) {
  const ids = collectionIds(f, '/filers');
  const primary = ids.find((id) => val(f, `/filers/#${id}/isPrimaryFiler`) === 'true');
  if (!primary) throw new Error('no primary filer in scenario');
  const secondary = ids.find((id) => id !== primary);
  return { primary, secondary };
}

function answers(f, id) {
  const p = (n) => `/filers/#${id}/${n}`;
  return {
    // A missing date of birth (secondary entry of a one-filer return) is never read: every rule that
    // uses the secondary date is guarded by the MFJ filing status. 1990-06-15 is an arbitrary adult date.
    date_of_birth: val(f, p('dateOfBirth')) || '1990-06-15',
    is_blind: bool(f, p('isBlind')),
    can_be_claimed: bool(f, p('canBeClaimed')),
    will_be_claimed: bool(f, p('willBeClaimed')),
    potential_claimer_must_file: bool(f, p('potentialClaimerMustFile')),
    potential_claimer_did_file: bool(f, p('potentialClaimerDidFile')),
    is_us_citizen_full_year: bool(f, p('isUsCitizenFullYear')),
    writable_citizen_at_end_of_tax_year: bool(f, p('writableCitizenAtEndOfTaxYear')),
    writable_is_noncitizen_resident_full_year: bool(f, p('writableIsNoncitizenResidentFullYear')),
    writable_is_national: bool(f, p('writableIsNational')),
  };
}

export default {
  name: 'filers',
  scope: 'FilersStandardDeduction',
  file: 'catala/filers.catala_en',
  appliesTo: () => true,
  inputs: {
    filing_status: (f) => FS[val(f, '/filingStatus')],
    marital_status: (f) => MARITAL[val(f, '/maritalStatus')],
    // Asked only of widowed filers; DF reads it only under isWidowed.
    year_of_spouse_death: (f) => DEATH[val(f, '/yearOfSpouseDeath')] ?? 'DiedBeforeTaxYearMinusTwo',
    primary_filer: (f) => answers(f, filerIds(f).primary),
    secondary_filer: (f) => answers(f, filerIds(f).secondary),
    secondary_filer_date_of_death: (f) => val(f, '/secondaryFilerDateOfDeath') || '2024-12-31',
    primary_filer_potential_claimer_filed_only_for_refund: (f) => bool(f, '/primaryFilerPotentialClaimerFiledOnlyForRefund'),
    mfj_required_to_file: (f) => bool(f, '/MFJRequiredToFile'),
    mfj_dependents_filing_for_credits: (f) => bool(f, '/MFJDependentsFilingForCredits'),
    lived_together_all_year_with_spouse: (f) => bool(f, '/livedTogetherAllYearWithSpouse', true),
    spouse_lived_together_months: (f) => {
      const v = val(f, '/spouseLivedTogetherMonths');
      return v ? upper(v) : 'LivedApartAllYear';
    },
    writable_lived_apart_last_six_months: (f) => bool(f, '/writableLivedApartLastSixMonths'),
    writable_separation_agreement: (f) => bool(f, '/writableSeparationAgreement'),
    can_file_jointly_year_of_spouse_death: (f) => bool(f, '/canFileJointlyYearOfSpouseDeath'),
    in_registered_domestic_partnership: (f) => bool(f, '/inRegisteredDomesticPartnership'),
    filer_residence_and_income_state: (f) => (val(f, '/filerResidenceAndIncomeState') ?? 'fl').toUpperCase(),
    spouse_itemizes: (f) => bool(f, '/spouseItemizes'),
    mfs_living_spouse_filing_return: (f) => bool(f, '/MFSLivingSpouseFilingReturn'),
    mfs_deceased_spouse_filing_return: (f) => bool(f, '/MFSDeceasedSpouseFilingReturn'),
    mfs_spouse_has_gross_income: (f) => bool(f, '/MFSSpouseHasGrossIncome'),
    eligible_for_hoh: (f) => val(f, '/filingStatus') === 'headOfHousehold',
    mfs_spouse_65_or_older: (f) => bool(f, '/MFSSpouse65OrOlder'),
    employer_income_subtotal: (f) => Number(val(f, '/employerIncomeSubtotal') ?? '0'),
  },
  outputs: [
    { oracle: '/standardDeduction', catala: 'standard_deduction', type: 'money' },
    { oracle: '/additionalStandardDeductionItems', catala: 'additional_standard_deduction_items', type: 'int' },
    { oracle: '/isSpouse65OrOlder', catala: 'is_spouse_65_or_older', type: 'bool' },
    { oracle: '/secondaryFilerIsBlindIndicatorXml', catala: 'secondary_filer_is_blind_indicator_xml', type: 'bool' },
    { oracle: '/xmlOver65SRIndicator', catala: 'xml_over65_sr_indicator', type: 'bool' },
    { oracle: '/primarySomeoneCanClaimForTaxBenefits', catala: 'primary_some_one_can_claim_for_tax_benefits', type: 'bool' },
    { oracle: '/secondarySomeoneCanClaimForTaxBenefits', catala: 'secondary_some_one_can_claim_for_tax_benefits', type: 'bool' },
  ],
};
