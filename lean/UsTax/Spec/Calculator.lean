import UsTax.Api.Response

/-!
# Spec: the whole return and the API answer (issues #48, #65, #66)

Properties of `Calculator.calculator` and `ApiCalculator.apiCalculator` beyond the Form 1040
ones (`RefundOrBalanceDue`, `CreditsWithinLiability`, which the whole return satisfies too):

* `CreditsWithinTax`: the three credits limited by line 18 in Direct File's order (child and
  dependent care, Schedule R, Saver's: Form 2441 line 10, Schedule R Credit Limit Worksheet line 3
  "line 18 less CDCC", Form 8880 line 11 "line 18 less CDCC and Schedule R") together never
  exceed line 18 (IRC 26(a): the nonrefundable credits are limited by the tax).
* `KnockoutSound`: a return is unsupported (HTTP 422) exactly when the response lists at least one
  reason (`docs/api.md`: "`reasons` is non-empty when `supported` is false").
* `RefundOutcome`: the response `outcome` is `refund` exactly when line 34 (overpaid) is positive
  (`docs/api.md`: "`refund` if line 34 > 0").

This file does not import the calculator.
-/

namespace UsTax.Spec

/-- The child and dependent care credit, the credit for the elderly or disabled and the Saver's
credit together never exceed the tax they are limited by. Amounts in cents. -/
def CreditsWithinTax (cdcc edc savers tax : Int) : Prop :=
  cdcc + edc + savers ≤ tax

/-- Satisfiable: tax $1,000, credits $600 + $200 + $200. -/
theorem creditsWithinTax_example : CreditsWithinTax 60_000 20_000 20_000 100_000 := by
  unfold CreditsWithinTax; omega

/-- Rejected: each credit limited by the full tax instead of the tax left after the earlier ones. -/
theorem not_creditsWithinTax_each_full : ¬ CreditsWithinTax 100_000 100_000 100_000 100_000 := by
  unfold CreditsWithinTax; omega

/-- A return is unsupported exactly when at least one reason is reported. -/
def KnockoutSound {α} (supported : Bool) (reasons : List α) : Prop :=
  supported = false ↔ reasons ≠ []

/-- Satisfiable: a supported return with no reason. -/
theorem knockoutSound_supported : KnockoutSound true ([] : List Nat) := by
  simp [KnockoutSound]

/-- Satisfiable: an unsupported return with one reason. -/
theorem knockoutSound_unsupported : KnockoutSound false [7] := by
  simp [KnockoutSound]

/-- Rejected: a 422 with an empty reason list. -/
theorem not_knockoutSound_silent : ¬ KnockoutSound false ([] : List Nat) := by
  simp [KnockoutSound]

/-- Rejected: a supported return that still lists a reason. -/
theorem not_knockoutSound_stray : ¬ KnockoutSound true [7] := by
  simp [KnockoutSound]

/-- The outcome is `refund` exactly when line 34 is positive. -/
def RefundOutcome (outcome : Api.Outcome) (overpayment : Int) : Prop :=
  outcome = .refund ↔ 0 < overpayment

/-- Satisfiable: a $981 refund. -/
theorem refundOutcome_example : RefundOutcome .refund 98_100 := by
  simp [RefundOutcome]

/-- Satisfiable: nothing overpaid, an amount owed. -/
theorem refundOutcome_balance : RefundOutcome .balanceDue 0 := by
  simp [RefundOutcome]

/-- Rejected: `refund` with nothing overpaid. -/
theorem not_refundOutcome_zero : ¬ RefundOutcome .refund 0 := by
  simp [RefundOutcome]

/-- Rejected: `even` for a $1 refund. -/
theorem not_refundOutcome_even : ¬ RefundOutcome .even 100 := by
  simp [RefundOutcome]

end UsTax.Spec
