import UsTax.Unemployment
import UsTax.Form1099Misc
import UsTax.SocialSecurity
import UsTax.EducatorAdjustment
import UsTax.StudentLoanAdjustment
import UsTax.EstimatedPayments
import UsTax.Form1040Full
import UsTax.Form1040.Lemmas
import UsTax.Money.Lemmas
import UsTax.Audit

/-!
# Nonnegativity and caps of the income and adjustment modules (issue #45)

Cheap structural facts about the code that runs, each property-tested first in
`UsTax/Income/Props.lean`:

* `unemploymentCompensation_nonneg`: line 7 is never negative, for every list of
  Forms 1099-G (the in-year repayment is capped at box 1);
* `alaskaPfdIncome_nonneg`: line 8g, for nonnegative box 3 amounts;
* `educatorAdjustment_nonneg`, `educatorAdjustment_le_600`: line 11 is between `$0`
  and `$600` (the IRC 62(a)(2)(D) cap of $300 per educator);
* `studentLoanAdjustment_nonneg`: line 21 is never negative for nonnegative interest;
* `line6b_nonneg`: taxable Social Security (line 6b) is never negative;
* `estimatedAndFromLastYear_nonneg`: line 26, for a nonnegative payment;
* `form1040Full_refund_or_owe_zero`: with the modules plugged in, line 34 or line 37
  is still `$0`.

Their hypotheses are satisfiable; the `#guard`s at the end instantiate them.
-/

namespace UsTax.Income

open Money

/-- The phase-out ratio is at most 1. -/
theorem phaseOutRatio_le_one (excess range : Int) :
    StudentLoanAdjustment.phaseOutRatio excess range ≤ 1 := by
  unfold StudentLoanAdjustment.phaseOutRatio
  dsimp only
  split
  · exact Rat.le_of_lt ‹_›
  · exact Rat.le_refl

/-! ### Unemployment (Schedule 1 line 7) -/

/-- Each 1099-G's net unemployment is nonnegative: the repayment is capped at box 1. -/
theorem netUnemploymentComp_nonneg (f : Unemployment.Form1099G) :
    0 ≤ (Unemployment.form1099GFacts f).netUnemploymentComp := by
  unfold Unemployment.form1099GFacts
  have := min_le_right f.writableAmountPaidBackForBenefitsInTaxYear f.amount
  dsimp only
  omega

/-- Line 7 is never negative, whatever the forms. -/
theorem unemploymentCompensation_nonneg (i : Unemployment.UnemploymentIn) :
    0 ≤ (Unemployment.unemployment i).unemploymentCompensation := by
  unfold Unemployment.unemployment
  dsimp only
  apply roundDollar_nonneg
  apply sumBy_nonneg
  intro x hx
  obtain ⟨f, _, rfl⟩ := List.mem_map.mp hx
  exact netUnemploymentComp_nonneg f

/-! ### Alaska PFD (Schedule 1 line 8g) -/

/-- Line 8g is nonnegative when every box 3 is. -/
theorem alaskaPfdIncome_nonneg (i : Form1099Misc.Form1099MiscsIn)
    (h : ∀ f ∈ i.form1099Miscs, 0 ≤ f.writableOtherIncome) :
    0 ≤ (Form1099Misc.form1099Miscs i).alaskaPfdIncome := by
  unfold Form1099Misc.form1099Miscs
  dsimp only
  apply roundDollar_nonneg
  apply sumBy_nonneg
  intro x hx
  exact h x (List.mem_filter.mp hx).1

/-! ### Educator expenses (Schedule 1 line 11) -/

/-- Line 11 is nonnegative when the expenses are. -/
theorem educatorAdjustment_nonneg (i : EducatorAdjustment.EducatorAdjustmentIn)
    (hp : 0 ≤ i.primaryEducatorExpensesWritable) (hs : 0 ≤ i.secondaryEducatorExpensesWritable) :
    0 ≤ (EducatorAdjustment.educatorAdjustment i).educatorExpensesAdjustment := by
  unfold EducatorAdjustment.educatorAdjustment
  dsimp only
  have h1 : 0 ≤ Money.min Params.educatorExpenseCapPerEducator i.primaryEducatorExpensesWritable :=
    le_min (by decide) hp
  have h2 : 0 ≤ Money.min Params.educatorExpenseCapPerEducator i.secondaryEducatorExpensesWritable :=
    le_min (by decide) hs
  split
  · exact Int.le_refl 0
  · apply roundDollar_nonneg
    split <;> split <;> omega

