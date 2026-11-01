import UsTax.Types
import UsTax.Date
import UsTax.Filers
import UsTax.Lists

/-!
# Qualifying child: the five tests of IRC 152(c), one person at a time (issue #44)

Lean implementation of `catala/qualifying_child.catala_en` (module `Qualifying_child`),
written by hand from the Catala source under strategy (c) of `docs/catala-to-lean.md`, in
the order of the Catala file.

| Catala (`Qualifying_child`)            | Lean (`UsTax.QualifyingChild`)                 |
|----------------------------------------|------------------------------------------------|
| enums `Relationship`, `ResidencyDuration` | same names                                  |
| struct `Person`                        | `Person`                                       |
| `qc_age_limit`, ...                    | `qcAgeLimit`, `qcStudentAgeLimit`, ...         |
| `scope QualifyingChildTest`            | `QualifyingChildTestIn` → `QualifyingChildTestOut` (`qualifyingChildTest`) |
| `scope QualifyingChildren`             | `QualifyingChildrenIn` → `QualifyingChildrenOut` (`qualifyingChildren`) |

`list of` is `List`, `map each p among persons to f p` is `List.map`, and `number of (list
of r among results such that c r)` is `Money.countBy` (`UsTax/Lists.lean`). A rule without an
exception sibling is a `Bool`.
-/

namespace UsTax.QualifyingChild

/-- Catala `Relationship` (DF `/relationshipOptions`), same order. -/
inductive Relationship where
  | biologicalChild | adoptedChild | stepChild | fosterChild | grandChildOrOtherDescendantOfChild
  | childInLaw | sibling | childOfSibling | halfSibling | childOfHalfSibling | stepSibling
  | childOfStepSibling | otherDescendantOfSibling | otherDescendantOfHalfSibling
  | otherDescendantOfStepSibling | siblingsSpouse | siblingInLaw | parent | fosterParent
  | siblingOfParent | grandParent | otherAncestorOfParent | stepParent | parentInLaw
  | noneOfTheAbove
  deriving DecidableEq, Repr, Inhabited

namespace Relationship

/-- The Catala case names with their constructors. -/
def all : List (String × Relationship) :=
  [("BiologicalChild", biologicalChild), ("AdoptedChild", adoptedChild),
   ("StepChild", stepChild), ("FosterChild", fosterChild),
   ("GrandChildOrOtherDescendantOfChild", grandChildOrOtherDescendantOfChild),
   ("ChildInLaw", childInLaw), ("Sibling", sibling), ("ChildOfSibling", childOfSibling),
   ("HalfSibling", halfSibling), ("ChildOfHalfSibling", childOfHalfSibling),
   ("StepSibling", stepSibling), ("ChildOfStepSibling", childOfStepSibling),
   ("OtherDescendantOfSibling", otherDescendantOfSibling),
   ("OtherDescendantOfHalfSibling", otherDescendantOfHalfSibling),
   ("OtherDescendantOfStepSibling", otherDescendantOfStepSibling),
   ("SiblingsSpouse", siblingsSpouse), ("SiblingInLaw", siblingInLaw), ("Parent", parent),
   ("FosterParent", fosterParent), ("SiblingOfParent", siblingOfParent),
   ("GrandParent", grandParent), ("OtherAncestorOfParent", otherAncestorOfParent),
   ("StepParent", stepParent), ("ParentInLaw", parentInLaw), ("NoneOfTheAbove", noneOfTheAbove)]

/-- Parse a Catala case name. -/
def ofString? (s : String) : Option Relationship := all.lookup s

#guard all.length == 25
#guard all.all fun (n, r) => ofString? n == some r

end Relationship

/-- Catala `ResidencyDuration` (DF `/residencyDurationOptions`). -/
inductive ResidencyDuration where
  | allYear | sixToElevenMonths | lessThanSixMonths
  deriving DecidableEq, Repr, Inhabited

