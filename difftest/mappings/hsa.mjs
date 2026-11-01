// Mapping for catala/hsa.catala_en (scope Hsa), issue #35. Run: make difftest SCOPE=hsa
//
// The oracle holds one HSA output, /hsaTotalDeductibleAmount (Form 1040 line 10 input). It is Complete only
// when a filer has HSA contributions (13 scenarios); elsewhere it is Incomplete (DF Switch with no default)
// and is counted as unchecked. Inputs are the oracle's writable facts. Defaults for facts the questionnaire did
// not ask are values DF never reads in that scenario (they sit behind the same gates as in hsa.xml).
// Inputs that other modules own are derived from oracle facts the same way those modules do:
//   age 55 or older: 2024 - year of birth >= 55 (filers.xml /filers/*/age55OrOlder);
//   W-2 box 12 W per filer: Round of the sum of Round(employerHsaContributions) (formW2s.xml).
import { collectionIds, parseMoney } from '../lib.mjs';

const val = (f, p) => { const r = f.get(p); return r && r.completeness !== 'Incomplete' ? r.value : undefined; };
const bool = (f, p, d = false) => { const v = val(f, p); return v === undefined || v === '' ? d : v === 'true'; };
const cents = (f, p) => { const v = val(f, p); return v === undefined || v === '' ? 0n : parseMoney(v); };
const dollars = (c) => Number(c) / 100;
const roundDollar = (c) => (c >= 0n ? (c + 50n) / 100n * 100n : -((-c + 50n) / 100n * 100n));

const MEDICARE = { allYear: 'MedicareAllYear', partOfYear: 'MedicarePartOfYear', noneOfYear: 'MedicareNoneOfYear' };
const HDHP = { allYear: 'HdhpAllYear', partOfYear: 'HdhpPartOfYear', noneOfYear: 'HdhpNoneOfYear' };
const TYPE = { selfOnly: 'SelfOnly', family: 'Family', both: 'BothSelfAndFamily' };
const OTHER = { wholeYear: 'OtherCoverageWholeYear', partOfYear: 'OtherCoveragePartOfYear', noneOfYear: 'OtherCoverageNoneOfYear' };
const MARITAL = {
  wasMarriedOrDivorcedThisYear: 'WasMarriedOrDivorcedThisYear',
  wasNotMarriedNorDivorcedThisYear: 'WasNotMarriedNorDivorcedThisYear',
};
const CODE = {
  normalDistribution: 'NormalDistribution', excessContributions: 'ExcessContributions', disability: 'Disability',
  deathOtherThanCode6: 'DeathOtherThanCode6', prohibitedTransaction: 'ProhibitedTransaction',
  deathDistributionAfterYear: 'DeathDistributionAfterYear',
};

function filerIds(f) {
  const ids = collectionIds(f, '/filers');
  const primary = ids.find((id) => val(f, `/filers/#${id}/isPrimaryFiler`) === 'true');
  if (!primary) throw new Error('no primary filer in scenario');
  return { primary, secondary: ids.find((id) => id !== primary) };
}

const age55 = (f, id) => {
  const dob = id && val(f, `/filers/#${id}/dateOfBirth`);
  return dob ? 2024 - Number(dob.slice(0, 4)) >= 55 : false;
};

function w2Total(f, id) {
  let sum = 0n;
  for (const w of collectionIds(f, '/formW2s')) {
    if (val(f, `/formW2s/#${w}/filer`) === id) sum += roundDollar(cents(f, `/formW2s/#${w}/employerHsaContributions`));
  }
  return roundDollar(sum);
}

function answers(f, id) {
  const p = (n) => `/filers/#${id}/${n}`;
  return {
    writable_primary_filer_has_made_contributions_to_hsa: bool(f, p('writablePrimaryFilerHasMadeContributionsToHsa')),
    writable_secondary_filer_has_made_contributions_to_hsa: bool(f, p('writableSecondaryFilerHasMadeContributionsToHsa')),
    enrolled_in_medicare: MEDICARE[val(f, p('enrolledInMedicare'))] ?? 'MedicareNoneOfYear',
    hsa_hdhp_coverage_status: HDHP[val(f, p('hsaHdhpCoverageStatus'))] ?? 'HdhpAllYear',
    type_of_hdhp: TYPE[val(f, p('typeOfHdhp'))] ?? 'SelfOnly',
    had_other_coverage_ineligible_for_hsa: OTHER[val(f, p('hadOtherCoverageIneligibleForHSA'))] ?? 'OtherCoverageNoneOfYear',
    writable_mfs_line6_check: bool(f, p('writableMfsLine6Check')),
    writable_change_in_marital_status_during_tax_year:
      MARITAL[val(f, p('writableChangeInMaritalStatusDuringTaxYear'))] ?? 'WasNotMarriedNorDivorcedThisYear',
    writable_marital_change_affect_contribution_limit_bool: bool(f, p('writableMaritalChangeAffectContributionLimitBool')),
    has_made_qualified_hsa_funding_distribution: bool(f, p('hasMadeQualifiedHsaFundingDistribution')),
    writable_hsa_nonemployer_contributions_tax_year: dollars(cents(f, p('writableHsaNonemployerContributionsTaxYear'))),
    writable_hsa_nonemployer_contributions_tax_year_plus_one:
      dollars(cents(f, p('writableHsaNonemployerContributionsTaxYearPlusOne'))),
  };
}

