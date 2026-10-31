import UsTax.Money
import UsTax.Types

/-!
# Tax rate schedules and the Tax Table midpoint: Form 1040 line 16 (issue #41)

Lean implementation of `catala/tax_rates.catala_en` (module `Tax_rates`,
scope `TentativeTax`), written by hand from the Catala source under strategy
(c) of `docs/catala-to-lean.md`. This file is the **code that runs**: the
`ustax` executable and the differential tests call `tentativeTax`.

It follows the Catala text declaration by declaration, with the same names in
lower camel case, so a reviewer can read the two side by side:

| Catala (`Tax_rates`)                 | Lean (`UsTax.TaxRates`)       |
|--------------------------------------|-------------------------------|
| `structure Bracket`                  | `Bracket`                     |
| `no_upper_bound`                     | `noUpperBound`                |
| `schedule_mfj_qss`, ...              | `scheduleMfjQss`, ...         |
| `schedule_for`                       | `scheduleFor`                 |
| `marginal_tax`                       | `marginalTax`                 |
| `cumulative_tax`                     | `cumulativeTax`               |
| `rounded_taxable_income_of`          | `roundedTaxableIncomeOf`      |
| `tentative_tax_for`                  | `tentativeTaxFor`             |
| `tentative_tax_cumulative_for`       | `tentativeTaxCumulativeFor`   |
| `scope TentativeTax` (inputs/outputs)| `TentativeTaxIn` → `TentativeTaxOut` (`tentativeTax`) |

Money is `Int` cents and `decimal` is `Rat` (`UsTax/Money.lean`). Every
Catala `money * decimal` is `Money.mulRate` (rounds to the cent, ties away
from zero) and `R.round_dollar` is `Money.roundDollar`, so the rounding points
are exactly Catala's.

The readable statutory form (`taxSpec`, "$B plus R% of the excess over $X")
and the proof that this code equals it are in `UsTax/TaxRates/Spec.lean`;
nonnegativity and monotonicity are in `UsTax/TaxRates/Lemmas.lean`.

Sources (cited in the Catala file): Rev. Proc. 2023-34 § 3.01 Tables 1 to 4
(`sources/revproc/rp-23-34.pdf` pp 5 to 7); Form 1040 instructions, Tax Table
and Tax Computation Worksheet (`sources/forms-instructions/i1040gi--2024.pdf`
pp 64 to 76); Direct File `taxCalculations.xml` `/roundedTaxableIncome` and
`/tentativeTaxFromTaxableIncome`.
-/

namespace UsTax.TaxRates

open Money

/-- `$d` in cents. -/
abbrev usd (d : Int) : Int := d * 100

/-- Catala `R%` as a decimal: `p / 100`, exact. -/
def pct (p : Int) : Rat := (p : Rat) / ((100 : Int) : Rat)

/-- One row of a rate table: income from `lower` up to `upper` is taxed at
`rate`; `base` is the table's "$B plus ..." amount, the tax on `lower`.
Amounts in cents. -/
structure Bracket where
  /-- "Over $X": the bottom of the bracket, cents. -/
  lower : Int
  /-- "but not over $Y": the top of the bracket, cents (inclusive). -/
  upper : Int
  /-- The marginal rate "R%", as an exact decimal. -/
  rate : Rat
  /-- "$B": the tax on `lower`, cents. -/
  base : Int

/-- Sentinel upper bound of the top bracket: one trillion dollars. Catala
`no_upper_bound`. The marginal form taxes no income above it, as in Catala. -/
def noUpperBound : Int := usd 1_000_000_000_000

/-- Rev. Proc. 2023-34 Table 1, § 1(j)(2)(A): married filing jointly and
qualifying surviving spouse. Catala `schedule_mfj_qss`. -/
def scheduleMfjQss : List Bracket := [
  { lower := usd 0,       upper := usd 23_200,  rate := pct 10, base := usd 0 },
  { lower := usd 23_200,  upper := usd 94_300,  rate := pct 12, base := usd 2_320 },
  { lower := usd 94_300,  upper := usd 201_050, rate := pct 22, base := usd 10_852 },
  { lower := usd 201_050, upper := usd 383_900, rate := pct 24, base := usd 34_337 },
  { lower := usd 383_900, upper := usd 487_450, rate := pct 32, base := usd 78_221 },
  { lower := usd 487_450, upper := usd 731_200, rate := pct 35, base := usd 111_357 },
  { lower := usd 731_200, upper := noUpperBound, rate := pct 37, base := usd 196_669 + 50 }]

