import UsTax.Interest
import UsTax.FormW2s
import UsTax.Unemployment
import UsTax.Form1099Misc
import UsTax.Form1099Rs
import UsTax.SocialSecurity
import UsTax.EstimatedPayments
import UsTax.Hsa
import UsTax.Api.Reasons

/-!
# Knockouts A: income, HSA and process unsupported situations (issues #36, #48)

Lean implementation of `catala/knockouts_income.catala_en` (module `Knockouts_income`, scope
`KnockoutsIncome`), written by hand from the Catala source under strategy (c) of
`docs/catala-to-lean.md`, in the order of the Catala file. Direct File refuses a return it does
not support (`flow.xml` `/flowIsKnockedOut`, an `Any` over about 98 facts). This module

1. runs the merged income modules once (`Interest`, `FormW2s`, `Unemployment`, `Form1099Miscs`,
   `Form1099Rs`, `SocialSecurity`, `EstimatedPayments`, `Hsa`) on the inputs the return computes
   upstream (the AGI, the W-2 HSA contributions, ...);
2. defines the knockouts of `income.xml`, `flow.xml` and `formW2s.xml` that no merged module owns
   (`LocalKnockouts`);
3. exposes one structure per module, a flag per module, the list of reasons that fired
   (`firedKnockouts`, in the order of the Catala `KnockoutReason`) and the combined
   `unsupportedIncomeOrHsa`.

The reason type is the generated `UsTax.Api.KnockoutReason` (`UsTax/Api/Reasons.lean`, made by
`scripts/gen_lean_api_reasons.py` from `api/knockout-reasons.json`, itself generated from the
Catala enumeration `Knockouts_income.KnockoutReason`): the constructors are the Catala ones in
lower camel case, in the same order, so a fired reason is the API `code` with no further mapping.

| Catala (`Knockouts_income`)            | Lean (`UsTax.KnockoutsIncome`)                      |
|----------------------------------------|-----------------------------------------------------|
| enum `KnockoutReason`                  | `UsTax.Api.KnockoutReason` (generated)              |
| struct `KnockoutEntry`                 | `KnockoutEntry`                                     |
| structs `InterestKnockouts` ... `LocalKnockouts` | the same names, fields in lower camel case |
| `scope KnockoutsIncome`                | `KnockoutsIncomeIn` → `KnockoutsIncomeOut` (`knockoutsIncome`) |
| internal `has_foreign_accounts_or_trusts`, `has_income_in_scope` | `hasForeignAccountsOrTrusts`, `hasIncomeInScope` |
| `map each e among (list of e among t such that e.fired) to e.reason` | `firedOf t` |

Every assertion of `catala/tests/test_knockouts_income.catala_en` that names a single knockout is
checked by a `#guard` below (one return per module plus the local ones), with the clean return.
-/

namespace UsTax.KnockoutsIncome

open Money
open Api (KnockoutReason)

/-- Catala `KnockoutEntry`: one row of the table behind `fired_knockouts`. -/
structure KnockoutEntry where
  reason : KnockoutReason
  fired : Bool
  deriving DecidableEq, Repr

/-- `map each e among (list of e among table such that e.fired) to e.reason`. -/
def firedOf (table : List KnockoutEntry) : List KnockoutReason :=
  (table.filter (·.fired)).map (·.reason)

/-- The fired list is empty exactly when no row fired. -/
theorem firedOf_eq_nil_iff (t : List KnockoutEntry) :
    firedOf t = [] ↔ t.any (·.fired) = false := by
  induction t with
  | nil => simp [firedOf]
  | cons e t ih =>
    cases h : e.fired <;> simp_all [firedOf, ]

/-- Catala `InterestKnockouts` (`interest.xml`). -/
structure InterestKnockouts where
  koHasRequiredFactaFilings : Bool
  koFlowKnockoutHasEarlyWithdrawlPenalty : Bool
  koFlowKnockoutHasBonds : Bool
  koFlowKnockoutHasForeignTaxPaid : Bool
  koFlowKnockoutWithholdingUnsupportedState : Bool
  koFlowKnockoutStateTaxWithheld : Bool
  koHasInterestIncomeAndAgiAboveThresholdForMfs : Bool
  koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss : Bool
  koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh : Bool
  koFlowKnockoutTaxExemptInterest : Bool
  deriving DecidableEq, Repr

/-- Catala `FormW2Knockouts` (`formW2s.xml`). -/
structure FormW2Knockouts where
  koKnockoutForBox12Value : Bool
  koKnockoutForBox12Dependency : Bool
  koFlowKnockoutAllocatedTips : Bool
  koFlowKnockoutStatutoryEmployee : Bool
  koFlowKnockoutThirdPartySickPay : Bool
  koFlowKnockoutNonQualifiedPlans : Bool
  koKnockoutMedicareWages : Bool
  koAnyFilerExceedsMaxOasdiWages : Bool
  deriving DecidableEq, Repr

/-- Catala `UnemploymentKnockouts` (`unemployment.xml`). -/
structure UnemploymentKnockouts where
  koFlowKnockout1099GRepayTooHigh : Bool
  koFlowKnockoutUnemploymentCompensationUnsupportedState : Bool
  deriving DecidableEq, Repr

/-- Catala `Form1099MiscKnockouts` (not in `flow.xml`). -/
structure Form1099MiscKnockouts where
  koNonPfd1099Misc : Bool
  deriving DecidableEq, Repr

/-- Catala `Form1099RKnockouts` (`form1099Rs.xml`). -/
structure Form1099RKnockouts where
  koFlowKnockoutRetirementTaxableAmountNotDetermined : Bool
  koFlowKnockoutRetirementTaxableAmountBlank : Bool
  koFlowKnockoutRetirementTotalDistribution : Bool
  koKnockoutForForm1099RBox8Value : Bool
  koKnockoutForForm1099RBox8Percentage : Bool
  koKnockoutForForm1099RBox9aPercentage : Bool
  koFlowKnockoutRetirementCapitalGain : Bool
  koFlowKnockoutRetirementNetUnrealizedAppreciation : Bool
  koFlowKnockoutRetirementAmountAllocableToIrr : Bool
  koFlowKnockoutRetirementFactaFilingRequirement : Bool
  koFlowKnockoutForRollover : Bool
  koFlowKnockoutForDeathBenefitPaymentDate : Bool
  koFlowKnockoutRetirementQualifiedDisasterDistribution : Bool
  koFlowKnockoutRetirementPublicSafetyOfficer : Bool
  koFlowKnockoutForPreTaxToPostTaxRollover : Bool
  koFlowKnockoutBox15 : Bool
  koKnockoutForForm1099RDistributionCode : Bool
  koKnockoutIraSepSimple : Bool
  koKnockoutTaxablePensionRollover : Bool
  koKnockoutIndirectRollover : Bool
  koKnockoutTaxableAmountNotDetermined : Bool
  deriving DecidableEq, Repr

