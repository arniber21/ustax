import UsTax.HohQssPersons

/-!
# Filing status: eligibility, validity and recommendation (issue #44)

Lean implementation of `catala/filing_status.catala_en` (module `Filing_status`), written by
hand from the Catala source under strategy (c) of `docs/catala-to-lean.md`, in the order of
the Catala file.

| Catala (`Filing_status`)               | Lean (`UsTax.FilingStatus`)                     |
|----------------------------------------|-------------------------------------------------|
| `scope FilingStatusEligibility`        | `EligibilityIn` → `EligibilityOut` (`eligibility`) |
| `scope FilingStatusReturn`             | `FilingStatusReturnIn` → `FilingStatusReturnOut` (`filingStatusReturn`) |

`FilingStatusReturn` runs `Filers` (stage 1, `eligibleForHoh := false`), the household
(stage 2), the eligibility check (stage 3), and `Filers` again with the stage-3
`eligibleForHoh` for its knockouts only, as in Catala.
-/

namespace UsTax.FilingStatusMod

open FilingStatus Filers HohQssPersons

/-! ### Scope `FilingStatusEligibility` -/

/-- Inputs of `FilingStatusEligibility`. -/
structure EligibilityIn where
  filingStatus : FilingStatus
  maritalStatusAllowsFilingMarried : Bool
  eligibleForMfj : Bool
  filerCouldQualifyForHoh : Bool
  filerCouldQualifyForQss : Bool
  hohQualifyingPeopleCount : Int
  qssQualifyingPeopleCount : Int

/-- Outputs of `FilingStatusEligibility`. -/
structure EligibilityOut where
  eligibleForMfs : Bool
  eligibleForQss : Bool
  eligibleForHoh : Bool
  eligibleForSingle : Bool
  isFilingStatusSingle : Bool
  isFilingStatusMfj : Bool
  isFilingStatusMfs : Bool
  isFilingStatusHoh : Bool
  isFilingStatusQss : Bool
  treatAsHoh : Bool
  eligibleFilingStatusCount : Int
  hasMultipleEligibleFilingStatuses : Bool
  isFilingStatusValid : Bool
  recommendedFilingStatus : FilingStatus
  koFilingStatusNotEligible : Bool
  unsupported : Bool

/-- Catala `scope FilingStatusEligibility`, definition by definition. -/
def eligibility (i : EligibilityIn) : EligibilityOut :=
  let isSingle := i.filingStatus == single
  let isMfj := i.filingStatus == marriedFilingJointly
  let isMfs := i.filingStatus == marriedFilingSeparately
  let isHoh := i.filingStatus == headOfHousehold
  let isQss := i.filingStatus == qualifyingSurvivingSpouse
  let wantsSeparateReturn := isMfs
  let eligibleForMfs := i.maritalStatusAllowsFilingMarried
  let eligibleForQss := i.filerCouldQualifyForQss && decide (i.qssQualifyingPeopleCount > 0)
  let eligibleForHoh :=
    decide (i.hohQualifyingPeopleCount > 0) && i.filerCouldQualifyForHoh && !eligibleForQss
  let eligibleForSingle := !i.maritalStatusAllowsFilingMarried
  let isFilingStatusValid :=
    (isMfj && i.eligibleForMfj) || (isMfs && eligibleForMfs) || (isSingle && eligibleForSingle) ||
      (isHoh && eligibleForHoh) || (isQss && eligibleForQss)
  let bit (b : Bool) : Int := if b then 1 else 0
  let count := bit i.eligibleForMfj + bit eligibleForMfs + bit eligibleForSingle +
    bit eligibleForHoh + bit eligibleForQss
  let recommended :=
    if i.eligibleForMfj then
      (if !wantsSeparateReturn then marriedFilingJointly
       else if eligibleForHoh then headOfHousehold
       else marriedFilingSeparately)
    else if eligibleForQss then qualifyingSurvivingSpouse
    else if eligibleForHoh then headOfHousehold
    else if eligibleForMfs then marriedFilingSeparately
    else single
  let ko := !isFilingStatusValid
  { eligibleForMfs, eligibleForQss, eligibleForHoh, eligibleForSingle
    isFilingStatusSingle := isSingle, isFilingStatusMfj := isMfj, isFilingStatusMfs := isMfs
    isFilingStatusHoh := isHoh, isFilingStatusQss := isQss, treatAsHoh := isHoh
    eligibleFilingStatusCount := count, hasMultipleEligibleFilingStatuses := decide (count > 1)
    isFilingStatusValid, recommendedFilingStatus := recommended
    koFilingStatusNotEligible := ko, unsupported := ko }

