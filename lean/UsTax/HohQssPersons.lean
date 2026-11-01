import UsTax.QualifyingRelative

/-!
# Head of household and qualifying surviving spouse: the persons (issue #44)

Lean implementation of `catala/hoh_qss_persons.catala_en` (module `Hoh_qss_persons`),
written by hand from the Catala source under strategy (c) of `docs/catala-to-lean.md`, in
the order of the Catala file.

| Catala (`Hoh_qss_persons`)             | Lean (`UsTax.HohQssPersons`)                    |
|----------------------------------------|-------------------------------------------------|
| structs `UpkeepAnswers`, `Member`      | `UpkeepAnswers`, `Member`                       |
| `scope HohQssPersonTest`               | `HohQssPersonTestIn` → `HohQssPersonTestOut` (`hohQssPersonTest`) |
| `scope HohQssPersons`                  | `HohQssPersonsIn` → `HohQssPersonsOut` (`hohQssPersons`) |

Counts are `Int` (`Money.countBy`, `UsTax/Lists.lean`). Deliberate departures from Direct
File, reproduced from Catala (Lean follows Catala): DF-BUG(19) to DF-BUG(22).
-/

namespace UsTax.HohQssPersons

open QualifyingChild DependentsBenefitSplit QualifyingRelative

/-- Catala `UpkeepAnswers`. -/
structure UpkeepAnswers where
  tpPaidMostOfHomeUpkeep : Bool
  tpPaidMostOfParentHomeUpkeep : Bool

/-- Catala `Member`: the dependent answers and the upkeep answers. -/
structure Member where
  dependent : QualifyingRelative.Member
  upkeep : UpkeepAnswers

/-! ### Scope `HohQssPersonTest` -/

/-- Inputs of `HohQssPersonTest`. -/
structure HohQssPersonTestIn where
  member : Member
  minimumFilerDateOfBirth : Date
  treatFilersAsDependents : Bool
  eitherFilerUsCitizenOrNational : Bool
  treatAsMfj : Bool
  eligibleForMfj : Bool
  filerCouldQualifyForHoh : Bool
  filerCouldQualifyForQss : Bool

/-- Outputs of `HohQssPersonTest` (`dep` is the sub-scope result). -/
structure HohQssPersonTestOut where
  dep : DependentTestOut
  marriedHohRelationshipTest : Bool
  isBiologicalAdoptedFosterOrStepchild : Bool
  isParent : Bool
  qssPersonResidencyTest : Bool
  flowAddPersonKeepingUpHome : Bool
  flowAddPersonKeepingUpParentsHome : Bool
  consideredUnmarriedChild : Bool
  marriedChildNotExcluded : Bool
  hohQualifyingChildPath : Bool
  hohParentPath : Bool
  hohOtherRelativePath : Bool
  hohQualifyingPerson : Bool
  personQualifiesTpForHoh : Bool
  hohQpHasTin : Bool
  qssQualifyingPerson : Bool
  personQualifiesTpForQss : Bool