/-- Catala `SocialSecurityKnockouts` (`socialSecurity.xml`). -/
structure SocialSecurityKnockouts where
  koSocialSecurityRepaymentOver3k : Bool
  deriving DecidableEq, Repr

/-- Catala `EstimatedPaymentsKnockouts` (`estimatedPayments.xml`). -/
structure EstimatedPaymentsKnockouts where
  koKnockoutPaidEstimatedTaxesUnderDifferentLastName : Bool
  deriving DecidableEq, Repr

/-- Catala `HsaKnockouts` (`hsa.xml`). -/
structure HsaKnockouts where
  koNoPaymentsHsaDistribution : Bool
  koHsaMedicalSavingsAccountType : Bool
  koHsaDistributionCode : Bool
  koOtherCoveragePartOfYear : Bool
  koOtherCoverageWholeYear : Bool
  koEarningsOnExcessContributions : Bool
  koHsaTestingPeriodAdditionalIncomeYes : Bool
  koHsaUnqualifiedDistributions : Bool
  koHsaDistributionFmv : Bool
  koMaritalChangeAffectsContributionLimit : Bool
  koMfsLine6Check : Bool
  koHsaContributionsOverLimit : Bool
  koHsaExcessContributions : Bool
  koContributionSummaryNoneAllowed : Bool
  koHdhpCoverageStatusNotNeeded : Bool
  koNotEnrolledInHdhp : Bool
  koMadeQualifiedHsaFundingDistribution : Bool
  koHsaCoverage : Bool
  koFilerIsDependentAndContributesToHsa : Bool
  koHasHsaDistributionsWithoutActivity : Bool
  koHsaDistributionsSecondaryFilerUsedWithoutMfj : Bool
  deriving DecidableEq, Repr

/-- Catala `LocalKnockouts`: the knockouts no merged module owns. -/
structure LocalKnockouts where
  koIncomeSourcesNotSupported : Bool
  koNotDigitalAssets : Bool
  koHasForeignAccountsOrTrusts : Bool
  koMadeIraContributions : Bool
  koFlowKnockoutBox15IncomeFromDifferentState : Bool
  koHasABox14NyrrtaValueWeKnockout : Bool
  koFlowKnockoutHasRrtaCodesInBox14NotInNy : Bool
  koKnockoutYonkersPartYear : Bool
  koFlowKnockoutUnsupportedState : Bool
  koIsTooLateToFileOrResubmit : Bool
  koKnockoutHasNoPaymentsOrCredits : Bool
  deriving DecidableEq, Repr

/-- Inputs of `scope KnockoutsIncome`, in Catala order (names in lower camel case). -/
structure KnockoutsIncomeIn where
  -- used by several modules
  filingStatus : FilingStatus
  agi : Int
  primaryFilerCanBeClaimed : Bool
  secondaryFilerCanBeClaimed : Bool
  paidEstimatedTaxesOrFromLastYear : Bool
  /-- DF `/knockoutHasNoPaymentsOrCredits`, computed by `Form1040`. -/
  knockoutHasNoPaymentsOrCredits : Bool
  -- income.xml
  incomeSourcesSupported : Bool
  receivedDigitalAssets : Bool
  disposedDigitalAssets : Bool
  hasForeignAccounts : Bool
  isForeignTrustsGrantor : Bool
  hasForeignTrustsTransactions : Bool
  madeIraContributions : Bool
  -- Interest, W-2
  interestReports : List Interest.InterestReport
  w2s : List FormW2s.FormW2
  combatPayElection : FormW2s.CombatPayElection
  w2Box15IncomeFromDifferentState : Bool
  w2HasBox14NyrrtaKnockoutCode : Bool
  w2HasRrtaCodesInBox14 : Bool
  livedInNy : Bool
  w2PaidYonkersTaxes : Bool
  partYearYonkersResident : Bool
  -- state scoping
  filerResidenceAndIncomeState : ScopedState
  primaryFilerFormsAnotherState : Bool
  receivedAlaskaPfd : Bool
  spouseReceivedAlaskaPfd : Bool
  treatAsMfj : Bool
  spouseLivesInOtherOrMultipleStates : Bool
  spouseFormsAnotherState : Bool
  -- 1099-G, 1099-MISC, 1099-R
  form1099Gs : List Unemployment.Form1099G
  form1099Miscs : List Form1099Misc.Form1099Misc
  form1099Rs : List Form1099Rs.Form1099R
  -- Social Security
  reportNetBenefits : List Int
  livedApartAllYear : Bool
  line1z : Int
  line2a : Int
  line2b : Int
  line3b : Int
  line4b : Int
  line5b : Int
  line7CapitalGains : Int
  line8OtherIncome : Int
  adjustmentsExcludingStudentLoanInterest : Int
  -- estimated payments
  estimatedTaxPaymentWritable : Int
  paidEstimatedTaxesOrFromLastYearUnderDifferentName : Bool
  paidEstimatedTaxesWithFormerSpouse : EstimatedPayments.PaidWithFormerSpouse
  -- HSA
  isFilingStatusMfj : Bool
  isMarried : Bool
  isSingle : Bool
  primaryFilerAge55OrOlder : Bool
  secondaryFilerAge55OrOlder : Bool
  primaryFilerTotalHsaContributionsFromW2s : Int
  secondaryFilerTotalHsaContributionsFromW2s : Int
  hasPrimaryFilerHsaContributionsFromW2s : Bool
  hasSecondaryFilerHsaContributionsFromW2s : Bool
  taxExemptInterest : Int
  pensionsAndAnnuities : Int
  socialSecurityBenefits : Int
  hsaPrimaryFiler : Hsa.HsaFilerAnswers
  hsaSecondaryFiler : Hsa.HsaFilerAnswers
  someFilerHadNonW2HsaActivity : Bool
  writablePrimaryFilerHadNonW2HsaActivity : Bool
  writableSecondaryFilerHadNonW2HsaActivity : Bool
  hasHsaMedicalSavingsAccountType : Bool
  writableHasHsaExcessContributionsPreviousYear : Bool
  writableHasHsaWithdrawnExcessContributionsYesNo : Bool
  someFilersMadeTestingPeriodContribution : Bool
  someFilersHaveTestingPeriodAdditionalIncome : Bool
  hsaDistributions : List Hsa.HsaDistribution
  -- process
  isAfterTaxDayAndNotResubmitting : Bool
  isAfterResubmissionDeadline : Bool

