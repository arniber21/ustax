import UsTax.Types
import UsTax.Date
import UsTax.StandardDeduction

/-!
# Filers: age, marital status, residency, dependency of the filers (issue #44)

Lean implementation of `catala/filers.catala_en` (module `Filers`, scopes `FilerFacts`,
`Filers` and `FilersStandardDeduction`), written by hand from the Catala source under
strategy (c) of `docs/catala-to-lean.md`, in the order of the Catala file. It is the code
that runs. Not modelled, as in Catala: names, TINs, addresses, the state-scoping
knockout, the per-filer student/disabled flags, and `/MFSSpouseFilingReturn`.

| Catala (`Filers`)                      | Lean (`UsTax.Filers`)                         |
|----------------------------------------|-----------------------------------------------|
| enums `MaritalStatus`, `YearOfSpouseDeath`, `SpouseLivedTogetherMonths` | same names |
| struct `FilerAnswers`                  | `FilerAnswers`                                |
| `tax_year`, `senior_age`, ...          | `taxYear`, `seniorAge`, `eitcMinimumAge`, ... |
| `completed_years`                      | `Date.completedYears` (`UsTax/Date.lean`)     |
| `scope FilerFacts`                     | `FilerFactsIn` → `FilerFactsOut` (`filerFacts`) |
| `scope Filers`                         | `FilersIn` → `FilersOut` (`filers`)           |
| `scope FilersStandardDeduction`        | `FilersStandardDeductionIn` → `FilersStandardDeductionOut` (`filersStandardDeduction`) |

Field names are the Catala names in lower camel case. Conditions are `Bool`; money is `Int`
cents; dates are `UsTax.Date` (`<` on dates is `Date.lt`). Every Catala `rule ... under
condition` is a plain `Bool` here: Catala's default for an unfired condition rule is
`false`, and no rule of this module has an exception sibling.
-/

namespace UsTax.Filers

open FilingStatus

/-- Catala `MaritalStatus` (DF `/maritalStatusOptions`; `NeverMarried` is DF `single`). -/
inductive MaritalStatus where
  | neverMarried | married | divorced | widowed
  deriving DecidableEq, Repr, Inhabited

/-- Catala `YearOfSpouseDeath` (DF `/yearOfSpouseDeathOptions`). -/
inductive YearOfSpouseDeath where
  | diedInTaxYear | diedTaxYearMinusOne | diedTaxYearMinusTwo | diedBeforeTaxYearMinusTwo
  deriving DecidableEq, Repr, Inhabited

/-- Catala `SpouseLivedTogetherMonths` (DF `/spouseLivedTogetherMonthsOptions`). -/
inductive SpouseLivedTogetherMonths where
  | livedApartAllYear | livedTogetherSixMonthsOrLess | livedTogetherMoreThanSixMonths
  deriving DecidableEq, Repr, Inhabited

namespace MaritalStatus
/-- Parse a Catala case name. -/
def ofString? : String → Option MaritalStatus
  | "NeverMarried" => some neverMarried | "Married" => some married
  | "Divorced" => some divorced | "Widowed" => some widowed | _ => none
end MaritalStatus

namespace YearOfSpouseDeath
/-- Parse a Catala case name. -/
def ofString? : String → Option YearOfSpouseDeath
  | "DiedInTaxYear" => some diedInTaxYear | "DiedTaxYearMinusOne" => some diedTaxYearMinusOne
  | "DiedTaxYearMinusTwo" => some diedTaxYearMinusTwo
  | "DiedBeforeTaxYearMinusTwo" => some diedBeforeTaxYearMinusTwo | _ => none
end YearOfSpouseDeath

namespace SpouseLivedTogetherMonths
/-- Parse a Catala case name. -/
def ofString? : String → Option SpouseLivedTogetherMonths
  | "LivedApartAllYear" => some livedApartAllYear
  | "LivedTogetherSixMonthsOrLess" => some livedTogetherSixMonthsOrLess
  | "LivedTogetherMoreThanSixMonths" => some livedTogetherMoreThanSixMonths | _ => none
end SpouseLivedTogetherMonths

/-- Catala `FilerAnswers`: the `Writable` answers DF keeps per filer. -/
structure FilerAnswers where
  /-- DF `/filers/*/dateOfBirth`. -/
  dateOfBirth : Date
  /-- DF `/filers/*/isBlind`. -/
  isBlind : Bool
  /-- DF `/filers/*/canBeClaimed`. -/
  canBeClaimed : Bool
  /-- DF `/filers/*/willBeClaimed`. -/
  willBeClaimed : Bool
  /-- DF `/filers/*/potentialClaimerMustFile`. -/
  potentialClaimerMustFile : Bool
  /-- DF `/filers/*/potentialClaimerDidFile`. -/
  potentialClaimerDidFile : Bool
  /-- DF `/filers/*/isUsCitizenFullYear`. -/
  isUsCitizenFullYear : Bool
  /-- DF `/filers/*/writableCitizenAtEndOfTaxYear`. -/
  writableCitizenAtEndOfTaxYear : Bool
  /-- DF `/filers/*/writableIsNoncitizenResidentFullYear`. -/
  writableIsNoncitizenResidentFullYear : Bool
  /-- DF `/filers/*/writableIsNational`. -/
  writableIsNational : Bool