/-- Rev. Proc. 2023-34 Table 2, § 1(j)(2)(B): head of household. The printed
32% row says "excess over $191,150", a typo for $191,950 (not copied).
Catala `schedule_head_of_household`. -/
def scheduleHeadOfHousehold : List Bracket := [
  { lower := usd 0,       upper := usd 16_550,  rate := pct 10, base := usd 0 },
  { lower := usd 16_550,  upper := usd 63_100,  rate := pct 12, base := usd 1_655 },
  { lower := usd 63_100,  upper := usd 100_500, rate := pct 22, base := usd 7_241 },
  { lower := usd 100_500, upper := usd 191_950, rate := pct 24, base := usd 15_469 },
  { lower := usd 191_950, upper := usd 243_700, rate := pct 32, base := usd 37_417 },
  { lower := usd 243_700, upper := usd 609_350, rate := pct 35, base := usd 53_977 },
  { lower := usd 609_350, upper := noUpperBound, rate := pct 37, base := usd 181_954 + 50 }]

/-- Rev. Proc. 2023-34 Table 3, § 1(j)(2)(C): single (same $191,150 typo).
Catala `schedule_single`. -/
def scheduleSingle : List Bracket := [
  { lower := usd 0,       upper := usd 11_600,  rate := pct 10, base := usd 0 },
  { lower := usd 11_600,  upper := usd 47_150,  rate := pct 12, base := usd 1_160 },
  { lower := usd 47_150,  upper := usd 100_525, rate := pct 22, base := usd 5_426 },
  { lower := usd 100_525, upper := usd 191_950, rate := pct 24, base := usd 17_168 + 50 },
  { lower := usd 191_950, upper := usd 243_725, rate := pct 32, base := usd 39_110 + 50 },
  { lower := usd 243_725, upper := usd 609_350, rate := pct 35, base := usd 55_678 + 50 },
  { lower := usd 609_350, upper := noUpperBound, rate := pct 37, base := usd 183_647 + 25 }]

/-- Rev. Proc. 2023-34 Table 4, § 1(j)(2)(D): married filing separately.
Same as single through $243,725; the 35% bracket ends at $365,600.
Catala `schedule_married_separate`. -/
def scheduleMarriedSeparate : List Bracket := [
  { lower := usd 0,       upper := usd 11_600,  rate := pct 10, base := usd 0 },
  { lower := usd 11_600,  upper := usd 47_150,  rate := pct 12, base := usd 1_160 },
  { lower := usd 47_150,  upper := usd 100_525, rate := pct 22, base := usd 5_426 },
  { lower := usd 100_525, upper := usd 191_950, rate := pct 24, base := usd 17_168 + 50 },
  { lower := usd 191_950, upper := usd 243_725, rate := pct 32, base := usd 39_110 + 50 },
  { lower := usd 243_725, upper := usd 365_600, rate := pct 35, base := usd 55_678 + 50 },
  { lower := usd 365_600, upper := noUpperBound, rate := pct 37, base := usd 98_334 + 75 }]

/-- The rate table of a filing status. Catala `schedule_for`. -/
def scheduleFor : FilingStatus → List Bracket
  | .marriedFilingJointly => scheduleMfjQss
  | .qualifyingSurvivingSpouse => scheduleMfjQss
  | .headOfHousehold => scheduleHeadOfHousehold
  | .single => scheduleSingle
  | .marriedFilingSeparately => scheduleMarriedSeparate

/-- Tax on `income` by the marginal form: the sum over the brackets of the
rate times the part of `income` inside the bracket, each product rounded to
the cent (Catala `money * decimal`). Not rounded to the dollar.
Catala `marginal_tax`. -/
def marginalTax (table : List Bracket) (income : Int) : Int :=
  Money.sum (table.map fun b =>
    mulRate (Money.positive (Money.min income b.upper - b.lower)) b.rate)

