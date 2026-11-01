import UsTax.KnockoutsIncome
import UsTax.Filers

/-!
# Knockouts B: household, credit and PTC unsupported situations (issues #37, #48)

Lean implementation of `catala/knockouts_household.catala_en` (module `Knockouts_household`,
scope `KnockoutsHousehold`), written by hand from the Catala source under strategy (c) of
`docs/catala-to-lean.md`. The other half of `flow.xml` `/flowIsKnockedOut` (the income, HSA and
process half is `UsTax/KnockoutsIncome.lean`): the household (`filers.xml`,
`familyAndHousehold.xml`, `dependentsBenefitSplit.xml`), credit (`eitc.xml`, `cdcc.xml`,
`saversCredits.xml`) and premium tax credit (`ptc.xml`) members. Each merged module computes its
own `ko_` conditions; this scope takes them as inputs (`in…`), so they are computed once, in the
module that owns the situation, and defines the one household knockout no module owns,
`/knockoutPersonBornAndDiedInTaxYearWithoutTin` (`familyAndHousehold.xml` lines 668 and 715).

| Catala (`Knockouts_household`)          | Lean (`UsTax.KnockoutsHousehold`)                   |
|-----------------------------------------|-----------------------------------------------------|
| struct `MemberVitals`                   | `MemberVitals`                                      |
| `scope KnockoutsHousehold`              | `KnockoutsHouseholdIn` → `KnockoutsHouseholdOut` (`knockoutsHousehold`) |
| input `in_x`, output `ko_x`             | `inX`, `koX` (each `koX` is its input, as the `rule ... consequence fulfilled`) |
| `KI.KnockoutReason`, `KI.KnockoutEntry` | `UsTax.Api.KnockoutReason`, `KnockoutsIncome.KnockoutEntry` |

The tests of `catala/tests/test_knockouts_household.catala_en` (generated there: one case per
knockout on a clean return, plus the three boundary cases of the born-and-died rule) are the
`#guard`s at the end: every row of the table, checked one at a time.
-/

namespace UsTax.KnockoutsHousehold

open Api (KnockoutReason)
open KnockoutsIncome (KnockoutEntry firedOf)

/-- Catala `MemberVitals`: one household member's vital data. -/
structure MemberVitals where
  /-- DF `/familyAndHousehold/*/dateOfBirth`. -/
  dateOfBirth : Date
  /-- DF `/familyAndHousehold/*/deceased`. -/
  deceased : Bool
  /-- DF `/familyAndHousehold/*/hasTinTypeOfNone`. -/
  hasTinTypeNone : Bool
  deriving DecidableEq, Repr

/-- Inputs of `scope KnockoutsHousehold`: the member data, then each module's `ko_` condition. -/
structure KnockoutsHouseholdIn where
  memberVitals : List MemberVitals
  inFlowKnockoutFilerAgeYoungerThan16 : Bool
  inSpouseItemizesKnockout : Bool
  inPrimaryFilerResidencyKnockout : Bool
  inFlowKnockoutHasApplicableRegisteredDomesticPartnership : Bool
  inKnockoutSubjectToCommunityPropertyLaws : Bool
  inKnockoutHohQpHasNoTin : Bool
  inKnockedOutByNonCustodialParentBenefitSplit : Bool
  inKnockedOutByContradictory8832 : Bool
  inSaversCreditKnockouts : Bool
  inFlowKnockoutBenefitsDistribution : Bool
  inKnockoutCdccWorksheetA : Bool
  inFlowKnockoutHouseholdEmployee : Bool
  inDependentTpRequiresAllocations : Bool
  inHasPtcQualifyingPlanAndQsehra : Bool
  inNeedsAllocations : Bool
  inHasEmployerSponsoredPlan : Bool
  inDependentsRequiredToFile : Bool
  inSelfReportedHasMultiple1095As : Bool
  inHasImmigrationStatusNotEligibleForMarketplace : Bool
  inWantsToUseAltCalculations : Bool
  inQualifyingChildTieBreaker : Bool
  inClaimedSpouseCombatPayWithoutMfj : Bool
  inFilingStatusNotEligible : Bool
  inSoleProprietorshipBenefits : Bool
  inBothSpousesDeemedIncome : Bool
  inTpNeedsToAdd1095A : Bool
  inTpNeedsToDelete1095A : Bool
  deriving DecidableEq, Repr

