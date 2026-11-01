/-!
# Spec: refund and balance due (issues #63, #65)

Main theorem 2 (`UsTax.Main.refund_balanceDue_consistent`, stated in
`UsTax/Comparator/Challenge.lean`): for every return, lines 24, 33, 34 and 37
of Form 1040 satisfy `RefundOrBalanceDue`.

Form 1040: line 34 "If line 33 is more than line 24, subtract line 24 from
line 33. This is the amount you overpaid"; line 37 "Subtract line 33 from
line 24. This is the amount you owe". Amounts in cents.

This file does not import the calculator.
-/

namespace UsTax.Spec

/-- Line 34 (`overpayment`) and line 37 (`balanceDue`) are consistent with
line 24 (`totalTax`) and line 33 (`totalPayments`):

* neither is negative;
* at most one is nonzero (a return shows a refund or an amount owed, not
  both);
* their difference is payments minus tax, exactly (no cent lost or added).

Together these force `overpayment = max 0 (totalPayments - totalTax)` and
`balanceDue = max 0 (totalTax - totalPayments)`
(`RefundOrBalanceDue.overpayment_eq`). -/
def RefundOrBalanceDue (totalTax totalPayments overpayment balanceDue : Int) : Prop :=
  0 ≤ overpayment ∧ 0 ≤ balanceDue ∧ (overpayment = 0 ∨ balanceDue = 0) ∧
    overpayment - balanceDue = totalPayments - totalTax

/-- The predicate determines both lines: the refund is the excess of payments
over tax, the amount owed the excess of tax over payments. -/
theorem RefundOrBalanceDue.overpayment_eq {t p o b : Int} (h : RefundOrBalanceDue t p o b) :
    o = max 0 (p - t) ∧ b = max 0 (t - p) := by
  obtain ⟨_, _, _ | _, _⟩ := h <;> omega

/-- Satisfiable: tax $4,019, payments $5,000, refund $981, nothing owed. -/
theorem refundOrBalanceDue_example : RefundOrBalanceDue 401_900 500_000 98_100 0 := by
  unfold RefundOrBalanceDue; omega

/-- Rejected: a refund and an amount owed on the same return. -/
theorem not_refundOrBalanceDue_both : ¬ RefundOrBalanceDue 401_900 500_000 98_200 100 := by
  unfold RefundOrBalanceDue; omega

/-- Rejected: a refund off by one cent. -/
theorem not_refundOrBalanceDue_off_by_one : ¬ RefundOrBalanceDue 401_900 500_000 98_101 0 := by
  unfold RefundOrBalanceDue; omega

/-- Rejected: a negative amount owed standing in for a refund. -/
theorem not_refundOrBalanceDue_negative : ¬ RefundOrBalanceDue 401_900 500_000 0 (-98_100) := by
  unfold RefundOrBalanceDue; omega

end UsTax.Spec