/-- Catala `scope HohQssPersonTest`, definition by definition. -/
def hohQssPersonTest (i : HohQssPersonTestIn) : HohQssPersonTestOut :=
  let m := i.member
  let person := m.dependent.person
  let dep := dependentTest
    { member := m.dependent, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
      treatFilersAsDependents := i.treatFilersAsDependents
      eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational
      treatAsMfj := i.treatAsMfj }
  -- DF-BUG(21): the statute excludes a married child only for 152(b)(2) or (b)(3).
  let marriedChildNotExcluded :=
    !person.married || (dep.qc.jointReturnTest && dep.citizenOrResidentTest)
  let hohQualifyingChildPath :=
    dep.qualifyingChild && m.upkeep.tpPaidMostOfHomeUpkeep &&
      (!dep.isQualifyingChildOfAnother || dep.isClaimedDependent) && marriedChildNotExcluded
  let isParent := person.relationship == .parent
  let flowAddPersonKeepingUpParentsHome :=
    i.filerCouldQualifyForHoh && isParent && person.residencyDuration == .lessThanSixMonths
  let hohParentPath :=
    dep.qualifyingRelative && dep.eligibleDependent && flowAddPersonKeepingUpParentsHome &&
      m.upkeep.tpPaidMostOfParentHomeUpkeep && isParent
  let flowAddPersonKeepingUpHome :=
    (i.filerCouldQualifyForHoh || i.filerCouldQualifyForQss) &&
      (dep.qc.qcRelationshipTest ||
        (dep.qrRelationshipTest && person.residencyDuration != .lessThanSixMonths))
  -- DF-BUG(22): DF also admits a qualifying relative the filer cannot claim.
  let hohOtherRelativePath :=
    dep.qualifyingRelative && dep.eligibleDependent && dep.qrRelationshipTest &&
      dep.qc.residencyTest && m.upkeep.tpPaidMostOfHomeUpkeep && flowAddPersonKeepingUpHome
  let marriedHohRelationshipTest :=
    person.relationship == .biologicalChild || person.relationship == .adoptedChild ||
      person.relationship == .stepChild || person.relationship == .fosterChild
  -- DF-BUG(19): IRC 7703(b)(1) needs a child the filer is entitled to claim.
  let consideredUnmarriedChild :=
    marriedHohRelationshipTest &&
      (dep.eligibleDependent || dep.split.tpCanClaimSplitBenefitsHohEitcCdcc)
  -- DF-BUG(19) and DF-BUG(20) (no isClaimedIfClaimable).
  let hohQualifyingPerson :=
    (!i.eligibleForMfj || consideredUnmarriedChild) &&
      !dep.split.disqualifiedDueToParentalCustody &&
      (hohQualifyingChildPath || hohParentPath || hohOtherRelativePath)
  let qssPersonResidencyTest := person.residencyDuration == .allYear
  -- DF-BUG(20): DF also requires isClaimedIfClaimable.
  let qssQualifyingPerson :=
    m.upkeep.tpPaidMostOfHomeUpkeep &&
      (person.relationship == .biologicalChild || dep.childIsAdopted ||
        person.relationship == .stepChild) &&
      dep.citizenOrResidentTest && qssPersonResidencyTest &&
      ((dep.qc.ageTest && dep.qc.qcSupportTest) ||
        (dep.notQualifyingChildTest && dep.qrSupportTest)) &&
      !dep.split.tpCanClaimSplitBenefitsHohEitcCdcc
  { dep, marriedHohRelationshipTest
    isBiologicalAdoptedFosterOrStepchild := marriedHohRelationshipTest
    isParent, qssPersonResidencyTest, flowAddPersonKeepingUpHome
    flowAddPersonKeepingUpParentsHome, consideredUnmarriedChild, marriedChildNotExcluded
    hohQualifyingChildPath, hohParentPath, hohOtherRelativePath, hohQualifyingPerson
    personQualifiesTpForHoh := hohQualifyingPerson && i.filerCouldQualifyForHoh
    hohQpHasTin := m.dependent.answers.tinType != .noTin
    qssQualifyingPerson
    personQualifiesTpForQss := qssQualifyingPerson && i.filerCouldQualifyForQss }

/-! ### Scope `HohQssPersons` -/

/-- Inputs of `HohQssPersons`. -/
structure HohQssPersonsIn where
  members : List Member
  minimumFilerDateOfBirth : Date
  treatFilersAsDependents : Bool
  eitherFilerUsCitizenOrNational : Bool
  treatAsMfj : Bool
  eligibleForMfj : Bool
  filerCouldQualifyForHoh : Bool
  filerCouldQualifyForQss : Bool
  filingStatus : FilingStatus

/-- Outputs of `HohQssPersons`. -/
structure HohQssPersonsOut where
  results : List HohQssPersonTestOut
  hohQualifyingPeopleCount : Int
  qssQualifyingPeopleCount : Int
  hasHohQualifyingChild : Bool
  hasHohQualifyingParent : Bool
  hohQualifyingPeopleWithTinCount : Int
  koKnockoutHohQpHasNoTin : Bool
  unsupported : Bool

