import UsTax.Spec.StandardDeduction
import UsTax.Spec.Interest
import UsTax.Spec.FormW2
import UsTax.Spec.SocialSecurity
import UsTax.Spec.Adjustments
import UsTax.Spec.Form1040Lines
import UsTax.Spec.Inputs
import UsTax.StandardDeduction
import UsTax.Interest
import UsTax.FormW2s
import UsTax.SocialSecurity
import UsTax.EducatorAdjustment
import UsTax.StudentLoanAdjustment
import UsTax.EstimatedPayments
import UsTax.Form1040
import UsTax.Form1040Full
import UsTax.Spec.Calculator
import UsTax.Spec.RefundBalance
import UsTax.Spec.Credits
import UsTax.Calculator
import UsTax.ApiCalculator
import UsTax.Api.Calculate

/-!
# Second challenge for `lake comparator`: module specs (issue #64)

Not the main theorems (those are `UsTax/Comparator/Challenge.lean`, chosen by
a human). These are the module-level statements of `UsTax/Proofs/*.lean`:
each module of the calculator equals a statute-style spec in
`UsTax/Spec/*.lean`, plus bounds and monotonicity. Checked by
`make comparator-extra` against `lean/comparator.extra.json`, with solution
module `UsTax.Proofs.Extra`. `sorry` proofs by design; not imported by
`UsTax.lean`, excluded from `make audit` (docs/comparator.md). Reviewed in
`docs/spec-surface.md`, section "Module specs".

Imports: the specs, and the calculator modules (definitions only, no proofs).
-/

namespace UsTax.Extra

open UsTax.Spec

/-! ## Standard deduction (IRC 63(c)) -/

/-- Line 12 is the IRC 63(c) amount. -/
theorem standardDeduction_eq_spec (i : StandardDeduction.StandardDeductionIn) :
    (StandardDeduction.standardDeduction i).standardDeduction =
      standardDeductionSpec i.filingStatus
        (StandardDeduction.standardDeduction i).additionalStandardDeductionItems
        i.treatFilersAsDependents i.employerIncomeSubtotal := by
  sorry

/-- The item count is between 0 and 4, at most 2 without a spouse who counts. -/
theorem additionalItems_range (i : StandardDeduction.StandardDeductionIn) :
    0 ≤ (StandardDeduction.standardDeduction i).additionalStandardDeductionItems ∧
      (StandardDeduction.standardDeduction i).additionalStandardDeductionItems ≤ 4 ∧
      (i.filingStatus ≠ .marriedFilingJointly → i.treatAsMfs = false →
        (StandardDeduction.standardDeduction i).additionalStandardDeductionItems ≤ 2) := by
  sorry

/-! ## Interest (Form 1040 line 2b, Schedule B) -/

/-- Schedule B is required exactly as the instructions say. -/
theorem requiresScheduleB_eq_spec (i : Interest.InterestIn) :
    (Interest.interest i).requiresScheduleB =
      scheduleBRequired (i.interestReports.map reportTaxableInterest) i.hasForeignAccountsOrTrusts := by
  sorry

/-- Line 2b is the spec's amount. -/
theorem interestIncome_eq_spec (i : Interest.InterestIn) :
    (Interest.interest i).interestIncome =
      interestLine2b (i.interestReports.map reportTaxableInterest) i.hasForeignAccountsOrTrusts := by
  sorry

/-! ## Forms W-2 -/

/-- Line 1a is the total of box 1, each W-2 rounded to the dollar. -/
theorem wages_eq_spec (i : FormW2s.FormW2sIn) :
    (FormW2s.formW2s i).wages = totalOfBox (i.w2s.map (·.writableWages)) := by
  sorry

/-- Line 25a is the total of box 2, each W-2 rounded to the dollar. -/
theorem formW2Withholding_eq_spec (i : FormW2s.FormW2sIn) :
    (FormW2s.formW2s i).formW2Withholding = totalOfBox (i.w2s.map (·.writableFederalWithholding)) := by
  sorry