/-- Line 11 is at most $600: $300 for each of two educators. -/
theorem educatorAdjustment_le_600 (i : EducatorAdjustment.EducatorAdjustmentIn) :
    (EducatorAdjustment.educatorAdjustment i).educatorExpensesAdjustment ≤ 60_000 := by
  unfold EducatorAdjustment.educatorAdjustment
  dsimp only
  have h1 := min_le_left Params.educatorExpenseCapPerEducator i.primaryEducatorExpensesWritable
  have h2 := min_le_left Params.educatorExpenseCapPerEducator i.secondaryEducatorExpensesWritable
  have hc : Params.educatorExpenseCapPerEducator = 30_000 := by decide
  rw [hc] at h1 h2 ⊢
  split
  · decide
  · have hm := roundDollar_mono (m := (if i.wasK12Educators == .bothDid || i.wasK12Educators == .tpDid then
        Money.min 30_000 i.primaryEducatorExpensesWritable else 0) +
      (if i.wasK12Educators == .bothDid || i.wasK12Educators == .spouseDid then
        Money.min 30_000 i.secondaryEducatorExpensesWritable else 0)) (n := 60_000)
      (by split <;> split <;> omega)
    have h600 : roundDollar 60_000 = 60_000 := roundDollar_mul_100 600
    omega

/-! ### Student loan interest (Schedule 1 line 21) -/

/-- `R.round_dollar_exact` of a nonnegative amount and rate is nonnegative. -/
theorem roundDollarExact_nonneg {m : Int} {r : Rat} (hm : 0 ≤ m) (hr : 0 ≤ r) :
    0 ≤ roundDollarExact m r := by
  unfold roundDollarExact
  rw [mulRate_intCast]
  have h100 : (0 : Rat) ≤ ((100 : Int) : Rat)⁻¹ := by
    rw [Rat.inv_def]
    exact Rat.divInt_nonneg (Int.natCast_nonneg _) (Rat.num_nonneg.mpr (Rat.intCast_nonneg.mpr (by decide)))
  have hq : (0 : Rat) ≤ divMoney m 100 * r :=
    Rat.mul_nonneg (Rat.mul_nonneg (Rat.intCast_nonneg.mpr hm) h100) hr
  have := roundRat_mono hq
  rw [roundRat_zero] at this
  omega

/-- Line 21 is never negative for nonnegative interest. -/
theorem studentLoanAdjustment_nonneg (i : StudentLoanAdjustment.StudentLoanAdjustmentIn)
    (h : 0 ≤ i.studentLoanInterestAmount) :
    0 ≤ (StudentLoanAdjustment.studentLoanAdjustment i).studentLoanInterestAdjustmentAmount := by
  unfold StudentLoanAdjustment.studentLoanAdjustment
  dsimp only
  split
  · exact Int.le_refl 0
  · apply roundDollarExact_nonneg
    · exact le_min h (by decide)
    · exact (Rat.le_iff_sub_nonneg _ _).mp (phaseOutRatio_le_one _ _)

/-! ### Social Security (Form 1040 line 6b) -/

/-- Worksheet line 16 is nonnegative for nonnegative benefits and line 7. -/
theorem wkshtLine16Of_nonneg (fs : FilingStatus) (lived : Bool) (l6a l7 : Int)
    (h6a : 0 ≤ l6a) (h7 : 0 ≤ l7) : 0 ≤ SocialSecurity.wkshtLine16Of fs lived l6a l7 := by
  have h85 : (0 : Rat) ≤ SocialSecurity.ssEightyFivePercent := by
    unfold SocialSecurity.ssEightyFivePercent; decide +kernel
  have hhalf : (0 : Rat) ≤ SocialSecurity.ssHalf := by
    unfold SocialSecurity.ssHalf; decide +kernel
  have h8 : 0 ≤ SocialSecurity.wkshtLine8Of fs := by
    unfold SocialSecurity.wkshtLine8Of; split <;> decide
  have h10 : 0 ≤ SocialSecurity.wkshtLine10Of fs := by
    unfold SocialSecurity.wkshtLine10Of; split <;> decide
  unfold SocialSecurity.wkshtLine16Of
  dsimp only
  split
  · exact mulRate_nonneg h7 h85
  · split
    · exact Int.le_refl 0
    · rename_i hlt
      have h9 : 0 ≤ l7 - SocialSecurity.wkshtLine8Of fs := by omega
      apply Int.add_nonneg
      · exact mulRate_nonneg (positive_nonneg _) h85
      · apply le_min
        · exact mulRate_nonneg h6a hhalf
        · exact mulRate_nonneg (le_min h9 h10) hhalf

