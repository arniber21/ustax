/-!
# Spec: the two roundings the forms use (issue #64)

Amounts are integers of **cents**. The forms round in two ways, both "to the
nearest, halves away from zero":

* to the whole dollar (Form 1040 instructions p 21: "drop amounts under 50
  cents and increase amounts from 50 to 99 cents to the next dollar");
* a percentage of an amount, to the cent (a worksheet line "multiply line X
  by 85%").

They are written here from scratch, with integer division only, so that the
module specs in `UsTax/Spec/` do not depend on the calculator's `Money`
library. `UsTax/Proofs/Rounding.lean` proves they agree with it.

This file imports nothing.
-/

namespace UsTax.Spec

/-- `a / b` rounded to the nearest integer, halves away from zero, for a
positive `b`. (`/` on `Int` with a positive divisor is floor division.) -/
def roundHalfAway (a b : Int) : Int :=
  if a < 0 then -((-a + b / 2) / b) else (a + b / 2) / b

/-- `c` cents rounded to the whole dollar, halves away from zero, in cents. -/
def roundToDollar (c : Int) : Int := roundHalfAway c 100 * 100

/-- `p` percent of `c` cents, rounded to the cent, halves away from zero. -/
def percentOf (p c : Int) : Int := roundHalfAway (c * p) 100

/-- $14.49 → $14, $14.50 → $15, −$14.50 → −$15. -/
example : roundToDollar 1449 = 1400 ∧ roundToDollar 1450 = 1500 ∧ roundToDollar (-1450) = -1500 := by
  decide

/-- 85% of $1.01 is 85.85 cents, so 86 cents; 50% of 3 cents is 1.5, so 2. -/
example : percentOf 85 101 = 86 ∧ percentOf 50 3 = 2 := by decide

/-- Rejected: rounding down (truncation) is not the rule. -/
example : roundToDollar 1450 ≠ 1400 := by decide

end UsTax.Spec
