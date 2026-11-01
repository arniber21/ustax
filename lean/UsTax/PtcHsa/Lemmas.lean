import UsTax.PtcFamily
import UsTax.PtcAllowed
import UsTax.PtcNet
import UsTax.Hsa
import UsTax.PtcHsa.Spec
import UsTax.Money.Lemmas
import UsTax.Audit

/-!
# Structural lemmas for the premium tax credit and HSA modules (issue #47)

Each statement was property-tested first in `UsTax/PtcHsa/Props.lean` (CLAUDE.md section 5).
The readable statements they are compared against (Table 5, the HSA ceiling) are in
`UsTax/PtcHsa/Spec.lean`.

* **Table 5** (`PtcNet`): line 28 is Table 5 as printed (`repaymentLimitation_eq_table5`), never
  negative and at most $3,150; line 29, the excess APTC repaid, is never negative, never more than
  line 27, and at most the Table 5 amount whenever the table limits it
  (`netPtc_repayment_within_table5`, the spec property `RepaymentWithinTable5`; hypothesis: the
  tax family is not empty, where Direct File's workaround repays everything).
* **Allowed PTC per month** (`PtcAllowed`): in every month of Form 8962 lines 12 to 23, column (e)
  is at most column (a), the enrollment premium, and at most column (d)
  (`ptcMonths_allowed_le_premium`, `ptcMonths_allowed_le_max`); column (d) is never negative;
  line 11(e) is at most line 11(a); line 24 is at most the premiums of its path
  (`totalPtcAmountAllowed_le_premiums`).
* **Applicable figure** (`PtcFamily`, Table 2): monotone in line 5 for every rational line 5
  (`applicableFigureOf_mono`), and between 0 and 0.085.
* **HSA deduction** (`Hsa`, Form 8889): line 13 is at most line 12, the limit
  (`filerHsaTotalDeductibleAmount_le_limit`), for every input; with nonnegative contributions it
  is nonnegative, line 12 is at most line 8, and line 8 is at most $9,300
  (`hsaTotalContributionLimit_le_max`). The Schedule 1 deduction is then between $0 and twice that.
-/

namespace UsTax.PtcHsa

open Money

/-! ### Form 8962 lines 26 to 29 (Table 5) -/

namespace Net
open PtcNet

/-- Line 28 is Table 5 as printed (`Spec.table5Limit`), `$0` where the table has no limitation. -/
theorem repaymentLimitation_eq_table5 (fs : FilingStatus) (p : Rat) :
    repaymentLimitation fs p false = (Spec.table5Limit (decide (fs = .single)) p).getD 0 := by
  unfold repaymentLimitation Spec.table5Limit Spec.table5
  simp only [ptcRepaymentPercentFirstStep, ptcRepaymentPercentSecondStep,
    ptcRepaymentPercentNoLimit, ptcRepaymentLimitUnder200Single, ptcRepaymentLimitUnder200Other,
    ptcRepaymentLimitUnder300Single, ptcRepaymentLimitUnder300Other,
    ptcRepaymentLimitUnder400Single, ptcRepaymentLimitUnder400Other, TaxRates.usd]
  by_cases h1 : p < 200 <;> by_cases h2 : p < 300 <;> by_cases h3 : p < 400 <;>
    cases decide (fs = .single) <;>
    simp_all [List.find?] <;> grind

/-- Line 28 is never negative. -/
theorem line28_nonneg (fs : FilingStatus) (p : Rat) (z : Bool) : 0 ≤ repaymentLimitation fs p z := by
  unfold repaymentLimitation; dsimp only; repeat' split
  all_goals decide

/-- Line 28 is at most the largest Table 5 amount, $3,150. -/
theorem line28_le_max (fs : FilingStatus) (p : Rat) (z : Bool) :
    repaymentLimitation fs p z ≤ Spec.table5Max := by
  unfold repaymentLimitation; dsimp only; repeat' split
  all_goals decide

/-- Line 29 (the excess APTC repaid, Schedule 2 line 1a) is never negative. -/
theorem line29_nonneg (i : NetPtcIn) : 0 ≤ (netPtc i).line29 := by
  have := line28_nonneg i.filingStatus i.householdIncomeAsPercent i.taxFamilySizeIsZero
  unfold netPtc; dsimp only; repeat' split
  all_goals omega

/-- Line 29 is never more than line 27, the excess APTC. -/
theorem line29_le_line27 (i : NetPtcIn) : (netPtc i).line29 ≤ (netPtc i).line27 := by
  unfold netPtc; dsimp only; repeat' split
  all_goals omega

/-- Line 26 (the net PTC, Schedule 3 line 9) is never negative. -/
theorem line26_nonneg (i : NetPtcIn) : 0 ≤ (netPtc i).line26 := by
  unfold netPtc; dsimp only; split <;> omega

/-- Lines 26 and 27 are never both positive. -/
theorem line26_or_line27_zero (i : NetPtcIn) : (netPtc i).line26 = 0 ∨ (netPtc i).line27 = 0 := by
  unfold netPtc; dsimp only; split <;> split <;> omega

/-- With a limitation (`$0` line 28 stands for none), line 29 is at most line 28. -/
theorem line29_le_line28 (i : NetPtcIn) (h : (netPtc i).line28 ≠ 0) :
    (netPtc i).line29 ≤ (netPtc i).line28 := by
  revert h; unfold netPtc; dsimp only; intro h; repeat' split
  all_goals omega

/-- **The repayment never exceeds the Table 5 cap and is nonnegative**: for a nonempty tax
family, line 29 satisfies the spec property `RepaymentWithinTable5` in the Table 5 column of the
filing status (Single or any other). -/
theorem netPtc_repayment_within_table5 (i : NetPtcIn) (hz : i.taxFamilySizeIsZero = false) :
    Spec.RepaymentWithinTable5 (decide (i.filingStatus = .single)) i.householdIncomeAsPercent
      (netPtc i).line27 (netPtc i).line29 := by
  refine ⟨line29_nonneg i, line29_le_line27 i, fun c hc => ?_⟩
  have h28 : (netPtc i).line28 = c := by
    have := repaymentLimitation_eq_table5 i.filingStatus i.householdIncomeAsPercent
    rw [hc] at this
    simp only [netPtc, hz]; simpa using this
  have hc0 : c ≠ 0 := by
    have := repaymentLimitation_eq_table5 i.filingStatus i.householdIncomeAsPercent
    revert hc; unfold Spec.table5Limit Spec.table5; intro hc
    simp only [List.find?] at hc; repeat' split at hc
    all_goals first | omega | (simp at hc; omega) | simp at hc
  rw [← h28]; exact line29_le_line28 i (by rw [h28]; exact hc0)

/-- Below 400 percent with a nonempty tax family, the repayment is at most $3,150. -/
theorem excessAptcRepayment_le_max (i : NetPtcIn) (hz : i.taxFamilySizeIsZero = false)
    (hp : i.householdIncomeAsPercent < 400) : (netPtc i).excessAptcRepayment ≤ Spec.table5Max := by
  have h28 := line28_le_max i.filingStatus i.householdIncomeAsPercent false
  have hpos : repaymentLimitation i.filingStatus i.householdIncomeAsPercent false ≠ 0 := by
    unfold repaymentLimitation; dsimp only
    simp only [Bool.false_eq_true, ↓reduceIte, ptcRepaymentPercentFirstStep,
      ptcRepaymentPercentSecondStep, ptcRepaymentPercentNoLimit]
    by_cases h1 : i.householdIncomeAsPercent < 200
    · simp only [h1, ↓reduceIte]; cases decide (i.filingStatus = .single) <;> decide
    by_cases h2 : i.householdIncomeAsPercent < 300
    · simp only [h1, h2, ↓reduceIte]; cases decide (i.filingStatus = .single) <;> decide
    · simp only [h1, h2, hp, ↓reduceIte]; cases decide (i.filingStatus = .single) <;> decide
  have := line29_le_line28 i (by simpa [netPtc, hz] using hpos)
  simp only [netPtc, hz] at this h28 ⊢
  omega

-- Hypotheses satisfiable: Single, 250 percent, $2,000 of excess APTC repays $950.
example : Spec.RepaymentWithinTable5 true 250 200_000 95_000 := by
  have := netPtc_repayment_within_table5
    { filingStatus := .single, householdIncomeAsPercent := 250, taxFamilySizeIsZero := false
      totalPtcAmountAllowed := 300_000, totalAptcAmountTaken := 500_000 } rfl
  exact this

end Net

/-! ### Form 8962 line 7 (Table 2): the applicable figure is monotone in line 5 -/

namespace Figure
open PtcFamily

/-- The rounded piece of Table 2 (300 to 399 percent), in ten-thousandths. -/
def upper (p : Rat) : Int := roundRat ((6 / 100 + 25 / 100000 * (p - 300)) * 10000)

/-- Table 2 with the parameters written out. -/
theorem applicableFigureOf_eq (p : Rat) : applicableFigureOf p =
    if p ≤ 150 then 0 else if p ≤ 300 then (p - 150) * (4 / 10000)
    else if p ≤ 399 then (upper p : Rat) / 10000 else 85 / 1000 := by
  unfold applicableFigureOf upper
  simp only [Params.ptcApplicableFigureZeroThrough, Params.ptcApplicableFigureLinearThrough,
    Params.ptcApplicableFigureLastRow, Params.ptcApplicableFigurePerPointLow,
    Params.ptcApplicableFigureMax, Params.ptcApplicableFigureAt300,
    Params.ptcApplicableFigurePerPointHigh]
  push_cast; rfl

/-- The rounded piece is monotone. -/
theorem upper_div_mono {p q : Rat} (h : p ≤ q) :
    (upper p : Rat) / 10000 ≤ (upper q : Rat) / 10000 := by
  have := Rat.intCast_le_intCast.mpr (roundRat_mono
    (q := (6 / 100 + 25 / 100000 * (p - 300)) * 10000)
    (r := (6 / 100 + 25 / 100000 * (q - 300)) * 10000) (by grind))
  unfold upper; grind

/-- Above 300 percent the rounded piece is at least 0.06. -/
theorem upper_ge {p : Rat} (h : 300 < p) : (6 / 100 : Rat) ≤ (upper p : Rat) / 10000 := by
  have h1 := roundRat_mono (q := ((600 : Int) : Rat))
    (r := (6 / 100 + 25 / 100000 * (p - 300)) * 10000) (by push_cast; grind)
  rw [roundRat_intCast] at h1
  have := Rat.intCast_le_intCast.mpr h1
  push_cast at this; unfold upper; grind

/-- Up to 399 percent the rounded piece is at most 0.0848. -/
theorem upper_le {p : Rat} (h : p ≤ 399) : (upper p : Rat) / 10000 ≤ 848 / 10000 := by
  have h1 := roundRat_mono (q := (6 / 100 + 25 / 100000 * (p - 300)) * 10000)
    (r := (1695 / 2 : Rat)) (by grind)
  have h848 : roundRat (1695 / 2 : Rat) = 848 := by decide +kernel
  rw [h848] at h1
  have := Rat.intCast_le_intCast.mpr h1
  push_cast at this; unfold upper; grind

/-- Table 2 is between 0 and 0.085. -/
theorem applicableFigureOf_bounds (p : Rat) :
    0 ≤ applicableFigureOf p ∧ applicableFigureOf p ≤ 85 / 1000 := by
  rw [applicableFigureOf_eq]
  by_cases h1 : p ≤ 150
  · simp only [h1, ↓reduceIte]; exact ⟨Rat.le_refl, by grind⟩
  by_cases h2 : p ≤ 300
  · simp only [h1, h2, ↓reduceIte]; constructor <;> grind
  by_cases h3 : p ≤ 399
  · simp only [h1, h2, h3, ↓reduceIte]
    have := upper_ge (p := p) (by grind); have := upper_le h3
    constructor <;> grind
  · simp only [h1, h2, h3, ↓reduceIte]; exact ⟨by grind, Rat.le_refl⟩

/-- **The applicable figure is monotone in line 5** (Table 2, Form 8962 line 7), for every
rational line 5. -/
theorem applicableFigureOf_mono {p q : Rat} (h : p ≤ q) :
    applicableFigureOf p ≤ applicableFigureOf q := by
  have bq := applicableFigureOf_bounds q
  rw [applicableFigureOf_eq] at bq ⊢; rw [applicableFigureOf_eq]
  by_cases p1 : p ≤ 150
  · simp only [p1, ↓reduceIte]; exact bq.1
  by_cases p2 : p ≤ 300
  · have q1 : ¬ q ≤ 150 := by grind
    simp only [p1, p2, q1, ↓reduceIte] at bq ⊢
    by_cases q2 : q ≤ 300
    · simp only [q2, ↓reduceIte]; grind
    by_cases q3 : q ≤ 399
    · simp only [q2, q3, ↓reduceIte]; have := upper_ge (p := q) (by grind); grind
    · simp only [q2, q3, ↓reduceIte]; grind
  by_cases p3 : p ≤ 399
  · have q1 : ¬ q ≤ 150 := by grind
    have q2 : ¬ q ≤ 300 := by grind
    simp only [p1, p2, p3, q1, q2, ↓reduceIte] at bq ⊢
    by_cases q3 : q ≤ 399
    · simp only [q3, ↓reduceIte]; exact upper_div_mono h
    · simp only [q3, ↓reduceIte]; have := upper_le p3; grind
  · have q1 : ¬ q ≤ 150 := by grind
    have q2 : ¬ q ≤ 300 := by grind
    have q3 : ¬ q ≤ 399 := by grind
    simp only [p1, p2, p3, q1, q2, q3, ↓reduceIte]; exact Rat.le_refl

end Figure

/-! ### Form 8962 lines 11 to 24: the allowed amount never exceeds the premium -/

namespace Allowed
open PtcAllowed

/-- Column (e) of one month is at most column (a), the enrollment premium. -/
theorem ptcMonthOf_allowed_le_premium (n : Bool) (c : Int) (ms : List Form1095AMonth) (m : Int) :
    (ptcMonthOf n c ms m).ptcAllowed ≤ (ptcMonthOf n c ms m).enrollmentPremium :=
  min_le_right _ _

/-- Column (e) of one month is at most column (d). -/
theorem ptcMonthOf_allowed_le_max (n : Bool) (c : Int) (ms : List Form1095AMonth) (m : Int) :
    (ptcMonthOf n c ms m).ptcAllowed ≤ (ptcMonthOf n c ms m).maxPremiumAssistance :=
  min_le_left _ _

/-- Column (d) of one month is never negative. -/
theorem ptcMonthOf_max_nonneg (n : Bool) (c : Int) (ms : List Form1095AMonth) (m : Int) :
    0 ≤ (ptcMonthOf n c ms m).maxPremiumAssistance :=
  positive_nonneg _

/-- The months of lines 12 to 23 are `ptcMonthOf` of each month number. -/
theorem ptcMonths_eq (i : PtcAllowedIn) : ∃ n c ms, (ptcAllowed i).ptcMonths =
    monthNumbers.map (ptcMonthOf n c ms) :=
  ⟨_, _, _, rfl⟩

/-- **Allowed PTC ≤ premium per month**: in every month of Form 8962 lines 12 to 23, the
premium tax credit allowed (column (e)) is at most the enrollment premium (column (a)). -/
theorem ptcMonths_allowed_le_premium (i : PtcAllowedIn) :
    ∀ r ∈ (ptcAllowed i).ptcMonths, r.ptcAllowed ≤ r.enrollmentPremium := by
  obtain ⟨n, c, ms, h⟩ := ptcMonths_eq i
  rw [h]; intro r hr
  obtain ⟨m, -, rfl⟩ := List.mem_map.mp hr
  exact ptcMonthOf_allowed_le_premium n c ms m

/-- In every month, column (e) is at most column (d) and column (d) is never negative. -/
theorem ptcMonths_allowed_le_max (i : PtcAllowedIn) :
    ∀ r ∈ (ptcAllowed i).ptcMonths, r.ptcAllowed ≤ r.maxPremiumAssistance ∧
      0 ≤ r.maxPremiumAssistance := by
  obtain ⟨n, c, ms, h⟩ := ptcMonths_eq i
  rw [h]; intro r hr
  obtain ⟨m, -, rfl⟩ := List.mem_map.mp hr
  exact ⟨ptcMonthOf_allowed_le_max n c ms m, ptcMonthOf_max_nonneg n c ms m⟩

/-- Line 11(e) is at most line 11(a), and line 11(d) is never negative. -/
theorem annualPtcAllowed_le_premium (i : PtcAllowedIn) :
    (ptcAllowed i).annualPtcAllowed ≤ (ptcAllowed i).totalPtcAnnualPremium ∧
      0 ≤ (ptcAllowed i).annualMaxPremiumAssistance :=
  ⟨min_le_right _ _, positive_nonneg _⟩

/-- Line 24 is at most the premiums of its path: line 11(a) on the annual path, the sum of
column (a) on the monthly path, `$0` without a Form 8962. -/
theorem totalPtcAmountAllowed_le_premiums (i : PtcAllowedIn) :
    (ptcAllowed i).totalPtcAmountAllowed ≤
      (if !(ptcAllowed i).mayNeedToFileForm8962 then 0
       else if (ptcAllowed i).ptcCanReportAnnualTotals then (ptcAllowed i).totalPtcAnnualPremium
       else sumBy (·.enrollmentPremium) (ptcAllowed i).ptcMonths) := by
  have hm := ptcMonths_allowed_le_premium i
  have ha := (annualPtcAllowed_le_premium i).1
  revert hm ha
  generalize hp : ptcAllowed i = o
  intro hm ha
  have h24 : o.totalPtcAmountAllowed =
      (if !o.mayNeedToFileForm8962 then 0 else if o.ptcCanReportAnnualTotals then o.annualPtcAllowed
       else sumBy (·.ptcAllowed) o.ptcMonths) := by
    subst hp; rfl
  rw [h24]
  split
  · exact Int.le_refl 0
  split
  · exact ha
  · exact sumBy_mono hm

end Allowed

/-! ### Form 8889: the HSA deduction is at most the limit -/

namespace HsaBounds
open Hsa

/-- **Line 13 is at most line 12** (the contribution limit left after employer contributions), for
every input and both filers. -/
theorem filerHsaTotalDeductibleAmount_le_limit (i : HsaIn) (r : FilerRole) :
    filerHsaTotalDeductibleAmount i r ≤ hsaContributionLimitLessLine11 i r := by
  unfold filerHsaTotalDeductibleAmount hsaContributionLimitLessLine11
  split
  · exact min_le_right _ _
  · exact Int.le_refl 0

/-- Line 12 is never negative. -/
theorem line12_nonneg (i : HsaIn) (r : FilerRole) : 0 ≤ hsaContributionLimitLessLine11 i r := by
  unfold hsaContributionLimitLessLine11; split
  · exact positive_nonneg _
  · exact Int.le_refl 0

/-- **Line 13 is never negative** when the filer's own contributions (line 2's two amounts) are
not negative. -/
theorem filerHsaTotalDeductibleAmount_nonneg (i : HsaIn) (r : FilerRole)
    (h : 0 ≤ (answers i r).writableHsaNonemployerContributionsTaxYear +
      (answers i r).writableHsaNonemployerContributionsTaxYearPlusOne) :
    0 ≤ filerHsaTotalDeductibleAmount i r := by
  unfold filerHsaTotalDeductibleAmount
  split
  · apply le_min
    · unfold hsaNonemployerContributionsTotal
      split <;> first | exact roundDollar_nonneg h | exact Int.le_refl 0
    · exact line12_nonneg i r
  · exact Int.le_refl 0

