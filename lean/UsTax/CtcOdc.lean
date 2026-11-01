import UsTax.Money
import UsTax.Lists
import UsTax.Types
import UsTax.Eitc
import UsTax.QualifyingRelative
import UsTax.Params2024.EitcCtc

/-!
# Child tax credit, credit for other dependents, additional child tax credit (issue #46)

Lean implementation of `catala/ctc_odc.catala_en` (module `Ctc_odc`: Schedule 8812; Form
1040 lines 19 and 28), written by hand from the Catala source under strategy (c) of
`docs/catala-to-lean.md`, in the order of the Catala file; the code that runs. Law:
26 U.S.C. § 24, Schedule 8812 (2024) and its instructions.

| Catala (`Ctc_odc`)                         | Lean (`UsTax.CtcOdc`)                              |
|--------------------------------------------|----------------------------------------------------|
| `ctc_age_limit`, `actc_alternative_minimum_children` | `ctcAgeLimit`, `actcAlternativeMinimumChildren` |
| enumeration `SsnEmploymentValidity`        | `SsnEmploymentValidity`                            |
| structure `HouseholdMember`                | `HouseholdMember`                                  |
| `scope CtcOdcPersonTest`                   | `CtcOdcPersonTestIn` → `CtcOdcPersonTestOut` (`ctcOdcPersonTest`) |
| `scope CtcOdcDependents`                   | `CtcOdcDependentsIn` → `CtcOdcDependentsOut` (`ctcOdcDependents`) |
| `scope Schedule8812`                       | `Schedule8812In` → `Schedule8812Out` (`schedule8812`) |

Money is `Int` cents. Every `R.round_dollar` is `Money.roundDollar`, every `money * decimal`
is `Money.mulRate`, `R.stepwise_multiply` is `Money.stepwiseMultiply`, so the rounding points
are Catala's. Rules without an exception sibling are `Bool`s.
-/

namespace UsTax.CtcOdc

open UsTax.Money QualifyingRelative

/-- IRC 24(c)(1): "has not attained age 17". -/
def ctcAgeLimit : Int := 17

/-- IRC 24(d)(1)(B)(ii): "3 or more qualifying children". -/
def actcAlternativeMinimumChildren : Int := 3

/-- Catala `SsnEmploymentValidity` (DF `/familyAndHouseholdSsnEmploymentValidityOptions`). -/
inductive SsnEmploymentValidity where
  | neither
  | notValid
  | validOnlyWithDhsAuthorizationInEffect
  | validOnlyWithDhsAuthorizationExpired
  deriving DecidableEq, Repr, Inhabited

namespace SsnEmploymentValidity

/-- Parse a Catala case name. -/
def ofString? : String → Option SsnEmploymentValidity
  | "Neither" => some neither
  | "NotValid" => some notValid
  | "ValidOnlyWithDhsAuthorizationInEffect" => some validOnlyWithDhsAuthorizationInEffect
  | "ValidOnlyWithDhsAuthorizationExpired" => some validOnlyWithDhsAuthorizationExpired
  | _ => none

end SsnEmploymentValidity

/-- Catala `HouseholdMember`: one member of DF `/familyAndHousehold`, with the one answer the CTC
reads beyond those of `QualifyingRelative.Member`. -/
structure HouseholdMember where
  member : QualifyingRelative.Member
  ssnEmploymentValidity : SsnEmploymentValidity

/-! ### Scope `CtcOdcPersonTest` -/

/-- Inputs of `CtcOdcPersonTest`. -/
structure CtcOdcPersonTestIn where
  householdMember : HouseholdMember
  minimumFilerDateOfBirth : Date
  treatFilersAsDependents : Bool
  eitherFilerUsCitizenOrNational : Bool
  treatAsMfj : Bool

/-- Outputs of `CtcOdcPersonTest`. -/
structure CtcOdcPersonTestOut where
  dependent : DependentTestOut
  ssnValidForEmployment : Bool
  eligibleCtc : Bool
  eligibleOdc : Bool

