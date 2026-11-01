import UsTax.Params2024
import UsTax.DependentsBenefitSplit

/-!
# Qualifying relative and eligible dependent: IRC 152(d), 152(b), one person at a time (issue #44)

Lean implementation of `catala/qualifying_relative.catala_en` (module
`Qualifying_relative`), written by hand from the Catala source under strategy (c) of
`docs/catala-to-lean.md`, in the order of the Catala file. It calls `qualifyingChildTest`
and `benefitSplitTest` for the same person, as the Catala scope does.

| Catala (`Qualifying_relative`)         | Lean (`UsTax.QualifyingRelative`)               |
|----------------------------------------|-------------------------------------------------|
| enum `TinType` (`NoTin` is DF `none`)  | `TinType`                                       |
| structs `DependentAnswers`, `Member`   | `DependentAnswers`, `Member`                    |
| `scope DependentTest`                  | `DependentTestIn` → `DependentTestOut` (`dependentTest`) |
| `scope Dependents`                     | `DependentsIn` → `DependentsOut` (`dependents`) |

Deliberate departures from Direct File, reproduced from Catala (Lean follows Catala):
DF-BUG(15) (`qualifyingRelative` also needs `not qualifyingChild`) and DF-BUG(16) (the
"qualifying child of another" answer counts for everyone who could be anyone's qualifying
child).
-/

namespace UsTax.QualifyingRelative

open QualifyingChild DependentsBenefitSplit

/-- Catala `TinType` (DF `/tinTypeOptions`); `noTin` is DF `none`. -/
inductive TinType where
  | ssn | itin | atin | noTin
  deriving DecidableEq, Repr, Inhabited

namespace TinType
/-- Parse a Catala case name. -/
def ofString? : String → Option TinType
  | "Ssn" => some ssn | "Itin" => some itin | "Atin" => some atin | "NoTin" => some noTin
  | _ => none
end TinType

/-- Catala `DependentAnswers`: the answers the qualifying relative and dependent tests
read, beyond those of `Person`. -/
structure DependentAnswers where
  /-- The person's gross income for 2024, cents (IRC 152(d)(1)(B)). -/
  grossIncome : Int
  writableQrSupportTest : Bool
  tinType : TinType
  isUsCitizenFullYear : Bool
  writableUsResident : Bool
  writableUsNational : Bool
  writableCanadaMexicoResident : Bool
  tpClaims : Bool

/-- Catala `Member`: one member of DF `/familyAndHousehold`. -/
structure Member where
  person : Person
  answers : DependentAnswers
  split : BenefitSplitAnswers

/-! ### Scope `DependentTest` -/

/-- Inputs of `DependentTest`. -/
structure DependentTestIn where
  member : Member
  minimumFilerDateOfBirth : Date
  treatFilersAsDependents : Bool
  eitherFilerUsCitizenOrNational : Bool
  treatAsMfj : Bool

/-- Outputs of `DependentTest` (`qc` and `split` are the sub-scope results). -/
structure DependentTestOut where
  qc : QualifyingChildTestOut
  split : BenefitSplitTestOut
  qualifyingChild : Bool
  askAboutQcOfAnother : Bool
  isQualifyingChildOfAnother : Bool
  couldBeQualifyingChildOfSomeTaxpayer : Bool
  notQualifyingChildTest : Bool
  qrRelationshipTest : Bool
  memberOfHouseholdTest : Bool
  relationshipMemberOfHouseholdTest : Bool
  grossIncomeTest : Bool
  qrSupportTest : Bool
  qualifyingRelativeMinusNotQcTest : Bool
  qualifyingRelative : Bool
  usResident : Bool
  usNational : Bool
  canadaMexicoResident : Bool
  childIsAdopted : Bool
  adoptedChildException : Bool
  citizenOrUsResidentTest : Bool
  citizenOrResidentTest : Bool
  qcOrQr : Bool
  eligibleDependentMinusFilerInformation : Bool
  eligibleDependent : Bool
  isClaimedDependent : Bool
  isClaimedIfClaimable : Bool

/-- IRC 152(d)(2)(A)-(G), 152(f)(1), (4); DF `/qrRelationshipTest`. -/
def qrRelationshipTest : Relationship → Bool
  | .biologicalChild | .adoptedChild | .stepChild | .fosterChild
  | .grandChildOrOtherDescendantOfChild | .sibling | .halfSibling | .stepSibling | .parent
  | .grandParent | .otherAncestorOfParent | .stepParent | .childOfSibling | .childOfHalfSibling
  | .siblingOfParent | .childInLaw | .parentInLaw | .siblingInLaw | .siblingsSpouse => true
  | _ => false

