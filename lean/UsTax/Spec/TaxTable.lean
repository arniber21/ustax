import UsTax.Types
import UsTax.TaxRates.TaxTableData

/-!
# Spec: line 16 equals the printed 2024 Tax Table (issue #63)

Main theorem 5 (`UsTax.Main.line16_matches_tax_table`, stated in
`UsTax/Comparator/Challenge.lean`): for every return, line 16 of Form 1040
`MatchesTaxTable` line 15.

The reference is the Tax Table printed in the Form 1040 instructions
(`sources/forms-instructions/i1040gi--2024.pdf` pp 64 to 75), not Direct File
and not the rate schedules. Its 2,060 rows are the generated data
`UsTax.TaxRates.TaxTable.rows` (`UsTax/TaxRates/TaxTableData.lean`, from
`sources/forms-instructions/derived-tax-table-2024.csv`). That data is part of
this spec: a wrong row would make the theorem say the wrong thing.

The table covers taxable income below $100,000. Above that the property says
nothing (no row contains the income). The data also lacks the printed rows
[$5, $15) and [$15, $25) (see `docs/spec-surface.md`).

This file imports the data and `FilingStatus`, not the calculator.
-/

namespace UsTax.Spec

open UsTax.TaxRates.TaxTable (Row rows)

/-- `d` whole dollars, in cents. -/
def dollars (d : Int) : Int := d * 100

/-- The tax printed in row `r` for filing status `fs`, whole dollars. The
table has four columns; qualifying surviving spouse uses the married filing
jointly column (Form 1040 instructions, Tax Table header). -/
def printedTax (r : Row) : FilingStatus → Int
  | .single => r.single
  | .marriedFilingJointly => r.mfj
  | .qualifyingSurvivingSpouse => r.mfj
  | .marriedFilingSeparately => r.mfs
  | .headOfHousehold => r.hoh

/-- Taxable income `ti` (cents) is in row `r`: "at least" `r.atLeast` dollars
"but less than" `r.butLessThan` dollars. -/
def InRow (r : Row) (ti : Int) : Prop :=
  dollars r.atLeast ≤ ti ∧ ti < dollars r.butLessThan

/-- Line 16 `tax` for line 15 `ti` and filing status `fs` is what the printed
Tax Table says: for every row that contains `ti`, `tax` is that row's amount
in the column of `fs`. -/
def MatchesTaxTable (fs : FilingStatus) (ti tax : Int) : Prop :=
  ∀ r ∈ rows, InRow r ti → tax = dollars (printedTax r fs)

/-- Satisfiable: single, $50,000 is in the row [$50,000, $50,050) and the
printed tax is $6,059. -/
theorem matchesTaxTable_example : MatchesTaxTable .single 50_000_00 6_059_00 := by
  have key : ∀ r ∈ rows, dollars r.atLeast ≤ 50_000_00 ∧ 50_000_00 < dollars r.butLessThan →
      6_059_00 = dollars (printedTax r .single) := by
    unfold dollars printedTax; decide +kernel
  exact key

/-- Rejected: the tax on the exact $50,000 (no midpoint) is $6,053, not the
printed $6,059. -/
theorem not_matchesTaxTable_no_midpoint : ¬ MatchesTaxTable .single 50_000_00 6_053_00 := by
  intro h
  have key : ∃ r ∈ rows, (dollars r.atLeast ≤ 50_000_00 ∧ 50_000_00 < dollars r.butLessThan) ∧
      6_053_00 ≠ dollars (printedTax r .single) := by
    unfold dollars printedTax; decide +kernel
  obtain ⟨r, hr, hin, hne⟩ := key
  exact hne (h r hr hin)

/-- Rejected: the single column used for a married-filing-jointly return. -/
theorem not_matchesTaxTable_wrong_column :
    ¬ MatchesTaxTable .marriedFilingJointly 50_000_00 6_059_00 := by
  intro h
  have key : ∃ r ∈ rows, (dollars r.atLeast ≤ 50_000_00 ∧ 50_000_00 < dollars r.butLessThan) ∧
      6_059_00 ≠ dollars (printedTax r .marriedFilingJointly) := by
    unfold dollars printedTax; decide +kernel
  obtain ⟨r, hr, hin, hne⟩ := key
  exact hne (h r hr hin)

end UsTax.Spec