/-- Catala `scope CtcOdcPersonTest`, definition by definition. -/
def ctcOdcPersonTest (i : CtcOdcPersonTestIn) : CtcOdcPersonTestOut :=
  let dependent := dependentTest
    { member := i.householdMember.member
      minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
      treatFilersAsDependents := i.treatFilersAsDependents
      eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational
      treatAsMfj := i.treatAsMfj }
  -- IRC 24(h)(7); i1040s8--2024.pdf p 1.
  let ssnValidForEmployment :=
    i.householdMember.ssnEmploymentValidity == .neither ||
      i.householdMember.ssnEmploymentValidity == .validOnlyWithDhsAuthorizationInEffect
  -- IRC 24(a), 24(c)(1), 24(c)(2), 24(h)(7); i1040s8--2024.pdf pp 1-2.
  let eligibleCtc :=
    dependent.isClaimedDependent && dependent.qualifyingChild &&
      decide (dependent.qc.age < ctcAgeLimit) && dependent.citizenOrUsResidentTest &&
      i.householdMember.member.answers.tinType == TinType.ssn && ssnValidForEmployment
  -- IRC 24(h)(4)(A)-(C); Treas. Reg. 1.24-1(a); Sch 8812 line 6.
  let eligibleOdc :=
    dependent.isClaimedDependent && !eligibleCtc && dependent.citizenOrUsResidentTest
  { dependent, ssnValidForEmployment, eligibleCtc, eligibleOdc }

/-! ### Scope `CtcOdcDependents` -/

/-- Inputs of `CtcOdcDependents`. -/
structure CtcOdcDependentsIn where
  householdMembers : List HouseholdMember
  minimumFilerDateOfBirth : Date
  treatFilersAsDependents : Bool
  eitherFilerUsCitizenOrNational : Bool
  treatAsMfj : Bool

/-- Outputs of `CtcOdcDependents`. -/
structure CtcOdcDependentsOut where
  results : List CtcOdcPersonTestOut
  ctcEligibleDependents : Int
  odcEligibleDependents : Int

/-- Catala `scope CtcOdcDependents`: the person test mapped over the household, and the two
counts, Schedule 8812 lines 4 and 6. -/
def ctcOdcDependents (i : CtcOdcDependentsIn) : CtcOdcDependentsOut :=
  let results := i.householdMembers.map fun m =>
    ctcOdcPersonTest
      { householdMember := m, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
        treatFilersAsDependents := i.treatFilersAsDependents
        eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational
        treatAsMfj := i.treatAsMfj }
  { results
    ctcEligibleDependents := (countBy (·.eligibleCtc) results : Nat)
    odcEligibleDependents := (countBy (·.eligibleOdc) results : Nat) }

/-! ### Scope `Schedule8812` -/

/-- Inputs of `Schedule8812`. -/
structure Schedule8812In where
  ctcEligibleDependents : Int
  odcEligibleDependents : Int
  filingStatus : FilingStatus
  agi : Int
  totalTentativeTax : Int
  cdccTotalCredit : Int
  qualifiedSaverCreditAmount : Int
  totalEdc : Int
  employerIncomeSubtotal : Int
  allCombatPay : Int
  socialSecurityTaxesWithheld : Int
  earnedIncomeCredit : Int
  receivedImproperClaims : Bool
  receivedImproperClaimsNotice : Eitc.ImproperClaimsNotice
  improperClaimsNoticeExpired : Bool
  hasFiledCtcOdcSinceNoticeExpired : Bool