/-- Outputs of `scope KnockoutsHousehold`. -/
structure KnockoutsHouseholdOut where
  koKnockoutPersonBornAndDiedInTaxYearWithoutTin : Bool
  koFlowKnockoutFilerAgeYoungerThan16 : Bool
  koSpouseItemizesKnockout : Bool
  koPrimaryFilerResidencyKnockout : Bool
  koFlowKnockoutHasApplicableRegisteredDomesticPartnership : Bool
  koKnockoutSubjectToCommunityPropertyLaws : Bool
  koKnockoutHohQpHasNoTin : Bool
  koKnockedOutByNonCustodialParentBenefitSplit : Bool
  koKnockedOutByContradictory8832 : Bool
  koSaversCreditKnockouts : Bool
  koFlowKnockoutBenefitsDistribution : Bool
  koKnockoutCdccWorksheetA : Bool
  koFlowKnockoutHouseholdEmployee : Bool
  koDependentTpRequiresAllocations : Bool
  koHasPtcQualifyingPlanAndQsehra : Bool
  koNeedsAllocations : Bool
  koHasEmployerSponsoredPlan : Bool
  koDependentsRequiredToFile : Bool
  koSelfReportedHasMultiple1095As : Bool
  koHasImmigrationStatusNotEligibleForMarketplace : Bool
  koWantsToUseAltCalculations : Bool
  koQualifyingChildTieBreaker : Bool
  koClaimedSpouseCombatPayWithoutMfj : Bool
  koFilingStatusNotEligible : Bool
  koSoleProprietorshipBenefits : Bool
  koBothSpousesDeemedIncome : Bool
  koTpNeedsToAdd1095A : Bool
  koTpNeedsToDelete1095A : Bool
  unsupportedHousehold : Bool
  knockoutTable : List KnockoutEntry
  firedKnockouts : List KnockoutReason

/-- DF `/familyAndHousehold/*/bornAndDiedInTaxYearWithoutTin`, counted: a member born in the tax
year (`Date.get_year of date_of_birth = F.tax_year`), deceased, with no TIN. -/
def bornAndDiedInTaxYearWithoutTin (vitals : List MemberVitals) : Bool :=
  vitals.any fun m => m.dateOfBirth.year == Filers.taxYear && m.deceased && m.hasTinTypeNone