/-- Tax on `income` by the cumulative form, "$B plus R% of the excess over
$X" for the row containing `income` (`lower < income ≤ upper`). `0` for
`income ≤ 0`. Catala `cumulative_tax`. -/
def cumulativeTax (table : List Bracket) (income : Int) : Int :=
  if income ≤ 0 then 0 else
  Money.sum ((table.filter fun b => decide (income > b.lower ∧ income ≤ b.upper)).map
    fun b => b.base + mulRate (income - b.lower) b.rate)

/-- Direct File `/roundedTaxableIncome`: the Tax Table midpoint below
$100,000, the income itself from $100,000. Catala `rounded_taxable_income_of`. -/
def roundedTaxableIncomeOf (taxableIncome : Int) : Int :=
  if taxableIncome ≤ 0 then 0
  else if taxableIncome < 500 then 250
  else if taxableIncome < 1500 then usd 10
  else if taxableIncome < 2500 then usd 20
  else if taxableIncome < usd 3_000 then stepwiseMultiply taxableIncome 25 25 + 1250
  else if taxableIncome < usd 100_000 then stepwiseMultiply taxableIncome 50 50 + usd 25
  else taxableIncome

/-- Form 1040 line 16: the marginal tax on the Tax Table midpoint, rounded to
the dollar. Catala `tentative_tax_for`. -/
def tentativeTaxFor (taxableIncome : Int) (filingStatus : FilingStatus) : Int :=
  roundDollar (marginalTax (scheduleFor filingStatus) (roundedTaxableIncomeOf taxableIncome))

/-- The same by the cumulative form. Catala `tentative_tax_cumulative_for`. -/
def tentativeTaxCumulativeFor (taxableIncome : Int) (filingStatus : FilingStatus) : Int :=
  roundDollar (cumulativeTax (scheduleFor filingStatus) (roundedTaxableIncomeOf taxableIncome))

/-! ## The scope `TentativeTax` -/

/-- Inputs of Catala scope `TentativeTax`. -/
structure TentativeTaxIn where
  /-- Form 1040 line 15, taxable income, cents (Direct File `/taxableIncome`). -/
  taxableIncome : Int
  /-- Direct File `/filingStatus`. -/
  filingStatus : FilingStatus
  deriving Repr

/-- Outputs of Catala scope `TentativeTax`, cents. -/
structure TentativeTaxOut where
  /-- Direct File `/roundedTaxableIncome`. -/
  roundedTaxableIncome : Int
  /-- Direct File `/tentativeTaxFromTaxableIncome`: Form 1040 line 16. -/
  tentativeTaxFromTaxableIncome : Int
  /-- The same by the cumulative "$B plus R%" form. -/
  tentativeTaxCumulativeForm : Int
  deriving Repr, DecidableEq

/-- Catala scope `TentativeTax`. -/
def tentativeTax (i : TentativeTaxIn) : TentativeTaxOut where
  roundedTaxableIncome := roundedTaxableIncomeOf i.taxableIncome
  tentativeTaxFromTaxableIncome := tentativeTaxFor i.taxableIncome i.filingStatus
  tentativeTaxCumulativeForm := tentativeTaxCumulativeFor i.taxableIncome i.filingStatus

/-! ## Unit tests: every assertion of `catala/tests/test_tax_rates.catala_en`

Amounts in cents. The Tax Table golden test (16,480 checks) is
`UsTax/TaxRates/TaxTable.lean`. -/

section Tests
open FilingStatus

