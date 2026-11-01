import UsTax.Spec.SocialSecurity
import UsTax.SocialSecurity
import UsTax.Proofs.Rounding
import UsTax.Spec.Inputs
import UsTax.Audit

/-!
# Taxable Social Security meets IRC 86 (issue #64)

For **every** input of the Social Security Benefits Worksheet:

* `line6b_eq_spec`: line 6b as computed is `Spec.taxableSocialSecurity` (the
  86(a)(1)/(a)(2) tiers) of the net benefits and the modified AGI;
* `line6b_bounds`: `0 ≤ line 6b ≤ 85% of line 6a` (85% rounded to the
  dollar: $1 of benefits gives 85 cents, line 6b $1);
* `line6b_mono_otherIncome`: more other income never lowers line 6b.

Method: every percentage of a nonnegative amount is `(c * p + 50) / 100`
(`percentOf_of_nonneg`), so after splitting on the tier each goal is linear
and `omega` closes it.
-/

namespace UsTax.Proofs

open Spec (ssModifiedAgi)

open Money hiding min max
open SocialSecurity

/-- On a nonnegative amount, `percentOf` is a floor division (`omega` reads it). -/
theorem percentOf_of_nonneg {p c : Int} (hp : 0 ≤ p) (hc : 0 ≤ c) :
    Spec.percentOf p c = (c * p + 50) / 100 := by
  unfold Spec.percentOf Spec.roundHalfAway
  have := Int.mul_nonneg hc hp
  split <;> omega

/-- One-half, as the worksheet multiplies. -/
theorem mulRate_ssHalf (m : Int) : mulRate m ssHalf = Spec.percentOf 50 m := by
  rw [← mulRate_eq_percentOf]
  congr 1 <;> (unfold ssHalf; decide +kernel)

/-- 85%, as the worksheet multiplies. -/
theorem mulRate_ss85 (m : Int) : mulRate m ssEightyFivePercent = Spec.percentOf 85 m := by
  rw [← mulRate_eq_percentOf]
  congr 1 <;> (unfold ssEightyFivePercent; decide +kernel)

