import UsTax.Spec.Adjustments
import UsTax.EducatorAdjustment
import UsTax.StudentLoanAdjustment
import UsTax.Proofs.Rounding
import UsTax.Spec.Inputs
import UsTax.Audit

/-!
# Educator expenses and student loan interest meet IRC 62(a)(2)(D) and 221 (issue #64)

For **every** input:

* `educatorAdjustment_eq_spec`: line 11 is `Spec.educatorDeduction`;
  `educatorAdjustment_bounds`: between `$0` and `$300` per educator, for
  nonnegative expenses;
* `studentLoanAdjustment_eq_spec`: line 21 is `Spec.studentLoanDeduction`
  (the exact phase-out fraction, rounded once);
  `studentLoanAdjustment_bounds`: `0 ≤ line 21 ≤ min(interest rounded, $2,500)`
  for nonnegative interest;
  `studentLoanAdjustment_zero_of_magi_ge_end`: `$0` from MAGI $95,000
  ($195,000 joint);
  `studentLoanAdjustment_antitone`: more total income never raises line 21.
-/

namespace UsTax.Proofs

open Spec (tpIsEducator spouseIsEducator studentLoanEligible)

open Money hiding min max

/-! ## Educator expenses -/

section Educator
open EducatorAdjustment

/-- **Line 11 is the IRC 62(a)(2)(D) amount.** -/
theorem educatorAdjustment_eq_spec (i : EducatorAdjustmentIn) :
    (educatorAdjustment i).educatorExpensesAdjustment =
      Spec.educatorDeduction (tpIsEducator i.wasK12Educators) (spouseIsEducator i.wasK12Educators)
        i.primaryEducatorExpensesWritable i.secondaryEducatorExpensesWritable i.isMfjDependent := by
  simp only [educatorAdjustment, Spec.educatorDeduction, Spec.educatorShare, tpIsEducator,
    spouseIsEducator, roundDollar_eq_spec, min_eq_min, Params.educatorExpenseCapPerEducator,
    TaxRates.usd]
  cases i.wasK12Educators <;> rfl