/-- The base limit is `$0`, $4,150 or $8,300. -/
theorem base_cases (i : HsaIn) (r : FilerRole) :
    hsaBaseContributionLimit i r = 0 ∨ hsaBaseContributionLimit i r = 415_000 ∨
      hsaBaseContributionLimit i r = 830_000 := by
  unfold hsaBaseContributionLimit; repeat' split
  all_goals simp [Params.hsaLimitSelfOnly, Params.hsaLimitFamily, TaxRates.usd]

/-- Line 7 adds the catch-up only when line 3 does not. -/
theorem catchUp_exclusive (i : HsaIn) (r : FilerRole)
    (h7 : (wasEligibleToMakeHsaContributionsAllYear i r && age55OrOlder i r &&
      isCoveredByFamilyHdhp i r && i.isMarried) = true) :
    ((wasEligibleToMakeHsaContributionsAllYear i r && age55OrOlder i r &&
        ((isCoveredByFamilyHdhp i r || isCoveredBySelfOnlyHdhp i r) && !i.isMarried)) ||
      (wasEligibleToMakeHsaContributionsAllYear i r && age55OrOlder i r &&
        isCoveredBySelfOnlyHdhp i r && i.isMarried)) = false := by
  simp only [Bool.and_eq_true] at h7
  obtain ⟨⟨⟨_, _⟩, hf⟩, hm⟩ := h7
  simp [isCoveredBySelfOnlyHdhp, hf, hm]