/-! ### Scope `FilingStatusReturn` -/

/-- Inputs of `FilingStatusReturn`: those of `Filers` without `eligibleForHoh`, plus the
household. -/
structure FilingStatusReturnIn where
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
  members : List HohQssPersons.Member

/-- Outputs of `FilingStatusReturn` (sub-scope results and scalar copies). -/
structure FilingStatusReturnOut where
  filers : FilersOut
  household : HohQssPersonsOut
  eligibility : EligibilityOut
  filersKnockouts : FilersOut
  maritalStatusAllowsFilingMarried : Bool
  eligibleForMfj : Bool
  eligibleForMfs : Bool
  eligibleForSingle : Bool
  eligibleForHoh : Bool
  eligibleForQss : Bool
  filerCouldQualifyForHoh : Bool
  filerCouldQualifyForQss : Bool
  hohQualifyingPeopleCount : Int
  qssQualifyingPeopleCount : Int
  isFilingStatusValid : Bool
  hasMultipleEligibleFilingStatuses : Bool
  recommendedFilingStatus : FilingStatus
  recommendedIsSingle : Bool
  recommendedIsMfj : Bool
  recommendedIsMfs : Bool
  recommendedIsHoh : Bool
  recommendedIsQss : Bool
  treatAsMfj : Bool
  treatAsMfs : Bool
  treatAsHoh : Bool
  koFilingStatusNotEligible : Bool
  unsupported : Bool

/-- The `Filers` input of `FilingStatusReturn` with a given `eligibleForHoh`. -/
def FilingStatusReturnIn.toFilers (i : FilingStatusReturnIn) (eligibleForHoh : Bool) : FilersIn :=
  { filingStatus := i.filingStatus, maritalStatus := i.maritalStatus
    yearOfSpouseDeath := i.yearOfSpouseDeath, primaryFiler := i.primaryFiler
    secondaryFiler := i.secondaryFiler, secondaryFilerDateOfDeath := i.secondaryFilerDateOfDeath
    primaryFilerPotentialClaimerFiledOnlyForRefund := i.primaryFilerPotentialClaimerFiledOnlyForRefund
    mfjRequiredToFile := i.mfjRequiredToFile
    mfjDependentsFilingForCredits := i.mfjDependentsFilingForCredits
    livedTogetherAllYearWithSpouse := i.livedTogetherAllYearWithSpouse
    spouseLivedTogetherMonths := i.spouseLivedTogetherMonths
    writableLivedApartLastSixMonths := i.writableLivedApartLastSixMonths
    writableSeparationAgreement := i.writableSeparationAgreement
    canFileJointlyYearOfSpouseDeath := i.canFileJointlyYearOfSpouseDeath
    inRegisteredDomesticPartnership := i.inRegisteredDomesticPartnership
    filerResidenceAndIncomeState := i.filerResidenceAndIncomeState
    spouseItemizes := i.spouseItemizes
    mfsLivingSpouseFilingReturn := i.mfsLivingSpouseFilingReturn
    mfsDeceasedSpouseFilingReturn := i.mfsDeceasedSpouseFilingReturn
    mfsSpouseHasGrossIncome := i.mfsSpouseHasGrossIncome, eligibleForHoh }

