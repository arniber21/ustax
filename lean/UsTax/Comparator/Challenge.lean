import UsTax.Spec.TaxMonotone
import UsTax.Spec.RefundBalance
import UsTax.Spec.Credits
import UsTax.Spec.TaxTable
import UsTax.Spec.TaxWorksheet
import UsTax.TaxRates
import UsTax.Form1040

/-!
# Trusted statements for `lake comparator` (issues #63, #70; docs/comparator.md)

This module is the *challenge*: the main theorems a reviewer has read and
trusts, each with a `sorry` proof. `lean/comparator.json` names it together
with the *solution* module `UsTax.Proofs.Main`, which must prove theorems of
the same names whose statements, and every definition they mention, are
identical after elaboration, using only `propext`, `Quot.sound`,
`Classical.choice`.

The `sorry`s are intended. This module is not imported by `UsTax.lean`, so it
is not a default target, and `lake check` does not see it. Never import it.

Imports: the property definitions (`UsTax/Spec/*.lean`, which do not import
the calculator) and the calculator's definitions (`tentativeTaxFor`,
`form1040`), never a module with proofs. The statements are about the code
that runs. What each mentions, transitively, is listed and reviewed in
`docs/spec-surface.md`.

Main theorems not proved yet (EITC, credit wiring) are in
`UsTax/Comparator/Pending.lean`, not here: comparator requires every listed
theorem to be proved.
-/

namespace UsTax.Main

open UsTax.Spec UsTax.TaxRates UsTax.Form1040

/-- (1) Line 16, the tax on taxable income, is never negative and never
decreases when taxable income grows, for every filing status. -/
theorem tentativeTax_nonneg_monotone (fs : FilingStatus) :
    NonnegMonotone (fun ti => tentativeTaxFor ti fs) := by
  sorry

/-- (2) On every return, refund (line 34) and amount owed (line 37) are
nonnegative, at most one is nonzero, and refund minus amount owed is payments
(line 33) minus total tax (line 24). -/
theorem refund_balanceDue_consistent (i : Form1040In) :
    RefundOrBalanceDue (form1040 i).totalTax (form1040 i).totalPayments
      (form1040 i).overpayment (form1040 i).balanceDue := by
  sorry

/-- (3a) On every return, line 22 is line 18 minus the nonrefundable credits
of line 21, floored at zero: the credits used never exceed the tax. -/
theorem credits_within_liability (i : Form1040In) :
    CreditsWithinLiability (form1040 i).totalTentativeTax (form1040 i).nonRefundableCredits
      (form1040 i).taxLessNonRefundableCredits := by
  sorry

/-- (3b) On every return, total tax (line 24) is never negative. -/
theorem totalTax_nonneg (i : Form1040In) : 0 ≤ (form1040 i).totalTax := by
  sorry

/-- (5a) For every filing status and taxable income, line 16 as computed is the
amount printed in the 2024 Tax Table. -/
theorem tentativeTax_matches_tax_table (fs : FilingStatus) (ti : Int) :
    MatchesTaxTable fs ti (tentativeTaxFor ti fs) := by
  sorry

/-- (5b) On every return, line 16 is the Tax Table amount for line 15 and the
filing status. -/
theorem line16_matches_tax_table (i : Form1040In) :
    MatchesTaxTable i.filingStatus (form1040 i).taxableIncome
      (form1040 i).tentativeTaxFromTaxableIncome := by
  sorry

/-- (5c) For every filing status and taxable income from $100,000 (up to the
code's $1-trillion sentinel), line 16 as computed is the 2024 Tax Computation
Worksheet amount. -/
theorem tentativeTax_matches_worksheet (fs : FilingStatus) (ti : Int)
    (h1 : 100_000_00 ≤ ti) (h2 : ti ≤ 1_000_000_000_000_00) :
    tentativeTaxFor ti fs = worksheetTax fs ti := by
  sorry

/-- (5d) On every return with line 15 from $100,000 (up to the sentinel),
line 16 is the Tax Computation Worksheet amount for line 15 and the filing
status. -/
theorem line16_matches_worksheet (i : Form1040In)
    (h1 : 100_000_00 ≤ (form1040 i).taxableIncome)
    (h2 : (form1040 i).taxableIncome ≤ 1_000_000_000_000_00) :
    (form1040 i).tentativeTaxFromTaxableIncome =
      worksheetTax i.filingStatus (form1040 i).taxableIncome := by
  sorry

end UsTax.Main