namespace ResidencyDuration
/-- Parse a Catala case name. -/
def ofString? : String → Option ResidencyDuration
  | "AllYear" => some allYear | "SixToElevenMonths" => some sixToElevenMonths
  | "LessThanSixMonths" => some lessThanSixMonths | _ => none
end ResidencyDuration

/-- Catala `Person`: the `Writable` answers DF keeps per household member that the
qualifying child tests read. -/
structure Person where
  /-- DF `/familyAndHousehold/*/relationship`. -/
  relationship : Relationship
  /-- DF `/familyAndHousehold/*/dateOfBirth`. -/
  dateOfBirth : Date
  fullTimeStudent : Bool
  permanentTotalDisability : Bool
  residencyDuration : ResidencyDuration
  ownSupport : Bool
  married : Bool
  writableJointReturn : Bool
  writableRequiredToFile : Bool
  writableFilingOnlyForRefund : Bool
  writableCouldBeQualifyingChildOfAnother : Bool
  writablePotentialClaimerMustFile : Bool
  writablePotentialClaimerDidFile : Bool
  writablePotentialClaimerFiledOnlyForRefund : Bool

/-- IRC 152(c)(3)(A)(i): "has not attained the age of 19". -/
def qcAgeLimit : Int := 19
/-- IRC 152(c)(3)(A)(ii): "a student who has not attained the age of 24". -/
def qcStudentAgeLimit : Int := 24
/-- DF `/studentStatusMayAffectBenefits`: asked only of a person older than 18. -/
def studentQuestionMinimumAge : Int := 18
/-- DF `/disabilityStatusMayAffectBenefits`: age 18 on July 2. -/
def disabilityQuestionAge : Int := 18
/-- DF `/ageAtFirstHalfOfYear`: July (month). -/
def firstHalfMonth : Nat := 7
/-- DF `/ageAtFirstHalfOfYear`: July 2 (day). -/
def firstHalfDay : Nat := 2

/-- IRC 152(c)(2), 152(f)(1), (4); DF `/qcRelationshipTest`: the 14 child and sibling
options. -/
def qcRelationshipTest : Relationship → Bool
  | .biologicalChild | .adoptedChild | .stepChild | .fosterChild
  | .grandChildOrOtherDescendantOfChild | .sibling | .halfSibling | .stepSibling
  | .childOfSibling | .childOfHalfSibling | .childOfStepSibling | .otherDescendantOfSibling
  | .otherDescendantOfHalfSibling | .otherDescendantOfStepSibling => true
  | _ => false

/-! ### Scope `QualifyingChildTest` -/

/-- Inputs of `QualifyingChildTest`. -/
structure QualifyingChildTestIn where
  /-- One member of DF `/familyAndHousehold`. -/
  person : Person
  /-- DF filers.xml `/minimumFilerDateOfBirth`. -/
  minimumFilerDateOfBirth : Date

/-- Outputs of `QualifyingChildTest`. -/
structure QualifyingChildTestOut where
  age : Int
  ageAtFirstHalfOfYear : Int
  youngerThanOldestFiler : Bool
  qcRelationshipTest : Bool
  studentStatusMayAffectBenefits : Bool
  isAStudentUnder24 : Bool
  disabilityStatusMayAffectBenefits : Bool
  ageTest : Bool
  residencyTest : Bool
  qcSupportTest : Bool
  jointReturn : Bool
  requiredToFile : Bool
  filingOnlyForRefund : Bool
  jointReturnTest : Bool
  qualifyingChild : Bool
  qcOfAnotherButNot : Bool
  otherTaxpayerCanClaimAsQualifyingChild : Bool
  koQualifyingChildTieBreaker : Bool