/-- The worksheet (lines 7 to 17) is the IRC 86 tiers, for nonnegative benefits. -/
theorem worksheet_eq_tiers (fs : FilingStatus) (apart : Bool) {b : Int} (hb : 0 ≤ b) (m : Int) :
    Min.min (wkshtLine16Of fs apart b (positive (Spec.percentOf 50 b + m))) (Spec.percentOf 85 b) =
      Spec.ssTaxableTiers fs apart b m := by
  rw [positive_eq]
  unfold wkshtLine16Of wkshtLine8Of wkshtLine10Of Spec.ssTaxableTiers Spec.ssBaseAmount
    Spec.ssAdjustedBaseAmount
  simp only [positive_eq, mulRate_ssHalf, mulRate_ss85, min_eq_min, Params.ssBaseAmountJoint,
    Params.ssBaseAmountOther, Params.ssAdjustedBaseGapJoint, Params.ssAdjustedBaseGapOther,
    TaxRates.usd]
  have h50 : 0 ≤ Spec.percentOf 50 b := by rw [percentOf_of_nonneg (by decide) hb]; omega
  generalize hP : Spec.percentOf 50 b + m = P
  have hm : m = P - Spec.percentOf 50 b := by omega
  subst hm
  cases fs <;> cases apart <;> simp only [beq_iff_eq, reduceCtorEq, Bool.and_true, Bool.and_false,
      Bool.not_true, Bool.not_false, beq_self_eq_true, Bool.false_eq_true, ↓reduceIte,
      Int.sub_add_cancel] <;>
    (repeat' split) <;>
    (try simp (disch := omega) only [percentOf_of_nonneg]) <;>
    omega

/-- **Line 6b is the IRC 86 amount**, for every input. -/
theorem line6b_eq_spec (i : SocialSecurityIn) :
    (socialSecurity i).line6b =
      Spec.taxableSocialSecurity i.filingStatus i.livedApartAllYear
        (Spec.roundToDollar i.reportNetBenefits.sum) (ssModifiedAgi i) := by
  have hsum : Money.sum i.reportNetBenefits = i.reportNetBenefits.sum := by
    have := sumBy_eq_sum id i.reportNetBenefits
    simpa [sumBy] using this
  simp only [socialSecurity, Spec.taxableSocialSecurity, hsum, roundDollar_eq_spec, mulRate_ss85,
    mulRate_ssHalf, min_eq_min]
  generalize Spec.roundToDollar i.reportNetBenefits.sum = b
  split
  · rfl
  · rename_i h
    rw [← worksheet_eq_tiers _ _ (by omega)]
    unfold ssModifiedAgi
    congr 4
    omega

/-- The tiers lie between `0` and 85% of the benefits. -/
theorem tiers_bounds (fs : FilingStatus) (apart : Bool) {b : Int} (hb : 0 ≤ b) (m : Int) :
    0 ≤ Spec.ssTaxableTiers fs apart b m ∧
      Spec.ssTaxableTiers fs apart b m ≤ Spec.percentOf 85 b := by
  have h50 : 0 ≤ Spec.percentOf 50 b := by rw [percentOf_of_nonneg (by decide) hb]; omega
  unfold Spec.ssTaxableTiers Spec.ssBaseAmount Spec.ssAdjustedBaseAmount
  generalize m + Spec.percentOf 50 b = P at *
  cases fs <;> cases apart <;> simp only [↓reduceIte, Bool.false_eq_true] <;>
    (repeat' split) <;>
    (try simp (disch := omega) only [percentOf_of_nonneg]) <;>
    omega

/-- The tiers never decrease when modified AGI grows. -/
theorem tiers_mono (fs : FilingStatus) (apart : Bool) {b : Int} (hb : 0 ≤ b) {m m' : Int}
    (h : m ≤ m') : Spec.ssTaxableTiers fs apart b m ≤ Spec.ssTaxableTiers fs apart b m' := by
  have h50 : 0 ≤ Spec.percentOf 50 b := by rw [percentOf_of_nonneg (by decide) hb]; omega
  unfold Spec.ssTaxableTiers Spec.ssBaseAmount Spec.ssAdjustedBaseAmount
  generalize hP : m + Spec.percentOf 50 b = P
  generalize hP' : m' + Spec.percentOf 50 b = P'
  have hPP : P ≤ P' := by omega
  clear hP hP'
  cases fs <;> cases apart <;> simp only [↓reduceIte, Bool.false_eq_true] <;>
    (repeat' split) <;>
    (try simp (disch := omega) only [percentOf_of_nonneg]) <;>
    omega

/-- **`0 ≤ line 6b ≤ 85% of line 6a`** (the 85% rounded to the dollar; `$0`
when net benefits are negative). -/
theorem line6b_bounds (i : SocialSecurityIn) :
    0 ≤ (socialSecurity i).line6b ∧
      (socialSecurity i).line6b ≤
        Spec.roundToDollar (Spec.percentOf 85 (max 0 (socialSecurity i).line6a)) := by
  have hsum : Money.sum i.reportNetBenefits = i.reportNetBenefits.sum := by
    have := sumBy_eq_sum id i.reportNetBenefits
    simpa [sumBy] using this
  have h6a : (socialSecurity i).line6a = Spec.roundToDollar i.reportNetBenefits.sum := by
    simp only [socialSecurity, hsum, roundDollar_eq_spec]
  rw [line6b_eq_spec, h6a]
  generalize Spec.roundToDollar i.reportNetBenefits.sum = b
  unfold Spec.taxableSocialSecurity
  have h0 : Spec.roundToDollar 0 = 0 := by decide
  split
  · rename_i h
    rw [show max 0 b = 0 by omega, show Spec.percentOf 85 0 = 0 by decide, h0]
    exact ⟨Int.le_refl 0, Int.le_refl 0⟩
  · rename_i h
    have hb := tiers_bounds i.filingStatus i.livedApartAllYear (b := b) (by omega) (ssModifiedAgi i)
    rw [show max 0 b = b by omega]
    exact ⟨h0 ▸ roundToDollar_mono hb.1, roundToDollar_mono hb.2⟩

/-- **More other income never lowers line 6b** (every other input fixed). -/
theorem line6b_mono_otherIncome (i : SocialSecurityIn) {x y : Int} (h : x ≤ y) :
    (socialSecurity { i with line8OtherIncome := x }).line6b ≤
      (socialSecurity { i with line8OtherIncome := y }).line6b := by
  rw [line6b_eq_spec, line6b_eq_spec]
  unfold Spec.taxableSocialSecurity
  dsimp only
  by_cases hb : Spec.roundToDollar i.reportNetBenefits.sum < 0
  · simp only [hb, ↓reduceIte]; exact Int.le_refl 0
  · simp only [hb, ↓reduceIte]
    apply roundToDollar_mono
    apply tiers_mono _ _ (by omega)
    unfold ssModifiedAgi; dsimp only; omega

/-! ## On concrete inputs -/

/-- Single, $24,000 of benefits, $30,000 of wages. -/
def ssSingle : SocialSecurityIn :=
  { reportNetBenefits := [24_000_00], filingStatus := .single, livedApartAllYear := false,
    line1z := 30_000_00, line2b := 0, line2a := 0, line3b := 0, line4b := 0, line5b := 0,
    line7CapitalGains := 0, line8OtherIncome := 0, adjustmentsExcludingStudentLoanInterest := 0 }

/-- Every hypothesis discharged: line 6b is $11,300, within $0 and $20,400. -/
example : (socialSecurity ssSingle).line6b = 11_300_00 := by
  rw [line6b_eq_spec]; decide

/-- Rejected: 85% of the benefits. -/
example : (socialSecurity ssSingle).line6b ≠ 20_400_00 := by
  rw [line6b_eq_spec]; decide

/-- The monotonicity hypothesis `x ≤ y` on a concrete pair ($0 and $5,000 of
other income). -/
example : (socialSecurity { ssSingle with line8OtherIncome := 0 }).line6b ≤
    (socialSecurity { ssSingle with line8OtherIncome := 5_000_00 }).line6b :=
  line6b_mono_otherIncome ssSingle (by decide)

end UsTax.Proofs

#audit_axioms UsTax.Proofs.line6b_eq_spec
#audit_axioms UsTax.Proofs.line6b_bounds
#audit_axioms UsTax.Proofs.line6b_mono_otherIncome