private theorem roundDollar_le_of_le {m : Int} {c : Int} (h : m ≤ c) (hc : c % 100 = 0) :
    roundDollar m ≤ c := by
  obtain ⟨k, rfl⟩ : ∃ k, c = 100 * k := ⟨c / 100, by omega⟩
  have := roundDollar_mono h
  rwa [roundDollar_mul_100] at this

/-- Line 5 (line 3) is between `$0` and $9,300, and is $8,300 at most when line 7 adds the
catch-up. -/
theorem line5_bounds (i : HsaIn) (r : FilerRole) :
    0 ≤ hsaContributionLimitLessMsaContributions i r ∧
      hsaContributionLimitLessMsaContributions i r ≤ 930_000 ∧
      ((wasEligibleToMakeHsaContributionsAllYear i r && age55OrOlder i r &&
        isCoveredByFamilyHdhp i r && i.isMarried) = true →
        hsaContributionLimitLessMsaContributions i r ≤ 830_000) := by
  have hb := base_cases i r
  unfold hsaContributionLimitLessMsaContributions hsaInitialContributionLimit
  split
  · simp only [Params.hsaCatchUp55, TaxRates.usd]
    refine ⟨?_, ?_, fun h7 => ?_⟩
    · split <;> exact roundDollar_nonneg (by omega)
    · split <;> exact roundDollar_le_of_le (by omega) (by decide)
    · rw [catchUp_exclusive i r h7]
      exact roundDollar_le_of_le (by simp; omega) (by decide)
  · exact ⟨Int.le_refl 0, by decide, fun _ => by decide⟩

