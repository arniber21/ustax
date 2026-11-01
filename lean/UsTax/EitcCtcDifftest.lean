import UsTax.Filers
import UsTax.Eitc
import UsTax.CtcOdc

/-!
# Difftest scaffolds for the EITC and CTC/ODC modules (issue #46)

Lean ports of the two wrapper scopes of the Catala difftest scaffolds, so that the same
mappings (`difftest/mappings/eitc.mjs`, `ctc_odc_household.mjs`) run on the Lean calculator:

| Catala (`catala/tests/...`)                         | Lean (`UsTax.EitcCtcDifftest`)                      |
|-----------------------------------------------------|-----------------------------------------------------|
| `difftest_eitc.catala_en` `EitcFromFilers`          | `EitcFromFiltersIn` → `EitcFromFiltersOut` (`eitcFromFilers`) |
| `difftest_ctc_odc.catala_en` `CtcOdcFromHousehold`  | `CtcOdcFromHouseholdIn` → `CtcOdcFromHouseholdOut` (`ctcOdcFromHousehold`) |

`EitcFromFilers` runs `Filers.filers` and wires its outputs into `Eitc.earnedIncomeCredit`
as the Catala scaffold does; the figures `Filers` does not supply are inputs.
-/

namespace UsTax.EitcCtcDifftest

open Filers Eitc CtcOdc

/-- Inputs of `EitcFromFilers`: those of `Filers`, then the `EarnedIncomeCredit` inputs
`Filers` does not supply. -/
structure EitcFromFiltersIn extends FilersIn where
  employerIncomeSubtotal : Int
  agi : Int
  taxExemptInterest : Int
  interestIncome : Int
  ordinaryDividends : Int
  capitalGainsOrLosses : Int
  primaryFilerCombatPay : Int
  mfjSpouseCombatPay : Int
  allCombatPay : Int
  combatPayElectionMade : Bool
  combatPayElection : FormW2s.CombatPayElection
  numEitcQualifyingChildren : Int
  numEitcQualifyingChildrenForCalculation : Int
  filersHaveValidSsnsForEitc : Bool
  eitcQcOfAnother : Bool
  eitcQcOfAnotherRequiredToFile : Bool
  eitcQcOfAnotherIsFiling : Bool
  eitcQcOfAnotherIsFilingRefundOnly : Bool
  eitcHadImproperClaims : Bool
  eitcImproperClaimsDueToQc : Bool
  eitcImproperClaimTakenSinceDisallowal : Bool
  eitcReceivedImproperClaimsNotice : ImproperClaimsNotice
  eitcImproperClaimsNoticeExpired : Bool

/-- Outputs of `EitcFromFilers`. -/
structure EitcFromFiltersOut where
  earnedIncomeCredit : Int
  isReceivingEitc : Bool
  eitc8862Required : Bool
  failsEitcQcTest : Bool
  receivingEitcWhileSeparatedCheckbox : Bool
  unsupported : Bool

