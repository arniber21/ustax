import UsTax.Money
import UsTax.Types
import UsTax.Date
import UsTax.Params2024

/-!
# Standard deduction: Form 1040 line 12 (issue #43)

Lean implementation of `catala/standard_deduction.catala_en` (module
`Standard_deduction`, scopes `Age65DayBeforeBirthday` and `StandardDeduction`),
written by hand from the Catala source under strategy (c) of
`docs/catala-to-lean.md`. It is the code that runs. The age rules of
`catala/filers.catala_en` (`completed_years`, `age65OrOlder`, ...) are in
`UsTax/Date.lean`.

| Catala (`Standard_deduction`)                 | Lean (`UsTax.StandardDeduction`) |
|-----------------------------------------------|----------------------------------|
| `scope Age65DayBeforeBirthday`                | `Age65In` → `Age65Out` (`age65DayBeforeBirthday`) |
| `scope StandardDeduction` (inputs/outputs)    | `StandardDeductionIn` → `StandardDeductionOut` (`standardDeduction`) |
| `filer_mfs_and_spouse_is_eligible_...`        | `filerMfsAndSpouseIsEligibleForStandardDeductions` |
| `is_spouse_info_applicable_for_...`           | `isSpouseInfoApplicableForStandardDeductions` |
| `secondary_filer_is_65_or_older_for_deduction`| `secondaryFilerIs65OrOlderForDeduction` |
| `secondary_filer_additional_standard_deduction_items` | `secondaryFilerAdditionalStandardDeductionItems` |
| `additional_standard_deduction_items`         | `additionalStandardDeductionItems` |
| `additional_standard_deduction_multiplier`    | `additionalStandardDeductionMultiplier` |
| `additional_standard_deduction`               | `additionalStandardDeduction` |
| `filing_status_standard_deduction`            | `filingStatusStandardDeduction` |
| `normal_standard_deduction`                   | `normalStandardDeduction` |
| `minimum_standard_deduction`                  | `minimumStandardDeduction` |
| `standard_deduction` (output)                 | `standardDeductionAmount` |

Sources: IRC 63(c) and (f); Rev. Proc. 2023-34 § 3.15; Pub. 501 p 3; Direct
File `standardDeduction.xml`, `filers.xml` (cited in the Catala file).
-/

namespace UsTax.StandardDeduction

open Money

/-! ### Scope `Age65DayBeforeBirthday` -/

/-- Inputs: the birth date and the date at which age is measured. -/
structure Age65In where
  /-- Catala input `date_of_birth`. -/
  dateOfBirth : Date
  /-- Catala input `as_of`. -/
  asOf : Date

/-- Outputs of `Age65DayBeforeBirthday`. -/
structure Age65Out where
  /-- Catala output `age`. -/
  age : Int
  /-- Catala output `is_65_or_older`. -/
  is65OrOlder : Bool

/-- Catala `scope Age65DayBeforeBirthday`: `day_before_birthday` is
`date_of_birth - 1 day`; `age` is the completed years from it to `as_of`. -/
def age65DayBeforeBirthday (i : Age65In) : Age65Out :=
  let dayBeforeBirthday := i.dateOfBirth.dayBefore
  let age := (i.asOf.year - dayBeforeBirthday.year) -
    (if i.asOf.month < dayBeforeBirthday.month ||
        (i.asOf.month == dayBeforeBirthday.month && i.asOf.day < dayBeforeBirthday.day)
     then 1 else 0)
  { age := age, is65OrOlder := decide (age ≥ 65) }

/-! ### Scope `StandardDeduction` -/