/-- **`0 ≤ line 11 ≤ $300 × the number of educators`**, for nonnegative expenses. -/
theorem educatorAdjustment_bounds (i : EducatorAdjustmentIn)
    (hp : 0 ≤ i.primaryEducatorExpensesWritable) (hs : 0 ≤ i.secondaryEducatorExpensesWritable) :
    0 ≤ (educatorAdjustment i).educatorExpensesAdjustment ∧
      (educatorAdjustment i).educatorExpensesAdjustment ≤
        300_00 * ((if tpIsEducator i.wasK12Educators then 1 else 0) +
          (if spouseIsEducator i.wasK12Educators then 1 else 0)) := by
  rw [educatorAdjustment_eq_spec]
  unfold Spec.educatorDeduction Spec.educatorShare Spec.roundToDollar Spec.roundHalfAway
  generalize tpIsEducator i.wasK12Educators = a
  generalize spouseIsEducator i.wasK12Educators = b
  cases a <;> cases b <;> simp only [Bool.false_eq_true, ↓reduceIte] <;>
    (repeat' split) <;> omega

end Educator

/-! ## Student loan interest -/

section StudentLoan
open StudentLoanAdjustment

/-- `R.round_dollar_exact` of `c × (1 − min(1, e / R))` is the spec's integer
form, for `0 < R`. -/
theorem roundDollarExact_phaseOut (c e R : Int) (hR : 0 < R) :
    roundDollarExact c (1 - phaseOutRatio e R) =
      Spec.roundHalfAway (c * (R - Min.min e R)) (100 * R) * 100 := by
  have hRq : (0 : Rat) < (R : Rat) := by exact_mod_cast hR
  have hR0 : (R : Rat) ≠ 0 := by intro h; rw [h] at hRq; exact absurd hRq (by decide)
  unfold roundDollarExact phaseOutRatio divMoney
  rw [mulRate_intCast]
  dsimp only
  split
  · rename_i hlt
    have hlt' : e < R := by
      rw [Rat.div_lt_iff hRq, Rat.one_mul] at hlt; exact_mod_cast hlt
    rw [Int.min_eq_left (by omega)]
    have hq : ((c : Rat) / ((100 : Int) : Rat)) * (1 - (e : Rat) / (R : Rat)) =
        ((c * (R - e) : Int) : Rat) / ((100 * R : Int) : Rat) := by
      push_cast; grind
    rw [hq, roundRat_div _ _ (by omega),
      show 100 * R = 2 * (50 * R) by omega, roundDiv_eq_roundHalfAway]
    omega
  · rename_i hge
    have hge' : R ≤ e := by
      apply Int.not_lt.mp; intro h
      apply hge
      rw [Rat.div_lt_iff hRq, Rat.one_mul]; exact_mod_cast h
    rw [Int.min_eq_right hge', Int.sub_self, Int.mul_zero]
    rw [Rat.sub_self, Rat.mul_zero, roundRat_zero]
    unfold Spec.roundHalfAway
    simp only [Int.lt_irrefl, ↓reduceIte, Int.zero_add]
    rw [Int.ediv_eq_zero_of_lt (by omega) (by omega)]
    rfl

/-- **Line 21 is the IRC 221 amount.** -/
theorem studentLoanAdjustment_eq_spec (i : StudentLoanAdjustmentIn) :
    (studentLoanAdjustment i).studentLoanInterestAdjustmentAmount =
      Spec.studentLoanDeduction i.filingStatus (studentLoanEligible i) i.studentLoanInterestAmount
        (i.totalIncome - i.adjustmentsToIncomeExcludingStudentLoanInterest) := by
  obtain ⟨fs, had, q, c, mfjDep, claimed, ti, adj⟩ := i
  simp only [studentLoanAdjustment, Spec.studentLoanDeduction, studentLoanEligible,
    Spec.studentLoanPhaseoutRange, Spec.studentLoanPhaseoutStart, Params.studentLoanPhaseoutEndOther,
    Params.studentLoanPhaseoutEndJoint, Params.studentLoanPhaseoutStartOther,
    Params.studentLoanPhaseoutStartJoint, Params.studentLoanInterestCap, TaxRates.usd,
    min_eq_min, max_eq_max]
  generalize ti - adj = m
  cases fs <;> cases had <;> cases q <;> cases claimed <;> cases mfjDep <;>
    simp <;>
    first
    | (intro h1 h2; omega)
    | (split
       · rw [Int.min_eq_right (a := max 0 _) (by omega), Int.sub_self, Int.mul_zero]; decide
       · rw [roundDollarExact_phaseOut _ _ _ (by decide)]; rfl)

/-- The phase-out on the spec, for `0 ≤ capped`: the deduction is between `0`
and `capped` rounded, and does not increase with MAGI. -/
theorem phaseOut_facts (fs : FilingStatus) {c : Int} (hc : 0 ≤ c) (m m' : Int) (hm : m ≤ m') :
    let R := Spec.studentLoanPhaseoutRange fs
    let e := fun m => min (max 0 (m - Spec.studentLoanPhaseoutStart fs)) R
    0 ≤ Spec.roundHalfAway (c * (R - e m)) (100 * R) * 100 ∧
    Spec.roundHalfAway (c * (R - e m)) (100 * R) * 100 ≤ Spec.roundToDollar c ∧
    Spec.roundHalfAway (c * (R - e m')) (100 * R) * 100 ≤
      Spec.roundHalfAway (c * (R - e m)) (100 * R) * 100 := by
  intro R e
  have hR : R = 1_500_000 ∨ R = 3_000_000 := by
    simp only [R, Spec.studentLoanPhaseoutRange]; split <;> simp
  have he : 0 ≤ e m ∧ e m ≤ R ∧ e m ≤ e m' ∧ e m' ≤ R := by
    simp only [e]; omega
  have h1 : 0 ≤ c * (R - e m) := Int.mul_nonneg hc (by omega)
  have h2 : c * (R - e m) ≤ c * R := Int.mul_le_mul_of_nonneg_left (by omega) hc
  have h3 : c * (R - e m') ≤ c * (R - e m) := Int.mul_le_mul_of_nonneg_left (by omega) hc
  have h4 : 0 ≤ c * (R - e m') := Int.mul_nonneg hc (by omega)
  generalize c * (R - e m) = p at *
  generalize c * (R - e m') = p' at *
  unfold Spec.roundToDollar Spec.roundHalfAway
  rcases hR with hR | hR <;> rw [hR] at h2 ⊢ <;> simp only [Int.reduceMul, Int.reduceDiv] <;>
    (repeat' split) <;> omega

/-- **`0 ≤ line 21 ≤ min(interest, $2,500)`** (interest rounded to the dollar),
for nonnegative interest. -/
theorem studentLoanAdjustment_bounds (i : StudentLoanAdjustmentIn)
    (h : 0 ≤ i.studentLoanInterestAmount) :
    0 ≤ (studentLoanAdjustment i).studentLoanInterestAdjustmentAmount ∧
      (studentLoanAdjustment i).studentLoanInterestAdjustmentAmount ≤
        min (Spec.roundToDollar i.studentLoanInterestAmount) 2_500_00 := by
  rw [studentLoanAdjustment_eq_spec]
  unfold Spec.studentLoanDeduction
  have hr0 := roundToDollar_mono h
  have h00 : Spec.roundToDollar 0 = 0 := by decide
  have hcap : Spec.roundToDollar (min i.studentLoanInterestAmount 2_500_00) =
      min (Spec.roundToDollar i.studentLoanInterestAmount) 2_500_00 := by
    unfold Spec.roundToDollar Spec.roundHalfAway; (repeat' split) <;> omega
  split
  · omega
  · have := phaseOut_facts i.filingStatus (c := min i.studentLoanInterestAmount 2_500_00) (by omega)
      (i.totalIncome - i.adjustmentsToIncomeExcludingStudentLoanInterest) _ (Int.le_refl _)
    dsimp only at this ⊢
    omega

/-- **Line 21 is `$0` from the end of the phase-out** ($95,000 of MAGI, $195,000
joint). -/
theorem studentLoanAdjustment_zero_of_magi_ge_end (i : StudentLoanAdjustmentIn)
    (h : Spec.studentLoanPhaseoutStart i.filingStatus + Spec.studentLoanPhaseoutRange i.filingStatus ≤
      i.totalIncome - i.adjustmentsToIncomeExcludingStudentLoanInterest) :
    (studentLoanAdjustment i).studentLoanInterestAdjustmentAmount = 0 := by
  rw [studentLoanAdjustment_eq_spec]
  unfold Spec.studentLoanDeduction
  split
  · rfl
  · dsimp only
    have hR : 0 < Spec.studentLoanPhaseoutRange i.filingStatus := by
      unfold Spec.studentLoanPhaseoutRange; split <;> decide
    rw [Int.min_eq_right (a := max 0 _) (by omega), Int.sub_self, Int.mul_zero]
    unfold Spec.roundHalfAway
    simp only [Int.lt_irrefl, ↓reduceIte, Int.zero_add]
    rw [Int.ediv_eq_zero_of_lt (by omega) (by omega)]
    rfl

/-- **More total income never raises line 21** (every other input fixed,
nonnegative interest). -/
theorem studentLoanAdjustment_antitone (i : StudentLoanAdjustmentIn)
    (hi : 0 ≤ i.studentLoanInterestAmount) {x y : Int} (h : x ≤ y) :
    (studentLoanAdjustment { i with totalIncome := y }).studentLoanInterestAdjustmentAmount ≤
      (studentLoanAdjustment { i with totalIncome := x }).studentLoanInterestAdjustmentAmount := by
  rw [studentLoanAdjustment_eq_spec, studentLoanAdjustment_eq_spec]
  unfold Spec.studentLoanDeduction
  dsimp only
  split
  · rename_i hz
    rw [ite_eq_left_of_eq_true _ _ (eq_true (by simpa [studentLoanEligible] using hz))]
    exact Int.le_refl 0
  · rename_i hz
    rw [ite_eq_right_of_eq_false _ _ (eq_false (by simpa [studentLoanEligible] using hz))]
    exact (phaseOut_facts i.filingStatus (by omega) _ _ (by omega)).2.2

/-! ## On concrete inputs -/

/-- Single, $3,000 of qualifying interest, $85,000 of MAGI. -/
def slSingle85k : StudentLoanAdjustmentIn :=
  { filingStatus := .single, hadStudentLoanInterestPayments := true, studentLoansQualify := true,
    studentLoanInterestAmount := 3_000_00, isMfjDependent := false,
    eitherFilerIsClaimedAsDependent := false, totalIncome := 85_000_00,
    adjustmentsToIncomeExcludingStudentLoanInterest := 0 }

/-- Every hypothesis discharged: line 21 is $1,667, within `0` and $2,500,
and at $95,000 it is `$0`. -/
example : (studentLoanAdjustment slSingle85k).studentLoanInterestAdjustmentAmount = 1_667_00 ∧
    (studentLoanAdjustment { slSingle85k with totalIncome := 95_000_00 }).studentLoanInterestAdjustmentAmount = 0 :=
  ⟨by rw [studentLoanAdjustment_eq_spec]; decide,
   studentLoanAdjustment_zero_of_magi_ge_end _ (by decide)⟩

/-- The antitone hypotheses on a concrete pair ($85,000 and $90,000). -/
example : (studentLoanAdjustment { slSingle85k with totalIncome := 90_000_00 }).studentLoanInterestAdjustmentAmount ≤
    (studentLoanAdjustment { slSingle85k with totalIncome := 85_000_00 }).studentLoanInterestAdjustmentAmount :=
  studentLoanAdjustment_antitone slSingle85k (by decide) (by decide)

/-- Rejected: Direct File's $1,668 (three-decimal ratio). -/
example : (studentLoanAdjustment slSingle85k).studentLoanInterestAdjustmentAmount ≠ 1_668_00 := by
  rw [studentLoanAdjustment_eq_spec]; decide

end StudentLoan

/-! ## Educator expenses on concrete inputs -/

/-- One educator (the taxpayer) with $450 of expenses: every hypothesis
discharged, line 11 is $300. -/
example : (EducatorAdjustment.educatorAdjustment
      { wasK12Educators := .tpDid, primaryEducatorExpensesWritable := 450_00 }).educatorExpensesAdjustment
    = 300_00 := by
  rw [educatorAdjustment_eq_spec]; decide

/-- The bound with its hypotheses discharged, and a rejected $450. -/
example : (EducatorAdjustment.educatorAdjustment
      { wasK12Educators := .tpDid, primaryEducatorExpensesWritable := 450_00 }).educatorExpensesAdjustment
    ≤ 300_00 ∧
    (EducatorAdjustment.educatorAdjustment
      { wasK12Educators := .tpDid, primaryEducatorExpensesWritable := 450_00 }).educatorExpensesAdjustment
    ≠ 450_00 := by
  refine ⟨(educatorAdjustment_bounds _ (by decide) (by decide)).2, ?_⟩
  rw [educatorAdjustment_eq_spec]; decide

end UsTax.Proofs

#audit_axioms UsTax.Proofs.educatorAdjustment_eq_spec
#audit_axioms UsTax.Proofs.educatorAdjustment_bounds
#audit_axioms UsTax.Proofs.studentLoanAdjustment_eq_spec
#audit_axioms UsTax.Proofs.studentLoanAdjustment_bounds
#audit_axioms UsTax.Proofs.studentLoanAdjustment_zero_of_magi_ge_end
#audit_axioms UsTax.Proofs.studentLoanAdjustment_antitone
