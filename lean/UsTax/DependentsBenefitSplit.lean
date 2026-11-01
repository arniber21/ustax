import UsTax.QualifyingChild

/-!
# Children of divorced or separated parents: the benefit split, IRC 152(e) (issue #44)

Lean implementation of `catala/dependents_benefit_split.catala_en` (module
`Dependents_benefit_split`), written by hand from the Catala source under strategy (c) of
`docs/catala-to-lean.md`, in the order of the Catala file. It reads only
`UsTax.QualifyingChild`.

| Catala (`Dependents_benefit_split`)    | Lean (`UsTax.DependentsBenefitSplit`)           |
|----------------------------------------|-------------------------------------------------|
| enums `ParentalSituation`, `WrittenDeclaration`, `NightsComparison` | same names |
| struct `BenefitSplitAnswers`, `Member` | `BenefitSplitAnswers`, `Member`                 |
| `age_of_majority`                      | `ageOfMajority`                                 |
| `scope BenefitSplitTest`               | `BenefitSplitTestIn` → `BenefitSplitTestOut` (`benefitSplitTest`) |
| `scope BenefitSplit`                   | `BenefitSplitIn` → `BenefitSplitOut` (`benefitSplit`) |
-/

namespace UsTax.DependentsBenefitSplit

open QualifyingChild

/-- Catala `ParentalSituation` (DF `/parentalSituationOptions`). -/
inductive ParentalSituation where
  | divorcedOrSeparated | livedApartLastSixMonths | other
  deriving DecidableEq, Repr, Inhabited

/-- Catala `WrittenDeclaration` (DF `/writtenDeclarationOptions`). -/
inductive WrittenDeclaration where
  | iDid | theyDid | nobodyDid
  deriving DecidableEq, Repr, Inhabited

/-- Catala `NightsComparison` (DF `/moreLessEqualOptions`). -/
inductive NightsComparison where
  | more | less | equal
  deriving DecidableEq, Repr, Inhabited

namespace ParentalSituation
/-- Parse a Catala case name. -/
def ofString? : String → Option ParentalSituation
  | "DivorcedOrSeparated" => some divorcedOrSeparated
  | "LivedApartLastSixMonths" => some livedApartLastSixMonths | "Other" => some other | _ => none
end ParentalSituation

namespace WrittenDeclaration
/-- Parse a Catala case name. -/
def ofString? : String → Option WrittenDeclaration
  | "IDid" => some iDid | "TheyDid" => some theyDid | "NobodyDid" => some nobodyDid | _ => none
end WrittenDeclaration

namespace NightsComparison
/-- Parse a Catala case name. -/
def ofString? : String → Option NightsComparison
  | "More" => some more | "Less" => some less | "Equal" => some equal | _ => none
end NightsComparison

/-- Catala `BenefitSplitAnswers`: the `Writable` answers the benefit split reads. -/
structure BenefitSplitAnswers where
  hasOtherBiologicalOrAdoptiveParent : Bool
  nonParentalSomeParentNotClaiming : Bool
  whichParentNotClaiming : WrittenDeclaration
  inParentsCustody : Bool
  livedWithTpOrOtherBiologicalOrAdoptiveParentMoreThanSixMonths : Bool
  biologicalOrAdoptiveParentsLiving : Bool
  nightsWithTpVsOtherParent : NightsComparison
  tpAgiHigherThanOtherParent : Bool
  parentsMeetReqsRuleForChildrenOfDivorcedParents : Bool
  specialRuleChildUsedByCustodialParentAsQp : Bool
  specialRuleAgiTest : Bool
  parentalSituation : ParentalSituation
  parentalSupport : Bool
  /-- No DF fact (DF-BUG(18)): a multiple support agreement, IRC 152(d)(3). -/
  multipleSupportAgreement : Bool

/-- Catala `Member`: the qualifying-child answers and the benefit-split answers. -/
structure Member where
  person : Person
  answers : BenefitSplitAnswers

/-- Age of majority; DF assumes custody ends at 18. -/
def ageOfMajority : Int := 18

/-! ### Scope `BenefitSplitTest` -/

/-- Inputs of `BenefitSplitTest`. -/
structure BenefitSplitTestIn where
  member : Member
  minimumFilerDateOfBirth : Date
  treatAsMfj : Bool

