// Mapping for catala/student_loan_adjustment.catala_en (scope StudentLoanAdjustment): Schedule 1 line 21.
// Run: make difftest SCOPE=student_loan_adjustment
//
// MAGI = /totalIncome less /adjustmentsToIncomeExcludingStudentLoanInterest, which is rebuilt here as
// /educatorExpensesAdjustment + /hsaTotalDeductibleAmount (blank = $0, as in taxCalculations.xml).
// The oracle has no /isMFJDependent or /eitherFilerIsClaimedAsDependent row; both are fed as false.
//
// knownDivergence (DF-BUG(7), candidate): the module implements IRC 221(b)(2)(B) with the exact
// ratio; DF rounds the ratio to three decimals and can differ by up to $2. A scenario is listed when
// its MAGI lies in the phase-out range (> start, <= end) with student loan interest paid. The
// difftest runner has no knownDivergence support yet; the predicate is exported for it. No oracle
// scenario is in a phase-out range (checked 2026-11-01), so the list is empty today.
const val = (f, p) => f.get(p)?.value;
const num = (f, p) => { const v = val(f, p); return v === undefined || v === '' ? 0 : Number(v); };
const FS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};
const magi = (f) => num(f, '/totalIncome') - num(f, '/educatorExpensesAdjustment') - num(f, '/hsaTotalDeductibleAmount');

export default {
  name: 'student_loan_adjustment',
  scope: 'StudentLoanAdjustment',
  file: 'catala/student_loan_adjustment.catala_en',
  appliesTo: () => true,
  inputs: {
    filing_status: (f) => FS[val(f, '/filingStatus')],
    had_student_loan_interest_payments: (f) => val(f, '/hadStudentLoanInterestPayments') === 'true',
    student_loans_qualify: (f) => val(f, '/studentLoansQualify') === 'true',
    student_loan_interest_amount: (f) => num(f, '/studentLoanInterestAmount'),
    is_mfj_dependent: () => false,
    either_filer_is_claimed_as_dependent: () => false,
    total_income: (f) => num(f, '/totalIncome'),
    adjustments_to_income_excluding_student_loan_interest: (f) =>
      num(f, '/educatorExpensesAdjustment') + num(f, '/hsaTotalDeductibleAmount'),
  },
  outputs: [
    { oracle: '/studentLoanInterestAdjustmentAmount', catala: 'student_loan_interest_adjustment_amount', type: 'money' },
  ],
  knownDivergence: (f) => {
    const mfj = val(f, '/filingStatus') === 'marriedFilingJointly';
    const [s, e] = mfj ? [165000, 195000] : [80000, 95000];
    const m = magi(f);
    return val(f, '/hadStudentLoanInterestPayments') === 'true' && m > s && m <= e ? 'DF-BUG(7)' : null;
  },
};
