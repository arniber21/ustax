import UsTax.Spec.Rounding

/-!
# Spec: taxable interest and the Schedule B threshold (issue #64)

Form 1040 instructions, line 2b, and Schedule B Part I and III
(2024): Schedule B is required if taxable interest is over $1,500 or the
filer had a foreign account or was connected with a foreign trust. On
Schedule B each payer's amount is entered (in whole dollars) and line 2b is
their total; without Schedule B line 2b is the total, rounded once.

Input: the taxable interest of each report (cents), see
`Proofs.reportTaxableInterest`. Imports only `Spec.Rounding`.
-/

namespace UsTax.Spec

/-- Schedule B Part I (line 4 over $1,500) or Part III (foreign account or
trust). -/
def scheduleBRequired (taxableInterest : List Int) (foreignAccountOrTrust : Bool) : Bool :=
  decide (taxableInterest.sum > 1_500_00) || foreignAccountOrTrust

/-- Form 1040 line 2b: with Schedule B, the total of the per-payer amounts each
rounded to the dollar; without it, the total rounded once. -/
def interestLine2b (taxableInterest : List Int) (foreignAccountOrTrust : Bool) : Int :=
  if scheduleBRequired taxableInterest foreignAccountOrTrust then
    roundToDollar (taxableInterest.map roundToDollar).sum
  else roundToDollar taxableInterest.sum

/-- $1,500.00 exactly does not require Schedule B; $1,500.01 does. -/
example : scheduleBRequired [1_500_00] false = false ∧ scheduleBRequired [1_500_01] false = true := by
  decide

/-- Three payers of $500.51: Schedule B is required, each rounds to $501, line
2b is $1,503 (the raw total $1,501.53 would round to $1,502). -/
example : interestLine2b [500_51, 500_51, 500_51] false = 1_503_00 := by decide

/-- Rejected: Schedule B ignored for a foreign account with $10 of interest is
not the rule; it is required. -/
example : scheduleBRequired [10_00] true ≠ false := by decide

/-- Rejected: rounding the total once when Schedule B is required. -/
example : interestLine2b [500_51, 500_51, 500_51] false ≠ 1_502_00 := by decide

end UsTax.Spec