/-- Catala `scope QualifyingChildTest`, definition by definition. -/
def qualifyingChildTest (i : QualifyingChildTestIn) : QualifyingChildTestOut :=
  let p := i.person
  let age := Filers.taxYear - p.dateOfBirth.year
  let ageAtFirstHalfOfYear :=
    if p.dateOfBirth.month > firstHalfMonth ||
        (p.dateOfBirth.month == firstHalfMonth && p.dateOfBirth.day > firstHalfDay)
    then age - 1 else age
  -- `person.date_of_birth > minimum_filer_date_of_birth`
  let youngerThanOldestFiler := i.minimumFilerDateOfBirth.lt p.dateOfBirth
  let studentStatusMayAffectBenefits :=
    decide (age > studentQuestionMinimumAge) && decide (age < qcStudentAgeLimit)
  let isAStudentUnder24 :=
    p.fullTimeStudent && studentStatusMayAffectBenefits && youngerThanOldestFiler
  let disabilityStatusMayAffectBenefits :=
    decide (ageAtFirstHalfOfYear ≥ disabilityQuestionAge) ||
      (decide (ageAtFirstHalfOfYear < disabilityQuestionAge) &&
        p.dateOfBirth.lt i.minimumFilerDateOfBirth)
  -- DF-BUG(11): the statute wins, so the disability answer counts for everyone.
  let ageTest :=
    (decide (age < qcAgeLimit) && youngerThanOldestFiler) || isAStudentUnder24 ||
      p.permanentTotalDisability
  let residencyTest := p.residencyDuration != .lessThanSixMonths
  let qcSupportTest := !p.ownSupport
  let jointReturn := p.married && p.writableJointReturn
  let requiredToFile := p.married && jointReturn && p.writableRequiredToFile
  let filingOnlyForRefund :=
    p.married && jointReturn && p.writableFilingOnlyForRefund && !requiredToFile
  let jointReturnTest :=
    !p.married || !jointReturn || (filingOnlyForRefund && !requiredToFile)
  let qcRel := qcRelationshipTest p.relationship
  let qualifyingChild := qcRel && ageTest && residencyTest && qcSupportTest && jointReturnTest
  let qcOfAnotherButNot :=
    p.writableCouldBeQualifyingChildOfAnother && !p.writablePotentialClaimerMustFile &&
      (!p.writablePotentialClaimerDidFile || p.writablePotentialClaimerFiledOnlyForRefund)
  let otherTaxpayerCanClaimAsQualifyingChild :=
    p.writableCouldBeQualifyingChildOfAnother && !qcOfAnotherButNot
  { age, ageAtFirstHalfOfYear, youngerThanOldestFiler, qcRelationshipTest := qcRel
    studentStatusMayAffectBenefits, isAStudentUnder24, disabilityStatusMayAffectBenefits
    ageTest, residencyTest, qcSupportTest, jointReturn, requiredToFile, filingOnlyForRefund
    jointReturnTest, qualifyingChild, qcOfAnotherButNot, otherTaxpayerCanClaimAsQualifyingChild
    koQualifyingChildTieBreaker := qualifyingChild && otherTaxpayerCanClaimAsQualifyingChild }

/-! ### Scope `QualifyingChildren` -/

/-- Inputs of `QualifyingChildren`. -/
structure QualifyingChildrenIn where
  persons : List Person
  minimumFilerDateOfBirth : Date

/-- Outputs of `QualifyingChildren`. -/
structure QualifyingChildrenOut where
  results : List QualifyingChildTestOut
  qualifyingChildCount : Int
  koQualifyingChildTieBreaker : Bool
  unsupported : Bool

/-- Catala `scope QualifyingChildren`: `QualifyingChildTest` over the household. -/
def qualifyingChildren (i : QualifyingChildrenIn) : QualifyingChildrenOut :=
  let results := i.persons.map fun p =>
    qualifyingChildTest { person := p, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth }
  let ko := results.any (·.koQualifyingChildTieBreaker)
  { results, qualifyingChildCount := (Money.countBy (·.qualifyingChild) results : Nat)
    koQualifyingChildTieBreaker := ko, unsupported := ko }