/-- Catala `knockout_table`, in the order of the Catala file. -/
def knockoutTable (i : KnockoutsHouseholdIn) : List KnockoutEntry :=
  [⟨.knockoutPersonBornAndDiedInTaxYearWithoutTin, bornAndDiedInTaxYearWithoutTin i.memberVitals⟩,
   ⟨.flowKnockoutFilerAgeYoungerThan16, i.inFlowKnockoutFilerAgeYoungerThan16⟩,
   ⟨.spouseItemizesKnockout, i.inSpouseItemizesKnockout⟩,
   ⟨.primaryFilerResidencyKnockout, i.inPrimaryFilerResidencyKnockout⟩,
   ⟨.flowKnockoutHasApplicableRegisteredDomesticPartnership,
     i.inFlowKnockoutHasApplicableRegisteredDomesticPartnership⟩,
   ⟨.knockoutSubjectToCommunityPropertyLaws, i.inKnockoutSubjectToCommunityPropertyLaws⟩,
   ⟨.knockoutHohQpHasNoTin, i.inKnockoutHohQpHasNoTin⟩,
   ⟨.knockedOutByNonCustodialParentBenefitSplit, i.inKnockedOutByNonCustodialParentBenefitSplit⟩,
   ⟨.knockedOutByContradictory8832, i.inKnockedOutByContradictory8832⟩,
   ⟨.saversCreditKnockouts, i.inSaversCreditKnockouts⟩,
   ⟨.flowKnockoutBenefitsDistribution, i.inFlowKnockoutBenefitsDistribution⟩,
   ⟨.knockoutCdccWorksheetA, i.inKnockoutCdccWorksheetA⟩,
   ⟨.flowKnockoutHouseholdEmployee, i.inFlowKnockoutHouseholdEmployee⟩,
   ⟨.dependentTpRequiresAllocations, i.inDependentTpRequiresAllocations⟩,
   ⟨.hasPtcQualifyingPlanAndQsehra, i.inHasPtcQualifyingPlanAndQsehra⟩,
   ⟨.needsAllocations, i.inNeedsAllocations⟩,
   ⟨.hasEmployerSponsoredPlan, i.inHasEmployerSponsoredPlan⟩,
   ⟨.dependentsRequiredToFile, i.inDependentsRequiredToFile⟩,
   ⟨.selfReportedHasMultiple1095As, i.inSelfReportedHasMultiple1095As⟩,
   ⟨.hasImmigrationStatusNotEligibleForMarketplace, i.inHasImmigrationStatusNotEligibleForMarketplace⟩,
   ⟨.wantsToUseAltCalculations, i.inWantsToUseAltCalculations⟩,
   ⟨.extraQualifyingChildTieBreaker, i.inQualifyingChildTieBreaker⟩,
   ⟨.extraClaimedSpouseCombatPayWithoutMfj, i.inClaimedSpouseCombatPayWithoutMfj⟩,
   ⟨.extraFilingStatusNotEligible, i.inFilingStatusNotEligible⟩,
   ⟨.extraCdccSoleProprietorshipBenefits, i.inSoleProprietorshipBenefits⟩,
   ⟨.extraCdccBothSpousesDeemedIncome, i.inBothSpousesDeemedIncome⟩,
   ⟨.extraTpNeedsToAdd1095A, i.inTpNeedsToAdd1095A⟩,
   ⟨.extraTpNeedsToDelete1095A, i.inTpNeedsToDelete1095A⟩]

/-- Catala `unsupported_household`: the disjunction of every `ko_` output. -/
def unsupportedHousehold (i : KnockoutsHouseholdIn) : Bool :=
  bornAndDiedInTaxYearWithoutTin i.memberVitals || i.inFlowKnockoutFilerAgeYoungerThan16 ||
    i.inSpouseItemizesKnockout || i.inPrimaryFilerResidencyKnockout ||
    i.inFlowKnockoutHasApplicableRegisteredDomesticPartnership ||
    i.inKnockoutSubjectToCommunityPropertyLaws || i.inKnockoutHohQpHasNoTin ||
    i.inKnockedOutByNonCustodialParentBenefitSplit || i.inKnockedOutByContradictory8832 ||
    i.inSaversCreditKnockouts || i.inFlowKnockoutBenefitsDistribution ||
    i.inKnockoutCdccWorksheetA || i.inFlowKnockoutHouseholdEmployee ||
    i.inDependentTpRequiresAllocations || i.inHasPtcQualifyingPlanAndQsehra ||
    i.inNeedsAllocations || i.inHasEmployerSponsoredPlan || i.inDependentsRequiredToFile ||
    i.inSelfReportedHasMultiple1095As || i.inHasImmigrationStatusNotEligibleForMarketplace ||
    i.inWantsToUseAltCalculations || i.inQualifyingChildTieBreaker ||
    i.inClaimedSpouseCombatPayWithoutMfj || i.inFilingStatusNotEligible ||
    i.inSoleProprietorshipBenefits || i.inBothSpousesDeemedIncome || i.inTpNeedsToAdd1095A ||
    i.inTpNeedsToDelete1095A

