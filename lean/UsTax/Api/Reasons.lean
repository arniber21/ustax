import UsTax.Api.Response

/-!
# Knockout reasons of the 422 response (issue #51, #52)

**Generated** by `scripts/gen_lean_api_reasons.py` from `api/knockout-reasons.json`
(itself generated from the Catala `KnockoutReason` enums by `make api-reasons`).
Do not edit by hand. `KnockoutReason` has 104 constructors, one per `reasons[].code`
of the contract, in file order; `ReasonCategory` is the schema's `ReasonCategory`.
`ustax api-reasons` prints the table and `scripts/api_conformance.mjs` compares it with
the JSON file, so a stale file fails `make api-conformance`.
-/

namespace UsTax.Api

/-- `UnsupportedReason.category` (schema `ReasonCategory`). -/
inductive ReasonCategory where
  /-- Wire value `credits`. -/
  | credits
  /-- Wire value `estimated_payments`. -/
  | estimated_payments
  /-- Wire value `filers`. -/
  | filers
  /-- Wire value `health_coverage`. -/
  | health_coverage
  /-- Wire value `household`. -/
  | household
  /-- Wire value `hsa`. -/
  | hsa
  /-- Wire value `income`. -/
  | income
  /-- Wire value `interest`. -/
  | interest
  /-- Wire value `process`. -/
  | process
  /-- Wire value `retirement`. -/
  | retirement
  /-- Wire value `social_security`. -/
  | social_security
  /-- Wire value `state`. -/
  | state
  /-- Wire value `unemployment`. -/
  | unemployment
  /-- Wire value `w2`. -/
  | w2
  deriving DecidableEq, Repr, Inhabited

/-- The wire spelling of a category. -/
def ReasonCategory.name : ReasonCategory → String
  | .credits => "credits"
  | .estimated_payments => "estimated_payments"
  | .filers => "filers"
  | .health_coverage => "health_coverage"
  | .household => "household"
  | .hsa => "hsa"
  | .income => "income"
  | .interest => "interest"
  | .process => "process"
  | .retirement => "retirement"
  | .social_security => "social_security"
  | .state => "state"
  | .unemployment => "unemployment"
  | .w2 => "w2"