/-- Outputs of `Schedule8812`. -/
structure Schedule8812Out where
  hadCtcOdcImproperClaimsBan : Bool
  ctcOdcDisqualifiedForImproperClaims : Bool
  maybeEligibleForCtc : Bool
  maybeEligibleForOdc : Bool
  ctcQualified : Bool
  odcQualified : Bool
  dependentCreditMagi : Int
  totalPotentialCtc : Int
  totalPotentialOdc : Int
  totalPotentialDependentCredits : Int
  dependentCreditPhaseoutThreshold : Int
  dependentCreditMagiAboveThreshold : Int
  roundedDependentCreditMagiAboveThreshold : Int
  dependentCreditPhaseout : Int
  dependentCreditLessPhaseout : Int
  dependentCreditNotFullyPhasedOut : Bool
  sched8812CreditLimit : Int
  totalCtcAndOdc : Int
  maxPotentialOdcAfterPhaseOut : Int
  totalOdc : Int
  totalCtc : Int
  isReceivingCtc : Bool
  isReceivingOdc : Bool
  isReceivingCtcOrOdc : Bool
  remainingCtcAndOdc : Int
  xmlHasRemainingCtcAndOdc : Bool
  totalPotentialActc : Int
  xmlHasPotentialActc : Bool
  remainingPotentialActc : Int
  earnedIncomeWithAllCombatPay : Int
  earnedIncomeAboveActcRefundabilityThreshold : Int
  earnedIncomeExceedsActcRefundabilityThreshold : Bool
  regularMaximumActc : Int
  threeOrMoreCtcEligibleDependents : Bool
  xmlThreeOrMoreCtcEligibleDependents : Bool
  socialSecurityOverEitc : Int
  maximumActc : Int
  additionalCtc : Int
  isReceivingActc : Bool
  ctc8862Required : Bool