/-! ### Unit tests: every assertion of `catala/tests/test_qualifying_child.catala_en`

`MkPerson` of the Catala test is `defaultPerson`: a biological child born 2010-03-01 who
lived with the filer all year. -/

/-- The Catala test `MkPerson` with its defaults. -/
def defaultPerson : Person :=
  { relationship := .biologicalChild, dateOfBirth := ⟨2010, 3, 1⟩, fullTimeStudent := false
    permanentTotalDisability := false, residencyDuration := .allYear, ownSupport := false
    married := false, writableJointReturn := false, writableRequiredToFile := false
    writableFilingOnlyForRefund := false, writableCouldBeQualifyingChildOfAnother := false
    writablePotentialClaimerMustFile := false, writablePotentialClaimerDidFile := false
    writablePotentialClaimerFiledOnlyForRefund := false }

/-- The oldest filer of most tests: born 1985-06-15. -/
def oldestFiler : Date := ⟨1985, 6, 15⟩

private def qc (p : Person) (min : Date := oldestFiler) : QualifyingChildTestOut :=
  qualifyingChildTest { person := p, minimumFilerDateOfBirth := min }

-- TestEighteenYearOldChild
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 8, 20⟩ }).age == 18
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 8, 20⟩ }).ageTest
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 8, 20⟩ }).qcRelationshipTest
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 8, 20⟩ }).residencyTest
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 8, 20⟩ }).qcSupportTest
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 8, 20⟩ }).jointReturnTest
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 8, 20⟩ }).qualifyingChild
#guard !(qc { defaultPerson with dateOfBirth := ⟨2006, 8, 20⟩ }).koQualifyingChildTieBreaker

-- TestNineteenYearOldNonStudent
private def nineteen := qc { defaultPerson with dateOfBirth := ⟨2005, 12, 10⟩ }
#guard nineteen.age == 19
#guard !nineteen.ageTest
#guard nineteen.qcRelationshipTest && nineteen.residencyTest && nineteen.qcSupportTest &&
  nineteen.jointReturnTest
#guard !nineteen.qualifyingChild

-- TestTwentyTwoYearOldStudent / NonStudent
private def student22 := qc { defaultPerson with dateOfBirth := ⟨2002, 4, 11⟩, fullTimeStudent := true }
#guard student22.age == 22
#guard student22.studentStatusMayAffectBenefits
#guard student22.isAStudentUnder24
#guard student22.ageTest
#guard student22.qualifyingChild
#guard !(qc { defaultPerson with dateOfBirth := ⟨2002, 4, 11⟩ }).isAStudentUnder24
#guard !(qc { defaultPerson with dateOfBirth := ⟨2002, 4, 11⟩ }).qualifyingChild

-- TestTwentyFourYearOldStudent
private def student24 := qc { defaultPerson with dateOfBirth := ⟨2000, 2, 1⟩, fullTimeStudent := true }
#guard student24.age == 24
#guard !student24.studentStatusMayAffectBenefits
#guard !student24.isAStudentUnder24
#guard !student24.ageTest
#guard !student24.qualifyingChild

-- TestDisabledAdultChild / TestAdultChildNotDisabled
private def disabled40 :=
  qc { defaultPerson with dateOfBirth := ⟨1984, 1, 20⟩, permanentTotalDisability := true } ⟨1959, 5, 5⟩
#guard disabled40.age == 40
#guard disabled40.disabilityStatusMayAffectBenefits
#guard disabled40.ageTest
#guard disabled40.qualifyingChild
#guard !(qc { defaultPerson with dateOfBirth := ⟨1984, 1, 20⟩ } ⟨1959, 5, 5⟩).ageTest
#guard !(qc { defaultPerson with dateOfBirth := ⟨1984, 1, 20⟩ } ⟨1959, 5, 5⟩).qualifyingChild

