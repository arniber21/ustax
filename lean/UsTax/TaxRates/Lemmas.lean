import UsTax.TaxRates.Spec

/-!
# Line 16 is nonnegative and monotone in taxable income (issues #41, #64)

The two key theorems of issue #64 for the rate schedule, proved about the code
that runs (`tentativeTaxFor`, `UsTax/TaxRates.lean`) for **every** taxable
income (negative, beyond the sentinel, any number of cents) and every filing
status, with no hypothesis:

* `tentativeTaxFor_nonneg`: `0 ≤ tentativeTaxFor ti fs`;
* `tentativeTaxFor_mono`: `a ≤ b → tentativeTaxFor a fs ≤ tentativeTaxFor b fs`.

The proofs are pure arithmetic and do not look at the bracket amounts: the
midpoint is monotone (`roundedTaxableIncomeOf`, through its integer form), the
marginal sum of any table with nonnegative rates is monotone and nonnegative
(each slice `positive (min x upper - lower)` is, and `money * rate` with
`rate ≥ 0` keeps the order even with cent rounding), and `roundDollar` is
monotone. The only fact about the 2024 tables used is that every rate is a
nonnegative percentage (`scheduleFor_rate_nonneg`). So they carry over
unchanged to another year's tables.

Both statements were property-tested first (`UsTax/TaxRates/Props.lean`).
-/

namespace UsTax.TaxRates

open Money

/-- Every rate of the 2024 tables is nonnegative. -/
theorem scheduleFor_rate_nonneg (fs : FilingStatus) : ∀ b ∈ scheduleFor fs, 0 ≤ b.rate := by
  intro b hb
  cases fs <;>
    simp only [scheduleFor, scheduleMfjQss, scheduleHeadOfHousehold, scheduleSingle,
      scheduleMarriedSeparate, List.mem_cons, List.not_mem_nil, or_false] at hb <;>
    rcases hb with rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
    exact pct_nonneg (by decide)

/-- The marginal tax of any table with nonnegative rates is nonnegative. -/
theorem marginalTax_nonneg {table : List Bracket} (hr : ∀ b ∈ table, 0 ≤ b.rate) (x : Int) :
    0 ≤ marginalTax table x := by
  unfold marginalTax
  apply sum_nonneg
  intro y hy
  obtain ⟨b, hb, rfl⟩ := List.mem_map.mp hy
  exact mulRate_nonneg (positive_nonneg _) (hr b hb)

/-- The marginal tax of any table with nonnegative rates is monotone in the
income. -/
theorem marginalTax_mono {table : List Bracket} (hr : ∀ b ∈ table, 0 ≤ b.rate) {x y : Int}
    (h : x ≤ y) : marginalTax table x ≤ marginalTax table y := by
  unfold marginalTax
  apply sum_map_le
  intro b hb
  apply mulRate_mono (hr b hb)
  apply positive_mono
  have := Money.min_mono h (Int.le_refl b.upper)
  omega

/-- The Tax Table midpoint is monotone in taxable income. -/
theorem roundedTaxableIncomeOf_mono {a b : Int} (h : a ≤ b) :
    roundedTaxableIncomeOf a ≤ roundedTaxableIncomeOf b := by
  rw [roundedTaxableIncomeOf_eq, roundedTaxableIncomeOf_eq]
  exact taxTableIncome_mono h

/-- **Form 1040 line 16 is never negative**, for every taxable income and
filing status. -/
theorem tentativeTaxFor_nonneg (ti : Int) (fs : FilingStatus) : 0 ≤ tentativeTaxFor ti fs :=
  roundDollar_nonneg (marginalTax_nonneg (scheduleFor_rate_nonneg fs) _)

/-- **Form 1040 line 16 is monotone in taxable income**: more taxable income
never gives less tax, for every filing status. -/
theorem tentativeTaxFor_mono (fs : FilingStatus) {a b : Int} (h : a ≤ b) :
    tentativeTaxFor a fs ≤ tentativeTaxFor b fs :=
  roundDollar_mono (marginalTax_mono (scheduleFor_rate_nonneg fs) (roundedTaxableIncomeOf_mono h))

/-- The same for the specification, wherever it is the code (below the
sentinel). -/
theorem taxSpec_nonneg (fs : FilingStatus) {ti : Int} (h : ti ≤ noUpperBound) :
    0 ≤ taxSpec fs ti := by
  rw [← tentativeTaxFor_eq_taxSpec fs h]; exact tentativeTaxFor_nonneg ti fs

/-- Monotonicity of the specification below the sentinel. -/
theorem taxSpec_mono (fs : FilingStatus) {a b : Int} (h : a ≤ b) (hb : b ≤ noUpperBound) :
    taxSpec fs a ≤ taxSpec fs b := by
  rw [← tentativeTaxFor_eq_taxSpec fs (Int.le_trans h hb), ← tentativeTaxFor_eq_taxSpec fs hb]
  exact tentativeTaxFor_mono fs h

/-- The hypotheses are satisfiable: a concrete instance with every hypothesis
discharged. -/
example : tentativeTaxFor (usd 50_000) .single ≤ tentativeTaxFor (usd 50_050) .single :=
  tentativeTaxFor_mono .single (by decide)

/-- Monotone, not strictly: the whole Tax Table row [$50,000, $50,050) has one
tax, so `tentativeTaxFor` is not injective; a strict statement would be false. -/
example : tentativeTaxFor (usd 50_000) .single = tentativeTaxFor (usd 50_049) .single := by
  simp only [tentativeTaxFor_eq_taxSpec _ (by decide : usd 50_000 ≤ noUpperBound),
    tentativeTaxFor_eq_taxSpec _ (by decide : usd 50_049 ≤ noUpperBound)]
  simp only [taxSpec, taxOnIncome, pctOf, mulRate_pct, roundDollar_eq_roundDiv]; decide

end UsTax.TaxRates

#audit_axioms UsTax.TaxRates.tentativeTaxFor_nonneg
#audit_axioms UsTax.TaxRates.tentativeTaxFor_mono
#audit_axioms UsTax.TaxRates.taxSpec_mono
#spec_surface UsTax.TaxRates.tentativeTaxFor_mono
#print axioms UsTax.TaxRates.tentativeTaxFor_nonneg
#print axioms UsTax.TaxRates.tentativeTaxFor_mono
