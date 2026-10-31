import UsTax.TaxRates
import UsTax.Money.Lemmas

/-!
# Readable specification of Form 1040 line 16, and the proof the code meets it

`taxSpec` is line 16 written the way the sources print it, for a reviewer to
check against them line by line:

* the Tax Table midpoint (`taxTableIncome`): Form 1040 instructions pp 64 to
  65 (rows of $5 to $25, then $25 rows to $3,000, then $50 rows to $100,000;
  the tax of a row is the tax on its midpoint), and the exact income from
  $100,000 (Tax Computation Worksheet, p 76);
* the rate tables of Rev. Proc. 2023-34 § 3.01 in their printed form,
  "Over $X but not over $Y: $B plus R% of the excess over $X"
  (`taxOnIncome`), with an open-ended top row as printed;
* the result rounded to the whole dollar, ties away from zero.

The only arithmetic is integer cents, `pctOf` (Catala `money * decimal`:
rounds R% of an amount to the cent) and `roundDollar`.

The code that runs (`UsTax/TaxRates.lean`) is the marginal form of the Catala
source: a sum over seven bracket slices with a $1-trillion sentinel as the top
bound. `tentativeTaxFor_eq_taxSpec` proves the two equal for **every**
taxable income up to that sentinel and every filing status. Above it the
Catala marginal form (and so the Lean code) stops taxing; no return reaches
it. `tentativeTaxCumulativeFor_eq_taxSpec` proves the same for Catala's
cumulative form. Together these replace the sampled `TestFormsAgree` and
`TestSchedulesChain` of `catala/tests/test_tax_rates.catala_en` by proofs.
-/

namespace UsTax.TaxRates

open Money

/-- `R%` of `m` cents, rounded to the cent (ties away from zero): Catala
`m * R%`. -/
def pctOf (p m : Int) : Int := mulRate m (pct p)

/-- The Tax Table midpoint for taxable income `ti` (cents), or `ti` itself
from $100,000. Integer division `/` is floor division (the income is positive
where it is used). -/
def taxTableIncome (ti : Int) : Int :=
  if ti ≤ 0 then 0
  else if ti < usd 5 then 250            -- row [0, 5): midpoint $2.50
  else if ti < usd 15 then usd 10        -- row [5, 15)
  else if ti < usd 25 then usd 20        -- row [15, 25)
  else if ti < usd 3_000 then ti / usd 25 * usd 25 + 1250   -- $25 rows
  else if ti < usd 100_000 then ti / usd 50 * usd 50 + usd 25  -- $50 rows
  else ti

