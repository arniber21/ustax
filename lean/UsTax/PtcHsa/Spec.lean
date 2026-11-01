/-!
# Specification: Form 8962 Table 5 and the HSA limit ceiling (issue #47)

Readable statements, as the sources print them, that the lemmas of `UsTax/PtcHsa/Lemmas.lean`
compare the code against. This file imports no calculator module; review it, not the code.

* **Table 5** (Instructions for Form 8962 (2024), `sources/forms-instructions/i8962--2024.pdf`
  p 17), the repayment limitation of IRC 36B(f)(2)(B), indexed for 2024:

  | Line 5 is                       | Single | Any other filing status |
  |---------------------------------|--------|-------------------------|
  | Less than 200                   | $375   | $750                    |
  | At least 200 but less than 300  | $950   | $1,900                  |
  | At least 300 but less than 400  | $1,575 | $3,150                  |
  | 400 or more                     | none   | none                    |

  "Single" is the column of a taxpayer whose tax is determined under IRC 1(c) (filing status
  Single); every other filing status takes the other column.
* **HSA ceiling**: one Form 8889 line 8 is at most the family limit plus the catch-up amount,
  $8,300 + $1,000 = $9,300 (Rev. Proc. 2023-23 section 3.04, `rp-23-23.pdf` p 2; IRC 223(b)(3)(B)).
-/

namespace UsTax.PtcHsa.Spec

/-- Table 5 rows as printed, in dollars: (line 5 is less than, Single, any other filing status). -/
def table5 : List (Int × Int × Int) :=
  [(200, 375, 750), (300, 950, 1_900), (400, 1_575, 3_150)]

/-- The Table 5 limitation in cents for line 5 `percent`: the first row whose bound `percent` is
below, in the Single column when `single`; `none` at 400 or more ("no repayment limitation"). -/
def table5Limit (single : Bool) (percent : Rat) : Option Int :=
  (table5.find? fun row => percent < (row.1 : Rat)).map fun row =>
    (if single then row.2.1 else row.2.2) * 100

/-- The largest Table 5 amount, $3,150, in cents. -/
def table5Max : Int := 315_000

/-- A repayment (Form 8962 line 29) respects Table 5: never negative, never more than the excess
APTC (line 27), and at most the Table 5 amount when the table limits it. -/
def RepaymentWithinTable5 (single : Bool) (percent : Rat) (excess repayment : Int) : Prop :=
  0 ≤ repayment ∧ repayment ≤ excess ∧
    ∀ c, table5Limit single percent = some c → repayment ≤ c

/-- Rev. Proc. 2023-23 section 3.04: $8,300 family limit plus the $1,000 catch-up, in cents. -/
def hsaFilerLimitMax : Int := 930_000

/-! ### Named examples (CLAUDE.md section 4) -/

example : table5Limit true 190 = some 37_500 := by decide
example : table5Limit false 190 = some 75_000 := by decide
example : table5Limit true 200 = some 95_000 := by decide
example : table5Limit false 399 = some 315_000 := by decide
example : table5Limit true 400 = none := by decide
-- Satisfiable: Single at 250 percent repaying $950 of a $2,000 excess.
example : RepaymentWithinTable5 true 250 200_000 95_000 := by
  refine ⟨by decide, by decide, fun c h => ?_⟩
  have : table5Limit true 250 = some 95_000 := by decide
  rw [this] at h; cases h; decide
-- Rejected: repaying the whole $2,000 excess at 250 percent (Single).
example : ¬ RepaymentWithinTable5 true 250 200_000 200_000 := fun h =>
  absurd (h.2.2 95_000 (by decide)) (by decide)
-- Rejected: the other-column $1,900 for a Single filer at 250 percent.
example : ¬ RepaymentWithinTable5 true 250 200_000 190_000 := fun h =>
  absurd (h.2.2 95_000 (by decide)) (by decide)
-- Rejected: a negative repayment.
example : ¬ RepaymentWithinTable5 false 150 10_000 (-1) := fun h => absurd h.1 (by decide)

end UsTax.PtcHsa.Spec