-- TestRoundedTaxableIncome
#guard roundedTaxableIncomeOf 0 = 0
#guard roundedTaxableIncomeOf (-10000) = 0
#guard roundedTaxableIncomeOf 1 = 250
#guard roundedTaxableIncomeOf 499 = 250
#guard roundedTaxableIncomeOf 500 = 1000
#guard roundedTaxableIncomeOf 1499 = 1000
#guard roundedTaxableIncomeOf 1500 = 2000
#guard roundedTaxableIncomeOf 2499 = 2000
#guard roundedTaxableIncomeOf 2500 = 3750
#guard roundedTaxableIncomeOf 4999 = 3750
#guard roundedTaxableIncomeOf 5000 = 6250
#guard roundedTaxableIncomeOf 297500 = 298750
#guard roundedTaxableIncomeOf 299999 = 298750
#guard roundedTaxableIncomeOf 300000 = 302500
#guard roundedTaxableIncomeOf 304999 = 302500
#guard roundedTaxableIncomeOf 9999900 = 9997500
#guard roundedTaxableIncomeOf 10000000 = 10000000
#guard roundedTaxableIncomeOf 12345678 = 12345678

-- TestTentativeTaxSingleBoundaries
#guard tentativeTaxFor 0 single = 0
#guard tentativeTaxFor 400 single = 0
#guard tentativeTaxFor 500 single = 100
#guard tentativeTaxFor 1500 single = 200
#guard tentativeTaxFor 1499900 single = 156500
#guard tentativeTaxFor 1500000 single = 157100
#guard tentativeTaxFor 299999 single = 29900
#guard tentativeTaxFor 300000 single = 30300
#guard tentativeTaxFor 9999900 single = 1704800
#guard tentativeTaxFor 10000000 single = 1705300

-- TestTentativeTaxMarriedJointly
#guard tentativeTaxFor (usd 11_600) marriedFilingJointly = usd 1_163
#guard tentativeTaxFor (usd 58_750) marriedFilingJointly = usd 6_589
#guard tentativeTaxFor (usd 147_675) marriedFilingJointly = usd 22_595
#guard tentativeTaxFor (usd 292_475) marriedFilingJointly = usd 56_279
#guard tentativeTaxFor (usd 435_675) marriedFilingJointly = usd 94_789
#guard tentativeTaxFor (usd 609_325) marriedFilingJointly = usd 154_013
#guard tentativeTaxFor (usd 732_200) marriedFilingJointly = usd 197_040
#guard tentativeTaxFor (usd 10_000_000) marriedFilingJointly = usd 3_626_126
#guard tentativeTaxFor (usd 201_050) marriedFilingJointly = usd 34_337
#guard tentativeTaxFor (usd 731_200) marriedFilingJointly = usd 196_670

-- TestTentativeTaxQualifyingSurvivingSpouse
#guard tentativeTaxFor (usd 11_600) qualifyingSurvivingSpouse = usd 1_163
#guard tentativeTaxFor (usd 147_675) qualifyingSurvivingSpouse = usd 22_595
#guard tentativeTaxFor (usd 732_200) qualifyingSurvivingSpouse = usd 197_040
example : scheduleFor qualifyingSurvivingSpouse = scheduleFor marriedFilingJointly := rfl

-- TestTentativeTaxHeadOfHousehold
#guard tentativeTaxFor (usd 8_275) headOfHousehold = usd 828
#guard tentativeTaxFor (usd 39_825) headOfHousehold = usd 4_448
#guard tentativeTaxFor (usd 81_800) headOfHousehold = usd 11_361
#guard tentativeTaxFor (usd 146_225) headOfHousehold = usd 26_443
#guard tentativeTaxFor (usd 217_825) headOfHousehold = usd 45_697
#guard tentativeTaxFor (usd 426_525) headOfHousehold = usd 117_966
#guard tentativeTaxFor (usd 610_350) headOfHousehold = usd 182_325
#guard tentativeTaxFor (usd 10_000_000) headOfHousehold = usd 3_656_495
#guard tentativeTaxFor (usd 609_350) headOfHousehold = usd 181_955

-- TestTentativeTaxSingle
#guard tentativeTaxFor (usd 5_800) single = usd 583
#guard tentativeTaxFor (usd 29_375) single = usd 3_293
#guard tentativeTaxFor (usd 73_837) single = usd 11_295
#guard tentativeTaxFor (usd 146_237) single = usd 28_139
#guard tentativeTaxFor (usd 217_837) single = usd 47_394
#guard tentativeTaxFor (usd 426_537) single = usd 119_663
#guard tentativeTaxFor (usd 610_350) single = usd 184_017
#guard tentativeTaxFor (usd 10_000_000) single = usd 3_658_188
#guard tentativeTaxFor (usd 609_350) single = usd 183_647

