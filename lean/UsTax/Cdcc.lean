import UsTax.Money
import UsTax.Lists
import UsTax.Types
import UsTax.Date
import UsTax.ParamsCredits
import UsTax.QualifyingRelative

/-!
# Child and dependent care credit: IRC 21, IRC 129, Form 2441 (issue #46)

Lean implementation of `catala/cdcc.catala_en` (module `Cdcc`, scopes `CdccPersonTest`,
`Form2441PartIII` and `Form2441`), written by hand from the Catala source under strategy (c) of
`docs/catala-to-lean.md`, in the order of the Catala file; the code that runs. Law: IRC 21 and
129, Form 2441 (2024) and its instructions, Reg. 1.21-1 to 1.21-3.

| Catala (`Cdcc`)                    | Lean (`UsTax.Cdcc`)                                         |
|------------------------------------|-------------------------------------------------------------|
| structs `CdccAnswers`, `CdccMember`, `CdccFiler` | the same names                                |
| `deemed_income_uplift`             | `deemedIncomeUplift`                                        |
| `scope CdccPersonTest`             | `CdccPersonTestIn` → `CdccPersonTestOut` (`cdccPersonTest`) |
| `scope Form2441PartIII`            | `Form2441PartIIIIn` → `Form2441PartIIIOut` (`form2441PartIII`) |
| `scope Form2441`                   | `Form2441In` (extends the Part III inputs) → `Form2441Out` (`form2441`) |
| `QR.DependentTest`                 | `QualifyingRelative.dependentTest`                          |
| `R.round_dollar`, `Money.*`        | `Money.roundDollar`, `Money.min`, `Money.positive`, ...     |

Money is `Int` cents, the applicable percentage is a `Rat`, conditions are `Bool`. The
Catala divergences from Direct File (DF-BUG(23) to (28)) are reproduced as in Catala (Lean
follows Catala): the custodial-parent-only reading of IRC 21(e)(5), 35 percent at AGI of zero
or less, one household for the married-separate exception, the secondary filer of a
qualifying surviving spouse, forfeited amounts whatever box 10 says, and "can be claimed".
-/

namespace UsTax.Cdcc

open Money QualifyingRelative

/-- Catala struct `CdccAnswers`: the answers DF keeps per household member that only the CDCC reads. -/
structure CdccAnswers where
  unableToCareForSelf : Bool
  hasDependentCareExpenses : Bool
  expensesPaidToQualifyingProvider : Bool
  writableQualifyingExpenseAmount : Int
  tpPaidMostOfHomeUpkeep : Bool

/-- Catala struct `CdccMember`: one member of DF `/familyAndHousehold`. -/
structure CdccMember where
  member : Member
  cdcc : CdccAnswers

/-- Catala struct `CdccFiler`: the per-filer inputs (primary or secondary filer). -/
structure CdccFiler where
  employerIncomeSubtotalBase : Int
  nontaxableCombatPay : Int
  electCombatPayForCredit : Bool
  electCombatPayForBenefits : Bool
  dependentCareBenefits : Int
  dependentCarePlanMaximum : Int
  isDisabled : Bool
  /-- IRC 21(d)(2): the filer's actual earnings in each month of incapacity or full-time study. -/
  deemedIncomeMonthEarnings : List Int
  hasDependentCareExpenses : Bool
  expensesPaidToQualifyingProvider : Bool
  writableQualifyingExpenseAmount : Int

/-- Catala `deemed_income_uplift`: by how much the deemed income of the listed months exceeds the
actual income, summed. Each month counts the higher of the deemed amount and the actual income. -/
def deemedIncomeUplift (months : List Int) (deemed : Int) : Int :=
  sumBy (fun a => positive (deemed - a)) months

/-! ### Scope `CdccPersonTest`: one person, qualifying person (IRC 21(b)(1)) -/

/-- Inputs of `CdccPersonTest`. -/
structure CdccPersonTestIn where
  cdccMember : CdccMember
  minimumFilerDateOfBirth : Date
  treatFilersAsDependents : Bool
  eitherFilerUsCitizenOrNational : Bool
  treatAsMfj : Bool

/-- Outputs of `CdccPersonTest`. -/
structure CdccPersonTestOut where
  dependent : DependentTestOut
  bornOnJanuaryFirst : Bool
  ageOnJanuaryFirst : Int
  under13ForPartOfYear : Bool
  turnedThirteenAfterJanuaryFirst : Bool
  qualifyingChildUnder13 : Bool
  incapableDependent : Bool
  custodialParentRelease : Bool
  cdccQualifyingPerson : Bool
  hasQualifyingExpenses : Bool
  qualifyingExpenseAmount : Int
  homeTestsForMarriedSeparate : Bool