/-- `UnsupportedReason.code`: the Catala `KnockoutReason` constructor names. -/
inductive KnockoutReason where
  /-- Code `HasRequiredFactaFilings`. -/
  | hasRequiredFactaFilings
  /-- Code `FlowKnockoutHasEarlyWithdrawlPenalty`. -/
  | flowKnockoutHasEarlyWithdrawlPenalty
  /-- Code `FlowKnockoutHasBonds`. -/
  | flowKnockoutHasBonds
  /-- Code `FlowKnockoutHasForeignTaxPaid`. -/
  | flowKnockoutHasForeignTaxPaid
  /-- Code `FlowKnockoutWithholdingUnsupportedState`. -/
  | flowKnockoutWithholdingUnsupportedState
  /-- Code `FlowKnockoutStateTaxWithheld`. -/
  | flowKnockoutStateTaxWithheld
  /-- Code `HasInterestIncomeAndAgiAboveThresholdForMfs`. -/
  | hasInterestIncomeAndAgiAboveThresholdForMfs
  /-- Code `HasInterestIncomeAndAgiAboveThresholdForMfjOrQss`. -/
  | hasInterestIncomeAndAgiAboveThresholdForMfjOrQss
  /-- Code `HasInterestIncomeAndAgiAboveThresholdForSingleOrHoh`. -/
  | hasInterestIncomeAndAgiAboveThresholdForSingleOrHoh
  /-- Code `FlowKnockoutTaxExemptInterest`. -/
  | flowKnockoutTaxExemptInterest
  /-- Code `KnockoutForBox12Value`. -/
  | knockoutForBox12Value
  /-- Code `KnockoutForBox12Dependency`. -/
  | knockoutForBox12Dependency
  /-- Code `FlowKnockoutAllocatedTips`. -/
  | flowKnockoutAllocatedTips
  /-- Code `FlowKnockoutStatutoryEmployee`. -/
  | flowKnockoutStatutoryEmployee
  /-- Code `FlowKnockoutThirdPartySickPay`. -/
  | flowKnockoutThirdPartySickPay
  /-- Code `FlowKnockoutNonQualifiedPlans`. -/
  | flowKnockoutNonQualifiedPlans
  /-- Code `KnockoutMedicareWages`. -/
  | knockoutMedicareWages
  /-- Code `AnyFilerExceedsMaxOasdiWages`. -/
  | anyFilerExceedsMaxOasdiWages
  /-- Code `FlowKnockout1099GRepayTooHigh`. -/
  | flowKnockout1099GRepayTooHigh
  /-- Code `FlowKnockoutUnemploymentCompensationUnsupportedState`. -/
  | flowKnockoutUnemploymentCompensationUnsupportedState
  /-- Code `ExtraNonPfd1099Misc`. -/
  | extraNonPfd1099Misc
  /-- Code `FlowKnockoutRetirementTaxableAmountNotDetermined`. -/
  | flowKnockoutRetirementTaxableAmountNotDetermined
  /-- Code `FlowKnockoutRetirementTaxableAmountBlank`. -/
  | flowKnockoutRetirementTaxableAmountBlank
  /-- Code `FlowKnockoutRetirementTotalDistribution`. -/
  | flowKnockoutRetirementTotalDistribution
  /-- Code `KnockoutForForm1099RBox8Value`. -/
  | knockoutForForm1099RBox8Value
  /-- Code `KnockoutForForm1099RBox8Percentage`. -/
  | knockoutForForm1099RBox8Percentage
  /-- Code `KnockoutForForm1099RBox9aPercentage`. -/
  | knockoutForForm1099RBox9aPercentage
  /-- Code `FlowKnockoutRetirementCapitalGain`. -/
  | flowKnockoutRetirementCapitalGain
  /-- Code `FlowKnockoutRetirementNetUnrealizedAppreciation`. -/
  | flowKnockoutRetirementNetUnrealizedAppreciation
  /-- Code `FlowKnockoutRetirementAmountAllocableToIRR`. -/
  | flowKnockoutRetirementAmountAllocableToIRR
  /-- Code `FlowKnockoutRetirementFactaFilingRequirement`. -/
  | flowKnockoutRetirementFactaFilingRequirement
  /-- Code `FlowKnockoutForRollover`. -/
  | flowKnockoutForRollover
  /-- Code `FlowKnockoutForDeathBenefitPaymentDate`. -/
  | flowKnockoutForDeathBenefitPaymentDate
  /-- Code `FlowKnockoutRetirementQualifiedDisasterDistribution`. -/
  | flowKnockoutRetirementQualifiedDisasterDistribution
  /-- Code `FlowKnockoutRetirementPublicSafetyOfficer`. -/
  | flowKnockoutRetirementPublicSafetyOfficer
  /-- Code `FlowKnockoutForPreTaxToPostTaxRollover`. -/
  | flowKnockoutForPreTaxToPostTaxRollover
  /-- Code `FlowKnockoutBox15`. -/
  | flowKnockoutBox15
  /-- Code `KnockoutForForm1099RDistributionCode`. -/
  | knockoutForForm1099RDistributionCode
  /-- Code `KnockoutIraSepSimple`. -/
  | knockoutIraSepSimple
  /-- Code `KnockoutTaxablePensionRollover`. -/
  | knockoutTaxablePensionRollover
  /-- Code `KnockoutIndirectRollover`. -/
  | knockoutIndirectRollover
  /-- Code `KnockoutTaxableAmountNotDetermined`. -/
  | knockoutTaxableAmountNotDetermined
  /-- Code `SocialSecurityBenefitsAreLossGreaterThan3k`. -/
  | socialSecurityBenefitsAreLossGreaterThan3k
  /-- Code `KnockoutPaidEstimatedTaxesUnderDifferentLastName`. -/
  | knockoutPaidEstimatedTaxesUnderDifferentLastName
  /-- Code `KnockoutNoPaymentsHsaDistribution`. -/
  | knockoutNoPaymentsHsaDistribution
  /-- Code `FlowKnockoutHsaMedicalSavingsAccountType`. -/
  | flowKnockoutHsaMedicalSavingsAccountType
  /-- Code `FlowKnockoutHsaDistributionCode`. -/
  | flowKnockoutHsaDistributionCode
  /-- Code `FlowKnockoutOtherCoveragePartOfYear`. -/
  | flowKnockoutOtherCoveragePartOfYear
  /-- Code `FlowKnockoutOtherCoverageWholeYear`. -/
  | flowKnockoutOtherCoverageWholeYear
  /-- Code `FlowKnockoutEarningsOnExcessContributions`. -/
  | flowKnockoutEarningsOnExcessContributions
  /-- Code `FlowKnockoutHsaTestingPeriodAdditionalIncomeYes`. -/
  | flowKnockoutHsaTestingPeriodAdditionalIncomeYes
  /-- Code `FlowKnockoutHsaUnqualifiedDistributions`. -/
  | flowKnockoutHsaUnqualifiedDistributions
  /-- Code `FlowKnockoutHsaDistributionFMV`. -/
  | flowKnockoutHsaDistributionFMV
  /-- Code `FlowKnockoutMaritalChangeAffectsContributionLimit`. -/
  | flowKnockoutMaritalChangeAffectsContributionLimit
  /-- Code `FlowKnockoutMFSLine6Check`. -/
  | flowKnockoutMFSLine6Check
  /-- Code `FlowHsaContributionsOverLimitKnockout`. -/
  | flowHsaContributionsOverLimitKnockout
  /-- Code `FlowKnockoutHsaExcessContributions`. -/
  | flowKnockoutHsaExcessContributions
  /-- Code `FlowKnockoutContributionSummaryNoneAllowed`. -/
  | flowKnockoutContributionSummaryNoneAllowed
  /-- Code `FlowKnockoutHdhpCoverageStatusNotNeeded`. -/
  | flowKnockoutHdhpCoverageStatusNotNeeded
  /-- Code `FlowKnockoutNotEnrolledInHdhp`. -/
  | flowKnockoutNotEnrolledInHdhp
  /-- Code `FlowKnockoutMadeQualifiedHsaFundingDistribution`. -/
  | flowKnockoutMadeQualifiedHsaFundingDistribution
  /-- Code `FlowKnockoutHsaCoverage`. -/
  | flowKnockoutHsaCoverage
  /-- Code `FlowKnockoutFilerIsDependentAndContributesToHsa`. -/
  | flowKnockoutFilerIsDependentAndContributesToHsa
  /-- Code `ExtraHsaDistributionsWithoutActivity`. -/
  | extraHsaDistributionsWithoutActivity
  /-- Code `ExtraHsaDistributionsSecondaryFilerWithoutMfj`. -/
  | extraHsaDistributionsSecondaryFilerWithoutMfj
  /-- Code `IncomeSourcesNotSupported`. -/
  | incomeSourcesNotSupported
  /-- Code `NotDigitalAssets`. -/
  | notDigitalAssets
  /-- Code `HasForeignAccountsOrTrusts`. -/
  | hasForeignAccountsOrTrusts
  /-- Code `MadeIraContributions`. -/
  | madeIraContributions
  /-- Code `FlowKnockoutBox15IncomeFromDifferentState`. -/
  | flowKnockoutBox15IncomeFromDifferentState
  /-- Code `HasABox14NYRRTAValueWeKnockout`. -/
  | hasABox14NYRRTAValueWeKnockout
  /-- Code `FlowKnockoutHasRRTACodesInBox14NotInNY`. -/
  | flowKnockoutHasRRTACodesInBox14NotInNY
  /-- Code `KnockoutYonkersPartYear`. -/
  | knockoutYonkersPartYear
  /-- Code `FlowKnockoutUnsupportedState`. -/
  | flowKnockoutUnsupportedState
  /-- Code `IsTooLateToFileOrResubmit`. -/
  | isTooLateToFileOrResubmit
  /-- Code `KnockoutHasNoPaymentsOrCredits`. -/
  | knockoutHasNoPaymentsOrCredits
  /-- Code `FlowKnockoutFilerAgeYoungerThan16`. -/
  | flowKnockoutFilerAgeYoungerThan16
  /-- Code `SpouseItemizesKnockout`. -/
  | spouseItemizesKnockout
  /-- Code `PrimaryFilerResidencyKnockout`. -/
  | primaryFilerResidencyKnockout
  /-- Code `FlowKnockoutHasApplicableRegisteredDomesticPartnership`. -/
  | flowKnockoutHasApplicableRegisteredDomesticPartnership
  /-- Code `KnockoutSubjectToCommunityPropertyLaws`. -/
  | knockoutSubjectToCommunityPropertyLaws
  /-- Code `KnockoutHohQpHasNoTin`. -/
  | knockoutHohQpHasNoTin
  /-- Code `KnockedOutByNonCustodialParentBenefitSplit`. -/
  | knockedOutByNonCustodialParentBenefitSplit
  /-- Code `KnockedOutByContradictory8832`. -/
  | knockedOutByContradictory8832
  /-- Code `SaversCreditKnockouts`. -/
  | saversCreditKnockouts
  /-- Code `FlowKnockoutBenefitsDistribution`. -/
  | flowKnockoutBenefitsDistribution
  /-- Code `KnockoutCdccWorksheetA`. -/
  | knockoutCdccWorksheetA
  /-- Code `FlowKnockoutHouseholdEmployee`. -/
  | flowKnockoutHouseholdEmployee
  /-- Code `DependentTpRequiresAllocations`. -/
  | dependentTpRequiresAllocations
  /-- Code `HasPtcQualifyingPlanAndQsehra`. -/
  | hasPtcQualifyingPlanAndQsehra
  /-- Code `NeedsAllocations`. -/
  | needsAllocations
  /-- Code `HasEmployerSponsoredPlan`. -/
  | hasEmployerSponsoredPlan
  /-- Code `DependentsRequiredToFile`. -/
  | dependentsRequiredToFile
  /-- Code `SelfReportedHasMultiple1095As`. -/
  | selfReportedHasMultiple1095As
  /-- Code `HasImmigrationStatusNotEligibleForMarketplace`. -/
  | hasImmigrationStatusNotEligibleForMarketplace
  /-- Code `WantsToUseAltCalculations`. -/
  | wantsToUseAltCalculations
  /-- Code `ExtraQualifyingChildTieBreaker`. -/
  | extraQualifyingChildTieBreaker
  /-- Code `ExtraClaimedSpouseCombatPayWithoutMfj`. -/
  | extraClaimedSpouseCombatPayWithoutMfj
  /-- Code `ExtraFilingStatusNotEligible`. -/
  | extraFilingStatusNotEligible
  /-- Code `ExtraCdccSoleProprietorshipBenefits`. -/
  | extraCdccSoleProprietorshipBenefits
  /-- Code `ExtraCdccBothSpousesDeemedIncome`. -/
  | extraCdccBothSpousesDeemedIncome
  /-- Code `ExtraTpNeedsToAdd1095A`. -/
  | extraTpNeedsToAdd1095A
  /-- Code `ExtraTpNeedsToDelete1095A`. -/
  | extraTpNeedsToDelete1095A
  /-- Code `KnockoutPersonBornAndDiedInTaxYearWithoutTin`. -/
  | knockoutPersonBornAndDiedInTaxYearWithoutTin
  deriving DecidableEq, Repr, Inhabited