/-- Inputs of `StandardDeduction`, with the Catala names in lower camel case. -/
structure StandardDeductionIn where
  /-- Catala input `filing_status`. -/
  filingStatus : FilingStatus
  /-- Catala input `treat_as_mfs`. -/
  treatAsMfs : Bool
  /-- Catala input `primary_filer_is_blind`. -/
  primaryFilerIsBlind : Bool
  /-- Catala input `primary_filer_age65_or_older`. -/
  primaryFilerAge65OrOlder : Bool
  /-- Catala input `secondary_filer_is_blind`. -/
  secondaryFilerIsBlind : Bool
  /-- Catala input `secondary_filer_age65_or_older`. -/
  secondaryFilerAge65OrOlder : Bool
  /-- Catala input `is_widowed_in_tax_year`. -/
  isWidowedInTaxYear : Bool
  /-- Catala input `mfj_deceased_spouse_reached_age65`. -/
  mfjDeceasedSpouseReachedAge65 : Bool
  /-- Catala input `mfs_spouse_65_or_older`. -/
  mfsSpouse65OrOlder : Bool
  /-- Catala input `mfs_spouse_provides_no_benefits`. -/
  mfsSpouseProvidesNoBenefits : Bool
  /-- Catala input `treat_filers_as_dependents`. -/
  treatFilersAsDependents : Bool
  /-- DF `/employerIncomeSubtotal`, cents. -/
  employerIncomeSubtotal : Int

/-- Outputs of `StandardDeduction` (Catala `output` variables). -/
structure StandardDeductionOut where
  /-- Catala output `is_spouse_info_applicable_for_standard_deductions`. -/
  isSpouseInfoApplicableForStandardDeductions : Bool
  /-- Catala output `is_spouse_65_or_older`. -/
  isSpouse65OrOlder : Bool
  /-- Catala output `additional_standard_deduction_items`. -/
  additionalStandardDeductionItems : Int
  /-- Form 1040 line 12, cents. -/
  standardDeduction : Int

open FilingStatus

/-- DF `/filerMFSAndSpouseIsEligibleForStandardDeductions`. -/
def filerMfsAndSpouseIsEligibleForStandardDeductions (i : StandardDeductionIn) : Bool :=
  i.treatAsMfs && !i.mfsSpouseProvidesNoBenefits

/-- DF `/isSpouseInfoApplicableForStandardDeductions`. -/
def isSpouseInfoApplicableForStandardDeductions (i : StandardDeductionIn) : Bool :=
  i.filingStatus == marriedFilingJointly ||
    filerMfsAndSpouseIsEligibleForStandardDeductions i

/-- DF `/secondaryFilerIs65OrOlderForDeduction`. -/
def secondaryFilerIs65OrOlderForDeduction (i : StandardDeductionIn) : Bool :=
  if i.filingStatus == marriedFilingJointly && i.isWidowedInTaxYear then
    i.mfjDeceasedSpouseReachedAge65
  else if i.filingStatus == marriedFilingSeparately then i.mfsSpouse65OrOlder
  else !(i.filingStatus == headOfHousehold) && i.secondaryFilerAge65OrOlder

/-- A condition as the integer 0 or 1 (`if c then 1 else 0`). -/
def bit (b : Bool) : Int := if b then 1 else 0

/-- DF `/secondaryFilerAdditionalStandardDeductionItems`. -/
def secondaryFilerAdditionalStandardDeductionItems (i : StandardDeductionIn) : Int :=
  if isSpouseInfoApplicableForStandardDeductions i then
    bit i.secondaryFilerIsBlind + bit (secondaryFilerIs65OrOlderForDeduction i)
  else 0

/-- DF `/additionalStandardDeductionItems`. -/
def additionalStandardDeductionItems (i : StandardDeductionIn) : Int :=
  bit i.primaryFilerIsBlind + bit i.primaryFilerAge65OrOlder +
    secondaryFilerAdditionalStandardDeductionItems i

/-- Rev. Proc. 2023-34 § 3.15(3). DF `/additionalStandardDeductionMultiplier`. -/
def additionalStandardDeductionMultiplier : FilingStatus → Int
  | single => Params.stdDeductionAdditionalUnmarried
  | headOfHousehold => Params.stdDeductionAdditionalUnmarried
  | marriedFilingJointly => Params.stdDeductionAdditionalMarried
  | qualifyingSurvivingSpouse => Params.stdDeductionAdditionalMarried
  | marriedFilingSeparately => Params.stdDeductionAdditionalMarried

