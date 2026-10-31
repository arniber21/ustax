// Shared input builder for the three Form1040 mappings (difftest/mappings/form_1040*.mjs).
// Not a mapping itself (the runner only loads difftest/mappings/*.mjs).
//
//   strict    : only scenarios whose out-of-module facts are all zero; slots left at their $0 default.
//   unplugged : every scenario, slots left at $0; failures show what later modules must supply.
//   plugged   : every scenario, slots filled from the oracle's own values for the facts a later module
//               computes; proves the chain wiring on all 157 scenarios without those modules.
import { collectionIds, parseOracleValue, toCatalaJson, parseMoney } from './lib.mjs';
import w2map from './mappings/form_w2s.mjs';
import sdmap from './mappings/standard_deduction.mjs';

const val = (facts, p) => {
  const r = facts.get(p);
  return r && r.completeness !== 'Incomplete' ? r.value : undefined;
};
const cents = (facts, p) => {
  const v = val(facts, p);
  return v === undefined || v === '' ? 0n : parseMoney(v);
};
const money = (c) => toCatalaJson('money', c);
const STATUS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};

// 1099-INT reports, the same field mapping as catala/tests/gen_oracle_interest.py.
const INTEREST_MONEY = {
  no1099Amount: 'no_1099_amount',
  writable1099Amount: 'writable_1099_amount',
  writableEarlyWithdrawlPenaltyAmount: 'writable_early_withdrawl_penalty_amount',
  writableInterestOnGovernmentBonds: 'writable_interest_on_government_bonds',
  writableTaxWithheld: 'writable_tax_withheld',
  writableForeignTaxPaid: 'writable_foreign_tax_paid',
  writableTaxExemptInterest: 'writable_tax_exempt_interest',
  writableSpecifiedPrivateActivityBondInterest: 'writable_specified_private_activity_bond_interest',
  writableMarketDiscount: 'writable_market_discount',
  writableBondPremium: 'writable_bond_premium',
  writableBondPremiumOnTreasuryObligations: 'writable_bond_premium_on_treasury_obligations',
  writableBondPremiumOnTaxExemptBond: 'writable_bond_premium_on_tax_exempt_bond',
  writableStateTaxWithheld: 'writable_state_tax_withheld',
};
const interestReports = (facts) =>
  collectionIds(facts, '/interestReports').map((id) => {
    const pre = `/interestReports/#${id}/`;
    const filerIsPrimary = val(facts, `/filers/#${val(facts, pre + 'filer')}/isPrimaryFiler`) === 'true';
    const r = {
      filer: filerIsPrimary ? 'PrimaryFiler' : 'SecondaryFiler',
      has_1099: val(facts, pre + 'has1099') === 'true',
      state_is_different_state: val(facts, pre + 'writableState') === 'differentState',
      facta_filing_required: val(facts, pre + 'factaFilingRequired') === 'true',
    };
    for (const [df, c] of Object.entries(INTEREST_MONEY)) r[c] = money(cents(facts, pre + df));
    return r;
  });
const interestWithheld = (facts) =>
  collectionIds(facts, '/interestReports').reduce((a, id) => a + cents(facts, `/interestReports/#${id}/writableTaxWithheld`), 0n);

/** Oracle value of the 1040 line 5b residual (DF does not export /taxablePensionsAndAnnuities). */
const pensions5b = (facts) =>
  cents(facts, '/totalIncome') - cents(facts, '/employerIncomeSubtotal') - cents(facts, '/interestIncome')
  - cents(facts, '/taxableSocialSecurityBenefits') - cents(facts, '/otherIncome');

/** Slot name -> oracle value (cents) for every plug-in slot of Form1040. */
export const slotValues = (facts) => ({
  taxable_dependent_care: cents(facts, '/taxableDependentCare'),
  taxable_pensions_and_annuities: pensions5b(facts),
  taxable_social_security_benefits: cents(facts, '/taxableSocialSecurityBenefits'),
  // /otherIncome = Round(unemployment + Round(alaskaPfd)); the split is not needed, so all goes to unemployment.
  unemployment_compensation: cents(facts, '/otherIncome'),
  alaska_pfd_income: 0n,
  student_loan_interest_adjustment_amount: cents(facts, '/studentLoanInterestAdjustmentAmount'),
  educator_expenses_adjustment: cents(facts, '/educatorExpensesAdjustment'),
  hsa_total_deductible_amount: cents(facts, '/hsaTotalDeductibleAmount'),
  total_additional_taxes_owed: cents(facts, '/totalAdditionalTaxesOwed'),
  total_ctc_and_odc: cents(facts, '/totalCtcAndOdc'),
  line8_of_schedule3: cents(facts, '/line8OfSchedule3'),
  other_1099_withholding: cents(facts, '/form1099Withholding') - interestWithheld(facts),
  estimated_and_from_last_year: cents(facts, '/estimatedAndFromLastYear'),
  earned_income_credit: cents(facts, '/earnedIncomeCredit'),
  additional_ctc: cents(facts, '/additionalCtc'),
  other_payments_and_refundable_credits_total: cents(facts, '/otherPaymentsAndRefundableCreditsTotal'),
});