/-- Every reason, in `api/knockout-reasons.json` order. -/
def KnockoutReason.all : List KnockoutReason :=
  [.hasRequiredFactaFilings,
   .flowKnockoutHasEarlyWithdrawlPenalty,
   .flowKnockoutHasBonds,
   .flowKnockoutHasForeignTaxPaid,
   .flowKnockoutWithholdingUnsupportedState,
   .flowKnockoutStateTaxWithheld,
   .hasInterestIncomeAndAgiAboveThresholdForMfs,
   .hasInterestIncomeAndAgiAboveThresholdForMfjOrQss,
   .hasInterestIncomeAndAgiAboveThresholdForSingleOrHoh,
   .flowKnockoutTaxExemptInterest,
   .knockoutForBox12Value,
   .knockoutForBox12Dependency,
   .flowKnockoutAllocatedTips,
   .flowKnockoutStatutoryEmployee,
   .flowKnockoutThirdPartySickPay,
   .flowKnockoutNonQualifiedPlans,
   .knockoutMedicareWages,
   .anyFilerExceedsMaxOasdiWages,
   .flowKnockout1099GRepayTooHigh,
   .flowKnockoutUnemploymentCompensationUnsupportedState,
   .extraNonPfd1099Misc,
   .flowKnockoutRetirementTaxableAmountNotDetermined,
   .flowKnockoutRetirementTaxableAmountBlank,
   .flowKnockoutRetirementTotalDistribution,
   .knockoutForForm1099RBox8Value,
   .knockoutForForm1099RBox8Percentage,
   .knockoutForForm1099RBox9aPercentage,
   .flowKnockoutRetirementCapitalGain,
   .flowKnockoutRetirementNetUnrealizedAppreciation,
   .flowKnockoutRetirementAmountAllocableToIRR,
   .flowKnockoutRetirementFactaFilingRequirement,
   .flowKnockoutForRollover,
   .flowKnockoutForDeathBenefitPaymentDate,
   .flowKnockoutRetirementQualifiedDisasterDistribution,
   .flowKnockoutRetirementPublicSafetyOfficer,
   .flowKnockoutForPreTaxToPostTaxRollover,
   .flowKnockoutBox15,
   .knockoutForForm1099RDistributionCode,
   .knockoutIraSepSimple,
   .knockoutTaxablePensionRollover,
   .knockoutIndirectRollover,
   .knockoutTaxableAmountNotDetermined,
   .socialSecurityBenefitsAreLossGreaterThan3k,
   .knockoutPaidEstimatedTaxesUnderDifferentLastName,
   .knockoutNoPaymentsHsaDistribution,
   .flowKnockoutHsaMedicalSavingsAccountType,
   .flowKnockoutHsaDistributionCode,
   .flowKnockoutOtherCoveragePartOfYear,
   .flowKnockoutOtherCoverageWholeYear,
   .flowKnockoutEarningsOnExcessContributions,
   .flowKnockoutHsaTestingPeriodAdditionalIncomeYes,
   .flowKnockoutHsaUnqualifiedDistributions,
   .flowKnockoutHsaDistributionFMV,
   .flowKnockoutMaritalChangeAffectsContributionLimit,
   .flowKnockoutMFSLine6Check,
   .flowHsaContributionsOverLimitKnockout,
   .flowKnockoutHsaExcessContributions,
   .flowKnockoutContributionSummaryNoneAllowed,
   .flowKnockoutHdhpCoverageStatusNotNeeded,
   .flowKnockoutNotEnrolledInHdhp,
   .flowKnockoutMadeQualifiedHsaFundingDistribution,
   .flowKnockoutHsaCoverage,
   .flowKnockoutFilerIsDependentAndContributesToHsa,
   .extraHsaDistributionsWithoutActivity,
   .extraHsaDistributionsSecondaryFilerWithoutMfj,
   .incomeSourcesNotSupported,
   .notDigitalAssets,
   .hasForeignAccountsOrTrusts,
   .madeIraContributions,
   .flowKnockoutBox15IncomeFromDifferentState,
   .hasABox14NYRRTAValueWeKnockout,
   .flowKnockoutHasRRTACodesInBox14NotInNY,
   .knockoutYonkersPartYear,
   .flowKnockoutUnsupportedState,
   .isTooLateToFileOrResubmit,
   .knockoutHasNoPaymentsOrCredits,
   .flowKnockoutFilerAgeYoungerThan16,
   .spouseItemizesKnockout,
   .primaryFilerResidencyKnockout,
   .flowKnockoutHasApplicableRegisteredDomesticPartnership,
   .knockoutSubjectToCommunityPropertyLaws,
   .knockoutHohQpHasNoTin,
   .knockedOutByNonCustodialParentBenefitSplit,
   .knockedOutByContradictory8832,
   .saversCreditKnockouts,
   .flowKnockoutBenefitsDistribution,
   .knockoutCdccWorksheetA,
   .flowKnockoutHouseholdEmployee,
   .dependentTpRequiresAllocations,
   .hasPtcQualifyingPlanAndQsehra,
   .needsAllocations,
   .hasEmployerSponsoredPlan,
   .dependentsRequiredToFile,
   .selfReportedHasMultiple1095As,
   .hasImmigrationStatusNotEligibleForMarketplace,
   .wantsToUseAltCalculations,
   .extraQualifyingChildTieBreaker,
   .extraClaimedSpouseCombatPayWithoutMfj,
   .extraFilingStatusNotEligible,
   .extraCdccSoleProprietorshipBenefits,
   .extraCdccBothSpousesDeemedIncome,
   .extraTpNeedsToAdd1095A,
   .extraTpNeedsToDelete1095A,
   .knockoutPersonBornAndDiedInTaxYearWithoutTin]

