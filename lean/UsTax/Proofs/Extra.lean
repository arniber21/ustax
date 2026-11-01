import UsTax.Proofs.StandardDeduction
import UsTax.Proofs.Interest
import UsTax.Proofs.FormW2
import UsTax.Proofs.SocialSecurity
import UsTax.Proofs.Adjustments
import UsTax.Proofs.Form1040Lines
import UsTax.Proofs.Calculator
import UsTax.Audit

/-!
# Module specs, proved (solution module of `lean/comparator.extra.json`)

Same names and statements as `UsTax/Comparator/Extra.lean`; each proof is the
theorem of the same name in namespace `UsTax.Proofs` (`UsTax/Proofs/*.lean`),
where the concrete instances and rejected bad outputs are.
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
  apply UsTax.Proofs.standardDeduction_eq_spec <;> assumption

/-- The item count is between 0 and 4, at most 2 without a spouse who counts. -/
theorem additionalItems_range (i : StandardDeduction.StandardDeductionIn) :
    0 ≤ (StandardDeduction.standardDeduction i).additionalStandardDeductionItems ∧
      (StandardDeduction.standardDeduction i).additionalStandardDeductionItems ≤ 4 ∧
      (i.filingStatus ≠ .marriedFilingJointly → i.treatAsMfs = false →
        (StandardDeduction.standardDeduction i).additionalStandardDeductionItems ≤ 2) := by
  apply UsTax.Proofs.additionalItems_range <;> assumption

/-! ## Interest (Form 1040 line 2b, Schedule B) -/

/-- Schedule B is required exactly as the instructions say. -/
theorem requiresScheduleB_eq_spec (i : Interest.InterestIn) :
    (Interest.interest i).requiresScheduleB =
      scheduleBRequired (i.interestReports.map reportTaxableInterest) i.hasForeignAccountsOrTrusts := by
  apply UsTax.Proofs.requiresScheduleB_eq_spec <;> assumption

/-- Line 2b is the spec's amount. -/
theorem interestIncome_eq_spec (i : Interest.InterestIn) :
    (Interest.interest i).interestIncome =
      interestLine2b (i.interestReports.map reportTaxableInterest) i.hasForeignAccountsOrTrusts := by
  apply UsTax.Proofs.interestIncome_eq_spec <;> assumption

/-! ## Forms W-2 -/

/-- Line 1a is the total of box 1, each W-2 rounded to the dollar. -/
theorem wages_eq_spec (i : FormW2s.FormW2sIn) :
    (FormW2s.formW2s i).wages = totalOfBox (i.w2s.map (·.writableWages)) := by
  apply UsTax.Proofs.wages_eq_spec <;> assumption

/-- Line 25a is the total of box 2, each W-2 rounded to the dollar. -/
theorem formW2Withholding_eq_spec (i : FormW2s.FormW2sIn) :
    (FormW2s.formW2s i).formW2Withholding = totalOfBox (i.w2s.map (·.writableFederalWithholding)) := by
  apply UsTax.Proofs.formW2Withholding_eq_spec <;> assumption

/-- The Medicare knockout is exactly "Form 8959 is needed". -/
theorem medicareKnockout_eq_spec (i : FormW2s.FormW2sIn) :
    (FormW2s.formW2s i).koKnockoutMedicareWages =
      needsForm8959 i.filingStatus (filerBox .primaryFiler (·.writableMedicareWages) i.w2s)
        (filerBox .secondaryFiler (·.writableMedicareWages) i.w2s) := by
  apply UsTax.Proofs.medicareKnockout_eq_spec <;> assumption

/-- The social security knockouts are exactly "excess withholding possible". -/
theorem oasdiKnockout_eq_spec (i : FormW2s.FormW2sIn) :
    (FormW2s.formW2s i).primaryFilerExceedsMaxOasdiWages =
      excessSocialSecurityPossible (filerBox .primaryFiler (·.writableOasdiWages) i.w2s) ∧
    (FormW2s.formW2s i).secondaryFilerExceedsMaxOasdiWages =
      excessSocialSecurityPossible (filerBox .secondaryFiler (·.writableOasdiWages) i.w2s) ∧
    (FormW2s.formW2s i).koAnyFilerExceedsMaxOasdiWages =
      ((FormW2s.formW2s i).primaryFilerExceedsMaxOasdiWages ||
        (FormW2s.formW2s i).secondaryFilerExceedsMaxOasdiWages) := by
  apply UsTax.Proofs.oasdiKnockout_eq_spec <;> assumption

/-! ## Social Security (IRC 86) -/