/** Which later module a non-zero slot belongs to (the mismatch categories of the PR). */
const CATEGORY = {
  taxable_dependent_care: 'CDCC taxable benefits (#28)',
  taxable_pensions_and_annuities: '1099-R pensions (#22)',
  taxable_social_security_benefits: 'Social Security benefits (#23)',
  unemployment_compensation: 'unemployment/1099-G, Alaska PFD, 1099-MISC (#21)',
  student_loan_interest_adjustment_amount: 'student loan / educator adjustments (#24)',
  educator_expenses_adjustment: 'student loan / educator adjustments (#24)',
  hsa_total_deductible_amount: 'HSA deduction (#35)',
  total_additional_taxes_owed: 'excess APTC repayment, PTC (#32-34)',
  total_ctc_and_odc: 'CTC/ODC (#27)',
  line8_of_schedule3: 'Schedule 3 credits: CDCC/Saver/Sched R (#28-30)',
  other_1099_withholding: 'non-interest 1099 withholding (#21-23)',
  estimated_and_from_last_year: 'estimated payments (#25)',
  earned_income_credit: 'EITC (#26)',
  additional_ctc: 'ACTC (#27)',
  other_payments_and_refundable_credits_total: 'net PTC (#32-34)',
};
export const categoriesOf = (facts) => [...new Set(
  Object.entries(slotValues(facts)).filter(([, v]) => v !== 0n).map(([k]) => CATEGORY[k]))];

const baseInputs = {
  filing_status: (f) => STATUS[val(f, '/filingStatus')],
  w2s: w2map.inputs.w2s,
  interest_reports: interestReports,
  has_foreign_accounts_or_trusts: (f) =>
    val(f, '/hasForeignAccounts') === 'true' || val(f, '/isForeignTrustsGrantorOrHasForeignTrustsTransactions') === 'true',
  combat_pay_election: w2map.inputs.combat_pay_election,
  primary_filer_can_be_claimed: w2map.inputs.primary_filer_can_be_claimed,
  secondary_filer_can_be_claimed: w2map.inputs.secondary_filer_can_be_claimed,
  // standard deduction inputs: see the limits stated in mappings/standard_deduction.mjs
  treat_as_mfs: sdmap.inputs.treat_as_mfs,
  primary_filer_is_blind: sdmap.inputs.primary_filer_is_blind,
  primary_filer_age65_or_older: sdmap.inputs.primary_filer_age65_or_older,
  secondary_filer_is_blind: sdmap.inputs.secondary_filer_is_blind,
  secondary_filer_age65_or_older: sdmap.inputs.secondary_filer_age65_or_older,
  is_widowed_in_tax_year: sdmap.inputs.is_widowed_in_tax_year,
  mfj_deceased_spouse_reached_age65: sdmap.inputs.mfj_deceased_spouse_reached_age65,
  mfs_spouse_65_or_older: sdmap.inputs.mfs_spouse_65_or_older,
  mfs_spouse_provides_no_benefits: sdmap.inputs.mfs_spouse_provides_no_benefits,
  treat_filers_as_dependents: sdmap.inputs.treat_filers_as_dependents,
};

export const pluggedInputs = {
  ...baseInputs,
  paid_estimated_taxes_or_from_last_year: (f) => val(f, '/paidEstimatedTaxesOrFromLastYear') === 'true',
};
// Money slots are added one function per slot so the runner can evaluate them per scenario.
for (const k of Object.keys(slotValues(new Map()))) pluggedInputs[k] = (f) => money(slotValues(f)[k]);

export const unpluggedInputs = baseInputs;

export const outputs = [
  ['/wages', 'wages'], ['/employerIncomeSubtotal', 'employer_income_subtotal'], ['/interestIncome', 'interest_income'],
  ['/totalIncome', 'total_income'], ['/adjustmentsToIncome', 'adjustments_to_income'], ['/agi', 'agi'],
  ['/standardOrItemizedDeductions', 'standard_or_itemized_deductions'], ['/totalDeductions', 'total_deductions'],
  ['/taxableIncome', 'taxable_income'], ['/tentativeTaxFromTaxableIncome', 'tentative_tax_from_taxable_income'],
  ['/totalTentativeTax', 'total_tentative_tax'], ['/nonRefundableCredits', 'non_refundable_credits'],
  ['/taxLessNonRefundableCredits', 'tax_less_non_refundable_credits'], ['/totalTax', 'total_tax'],
  ['/formW2Withholding', 'form_w2_withholding'], ['/form1099Withholding', 'form_1099_withholding'],
  ['/totalWithholding', 'total_withholding'],
  ['/totalOtherPaymentsRefundableCredits', 'total_other_payments_refundable_credits'],
  ['/totalPayments', 'total_payments'], ['/overpayment', 'overpayment'], ['/balanceDue', 'balance_due'],
].map(([oracle, catala]) => ({ oracle, catala, type: 'money' }));

// parseOracleValue is re-exported for mappings that need it
export { parseOracleValue };