/-- The wire code (the Catala constructor name). -/
def KnockoutReason.code : KnockoutReason → String
  | .hasRequiredFactaFilings => "HasRequiredFactaFilings"
  | .flowKnockoutHasEarlyWithdrawlPenalty => "FlowKnockoutHasEarlyWithdrawlPenalty"
  | .flowKnockoutHasBonds => "FlowKnockoutHasBonds"
  | .flowKnockoutHasForeignTaxPaid => "FlowKnockoutHasForeignTaxPaid"
  | .flowKnockoutWithholdingUnsupportedState => "FlowKnockoutWithholdingUnsupportedState"
  | .flowKnockoutStateTaxWithheld => "FlowKnockoutStateTaxWithheld"
  | .hasInterestIncomeAndAgiAboveThresholdForMfs => "HasInterestIncomeAndAgiAboveThresholdForMfs"
  | .hasInterestIncomeAndAgiAboveThresholdForMfjOrQss => "HasInterestIncomeAndAgiAboveThresholdForMfjOrQss"
  | .hasInterestIncomeAndAgiAboveThresholdForSingleOrHoh => "HasInterestIncomeAndAgiAboveThresholdForSingleOrHoh"
  | .flowKnockoutTaxExemptInterest => "FlowKnockoutTaxExemptInterest"
  | .knockoutForBox12Value => "KnockoutForBox12Value"
  | .knockoutForBox12Dependency => "KnockoutForBox12Dependency"
  | .flowKnockoutAllocatedTips => "FlowKnockoutAllocatedTips"
  | .flowKnockoutStatutoryEmployee => "FlowKnockoutStatutoryEmployee"
  | .flowKnockoutThirdPartySickPay => "FlowKnockoutThirdPartySickPay"
  | .flowKnockoutNonQualifiedPlans => "FlowKnockoutNonQualifiedPlans"
  | .knockoutMedicareWages => "KnockoutMedicareWages"
  | .anyFilerExceedsMaxOasdiWages => "AnyFilerExceedsMaxOasdiWages"
  | .flowKnockout1099GRepayTooHigh => "FlowKnockout1099GRepayTooHigh"
  | .flowKnockoutUnemploymentCompensationUnsupportedState => "FlowKnockoutUnemploymentCompensationUnsupportedState"
  | .extraNonPfd1099Misc => "ExtraNonPfd1099Misc"
  | .flowKnockoutRetirementTaxableAmountNotDetermined => "FlowKnockoutRetirementTaxableAmountNotDetermined"
  | .flowKnockoutRetirementTaxableAmountBlank => "FlowKnockoutRetirementTaxableAmountBlank"
  | .flowKnockoutRetirementTotalDistribution => "FlowKnockoutRetirementTotalDistribution"
  | .knockoutForForm1099RBox8Value => "KnockoutForForm1099RBox8Value"
  | .knockoutForForm1099RBox8Percentage => "KnockoutForForm1099RBox8Percentage"
  | .knockoutForForm1099RBox9aPercentage => "KnockoutForForm1099RBox9aPercentage"
  | .flowKnockoutRetirementCapitalGain => "FlowKnockoutRetirementCapitalGain"
  | .flowKnockoutRetirementNetUnrealizedAppreciation => "FlowKnockoutRetirementNetUnrealizedAppreciation"
  | .flowKnockoutRetirementAmountAllocableToIRR => "FlowKnockoutRetirementAmountAllocableToIRR"
  | .flowKnockoutRetirementFactaFilingRequirement => "FlowKnockoutRetirementFactaFilingRequirement"
  | .flowKnockoutForRollover => "FlowKnockoutForRollover"
  | .flowKnockoutForDeathBenefitPaymentDate => "FlowKnockoutForDeathBenefitPaymentDate"
  | .flowKnockoutRetirementQualifiedDisasterDistribution => "FlowKnockoutRetirementQualifiedDisasterDistribution"
  | .flowKnockoutRetirementPublicSafetyOfficer => "FlowKnockoutRetirementPublicSafetyOfficer"
  | .flowKnockoutForPreTaxToPostTaxRollover => "FlowKnockoutForPreTaxToPostTaxRollover"
  | .flowKnockoutBox15 => "FlowKnockoutBox15"
  | .knockoutForForm1099RDistributionCode => "KnockoutForForm1099RDistributionCode"
  | .knockoutIraSepSimple => "KnockoutIraSepSimple"
  | .knockoutTaxablePensionRollover => "KnockoutTaxablePensionRollover"
  | .knockoutIndirectRollover => "KnockoutIndirectRollover"
  | .knockoutTaxableAmountNotDetermined => "KnockoutTaxableAmountNotDetermined"
  | .socialSecurityBenefitsAreLossGreaterThan3k => "SocialSecurityBenefitsAreLossGreaterThan3k"
  | .knockoutPaidEstimatedTaxesUnderDifferentLastName => "KnockoutPaidEstimatedTaxesUnderDifferentLastName"
  | .knockoutNoPaymentsHsaDistribution => "KnockoutNoPaymentsHsaDistribution"
  | .flowKnockoutHsaMedicalSavingsAccountType => "FlowKnockoutHsaMedicalSavingsAccountType"
  | .flowKnockoutHsaDistributionCode => "FlowKnockoutHsaDistributionCode"
  | .flowKnockoutOtherCoveragePartOfYear => "FlowKnockoutOtherCoveragePartOfYear"
  | .flowKnockoutOtherCoverageWholeYear => "FlowKnockoutOtherCoverageWholeYear"
  | .flowKnockoutEarningsOnExcessContributions => "FlowKnockoutEarningsOnExcessContributions"
  | .flowKnockoutHsaTestingPeriodAdditionalIncomeYes => "FlowKnockoutHsaTestingPeriodAdditionalIncomeYes"
  | .flowKnockoutHsaUnqualifiedDistributions => "FlowKnockoutHsaUnqualifiedDistributions"
  | .flowKnockoutHsaDistributionFMV => "FlowKnockoutHsaDistributionFMV"
  | .flowKnockoutMaritalChangeAffectsContributionLimit => "FlowKnockoutMaritalChangeAffectsContributionLimit"
  | .flowKnockoutMFSLine6Check => "FlowKnockoutMFSLine6Check"
  | .flowHsaContributionsOverLimitKnockout => "FlowHsaContributionsOverLimitKnockout"
  | .flowKnockoutHsaExcessContributions => "FlowKnockoutHsaExcessContributions"
  | .flowKnockoutContributionSummaryNoneAllowed => "FlowKnockoutContributionSummaryNoneAllowed"
  | .flowKnockoutHdhpCoverageStatusNotNeeded => "FlowKnockoutHdhpCoverageStatusNotNeeded"
  | .flowKnockoutNotEnrolledInHdhp => "FlowKnockoutNotEnrolledInHdhp"
  | .flowKnockoutMadeQualifiedHsaFundingDistribution => "FlowKnockoutMadeQualifiedHsaFundingDistribution"
  | .flowKnockoutHsaCoverage => "FlowKnockoutHsaCoverage"
  | .flowKnockoutFilerIsDependentAndContributesToHsa => "FlowKnockoutFilerIsDependentAndContributesToHsa"
  | .extraHsaDistributionsWithoutActivity => "ExtraHsaDistributionsWithoutActivity"
  | .extraHsaDistributionsSecondaryFilerWithoutMfj => "ExtraHsaDistributionsSecondaryFilerWithoutMfj"
  | .incomeSourcesNotSupported => "IncomeSourcesNotSupported"
  | .notDigitalAssets => "NotDigitalAssets"
  | .hasForeignAccountsOrTrusts => "HasForeignAccountsOrTrusts"
  | .madeIraContributions => "MadeIraContributions"
  | .flowKnockoutBox15IncomeFromDifferentState => "FlowKnockoutBox15IncomeFromDifferentState"
  | .hasABox14NYRRTAValueWeKnockout => "HasABox14NYRRTAValueWeKnockout"
  | .flowKnockoutHasRRTACodesInBox14NotInNY => "FlowKnockoutHasRRTACodesInBox14NotInNY"
  | .knockoutYonkersPartYear => "KnockoutYonkersPartYear"
  | .flowKnockoutUnsupportedState => "FlowKnockoutUnsupportedState"
  | .isTooLateToFileOrResubmit => "IsTooLateToFileOrResubmit"
  | .knockoutHasNoPaymentsOrCredits => "KnockoutHasNoPaymentsOrCredits"
  | .flowKnockoutFilerAgeYoungerThan16 => "FlowKnockoutFilerAgeYoungerThan16"
  | .spouseItemizesKnockout => "SpouseItemizesKnockout"
  | .primaryFilerResidencyKnockout => "PrimaryFilerResidencyKnockout"
  | .flowKnockoutHasApplicableRegisteredDomesticPartnership => "FlowKnockoutHasApplicableRegisteredDomesticPartnership"
  | .knockoutSubjectToCommunityPropertyLaws => "KnockoutSubjectToCommunityPropertyLaws"
  | .knockoutHohQpHasNoTin => "KnockoutHohQpHasNoTin"
  | .knockedOutByNonCustodialParentBenefitSplit => "KnockedOutByNonCustodialParentBenefitSplit"
  | .knockedOutByContradictory8832 => "KnockedOutByContradictory8832"
  | .saversCreditKnockouts => "SaversCreditKnockouts"
  | .flowKnockoutBenefitsDistribution => "FlowKnockoutBenefitsDistribution"
  | .knockoutCdccWorksheetA => "KnockoutCdccWorksheetA"
  | .flowKnockoutHouseholdEmployee => "FlowKnockoutHouseholdEmployee"
  | .dependentTpRequiresAllocations => "DependentTpRequiresAllocations"
  | .hasPtcQualifyingPlanAndQsehra => "HasPtcQualifyingPlanAndQsehra"
  | .needsAllocations => "NeedsAllocations"
  | .hasEmployerSponsoredPlan => "HasEmployerSponsoredPlan"
  | .dependentsRequiredToFile => "DependentsRequiredToFile"
  | .selfReportedHasMultiple1095As => "SelfReportedHasMultiple1095As"
  | .hasImmigrationStatusNotEligibleForMarketplace => "HasImmigrationStatusNotEligibleForMarketplace"
  | .wantsToUseAltCalculations => "WantsToUseAltCalculations"
  | .extraQualifyingChildTieBreaker => "ExtraQualifyingChildTieBreaker"
  | .extraClaimedSpouseCombatPayWithoutMfj => "ExtraClaimedSpouseCombatPayWithoutMfj"
  | .extraFilingStatusNotEligible => "ExtraFilingStatusNotEligible"
  | .extraCdccSoleProprietorshipBenefits => "ExtraCdccSoleProprietorshipBenefits"
  | .extraCdccBothSpousesDeemedIncome => "ExtraCdccBothSpousesDeemedIncome"
  | .extraTpNeedsToAdd1095A => "ExtraTpNeedsToAdd1095A"
  | .extraTpNeedsToDelete1095A => "ExtraTpNeedsToDelete1095A"
  | .knockoutPersonBornAndDiedInTaxYearWithoutTin => "KnockoutPersonBornAndDiedInTaxYearWithoutTin"