/-- DF constants.xml `/taxYear`. -/
def taxYear : Int := 2024
/-- IRC 63(f)(1): "attained age 65". -/
def seniorAge : Int := 65
/-- IRC 32(c)(1)(A)(ii)(II): minimum age 25. -/
def eitcMinimumAge : Int := 25
/-- IRC 32(c)(1)(A)(ii)(II): 64 or younger. -/
def eitcMaximumAge : Int := 64
/-- DF `/filers/*/age55OrOlder`. -/
def age55 : Int := 55
/-- IRC 25B(c)(2)(C). -/
def adultAge : Int := 18
/-- DF product decision, `/flowKnockoutFilerAgeYoungerThan16`. -/
def minimumSupportedFilerAge : Int := 16

/-! ### Scope `FilerFacts` -/

/-- Inputs of `FilerFacts`. -/
structure FilerFactsIn where
  /-- DF `/filers/*/dateOfBirth`. -/
  dateOfBirth : Date
  /-- True for the secondary filer when the spouse died in the tax year. -/
  isDeceasedInTaxYear : Bool
  /-- DF `/secondaryFilerDateOfDeath`; read only if `isDeceasedInTaxYear`. -/
  dateOfDeath : Date
  isUsCitizenFullYear : Bool
  writableCitizenAtEndOfTaxYear : Bool
  writableIsNoncitizenResidentFullYear : Bool
  writableIsNational : Bool

/-- Outputs of `FilerFacts` (and its internal ages). -/
structure FilerFactsOut where
  age : Int
  ageCalculatedDayBeforeDob : Int
  age65OrOlder : Bool
  age55OrOlder : Bool
  youngerThan16 : Bool
  isUnder18 : Bool
  ageDayBeforeDeath : Int
  ageDayOfDeath : Int
  reachedAge65AtDeath : Bool
  ageForSelfOnlyEitcLimits : Int
  age25OrOlderForEitc : Bool
  age64OrYoungerForEitc : Bool
  citizenAtEndOfTaxYear : Bool
  isNoncitizenResidentFullYear : Bool
  isNational : Bool
  isCitizenOrNational : Bool
  isCitizenOrRaAllYear : Bool
  isCitizenOrNationalForReturn : Bool

/-- Catala `scope FilerFacts`, definition by definition. -/
def filerFacts (i : FilerFactsIn) : FilerFactsOut :=
  let dayBeforeDateOfBirth := i.dateOfBirth.dayBefore
  let age := taxYear - i.dateOfBirth.year
  let ageCalculatedDayBeforeDob := taxYear - dayBeforeDateOfBirth.year
  let ageDayBeforeDeath := Date.completedYears dayBeforeDateOfBirth i.dateOfDeath
  let ageDayOfDeath := Date.completedYears i.dateOfBirth i.dateOfDeath
  let ageForSelfOnlyEitcLimits :=
    if i.isDeceasedInTaxYear && age == eitcMinimumAge then ageDayBeforeDeath
    else if i.isDeceasedInTaxYear then ageDayOfDeath
    else if ageCalculatedDayBeforeDob == eitcMinimumAge then ageCalculatedDayBeforeDob
    else age
  let citizenAtEndOfTaxYear := !i.isUsCitizenFullYear && i.writableCitizenAtEndOfTaxYear
  let isNoncitizenResidentFullYear :=
    !i.isUsCitizenFullYear && !citizenAtEndOfTaxYear && i.writableIsNoncitizenResidentFullYear
  let isNational :=
    !i.isUsCitizenFullYear && !citizenAtEndOfTaxYear && isNoncitizenResidentFullYear &&
      i.writableIsNational
  { age, ageCalculatedDayBeforeDob
    age65OrOlder := decide (ageCalculatedDayBeforeDob ≥ seniorAge)
    age55OrOlder := decide (age ≥ age55)
    youngerThan16 := decide (age < minimumSupportedFilerAge)
    isUnder18 := decide (ageCalculatedDayBeforeDob < adultAge)
    ageDayBeforeDeath, ageDayOfDeath
    reachedAge65AtDeath := i.isDeceasedInTaxYear && decide (ageDayBeforeDeath ≥ seniorAge)
    ageForSelfOnlyEitcLimits
    age25OrOlderForEitc := decide (ageForSelfOnlyEitcLimits ≥ eitcMinimumAge)
    age64OrYoungerForEitc := decide (ageForSelfOnlyEitcLimits ≤ eitcMaximumAge)
    citizenAtEndOfTaxYear, isNoncitizenResidentFullYear, isNational
    isCitizenOrNational := i.isUsCitizenFullYear || isNoncitizenResidentFullYear || isNational
    isCitizenOrRaAllYear :=
      isNoncitizenResidentFullYear || i.isUsCitizenFullYear || citizenAtEndOfTaxYear
    isCitizenOrNationalForReturn :=
      i.isUsCitizenFullYear || citizenAtEndOfTaxYear || isNational }

/-! ### Scope `Filers` -/

/-- Inputs of `Filers`. -/
structure FilersIn where
  filingStatus : FilingStatus
  maritalStatus : MaritalStatus
  yearOfSpouseDeath : YearOfSpouseDeath
  primaryFiler : FilerAnswers
  secondaryFiler : FilerAnswers
  secondaryFilerDateOfDeath : Date
  primaryFilerPotentialClaimerFiledOnlyForRefund : Bool
  mfjRequiredToFile : Bool
  mfjDependentsFilingForCredits : Bool
  livedTogetherAllYearWithSpouse : Bool
  spouseLivedTogetherMonths : SpouseLivedTogetherMonths
  writableLivedApartLastSixMonths : Bool
  writableSeparationAgreement : Bool
  canFileJointlyYearOfSpouseDeath : Bool
  inRegisteredDomesticPartnership : Bool
  filerResidenceAndIncomeState : ScopedState
  spouseItemizes : Bool
  mfsLivingSpouseFilingReturn : Bool
  mfsDeceasedSpouseFilingReturn : Bool
  mfsSpouseHasGrossIncome : Bool
  /-- DF filingStatus.xml `/eligibleForHoh`, computed by the household modules; only the
  community-property knockout reads it here. -/
  eligibleForHoh : Bool