/-- Outputs of `BenefitSplitTest` (`qc` is the sub-scope result). -/
structure BenefitSplitTestOut where
  qc : QualifyingChildTestOut
  childMayQualifyForBenefitSplit : Bool
  tpIsParent : Bool
  tpIsNotParent : Bool
  parentalSomeParentNotClaiming : Bool
  primaryFilerNotClaiming : Bool
  bothFilersNotClaiming : Bool
  otherParentNotClaiming : Bool
  hadEqualNumberOfNightsWithParents : Bool
  parentsAreDivorcedSeparatedOrLivingApart : Bool
  tpIsCustodialParent : Bool
  section152eAppliesDespiteSupportAgreements : Bool
  eligibleOnParentalPath : Bool
  eligibleOnNonParentalPath : Bool
  eligibleForBenefitSplit : Bool
  reachedNonParentalBenefitSplit : Bool
  tpCanClaimSplitBenefitsHohEitcCdcc : Bool
  disqualifiedDueToParentalCustody : Bool
  contradictory8832TpIsCustodialParent : Bool
  contradictory8832TpNotCustodialParent : Bool
  contradictory8832Knockout : Bool
  causesNoncustodialParentBenefitSplitKnockout : Bool
  unsupported : Bool

/-- Catala `scope BenefitSplitTest`, definition by definition. -/
def benefitSplitTest (i : BenefitSplitTestIn) : BenefitSplitTestOut :=
  let a := i.member.answers
  let p := i.member.person
  let qc := qualifyingChildTest { person := p, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth }
  let childMayQualifyForBenefitSplit :=
    decide (qc.ageAtFirstHalfOfYear < ageOfMajority) ||
      (qc.disabilityStatusMayAffectBenefits && p.permanentTotalDisability)
  let tpIsParent := p.relationship == .biologicalChild || p.relationship == .adoptedChild
  let tpIsNotParent := !tpIsParent && qc.qcRelationshipTest
  let parentsAreDivorcedSeparatedOrLivingApart := a.parentalSituation != .other
  let parentalSomeParentNotClaiming :=
    a.whichParentNotClaiming == .iDid || a.whichParentNotClaiming == .theyDid
  let primaryFilerNotClaiming := a.whichParentNotClaiming == .iDid && !i.treatAsMfj
  let bothFilersNotClaiming := a.whichParentNotClaiming == .iDid && i.treatAsMfj
  let otherParentNotClaiming := a.whichParentNotClaiming == .theyDid
  let hadEqualNumberOfNightsWithParents := a.nightsWithTpVsOtherParent == .equal
  let tpIsCustodialParent :=
    a.nightsWithTpVsOtherParent == .more ||
      (a.nightsWithTpVsOtherParent == .equal && a.tpAgiHigherThanOtherParent)
  let section152eAppliesDespiteSupportAgreements := !a.multipleSupportAgreement
  let eligibleOnParentalPath :=
    childMayQualifyForBenefitSplit && tpIsParent && a.hasOtherBiologicalOrAdoptiveParent &&
      parentalSomeParentNotClaiming && a.inParentsCustody &&
      a.livedWithTpOrOtherBiologicalOrAdoptiveParentMoreThanSixMonths &&
      parentsAreDivorcedSeparatedOrLivingApart && a.parentalSupport &&
      section152eAppliesDespiteSupportAgreements
  let reachedNonParentalBenefitSplit :=
    childMayQualifyForBenefitSplit && tpIsNotParent && a.biologicalOrAdoptiveParentsLiving &&
      a.inParentsCustody && a.nonParentalSomeParentNotClaiming &&
      a.parentsMeetReqsRuleForChildrenOfDivorcedParents &&
      section152eAppliesDespiteSupportAgreements
  let eligibleOnNonParentalPath :=
    reachedNonParentalBenefitSplit && !a.specialRuleChildUsedByCustodialParentAsQp &&
      a.specialRuleAgiTest
  let eligibleForBenefitSplit := eligibleOnParentalPath || eligibleOnNonParentalPath
  let disqualifiedDueToParentalCustody :=
    reachedNonParentalBenefitSplit &&
      (!a.specialRuleAgiTest || a.specialRuleChildUsedByCustodialParentAsQp)
  let tpCanClaimSplitBenefitsHohEitcCdcc :=
    eligibleForBenefitSplit &&
      ((a.whichParentNotClaiming == .iDid && tpIsCustodialParent) || reachedNonParentalBenefitSplit)
  let contradictory8832TpIsCustodialParent :=
    tpIsCustodialParent && a.whichParentNotClaiming == .theyDid
  let contradictory8832TpNotCustodialParent :=
    !tpIsCustodialParent && a.whichParentNotClaiming == .iDid
  let contradictory8832Knockout :=
    eligibleForBenefitSplit &&
      (contradictory8832TpIsCustodialParent || contradictory8832TpNotCustodialParent)
  let causesNoncustodialParentBenefitSplitKnockout :=
    eligibleForBenefitSplit && !tpIsCustodialParent && a.whichParentNotClaiming == .theyDid
  { qc, childMayQualifyForBenefitSplit, tpIsParent, tpIsNotParent, parentalSomeParentNotClaiming
    primaryFilerNotClaiming, bothFilersNotClaiming, otherParentNotClaiming
    hadEqualNumberOfNightsWithParents, parentsAreDivorcedSeparatedOrLivingApart
    tpIsCustodialParent, section152eAppliesDespiteSupportAgreements, eligibleOnParentalPath
    eligibleOnNonParentalPath, eligibleForBenefitSplit, reachedNonParentalBenefitSplit
    tpCanClaimSplitBenefitsHohEitcCdcc, disqualifiedDueToParentalCustody
    contradictory8832TpIsCustodialParent, contradictory8832TpNotCustodialParent
    contradictory8832Knockout, causesNoncustodialParentBenefitSplitKnockout
    unsupported := contradictory8832Knockout || causesNoncustodialParentBenefitSplitKnockout }