/-- Line 6b is the IRC 86 amount. -/
theorem line6b_eq_spec (i : SocialSecurity.SocialSecurityIn) :
    (SocialSecurity.socialSecurity i).line6b =
      taxableSocialSecurity i.filingStatus i.livedApartAllYear
        (roundToDollar i.reportNetBenefits.sum) (ssModifiedAgi i) := by
  apply UsTax.Proofs.line6b_eq_spec <;> assumption

/-- `0 ≤ line 6b ≤ 85% of line 6a` (rounded; `$0` for negative benefits). -/
theorem line6b_bounds (i : SocialSecurity.SocialSecurityIn) :
    0 ≤ (SocialSecurity.socialSecurity i).line6b ∧
      (SocialSecurity.socialSecurity i).line6b ≤
        roundToDollar (percentOf 85 (max 0 (SocialSecurity.socialSecurity i).line6a)) := by
  apply UsTax.Proofs.line6b_bounds <;> assumption

/-- More other income never lowers line 6b. -/
theorem line6b_mono_otherIncome (i : SocialSecurity.SocialSecurityIn) {x y : Int} (h : x ≤ y) :
    (SocialSecurity.socialSecurity { i with line8OtherIncome := x }).line6b ≤
      (SocialSecurity.socialSecurity { i with line8OtherIncome := y }).line6b := by
  apply UsTax.Proofs.line6b_mono_otherIncome <;> assumption

/-! ## Educator expenses (IRC 62(a)(2)(D)), student loan interest (IRC 221) -/

/-- Line 11 is the IRC 62(a)(2)(D) amount. -/
theorem educatorAdjustment_eq_spec (i : EducatorAdjustment.EducatorAdjustmentIn) :
    (EducatorAdjustment.educatorAdjustment i).educatorExpensesAdjustment =
      educatorDeduction (tpIsEducator i.wasK12Educators) (spouseIsEducator i.wasK12Educators)
        i.primaryEducatorExpensesWritable i.secondaryEducatorExpensesWritable i.isMfjDependent := by
  apply UsTax.Proofs.educatorAdjustment_eq_spec <;> assumption

/-- `0 ≤ line 11 ≤ $300 × the number of educators`, for nonnegative expenses. -/
theorem educatorAdjustment_bounds (i : EducatorAdjustment.EducatorAdjustmentIn)
    (hp : 0 ≤ i.primaryEducatorExpensesWritable) (hs : 0 ≤ i.secondaryEducatorExpensesWritable) :
    0 ≤ (EducatorAdjustment.educatorAdjustment i).educatorExpensesAdjustment ∧
      (EducatorAdjustment.educatorAdjustment i).educatorExpensesAdjustment ≤
        300_00 * ((if tpIsEducator i.wasK12Educators then 1 else 0) +
          (if spouseIsEducator i.wasK12Educators then 1 else 0)) := by
  apply UsTax.Proofs.educatorAdjustment_bounds <;> assumption

/-- Line 21 is the IRC 221 amount. -/
theorem studentLoanAdjustment_eq_spec (i : StudentLoanAdjustment.StudentLoanAdjustmentIn) :
    (StudentLoanAdjustment.studentLoanAdjustment i).studentLoanInterestAdjustmentAmount =
      studentLoanDeduction i.filingStatus (studentLoanEligible i) i.studentLoanInterestAmount
        (i.totalIncome - i.adjustmentsToIncomeExcludingStudentLoanInterest) := by
  apply UsTax.Proofs.studentLoanAdjustment_eq_spec <;> assumption

/-- `0 ≤ line 21 ≤ min(interest, $2,500)`, for nonnegative interest. -/
theorem studentLoanAdjustment_bounds (i : StudentLoanAdjustment.StudentLoanAdjustmentIn)
    (h : 0 ≤ i.studentLoanInterestAmount) :
    0 ≤ (StudentLoanAdjustment.studentLoanAdjustment i).studentLoanInterestAdjustmentAmount ∧
      (StudentLoanAdjustment.studentLoanAdjustment i).studentLoanInterestAdjustmentAmount ≤
        min (roundToDollar i.studentLoanInterestAmount) 2_500_00 := by
  apply UsTax.Proofs.studentLoanAdjustment_bounds <;> assumption

/-- Line 21 is `$0` from the end of the phase-out. -/
theorem studentLoanAdjustment_zero_of_magi_ge_end (i : StudentLoanAdjustment.StudentLoanAdjustmentIn)
    (h : studentLoanPhaseoutStart i.filingStatus + studentLoanPhaseoutRange i.filingStatus ≤
      i.totalIncome - i.adjustmentsToIncomeExcludingStudentLoanInterest) :
    (StudentLoanAdjustment.studentLoanAdjustment i).studentLoanInterestAdjustmentAmount = 0 := by
  apply UsTax.Proofs.studentLoanAdjustment_zero_of_magi_ge_end <;> assumption