function distributions(f) {
  const { primary } = filerIds(f);
  return collectionIds(f, '/hsaDistributions').map((id) => {
    const p = (n) => `/hsaDistributions/#${id}/${n}`;
    return {
      filer: val(f, p('filer')) === primary ? 'PrimaryFiler' : 'SecondaryFiler',
      writable_distributions_rollover_bool: bool(f, p('writableDistributionsRolloverBool')),
      writable_distributions_rollover_amount: dollars(cents(f, p('writableDistributionsRolloverAmount'))),
      writable_gross_distribution: dollars(cents(f, p('writableGrossDistribution'))),
      has_withdrawn_excess_contributions: bool(f, p('hasWithdrawnExcessContributions')),
      writable_withdrawn_excess_contributions_amount: dollars(cents(f, p('writableWithdrawnExcessContributionsAmount'))),
      writable_earnings_on_excess_contributions: dollars(cents(f, p('writableEarningsOnExcessContributions'))),
      hsa_distribution_code: CODE[val(f, p('hsaDistributionCode'))] ?? 'NormalDistribution',
      writable_fmv_on_date_of_death: dollars(cents(f, p('writableFmvOnDateOfDeath'))),
      writable_qualified_med_expenses: dollars(cents(f, p('writableQualifiedMedExpenses'))),
    };
  });
}

export default {
  name: 'hsa',
  scope: 'Hsa',
  file: 'catala/hsa.catala_en',
  appliesTo: () => true,
  // Scenarios where the law and Direct File give different deductions (CONVENTIONS section 8). Filled from the run:
  // DF-BUG(7) candidate: DF assumes the spouses agreed to the allocation of the family limit that maximises
  // the deduction; the law (IRC 223(b)(5)(B)(ii)) divides it equally.
  knownDivergence: [],
  inputs: {
    is_filing_status_mfj: (f) => val(f, '/filingStatus') === 'marriedFilingJointly',
    is_married: (f) => val(f, '/maritalStatus') === 'married',
    is_single: (f) => val(f, '/maritalStatus') === 'single',
    primary_filer_age55_or_older: (f) => age55(f, filerIds(f).primary),
    secondary_filer_age55_or_older: (f) => age55(f, filerIds(f).secondary),
    primary_filer_can_be_claimed: (f) => bool(f, `/filers/#${filerIds(f).primary}/canBeClaimed`),
    secondary_filer_can_be_claimed: (f) => bool(f, `/filers/#${filerIds(f).secondary}/canBeClaimed`),
    primary_filer_total_hsa_contributions_from_w2s: (f) => dollars(w2Total(f, filerIds(f).primary)),
    secondary_filer_total_hsa_contributions_from_w2s: (f) => dollars(w2Total(f, filerIds(f).secondary)),
    has_primary_filer_hsa_contributions_from_w2s: (f) => w2Total(f, filerIds(f).primary) > 0n,
    has_secondary_filer_hsa_contributions_from_w2s: (f) => w2Total(f, filerIds(f).secondary) > 0n,
    // Not in the oracle; only feeds a knockout, not compared here.
    knockout_has_no_payments_or_credits: () => false,
    paid_estimated_taxes_or_from_last_year: (f) => bool(f, '/paidEstimatedTaxesOrFromLastYear'),
    tax_exempt_interest: (f) => dollars(cents(f, '/taxExemptInterest')),
    pensions_and_annuities: (f) => dollars(cents(f, '/pensionsAndAnnuities')),
    social_security_benefits: (f) => dollars(cents(f, '/socialSecurityBenefits')),
    primary_filer: (f) => answers(f, filerIds(f).primary),
    secondary_filer: (f) => answers(f, filerIds(f).secondary),
    some_filer_had_non_w2_hsa_activity: (f) => bool(f, '/someFilerHadNonW2HsaActivity'),
    writable_primary_filer_had_non_w2_hsa_activity: (f) => bool(f, '/writablePrimaryFilerHadNonW2HsaActivity'),
    writable_secondary_filer_had_non_w2_hsa_activity: (f) => bool(f, '/writableSecondaryFilerHadNonW2HsaActivity'),
    has_hsa_medical_savings_account_type: (f) => bool(f, '/hasHsaMedicalSavingsAccountType'),
    writable_has_hsa_excess_contributions_previous_year: (f) => bool(f, '/writableHasHsaExcessContributionsPreviousYear'),
    writable_has_hsa_withdrawn_excess_contributions_yes_no: (f) => bool(f, '/writableHasHsaWithdrawnExcessContributionsYesNo'),
    some_filers_made_testing_period_contribution: (f) => bool(f, '/someFilersMadeTestingPeriodContribution'),
    some_filers_have_testing_period_additional_income: (f) => bool(f, '/someFilersHaveTestingPeriodAdditionalIncome'),
    hsa_distributions: distributions,
  },
  outputs: [
    { oracle: '/hsaTotalDeductibleAmount', catala: 'hsa_total_deductible_amount', type: 'money' },
  ],
  // No oracle row (/requiresForm8889 and /numberOfFilersRequiredToFileForm8889 are not in facts.csv): compared
  // Lean = Catala only (issue #47). The 157 non-knocked-out scenarios are supported returns, so `unsupported`
  // is expected to be false there.
  extraOutputs: [
    { catala: 'requires_form_8889', type: 'bool' },
    { catala: 'number_of_filers_required_to_file_form_8889', type: 'int' },
    { catala: 'unsupported', type: 'bool' },
  ],
};