/-- Outputs of `scope KnockoutsIncome`. -/
structure KnockoutsIncomeOut where
  interestKnockouts : InterestKnockouts
  formW2Knockouts : FormW2Knockouts
  unemploymentKnockouts : UnemploymentKnockouts
  form1099MiscKnockouts : Form1099MiscKnockouts
  form1099RKnockouts : Form1099RKnockouts
  socialSecurityKnockouts : SocialSecurityKnockouts
  estimatedPaymentsKnockouts : EstimatedPaymentsKnockouts
  hsaKnockouts : HsaKnockouts
  localKnockouts : LocalKnockouts
  unsupportedInterest : Bool
  unsupportedW2s : Bool
  unsupportedUnemployment : Bool
  unsupportedMisc : Bool
  unsupportedRs : Bool
  unsupportedSs : Bool
  unsupportedEp : Bool
  unsupportedHsa : Bool
  unsupportedLocal : Bool
  unsupportedIncomeOrHsa : Bool
  knockoutTable : List KnockoutEntry
  firedKnockouts : List KnockoutReason

section Variables

variable (i : KnockoutsIncomeIn)

/-- DF `income.xml` `/hasForeignAccountsOrTrusts`. -/
def hasForeignAccountsOrTrusts : Bool :=
  i.hasForeignAccounts || i.isForeignTrustsGrantor || i.hasForeignTrustsTransactions

/-- DF `filers.xml` `/hasIncomeInScope`: one in-scope state, no form from another state, an
Alaska PFD only for an Alaska resident; the same tests for the spouse on a joint return. -/
def hasIncomeInScope : Bool :=
  !(i.filerResidenceAndIncomeState == .noneOfThese ||
    i.filerResidenceAndIncomeState == .moreThanOne ||
    i.primaryFilerFormsAnotherState ||
    (i.receivedAlaskaPfd && i.filerResidenceAndIncomeState != .ak) ||
    (i.treatAsMfj && i.spouseReceivedAlaskaPfd && i.filerResidenceAndIncomeState != .ak) ||
    (i.treatAsMfj && i.spouseLivesInOtherOrMultipleStates) ||
    (i.treatAsMfj && i.spouseFormsAnotherState))

/-- Sub-scope `interest` (`flow_has_seen_deductions` true: the AGI knockouts are evaluated). -/
def interest : Interest.InterestOut :=
  Interest.interest
    { interestReports := i.interestReports, hasForeignAccountsOrTrusts := hasForeignAccountsOrTrusts i,
      filingStatus := i.filingStatus, agi := i.agi, flowHasSeenDeductions := true }

/-- Sub-scope `w2`. -/
def w2 : FormW2s.FormW2sOut :=
  FormW2s.formW2s
    { w2s := i.w2s, filingStatus := i.filingStatus,
      primaryFilerCanBeClaimed := i.primaryFilerCanBeClaimed,
      secondaryFilerCanBeClaimed := i.secondaryFilerCanBeClaimed,
      combatPayElection := i.combatPayElection }

/-- Sub-scope `unemp`. -/
def unemp : Unemployment.UnemploymentOut := Unemployment.unemployment { form1099Gs := i.form1099Gs }

/-- Sub-scope `misc`. -/
def misc : Form1099Misc.Form1099MiscsOut :=
  Form1099Misc.form1099Miscs { form1099Miscs := i.form1099Miscs }

/-- Sub-scope `rs`. -/
def rs : Form1099Rs.Form1099RsOut := Form1099Rs.form1099Rs { forms := i.form1099Rs }

/-- Sub-scope `ss`. -/
def ss : SocialSecurity.SocialSecurityOut :=
  SocialSecurity.socialSecurity
    { reportNetBenefits := i.reportNetBenefits, filingStatus := i.filingStatus,
      livedApartAllYear := i.livedApartAllYear, line1z := i.line1z, line2b := i.line2b,
      line2a := i.line2a, line3b := i.line3b, line4b := i.line4b, line5b := i.line5b,
      line7CapitalGains := i.line7CapitalGains, line8OtherIncome := i.line8OtherIncome,
      adjustmentsExcludingStudentLoanInterest := i.adjustmentsExcludingStudentLoanInterest }

/-- Sub-scope `ep`. -/
def ep : EstimatedPayments.EstimatedPaymentsOut :=
  EstimatedPayments.estimatedPayments
    { paidEstimatedTaxesOrFromLastYear := i.paidEstimatedTaxesOrFromLastYear,
      estimatedTaxPaymentWritable := i.estimatedTaxPaymentWritable,
      paidEstimatedTaxesOrFromLastYearUnderDifferentName :=
        i.paidEstimatedTaxesOrFromLastYearUnderDifferentName,
      paidEstimatedTaxesWithFormerSpouse := i.paidEstimatedTaxesWithFormerSpouse }

/-- The input of sub-scope `hsa`. -/
def hsaIn : Hsa.HsaIn :=
  { isFilingStatusMfj := i.isFilingStatusMfj, isMarried := i.isMarried, isSingle := i.isSingle
    primaryFilerAge55OrOlder := i.primaryFilerAge55OrOlder
    secondaryFilerAge55OrOlder := i.secondaryFilerAge55OrOlder
    primaryFilerCanBeClaimed := i.primaryFilerCanBeClaimed
    secondaryFilerCanBeClaimed := i.secondaryFilerCanBeClaimed
    primaryFilerTotalHsaContributionsFromW2s := i.primaryFilerTotalHsaContributionsFromW2s
    secondaryFilerTotalHsaContributionsFromW2s := i.secondaryFilerTotalHsaContributionsFromW2s
    hasPrimaryFilerHsaContributionsFromW2s := i.hasPrimaryFilerHsaContributionsFromW2s
    hasSecondaryFilerHsaContributionsFromW2s := i.hasSecondaryFilerHsaContributionsFromW2s
    knockoutHasNoPaymentsOrCredits := i.knockoutHasNoPaymentsOrCredits
    paidEstimatedTaxesOrFromLastYear := i.paidEstimatedTaxesOrFromLastYear
    taxExemptInterest := i.taxExemptInterest
    pensionsAndAnnuities := i.pensionsAndAnnuities
    socialSecurityBenefits := i.socialSecurityBenefits
    primaryFiler := i.hsaPrimaryFiler, secondaryFiler := i.hsaSecondaryFiler
    someFilerHadNonW2HsaActivity := i.someFilerHadNonW2HsaActivity
    writablePrimaryFilerHadNonW2HsaActivity := i.writablePrimaryFilerHadNonW2HsaActivity
    writableSecondaryFilerHadNonW2HsaActivity := i.writableSecondaryFilerHadNonW2HsaActivity
    hasHsaMedicalSavingsAccountType := i.hasHsaMedicalSavingsAccountType
    writableHasHsaExcessContributionsPreviousYear := i.writableHasHsaExcessContributionsPreviousYear
    writableHasHsaWithdrawnExcessContributionsYesNo :=
      i.writableHasHsaWithdrawnExcessContributionsYesNo
    someFilersMadeTestingPeriodContribution := i.someFilersMadeTestingPeriodContribution
    someFilersHaveTestingPeriodAdditionalIncome := i.someFilersHaveTestingPeriodAdditionalIncome
    hsaDistributions := i.hsaDistributions }