/-- More total income never raises line 21 (nonnegative interest). -/
theorem studentLoanAdjustment_antitone (i : StudentLoanAdjustment.StudentLoanAdjustmentIn)
    (hi : 0 ≤ i.studentLoanInterestAmount) {x y : Int} (h : x ≤ y) :
    (StudentLoanAdjustment.studentLoanAdjustment
        { i with totalIncome := y }).studentLoanInterestAdjustmentAmount ≤
      (StudentLoanAdjustment.studentLoanAdjustment
        { i with totalIncome := x }).studentLoanInterestAdjustmentAmount := by
  apply UsTax.Proofs.studentLoanAdjustment_antitone <;> assumption

/-! ## Line 26 and the Form 1040 line arithmetic -/

/-- Line 26 is the payment in whole dollars, or `$0`. -/
theorem estimatedPayments_eq_spec (i : EstimatedPayments.EstimatedPaymentsIn) :
    (EstimatedPayments.estimatedPayments i).estimatedAndFromLastYear =
      estimatedPaymentsLine26 i.paidEstimatedTaxesOrFromLastYear i.estimatedTaxPaymentWritable := by
  apply UsTax.Proofs.estimatedPayments_eq_spec <;> assumption

/-- Line 11 = line 9 − line 10. -/
theorem agi_eq (i : Form1040.Form1040In) :
    (Form1040.form1040 i).agi =
      (Form1040.form1040 i).totalIncome - (Form1040.form1040 i).adjustmentsToIncome := by
  apply UsTax.Proofs.agi_eq <;> assumption

/-- Line 15 = `max 0 (line 11 − line 14)`. -/
theorem taxableIncome_eq (i : Form1040.Form1040In) :
    (Form1040.form1040 i).taxableIncome =
      max 0 ((Form1040.form1040 i).agi - (Form1040.form1040 i).totalDeductions) := by
  apply UsTax.Proofs.taxableIncome_eq <;> assumption

/-- Line 33 = line 25d + line 26 + line 32, when line 26 is whole dollars. -/
theorem totalPayments_eq (i : Form1040.Form1040In) (h26 : i.estimatedAndFromLastYear % 100 = 0) :
    (Form1040.form1040 i).totalPayments =
      (Form1040.form1040 i).totalWithholding + i.estimatedAndFromLastYear +
        (Form1040.form1040 i).totalOtherPaymentsRefundableCredits := by
  apply UsTax.Proofs.totalPayments_eq <;> assumption

/-- On the whole return, line 33 = line 25d + line 26 + line 32 always. -/
theorem totalPayments_eq_full (i : Form1040Full.Form1040FullIn) :
    (Form1040Full.form1040Full i).form1040.totalPayments =
      (Form1040Full.form1040Full i).form1040.totalWithholding +
        (Form1040Full.form1040Full i).estimated.estimatedAndFromLastYear +
        (Form1040Full.form1040Full i).form1040.totalOtherPaymentsRefundableCredits := by
  apply UsTax.Proofs.totalPayments_eq_full <;> assumption

/-- Adding a W-2 with nonnegative wages never lowers line 24 (credits fixed). -/
theorem totalTax_mono_addW2 (i : Form1040.Form1040In) (w : FormW2s.FormW2) (hw : 0 ≤ w.writableWages) :
    (Form1040.form1040 i).totalTax ≤ (Form1040.form1040 { i with w2s := w :: i.w2s }).totalTax := by
  apply UsTax.Proofs.totalTax_mono_addW2 <;> assumption

/-! ## The whole return and the API answer (issue #48) -/