/-- **Line 8 is at most $9,300** (`Spec.hsaFilerLimitMax`: the family limit plus the catch-up),
and never negative. -/
theorem hsaTotalContributionLimit_le_max (i : HsaIn) (r : FilerRole) :
    0 ≤ hsaTotalContributionLimit i r ∧ hsaTotalContributionLimit i r ≤ Spec.hsaFilerLimitMax := by
  obtain ⟨l5lo, l5hi, l5c⟩ := line5_bounds i r
  have l6 : 0 ≤ hsaContributionLimitLessAddition i r ∧
      hsaContributionLimitLessAddition i r ≤ hsaContributionLimitLessMsaContributions i r := by
    unfold hsaContributionLimitLessAddition
    split
    · have hr : hsaContributionLimitLessMsaContributions i r % 100 = 0 := by
        unfold hsaContributionLimitLessMsaContributions hsaInitialContributionLimit
        split <;> first | exact roundDollar_emod _ | rfl
      split
      · unfold hsaAllocatedContributionLimit
        exact ⟨roundDollar_nonneg (mulRate_nonneg l5lo (by decide +kernel)),
          roundDollar_le_of_le (mulRate_le_self l5lo (by decide +kernel)) hr⟩
      · exact ⟨roundDollar_nonneg l5lo, roundDollar_le_of_le (Int.le_refl _) hr⟩
    · exact ⟨Int.le_refl 0, l5lo⟩
  unfold hsaTotalContributionLimit Spec.hsaFilerLimitMax additionToHsaContributionLimit
  by_cases hm : hasMadeContributionsToHsa i r = true
  · simp only [hm, ↓reduceIte, Params.hsaCatchUp55, TaxRates.usd]
    by_cases h7 : (wasEligibleToMakeHsaContributionsAllYear i r && age55OrOlder i r &&
        isCoveredByFamilyHdhp i r && i.isMarried) = true
    · have := l5c h7
      have r7 : roundDollar (1000 * 100) = 100_000 := by
        rw [Int.mul_comm]; exact roundDollar_mul_100 1000
      simp only [h7, ↓reduceIte, r7]
      exact ⟨roundDollar_nonneg (by omega), roundDollar_le_of_le (by omega) (by decide)⟩
    · simp only [h7, ↓reduceIte, Bool.false_eq_true, roundDollar_zero]
      exact ⟨roundDollar_nonneg (by omega), roundDollar_le_of_le (by omega) (by decide)⟩
  · simp only [hm, ↓reduceIte, Bool.false_eq_true]
    exact ⟨Int.le_refl 0, by decide⟩