/-- Rev. Proc. 2023-34 § 3.01, Tables 1 to 4, as printed: tax on `x` cents
(`x ≥ 0`), before rounding to the dollar. -/
def taxOnIncome : FilingStatus → Int → Int
  | .marriedFilingJointly, x | .qualifyingSurvivingSpouse, x =>   -- Table 1
    if x ≤ usd 23_200 then pctOf 10 x
    else if x ≤ usd 94_300 then usd 2_320 + pctOf 12 (x - usd 23_200)
    else if x ≤ usd 201_050 then usd 10_852 + pctOf 22 (x - usd 94_300)
    else if x ≤ usd 383_900 then usd 34_337 + pctOf 24 (x - usd 201_050)
    else if x ≤ usd 487_450 then usd 78_221 + pctOf 32 (x - usd 383_900)
    else if x ≤ usd 731_200 then usd 111_357 + pctOf 35 (x - usd 487_450)
    else usd 196_669 + 50 + pctOf 37 (x - usd 731_200)
  | .headOfHousehold, x =>                                          -- Table 2
    if x ≤ usd 16_550 then pctOf 10 x
    else if x ≤ usd 63_100 then usd 1_655 + pctOf 12 (x - usd 16_550)
    else if x ≤ usd 100_500 then usd 7_241 + pctOf 22 (x - usd 63_100)
    else if x ≤ usd 191_950 then usd 15_469 + pctOf 24 (x - usd 100_500)
    else if x ≤ usd 243_700 then usd 37_417 + pctOf 32 (x - usd 191_950)
    else if x ≤ usd 609_350 then usd 53_977 + pctOf 35 (x - usd 243_700)
    else usd 181_954 + 50 + pctOf 37 (x - usd 609_350)
  | .single, x =>                                                   -- Table 3
    if x ≤ usd 11_600 then pctOf 10 x
    else if x ≤ usd 47_150 then usd 1_160 + pctOf 12 (x - usd 11_600)
    else if x ≤ usd 100_525 then usd 5_426 + pctOf 22 (x - usd 47_150)
    else if x ≤ usd 191_950 then usd 17_168 + 50 + pctOf 24 (x - usd 100_525)
    else if x ≤ usd 243_725 then usd 39_110 + 50 + pctOf 32 (x - usd 191_950)
    else if x ≤ usd 609_350 then usd 55_678 + 50 + pctOf 35 (x - usd 243_725)
    else usd 183_647 + 25 + pctOf 37 (x - usd 609_350)
  | .marriedFilingSeparately, x =>                                  -- Table 4
    if x ≤ usd 11_600 then pctOf 10 x
    else if x ≤ usd 47_150 then usd 1_160 + pctOf 12 (x - usd 11_600)
    else if x ≤ usd 100_525 then usd 5_426 + pctOf 22 (x - usd 47_150)
    else if x ≤ usd 191_950 then usd 17_168 + 50 + pctOf 24 (x - usd 100_525)
    else if x ≤ usd 243_725 then usd 39_110 + 50 + pctOf 32 (x - usd 191_950)
    else if x ≤ usd 365_600 then usd 55_678 + 50 + pctOf 35 (x - usd 243_725)
    else usd 98_334 + 75 + pctOf 37 (x - usd 365_600)

/-- **Specification of Form 1040 line 16** (no capital-gain worksheets): the
rate table of the filing status applied to the Tax Table midpoint, rounded to
the whole dollar. Cents in, cents out. -/
def taxSpec (fs : FilingStatus) (ti : Int) : Int :=
  roundDollar (taxOnIncome fs (taxTableIncome ti))

/-- A named example: single, taxable income $50,000 is in the Tax Table row
[$50,000, $50,050), midpoint $50,025, tax $6,059 (as printed). -/
example : taxTableIncome (usd 50_000) = usd 50_025 := by decide

/-! ## Proof: the code equals the specification

Method: every `money * R%` is `roundDiv (m * R) 100` (`mulRate_pct`); a slice
of a whole-dollar bracket below the income is exact (`mulRate_pct_whole`);
each bracket slice is `0`, the part of the income inside the bracket, or the
whole bracket (`slice_below`, `slice_inside`, `slice_above`, with disjoint
conditions). After splitting on the row of the statutory table, `simp` with
`omega` as discharger picks the case of each slice and `omega` closes the
linear goal. No `decide` on `Rat`, no `native_decide`. -/

section Refinement

/-- `m * R%` is `roundDiv (m * R) 100` on integers. -/
theorem mulRate_pct (m p : Int) : mulRate m (pct p) = roundDiv (m * p) 100 :=
  mulRate_div m p 100 (by decide)

/-- A nonnegative percentage is a nonnegative decimal. -/
theorem pct_nonneg {p : Int} (hp : 0 ≤ p) : 0 ≤ pct p := by
  unfold pct; rw [div_eq_divInt]; exact Rat.divInt_nonneg hp (by decide)

/-- R% of a whole-dollar amount is exact. -/
theorem mulRate_pct_whole {m : Int} (p : Int) (h : m % 100 = 0) :
    mulRate m (pct p) = m / 100 * p := by
  obtain ⟨k, rfl⟩ : ∃ k, m = 100 * k := ⟨m / 100, by omega⟩
  rw [mulRate_pct, Int.mul_ediv_cancel_left k (by decide),
    show 100 * k * p = k * p * 100 by rw [Int.mul_assoc, Int.mul_comm],
    roundDiv_mul_self _ (by decide)]