/-! ### Scope `BenefitSplit` -/

/-- Inputs of `BenefitSplit`. -/
structure BenefitSplitIn where
  members : List Member
  minimumFilerDateOfBirth : Date
  treatAsMfj : Bool

/-- Outputs of `BenefitSplit`. -/
structure BenefitSplitOut where
  results : List BenefitSplitTestOut
  koKnockedOutByContradictory8832 : Bool
  koKnockedOutByNonCustodialParentBenefitSplit : Bool
  unsupported : Bool

/-- Catala `scope BenefitSplit`: `BenefitSplitTest` over the household. -/
def benefitSplit (i : BenefitSplitIn) : BenefitSplitOut :=
  let results := i.members.map fun m =>
    benefitSplitTest { member := m, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
                       treatAsMfj := i.treatAsMfj }
  let k1 := results.any (·.contradictory8832Knockout)
  let k2 := results.any (·.causesNoncustodialParentBenefitSplitKnockout)
  { results, koKnockedOutByContradictory8832 := k1
    koKnockedOutByNonCustodialParentBenefitSplit := k2, unsupported := k1 || k2 }

/-! ### Unit tests: every assertion of `catala/tests/test_dependents_benefit_split.catala_en`

`MkMember` of the Catala test is `defaultMember`: a biological child born 2016-05-01, a
divorced parent who signed (`IDid`), more nights with the filer, parents not living. The
assertion of `TestCustodialReleasedKeepsHohEitcCdcc` that reads `Dependents` is in
`UsTax/QualifyingRelative.lean`. -/

/-- The Catala test `MkMember` with its defaults. -/
def defaultMember : Member :=
  { person := { defaultPerson with relationship := .biologicalChild, dateOfBirth := ⟨2016, 5, 1⟩ }
    answers :=
      { hasOtherBiologicalOrAdoptiveParent := true, nonParentalSomeParentNotClaiming := false
        whichParentNotClaiming := .iDid, inParentsCustody := true
        livedWithTpOrOtherBiologicalOrAdoptiveParentMoreThanSixMonths := true
        biologicalOrAdoptiveParentsLiving := false, nightsWithTpVsOtherParent := .more
        tpAgiHigherThanOtherParent := false
        parentsMeetReqsRuleForChildrenOfDivorcedParents := false
        specialRuleChildUsedByCustodialParentAsQp := false, specialRuleAgiTest := false
        parentalSituation := .divorcedOrSeparated, parentalSupport := true
        multipleSupportAgreement := false } }

