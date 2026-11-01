// Mapping for catala/calculator.catala_en (scope Calculator), issues #38 and #48: the whole return with every
// merged module plugged in and NO oracle value fed in. Run: make difftest SCOPE=calculator
//
// Every input is a writable fact of the scenario (oracle/facts.csv input rows, including the per-person rows
// /familyAndHousehold/#<uuid>/<fact>), mapped with the same helpers as the module mappings. No derived oracle
// fact (/agi, /numEitcQualifyingChildren, /minimumFilerDateOfBirth, ...) is read as an input.
//
// Every merged module is wired in, PTC (#32 to #34) included: the ptc.xml writables and the /1095As collection
// are mapped as in ptc_allowed.mjs. CDCC answers follow difftest/mappings/cdcc.mjs: the per-person and per-filer expense answers count
// only when /writableCdccHasQualifyingExpenses is true (DF does not ask them otherwise).
//
// Defaults for questions DF did not ask are the module mappings' defaults (each read only behind a gate that is
// false for that scenario). Additional defaults here:
//   monthsLivedWithTPInUS missing: 0 (DF asks it only after the residency test passes);
//   ssnEmploymentValidity missing: neither; filer SSN employment validity missing: neither (asked only of a
//   filer who is not a citizen all year, needsSSNWorkStatus);
//   W-2 box 14/15 state flags, Yonkers: false (as knockouts_income.mjs).
import { collectionIds, listFromCollection, parseMoney } from '../lib.mjs';
import filersMap from './filers.mjs';
import w2map from './form_w2s.mjs';
import { interestReports } from '../form_1040_inputs.mjs';
import { form1099Gs } from './unemployment.mjs';
import { form1099Miscs } from './form1099_misc.mjs';
import { formsInput } from './form1099_rs.mjs';
import educatorMap from './educator_adjustment.mjs';
import slMap from './student_loan_adjustment.mjs';
import hsaMap from './hsa.mjs';
import epMap from './estimated_payments.mjs';
import eitcMap from './eitc.mjs';
import { scheduleInputs } from './ctc_odc.mjs';
import saversMap from './savers_credit.mjs';
import edcMap, { knownDivergence as edcDivergence } from './elderly_and_disabled.mjs';
import koMap from './knockouts_income.mjs';
import ptcMap from './ptc_allowed.mjs';
import { person } from './qualifying_child.mjs';
import { answers } from './qualifying_relative.mjs';
import { splitAnswers } from './dependents_benefit_split.mjs';

const val = (f, p) => { const r = f.get(p); return r && r.completeness !== 'Incomplete' && r.value !== '' ? r.value : undefined; };
const bool = (f, p) => val(f, p) === 'true';
const cents = (f, p) => { const v = val(f, p); return v === undefined ? 0n : parseMoney(v); };
const upper = (s) => s.charAt(0).toUpperCase() + s.slice(1);
const P = '/familyAndHousehold/*/';

function filerIds(f) {
  const ids = collectionIds(f, '/filers');
  const primary = ids.find((id) => bool(f, `/filers/#${id}/isPrimaryFiler`));
  return { primary, secondary: ids.find((id) => id !== primary) };
}

// ---- filers ---------------------------------------------------------------------------------
const FILERS_FIELDS = [
  'marital_status', 'year_of_spouse_death', 'primary_filer', 'secondary_filer', 'secondary_filer_date_of_death',
  'primary_filer_potential_claimer_filed_only_for_refund', 'mfj_required_to_file', 'mfj_dependents_filing_for_credits',
  'lived_together_all_year_with_spouse', 'spouse_lived_together_months', 'writable_lived_apart_last_six_months',
  'writable_separation_agreement', 'can_file_jointly_year_of_spouse_death', 'in_registered_domestic_partnership',
  'filer_residence_and_income_state', 'spouse_itemizes', 'mfs_living_spouse_filing_return',
  'mfs_deceased_spouse_filing_return', 'mfs_spouse_has_gross_income', 'mfs_spouse_65_or_older',
];