/-- Sub-scope `hsa`. -/
def hsa : Hsa.HsaOut := Hsa.hsa (hsaIn i)

/-- Catala `interest_knockouts`. -/
def interestKnockouts : InterestKnockouts :=
  let o := interest i
  { koHasRequiredFactaFilings := o.koHasRequiredFactaFilings
    koFlowKnockoutHasEarlyWithdrawlPenalty := o.koFlowKnockoutHasEarlyWithdrawlPenalty
    koFlowKnockoutHasBonds := o.koFlowKnockoutHasBonds
    koFlowKnockoutHasForeignTaxPaid := o.koFlowKnockoutHasForeignTaxPaid
    koFlowKnockoutWithholdingUnsupportedState := o.koFlowKnockoutWithholdingUnsupportedState
    koFlowKnockoutStateTaxWithheld := o.koFlowKnockoutStateTaxWithheld
    koHasInterestIncomeAndAgiAboveThresholdForMfs := o.koHasInterestIncomeAndAgiAboveThresholdForMfs
    koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss :=
      o.koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss
    koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh :=
      o.koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh
    koFlowKnockoutTaxExemptInterest := o.koFlowKnockoutTaxExemptInterest }

/-- Catala `form_w2_knockouts`. -/
def formW2Knockouts : FormW2Knockouts :=
  let o := w2 i
  { koKnockoutForBox12Value := o.koKnockoutForBox12Value
    koKnockoutForBox12Dependency := o.koKnockoutForBox12Dependency
    koFlowKnockoutAllocatedTips := o.koFlowKnockoutAllocatedTips
    koFlowKnockoutStatutoryEmployee := o.koFlowKnockoutStatutoryEmployee
    koFlowKnockoutThirdPartySickPay := o.koFlowKnockoutThirdPartySickPay
    koFlowKnockoutNonQualifiedPlans := o.koFlowKnockoutNonQualifiedPlans
    koKnockoutMedicareWages := o.koKnockoutMedicareWages
    koAnyFilerExceedsMaxOasdiWages := o.koAnyFilerExceedsMaxOasdiWages }

/-- Catala `unemployment_knockouts`. -/
def unemploymentKnockouts : UnemploymentKnockouts :=
  { koFlowKnockout1099GRepayTooHigh := (unemp i).koFlowKnockout1099GRepayTooHigh
    koFlowKnockoutUnemploymentCompensationUnsupportedState :=
      (unemp i).koFlowKnockoutUnemploymentCompensationUnsupportedState }

/-- Catala `form1099_misc_knockouts`. -/
def form1099MiscKnockouts : Form1099MiscKnockouts := { koNonPfd1099Misc := (misc i).koNonPfd1099Misc }

/-- Catala `form1099_r_knockouts`. -/
def form1099RKnockouts : Form1099RKnockouts :=
  let o := rs i
  { koFlowKnockoutRetirementTaxableAmountNotDetermined :=
      o.koFlowKnockoutRetirementTaxableAmountNotDetermined
    koFlowKnockoutRetirementTaxableAmountBlank := o.koFlowKnockoutRetirementTaxableAmountBlank
    koFlowKnockoutRetirementTotalDistribution := o.koFlowKnockoutRetirementTotalDistribution
    koKnockoutForForm1099RBox8Value := o.koKnockoutForForm1099RBox8Value
    koKnockoutForForm1099RBox8Percentage := o.koKnockoutForForm1099RBox8Percentage
    koKnockoutForForm1099RBox9aPercentage := o.koKnockoutForForm1099RBox9aPercentage
    koFlowKnockoutRetirementCapitalGain := o.koFlowKnockoutRetirementCapitalGain
    koFlowKnockoutRetirementNetUnrealizedAppreciation :=
      o.koFlowKnockoutRetirementNetUnrealizedAppreciation
    koFlowKnockoutRetirementAmountAllocableToIrr := o.koFlowKnockoutRetirementAmountAllocableToIrr
    koFlowKnockoutRetirementFactaFilingRequirement := o.koFlowKnockoutRetirementFactaFilingRequirement
    koFlowKnockoutForRollover := o.koFlowKnockoutForRollover
    koFlowKnockoutForDeathBenefitPaymentDate := o.koFlowKnockoutForDeathBenefitPaymentDate
    koFlowKnockoutRetirementQualifiedDisasterDistribution :=
      o.koFlowKnockoutRetirementQualifiedDisasterDistribution
    koFlowKnockoutRetirementPublicSafetyOfficer := o.koFlowKnockoutRetirementPublicSafetyOfficer
    koFlowKnockoutForPreTaxToPostTaxRollover := o.koFlowKnockoutForPreTaxToPostTaxRollover
    koFlowKnockoutBox15 := o.koFlowKnockoutBox15
    koKnockoutForForm1099RDistributionCode := o.koKnockoutForForm1099RDistributionCode
    koKnockoutIraSepSimple := o.koKnockoutIraSepSimple
    koKnockoutTaxablePensionRollover := o.koKnockoutTaxablePensionRollover
    koKnockoutIndirectRollover := o.koKnockoutIndirectRollover
    koKnockoutTaxableAmountNotDetermined := o.koKnockoutTaxableAmountNotDetermined }

/-- Catala `social_security_knockouts`. -/
def socialSecurityKnockouts : SocialSecurityKnockouts :=
  { koSocialSecurityRepaymentOver3k := (ss i).repaymentOver3k }