/-- Catala `scope DependentTest`, definition by definition. -/
def dependentTest (i : DependentTestIn) : DependentTestOut :=
  let m := i.member
  let qc := qualifyingChildTest { person := m.person, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth }
  let split := benefitSplitTest
    { member := { person := m.person, answers := m.split }
      minimumFilerDateOfBirth := i.minimumFilerDateOfBirth, treatAsMfj := i.treatAsMfj }
  let qualifyingChild := qc.qualifyingChild
  let qrRel := qrRelationshipTest m.person.relationship
  let memberOfHouseholdTest := m.person.residencyDuration == .allYear
  let relationshipMemberOfHouseholdTest := qrRel || memberOfHouseholdTest
  let grossIncomeTest := decide (m.answers.grossIncome < Params.qualifyingRelativeGrossIncomeLimit)
  let qrSupportTest := !m.person.ownSupport && m.answers.writableQrSupportTest
  let qualifyingRelativeMinusNotQcTest :=
    relationshipMemberOfHouseholdTest && grossIncomeTest && qrSupportTest
  -- DF-BUG(16): the answer counts for everyone who could be anyone's qualifying child.
  let couldBeQualifyingChildOfSomeTaxpayer :=
    qc.qcSupportTest && qc.jointReturnTest &&
      (decide (qc.age < qcAgeLimit) ||
        (m.person.fullTimeStudent && decide (qc.age < qcStudentAgeLimit)) ||
        m.person.permanentTotalDisability)
  let notQualifyingChildTest :=
    !(couldBeQualifyingChildOfSomeTaxpayer && qc.otherTaxpayerCanClaimAsQualifyingChild)
  -- DF-BUG(15): DF's `/qualifyingRelative` omits "not a qualifying child of such taxpayer".
  let qualifyingRelative :=
    !qualifyingChild && notQualifyingChildTest && qualifyingRelativeMinusNotQcTest
  let askAboutQcOfAnother :=
    qc.ageTest && (qualifyingRelativeMinusNotQcTest || qualifyingChild) &&
      !split.tpCanClaimSplitBenefitsHohEitcCdcc
  let isQualifyingChildOfAnother :=
    askAboutQcOfAnother && m.person.writableCouldBeQualifyingChildOfAnother &&
      (qualifyingChild || !qc.qcOfAnotherButNot)
  let usResident := !m.answers.isUsCitizenFullYear && m.answers.writableUsResident
  let usNational := !m.answers.isUsCitizenFullYear && !usResident && m.answers.writableUsNational
  let canadaMexicoResident :=
    !m.answers.isUsCitizenFullYear && !usResident && !usNational &&
      m.answers.writableCanadaMexicoResident
  let childIsAdopted := m.person.relationship == .adoptedChild
  let adoptedChildException :=
    childIsAdopted && i.eitherFilerUsCitizenOrNational &&
      m.person.residencyDuration == .allYear
  let citizenOrUsResidentTest :=
    m.answers.isUsCitizenFullYear || usResident || usNational || adoptedChildException
  let citizenOrResidentTest := citizenOrUsResidentTest || canadaMexicoResident || adoptedChildException
  let qcOrQr := qualifyingChild || qualifyingRelative
  let eligibleDependentMinusFilerInformation :=
    qcOrQr && !split.disqualifiedDueToParentalCustody &&
      !split.tpCanClaimSplitBenefitsHohEitcCdcc && citizenOrResidentTest &&
      qc.jointReturnTest && m.answers.tinType != .noTin
  let eligibleDependent := !i.treatFilersAsDependents && eligibleDependentMinusFilerInformation
  let isClaimedDependent := m.answers.tpClaims && eligibleDependent
  { qc, split, qualifyingChild, askAboutQcOfAnother, isQualifyingChildOfAnother
    couldBeQualifyingChildOfSomeTaxpayer, notQualifyingChildTest, qrRelationshipTest := qrRel
    memberOfHouseholdTest, relationshipMemberOfHouseholdTest, grossIncomeTest, qrSupportTest
    qualifyingRelativeMinusNotQcTest, qualifyingRelative, usResident, usNational
    canadaMexicoResident, childIsAdopted, adoptedChildException, citizenOrUsResidentTest
    citizenOrResidentTest, qcOrQr, eligibleDependentMinusFilerInformation, eligibleDependent
    isClaimedDependent, isClaimedIfClaimable := isClaimedDependent || !eligibleDependent }