/-- Catala `scope CdccPersonTest`. -/
def cdccPersonTest (i : CdccPersonTestIn) : CdccPersonTestOut :=
  let m := i.cdccMember
  let dependent := dependentTest
    { member := m.member, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
      treatFilersAsDependents := i.treatFilersAsDependents
      eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational
      treatAsMfj := i.treatAsMfj }
  let dob := m.member.person.dateOfBirth
  let born := decide (dob.month = 1) && decide (dob.day = 1)
  let ageOnJan := if born then dependent.qc.age else dependent.qc.age - 1
  let under13 := decide (ageOnJan < Params.cdccQualifyingChildAgeLimit)
  let turned13 := under13 && decide (dependent.qc.age ≥ Params.cdccQualifyingChildAgeLimit)
  -- DF-BUG(28): `eligibleDependent`, not `isClaimedDependent`.
  let qcUnder13 := dependent.eligibleDependent && dependent.qualifyingChild && under13
  let hasTin := m.member.answers.tinType != .noTin
  let incapable :=
    m.cdcc.unableToCareForSelf && dependent.qc.residencyTest && dependent.citizenOrResidentTest &&
      hasTin &&
      ((dependent.qc.qcRelationshipTest && dependent.qc.ageTest && dependent.qc.qcSupportTest) ||
        (dependent.notQualifyingChildTest && dependent.relationshipMemberOfHouseholdTest &&
          dependent.qrSupportTest)) &&
      !dependent.split.disqualifiedDueToParentalCustody &&
      !dependent.split.tpCanClaimSplitBenefitsHohEitcCdcc
  -- IRC 21(e)(5); the non-parent path of DF is DF-BUG(23).
  let custodial :=
    dependent.split.tpCanClaimSplitBenefitsHohEitcCdcc && dependent.split.tpIsParent &&
      dependent.citizenOrResidentTest && hasTin &&
      ((dependent.qualifyingChild && under13) ||
        (dependent.qc.residencyTest && m.cdcc.unableToCareForSelf))
  let person := qcUnder13 || incapable || custodial
  let hasQE := m.cdcc.hasDependentCareExpenses && m.cdcc.expensesPaidToQualifyingProvider
  { dependent, bornOnJanuaryFirst := born, ageOnJanuaryFirst := ageOnJan
    under13ForPartOfYear := under13, turnedThirteenAfterJanuaryFirst := turned13
    qualifyingChildUnder13 := qcUnder13, incapableDependent := incapable
    custodialParentRelease := custodial, cdccQualifyingPerson := person
    hasQualifyingExpenses := hasQE
    qualifyingExpenseAmount :=
      if person && hasQE then roundDollar m.cdcc.writableQualifyingExpenseAmount else 0
    homeTestsForMarriedSeparate :=
      person && dependent.qc.residencyTest && m.cdcc.tpPaidMostOfHomeUpkeep }

/-! ### Scope `Form2441PartIII`: dependent care benefits (lines 12 to 31) -/

/-- Inputs of `Form2441PartIII`. -/
structure Form2441PartIIIIn where
  filingStatus : FilingStatus
  household : List CdccMember
  minimumFilerDateOfBirth : Date
  treatFilersAsDependents : Bool
  eitherFilerUsCitizenOrNational : Bool
  treatAsMfj : Bool
  livedApartLastSixMonths : Bool
  spouseSameAbodeMoreThanHalfYear : Bool
  primaryFiler : CdccFiler
  secondaryFiler : CdccFiler
  hasMfsSpouseEarnedIncome : Bool
  writableMfsSpouseEarnedIncome : Int
  /-- Line 16. -/
  writableTotalQualifiedDependentCareExpenses : Int
  /-- Line 13. -/
  writableCarryoverAmount : Int
  /-- Line 14. -/
  writableForfeitedAmount : Int
  hasCreditForPriorYearExpenses : Bool
  claimedCreditForPriorYearExpenses : Bool
  claimedMaxCreditForPriorTaxYear : Bool
  hasHouseholdEmployee : Bool
  /-- Form 2441 line 22 "Yes". -/
  benefitsFromSoleProprietorshipOrPartnership : Bool