-- TestTentativeTaxMarriedSeparately
#guard tentativeTaxFor (usd 5_800) marriedFilingSeparately = usd 583
#guard tentativeTaxFor (usd 29_375) marriedFilingSeparately = usd 3_293
#guard tentativeTaxFor (usd 73_837) marriedFilingSeparately = usd 11_295
#guard tentativeTaxFor (usd 146_237) marriedFilingSeparately = usd 28_139
#guard tentativeTaxFor (usd 217_837) marriedFilingSeparately = usd 47_394
#guard tentativeTaxFor (usd 304_662) marriedFilingSeparately = usd 77_006
#guard tentativeTaxFor (usd 366_600) marriedFilingSeparately = usd 98_705
#guard tentativeTaxFor (usd 10_000_000) marriedFilingSeparately = usd 3_663_063
#guard tentativeTaxFor (usd 365_600) marriedFilingSeparately = usd 98_335
#guard tentativeTaxFor (usd 366_600) single = usd 98_685

-- TestTentativeTaxScope
#guard tentativeTax { taxableIncome := usd 14_999, filingStatus := single } =
  { roundedTaxableIncome := usd 14_975, tentativeTaxFromTaxableIncome := usd 1_565,
    tentativeTaxCumulativeForm := usd 1_565 }

-- TestBadOutputsRejected
#guard tentativeTaxFor (usd 14_999) single ≠ usd 1_568
#guard tentativeTaxFor (usd 200_000) single = usd 41_687
#guard tentativeTaxFor (usd 200_000) single ≠ usd 41_943
#guard tentativeTaxFor (usd 100_000) marriedFilingJointly ≠ tentativeTaxFor (usd 100_000) single
#guard tentativeTaxFor (usd 50_000) single ≠ usd 5_000

-- TestSchedulesChain: the first bracket starts at $0 with base $0, every later
-- bracket starts at the previous upper bound and its base is the previous base
-- plus the previous rate times the previous width; rates 10 ... 37%; the top
-- bracket is open-ended. (Proved for all four tables in `TaxRates/Spec.lean`.)
private def chains : List Bracket → Bool
  | p :: b :: rest =>
    p.upper == b.lower && b.base == p.base + mulRate (p.upper - p.lower) p.rate && chains (b :: rest)
  | _ => true
private def allTables : List (List Bracket) :=
  [scheduleMfjQss, scheduleHeadOfHousehold, scheduleSingle, scheduleMarriedSeparate]
#guard allTables.all fun t =>
  chains t && (t.head?.map fun b => b.lower == 0 && b.base == 0) == some true
#guard allTables.all fun t => t.map (·.rate) == [10, 12, 22, 24, 32, 35, 37].map pct
#guard allTables.all fun t => t.any (·.upper == noUpperBound)

-- TestFormsAgree (proved for every income in `TaxRates/Spec.lean`)
private def formsAgreeIncomes : List Int :=
  [0, usd 4, usd 15, usd 25, 299999, usd 3_000, usd 11_600, usd 11_650, usd 14_999,
    usd 23_200, usd 23_250, usd 47_150, usd 63_100, usd 94_300, usd 99_999, usd 100_000,
    usd 100_525, usd 100_500, usd 191_950, usd 201_050, usd 243_700, usd 243_725,
    usd 365_600, usd 383_900, usd 487_450, usd 609_350, usd 731_200, 123456789,
    usd 10_000_000]
#guard FilingStatus.all.all fun s => formsAgreeIncomes.all fun x =>
  tentativeTaxFor x s == tentativeTaxCumulativeFor x s
#guard formsAgreeIncomes.all fun x =>
  tentativeTaxFor x qualifyingSurvivingSpouse == tentativeTaxFor x marriedFilingJointly
#guard FilingStatus.all.all fun s => tentativeTaxFor 0 s == 0

end Tests

end UsTax.TaxRates
