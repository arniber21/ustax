// Mapping for catala/ptc_allowed.catala_en (scope PtcAllowed, through the wrapper PtcAllowedDifftest in
// catala/tests/difftest_ptc_allowed.catala_en), issue #33. Run: make difftest SCOPE=ptc_allowed
//
// Inputs:
//   - ptc.xml writables and the /1095As collection: the oracle's own input rows. A writable the scenario does
//     not answer is `false` (DF never reads it in that scenario: each sits behind the gate reproduced in Catala),
//     except the below-100-percent immigration answer and the MFS exception, where DF reads Incomplete as
//     "applicable" (true).
//     A 1095-A month amount that is not entered is $0; coverageMonths jan..dec become 1..12.
//   - Facts other modules own come from the oracle's derived rows (oracle/generate.mjs EXTRA, issue #33):
//     /filingStatus, /isMFJDependent, /notMfjAndPrimaryFilerCouldBeDependent..., /primaryFilerIsClaimedAsDependent,
//     /isMarried, /secondaryFilerResidencyEligibleForMFJ and /livedApartLastSixMonths (Incomplete -> false: DF
//     reads them only for a married head of household), /allEligibleFilersAreUSCitizensOrNationals,
//     /claimedDependentsCount, /hasQsehra, and part 1's /householdIncomeAsPercent, /ptcAnnualContributionAmount,
//     /ptcMontlyContributionAmount.
// Compared: the eligibility gates, line 11 (annual), lines 12 to 23 (each month, columns (a) to (f) and
// /hasActive1095APolicyIn<Month>), lines 24 and 25, and the PTC knockouts. Most rows are Incomplete in the 154
// scenarios with no Form 1095-A and are counted as unchecked.
import { collectionIds } from '../lib.mjs';

const val = (f, p) => { const r = f.get(p); return r && r.completeness !== 'Incomplete' ? r.value : undefined; };
const bool = (f, p) => val(f, p) === 'true';
const money = (f, p) => { const v = val(f, p); return v === undefined || v === '' ? 0 : Number(v); };
const FS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};
const MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
const Mon = (m) => m[0].toUpperCase() + m.slice(1);

function forms(f) {
  return collectionIds(f, '/1095As').map((id) => {
    const p = (n) => `/1095As/#${id}/${n}`;
    const monthly = (n) => MONTHS.map((m) => money(f, p(`${n}${Mon(m)}`)));
    const covered = (val(f, p('coverageMonths')) ?? '').split(';').filter((m) => m !== '');
    return {
      writable_policy_start_date: val(f, p('writablePolicyStartDate')),
      writable_policy_end_date: val(f, p('writablePolicyEndDate')),
      writable_special_policy_modification_in_starting_month: bool(f, p('writableSpecialPolicyModificationInStartingMonth')),
      writable_has_policy_date_exception: bool(f, p('writableHasPolicyDateException')),
      has_coverage_months: bool(f, p('hasCoverageMonths')),
      coverage_months: covered.map((m) => MONTHS.indexOf(m) + 1).sort((a, b) => a - b),
      writable_premiums_or_slcsp_change: bool(f, p('writablePremiumsOrSlcspChange')),
      has_change_in_circumstance: bool(f, p('hasChangeInCircumstance')),
      writable_ptc_annual_premium: money(f, p('writablePtcAnnualPremium')),
      writable_slcsp_annual_premium: money(f, p('writableSlcspAnnualPremium')),
      writable_aptc_annual_amount: money(f, p('writableAptcAnnualAmount')),
      writable_ptc_monthly_premium: monthly('writablePtcMonthlyPremium'),
      writable_ptc_monthly_slcsp_premium: monthly('writablePtcMonthlySlcspPremium'),
      writable_ptc_monthly_aptc_premium: monthly('writablePtcMonthlyAptcPremium'),
    };
  });
}

const writables = [
  'writableHasPtcQualifyingPlan', 'writableHasAdvancedPtc', 'dependentTpSelfEnrolled', 'dependentTpEnrolledSomeoneElse',
  'writableDependentTpOtherMembersArePartOfDifferentTaxFamily', 'writableHasMfsException',
  'writableClaimingMfsExceptionForFourthStraightYear',
  'writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus', 'writableHasEmployerSponsoredPlan',
  'writableDependentsRequiredToFile', 'writableSelfReportedHasMultiple1095As',
  'writableIsAdditionalPersonInEnrollmentFamily', 'writableIsAdditionalPersonPartofDifferentTaxFamily',
  'writableIsEnrolledWithOtherFamily', 'writableHasImmigrationStatusNotEligibleForMarketplace',
  'writableWantsToUseAltCalculations',
];
// camelCase DF name -> snake_case Catala name (digits keep to the word before: has100 -> has100, 1095As -> 1095_as)
const snake = (s) => s.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();

const filerFacts = {
  is_mfj_dependent: '/isMFJDependent',
  not_mfj_and_primary_filer_could_be_dependent_and_claimer_is_required_to_file_or_filing_for_credits:
    '/notMfjAndPrimaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits',
  primary_filer_is_claimed_as_dependent: '/primaryFilerIsClaimedAsDependent',
  is_married: '/isMarried',
  secondary_filer_residency_eligible_for_mfj: '/secondaryFilerResidencyEligibleForMFJ',
  lived_apart_last_six_months: '/livedApartLastSixMonths',
  all_eligible_filers_are_us_citizens_or_nationals: '/allEligibleFilersAreUSCitizensOrNationals',
  has_qsehra: '/hasQsehra',
};