-- TestChildOlderThanFiler
private def olderThanFiler :=
  qc { defaultPerson with relationship := .sibling, dateOfBirth := ⟨2007, 3, 1⟩ } ⟨2008, 5, 1⟩
#guard olderThanFiler.age == 17
#guard !olderThanFiler.youngerThanOldestFiler
#guard !olderThanFiler.ageTest
#guard !olderThanFiler.qualifyingChild

-- TestMarriedJointRefundOnly
private def marriedChild : Person :=
  { defaultPerson with dateOfBirth := ⟨2006, 2, 2⟩, married := true }
private def refundOnly := qc
  { marriedChild with writableJointReturn := true, writableRequiredToFile := false
                      writableFilingOnlyForRefund := true }
#guard refundOnly.jointReturn
#guard refundOnly.filingOnlyForRefund
#guard refundOnly.jointReturnTest
#guard refundOnly.qualifyingChild
-- TestMarriedJointNotRefundOnly
#guard !(qc { marriedChild with writableJointReturn := true }).jointReturnTest
#guard !(qc { marriedChild with writableJointReturn := true }).qualifyingChild
-- TestMarriedJointRequiredToFile
private def requiredFile := qc
  { marriedChild with writableJointReturn := true, writableRequiredToFile := true
                      writableFilingOnlyForRefund := true }
#guard requiredFile.requiredToFile
#guard !requiredFile.filingOnlyForRefund
#guard !requiredFile.jointReturnTest
#guard !requiredFile.qualifyingChild
-- TestMarriedSeparate
#guard (qc marriedChild).jointReturnTest
#guard (qc marriedChild).qualifyingChild
-- TestJointAnswersIgnoredIfUnmarried
private def unmarriedJoint := qc
  { defaultPerson with writableJointReturn := true, writableRequiredToFile := true }
#guard !unmarriedJoint.jointReturn
#guard !unmarriedJoint.requiredToFile
#guard unmarriedJoint.qualifyingChild

-- TestRelationships
private def rel (r : Relationship) : QualifyingChildTestOut := qc { defaultPerson with relationship := r }
#guard (qc defaultPerson).qualifyingChild
#guard (rel .stepChild).qualifyingChild
#guard (rel .fosterChild).qualifyingChild
#guard (rel .grandChildOrOtherDescendantOfChild).qualifyingChild
#guard (rel .childOfSibling).qualifyingChild
#guard (rel .childOfHalfSibling).qualifyingChild
#guard !(rel .childInLaw).qcRelationshipTest
#guard !(rel .childInLaw).qualifyingChild
#guard !(rel .siblingInLaw).qualifyingChild
#guard !(rel .parent).qualifyingChild
#guard !(rel .siblingOfParent).qualifyingChild
#guard !(rel .noneOfTheAbove).qualifyingChild

-- TestResidency
private def res (r : ResidencyDuration) := qc { defaultPerson with residencyDuration := r }
#guard (res .sixToElevenMonths).residencyTest
#guard (res .sixToElevenMonths).qualifyingChild
#guard !(res .lessThanSixMonths).residencyTest
#guard !(res .lessThanSixMonths).qualifyingChild

-- TestOwnSupport
#guard !(qc { defaultPerson with ownSupport := true }).qcSupportTest
#guard !(qc { defaultPerson with ownSupport := true }).qualifyingChild

-- TestPub501YoungerThanSpouse
private def sibStudent : Person :=
  { defaultPerson with relationship := .sibling, dateOfBirth := ⟨2001, 7, 1⟩, fullTimeStudent := true }
#guard (qc sibStudent ⟨2003, 1, 10⟩).age == 23
#guard !(qc sibStudent ⟨2003, 1, 10⟩).qualifyingChild
#guard (qc sibStudent ⟨1999, 1, 10⟩).qualifyingChild