// filers.xml /filers/*/tin/isSSN: a TIN that is not an ITIN (9xx) or ATIN (xxx-xx-0000 style), as eitc.mjs
const tinIsSsn = (tin) => !!tin && !(tin.startsWith('9') || tin.endsWith('0000'));
const FILER_SSN = { neither: 'Neither', notValid: 'NotValid', validOnlyWithDhsAuthorization: 'ValidOnlyWithDhsAuthorization' };
function extra(f, role) {
  const { primary, secondary } = filerIds(f);
  const id = role === 'primary' ? primary : secondary;
  const validity = val(f, role === 'primary' ? '/primaryFilerSsnEmploymentValidity' : '/secondaryFilerSsnEmploymentValidity');
  return {
    tin: {
      tin_is_ssn: tinIsSsn(id && val(f, `/filers/#${id}/tin`)),
      ssn_employment_validity: FILER_SSN[validity] ?? 'Neither',
      has_ssn_only_for_benefits: !!id && bool(f, `/filers/#${id}/writableHasSSNOnlyForBenefits`),
    },
    is_student: !!id && bool(f, `/filers/#${id}/isStudent`),
    disability: edcMap.inputs[`${role}_answers`](f),
    hsa: hsaMap.inputs[role === 'primary' ? 'primary_filer' : 'secondary_filer'](f),
    cdcc: cdccFiler(f, id, role),
  };
}

// ---- CDCC (as cdcc.mjs) ---------------------------------------------------------------------
const hasCdccExpenses = (f) => bool(f, '/writableCdccHasQualifyingExpenses');
const dollars = (f, p) => Number(cents(f, p)) / 100;
function cdccFiler(f, id, role) {
  const own = role === 'primary'
    ? ['usePrimaryCombatPay', 'useBothCombatPay', 'usePrimaryNotSpouseCombatPay']
    : ['useSpouseCombatPay', 'useBothCombatPay', 'useSpouseNotPrimaryCombatPay'];
  const it = `/filers/#${id}/`;
  return {
    elect_combat_pay_for_credit: own.includes(val(f, '/cdccCombatPayElection')),
    elect_combat_pay_for_benefits: own.includes(val(f, '/cdccCombatPayElectionForBenefits')),
    dependent_care_plan_maximum: dollars(f, role === 'primary'
      ? '/writablePrimaryFilerDependentCarePlanMaximum' : '/writableSecondaryFilerDependentCarePlanMaximum'),
    is_disabled: !!id && bool(f, it + 'isDisabled'),
    deemed_income_month_earnings: [],
    has_dependent_care_expenses: !!id && hasCdccExpenses(f) && bool(f, it + 'cdccHasDependentCareExpenses'),
    expenses_paid_to_qualifying_provider: !!id && bool(f, it + 'cdccHadExpensesPaidToQualifyingProvider'),
    writable_qualifying_expense_amount: id ? dollars(f, it + 'writableCdccQualifyingExpenseAmount') : 0,
  };
}
const cdccAnswers = (f) => ({
  has_mfs_spouse_earned_income: bool(f, '/hasMfjSpouseEarnedIncome'),
  writable_mfs_spouse_earned_income: dollars(f, '/writableMfsSpouseEarnedIncome'),
  writable_total_qualified_dependent_care_expenses: dollars(f, '/writableCdccTotalQualifiedDependentCareExpenses'),
  writable_carryover_amount: bool(f, '/hasCdccCarryoverAmountFromPriorTaxYear')
    ? dollars(f, '/writableCdccCarryoverAmountFromPriorTaxYear') : 0,
  // DF-BUG(27) (cdcc.mjs): the statute counts the forfeited amount whatever box 10 says.
  writable_forfeited_amount: bool(f, '/writableHasCdccForfeitedCredits') ? dollars(f, '/writableCdccForfeitedCredits') : 0,
  has_credit_for_prior_year_expenses: bool(f, '/cdccHasCreditForPriorYearExpenses'),
  claimed_credit_for_prior_year_expenses: bool(f, '/cdccClaimedCreditForPriorYearExpenses'),
  claimed_max_credit_for_prior_tax_year: bool(f, '/cdccClaimedMaxCreditForPriorTaxYear'),
  has_household_employee: bool(f, '/flowKnockoutHouseholdEmployee'),
  benefits_from_sole_proprietorship_or_partnership: false,
});