/-- The category. -/
def KnockoutReason.category : KnockoutReason → ReasonCategory
  | .hasRequiredFactaFilings => .interest
  | .flowKnockoutHasEarlyWithdrawlPenalty => .interest
  | .flowKnockoutHasBonds => .interest
  | .flowKnockoutHasForeignTaxPaid => .interest
  | .flowKnockoutWithholdingUnsupportedState => .interest
  | .flowKnockoutStateTaxWithheld => .interest
  | .hasInterestIncomeAndAgiAboveThresholdForMfs => .interest
  | .hasInterestIncomeAndAgiAboveThresholdForMfjOrQss => .interest
  | .hasInterestIncomeAndAgiAboveThresholdForSingleOrHoh => .interest
  | .flowKnockoutTaxExemptInterest => .interest
  | .knockoutForBox12Value => .w2
  | .knockoutForBox12Dependency => .w2
  | .flowKnockoutAllocatedTips => .w2
  | .flowKnockoutStatutoryEmployee => .w2
  | .flowKnockoutThirdPartySickPay => .w2
  | .flowKnockoutNonQualifiedPlans => .w2
  | .knockoutMedicareWages => .w2
  | .anyFilerExceedsMaxOasdiWages => .w2
  | .flowKnockout1099GRepayTooHigh => .unemployment
  | .flowKnockoutUnemploymentCompensationUnsupportedState => .unemployment
  | .extraNonPfd1099Misc => .income
  | .flowKnockoutRetirementTaxableAmountNotDetermined => .retirement
  | .flowKnockoutRetirementTaxableAmountBlank => .retirement
  | .flowKnockoutRetirementTotalDistribution => .retirement
  | .knockoutForForm1099RBox8Value => .retirement
  | .knockoutForForm1099RBox8Percentage => .retirement
  | .knockoutForForm1099RBox9aPercentage => .retirement
  | .flowKnockoutRetirementCapitalGain => .retirement
  | .flowKnockoutRetirementNetUnrealizedAppreciation => .retirement
  | .flowKnockoutRetirementAmountAllocableToIRR => .retirement
  | .flowKnockoutRetirementFactaFilingRequirement => .retirement
  | .flowKnockoutForRollover => .retirement
  | .flowKnockoutForDeathBenefitPaymentDate => .retirement
  | .flowKnockoutRetirementQualifiedDisasterDistribution => .retirement
  | .flowKnockoutRetirementPublicSafetyOfficer => .retirement
  | .flowKnockoutForPreTaxToPostTaxRollover => .retirement
  | .flowKnockoutBox15 => .retirement
  | .knockoutForForm1099RDistributionCode => .retirement
  | .knockoutIraSepSimple => .retirement
  | .knockoutTaxablePensionRollover => .retirement
  | .knockoutIndirectRollover => .retirement
  | .knockoutTaxableAmountNotDetermined => .retirement
  | .socialSecurityBenefitsAreLossGreaterThan3k => .social_security
  | .knockoutPaidEstimatedTaxesUnderDifferentLastName => .estimated_payments
  | .knockoutNoPaymentsHsaDistribution => .hsa
  | .flowKnockoutHsaMedicalSavingsAccountType => .hsa
  | .flowKnockoutHsaDistributionCode => .hsa
  | .flowKnockoutOtherCoveragePartOfYear => .hsa
  | .flowKnockoutOtherCoverageWholeYear => .hsa
  | .flowKnockoutEarningsOnExcessContributions => .hsa
  | .flowKnockoutHsaTestingPeriodAdditionalIncomeYes => .hsa
  | .flowKnockoutHsaUnqualifiedDistributions => .hsa
  | .flowKnockoutHsaDistributionFMV => .hsa
  | .flowKnockoutMaritalChangeAffectsContributionLimit => .hsa
  | .flowKnockoutMFSLine6Check => .hsa
  | .flowHsaContributionsOverLimitKnockout => .hsa
  | .flowKnockoutHsaExcessContributions => .hsa
  | .flowKnockoutContributionSummaryNoneAllowed => .hsa
  | .flowKnockoutHdhpCoverageStatusNotNeeded => .hsa
  | .flowKnockoutNotEnrolledInHdhp => .hsa
  | .flowKnockoutMadeQualifiedHsaFundingDistribution => .hsa
  | .flowKnockoutHsaCoverage => .hsa
  | .flowKnockoutFilerIsDependentAndContributesToHsa => .hsa
  | .extraHsaDistributionsWithoutActivity => .hsa
  | .extraHsaDistributionsSecondaryFilerWithoutMfj => .hsa
  | .incomeSourcesNotSupported => .income
  | .notDigitalAssets => .income
  | .hasForeignAccountsOrTrusts => .income
  | .madeIraContributions => .income
  | .flowKnockoutBox15IncomeFromDifferentState => .w2
  | .hasABox14NYRRTAValueWeKnockout => .w2
  | .flowKnockoutHasRRTACodesInBox14NotInNY => .w2
  | .knockoutYonkersPartYear => .w2
  | .flowKnockoutUnsupportedState => .state
  | .isTooLateToFileOrResubmit => .process
  | .knockoutHasNoPaymentsOrCredits => .process
  | .flowKnockoutFilerAgeYoungerThan16 => .filers
  | .spouseItemizesKnockout => .filers
  | .primaryFilerResidencyKnockout => .filers
  | .flowKnockoutHasApplicableRegisteredDomesticPartnership => .filers
  | .knockoutSubjectToCommunityPropertyLaws => .filers
  | .knockoutHohQpHasNoTin => .household
  | .knockedOutByNonCustodialParentBenefitSplit => .household
  | .knockedOutByContradictory8832 => .household
  | .saversCreditKnockouts => .credits
  | .flowKnockoutBenefitsDistribution => .credits
  | .knockoutCdccWorksheetA => .credits
  | .flowKnockoutHouseholdEmployee => .credits
  | .dependentTpRequiresAllocations => .health_coverage
  | .hasPtcQualifyingPlanAndQsehra => .health_coverage
  | .needsAllocations => .health_coverage
  | .hasEmployerSponsoredPlan => .health_coverage
  | .dependentsRequiredToFile => .health_coverage
  | .selfReportedHasMultiple1095As => .health_coverage
  | .hasImmigrationStatusNotEligibleForMarketplace => .health_coverage
  | .wantsToUseAltCalculations => .health_coverage
  | .extraQualifyingChildTieBreaker => .household
  | .extraClaimedSpouseCombatPayWithoutMfj => .credits
  | .extraFilingStatusNotEligible => .household
  | .extraCdccSoleProprietorshipBenefits => .credits
  | .extraCdccBothSpousesDeemedIncome => .credits
  | .extraTpNeedsToAdd1095A => .health_coverage
  | .extraTpNeedsToDelete1095A => .health_coverage
  | .knockoutPersonBornAndDiedInTaxYearWithoutTin => .household