/-- A bracket entirely above the income contributes nothing. -/
theorem slice_below {x l u : Int} {r : Rat} (h : x ≤ l) :
    mulRate (positive (Money.min x u - l)) r = 0 := by
  rw [positive_of_nonpos (by have := Money.min_le_left x u; omega), mulRate_zero_left]

/-- The bracket containing the income contributes R% of the part above its bottom. -/
theorem slice_inside {x l u : Int} {r : Rat} (h1 : l < x) (h2 : x ≤ u) :
    mulRate (positive (Money.min x u - l)) r = mulRate (x - l) r := by
  rw [Money.min_eq_left h2, positive_of_nonneg (by omega)]

/-- A bracket entirely below the income contributes R% of its whole width. -/
theorem slice_above {x l u : Int} {r : Rat} (h1 : l ≤ u) (h2 : u < x) :
    mulRate (positive (Money.min x u - l)) r = mulRate (u - l) r := by
  rw [Money.min_eq_right (by omega), positive_of_nonneg (by omega)]

/-! The three slice lemmas for a bracket starting at `$0` (after `simp` has
removed the `- 0`). -/

/-- `slice_below` for a bracket starting at `$0`. -/
theorem slice0_below {x u : Int} {r : Rat} (h : x ≤ 0) :
    mulRate (positive (Money.min x u)) r = 0 := by
  simpa using slice_below (u := u) (r := r) h

/-- `slice_inside` for a bracket starting at `$0`. -/
theorem slice0_inside {x u : Int} {r : Rat} (h1 : 0 < x) (h2 : x ≤ u) :
    mulRate (positive (Money.min x u)) r = mulRate x r := by
  simpa using slice_inside (r := r) h1 h2

/-- `slice_above` for a bracket starting at `$0`. -/
theorem slice0_above {x u : Int} {r : Rat} (h1 : 0 ≤ u) (h2 : u < x) :
    mulRate (positive (Money.min x u)) r = mulRate u r := by
  simpa using slice_above (r := r) h1 h2

/-- Below the sentinel, Catala's marginal form of each schedule is the printed
"$B plus R% of the excess" table. This checks, for every income, that the
printed bases chain (each $B is the tax on the row's lower bound). -/
theorem marginalTax_eq_taxOnIncome (fs : FilingStatus) {x : Int} (h0 : 0 ≤ x)
    (h1 : x ≤ noUpperBound) : marginalTax (scheduleFor fs) x = taxOnIncome fs x := by
  simp only [noUpperBound, usd] at h1
  rcases Int.lt_or_eq_of_le h0 with h0 | rfl <;>
  cases fs <;>
    simp only [scheduleFor, marginalTax, scheduleMfjQss, scheduleHeadOfHousehold, scheduleSingle,
      scheduleMarriedSeparate, taxOnIncome, List.map_cons, List.map_nil, sum_cons, sum_nil,
      pctOf, usd, noUpperBound] <;>
    repeat' split
  all_goals
    simp (disch := omega) only [slice_below, slice_inside, slice_above, slice0_below,
      slice0_inside, slice0_above, mulRate_pct_whole, Int.zero_mul, Int.sub_zero]
    omega

/-- Catala's cumulative form (`cumulative_tax`: the one row with
`lower < x ≤ upper`, "$B plus R% of the excess") is the printed table too. The
rows of each schedule are therefore disjoint and cover `(0, sentinel]`: the
`list ... such that` filter never selects two rows or none. -/
theorem cumulativeTax_eq_taxOnIncome (fs : FilingStatus) {x : Int} (h0 : 0 ≤ x)
    (h1 : x ≤ noUpperBound) : cumulativeTax (scheduleFor fs) x = taxOnIncome fs x := by
  simp only [noUpperBound, usd] at h1
  rcases Int.lt_or_eq_of_le h0 with h0 | rfl
  · -- split on the row of the printed table first, with `cumulativeTax` folded
    cases fs <;> simp only [taxOnIncome, pctOf, usd] <;> repeat' split
    all_goals
      simp only [cumulativeTax, scheduleFor, scheduleMfjQss, scheduleHeadOfHousehold,
        scheduleSingle, scheduleMarriedSeparate, usd, noUpperBound]
      rw [ite_eq_right (by omega : ¬ x ≤ 0)]
      simp (disch := (simp only [decide_eq_true_eq]; omega)) only
        [List.filter_cons_of_pos, List.filter_cons_of_neg, List.filter_nil]
      simp only [List.map_cons, List.map_nil, sum_cons, sum_nil, Int.zero_mul, Int.sub_zero]
      omega
  · cases fs <;> simp (disch := omega) only [cumulativeTax, taxOnIncome, pctOf, usd, ite_eq_left,
      mulRate_zero_left]