/-- Catala `scope HohQssPersons`: `HohQssPersonTest` over the household. -/
def hohQssPersons (i : HohQssPersonsIn) : HohQssPersonsOut :=
  let results := i.members.map fun m =>
    hohQssPersonTest
      { member := m, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
        treatFilersAsDependents := i.treatFilersAsDependents
        eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational
        treatAsMfj := i.treatAsMfj, eligibleForMfj := i.eligibleForMfj
        filerCouldQualifyForHoh := i.filerCouldQualifyForHoh
        filerCouldQualifyForQss := i.filerCouldQualifyForQss }
  let hohCount : Int := (Money.countBy (·.hohQualifyingPerson) results : Nat)
  let withTin : Int := (Money.countBy (fun r => r.hohQualifyingPerson && r.hohQpHasTin) results : Nat)
  let ko := i.filingStatus == .headOfHousehold && decide (hohCount > 0) && decide (withTin = 0)
  { results, hohQualifyingPeopleCount := hohCount
    qssQualifyingPeopleCount := (Money.countBy (·.qssQualifyingPerson) results : Nat)
    hasHohQualifyingChild :=
      results.any fun r => r.hohQualifyingPerson && r.isBiologicalAdoptedFosterOrStepchild
    hasHohQualifyingParent := results.any fun r => r.hohQualifyingPerson && r.isParent
    hohQualifyingPeopleWithTinCount := withTin
    koKnockoutHohQpHasNoTin := ko, unsupported := ko }

/-! ### Structural lemmas -/

/-- The counts never exceed the household size. -/
theorem hohQssPersons_counts_le (i : HohQssPersonsIn) :
    (hohQssPersons i).hohQualifyingPeopleCount ≤ i.members.length ∧
    (hohQssPersons i).qssQualifyingPeopleCount ≤ i.members.length ∧
    (hohQssPersons i).hohQualifyingPeopleWithTinCount ≤ i.members.length := by
  have h1 := Money.countBy_le_length (fun r : HohQssPersonTestOut => r.hohQualifyingPerson)
    (i.members.map fun m => hohQssPersonTest
      { member := m, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
        treatFilersAsDependents := i.treatFilersAsDependents
        eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational
        treatAsMfj := i.treatAsMfj, eligibleForMfj := i.eligibleForMfj
        filerCouldQualifyForHoh := i.filerCouldQualifyForHoh
        filerCouldQualifyForQss := i.filerCouldQualifyForQss })
  have h2 := Money.countBy_le_length (fun r : HohQssPersonTestOut => r.qssQualifyingPerson)
    (i.members.map fun m => hohQssPersonTest
      { member := m, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
        treatFilersAsDependents := i.treatFilersAsDependents
        eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational
        treatAsMfj := i.treatAsMfj, eligibleForMfj := i.eligibleForMfj
        filerCouldQualifyForHoh := i.filerCouldQualifyForHoh
        filerCouldQualifyForQss := i.filerCouldQualifyForQss })
  have h3 := Money.countBy_le_length (fun r : HohQssPersonTestOut => r.hohQualifyingPerson && r.hohQpHasTin)
    (i.members.map fun m => hohQssPersonTest
      { member := m, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
        treatFilersAsDependents := i.treatFilersAsDependents
        eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational
        treatAsMfj := i.treatAsMfj, eligibleForMfj := i.eligibleForMfj
        filerCouldQualifyForHoh := i.filerCouldQualifyForHoh
        filerCouldQualifyForQss := i.filerCouldQualifyForQss })
  simp only [List.length_map] at h1 h2 h3
  simp only [hohQssPersons]
  exact ⟨by omega, by omega, by omega⟩

/-! ### Unit tests: every assertion of `catala/tests/test_hoh_qss_persons.catala_en`

`Case` of the Catala test is `Case` here: a biological child born 2016-05-01 who lived with
the filer all year, SSN, citizen, claimed, filer paid the home upkeep, could qualify for HoH. -/