/-- Line 12 is at most line 8 when the W-2 code W amounts are not negative. -/
theorem line12_le_line8 (i : HsaIn) (r : FilerRole)
    (hp : 0 ≤ i.primaryFilerTotalHsaContributionsFromW2s)
    (hs : 0 ≤ i.secondaryFilerTotalHsaContributionsFromW2s) :
    hsaContributionLimitLessLine11 i r ≤ hsaTotalContributionLimit i r := by
  have h8 := (hsaTotalContributionLimit_le_max i r).1
  have h11 : 0 ≤ hsaEmployerContributionsAndFundingDistributionTotal i r := by
    unfold hsaEmployerContributionsAndFundingDistributionTotal hsaContributionsW2sTotal
      hsaFundingDistributionsTotal
    apply roundDollar_nonneg
    have : 0 ≤ roundDollar (if i.isFilingStatusMfj && isSecondary r
        then i.secondaryFilerTotalHsaContributionsFromW2s
        else i.primaryFilerTotalHsaContributionsFromW2s) := by
      apply roundDollar_nonneg; split <;> assumption
    omega
  unfold hsaContributionLimitLessLine11
  split
  · rw [positive_eq]; split <;> omega
  · exact h8

/-- **The Schedule 1 HSA deduction is at most the two limits** (line 12 of each filer), for every
input; with nonnegative contributions it is between `$0` and $18,600. -/
theorem hsaTotalDeductibleAmount_le_limits (i : HsaIn) :
    hsaTotalDeductibleAmount i ≤
      hsaContributionLimitLessLine11 i .primaryFiler + hsaContributionLimitLessLine11 i .secondaryFiler := by
  unfold hsaTotalDeductibleAmount
  have := filerHsaTotalDeductibleAmount_le_limit i .primaryFiler
  have := filerHsaTotalDeductibleAmount_le_limit i .secondaryFiler
  omega

