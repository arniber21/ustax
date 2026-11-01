import UsTax.Eitc.Case
import UsTax.Money.Lemmas
import UsTax.Audit

/-!
# The EITC is within its bounds (issues #46, #67)

Proof, for the Lean implementation of `EitcTable` (`UsTax/Eitc.lean`), of the property
`EitcWithinBounds` of `UsTax/Spec/Eitc.lean` (read, not changed): the credit is between $0
and the maximum credit of the column, and is $0 once the larger of earned income and AGI
reaches the completed phase-out amount. The statement used by `lake comparator` is
`UsTax.Main.eitc_within_bounds` (`UsTax/Comparator/Challenge.lean`, proved in
`UsTax/Proofs/Main.lean` from `eitc_within_bounds` here).

Proof idea, in the order of the file.

1. `dollars` is monotone; the phase-out reduction is nonnegative when the cap on the income
   used is at least the threshold (`phaseoutReduction_nonneg`; the cap is checked on the
   eight columns by `decide +kernel`).
2. So the maximum-minus-reduction figure is at most the maximum credit in dollars, the
   smaller of it and the other figure is too, and rounding (monotone, fixing whole dollars)
   keeps that: `amount ≤ maxCredit`. The floor `Money.max 0` gives `0 ≤ amount`.
3. The `no_credit` rule (DF-BUG(17)) fires when earned income or AGI is at or above the
   completed phase-out amount, so the credit is $0 there.
4. For every input the code's maximum credit and completed phase-out amount are
   the spec's (`Spec.eitcMaxCredit`, `Spec.eitcCompletedPhaseout`).

A negative child count is not a return; the code gives it the "3 or more" column, and
`caseOf` (`UsTax/Eitc/Case.lean`) reads it as 3, so the theorem needs no hypothesis.
-/

namespace UsTax.Proofs

open UsTax.Eitc UsTax.Money

/-- `dollars` is monotone. -/
theorem dollars_mono {a b : Int} (h : a ≤ b) : dollars a ≤ dollars b := by
  unfold dollars divMoney
  rw [Rat.div_def, Rat.div_def]
  exact Rat.mul_le_mul_of_nonneg_right (Rat.intCast_le_intCast.mpr h) (by decide +kernel)

/-- Rounding the dollars of an amount in cents is `roundDiv`. -/
theorem roundRat_dollars (m : Int) : roundRat (dollars m) = roundDiv m 100 := by
  unfold dollars divMoney
  exact roundRat_div m 100 (by decide)

theorem rat_sub_le_self (x y : Rat) (h : 0 ≤ y) : x - y ≤ x := by
  apply Rat.sub_right_le_iff_le_add.mpr
  have := (Rat.add_le_add_left (c := x) (a := 0) (b := y)).mpr h
  rwa [Rat.add_zero] at this

/-- The phase-out reduction is nonnegative, if the cap on the income used (the middle of the
last row) is at least the threshold. -/
theorem phaseoutReduction_nonneg (roundedIncome threshold completed : Int) (percentage : Rat)
    (hp : 0 ≤ percentage)
    (hcap : dollars threshold ≤
      (dollars (stepwiseMultiply completed Params.eitcTableRowWidth Params.eitcTableRowWidth) +
        dollars completed) / 2) :
    0 ≤ phaseoutReduction roundedIncome threshold completed percentage := by
  unfold phaseoutReduction
  dsimp only
  split
  · exact Rat.le_refl
  · rename_i h
    have h1 : threshold ≤ roundedIncome := by
      have : Params.eitcTableRowMidpoint = 2500 := rfl
      omega
    apply Rat.mul_nonneg hp
    rw [← Rat.le_iff_sub_nonneg]
    split
    · exact dollars_mono h1
    · exact hcap

/-- All eight columns have a cap at least the threshold. -/
theorem column_cap (i : EitcTableIn) :
    dollars (eitcTable i).phaseoutThreshold ≤
      (dollars (stepwiseMultiply (eitcTable i).completedPhaseout Params.eitcTableRowWidth
          Params.eitcTableRowWidth) + dollars (eitcTable i).completedPhaseout) / 2 := by
  unfold eitcTable
  dsimp only
  split <;> split <;> (try split) <;> (try split) <;> decide +kernel

