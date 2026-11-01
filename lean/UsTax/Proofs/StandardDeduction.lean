import UsTax.Spec.StandardDeduction
import UsTax.StandardDeduction
import UsTax.Money.Lemmas
import UsTax.Audit

/-!
# The standard deduction meets IRC 63(c) (issue #64)

For **every** input, line 12 as computed (`standardDeduction`) equals
`Spec.standardDeductionSpec` of the filing status, the item count, the
dependent flag and the earned income (line 1z). The item count is between 0
and 4, and at most 2 when no spouse can count.
-/

namespace UsTax.Proofs

open Money StandardDeduction

/-- Line 12 is the IRC 63(c) amount. -/
theorem standardDeduction_eq_spec (i : StandardDeductionIn) :
    (standardDeduction i).standardDeduction =
      Spec.standardDeductionSpec i.filingStatus (standardDeduction i).additionalStandardDeductionItems
        i.treatFilersAsDependents i.employerIncomeSubtotal := by
  simp only [standardDeduction, standardDeductionAmount, minimumStandardDeduction,
    normalStandardDeduction, additionalStandardDeduction, mulInt_eq, Spec.standardDeductionSpec]
  generalize additionalStandardDeductionItems i = n
  cases h : i.filingStatus <;> cases i.treatFilersAsDependents <;>
    simp only [filingStatusStandardDeduction, additionalStandardDeductionMultiplier,
      Spec.basicStandardDeduction, Spec.additionalAmountPerItem, Params.stdDeductionUnmarried,
      Params.stdDeductionJointOrSurvivingSpouse, Params.stdDeductionHeadOfHousehold,
      Params.stdDeductionMarriedSeparate, Params.stdDeductionAdditionalMarried,
      Params.stdDeductionAdditionalUnmarried, Params.stdDeductionDependentFloor,
      Params.stdDeductionDependentEarnedIncomeAddition, TaxRates.usd, Money.min, Money.max,
      Bool.false_eq_true, ↓reduceIte] <;>
    (repeat' split) <;> omega

/-- The item count (65 or older, blind; filer and spouse) is between 0 and 4,
and at most 2 unless the return is joint or treated as separate with a spouse
who counts. -/
theorem additionalItems_range (i : StandardDeductionIn) :
    0 ≤ (standardDeduction i).additionalStandardDeductionItems ∧
      (standardDeduction i).additionalStandardDeductionItems ≤ 4 ∧
      (i.filingStatus ≠ .marriedFilingJointly → i.treatAsMfs = false →
        (standardDeduction i).additionalStandardDeductionItems ≤ 2) := by
  simp only [standardDeduction, additionalStandardDeductionItems,
    secondaryFilerAdditionalStandardDeductionItems, isSpouseInfoApplicableForStandardDeductions,
    filerMfsAndSpouseIsEligibleForStandardDeductions, bit]
  refine ⟨?_, ?_, fun hfs hmfs => ?_⟩
  · repeat' split
    all_goals omega
  · repeat' split
    all_goals omega
  · have : (i.filingStatus == .marriedFilingJointly) = false := by
      cases h : i.filingStatus <;> simp_all
    simp only [this, hmfs, Bool.false_and, Bool.or_self, Bool.false_eq_true, ↓reduceIte]
    repeat' split
    all_goals omega

/-! ## On concrete inputs -/

/-- A single filer who can be claimed as a dependent, 65 or older, with
$5,000 of wages. -/
def sdDependent65 : StandardDeductionIn :=
  { filingStatus := .single, treatAsMfs := false, primaryFilerIsBlind := false,
    primaryFilerAge65OrOlder := true, secondaryFilerIsBlind := false,
    secondaryFilerAge65OrOlder := false, isWidowedInTaxYear := false,
    mfjDeceasedSpouseReachedAge65 := false, mfsSpouse65OrOlder := false,
    mfsSpouseProvidesNoBenefits := false, treatFilersAsDependents := true,
    employerIncomeSubtotal := 5_000_00 }

/-- Every hypothesis discharged: line 12 is $5,450 + $1,950 = $7,400, and the
item count is 1, within its range. -/
example : (standardDeduction sdDependent65).standardDeduction = 7_400_00 ∧
    (standardDeduction sdDependent65).additionalStandardDeductionItems ≤ 2 := by
  refine ⟨?_, (additionalItems_range sdDependent65).2.2 (by decide) rfl⟩
  rw [standardDeduction_eq_spec]; decide

/-- Rejected: $14,600 (the dependent limitation ignored). -/
example : (standardDeduction sdDependent65).standardDeduction ≠ 14_600_00 := by
  rw [standardDeduction_eq_spec]; decide

end UsTax.Proofs

#audit_axioms UsTax.Proofs.standardDeduction_eq_spec
#audit_axioms UsTax.Proofs.additionalItems_range
#spec_surface UsTax.Proofs.standardDeduction_eq_spec