/-- Catala `scope KnockoutsHousehold`. -/
def knockoutsHousehold (i : KnockoutsHouseholdIn) : KnockoutsHouseholdOut :=
  { koKnockoutPersonBornAndDiedInTaxYearWithoutTin := bornAndDiedInTaxYearWithoutTin i.memberVitals
    koFlowKnockoutFilerAgeYoungerThan16 := i.inFlowKnockoutFilerAgeYoungerThan16
    koSpouseItemizesKnockout := i.inSpouseItemizesKnockout
    koPrimaryFilerResidencyKnockout := i.inPrimaryFilerResidencyKnockout
    koFlowKnockoutHasApplicableRegisteredDomesticPartnership :=
      i.inFlowKnockoutHasApplicableRegisteredDomesticPartnership
    koKnockoutSubjectToCommunityPropertyLaws := i.inKnockoutSubjectToCommunityPropertyLaws
    koKnockoutHohQpHasNoTin := i.inKnockoutHohQpHasNoTin
    koKnockedOutByNonCustodialParentBenefitSplit := i.inKnockedOutByNonCustodialParentBenefitSplit
    koKnockedOutByContradictory8832 := i.inKnockedOutByContradictory8832
    koSaversCreditKnockouts := i.inSaversCreditKnockouts
    koFlowKnockoutBenefitsDistribution := i.inFlowKnockoutBenefitsDistribution
    koKnockoutCdccWorksheetA := i.inKnockoutCdccWorksheetA
    koFlowKnockoutHouseholdEmployee := i.inFlowKnockoutHouseholdEmployee
    koDependentTpRequiresAllocations := i.inDependentTpRequiresAllocations
    koHasPtcQualifyingPlanAndQsehra := i.inHasPtcQualifyingPlanAndQsehra
    koNeedsAllocations := i.inNeedsAllocations
    koHasEmployerSponsoredPlan := i.inHasEmployerSponsoredPlan
    koDependentsRequiredToFile := i.inDependentsRequiredToFile
    koSelfReportedHasMultiple1095As := i.inSelfReportedHasMultiple1095As
    koHasImmigrationStatusNotEligibleForMarketplace := i.inHasImmigrationStatusNotEligibleForMarketplace
    koWantsToUseAltCalculations := i.inWantsToUseAltCalculations
    koQualifyingChildTieBreaker := i.inQualifyingChildTieBreaker
    koClaimedSpouseCombatPayWithoutMfj := i.inClaimedSpouseCombatPayWithoutMfj
    koFilingStatusNotEligible := i.inFilingStatusNotEligible
    koSoleProprietorshipBenefits := i.inSoleProprietorshipBenefits
    koBothSpousesDeemedIncome := i.inBothSpousesDeemedIncome
    koTpNeedsToAdd1095A := i.inTpNeedsToAdd1095A
    koTpNeedsToDelete1095A := i.inTpNeedsToDelete1095A
    unsupportedHousehold := unsupportedHousehold i
    knockoutTable := knockoutTable i
    firedKnockouts := firedOf (knockoutTable i) }

/-- The combined flag is exactly "some row of the table fired" (both are the same 28 conditions,
in the same order). -/
theorem unsupportedHousehold_eq_any (i : KnockoutsHouseholdIn) :
    unsupportedHousehold i = (knockoutTable i).any (·.fired) := by
  simp only [unsupportedHousehold, knockoutTable, List.any_cons, List.any_nil, Bool.or_false,
    Bool.or_assoc]

/-- Soundness of the reason list: it is empty exactly when the household flag is false. -/
theorem firedKnockouts_eq_nil_iff (i : KnockoutsHouseholdIn) :
    (knockoutsHousehold i).firedKnockouts = [] ↔ (knockoutsHousehold i).unsupportedHousehold = false := by
  simp only [knockoutsHousehold, KnockoutsIncome.firedOf_eq_nil_iff, unsupportedHousehold_eq_any]

/-! ### Unit tests (`catala/tests/test_knockouts_household.catala_en`)

The clean return has no reason; setting the `n`-th input alone fires exactly the `n`-th reason. -/

/-- The clean return: no member data, every condition false. -/
def clean : KnockoutsHouseholdIn :=
  { memberVitals := [], inFlowKnockoutFilerAgeYoungerThan16 := false,
    inSpouseItemizesKnockout := false, inPrimaryFilerResidencyKnockout := false,
    inFlowKnockoutHasApplicableRegisteredDomesticPartnership := false,
    inKnockoutSubjectToCommunityPropertyLaws := false, inKnockoutHohQpHasNoTin := false,
    inKnockedOutByNonCustodialParentBenefitSplit := false, inKnockedOutByContradictory8832 := false,
    inSaversCreditKnockouts := false, inFlowKnockoutBenefitsDistribution := false,
    inKnockoutCdccWorksheetA := false, inFlowKnockoutHouseholdEmployee := false,
    inDependentTpRequiresAllocations := false, inHasPtcQualifyingPlanAndQsehra := false,
    inNeedsAllocations := false, inHasEmployerSponsoredPlan := false,
    inDependentsRequiredToFile := false, inSelfReportedHasMultiple1095As := false,
    inHasImmigrationStatusNotEligibleForMarketplace := false, inWantsToUseAltCalculations := false,
    inQualifyingChildTieBreaker := false, inClaimedSpouseCombatPayWithoutMfj := false,
    inFilingStatusNotEligible := false, inSoleProprietorshipBenefits := false,
    inBothSpousesDeemedIncome := false, inTpNeedsToAdd1095A := false, inTpNeedsToDelete1095A := false }