/-- Outputs of `Form2441PartIII`. -/
structure Form2441PartIIIOut where
  results : List CdccPersonTestOut
  isMfj : Bool
  isMfs : Bool
  nonFilerQualifyingPersonCount : Int
  primaryFilerIsQualifyingPerson : Bool
  secondaryFilerIsQualifyingPerson : Bool
  countOfQualifyingPersons : Int
  hasQualifyingPersons : Bool
  mfsButEligibleForCdcc : Bool
  marriedSeparateNotAllowed : Bool
  uncappedQualifyingExpenses : Int
  /-- Line 27. -/
  qualifyingExpenseCap : Int
  primaryDependentCareBenefits : Int
  secondaryDependentCareBenefits : Int
  hasReportedPrimaryBenefits : Bool
  hasReportedSecondaryBenefits : Bool
  line12DependentCareBenefits : Int
  line13Carryover : Int
  hasReportedCarryover : Bool
  line14Forfeited : Int
  line15AdjustedBenefits : Int
  isFillingPartIii : Bool
  line16Expenses : Int
  line17Lesser : Int
  deemedMonthlyIncome : Int
  primaryDeemedUplift : Int
  secondaryDeemedUplift : Int
  line18EarnedIncome : Int
  line19EarnedIncome : Int
  line20TentativeExclusion : Int
  maximumExclusion : Int
  askedAboutMaxExclusion : Bool
  line21SpecifiedExclusion : Int
  line22SoleProprietorshipBenefits : Int
  line23 : Int
  line24DeductibleBenefits : Int
  line25ExcludedBenefits : Int
  /-- Line 26; Form 1040 line 1e. -/
  taxableBenefits : Int
  line28 : Int
  line29NetAllowable : Int
  line31 : Int
  potentialCdccIsZeroDueToExclusion : Bool
  koKnockoutCdccWorksheetA : Bool
  koKnockoutHouseholdEmployee : Bool
  koSoleProprietorshipBenefits : Bool
  koBothSpousesDeemedIncome : Bool
  unsupported : Bool