-- TestAgeAtFirstHalfOfYear
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 7, 2⟩ }).ageAtFirstHalfOfYear == 18
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 7, 2⟩ }).disabilityStatusMayAffectBenefits
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 7, 3⟩ }).ageAtFirstHalfOfYear == 17
#guard !(qc { defaultPerson with dateOfBirth := ⟨2006, 7, 3⟩ }).disabilityStatusMayAffectBenefits
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 7, 3⟩ }).age == 18
#guard (qc { defaultPerson with dateOfBirth := ⟨2006, 7, 3⟩ }).qualifyingChild

-- TestDisabledTwinOfFiler (DF-BUG(16-a): the law wins, DF fails the age test)
private def twin := qc
  { defaultPerson with relationship := .sibling, dateOfBirth := ⟨2007, 3, 1⟩
                       permanentTotalDisability := true } ⟨2007, 3, 1⟩
#guard !twin.disabilityStatusMayAffectBenefits
#guard twin.ageTest
#guard twin.qualifyingChild

-- TestStudentEighteenNotAsked
private def student18 := qc { defaultPerson with dateOfBirth := ⟨2006, 1, 15⟩, fullTimeStudent := true }
#guard !student18.studentStatusMayAffectBenefits
#guard student18.ageTest

-- TestTieBreakerKnockout
private def mustFile := qc
  { defaultPerson with writableCouldBeQualifyingChildOfAnother := true
                       writablePotentialClaimerMustFile := true }
private def filesForTax := qc
  { defaultPerson with writableCouldBeQualifyingChildOfAnother := true
                       writablePotentialClaimerDidFile := true }
private def refundOnlyClaimer := qc
  { defaultPerson with writableCouldBeQualifyingChildOfAnother := true
                       writablePotentialClaimerDidFile := true
                       writablePotentialClaimerFiledOnlyForRefund := true }
private def notFiling := qc { defaultPerson with writableCouldBeQualifyingChildOfAnother := true }
private def notMyQc := qc
  { defaultPerson with writableCouldBeQualifyingChildOfAnother := true
                       writablePotentialClaimerMustFile := true
                       residencyDuration := .lessThanSixMonths }
#guard mustFile.qualifyingChild
#guard mustFile.koQualifyingChildTieBreaker
#guard filesForTax.koQualifyingChildTieBreaker
#guard refundOnlyClaimer.qcOfAnotherButNot
#guard !refundOnlyClaimer.koQualifyingChildTieBreaker
#guard notFiling.qcOfAnotherButNot
#guard !notFiling.koQualifyingChildTieBreaker
#guard !notMyQc.qualifyingChild
#guard !notMyQc.koQualifyingChildTieBreaker

-- TestHousehold
private def kid : Person := defaultPerson
private def student : Person := { defaultPerson with dateOfBirth := ⟨2003, 9, 9⟩, fullTimeStudent := true }
private def adult : Person := { defaultPerson with dateOfBirth := ⟨1995, 9, 9⟩ }
private def parentP : Person := { defaultPerson with relationship := .parent, dateOfBirth := ⟨1955, 1, 1⟩ }
private def tie : Person :=
  { defaultPerson with writableCouldBeQualifyingChildOfAnother := true
                       writablePotentialClaimerMustFile := true }
private def h := qualifyingChildren { persons := [kid, student, adult, parentP], minimumFilerDateOfBirth := ⟨1980, 1, 1⟩ }
private def hTie := qualifyingChildren { persons := [kid, tie], minimumFilerDateOfBirth := ⟨1980, 1, 1⟩ }
private def hEmpty := qualifyingChildren { persons := [], minimumFilerDateOfBirth := ⟨1980, 1, 1⟩ }
#guard h.results.length == 4
#guard h.qualifyingChildCount == 2
#guard !h.unsupported
#guard hTie.qualifyingChildCount == 2
#guard hTie.koQualifyingChildTieBreaker
#guard hTie.unsupported
#guard hEmpty.qualifyingChildCount == 0
#guard !hEmpty.unsupported

end UsTax.QualifyingChild