/-- Outputs of `Filers` (Catala `output` variables; `internal` ones are local). -/
structure FilersOut where
  isMarried : Bool
  isSingle : Bool
  isWidowed : Bool
  isWidowedInTaxYear : Bool
  widowedBeforeTaxYearMinusTwo : Bool
  widowedCouldQualifyForQss : Bool
  filerCouldQualifyForQss : Bool
  isFilingStatusMfj : Bool
  secondaryFilerResidencyEligibleForMfj : Bool
  eligibleForMfj : Bool
  eligibleForMfs : Bool
  eligibleForSingle : Bool
  treatAsMfj : Bool
  treatAsMfs : Bool
  livedApartAllYear : Bool
  livedApartLastSixMonths : Bool
  separationAgreement : Bool
  specialRuleForSeparatedSpouses : Bool
  filerCouldQualifyForHoh : Bool
  mfsFilerCouldBeConsideredUnmarriedForCdcc : Bool
  filersCouldQualifyForCdcc : Bool
  primaryFilerAge : Int
  secondaryFilerAge : Int
  primaryFilerAge65OrOlder : Bool
  secondaryFilerAge65OrOlder : Bool
  primaryFilerAge25OrOlderForEitc : Bool
  secondaryFilerAge25OrOlderForEitc : Bool
  primaryFilerAge64OrYoungerForEitc : Bool
  secondaryFilerAge64OrYoungerForEitc : Bool
  mfjDeceasedSpouseReachedAge65ForStandardD : Bool
  atLeastOneTpIs65OrOlder : Bool
  atLeastOneTpIsUnder65 : Bool
  xmlOver65SrIndicator : Bool
  minimumFilerDateOfBirth : Date
  filersUsCitizenOrRaAllYear : Bool
  eitherFilerUsCitizenOrNational : Bool
  allEligibleFilersAreUsCitizensOrNationals : Bool
  isSecondaryFilerNra : Bool
  primaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits : Bool
  notMfjAndPrimaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits : Bool
  eitherFilerCanBeClaimed : Bool
  mfjClaimingRefundOnly : Bool
  mfjNotRequiredToFileAndEitherFilerCanBeClaimed : Bool
  isMfjDependent : Bool
  taxpayerCannotBeClaimed : Bool
  primaryFilerIsClaimedAsDependent : Bool
  secondaryFilerIsClaimedAsDependent : Bool
  eitherFilerIsClaimedAsDependent : Bool
  treatFilersAsDependents : Bool
  filersCouldntBeDependents : Bool
  primarySomeOneCanClaimForTaxBenefits : Bool
  secondarySomeOneCanClaimForTaxBenefits : Bool
  isSpouseExempt : Bool
  mfsSpouseProvidesNoBenefits : Bool
  koFlowKnockoutFilerAgeYoungerThan16 : Bool
  koSpouseItemizesKnockout : Bool
  koPrimaryFilerResidencyKnockout : Bool
  koFlowKnockoutHasApplicableRegisteredDomesticPartnership : Bool
  koKnockoutSubjectToCommunityPropertyLaws : Bool
  unsupported : Bool