/-- With nonnegative contributions (own and W-2), the deduction is between `$0` and twice $9,300. -/
theorem hsaTotalDeductibleAmount_bounds (i : HsaIn)
    (hp : 0 ≤ i.primaryFilerTotalHsaContributionsFromW2s)
    (hs : 0 ≤ i.secondaryFilerTotalHsaContributionsFromW2s)
    (hc : ∀ r, 0 ≤ (answers i r).writableHsaNonemployerContributionsTaxYear +
      (answers i r).writableHsaNonemployerContributionsTaxYearPlusOne) :
    0 ≤ hsaTotalDeductibleAmount i ∧ hsaTotalDeductibleAmount i ≤ 2 * Spec.hsaFilerLimitMax := by
  have a1 := filerHsaTotalDeductibleAmount_nonneg i .primaryFiler (hc _)
  have a2 := filerHsaTotalDeductibleAmount_nonneg i .secondaryFiler (hc _)
  have b1 := filerHsaTotalDeductibleAmount_le_limit i .primaryFiler
  have b2 := filerHsaTotalDeductibleAmount_le_limit i .secondaryFiler
  have c1 := line12_le_line8 i .primaryFiler hp hs
  have c2 := line12_le_line8 i .secondaryFiler hp hs
  have d1 := (hsaTotalContributionLimit_le_max i .primaryFiler).2
  have d2 := (hsaTotalContributionLimit_le_max i .secondaryFiler).2
  unfold hsaTotalDeductibleAmount
  constructor <;> omega