/-- Catala `scope Schedule8812`, definition by definition, in the order of the Catala file. -/
def schedule8812 (i : Schedule8812In) : Schedule8812Out :=
  -- IRC 24(g): taxpayers who improperly claimed the credit
  let hadCtcOdcImproperClaimsBan :=
    !i.hasFiledCtcOdcSinceNoticeExpired &&
      (i.receivedImproperClaimsNotice == .twoYears || i.receivedImproperClaimsNotice == .tenYears)
  let ctcOdcDisqualifiedForImproperClaims :=
    i.receivedImproperClaims && !i.hasFiledCtcOdcSinceNoticeExpired &&
      hadCtcOdcImproperClaimsBan && !i.improperClaimsNoticeExpired
  -- Part I, lines 4 to 8
  let maybeEligibleForCtc := decide (i.ctcEligibleDependents > 0)
  let maybeEligibleForOdc := decide (i.odcEligibleDependents > 0)
  let ctcQualified := !ctcOdcDisqualifiedForImproperClaims && maybeEligibleForCtc
  let odcQualified := !ctcOdcDisqualifiedForImproperClaims && maybeEligibleForOdc
  let totalPotentialCtc :=
    roundDollar
      (if ctcOdcDisqualifiedForImproperClaims || !maybeEligibleForCtc then 0
       else mulRate Params.ctcPerQualifyingChild (i.ctcEligibleDependents : Rat))
  let totalPotentialOdc :=
    roundDollar
      (if ctcOdcDisqualifiedForImproperClaims || !maybeEligibleForOdc then 0
       else mulRate Params.odcPerOtherDependent (i.odcEligibleDependents : Rat))
  let totalPotentialDependentCredits := roundDollar (totalPotentialCtc + totalPotentialOdc)
  -- The phase-out, lines 1 to 3 and 9 to 12
  let dependentCreditMagi := roundDollar i.agi
  let dependentCreditPhaseoutThreshold :=
    if i.filingStatus == .marriedFilingJointly then Params.ctcPhaseoutThresholdJoint
    else Params.ctcPhaseoutThresholdOther
  let dependentCreditMagiAboveThreshold :=
    positive (dependentCreditMagi - dependentCreditPhaseoutThreshold)
  let roundedDependentCreditMagiAboveThreshold :=
    roundDollar
      (stepwiseMultiply (dependentCreditMagiAboveThreshold + Params.ctcPhaseoutStep - 1) 1000 1000)
  let dependentCreditPhaseout :=
    roundDollar
      (mulRate roundedDependentCreditMagiAboveThreshold
        (divMoney Params.ctcPhaseoutReductionPerStep Params.ctcPhaseoutStep))
  let dependentCreditLessPhaseout :=
    roundDollar (positive (totalPotentialDependentCredits - dependentCreditPhaseout))
  let dependentCreditNotFullyPhasedOut := decide (dependentCreditLessPhaseout > 0)
  -- Lines 13 and 14: the credit limit (Credit Limit Worksheet A)
  let sched8812CreditLimit :=
    positive (i.totalTentativeTax - (i.cdccTotalCredit + i.qualifiedSaverCreditAmount + i.totalEdc))
  let totalCtcAndOdc := roundDollar (Money.min dependentCreditLessPhaseout sched8812CreditLimit)
  let isReceivingCtcOrOdc := decide (totalCtcAndOdc > 0)
  let maxPotentialOdcAfterPhaseOut := positive (totalPotentialOdc - dependentCreditPhaseout)
  let totalOdc :=
    if totalCtcAndOdc == 0 then 0 else Money.min maxPotentialOdcAfterPhaseOut totalCtcAndOdc
  let totalCtc := if totalCtcAndOdc == 0 then 0 else totalCtcAndOdc - totalOdc
  let isReceivingCtc := decide (totalCtc > 0)
  let isReceivingOdc := decide (totalOdc > 0)
  -- Part II-A
  let remainingCtcAndOdc := roundDollar (positive (dependentCreditLessPhaseout - totalCtcAndOdc))
  let xmlHasRemainingCtcAndOdc := dependentCreditNotFullyPhasedOut && decide (remainingCtcAndOdc > 0)
  let totalPotentialActc :=
    roundDollar
      (if ctcOdcDisqualifiedForImproperClaims || !maybeEligibleForCtc then 0
       else mulRate Params.actcPerQualifyingChildCap (i.ctcEligibleDependents : Rat))
  let xmlHasPotentialActc := xmlHasRemainingCtcAndOdc && decide (totalPotentialActc > 0)
  let remainingPotentialActc := roundDollar (Money.min remainingCtcAndOdc totalPotentialActc)
  let earnedIncomeWithAllCombatPay := roundDollar (i.employerIncomeSubtotal + i.allCombatPay)
  let earnedIncomeAboveActcRefundabilityThreshold :=
    roundDollar (positive (earnedIncomeWithAllCombatPay - Params.actcEarnedIncomeFloor))
  let earnedIncomeExceedsActcRefundabilityThreshold :=
    xmlHasPotentialActc && decide (earnedIncomeAboveActcRefundabilityThreshold > 0)
  let regularMaximumActc :=
    roundDollar (mulRate earnedIncomeAboveActcRefundabilityThreshold Params.actcEarnedIncomeRate)
  let threeOrMoreCtcEligibleDependents :=
    decide (i.ctcEligibleDependents ≥ actcAlternativeMinimumChildren)
  let xmlThreeOrMoreCtcEligibleDependents :=
    xmlHasPotentialActc && threeOrMoreCtcEligibleDependents
  -- Part II-B
  let socialSecurityOverEitc :=
    roundDollar (positive (i.socialSecurityTaxesWithheld - i.earnedIncomeCredit))
  let maximumActc :=
    roundDollar
      (if threeOrMoreCtcEligibleDependents then Money.max regularMaximumActc socialSecurityOverEitc
       else regularMaximumActc)
  -- Part II-C
  let additionalCtc := roundDollar (Money.min remainingPotentialActc maximumActc)
  let isReceivingActc := decide (additionalCtc > 0)
  let ctc8862Required :=
    (isReceivingCtc || isReceivingActc || isReceivingOdc) && i.receivedImproperClaims &&
      !i.hasFiledCtcOdcSinceNoticeExpired &&
      ((hadCtcOdcImproperClaimsBan && i.improperClaimsNoticeExpired) ||
        i.receivedImproperClaimsNotice == .zeroYears)
  { hadCtcOdcImproperClaimsBan, ctcOdcDisqualifiedForImproperClaims, maybeEligibleForCtc
    maybeEligibleForOdc, ctcQualified, odcQualified, dependentCreditMagi, totalPotentialCtc
    totalPotentialOdc, totalPotentialDependentCredits, dependentCreditPhaseoutThreshold
    dependentCreditMagiAboveThreshold, roundedDependentCreditMagiAboveThreshold
    dependentCreditPhaseout, dependentCreditLessPhaseout, dependentCreditNotFullyPhasedOut
    sched8812CreditLimit, totalCtcAndOdc, maxPotentialOdcAfterPhaseOut, totalOdc, totalCtc
    isReceivingCtc, isReceivingOdc, isReceivingCtcOrOdc, remainingCtcAndOdc
    xmlHasRemainingCtcAndOdc, totalPotentialActc, xmlHasPotentialActc, remainingPotentialActc
    earnedIncomeWithAllCombatPay, earnedIncomeAboveActcRefundabilityThreshold
    earnedIncomeExceedsActcRefundabilityThreshold, regularMaximumActc
    threeOrMoreCtcEligibleDependents, xmlThreeOrMoreCtcEligibleDependents
    socialSecurityOverEitc, maximumActc, additionalCtc, isReceivingActc, ctc8862Required }