/-- The Catala test `Case` with its defaults. -/
structure Case where
  relationship : Relationship := .biologicalChild
  dateOfBirth : Date := ⟨2016, 5, 1⟩
  residency : ResidencyDuration := .allYear
  married : Bool := false
  writableJointReturn : Bool := false
  ownSupport : Bool := false
  couldBeQcOfAnother : Bool := false
  potentialClaimerMustFile : Bool := false
  grossIncome : Int := 0
  qrSupport : Bool := true
  tinType : TinType := .ssn
  citizen : Bool := true
  tpClaims : Bool := true
  custodialRelease : Bool := false
  grandparentLowerAgi : Bool := false
  upkeep : Bool := true
  parentUpkeep : Bool := false
  eligibleForMfj : Bool := false
  filerCouldQualifyForHoh : Bool := true
  filerCouldQualifyForQss : Bool := false
  minimumFilerDateOfBirth : Date := ⟨1985, 6, 15⟩

/-- The `Member` the Catala `Case` builds. -/
def Case.member (c : Case) : Member :=
  { dependent :=
      { person :=
          { relationship := c.relationship, dateOfBirth := c.dateOfBirth, fullTimeStudent := false
            permanentTotalDisability := false, residencyDuration := c.residency
            ownSupport := c.ownSupport, married := c.married
            writableJointReturn := c.writableJointReturn
            writableRequiredToFile := c.writableJointReturn
            writableFilingOnlyForRefund := false
            writableCouldBeQualifyingChildOfAnother := c.couldBeQcOfAnother
            writablePotentialClaimerMustFile := c.potentialClaimerMustFile
            writablePotentialClaimerDidFile := c.potentialClaimerMustFile
            writablePotentialClaimerFiledOnlyForRefund := false }
        answers :=
          { grossIncome := c.grossIncome, writableQrSupportTest := c.qrSupport
            tinType := c.tinType, isUsCitizenFullYear := c.citizen, writableUsResident := false
            writableUsNational := false, writableCanadaMexicoResident := false
            tpClaims := c.tpClaims }
        split :=
          { hasOtherBiologicalOrAdoptiveParent := c.custodialRelease
            nonParentalSomeParentNotClaiming := c.grandparentLowerAgi
            whichParentNotClaiming := if c.custodialRelease then .iDid else .nobodyDid
            inParentsCustody := c.custodialRelease || c.grandparentLowerAgi
            livedWithTpOrOtherBiologicalOrAdoptiveParentMoreThanSixMonths := c.custodialRelease
            biologicalOrAdoptiveParentsLiving := c.grandparentLowerAgi
            nightsWithTpVsOtherParent := if c.custodialRelease then .more else .less
            tpAgiHigherThanOtherParent := false
            parentsMeetReqsRuleForChildrenOfDivorcedParents := c.grandparentLowerAgi
            specialRuleChildUsedByCustodialParentAsQp := false, specialRuleAgiTest := false
            parentalSituation := if c.custodialRelease then .divorcedOrSeparated else .other
            parentalSupport := c.custodialRelease, multipleSupportAgreement := false } }
    upkeep := { tpPaidMostOfHomeUpkeep := c.upkeep, tpPaidMostOfParentHomeUpkeep := c.parentUpkeep } }

/-- The Catala `Case.r`. -/
def Case.r (c : Case) : HohQssPersonTestOut :=
  hohQssPersonTest
    { member := c.member, minimumFilerDateOfBirth := c.minimumFilerDateOfBirth
      treatFilersAsDependents := false, eitherFilerUsCitizenOrNational := true, treatAsMfj := false
      eligibleForMfj := c.eligibleForMfj, filerCouldQualifyForHoh := c.filerCouldQualifyForHoh
      filerCouldQualifyForQss := c.filerCouldQualifyForQss }