/-! ### Scope `Dependents` -/

/-- Inputs of `Dependents`. -/
structure DependentsIn where
  members : List Member
  minimumFilerDateOfBirth : Date
  treatFilersAsDependents : Bool
  eitherFilerUsCitizenOrNational : Bool
  treatAsMfj : Bool

/-- Outputs of `Dependents`. -/
structure DependentsOut where
  results : List DependentTestOut
  claimedDependentsCount : Int

/-- Catala `scope Dependents`: `DependentTest` over the household. -/
def dependents (i : DependentsIn) : DependentsOut :=
  let results := i.members.map fun m =>
    dependentTest
      { member := m, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
        treatFilersAsDependents := i.treatFilersAsDependents
        eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational
        treatAsMfj := i.treatAsMfj }
  { results, claimedDependentsCount := (Money.countBy (·.isClaimedDependent) results : Nat) }

/-! ### Unit tests: every assertion of `catala/tests/test_qualifying_relative.catala_en`

`MkMember` of the Catala test is `defaultMember`: a parent born 1950-04-02 who lived with
the filer less than six months, gross income $3,000, a Social Security number, a citizen.
The `TestCustodialReleasedKeepsHohEitcCdcc` test of
`catala/tests/test_dependents_benefit_split.catala_en` is at the end. -/

/-- The Catala test `MkMember` with its defaults (the benefit split answers are the
"no split" defaults of `MkMember`). -/
def defaultMember : Member :=
  { person := { QualifyingChild.defaultPerson with
      relationship := .parent, dateOfBirth := ⟨1950, 4, 2⟩, residencyDuration := .lessThanSixMonths }
    answers :=
      { grossIncome := 300_000, writableQrSupportTest := true, tinType := .ssn
        isUsCitizenFullYear := true, writableUsResident := false, writableUsNational := false
        writableCanadaMexicoResident := false, tpClaims := true }
    split :=
      { hasOtherBiologicalOrAdoptiveParent := false, nonParentalSomeParentNotClaiming := false
        whichParentNotClaiming := .nobodyDid, inParentsCustody := false
        livedWithTpOrOtherBiologicalOrAdoptiveParentMoreThanSixMonths := false
        biologicalOrAdoptiveParentsLiving := false, nightsWithTpVsOtherParent := .less
        tpAgiHigherThanOtherParent := false
        parentsMeetReqsRuleForChildrenOfDivorcedParents := false
        specialRuleChildUsedByCustodialParentAsQp := false, specialRuleAgiTest := false
        parentalSituation := .other, parentalSupport := false, multipleSupportAgreement := false } }

private def P (f : Person → Person) (m : Member := defaultMember) : Member :=
  { m with person := f m.person }
private def A (f : DependentAnswers → DependentAnswers) (m : Member := defaultMember) : Member :=
  { m with answers := f m.answers }

private def dep (m : Member) (min : Date := ⟨1985, 6, 15⟩) (deps : Bool := false)
    (citizen : Bool := true) : DependentTestOut :=
  dependentTest { member := m, minimumFilerDateOfBirth := min, treatFilersAsDependents := deps
                  eitherFilerUsCitizenOrNational := citizen, treatAsMfj := false }

-- TestParentIncome5049
private def d1 := dep (A fun a => { a with grossIncome := 504_900 })
#guard !d1.qualifyingChild
#guard d1.qrRelationshipTest
#guard !d1.memberOfHouseholdTest
#guard d1.relationshipMemberOfHouseholdTest
#guard d1.grossIncomeTest
#guard d1.qrSupportTest
#guard d1.notQualifyingChildTest
#guard d1.qualifyingRelative
#guard d1.qcOrQr
#guard d1.citizenOrResidentTest
#guard d1.eligibleDependent
#guard d1.isClaimedDependent
#guard d1.isClaimedIfClaimable

-- TestParentIncome5050
private def d2 := dep (A fun a => { a with grossIncome := 505_000 })
#guard !d2.grossIncomeTest
#guard d2.relationshipMemberOfHouseholdTest && d2.qrSupportTest && d2.notQualifyingChildTest
#guard !d2.qualifyingRelative
#guard !d2.eligibleDependent
#guard !d2.isClaimedDependent
#guard d2.isClaimedIfClaimable

