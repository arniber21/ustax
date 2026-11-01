import UsTax.TaxRates.Spec
import UsTax.Spec.TaxWorksheet

/-!
# Lemmas for main theorems 5c and 5d: line 16 from $100,000 is the worksheet

Method. From $100,000 the Tax Table midpoint is the income itself, so
`taxSpec` (the Rev. Proc. 2023-34 rate schedules, which the code equals by
`TaxRates.tentativeTaxFor_eq_taxSpec`) is `roundDollar ($B + R% of (ti − $X))`.
R% of `$X` is a whole number of cents, so this is `(ti × R rounded) − (X × R −
B)`: the worksheet with (d) = `X × R − B`. After splitting on the row, `omega`
closes each case; the constants of `worksheetRow` are thus checked against the
rate schedules by the proof. No `decide` on `Rat`, no `native_decide`.

Below the proof, `#guard` tests: the two formulas agree at $100,000, every
$1,000 up to $2,000,000, and one cent either side of every bracket edge, for
all five filing statuses; and each column (d) is `X × R − B` with `X`, `R`,
`B` read from the rate schedules.
-/

namespace UsTax.Proofs

open UsTax.Spec UsTax.TaxRates UsTax.Money

/-- From $100,000 the Tax Table midpoint is the income itself. -/
theorem taxTableIncome_of_ge {ti : Int} (h : 100_000_00 ≤ ti) : taxTableIncome ti = ti := by
  unfold taxTableIncome; simp only [usd]; repeat' split
  all_goals omega

/-- **The rate schedules are the Tax Computation Worksheet** from $100,000, for
every filing status. -/
theorem taxSpec_eq_worksheetTax (fs : FilingStatus) {ti : Int} (h : 100_000_00 ≤ ti) :
    taxSpec fs ti = worksheetTax fs ti := by
  unfold taxSpec
  rw [taxTableIncome_of_ge h]
  -- split on the rate-schedule row, pick the worksheet row by `omega`, then
  -- unfold both roundings (sign cases) and close by linear arithmetic
  cases fs <;>
    simp only [taxOnIncome, worksheetTax, worksheetRow, pctOf, mulRate_pct,
      roundDollar_eq_roundDiv, usd] <;>
    split <;> (try split) <;> (try split) <;> (try split) <;> (try split) <;> (try split) <;>
    (try simp (disch := omega) only [ite_eq_left, ite_eq_right]) <;>
    unfold roundDiv roundHalfUp <;>
    split <;> split <;> omega

/-- **Line 16 as computed is the worksheet** from $100,000 up to the
$1-trillion sentinel of the code (`noUpperBound`). -/
theorem tentativeTaxFor_eq_worksheetTax (fs : FilingStatus) {ti : Int}
    (h1 : 100_000_00 ≤ ti) (h2 : ti ≤ 1_000_000_000_000_00) :
    tentativeTaxFor ti fs = worksheetTax fs ti := by
  rw [tentativeTaxFor_eq_taxSpec fs (by unfold noUpperBound usd; omega),
    taxSpec_eq_worksheetTax fs h1]

/-! ## Tests (compiled, `#guard`)

The theorem above covers every income; these evaluate both sides on concrete
ones, as a check that the worksheet data reads as intended. -/

/-- $100,000, then every $1,000 up to $2,000,000, then one cent below, at and
one cent above every bracket edge of every status. -/
private def worksheetTestIncomes : List Int :=
  (List.range 1901).map (fun (k : Nat) => usd (100_000 + 1_000 * (k : Int))) ++
  ([100_500, 100_525, 191_950, 201_050, 243_700, 243_725, 365_600, 383_900, 487_450,
    609_350, 731_200].flatMap fun e => [usd e - 1, usd e, usd e + 1])

#guard worksheetTestIncomes.all fun ti =>
  FilingStatus.all.all fun fs => taxSpec fs ti == worksheetTax fs ti

#guard worksheetTestIncomes.all fun ti =>
  FilingStatus.all.all fun fs => tentativeTaxFor ti fs == worksheetTax fs ti

-- Derivation of column (d), for each rate-schedule bracket that reaches
-- $100,000: the worksheet row at the bottom of the bracket (or at $100,000) has
-- rate `R` and subtraction `X × R − B` ("over $X: $B plus R% of the excess",
-- `scheduleFor`), and the same row still applies at the top of the bracket.
#guard FilingStatus.all.all fun fs => (scheduleFor fs).all fun b =>
  decide (b.upper < usd 100_000) ||
    (let row := worksheetRow fs (Max.max (b.lower + 1) (usd 100_000))
     pct row.1 == b.rate && row.2 == Money.mulRate b.lower b.rate - b.base &&
       (b.upper == noUpperBound || worksheetRow fs b.upper == row))

end UsTax.Proofs