/-- Catala `estimated_payments_knockouts`. -/
def estimatedPaymentsKnockouts : EstimatedPaymentsKnockouts :=
  { koKnockoutPaidEstimatedTaxesUnderDifferentLastName :=
      (ep i).koKnockoutPaidEstimatedTaxesUnderDifferentLastName }

/-- Catala `hsa_knockouts`. -/
def hsaKnockouts : HsaKnockouts :=
  let o := hsa i
  { koNoPaymentsHsaDistribution := o.koNoPaymentsHsaDistribution
    koHsaMedicalSavingsAccountType := o.koHsaMedicalSavingsAccountType
    koHsaDistributionCode := o.koHsaDistributionCode
    koOtherCoveragePartOfYear := o.koOtherCoveragePartOfYear
    koOtherCoverageWholeYear := o.koOtherCoverageWholeYear
    koEarningsOnExcessContributions := o.koEarningsOnExcessContributions
    koHsaTestingPeriodAdditionalIncomeYes := o.koHsaTestingPeriodAdditionalIncomeYes
    koHsaUnqualifiedDistributions := o.koHsaUnqualifiedDistributions
    koHsaDistributionFmv := o.koHsaDistributionFmv
    koMaritalChangeAffectsContributionLimit := o.koMaritalChangeAffectsContributionLimit
    koMfsLine6Check := o.koMfsLine6Check
    koHsaContributionsOverLimit := o.koHsaContributionsOverLimit
    koHsaExcessContributions := o.koHsaExcessContributions
    koContributionSummaryNoneAllowed := o.koContributionSummaryNoneAllowed
    koHdhpCoverageStatusNotNeeded := o.koHdhpCoverageStatusNotNeeded
    koNotEnrolledInHdhp := o.koNotEnrolledInHdhp
    koMadeQualifiedHsaFundingDistribution := o.koMadeQualifiedHsaFundingDistribution
    koHsaCoverage := o.koHsaCoverage
    koFilerIsDependentAndContributesToHsa := o.koFilerIsDependentAndContributesToHsa
    koHasHsaDistributionsWithoutActivity := o.koHasHsaDistributionsWithoutActivity
    koHsaDistributionsSecondaryFilerUsedWithoutMfj := o.koHsaDistributionsSecondaryFilerUsedWithoutMfj }

/-- Catala `local_knockouts`: `income.xml`, the `formW2s.xml` state facts, `filers.xml`
unsupported state, `flow.xml` too late and no payments or credits. -/
def localKnockouts : LocalKnockouts :=
  { koIncomeSourcesNotSupported := !i.incomeSourcesSupported
    koNotDigitalAssets := i.receivedDigitalAssets || i.disposedDigitalAssets
    koHasForeignAccountsOrTrusts := hasForeignAccountsOrTrusts i
    koMadeIraContributions := i.madeIraContributions
    koFlowKnockoutBox15IncomeFromDifferentState := i.w2Box15IncomeFromDifferentState
    koHasABox14NyrrtaValueWeKnockout := i.w2HasBox14NyrrtaKnockoutCode
    koFlowKnockoutHasRrtaCodesInBox14NotInNy := i.w2HasRrtaCodesInBox14 && !i.livedInNy
    koKnockoutYonkersPartYear := i.w2PaidYonkersTaxes && i.partYearYonkersResident
    koFlowKnockoutUnsupportedState := !hasIncomeInScope i
    koIsTooLateToFileOrResubmit := i.isAfterTaxDayAndNotResubmitting || i.isAfterResubmissionDeadline
    koKnockoutHasNoPaymentsOrCredits := i.knockoutHasNoPaymentsOrCredits }

/-- Catala `unsupported_local`. -/
def unsupportedLocal : Bool :=
  let l := localKnockouts i
  l.koIncomeSourcesNotSupported || l.koNotDigitalAssets || l.koHasForeignAccountsOrTrusts ||
    l.koMadeIraContributions || l.koFlowKnockoutBox15IncomeFromDifferentState ||
    l.koHasABox14NyrrtaValueWeKnockout || l.koFlowKnockoutHasRrtaCodesInBox14NotInNy ||
    l.koKnockoutYonkersPartYear || l.koFlowKnockoutUnsupportedState ||
    l.koIsTooLateToFileOrResubmit || l.koKnockoutHasNoPaymentsOrCredits

/-- Catala `unsupported_income_or_hsa`: every module flag and the local knockouts. -/
def unsupportedIncomeOrHsa : Bool :=
  (interest i).unsupported || (w2 i).unsupported || (unemp i).unsupported ||
    (misc i).unsupported || (rs i).unsupported || (ss i).repaymentOver3k ||
    (ep i).unsupported || (hsa i).unsupported || unsupportedLocal i