/-- The Medicare knockout is exactly "Form 8959 is needed". -/
theorem medicareKnockout_eq_spec (i : FormW2s.FormW2sIn) :
    (FormW2s.formW2s i).koKnockoutMedicareWages =
      needsForm8959 i.filingStatus (filerBox .primaryFiler (·.writableMedicareWages) i.w2s)
        (filerBox .secondaryFiler (·.writableMedicareWages) i.w2s) := by
  sorry

/-- The social security knockouts are exactly "excess withholding possible". -/
theorem oasdiKnockout_eq_spec (i : FormW2s.FormW2sIn) :
    (FormW2s.formW2s i).primaryFilerExceedsMaxOasdiWages =
      excessSocialSecurityPossible (filerBox .primaryFiler (·.writableOasdiWages) i.w2s) ∧
    (FormW2s.formW2s i).secondaryFilerExceedsMaxOasdiWages =
      excessSocialSecurityPossible (filerBox .secondaryFiler (·.writableOasdiWages) i.w2s) ∧
    (FormW2s.formW2s i).koAnyFilerExceedsMaxOasdiWages =
      ((FormW2s.formW2s i).primaryFilerExceedsMaxOasdiWages ||
        (FormW2s.formW2s i).secondaryFilerExceedsMaxOasdiWages) := by
  sorry

/-! ## Social Security (IRC 86) -/

/-- Line 6b is the IRC 86 amount. -/
theorem line6b_eq_spec (i : SocialSecurity.SocialSecurityIn) :
    (SocialSecurity.socialSecurity i).line6b =
      taxableSocialSecurity i.filingStatus i.livedApartAllYear
        (roundToDollar i.reportNetBenefits.sum) (ssModifiedAgi i) := by
  sorry

/-- `0 ≤ line 6b ≤ 85% of line 6a` (rounded; `$0` for negative benefits). -/
theorem line6b_bounds (i : SocialSecurity.SocialSecurityIn) :
    0 ≤ (SocialSecurity.socialSecurity i).line6b ∧
      (SocialSecurity.socialSecurity i).line6b ≤
        roundToDollar (percentOf 85 (max 0 (SocialSecurity.socialSecurity i).line6a)) := by
  sorry

/-- More other income never lowers line 6b. -/
theorem line6b_mono_otherIncome (i : SocialSecurity.SocialSecurityIn) {x y : Int} (h : x ≤ y) :
    (SocialSecurity.socialSecurity { i with line8OtherIncome := x }).line6b ≤
      (SocialSecurity.socialSecurity { i with line8OtherIncome := y }).line6b := by
  sorry

/-! ## Educator expenses (IRC 62(a)(2)(D)), student loan interest (IRC 221) -/

/-- Line 11 is the IRC 62(a)(2)(D) amount. -/
theorem educatorAdjustment_eq_spec (i : EducatorAdjustment.EducatorAdjustmentIn) :
    (EducatorAdjustment.educatorAdjustment i).educatorExpensesAdjustment =
      educatorDeduction (tpIsEducator i.wasK12Educators) (spouseIsEducator i.wasK12Educators)
        i.primaryEducatorExpensesWritable i.secondaryEducatorExpensesWritable i.isMfjDependent := by
  sorry

/-- `0 ≤ line 11 ≤ $300 × the number of educators`, for nonnegative expenses. -/
theorem educatorAdjustment_bounds (i : EducatorAdjustment.EducatorAdjustmentIn)
    (hp : 0 ≤ i.primaryEducatorExpensesWritable) (hs : 0 ≤ i.secondaryEducatorExpensesWritable) :
    0 ≤ (EducatorAdjustment.educatorAdjustment i).educatorExpensesAdjustment ∧
      (EducatorAdjustment.educatorAdjustment i).educatorExpensesAdjustment ≤
        300_00 * ((if tpIsEducator i.wasK12Educators then 1 else 0) +
          (if spouseIsEducator i.wasK12Educators then 1 else 0)) := by
  sorry