-- TestNonRelativeAllYear
private def lodger (r : ResidencyDuration) : Member :=
  P fun p => { p with relationship := .noneOfTheAbove, dateOfBirth := ⟨1990, 9, 9⟩, residencyDuration := r }
private def d3 := dep (lodger .allYear)
#guard !d3.qrRelationshipTest
#guard d3.memberOfHouseholdTest
#guard d3.relationshipMemberOfHouseholdTest
#guard d3.qualifyingRelative
#guard d3.eligibleDependent
-- TestNonRelativeEightMonths
private def d4 := dep (lodger .sixToElevenMonths)
#guard !d4.memberOfHouseholdTest
#guard !d4.relationshipMemberOfHouseholdTest
#guard d4.grossIncomeTest && d4.qrSupportTest
#guard !d4.qualifyingRelative
#guard !d4.eligibleDependent

-- TestQualifyingChildOfAnother
private def grandchild (mustFile didFile : Bool) : Member :=
  P (fun p => { p with relationship := .grandChildOrOtherDescendantOfChild
                       dateOfBirth := ⟨2011, 5, 5⟩, residencyDuration := .lessThanSixMonths
                       writableCouldBeQualifyingChildOfAnother := true
                       writablePotentialClaimerMustFile := mustFile
                       writablePotentialClaimerDidFile := didFile })
    (A (fun a => { a with grossIncome := 0 }))
private def d5 := dep (grandchild true true)
#guard !d5.qualifyingChild
#guard d5.qualifyingRelativeMinusNotQcTest
#guard d5.isQualifyingChildOfAnother
#guard !d5.notQualifyingChildTest
#guard !d5.qualifyingRelative
#guard !d5.eligibleDependent
-- TestQualifyingChildOfNonFiler
private def d6 := dep (grandchild false false)
#guard !d6.isQualifyingChildOfAnother
#guard d6.notQualifyingChildTest
#guard d6.qualifyingRelative
#guard d6.eligibleDependent

-- TestNoTin
private def child (t : TinType) : Member :=
  P (fun p => { p with relationship := .biologicalChild, dateOfBirth := ⟨2014, 1, 20⟩
                       residencyDuration := .allYear })
    (A (fun a => { a with tinType := t }))
private def d7 := dep (child .noTin)
#guard d7.qualifyingChild
#guard d7.qcOrQr
#guard !d7.eligibleDependentMinusFilerInformation
#guard !d7.eligibleDependent
#guard !d7.isClaimedDependent
#guard (dep (child .atin)).eligibleDependent
#guard (dep (child .atin)).isClaimedDependent

-- TestAdoptedChildException
private def adopted (r : ResidencyDuration) : Member :=
  P (fun p => { p with relationship := .adoptedChild, dateOfBirth := ⟨2018, 2, 14⟩
                       residencyDuration := r })
    (A (fun a => { a with isUsCitizenFullYear := false, tinType := .atin }))
private def d8 := dep (adopted .allYear)
#guard d8.qualifyingChild
#guard d8.childIsAdopted
#guard !d8.usResident && !d8.usNational && !d8.canadaMexicoResident
#guard d8.adoptedChildException
#guard d8.citizenOrResidentTest
#guard d8.citizenOrUsResidentTest
#guard d8.eligibleDependent
private def d8n := dep (adopted .allYear) ⟨1985, 6, 15⟩ false false
#guard !d8n.adoptedChildException
#guard !d8n.citizenOrResidentTest
#guard !d8n.eligibleDependent
private def d8p := dep (adopted .sixToElevenMonths)
#guard d8p.qualifyingChild
#guard !d8p.adoptedChildException
#guard !d8p.eligibleDependent

-- TestChildInMexico
private def d9 := dep
  (P (fun p => { p with relationship := .biologicalChild, dateOfBirth := ⟨2018, 7, 1⟩ })
    (A (fun a => { a with grossIncome := 0, isUsCitizenFullYear := false
                          writableCanadaMexicoResident := true, tinType := .itin })))
#guard !d9.qualifyingChild
#guard d9.qualifyingRelative
#guard d9.canadaMexicoResident
#guard !d9.citizenOrUsResidentTest
#guard d9.citizenOrResidentTest
#guard d9.eligibleDependent

-- TestFilerIsDependent
private def d10 := dep defaultMember ⟨1985, 6, 15⟩ true
#guard d10.qualifyingRelative
#guard d10.eligibleDependentMinusFilerInformation
#guard !d10.eligibleDependent
#guard !d10.isClaimedDependent
#guard d10.isClaimedIfClaimable