/-- Catala `knockout_table`, in the order of `KnockoutReason`. -/
def knockoutTable : List KnockoutEntry :=
  let a := interestKnockouts i
  let w := formW2Knockouts i
  let u := unemploymentKnockouts i
  let m := form1099MiscKnockouts i
  let r := form1099RKnockouts i
  let s := socialSecurityKnockouts i
  let e := estimatedPaymentsKnockouts i
  let h := hsaKnockouts i
  let l := localKnockouts i
  [⟨.hasRequiredFactaFilings, a.koHasRequiredFactaFilings⟩,
   ⟨.flowKnockoutHasEarlyWithdrawlPenalty, a.koFlowKnockoutHasEarlyWithdrawlPenalty⟩,
   ⟨.flowKnockoutHasBonds, a.koFlowKnockoutHasBonds⟩,
   ⟨.flowKnockoutHasForeignTaxPaid, a.koFlowKnockoutHasForeignTaxPaid⟩,
   ⟨.flowKnockoutWithholdingUnsupportedState, a.koFlowKnockoutWithholdingUnsupportedState⟩,
   ⟨.flowKnockoutStateTaxWithheld, a.koFlowKnockoutStateTaxWithheld⟩,
   ⟨.hasInterestIncomeAndAgiAboveThresholdForMfs, a.koHasInterestIncomeAndAgiAboveThresholdForMfs⟩,
   ⟨.hasInterestIncomeAndAgiAboveThresholdForMfjOrQss,
     a.koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss⟩,
   ⟨.hasInterestIncomeAndAgiAboveThresholdForSingleOrHoh,
     a.koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh⟩,
   ⟨.flowKnockoutTaxExemptInterest, a.koFlowKnockoutTaxExemptInterest⟩,
   ⟨.knockoutForBox12Value, w.koKnockoutForBox12Value⟩,
   ⟨.knockoutForBox12Dependency, w.koKnockoutForBox12Dependency⟩,
   ⟨.flowKnockoutAllocatedTips, w.koFlowKnockoutAllocatedTips⟩,
   ⟨.flowKnockoutStatutoryEmployee, w.koFlowKnockoutStatutoryEmployee⟩,
   ⟨.flowKnockoutThirdPartySickPay, w.koFlowKnockoutThirdPartySickPay⟩,
   ⟨.flowKnockoutNonQualifiedPlans, w.koFlowKnockoutNonQualifiedPlans⟩,
   ⟨.knockoutMedicareWages, w.koKnockoutMedicareWages⟩,
   ⟨.anyFilerExceedsMaxOasdiWages, w.koAnyFilerExceedsMaxOasdiWages⟩,
   ⟨.flowKnockout1099GRepayTooHigh, u.koFlowKnockout1099GRepayTooHigh⟩,
   ⟨.flowKnockoutUnemploymentCompensationUnsupportedState,
     u.koFlowKnockoutUnemploymentCompensationUnsupportedState⟩,
   ⟨.extraNonPfd1099Misc, m.koNonPfd1099Misc⟩,
   ⟨.flowKnockoutRetirementTaxableAmountNotDetermined,
     r.koFlowKnockoutRetirementTaxableAmountNotDetermined⟩,
   ⟨.flowKnockoutRetirementTaxableAmountBlank, r.koFlowKnockoutRetirementTaxableAmountBlank⟩,
   ⟨.flowKnockoutRetirementTotalDistribution, r.koFlowKnockoutRetirementTotalDistribution⟩,
   ⟨.knockoutForForm1099RBox8Value, r.koKnockoutForForm1099RBox8Value⟩,
   ⟨.knockoutForForm1099RBox8Percentage, r.koKnockoutForForm1099RBox8Percentage⟩,
   ⟨.knockoutForForm1099RBox9aPercentage, r.koKnockoutForForm1099RBox9aPercentage⟩,
   ⟨.flowKnockoutRetirementCapitalGain, r.koFlowKnockoutRetirementCapitalGain⟩,
   ⟨.flowKnockoutRetirementNetUnrealizedAppreciation,
     r.koFlowKnockoutRetirementNetUnrealizedAppreciation⟩,
   ⟨.flowKnockoutRetirementAmountAllocableToIRR, r.koFlowKnockoutRetirementAmountAllocableToIrr⟩,
   ⟨.flowKnockoutRetirementFactaFilingRequirement, r.koFlowKnockoutRetirementFactaFilingRequirement⟩,
   ⟨.flowKnockoutForRollover, r.koFlowKnockoutForRollover⟩,
   ⟨.flowKnockoutForDeathBenefitPaymentDate, r.koFlowKnockoutForDeathBenefitPaymentDate⟩,
   ⟨.flowKnockoutRetirementQualifiedDisasterDistribution,
     r.koFlowKnockoutRetirementQualifiedDisasterDistribution⟩,
   ⟨.flowKnockoutRetirementPublicSafetyOfficer, r.koFlowKnockoutRetirementPublicSafetyOfficer⟩,
   ⟨.flowKnockoutForPreTaxToPostTaxRollover, r.koFlowKnockoutForPreTaxToPostTaxRollover⟩,
   ⟨.flowKnockoutBox15, r.koFlowKnockoutBox15⟩,
   ⟨.knockoutForForm1099RDistributionCode, r.koKnockoutForForm1099RDistributionCode⟩,
   ⟨.knockoutIraSepSimple, r.koKnockoutIraSepSimple⟩,
   ⟨.knockoutTaxablePensionRollover, r.koKnockoutTaxablePensionRollover⟩,
   ⟨.knockoutIndirectRollover, r.koKnockoutIndirectRollover⟩,
   ⟨.knockoutTaxableAmountNotDetermined, r.koKnockoutTaxableAmountNotDetermined⟩,
   ⟨.socialSecurityBenefitsAreLossGreaterThan3k, s.koSocialSecurityRepaymentOver3k⟩,
   ⟨.knockoutPaidEstimatedTaxesUnderDifferentLastName,
     e.koKnockoutPaidEstimatedTaxesUnderDifferentLastName⟩,
   ⟨.knockoutNoPaymentsHsaDistribution, h.koNoPaymentsHsaDistribution⟩,
   ⟨.flowKnockoutHsaMedicalSavingsAccountType, h.koHsaMedicalSavingsAccountType⟩,
   ⟨.flowKnockoutHsaDistributionCode, h.koHsaDistributionCode⟩,
   ⟨.flowKnockoutOtherCoveragePartOfYear, h.koOtherCoveragePartOfYear⟩,
   ⟨.flowKnockoutOtherCoverageWholeYear, h.koOtherCoverageWholeYear⟩,
   ⟨.flowKnockoutEarningsOnExcessContributions, h.koEarningsOnExcessContributions⟩,
   ⟨.flowKnockoutHsaTestingPeriodAdditionalIncomeYes, h.koHsaTestingPeriodAdditionalIncomeYes⟩,
   ⟨.flowKnockoutHsaUnqualifiedDistributions, h.koHsaUnqualifiedDistributions⟩,
   ⟨.flowKnockoutHsaDistributionFMV, h.koHsaDistributionFmv⟩,
   ⟨.flowKnockoutMaritalChangeAffectsContributionLimit, h.koMaritalChangeAffectsContributionLimit⟩,
   ⟨.flowKnockoutMFSLine6Check, h.koMfsLine6Check⟩,
   ⟨.flowHsaContributionsOverLimitKnockout, h.koHsaContributionsOverLimit⟩,
   ⟨.flowKnockoutHsaExcessContributions, h.koHsaExcessContributions⟩,
   ⟨.flowKnockoutContributionSummaryNoneAllowed, h.koContributionSummaryNoneAllowed⟩,
   ⟨.flowKnockoutHdhpCoverageStatusNotNeeded, h.koHdhpCoverageStatusNotNeeded⟩,
   ⟨.flowKnockoutNotEnrolledInHdhp, h.koNotEnrolledInHdhp⟩,
   ⟨.flowKnockoutMadeQualifiedHsaFundingDistribution, h.koMadeQualifiedHsaFundingDistribution⟩,
   ⟨.flowKnockoutHsaCoverage, h.koHsaCoverage⟩,
   ⟨.flowKnockoutFilerIsDependentAndContributesToHsa, h.koFilerIsDependentAndContributesToHsa⟩,
   ⟨.extraHsaDistributionsWithoutActivity, h.koHasHsaDistributionsWithoutActivity⟩,
   ⟨.extraHsaDistributionsSecondaryFilerWithoutMfj, h.koHsaDistributionsSecondaryFilerUsedWithoutMfj⟩,
   ⟨.incomeSourcesNotSupported, l.koIncomeSourcesNotSupported⟩,
   ⟨.notDigitalAssets, l.koNotDigitalAssets⟩,
   ⟨.hasForeignAccountsOrTrusts, l.koHasForeignAccountsOrTrusts⟩,
   ⟨.madeIraContributions, l.koMadeIraContributions⟩,
   ⟨.flowKnockoutBox15IncomeFromDifferentState, l.koFlowKnockoutBox15IncomeFromDifferentState⟩,
   ⟨.hasABox14NYRRTAValueWeKnockout, l.koHasABox14NyrrtaValueWeKnockout⟩,
   ⟨.flowKnockoutHasRRTACodesInBox14NotInNY, l.koFlowKnockoutHasRrtaCodesInBox14NotInNy⟩,
   ⟨.knockoutYonkersPartYear, l.koKnockoutYonkersPartYear⟩,
   ⟨.flowKnockoutUnsupportedState, l.koFlowKnockoutUnsupportedState⟩,
   ⟨.isTooLateToFileOrResubmit, l.koIsTooLateToFileOrResubmit⟩,
   ⟨.knockoutHasNoPaymentsOrCredits, l.koKnockoutHasNoPaymentsOrCredits⟩]