-- TestChildPath
#guard ({} : Case).r.dep.qualifyingChild
#guard ({} : Case).r.hohQualifyingChildPath
#guard !({} : Case).r.hohParentPath && !({} : Case).r.hohOtherRelativePath
#guard ({} : Case).r.hohQualifyingPerson
#guard ({} : Case).r.personQualifiesTpForHoh
#guard ({ upkeep := false } : Case).r.dep.qualifyingChild
#guard !({ upkeep := false } : Case).r.hohQualifyingChildPath
#guard !({ upkeep := false } : Case).r.hohQualifyingPerson

-- TestParentPath
private def parentCase (income : Int) (upkeep parentUpkeep : Bool) : Case :=
  { relationship := .parent, dateOfBirth := ⟨1950, 4, 2⟩, residency := .lessThanSixMonths
    grossIncome := income, upkeep, parentUpkeep }
#guard (parentCase 300_000 false true).r.isParent
#guard (parentCase 300_000 false true).r.dep.qualifyingRelative &&
  (parentCase 300_000 false true).r.dep.eligibleDependent
#guard (parentCase 300_000 false true).r.flowAddPersonKeepingUpParentsHome
#guard (parentCase 300_000 false true).r.hohParentPath
#guard (parentCase 300_000 false true).r.hohQualifyingPerson
#guard !(parentCase 300_000 false true).r.hohOtherRelativePath
#guard !(parentCase 505_000 false true).r.dep.eligibleDependent
#guard !(parentCase 505_000 false true).r.hohQualifyingPerson
#guard !(parentCase 300_000 true false).r.hohParentPath
#guard !(parentCase 300_000 true false).r.hohOtherRelativePath
#guard !(parentCase 300_000 true false).r.hohQualifyingPerson

-- TestOtherRelativePath
private def sibling (r : ResidencyDuration) : Case :=
  { relationship := .sibling, dateOfBirth := ⟨1990, 1, 1⟩, residency := r, grossIncome := 200_000 }
#guard !(sibling .sixToElevenMonths).r.dep.qualifyingChild
#guard (sibling .sixToElevenMonths).r.dep.qualifyingRelative
#guard (sibling .sixToElevenMonths).r.hohOtherRelativePath
#guard (sibling .sixToElevenMonths).r.hohQualifyingPerson
#guard (sibling .lessThanSixMonths).r.dep.qualifyingRelative
#guard !(sibling .lessThanSixMonths).r.hohQualifyingPerson
private def friend : Case :=
  { relationship := .noneOfTheAbove, dateOfBirth := ⟨1984, 1, 1⟩, grossIncome := 200_000 }
#guard friend.r.dep.qualifyingRelative
#guard friend.r.dep.eligibleDependent
#guard !friend.r.hohQualifyingPerson

-- TestMarriedConsideredUnmarried
#guard ({ eligibleForMfj := true } : Case).r.consideredUnmarriedChild
#guard ({ eligibleForMfj := true } : Case).r.hohQualifyingPerson
#guard ({ eligibleForMfj := true, relationship := .fosterChild } : Case).r.marriedHohRelationshipTest
#guard ({ eligibleForMfj := true, relationship := .fosterChild } : Case).r.hohQualifyingPerson
private def brother : Case :=
  { eligibleForMfj := true, relationship := .sibling, dateOfBirth := ⟨1990, 1, 1⟩
    residency := .sixToElevenMonths, grossIncome := 200_000 }
#guard !brother.r.marriedHohRelationshipTest
#guard brother.r.hohOtherRelativePath
#guard !brother.r.hohQualifyingPerson

-- TestQss
#guard ({ filerCouldQualifyForQss := true } : Case).r.qssPersonResidencyTest
#guard ({ filerCouldQualifyForQss := true } : Case).r.qssQualifyingPerson
#guard ({ filerCouldQualifyForQss := true } : Case).r.personQualifiesTpForQss
private def partYear : Case := { filerCouldQualifyForQss := true, residency := .sixToElevenMonths }
#guard !partYear.r.qssPersonResidencyTest
#guard !partYear.r.qssQualifyingPerson
#guard partYear.r.hohQualifyingPerson
private def fosterQss : Case := { filerCouldQualifyForQss := true, relationship := .fosterChild }
#guard !fosterQss.r.qssQualifyingPerson
#guard fosterQss.r.hohQualifyingPerson
#guard ({ filerCouldQualifyForQss := true, relationship := .stepChild } : Case).r.qssQualifyingPerson