/-- Catala `scope FilingStatusReturn`. -/
def filingStatusReturn (i : FilingStatusReturnIn) : FilingStatusReturnOut :=
  -- stage 1: Read only by the community-property knockout, `eligible_for_hoh := false`
  let f := filers (i.toFilers false)
  -- stage 2
  let household := hohQssPersons
    { members := i.members, minimumFilerDateOfBirth := f.minimumFilerDateOfBirth
      treatFilersAsDependents := f.treatFilersAsDependents
      eitherFilerUsCitizenOrNational := f.eitherFilerUsCitizenOrNational
      treatAsMfj := f.treatAsMfj, eligibleForMfj := f.eligibleForMfj
      filerCouldQualifyForHoh := f.filerCouldQualifyForHoh
      filerCouldQualifyForQss := f.filerCouldQualifyForQss, filingStatus := i.filingStatus }
  -- stage 3
  let e := eligibility
    { filingStatus := i.filingStatus, maritalStatusAllowsFilingMarried := f.eligibleForMfs
      eligibleForMfj := f.eligibleForMfj, filerCouldQualifyForHoh := f.filerCouldQualifyForHoh
      filerCouldQualifyForQss := f.filerCouldQualifyForQss
      hohQualifyingPeopleCount := household.hohQualifyingPeopleCount
      qssQualifyingPeopleCount := household.qssQualifyingPeopleCount }
  let fk := filers (i.toFilers e.eligibleForHoh)
  { filers := f, household, eligibility := e, filersKnockouts := fk
    maritalStatusAllowsFilingMarried := f.eligibleForMfs
    eligibleForMfj := f.eligibleForMfj, eligibleForMfs := e.eligibleForMfs
    eligibleForSingle := e.eligibleForSingle, eligibleForHoh := e.eligibleForHoh
    eligibleForQss := e.eligibleForQss, filerCouldQualifyForHoh := f.filerCouldQualifyForHoh
    filerCouldQualifyForQss := f.filerCouldQualifyForQss
    hohQualifyingPeopleCount := household.hohQualifyingPeopleCount
    qssQualifyingPeopleCount := household.qssQualifyingPeopleCount
    isFilingStatusValid := e.isFilingStatusValid
    hasMultipleEligibleFilingStatuses := e.hasMultipleEligibleFilingStatuses
    recommendedFilingStatus := e.recommendedFilingStatus
    recommendedIsSingle := e.recommendedFilingStatus == single
    recommendedIsMfj := e.recommendedFilingStatus == marriedFilingJointly
    recommendedIsMfs := e.recommendedFilingStatus == marriedFilingSeparately
    recommendedIsHoh := e.recommendedFilingStatus == headOfHousehold
    recommendedIsQss := e.recommendedFilingStatus == qualifyingSurvivingSpouse
    treatAsMfj := f.treatAsMfj, treatAsMfs := f.treatAsMfs, treatAsHoh := e.treatAsHoh
    koFilingStatusNotEligible := e.koFilingStatusNotEligible
    unsupported := e.koFilingStatusNotEligible || fk.unsupported || household.unsupported }

/-! ### Structural lemmas (cheap, unconditional) -/

/-- QSS preempts HoH (IRC 2(b)): a QSS-eligible filer is never HoH-eligible. -/
theorem eligibility_qss_preempts_hoh (i : EligibilityIn) :
    (eligibility i).eligibleForQss = true → (eligibility i).eligibleForHoh = false := by
  intro h
  simp only [eligibility] at h ⊢
  simp [h]

/-- A valid chosen status is not knocked out by the filing-status check. -/
theorem eligibility_valid_not_ko (i : EligibilityIn) :
    (eligibility i).isFilingStatusValid = true → (eligibility i).koFilingStatusNotEligible = false := by
  intro h
  simp only [eligibility] at h ⊢
  rw [h]; rfl

/-- The scope's own knockout is exactly "the chosen status is not eligible". -/
theorem eligibility_unsupported_iff (i : EligibilityIn) :
    (eligibility i).unsupported = !(eligibility i).isFilingStatusValid := rfl

/-- The recommendation is never HoH when QSS is eligible. -/
theorem eligibility_recommended_qss (i : EligibilityIn) (hm : i.eligibleForMfj = false)
    (h : (eligibility i).eligibleForQss = true) :
    (eligibility i).recommendedFilingStatus = qualifyingSurvivingSpouse := by
  simp only [eligibility] at h ⊢
  simp [hm, h]

/-- At most five statuses are counted. -/
theorem eligibility_count_le (i : EligibilityIn) : (eligibility i).eligibleFilingStatusCount ≤ 5 := by
  simp only [eligibility]
  split <;> split <;> split <;> split <;> split <;> omega

