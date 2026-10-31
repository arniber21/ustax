// Mapping for catala/ctc_odc.catala_en (scope Schedule8812), issue #27. Run: make difftest SCOPE=ctc_odc
//
// Schedule 8812 from the oracle's own counts of CTC and ODC dependents (/ctcEligibleDependents,
// /odcEligibleDependents; the household computation of those counts is checked separately by
// ctc_odc_household.mjs and, per person, by ctc_odc_person.mjs).
//
// Inputs that other modules compute are the oracle's values (the orchestrator wires the real modules
// in later; see the PR): /agi, /totalTentativeTax, /cdccTotalCredit, /qualifiedSaverCreditAmount,
// /totalEdc, /employerIncomeSubtotal, /allCombatPay, /socialSecurityTaxesWithheld, /earnedIncomeCredit.
// The improper-claims questions are Writable facts; DF asks them only after "yes" to the first, so a
// missing answer is false (NotAnswered for the notice).
import { scalar } from '../lib.mjs';

const val = (f, p) => {
  const r = f.get(p);
  return r && r.completeness !== 'Incomplete' ? r.value : undefined;
};
const bool = (p) => (f) => val(f, p) === 'true';
const money = (p) => scalar(p, { type: 'money' });
const FS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};
const NOTICE = { twoYears: 'TwoYears', tenYears: 'TenYears', zeroYears: 'ZeroYears' };

export const scheduleInputs = {
  filing_status: (f) => FS[val(f, '/filingStatus')],
  agi: money('/agi'),
  total_tentative_tax: money('/totalTentativeTax'),
  cdcc_total_credit: money('/cdccTotalCredit'),
  qualified_saver_credit_amount: money('/qualifiedSaverCreditAmount'),
  total_edc: money('/totalEdc'),
  employer_income_subtotal: money('/employerIncomeSubtotal'),
  all_combat_pay: money('/allCombatPay'),
  social_security_taxes_withheld: money('/socialSecurityTaxesWithheld'),
  earned_income_credit: money('/earnedIncomeCredit'),
  received_improper_claims: bool('/receivedImproperClaims'),
  received_improper_claims_notice: (f) => NOTICE[val(f, '/receivedImproperClaimsNotice')] ?? 'NotAnswered',
  improper_claims_notice_expired: bool('/improperClaimsNoticeExpired'),
  has_filed_ctc_odc_since_notice_expired: bool('/hasFiledCtcOdcSinceNoticeExpired'),
};

const m = (o, c) => ({ oracle: `/${o}`, catala: c, type: 'money' });
const b = (o, c) => ({ oracle: `/${o}`, catala: c, type: 'bool' });

// Every fact of ctcOdc.xml that the oracle holds (Export mef="true" or a required output), except the
// inputs (/ctcEligibleDependents, /odcEligibleDependents, the improper-claims Writables) and the
// copy /xmlTotalCtcAndOdcFor8812 (= /totalCtcAndOdc). /earnedIncomeWithAllCombatPay is income.xml's.
export const scheduleOutputs = [
  m('dependentCreditMagi', 'dependent_credit_magi'),
  m('totalPotentialCtc', 'total_potential_ctc'),
  m('totalPotentialOdc', 'total_potential_odc'),
  m('totalPotentialDependentCredits', 'total_potential_dependent_credits'),
  m('dependentCreditPhaseoutThreshold', 'dependent_credit_phaseout_threshold'),
  m('roundedDependentCreditMagiAboveThreshold', 'rounded_dependent_credit_magi_above_threshold'),
  m('dependentCreditPhaseout', 'dependent_credit_phaseout'),
  m('dependentCreditLessPhaseout', 'dependent_credit_less_phaseout'),
  b('dependentCreditNotFullyPhasedOut', 'dependent_credit_not_fully_phased_out'),
  m('sched8812CreditLimit', 'sched8812_credit_limit'),
  m('totalCtcAndOdc', 'total_ctc_and_odc'),
  m('xmlTotalCtcAndOdcFor8812', 'total_ctc_and_odc'),
  b('isReceivingCtcOrOdc', 'is_receiving_ctc_or_odc'),
  m('remainingCtcAndOdc', 'remaining_ctc_and_odc'),
  b('xmlHasRemainingCtcAndOdc', 'xml_has_remaining_ctc_and_odc'),
  m('totalPotentialActc', 'total_potential_actc'),
  b('xmlHasPotentialActc', 'xml_has_potential_actc'),
  m('remainingPotentialActc', 'remaining_potential_actc'),
  m('earnedIncomeWithAllCombatPay', 'earned_income_with_all_combat_pay'),
  m('earnedIncomeAboveActcRefundabilityThreshold', 'earned_income_above_actc_refundability_threshold'),
  b('earnedIncomeExceedsActcRefundabilityThreshold', 'earned_income_exceeds_actc_refundability_threshold'),
  m('regularMaximumActc', 'regular_maximum_actc'),
  b('threeOrMoreCtcEligibleDependents', 'three_or_more_ctc_eligible_dependents'),
  b('xmlThreeOrMoreCtcEligibleDependents', 'xml_three_or_more_ctc_eligible_dependents'),
  m('socialSecurityOverEitc', 'social_security_over_eitc'),
  m('maximumActc', 'maximum_actc'),
  m('additionalCtc', 'additional_ctc'),
  b('isReceivingActc', 'is_receiving_actc'),
  b('ctc8862Required', 'ctc8862_required'),
];

export default {
  name: 'ctc_odc',
  scope: 'Schedule8812',
  file: 'catala/ctc_odc.catala_en',
  appliesTo: () => true,
  inputs: {
    ctc_eligible_dependents: scalar('/ctcEligibleDependents', { type: 'int' }),
    odc_eligible_dependents: scalar('/odcEligibleDependents', { type: 'int' }),
    ...scheduleInputs,
  },
  outputs: scheduleOutputs,
  knownDivergence: [],
};