/-- Catala `scope Form2441PartIII`, definition by definition. -/
def form2441PartIII (i : Form2441PartIIIIn) : Form2441PartIIIOut :=
  let isMfj := decide (i.filingStatus = .marriedFilingJointly)
  let isMfs := decide (i.filingStatus = .marriedFilingSeparately)
  let results := i.household.map fun m =>
    cdccPersonTest
      { cdccMember := m, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
        treatFilersAsDependents := i.treatFilersAsDependents
        eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational
        treatAsMfj := i.treatAsMfj }
  let nonFilerCount : Int := (countBy (·.cdccQualifyingPerson) results : Nat)
  let primaryQp := i.primaryFiler.isDisabled && i.treatAsMfj && i.spouseSameAbodeMoreThanHalfYear
  let secondaryQp := i.secondaryFiler.isDisabled && i.treatAsMfj && i.spouseSameAbodeMoreThanHalfYear
  let count : Int := nonFilerCount + (if primaryQp then 1 else 0) + (if secondaryQp then 1 else 0)
  let hasQps := decide (count > 0)
  let mfsButEligible := isMfs && i.livedApartLastSixMonths &&
    results.any (·.homeTestsForMarriedSeparate)
  let marriedSeparateNotAllowed := isMfs && !mfsButEligible
  let uncapped :=
    sumBy (·.qualifyingExpenseAmount) results +
      (if primaryQp && i.primaryFiler.hasDependentCareExpenses &&
          i.primaryFiler.expensesPaidToQualifyingProvider
       then roundDollar i.primaryFiler.writableQualifyingExpenseAmount else 0) +
      (if secondaryQp && i.secondaryFiler.hasDependentCareExpenses &&
          i.secondaryFiler.expensesPaidToQualifyingProvider
       then roundDollar i.secondaryFiler.writableQualifyingExpenseAmount else 0)
  let cap :=
    if count > 1 then Params.cdccExpenseCapTwoOrMore
    else if count = 1 then Params.cdccExpenseCapOnePerson else 0
  -- lines 12 to 15
  let primaryBenefits := i.primaryFiler.dependentCareBenefits
  let secondaryBenefits := if isMfj then i.secondaryFiler.dependentCareBenefits else 0
  let hasReportedPrimary := decide (primaryBenefits > 0)
  let hasReportedSecondary := decide (secondaryBenefits > 0)
  let line12 := roundDollar primaryBenefits + (if isMfj then roundDollar secondaryBenefits else 0)
  let line13 := roundDollar i.writableCarryoverAmount
  let hasReportedCarryover := decide (line13 > 0)
  -- DF-BUG(27): the statute counts the amount whatever box 10 says.
  let line14 := roundDollar i.writableForfeitedAmount
  let line15 := line12 + line13 - line14
  let isFillingIii := hasReportedPrimary || hasReportedSecondary || hasReportedCarryover
  let line16 := if hasQps then roundDollar i.writableTotalQualifiedDependentCareExpenses else 0
  let line17 := Money.min line15 line16
  -- lines 18 to 21
  let deemedMonthly :=
    if count > 1 then Params.cdccDeemedMonthlyIncomeTwoOrMore
    else if count = 1 then Params.cdccDeemedMonthlyIncomeOnePerson else 0
  let primaryUplift :=
    if isMfj then deemedIncomeUplift i.primaryFiler.deemedIncomeMonthEarnings deemedMonthly else 0
  let secondaryUplift :=
    if isMfj then deemedIncomeUplift i.secondaryFiler.deemedIncomeMonthEarnings deemedMonthly else 0
  let line18 := roundDollar
    (i.primaryFiler.employerIncomeSubtotalBase +
      (if i.primaryFiler.electCombatPayForBenefits then i.primaryFiler.nontaxableCombatPay else 0) +
      primaryUplift)
  let line19 :=
    if isMfj then roundDollar
      (i.secondaryFiler.employerIncomeSubtotalBase +
        (if i.secondaryFiler.electCombatPayForBenefits then i.secondaryFiler.nontaxableCombatPay
         else 0) + secondaryUplift)
    else if marriedSeparateNotAllowed then
      (if i.hasMfsSpouseEarnedIncome then roundDollar i.writableMfsSpouseEarnedIncome else 0)
    else line18
  let line20 := if line17 > 0 then Money.min line17 (Money.min line18 line19) else 0
  let maxExclusion :=
    if marriedSeparateNotAllowed then Params.dependentCareExclusionCapMarriedSeparate
    else Params.dependentCareExclusionCap
  let askedAboutMax := isFillingIii && hasQps
  let line21 :=
    if !askedAboutMax then 0
    else if (isMfj || isMfs) && !mfsButEligible then
      Money.min maxExclusion
        ((if hasReportedPrimary || hasReportedCarryover
          then roundDollar i.primaryFiler.dependentCarePlanMaximum else 0) +
         (if hasReportedSecondary then roundDollar i.secondaryFiler.dependentCarePlanMaximum
          else 0))
    else
      Money.min maxExclusion
        (if hasReportedPrimary || hasReportedCarryover
         then roundDollar i.primaryFiler.dependentCarePlanMaximum else 0)
  -- OUT OF SCOPE: line 22 (sole proprietorship or partnership benefits)
  let line22 : Int := 0
  let line23 := line15 - line22
  let line24 := Money.min line20 (Money.min line21 line22)
  let line25 := Money.min line21 line20
  let taxable := if isFillingIii then positive (line23 - line25) else 0
  let line28 := line24 + line25
  let line29 := cap - line28
  let line31 := Money.min line29 uncapped
  let potentialZero := isFillingIii && decide (line29 ≤ 0)
  let koA := i.hasCreditForPriorYearExpenses &&
    (!i.claimedCreditForPriorYearExpenses || !i.claimedMaxCreditForPriorTaxYear)
  let koHousehold := i.hasHouseholdEmployee
  let koSole := i.benefitsFromSoleProprietorshipOrPartnership
  let koBoth := isMfj && !i.primaryFiler.deemedIncomeMonthEarnings.isEmpty &&
    !i.secondaryFiler.deemedIncomeMonthEarnings.isEmpty
  { results, isMfj, isMfs, nonFilerQualifyingPersonCount := nonFilerCount
    primaryFilerIsQualifyingPerson := primaryQp, secondaryFilerIsQualifyingPerson := secondaryQp
    countOfQualifyingPersons := count, hasQualifyingPersons := hasQps
    mfsButEligibleForCdcc := mfsButEligible, marriedSeparateNotAllowed
    uncappedQualifyingExpenses := uncapped, qualifyingExpenseCap := cap
    primaryDependentCareBenefits := primaryBenefits
    secondaryDependentCareBenefits := secondaryBenefits
    hasReportedPrimaryBenefits := hasReportedPrimary
    hasReportedSecondaryBenefits := hasReportedSecondary
    line12DependentCareBenefits := line12, line13Carryover := line13
    hasReportedCarryover, line14Forfeited := line14, line15AdjustedBenefits := line15
    isFillingPartIii := isFillingIii, line16Expenses := line16, line17Lesser := line17
    deemedMonthlyIncome := deemedMonthly, primaryDeemedUplift := primaryUplift
    secondaryDeemedUplift := secondaryUplift, line18EarnedIncome := line18
    line19EarnedIncome := line19, line20TentativeExclusion := line20
    maximumExclusion := maxExclusion, askedAboutMaxExclusion := askedAboutMax
    line21SpecifiedExclusion := line21, line22SoleProprietorshipBenefits := line22
    line23, line24DeductibleBenefits := line24, line25ExcludedBenefits := line25
    taxableBenefits := taxable, line28, line29NetAllowable := line29, line31
    potentialCdccIsZeroDueToExclusion := potentialZero
    koKnockoutCdccWorksheetA := koA, koKnockoutHouseholdEmployee := koHousehold
    koSoleProprietorshipBenefits := koSole, koBothSpousesDeemedIncome := koBoth
    unsupported := koA || koHousehold || koSole || koBoth }

/-! ### Scope `Form2441`: the credit (lines 3 to 11) -/

/-- Inputs of `Form2441`: those of `Form2441PartIII` and the two figures from the rest of the
return. -/
structure Form2441In extends Form2441PartIIIIn where
  /-- Form 2441 line 7: Form 1040 line 11. -/
  agi : Int
  /-- Credit Limit Worksheet line 1: Form 1040 line 18. -/
  totalTentativeTax : Int