/-- Catala `scope Filers`, definition by definition, in the order of the Catala file. -/
def filers (i : FilersIn) : FilersOut :=
  -- sub-scope wiring
  let primaryFacts := filerFacts
    { dateOfBirth := i.primaryFiler.dateOfBirth, isDeceasedInTaxYear := false
      dateOfDeath := i.secondaryFilerDateOfDeath
      isUsCitizenFullYear := i.primaryFiler.isUsCitizenFullYear
      writableCitizenAtEndOfTaxYear := i.primaryFiler.writableCitizenAtEndOfTaxYear
      writableIsNoncitizenResidentFullYear := i.primaryFiler.writableIsNoncitizenResidentFullYear
      writableIsNational := i.primaryFiler.writableIsNational }
  -- marital status rules
  let isMarried := i.maritalStatus == .married
  let isSingle := i.maritalStatus == .neverMarried
  let isWidowed := i.maritalStatus == .widowed
  let isWidowedInTaxYear := isWidowed && i.yearOfSpouseDeath == .diedInTaxYear
  let widowedBeforeTaxYearMinusTwo := isWidowed && i.yearOfSpouseDeath == .diedBeforeTaxYearMinusTwo
  let widowedCouldQualifyForQss :=
    isWidowed && (i.yearOfSpouseDeath == .diedTaxYearMinusOne ||
      i.yearOfSpouseDeath == .diedTaxYearMinusTwo)
  let secondaryFacts := filerFacts
    { dateOfBirth := i.secondaryFiler.dateOfBirth, isDeceasedInTaxYear := isWidowedInTaxYear
      dateOfDeath := i.secondaryFilerDateOfDeath
      isUsCitizenFullYear := i.secondaryFiler.isUsCitizenFullYear
      writableCitizenAtEndOfTaxYear := i.secondaryFiler.writableCitizenAtEndOfTaxYear
      writableIsNoncitizenResidentFullYear := i.secondaryFiler.writableIsNoncitizenResidentFullYear
      writableIsNational := i.secondaryFiler.writableIsNational }
  let filerCouldQualifyForQss := widowedCouldQualifyForQss && i.canFileJointlyYearOfSpouseDeath
  -- filing status basics
  let isFilingStatusMfj := i.filingStatus == marriedFilingJointly
  let maritalStatusAllowsFilingMarried := isMarried || isWidowedInTaxYear
  let secondaryFilerResidencyEligibleForMfj :=
    i.secondaryFiler.isUsCitizenFullYear || secondaryFacts.citizenAtEndOfTaxYear ||
      secondaryFacts.isNoncitizenResidentFullYear
  let eligibleForMfj := maritalStatusAllowsFilingMarried && secondaryFilerResidencyEligibleForMfj
  let eligibleForMfs := maritalStatusAllowsFilingMarried
  let eligibleForSingle := !maritalStatusAllowsFilingMarried
  let treatAsMfj := isFilingStatusMfj && eligibleForMfj
  let treatAsMfs := i.filingStatus == marriedFilingSeparately
  let treatAsHoh := i.filingStatus == headOfHousehold
  -- lived apart rules
  let livedTogetherSixMonthsOrLess :=
    !i.livedTogetherAllYearWithSpouse && i.spouseLivedTogetherMonths == .livedTogetherSixMonthsOrLess
  let livedTogetherMoreThanSixMonths :=
    !i.livedTogetherAllYearWithSpouse &&
      i.spouseLivedTogetherMonths == .livedTogetherMoreThanSixMonths
  let livedApartAllYear :=
    !i.livedTogetherAllYearWithSpouse && i.spouseLivedTogetherMonths == .livedApartAllYear
  let livedApartLastSixMonths :=
    if livedTogetherMoreThanSixMonths || i.livedTogetherAllYearWithSpouse then false
    else if livedApartAllYear then true
    else if livedTogetherSixMonthsOrLess then i.writableLivedApartLastSixMonths
    else false
  let separationAgreement :=
    if i.livedTogetherAllYearWithSpouse then false else i.writableSeparationAgreement
  let specialRuleForSeparatedSpouses := livedApartLastSixMonths || separationAgreement
  let filerCouldQualifyForHoh := !eligibleForMfj || (eligibleForMfj && livedApartLastSixMonths)
  let mfsFilerCouldBeConsideredUnmarriedForCdcc := treatAsMfs && livedApartLastSixMonths
  let filersCouldQualifyForCdcc :=
    if treatAsMfs then mfsFilerCouldBeConsideredUnmarriedForCdcc else true
  -- ages of both filers
  let atLeastOneTpIs65OrOlder :=
    if isFilingStatusMfj then primaryFacts.age65OrOlder || secondaryFacts.age65OrOlder
    else primaryFacts.age65OrOlder
  let atLeastOneTpIsUnder65 :=
    if isFilingStatusMfj then !primaryFacts.age65OrOlder || !secondaryFacts.age65OrOlder
    else !primaryFacts.age65OrOlder
  let xmlOver65SrIndicator :=
    primaryFacts.age65OrOlder || (isFilingStatusMfj && secondaryFacts.age65OrOlder)
  let minimumFilerDateOfBirth :=
    if treatAsMfj && i.secondaryFiler.dateOfBirth.lt i.primaryFiler.dateOfBirth
    then i.secondaryFiler.dateOfBirth else i.primaryFiler.dateOfBirth
  -- citizenship and residency rules
  let filersUsCitizenOrRaAllYear :=
    if treatAsMfj then primaryFacts.isCitizenOrRaAllYear && secondaryFacts.isCitizenOrRaAllYear
    else primaryFacts.isCitizenOrRaAllYear
  let eitherFilerUsCitizenOrNational :=
    if treatAsMfj
    then primaryFacts.isCitizenOrNationalForReturn || secondaryFacts.isCitizenOrNationalForReturn
    else primaryFacts.isCitizenOrNationalForReturn
  let allEligibleFilersAreUsCitizensOrNationals :=
    if treatAsMfj
    then primaryFacts.isCitizenOrNationalForReturn && secondaryFacts.isCitizenOrNationalForReturn
    else primaryFacts.isCitizenOrNationalForReturn
  let isSecondaryFilerNra := !secondaryFacts.isCitizenOrRaAllYear
  -- dependency rules
  let pcb :=
    i.primaryFiler.canBeClaimed &&
      (i.primaryFiler.potentialClaimerMustFile ||
        (!i.primaryFiler.potentialClaimerMustFile && i.primaryFiler.potentialClaimerDidFile &&
          !i.primaryFilerPotentialClaimerFiledOnlyForRefund))
  let notMfjPcb := !isFilingStatusMfj && pcb
  let eitherFilerCanBeClaimed := i.primaryFiler.canBeClaimed || i.secondaryFiler.canBeClaimed
  let mfjClaimingRefundOnly := !i.mfjDependentsFilingForCredits
  let mfjNotRequiredToFileAndEitherFilerCanBeClaimed :=
    !i.mfjRequiredToFile && eitherFilerCanBeClaimed
  let flowMfjSpouseFilingRequirementSubsection :=
    i.secondaryFiler.canBeClaimed || (!i.secondaryFiler.canBeClaimed && pcb)
  let isMfjDependent :=
    treatAsMfj && flowMfjSpouseFilingRequirementSubsection && !i.mfjRequiredToFile &&
      mfjClaimingRefundOnly
  let taxpayerCannotBeClaimed :=
    treatAsMfj && flowMfjSpouseFilingRequirementSubsection && !i.mfjRequiredToFile &&
      !mfjClaimingRefundOnly
  let primaryFilerIsClaimedAsDependent :=
    pcb && i.primaryFiler.willBeClaimed && !taxpayerCannotBeClaimed
  let secondaryFilerIsClaimedAsDependent :=
    treatAsMfj && !i.mfjRequiredToFile && i.secondaryFiler.canBeClaimed &&
      i.secondaryFiler.willBeClaimed && !taxpayerCannotBeClaimed
  let treatFilersAsDependents := if treatAsMfj then isMfjDependent else pcb
  let filersCouldntBeDependents :=
    if treatAsMfj then !isMfjDependent else !i.primaryFiler.canBeClaimed
  -- MFS spouse
  let mfsSpouseFilingReturnDerived :=
    if isWidowed then i.mfsDeceasedSpouseFilingReturn else i.mfsLivingSpouseFilingReturn
  -- knockout rules
  let livesInCommunityPropertyState :=
    [ScopedState.az, .ca, .id, .nm, .nv, .tx, .wa, .wi].contains i.filerResidenceAndIncomeState
  let checkForRegisteredDomesticPartner :=
    livesInCommunityPropertyState &&
      (i.maritalStatus == .neverMarried || i.maritalStatus == .divorced ||
        i.maritalStatus == .widowed)
  let koFlowKnockoutFilerAgeYoungerThan16 :=
    primaryFacts.youngerThan16 || (secondaryFacts.youngerThan16 && treatAsMfj)
  let koSpouseItemizesKnockout := i.spouseItemizes && mfsSpouseFilingReturnDerived
  let koPrimaryFilerResidencyKnockout :=
    !i.primaryFiler.isUsCitizenFullYear && !primaryFacts.citizenAtEndOfTaxYear &&
      !primaryFacts.isNoncitizenResidentFullYear
  let koFlowKnockoutHasApplicableRegisteredDomesticPartnership :=
    checkForRegisteredDomesticPartner && i.inRegisteredDomesticPartnership
  let koKnockoutSubjectToCommunityPropertyLaws :=
    livesInCommunityPropertyState &&
      ((isMarried && !eligibleForMfj && !i.eligibleForHoh) || treatAsMfs ||
        (treatAsHoh && i.maritalStatus == .married))
  { isMarried, isSingle, isWidowed, isWidowedInTaxYear, widowedBeforeTaxYearMinusTwo
    widowedCouldQualifyForQss, filerCouldQualifyForQss, isFilingStatusMfj
    secondaryFilerResidencyEligibleForMfj, eligibleForMfj, eligibleForMfs, eligibleForSingle
    treatAsMfj, treatAsMfs, livedApartAllYear, livedApartLastSixMonths, separationAgreement
    specialRuleForSeparatedSpouses, filerCouldQualifyForHoh
    mfsFilerCouldBeConsideredUnmarriedForCdcc, filersCouldQualifyForCdcc
    primaryFilerAge := primaryFacts.age
    secondaryFilerAge := secondaryFacts.age
    primaryFilerAge65OrOlder := primaryFacts.age65OrOlder
    secondaryFilerAge65OrOlder := secondaryFacts.age65OrOlder
    primaryFilerAge25OrOlderForEitc := primaryFacts.age25OrOlderForEitc
    secondaryFilerAge25OrOlderForEitc := secondaryFacts.age25OrOlderForEitc
    primaryFilerAge64OrYoungerForEitc := primaryFacts.age64OrYoungerForEitc
    secondaryFilerAge64OrYoungerForEitc := secondaryFacts.age64OrYoungerForEitc
    mfjDeceasedSpouseReachedAge65ForStandardD := secondaryFacts.reachedAge65AtDeath
    atLeastOneTpIs65OrOlder, atLeastOneTpIsUnder65, xmlOver65SrIndicator
    minimumFilerDateOfBirth, filersUsCitizenOrRaAllYear, eitherFilerUsCitizenOrNational
    allEligibleFilersAreUsCitizensOrNationals, isSecondaryFilerNra
    primaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits := pcb
    notMfjAndPrimaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits := notMfjPcb
    eitherFilerCanBeClaimed, mfjClaimingRefundOnly
    mfjNotRequiredToFileAndEitherFilerCanBeClaimed, isMfjDependent, taxpayerCannotBeClaimed
    primaryFilerIsClaimedAsDependent, secondaryFilerIsClaimedAsDependent
    eitherFilerIsClaimedAsDependent := primaryFilerIsClaimedAsDependent || secondaryFilerIsClaimedAsDependent
    treatFilersAsDependents, filersCouldntBeDependents
    primarySomeOneCanClaimForTaxBenefits :=
      (isFilingStatusMfj && isMfjDependent && pcb) || notMfjPcb
    secondarySomeOneCanClaimForTaxBenefits :=
      isFilingStatusMfj && isMfjDependent && i.secondaryFiler.canBeClaimed
    isSpouseExempt := !i.secondaryFiler.canBeClaimed && isFilingStatusMfj
    mfsSpouseProvidesNoBenefits :=
      mfsSpouseFilingReturnDerived || i.mfsSpouseHasGrossIncome || i.secondaryFiler.canBeClaimed
    koFlowKnockoutFilerAgeYoungerThan16, koSpouseItemizesKnockout
    koPrimaryFilerResidencyKnockout
    koFlowKnockoutHasApplicableRegisteredDomesticPartnership
    koKnockoutSubjectToCommunityPropertyLaws
    unsupported :=
      koFlowKnockoutFilerAgeYoungerThan16 || koSpouseItemizesKnockout ||
        koPrimaryFilerResidencyKnockout ||
        koFlowKnockoutHasApplicableRegisteredDomesticPartnership ||
        koKnockoutSubjectToCommunityPropertyLaws }