/-- IRC 63(c)(3). DF `/additionalStandardDeduction`: multiplier times the item
count as a decimal (`mulInt` rounds to the cent; exact here). -/
def additionalStandardDeduction (i : StandardDeductionIn) : Int :=
  mulInt (additionalStandardDeductionMultiplier i.filingStatus)
    (additionalStandardDeductionItems i)

/-- IRC 63(c)(2). DF `/filingStatusStandardDeduction`. -/
def filingStatusStandardDeduction : FilingStatus → Int
  | single => Params.stdDeductionUnmarried
  | marriedFilingSeparately => Params.stdDeductionMarriedSeparate
  | headOfHousehold => Params.stdDeductionHeadOfHousehold
  | marriedFilingJointly => Params.stdDeductionJointOrSurvivingSpouse
  | qualifyingSurvivingSpouse => Params.stdDeductionJointOrSurvivingSpouse

/-- IRC 63(c)(1). DF `/normalStandardDeduction`. -/
def normalStandardDeduction (i : StandardDeductionIn) : Int :=
  filingStatusStandardDeduction i.filingStatus + additionalStandardDeduction i

/-- IRC 63(c)(5), Rev. Proc. 2023-34 § 3.15(2). DF `/minimumStandardDeduction`. -/
def minimumStandardDeduction (i : StandardDeductionIn) : Int :=
  Money.max Params.stdDeductionDependentFloor
      (i.employerIncomeSubtotal + Params.stdDeductionDependentEarnedIncomeAddition)
    + additionalStandardDeduction i

/-- Form 1040 line 12 (DF `/standardDeduction`). -/
def standardDeductionAmount (i : StandardDeductionIn) : Int :=
  if i.treatFilersAsDependents then
    Money.min (minimumStandardDeduction i) (normalStandardDeduction i)
  else normalStandardDeduction i

/-- Catala `scope StandardDeduction`. -/
def standardDeduction (i : StandardDeductionIn) : StandardDeductionOut :=
  { isSpouseInfoApplicableForStandardDeductions := isSpouseInfoApplicableForStandardDeductions i
    isSpouse65OrOlder :=
      isSpouseInfoApplicableForStandardDeductions i && secondaryFilerIs65OrOlderForDeduction i
    additionalStandardDeductionItems := additionalStandardDeductionItems i
    standardDeduction := standardDeductionAmount i }

/-! ### Unit tests: every assertion of `catala/tests/test_standard_deduction.catala_en` -/

/-- The all-false base case of `TestBase`, $50,000 of earned income. -/
def base (fs : FilingStatus) : StandardDeductionIn :=
  { filingStatus := fs, treatAsMfs := fs == marriedFilingSeparately
    primaryFilerIsBlind := false, primaryFilerAge65OrOlder := false
    secondaryFilerIsBlind := false, secondaryFilerAge65OrOlder := false
    isWidowedInTaxYear := false, mfjDeceasedSpouseReachedAge65 := false
    mfsSpouse65OrOlder := false, mfsSpouseProvidesNoBenefits := false
    treatFilersAsDependents := false, employerIncomeSubtotal := 5_000_000 }

private def sd (i : StandardDeductionIn) : Int := (standardDeduction i).standardDeduction

-- TestBase
#guard sd (base single) == 1_460_000
#guard sd (base marriedFilingJointly) == 2_920_000
#guard sd (base headOfHousehold) == 2_190_000
#guard sd (base marriedFilingSeparately) == 1_460_000
#guard sd (base qualifyingSurvivingSpouse) == 2_920_000

-- TestAdditional
private def single65 : StandardDeductionIn :=
  { base single with primaryFilerAge65OrOlder := true, employerIncomeSubtotal := 0 }
