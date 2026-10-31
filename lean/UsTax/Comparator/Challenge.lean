import UsTax.Money

/-!
# Trusted statements for `lake comparator` (issue #70, docs/comparator.md)

This module is the *challenge*: the statements a reviewer has read and
trusts, each with a `sorry` proof. `lean/comparator.json` names it together
with the *solution* module, which must prove theorems of the same names whose
statements, and every definition they mention, are identical after
elaboration, using only the permitted axioms.

The `sorry`s are intended. This module is not imported by `UsTax.lean`, so it
is not a default target, and `lake check` does not see it. Never import it.

The theorems below are placeholders taken from the money library (#39), so
that the pipeline runs end to end. The main tax theorems (#63) replace them.
-/

namespace UsTax.Money

/-- Integer form of `round of money` (ties away from zero). -/
theorem roundDollar_eq (m : Int) :
    roundDollar m = if m < 0 then -((-m + 50) / 100 * 100) else (m + 50) / 100 * 100 := by
  sorry

theorem roundDollar_mono {m n : Int} (h : m ≤ n) : roundDollar m ≤ roundDollar n := by
  sorry

/-- For `0 ≤ r ≤ 1`, `money * r` does not exceed the amount. -/
theorem mulRate_le_self {m : Int} {r : Rat} (hm : 0 ≤ m) (hr : r ≤ 1) : mulRate m r ≤ m := by
  sorry

end UsTax.Money
