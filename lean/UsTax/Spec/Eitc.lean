/-!
# Spec: EITC bounds (issues #63, #67), PENDING

Main theorem 4 (pending: the Lean EITC is not written yet, #46). Its
statement is a template in `UsTax/Comparator/Pending.lean`: for every case,
the credit the calculator computes satisfies `EitcWithinBounds`.

Amounts from Rev. Proc. 2023-34 § 3.06(1) (tax year 2024), the same numbers as
`catala/params_2024.catala_en`, typed in again here from the Rev. Proc. so
that the spec does not import the implementation's parameters. Amounts in
cents.

This file does not import the calculator.
-/

namespace UsTax.Spec

/-- The facts the EITC bounds depend on. Eligibility (age, residency,
investment income, ...) is not part of this spec (#67 "out of scope"). -/
structure EitcCase where
  /-- Number of qualifying children (3 means "3 or more"). -/
  qualifyingChildren : Nat
  /-- Married filing jointly: the joint phase-out column. Every other status
  (single, head of household, qualifying surviving spouse, married filing
  separately under the separated-spouse rule) uses the other column. -/
  marriedFilingJointly : Bool
  /-- Earned income, cents. -/
  earnedIncome : Int
  /-- Adjusted gross income, cents. -/
  agi : Int

/-- Rev. Proc. 2023-34 § 3.06(1), "Maximum Amount of Credit": $632, $4,213,
$6,960, $7,830 for 0, 1, 2, 3 or more qualifying children. -/
def eitcMaxCredit : Nat → Int
  | 0 => 632_00
  | 1 => 4_213_00
  | 2 => 6_960_00
  | _ => 7_830_00

/-- Rev. Proc. 2023-34 § 3.06(1), "Completed Phaseout Amount": the income at
which the credit reaches zero. -/
def eitcCompletedPhaseout : Nat → Bool → Int
  | 0, false => 18_591_00
  | 1, false => 49_084_00
  | 2, false => 55_768_00
  | _, false => 59_899_00
  | 0, true => 25_511_00
  | 1, true => 56_004_00
  | 2, true => 62_688_00
  | _, true => 66_819_00

/-- The credit is between `$0` and the maximum credit for the number of
children, and it is `$0` once the larger of AGI and earned income reaches the
completed phase-out amount (IRC 32(a)(2)(B): the phase-out applies to AGI "or,
if greater, the earned income"). -/
def EitcWithinBounds (c : EitcCase) (credit : Int) : Prop :=
  0 ≤ credit ∧ credit ≤ eitcMaxCredit c.qualifyingChildren ∧
    (eitcCompletedPhaseout c.qualifyingChildren c.marriedFilingJointly ≤ max c.earnedIncome c.agi →
      credit = 0)

/-- Satisfiable: single, one child, $15,000 earned income and AGI, credit
$4,213 (the maximum: the phase-in ends at $12,390 and the phase-out starts at
$22,720). -/
theorem eitcWithinBounds_example :
    EitcWithinBounds ⟨1, false, 15_000_00, 15_000_00⟩ 4_213_00 := by
  unfold EitcWithinBounds; simp only [eitcMaxCredit, eitcCompletedPhaseout]; omega

/-- Rejected: more than the maximum credit for one child. -/
theorem not_eitcWithinBounds_above_max :
    ¬ EitcWithinBounds ⟨1, false, 15_000_00, 15_000_00⟩ 4_214_00 := by
  unfold EitcWithinBounds; simp only [eitcMaxCredit, eitcCompletedPhaseout]; omega

/-- Rejected: a credit at the completed phase-out ($49,084, single, one
child). -/
theorem not_eitcWithinBounds_after_phaseout :
    ¬ EitcWithinBounds ⟨1, false, 30_000_00, 49_084_00⟩ 100 := by
  unfold EitcWithinBounds; simp only [eitcMaxCredit, eitcCompletedPhaseout]; omega

/-- Rejected: a negative credit. -/
theorem not_eitcWithinBounds_negative :
    ¬ EitcWithinBounds ⟨0, true, 10_000_00, 10_000_00⟩ (-100) := by
  unfold EitcWithinBounds; omega

end UsTax.Spec
