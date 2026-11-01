import UsTax.Spec.Rounding

/-!
# Spec: Form 1040 line 26 and the line arithmetic of Form 1040 (issue #64)

Amounts in cents. Imports only `Spec.Rounding`.

**Line 26** (estimated tax payments and amount applied from the 2023
return): the amount paid, in whole dollars (Form 1040 instructions p 21), or
`$0` if the filer says none was paid.

**The line arithmetic** (Form 1040, 2024) is stated directly on the
calculator's output in `UsTax/Proofs/Form1040Lines.lean`, each line as its
form text:

* line 11 (AGI): "Subtract line 10 from line 9";
* line 15 (taxable income): "Subtract line 14 from line 11. If zero or less,
  enter -0-" (`max 0 (line 11 − line 14)`);
* line 33 (total payments): "Add lines 25d, 26, and 32";
* line 24 (total tax) does not decrease when a W-2 with nonnegative wages is
  added and nothing else changes.
-/

namespace UsTax.Spec

/-- Form 1040 line 26: the payment rounded to the dollar, or `$0`. -/
def estimatedPaymentsLine26 (paid : Bool) (amount : Int) : Int :=
  if paid then roundToDollar amount else 0

/-- $500.49 paid: $500. -/
example : estimatedPaymentsLine26 true 500_49 = 500_00 := by decide

/-- Rejected: an amount typed but "no payments" answered still counts as
`$0`, not $500. -/
example : estimatedPaymentsLine26 false 500_00 ≠ 500_00 := by decide

end UsTax.Spec