// ---- household ------------------------------------------------------------------------------
// The writable rows of one household member, keyed as in oracle/persons.csv (/familyAndHousehold/*/<fact>).
function personFacts(f, id) {
  const pre = `/familyAndHousehold/#${id}/`;
  const m = new Map();
  for (const [p, r] of f) if (p.startsWith(pre)) m.set(P + p.slice(pre.length), r);
  return m;
}
const MONTHS = { six: 6, seven: 7, eight: 8, nine: 9, ten: 10, eleven: 11, twelve: 12 };
function household(f) {
  return collectionIds(f, '/familyAndHousehold').map((id) => {
    const pf = personFacts(f, id);
    const pv = (n) => pf.get(P + n)?.value;
    return {
      dependent: { person: person(pf), answers: answers(pf), split: splitAnswers(pf) },
      upkeep: {
        tp_paid_most_of_home_upkeep: pv('tpPaidMostOfHomeUpkeep') === 'true',
        tp_paid_most_of_parent_home_upkeep: pv('tpPaidMostOfParentHomeUpkeep') === 'true',
      },
      ssn_employment_validity: upper(pv('ssnEmploymentValidity') || 'neither'),
      ssn_only_for_federally_funded_benefit: pv('ssnOnlyForFederallyFundedBenefit') === 'true',
      months_lived_with_tp_in_us: MONTHS[pv('monthsLivedWithTPInUS')] ?? 0,
      cdcc: {
        unable_to_care_for_self: pv('unableToCareForSelf') === 'true',
        has_dependent_care_expenses: hasCdccExpenses(f) && pv('cdccHasDependentCareExpenses') === 'true',
        expenses_paid_to_qualifying_provider: pv('cdccHadExpensesPaidToQualifyingProvider') === 'true',
        writable_qualifying_expense_amount: pv('writableCdccQualifyingExpenseAmount')
          ? Number(pv('writableCdccQualifyingExpenseAmount')) : 0,
      },
    };
  });
}

// ---- blocked scenarios ----------------------------------------------------------------------
// None: every module is merged. (CALC_INCLUDE_BLOCKED is kept as a no-op for old command lines.)
const blocked = () => true;

const PTC_ANSWERS = [
  'form1095_as', 'writable_has_ptc_qualifying_plan', 'writable_has_advanced_ptc', 'dependent_tp_self_enrolled',
  'dependent_tp_enrolled_someone_else', 'writable_dependent_tp_other_members_are_part_of_different_tax_family',
  'writable_has_mfs_exception', 'writable_claiming_mfs_exception_for_fourth_straight_year',
  'writable_below100_threshold_and_not_eligible_for_medicaid_because_of_immigration_status',
  'writable_has_employer_sponsored_plan', 'writable_dependents_required_to_file',
  'writable_self_reported_has_multiple1095_as', 'writable_is_additional_person_in_enrollment_family',
  'writable_is_additional_person_partof_different_tax_family', 'writable_is_enrolled_with_other_family',
  'writable_has_immigration_status_not_eligible_for_marketplace', 'writable_wants_to_use_alt_calculations',
];

const HSA_TOP = [
  'some_filer_had_non_w2_hsa_activity', 'writable_primary_filer_had_non_w2_hsa_activity',
  'writable_secondary_filer_had_non_w2_hsa_activity', 'has_hsa_medical_savings_account_type',
  'writable_has_hsa_excess_contributions_previous_year', 'writable_has_hsa_withdrawn_excess_contributions_yes_no',
  'some_filers_made_testing_period_contribution', 'some_filers_have_testing_period_additional_income', 'hsa_distributions',
];
const SCREENING = [
  'income_sources_supported', 'received_digital_assets', 'disposed_digital_assets', 'has_foreign_accounts',
  'is_foreign_trusts_grantor', 'has_foreign_trusts_transactions', 'made_ira_contributions',
  'w2_box15_income_from_different_state', 'w2_has_box14_nyrrta_knockout_code', 'w2_has_rrta_codes_in_box14',
  'lived_in_ny', 'w2_paid_yonkers_taxes', 'part_year_yonkers_resident', 'primary_filer_forms_another_state',
  'received_alaska_pfd', 'spouse_received_alaska_pfd', 'spouse_lives_in_other_or_multiple_states',
  'spouse_forms_another_state', 'is_after_tax_day_and_not_resubmitting', 'is_after_resubmission_deadline',
];
const pick = (inputs, names, f) => Object.fromEntries(names.map((n) => [n, inputs[n](f)]));

// ---- known divergences (CONVENTIONS section 8) ----------------------------------------------
// DF-BUG(13) (Schedule R line 13b adds 1040 line 5a - 5b): in those scenarios /totalEdc differs, and so does
// everything downstream of it.
const EDC_DOWNSTREAM = ['/totalEdc', '/line8OfSchedule3', '/nonRefundableCredits', '/totalTax', '/overpayment',
  '/balanceDue', '/totalCtcAndOdc', '/qualifiedSaverCreditAmount', '/additionalCtc', '/totalPayments',
  '/totalOtherPaymentsRefundableCredits'];