/-- Line 21 is the IRC 221 amount. -/
theorem studentLoanAdjustment_eq_spec (i : StudentLoanAdjustment.StudentLoanAdjustmentIn) :
    (StudentLoanAdjustment.studentLoanAdjustment i).studentLoanInterestAdjustmentAmount =
      studentLoanDeduction i.filingStatus (studentLoanEligible i) i.studentLoanInterestAmount
        (i.totalIncome - i.adjustmentsToIncomeExcludingStudentLoanInterest) := by
  sorry

/-- `0 ≤ line 21 ≤ min(interest, $2,500)`, for nonnegative interest. -/
theorem studentLoanAdjustment_bounds (i : StudentLoanAdjustment.StudentLoanAdjustmentIn)
    (h : 0 ≤ i.studentLoanInterestAmount) :
    0 ≤ (StudentLoanAdjustment.studentLoanAdjustment i).studentLoanInterestAdjustmentAmount ∧
      (StudentLoanAdjustment.studentLoanAdjustment i).studentLoanInterestAdjustmentAmount ≤
        min (roundToDollar i.studentLoanInterestAmount) 2_500_00 := by
  sorry

/-- Line 21 is `$0` from the end of the phase-out. -/
theorem studentLoanAdjustment_zero_of_magi_ge_end (i : StudentLoanAdjustment.StudentLoanAdjustmentIn)
    (h : studentLoanPhaseoutStart i.filingStatus + studentLoanPhaseoutRange i.filingStatus ≤
      i.totalIncome - i.adjustmentsToIncomeExcludingStudentLoanInterest) :
    (StudentLoanAdjustment.studentLoanAdjustment i).studentLoanInterestAdjustmentAmount = 0 := by
  sorry

/-- More total income never raises line 21 (nonnegative interest). -/
theorem studentLoanAdjustment_antitone (i : StudentLoanAdjustment.StudentLoanAdjustmentIn)
    (hi : 0 ≤ i.studentLoanInterestAmount) {x y : Int} (h : x ≤ y) :
    (StudentLoanAdjustment.studentLoanAdjustment
        { i with totalIncome := y }).studentLoanInterestAdjustmentAmount ≤
      (StudentLoanAdjustment.studentLoanAdjustment
        { i with totalIncome := x }).studentLoanInterestAdjustmentAmount := by
  sorry

/-! ## Line 26 and the Form 1040 line arithmetic -/

/-- Line 26 is the payment in whole dollars, or `$0`. -/
theorem estimatedPayments_eq_spec (i : EstimatedPayments.EstimatedPaymentsIn) :
    (EstimatedPayments.estimatedPayments i).estimatedAndFromLastYear =
      estimatedPaymentsLine26 i.paidEstimatedTaxesOrFromLastYear i.estimatedTaxPaymentWritable := by
  sorry

/-- Line 11 = line 9 − line 10. -/
theorem agi_eq (i : Form1040.Form1040In) :
    (Form1040.form1040 i).agi =
      (Form1040.form1040 i).totalIncome - (Form1040.form1040 i).adjustmentsToIncome := by
  sorry

/-- Line 15 = `max 0 (line 11 − line 14)`. -/
theorem taxableIncome_eq (i : Form1040.Form1040In) :
    (Form1040.form1040 i).taxableIncome =
      max 0 ((Form1040.form1040 i).agi - (Form1040.form1040 i).totalDeductions) := by
  sorry

/-- Line 33 = line 25d + line 26 + line 32, when line 26 is whole dollars. -/
theorem totalPayments_eq (i : Form1040.Form1040In) (h26 : i.estimatedAndFromLastYear % 100 = 0) :
    (Form1040.form1040 i).totalPayments =
      (Form1040.form1040 i).totalWithholding + i.estimatedAndFromLastYear +
        (Form1040.form1040 i).totalOtherPaymentsRefundableCredits := by
  sorry