/-- The two forms of the Tax Table midpoint agree: Catala's (through Direct
File's `StepwiseMultiply`, on rationals) and the integer one. -/
theorem roundedTaxableIncomeOf_eq (ti : Int) : roundedTaxableIncomeOf ti = taxTableIncome ti := by
  unfold roundedTaxableIncomeOf taxTableIncome
  rw [stepwiseMultiply_eq _ _ _ (by decide), stepwiseMultiply_eq _ _ _ (by decide)]
  simp only [usd, tdiv_eq_if]
  repeat' split
  all_goals omega

/-- The midpoint is never negative. -/
theorem taxTableIncome_nonneg (ti : Int) : 0 ≤ taxTableIncome ti := by
  unfold taxTableIncome; simp only [usd]; repeat' split
  all_goals omega

/-- The midpoint is monotone in taxable income. -/
theorem taxTableIncome_mono {a b : Int} (h : a ≤ b) : taxTableIncome a ≤ taxTableIncome b := by
  unfold taxTableIncome; simp only [usd]; repeat' split
  all_goals omega

/-- The midpoint stays below the sentinel when the income does. -/
theorem taxTableIncome_le {ti : Int} (h : ti ≤ noUpperBound) : taxTableIncome ti ≤ noUpperBound := by
  unfold taxTableIncome noUpperBound at *; simp only [usd] at *; repeat' split
  all_goals omega