private def mem (f : Member → Member) : Member := f defaultMember
private def ans (f : BenefitSplitAnswers → BenefitSplitAnswers) : Member :=
  { defaultMember with answers := f defaultMember.answers }
private def split (m : Member) (mfj : Bool := false) (min : Date := ⟨1985, 6, 15⟩) :
    BenefitSplitTestOut :=
  benefitSplitTest { member := m, minimumFilerDateOfBirth := min, treatAsMfj := mfj }

-- TestMoreNightsCustodialReleased
private def s1 := split defaultMember
#guard s1.childMayQualifyForBenefitSplit
#guard s1.tpIsParent && !s1.tpIsNotParent
#guard s1.parentalSomeParentNotClaiming
#guard s1.primaryFilerNotClaiming && !s1.bothFilersNotClaiming
#guard !s1.otherParentNotClaiming
#guard !s1.hadEqualNumberOfNightsWithParents
#guard s1.parentsAreDivorcedSeparatedOrLivingApart
#guard s1.tpIsCustodialParent
#guard s1.eligibleForBenefitSplit
#guard !s1.reachedNonParentalBenefitSplit
#guard s1.tpCanClaimSplitBenefitsHohEitcCdcc
#guard !s1.disqualifiedDueToParentalCustody
#guard !s1.contradictory8832Knockout
#guard !s1.causesNoncustodialParentBenefitSplitKnockout
#guard !s1.unsupported

-- TestEqualNightsHigherAgi
private def s2 := split (ans fun a => { a with nightsWithTpVsOtherParent := .equal, tpAgiHigherThanOtherParent := true })
#guard s2.hadEqualNumberOfNightsWithParents
#guard s2.tpIsCustodialParent
#guard s2.tpCanClaimSplitBenefitsHohEitcCdcc
#guard !s2.unsupported

-- TestEqualNightsLowerAgi
private def s3 := split (ans fun a => { a with nightsWithTpVsOtherParent := .equal, tpAgiHigherThanOtherParent := false })
#guard !s3.tpIsCustodialParent
#guard s3.contradictory8832TpNotCustodialParent
#guard s3.contradictory8832Knockout
#guard !s3.tpCanClaimSplitBenefitsHohEitcCdcc
#guard s3.unsupported

-- TestNoncustodialClaimant
private def s5 := split (ans fun a => { a with nightsWithTpVsOtherParent := .less, whichParentNotClaiming := .theyDid })
#guard s5.eligibleForBenefitSplit
#guard s5.otherParentNotClaiming
#guard !s5.tpIsCustodialParent
#guard s5.causesNoncustodialParentBenefitSplitKnockout
#guard !s5.contradictory8832Knockout
#guard !s5.tpCanClaimSplitBenefitsHohEitcCdcc
#guard s5.unsupported

-- TestCustodialButOtherSigned
private def s6 := split (ans fun a => { a with whichParentNotClaiming := .theyDid })
#guard s6.tpIsCustodialParent
#guard s6.contradictory8832TpIsCustodialParent
#guard s6.contradictory8832Knockout
#guard !s6.causesNoncustodialParentBenefitSplitKnockout
#guard !s6.tpCanClaimSplitBenefitsHohEitcCdcc
#guard s6.unsupported

-- TestNobodySigned
private def s7 := split (ans fun a => { a with whichParentNotClaiming := .nobodyDid }) true
#guard s7.tpIsCustodialParent
#guard !s7.parentalSomeParentNotClaiming
#guard !s7.bothFilersNotClaiming
#guard !s7.eligibleForBenefitSplit
#guard !s7.tpCanClaimSplitBenefitsHohEitcCdcc
#guard !s7.unsupported

-- TestNotSeparatedNoKnockout
private def s8 := split
  { defaultMember with person := { defaultMember.person with relationship := .adoptedChild }
                       answers := { defaultMember.answers with whichParentNotClaiming := .theyDid
                                                               parentalSituation := .other } } true
#guard s8.tpIsParent
#guard !s8.parentsAreDivorcedSeparatedOrLivingApart
#guard s8.contradictory8832TpIsCustodialParent
#guard !s8.eligibleForBenefitSplit
#guard !s8.contradictory8832Knockout
#guard !s8.unsupported