/-- The clean return with the `n`-th condition (1 to 27, table order after the born-and-died row)
set. -/
def withNth (n : Nat) : KnockoutsHouseholdIn :=
  let s (k : Nat) := n == k
  { clean with
    inFlowKnockoutFilerAgeYoungerThan16 := s 1, inSpouseItemizesKnockout := s 2,
    inPrimaryFilerResidencyKnockout := s 3,
    inFlowKnockoutHasApplicableRegisteredDomesticPartnership := s 4,
    inKnockoutSubjectToCommunityPropertyLaws := s 5, inKnockoutHohQpHasNoTin := s 6,
    inKnockedOutByNonCustodialParentBenefitSplit := s 7, inKnockedOutByContradictory8832 := s 8,
    inSaversCreditKnockouts := s 9, inFlowKnockoutBenefitsDistribution := s 10,
    inKnockoutCdccWorksheetA := s 11, inFlowKnockoutHouseholdEmployee := s 12,
    inDependentTpRequiresAllocations := s 13, inHasPtcQualifyingPlanAndQsehra := s 14,
    inNeedsAllocations := s 15, inHasEmployerSponsoredPlan := s 16,
    inDependentsRequiredToFile := s 17, inSelfReportedHasMultiple1095As := s 18,
    inHasImmigrationStatusNotEligibleForMarketplace := s 19, inWantsToUseAltCalculations := s 20,
    inQualifyingChildTieBreaker := s 21, inClaimedSpouseCombatPayWithoutMfj := s 22,
    inFilingStatusNotEligible := s 23, inSoleProprietorshipBenefits := s 24,
    inBothSpousesDeemedIncome := s 25, inTpNeedsToAdd1095A := s 26, inTpNeedsToDelete1095A := s 27 }

-- TestClean
#guard !(knockoutsHousehold clean).unsupportedHousehold
#guard (knockoutsHousehold clean).firedKnockouts == []
-- one test per knockout: the flag, and exactly that reason
#guard (List.range 27).all fun k =>
  let o := knockoutsHousehold (withNth (k + 1))
  o.unsupportedHousehold && o.firedKnockouts == ((knockoutTable clean).map (·.reason))[k + 1]?.toList
#guard (knockoutTable clean).length == 28

/-- A member born on `dob`, `deceased`, with or without a TIN. -/
private def vitals (dob : Date) (deceased none : Bool) : KnockoutsHouseholdIn :=
  { clean with memberVitals := [{ dateOfBirth := dob, deceased := deceased, hasTinTypeNone := none }] }

-- TestBornAndDiedInTaxYearWithoutTin and its three boundary cases
#guard (knockoutsHousehold (vitals ⟨2024, 3, 1⟩ true true)).firedKnockouts ==
  [.knockoutPersonBornAndDiedInTaxYearWithoutTin]
#guard !(knockoutsHousehold (vitals ⟨2023, 12, 31⟩ true true)).unsupportedHousehold
#guard !(knockoutsHousehold (vitals ⟨2024, 3, 1⟩ false true)).unsupportedHousehold
#guard !(knockoutsHousehold (vitals ⟨2024, 3, 1⟩ true false)).unsupportedHousehold
-- two knockouts: both reasons, in table order
#guard (knockoutsHousehold { clean with inTpNeedsToDelete1095A := true,
                                        inSpouseItemizesKnockout := true }).firedKnockouts ==
  [.spouseItemizesKnockout, .extraTpNeedsToDelete1095A]

end UsTax.KnockoutsHousehold