-- TestQssGrossIncomeDisregarded
private def grown : Case :=
  { dateOfBirth := ⟨1999, 3, 1⟩, grossIncome := 600_000, filerCouldQualifyForQss := true }
#guard !grown.r.dep.qualifyingChild
#guard !grown.r.dep.qualifyingRelative
#guard grown.r.qssQualifyingPerson
#guard !grown.r.hohQualifyingPerson

-- TestNoTinPerson
private def noTinBrother : Case := { brother with eligibleForMfj := false, tinType := .noTin }
#guard noTinBrother.r.dep.qualifyingRelative
#guard !noTinBrother.r.dep.eligibleDependent
#guard !noTinBrother.r.hohQualifyingPerson
#guard ({ tinType := .noTin } : Case).r.hohQualifyingPerson
#guard !({ tinType := .noTin } : Case).r.hohQpHasTin

-- TestNoTinHousehold
private def hhOf (ms : List Member) (fs : FilingStatus) : HohQssPersonsOut :=
  hohQssPersons
    { members := ms, minimumFilerDateOfBirth := ⟨1985, 6, 15⟩, treatFilersAsDependents := false
      eitherFilerUsCitizenOrNational := true, treatAsMfj := false, eligibleForMfj := false
      filerCouldQualifyForHoh := true, filerCouldQualifyForQss := false, filingStatus := fs }
private def sonNoTin : Member := ({ tinType := .noTin } : Case).member
private def daughter : Member := ({ dateOfBirth := ⟨2018, 9, 9⟩ } : Case).member
private def onlyNoTin := hhOf [sonNoTin] .headOfHousehold
private def withTin := hhOf [sonNoTin, daughter] .headOfHousehold
private def notHoh := hhOf [sonNoTin] .single
#guard onlyNoTin.hohQualifyingPeopleCount == 1
#guard onlyNoTin.hohQualifyingPeopleWithTinCount == 0
#guard onlyNoTin.koKnockoutHohQpHasNoTin
#guard onlyNoTin.unsupported
#guard withTin.hohQualifyingPeopleCount == 2
#guard withTin.hohQualifyingPeopleWithTinCount == 1
#guard withTin.hasHohQualifyingChild
#guard !withTin.hasHohQualifyingParent
#guard !withTin.koKnockoutHohQpHasNoTin
#guard !notHoh.koKnockoutHohQpHasNoTin
#guard !notHoh.unsupported

-- TestCustodialRelease
#guard ({ custodialRelease := true, filerCouldQualifyForQss := true } : Case).r.dep.split.tpCanClaimSplitBenefitsHohEitcCdcc
#guard !({ custodialRelease := true, filerCouldQualifyForQss := true } : Case).r.dep.eligibleDependent
#guard ({ custodialRelease := true, filerCouldQualifyForQss := true } : Case).r.hohQualifyingPerson
#guard !({ custodialRelease := true, filerCouldQualifyForQss := true } : Case).r.qssQualifyingPerson
#guard ({ custodialRelease := true, eligibleForMfj := true } : Case).r.consideredUnmarriedChild
#guard ({ custodialRelease := true, eligibleForMfj := true } : Case).r.hohQualifyingPerson

-- TestGrandparentDisqualified
private def grandCase (lower : Bool) : Case :=
  { relationship := .grandChildOrOtherDescendantOfChild, dateOfBirth := ⟨2019, 3, 1⟩
    minimumFilerDateOfBirth := ⟨1960, 6, 15⟩, grandparentLowerAgi := lower }
#guard (grandCase true).r.dep.split.disqualifiedDueToParentalCustody
#guard (grandCase true).r.hohQualifyingChildPath
#guard !(grandCase true).r.hohQualifyingPerson
#guard (grandCase false).r.hohQualifyingPerson