/-- Outputs of `Form2441` (the flat pass-through outputs of the Catala scope are read from
`benefits`, the Part III result). -/
structure Form2441Out where
  benefits : Form2441PartIIIOut
  hasQualifyingExpenses : Bool
  hasMoreThanThreeQualifyingPersons : Bool
  /-- Line 3. -/
  line3 : Int
  primaryEarnedIncomeBeforeBenefits : Int
  secondaryEarnedIncomeBeforeBenefits : Int
  primaryAdjustment : Int
  secondaryAdjustment : Int
  allocateAllToPrimary : Bool
  allocateAllToSecondary : Bool
  primaryTaxableBenefits : Int
  secondaryTaxableBenefits : Int
  /-- Line 4. -/
  line4EarnedIncome : Int
  /-- Line 5. -/
  line5EarnedIncome : Int
  lowerOfEarnedIncome : Int
  /-- Line 6. -/
  line6 : Int
  /-- IRC 21(a)(2) as a decimal. -/
  applicablePercentage : Rat
  line8DecimalAmount : Int
  line9a : Int
  line9b : Int
  line9c : Int
  line10TaxLiabilityLimit : Int
  /-- Line 11; Schedule 3 line 2. -/
  cdccTotalCredit : Int
  isReceivingCdccCredit : Bool
  shouldSubmitForm2441 : Bool
  koFlowKnockoutBenefitsDistribution : Bool
  unsupported : Bool

/-- IRC 21(a)(2): 35 percent reduced (not below 20 percent) by one point for each started
`$2,000` of AGI over `$15,000`. DF-BUG(24): 35 percent at AGI of zero or less. -/
def applicablePercentage (agi : Int) : Rat :=
  if agi ≤ Params.cdccPercentageReductionThreshold then Params.cdccMaximumPercentage
  else
    let steps := divMoney (agi - Params.cdccPercentageReductionThreshold) Params.cdccPercentageStepIncome
    let wholeSteps := truncateRat steps
    let startedSteps := if steps > wholeSteps then wholeSteps + 1 else wholeSteps
    let reduced := Params.cdccMaximumPercentage - Params.cdccPercentageStep * startedSteps
    if reduced < Params.cdccMinimumPercentage then Params.cdccMinimumPercentage else reduced

/-- Catala `scope Form2441`, definition by definition. -/
def form2441 (i : Form2441In) : Form2441Out :=
  let b := form2441PartIII i.toForm2441PartIIIIn
  let isMfj := decide (i.filingStatus = .marriedFilingJointly)
  let line3 :=
    if b.isFillingPartIii then b.line31 else Money.min b.uncappedQualifyingExpenses b.qualifyingExpenseCap
  let hasQE := decide (b.uncappedQualifyingExpenses > 0)
  let primaryEarned :=
    i.primaryFiler.employerIncomeSubtotalBase +
      (if i.primaryFiler.electCombatPayForCredit then i.primaryFiler.nontaxableCombatPay else 0) +
      b.primaryDeemedUplift
  let secondaryEarned :=
    if isMfj then
      i.secondaryFiler.employerIncomeSubtotalBase +
        (if i.secondaryFiler.electCombatPayForCredit then i.secondaryFiler.nontaxableCombatPay
         else 0) + b.secondaryDeemedUplift
    else 0
  -- whose earned income holds the taxable benefits (QUIRK(Q12), reproduced)
  let primaryAdjustment := Money.min b.taxableBenefits b.primaryDependentCareBenefits
  let secondaryAdjustment := Money.min b.taxableBenefits b.secondaryDependentCareBenefits
  let allocPrimary := b.hasReportedPrimaryBenefits &&
    (!(isMfj && b.hasReportedSecondaryBenefits) ||
      decide (secondaryEarned - primaryEarned ≥ primaryEarned + primaryAdjustment) ||
      (decide (primaryEarned ≤ secondaryEarned) &&
        decide (Money.min secondaryEarned (primaryEarned + primaryAdjustment) ≥ b.line31) &&
        !decide (secondaryEarned < primaryEarned + primaryAdjustment)))
  let allocSecondary := b.hasReportedSecondaryBenefits &&
    (!b.hasReportedPrimaryBenefits ||
      decide (primaryEarned - secondaryEarned ≥ secondaryEarned + secondaryAdjustment) ||
      (decide (secondaryEarned < primaryEarned) &&
        decide (Money.min primaryEarned (secondaryEarned + secondaryAdjustment) ≥ b.line31) &&
        !decide (primaryEarned < secondaryEarned + secondaryAdjustment)))
  let primaryTaxable :=
    if allocPrimary then primaryAdjustment
    else if b.taxableBenefits > secondaryAdjustment
    then Money.min primaryAdjustment (b.taxableBenefits - secondaryAdjustment) else 0
  let secondaryTaxable :=
    if allocSecondary then secondaryAdjustment
    else if b.taxableBenefits > primaryAdjustment
    then Money.min secondaryAdjustment (b.taxableBenefits - primaryAdjustment) else 0
  let line4 := roundDollar (primaryEarned + primaryTaxable)
  let line5 := if isMfj then roundDollar (secondaryEarned + secondaryTaxable) else line4
  let lowerOfEarned := if isMfj then Money.min line4 line5 else line4
  let line6 := Money.min line3 lowerOfEarned
  let koDistribution := isMfj &&
    (b.hasReportedCarryover || (b.hasReportedPrimaryBenefits && b.hasReportedSecondaryBenefits)) &&
    decide (b.taxableBenefits > 0) &&
    (decide (primaryEarned < b.line31) || decide (secondaryEarned < b.line31)) &&
    !(allocPrimary || allocSecondary)
  -- lines 7 to 11
  let pct := applicablePercentage i.agi
  let line9a := roundDollar (mulRate line6 pct)
  let line9b : Int := 0
  let line9c := line9a + line9b
  let line10 := i.totalTentativeTax
  let credit :=
    if !b.potentialCdccIsZeroDueToExclusion && !b.marriedSeparateNotAllowed && hasQE &&
        decide (line6 > 0)
    then Money.min line9c (positive line10) else 0
  { benefits := b, hasQualifyingExpenses := hasQE
    hasMoreThanThreeQualifyingPersons := decide (b.countOfQualifyingPersons > 3)
    line3, primaryEarnedIncomeBeforeBenefits := primaryEarned
    secondaryEarnedIncomeBeforeBenefits := secondaryEarned
    primaryAdjustment, secondaryAdjustment
    allocateAllToPrimary := allocPrimary, allocateAllToSecondary := allocSecondary
    primaryTaxableBenefits := primaryTaxable, secondaryTaxableBenefits := secondaryTaxable
    line4EarnedIncome := line4, line5EarnedIncome := line5, lowerOfEarnedIncome := lowerOfEarned
    line6, applicablePercentage := pct, line8DecimalAmount := mulRate 100 pct
    line9a, line9b, line9c, line10TaxLiabilityLimit := line10
    cdccTotalCredit := credit, isReceivingCdccCredit := decide (credit > 0)
    shouldSubmitForm2441 := decide (credit > 0) || b.isFillingPartIii
    koFlowKnockoutBenefitsDistribution := koDistribution
    unsupported := b.unsupported || koDistribution }