/-! ### Scope `FilersStandardDeduction` -/

/-- Inputs of `FilersStandardDeduction`: those of `Filers` plus two. -/
structure FilersStandardDeductionIn extends FilersIn where
  /-- DF filers.xml `/MFSSpouse65OrOlder`. -/
  mfsSpouse65OrOlder : Bool
  /-- DF income.xml `/employerIncomeSubtotal`, cents. -/
  employerIncomeSubtotal : Int

/-- Outputs of `FilersStandardDeduction`. -/
structure FilersStandardDeductionOut where
  standardDeduction : Int
  additionalStandardDeductionItems : Int
  isSpouse65OrOlder : Bool
  secondaryFilerIsBlindIndicatorXml : Bool
  xmlOver65SrIndicator : Bool
  primarySomeOneCanClaimForTaxBenefits : Bool
  secondarySomeOneCanClaimForTaxBenefits : Bool
  unsupported : Bool

/-- Catala `scope FilersStandardDeduction`: `Filers` feeding `StandardDeduction`. -/
def filersStandardDeduction (i : FilersStandardDeductionIn) : FilersStandardDeductionOut :=
  let f := filers i.toFilersIn
  let sd := StandardDeduction.standardDeduction
    { filingStatus := i.filingStatus
      treatAsMfs := f.treatAsMfs
      primaryFilerIsBlind := i.primaryFiler.isBlind
      primaryFilerAge65OrOlder := f.primaryFilerAge65OrOlder
      secondaryFilerIsBlind := i.secondaryFiler.isBlind
      secondaryFilerAge65OrOlder := f.secondaryFilerAge65OrOlder
      isWidowedInTaxYear := f.isWidowedInTaxYear
      mfjDeceasedSpouseReachedAge65 := f.mfjDeceasedSpouseReachedAge65ForStandardD
      mfsSpouse65OrOlder := i.mfsSpouse65OrOlder
      mfsSpouseProvidesNoBenefits := f.mfsSpouseProvidesNoBenefits
      treatFilersAsDependents := f.treatFilersAsDependents
      employerIncomeSubtotal := i.employerIncomeSubtotal }
  { standardDeduction := sd.standardDeduction
    additionalStandardDeductionItems := sd.additionalStandardDeductionItems
    isSpouse65OrOlder := sd.isSpouse65OrOlder
    secondaryFilerIsBlindIndicatorXml :=
      sd.isSpouseInfoApplicableForStandardDeductions && i.secondaryFiler.isBlind
    xmlOver65SrIndicator := f.xmlOver65SrIndicator
    primarySomeOneCanClaimForTaxBenefits := f.primarySomeOneCanClaimForTaxBenefits
    secondarySomeOneCanClaimForTaxBenefits := f.secondarySomeOneCanClaimForTaxBenefits
    unsupported := f.unsupported }