/-! ### Unit tests: every assertion of `catala/tests/test_filing_status.catala_en`

`Case` of the Catala test is `Case` here: a single filer born 1985-06-15, a US-citizen
spouse born 1986-02-20 (read only if married), no child. -/

/-- The Catala test `Case`. -/
structure Case where
  filingStatus : FilingStatus := single
  maritalStatus : MaritalStatus := .neverMarried
  yearOfSpouseDeath : YearOfSpouseDeath := .diedBeforeTaxYearMinusTwo
  secondaryIsCitizen : Bool := true
  secondaryIsResident : Bool := false
  livedTogetherAllYear : Bool := true
  livedTogetherMonths : SpouseLivedTogetherMonths := .livedTogetherMoreThanSixMonths
  canFileJointlyYearOfSpouseDeath : Bool := false
  hasChild : Bool := false
  childResidency : QualifyingChild.ResidencyDuration := .allYear
  upkeep : Bool := true

/-- The child of the Catala `Case`. -/
def Case.child (c : Case) : HohQssPersons.Member :=
  ({ residency := c.childResidency, upkeep := c.upkeep } : HohQssPersons.Case).member

/-- The Catala `Case.r`. -/
def Case.r (c : Case) : FilingStatusReturnOut :=
  filingStatusReturn
    { filingStatus := c.filingStatus, maritalStatus := c.maritalStatus
      yearOfSpouseDeath := c.yearOfSpouseDeath
      primaryFiler := citizen ⟨1985, 6, 15⟩
      secondaryFiler :=
        { citizen ⟨1986, 2, 20⟩ with isUsCitizenFullYear := c.secondaryIsCitizen
                                     writableIsNoncitizenResidentFullYear := c.secondaryIsResident }
      secondaryFilerDateOfDeath := ⟨2022, 3, 1⟩
      primaryFilerPotentialClaimerFiledOnlyForRefund := false
      mfjRequiredToFile := true, mfjDependentsFilingForCredits := false
      livedTogetherAllYearWithSpouse := c.livedTogetherAllYear
      spouseLivedTogetherMonths := c.livedTogetherMonths
      writableLivedApartLastSixMonths := false, writableSeparationAgreement := false
      canFileJointlyYearOfSpouseDeath := c.canFileJointlyYearOfSpouseDeath
      inRegisteredDomesticPartnership := false, filerResidenceAndIncomeState := .fl
      spouseItemizes := false, mfsLivingSpouseFilingReturn := false
      mfsDeceasedSpouseFilingReturn := false, mfsSpouseHasGrossIncome := false
      members := if c.hasChild then [c.child] else [] }

-- TestMarriedNraSpouse
private def nra : Case := { maritalStatus := .married, secondaryIsCitizen := false }
private def alone := { nra with filingStatus := marriedFilingSeparately }.r
private def nraChild := { nra with filingStatus := headOfHousehold, hasChild := true }.r
private def nraMfj := { nra with filingStatus := marriedFilingJointly }.r
#guard !alone.eligibleForMfj
#guard alone.eligibleForMfs
#guard !alone.eligibleForSingle
#guard !alone.eligibleForHoh
#guard !alone.eligibleForQss
#guard alone.isFilingStatusValid
#guard !alone.unsupported
#guard alone.recommendedFilingStatus == marriedFilingSeparately
#guard !nraChild.eligibleForMfj
#guard nraChild.filerCouldQualifyForHoh
#guard nraChild.eligibleForHoh
#guard nraChild.eligibleForMfs
#guard nraChild.isFilingStatusValid
#guard !nraChild.unsupported
#guard nraChild.recommendedFilingStatus == headOfHousehold
#guard !nraMfj.isFilingStatusValid
#guard nraMfj.koFilingStatusNotEligible
#guard nraMfj.unsupported

-- TestMarriedLivedApartWithChild
private def apart (fs : FilingStatus) : Case :=
  { maritalStatus := .married, livedTogetherAllYear := false
    livedTogetherMonths := .livedApartAllYear, hasChild := true, filingStatus := fs }