/-- Worksheet line 7 is `Money.positive` of something, so nonnegative. -/
theorem wkshtLine7_nonneg (i : SocialSecurity.SocialSecurityIn) :
    0 ≤ (SocialSecurity.socialSecurity i).wkshtLine7 := positive_nonneg _

/-- Line 6b is never negative. -/
theorem line6b_nonneg (i : SocialSecurity.SocialSecurityIn) :
    0 ≤ (SocialSecurity.socialSecurity i).line6b := by
  have h85 : (0 : Rat) ≤ SocialSecurity.ssEightyFivePercent := by
    unfold SocialSecurity.ssEightyFivePercent; decide +kernel
  have h7 := wkshtLine7_nonneg i
  unfold SocialSecurity.socialSecurity at h7 ⊢
  dsimp only at h7 ⊢
  split
  · exact Int.le_refl 0
  · rename_i hneg
    apply roundDollar_nonneg
    apply le_min
    · exact wkshtLine16Of_nonneg _ _ _ _ (by omega) h7
    · exact mulRate_nonneg (by omega) h85

/-! ### Estimated payments (Form 1040 line 26) -/

/-- Line 26 is nonnegative for a nonnegative payment. -/
theorem estimatedAndFromLastYear_nonneg (i : EstimatedPayments.EstimatedPaymentsIn)
    (h : 0 ≤ i.estimatedTaxPaymentWritable) :
    0 ≤ (EstimatedPayments.estimatedPayments i).estimatedAndFromLastYear := by
  unfold EstimatedPayments.estimatedPayments
  dsimp only
  apply roundDollar_nonneg
  split <;> omega

/-! ### The composition -/

/-- With the modules plugged in, line 34 or line 37 is still `$0`. -/
theorem form1040Full_refund_or_owe_zero (i : Form1040Full.Form1040FullIn) :
    (Form1040Full.form1040Full i).form1040.overpayment = 0 ∨
      (Form1040Full.form1040Full i).form1040.balanceDue = 0 :=
  Form1040.overpayment_eq_zero_or_balanceDue_eq_zero _

/-! ### Hypotheses are satisfiable, bad outputs are rejected -/

#guard (EducatorAdjustment.educatorAdjustment
  { wasK12Educators := .bothDid, primaryEducatorExpensesWritable := 45_000,
    secondaryEducatorExpensesWritable := 45_000 }).educatorExpensesAdjustment == 60_000
#guard (StudentLoanAdjustment.studentLoanAdjustment
  { filingStatus := .single, hadStudentLoanInterestPayments := true, studentLoansQualify := true,
    studentLoanInterestAmount := 300_000, isMfjDependent := false,
    eitherFilerIsClaimedAsDependent := false, totalIncome := 7_000_000,
    adjustmentsToIncomeExcludingStudentLoanInterest := 0 }).studentLoanInterestAdjustmentAmount == 250_000
#guard (SocialSecurity.socialSecurity
  { reportNetBenefits := [2_400_000], filingStatus := .single, livedApartAllYear := false,
    line1z := 0, line2b := 0, line2a := 0, line3b := 0, line4b := 0, line5b := 0,
    line7CapitalGains := 0, line8OtherIncome := 3_000_000,
    adjustmentsExcludingStudentLoanInterest := 0 }).line6b == 1_130_000

/-- A rejected bad output: a negative line 7. -/
example : ¬ ((Unemployment.unemployment
    { form1099Gs := [{ amount := 200_000, writableAmountPaidBackForBenefitsInTaxYear := 250_000 }] }
    ).unemploymentCompensation < 0) :=
  Int.not_lt.mpr (unemploymentCompensation_nonneg _)

end UsTax.Income

#audit_axioms UsTax.Income.unemploymentCompensation_nonneg
#audit_axioms UsTax.Income.alaskaPfdIncome_nonneg
#audit_axioms UsTax.Income.educatorAdjustment_nonneg
#audit_axioms UsTax.Income.educatorAdjustment_le_600
#audit_axioms UsTax.Income.studentLoanAdjustment_nonneg
#audit_axioms UsTax.Income.line6b_nonneg
#audit_axioms UsTax.Income.estimatedAndFromLastYear_nonneg
#audit_axioms UsTax.Income.form1040Full_refund_or_owe_zero