/-- The phase-out rates are nonnegative. -/
theorem phaseoutRate_nonneg (i : EitcTableIn) : 0 ≤ (eitcTable i).phaseoutRate := by
  unfold eitcTable
  dsimp only
  split <;> (try split) <;> decide +kernel

/-- The maximum credit is a nonnegative whole number of dollars. -/
theorem maxCredit_whole (i : EitcTableIn) :
    0 ≤ (eitcTable i).maxCredit ∧ (eitcTable i).maxCredit % 100 = 0 := by
  unfold eitcTable
  dsimp only
  split <;> (try split) <;> (try split) <;> decide +kernel

/-- The `amount` rule, as the code states it. -/
theorem eitcTable_amount_eq (i : EitcTableIn) :
    (eitcTable i).amount = if (eitcTable i).noCredit then 0 else Money.max 0
      (100 * roundRat (if (eitcTable i).maxEitcFromAgi < (eitcTable i).creditFromEarnedIncome
        then (eitcTable i).maxEitcFromAgi else (eitcTable i).creditFromEarnedIncome)) := rfl

/-- `0 ≤ amount`. -/
theorem eitcTable_amount_nonneg (i : EitcTableIn) : 0 ≤ (eitcTable i).amount := by
  rw [eitcTable_amount_eq]
  split
  · exact Int.le_refl 0
  · unfold Money.max; split <;> omega