/-- On the whole return, line 33 = line 25d + line 26 + line 32 always. -/
theorem totalPayments_eq_full (i : Form1040Full.Form1040FullIn) :
    (Form1040Full.form1040Full i).form1040.totalPayments =
      (Form1040Full.form1040Full i).form1040.totalWithholding +
        (Form1040Full.form1040Full i).estimated.estimatedAndFromLastYear +
        (Form1040Full.form1040Full i).form1040.totalOtherPaymentsRefundableCredits := by
  sorry

/-- Adding a W-2 with nonnegative wages never lowers line 24 (credits fixed). -/
theorem totalTax_mono_addW2 (i : Form1040.Form1040In) (w : FormW2s.FormW2) (hw : 0 ≤ w.writableWages) :
    (Form1040.form1040 i).totalTax ≤ (Form1040.form1040 { i with w2s := w :: i.w2s }).totalTax := by
  sorry

/-! ## The whole return and the API answer (issue #48) -/

/-- Refund and amount owed on the whole return are exclusive and consistent (#65). -/
theorem calculator_refund_balanceDue_consistent (i : Calculator.CalculatorIn) :
    RefundOrBalanceDue (Calculator.calculator i).totalTax (Calculator.calculator i).totalPayments
      (Calculator.calculator i).overpayment (Calculator.calculator i).balanceDue := by
  sorry

/-- On the whole return, the nonrefundable credits used (lines 19 + 20 = 21) never exceed line 18
(#66). -/
theorem calculator_credits_within_liability (i : Calculator.CalculatorIn) :
    CreditsWithinLiability (Calculator.calculator i).totalTentativeTax
      (Calculator.calculator i).nonRefundableCredits
      (Calculator.calculator i).taxLessNonRefundableCredits := by
  sorry

/-- On the whole return, total tax (line 24) is never negative. -/
theorem calculator_totalTax_nonneg (i : Calculator.CalculatorIn) :
    0 ≤ (Calculator.calculator i).totalTax := by
  sorry

/-- The CDCC, Schedule R and Saver's credits together are within line 18 of the tax pass (#66). -/
theorem calculator_credits_le_tax (i : Calculator.CalculatorIn) :
    CreditsWithinTax (Calculator.calculator i).cdccTotalCredit (Calculator.calculator i).totalEdc
      (Calculator.calculator i).qualifiedSaverCreditAmount
      (Calculator.calculator i).fTax.totalTentativeTax := by
  sorry

/-- A return is unsupported exactly when at least one knockout reason fired. -/
theorem calculator_unsupported_iff (i : Calculator.CalculatorIn) :
    (Calculator.calculator i).unsupported = true ↔ (Calculator.calculator i).firedKnockouts ≠ [] := by
  sorry

/-- The API answer: `supported = false` exactly when `reasons` is non-empty. -/
theorem apiCalculator_supported_iff (r : Api.Request) :
    KnockoutSound (ApiCalculator.apiCalculator r).supported (ApiCalculator.apiCalculator r).reasons := by
  sorry

/-- The API answer: `outcome = refund` exactly when line 34 is positive. -/
theorem apiCalculator_outcome_refund_iff (r : Api.Request) :
    RefundOutcome (ApiCalculator.apiCalculator r).outcome
      (ApiCalculator.apiCalculator r).lines.overpayment := by
  sorry

/-- The pure calculator never returns its internal-inconsistency result on a valid request.
HTTP/runtime exceptions are outside this theorem. -/
theorem calculateRequest_ne_fault (r : Api.Request) (h : r.Valid) :
    Api.calculateRequest r h ≠ .fault := by
  sorry

end UsTax.Extra