private def ca := (apart headOfHousehold).r
#guard ca.eligibleForMfj
#guard ca.eligibleForMfs
#guard ca.filerCouldQualifyForHoh
#guard ca.hohQualifyingPeopleCount == 1
#guard ca.eligibleForHoh
#guard !ca.eligibleForSingle
#guard !ca.eligibleForQss
#guard ca.hasMultipleEligibleFilingStatuses
#guard ca.isFilingStatusValid
#guard !ca.unsupported
#guard ca.treatAsHoh
-- DF: chose HoH, so not "wants a separate return": the recommendation is MFJ
#guard ca.recommendedFilingStatus == marriedFilingJointly
private def together := { maritalStatus := .married, hasChild := true, filingStatus := headOfHousehold : Case }.r
#guard !together.filerCouldQualifyForHoh
#guard !together.eligibleForHoh
#guard !together.isFilingStatusValid
#guard together.unsupported
#guard !(apart single).r.eligibleForSingle
#guard (apart single).r.koFilingStatusNotEligible

-- TestWidowedYearMinusOneWithChild
private def widow (fs : FilingStatus) (joint : Bool) : Case :=
  { maritalStatus := .widowed, yearOfSpouseDeath := .diedTaxYearMinusOne
    canFileJointlyYearOfSpouseDeath := joint, hasChild := true, filingStatus := fs }
private def wc := (widow qualifyingSurvivingSpouse true).r
#guard wc.filerCouldQualifyForQss
#guard wc.qssQualifyingPeopleCount == 1
#guard wc.eligibleForQss
#guard wc.hohQualifyingPeopleCount == 1
#guard !wc.eligibleForHoh
#guard wc.eligibleForSingle
#guard !wc.eligibleForMfj
#guard !wc.eligibleForMfs
#guard wc.hasMultipleEligibleFilingStatuses
#guard wc.isFilingStatusValid
#guard !wc.unsupported
#guard wc.recommendedFilingStatus == qualifyingSurvivingSpouse
-- Known-bad: QSS preempts HoH
#guard (widow headOfHousehold true).r.koFilingStatusNotEligible
#guard (widow headOfHousehold true).r.unsupported
-- Single stays selectable, but QSS is recommended
#guard (widow single true).r.isFilingStatusValid
#guard !(widow single true).r.unsupported
#guard (widow single true).r.recommendedFilingStatus == qualifyingSurvivingSpouse
-- Without 2(a)(2)(B), not a surviving spouse: head of household instead
#guard !(widow headOfHousehold false).r.eligibleForQss
#guard (widow headOfHousehold false).r.eligibleForHoh
#guard (widow headOfHousehold false).r.isFilingStatusValid
#guard (widow headOfHousehold false).r.recommendedFilingStatus == headOfHousehold

-- TestDivorcedNoDependents
private def divorced (fs : FilingStatus) : Case := { maritalStatus := .divorced, filingStatus := fs }
private def dv := (divorced single).r
#guard dv.eligibleForSingle
#guard !dv.eligibleForMfj
#guard !dv.eligibleForMfs
#guard !dv.eligibleForHoh
#guard !dv.eligibleForQss
#guard dv.eligibility.eligibleFilingStatusCount == 1
#guard !dv.hasMultipleEligibleFilingStatuses
#guard dv.isFilingStatusValid
#guard !dv.unsupported
#guard dv.recommendedFilingStatus == single
#guard (divorced headOfHousehold).r.koFilingStatusNotEligible
#guard (divorced marriedFilingSeparately).r.koFilingStatusNotEligible
#guard (divorced marriedFilingJointly).r.koFilingStatusNotEligible

-- TestUnmarriedWithChild
private def uc (fs : FilingStatus) (upkeep : Bool := true) : Case :=
  { hasChild := true, filingStatus := fs, upkeep }
#guard (uc headOfHousehold).r.eligibleForHoh
#guard (uc headOfHousehold).r.eligibleForSingle
#guard (uc headOfHousehold).r.hasMultipleEligibleFilingStatuses
#guard (uc headOfHousehold).r.isFilingStatusValid
#guard (uc headOfHousehold).r.recommendedFilingStatus == headOfHousehold
#guard (uc single).r.isFilingStatusValid
#guard !(uc single).r.unsupported
#guard (uc single).r.recommendedFilingStatus == headOfHousehold
#guard (uc headOfHousehold).r.recommendedFilingStatus != single
#guard !(uc single false).r.eligibleForHoh
#guard (uc single false).r.eligibleForSingle
#guard (uc single false).r.isFilingStatusValid