/-- Catala scope `EitcFromFilers`. -/
def eitcFromFilers (i : EitcFromFiltersIn) : EitcFromFiltersOut :=
  let f := filers i.toFilersIn
  let e := earnedIncomeCredit
    { filingStatus := i.filingStatus, employerIncomeSubtotal := i.employerIncomeSubtotal
      agi := i.agi, taxExemptInterest := i.taxExemptInterest, interestIncome := i.interestIncome
      ordinaryDividends := i.ordinaryDividends, capitalGainsOrLosses := i.capitalGainsOrLosses
      primaryFilerCombatPay := i.primaryFilerCombatPay, mfjSpouseCombatPay := i.mfjSpouseCombatPay
      allCombatPay := i.allCombatPay, combatPayElectionMade := i.combatPayElectionMade
      combatPayElection := i.combatPayElection
      numEitcQualifyingChildren := i.numEitcQualifyingChildren
      numEitcQualifyingChildrenForCalculation := i.numEitcQualifyingChildrenForCalculation
      isMarried := f.isMarried, treatAsMfs := f.treatAsMfs
      specialRuleForSeparatedSpouses := f.specialRuleForSeparatedSpouses
      treatFilersAsDependents := f.treatFilersAsDependents, isMfjDependent := f.isMfjDependent
      filersUsCitizenOrRaAllYear := f.filersUsCitizenOrRaAllYear
      filersHaveValidSsnsForEitc := i.filersHaveValidSsnsForEitc
      primaryFilerAge25OrOlderForEitc := f.primaryFilerAge25OrOlderForEitc
      primaryFilerAge64OrYoungerForEitc := f.primaryFilerAge64OrYoungerForEitc
      secondaryFilerAge25OrOlderForEitc := f.secondaryFilerAge25OrOlderForEitc
      secondaryFilerAge64OrYoungerForEitc := f.secondaryFilerAge64OrYoungerForEitc
      eitcQcOfAnother := i.eitcQcOfAnother
      eitcQcOfAnotherRequiredToFile := i.eitcQcOfAnotherRequiredToFile
      eitcQcOfAnotherIsFiling := i.eitcQcOfAnotherIsFiling
      eitcQcOfAnotherIsFilingRefundOnly := i.eitcQcOfAnotherIsFilingRefundOnly
      eitcHadImproperClaims := i.eitcHadImproperClaims
      eitcImproperClaimsDueToQc := i.eitcImproperClaimsDueToQc
      eitcImproperClaimTakenSinceDisallowal := i.eitcImproperClaimTakenSinceDisallowal
      eitcReceivedImproperClaimsNotice := i.eitcReceivedImproperClaimsNotice
      eitcImproperClaimsNoticeExpired := i.eitcImproperClaimsNoticeExpired }
  { earnedIncomeCredit := e.earnedIncomeCredit, isReceivingEitc := e.isReceivingEitc
    eitc8862Required := e.eitc8862Required, failsEitcQcTest := e.failsEitcQcTest
    receivingEitcWhileSeparatedCheckbox := e.receivingEitcWhileSeparatedCheckbox
    unsupported := e.unsupported }

/-- Inputs of `CtcOdcFromHousehold`. -/
structure CtcOdcFromHouseholdIn where
  householdMembers : List HouseholdMember
  minimumFilerDateOfBirth : Date
  treatFilersAsDependents : Bool
  eitherFilerUsCitizenOrNational : Bool
  treatAsMfj : Bool
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
  receivedImproperClaimsNotice : ImproperClaimsNotice
  improperClaimsNoticeExpired : Bool
  hasFiledCtcOdcSinceNoticeExpired : Bool

/-- Outputs of `CtcOdcFromHousehold`. -/
structure CtcOdcFromHouseholdOut where
  ctcEligibleDependents : Int
  odcEligibleDependents : Int
  totalPotentialCtc : Int
  totalPotentialOdc : Int
  totalCtcAndOdc : Int
  totalPotentialActc : Int
  threeOrMoreCtcEligibleDependents : Bool
  additionalCtc : Int

/-- Catala scope `CtcOdcFromHousehold`. -/
def ctcOdcFromHousehold (i : CtcOdcFromHouseholdIn) : CtcOdcFromHouseholdOut :=
  let h := ctcOdcDependents
    { householdMembers := i.householdMembers, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth
      treatFilersAsDependents := i.treatFilersAsDependents
      eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational
      treatAsMfj := i.treatAsMfj }
  let s := schedule8812
    { ctcEligibleDependents := h.ctcEligibleDependents
      odcEligibleDependents := h.odcEligibleDependents, filingStatus := i.filingStatus
      agi := i.agi, totalTentativeTax := i.totalTentativeTax
      cdccTotalCredit := i.cdccTotalCredit
      qualifiedSaverCreditAmount := i.qualifiedSaverCreditAmount, totalEdc := i.totalEdc
      employerIncomeSubtotal := i.employerIncomeSubtotal, allCombatPay := i.allCombatPay
      socialSecurityTaxesWithheld := i.socialSecurityTaxesWithheld
      earnedIncomeCredit := i.earnedIncomeCredit
      receivedImproperClaims := i.receivedImproperClaims
      receivedImproperClaimsNotice := i.receivedImproperClaimsNotice
      improperClaimsNoticeExpired := i.improperClaimsNoticeExpired
      hasFiledCtcOdcSinceNoticeExpired := i.hasFiledCtcOdcSinceNoticeExpired }
  { ctcEligibleDependents := h.ctcEligibleDependents
    odcEligibleDependents := h.odcEligibleDependents, totalPotentialCtc := s.totalPotentialCtc
    totalPotentialOdc := s.totalPotentialOdc, totalCtcAndOdc := s.totalCtcAndOdc
    totalPotentialActc := s.totalPotentialActc
    threeOrMoreCtcEligibleDependents := s.threeOrMoreCtcEligibleDependents
    additionalCtc := s.additionalCtc }

end UsTax.EitcCtcDifftest
