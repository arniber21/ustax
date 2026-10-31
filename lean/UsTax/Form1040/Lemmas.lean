import UsTax.Form1040
import UsTax.Money.Lemmas
import UsTax.Audit

/-!
# Refund and balance due are exclusive (issues #43, #65)

For **every** input of `Form1040` (every filing status, every W-2 and interest
list, every plug-in slot) the code that runs satisfies:

* `overpayment_eq_zero_or_balanceDue_eq_zero`: line 34 (refund) or line 37
  (amount you owe) is `$0`; a return never shows both;
* `overpayment_nonneg`, `balanceDue_nonneg`: neither is negative;
* `taxableIncome_nonneg`: line 15 is never negative.

Pure arithmetic about `positive`: of `p - t` and `t - p` one is `≤ 0`. The
statements were property-tested first (`UsTax/Form1040/Props.lean`). The
dedicated proof issue (#65) may add more (for example that the refund is
payments minus tax); only these cheap ones are stated now.
-/

namespace UsTax.Form1040

open Money

/-- Of `positive (p - t)` and `positive (t - p)` one is zero, so after
rounding one of the two amounts is `$0`. -/
theorem refund_or_owe_zero (p t : Int) :
    roundDollar (positive (p - t)) = 0 ∨ roundDollar (positive (t - p)) = 0 := by
  by_cases h : p ≤ t
  · left; rw [positive_of_nonpos (by omega), roundDollar_zero]
  · right; rw [positive_of_nonpos (by omega), roundDollar_zero]

/-- Line 34 or line 37 is `$0`: refund and balance due are exclusive. -/
theorem overpayment_eq_zero_or_balanceDue_eq_zero (i : Form1040In) :
    (form1040 i).overpayment = 0 ∨ (form1040 i).balanceDue = 0 :=
  refund_or_owe_zero _ _

/-- Line 34 is never negative. -/
theorem overpayment_nonneg (i : Form1040In) : 0 ≤ (form1040 i).overpayment :=
  roundDollar_nonneg (positive_nonneg _)

/-- Line 37 is never negative. -/
theorem balanceDue_nonneg (i : Form1040In) : 0 ≤ (form1040 i).balanceDue :=
  roundDollar_nonneg (positive_nonneg _)

/-- Line 15, taxable income, is never negative. -/
theorem taxableIncome_nonneg (i : Form1040In) : 0 ≤ (form1040 i).taxableIncome :=
  roundDollar_nonneg (positive_nonneg _)

/- Hypotheses are satisfiable (the theorems have none): a concrete return (single, one
W-2 of $50,000 with $5,000 withheld) with a refund of $981 and no balance due. -/
#guard (form1040 (run [{ writableWages := 5_000_000, writableFederalWithholding := 500_000 }])).overpayment
    == 98_100

/-- A rejected bad output: a refund and a balance due together. -/
example : ¬ ((form1040 (run [{ writableWages := 5_000_000, writableFederalWithholding := 500_000 }])).overpayment > 0
    ∧ (form1040 (run [{ writableWages := 5_000_000, writableFederalWithholding := 500_000 }])).balanceDue > 0) := by
  intro ⟨a, b⟩
  have := overpayment_eq_zero_or_balanceDue_eq_zero
    (run [{ writableWages := 5_000_000, writableFederalWithholding := 500_000 }])
  omega

end UsTax.Form1040

#audit_axioms UsTax.Form1040.overpayment_eq_zero_or_balanceDue_eq_zero
#audit_axioms UsTax.Form1040.overpayment_nonneg
#audit_axioms UsTax.Form1040.balanceDue_nonneg
#audit_axioms UsTax.Form1040.taxableIncome_nonneg
#spec_surface UsTax.Form1040.overpayment_eq_zero_or_balanceDue_eq_zero
#print axioms UsTax.Form1040.overpayment_eq_zero_or_balanceDue_eq_zero