end Variables

/-- Catala `scope KnockoutsIncome`. -/
def knockoutsIncome (i : KnockoutsIncomeIn) : KnockoutsIncomeOut :=
  { interestKnockouts := interestKnockouts i
    formW2Knockouts := formW2Knockouts i
    unemploymentKnockouts := unemploymentKnockouts i
    form1099MiscKnockouts := form1099MiscKnockouts i
    form1099RKnockouts := form1099RKnockouts i
    socialSecurityKnockouts := socialSecurityKnockouts i
    estimatedPaymentsKnockouts := estimatedPaymentsKnockouts i
    hsaKnockouts := hsaKnockouts i
    localKnockouts := localKnockouts i
    unsupportedInterest := (interest i).unsupported
    unsupportedW2s := (w2 i).unsupported
    unsupportedUnemployment := (unemp i).unsupported
    unsupportedMisc := (misc i).unsupported
    unsupportedRs := (rs i).unsupported
    unsupportedSs := (ss i).repaymentOver3k
    unsupportedEp := (ep i).unsupported
    unsupportedHsa := (hsa i).unsupported
    unsupportedLocal := unsupportedLocal i
    unsupportedIncomeOrHsa := unsupportedIncomeOrHsa i
    knockoutTable := knockoutTable i
    firedKnockouts := firedOf (knockoutTable i) }

/-! ### Unit tests (`catala/tests/test_knockouts_income.catala_en`)

`clean` is the Catala helper `Case`: a single filer living in Florida, no forms, income sources
supported, a payment so that `/knockoutHasNoPaymentsOrCredits` is false. Each case sets one
condition and checks that the combined flag is true and the reason list is exactly that one
reason; the clean return has none. -/

/-- HSA answers of a filer with no HSA activity. -/
def noHsa : Hsa.HsaFilerAnswers :=
  { writablePrimaryFilerHasMadeContributionsToHsa := false,
    writableSecondaryFilerHasMadeContributionsToHsa := false,
    enrolledInMedicare := .medicareNoneOfYear, hsaHdhpCoverageStatus := .hdhpAllYear,
    typeOfHdhp := .selfOnly, hadOtherCoverageIneligibleForHsa := .otherCoverageNoneOfYear,
    writableMfsLine6Check := false,
    writableChangeInMaritalStatusDuringTaxYear := .wasNotMarriedNorDivorcedThisYear,
    writableMaritalChangeAffectContributionLimitBool := false,
    hasMadeQualifiedHsaFundingDistribution := false,
    writableHsaNonemployerContributionsTaxYear := 0,
    writableHsaNonemployerContributionsTaxYearPlusOne := 0 }

/-- The clean return of the Catala test helper. -/
def clean : KnockoutsIncomeIn :=
  { filingStatus := .single, agi := 5_000_000, primaryFilerCanBeClaimed := false,
    secondaryFilerCanBeClaimed := false, paidEstimatedTaxesOrFromLastYear := false,
    knockoutHasNoPaymentsOrCredits := false, incomeSourcesSupported := true,
    receivedDigitalAssets := false, disposedDigitalAssets := false, hasForeignAccounts := false,
    isForeignTrustsGrantor := false, hasForeignTrustsTransactions := false,
    madeIraContributions := false, interestReports := [], w2s := [],
    combatPayElection := .noCombatPay, w2Box15IncomeFromDifferentState := false,
    w2HasBox14NyrrtaKnockoutCode := false, w2HasRrtaCodesInBox14 := false, livedInNy := false,
    w2PaidYonkersTaxes := false, partYearYonkersResident := false,
    filerResidenceAndIncomeState := .fl, primaryFilerFormsAnotherState := false,
    receivedAlaskaPfd := false, spouseReceivedAlaskaPfd := false, treatAsMfj := false,
    spouseLivesInOtherOrMultipleStates := false, spouseFormsAnotherState := false,
    form1099Gs := [], form1099Miscs := [], form1099Rs := [], reportNetBenefits := [],
    livedApartAllYear := false, line1z := 0, line2a := 0, line2b := 0, line3b := 0, line4b := 0,
    line5b := 0, line7CapitalGains := 0, line8OtherIncome := 0,
    adjustmentsExcludingStudentLoanInterest := 0, estimatedTaxPaymentWritable := 0,
    paidEstimatedTaxesOrFromLastYearUnderDifferentName := false,
    paidEstimatedTaxesWithFormerSpouse := .neither, isFilingStatusMfj := false, isMarried := false,
    isSingle := true, primaryFilerAge55OrOlder := false, secondaryFilerAge55OrOlder := false,
    primaryFilerTotalHsaContributionsFromW2s := 0, secondaryFilerTotalHsaContributionsFromW2s := 0,
    hasPrimaryFilerHsaContributionsFromW2s := false, hasSecondaryFilerHsaContributionsFromW2s := false,
    taxExemptInterest := 0, pensionsAndAnnuities := 0, socialSecurityBenefits := 0,
    hsaPrimaryFiler := noHsa, hsaSecondaryFiler := noHsa, someFilerHadNonW2HsaActivity := false,
    writablePrimaryFilerHadNonW2HsaActivity := false, writableSecondaryFilerHadNonW2HsaActivity := false,
    hasHsaMedicalSavingsAccountType := false, writableHasHsaExcessContributionsPreviousYear := false,
    writableHasHsaWithdrawnExcessContributionsYesNo := false,
    someFilersMadeTestingPeriodContribution := false,
    someFilersHaveTestingPeriodAdditionalIncome := false, hsaDistributions := [],
    isAfterTaxDayAndNotResubmitting := false, isAfterResubmissionDeadline := false }