/-! ### Unit tests: every assertion of `catala/tests/test_cdcc.catala_en`

`Case` is the Catala helper of the same name. By default: a head of household (born 1985-06-15)
with wages of `$45,000`, one qualifying child (a 4-year-old son born 2020-03-01, claimed, SSN)
with `$3,000` of qualified expenses paid to a qualified provider, AGI `$15,000` and a tax
liability limit of `$5,000`. A test overrides only what it tests. -/

/-- The Catala test helper `Case` (its `context` variables). -/
structure Case where
  filingStatus : FilingStatus := .headOfHousehold
  childDateOfBirth : Date := ⟨2020, 3, 1⟩
  childExpenses : Int := 300_000
  childUnableToCare : Bool := false
  secondChild : Bool := false
  secondChildExpenses : Int := 0
  agi : Int := 1_500_000
  taxLimit : Int := 500_000
  primaryWages : Int := 4_500_000
  secondaryWages : Int := 0
  primaryBenefits : Int := 0
  secondaryBenefits : Int := 0
  primaryPlanMax : Int := 0
  secondaryPlanMax : Int := 0
  line16 : Int := 0
  carryover : Int := 0
  forfeited : Int := 0
  secondaryMonths : List Int := []
  secondaryDisabled : Bool := false
  secondaryExpenses : Int := 0
  spouseSameAbode : Bool := false
  primaryCombatPay : Int := 0
  primaryElectsCombatForCredit : Bool := false
  householdEmployee : Bool := false

/-- Catala `MkChild`: a biological child who lived with the filer all year. -/
def mkChild (dateOfBirth : Date) (expenses : Int) (unable : Bool) : CdccMember :=
  { member :=
      { person := { QualifyingChild.defaultPerson with dateOfBirth }
        answers :=
          { grossIncome := 0, writableQrSupportTest := true, tinType := .ssn
            isUsCitizenFullYear := true, writableUsResident := false, writableUsNational := false
            writableCanadaMexicoResident := false, tpClaims := true }
        split := defaultMember.split }
    cdcc :=
      { unableToCareForSelf := unable, hasDependentCareExpenses := decide (expenses > 0)
        expensesPaidToQualifyingProvider := true, writableQualifyingExpenseAmount := expenses
        tpPaidMostOfHomeUpkeep := true } }