-- TestRecommendationMarried
private def mar (fs : FilingStatus) : Case := { maritalStatus := .married, filingStatus := fs }
#guard (mar marriedFilingJointly).r.eligibleForMfj && (mar marriedFilingJointly).r.eligibleForMfs
#guard (mar marriedFilingJointly).r.eligibility.eligibleFilingStatusCount == 2
#guard (mar marriedFilingJointly).r.treatAsMfj
#guard (mar marriedFilingJointly).r.recommendedFilingStatus == marriedFilingJointly
#guard (mar marriedFilingSeparately).r.treatAsMfs
#guard (mar marriedFilingSeparately).r.isFilingStatusValid
#guard (mar marriedFilingSeparately).r.recommendedFilingStatus == marriedFilingSeparately
private def apartMfs : Case := { apart marriedFilingSeparately with }
#guard apartMfs.r.eligibleForHoh
#guard apartMfs.r.isFilingStatusValid
#guard apartMfs.r.recommendedFilingStatus == headOfHousehold
#guard (mar marriedFilingSeparately).r.recommendedFilingStatus != marriedFilingJointly

-- TestRecommendationEligible
private def elig (fs : FilingStatus) (married mfj couldHoh couldQss : Bool) (hohN qssN : Int) :
    EligibilityOut :=
  eligibility { filingStatus := fs, maritalStatusAllowsFilingMarried := married, eligibleForMfj := mfj
                filerCouldQualifyForHoh := couldHoh, filerCouldQualifyForQss := couldQss
                hohQualifyingPeopleCount := hohN, qssQualifyingPeopleCount := qssN }
private def recommendationIsEligible (e : EligibilityOut) (mfj : Bool) : Bool :=
  match e.recommendedFilingStatus with
  | .single => e.eligibleForSingle
  | .marriedFilingJointly => mfj
  | .marriedFilingSeparately => e.eligibleForMfs
  | .headOfHousehold => e.eligibleForHoh
  | .qualifyingSurvivingSpouse => e.eligibleForQss
private def singleNone := elig single false false false false 0 0
private def singleHoh := elig single false false true false 2 0
private def widowQssHoh := elig qualifyingSurvivingSpouse false false true true 1 1
private def marriedTogether := elig marriedFilingJointly true true false false 0 0
private def marriedApartHohChoseMfs := elig marriedFilingSeparately true true true false 1 0
private def nraSpouseHoh := elig headOfHousehold true false true false 1 0
private def nraSpouseAlone := elig marriedFilingSeparately true false true false 0 0
private def noneChoseHoh := elig headOfHousehold false false false false 0 0
#guard recommendationIsEligible singleNone false
#guard recommendationIsEligible singleHoh false
#guard recommendationIsEligible widowQssHoh false
#guard recommendationIsEligible marriedTogether true
#guard recommendationIsEligible marriedApartHohChoseMfs true
#guard recommendationIsEligible nraSpouseHoh false
#guard recommendationIsEligible nraSpouseAlone false
#guard singleNone.recommendedFilingStatus == single
#guard singleHoh.recommendedFilingStatus == headOfHousehold
#guard widowQssHoh.recommendedFilingStatus == qualifyingSurvivingSpouse
#guard !widowQssHoh.eligibleForHoh
#guard marriedTogether.recommendedFilingStatus == marriedFilingJointly
#guard marriedApartHohChoseMfs.recommendedFilingStatus == headOfHousehold
#guard nraSpouseHoh.recommendedFilingStatus == headOfHousehold
#guard nraSpouseAlone.recommendedFilingStatus == marriedFilingSeparately
-- valid exactly when not knocked out
#guard !singleHoh.koFilingStatusNotEligible
#guard recommendationIsEligible noneChoseHoh false
#guard noneChoseHoh.koFilingStatusNotEligible
#guard !singleNone.koFilingStatusNotEligible
#guard !nraSpouseHoh.koFilingStatusNotEligible
#guard !widowQssHoh.unsupported

end UsTax.FilingStatusMod