-- Hypotheses satisfiable: the Catala test `TestSelfOnly4000` meets them, deduction $4,000.
example : 0 ≤ hsaTotalDeductibleAmount ({ pTy := 400_000 } : Case).input ∧
    hsaTotalDeductibleAmount ({ pTy := 400_000 } : Case).input ≤ 2 * Spec.hsaFilerLimitMax :=
  hsaTotalDeductibleAmount_bounds _ (by decide) (by decide) (by
    intro r; cases r <;> decide)

end HsaBounds

/-! ### Axiom audit -/

#audit_axioms Net.repaymentLimitation_eq_table5
#audit_axioms Net.netPtc_repayment_within_table5
#audit_axioms Net.excessAptcRepayment_le_max
#audit_axioms Net.line26_or_line27_zero
#audit_axioms Figure.applicableFigureOf_mono
#audit_axioms Figure.applicableFigureOf_bounds
#audit_axioms Allowed.ptcMonths_allowed_le_premium
#audit_axioms Allowed.ptcMonths_allowed_le_max
#audit_axioms Allowed.totalPtcAmountAllowed_le_premiums
#audit_axioms HsaBounds.filerHsaTotalDeductibleAmount_le_limit
#audit_axioms HsaBounds.filerHsaTotalDeductibleAmount_nonneg
#audit_axioms HsaBounds.hsaTotalContributionLimit_le_max
#audit_axioms HsaBounds.line12_le_line8
#audit_axioms HsaBounds.hsaTotalDeductibleAmount_bounds

end UsTax.PtcHsa