/-- English fallback text. -/
def KnockoutReason.message : KnockoutReason → String
  | .hasRequiredFactaFilings => "Has Required Facta Filings"
  | .flowKnockoutHasEarlyWithdrawlPenalty => "Flow Knockout Has Early Withdrawl Penalty"
  | .flowKnockoutHasBonds => "Flow Knockout Has Bonds"
  | .flowKnockoutHasForeignTaxPaid => "Flow Knockout Has Foreign Tax Paid"
  | .flowKnockoutWithholdingUnsupportedState => "Flow Knockout Withholding Unsupported State"
  | .flowKnockoutStateTaxWithheld => "Flow Knockout State Tax Withheld"
  | .hasInterestIncomeAndAgiAboveThresholdForMfs => "Has Interest Income And Agi Above Threshold For Mfs"
  | .hasInterestIncomeAndAgiAboveThresholdForMfjOrQss => "Has Interest Income And Agi Above Threshold For Mfj Or Qss"
  | .hasInterestIncomeAndAgiAboveThresholdForSingleOrHoh => "Has Interest Income And Agi Above Threshold For Single Or Hoh"
  | .flowKnockoutTaxExemptInterest => "Flow Knockout Tax Exempt Interest"
  | .knockoutForBox12Value => "Knockout For Box12 Value"
  | .knockoutForBox12Dependency => "Knockout For Box12 Dependency"
  | .flowKnockoutAllocatedTips => "Flow Knockout Allocated Tips"
  | .flowKnockoutStatutoryEmployee => "Flow Knockout Statutory Employee"
  | .flowKnockoutThirdPartySickPay => "Flow Knockout Third Party Sick Pay"
  | .flowKnockoutNonQualifiedPlans => "Flow Knockout Non Qualified Plans"
  | .knockoutMedicareWages => "Knockout Medicare Wages"
  | .anyFilerExceedsMaxOasdiWages => "Any Filer Exceeds Max Oasdi Wages"
  | .flowKnockout1099GRepayTooHigh => "Flow Knockout1099 GRepay Too High"
  | .flowKnockoutUnemploymentCompensationUnsupportedState => "Flow Knockout Unemployment Compensation Unsupported State"
  | .extraNonPfd1099Misc => "Extra Non Pfd1099 Misc"
  | .flowKnockoutRetirementTaxableAmountNotDetermined => "Flow Knockout Retirement Taxable Amount Not Determined"
  | .flowKnockoutRetirementTaxableAmountBlank => "Flow Knockout Retirement Taxable Amount Blank"
  | .flowKnockoutRetirementTotalDistribution => "Flow Knockout Retirement Total Distribution"
  | .knockoutForForm1099RBox8Value => "Knockout For Form1099 RBox8 Value"
  | .knockoutForForm1099RBox8Percentage => "Knockout For Form1099 RBox8 Percentage"
  | .knockoutForForm1099RBox9aPercentage => "Knockout For Form1099 RBox9a Percentage"
  | .flowKnockoutRetirementCapitalGain => "Flow Knockout Retirement Capital Gain"
  | .flowKnockoutRetirementNetUnrealizedAppreciation => "Flow Knockout Retirement Net Unrealized Appreciation"
  | .flowKnockoutRetirementAmountAllocableToIRR => "Flow Knockout Retirement Amount Allocable To IRR"
  | .flowKnockoutRetirementFactaFilingRequirement => "Flow Knockout Retirement Facta Filing Requirement"
  | .flowKnockoutForRollover => "Flow Knockout For Rollover"
  | .flowKnockoutForDeathBenefitPaymentDate => "Flow Knockout For Death Benefit Payment Date"
  | .flowKnockoutRetirementQualifiedDisasterDistribution => "Flow Knockout Retirement Qualified Disaster Distribution"
  | .flowKnockoutRetirementPublicSafetyOfficer => "Flow Knockout Retirement Public Safety Officer"
  | .flowKnockoutForPreTaxToPostTaxRollover => "Flow Knockout For Pre Tax To Post Tax Rollover"
  | .flowKnockoutBox15 => "Flow Knockout Box15"
  | .knockoutForForm1099RDistributionCode => "Knockout For Form1099 RDistribution Code"
  | .knockoutIraSepSimple => "Knockout Ira Sep Simple"
  | .knockoutTaxablePensionRollover => "Knockout Taxable Pension Rollover"
  | .knockoutIndirectRollover => "Knockout Indirect Rollover"
  | .knockoutTaxableAmountNotDetermined => "Knockout Taxable Amount Not Determined"
  | .socialSecurityBenefitsAreLossGreaterThan3k => "Social Security Benefits Are Loss Greater Than3k"
  | .knockoutPaidEstimatedTaxesUnderDifferentLastName => "Knockout Paid Estimated Taxes Under Different Last Name"
  | .knockoutNoPaymentsHsaDistribution => "Knockout No Payments Hsa Distribution"
  | .flowKnockoutHsaMedicalSavingsAccountType => "Flow Knockout Hsa Medical Savings Account Type"
  | .flowKnockoutHsaDistributionCode => "Flow Knockout Hsa Distribution Code"
  | .flowKnockoutOtherCoveragePartOfYear => "Flow Knockout Other Coverage Part Of Year"
  | .flowKnockoutOtherCoverageWholeYear => "Flow Knockout Other Coverage Whole Year"
  | .flowKnockoutEarningsOnExcessContributions => "Flow Knockout Earnings On Excess Contributions"
  | .flowKnockoutHsaTestingPeriodAdditionalIncomeYes => "Flow Knockout Hsa Testing Period Additional Income Yes"
  | .flowKnockoutHsaUnqualifiedDistributions => "Flow Knockout Hsa Unqualified Distributions"
  | .flowKnockoutHsaDistributionFMV => "Flow Knockout Hsa Distribution FMV"
  | .flowKnockoutMaritalChangeAffectsContributionLimit => "Flow Knockout Marital Change Affects Contribution Limit"
  | .flowKnockoutMFSLine6Check => "Flow Knockout MFSLine6 Check"
  | .flowHsaContributionsOverLimitKnockout => "Flow Hsa Contributions Over Limit Knockout"
  | .flowKnockoutHsaExcessContributions => "Flow Knockout Hsa Excess Contributions"
  | .flowKnockoutContributionSummaryNoneAllowed => "Flow Knockout Contribution Summary None Allowed"
  | .flowKnockoutHdhpCoverageStatusNotNeeded => "Flow Knockout Hdhp Coverage Status Not Needed"
  | .flowKnockoutNotEnrolledInHdhp => "Flow Knockout Not Enrolled In Hdhp"
  | .flowKnockoutMadeQualifiedHsaFundingDistribution => "Flow Knockout Made Qualified Hsa Funding Distribution"
  | .flowKnockoutHsaCoverage => "Flow Knockout Hsa Coverage"
  | .flowKnockoutFilerIsDependentAndContributesToHsa => "Flow Knockout Filer Is Dependent And Contributes To Hsa"
  | .extraHsaDistributionsWithoutActivity => "Extra Hsa Distributions Without Activity"
  | .extraHsaDistributionsSecondaryFilerWithoutMfj => "Extra Hsa Distributions Secondary Filer Without Mfj"
  | .incomeSourcesNotSupported => "Income Sources Not Supported"
  | .notDigitalAssets => "Not Digital Assets"
  | .hasForeignAccountsOrTrusts => "Has Foreign Accounts Or Trusts"
  | .madeIraContributions => "Made Ira Contributions"
  | .flowKnockoutBox15IncomeFromDifferentState => "Flow Knockout Box15 Income From Different State"
  | .hasABox14NYRRTAValueWeKnockout => "Has ABox14 NYRRTAValue We Knockout"
  | .flowKnockoutHasRRTACodesInBox14NotInNY => "Flow Knockout Has RRTACodes In Box14 Not In NY"
  | .knockoutYonkersPartYear => "Knockout Yonkers Part Year"
  | .flowKnockoutUnsupportedState => "Flow Knockout Unsupported State"
  | .isTooLateToFileOrResubmit => "Is Too Late To File Or Resubmit"
  | .knockoutHasNoPaymentsOrCredits => "Knockout Has No Payments Or Credits"
  | .flowKnockoutFilerAgeYoungerThan16 => "Flow Knockout Filer Age Younger Than16"
  | .spouseItemizesKnockout => "Spouse Itemizes Knockout"
  | .primaryFilerResidencyKnockout => "Primary Filer Residency Knockout"
  | .flowKnockoutHasApplicableRegisteredDomesticPartnership => "Flow Knockout Has Applicable Registered Domestic Partnership"
  | .knockoutSubjectToCommunityPropertyLaws => "Knockout Subject To Community Property Laws"
  | .knockoutHohQpHasNoTin => "Knockout Hoh Qp Has No Tin"
  | .knockedOutByNonCustodialParentBenefitSplit => "Knocked Out By Non Custodial Parent Benefit Split"
  | .knockedOutByContradictory8832 => "Knocked Out By Contradictory8832"
  | .saversCreditKnockouts => "Savers Credit Knockouts"
  | .flowKnockoutBenefitsDistribution => "Flow Knockout Benefits Distribution"
  | .knockoutCdccWorksheetA => "Knockout Cdcc Worksheet A"
  | .flowKnockoutHouseholdEmployee => "Flow Knockout Household Employee"
  | .dependentTpRequiresAllocations => "Dependent Tp Requires Allocations"
  | .hasPtcQualifyingPlanAndQsehra => "Has Ptc Qualifying Plan And Qsehra"
  | .needsAllocations => "Needs Allocations"
  | .hasEmployerSponsoredPlan => "Has Employer Sponsored Plan"
  | .dependentsRequiredToFile => "Dependents Required To File"
  | .selfReportedHasMultiple1095As => "Self Reported Has Multiple1095 As"
  | .hasImmigrationStatusNotEligibleForMarketplace => "Has Immigration Status Not Eligible For Marketplace"
  | .wantsToUseAltCalculations => "Wants To Use Alt Calculations"
  | .extraQualifyingChildTieBreaker => "Extra Qualifying Child Tie Breaker"
  | .extraClaimedSpouseCombatPayWithoutMfj => "Extra Claimed Spouse Combat Pay Without Mfj"
  | .extraFilingStatusNotEligible => "Extra Filing Status Not Eligible"
  | .extraCdccSoleProprietorshipBenefits => "Extra Cdcc Sole Proprietorship Benefits"
  | .extraCdccBothSpousesDeemedIncome => "Extra Cdcc Both Spouses Deemed Income"
  | .extraTpNeedsToAdd1095A => "Extra Tp Needs To Add1095 A"
  | .extraTpNeedsToDelete1095A => "Extra Tp Needs To Delete1095 A"
  | .knockoutPersonBornAndDiedInTaxYearWithoutTin => "Knockout Person Born And Died In Tax Year Without Tin"

/-- The `UnsupportedReason` of the response. -/
def KnockoutReason.toReason (k : KnockoutReason) : UnsupportedReason :=
  { code := k.code, category := k.category.name, message := k.message }

/-- The table as JSON text, `[{"code":..,"category":..,"message":..}, ...]`, for the conformance check. -/
def reasonTableJson : String :=
  "[" ++ ",".intercalate (KnockoutReason.all.map fun k =>
    "{\"code\":\"" ++ k.code ++ "\",\"category\":\"" ++ k.category.name ++
    "\",\"message\":\"" ++ k.message ++ "\"}") ++ "]"

#guard KnockoutReason.all.length == 104
#guard (KnockoutReason.all.map KnockoutReason.code).eraseDups.length == 104

end UsTax.Api