const inputs = {
  filing_status: (f) => FS[val(f, '/filingStatus')],
  ...Object.fromEntries(Object.entries(filerFacts).map(([k, p]) => [k, (f) => bool(f, p)])),
  claimed_dependents_count: (f) => Number(val(f, '/claimedDependentsCount') ?? 0),
  household_income_as_percent: (f) => Number(val(f, '/householdIncomeAsPercent') ?? 0),
  ptc_annual_contribution_amount: (f) => money(f, '/ptcAnnualContributionAmount'),
  ptc_monthly_contribution_amount: (f) => money(f, '/ptcMontlyContributionAmount'),
  form1095_as: forms,
  ...Object.fromEntries(writables.map((w) => [snake(w), (f) => bool(f, `/${w}`)])),
  // Unanswered, DF leaves /below100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus Incomplete, and
  // /potentiallyApplicableTaxPayer then counts the taxpayer as applicable: the same as answering yes.
  writable_below100_threshold_and_not_eligible_for_medicaid_because_of_immigration_status: (f) =>
    val(f, '/writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus') !== 'false',
  // Same for the MFS exception: unanswered (only returns with no qualifying plan, so no Form 8962), DF's
  // /notPtcApplicableTaxPayerSoFar is Incomplete and the taxpayer counts as applicable, as with a "yes".
  writable_has_mfs_exception: (f) => val(f, '/writableHasMfsException') !== 'false',
};
// snake() gives writable_below100_threshold_..., writable_self_reported_has_multiple1095_as: as in Catala.

const scalarOutputs = [
  ['/maybeEligibleForPtc', 'maybe_eligible_for_ptc', 'bool'],
  ['/hasPtcQualifyingPlan', 'has_ptc_qualifying_plan', 'bool'],
  ['/hasAdvancedPtc', 'has_advanced_ptc', 'bool'],
  ['/notPtcApplicableTaxPayer', 'not_ptc_applicable_tax_payer', 'bool'],
  ['/potentiallyApplicableTaxPayer', 'potentially_applicable_tax_payer', 'bool'],
  ['/mayNeedToFileForm8962', 'may_need_to_file_form8962', 'bool'],
  ['/needsToFileForm8962', 'needs_to_file_form8962', 'bool'],
  ['/needsToFileForm8962Monthly', 'needs_to_file_form8962_monthly', 'bool'],
  ['/ptcCanReportAnnualTotals', 'ptc_can_report_annual_totals', 'bool'],
  ['/totalPtcAnnualPremium', 'total_ptc_annual_premium', 'money'],
  ['/totalAnnualSlcspPremium', 'total_annual_slcsp_premium', 'money'],
  ['/totalAnnualAptcAmount', 'total_annual_aptc_amount', 'money'],
  ['/annualMaxPremiumAssitance', 'annual_max_premium_assistance', 'money'],
  ['/annualPtcAllowed', 'annual_ptc_allowed', 'money'],
  ['/totalPtcAmountAllowed', 'total_ptc_amount_allowed', 'money'],
  ['/totalAptcAmountTaken', 'total_aptc_amount_taken', 'money'],
  ['/dependentTpRequiresAllocations', 'ko_dependent_tp_requires_allocations', 'bool'],
  ['/hasPtcQualifyingPlanAndQsehra', 'ko_has_ptc_qualifying_plan_and_qsehra', 'bool'],
  ['/needsAllocations', 'ko_needs_allocations', 'bool'],
  ['/hasEmployerSponsoredPlan', 'ko_has_employer_sponsored_plan', 'bool'],
  ['/dependentsRequiredToFile', 'ko_dependents_required_to_file', 'bool'],
  ['/selfReportedHasMultiple1095As', 'ko_self_reported_has_multiple1095_as', 'bool'],
  ['/hasImmigrationStatusNotEligibleForMarketplace', 'ko_has_immigration_status_not_eligible_for_marketplace', 'bool'],
  ['/wantsToUseAltCalculations', 'ko_wants_to_use_alt_calculations', 'bool'],
  ['/tpNeedsToAdd1095A', 'ko_tp_needs_to_add1095_a', 'bool'],
  ['/tpNeedsToDelete1095A', 'ko_tp_needs_to_delete1095_a', 'bool'],
];
const monthColumns = [
  ['/hasActive1095APolicyIn', 'has_active_policy', 'bool'],
  ['/monthlyPtcPremiumFor', 'enrollment_premium', 'money'],
  ['/monthlyPtcSlcspPremiumFor', 'slcsp_premium', 'money'],
  ['/monthlyPtcContributionAmountFor', 'contribution_amount', 'money'],
  ['/monthlyPtcMaxPremiumAssitanceFor', 'max_premium_assistance', 'money'],
  ['/monthlyPtcAllowedFor', 'ptc_allowed', 'money'],
  ['/monthlyAptcPremiumFor', 'advance_payment', 'money'],
];

export default {
  name: 'ptc_allowed',
  scope: 'PtcAllowedDifftest',
  file: 'catala/tests/difftest_ptc_allowed.catala_en',
  appliesTo: () => true,
  inputs,
  outputs: [
    ...scalarOutputs.map(([oracle, catala, type]) => ({ oracle, catala, type })),
    ...MONTHS.flatMap((m) => monthColumns.map(([o, c, type]) => ({ oracle: o + Mon(m), catala: `${m}_${c}`, type }))),
  ],
  // DF-BUG(33-a) (December 1 start), DF-BUG(33-b) (line 11 with fewer than 12 coverage months) and DF-BUG(33-c)
  // (line 10 "any" instead of "each" Form 1095-A) change no oracle value: no scenario starts a policy on
  // December 1, every annual-path scenario has 12 coverage months or none, and none has two Forms 1095-A.
  knownDivergence: [],
};