/-- `amount ≤ maxCredit`. -/
theorem eitcTable_amount_le_maxCredit (i : EitcTableIn) :
    (eitcTable i).amount ≤ (eitcTable i).maxCredit := by
  obtain ⟨hmc0, hmc100⟩ := maxCredit_whole i
  have hcap := column_cap i
  have hrate := phaseoutRate_nonneg i
  generalize hT : eitcTable i = T at *
  have hT' : T = eitcTable i := hT.symm
  -- the reduction applied to the AGI is nonnegative
  have hred : 0 ≤ phaseoutReduction T.roundedAgi T.phaseoutThreshold T.completedPhaseout T.phaseoutRate :=
    phaseoutReduction_nonneg _ _ _ _ hrate hcap
  have hA : T.maxEitcFromAgi ≤ dollars T.maxCredit := by
    have : T.maxEitcFromAgi = dollars T.maxCredit -
        phaseoutReduction T.roundedAgi T.phaseoutThreshold T.completedPhaseout T.phaseoutRate := by
      rw [hT']; rfl
    rw [this]; exact rat_sub_le_self _ _ hred
  have hmin : (if T.maxEitcFromAgi < T.creditFromEarnedIncome then T.maxEitcFromAgi
      else T.creditFromEarnedIncome) ≤ dollars T.maxCredit := by
    split
    · exact hA
    · rename_i h
      exact Rat.le_trans (Rat.not_lt.mp h) hA
  have hR : roundRat (if T.maxEitcFromAgi < T.creditFromEarnedIncome then T.maxEitcFromAgi
      else T.creditFromEarnedIncome) ≤ roundDiv T.maxCredit 100 := by
    rw [← roundRat_dollars]; exact roundRat_mono hmin
  have hamount : T.amount = if T.noCredit then 0 else Money.max 0
      (100 * roundRat (if T.maxEitcFromAgi < T.creditFromEarnedIncome then T.maxEitcFromAgi
                       else T.creditFromEarnedIncome)) := by
    rw [hT']; rfl
  rw [hamount]
  generalize roundRat (if T.maxEitcFromAgi < T.creditFromEarnedIncome then T.maxEitcFromAgi
      else T.creditFromEarnedIncome) = R at hR ⊢
  unfold roundDiv at hR
  split
  · exact hmc0
  · unfold Money.max; split <;> split at hR <;> omega

/-- The maximum credit is the spec's. -/
theorem eitcTable_maxCredit (i : EitcTableIn) :
    (eitcTable i).maxCredit = Spec.eitcMaxCredit (caseOf i).qualifyingChildren := by
  unfold eitcTable caseOf
  dsimp only
  by_cases h0 : i.qualifyingChildren = 0
  · simp [h0, Spec.eitcMaxCredit, Params.eitcMaxCredit0Children, TaxRates.usd]
  by_cases h1 : i.qualifyingChildren = 1
  · simp [h1, Spec.eitcMaxCredit, Params.eitcMaxCredit1Child, TaxRates.usd]
  by_cases h2 : i.qualifyingChildren = 2
  · simp [h2, Spec.eitcMaxCredit, Params.eitcMaxCredit2Children, TaxRates.usd]
  obtain ⟨m, hm⟩ : ∃ m : Nat, (if i.qualifyingChildren < 0 then 3 else i.qualifyingChildren.toNat) = m + 3 :=
    ⟨(if i.qualifyingChildren < 0 then 3 else i.qualifyingChildren.toNat) - 3, by split <;> omega⟩
  simp [h0, h1, h2, hm, Spec.eitcMaxCredit, Params.eitcMaxCredit3OrMoreChildren, TaxRates.usd]

/-- The completed phase-out amount is the spec's. -/
theorem eitcTable_completedPhaseout (i : EitcTableIn) :
    (eitcTable i).completedPhaseout =
      Spec.eitcCompletedPhaseout (caseOf i).qualifyingChildren (caseOf i).marriedFilingJointly := by
  unfold eitcTable caseOf
  dsimp only
  by_cases h0 : i.qualifyingChildren = 0
  · cases hm : i.isMfj <;>
      simp [h0, Spec.eitcCompletedPhaseout, Params.eitcCompletedPhaseoutJoint0Children,
        Params.eitcCompletedPhaseoutOther0Children, TaxRates.usd]
  by_cases h1 : i.qualifyingChildren = 1
  · cases hm : i.isMfj <;>
      simp [h1, Spec.eitcCompletedPhaseout, Params.eitcCompletedPhaseoutJoint1Child,
        Params.eitcCompletedPhaseoutOther1Child, TaxRates.usd]
  by_cases h2 : i.qualifyingChildren = 2
  · cases hm : i.isMfj <;>
      simp [h2, Spec.eitcCompletedPhaseout, Params.eitcCompletedPhaseoutJoint2Children,
        Params.eitcCompletedPhaseoutOther2Children, TaxRates.usd]
  obtain ⟨m, hm⟩ : ∃ m : Nat, (if i.qualifyingChildren < 0 then 3 else i.qualifyingChildren.toNat) = m + 3 :=
    ⟨(if i.qualifyingChildren < 0 then 3 else i.qualifyingChildren.toNat) - 3, by split <;> omega⟩
  cases hj : i.isMfj <;>
    simp [h0, h1, h2, hm, Spec.eitcCompletedPhaseout,
      Params.eitcCompletedPhaseoutJoint3OrMoreChildren,
      Params.eitcCompletedPhaseoutOther3OrMoreChildren, TaxRates.usd]

/-- The `no_credit` rule, as the code states it. -/
theorem eitcTable_noCredit_eq (i : EitcTableIn) :
    (eitcTable i).noCredit = (decide (i.earnedIncome ≤ 0) ||
      decide (i.earnedIncome ≥ (eitcTable i).completedPhaseout) ||
      decide (i.agi ≥ (eitcTable i).completedPhaseout)) := rfl

/-- At or after the completed phase-out amount (of earned income or AGI) there is no credit. -/
theorem eitcTable_zero_of_completed (i : EitcTableIn)
    (h : (eitcTable i).completedPhaseout ≤ Max.max i.earnedIncome i.agi) : (eitcTable i).amount = 0 := by
  have hnc : (eitcTable i).noCredit = true := by
    rw [eitcTable_noCredit_eq]
    have : i.earnedIncome ≥ (eitcTable i).completedPhaseout ∨ i.agi ≥ (eitcTable i).completedPhaseout := by
      omega
    rcases this with h' | h' <;> simp [h']
  rw [eitcTable_amount_eq, hnc]; rfl

/-- **The EITC is within its bounds** (issue #67): for every input, the credit `EitcTable` computes satisfies `EitcWithinBounds` for the case read off the
input: between $0 and the maximum credit, and $0 at or after the completed phase-out. -/
theorem eitc_within_bounds (i : EitcTableIn) :
    Spec.EitcWithinBounds (caseOf i) (eitc i) := by
  refine ⟨eitcTable_amount_nonneg i, ?_, ?_⟩
  · rw [← eitcTable_maxCredit i]; exact eitcTable_amount_le_maxCredit i
  · intro hc
    rw [← eitcTable_completedPhaseout i] at hc
    exact eitcTable_zero_of_completed i hc

#audit_axioms UsTax.Proofs.eitc_within_bounds

end UsTax.Proofs
