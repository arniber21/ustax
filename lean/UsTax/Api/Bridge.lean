import UsTax.Api.Spec
import UsTax.Form1040
import UsTax.Calculator

/-!
# Bridge to the calculator input (issues #51, #52, #48)

`Request` is the typed, validated image of the HTTP body. The calculator's
input is `Calculator.CalculatorIn` (issue #48, `catala/calculator.catala_en`).
This file is the **only** place that knows both field vocabularies (API box
names and Catala names), as `docs/api.md` states. Its functions are thin and
total:

* money: `Int` cents to `Int` cents, **no arithmetic and no rounding** (the
  calculator rounds, per CONVENTIONS section 4);
* an absent section, object or answer is its schema default (`Option.getD`),
  as `scripts/api_decode.mjs` decodes it for the Catala `ApiCalculator`;
* box 12 entries are looked up by code (absent code = `0`) and land in the
  `FormW2s.FormW2` field named in `$defs/W2Box12.description`;
* enumerations map constructor to constructor of the same name.

`toCalculatorInput` is the Catala `ApiCalculator`'s mapping of the request to the
`Calculator` inputs (`docs/api-mapping.md`); every section of schema 1.2.0 is read.
`toForm1040Input` is the schema 1.0 slice (W-2s, 1099-INT, the `filing_details`
flags into `Form1040` directly), kept for the `Form1040` tests and properties.
-/

namespace UsTax.Api

/-- The amount of a box 12 code on a W-2; absent code is `0`. -/
def Box12.amount (b : Box12) (code : Box12Code) : Int :=
  ((b.entries.find? (·.1 == code)).map (·.2)).getD 0

/-- API filer role to the Catala `FilerRole`. -/
def FilerRole.toCore : FilerRole → UsTax.FilerRole
  | .primaryFiler => .primaryFiler
  | .secondaryFiler => .secondaryFiler

/-- API combat pay election to the Catala one (same constructors). -/
def CombatPayElection.toCore : CombatPayElection → FormW2s.CombatPayElection
  | .noCombatPay => .noCombatPay
  | .usePrimaryCombatPay => .usePrimaryCombatPay
  | .useSpouseCombatPay => .useSpouseCombatPay
  | .useBothCombatPay => .useBothCombatPay
  | .usePrimaryNotSpouseCombatPay => .usePrimaryNotSpouseCombatPay
  | .useSpouseNotPrimaryCombatPay => .useSpouseNotPrimaryCombatPay

/-- One API W-2 to the Catala `FormW2`. Box 12 code letters per `$defs/W2Box12`. -/
def FormW2.toCore (w : FormW2) : FormW2s.FormW2 :=
  { filer := w.filer.toCore
    writableWages := w.wages
    writableFederalWithholding := w.federalWithholding
    writableOasdiWages := w.oasdiWages
    writableOasdiWithholding := w.oasdiWithholding
    writableMedicareWages := w.medicareWages
    writableMedicareWithholding := w.medicareWithholding
    writableAllocatedTips := w.allocatedTips
    writableDependentCareBenefits := w.dependentCareBenefits
    writableNonQualifiedPlans := w.nonQualifiedPlans
    writableCombatPay := w.box12.amount .q
    uncollectedOasdiTaxOnTips := w.box12.amount .a
    uncollectedMedicareTaxOnTips := w.box12.amount .b
    taxableLifeInsuranceOver50k := w.box12.amount .c
    deferrals401k := w.box12.amount .d
    deferrals403b := w.box12.amount .e
    sarsepDeferrals := w.box12.amount .f
    deferrals457b := w.box12.amount .g
    deferrals501c18 := w.box12.amount .h
    nontaxableSickPay := w.box12.amount .j
    goldenParachuteExciseTax := w.box12.amount .k
    expenseReimbursements := w.box12.amount .l
    uncollectedOasdiTaxOnLifeInsuranceOver50k := w.box12.amount .m
    uncollectedMedicareTaxOnLifeInsuranceOver50k := w.box12.amount .n
    armedForcesMovingExpenses := w.box12.amount .p
    archerMsaContributions := w.box12.amount .r
    simpleContributions := w.box12.amount .s
    adoptionBenefits := w.box12.amount .t
    nsoIncome := w.box12.amount .v
    employerHsaContributions := w.box12.amount .w
    deferrals409a := w.box12.amount .y
    nqdcDeferrals := w.box12.amount .z
    roth401kContributions := w.box12.amount .aa
    roth403bContributions := w.box12.amount .bb
    healthCoverageCost := w.box12.amount .dd
    roth457bContributions := w.box12.amount .ee
    qsehraBenefits := w.box12.amount .ff
    income83i := w.box12.amount .gg
    deferrals83i := w.box12.amount .hh
    nonTaxableMedicaidWaiverPayments := w.box12.amount .ii
    plan457bIsGovernmental := w.plan457bIsGovernmental
    statutoryEmployee := w.statutoryEmployee
    thirdPartySickPay := w.thirdPartySickPay }

/-- One API 1099-INT to the Catala `InterestReport` (`$defs/Form1099Int.description`). -/
def Form1099Int.toCore (f : Form1099Int) : Interest.InterestReport :=
  { filer := f.filer.toCore
    has1099 := f.has1099
    no1099Amount := f.no1099Amount
    writable1099Amount := f.interestIncome
    writableEarlyWithdrawlPenaltyAmount := f.earlyWithdrawalPenalty
    writableInterestOnGovernmentBonds := f.governmentBondInterest
    writableTaxWithheld := f.federalTaxWithheld
    writableForeignTaxPaid := f.foreignTaxPaid
    writableTaxExemptInterest := f.taxExemptInterest
    writableSpecifiedPrivateActivityBondInterest := f.privateActivityBondInterest
    writableMarketDiscount := f.marketDiscount
    writableBondPremium := f.bondPremium
    writableBondPremiumOnTreasuryObligations := f.bondPremiumTreasury
    writableBondPremiumOnTaxExemptBond := f.bondPremiumTaxExempt
    stateIsDifferentState := f.stateIsDifferent
    writableStateTaxWithheld := f.stateTaxWithheld
    factaFilingRequired := f.factaFilingRequired }

/-- The schema 1.0 slice of the request as the `Form1040` scope input (plug-in slots at their
Catala defaults `$0`, `false`). The server uses `toCalculatorInput`. -/
def toForm1040Input (r : Request) (_h : r.Valid) : Form1040.Form1040In :=
  let p := r.filers.primary.getD {}
  let s := r.filers.secondary.getD {}
  let d := r.filingDetails
  { filingStatus := r.filingStatus
    w2s := r.w2s.map FormW2.toCore
    interestReports := r.interestReports.map Form1099Int.toCore
    hasForeignAccountsOrTrusts := d.hasForeignAccountsOrTrusts
    combatPayElection := d.combatPayElection.toCore
    primaryFilerCanBeClaimed := p.canBeClaimedAsDependent
    secondaryFilerCanBeClaimed := s.canBeClaimedAsDependent
    treatAsMfs := d.treatAsMfs.getD (r.filingStatus == .marriedFilingSeparately)
    primaryFilerIsBlind := p.isBlind
    primaryFilerAge65OrOlder := p.age65OrOlder
    secondaryFilerIsBlind := s.isBlind
    secondaryFilerAge65OrOlder := s.age65OrOlder
    isWidowedInTaxYear := d.isWidowedInTaxYear.getD false
    mfjDeceasedSpouseReachedAge65 := d.mfjDeceasedSpouseReachedAge65.getD false
    mfsSpouse65OrOlder := d.mfsSpouse65OrOlder
    mfsSpouseProvidesNoBenefits := d.mfsSpouseProvidesNoBenefits.getD false
    treatFilersAsDependents := d.treatFilersAsDependents.getD false }

/-! ## The whole-return mapping (`docs/api-mapping.md`, Catala `Api_calculator`, issue #48)

The request as the input of `Calculator.calculator`, field for field as the Catala scope
`ApiCalculator` (`catala/api_calculator.catala_en`) maps the decoded `ApiRequest`. An absent
section, object or answer is its schema default (`Option.getD`: `false`, `0`, `[]`, or the schema's
named default); money stays in cents (no arithmetic, no rounding). -/

/-- `Form1099G` to the Catala `Unemployment.Form1099G`. -/
def Form1099G.toCore (f : Form1099G) : Unemployment.Form1099G :=
  { filer := f.filer.toCore, amount := f.unemploymentCompensation
    writableAmountPaidBackForBenefitsInTaxYear := f.repaidThisYearForThisYear
    writableAmountPaidBackForBenefitsBeforeTaxYear := f.repaidThisYearForEarlierYear
    writableFederalTaxWithheld := f.federalTaxWithheld, stateIsDifferentState := f.stateIsDifferent }

/-- `Form1099Misc` to the Catala `Form1099Misc.Form1099Misc`. -/
def Form1099Misc.toCore (f : Form1099Misc) : UsTax.Form1099Misc.Form1099Misc :=
  { filer := f.filer.toCore, isAlaskaPfd := f.isAlaskaPfd, writableOtherIncome := f.otherIncome
    writableFederalWithholding := f.federalWithholding }

/-- `distribution_code` items `2 4 7 B G H Other` to `Code2 ... OtherCode`. -/
def CodeChar.toCore : CodeChar → Form1099Rs.CodeChar
  | .c2 => .code2 | .c4 => .code4 | .c7 => .code7 | .b => .codeB | .g => .codeG | .h => .codeH
  | .other => .otherCode

/-- `Form1099R` to the Catala `Form1099Rs.Form1099R`; an absent recipient date of birth is
1980-01-01 (age 44, `docs/api-mapping.md` "Optional dates"). -/
def Form1099R.toCore (f : Form1099R) : Form1099Rs.Form1099R :=
  { filer := f.filer.toCore, distributionCode := f.distributionCode.map CodeChar.toCore
    writableGrossDistribution := f.grossDistribution, writableTaxableAmount := f.taxableAmount
    taxableAmountBlank := f.taxableAmountBlank
    taxableAmountNotDetermined := f.taxableAmountNotDetermined
    totalDistribution := f.totalDistribution, writableCapitalGain := f.capitalGain
    writableFederalWithholding := f.federalWithholding, writableNetAppreciation := f.netAppreciation
    iraSepSimple := f.iraSepSimple, writableOtherDollar := f.otherDollar
    otherPercentageNonzero := f.otherPercentageNonzero
    percentageTotalDistributionNonzero := f.percentageTotalDistributionNonzero
    writableAmountAllocableToIrr := f.amountAllocableToIrr
    factaFilingRequirement := f.factaFilingRequirement
    writableStateTaxWithheld := f.stateTaxWithheld, payerStateIsDifferent := f.payerStateIsDifferent
    hasDeathBenefitPaymentDate := f.hasDeathBenefitPaymentDate
    writableIsIndirectRollover := f.isIndirectRollover
    writableIsDistributionFromMilitaryRetirementPlan := f.isDistributionFromMilitaryRetirementPlan
    writableQualifiedDisasterDistribution := f.qualifiedDisasterDistribution
    writeablePublicSafetyOfficer := f.publicSafetyOfficer
    writeablePublicSafetyOfficerPremiums := f.publicSafetyOfficerPremiums
    recipientDateOfBirth := f.recipientDateOfBirth.getD ⟨1980, 1, 1⟩ }

/-- Educator expenses and estimated payments `WhoDid` to the Catala enumerations. -/
def WhoDid.toK12 : WhoDid → EducatorAdjustment.K12EducatorOptions
  | .tpDid => .tpDid | .spouseDid => .spouseDid | .bothDid => .bothDid | .neither => .neither

/-- `paid_with_former_spouse` to the Catala `PaidWithFormerSpouse`. -/
def WhoDid.toFormerSpouse : WhoDid → EstimatedPayments.PaidWithFormerSpouse
  | .tpDid => .tpDid | .spouseDid => .spouseDid | .bothDid => .bothDid | .neither => .neither

/-- Filing answers' enumerations. -/
def MaritalStatus.toCore : MaritalStatus → Filers.MaritalStatus
  | .neverMarried => .neverMarried | .married => .married | .divorced => .divorced
  | .widowed => .widowed

/-- `year_of_spouse_death` to the Catala enumeration. -/
def YearOfSpouseDeath.toCore : YearOfSpouseDeath → Filers.YearOfSpouseDeath
  | .diedInTaxYear => .diedInTaxYear | .diedTaxYearMinusOne => .diedTaxYearMinusOne
  | .diedTaxYearMinusTwo => .diedTaxYearMinusTwo
  | .diedBeforeTaxYearMinusTwo => .diedBeforeTaxYearMinusTwo

/-- `spouse_lived_together_months` to the Catala enumeration. -/
def SpouseLivedTogetherMonths.toCore : SpouseLivedTogetherMonths → Filers.SpouseLivedTogetherMonths
  | .livedApartAllYear => .livedApartAllYear
  | .livedTogetherSixMonthsOrLess => .livedTogetherSixMonthsOrLess
  | .livedTogetherMoreThanSixMonths => .livedTogetherMoreThanSixMonths

/-- `residence_state` to the Catala `ScopedState`. -/
def ResidenceState.toCore : ResidenceState → ScopedState
  | .moreThanOne => .moreThanOne | .ak => .ak | .az => .az | .ca => .ca | .ct => .ct | .fl => .fl
  | .id => .id | .il => .il | .ks => .ks | .me => .me | .md => .md | .ma => .ma | .nv => .nv
  | .nh => .nh | .nj => .nj | .nm => .nm | .ny => .ny | .nc => .nc | .or => .or | .pa => .pa
  | .sd => .sd | .tn => .tn | .tx => .tx | .wa => .wa | .wi => .wi | .wy => .wy
  | .noneOfThese => .noneOfThese

/-- Dependent enumerations. -/
def Relationship.toCore : Relationship → QualifyingChild.Relationship
  | .biologicalChild => .biologicalChild | .adoptedChild => .adoptedChild
  | .stepChild => .stepChild | .fosterChild => .fosterChild
  | .grandChildOrOtherDescendantOfChild => .grandChildOrOtherDescendantOfChild
  | .childInLaw => .childInLaw | .sibling => .sibling | .childOfSibling => .childOfSibling
  | .halfSibling => .halfSibling | .childOfHalfSibling => .childOfHalfSibling
  | .stepSibling => .stepSibling | .childOfStepSibling => .childOfStepSibling
  | .otherDescendantOfSibling => .otherDescendantOfSibling
  | .otherDescendantOfHalfSibling => .otherDescendantOfHalfSibling
  | .otherDescendantOfStepSibling => .otherDescendantOfStepSibling
  | .siblingsSpouse => .siblingsSpouse | .siblingInLaw => .siblingInLaw | .parent => .parent
  | .fosterParent => .fosterParent | .siblingOfParent => .siblingOfParent
  | .grandParent => .grandParent | .otherAncestorOfParent => .otherAncestorOfParent
  | .stepParent => .stepParent | .parentInLaw => .parentInLaw | .noneOfTheAbove => .noneOfTheAbove

/-- `residency_duration` to the Catala enumeration. -/
def ResidencyDuration.toCore : ResidencyDuration → QualifyingChild.ResidencyDuration
  | .allYear => .allYear | .sixToElevenMonths => .sixToElevenMonths
  | .lessThanSixMonths => .lessThanSixMonths

/-- `tin_type` to the Catala enumeration. -/
def TinType.toCore : TinType → QualifyingRelative.TinType
  | .ssn => .ssn | .itin => .itin | .atin => .atin | .noTin => .noTin

/-- A dependent's `ssn_employment_validity` to the Catala enumeration. -/
def DependentSsnEmploymentValidity.toCore : DependentSsnEmploymentValidity → CtcOdc.SsnEmploymentValidity
  | .neither => .neither | .notValid => .notValid
  | .validOnlyWithDhsAuthorizationInEffect => .validOnlyWithDhsAuthorizationInEffect
  | .validOnlyWithDhsAuthorizationExpired => .validOnlyWithDhsAuthorizationExpired

/-- `custody.which_parent_not_claiming` to the Catala enumeration. -/
def WhichParentNotClaiming.toCore : WhichParentNotClaiming → DependentsBenefitSplit.WrittenDeclaration
  | .iDid => .iDid | .theyDid => .theyDid | .nobodyDid => .nobodyDid

/-- `custody.nights_with_tp_vs_other_parent` to the Catala enumeration. -/
def NightsWithTpVsOtherParent.toCore : NightsWithTpVsOtherParent → DependentsBenefitSplit.NightsComparison
  | .more => .more | .less => .less | .equal => .equal

/-- `custody.parental_situation` to the Catala enumeration. -/
def ParentalSituation.toCore : ParentalSituation → DependentsBenefitSplit.ParentalSituation
  | .divorcedOrSeparated => .divorcedOrSeparated | .livedApartLastSixMonths => .livedApartLastSixMonths
  | .other => .other

/-- `dependents[].custody` (absent answers `false`). -/
def BenefitSplitAnswers.toCore (a : BenefitSplitAnswers) : DependentsBenefitSplit.BenefitSplitAnswers :=
  { hasOtherBiologicalOrAdoptiveParent := a.hasOtherBiologicalOrAdoptiveParent.getD false
    nonParentalSomeParentNotClaiming := a.nonParentalSomeParentNotClaiming.getD false
    whichParentNotClaiming := a.whichParentNotClaiming.toCore
    inParentsCustody := a.inParentsCustody.getD false
    livedWithTpOrOtherBiologicalOrAdoptiveParentMoreThanSixMonths :=
      a.livedWithTpOrOtherBiologicalOrAdoptiveParentMoreThanSixMonths.getD false
    biologicalOrAdoptiveParentsLiving := a.biologicalOrAdoptiveParentsLiving.getD false
    nightsWithTpVsOtherParent := a.nightsWithTpVsOtherParent.toCore
    tpAgiHigherThanOtherParent := a.tpAgiHigherThanOtherParent.getD false
    parentsMeetReqsRuleForChildrenOfDivorcedParents :=
      a.parentsMeetReqsRuleForChildrenOfDivorcedParents.getD false
    specialRuleChildUsedByCustodialParentAsQp := a.specialRuleChildUsedByCustodialParentAsQp.getD false
    specialRuleAgiTest := a.specialRuleAgiTest.getD false
    parentalSituation := a.parentalSituation.toCore
    parentalSupport := a.parentalSupport.getD false
    multipleSupportAgreement := a.multipleSupportAgreement.getD false }

/-- `dependents[].cdcc`. -/
def CdccMemberAnswers.toCore (a : CdccMemberAnswers) : Calculator.CdccMemberAnswers :=
  { unableToCareForSelf := a.unableToCareForSelf.getD false
    hasDependentCareExpenses := a.hasDependentCareExpenses.getD false
    expensesPaidToQualifyingProvider := a.expensesPaidToQualifyingProvider.getD false
    writableQualifyingExpenseAmount := a.writableQualifyingExpenseAmount.getD 0 }

/-- Catala `ApiDependentToCalc`: one `dependents[]` entry as a `Calculator.HouseholdMember`. -/
def Dependent.toCore (d : Dependent) : Calculator.HouseholdMember :=
  { dependent :=
      { person :=
          { relationship := d.relationship.toCore, dateOfBirth := d.dateOfBirth
            fullTimeStudent := d.fullTimeStudent, permanentTotalDisability := d.permanentTotalDisability
            residencyDuration := d.residencyDuration.toCore, ownSupport := d.ownSupport
            married := d.married, writableJointReturn := d.jointReturn
            writableRequiredToFile := d.requiredToFile
            writableFilingOnlyForRefund := d.filingOnlyForRefund
            writableCouldBeQualifyingChildOfAnother := d.couldBeQualifyingChildOfAnother
            writablePotentialClaimerMustFile := d.potentialClaimerMustFile
            writablePotentialClaimerDidFile := d.potentialClaimerDidFile
            writablePotentialClaimerFiledOnlyForRefund := d.potentialClaimerFiledOnlyForRefund }
        answers :=
          { grossIncome := d.grossIncome, writableQrSupportTest := d.qrSupportTest
            tinType := d.tinType.toCore, isUsCitizenFullYear := d.isUsCitizenFullYear
            writableUsResident := d.usResident, writableUsNational := d.usNational
            writableCanadaMexicoResident := d.canadaMexicoResident, tpClaims := d.tpClaims }
        split := (d.custody.getD {}).toCore }
    upkeep :=
      { tpPaidMostOfHomeUpkeep := d.tpPaidMostOfHomeUpkeep
        tpPaidMostOfParentHomeUpkeep := d.tpPaidMostOfParentHomeUpkeep }
    ssnEmploymentValidity := d.ssnEmploymentValidity.toCore
    ssnOnlyForFederallyFundedBenefit := d.ssnOnlyForFederallyFundedBenefit
    monthsLivedWithTpInUs := d.monthsLivedWithTpInUs
    cdcc := (d.cdcc.getD {}).toCore }

/-- A filer's `tin.ssn_employment_validity` to the Catala enumeration. -/
def FilerTinSsnEmploymentValidity.toCore :
    FilerTinSsnEmploymentValidity → Calculator.FilerSsnEmploymentValidity
  | .neither => .neither | .notValid => .notValid
  | .validOnlyWithDhsAuthorization => .validOnlyWithDhsAuthorization

/-- `filers.*.tin`. -/
def FilerTin.toCore (t : FilerTin) : Calculator.FilerTin :=
  { tinIsSsn := t.tinIsSsn, ssnEmploymentValidity := t.ssnEmploymentValidity.toCore
    hasSsnOnlyForBenefits := t.hasSsnOnlyForBenefits.getD false }

/-- `filers.*.disability` (`has_w2_wages` is recomputed by the calculator). -/
def DisabilityAnswers.toCore (a : DisabilityAnswers) : ElderlyAndDisabled.DisabilityAnswers :=
  { isRetiredOnPermOrTotalDisability := a.isRetiredOnPermOrTotalDisability.getD false
    employerHasMandatoryRetirementAge := a.employerHasMandatoryRetirementAge.getD false
    hasMetEmployerMandatoryRetirementAge := a.hasMetEmployerMandatoryRetirementAge.getD false
    arePaymentsTaxableDisabilityIncome := a.arePaymentsTaxableDisabilityIncome.getD false
    writableTotalTaxableDisabilityAmount := a.writableTotalTaxableDisabilityAmount.getD 0
    hasW2Wages := a.hasW2Wages.getD false }

/-- `filers.*.hsa`. -/
def HsaFilerAnswers.toCore (a : HsaFilerAnswers) : Hsa.HsaFilerAnswers :=
  { writablePrimaryFilerHasMadeContributionsToHsa :=
      a.writablePrimaryFilerHasMadeContributionsToHsa.getD false
    writableSecondaryFilerHasMadeContributionsToHsa :=
      a.writableSecondaryFilerHasMadeContributionsToHsa.getD false
    enrolledInMedicare := match a.enrolledInMedicare with
      | .medicareAllYear => .medicareAllYear | .medicarePartOfYear => .medicarePartOfYear
      | .medicareNoneOfYear => .medicareNoneOfYear
    hsaHdhpCoverageStatus := match a.hsaHdhpCoverageStatus with
      | .hdhpAllYear => .hdhpAllYear | .hdhpPartOfYear => .hdhpPartOfYear
      | .hdhpNoneOfYear => .hdhpNoneOfYear
    typeOfHdhp := match a.typeOfHdhp with
      | .selfOnly => .selfOnly | .family => .family | .bothSelfAndFamily => .bothSelfAndFamily
    hadOtherCoverageIneligibleForHsa := match a.hadOtherCoverageIneligibleForHsa with
      | .otherCoverageWholeYear => .otherCoverageWholeYear
      | .otherCoveragePartOfYear => .otherCoveragePartOfYear
      | .otherCoverageNoneOfYear => .otherCoverageNoneOfYear
    writableMfsLine6Check := a.writableMfsLine6Check.getD false
    writableChangeInMaritalStatusDuringTaxYear := match a.writableChangeInMaritalStatusDuringTaxYear with
      | .wasMarriedOrDivorcedThisYear => .wasMarriedOrDivorcedThisYear
      | .wasNotMarriedNorDivorcedThisYear => .wasNotMarriedNorDivorcedThisYear
    writableMaritalChangeAffectContributionLimitBool :=
      a.writableMaritalChangeAffectContributionLimitBool.getD false
    hasMadeQualifiedHsaFundingDistribution := a.hasMadeQualifiedHsaFundingDistribution.getD false
    writableHsaNonemployerContributionsTaxYear := a.writableHsaNonemployerContributionsTaxYear.getD 0
    writableHsaNonemployerContributionsTaxYearPlusOne :=
      a.writableHsaNonemployerContributionsTaxYearPlusOne.getD 0 }

/-- `filers.*.cdcc`. -/
def CdccFilerAnswers.toCore (a : CdccFilerAnswers) : Calculator.CdccFilerAnswers :=
  { electCombatPayForCredit := a.electCombatPayForCredit.getD false
    electCombatPayForBenefits := a.electCombatPayForBenefits.getD false
    dependentCarePlanMaximum := a.dependentCarePlanMaximum.getD 0
    isDisabled := a.isDisabled.getD false
    deemedIncomeMonthEarnings := a.deemedIncomeMonthEarnings
    hasDependentCareExpenses := a.hasDependentCareExpenses.getD false
    expensesPaidToQualifyingProvider := a.expensesPaidToQualifyingProvider.getD false
    writableQualifyingExpenseAmount := a.writableQualifyingExpenseAmount.getD 0 }

/-- Catala `ApiFilerToCalc.answers`: the filer's answers with the legacy flags folded in. An
absent date of birth is 1950-06-15 for a filer 65 or older (`age65_or_older`, or `alsoAge65`, the
legacy `mfj_deceased_spouse_reached_age65`), else 1985-06-15. `treatAsDependent` is
`filing_details.treat_filers_as_dependents`. -/
def FilerFlags.answers (f : FilerFlags) (treatAsDependent alsoAge65 : Bool) : Filers.FilerAnswers :=
  { dateOfBirth := f.dateOfBirth.getD
      (if f.age65OrOlder || alsoAge65 then ⟨1950, 6, 15⟩ else ⟨1985, 6, 15⟩)
    isBlind := f.isBlind
    canBeClaimed := f.canBeClaimedAsDependent || treatAsDependent
    willBeClaimed := f.willBeClaimed || treatAsDependent
    potentialClaimerMustFile := f.potentialClaimerMustFile || treatAsDependent
    potentialClaimerDidFile := f.potentialClaimerDidFile
    isUsCitizenFullYear := f.isUsCitizenFullYear
    writableCitizenAtEndOfTaxYear := f.citizenAtEndOfTaxYear
    writableIsNoncitizenResidentFullYear := f.noncitizenResidentFullYear
    writableIsNational := f.isNational }

/-- Catala `ApiFilerToCalc.extra`. -/
def FilerFlags.extra (f : FilerFlags) : Calculator.FilerExtra :=
  { tin := (f.tin.getD {}).toCore, isStudent := f.isStudent
    disability := (f.disability.getD {}).toCore, hsa := (f.hsa.getD {}).toCore
    cdcc := (f.cdcc.getD {}).toCore }

/-- Catala `MaritalOf.marital_status_used`: an unspecified marital status takes the default of
the filing status (Single, HoH: never married; MFJ, MFS: married; QSS: widowed), or widowed for
the legacy `is_widowed_in_tax_year`. -/
def maritalStatusUsed (fs : FilingStatus) (ms : Option MaritalStatus) (widowedInTaxYear : Bool) :
    Filers.MaritalStatus :=
  match ms with
  | some m => m.toCore
  | none =>
    if widowedInTaxYear then .widowed
    else match fs with
      | .single | .headOfHousehold => .neverMarried
      | .marriedFilingJointly | .marriedFilingSeparately => .married
      | .qualifyingSurvivingSpouse => .widowed

/-- Catala `MaritalOf.year_of_spouse_death_used`. -/
def yearOfSpouseDeathUsed (fs : FilingStatus) (y : Option YearOfSpouseDeath) (widowedInTaxYear : Bool) :
    Filers.YearOfSpouseDeath :=
  match y with
  | some v => v.toCore
  | none =>
    if widowedInTaxYear then .diedInTaxYear
    else if fs == .qualifyingSurvivingSpouse then .diedTaxYearMinusOne
    else .diedBeforeTaxYearMinusTwo

/-- `credits.*_improper_claims_notice` to the Catala enumeration. -/
def EitcReceivedImproperClaimsNotice.toCore : EitcReceivedImproperClaimsNotice → Eitc.ImproperClaimsNotice
  | .twoYears => .twoYears | .tenYears => .tenYears | .zeroYears => .zeroYears
  | .notAnswered => .notAnswered

/-- `credits` (absent answers `false`, `NotAnswered`, `$0`). -/
def CreditAnswers.toCore (c : CreditAnswers) : Calculator.CreditAnswers :=
  { eitcQcOfAnother := c.eitcQcOfAnother.getD false
    eitcQcOfAnotherRequiredToFile := c.eitcQcOfAnotherRequiredToFile.getD false
    eitcQcOfAnotherIsFiling := c.eitcQcOfAnotherIsFiling.getD false
    eitcQcOfAnotherIsFilingRefundOnly := c.eitcQcOfAnotherIsFilingRefundOnly.getD false
    eitcHadImproperClaims := c.eitcHadImproperClaims.getD false
    eitcImproperClaimsDueToQc := c.eitcImproperClaimsDueToQc.getD false
    eitcImproperClaimTakenSinceDisallowal := c.eitcImproperClaimTakenSinceDisallowal.getD false
    eitcReceivedImproperClaimsNotice := c.eitcReceivedImproperClaimsNotice.toCore
    eitcImproperClaimsNoticeExpired := c.eitcImproperClaimsNoticeExpired.getD false
    receivedImproperClaims := c.receivedImproperClaims.getD false
    receivedImproperClaimsNotice := c.receivedImproperClaimsNotice.toCore
    improperClaimsNoticeExpired := c.improperClaimsNoticeExpired.getD false
    hasFiledCtcOdcSinceNoticeExpired := c.hasFiledCtcOdcSinceNoticeExpired.getD false
    hasDistributionsInLastThreeYears := c.hasDistributionsInLastThreeYears.getD false
    hasCurrentYearDistributions := c.hasCurrentYearDistributions.getD false
    hasSelfReportedContributions := c.hasSelfReportedContributions.getD false
    hasSelfReportedNonTaxablePayments := c.hasSelfReportedNonTaxablePayments.getD false
    selfReportedNonTaxablePaymentAmount := c.selfReportedNonTaxablePaymentAmount.getD 0 }

/-- `cdcc`. -/
def CdccInput.toCore (c : CdccInput) : Calculator.CdccInput :=
  { hasMfsSpouseEarnedIncome := c.hasMfsSpouseEarnedIncome.getD false
    writableMfsSpouseEarnedIncome := c.writableMfsSpouseEarnedIncome.getD 0
    writableTotalQualifiedDependentCareExpenses := c.writableTotalQualifiedDependentCareExpenses.getD 0
    writableCarryoverAmount := c.writableCarryoverAmount.getD 0
    writableForfeitedAmount := c.writableForfeitedAmount.getD 0
    hasCreditForPriorYearExpenses := c.hasCreditForPriorYearExpenses.getD false
    claimedCreditForPriorYearExpenses := c.claimedCreditForPriorYearExpenses.getD false
    claimedMaxCreditForPriorTaxYear := c.claimedMaxCreditForPriorTaxYear.getD false
    hasHouseholdEmployee := c.hasHouseholdEmployee.getD false
    benefitsFromSoleProprietorshipOrPartnership :=
      c.benefitsFromSoleProprietorshipOrPartnership.getD false }

/-- One Form 1095-A (same field names as the Catala `Ptc_allowed.Form1095A`). -/
def Form1095A.toCore (f : Form1095A) : PtcAllowed.Form1095A :=
  { writablePolicyStartDate := f.writablePolicyStartDate
    writablePolicyEndDate := f.writablePolicyEndDate
    writableSpecialPolicyModificationInStartingMonth := f.writableSpecialPolicyModificationInStartingMonth
    writableHasPolicyDateException := f.writableHasPolicyDateException
    hasCoverageMonths := f.hasCoverageMonths, coverageMonths := f.coverageMonths
    writablePremiumsOrSlcspChange := f.writablePremiumsOrSlcspChange
    hasChangeInCircumstance := f.hasChangeInCircumstance
    writablePtcAnnualPremium := f.writablePtcAnnualPremium
    writableSlcspAnnualPremium := f.writableSlcspAnnualPremium
    writableAptcAnnualAmount := f.writableAptcAnnualAmount
    writablePtcMonthlyPremium := f.writablePtcMonthlyPremium
    writablePtcMonthlySlcspPremium := f.writablePtcMonthlySlcspPremium
    writablePtcMonthlyAptcPremium := f.writablePtcMonthlyAptcPremium }

/-- `premium_tax_credit`. -/
def PtcInput.toCore (p : PtcInput) : Calculator.PtcInput :=
  { form1095As := p.form1095As.map Form1095A.toCore
    writableHasPtcQualifyingPlan := p.writableHasPtcQualifyingPlan.getD false
    writableHasAdvancedPtc := p.writableHasAdvancedPtc.getD false
    dependentTpSelfEnrolled := p.dependentTpSelfEnrolled.getD false
    dependentTpEnrolledSomeoneElse := p.dependentTpEnrolledSomeoneElse.getD false
    writableDependentTpOtherMembersArePartOfDifferentTaxFamily :=
      p.writableDependentTpOtherMembersArePartOfDifferentTaxFamily.getD false
    writableHasMfsException := p.writableHasMfsException.getD false
    writableClaimingMfsExceptionForFourthStraightYear :=
      p.writableClaimingMfsExceptionForFourthStraightYear.getD false
    writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus :=
      p.writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus.getD false
    writableHasEmployerSponsoredPlan := p.writableHasEmployerSponsoredPlan.getD false
    writableDependentsRequiredToFile := p.writableDependentsRequiredToFile.getD false
    writableSelfReportedHasMultiple1095As := p.writableSelfReportedHasMultiple1095As.getD false
    writableIsAdditionalPersonInEnrollmentFamily :=
      p.writableIsAdditionalPersonInEnrollmentFamily.getD false
    writableIsAdditionalPersonPartofDifferentTaxFamily :=
      p.writableIsAdditionalPersonPartofDifferentTaxFamily.getD false
    writableIsEnrolledWithOtherFamily := p.writableIsEnrolledWithOtherFamily.getD false
    writableHasImmigrationStatusNotEligibleForMarketplace :=
      p.writableHasImmigrationStatusNotEligibleForMarketplace.getD false
    writableWantsToUseAltCalculations := p.writableWantsToUseAltCalculations.getD false }

/-- One HSA distribution (same field names as the Catala `Hsa.HsaDistribution`). -/
def HsaDistribution.toCore (d : HsaDistribution) : Hsa.HsaDistribution :=
  { filer := d.filer.toCore, writableDistributionsRolloverBool := d.writableDistributionsRolloverBool
    writableDistributionsRolloverAmount := d.writableDistributionsRolloverAmount
    writableGrossDistribution := d.writableGrossDistribution
    hasWithdrawnExcessContributions := d.hasWithdrawnExcessContributions
    writableWithdrawnExcessContributionsAmount := d.writableWithdrawnExcessContributionsAmount
    writableEarningsOnExcessContributions := d.writableEarningsOnExcessContributions
    hsaDistributionCode := match d.hsaDistributionCode with
      | .normalDistribution => .normalDistribution | .excessContributions => .excessContributions
      | .disability => .disability | .deathOtherThanCode6 => .deathOtherThanCode6
      | .prohibitedTransaction => .prohibitedTransaction
      | .deathDistributionAfterYear => .deathDistributionAfterYear
    writableFmvOnDateOfDeath := d.writableFmvOnDateOfDeath
    writableQualifiedMedExpenses := d.writableQualifiedMedExpenses }

/-- `adjustments.hsa`. -/
def HsaInput.toCore (h : HsaInput) : Calculator.HsaInput :=
  { someFilerHadNonW2HsaActivity := h.someFilerHadNonW2HsaActivity.getD false
    writablePrimaryFilerHadNonW2HsaActivity := h.writablePrimaryFilerHadNonW2HsaActivity.getD false
    writableSecondaryFilerHadNonW2HsaActivity := h.writableSecondaryFilerHadNonW2HsaActivity.getD false
    hasHsaMedicalSavingsAccountType := h.hasHsaMedicalSavingsAccountType.getD false
    writableHasHsaExcessContributionsPreviousYear :=
      h.writableHasHsaExcessContributionsPreviousYear.getD false
    writableHasHsaWithdrawnExcessContributionsYesNo :=
      h.writableHasHsaWithdrawnExcessContributionsYesNo.getD false
    someFilersMadeTestingPeriodContribution := h.someFilersMadeTestingPeriodContribution.getD false
    someFilersHaveTestingPeriodAdditionalIncome :=
      h.someFilersHaveTestingPeriodAdditionalIncome.getD false
    hsaDistributions := h.hsaDistributions.map HsaDistribution.toCore }

/-- `social_security.federal_tax_withheld` padded with `$0` to the length of `net_benefits`
(`docs/api-mapping.md` "Padding"). -/
def padWithheld (net withheld : List Int) : List Int :=
  withheld ++ List.replicate (net.length - withheld.length) 0

/-- **The calculator input of the whole-return `Calculator` scope** (issue #48): the request
mapped field for field as the Catala scope `ApiCalculator` (`catala/api_calculator.catala_en`) and
`docs/api-mapping.md` say. The legacy `filing_details` flags are folded in (`treat_as_mfs` is
derived from the filing status and ignored; `is_widowed_in_tax_year` and
`mfj_deceased_spouse_reached_age65` only where the newer answers are absent;
`mfs_spouse_provides_no_benefits` counts as `mfs_spouse_has_gross_income`;
`treat_filers_as_dependents` makes both filers claimable; `has_foreign_accounts_or_trusts` is
or-ed into `screening.has_foreign_accounts`; `social_security.lived_apart_all_year` means the
spouses did not live together at any time). Total, no arithmetic, no rounding. The server calls
it only on a validated request (`Request.Valid`), but the mapping itself needs no hypothesis. -/
def toCalculatorInput (r : Request) : Calculator.CalculatorIn :=
  let d := r.filingDetails
  let treatAsDependent := d.treatFilersAsDependents.getD false
  let widowed := d.isWidowedInTaxYear.getD false
  let p := r.filers.primary.getD {}
  let s := r.filers.secondary.getD {}
  let fa := r.filingAnswers.getD {}
  let ssApart := (r.socialSecurity.map (·.livedApartAllYear)).getD false
  let net := (r.socialSecurity.map (·.netBenefits)).getD []
  let withheld := (r.socialSecurity.map (·.federalTaxWithheld)).getD []
  let edu := r.adjustments.educatorExpenses
  let sl := r.adjustments.studentLoanInterest
  let est := r.estimatedPayments
  let sc := r.screening.getD {}
  let b (o : Option Bool) := o.getD false
  { filingStatus := r.filingStatus
    filers :=
      { maritalStatus := maritalStatusUsed r.filingStatus fa.maritalStatus widowed
        yearOfSpouseDeath := yearOfSpouseDeathUsed r.filingStatus fa.yearOfSpouseDeath widowed
        primaryFiler := p.answers treatAsDependent false
        secondaryFiler := s.answers treatAsDependent (d.mfjDeceasedSpouseReachedAge65.getD false)
        secondaryFilerDateOfDeath := fa.secondaryFilerDateOfDeath
        primaryFilerPotentialClaimerFiledOnlyForRefund := fa.primaryFilerPotentialClaimerFiledOnlyForRefund
        mfjRequiredToFile := fa.mfjRequiredToFile
        mfjDependentsFilingForCredits := fa.mfjDependentsFilingForCredits
        livedTogetherAllYearWithSpouse := fa.livedTogetherAllYearWithSpouse && !ssApart
        spouseLivedTogetherMonths :=
          if ssApart then .livedApartAllYear else fa.spouseLivedTogetherMonths.toCore
        writableLivedApartLastSixMonths := fa.livedApartLastSixMonths
        writableSeparationAgreement := fa.separationAgreement
        canFileJointlyYearOfSpouseDeath :=
          fa.canFileJointlyYearOfSpouseDeath || r.filingStatus == .qualifyingSurvivingSpouse
        inRegisteredDomesticPartnership := fa.inRegisteredDomesticPartnership
        filerResidenceAndIncomeState := fa.residenceState.toCore
        spouseItemizes := fa.spouseItemizes
        mfsLivingSpouseFilingReturn := fa.mfsLivingSpouseFilingReturn
        mfsDeceasedSpouseFilingReturn := fa.mfsDeceasedSpouseFilingReturn
        mfsSpouseHasGrossIncome := fa.mfsSpouseHasGrossIncome || d.mfsSpouseProvidesNoBenefits.getD false
        mfsSpouse65OrOlder := d.mfsSpouse65OrOlder }
    primaryExtra := p.extra
    secondaryExtra := s.extra
    household := r.dependents.map Dependent.toCore
    income :=
      { w2s := r.w2s.map FormW2.toCore
        combatPayElection := d.combatPayElection.toCore
        combatPayElectionMade := d.combatPayElectionMade || d.combatPayElection != .noCombatPay
        interestReports := r.interestReports.map Form1099Int.toCore
        form1099Gs := r.form1099g.map Form1099G.toCore
        form1099Miscs := r.form1099misc.map Form1099Misc.toCore
        form1099Rs := r.form1099r.map Form1099R.toCore
        ssaNetBenefits := net
        ssaFederalTaxWithheld := padWithheld net withheld }
    adjustments :=
      { -- an absent `educator_expenses` decodes to its first enumeration value, `TpDid`, with $0
        wasK12Educators := ((edu.map EducatorExpenses.wasK12Educators).getD WhoDid.tpDid).toK12
        primaryEducatorExpensesWritable := (edu.map (·.primaryExpenses)).getD 0
        secondaryEducatorExpensesWritable := (edu.map (·.secondaryExpenses)).getD 0
        hadStudentLoanInterestPayments := (sl.map (·.hadPayments)).getD false
        studentLoansQualify := (sl.map (·.loansQualify)).getD false
        studentLoanInterestAmount := (sl.map (·.interestAmount)).getD 0
        hsa := (r.adjustments.hsa.getD {}).toCore }
    payments :=
      { paidEstimatedTaxesOrFromLastYear := (est.map (·.paidEstimatedTaxesOrFromLastYear)).getD false
        estimatedTaxPaymentWritable := (est.map (·.amount)).getD 0
        paidEstimatedTaxesOrFromLastYearUnderDifferentName :=
          (est.map (·.paidUnderDifferentName)).getD false
        paidEstimatedTaxesWithFormerSpouse :=
          ((est.bind EstimatedPayments.paidWithFormerSpouse).getD WhoDid.neither).toFormerSpouse }
    credits := (r.credits.getD {}).toCore
    cdccAnswers := (r.cdcc.getD {}).toCore
    ptcAnswers := (r.premiumTaxCredit.getD {}).toCore
    screening :=
      { memberVitals := r.dependents.map fun x =>
          { dateOfBirth := x.dateOfBirth, deceased := x.deceased, hasTinTypeNone := x.tinType == .noTin }
        incomeSourcesSupported := sc.incomeSourcesSupported
        receivedDigitalAssets := b sc.receivedDigitalAssets
        disposedDigitalAssets := b sc.disposedDigitalAssets
        hasForeignAccounts := b sc.hasForeignAccounts || d.hasForeignAccountsOrTrusts
        isForeignTrustsGrantor := b sc.isForeignTrustsGrantor
        hasForeignTrustsTransactions := b sc.hasForeignTrustsTransactions
        madeIraContributions := b sc.madeIraContributions
        w2Box15IncomeFromDifferentState := b sc.w2Box15IncomeFromDifferentState
        w2HasBox14NyrrtaKnockoutCode := b sc.w2HasBox14NyrrtaKnockoutCode
        w2HasRrtaCodesInBox14 := b sc.w2HasRrtaCodesInBox14
        livedInNy := b sc.livedInNy
        w2PaidYonkersTaxes := b sc.w2PaidYonkersTaxes
        partYearYonkersResident := b sc.partYearYonkersResident
        primaryFilerFormsAnotherState := b sc.primaryFilerFormsAnotherState
        receivedAlaskaPfd := b sc.receivedAlaskaPfd
        spouseReceivedAlaskaPfd := b sc.spouseReceivedAlaskaPfd
        spouseLivesInOtherOrMultipleStates := b sc.spouseLivesInOtherOrMultipleStates
        spouseFormsAnotherState := b sc.spouseFormsAnotherState
        isAfterTaxDayAndNotResubmitting := b sc.isAfterTaxDayAndNotResubmitting
        isAfterResubmissionDeadline := b sc.isAfterResubmissionDeadline } }

/-- A request part the response comments on (`Warning.path` and its text). -/
structure RequestNote where
  /-- RFC 6901 pointer of the request part. -/
  path : String
  /-- English text. -/
  message : String
  deriving DecidableEq, Repr

/-- Schema 1.0 `filing_details` fields that `Calculator` derives from the
filers' facts (`docs/api-mapping.md`, "Legacy `filing_details` fields"): the
request sets them (`some`), the response says `field_superseded`. Every other section of the
request is read by `toCalculatorInput` (schema 1.2.0: no `section_not_used`). -/
def supersededFields (r : Request) : List RequestNote :=
  let d := r.filingDetails
  let mk (k : String) : RequestNote :=
    ⟨s!"/filing_details/{k}", s!"filing_details.{k} is superseded in schema 1.2.0: the calculator derives it from the filers' answers (docs/api-mapping.md)."⟩
  (if d.treatAsMfs.isSome then [mk "treat_as_mfs"] else []) ++
  (if d.isWidowedInTaxYear.isSome then [mk "is_widowed_in_tax_year"] else []) ++
  (if d.mfjDeceasedSpouseReachedAge65.isSome then [mk "mfj_deceased_spouse_reached_age65"] else []) ++
  (if d.mfsSpouseProvidesNoBenefits.isSome then [mk "mfs_spouse_provides_no_benefits"] else []) ++
  (if d.treatFilersAsDependents.isSome then [mk "treat_filers_as_dependents"] else [])

end UsTax.Api