-- TestQualifyingChildOfAnother
private def claimedCase (claims : Bool) : Case :=
  { couldBeQcOfAnother := true, potentialClaimerMustFile := true, tpClaims := claims }
#guard (claimedCase true).r.dep.isQualifyingChildOfAnother
#guard (claimedCase true).r.hohQualifyingPerson
#guard (claimedCase false).r.dep.isQualifyingChildOfAnother
#guard !(claimedCase false).r.hohQualifyingPerson

-- TestDfBug19aMarriedChildNoTin
private def bug19a : Case := { eligibleForMfj := true, tinType := .noTin }
#guard bug19a.r.marriedHohRelationshipTest
#guard !bug19a.r.consideredUnmarriedChild
#guard bug19a.r.hohQualifyingChildPath
#guard !bug19a.r.hohQualifyingPerson
#guard ({ tinType := .noTin } : Case).r.hohQualifyingPerson

-- TestDfBug19bUnclaimed
private def bug19b : Case := { tpClaims := false, filerCouldQualifyForQss := true }
#guard bug19b.r.dep.eligibleDependent
#guard !bug19b.r.dep.isClaimedIfClaimable
#guard bug19b.r.hohQualifyingPerson
#guard bug19b.r.qssQualifyingPerson

-- TestDfBug19cMarriedChild
private def bug19c : Case := { dateOfBirth := ⟨2007, 2, 1⟩, married := true }
#guard ({ bug19c with tinType := .noTin } : Case).r.dep.qualifyingChild
#guard !({ bug19c with tinType := .noTin } : Case).r.dep.eligibleDependentMinusFilerInformation
#guard ({ bug19c with tinType := .noTin } : Case).r.marriedChildNotExcluded
#guard ({ bug19c with tinType := .noTin } : Case).r.hohQualifyingPerson
#guard !({ bug19c with writableJointReturn := true } : Case).r.dep.qualifyingChild
#guard !({ bug19c with writableJointReturn := true } : Case).r.hohQualifyingPerson
#guard !({ bug19c with citizen := false } : Case).r.marriedChildNotExcluded
#guard !({ bug19c with citizen := false } : Case).r.hohQualifyingPerson

-- TestDfBug19dSplitRelative
private def bug19d : Case :=
  { dateOfBirth := ⟨2008, 2, 1⟩, married := true, writableJointReturn := true
    grossIncome := 100_000, custodialRelease := true }
#guard !bug19d.r.dep.qualifyingChild
#guard bug19d.r.dep.qualifyingRelative
#guard bug19d.r.dep.split.tpCanClaimSplitBenefitsHohEitcCdcc
#guard !bug19d.r.dep.eligibleDependent
#guard !bug19d.r.hohOtherRelativePath
#guard !bug19d.r.hohQualifyingPerson

-- TestHousehold
private def hhMotherFixed : Case :=
  { relationship := .parent, dateOfBirth := ⟨1950, 4, 2⟩, residency := .lessThanSixMonths
    grossIncome := 300_000, parentUpkeep := true }
private def hhLodger : Case :=
  { relationship := .noneOfTheAbove, dateOfBirth := ⟨1984, 1, 1⟩, grossIncome := 200_000 }
private def hhMixed := hohQssPersons
  { members := [({} : Case).member, hhMotherFixed.member, hhLodger.member]
    minimumFilerDateOfBirth := ⟨1985, 6, 15⟩, treatFilersAsDependents := false
    eitherFilerUsCitizenOrNational := true, treatAsMfj := false, eligibleForMfj := false
    filerCouldQualifyForHoh := true, filerCouldQualifyForQss := true
    filingStatus := .qualifyingSurvivingSpouse }
#guard hhMixed.results.length == 3
#guard hhMixed.hohQualifyingPeopleCount == 2
#guard hhMixed.qssQualifyingPeopleCount == 1
#guard hhMixed.hasHohQualifyingChild
#guard hhMixed.hasHohQualifyingParent
#guard !hhMixed.unsupported

end UsTax.HohQssPersons