private def mfjBoth65 : StandardDeductionIn :=
  { base marriedFilingJointly with primaryFilerAge65OrOlder := true, secondaryFilerAge65OrOlder := true, employerIncomeSubtotal := 0 }
private def singleBlind65 : StandardDeductionIn :=
  { base single with primaryFilerIsBlind := true, primaryFilerAge65OrOlder := true, employerIncomeSubtotal := 0 }
private def mfjThree : StandardDeductionIn :=
  { base marriedFilingJointly with primaryFilerAge65OrOlder := true, secondaryFilerIsBlind := true, secondaryFilerAge65OrOlder := true, employerIncomeSubtotal := 0 }
#guard sd single65 == 1_655_000
#guard sd mfjBoth65 == 3_230_000
#guard (standardDeduction mfjBoth65).isSpouse65OrOlder
#guard sd singleBlind65 == 1_850_000
#guard (standardDeduction singleBlind65).additionalStandardDeductionItems == 2
#guard sd mfjThree == 3_385_000
#guard (standardDeduction mfjThree).additionalStandardDeductionItems == 3

-- TestSpouseRules
private def mfsEligible : StandardDeductionIn :=
  { base marriedFilingSeparately with primaryFilerAge65OrOlder := true, mfsSpouse65OrOlder := true, employerIncomeSubtotal := 0 }
private def mfsNoBenefit : StandardDeductionIn :=
  { base marriedFilingSeparately with primaryFilerAge65OrOlder := true, secondaryFilerIsBlind := true, mfsSpouse65OrOlder := true, mfsSpouseProvidesNoBenefits := true, employerIncomeSubtotal := 0 }
private def mfjDeceased65 : StandardDeductionIn :=
  { base marriedFilingJointly with isWidowedInTaxYear := true, mfjDeceasedSpouseReachedAge65 := true, employerIncomeSubtotal := 0 }
private def mfjDeceasedNot65 : StandardDeductionIn :=
  { base marriedFilingJointly with secondaryFilerAge65OrOlder := true, isWidowedInTaxYear := true, mfjDeceasedSpouseReachedAge65 := false, employerIncomeSubtotal := 0 }
#guard sd mfsEligible == 1_770_000
#guard sd mfsNoBenefit == 1_615_000
#guard !(standardDeduction mfsNoBenefit).isSpouse65OrOlder
#guard sd mfjDeceased65 == 3_075_000
#guard sd mfjDeceasedNot65 == 2_920_000

-- TestDependent
private def dep (earned : Int) (aged : Bool) : StandardDeductionIn :=
  { base single with treatFilersAsDependents := true, employerIncomeSubtotal := earned, primaryFilerAge65OrOlder := aged }
#guard sd (dep 500_000 false) == 545_000
#guard sd (dep 0 false) == 130_000
#guard sd (dep 2_000_000 false) == 1_460_000
#guard sd (dep 500_000 true) == 740_000
#guard sd (dep 500_000 false) != 1_460_000

-- TestAge
private def ageOf (b a : Date) : Age65Out := age65DayBeforeBirthday ⟨b, a⟩
#guard (ageOf ⟨1960, 1, 1⟩ ⟨2024, 12, 31⟩).is65OrOlder
#guard (ageOf ⟨1960, 1, 1⟩ ⟨2024, 12, 31⟩).age == 65
#guard !(ageOf ⟨1960, 1, 2⟩ ⟨2024, 12, 31⟩).is65OrOlder
#guard (ageOf ⟨1960, 1, 2⟩ ⟨2024, 12, 31⟩).age == 64
#guard (ageOf ⟨1959, 12, 31⟩ ⟨2024, 12, 31⟩).is65OrOlder
#guard (ageOf ⟨1959, 7, 10⟩ ⟨2024, 7, 9⟩).is65OrOlder
#guard !(ageOf ⟨1959, 7, 10⟩ ⟨2024, 7, 8⟩).is65OrOlder

end UsTax.StandardDeduction