-- TestAgeOfMajorityBoundary
private def dob (d : Date) : Member := mem fun m => { m with person := { m.person with dateOfBirth := d } }
#guard !(split (dob ⟨2006, 7, 2⟩)).childMayQualifyForBenefitSplit
#guard !(split (dob ⟨2006, 7, 2⟩)).eligibleForBenefitSplit
#guard !(split (dob ⟨2006, 7, 2⟩)).tpCanClaimSplitBenefitsHohEitcCdcc
#guard (split (dob ⟨2006, 7, 3⟩)).childMayQualifyForBenefitSplit
#guard (split (dob ⟨2006, 7, 3⟩)).eligibleForBenefitSplit
#guard (split (dob ⟨2006, 7, 3⟩)).tpCanClaimSplitBenefitsHohEitcCdcc

-- TestDisabledAdultChild
private def s9 := split
  (mem fun m => { m with person := { m.person with dateOfBirth := ⟨1994, 3, 1⟩, permanentTotalDisability := true } })
  false ⟨1965, 6, 15⟩
#guard s9.childMayQualifyForBenefitSplit
#guard s9.eligibleForBenefitSplit
#guard s9.tpCanClaimSplitBenefitsHohEitcCdcc

-- TestMultipleSupportAgreement
private def s10 := split (ans fun a => { a with multipleSupportAgreement := true })
#guard !s10.section152eAppliesDespiteSupportAgreements
#guard s10.tpIsCustodialParent
#guard !s10.eligibleForBenefitSplit
#guard !s10.tpCanClaimSplitBenefitsHohEitcCdcc

-- TestGrandparent*: the non-parental path
private def grand (agi used : Bool) : BenefitSplitTestOut :=
  split
    { person := { defaultMember.person with relationship := .grandChildOrOtherDescendantOfChild
                                            dateOfBirth := ⟨2019, 3, 1⟩ }
      answers := { defaultMember.answers with whichParentNotClaiming := .nobodyDid
                                              biologicalOrAdoptiveParentsLiving := true
                                              nonParentalSomeParentNotClaiming := true
                                              parentsMeetReqsRuleForChildrenOfDivorcedParents := true
                                              specialRuleChildUsedByCustodialParentAsQp := used
                                              specialRuleAgiTest := agi } }
    false ⟨1960, 6, 15⟩
#guard (grand true false).tpIsNotParent
#guard (grand true false).reachedNonParentalBenefitSplit
#guard (grand true false).eligibleForBenefitSplit
#guard (grand true false).tpCanClaimSplitBenefitsHohEitcCdcc
#guard !(grand true false).disqualifiedDueToParentalCustody
#guard !(grand true false).unsupported
#guard (grand false false).reachedNonParentalBenefitSplit
#guard !(grand false false).eligibleForBenefitSplit
#guard !(grand false false).tpCanClaimSplitBenefitsHohEitcCdcc
#guard (grand false false).disqualifiedDueToParentalCustody
#guard !(grand true true).eligibleForBenefitSplit
#guard (grand true true).disqualifiedDueToParentalCustody

-- TestHousehold
private def second : Member :=
  { defaultMember with person := { defaultMember.person with dateOfBirth := ⟨2012, 10, 10⟩ }
                       answers := { defaultMember.answers with nightsWithTpVsOtherParent := .less
                                                               whichParentNotClaiming := .theyDid } }
private def hh := benefitSplit { members := [defaultMember, second], minimumFilerDateOfBirth := ⟨1985, 6, 15⟩, treatAsMfj := false }
#guard hh.results.length == 2
#guard !hh.koKnockedOutByContradictory8832
#guard hh.koKnockedOutByNonCustodialParentBenefitSplit
#guard hh.unsupported
-- TestHouseholdSupported
private def hh1 := benefitSplit { members := [defaultMember], minimumFilerDateOfBirth := ⟨1985, 6, 15⟩, treatAsMfj := false }
#guard !hh1.koKnockedOutByContradictory8832
#guard !hh1.koKnockedOutByNonCustodialParentBenefitSplit
#guard !hh1.unsupported

end UsTax.DependentsBenefitSplit