/-! ### Unit tests: every assertion of `catala/tests/test_ctc_odc.catala_en`

`mkChild` is the Catala helper `MkChild`: the filer's biological son born 2014-05-10, a U.S.
citizen with an SSN whose card has no restriction, who lived with the filer all year, claimed;
the filer was born 1985-06-15 and cannot be claimed by anyone. `mk8812` is `Mk8812`: single,
two CTC children, AGI and line 1z $100,000, tax $13,841. Amounts are cents. -/

private def d (dollars : Int) : Int := dollars * 100

/-- The Catala helper `MkChild`'s overridable fields. -/
structure ChildOpts where
  relationship : QualifyingChild.Relationship := .biologicalChild
  dateOfBirth : Date := ⟨2014, 5, 10⟩
  residencyDuration : QualifyingChild.ResidencyDuration := .allYear
  tinType : TinType := .ssn
  citizen : Bool := true
  usResident : Bool := false
  canadaMexicoResident : Bool := false
  ssnEmploymentValidity : SsnEmploymentValidity := .neither
  tpClaims : Bool := true

/-- `MkChild.household_member`. -/
def mkChild (o : ChildOpts := {}) : HouseholdMember :=
  { member :=
      { person :=
          { QualifyingChild.defaultPerson with
            relationship := o.relationship, dateOfBirth := o.dateOfBirth
            residencyDuration := o.residencyDuration }
        answers :=
          { grossIncome := 0, writableQrSupportTest := true, tinType := o.tinType
            isUsCitizenFullYear := o.citizen, writableUsResident := o.usResident
            writableUsNational := false, writableCanadaMexicoResident := o.canadaMexicoResident
            tpClaims := o.tpClaims }
        split := defaultMember.split }
    ssnEmploymentValidity := o.ssnEmploymentValidity }

/-- `MkChild.result`. -/
def childResult (o : ChildOpts := {}) : CtcOdcPersonTestOut :=
  ctcOdcPersonTest
    { householdMember := mkChild o, minimumFilerDateOfBirth := ⟨1985, 6, 15⟩
      treatFilersAsDependents := false, eitherFilerUsCitizenOrNational := true, treatAsMfj := false }

-- TestPersonCtcChild
#guard (childResult).dependent.qualifyingChild
#guard (childResult).ssnValidForEmployment
#guard (childResult).eligibleCtc
#guard !(childResult).eligibleOdc
-- TestPersonAge17
#guard (childResult { dateOfBirth := ⟨2007, 12, 31⟩ }).dependent.qc.age == 17
#guard (childResult { dateOfBirth := ⟨2007, 12, 31⟩ }).dependent.qualifyingChild
#guard !(childResult { dateOfBirth := ⟨2007, 12, 31⟩ }).eligibleCtc
#guard (childResult { dateOfBirth := ⟨2007, 12, 31⟩ }).eligibleOdc
-- TestPersonAge16
#guard (childResult { dateOfBirth := ⟨2008, 1, 1⟩ }).dependent.qc.age == 16
#guard (childResult { dateOfBirth := ⟨2008, 1, 1⟩ }).eligibleCtc
#guard !(childResult { dateOfBirth := ⟨2008, 1, 1⟩ }).eligibleOdc
-- TestPersonItin
#guard (childResult { tinType := .itin }).dependent.isClaimedDependent
#guard !(childResult { tinType := .itin }).eligibleCtc
#guard (childResult { tinType := .itin }).eligibleOdc
-- TestPersonSsnNotValid
#guard !(childResult { ssnEmploymentValidity := .notValid }).ssnValidForEmployment
#guard !(childResult { ssnEmploymentValidity := .notValid }).eligibleCtc
#guard (childResult { ssnEmploymentValidity := .notValid }).eligibleOdc
-- TestPersonDhsAuthorization
#guard (childResult { ssnEmploymentValidity := .validOnlyWithDhsAuthorizationInEffect }).eligibleCtc
#guard !(childResult { ssnEmploymentValidity := .validOnlyWithDhsAuthorizationExpired }).eligibleCtc
#guard (childResult { ssnEmploymentValidity := .validOnlyWithDhsAuthorizationExpired }).eligibleOdc
-- TestPersonMexicanNephew
private def nephew : ChildOpts :=
  { relationship := .childOfSibling, residencyDuration := .lessThanSixMonths, citizen := false
    canadaMexicoResident := true, tinType := .itin }