/-! ### Unit tests: every assertion of `catala/tests/test_filers.catala_en`

`Case` of the Catala test is `baseline`: a single filer born 1985-06-15, a US citizen, not
claimed by anyone, living in Florida, $50,000 of employer income. A test overrides only what
it tests. -/

/-- A plain US-citizen answer set born on `dob`. -/
def citizen (dob : Date) : FilerAnswers :=
  { dateOfBirth := dob, isBlind := false, canBeClaimed := false, willBeClaimed := false
    potentialClaimerMustFile := false, potentialClaimerDidFile := false
    isUsCitizenFullYear := true, writableCitizenAtEndOfTaxYear := false
    writableIsNoncitizenResidentFullYear := false, writableIsNational := false }

/-- The Catala test `Case` with its defaults. -/
def baseline : FilersStandardDeductionIn :=
  { filingStatus := single, maritalStatus := .neverMarried
    yearOfSpouseDeath := .diedBeforeTaxYearMinusTwo
    primaryFiler := citizen ⟨1985, 6, 15⟩, secondaryFiler := citizen ⟨1985, 6, 15⟩
    secondaryFilerDateOfDeath := ⟨2024, 12, 31⟩
    primaryFilerPotentialClaimerFiledOnlyForRefund := false
    mfjRequiredToFile := true, mfjDependentsFilingForCredits := false
    livedTogetherAllYearWithSpouse := true, spouseLivedTogetherMonths := .livedApartAllYear
    writableLivedApartLastSixMonths := false, writableSeparationAgreement := false
    canFileJointlyYearOfSpouseDeath := false, inRegisteredDomesticPartnership := false
    filerResidenceAndIncomeState := .fl, spouseItemizes := false
    mfsLivingSpouseFilingReturn := false, mfsDeceasedSpouseFilingReturn := false
    mfsSpouseHasGrossIncome := false, eligibleForHoh := false
    mfsSpouse65OrOlder := false, employerIncomeSubtotal := 5_000_000 }

private def F (c : FilersStandardDeductionIn) : FilersOut := filers c.toFilersIn
private def SD (c : FilersStandardDeductionIn) : Int := (filersStandardDeduction c).standardDeduction
private def withPrimaryDob (c : FilersStandardDeductionIn) (d : Date) : FilersStandardDeductionIn :=
  { c with primaryFiler := { c.primaryFiler with dateOfBirth := d } }
private def withSecondaryDob (c : FilersStandardDeductionIn) (d : Date) : FilersStandardDeductionIn :=
  { c with secondaryFiler := { c.secondaryFiler with dateOfBirth := d } }
private def widowedMfj : FilersStandardDeductionIn :=
  { baseline with filingStatus := marriedFilingJointly, maritalStatus := .widowed
                  yearOfSpouseDeath := .diedInTaxYear }
private def marriedMfj : FilersStandardDeductionIn :=
  { baseline with filingStatus := marriedFilingJointly, maritalStatus := .married }