/-- Catala `MkFiler`. -/
def mkFiler (wages benefits planMax : Int) (months : List Int) (disabled : Bool) (expenses combat : Int)
    (electCredit : Bool) : CdccFiler :=
  { employerIncomeSubtotalBase := wages, nontaxableCombatPay := combat
    electCombatPayForCredit := electCredit, electCombatPayForBenefits := false
    dependentCareBenefits := benefits, dependentCarePlanMaximum := planMax, isDisabled := disabled
    deemedIncomeMonthEarnings := months, hasDependentCareExpenses := decide (expenses > 0)
    expensesPaidToQualifyingProvider := true, writableQualifyingExpenseAmount := expenses }

/-- The `Form2441` input of a `Case`. -/
def Case.input (c : Case) : Form2441In :=
  { filingStatus := c.filingStatus
    household :=
      if c.secondChild
      then [mkChild c.childDateOfBirth c.childExpenses c.childUnableToCare,
            mkChild ⟨2018, 5, 5⟩ c.secondChildExpenses false]
      else [mkChild c.childDateOfBirth c.childExpenses c.childUnableToCare]
    minimumFilerDateOfBirth := ⟨1985, 6, 15⟩
    treatFilersAsDependents := false
    eitherFilerUsCitizenOrNational := true
    treatAsMfj := decide (c.filingStatus = .marriedFilingJointly)
    livedApartLastSixMonths := false
    spouseSameAbodeMoreThanHalfYear := c.spouseSameAbode
    primaryFiler := mkFiler c.primaryWages c.primaryBenefits c.primaryPlanMax [] false 0
      c.primaryCombatPay c.primaryElectsCombatForCredit
    secondaryFiler := mkFiler c.secondaryWages c.secondaryBenefits c.secondaryPlanMax
      c.secondaryMonths c.secondaryDisabled c.secondaryExpenses 0 false
    hasMfsSpouseEarnedIncome := false, writableMfsSpouseEarnedIncome := 0
    writableTotalQualifiedDependentCareExpenses := c.line16
    writableCarryoverAmount := c.carryover, writableForfeitedAmount := c.forfeited
    hasCreditForPriorYearExpenses := false, claimedCreditForPriorYearExpenses := false
    claimedMaxCreditForPriorTaxYear := false, hasHouseholdEmployee := c.householdEmployee
    benefitsFromSoleProprietorshipOrPartnership := false
    agi := c.agi, totalTentativeTax := c.taxLimit }

private def run (f : Case → Case) : Form2441Out := form2441 (f {}).input

-- TestOneQpAgi15k: one qualifying person, $3,000, AGI $15,000: 35 percent, $1,050
private def t1 := run id
#guard t1.benefits.countOfQualifyingPersons == 1
#guard t1.line3 == 300_000
#guard t1.line8DecimalAmount == 35
#guard t1.cdccTotalCredit == 105_000
#guard t1.cdccTotalCredit != 102_000
#guard !t1.unsupported

-- TestAgi43001: 20 percent, $600
private def t2 := run fun c => { c with agi := 4_300_100 }
#guard t2.line8DecimalAmount == 20
#guard t2.cdccTotalCredit == 60_000

-- TestPercentageSteps
#guard (run fun c => { c with agi := 4_300_000 }).line8DecimalAmount == 21
#guard (run fun c => { c with agi := 1_500_100 }).line8DecimalAmount == 34
#guard (run fun c => { c with agi := 1_700_000 }).line8DecimalAmount == 34
#guard (run fun c => { c with agi := 1_700_100 }).line8DecimalAmount == 33

-- TestNegativeAgi: 35 percent (IRC 21(a)(2); DF-BUG(24))
private def t3 := run fun c => { c with agi := -50_000 }
#guard t3.line8DecimalAmount == 35
#guard t3.cdccTotalCredit == 105_000

-- TestTwoQps: AGI $30,000 is over $29,000 and not over $31,000: .27; $6,000 x .27 = $1,620
private def t4 := run fun c => { c with
    secondChild := true, childExpenses := 350_000,
    secondChildExpenses := 400_000, agi := 3_000_000 }
#guard t4.benefits.countOfQualifyingPersons == 2
#guard t4.benefits.uncappedQualifyingExpenses == 750_000
#guard t4.line3 == 600_000
#guard t4.line8DecimalAmount == 27
#guard t4.cdccTotalCredit == 162_000
#guard t4.cdccTotalCredit != 81_000

-- TestEarnedIncomeLimit: the only earner makes $2,000
private def t5 := run fun c => { c with primaryWages := 200_000, agi := 4_500_000 }
#guard t5.line6 == 200_000
#guard t5.cdccTotalCredit == 40_000

-- TestStudentSpouse: deemed $250 a month for nine months
private def t6 := run fun c => { c with
    filingStatus := .marriedFilingJointly,
    primaryWages := 4_000_000, childExpenses := 500_000, agi := 4_500_000,
    secondaryMonths := [0, 0, 0, 0, 0, 0, 0, 0, 0] }