/-- Refund and amount owed on the whole return are exclusive and consistent (#65). -/
theorem calculator_refund_balanceDue_consistent (i : Calculator.CalculatorIn) :
    RefundOrBalanceDue (Calculator.calculator i).totalTax (Calculator.calculator i).totalPayments
      (Calculator.calculator i).overpayment (Calculator.calculator i).balanceDue := by
  exact UsTax.Proofs.calculator_refund_balanceDue_consistent _

/-- On the whole return, the nonrefundable credits used (lines 19 + 20 = 21) never exceed line 18
(#66). -/
theorem calculator_credits_within_liability (i : Calculator.CalculatorIn) :
    CreditsWithinLiability (Calculator.calculator i).totalTentativeTax
      (Calculator.calculator i).nonRefundableCredits
      (Calculator.calculator i).taxLessNonRefundableCredits := by
  exact UsTax.Proofs.calculator_credits_within_liability _

/-- On the whole return, total tax (line 24) is never negative. -/
theorem calculator_totalTax_nonneg (i : Calculator.CalculatorIn) :
    0 ≤ (Calculator.calculator i).totalTax := by
  exact UsTax.Proofs.calculator_totalTax_nonneg _

/-- The CDCC, Schedule R and Saver's credits together are within line 18 of the tax pass (#66). -/
theorem calculator_credits_le_tax (i : Calculator.CalculatorIn) :
    CreditsWithinTax (Calculator.calculator i).cdccTotalCredit (Calculator.calculator i).totalEdc
      (Calculator.calculator i).qualifiedSaverCreditAmount
      (Calculator.calculator i).fTax.totalTentativeTax := by
  exact UsTax.Proofs.calculator_credits_le_tax _

/-- A return is unsupported exactly when at least one knockout reason fired. -/
theorem calculator_unsupported_iff (i : Calculator.CalculatorIn) :
    (Calculator.calculator i).unsupported = true ↔ (Calculator.calculator i).firedKnockouts ≠ [] := by
  exact UsTax.Proofs.calculator_unsupported_iff _

/-- The API answer: `supported = false` exactly when `reasons` is non-empty. -/
theorem apiCalculator_supported_iff (r : Api.Request) :
    KnockoutSound (ApiCalculator.apiCalculator r).supported (ApiCalculator.apiCalculator r).reasons := by
  exact UsTax.Proofs.apiCalculator_supported_iff _

/-- The API answer: `outcome = refund` exactly when line 34 is positive. -/
theorem apiCalculator_outcome_refund_iff (r : Api.Request) :
    RefundOutcome (ApiCalculator.apiCalculator r).outcome
      (ApiCalculator.apiCalculator r).lines.overpayment := by
  exact UsTax.Proofs.apiCalculator_outcome_refund_iff _

/-- The endpoint never answers 500 on a valid request. -/
theorem calculateRequest_ne_fault (r : Api.Request) (h : r.Valid) :
    Api.calculateRequest r h ≠ .fault := by
  exact UsTax.Proofs.calculateRequest_ne_fault r h

end UsTax.Extra

#audit_axioms UsTax.Extra.standardDeduction_eq_spec
#audit_axioms UsTax.Extra.additionalItems_range
#audit_axioms UsTax.Extra.requiresScheduleB_eq_spec
#audit_axioms UsTax.Extra.interestIncome_eq_spec
#audit_axioms UsTax.Extra.wages_eq_spec
#audit_axioms UsTax.Extra.formW2Withholding_eq_spec
#audit_axioms UsTax.Extra.medicareKnockout_eq_spec
#audit_axioms UsTax.Extra.oasdiKnockout_eq_spec
#audit_axioms UsTax.Extra.line6b_eq_spec
#audit_axioms UsTax.Extra.line6b_bounds
#audit_axioms UsTax.Extra.line6b_mono_otherIncome
#audit_axioms UsTax.Extra.educatorAdjustment_eq_spec
#audit_axioms UsTax.Extra.educatorAdjustment_bounds
#audit_axioms UsTax.Extra.studentLoanAdjustment_eq_spec
#audit_axioms UsTax.Extra.studentLoanAdjustment_bounds
#audit_axioms UsTax.Extra.studentLoanAdjustment_zero_of_magi_ge_end
#audit_axioms UsTax.Extra.studentLoanAdjustment_antitone
#audit_axioms UsTax.Extra.estimatedPayments_eq_spec
#audit_axioms UsTax.Extra.agi_eq
#audit_axioms UsTax.Extra.taxableIncome_eq
#audit_axioms UsTax.Extra.totalPayments_eq
#audit_axioms UsTax.Extra.totalPayments_eq_full
#audit_axioms UsTax.Extra.totalTax_mono_addW2
#audit_axioms UsTax.Extra.calculator_refund_balanceDue_consistent
#audit_axioms UsTax.Extra.calculator_credits_within_liability
#audit_axioms UsTax.Extra.calculator_totalTax_nonneg
#audit_axioms UsTax.Extra.calculator_credits_le_tax
#audit_axioms UsTax.Extra.calculator_unsupported_iff
#audit_axioms UsTax.Extra.apiCalculator_supported_iff
#audit_axioms UsTax.Extra.apiCalculator_outcome_refund_iff
#audit_axioms UsTax.Extra.calculateRequest_ne_fault