/-- `c` fires exactly `[r]`, and the combined flag is set. -/
def firesOnly (c : KnockoutsIncomeIn) (r : KnockoutReason) : Bool :=
  let o := knockoutsIncome c
  o.unsupportedIncomeOrHsa && o.firedKnockouts == [r]

-- TestClean
#guard !(knockoutsIncome clean).unsupportedIncomeOrHsa
#guard (knockoutsIncome clean).firedKnockouts == []
#guard (knockoutsIncome clean).knockoutTable.length == 76
-- income.xml, local knockouts
#guard firesOnly { clean with incomeSourcesSupported := false } .incomeSourcesNotSupported
#guard firesOnly { clean with receivedDigitalAssets := true } .notDigitalAssets
#guard firesOnly { clean with disposedDigitalAssets := true } .notDigitalAssets
#guard firesOnly { clean with hasForeignAccounts := true } .hasForeignAccountsOrTrusts
#guard firesOnly { clean with isForeignTrustsGrantor := true } .hasForeignAccountsOrTrusts
#guard firesOnly { clean with hasForeignTrustsTransactions := true } .hasForeignAccountsOrTrusts
#guard firesOnly { clean with madeIraContributions := true } .madeIraContributions
#guard firesOnly { clean with w2Box15IncomeFromDifferentState := true }
  .flowKnockoutBox15IncomeFromDifferentState
#guard firesOnly { clean with w2HasBox14NyrrtaKnockoutCode := true } .hasABox14NYRRTAValueWeKnockout
#guard firesOnly { clean with w2HasRrtaCodesInBox14 := true } .flowKnockoutHasRRTACodesInBox14NotInNY
#guard !(knockoutsIncome { clean with w2HasRrtaCodesInBox14 := true, livedInNy := true }).unsupportedIncomeOrHsa
#guard firesOnly { clean with w2PaidYonkersTaxes := true, partYearYonkersResident := true }
  .knockoutYonkersPartYear
#guard !(knockoutsIncome { clean with w2PaidYonkersTaxes := true }).unsupportedIncomeOrHsa
#guard firesOnly { clean with filerResidenceAndIncomeState := .noneOfThese } .flowKnockoutUnsupportedState
#guard firesOnly { clean with filerResidenceAndIncomeState := .moreThanOne } .flowKnockoutUnsupportedState
#guard firesOnly { clean with primaryFilerFormsAnotherState := true } .flowKnockoutUnsupportedState
#guard firesOnly { clean with receivedAlaskaPfd := true } .flowKnockoutUnsupportedState
#guard !(knockoutsIncome
  { clean with receivedAlaskaPfd := true, filerResidenceAndIncomeState := .ak }).unsupportedIncomeOrHsa
#guard firesOnly { clean with treatAsMfj := true, spouseFormsAnotherState := true }
  .flowKnockoutUnsupportedState
#guard !(knockoutsIncome { clean with spouseFormsAnotherState := true }).unsupportedIncomeOrHsa
#guard firesOnly { clean with isAfterTaxDayAndNotResubmitting := true } .isTooLateToFileOrResubmit
#guard firesOnly { clean with isAfterResubmissionDeadline := true } .isTooLateToFileOrResubmit
#guard firesOnly { clean with knockoutHasNoPaymentsOrCredits := true } .knockoutHasNoPaymentsOrCredits
-- module knockouts: interest, W-2, 1099-G, 1099-MISC, 1099-R, SSA-1099, estimated payments, HSA
#guard firesOnly { clean with interestReports :=
  [{ has1099 := true, writable1099Amount := 10_000, writableEarlyWithdrawlPenaltyAmount := 500 }] }
  .flowKnockoutHasEarlyWithdrawlPenalty
#guard firesOnly { clean with interestReports :=
  [{ has1099 := true, writable1099Amount := 10_000, factaFilingRequired := true }] }
  .hasRequiredFactaFilings
#guard firesOnly { clean with agi := 30_000_000, interestReports :=
  [{ has1099 := true, writable1099Amount := 10_000 }] }
  .hasInterestIncomeAndAgiAboveThresholdForSingleOrHoh
#guard firesOnly { clean with w2s := [{ writableWages := 5_000_000, statutoryEmployee := true }] }
  .flowKnockoutStatutoryEmployee
#guard firesOnly { clean with w2s := [{ writableWages := 5_000_000, writableAllocatedTips := 10_000 }] }
  .flowKnockoutAllocatedTips
#guard firesOnly { clean with form1099Gs := [{ amount := 100_000, stateIsDifferentState := true }] }
  .flowKnockoutUnemploymentCompensationUnsupportedState
#guard firesOnly { clean with form1099Miscs := [{ isAlaskaPfd := false, writableOtherIncome := 10_000 }] }
  .extraNonPfd1099Misc
#guard firesOnly { clean with form1099Rs :=
  [{ writableGrossDistribution := 100_000, writableTaxableAmount := 100_000, iraSepSimple := true }] }
  .knockoutIraSepSimple
#guard firesOnly { clean with reportNetBenefits := [-400_000] } .socialSecurityBenefitsAreLossGreaterThan3k
#guard firesOnly
  { clean with
    paidEstimatedTaxesOrFromLastYear := true, estimatedTaxPaymentWritable := 10_000,
    paidEstimatedTaxesOrFromLastYearUnderDifferentName := true }
  .knockoutPaidEstimatedTaxesUnderDifferentLastName
-- the reasons follow the table order whatever the input order
#guard (knockoutsIncome { clean with madeIraContributions := true, incomeSourcesSupported := false }).firedKnockouts ==
  [.incomeSourcesNotSupported, .madeIraContributions]

end UsTax.KnockoutsIncome