#guard t6.benefits.deemedMonthlyIncome == 25_000
#guard t6.line5EarnedIncome == 225_000
#guard t6.line6 == 225_000
#guard t6.cdccTotalCredit == 45_000
#guard !t6.unsupported

-- TestDeemedHigher: the higher of deemed and actual income counts each month
private def t7 := run fun c => { c with
    filingStatus := .marriedFilingJointly,
    secondaryMonths := [10_000, 10_000, 100_000] }
#guard t7.benefits.secondaryDeemedUplift == 30_000
#guard t7.line5EarnedIncome == 30_000

-- TestBenefits5000: employer benefits of $5,000 reduce the cap to 0
private def t8 := run fun c => { c with
    primaryBenefits := 500_000, primaryPlanMax := 500_000,
    line16 := 500_000, childExpenses := 500_000 }
#guard t8.benefits.line25ExcludedBenefits == 500_000
#guard t8.benefits.line29NetAllowable == -200_000
#guard t8.benefits.taxableBenefits == 0
#guard t8.cdccTotalCredit == 0
#guard t8.cdccTotalCredit != 105_000

-- TestTaxableBenefits: benefits above the exclusion limit are taxable
private def t9 := run fun c => { c with
    primaryBenefits := 600_000, primaryPlanMax := 600_000,
    line16 := 600_000, childExpenses := 600_000 }
#guard t9.benefits.line21SpecifiedExclusion == 500_000
#guard t9.benefits.line25ExcludedBenefits == 500_000
#guard t9.benefits.taxableBenefits == 100_000

-- TestBenefitsNoExpenses: benefits without expenses are all taxable
private def t10 := run fun c => { c with
    primaryBenefits := 56_000, primaryPlanMax := 500_000,
    line16 := 0, childExpenses := 0 }
#guard t10.benefits.taxableBenefits == 56_000
#guard t10.cdccTotalCredit == 0

-- TestBenefitsReduceCap
private def t11 := run fun c => { c with
    primaryBenefits := 100_000, carryover := 30_000,
    primaryPlanMax := 200_000, line16 := 2_000_000, childExpenses := 2_000_000, agi := 4_500_000 }
#guard t11.benefits.line15AdjustedBenefits == 130_000
#guard t11.benefits.line25ExcludedBenefits == 130_000
#guard t11.benefits.line31 == 170_000
#guard t11.line3 == 170_000
#guard t11.cdccTotalCredit == 34_000

-- TestTaxLimit
private def t12 := run fun c => { c with taxLimit := 30_000 }
#guard t12.line9c == 105_000
#guard t12.cdccTotalCredit == 30_000

-- TestAge13
#guard (run fun c => { c with childDateOfBirth := ⟨2011, 6, 1⟩ }).benefits.countOfQualifyingPersons == 1
private def t13 := run fun c => { c with childDateOfBirth := ⟨2011, 1, 1⟩ }
#guard t13.benefits.countOfQualifyingPersons == 0
#guard t13.cdccTotalCredit == 0
#guard (run fun c => { c with
    childDateOfBirth := ⟨2011, 1, 1⟩,
    childUnableToCare := true }).benefits.countOfQualifyingPersons == 1

-- TestDisabledSpouse
private def t14 := run fun c => { c with
    filingStatus := .marriedFilingJointly,
    secondaryDisabled := true, spouseSameAbode := true, secondaryWages := 300_000,
    secondaryExpenses := 400_000 }
#guard t14.benefits.countOfQualifyingPersons == 2
#guard t14.benefits.qualifyingExpenseCap == 600_000
#guard t14.benefits.uncappedQualifyingExpenses == 700_000
#guard t14.line3 == 600_000
#guard t14.line6 == 300_000
#guard t14.cdccTotalCredit == 105_000

-- TestMfs: no credit (IRC 21(e)(2))
private def t15 := run fun c => { c with filingStatus := .marriedFilingSeparately }
#guard t15.benefits.marriedSeparateNotAllowed
#guard t15.cdccTotalCredit == 0

-- TestCombatPay
#guard (run fun c => { c with
    primaryWages := 100_000, primaryCombatPay := 250_000,
    primaryElectsCombatForCredit := true }).line6 == 300_000
#guard (run fun c => { c with primaryWages := 100_000, primaryCombatPay := 250_000 }).line6 == 100_000

-- TestKnockouts
private def t16 := run fun c => { c with householdEmployee := true }
#guard t16.unsupported
#guard t16.benefits.koKnockoutHouseholdEmployee

-- TestRejectsOldChild: a 13-year-old is not a qualifying person
private def t17 := run fun c => { c with childDateOfBirth := ⟨2008, 1, 1⟩ }
#guard t17.benefits.countOfQualifyingPersons != 1
#guard t17.cdccTotalCredit == 0

end UsTax.Cdcc