-- TestMarriedParentJointReturn
private def d11 := dep (P fun p => { p with married := true, writableJointReturn := true })
#guard d11.qualifyingRelative
#guard !d11.qc.jointReturnTest
#guard !d11.eligibleDependent

-- TestEligibleNotClaimed
private def d12 := dep (A fun a => { a with tpClaims := false })
#guard d12.eligibleDependent
#guard !d12.isClaimedDependent
#guard !d12.isClaimedIfClaimable

-- TestOwnQualifyingChildNotQualifyingRelative
private def d13 := dep
  (P fun p => { p with relationship := .biologicalChild, dateOfBirth := ⟨2002, 4, 11⟩
                       fullTimeStudent := true, residencyDuration := .allYear })
#guard d13.qualifyingChild
#guard d13.notQualifyingChildTest
#guard d13.qualifyingRelativeMinusNotQcTest
#guard !d13.qualifyingRelative
#guard d13.qcOrQr
#guard d13.eligibleDependent

-- TestOlderSiblingQualifyingChildOfParent
private def d14 := dep
  (P (fun p => { p with relationship := .sibling, dateOfBirth := ⟨2003, 1, 10⟩
                        fullTimeStudent := true, residencyDuration := .sixToElevenMonths
                        writableCouldBeQualifyingChildOfAnother := true
                        writablePotentialClaimerMustFile := true
                        writablePotentialClaimerDidFile := true })
    (A fun a => { a with grossIncome := 200_000 })) ⟨2004, 3, 1⟩
#guard !d14.qc.ageTest
#guard !d14.qualifyingChild
#guard !d14.askAboutQcOfAnother
#guard !d14.isQualifyingChildOfAnother
#guard !d14.notQualifyingChildTest
#guard d14.qualifyingRelativeMinusNotQcTest
#guard !d14.qualifyingRelative
#guard !d14.eligibleDependent

-- TestHousehold
private def hh := dependents
  { members := [defaultMember,
      P (fun p => { p with relationship := .noneOfTheAbove, dateOfBirth := ⟨1990, 9, 9⟩
                           residencyDuration := .sixToElevenMonths }),
      P (fun p => { p with relationship := .biologicalChild, dateOfBirth := ⟨2014, 1, 20⟩
                           residencyDuration := .allYear })
        (A fun a => { a with tinType := .noTin })]
    minimumFilerDateOfBirth := ⟨1985, 6, 15⟩, treatFilersAsDependents := false
    eitherFilerUsCitizenOrNational := true, treatAsMfj := false }
#guard hh.results.length == 3
#guard hh.claimedDependentsCount == 1

-- TestOwnSupportChildCannotBeAnyonesQualifyingChild
private def d15 := dep
  (P fun p => { p with relationship := .biologicalChild, dateOfBirth := ⟨2015, 9, 9⟩
                       residencyDuration := .allYear, ownSupport := true
                       writableCouldBeQualifyingChildOfAnother := true
                       writablePotentialClaimerMustFile := true })
#guard !d15.qc.qcSupportTest
#guard !d15.couldBeQualifyingChildOfSomeTaxpayer
#guard d15.notQualifyingChildTest
#guard !d15.qrSupportTest
#guard !d15.qualifyingRelative
#guard !d15.eligibleDependent

-- test_dependents_benefit_split: TestCustodialReleasedKeepsHohEitcCdcc
private def releasedMember (nobody : Bool) : Member :=
  { person := DependentsBenefitSplit.defaultMember.person
    answers :=
      { grossIncome := 0, writableQrSupportTest := false, tinType := .ssn
        isUsCitizenFullYear := true, writableUsResident := false, writableUsNational := false
        writableCanadaMexicoResident := false, tpClaims := true }
    split :=
      if nobody then
        { DependentsBenefitSplit.defaultMember.answers with whichParentNotClaiming := .nobodyDid }
      else DependentsBenefitSplit.defaultMember.answers }
private def released := dep (releasedMember false)
private def releasedWithoutSplit := dep (releasedMember true)
#guard released.split.tpCanClaimSplitBenefitsHohEitcCdcc
#guard released.qualifyingChild
#guard !released.eligibleDependent
#guard !released.isClaimedDependent
#guard released.isClaimedIfClaimable
#guard !releasedWithoutSplit.split.tpCanClaimSplitBenefitsHohEitcCdcc
#guard releasedWithoutSplit.eligibleDependent
#guard releasedWithoutSplit.isClaimedDependent

end UsTax.QualifyingRelative
