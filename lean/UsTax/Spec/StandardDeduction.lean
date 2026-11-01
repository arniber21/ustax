import UsTax.Types

/-!
# Spec: the standard deduction, Form 1040 line 12 (issue #64)

IRC 63(c) as indexed for 2024 by Rev. Proc. 2023-34 § 3.15, written the way
the statute reads. Amounts in cents. Imports only `FilingStatus`.

* 63(c)(1): standard deduction = basic standard deduction + additional
  standard deduction;
* 63(c)(2), § 3.15(1): the basic amount by filing status;
* 63(f), § 3.15(3): one additional amount per "item" (the filer, or the
  spouse whose exemption the filer could claim, is 65 or older; is blind),
  $1,550 if married or a surviving spouse, $1,950 if unmarried;
* 63(c)(5), § 3.15(2): for someone who can be claimed as a dependent, the
  basic amount is limited to the greater of $1,300 and earned income plus
  $450; the additional amounts are still added.

Who counts as an item (the spouse rules) is not restated here: the theorem
takes the item count from the calculator and states its range separately
(`Proofs/StandardDeduction.lean`).
-/

namespace UsTax.Spec

/-- IRC 63(c)(2), Rev. Proc. 2023-34 § 3.15(1): the basic standard deduction. -/
def basicStandardDeduction : FilingStatus → Int
  | .marriedFilingJointly => 29_200_00
  | .qualifyingSurvivingSpouse => 29_200_00
  | .headOfHousehold => 21_900_00
  | .single => 14_600_00
  | .marriedFilingSeparately => 14_600_00

/-- IRC 63(f)(1) to (3), Rev. Proc. 2023-34 § 3.15(3): the additional amount
per item, $1,950 for an unmarried filer (single, head of household), $1,550
otherwise (married, surviving spouse). -/
def additionalAmountPerItem : FilingStatus → Int
  | .single => 1_950_00
  | .headOfHousehold => 1_950_00
  | _ => 1_550_00

/-- IRC 63(c)(1) and (5): the standard deduction for filing status `fs`,
`items` additional items, whether the filer can be claimed as a dependent,
and earned income (cents). -/
def standardDeductionSpec (fs : FilingStatus) (items : Int) (canBeClaimed : Bool)
    (earnedIncome : Int) : Int :=
  let additional := items * additionalAmountPerItem fs
  if canBeClaimed then min (basicStandardDeduction fs) (max 1_300_00 (earnedIncome + 450_00)) + additional
  else basicStandardDeduction fs + additional

/-- Single, 65 or older (one item): $14,600 + $1,950 = $16,550. -/
example : standardDeductionSpec .single 1 false 0 = 16_550_00 := by decide

/-- A dependent with $5,000 of wages: $5,450. -/
example : standardDeductionSpec .single 0 true 5_000_00 = 5_450_00 := by decide

/-- Rejected: a dependent's limitation must not drop the additional amount
(blind dependent, $500 of wages: $1,300 + $1,950 = $3,250, not $1,300). -/
example : standardDeductionSpec .single 1 true 500_00 ≠ 1_300_00 := by decide

/-- Rejected: a surviving spouse gets the joint amount, not the single one. -/
example : standardDeductionSpec .qualifyingSurvivingSpouse 0 false 0 ≠ 14_600_00 := by decide

end UsTax.Spec