/-- **The code meets the specification**: for every filing status and every
taxable income up to the $1-trillion sentinel, Form 1040 line 16 as computed
(`tentativeTaxFor`, Catala's marginal form) equals `taxSpec`. -/
theorem tentativeTaxFor_eq_taxSpec (fs : FilingStatus) {ti : Int} (h : ti ≤ noUpperBound) :
    tentativeTaxFor ti fs = taxSpec fs ti := by
  unfold tentativeTaxFor taxSpec
  rw [roundedTaxableIncomeOf_eq,
    marginalTax_eq_taxOnIncome fs (taxTableIncome_nonneg ti) (taxTableIncome_le h)]

/-- Catala's second output, by the cumulative form, meets the same
specification. -/
theorem tentativeTaxCumulativeFor_eq_taxSpec (fs : FilingStatus) {ti : Int}
    (h : ti ≤ noUpperBound) : tentativeTaxCumulativeFor ti fs = taxSpec fs ti := by
  unfold tentativeTaxCumulativeFor taxSpec
  rw [roundedTaxableIncomeOf_eq,
    cumulativeTax_eq_taxOnIncome fs (taxTableIncome_nonneg ti) (taxTableIncome_le h)]

/-- The scope `TentativeTax`, all three outputs, against the specification. -/
theorem tentativeTax_spec (i : TentativeTaxIn) (h : i.taxableIncome ≤ noUpperBound) :
    tentativeTax i =
      { roundedTaxableIncome := taxTableIncome i.taxableIncome
        tentativeTaxFromTaxableIncome := taxSpec i.filingStatus i.taxableIncome
        tentativeTaxCumulativeForm := taxSpec i.filingStatus i.taxableIncome } := by
  simp only [tentativeTax, roundedTaxableIncomeOf_eq, tentativeTaxFor_eq_taxSpec _ h,
    tentativeTaxCumulativeFor_eq_taxSpec _ h]

/-- Above the sentinel the marginal form stops growing; this is the one place
where the Catala source (and so the code) departs from the statute, and it is
never reached ($1 trillion of taxable income). -/
example : tentativeTaxFor (noUpperBound + usd 1_000_000) .single
    ≠ taxSpec .single (noUpperBound + usd 1_000_000) := by
  rw [tentativeTaxFor, roundedTaxableIncomeOf, taxSpec, taxTableIncome]
  simp (disch := omega) only [noUpperBound, usd, ite_eq_right, marginalTax, scheduleFor,
    scheduleSingle, List.map_cons, List.map_nil, sum_cons, sum_nil, taxOnIncome, pctOf,
    mulRate_pct_whole, Int.zero_mul, Int.sub_zero, mulRate_pct,
    roundDollar_eq_roundDiv]
  decide

end Refinement

/-! ## The specification on concrete inputs

The theorems above have one hypothesis, `ti ≤ noUpperBound`; it is
satisfiable (every Tax Table income meets it). The specification rejects
known-bad outputs (CLAUDE.md section 4). Values are computed by rewriting
every `money * R%` to integers (`mulRate_pct`) and `decide`. -/

section Examples
open FilingStatus

/-- Every hypothesis discharged on a concrete input: single, $14,999. -/
example : tentativeTaxFor (usd 14_999) single = taxSpec single (usd 14_999) :=
  tentativeTaxFor_eq_taxSpec single (by decide)

/-- `taxSpec` evaluated: the Tax Table row [$14,975, $15,000) gives $1,565. -/
theorem taxSpec_single_14999 : taxSpec single (usd 14_999) = usd 1_565 := by
  simp only [taxSpec, taxOnIncome, pctOf, mulRate_pct, roundDollar_eq_roundDiv]; decide

/-- Without the midpoint (tax on the exact $14,999) the answer would be
$1,568; the specification rejects it. -/
example : taxSpec single (usd 14_999) ≠ usd 1_568 := by
  rw [taxSpec_single_14999]; decide

/-- Copying the Rev. Proc. typo ("excess over $191,150") for single at
$200,000 would give $41,943; the specification gives $41,687. -/
example : taxSpec single (usd 200_000) = usd 41_687 ∧ taxSpec single (usd 200_000) ≠ usd 41_943 := by
  simp only [taxSpec, taxOnIncome, pctOf, mulRate_pct, roundDollar_eq_roundDiv]; decide

/-- The married-filing-jointly table is not the single table. -/
example : taxSpec marriedFilingJointly (usd 100_000) ≠ taxSpec single (usd 100_000) := by
  simp only [taxSpec, taxOnIncome, pctOf, mulRate_pct, roundDollar_eq_roundDiv]; decide

/-- A flat 10% would be wrong above the first bracket. -/
example : taxSpec single (usd 50_000) ≠ usd 5_000 := by
  simp only [taxSpec, taxOnIncome, pctOf, mulRate_pct, roundDollar_eq_roundDiv]; decide

/-- Ties round away from zero: MFJ at $731,200 is $196,669.50, line 16 is
$196,670 (half-to-even would give $196,670 too, so also check $3,000 single:
midpoint $3,025, 10% = $302.50, line 16 $303, where half-to-even gives $302). -/
example : taxSpec marriedFilingJointly (usd 731_200) = usd 196_670 ∧
    taxSpec single (usd 3_000) = usd 303 := by
  simp only [taxSpec, taxOnIncome, pctOf, mulRate_pct, roundDollar_eq_roundDiv]; decide

end Examples

end UsTax.TaxRates

#audit_axioms UsTax.TaxRates.tentativeTaxFor_eq_taxSpec
#audit_axioms UsTax.TaxRates.tentativeTaxCumulativeFor_eq_taxSpec
#audit_axioms UsTax.TaxRates.tentativeTax_spec
#spec_surface UsTax.TaxRates.tentativeTaxFor_eq_taxSpec