const bug13Scenarios = [...new Set(edcDivergence.map((d) => d.scenario))];
export const knownDivergence = [
  // DF-BUG-3 (docs/direct-file-bugs.md; qualifying_child.mjs): a qualifying child of the filer who could also be
  // the qualifying child of another taxpayer who must file. IRC 152(c)(4) cannot be decided from the return, so
  // the formalization knocks out (QualifyingChildTieBreaker); DF accepts the return.
  { scenario: 'qss_35K_1 dependent-signed', path: '/flowIsKnockedOut', bug: 'DF-BUG-3' },
  // Not a DF bug: the scenario file has /filingStatus = headOfHousehold while DF's own /isFilingStatusValid is false
  // (/filingStatusChoice wantsMarriedFilingSeparately, /eligibleForHoh false). DF's UI never offers an ineligible
  // status; the formalization makes it the knockout ko_filing_status_not_eligible (#20, CONVENTIONS section 7).
  { scenario: 'mfs-4300-none', path: '/flowIsKnockedOut', bug: 'invalid input: DF /isFilingStatusValid=false (#20)' },
  // DF-BUG(23) (cdcc.mjs): the foster child of the non-parent Form 8332 split is a CDCC qualifying person in DF;
  // IRC 21(e)(5) gives the child to the custodial parent only. CDCC $702 (DF) vs $602 (law), and everything after it.
  ...['/cdccTotalCredit', '/line8OfSchedule3', '/nonRefundableCredits', '/totalTax', '/totalCtcAndOdc',
    '/additionalCtc', '/totalOtherPaymentsRefundableCredits', '/totalPayments', '/overpayment', '/balanceDue']
    .map((path) => ({ scenario: 'hoh-cdcc-multiple-careproviders', path, bug: 'DF-BUG(23)' })),
  ...bug13Scenarios.flatMap((scenario) => EDC_DOWNSTREAM.map((path) => ({ scenario, path, bug: 'DF-BUG(13)' }))),
];

const m = (oracle, catala) => ({ oracle, catala, type: 'money' });