#guard (childResult nephew).dependent.qualifyingRelative
#guard (childResult nephew).dependent.citizenOrResidentTest
#guard (childResult nephew).dependent.isClaimedDependent
#guard !(childResult nephew).dependent.citizenOrUsResidentTest
#guard !(childResult nephew).eligibleCtc
#guard !(childResult nephew).eligibleOdc
-- TestPersonNotClaimed
#guard (childResult { tpClaims := false }).dependent.qualifyingChild
#guard !(childResult { tpClaims := false }).eligibleCtc
#guard !(childResult { tpClaims := false }).eligibleOdc
-- TestHouseholdCounts
private def household (ms : List HouseholdMember) (deps : Bool := false) : CtcOdcDependentsOut :=
  ctcOdcDependents
    { householdMembers := ms, minimumFilerDateOfBirth := ⟨1985, 6, 15⟩
      treatFilersAsDependents := deps, eitherFilerUsCitizenOrNational := true, treatAsMfj := false }
private def h1 := household
  [mkChild, mkChild { dateOfBirth := ⟨2020, 2, 29⟩ }, mkChild { dateOfBirth := ⟨2006, 3, 1⟩ },
   mkChild { tinType := .itin }]
#guard h1.ctcEligibleDependents == 2
#guard h1.odcEligibleDependents == 2
-- TestHouseholdFilerIsDependent
#guard (household [mkChild] (deps := true)).ctcEligibleDependents == 0
#guard (household [mkChild] (deps := true)).odcEligibleDependents == 0

/-- The Catala helper `Mk8812`'s overridable fields. -/
structure Opts where
  ctc : Int := 2
  odc : Int := 0
  filingStatus : FilingStatus := .single
  agi : Int := d 100000
  tax : Int := d 13841
  cdcc : Int := 0
  savers : Int := 0
  edc : Int := 0
  earned : Int := d 100000
  combatPay : Int := 0
  ssTaxes : Int := d 7650
  eic : Int := 0
  receivedImproperClaims : Bool := false
  notice : Eitc.ImproperClaimsNotice := .notAnswered
  noticeExpired : Bool := false

/-- `Mk8812.s`. -/
def mk8812 (o : Opts := {}) : Schedule8812Out :=
  schedule8812
    { ctcEligibleDependents := o.ctc, odcEligibleDependents := o.odc
      filingStatus := o.filingStatus, agi := o.agi, totalTentativeTax := o.tax
      cdccTotalCredit := o.cdcc, qualifiedSaverCreditAmount := o.savers, totalEdc := o.edc
      employerIncomeSubtotal := o.earned, allCombatPay := o.combatPay
      socialSecurityTaxesWithheld := o.ssTaxes, earnedIncomeCredit := o.eic
      receivedImproperClaims := o.receivedImproperClaims
      receivedImproperClaimsNotice := o.notice, improperClaimsNoticeExpired := o.noticeExpired
      hasFiledCtcOdcSinceNoticeExpired := false }

