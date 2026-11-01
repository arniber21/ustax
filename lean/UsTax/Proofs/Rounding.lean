import UsTax.Spec.Rounding
import UsTax.Money.Lemmas
import UsTax.Lists

/-!
# The calculator's roundings are the spec's (issue #64)

`Money.roundDollar` (Catala `round of money`) is `Spec.roundToDollar`, and
`Money.mulRate c (p/100)` (Catala `money * decimal`) is `Spec.percentOf p c`,
for every amount. Bridge lemmas for the module proofs in this directory.
-/

namespace UsTax.Proofs

open Money

/-- `roundDiv` (the calculator's) is `roundHalfAway` (the spec's) for an even divisor `2k`. -/
theorem roundDiv_eq_roundHalfAway (a k : Int) :
    roundDiv a (2 * k) = Spec.roundHalfAway a (2 * k) := by
  unfold roundDiv Spec.roundHalfAway
  have h2 : 2 * k / 2 = k := by omega
  rw [h2]
  split
  · rw [show 2 * -a + 2 * k = 2 * (-a + k) by omega, Int.mul_ediv_mul_of_pos _ _ (by omega)]
  · rw [show 2 * a + 2 * k = 2 * (a + k) by omega, Int.mul_ediv_mul_of_pos _ _ (by omega)]

/-- `Money.roundDollar` is `Spec.roundToDollar`. -/
theorem roundDollar_eq_spec (c : Int) : roundDollar c = Spec.roundToDollar c := by
  rw [roundDollar_eq]; unfold Spec.roundToDollar Spec.roundHalfAway; split <;> omega

/-- `money * (p / 100)` is `Spec.percentOf p`. -/
theorem mulRate_eq_percentOf (c p : Int) :
    mulRate c ((p : Rat) / ((100 : Int) : Rat)) = Spec.percentOf p c := by
  rw [mulRate_div _ _ _ (by decide)]
  unfold roundDiv Spec.percentOf Spec.roundHalfAway; split <;> omega

/-- `Spec.roundToDollar` is monotone. -/
theorem roundToDollar_mono {a b : Int} (h : a ≤ b) : Spec.roundToDollar a ≤ Spec.roundToDollar b := by
  rw [← roundDollar_eq_spec, ← roundDollar_eq_spec]; exact roundDollar_mono h

/-- `Spec.roundToDollar` leaves whole dollars alone. -/
theorem roundToDollar_of_emod {c : Int} (h : c % 100 = 0) : Spec.roundToDollar c = c := by
  unfold Spec.roundToDollar Spec.roundHalfAway; split <;> omega

/-- `Spec.roundToDollar` gives whole dollars. -/
theorem roundToDollar_emod (c : Int) : Spec.roundToDollar c % 100 = 0 := by
  unfold Spec.roundToDollar Spec.roundHalfAway; split <;> omega

/-- The calculator's `sumBy f l` is the plain list sum of `f` over `l`. -/
theorem sumBy_eq_sum {α} (f : α → Int) (l : List α) : sumBy f l = (l.map f).sum := by
  induction l with
  | nil => rfl
  | cons x xs ih => rw [sumBy_cons, ih, List.map_cons, List.sum_cons]

end UsTax.Proofs
