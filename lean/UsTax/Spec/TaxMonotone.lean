/-!
# Spec: line 16 is nonnegative and monotone (issues #63, #64)

Main theorem 1 (`UsTax.Main.tentativeTax_nonneg_monotone`, stated in
`UsTax/Comparator/Challenge.lean`): for every filing status, the tax on
taxable income is `NonnegMonotone` as a function of taxable income.

This file does not import the calculator. It only says what the property is.
-/

namespace UsTax.Spec

/-- `f` never gives a negative amount, and a larger input never gives a
smaller output: `0 ≤ f x` for every `x`, and `a ≤ b → f a ≤ f b`.
Monotone, not strictly monotone: the Tax Table gives the same tax for every
income in a row. -/
def NonnegMonotone (f : Int → Int) : Prop :=
  (∀ x, 0 ≤ f x) ∧ ∀ a b, a ≤ b → f a ≤ f b

/-- Satisfiable: a flat 10% tax on the nonnegative part of the income (cents,
floored) has the property. -/
theorem nonnegMonotone_example : NonnegMonotone (fun x => max 0 x / 10) := by
  constructor
  · intro x; dsimp only; omega
  · intro a b h; dsimp only; omega

/-- Rejected: a tax that goes down when income goes up (a "cliff" that gives
$100 below $10,000 and $0 from $10,000). -/
theorem not_nonnegMonotone_cliff :
    ¬ NonnegMonotone (fun x => if x < 1_000_000 then 10_000 else 0) := by
  intro ⟨_, h⟩
  have := h 999_999 1_000_000 (by omega)
  simp at this

/-- Rejected: a negative tax (a refundable amount where line 16 should be). -/
theorem not_nonnegMonotone_negative : ¬ NonnegMonotone (fun x => x - 100) := by
  intro ⟨h, _⟩
  have := h 0
  dsimp only at this; omega

end UsTax.Spec