export default {
  name: 'calculator',
  scope: 'Calculator',
  file: 'catala/calculator.catala_en',
  appliesTo: blocked,
  knownDivergence,
  inputs: {
    filing_status: filersMap.inputs.filing_status,
    filers: (f) => pick(filersMap.inputs, FILERS_FIELDS, f),
    primary_extra: (f) => extra(f, 'primary'),
    secondary_extra: (f) => extra(f, 'secondary'),
    household,
    income: (f) => ({
      w2s: w2map.inputs.w2s(f),
      combat_pay_election: w2map.inputs.combat_pay_election(f),
      combat_pay_election_made: eitcMap.inputs.combat_pay_election_made(f),
      interest_reports: interestReports(f),
      form_1099gs: form1099Gs(f),
      form_1099miscs: form1099Miscs(f),
      form_1099rs: formsInput(f),
      ssa_net_benefits: listFromCollection('/socialSecurityReports', 'ssaNetBenefits', { missing: '0' })(f),
      ssa_federal_tax_withheld: listFromCollection('/socialSecurityReports', 'writableSsaFederalTaxWithheld', { missing: '0' })(f),
    }),
    adjustments: (f) => ({
      was_k12_educators: educatorMap.inputs.was_k12_educators(f),
      primary_educator_expenses_writable: educatorMap.inputs.primary_educator_expenses_writable(f),
      secondary_educator_expenses_writable: educatorMap.inputs.secondary_educator_expenses_writable(f),
      had_student_loan_interest_payments: slMap.inputs.had_student_loan_interest_payments(f),
      student_loans_qualify: slMap.inputs.student_loans_qualify(f),
      student_loan_interest_amount: slMap.inputs.student_loan_interest_amount(f),
      hsa: pick(hsaMap.inputs, HSA_TOP, f),
    }),
    payments: (f) => pick(epMap.inputs, Object.keys(epMap.inputs), f),
    credits: (f) => ({
      ...pick(eitcMap.inputs, ['eitc_qc_of_another', 'eitc_qc_of_another_required_to_file', 'eitc_qc_of_another_is_filing',
        'eitc_qc_of_another_is_filing_refund_only', 'eitc_had_improper_claims', 'eitc_improper_claims_due_to_qc',
        'eitc_improper_claim_taken_since_disallowal', 'eitc_received_improper_claims_notice',
        'eitc_improper_claims_notice_expired'], f),
      ...pick(scheduleInputs, ['received_improper_claims', 'received_improper_claims_notice',
        'improper_claims_notice_expired', 'has_filed_ctc_odc_since_notice_expired'], f),
      ...pick(saversMap.inputs, ['has_distributions_in_last_three_years', 'has_current_year_distributions',
        'has_self_reported_contributions'], f),
      has_self_reported_non_taxable_payments: bool(f, '/writableHasSelfReportedNonTaxablePayments'),
      self_reported_non_taxable_payment_amount: Number(cents(f, '/writableEdcSelfReportedNonTaxablePaymentAmount')) / 100,
    }),
    cdcc_answers: cdccAnswers,
    ptc_answers: (f) => pick(ptcMap.inputs, PTC_ANSWERS, f),
    screening: (f) => ({
      ...pick(koMap.inputs, SCREENING, f),
      // knockouts_household.catala_en: the data of /knockoutPersonBornAndDiedInTaxYearWithoutTin, per member
      member_vitals: collectionIds(f, '/familyAndHousehold').map((id) => {
        const pf = personFacts(f, id);
        const pv = (n) => pf.get(P + n)?.value;
        return { date_of_birth: person(pf).date_of_birth, deceased: pv('deceased') === 'true', has_tin_type_none: pv('tinType') === 'none' };
      }),
    }),
  },
  outputs: [
    m('/wages', 'wages'),
    m('/taxableDependentCare', 'taxable_dependent_care'),
    m('/cdccTotalCredit', 'cdcc_total_credit'),
    m('/totalIncome', 'total_income'),
    m('/taxableSocialSecurityBenefits', 'taxable_social_security_benefits'),
    m('/educatorExpensesAdjustment', 'educator_expenses_adjustment'),
    m('/studentLoanInterestAdjustmentAmount', 'student_loan_interest_adjustment_amount'),
    m('/hsaTotalDeductibleAmount', 'hsa_total_deductible_amount'),
    m('/adjustmentsToIncome', 'adjustments_to_income'),
    m('/agi', 'agi'),
    m('/standardOrItemizedDeductions', 'standard_or_itemized_deductions'),
    m('/taxableIncome', 'taxable_income'),
    m('/totalTentativeTax', 'total_tentative_tax'),
    { oracle: '/numEitcQualifyingChildren', catala: 'num_eitc_qualifying_children', type: 'int' },
    { oracle: '/ctcEligibleDependents', catala: 'ctc_eligible_dependents', type: 'int' },
    { oracle: '/odcEligibleDependents', catala: 'odc_eligible_dependents', type: 'int' },
    m('/totalCtcAndOdc', 'total_ctc_and_odc'),
    m('/qualifiedSaverCreditAmount', 'qualified_saver_credit_amount'),
    m('/totalEdc', 'total_edc'),
    m('/line8OfSchedule3', 'line8_of_schedule3'),
    m('/nonRefundableCredits', 'non_refundable_credits'),
    m('/totalTax', 'total_tax'),
    m('/form1099Withholding', 'form_1099_withholding'),
    m('/totalWithholding', 'total_withholding'),
    m('/estimatedAndFromLastYear', 'estimated_and_from_last_year'),
    m('/earnedIncomeCredit', 'earned_income_credit'),
    m('/additionalCtc', 'additional_ctc'),
    m('/totalOtherPaymentsRefundableCredits', 'total_other_payments_refundable_credits'),
    m('/netPtcAmount', 'net_ptc_amount'),
    m('/netPtcAmountWhenZeroOrPositive', 'net_ptc_amount_when_zero_or_positive'),
    m('/netPtcAmountWhenNegative', 'net_ptc_amount_when_negative'),
    m('/ptcRepaymentLimitation', 'ptc_repayment_limitation'),
    m('/lesserOfNetPtcAmountAndRepaymentLimitation', 'lesser_of_net_ptc_amount_and_repayment_limitation'),
    m('/totalAdditionalTaxesOwed', 'total_additional_taxes_owed'),
    m('/otherPaymentsAndRefundableCreditsTotal', 'other_payments_and_refundable_credits_total'),
    m('/totalPayments', 'total_payments'),
    m('/overpayment', 'overpayment'),
    m('/balanceDue', 'balance_due'),
    { oracle: '/flowIsKnockedOut', catala: 'unsupported', type: 'bool', placeholderFalse: true },
  ],
};
