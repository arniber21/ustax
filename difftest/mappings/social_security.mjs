// Mapping for catala/social_security.catala_en (scope SocialSecurity), issue #23.
// Run: make difftest SCOPE=social_security
//
// Inputs from the oracle: the writable SSA net benefits per report (formType is hard-wired to SSA-1099 in
// DF, so /rrbNetBenefits is never read), filing status, the 1040 line 1z / 2a / 2b / 8 figures, and the
// adjustments DF sums for worksheet line 6 (educator expenses + HSA deduction; every other Schedule 1
// adjustment is a comment in DF's /adjustmentsToIncomeExcludingStudentLoanInterest).
// Not in the oracle: 3b, 4b, 5b and 7 (dividends, IRA, pensions, capital gains; DF modules not yet
// built). 3b, 4b and 7 are $0. Worksheet line 3 only needs their sum, so line 5b carries the residual
// /totalIncome - 1z - 2b - 8 - 6b (the 1099-R scenarios; $0 in all others), which does not depend on the
// Catala output under test. DF's /totalIncome is the sum of those 1040 lines, so the residual is exact.
import { parseMoney, scalar, listFromCollection } from '../lib.mjs';

const val = (f, p) => { const r = f.get(p); return r && r.completeness !== 'Incomplete' ? r.value : undefined; };
const cents = (f, p) => { const v = val(f, p); return v === undefined || v === '' ? 0n : parseMoney(v); };
const FS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};

export default {
  name: 'social_security',
  scope: 'SocialSecurity',
  file: 'catala/social_security.catala_en',
  appliesTo: () => true,
  inputs: {
    report_net_benefits: listFromCollection('/socialSecurityReports', 'ssaNetBenefits', { type: 'money', missing: '0' }),
    filing_status: (f) => FS[val(f, '/filingStatus')],
    // DF /livedApartAllYear = not livedTogetherAllYearWithSpouse and spouseLivedTogetherMonths = livedApartAllYear
    // (catala/filers.catala_en); only read for MFS.
    lived_apart_all_year: (f) => val(f, '/livedTogetherAllYearWithSpouse') === 'false'
      && val(f, '/spouseLivedTogetherMonths') === 'livedApartAllYear',
    line_1z: scalar('/employerIncomeSubtotal', { type: 'money', missing: '0' }),
    line_2b: scalar('/interestIncome', { type: 'money', missing: '0' }),
    line_2a: scalar('/taxExemptInterest', { type: 'money', missing: '0' }),
    line_3b: () => 0,
    line_4b: () => 0,
    line_5b: (f) => Number(cents(f, '/totalIncome') - cents(f, '/employerIncomeSubtotal') - cents(f, '/interestIncome')
      - cents(f, '/otherIncome') - cents(f, '/taxableSocialSecurityBenefits')) / 100,
    line_7_capital_gains: () => 0,
    line_8_other_income: scalar('/otherIncome', { type: 'money', missing: '0' }),
    adjustments_excluding_student_loan_interest: (f) =>
      Number(cents(f, '/educatorExpensesAdjustment') + cents(f, '/hsaTotalDeductibleAmount')) / 100,
  },
  outputs: [
    { oracle: '/socialSecurityBenefits', catala: 'line_6a', type: 'money' },
    { oracle: '/taxableSocialSecurityBenefits', catala: 'line_6b', type: 'money' },
    { oracle: '/hasSocialSecurityBenefits', catala: 'has_benefits', type: 'bool' },
  ],
};
