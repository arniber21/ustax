import UsTax.Form1040
import UsTax.Money.Lemmas

/-!
# Lemmas for main theorems 2 and 3: lines 22, 24, 34, 37 (issues #65, #66)

Every amount on these lines is `roundDollar` of something, so a whole number
of dollars, and `roundDollar` leaves whole dollars alone. So the `positive`
(floor at zero) on lines 22, 34 and 37 is the only thing between the code and
"`max 0` of the difference". No `Nat` anywhere: amounts are `Int` cents, so
there is no truncating subtraction.
-/

namespace UsTax.Proofs

open Money hiding max min
open Form1040

/-- `roundDollar` leaves a whole number of dollars unchanged. -/
theorem roundDollar_of_emod {x : Int} (h : x % 100 = 0) : roundDollar x = x := by
  obtain ⟨k, rfl⟩ : ∃ k, x = 100 * k := ⟨x / 100, by omega⟩
  exact roundDollar_mul_100 k

/-- `Money.positive` is `max 0`. -/
theorem positive_eq_max (x : Int) : positive x = max 0 x := by
  unfold positive Money.floor Money.max; split <;> omega

/-- `roundDollar (positive (a - b))` of whole-dollar amounts is `max 0 (a - b)`. -/
theorem roundDollar_positive_sub {a b : Int} (ha : a % 100 = 0) (hb : b % 100 = 0) :
    roundDollar (positive (a - b)) = max 0 (a - b) := by
  rw [positive_eq_max]
  exact roundDollar_of_emod (by omega)

/-- Line 34 as computed. -/
theorem overpayment_eq (i : Form1040In) :
    (form1040 i).overpayment = max 0 ((form1040 i).totalPayments - (form1040 i).totalTax) :=
  roundDollar_positive_sub (roundDollar_emod _) (roundDollar_emod _)

/-- Line 37 as computed. -/
theorem balanceDue_eq (i : Form1040In) :
    (form1040 i).balanceDue = max 0 ((form1040 i).totalTax - (form1040 i).totalPayments) :=
  roundDollar_positive_sub (roundDollar_emod _) (roundDollar_emod _)

/-- Line 22 as computed. -/
theorem taxLessNonRefundableCredits_eq (i : Form1040In) :
    (form1040 i).taxLessNonRefundableCredits =
      max 0 ((form1040 i).totalTentativeTax - (form1040 i).nonRefundableCredits) :=
  roundDollar_positive_sub (roundDollar_emod _) (roundDollar_emod _)

/-- Line 24 is line 22 (line 23, other taxes, is not added yet: QUIRK(Q3) in
`UsTax/Form1040.lean`). -/
theorem totalTax_eq (i : Form1040In) :
    (form1040 i).totalTax = (form1040 i).taxLessNonRefundableCredits :=
  roundDollar_idem _

end UsTax.Proofs
