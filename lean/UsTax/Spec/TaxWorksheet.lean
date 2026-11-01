import UsTax.Types

/-!
# Spec: line 16 from $100,000 is the 2024 Tax Computation Worksheet (issue #63)

Main theorems 5c and 5d (`UsTax.Main.tentativeTax_matches_worksheet`,
`UsTax.Main.line16_matches_worksheet`, stated in
`UsTax/Comparator/Challenge.lean`): when line 15 is $100,000 or more, line 16
of Form 1040 is `worksheetTax`. Below $100,000 the Tax Table applies
(`Spec/TaxTable.lean`, theorems 5a and 5b).

Source: Form 1040 instructions, `sources/forms-instructions/i1040gi--2024.pdf`.

* p 33, line 16: "If your taxable income is $100,000 or more, use the Tax
  Computation Worksheet right after the Tax Table."
* p 76, "2024 Tax Computation Worksheet—Line 16": Sections A (single),
  B (married filing jointly or qualifying surviving spouse), C (married filing
  separately), D (head of household). In the row that applies to line 15:
  (a) line 15, (b) the multiplication amount, (c) = (a) × (b), (d) the
  subtraction amount, tax = (c) − (d).
* p 23, "Rounding Off to Whole Dollars": "drop amounts under 50 cents and
  increase amounts from 50 to 99 cents to the next dollar".

`worksheetRow` is the p 76 table, typed from the PDF: the bounds, column (b)
and column (d) of every row. Derivation (not trusted, checked): each (d) is
`X × R − B` for the Rev. Proc. 2023-34 § 3.01 row "over $X: $B plus R% of the
excess over $X", so (c) − (d) is the rate-schedule tax. `Proofs/TaxWorksheet.lean`
checks every row against the rate schedules and proves the theorem.

Rounding. Money is integer cents. Column (c) is rounded to the cent (it is
entered on the form in dollars and cents) and the tax to the whole dollar
(p 23), both half up. Every amount here is positive, where half up is the
same as half away from zero.

This file imports only `FilingStatus`, not the calculator.
-/

namespace UsTax.Spec

/-- `n / d` rounded to the nearest integer, halves up, for `d > 0`. Lean's `/`
on a positive divisor is floor division. -/
def roundHalfUp (n d : Int) : Int := (2 * n + d) / (2 * d)

/-- The row of the Tax Computation Worksheet (p 76) that applies to line 15
`ti` (cents, at least $100,000): (column (b) in percent, column (d) in cents).
Upper bounds are "not over", inclusive. -/
def worksheetRow : FilingStatus → Int → Int × Int
  | .single, ti =>                                    -- Section A
    if ti ≤ 100_525_00 then (22, 4_947_00)
    else if ti ≤ 191_950_00 then (24, 6_957_50)
    else if ti ≤ 243_725_00 then (32, 22_313_50)
    else if ti ≤ 609_350_00 then (35, 29_625_25)
    else (37, 41_812_25)
  | .marriedFilingJointly, ti | .qualifyingSurvivingSpouse, ti =>  -- Section B
    if ti ≤ 201_050_00 then (22, 9_894_00)
    else if ti ≤ 383_900_00 then (24, 13_915_00)
    else if ti ≤ 487_450_00 then (32, 44_627_00)
    else if ti ≤ 731_200_00 then (35, 59_250_50)
    else (37, 73_874_50)
  | .marriedFilingSeparately, ti =>                   -- Section C
    if ti ≤ 100_525_00 then (22, 4_947_00)
    else if ti ≤ 191_950_00 then (24, 6_957_50)
    else if ti ≤ 243_725_00 then (32, 22_313_50)
    else if ti ≤ 365_600_00 then (35, 29_625_25)
    else (37, 36_937_25)
  | .headOfHousehold, ti =>                           -- Section D
    if ti ≤ 100_500_00 then (22, 6_641_00)
    else if ti ≤ 191_950_00 then (24, 8_651_00)
    else if ti ≤ 243_700_00 then (32, 24_007_00)
    else if ti ≤ 609_350_00 then (35, 31_318_00)
    else (37, 43_505_00)

/-- **Line 16 by the Tax Computation Worksheet**, cents in, cents out: (c) =
line 15 × (b) rounded to the cent, minus (d), rounded to the whole dollar. -/
def worksheetTax (fs : FilingStatus) (ti : Int) : Int :=
  let c := roundHalfUp (ti * (worksheetRow fs ti).1) 100
  roundHalfUp (c - (worksheetRow fs ti).2) 100 * 100

/-- Single, line 15 $185,400: (c) = $44,496.00, (d) = $6,957.50, tax
$37,538.50, entered as $37,539. -/
theorem worksheetTax_example : worksheetTax .single 185_400_00 = 37_539_00 := by decide

/-- Rejected: rounding $37,538.50 down. -/
example : worksheetTax .single 185_400_00 ≠ 37_538_00 := by decide

/-- Rejected: the Section B (joint) row used for a single filer
($185,400 × 22% − $9,894 = $30,894). -/
example : worksheetTax .single 185_400_00 ≠ 30_894_00 := by decide

/-- Rejected: 24% of the whole income with nothing subtracted. -/
example : worksheetTax .single 185_400_00 ≠ 44_496_00 := by decide

/-- Rejected: Section A used for married filing separately. At $400,000,
Section C (37% row from $365,600) gives $111,062.75, entered as $111,063;
Section A (35% row) would give $110,375. -/
example : worksheetTax .marriedFilingSeparately 400_000_00 = 111_063_00 ∧
    worksheetTax .marriedFilingSeparately 400_000_00 ≠ 110_375_00 := by decide

end UsTax.Spec
