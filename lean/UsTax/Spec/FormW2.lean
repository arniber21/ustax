import UsTax.Types
import UsTax.Spec.Rounding

/-!
# Spec: W-2 totals and the two W-2 knockouts (issue #64)

Amounts in cents. Imports only `FilingStatus` and `Spec.Rounding`.

* Form 1040 line 1a and line 25a: the total of box 1 (wages) and of box 2
  (federal income tax withheld) of all Forms W-2, each entered in whole
  dollars (instructions p 21: "round off cents to whole dollars").
* Additional Medicare Tax, IRC 3101(b)(2) and Form 8959 (not supported, so a
  knockout): due when Medicare wages (box 5) exceed $250,000 on a joint
  return, $125,000 married filing separately, $200,000 otherwise. Employers
  withhold it on wages over $200,000 (IRC 3102(f)), so on a joint return a
  spouse over $200,000 also needs Form 8959 (to claim the withholding).
* Excess social security tax withheld, Schedule 3 line 11 (not supported, so
  a knockout): a filer with more than one employer whose social security
  wages (box 3), each capped at the 2024 wage base $168,600, add up to more
  than $168,600.
-/

namespace UsTax.Spec

/-- Total of one W-2 box over all W-2s, each box rounded to the dollar, and the
total rounded again (a no-op on whole dollars). Lines 1a and 25a. -/
def totalOfBox (amounts : List Int) : Int :=
  roundToDollar (amounts.map roundToDollar).sum

/-- IRC 3101(b)(2): the Additional Medicare Tax threshold. -/
def additionalMedicareThreshold : FilingStatus → Int
  | .marriedFilingJointly => 250_000_00
  | .marriedFilingSeparately => 125_000_00
  | _ => 200_000_00

/-- Form 8959 is needed: total Medicare wages over the threshold, or on a
joint return either spouse's Medicare wages over $200,000. Arguments: the
filing status and the box 5 amounts (whole dollars) of the primary filer's and
the spouse's W-2s. -/
def needsForm8959 (fs : FilingStatus) (primaryBox5 spouseBox5 : List Int) : Bool :=
  decide (primaryBox5.sum + spouseBox5.sum > additionalMedicareThreshold fs) ||
    (fs == .marriedFilingJointly &&
      (decide (primaryBox5.sum > 200_000_00) || decide (spouseBox5.sum > 200_000_00)))

/-- Excess social security withholding is possible for one filer: more than one
W-2, and their box 3 amounts, each capped at $168,600, total more than
$168,600. -/
def excessSocialSecurityPossible (box3 : List Int) : Bool :=
  decide (box3.length > 1) && decide ((box3.map (min 168_600_00)).sum > 168_600_00)

/-- Two W-2s of $1,000.40 each: line 1a is $2,000. -/
example : totalOfBox [1_000_40, 1_000_40] = 2_000_00 := by decide

/-- Single, $150,000 + $60,000: Form 8959 is needed. -/
example : needsForm8959 .single [150_000_00, 60_000_00] [] = true := by decide

/-- Joint, $210,000 and $30,000: total $240,000 is under $250,000, but one
spouse is over $200,000. -/
example : needsForm8959 .marriedFilingJointly [210_000_00] [30_000_00] = true := by decide

/-- Rejected: joint with $150,000 each ($300,000 total) does not escape. -/
example : needsForm8959 .marriedFilingJointly [150_000_00] [150_000_00] ≠ false := by decide

/-- Two jobs, $100,000 each: excess withholding is possible; one job of
$200,000 is not (the employer stops at the wage base). -/
example : excessSocialSecurityPossible [100_000_00, 100_000_00] = true ∧
    excessSocialSecurityPossible [200_000_00] = false := by decide

/-- Rejected: rounding only the total (two W-2s of $1,000.40 would give
$2,001). -/
example : totalOfBox [1_000_40, 1_000_40] ≠ 2_001_00 := by decide

end UsTax.Spec