-- Test8812TwoKidsSingle100k
#guard (mk8812).totalPotentialCtc == d 4000
#guard (mk8812).totalPotentialDependentCredits == d 4000
#guard (mk8812).dependentCreditPhaseout == 0
#guard (mk8812).sched8812CreditLimit == d 13841
#guard (mk8812).totalCtcAndOdc == d 4000
#guard (mk8812).totalCtc == d 4000
#guard (mk8812).totalOdc == 0
#guard (mk8812).remainingCtcAndOdc == 0
#guard (mk8812).additionalCtc == 0
#guard (mk8812).additionalCtc != d 3400
-- Test8812LimitedByTax
#guard (mk8812 { tax := d 3000 }).sched8812CreditLimit == d 3000
#guard (mk8812 { tax := d 3000 }).totalCtcAndOdc == d 3000
#guard (mk8812 { tax := d 3000 }).remainingCtcAndOdc == d 1000
#guard (mk8812 { tax := d 3000 }).totalPotentialActc == d 3400
#guard (mk8812 { tax := d 3000 }).remainingPotentialActc == d 1000
#guard (mk8812 { tax := d 3000 }).regularMaximumActc == d 14625
#guard (mk8812 { tax := d 3000 }).additionalCtc == d 1000
#guard (mk8812 { tax := d 3000 }).totalCtcAndOdc + (mk8812 { tax := d 3000 }).additionalCtc == d 4000
-- Test8812CreditLimitOtherCredits
private def otherCredits : Opts := { tax := d 5000, cdcc := d 600, savers := d 400, edc := d 1000 }
#guard (mk8812 otherCredits).sched8812CreditLimit == d 3000
#guard (mk8812 otherCredits).totalCtcAndOdc == d 3000
#guard (mk8812 otherCredits).totalCtcAndOdc != d 4000
-- Test8812PhaseoutSingle200001
private def ph1 : Opts := { agi := d 200001, tax := d 40000 }
#guard (mk8812 ph1).dependentCreditPhaseoutThreshold == d 200000
#guard (mk8812 ph1).dependentCreditMagiAboveThreshold == d 1
#guard (mk8812 ph1).roundedDependentCreditMagiAboveThreshold == d 1000
#guard (mk8812 ph1).dependentCreditPhaseout == d 50
#guard (mk8812 ph1).dependentCreditLessPhaseout == d 3950
#guard (mk8812 ph1).totalCtcAndOdc == d 3950
#guard (mk8812 ph1).dependentCreditPhaseout != 0
#guard (mk8812 ph1).totalCtcAndOdc != d 4000
-- Test8812PhaseoutSteps
#guard (mk8812 { agi := d 200000 }).roundedDependentCreditMagiAboveThreshold == 0
#guard (mk8812 { agi := d 200000 }).dependentCreditPhaseout == 0
#guard (mk8812 { agi := d 200425 }).roundedDependentCreditMagiAboveThreshold == d 1000
#guard (mk8812 { agi := d 201000 }).roundedDependentCreditMagiAboveThreshold == d 1000
#guard (mk8812 { agi := d 201000 }).dependentCreditPhaseout == d 50
#guard (mk8812 { agi := d 201025 }).roundedDependentCreditMagiAboveThreshold == d 2000
#guard (mk8812 { agi := d 201025 }).dependentCreditPhaseout == d 100
-- Test8812PhaseoutMfj
#guard (mk8812 { filingStatus := .marriedFilingJointly, agi := d 400000 }).dependentCreditPhaseoutThreshold == d 400000
#guard (mk8812 { filingStatus := .marriedFilingJointly, agi := d 400000 }).dependentCreditPhaseout == 0
#guard (mk8812 { filingStatus := .marriedFilingJointly, agi := d 400000 }).totalCtcAndOdc == d 4000
#guard (mk8812 { filingStatus := .marriedFilingJointly, agi := d 400001 }).dependentCreditPhaseout == d 50
#guard (mk8812 { filingStatus := .marriedFilingJointly, agi := d 400001 }).totalCtcAndOdc == d 3950
private def single400k := mk8812 { agi := d 400000, tax := 0 }
#guard single400k.dependentCreditPhaseout == d 10000
#guard single400k.dependentCreditLessPhaseout == 0
#guard !single400k.dependentCreditNotFullyPhasedOut
#guard single400k.totalCtcAndOdc == 0
#guard single400k.additionalCtc == 0
-- Test8812PhaseoutQss
#guard (mk8812 { filingStatus := .qualifyingSurvivingSpouse, agi := d 250000 }).dependentCreditPhaseoutThreshold
  == d 200000
#guard (mk8812 { filingStatus := .qualifyingSurvivingSpouse, agi := d 250000 }).dependentCreditPhaseout
  == d 2500
