import UsTax.SaversCredit
import UsTax.ElderlyAndDisabled
import UsTax.Cdcc
import UsTax.Money.Lemmas
import UsTax.Audit

/-!
# Nonrefundable credits never exceed their limits (issues #46, #66)

Cheap structural facts about the code that runs, each property-tested first in
`UsTax/NonrefundableCredits/Props.lean` (CLAUDE.md section 5). They are the pieces issue #66
(nonrefundable credits never exceed liability) composes in the Calculator (#48).

For every credit the key statement has the shape "the credit is nonnegative and at most the
tax limit the credit's own scope was given", where the limit is the Credit Limit Worksheet of
the form:

* CDCC (Form 2441 line 11): `0 ≤ cdccTotalCredit`, `cdccTotalCredit ≤ line9c` (the tentative
  credit) and `cdccTotalCredit ≤ positive totalTentativeTax` (line 10, Form 1040 line 18);
  a positive credit satisfies `cdccTotalCredit ≤ totalTentativeTax`.
* Saver's credit (Form 8880 line 12): `0 ≤ qualifiedSaverCreditAmount`, `≤ ratioed` (line 10),
  `≤ limitationBasedOnTaxLiability` (line 11, which is `positive (tax - (cdcc + edc))`), and
  `≤ $2,000`; a positive credit satisfies `cdcc + edc + credit ≤ tax`.
* Schedule R (line 22): `0 ≤ totalEdc`, `≤ net_edc_amount` (line 20), `≤ positive line3`
  (line 21, the Credit Limit Worksheet line 3 the caller computes as tax less CDCC), and
  `≤ $1,125`.

Composition (issue #66): with Schedule R's line 3 fed `tax - cdcc` and the Saver's credit fed
the same `cdcc` and `totalEdc`, the three credits together never exceed the tax when the tax
covers the CDCC (`credits_within_tax`).
-/

namespace UsTax.NonrefundableCredits

open Money

/-! ### Saver's credit (Form 8880) -/

namespace Savers
open SaversCredit

/-- Line 6 of a column is between `$0` and `$2,000`. -/
theorem saversColumn_line6_bounds (i : SaversColumnIn) :
    0 ≤ (saversColumn i).line6 ∧ (saversColumn i).line6 ≤ Params.saversContributionCap := by
  unfold saversColumn
  dsimp only
  have h1 := positive_nonneg (i.line1 + i.line2 - i.line4)
  have h2 := min_le_left Params.saversContributionCap (positive (i.line1 + i.line2 - i.line4))
  have h3 := le_min (a := Params.saversContributionCap)
    (b := positive (i.line1 + i.line2 - i.line4)) (c := 0) (by decide) h1
  exact ⟨h3, h2⟩

/-- The decimal amount of line 9 is between 0 and one half. -/
theorem multiplierAsRational_bounds (m : SaversCreditMultiplier) :
    0 ≤ multiplierAsRational m ∧ multiplierAsRational m ≤ 1 / 2 := by
  cases m <;> unfold multiplierAsRational Params.saversRateHigh Params.saversRateMiddle
    Params.saversRateLow <;> decide +kernel

/-- Each column's line 6 is between `$0` and `$2,000`. -/
theorem columns_bounds (i : SaversCreditIn) :
    (0 ≤ (saversCredit i).primaryFilerMaxCreditCalc ∧
      (saversCredit i).primaryFilerMaxCreditCalc ≤ Params.saversContributionCap) ∧
    (0 ≤ (saversCredit i).secondaryFilerMaxCreditCalc ∧
      (saversCredit i).secondaryFilerMaxCreditCalc ≤ Params.saversContributionCap) :=
  ⟨saversColumn_line6_bounds _, saversColumn_line6_bounds _⟩

/-- Line 7 is `primary + secondary` (the definition). -/
theorem combined_eq (i : SaversCreditIn) :
    (saversCredit i).combinedCreditLimit =
      (saversCredit i).primaryFilerMaxCreditCalc + (saversCredit i).secondaryFilerMaxCreditCalc := rfl

/-- Line 10 is the rounded product of line 7 and line 9 (the definition). -/
theorem ratioed_eq (i : SaversCreditIn) :
    (saversCredit i).ratioedCombinedCreditLimit =
      roundDollar (mulRate (saversCredit i).combinedCreditLimit
        (saversCredit i).saversCreditMultiplierAsRational) := rfl

/-- Line 9 as a decimal is the multiplier's decimal (the definition). -/
theorem multiplierRat_eq (i : SaversCreditIn) :
    (saversCredit i).saversCreditMultiplierAsRational =
      multiplierAsRational (saversCredit i).saversCreditMultiplier := rfl

/-- Line 11 is the Credit Limit Worksheet (the definition). -/
theorem limitation_eq (i : SaversCreditIn) :
    (saversCredit i).limitationBasedOnTaxLiability =
      positive (i.totalTentativeTax - (i.cdccTotalCredit + i.totalEdc)) := rfl

/-- Line 12 (the definition). -/
theorem amount_eq (i : SaversCreditIn) :
    (saversCredit i).qualifiedSaverCreditAmount =
      if (saversCredit i).qualifiedForSaverCredit = true
      then Money.min (saversCredit i).ratioedCombinedCreditLimit
        (saversCredit i).limitationBasedOnTaxLiability else 0 := rfl

/-- A qualifying return has tax left after the earlier credits (the definition). -/
theorem qualified_imp_limitation_pos (i : SaversCreditIn)
    (h : (saversCredit i).qualifiedForSaverCredit = true) :
    0 < (saversCredit i).limitationBasedOnTaxLiability := by
  have : (saversCredit i).qualifiedForSaverCredit =
      ((saversCredit i).qualifiedForSaverCreditWoTaxLiability &&
        decide (0 < (saversCredit i).limitationBasedOnTaxLiability)) := rfl
  rw [this] at h
  simp at h
  exact h.2

/-- Line 7 is between `$0` and `$4,000`. -/
theorem combinedCreditLimit_bounds (i : SaversCreditIn) :
    0 ≤ (saversCredit i).combinedCreditLimit ∧
      (saversCredit i).combinedCreditLimit ≤ 2 * Params.saversContributionCap := by
  have h := columns_bounds i
  rw [combined_eq]
  omega

/-- Line 10 is between `$0` and `$2,000`: at most half of line 7, rounded. -/
theorem ratioed_bounds (i : SaversCreditIn) :
    0 ≤ (saversCredit i).ratioedCombinedCreditLimit ∧
      (saversCredit i).ratioedCombinedCreditLimit ≤ 200_000 := by
  have hc := combinedCreditLimit_bounds i
  have hm := multiplierAsRational_bounds (saversCredit i).saversCreditMultiplier
  rw [ratioed_eq, multiplierRat_eq]
  generalize multiplierAsRational (saversCredit i).saversCreditMultiplier = r at hm
  generalize (saversCredit i).combinedCreditLimit = c at hc
  have h0 := roundDollar_nonneg (mulRate_nonneg hc.1 hm.1)
  have h1 : mulRate c r ≤ mulRate (2 * Params.saversContributionCap) (1 / 2) :=
    Int.le_trans (mulRate_mono hm.1 hc.2)
      (mulRate_mono_rate (m := 2 * Params.saversContributionCap) (by decide) hm.2)
  have h2 := roundDollar_mono h1
  have h3 : roundDollar (mulRate (2 * Params.saversContributionCap) (1 / 2)) = 200_000 := by
    decide +kernel
  exact ⟨h0, by omega⟩

/-- Form 8880 line 12 is never negative. -/
theorem credit_nonneg (i : SaversCreditIn) : 0 ≤ (saversCredit i).qualifiedSaverCreditAmount := by
  have hr := (ratioed_bounds i).1
  rw [amount_eq]
  split
  · rename_i hq
    have hl := qualified_imp_limitation_pos i hq
    exact le_min hr (by omega)
  · omega

/-- The credit is at most line 10 (the tentative credit). -/
theorem credit_le_ratioed (i : SaversCreditIn) :
    (saversCredit i).qualifiedSaverCreditAmount ≤ (saversCredit i).ratioedCombinedCreditLimit := by
  have hr := (ratioed_bounds i).1
  rw [amount_eq]
  split
  · exact min_le_left _ _
  · exact hr

/-- The credit is at most line 11, the Credit Limit Worksheet (the tax limit). -/
theorem credit_le_limitation (i : SaversCreditIn) :
    (saversCredit i).qualifiedSaverCreditAmount ≤ (saversCredit i).limitationBasedOnTaxLiability := by
  have hl := positive_nonneg (i.totalTentativeTax - (i.cdccTotalCredit + i.totalEdc))
  rw [amount_eq, limitation_eq]
  split
  · exact min_le_right _ _
  · exact hl

/-- The credit is at most `$2,000` (a joint return: two columns of `$2,000` at 50 percent). -/
theorem credit_le_2000 (i : SaversCreditIn) :
    (saversCredit i).qualifiedSaverCreditAmount ≤ 200_000 := by
  have := credit_le_ratioed i
  have := (ratioed_bounds i).2
  omega

/-- **Composable form (issue #66).** A positive Saver's credit fits in the tax left after the
CDCC and the credit for the elderly or the disabled:
`cdcc + edc + credit ≤ tax`. -/
theorem credit_pos_imp_sum_le_tax (i : SaversCreditIn)
    (h : 0 < (saversCredit i).qualifiedSaverCreditAmount) :
    i.cdccTotalCredit + i.totalEdc + (saversCredit i).qualifiedSaverCreditAmount ≤
      i.totalTentativeTax := by
  have hle := credit_le_limitation i
  rw [limitation_eq, positive_eq] at hle
  split at hle <;> omega

/-- **Composable form (issue #66).** If the tax covers the earlier credits, adding the
Saver's credit keeps the total within the tax. -/
theorem sum_le_tax_of_covered (i : SaversCreditIn)
    (h : i.cdccTotalCredit + i.totalEdc ≤ i.totalTentativeTax) :
    i.cdccTotalCredit + i.totalEdc + (saversCredit i).qualifiedSaverCreditAmount ≤
      i.totalTentativeTax := by
  have hle := credit_le_limitation i
  rw [limitation_eq, positive_eq] at hle
  split at hle <;> omega

end Savers

/-! ### Credit for the elderly or the disabled (Schedule R) -/

namespace ScheduleR
open ElderlyAndDisabled

/-- Line 21 is the Credit Limit Worksheet line 3, not below `$0` (the definition). -/
theorem limit_eq (i : ScheduleRIn) :
    (scheduleR i).edcTaxLiabilityLimit = positive i.creditLimitWorksheetLine3 := rfl

/-- Line 22 (the definition). -/
theorem totalEdc_eq (i : ScheduleRIn) :
    (scheduleR i).totalEdc =
      if (scheduleR i).qualifiedForCreditForElderlyAndDisabled = true
      then Money.min (scheduleR i).netEdcAmount (scheduleR i).edcTaxLiabilityLimit else 0 := rfl

/-- Line 20 is 15 percent of line 19, rounded (the definition). -/
theorem netEdc_eq (i : ScheduleRIn) :
    (scheduleR i).netEdcAmount =
      roundDollar (mulRate (scheduleR i).edcNetCreditAmount Params.edcCreditRate) := rfl

/-- Line 19 (the definition). -/
theorem netCredit_eq (i : ScheduleRIn) :
    (scheduleR i).edcNetCreditAmount =
      positive ((scheduleR i).lesserOfFilingStatusAmountAndTaxableDisabilityIncome -
        (scheduleR i).edcAdjustedCreditAmount) := rfl

/-- Line 18 (the definition). -/
theorem adjusted_eq (i : ScheduleRIn) :
    (scheduleR i).edcAdjustedCreditAmount =
      (scheduleR i).edcTotalNonTaxableAmount + (scheduleR i).edcHalfMagi := rfl

/-- Line 13c (the definition). -/
theorem totalNonTaxable_eq (i : ScheduleRIn) :
    (scheduleR i).edcTotalNonTaxableAmount =
      roundDollar (positive ((scheduleR i).edcNonTaxableSocialSecurityAndRailroadBenefits +
        (scheduleR i).edcNonTaxableIncomeNotIncludingSocialSecurityAndRrb)) := rfl

/-- Line 17 (the definition). -/
theorem halfMagi_eq (i : ScheduleRIn) :
    (scheduleR i).edcHalfMagi =
      roundDollar (mulRate (scheduleR i).edcMagi Params.edcAgiReductionRate) := rfl

/-- Line 16 (the definition). -/
theorem magi_eq (i : ScheduleRIn) :
    (scheduleR i).edcMagi =
      roundDollar (positive (i.agi - (scheduleR i).edcExemptionAmount)) := rfl

/-- Line 12 (the definition). -/
theorem lesser_eq (i : ScheduleRIn) :
    (scheduleR i).lesserOfFilingStatusAmountAndTaxableDisabilityIncome =
      if decide ((scheduleR i).numberQualifiedThroughDisability > 0) = true
      then Money.min (scheduleR i).edcFilingStatusAmt (scheduleR i).statusBasedDisabilityIncome
      else (scheduleR i).edcFilingStatusAmt := rfl

/-- Line 10 is one of `$0`, `$3,750`, `$5,000`, `$7,500`; at most `$7,500`. -/
theorem filingStatusAmt_le (i : ScheduleRIn) : (scheduleR i).edcFilingStatusAmt ≤ 750_000 := by
  unfold scheduleR
  dsimp only
  split <;> try split <;> try split <;>
    simp only [Params.edcInitialAmountSingleOrOneQualified, Params.edcInitialAmountJointBothQualified,
      Params.edcInitialAmountMarriedSeparate, TaxRates.usd] <;> omega

/-- Line 12 is at most `$7,500`. -/
theorem lesser_le (i : ScheduleRIn) :
    (scheduleR i).lesserOfFilingStatusAmountAndTaxableDisabilityIncome ≤ 750_000 := by
  have h := filingStatusAmt_le i
  rw [lesser_eq]
  split
  · exact Int.le_trans (min_le_left _ _) h
  · exact h

/-- Line 18 is never negative. -/
theorem adjusted_nonneg (i : ScheduleRIn) : 0 ≤ (scheduleR i).edcAdjustedCreditAmount := by
  rw [adjusted_eq, totalNonTaxable_eq, halfMagi_eq, magi_eq]
  have h1 := roundDollar_nonneg (positive_nonneg
    ((scheduleR i).edcNonTaxableSocialSecurityAndRailroadBenefits +
      (scheduleR i).edcNonTaxableIncomeNotIncludingSocialSecurityAndRrb))
  have h2 := roundDollar_nonneg (mulRate_nonneg
    (roundDollar_nonneg (positive_nonneg (i.agi - (scheduleR i).edcExemptionAmount)))
    (by decide +kernel : (0 : Rat) ≤ Params.edcAgiReductionRate))
  omega

/-- Line 19 is between `$0` and `$7,500`. -/
theorem netCredit_bounds (i : ScheduleRIn) :
    0 ≤ (scheduleR i).edcNetCreditAmount ∧ (scheduleR i).edcNetCreditAmount ≤ 750_000 := by
  have h1 := lesser_le i
  have h2 := adjusted_nonneg i
  rw [netCredit_eq, positive_eq]
  split <;> omega

/-- Line 20 is between `$0` and `$1,125` (15 percent of `$7,500`). -/
theorem netEdc_bounds (i : ScheduleRIn) :
    0 ≤ (scheduleR i).netEdcAmount ∧ (scheduleR i).netEdcAmount ≤ 112_500 := by
  have hb := netCredit_bounds i
  rw [netEdc_eq]
  generalize (scheduleR i).edcNetCreditAmount = c at hb
  have h0 := roundDollar_nonneg
    (mulRate_nonneg hb.1 (by decide +kernel : (0 : Rat) ≤ Params.edcCreditRate))
  have h1 : mulRate c Params.edcCreditRate ≤ mulRate 750_000 Params.edcCreditRate :=
    mulRate_mono (by decide +kernel) hb.2
  have h2 := roundDollar_mono h1
  have h3 : roundDollar (mulRate 750_000 Params.edcCreditRate) = 112_500 := by decide +kernel
  exact ⟨h0, by omega⟩

/-- Schedule R line 22 is never negative. -/
theorem totalEdc_nonneg (i : ScheduleRIn) : 0 ≤ (scheduleR i).totalEdc := by
  have h1 := (netEdc_bounds i).1
  have h2 := positive_nonneg i.creditLimitWorksheetLine3
  rw [totalEdc_eq, limit_eq]
  split
  · exact le_min h1 h2
  · omega

/-- The credit is at most line 20 (15 percent of line 19). -/
theorem totalEdc_le_netEdc (i : ScheduleRIn) :
    (scheduleR i).totalEdc ≤ (scheduleR i).netEdcAmount := by
  have h1 := (netEdc_bounds i).1
  rw [totalEdc_eq]
  split
  · exact min_le_left _ _
  · exact h1

/-- The credit is at most line 21, the Credit Limit Worksheet (the tax limit). -/
theorem totalEdc_le_limit (i : ScheduleRIn) :
    (scheduleR i).totalEdc ≤ positive i.creditLimitWorksheetLine3 := by
  have h2 := positive_nonneg i.creditLimitWorksheetLine3
  rw [totalEdc_eq, limit_eq]
  split
  · exact min_le_right _ _
  · exact h2

/-- The credit is at most `$1,125`. -/
theorem totalEdc_le_1125 (i : ScheduleRIn) : (scheduleR i).totalEdc ≤ 112_500 := by
  have := totalEdc_le_netEdc i
  have := (netEdc_bounds i).2
  omega

/-- **Composable form (issue #66).** If the caller feeds Credit Limit Worksheet line 3 as the tax
less the CDCC (Form 1040 line 18 less Schedule 3 line 2), the CDCC and the credit for the
elderly or the disabled together stay within the tax. -/
theorem cdcc_add_edc_le_tax (i : ScheduleRIn) (tax cdcc : Int)
    (h3 : i.creditLimitWorksheetLine3 = tax - cdcc) (hc : cdcc ≤ tax) :
    cdcc + (scheduleR i).totalEdc ≤ tax := by
  have h := totalEdc_le_limit i
  rw [positive_eq] at h
  split at h <;> omega

end ScheduleR

/-! ### Child and dependent care credit (Form 2441) -/

namespace CdccLemmas
open Cdcc

/-- A division of a nonnegative amount by a positive one is nonnegative. -/
theorem divMoney_nonneg (a b : Int) (hb : 0 < b) (ha : 0 ≤ a) : 0 ≤ divMoney a b := by
  unfold divMoney
  rw [div_eq_divInt]
  apply Rat.num_nonneg.mp
  have h := divInt_cross a b hb
  have hd := den_pos (Rat.divInt a b)
  refine Int.not_lt.mp ?_
  intro hn
  have : (Rat.divInt a b).num * b < 0 := Int.mul_neg_of_neg_of_pos (by omega) hb
  have : 0 ≤ a * ((Rat.divInt a b).den : Int) := Int.mul_nonneg ha (by omega)
  omega

/-- Truncation of a nonnegative decimal is nonnegative. -/
theorem truncateRat_nonneg {q : Rat} (h : 0 ≤ q) : (0 : Rat) ≤ truncateRat q := by
  rw [truncateRat_eq]
  unfold intOfRat
  have hn : 0 ≤ q.num := Rat.num_nonneg.mpr h
  have := Int.tdiv_nonneg hn (Int.natCast_nonneg q.den)
  exact_mod_cast this

/-- The clamp at the end of the percentage table, for any nonnegative number of steps. -/
theorem clamp_bounds (st : Rat) (hst : 0 ≤ st) :
    (20 / 100 : Rat) ≤
      (if Params.cdccMaximumPercentage - Params.cdccPercentageStep * st < Params.cdccMinimumPercentage
       then Params.cdccMinimumPercentage
       else Params.cdccMaximumPercentage - Params.cdccPercentageStep * st) ∧
    (if Params.cdccMaximumPercentage - Params.cdccPercentageStep * st < Params.cdccMinimumPercentage
     then Params.cdccMinimumPercentage
     else Params.cdccMaximumPercentage - Params.cdccPercentageStep * st) ≤ 35 / 100 := by
  have hprod : 0 ≤ Params.cdccPercentageStep * st := Rat.mul_nonneg (by decide +kernel) hst
  have hle : Params.cdccMaximumPercentage - Params.cdccPercentageStep * st ≤
      Params.cdccMaximumPercentage := by grind
  have hmin : Params.cdccMinimumPercentage = 20 / 100 := rfl
  have hmax : Params.cdccMaximumPercentage = 35 / 100 := rfl
  split
  · rw [hmin]; exact ⟨Rat.le_refl, by decide +kernel⟩
  · rename_i h
    exact ⟨hmin ▸ Rat.not_lt.mp h, hmax ▸ hle⟩

/-- IRC 21(a)(2): the applicable percentage is between 20 and 35 percent, for every AGI. -/
theorem applicablePercentage_bounds (agi : Int) :
    (20 / 100 : Rat) ≤ applicablePercentage agi ∧ applicablePercentage agi ≤ 35 / 100 := by
  unfold applicablePercentage
  split
  · exact ⟨by decide +kernel, by decide +kernel⟩
  · rename_i hgt
    have hs := divMoney_nonneg (agi - Params.cdccPercentageReductionThreshold)
      Params.cdccPercentageStepIncome (by decide) (by omega)
    have hw := truncateRat_nonneg hs
    dsimp only
    generalize divMoney (agi - Params.cdccPercentageReductionThreshold)
      Params.cdccPercentageStepIncome = s at hs hw ⊢
    generalize truncateRat s = w at hw ⊢
    have hst : 0 ≤ (if s > w then w + 1 else w) := by
      split
      · exact by grind
      · exact hw
    exact clamp_bounds _ hst

/-- Line 11 of Form 2441 (the definition). -/
theorem credit_eq (i : Form2441In) :
    (form2441 i).cdccTotalCredit =
      if (!(form2441 i).benefits.potentialCdccIsZeroDueToExclusion &&
          !(form2441 i).benefits.marriedSeparateNotAllowed && (form2441 i).hasQualifyingExpenses &&
          decide ((form2441 i).line6 > 0)) = true
      then Money.min (form2441 i).line9c (positive (form2441 i).line10TaxLiabilityLimit) else 0 :=
  rfl

/-- Line 9c, the tentative credit (the definition; line 9b is `$0`). -/
theorem line9c_eq (i : Form2441In) :
    (form2441 i).line9c =
      roundDollar (mulRate (form2441 i).line6 (form2441 i).applicablePercentage) + 0 := rfl

/-- Line 10 is Form 1040 line 18 (the definition). -/
theorem line10_eq (i : Form2441In) :
    (form2441 i).line10TaxLiabilityLimit = i.totalTentativeTax := rfl

/-- The applicable percentage of the scope is the table of IRC 21(a)(2) at the AGI. -/
theorem percentage_eq (i : Form2441In) :
    (form2441 i).applicablePercentage = applicablePercentage i.agi := rfl

/-- Either no credit, or the smaller of line 9c and the tax limit with `line6 > 0`. -/
theorem credit_cases (i : Form2441In) :
    (form2441 i).cdccTotalCredit = 0 ∨
      ((form2441 i).cdccTotalCredit =
          Money.min (form2441 i).line9c (positive (form2441 i).line10TaxLiabilityLimit) ∧
        0 < (form2441 i).line6) := by
  rw [credit_eq]
  split
  · rename_i h
    right
    refine ⟨rfl, ?_⟩
    simp at h
    exact h.2
  · left; rfl

/-- With a positive line 6, line 9c is nonnegative. -/
theorem line9c_nonneg_of_line6_pos (i : Form2441In) (hl : 0 < (form2441 i).line6) :
    0 ≤ (form2441 i).line9c := by
  have hp := applicablePercentage_bounds i.agi
  rw [line9c_eq, percentage_eq]
  have := roundDollar_nonneg (mulRate_nonneg (Int.le_of_lt hl)
    (Rat.le_trans (by decide +kernel : (0 : Rat) ≤ 20 / 100) hp.1))
  omega

/-- Form 2441 line 11 (Schedule 3 line 2) is never negative. -/
theorem credit_nonneg (i : Form2441In) : 0 ≤ (form2441 i).cdccTotalCredit := by
  rcases credit_cases i with h | ⟨h, hl⟩
  · omega
  · rw [h]
    exact le_min (line9c_nonneg_of_line6_pos i hl) (by rw [line10_eq]; exact positive_nonneg _)

/-- A positive credit is at most line 9c, the tentative credit. -/
theorem credit_le_tentative (i : Form2441In) :
    (form2441 i).cdccTotalCredit ≤ Max.max 0 (form2441 i).line9c := by
  rcases credit_cases i with h | ⟨h, _⟩
  · rw [h]; exact Int.le_max_left _ _
  · rw [h]; exact Int.le_trans (min_le_left _ _) (Int.le_max_right _ _)

/-- The credit is at most the tax limit of the Credit Limit Worksheet, `positive line 18`. -/
theorem credit_le_limit (i : Form2441In) :
    (form2441 i).cdccTotalCredit ≤ positive i.totalTentativeTax := by
  have h0 := positive_nonneg i.totalTentativeTax
  rcases credit_cases i with h | ⟨h, _⟩
  · omega
  · rw [h, line10_eq]; exact min_le_right _ _

/-- **Composable form (issue #66).** A positive CDCC fits in the tax: `cdcc ≤ tax`. -/
theorem credit_pos_imp_le_tax (i : Form2441In) (h : 0 < (form2441 i).cdccTotalCredit) :
    (form2441 i).cdccTotalCredit ≤ i.totalTentativeTax := by
  have := credit_le_limit i
  rw [positive_eq] at this
  split at this <;> omega

/-- Form 2441 line 27: at most `$6,000`. -/
theorem expenseCap_le (i : Form2441In) :
    (form2441 i).benefits.qualifyingExpenseCap ≤ 600_000 := by
  show (form2441PartIII i.toForm2441PartIIIIn).qualifyingExpenseCap ≤ 600_000
  unfold form2441PartIII
  dsimp only
  split <;> try split <;>
    simp only [Params.cdccExpenseCapTwoOrMore, Params.cdccExpenseCapOnePerson, TaxRates.usd] <;> omega

/-- Line 3 is at most the expense cap, provided the benefits it was reduced by are not negative
(a negative line 28 needs a negative plan maximum or negative earned income, which no real
return has). Without Part III the cap is applied directly. -/
theorem line3_le_cap (i : Form2441In)
    (h : (form2441 i).benefits.isFillingPartIii = true → 0 ≤ (form2441 i).benefits.line28) :
    (form2441 i).line3 ≤ (form2441 i).benefits.qualifyingExpenseCap := by
  have e3 : (form2441 i).line3 =
      if (form2441 i).benefits.isFillingPartIii = true then (form2441 i).benefits.line31
      else Money.min (form2441 i).benefits.uncappedQualifyingExpenses
        (form2441 i).benefits.qualifyingExpenseCap := rfl
  have e31 : (form2441 i).benefits.line31 =
      Money.min (form2441 i).benefits.line29NetAllowable
        (form2441 i).benefits.uncappedQualifyingExpenses := rfl
  have e29 : (form2441 i).benefits.line29NetAllowable =
      (form2441 i).benefits.qualifyingExpenseCap - (form2441 i).benefits.line28 := rfl
  rw [e3]
  split
  · rename_i hf
    have := h hf
    have := min_le_left (form2441 i).benefits.line29NetAllowable
      (form2441 i).benefits.uncappedQualifyingExpenses
    rw [e31]
    omega
  · exact min_le_right _ _

/-- **The CDCC is at most `$2,100`**: 35 percent of the `$6,000` cap (IRC 21(a)(2), (c)(2)). -/
theorem credit_le_2100 (i : Form2441In)
    (h : (form2441 i).benefits.isFillingPartIii = true → 0 ≤ (form2441 i).benefits.line28) :
    (form2441 i).cdccTotalCredit ≤ 210_000 := by
  rcases credit_cases i with hc | ⟨hc, hl⟩
  · rw [hc]; omega
  · have e6 : (form2441 i).line6 =
        Money.min (form2441 i).line3 (form2441 i).lowerOfEarnedIncome := rfl
    have h6 : (form2441 i).line6 ≤ 600_000 := by
      have := min_le_left (form2441 i).line3 (form2441 i).lowerOfEarnedIncome
      have := line3_le_cap i h
      have := expenseCap_le i
      omega
    have hp := applicablePercentage_bounds i.agi
    have hm : mulRate (form2441 i).line6 (form2441 i).applicablePercentage ≤
        mulRate 600_000 (35 / 100) := by
      rw [percentage_eq]
      exact Int.le_trans (mulRate_mono (Rat.le_trans (by decide +kernel) hp.1) h6)
        (mulRate_mono_rate (m := 600_000) (by decide) hp.2)
    have h2 := roundDollar_mono hm
    have h3 : roundDollar (mulRate 600_000 (35 / 100)) = 210_000 := by decide +kernel
    have h4 := min_le_left (form2441 i).line9c (positive (form2441 i).line10TaxLiabilityLimit)
    have h9 : (form2441 i).line9c ≤ 210_000 := by
      rw [line9c_eq]
      omega
    rw [hc]
    omega

end CdccLemmas

/-! ### The three credits together (issue #66) -/

/-- **CDCC, credit for the elderly or the disabled and Saver's credit never exceed the tax.**
Wiring as the Calculator does it: Schedule R's Credit Limit Worksheet line 3 is the tax less
the CDCC, and the Saver's credit is given the tax, the CDCC and the Schedule R credit. When the
tax (Form 1040 line 18) is not negative, the three credits add up to at most the tax. -/
theorem credits_within_tax (c : Cdcc.Form2441In) (r : ElderlyAndDisabled.ScheduleRIn)
    (s : SaversCredit.SaversCreditIn)
    (hr : r.creditLimitWorksheetLine3 =
      c.totalTentativeTax - (Cdcc.form2441 c).cdccTotalCredit)
    (hs : s.totalTentativeTax = c.totalTentativeTax ∧
      s.cdccTotalCredit = (Cdcc.form2441 c).cdccTotalCredit ∧
      s.totalEdc = (ElderlyAndDisabled.scheduleR r).totalEdc)
    (htax : 0 ≤ c.totalTentativeTax) :
    (Cdcc.form2441 c).cdccTotalCredit + (ElderlyAndDisabled.scheduleR r).totalEdc +
        (SaversCredit.saversCredit s).qualifiedSaverCreditAmount ≤ c.totalTentativeTax := by
  obtain ⟨hs1, hs2, hs3⟩ := hs
  have hcdcc : (Cdcc.form2441 c).cdccTotalCredit ≤ c.totalTentativeTax := by
    have h0 := CdccLemmas.credit_nonneg c
    by_cases hp : 0 < (Cdcc.form2441 c).cdccTotalCredit
    · exact CdccLemmas.credit_pos_imp_le_tax c hp
    · omega
  have hedc := ScheduleR.cdcc_add_edc_le_tax r c.totalTentativeTax
    (Cdcc.form2441 c).cdccTotalCredit hr hcdcc
  have := Savers.sum_le_tax_of_covered s (by rw [hs1, hs2, hs3]; exact hedc)
  rw [hs1, hs2, hs3] at this
  exact this

end UsTax.NonrefundableCredits

/-! ### Satisfiability and axiom audit -/

open UsTax

-- The hypotheses are satisfiable: the default `Case` of the CDCC tests has no Part III, a
-- positive tax, and the Schedule R and Saver's inputs below wire to it.
#guard !(Cdcc.form2441 (Cdcc.Case.input {})).benefits.isFillingPartIii
#guard 0 ≤ (Cdcc.Case.input {}).totalTentativeTax
#guard (Cdcc.form2441 (Cdcc.Case.input {})).cdccTotalCredit == 105_000

#print axioms UsTax.NonrefundableCredits.Savers.credit_nonneg
#print axioms UsTax.NonrefundableCredits.Savers.credit_le_limitation
#print axioms UsTax.NonrefundableCredits.Savers.credit_le_2000
#print axioms UsTax.NonrefundableCredits.Savers.credit_pos_imp_sum_le_tax
#print axioms UsTax.NonrefundableCredits.Savers.sum_le_tax_of_covered
#print axioms UsTax.NonrefundableCredits.ScheduleR.totalEdc_nonneg
#print axioms UsTax.NonrefundableCredits.ScheduleR.totalEdc_le_limit
#print axioms UsTax.NonrefundableCredits.ScheduleR.totalEdc_le_1125
#print axioms UsTax.NonrefundableCredits.ScheduleR.cdcc_add_edc_le_tax
#print axioms UsTax.NonrefundableCredits.CdccLemmas.applicablePercentage_bounds
#print axioms UsTax.NonrefundableCredits.CdccLemmas.credit_nonneg
#print axioms UsTax.NonrefundableCredits.CdccLemmas.credit_le_limit
#print axioms UsTax.NonrefundableCredits.CdccLemmas.credit_pos_imp_le_tax
#print axioms UsTax.NonrefundableCredits.CdccLemmas.credit_le_2100
#print axioms UsTax.NonrefundableCredits.credits_within_tax