-- TestAge65
#guard (F (withPrimaryDob baseline ⟨1960, 1, 1⟩)).primaryFilerAge65OrOlder
#guard !(F (withPrimaryDob baseline ⟨1960, 1, 2⟩)).primaryFilerAge65OrOlder
#guard (F (withPrimaryDob baseline ⟨1959, 12, 31⟩)).primaryFilerAge65OrOlder
#guard (F (withPrimaryDob baseline ⟨1960, 1, 1⟩)).primaryFilerAge == 64
#guard (F (withPrimaryDob baseline ⟨1960, 1, 2⟩)).primaryFilerAge == 64
#guard (F (withPrimaryDob baseline ⟨1959, 12, 31⟩)).primaryFilerAge == 65
-- known-bad output: the plain-age rule disagrees with the spec for Jan 1, 1960
#guard (F (withPrimaryDob baseline ⟨1960, 1, 1⟩)).primaryFilerAge65OrOlder !=
  decide ((F (withPrimaryDob baseline ⟨1960, 1, 1⟩)).primaryFilerAge ≥ 65)

-- TestAge65Reference: Pub 501 "65th birthday on or before January 1 of the following year"
private def pub501Age65 (d : Date) : Bool := Date.lt ⟨d.year + 65, d.month, d.day⟩ ⟨2025, 1, 2⟩
#guard [Date.mk 1959 12 31, ⟨1960, 1, 1⟩, ⟨1960, 1, 2⟩, ⟨1960, 7, 4⟩, ⟨1930, 2, 28⟩].all fun d =>
  (F (withPrimaryDob baseline d)).primaryFilerAge65OrOlder == pub501Age65 d

-- TestEitcAge
#guard (F (withPrimaryDob baseline ⟨2000, 1, 1⟩)).primaryFilerAge25OrOlderForEitc
#guard !(F (withPrimaryDob baseline ⟨2000, 1, 2⟩)).primaryFilerAge25OrOlderForEitc
#guard (F (withPrimaryDob baseline ⟨1999, 12, 31⟩)).primaryFilerAge25OrOlderForEitc
#guard (F (withPrimaryDob baseline ⟨1960, 1, 1⟩)).primaryFilerAge64OrYoungerForEitc
#guard (F (withPrimaryDob baseline ⟨1960, 1, 1⟩)).primaryFilerAge65OrOlder
#guard (F (withPrimaryDob baseline ⟨1960, 1, 2⟩)).primaryFilerAge64OrYoungerForEitc
#guard !(F (withPrimaryDob baseline ⟨1959, 12, 31⟩)).primaryFilerAge64OrYoungerForEitc

-- TestDeceasedSpouse
private def deceased (dob dod : Date) : FilersOut :=
  F { withSecondaryDob widowedMfj dob with secondaryFilerDateOfDeath := dod }
#guard (deceased ⟨1999, 2, 14⟩ ⟨2024, 2, 13⟩).treatAsMfj
#guard (deceased ⟨1999, 2, 14⟩ ⟨2024, 2, 13⟩).secondaryFilerAge25OrOlderForEitc
#guard !(deceased ⟨1999, 2, 14⟩ ⟨2024, 2, 12⟩).secondaryFilerAge25OrOlderForEitc
#guard (deceased ⟨1959, 7, 10⟩ ⟨2024, 7, 9⟩).mfjDeceasedSpouseReachedAge65ForStandardD
#guard !(deceased ⟨1959, 7, 10⟩ ⟨2024, 7, 8⟩).mfjDeceasedSpouseReachedAge65ForStandardD
#guard (deceased ⟨1959, 7, 10⟩ ⟨2024, 7, 9⟩).secondaryFilerAge64OrYoungerForEitc

-- TestMarital
#guard (F marriedMfj).eligibleForMfj && (F marriedMfj).treatAsMfj
private def nraSpouse : FilersStandardDeductionIn :=
  { marriedMfj with secondaryFiler := { marriedMfj.secondaryFiler with isUsCitizenFullYear := false } }
#guard !(F nraSpouse).eligibleForMfj
#guard !(F nraSpouse).treatAsMfj
private def widowedPriorYear : FilersStandardDeductionIn :=
  { baseline with filingStatus := marriedFilingJointly, maritalStatus := .widowed
                  yearOfSpouseDeath := .diedTaxYearMinusOne }
#guard !(F widowedPriorYear).eligibleForMfj
#guard !(F widowedPriorYear).treatAsMfj
#guard !(F { baseline with filingStatus := marriedFilingJointly }).treatAsMfj

-- TestLivedApart
private def livedApart (all : Bool) (m : SpouseLivedTogetherMonths) (w sep : Bool) :
    FilersStandardDeductionIn :=
  { baseline with maritalStatus := .married, livedTogetherAllYearWithSpouse := all
                  spouseLivedTogetherMonths := m, writableLivedApartLastSixMonths := w
                  writableSeparationAgreement := sep }
#guard !(F (livedApart true .livedApartAllYear false false)).livedApartLastSixMonths
#guard !(F (livedApart true .livedApartAllYear false false)).filerCouldQualifyForHoh
#guard (F (livedApart false .livedApartAllYear false false)).livedApartLastSixMonths
#guard (F (livedApart false .livedApartAllYear false false)).filerCouldQualifyForHoh
-- the stale writable answer is ignored when the spouses lived together more than six months
#guard !(F (livedApart false .livedTogetherMoreThanSixMonths true false)).livedApartLastSixMonths
#guard (F (livedApart false .livedTogetherSixMonthsOrLess true false)).livedApartLastSixMonths
#guard !(F (livedApart false .livedTogetherSixMonthsOrLess false true)).livedApartLastSixMonths
#guard (F (livedApart false .livedTogetherSixMonthsOrLess false true)).specialRuleForSeparatedSpouses