-- Test8812OdcReducedFirst
private def odcFirst := mk8812 { ctc := 1, odc := 1, agi := d 210000, tax := d 30000 }
#guard odcFirst.totalPotentialDependentCredits == d 2500
#guard odcFirst.dependentCreditPhaseout == d 500
#guard odcFirst.totalCtcAndOdc == d 2000
#guard odcFirst.totalOdc == 0
#guard odcFirst.totalCtc == d 2000
#guard odcFirst.isReceivingCtc
#guard !odcFirst.isReceivingOdc
-- Test8812OdcOnlyNoActc
private def odcOnly := mk8812 { ctc := 0, odc := 1, tax := d 200 }
#guard odcOnly.totalPotentialOdc == d 500
#guard odcOnly.totalCtcAndOdc == d 200
#guard odcOnly.totalOdc == d 200
#guard odcOnly.remainingCtcAndOdc == d 300
#guard odcOnly.totalPotentialActc == 0
#guard odcOnly.additionalCtc == 0
-- Test8812ActcEarnedIncome
private def e2500 := mk8812 { agi := d 2500, earned := d 2500, tax := 0 }
private def e10000 := mk8812 { agi := d 10000, earned := d 10000, tax := 0 }
#guard e2500.remainingPotentialActc == d 3400
#guard e2500.earnedIncomeAboveActcRefundabilityThreshold == 0
#guard !e2500.earnedIncomeExceedsActcRefundabilityThreshold
#guard e2500.regularMaximumActc == 0
#guard e2500.additionalCtc == 0
#guard e10000.earnedIncomeAboveActcRefundabilityThreshold == d 7500
#guard e10000.regularMaximumActc == d 1125
#guard e10000.additionalCtc == d 1125
#guard e10000.additionalCtc != d 1500
-- Test8812CombatPay
private def combat := mk8812 { agi := d 10000, earned := d 10000, combatPay := d 4000, tax := 0 }
#guard combat.earnedIncomeWithAllCombatPay == d 14000
#guard combat.regularMaximumActc == d 1725
#guard combat.additionalCtc == d 1725
-- Test8812ThreeKidsAlternative
private def three := mk8812 { ctc := 3, agi := d 20000, earned := d 3000, ssTaxes := d 230, tax := 0 }
private def two := mk8812 { agi := d 20000, earned := d 3000, ssTaxes := d 230, tax := 0 }
private def threeEic :=
  mk8812 { ctc := 3, agi := d 20000, earned := d 3000, ssTaxes := d 230, eic := d 200, tax := 0 }
#guard three.regularMaximumActc == d 75
#guard three.threeOrMoreCtcEligibleDependents
#guard three.socialSecurityOverEitc == d 230
#guard three.maximumActc == d 230
#guard three.additionalCtc == d 230
#guard !two.threeOrMoreCtcEligibleDependents
#guard two.maximumActc == d 75
#guard two.additionalCtc == d 75
#guard two.additionalCtc != d 230
#guard threeEic.socialSecurityOverEitc == d 30
#guard threeEic.additionalCtc == d 75
-- Test8812ActcCap
private def cap := mk8812 { ctc := 1, agi := d 40000, earned := d 40000, tax := 0 }
#guard cap.remainingCtcAndOdc == d 2000
#guard cap.totalPotentialActc == d 1700
#guard cap.additionalCtc == d 1700
#guard cap.additionalCtc != d 2000
-- Test8812ImproperClaimsBan
private def ban :=
  mk8812 { odc := 1, tax := 0, receivedImproperClaims := true, notice := .twoYears }
#guard ban.ctcOdcDisqualifiedForImproperClaims
#guard ban.totalPotentialCtc == 0
#guard ban.totalPotentialOdc == 0
#guard ban.totalCtcAndOdc == 0
#guard ban.additionalCtc == 0
#guard !ban.ctc8862Required
-- Test8812ImproperClaimsExpired
private def banExpired :=
  mk8812 { receivedImproperClaims := true, notice := .twoYears, noticeExpired := true }
#guard !banExpired.ctcOdcDisqualifiedForImproperClaims
#guard banExpired.totalCtcAndOdc == d 4000
#guard banExpired.ctc8862Required

end UsTax.CtcOdc