-- TestDependents
private def claimed (mustFile didFile onlyRefund : Bool) : FilersStandardDeductionIn :=
  { baseline with
    primaryFiler := { baseline.primaryFiler with
      canBeClaimed := true, willBeClaimed := true, potentialClaimerMustFile := mustFile
      potentialClaimerDidFile := didFile }
    primaryFilerPotentialClaimerFiledOnlyForRefund := onlyRefund }
#guard (F (claimed true false false)).treatFilersAsDependents
#guard !(F (claimed false true true)).treatFilersAsDependents
#guard !(F { baseline with primaryFiler := { baseline.primaryFiler with
    potentialClaimerMustFile := true } }).treatFilersAsDependents
#guard (F (claimed false true false)).treatFilersAsDependents
private def mfjDep (required credits : Bool) : FilersStandardDeductionIn :=
  { marriedMfj with
    secondaryFiler := { marriedMfj.secondaryFiler with canBeClaimed := true, willBeClaimed := true }
    mfjRequiredToFile := required, mfjDependentsFilingForCredits := credits }
#guard (F (mfjDep false false)).isMfjDependent
#guard (F (mfjDep false false)).treatFilersAsDependents
#guard !(F (mfjDep false false)).taxpayerCannotBeClaimed
#guard !(F (mfjDep false true)).isMfjDependent
#guard !(F (mfjDep false true)).treatFilersAsDependents
#guard (F (mfjDep false true)).taxpayerCannotBeClaimed
#guard !(F (mfjDep true false)).isMfjDependent
#guard !(F (mfjDep true false)).treatFilersAsDependents

-- TestKnockouts
#guard !(F baseline).unsupported
#guard (F (withPrimaryDob baseline ⟨2009, 1, 1⟩)).koFlowKnockoutFilerAgeYoungerThan16
#guard (F (withPrimaryDob baseline ⟨2009, 1, 1⟩)).unsupported
#guard !(F (withPrimaryDob baseline ⟨2008, 12, 31⟩)).koFlowKnockoutFilerAgeYoungerThan16
#guard (F (withSecondaryDob marriedMfj ⟨2010, 5, 5⟩)).koFlowKnockoutFilerAgeYoungerThan16
#guard !(F (withSecondaryDob baseline ⟨2010, 5, 5⟩)).koFlowKnockoutFilerAgeYoungerThan16
private def communityMfs : FilersStandardDeductionIn :=
  { baseline with filingStatus := marriedFilingSeparately, maritalStatus := .married
                  filerResidenceAndIncomeState := .ca }
#guard (F communityMfs).koKnockoutSubjectToCommunityPropertyLaws
#guard (F communityMfs).unsupported
#guard !(F { baseline with filerResidenceAndIncomeState := .ca }).koKnockoutSubjectToCommunityPropertyLaws
#guard (F { baseline with filingStatus := headOfHousehold, maritalStatus := .married
                          filerResidenceAndIncomeState := .tx }).koKnockoutSubjectToCommunityPropertyLaws
#guard !(F { baseline with filingStatus := marriedFilingSeparately, maritalStatus := .married
                           }).koKnockoutSubjectToCommunityPropertyLaws
#guard (F { baseline with filerResidenceAndIncomeState := .wa
                          inRegisteredDomesticPartnership := true
                          }).koFlowKnockoutHasApplicableRegisteredDomesticPartnership
#guard !(F { baseline with inRegisteredDomesticPartnership := true
                           }).koFlowKnockoutHasApplicableRegisteredDomesticPartnership
#guard (F { baseline with primaryFiler := { baseline.primaryFiler with isUsCitizenFullYear := false }
                          }).koPrimaryFilerResidencyKnockout
#guard !(F baseline).koPrimaryFilerResidencyKnockout
#guard (F { baseline with filingStatus := marriedFilingSeparately, maritalStatus := .married
                          spouseItemizes := true, mfsLivingSpouseFilingReturn := true
                          }).koSpouseItemizesKnockout
#guard !(F baseline).koSpouseItemizesKnockout

-- TestMinimumDob
#guard (F (withSecondaryDob (withPrimaryDob marriedMfj ⟨1985, 6, 15⟩) ⟨1980, 3, 1⟩)).minimumFilerDateOfBirth ==
  ⟨1980, 3, 1⟩
#guard (F (withSecondaryDob (withPrimaryDob baseline ⟨1985, 6, 15⟩) ⟨1980, 3, 1⟩)).minimumFilerDateOfBirth ==
  ⟨1985, 6, 15⟩

-- TestStandardDeductionWiring
#guard SD (withPrimaryDob baseline ⟨1960, 1, 1⟩) == 1_655_000
#guard SD (withPrimaryDob baseline ⟨1960, 1, 2⟩) == 1_460_000
#guard SD (withSecondaryDob (withPrimaryDob marriedMfj ⟨1960, 1, 1⟩) ⟨1960, 1, 1⟩) == 3_230_000
#guard SD { withSecondaryDob widowedMfj ⟨1959, 7, 10⟩ with secondaryFilerDateOfDeath := ⟨2024, 7, 9⟩ } == 3_075_000
#guard SD { withSecondaryDob widowedMfj ⟨1959, 7, 10⟩ with secondaryFilerDateOfDeath := ⟨2024, 7, 8⟩ } == 2_920_000
#guard SD { baseline with
    primaryFiler := { baseline.primaryFiler with canBeClaimed := true, willBeClaimed := true
                                                 potentialClaimerMustFile := true }
    employerIncomeSubtotal := 300_000 } == 345_000
#guard SD (mfjDep false false) == 2_920_000

end UsTax.Filers
