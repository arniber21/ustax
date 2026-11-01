import UsTax.Form1040
import UsTax.Filers
import UsTax.QualifyingChild
import UsTax.DependentsBenefitSplit
import UsTax.QualifyingRelative
import UsTax.HohQssPersons
import UsTax.FilingStatus
import UsTax.Unemployment
import UsTax.Form1099Misc
import UsTax.Form1099Rs
import UsTax.SocialSecurity
import UsTax.EducatorAdjustment
import UsTax.StudentLoanAdjustment
import UsTax.EstimatedPayments
import UsTax.Hsa
import UsTax.Cdcc
import UsTax.ElderlyAndDisabled
import UsTax.SaversCredit
import UsTax.Eitc
import UsTax.CtcOdc
import UsTax.PtcFamily
import UsTax.PtcAllowed
import UsTax.PtcNet
import UsTax.KnockoutsIncome
import UsTax.KnockoutsHousehold

/-!
# The calculator: one return, from the answers to the refund (issues #38, #48)

Lean implementation of `catala/calculator.catala_en` (module `Calculator`, scopes
`EitcQualifyingChildTest`, `Calculator` and the helper `Form1040Pass`), written by hand from the
Catala source under strategy (c) of `docs/catala-to-lean.md`, in the order of the Catala file.
`Calculator` is the top-level scope: it takes the answers to Direct File's writable questions and
computes the whole Form 1040 with every merged module plugged into the slots of
`Form1040.form1040`. No value is taken from the oracle.

## Stages (a staged single pass, `catala/CONVENTIONS.md` section 7)

Each stage reads only earlier stages; every module is called on its own input, so a module can
be called twice (once early for amounts, once late for knockouts) without a cycle.

1. **Filers** (`Filers.filers` with `eligibleForHoh := false`, and the per-filer `FilerFacts`).
2. **Household**: qualifying children, benefit split, HoH/QSS persons, CTC/ODC dependents and
   the EITC qualifying child test of this file (`eitcQualifyingChildTest`).
3. **Filing status eligibility** (`FilingStatusMod.eligibility`): `eligibleForQss`,
   `eligibleForHoh` and `ko_filing_status_not_eligible`.
4. **Income**: W-2s, 1099-INT, 1099-G, 1099-MISC, 1099-R, Form 2441 Part III (line 1e),
   Social Security.
5. **Adjustments**: educator expenses, HSA, then (after total income) student loan interest.
6. **Form 1040, AGI pass** (`fAgi`): lines 1 to 18 with the income and adjustment slots filled.
6b. **Premium tax credit** (Form 8962 from the AGI): line 17 joins the tax (`fTax`); the net PTC
   is line 31.
7. **Credits** in Direct File's order: CDCC, Schedule R (limit: line 18 less CDCC), Saver's
   (line 18 less CDCC and Schedule R), EITC, CTC/ODC and ACTC (Schedule 8812, reads the EITC).
8. **Form 1040, final pass** (`fFinal`): every slot filled.
9. **Knockouts**: `unsupported` is the disjunction of every module's knockouts;
   `firedKnockouts` lists the reasons (income/HSA/process first, then household/credit/PTC).

The five Form 1040 calls compute the same lines 1 to 18 wherever both define them:

| Call           | Slots filled                                                  | Read by |
|----------------|---------------------------------------------------------------|---------|
| `fIncome`      | 1z (with 1e), 2b, 5b, 8                                       | Social Security worksheet |
| `fTotalIncome` | + 6b, educator, HSA                                           | student loan MAGI (line 9) |
| `fAgi`         | + student loan interest                                       | PTC, credits (AGI, line 1z) |
| `fTax`         | + line 17 (excess APTC repayment)                             | credits (line 18) |
| `fFinal`       | + credits, withholding, estimated payments, net PTC           | the outputs |

## Catala ↔ Lean

| Catala (`Calculator`)                         | Lean (`UsTax.Calculator`)                       |
|-----------------------------------------------|-------------------------------------------------|
| enum `FilerSsnEmploymentValidity`, structs `FilerTin` ... `ScreeningAnswers` | the same names |
| enum `CalculatorKnockout`, struct `CalculatorKnockoutEntry` | the same names                |
| `scope EitcQualifyingChildTest`               | `EitcQualifyingChildTestIn` → `…Out` (`eitcQualifyingChildTest`) |
| `ssn_valid_for_eitc`                          | `ssnValidForEitc`                               |
| structs `Form1040Base`, `Form1040Slots`, `scope Form1040Pass` | the same names; `form1040Pass` |
| `scope Calculator`                            | `CalculatorIn` → `CalculatorOut` (`calculator`) |
| internal `x` of `Calculator`                  | the `let x` of `calculator`, also a field of `CalculatorOut` when a proof or the knockouts read it |
| `R.round_dollar`, `Money.sum`, `number of`    | `Money.roundDollar`, `Money.sum`, `Money.countBy` |

Money is `Int` cents. The Catala assertion `cdcc.taxable_benefits = cdcc_benefits.taxable_benefits`
is the `#guard`ed property `taxableBenefitsAgree` on the test returns below.
-/

namespace UsTax.Calculator

open Money

/-! ## Declarations -/

/-- DF `/primaryFilerSsnEmploymentValidityOptions`: what the filer's Social Security card says
about work. -/
inductive FilerSsnEmploymentValidity where
  | neither | notValid | validOnlyWithDhsAuthorization
  deriving DecidableEq, Repr, Inhabited

/-- A filer's TIN facts that the earned income credit reads (IRC 32(m)). -/
structure FilerTin where
  /-- DF `/filers/*/tin/isSSN`. -/
  tinIsSsn : Bool := true
  /-- DF `/primaryFilerSsnEmploymentValidity` (asked only of a non-citizen). -/
  ssnEmploymentValidity : FilerSsnEmploymentValidity := .neither
  /-- DF `/filers/*/writableHasSSNOnlyForBenefits`. -/
  hasSsnOnlyForBenefits : Bool := false
  deriving DecidableEq, Repr

/-- A filer's CDCC answers (`Cdcc.CdccFiler` without the W-2 amounts). -/
structure CdccFilerAnswers where
  electCombatPayForCredit : Bool := false
  electCombatPayForBenefits : Bool := false
  dependentCarePlanMaximum : Int := 0
  isDisabled : Bool := false
  deemedIncomeMonthEarnings : List Int := []
  hasDependentCareExpenses : Bool := false
  expensesPaidToQualifyingProvider : Bool := false
  writableQualifyingExpenseAmount : Int := 0
  deriving DecidableEq, Repr

/-- The per-filer answers `Filers.FilerAnswers` does not carry. -/
structure FilerExtra where
  tin : FilerTin
  /-- DF `/filers/*/isStudent`. -/
  isStudent : Bool
  /-- Schedule R answers; `hasW2Wages` is recomputed from the W-2s. -/
  disability : ElderlyAndDisabled.DisabilityAnswers
  /-- The HSA answers of the filer. -/
  hsa : Hsa.HsaFilerAnswers
  /-- The CDCC answers of the filer. -/
  cdcc : CdccFilerAnswers

/-- A household member's CDCC answers (`Cdcc.CdccAnswers` without the upkeep answer). -/
structure CdccMemberAnswers where
  unableToCareForSelf : Bool := false
  hasDependentCareExpenses : Bool := false
  expensesPaidToQualifyingProvider : Bool := false
  writableQualifyingExpenseAmount : Int := 0
  deriving DecidableEq, Repr

/-- The return-level CDCC answers (Form 2441 inputs). -/
structure CdccInput where
  hasMfsSpouseEarnedIncome : Bool := false
  writableMfsSpouseEarnedIncome : Int := 0
  writableTotalQualifiedDependentCareExpenses : Int := 0
  writableCarryoverAmount : Int := 0
  writableForfeitedAmount : Int := 0
  hasCreditForPriorYearExpenses : Bool := false
  claimedCreditForPriorYearExpenses : Bool := false
  claimedMaxCreditForPriorTaxYear : Bool := false
  hasHouseholdEmployee : Bool := false
  benefitsFromSoleProprietorshipOrPartnership : Bool := false
  deriving DecidableEq, Repr

/-- The `ptc.xml` writable answers and the Forms 1095-A. -/
structure PtcInput where
  form1095As : List PtcAllowed.Form1095A := []
  writableHasPtcQualifyingPlan : Bool := false
  writableHasAdvancedPtc : Bool := false
  dependentTpSelfEnrolled : Bool := false
  dependentTpEnrolledSomeoneElse : Bool := false
  writableDependentTpOtherMembersArePartOfDifferentTaxFamily : Bool := false
  writableHasMfsException : Bool := false
  writableClaimingMfsExceptionForFourthStraightYear : Bool := false
  writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus : Bool := false
  writableHasEmployerSponsoredPlan : Bool := false
  writableDependentsRequiredToFile : Bool := false
  writableSelfReportedHasMultiple1095As : Bool := false
  writableIsAdditionalPersonInEnrollmentFamily : Bool := false
  writableIsAdditionalPersonPartofDifferentTaxFamily : Bool := false
  writableIsEnrolledWithOtherFamily : Bool := false
  writableHasImmigrationStatusNotEligibleForMarketplace : Bool := false
  writableWantsToUseAltCalculations : Bool := false

/-- The answers `Filers.Filers` takes, except the filing status and `eligible_for_hoh`. -/
structure FilersInput where
  maritalStatus : Filers.MaritalStatus
  yearOfSpouseDeath : Filers.YearOfSpouseDeath
  primaryFiler : Filers.FilerAnswers
  secondaryFiler : Filers.FilerAnswers
  secondaryFilerDateOfDeath : Date
  primaryFilerPotentialClaimerFiledOnlyForRefund : Bool
  mfjRequiredToFile : Bool
  mfjDependentsFilingForCredits : Bool
  livedTogetherAllYearWithSpouse : Bool
  spouseLivedTogetherMonths : Filers.SpouseLivedTogetherMonths
  writableLivedApartLastSixMonths : Bool
  writableSeparationAgreement : Bool
  canFileJointlyYearOfSpouseDeath : Bool
  inRegisteredDomesticPartnership : Bool
  filerResidenceAndIncomeState : ScopedState
  spouseItemizes : Bool
  mfsLivingSpouseFilingReturn : Bool
  mfsDeceasedSpouseFilingReturn : Bool
  mfsSpouseHasGrossIncome : Bool
  /-- DF `/MFSSpouse65OrOlder` (standard deduction). -/
  mfsSpouse65OrOlder : Bool

/-- One member of DF `/familyAndHousehold`. -/
structure HouseholdMember where
  /-- Qualifying child, dependent and benefit-split answers. -/
  dependent : QualifyingRelative.Member
  /-- HoH and QSS upkeep answers. -/
  upkeep : HohQssPersons.UpkeepAnswers
  /-- DF `/familyAndHousehold/*/ssnEmploymentValidity`. -/
  ssnEmploymentValidity : CtcOdc.SsnEmploymentValidity
  /-- DF `/familyAndHousehold/*/ssnOnlyForFederallyFundedBenefit`. -/
  ssnOnlyForFederallyFundedBenefit : Bool
  /-- DF `/familyAndHousehold/*/monthsLivedWithTPInUS` as a number of months (0 if not asked). -/
  monthsLivedWithTpInUs : Int
  /-- CDCC answers. -/
  cdcc : CdccMemberAnswers

/-- Income forms. -/
structure IncomeInput where
  w2s : List FormW2s.FormW2
  combatPayElection : FormW2s.CombatPayElection
  combatPayElectionMade : Bool
  interestReports : List Interest.InterestReport
  form1099Gs : List Unemployment.Form1099G
  form1099Miscs : List Form1099Misc.Form1099Misc
  form1099Rs : List Form1099Rs.Form1099R
  /-- SSA-1099 box 5, per report. -/
  ssaNetBenefits : List Int
  /-- SSA-1099 box 6, per report. -/
  ssaFederalTaxWithheld : List Int

/-- The return-level HSA answers (`hsa.xml`). -/
structure HsaInput where
  someFilerHadNonW2HsaActivity : Bool := false
  writablePrimaryFilerHadNonW2HsaActivity : Bool := false
  writableSecondaryFilerHadNonW2HsaActivity : Bool := false
  hasHsaMedicalSavingsAccountType : Bool := false
  writableHasHsaExcessContributionsPreviousYear : Bool := false
  writableHasHsaWithdrawnExcessContributionsYesNo : Bool := false
  someFilersMadeTestingPeriodContribution : Bool := false
  someFilersHaveTestingPeriodAdditionalIncome : Bool := false
  hsaDistributions : List Hsa.HsaDistribution := []

/-- Schedule 1 adjustments. -/
structure AdjustmentsInput where
  wasK12Educators : EducatorAdjustment.K12EducatorOptions := .neither
  primaryEducatorExpensesWritable : Int := 0
  secondaryEducatorExpensesWritable : Int := 0
  hadStudentLoanInterestPayments : Bool := false
  studentLoansQualify : Bool := false
  studentLoanInterestAmount : Int := 0
  hsa : HsaInput := {}

/-- Estimated tax payments. -/
structure PaymentsInput where
  paidEstimatedTaxesOrFromLastYear : Bool := false
  estimatedTaxPaymentWritable : Int := 0
  paidEstimatedTaxesOrFromLastYearUnderDifferentName : Bool := false
  paidEstimatedTaxesWithFormerSpouse : EstimatedPayments.PaidWithFormerSpouse := .neither

/-- The credit questions. -/
structure CreditAnswers where
  eitcQcOfAnother : Bool := false
  eitcQcOfAnotherRequiredToFile : Bool := false
  eitcQcOfAnotherIsFiling : Bool := false
  eitcQcOfAnotherIsFilingRefundOnly : Bool := false
  eitcHadImproperClaims : Bool := false
  eitcImproperClaimsDueToQc : Bool := false
  eitcImproperClaimTakenSinceDisallowal : Bool := false
  eitcReceivedImproperClaimsNotice : Eitc.ImproperClaimsNotice := .notAnswered
  eitcImproperClaimsNoticeExpired : Bool := false
  receivedImproperClaims : Bool := false
  receivedImproperClaimsNotice : Eitc.ImproperClaimsNotice := .notAnswered
  improperClaimsNoticeExpired : Bool := false
  hasFiledCtcOdcSinceNoticeExpired : Bool := false
  hasDistributionsInLastThreeYears : Bool := false
  hasCurrentYearDistributions : Bool := false
  hasSelfReportedContributions : Bool := false
  /-- Schedule R line 13b. -/
  hasSelfReportedNonTaxablePayments : Bool := false
  selfReportedNonTaxablePaymentAmount : Int := 0

/-- The screening questions that only feed knockouts. -/
structure ScreeningAnswers where
  memberVitals : List KnockoutsHousehold.MemberVitals := []
  incomeSourcesSupported : Bool := true
  receivedDigitalAssets : Bool := false
  disposedDigitalAssets : Bool := false
  hasForeignAccounts : Bool := false
  isForeignTrustsGrantor : Bool := false
  hasForeignTrustsTransactions : Bool := false
  madeIraContributions : Bool := false
  w2Box15IncomeFromDifferentState : Bool := false
  w2HasBox14NyrrtaKnockoutCode : Bool := false
  w2HasRrtaCodesInBox14 : Bool := false
  livedInNy : Bool := false
  w2PaidYonkersTaxes : Bool := false
  partYearYonkersResident : Bool := false
  primaryFilerFormsAnotherState : Bool := false
  receivedAlaskaPfd : Bool := false
  spouseReceivedAlaskaPfd : Bool := false
  spouseLivesInOtherOrMultipleStates : Bool := false
  spouseFormsAnotherState : Bool := false
  isAfterTaxDayAndNotResubmitting : Bool := false
  isAfterResubmissionDeadline : Bool := false

/-- Every knockout the calculator can report: from `Knockouts_income` or `Knockouts_household`. -/
inductive CalculatorKnockout where
  | incomeOrHsa (r : Api.KnockoutReason)
  | household (r : Api.KnockoutReason)
  deriving DecidableEq, Repr

/-- The `KnockoutReason` inside either wrapper (the API `code`). -/
def CalculatorKnockout.reason : CalculatorKnockout → Api.KnockoutReason
  | .incomeOrHsa r => r
  | .household r => r

/-- One row of the calculator's knockout table. -/
structure CalculatorKnockoutEntry where
  reason : CalculatorKnockout
  fired : Bool
  deriving DecidableEq, Repr

/-! ## EITC qualifying children

IRC 32(c)(3) (`sources/statute/irc-32.html`): a qualifying child of 152(c) without 152(c)(1)(D)
(support) and 152(e); a married child only if the filer is entitled to the deduction
(DF-BUG(30): the statute's "entitled", not DF's "claimed"); principal place of abode in the United
States for more than half the year; a child need not be claimed (DF-BUG(29)). 32(m): an SSN not
issued only for a federally funded benefit. -/

/-- Inputs of `scope EitcQualifyingChildTest`. -/
structure EitcQualifyingChildTestIn where
  member : HouseholdMember
  minimumFilerDateOfBirth : Date
  treatFilersAsDependents : Bool
  eitherFilerUsCitizenOrNational : Bool
  treatAsMfj : Bool

/-- Outputs of `scope EitcQualifyingChildTest`. -/
structure EitcQualifyingChildTestOut where
  dep : QualifyingRelative.DependentTestOut
  /-- DF `/familyAndHousehold/*/livedWithTpInUsMostOfYear`. -/
  livedWithTpInUsMostOfYear : Bool
  /-- DF `/familyAndHousehold/*/eitcRelAgeResJointTest`. -/
  eitcRelAgeResJointTest : Bool
  /-- DF `/familyAndHousehold/*/eitcQualifyingChild`. -/
  eitcQualifyingChild : Bool
  /-- DF `/familyAndHousehold/*/ssnValidForEITCCalculation`. -/
  ssnValidForEitcCalculation : Bool
  /-- DF `/familyAndHousehold/*/eitcQualifyingChildForCalculation`. -/
  eitcQualifyingChildForCalculation : Bool

/-- Catala `scope EitcQualifyingChildTest`. -/
def eitcQualifyingChildTest (i : EitcQualifyingChildTestIn) : EitcQualifyingChildTestOut :=
  let m := i.member
  let dep := QualifyingRelative.dependentTest
    { member := m.dependent, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth,
      treatFilersAsDependents := i.treatFilersAsDependents,
      eitherFilerUsCitizenOrNational := i.eitherFilerUsCitizenOrNational, treatAsMfj := i.treatAsMfj }
  -- 32(c)(3)(C): principal place of abode in the United States for more than half the year
  let lived := dep.qc.residencyTest && decide (m.monthsLivedWithTpInUs ≥ 6)
  let relAge := dep.qc.qcRelationshipTest && dep.qc.ageTest && lived && dep.qc.jointReturnTest
  -- DF-BUG(29), DF-BUG(30)
  let qc := relAge && !dep.split.disqualifiedDueToParentalCustody &&
    (!dep.isQualifyingChildOfAnother || dep.isClaimedDependent) &&
    (!m.dependent.person.married || dep.eligibleDependent) &&
    (!dep.split.eligibleForBenefitSplit || dep.split.tpCanClaimSplitBenefitsHohEitcCdcc)
  -- IRC 32(m)
  let ssnValid := m.dependent.answers.tinType == .ssn &&
    (m.ssnEmploymentValidity == .neither ||
      m.ssnEmploymentValidity == .validOnlyWithDhsAuthorizationInEffect ||
      (m.ssnEmploymentValidity == .notValid && !m.ssnOnlyForFederallyFundedBenefit))
  { dep, livedWithTpInUsMostOfYear := lived, eitcRelAgeResJointTest := relAge,
    eitcQualifyingChild := qc, ssnValidForEitcCalculation := ssnValid,
    eitcQualifyingChildForCalculation := qc && ssnValid }

/-- Catala `ssn_valid_for_eitc` (IRC 32(c)(1)(E), DF `/filers/*/ssnValidForEitc`): an SSN, and,
when the work status was asked (not a citizen all year), a card that is unrestricted, valid with
DHS authorization, or not valid for work but not issued only for benefits. -/
def ssnValidForEitc (tin : FilerTin) (isUsCitizenFullYear : Bool) : Bool :=
  tin.tinIsSsn &&
    (isUsCitizenFullYear || tin.ssnEmploymentValidity == .neither ||
      tin.ssnEmploymentValidity == .validOnlyWithDhsAuthorization ||
      (tin.ssnEmploymentValidity == .notValid && !tin.hasSsnOnlyForBenefits))

/-! ## Helper: one Form 1040 call -/

/-- Every input of `Form1040` that is the same in the five calls. -/
structure Form1040Base where
  filingStatus : FilingStatus
  w2s : List FormW2s.FormW2
  interestReports : List Interest.InterestReport
  hasForeignAccountsOrTrusts : Bool
  combatPayElection : FormW2s.CombatPayElection
  primaryFilerCanBeClaimed : Bool
  secondaryFilerCanBeClaimed : Bool
  treatAsMfs : Bool
  primaryFilerIsBlind : Bool
  primaryFilerAge65OrOlder : Bool
  secondaryFilerIsBlind : Bool
  secondaryFilerAge65OrOlder : Bool
  isWidowedInTaxYear : Bool
  mfjDeceasedSpouseReachedAge65 : Bool
  mfsSpouse65OrOlder : Bool
  mfsSpouseProvidesNoBenefits : Bool
  treatFilersAsDependents : Bool

/-- Every plug-in slot of `Form1040`. -/
structure Form1040Slots where
  taxableDependentCare : Int
  taxablePensionsAndAnnuities : Int
  taxableSocialSecurityBenefits : Int
  unemploymentCompensation : Int
  alaskaPfdIncome : Int
  studentLoanInterestAdjustmentAmount : Int
  educatorExpensesAdjustment : Int
  hsaTotalDeductibleAmount : Int
  totalAdditionalTaxesOwed : Int
  totalCtcAndOdc : Int
  line8OfSchedule3 : Int
  other1099Withholding : Int
  paidEstimatedTaxesOrFromLastYear : Bool
  estimatedAndFromLastYear : Int
  earnedIncomeCredit : Int
  additionalCtc : Int
  otherPaymentsAndRefundableCreditsTotal : Int

/-- The `Form1040` input of `Form1040Pass`. -/
def form1040PassIn (base : Form1040Base) (slots : Form1040Slots) : Form1040.Form1040In :=
  { filingStatus := base.filingStatus, w2s := base.w2s, interestReports := base.interestReports
    hasForeignAccountsOrTrusts := base.hasForeignAccountsOrTrusts
    combatPayElection := base.combatPayElection
    primaryFilerCanBeClaimed := base.primaryFilerCanBeClaimed
    secondaryFilerCanBeClaimed := base.secondaryFilerCanBeClaimed
    treatAsMfs := base.treatAsMfs, primaryFilerIsBlind := base.primaryFilerIsBlind
    primaryFilerAge65OrOlder := base.primaryFilerAge65OrOlder
    secondaryFilerIsBlind := base.secondaryFilerIsBlind
    secondaryFilerAge65OrOlder := base.secondaryFilerAge65OrOlder
    isWidowedInTaxYear := base.isWidowedInTaxYear
    mfjDeceasedSpouseReachedAge65 := base.mfjDeceasedSpouseReachedAge65
    mfsSpouse65OrOlder := base.mfsSpouse65OrOlder
    mfsSpouseProvidesNoBenefits := base.mfsSpouseProvidesNoBenefits
    treatFilersAsDependents := base.treatFilersAsDependents
    taxableDependentCare := slots.taxableDependentCare
    taxablePensionsAndAnnuities := slots.taxablePensionsAndAnnuities
    taxableSocialSecurityBenefits := slots.taxableSocialSecurityBenefits
    unemploymentCompensation := slots.unemploymentCompensation
    alaskaPfdIncome := slots.alaskaPfdIncome
    studentLoanInterestAdjustmentAmount := slots.studentLoanInterestAdjustmentAmount
    educatorExpensesAdjustment := slots.educatorExpensesAdjustment
    hsaTotalDeductibleAmount := slots.hsaTotalDeductibleAmount
    totalAdditionalTaxesOwed := slots.totalAdditionalTaxesOwed
    totalCtcAndOdc := slots.totalCtcAndOdc
    line8OfSchedule3 := slots.line8OfSchedule3
    other1099Withholding := slots.other1099Withholding
    paidEstimatedTaxesOrFromLastYear := slots.paidEstimatedTaxesOrFromLastYear
    estimatedAndFromLastYear := slots.estimatedAndFromLastYear
    earnedIncomeCredit := slots.earnedIncomeCredit
    additionalCtc := slots.additionalCtc
    otherPaymentsAndRefundableCreditsTotal := slots.otherPaymentsAndRefundableCreditsTotal }

/-- Catala `scope Form1040Pass`: `Form1040` on the base inputs and the slots. -/
def form1040Pass (base : Form1040Base) (slots : Form1040Slots) : Form1040.Form1040Out :=
  Form1040.form1040 (form1040PassIn base slots)

/-! ## The calculator scope -/

/-- Inputs of `scope Calculator`. -/
structure CalculatorIn where
  /-- DF `/filingStatus` (an input, CONVENTIONS section 7). -/
  filingStatus : FilingStatus
  filers : FilersInput
  primaryExtra : FilerExtra
  secondaryExtra : FilerExtra
  /-- DF `/familyAndHousehold`. -/
  household : List HouseholdMember
  income : IncomeInput
  adjustments : AdjustmentsInput
  payments : PaymentsInput
  credits : CreditAnswers
  cdccAnswers : CdccInput
  ptcAnswers : PtcInput
  screening : ScreeningAnswers

/-- Outputs of `scope Calculator`, then the internal module results the knockouts and the proofs
read (Catala internals, exposed). Money in cents. -/
structure CalculatorOut where
  -- filing status eligibility
  eligibleForQss : Bool
  eligibleForHoh : Bool
  -- Form 1040 (final pass)
  wages : Int
  employerIncomeSubtotal : Int
  interestIncome : Int
  taxablePensionsAndAnnuities : Int
  socialSecurityBenefits : Int
  taxableSocialSecurityBenefits : Int
  otherIncome : Int
  totalIncome : Int
  adjustmentsToIncome : Int
  agi : Int
  standardOrItemizedDeductions : Int
  totalDeductions : Int
  taxableIncome : Int
  tentativeTaxFromTaxableIncome : Int
  totalTentativeTax : Int
  totalCtcAndOdc : Int
  line8OfSchedule3 : Int
  nonRefundableCredits : Int
  taxLessNonRefundableCredits : Int
  totalTax : Int
  formW2Withholding : Int
  form1099Withholding : Int
  totalWithholding : Int
  estimatedAndFromLastYear : Int
  earnedIncomeCredit : Int
  additionalCtc : Int
  totalOtherPaymentsRefundableCredits : Int
  totalPayments : Int
  overpayment : Int
  balanceDue : Int
  -- module figures
  educatorExpensesAdjustment : Int
  studentLoanInterestAdjustmentAmount : Int
  hsaTotalDeductibleAmount : Int
  numEitcQualifyingChildren : Int
  ctcEligibleDependents : Int
  odcEligibleDependents : Int
  cdccTotalCredit : Int
  taxableDependentCare : Int
  qualifiedSaverCreditAmount : Int
  totalEdc : Int
  netPtcAmount : Int
  netPtcAmountWhenZeroOrPositive : Int
  netPtcAmountWhenNegative : Int
  ptcRepaymentLimitation : Int
  lesserOfNetPtcAmountAndRepaymentLimitation : Int
  totalAdditionalTaxesOwed : Int
  otherPaymentsAndRefundableCreditsTotal : Int
  -- knockouts
  unsupported : Bool
  firedKnockouts : List CalculatorKnockout
  -- internals (Catala `internal`), exposed for the knockouts and the proofs
  /-- Stage 1: `Filers` (with `eligible_for_hoh` false). -/
  f : Filers.FilersOut
  /-- Stage 2. -/
  qualifyingChildren : QualifyingChild.QualifyingChildrenOut
  benefitSplit : DependentsBenefitSplit.BenefitSplitOut
  hohQss : HohQssPersons.HohQssPersonsOut
  /-- Stage 3. -/
  filingStatusCheck : FilingStatusMod.EligibilityOut
  /-- Stage 6b. -/
  ptcAllowed : PtcAllowed.PtcAllowedOut
  ptcNet : PtcNet.NetPtcOut
  /-- The AGI pass and the tax pass (line 17 included) of Form 1040. -/
  fAgi : Form1040.Form1040Out
  fTax : Form1040.Form1040Out
  /-- Stage 7 (with the inputs of the three credits limited by line 18). -/
  cdccIn : Cdcc.Form2441In
  cdcc : Cdcc.Form2441Out
  cdccBenefits : Cdcc.Form2441Out
  scheduleRIn : ElderlyAndDisabled.ScheduleRIn
  scheduleR : ElderlyAndDisabled.ScheduleROut
  saversIn : SaversCredit.SaversCreditIn
  savers : SaversCredit.SaversCreditOut
  eitc : Eitc.EarnedIncomeCreditOut
  schedule8812 : CtcOdc.Schedule8812Out
  /-- Stage 8: the input and the result of the final Form 1040 pass. -/
  fFinalIn : Form1040.Form1040In
  fFinal : Form1040.Form1040Out
  /-- Stage 9. -/
  filersKo : Filers.FilersOut
  incomeKoIn : KnockoutsIncome.KnockoutsIncomeIn
  incomeKo : KnockoutsIncome.KnockoutsIncomeOut
  householdKo : KnockoutsHousehold.KnockoutsHouseholdOut
  knockoutTable : List CalculatorKnockoutEntry

/-- The `Filers` input of the calculator for a given `eligible_for_hoh`. -/
def filersIn (i : CalculatorIn) (eligibleForHoh : Bool) : Filers.FilersIn :=
  let filers := i.filers
  { filingStatus := i.filingStatus, maritalStatus := filers.maritalStatus
    yearOfSpouseDeath := filers.yearOfSpouseDeath, primaryFiler := filers.primaryFiler
    secondaryFiler := filers.secondaryFiler
    secondaryFilerDateOfDeath := filers.secondaryFilerDateOfDeath
    primaryFilerPotentialClaimerFiledOnlyForRefund :=
      filers.primaryFilerPotentialClaimerFiledOnlyForRefund
    mfjRequiredToFile := filers.mfjRequiredToFile
    mfjDependentsFilingForCredits := filers.mfjDependentsFilingForCredits
    livedTogetherAllYearWithSpouse := filers.livedTogetherAllYearWithSpouse
    spouseLivedTogetherMonths := filers.spouseLivedTogetherMonths
    writableLivedApartLastSixMonths := filers.writableLivedApartLastSixMonths
    writableSeparationAgreement := filers.writableSeparationAgreement
    canFileJointlyYearOfSpouseDeath := filers.canFileJointlyYearOfSpouseDeath
    inRegisteredDomesticPartnership := filers.inRegisteredDomesticPartnership
    filerResidenceAndIncomeState := filers.filerResidenceAndIncomeState
    spouseItemizes := filers.spouseItemizes
    mfsLivingSpouseFilingReturn := filers.mfsLivingSpouseFilingReturn
    mfsDeceasedSpouseFilingReturn := filers.mfsDeceasedSpouseFilingReturn
    mfsSpouseHasGrossIncome := filers.mfsSpouseHasGrossIncome
    eligibleForHoh := eligibleForHoh }

/-- Catala `scope Calculator`, stage by stage (see the module docstring). -/
def calculator (i : CalculatorIn) : CalculatorOut :=
  let filers := i.filers
  let screening := i.screening
  let income := i.income
  let adjustments := i.adjustments
  let payments := i.payments
  let credits := i.credits
  let cdccAnswers := i.cdccAnswers
  let ptcAnswers := i.ptcAnswers
  -- ---- Stage 1: filers
  -- `eligible_for_hoh` is read only by the community-property knockout; see `filersKo`.
  let f := Filers.filers (filersIn i false)
  -- The per-filer age facts Filers does not export (age 55: HSA; under 18: Saver's).
  let primaryFacts := Filers.filerFacts
    { dateOfBirth := filers.primaryFiler.dateOfBirth, isDeceasedInTaxYear := false
      dateOfDeath := filers.secondaryFilerDateOfDeath
      isUsCitizenFullYear := filers.primaryFiler.isUsCitizenFullYear
      writableCitizenAtEndOfTaxYear := filers.primaryFiler.writableCitizenAtEndOfTaxYear
      writableIsNoncitizenResidentFullYear := filers.primaryFiler.writableIsNoncitizenResidentFullYear
      writableIsNational := filers.primaryFiler.writableIsNational }
  let secondaryFacts := Filers.filerFacts
    { dateOfBirth := filers.secondaryFiler.dateOfBirth, isDeceasedInTaxYear := f.isWidowedInTaxYear
      dateOfDeath := filers.secondaryFilerDateOfDeath
      isUsCitizenFullYear := filers.secondaryFiler.isUsCitizenFullYear
      writableCitizenAtEndOfTaxYear := filers.secondaryFiler.writableCitizenAtEndOfTaxYear
      writableIsNoncitizenResidentFullYear :=
        filers.secondaryFiler.writableIsNoncitizenResidentFullYear
      writableIsNational := filers.secondaryFiler.writableIsNational }
  -- ---- Stage 2: household
  let qualifyingChildren := QualifyingChild.qualifyingChildren
    { persons := i.household.map (·.dependent.person)
      minimumFilerDateOfBirth := f.minimumFilerDateOfBirth }
  let benefitSplit := DependentsBenefitSplit.benefitSplit
    { members := i.household.map fun m => { person := m.dependent.person, answers := m.dependent.split }
      minimumFilerDateOfBirth := f.minimumFilerDateOfBirth, treatAsMfj := f.treatAsMfj }
  let hohQss := HohQssPersons.hohQssPersons
    { members := i.household.map fun m => { dependent := m.dependent, upkeep := m.upkeep }
      minimumFilerDateOfBirth := f.minimumFilerDateOfBirth
      treatFilersAsDependents := f.treatFilersAsDependents
      eitherFilerUsCitizenOrNational := f.eitherFilerUsCitizenOrNational
      treatAsMfj := f.treatAsMfj, eligibleForMfj := f.eligibleForMfj
      filerCouldQualifyForHoh := f.filerCouldQualifyForHoh
      filerCouldQualifyForQss := f.filerCouldQualifyForQss, filingStatus := i.filingStatus }
  let ctcDependents := CtcOdc.ctcOdcDependents
    { householdMembers := i.household.map fun m =>
        { member := m.dependent, ssnEmploymentValidity := m.ssnEmploymentValidity }
      minimumFilerDateOfBirth := f.minimumFilerDateOfBirth
      treatFilersAsDependents := f.treatFilersAsDependents
      eitherFilerUsCitizenOrNational := f.eitherFilerUsCitizenOrNational
      treatAsMfj := f.treatAsMfj }
  let eitcChildren := i.household.map fun m => eitcQualifyingChildTest
    { member := m, minimumFilerDateOfBirth := f.minimumFilerDateOfBirth
      treatFilersAsDependents := f.treatFilersAsDependents
      eitherFilerUsCitizenOrNational := f.eitherFilerUsCitizenOrNational, treatAsMfj := f.treatAsMfj }
  -- ---- Stage 3: filing status eligibility (#20)
  let filingStatusCheck := FilingStatusMod.eligibility
    { filingStatus := i.filingStatus, maritalStatusAllowsFilingMarried := f.eligibleForMfs
      eligibleForMfj := f.eligibleForMfj, filerCouldQualifyForHoh := f.filerCouldQualifyForHoh
      filerCouldQualifyForQss := f.filerCouldQualifyForQss
      hohQualifyingPeopleCount := hohQss.hohQualifyingPeopleCount
      qssQualifyingPeopleCount := hohQss.qssQualifyingPeopleCount }
  let eligibleForQss := filingStatusCheck.eligibleForQss
  let eligibleForHoh := filingStatusCheck.eligibleForHoh
  -- ---- Stage 4: income
  let hasForeignAccountsOrTrusts :=
    screening.hasForeignAccounts || screening.isForeignTrustsGrantor ||
      screening.hasForeignTrustsTransactions
  let w2 := FormW2s.formW2s
    { w2s := income.w2s, filingStatus := i.filingStatus
      primaryFilerCanBeClaimed := filers.primaryFiler.canBeClaimed
      secondaryFilerCanBeClaimed := filers.secondaryFiler.canBeClaimed
      combatPayElection := income.combatPayElection }
  -- `agi` $0: this instance supplies amounts; the AGI knockouts are `incomeKo`'s.
  let interest := Interest.interest
    { interestReports := income.interestReports
      hasForeignAccountsOrTrusts := hasForeignAccountsOrTrusts
      filingStatus := i.filingStatus, agi := 0, flowHasSeenDeductions := true }
  let unemployment := Unemployment.unemployment { form1099Gs := income.form1099Gs }
  let misc := Form1099Misc.form1099Miscs { form1099Miscs := income.form1099Miscs }
  let rs := Form1099Rs.form1099Rs { forms := income.form1099Rs }
  -- Form 1040 line 1e is Form 2441 Part III: the first `Form2441` call gets $0 AGI and tax.
  let cdccMembers : List Cdcc.CdccMember := i.household.map fun m =>
    { member := m.dependent
      cdcc := { unableToCareForSelf := m.cdcc.unableToCareForSelf
                hasDependentCareExpenses := m.cdcc.hasDependentCareExpenses
                expensesPaidToQualifyingProvider := m.cdcc.expensesPaidToQualifyingProvider
                writableQualifyingExpenseAmount := m.cdcc.writableQualifyingExpenseAmount
                tpPaidMostOfHomeUpkeep := m.upkeep.tpPaidMostOfHomeUpkeep } }
  let pc := i.primaryExtra.cdcc
  let cdccPrimary : Cdcc.CdccFiler :=
    { employerIncomeSubtotalBase := w2.primaryFilerWages
      nontaxableCombatPay := w2.primaryFilerCombatPay
      electCombatPayForCredit := pc.electCombatPayForCredit
      electCombatPayForBenefits := pc.electCombatPayForBenefits
      dependentCareBenefits := w2.primaryFilerDependentCareBenefits
      dependentCarePlanMaximum := pc.dependentCarePlanMaximum, isDisabled := pc.isDisabled
      deemedIncomeMonthEarnings := pc.deemedIncomeMonthEarnings
      hasDependentCareExpenses := pc.hasDependentCareExpenses
      expensesPaidToQualifyingProvider := pc.expensesPaidToQualifyingProvider
      writableQualifyingExpenseAmount := pc.writableQualifyingExpenseAmount }
  let sc := i.secondaryExtra.cdcc
  let cdccSecondary : Cdcc.CdccFiler :=
    if f.treatAsMfj then
      { employerIncomeSubtotalBase := w2.secondaryFilerWages
        nontaxableCombatPay := w2.mfjSpouseCombatPay
        electCombatPayForCredit := sc.electCombatPayForCredit
        electCombatPayForBenefits := sc.electCombatPayForBenefits
        dependentCareBenefits := w2.secondaryFilerDependentCareBenefits
        dependentCarePlanMaximum := sc.dependentCarePlanMaximum, isDisabled := sc.isDisabled
        deemedIncomeMonthEarnings := sc.deemedIncomeMonthEarnings
        hasDependentCareExpenses := sc.hasDependentCareExpenses
        expensesPaidToQualifyingProvider := sc.expensesPaidToQualifyingProvider
        writableQualifyingExpenseAmount := sc.writableQualifyingExpenseAmount }
    else
      { employerIncomeSubtotalBase := 0, nontaxableCombatPay := 0, electCombatPayForCredit := false
        electCombatPayForBenefits := false, dependentCareBenefits := 0, dependentCarePlanMaximum := 0
        isDisabled := false, deemedIncomeMonthEarnings := [], hasDependentCareExpenses := false
        expensesPaidToQualifyingProvider := false, writableQualifyingExpenseAmount := 0 }
  let cdccPartIII : Cdcc.Form2441PartIIIIn :=
    { filingStatus := i.filingStatus, household := cdccMembers
      minimumFilerDateOfBirth := f.minimumFilerDateOfBirth
      treatFilersAsDependents := f.treatFilersAsDependents
      eitherFilerUsCitizenOrNational := f.eitherFilerUsCitizenOrNational
      treatAsMfj := f.treatAsMfj
      livedApartLastSixMonths := f.mfsFilerCouldBeConsideredUnmarriedForCdcc
      spouseSameAbodeMoreThanHalfYear :=
        filers.livedTogetherAllYearWithSpouse ||
          filers.spouseLivedTogetherMonths == .livedTogetherMoreThanSixMonths
      primaryFiler := cdccPrimary, secondaryFiler := cdccSecondary
      hasMfsSpouseEarnedIncome := cdccAnswers.hasMfsSpouseEarnedIncome
      writableMfsSpouseEarnedIncome := cdccAnswers.writableMfsSpouseEarnedIncome
      writableTotalQualifiedDependentCareExpenses :=
        cdccAnswers.writableTotalQualifiedDependentCareExpenses
      writableCarryoverAmount := cdccAnswers.writableCarryoverAmount
      writableForfeitedAmount := cdccAnswers.writableForfeitedAmount
      hasCreditForPriorYearExpenses := cdccAnswers.hasCreditForPriorYearExpenses
      claimedCreditForPriorYearExpenses := cdccAnswers.claimedCreditForPriorYearExpenses
      claimedMaxCreditForPriorTaxYear := cdccAnswers.claimedMaxCreditForPriorTaxYear
      hasHouseholdEmployee := cdccAnswers.hasHouseholdEmployee
      benefitsFromSoleProprietorshipOrPartnership :=
        cdccAnswers.benefitsFromSoleProprietorshipOrPartnership }
  let cdccBenefits := Cdcc.form2441
    { toForm2441PartIIIIn := cdccPartIII, agi := 0, totalTentativeTax := 0 }
  let taxableDependentCare := cdccBenefits.benefits.taxableBenefits
  let base1040 : Form1040Base :=
    { filingStatus := i.filingStatus, w2s := income.w2s, interestReports := income.interestReports
      hasForeignAccountsOrTrusts := hasForeignAccountsOrTrusts
      combatPayElection := income.combatPayElection
      primaryFilerCanBeClaimed := filers.primaryFiler.canBeClaimed
      secondaryFilerCanBeClaimed := filers.secondaryFiler.canBeClaimed
      treatAsMfs := f.treatAsMfs, primaryFilerIsBlind := filers.primaryFiler.isBlind
      primaryFilerAge65OrOlder := f.primaryFilerAge65OrOlder
      secondaryFilerIsBlind := filers.secondaryFiler.isBlind
      secondaryFilerAge65OrOlder := f.secondaryFilerAge65OrOlder
      isWidowedInTaxYear := f.isWidowedInTaxYear
      mfjDeceasedSpouseReachedAge65 := f.mfjDeceasedSpouseReachedAge65ForStandardD
      mfsSpouse65OrOlder := filers.mfsSpouse65OrOlder
      mfsSpouseProvidesNoBenefits := f.mfsSpouseProvidesNoBenefits
      treatFilersAsDependents := f.treatFilersAsDependents }
  let slotsIncome : Form1040Slots :=
    { taxableDependentCare := taxableDependentCare
      taxablePensionsAndAnnuities := rs.line5b, taxableSocialSecurityBenefits := 0
      unemploymentCompensation := unemployment.unemploymentCompensation
      alaskaPfdIncome := misc.alaskaPfdIncome, studentLoanInterestAdjustmentAmount := 0
      educatorExpensesAdjustment := 0, hsaTotalDeductibleAmount := 0
      -- line 17 (excess APTC repayment): $0 until stage 6b
      totalAdditionalTaxesOwed := 0, totalCtcAndOdc := 0, line8OfSchedule3 := 0
      other1099Withholding := 0, paidEstimatedTaxesOrFromLastYear := false
      estimatedAndFromLastYear := 0, earnedIncomeCredit := 0, additionalCtc := 0
      -- line 31 (net PTC): $0 until the final pass
      otherPaymentsAndRefundableCreditsTotal := 0 }
  let fIncome := form1040Pass base1040 slotsIncome
  -- Social Security worksheet; `ssGross` gets $0 for worksheet line 6 (line 6a does not depend on
  -- it), so that the HSA module (which reads 6a only for a knockout) does not depend on itself.
  let ssIn (adjustmentsExcludingStudentLoanInterest : Int) : SocialSecurity.SocialSecurityIn :=
    { reportNetBenefits := income.ssaNetBenefits, filingStatus := i.filingStatus
      livedApartAllYear := f.livedApartAllYear, line1z := fIncome.employerIncomeSubtotal
      line2b := fIncome.interestIncome, line2a := interest.taxExemptInterest, line3b := 0
      line4b := 0, line5b := rs.line5b, line7CapitalGains := 0
      line8OtherIncome := fIncome.otherIncome
      adjustmentsExcludingStudentLoanInterest := adjustmentsExcludingStudentLoanInterest }
  let ssGross := SocialSecurity.socialSecurity (ssIn 0)
  -- DF /form1099Withholding: the SSA-1099 box 6 term, each report's amount unrounded
  let ssaWithholding := Money.sum income.ssaFederalTaxWithheld
  -- ---- Stage 5: adjustments
  let educator := EducatorAdjustment.educatorAdjustment
    { wasK12Educators := adjustments.wasK12Educators
      primaryEducatorExpensesWritable := adjustments.primaryEducatorExpensesWritable
      secondaryEducatorExpensesWritable := adjustments.secondaryEducatorExpensesWritable
      isMfjDependent := f.isMfjDependent }
  let ah := adjustments.hsa
  -- `knockoutHasNoPaymentsOrCredits` feeds only a knockout: false here, the real one in `incomeKo`
  let hsa := Hsa.hsa
    { isFilingStatusMfj := f.isFilingStatusMfj, isMarried := f.isMarried, isSingle := f.isSingle
      primaryFilerAge55OrOlder := primaryFacts.age55OrOlder
      secondaryFilerAge55OrOlder := secondaryFacts.age55OrOlder
      primaryFilerCanBeClaimed := filers.primaryFiler.canBeClaimed
      secondaryFilerCanBeClaimed := filers.secondaryFiler.canBeClaimed
      primaryFilerTotalHsaContributionsFromW2s := w2.primaryFilerTotalHsaContributionsFromW2s
      secondaryFilerTotalHsaContributionsFromW2s := w2.secondaryFilerTotalHsaContributionsFromW2s
      hasPrimaryFilerHsaContributionsFromW2s := w2.hasPrimaryFilerHsaContributionsFromW2s
      hasSecondaryFilerHsaContributionsFromW2s := w2.hasSecondaryFilerHsaContributionsFromW2s
      knockoutHasNoPaymentsOrCredits := false
      paidEstimatedTaxesOrFromLastYear := payments.paidEstimatedTaxesOrFromLastYear
      taxExemptInterest := interest.taxExemptInterest, pensionsAndAnnuities := rs.line5a
      socialSecurityBenefits := ssGross.line6a
      primaryFiler := i.primaryExtra.hsa, secondaryFiler := i.secondaryExtra.hsa
      someFilerHadNonW2HsaActivity := ah.someFilerHadNonW2HsaActivity
      writablePrimaryFilerHadNonW2HsaActivity := ah.writablePrimaryFilerHadNonW2HsaActivity
      writableSecondaryFilerHadNonW2HsaActivity := ah.writableSecondaryFilerHadNonW2HsaActivity
      hasHsaMedicalSavingsAccountType := ah.hasHsaMedicalSavingsAccountType
      writableHasHsaExcessContributionsPreviousYear := ah.writableHasHsaExcessContributionsPreviousYear
      writableHasHsaWithdrawnExcessContributionsYesNo :=
        ah.writableHasHsaWithdrawnExcessContributionsYesNo
      someFilersMadeTestingPeriodContribution := ah.someFilersMadeTestingPeriodContribution
      someFilersHaveTestingPeriodAdditionalIncome := ah.someFilersHaveTestingPeriodAdditionalIncome
      hsaDistributions := ah.hsaDistributions }
  let adjustmentsExcludingSl := educator.educatorExpensesAdjustment + hsa.hsaTotalDeductibleAmount
  let ss := SocialSecurity.socialSecurity (ssIn adjustmentsExcludingSl)
  -- The second call adds line 6b and the two adjustments that do not depend on total income;
  -- its line 9 is the student loan worksheet's line 1.
  let slotsTotalIncome : Form1040Slots :=
    { slotsIncome with
      taxableSocialSecurityBenefits := ss.line6b
      educatorExpensesAdjustment := educator.educatorExpensesAdjustment
      hsaTotalDeductibleAmount := hsa.hsaTotalDeductibleAmount }
  let fTotalIncome := form1040Pass base1040 slotsTotalIncome
  -- Schedule 1 line 21; MAGI = line 9 less the other adjustments (IRC 221(b)(2)(C))
  let studentLoan := StudentLoanAdjustment.studentLoanAdjustment
    { filingStatus := i.filingStatus
      hadStudentLoanInterestPayments := adjustments.hadStudentLoanInterestPayments
      studentLoansQualify := adjustments.studentLoansQualify
      studentLoanInterestAmount := adjustments.studentLoanInterestAmount
      isMfjDependent := f.isMfjDependent
      eitherFilerIsClaimedAsDependent := f.eitherFilerIsClaimedAsDependent
      totalIncome := fTotalIncome.totalIncome
      adjustmentsToIncomeExcludingStudentLoanInterest := adjustmentsExcludingSl }
  -- ---- Stage 6: adjusted gross income
  let slotsAgi : Form1040Slots :=
    { slotsTotalIncome with
      studentLoanInterestAdjustmentAmount := studentLoan.studentLoanInterestAdjustmentAmount }
  let fAgi := form1040Pass base1040 slotsAgi
  -- ---- Stage 6b: premium tax credit
  let claimedDependents := QualifyingRelative.dependents
    { members := i.household.map (·.dependent)
      minimumFilerDateOfBirth := f.minimumFilerDateOfBirth
      treatFilersAsDependents := f.treatFilersAsDependents
      eitherFilerUsCitizenOrNational := f.eitherFilerUsCitizenOrNational, treatAsMfj := f.treatAsMfj }
  let ptcFamily := PtcFamily.ptcFamily
    { filingStatus := i.filingStatus
      claimedDependentsCount := claimedDependents.claimedDependentsCount
      primarySomeoneCanClaimForTaxBenefits := f.primarySomeOneCanClaimForTaxBenefits
      secondarySomeoneCanClaimForTaxBenefits := f.secondarySomeOneCanClaimForTaxBenefits
      livedInAk := filers.filerResidenceAndIncomeState == .ak
      -- Direct File does not offer Hawaii
      livedInHi := false, agi := fAgi.agi, taxExemptInterest := interest.taxExemptInterest
      nonTaxableSocialSecurityBenefits := ss.nonTaxableBenefits }
  let ptcAllowed := PtcAllowed.ptcAllowed
    { filingStatus := i.filingStatus, isMfjDependent := f.isMfjDependent
      notMfjAndPrimaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits :=
        f.notMfjAndPrimaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits
      primaryFilerIsClaimedAsDependent := f.primaryFilerIsClaimedAsDependent
      isMarried := f.isMarried
      secondaryFilerResidencyEligibleForMfj := f.secondaryFilerResidencyEligibleForMfj
      livedApartLastSixMonths := f.livedApartLastSixMonths
      allEligibleFilersAreUsCitizensOrNationals := f.allEligibleFilersAreUsCitizensOrNationals
      claimedDependentsCount := claimedDependents.claimedDependentsCount
      -- DF /hasQsehra: a W-2 box 12 code FF amount above $0
      hasQsehra := income.w2s.any fun w => decide (w.qsehraBenefits > 0)
      householdIncomeAsPercent := ptcFamily.householdIncomeAsPercent
      ptcAnnualContributionAmount := ptcFamily.ptcAnnualContributionAmount
      ptcMonthlyContributionAmount := ptcFamily.ptcMonthlyContributionAmount
      form1095As := ptcAnswers.form1095As
      writableHasPtcQualifyingPlan := ptcAnswers.writableHasPtcQualifyingPlan
      writableHasAdvancedPtc := ptcAnswers.writableHasAdvancedPtc
      dependentTpSelfEnrolled := ptcAnswers.dependentTpSelfEnrolled
      dependentTpEnrolledSomeoneElse := ptcAnswers.dependentTpEnrolledSomeoneElse
      writableDependentTpOtherMembersArePartOfDifferentTaxFamily :=
        ptcAnswers.writableDependentTpOtherMembersArePartOfDifferentTaxFamily
      writableHasMfsException := ptcAnswers.writableHasMfsException
      writableClaimingMfsExceptionForFourthStraightYear :=
        ptcAnswers.writableClaimingMfsExceptionForFourthStraightYear
      writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus :=
        ptcAnswers.writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus
      writableHasEmployerSponsoredPlan := ptcAnswers.writableHasEmployerSponsoredPlan
      writableDependentsRequiredToFile := ptcAnswers.writableDependentsRequiredToFile
      writableSelfReportedHasMultiple1095As := ptcAnswers.writableSelfReportedHasMultiple1095As
      writableIsAdditionalPersonInEnrollmentFamily :=
        ptcAnswers.writableIsAdditionalPersonInEnrollmentFamily
      writableIsAdditionalPersonPartofDifferentTaxFamily :=
        ptcAnswers.writableIsAdditionalPersonPartofDifferentTaxFamily
      writableIsEnrolledWithOtherFamily := ptcAnswers.writableIsEnrolledWithOtherFamily
      writableHasImmigrationStatusNotEligibleForMarketplace :=
        ptcAnswers.writableHasImmigrationStatusNotEligibleForMarketplace
      writableWantsToUseAltCalculations := ptcAnswers.writableWantsToUseAltCalculations }
  let ptcNet := PtcNet.netPtc
    { filingStatus := i.filingStatus
      householdIncomeAsPercent := ptcFamily.householdIncomeAsPercent
      taxFamilySizeIsZero := ptcFamily.taxFamilySizeIsZero
      totalPtcAmountAllowed := ptcAllowed.totalPtcAmountAllowed
      totalAptcAmountTaken := ptcAllowed.totalAptcAmountTaken }
  -- Line 17 joins the tax (IRC 36B(f)(2)(A)), and so the credits' starting point.
  let slotsTax : Form1040Slots :=
    { slotsAgi with totalAdditionalTaxesOwed := ptcNet.excessAptcRepayment }
  let fTax := form1040Pass base1040 slotsTax
  -- ---- Stage 7: credits (CDCC, Schedule R, Saver's, EITC, CTC/ODC/ACTC)
  let estimated := EstimatedPayments.estimatedPayments
    { paidEstimatedTaxesOrFromLastYear := payments.paidEstimatedTaxesOrFromLastYear
      estimatedTaxPaymentWritable := payments.estimatedTaxPaymentWritable
      paidEstimatedTaxesOrFromLastYearUnderDifferentName :=
        payments.paidEstimatedTaxesOrFromLastYearUnderDifferentName
      paidEstimatedTaxesWithFormerSpouse := payments.paidEstimatedTaxesWithFormerSpouse }
  -- Form 2441 line 11, Schedule 3 line 2
  let cdccIn : Cdcc.Form2441In :=
    { toForm2441PartIIIIn := cdccPartIII, agi := fAgi.agi
      totalTentativeTax := fTax.totalTentativeTax }
  let cdcc := Cdcc.form2441 cdccIn
  let cdccTotalCredit := cdcc.cdccTotalCredit
  -- DF /primaryFilerHasW2WagesGreaterThan0, /secondaryFilerHasW2WagesGreaterThan0
  let primaryDisability : ElderlyAndDisabled.DisabilityAnswers :=
    { i.primaryExtra.disability with hasW2Wages := w2.primaryFilerHasW2WagesGreaterThan0 }
  let secondaryDisability : ElderlyAndDisabled.DisabilityAnswers :=
    { i.secondaryExtra.disability with hasW2Wages := w2.secondaryFilerHasW2WagesGreaterThan0 }
  let scheduleRIn : ElderlyAndDisabled.ScheduleRIn :=
    { filingStatus := i.filingStatus, livedApartAllYear := f.livedApartAllYear
      primaryAge65OrOlder := f.primaryFilerAge65OrOlder
      secondaryAge65OrOlder := f.secondaryFilerAge65OrOlder
      primaryAnswers := primaryDisability, secondaryAnswers := secondaryDisability
      agi := fAgi.agi, nonTaxableSocialSecurityBenefits := ss.nonTaxableBenefits
      selfReportedNonTaxablePayments :=
        if credits.hasSelfReportedNonTaxablePayments then
          roundDollar credits.selfReportedNonTaxablePaymentAmount
        else 0
      creditLimitWorksheetLine3 := fTax.totalTentativeTax - cdccTotalCredit }
  let scheduleR := ElderlyAndDisabled.scheduleR scheduleRIn
  let saversIn : SaversCredit.SaversCreditIn :=
    { filingStatus := i.filingStatus, agi := fAgi.agi, isMfjDependent := f.isMfjDependent
      primaryFilerIsUnder18 := primaryFacts.isUnder18
      primaryFilerIsStudent := i.primaryExtra.isStudent
      primaryFilerIsClaimedAsDependent := f.primaryFilerIsClaimedAsDependent
      secondaryFilerIsUnder18 := secondaryFacts.isUnder18
      secondaryFilerIsStudent := i.secondaryExtra.isStudent
      secondaryFilerIsClaimedAsDependent := f.secondaryFilerIsClaimedAsDependent
      primaryFilerTotalDeferralsAndContributions := w2.primaryFilerTotalDeferralsAndContributions
      secondaryFilerTotalDeferralsAndContributions := w2.secondaryFilerTotalDeferralsAndContributions
      primaryFilerSaversGrossDistributions := rs.primaryFilerSaversGrossDistributions
      secondaryFilerSaversGrossDistributions := rs.secondaryFilerSaversGrossDistributions
      totalTentativeTax := fTax.totalTentativeTax, cdccTotalCredit := cdccTotalCredit
      totalEdc := scheduleR.totalEdc
      hasDistributionsInLastThreeYears := credits.hasDistributionsInLastThreeYears
      hasCurrentYearDistributions := credits.hasCurrentYearDistributions
      hasSelfReportedContributions := credits.hasSelfReportedContributions }
  let savers := SaversCredit.saversCredit saversIn
  let numEitcQualifyingChildren : Int := ((countBy (·.eitcQualifyingChild) eitcChildren : Nat) : Int)
  let eitc := Eitc.earnedIncomeCredit
    { filingStatus := i.filingStatus, employerIncomeSubtotal := fAgi.employerIncomeSubtotal
      agi := fAgi.agi, taxExemptInterest := interest.taxExemptInterest
      interestIncome := fAgi.interestIncome
      -- lines 3b and 7: out of scope in Direct File ($0)
      ordinaryDividends := 0, capitalGainsOrLosses := 0
      primaryFilerCombatPay := w2.primaryFilerCombatPay, mfjSpouseCombatPay := w2.mfjSpouseCombatPay
      allCombatPay := w2.allCombatPay, combatPayElectionMade := income.combatPayElectionMade
      combatPayElection := income.combatPayElection
      numEitcQualifyingChildren := numEitcQualifyingChildren
      numEitcQualifyingChildrenForCalculation :=
        ((countBy (·.eitcQualifyingChildForCalculation) eitcChildren : Nat) : Int)
      isMarried := f.isMarried, treatAsMfs := f.treatAsMfs
      specialRuleForSeparatedSpouses := f.specialRuleForSeparatedSpouses
      treatFilersAsDependents := f.treatFilersAsDependents, isMfjDependent := f.isMfjDependent
      filersUsCitizenOrRaAllYear := f.filersUsCitizenOrRaAllYear
      filersHaveValidSsnsForEitc :=
        ssnValidForEitc i.primaryExtra.tin filers.primaryFiler.isUsCitizenFullYear &&
          (!f.treatAsMfj ||
            ssnValidForEitc i.secondaryExtra.tin filers.secondaryFiler.isUsCitizenFullYear)
      primaryFilerAge25OrOlderForEitc := f.primaryFilerAge25OrOlderForEitc
      primaryFilerAge64OrYoungerForEitc := f.primaryFilerAge64OrYoungerForEitc
      secondaryFilerAge25OrOlderForEitc := f.secondaryFilerAge25OrOlderForEitc
      secondaryFilerAge64OrYoungerForEitc := f.secondaryFilerAge64OrYoungerForEitc
      eitcQcOfAnother := credits.eitcQcOfAnother
      eitcQcOfAnotherRequiredToFile := credits.eitcQcOfAnotherRequiredToFile
      eitcQcOfAnotherIsFiling := credits.eitcQcOfAnotherIsFiling
      eitcQcOfAnotherIsFilingRefundOnly := credits.eitcQcOfAnotherIsFilingRefundOnly
      eitcHadImproperClaims := credits.eitcHadImproperClaims
      eitcImproperClaimsDueToQc := credits.eitcImproperClaimsDueToQc
      eitcImproperClaimTakenSinceDisallowal := credits.eitcImproperClaimTakenSinceDisallowal
      eitcReceivedImproperClaimsNotice := credits.eitcReceivedImproperClaimsNotice
      eitcImproperClaimsNoticeExpired := credits.eitcImproperClaimsNoticeExpired }
  let schedule8812 := CtcOdc.schedule8812
    { ctcEligibleDependents := ctcDependents.ctcEligibleDependents
      odcEligibleDependents := ctcDependents.odcEligibleDependents
      filingStatus := i.filingStatus, agi := fAgi.agi, totalTentativeTax := fTax.totalTentativeTax
      cdccTotalCredit := cdccTotalCredit
      qualifiedSaverCreditAmount := savers.qualifiedSaverCreditAmount
      totalEdc := scheduleR.totalEdc, employerIncomeSubtotal := fAgi.employerIncomeSubtotal
      allCombatPay := w2.allCombatPay
      socialSecurityTaxesWithheld := w2.socialSecurityTaxesWithheld
      earnedIncomeCredit := eitc.earnedIncomeCredit
      receivedImproperClaims := credits.receivedImproperClaims
      receivedImproperClaimsNotice := credits.receivedImproperClaimsNotice
      improperClaimsNoticeExpired := credits.improperClaimsNoticeExpired
      hasFiledCtcOdcSinceNoticeExpired := credits.hasFiledCtcOdcSinceNoticeExpired }
  -- ---- Stage 8: the return
  -- Schedule 3 line 8 = line 1 ($0) + CDCC + line 3 ($0) + Saver's + line 5b ($0) + line 7
  -- (Schedule R plus three $0 placeholders); line 25b's other terms are SSA-1099, 1099-G,
  -- 1099-MISC and 1099-R.
  let slotsFinal : Form1040Slots :=
    { slotsTax with
      totalCtcAndOdc := schedule8812.totalCtcAndOdc
      line8OfSchedule3 :=
        0 + cdccTotalCredit + 0 + savers.qualifiedSaverCreditAmount + 0 +
          (scheduleR.totalEdc + 0 + 0 + 0)
      other1099Withholding :=
        ssaWithholding + unemployment.form1099gFederalTaxWithheld +
          misc.form1099MiscFederalIncomeTaxWithheld + rs.form1099rFederalIncomeTaxWithheld
      paidEstimatedTaxesOrFromLastYear := payments.paidEstimatedTaxesOrFromLastYear
      estimatedAndFromLastYear := estimated.estimatedAndFromLastYear
      earnedIncomeCredit := eitc.earnedIncomeCredit
      additionalCtc := schedule8812.additionalCtc
      -- Schedule 3 line 15 = line 9 (net PTC)
      otherPaymentsAndRefundableCreditsTotal := ptcNet.netPtcCredit }
  let fFinalIn := form1040PassIn base1040 slotsFinal
  let fFinal := Form1040.form1040 fFinalIn
  -- ---- Stage 9: knockouts
  let filersKo := Filers.filers (filersIn i eligibleForHoh)
  let incomeKoIn : KnockoutsIncome.KnockoutsIncomeIn :=
    { filingStatus := i.filingStatus, agi := fFinal.agi
      primaryFilerCanBeClaimed := filers.primaryFiler.canBeClaimed
      secondaryFilerCanBeClaimed := filers.secondaryFiler.canBeClaimed
      paidEstimatedTaxesOrFromLastYear := payments.paidEstimatedTaxesOrFromLastYear
      knockoutHasNoPaymentsOrCredits := fFinal.koKnockoutHasNoPaymentsOrCredits
      incomeSourcesSupported := screening.incomeSourcesSupported
      receivedDigitalAssets := screening.receivedDigitalAssets
      disposedDigitalAssets := screening.disposedDigitalAssets
      hasForeignAccounts := screening.hasForeignAccounts
      isForeignTrustsGrantor := screening.isForeignTrustsGrantor
      hasForeignTrustsTransactions := screening.hasForeignTrustsTransactions
      madeIraContributions := screening.madeIraContributions
      interestReports := income.interestReports, w2s := income.w2s
      combatPayElection := income.combatPayElection
      w2Box15IncomeFromDifferentState := screening.w2Box15IncomeFromDifferentState
      w2HasBox14NyrrtaKnockoutCode := screening.w2HasBox14NyrrtaKnockoutCode
      w2HasRrtaCodesInBox14 := screening.w2HasRrtaCodesInBox14, livedInNy := screening.livedInNy
      w2PaidYonkersTaxes := screening.w2PaidYonkersTaxes
      partYearYonkersResident := screening.partYearYonkersResident
      filerResidenceAndIncomeState := filers.filerResidenceAndIncomeState
      primaryFilerFormsAnotherState := screening.primaryFilerFormsAnotherState
      receivedAlaskaPfd := screening.receivedAlaskaPfd
      spouseReceivedAlaskaPfd := screening.spouseReceivedAlaskaPfd, treatAsMfj := f.treatAsMfj
      spouseLivesInOtherOrMultipleStates := screening.spouseLivesInOtherOrMultipleStates
      spouseFormsAnotherState := screening.spouseFormsAnotherState
      form1099Gs := income.form1099Gs, form1099Miscs := income.form1099Miscs
      form1099Rs := income.form1099Rs, reportNetBenefits := income.ssaNetBenefits
      livedApartAllYear := f.livedApartAllYear, line1z := fIncome.employerIncomeSubtotal
      line2a := interest.taxExemptInterest, line2b := fIncome.interestIncome, line3b := 0
      line4b := 0, line5b := rs.line5b, line7CapitalGains := 0
      line8OtherIncome := fIncome.otherIncome
      adjustmentsExcludingStudentLoanInterest := adjustmentsExcludingSl
      estimatedTaxPaymentWritable := payments.estimatedTaxPaymentWritable
      paidEstimatedTaxesOrFromLastYearUnderDifferentName :=
        payments.paidEstimatedTaxesOrFromLastYearUnderDifferentName
      paidEstimatedTaxesWithFormerSpouse := payments.paidEstimatedTaxesWithFormerSpouse
      isFilingStatusMfj := f.isFilingStatusMfj, isMarried := f.isMarried, isSingle := f.isSingle
      primaryFilerAge55OrOlder := primaryFacts.age55OrOlder
      secondaryFilerAge55OrOlder := secondaryFacts.age55OrOlder
      primaryFilerTotalHsaContributionsFromW2s := w2.primaryFilerTotalHsaContributionsFromW2s
      secondaryFilerTotalHsaContributionsFromW2s := w2.secondaryFilerTotalHsaContributionsFromW2s
      hasPrimaryFilerHsaContributionsFromW2s := w2.hasPrimaryFilerHsaContributionsFromW2s
      hasSecondaryFilerHsaContributionsFromW2s := w2.hasSecondaryFilerHsaContributionsFromW2s
      taxExemptInterest := interest.taxExemptInterest, pensionsAndAnnuities := rs.line5a
      socialSecurityBenefits := ss.line6a
      hsaPrimaryFiler := i.primaryExtra.hsa, hsaSecondaryFiler := i.secondaryExtra.hsa
      someFilerHadNonW2HsaActivity := ah.someFilerHadNonW2HsaActivity
      writablePrimaryFilerHadNonW2HsaActivity := ah.writablePrimaryFilerHadNonW2HsaActivity
      writableSecondaryFilerHadNonW2HsaActivity := ah.writableSecondaryFilerHadNonW2HsaActivity
      hasHsaMedicalSavingsAccountType := ah.hasHsaMedicalSavingsAccountType
      writableHasHsaExcessContributionsPreviousYear := ah.writableHasHsaExcessContributionsPreviousYear
      writableHasHsaWithdrawnExcessContributionsYesNo :=
        ah.writableHasHsaWithdrawnExcessContributionsYesNo
      someFilersMadeTestingPeriodContribution := ah.someFilersMadeTestingPeriodContribution
      someFilersHaveTestingPeriodAdditionalIncome := ah.someFilersHaveTestingPeriodAdditionalIncome
      hsaDistributions := ah.hsaDistributions
      isAfterTaxDayAndNotResubmitting := screening.isAfterTaxDayAndNotResubmitting
      isAfterResubmissionDeadline := screening.isAfterResubmissionDeadline }
  let incomeKo := KnockoutsIncome.knockoutsIncome incomeKoIn
  let householdKo := KnockoutsHousehold.knockoutsHousehold
    { memberVitals := screening.memberVitals
      inFlowKnockoutFilerAgeYoungerThan16 := filersKo.koFlowKnockoutFilerAgeYoungerThan16
      inSpouseItemizesKnockout := filersKo.koSpouseItemizesKnockout
      inPrimaryFilerResidencyKnockout := filersKo.koPrimaryFilerResidencyKnockout
      inFlowKnockoutHasApplicableRegisteredDomesticPartnership :=
        filersKo.koFlowKnockoutHasApplicableRegisteredDomesticPartnership
      inKnockoutSubjectToCommunityPropertyLaws := filersKo.koKnockoutSubjectToCommunityPropertyLaws
      inKnockoutHohQpHasNoTin := hohQss.koKnockoutHohQpHasNoTin
      inKnockedOutByNonCustodialParentBenefitSplit :=
        benefitSplit.koKnockedOutByNonCustodialParentBenefitSplit
      inKnockedOutByContradictory8832 := benefitSplit.koKnockedOutByContradictory8832
      inSaversCreditKnockouts := savers.koSaversCreditKnockouts
      inFlowKnockoutBenefitsDistribution := cdcc.koFlowKnockoutBenefitsDistribution
      inKnockoutCdccWorksheetA := cdcc.benefits.koKnockoutCdccWorksheetA
      inFlowKnockoutHouseholdEmployee := cdcc.benefits.koKnockoutHouseholdEmployee
      inDependentTpRequiresAllocations := ptcAllowed.koDependentTpRequiresAllocations
      inHasPtcQualifyingPlanAndQsehra := ptcAllowed.koHasPtcQualifyingPlanAndQsehra
      inNeedsAllocations := ptcAllowed.koNeedsAllocations
      inHasEmployerSponsoredPlan := ptcAllowed.koHasEmployerSponsoredPlan
      inDependentsRequiredToFile := ptcAllowed.koDependentsRequiredToFile
      inSelfReportedHasMultiple1095As := ptcAllowed.koSelfReportedHasMultiple1095As
      inHasImmigrationStatusNotEligibleForMarketplace :=
        ptcAllowed.koHasImmigrationStatusNotEligibleForMarketplace
      inWantsToUseAltCalculations := ptcAllowed.koWantsToUseAltCalculations
      inQualifyingChildTieBreaker := qualifyingChildren.koQualifyingChildTieBreaker
      inClaimedSpouseCombatPayWithoutMfj := eitc.koClaimedSpouseCombatPayWithoutMfj
      inFilingStatusNotEligible := filingStatusCheck.koFilingStatusNotEligible
      inSoleProprietorshipBenefits := cdcc.benefits.koSoleProprietorshipBenefits
      inBothSpousesDeemedIncome := cdcc.benefits.koBothSpousesDeemedIncome
      inTpNeedsToAdd1095A := ptcAllowed.koTpNeedsToAdd1095A
      inTpNeedsToDelete1095A := ptcAllowed.koTpNeedsToDelete1095A }
  let knockoutTable : List CalculatorKnockoutEntry :=
    incomeKo.firedKnockouts.map (fun r => ⟨.incomeOrHsa r, true⟩) ++
      householdKo.firedKnockouts.map (fun r => ⟨.household r, true⟩)
  -- flow.xml /flowIsKnockedOut, restricted to the merged modules
  let unsupported :=
    incomeKo.unsupportedIncomeOrHsa || fFinal.unsupported || householdKo.unsupportedHousehold ||
      filersKo.unsupported || qualifyingChildren.unsupported || benefitSplit.unsupported ||
      hohQss.unsupported || eitc.unsupported || savers.unsupported ||
      filingStatusCheck.unsupported || cdcc.unsupported || ptcAllowed.unsupported
  { eligibleForQss, eligibleForHoh
    wages := fFinal.wages, employerIncomeSubtotal := fFinal.employerIncomeSubtotal
    interestIncome := fFinal.interestIncome, taxablePensionsAndAnnuities := rs.line5b
    socialSecurityBenefits := ss.line6a, taxableSocialSecurityBenefits := ss.line6b
    otherIncome := fFinal.otherIncome, totalIncome := fFinal.totalIncome
    adjustmentsToIncome := fFinal.adjustmentsToIncome, agi := fFinal.agi
    standardOrItemizedDeductions := fFinal.standardOrItemizedDeductions
    totalDeductions := fFinal.totalDeductions, taxableIncome := fFinal.taxableIncome
    tentativeTaxFromTaxableIncome := fFinal.tentativeTaxFromTaxableIncome
    totalTentativeTax := fFinal.totalTentativeTax
    totalCtcAndOdc := schedule8812.totalCtcAndOdc
    line8OfSchedule3 := slotsFinal.line8OfSchedule3
    nonRefundableCredits := fFinal.nonRefundableCredits
    taxLessNonRefundableCredits := fFinal.taxLessNonRefundableCredits
    totalTax := fFinal.totalTax, formW2Withholding := fFinal.formW2Withholding
    form1099Withholding := fFinal.form1099Withholding, totalWithholding := fFinal.totalWithholding
    estimatedAndFromLastYear := estimated.estimatedAndFromLastYear
    earnedIncomeCredit := eitc.earnedIncomeCredit, additionalCtc := schedule8812.additionalCtc
    totalOtherPaymentsRefundableCredits := fFinal.totalOtherPaymentsRefundableCredits
    totalPayments := fFinal.totalPayments, overpayment := fFinal.overpayment
    balanceDue := fFinal.balanceDue
    educatorExpensesAdjustment := educator.educatorExpensesAdjustment
    studentLoanInterestAdjustmentAmount := studentLoan.studentLoanInterestAdjustmentAmount
    hsaTotalDeductibleAmount := hsa.hsaTotalDeductibleAmount
    numEitcQualifyingChildren := numEitcQualifyingChildren
    ctcEligibleDependents := ctcDependents.ctcEligibleDependents
    odcEligibleDependents := ctcDependents.odcEligibleDependents
    cdccTotalCredit := cdccTotalCredit, taxableDependentCare := taxableDependentCare
    qualifiedSaverCreditAmount := savers.qualifiedSaverCreditAmount
    totalEdc := scheduleR.totalEdc
    netPtcAmount := ptcNet.netPtcAmount, netPtcAmountWhenZeroOrPositive := ptcNet.line26
    netPtcAmountWhenNegative := ptcNet.line27, ptcRepaymentLimitation := ptcNet.line28
    lesserOfNetPtcAmountAndRepaymentLimitation := ptcNet.line29
    totalAdditionalTaxesOwed := ptcNet.excessAptcRepayment
    otherPaymentsAndRefundableCreditsTotal := ptcNet.netPtcCredit
    unsupported
    firedKnockouts := (knockoutTable.filter (·.fired)).map (·.reason)
    f, qualifyingChildren, benefitSplit, hohQss, filingStatusCheck, ptcAllowed, ptcNet, fAgi, fTax
    cdccIn, cdcc, cdccBenefits, scheduleRIn, scheduleR, saversIn, savers, eitc, schedule8812, fFinalIn, fFinal, filersKo
    incomeKoIn, incomeKo, householdKo, knockoutTable }

/-! ## Unit tests: the assertions of `catala/tests/test_calculator.catala_en`

`mkW2`, `mkChild` and the `default…` values are the Catala helpers `MkW2`, `MkChild` and
`Defaults`: an adult citizen filer born 1990-06-15 with an SSN, living in Florida, no other
activity; a child who is the filer's biological child, lived with the filer all year, has an SSN
and is claimed. Amounts in cents. -/

namespace Tests

/-- Catala `MkW2`: boxes 1 and 2, Social Security and Medicare wages equal to box 1 (taxes 6.2%
and 1.45%), every other box `$0`. -/
def mkW2 (wages withholding : Int) (filer : FilerRole := .primaryFiler) : FormW2s.FormW2 :=
  { filer, writableWages := wages, writableFederalWithholding := withholding
    writableOasdiWages := wages, writableOasdiWithholding := mulRate wages (62 / 1000)
    writableMedicareWages := wages, writableMedicareWithholding := mulRate wages (145 / 10000) }

/-- Catala `MkChild`. -/
def mkChild (dob : Date) : HouseholdMember :=
  { dependent :=
      { person :=
          { relationship := .biologicalChild, dateOfBirth := dob, fullTimeStudent := false
            permanentTotalDisability := false, residencyDuration := .allYear, ownSupport := false
            married := false, writableJointReturn := false, writableRequiredToFile := false
            writableFilingOnlyForRefund := false, writableCouldBeQualifyingChildOfAnother := false
            writablePotentialClaimerMustFile := false, writablePotentialClaimerDidFile := false
            writablePotentialClaimerFiledOnlyForRefund := false }
        answers :=
          { grossIncome := 0, writableQrSupportTest := false, tinType := .ssn
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
            parentalSituation := .other, parentalSupport := false
            multipleSupportAgreement := false } }
    upkeep := { tpPaidMostOfHomeUpkeep := true, tpPaidMostOfParentHomeUpkeep := false }
    ssnEmploymentValidity := .neither, ssnOnlyForFederallyFundedBenefit := false
    monthsLivedWithTpInUs := 12, cdcc := {} }

/-- Catala `Defaults.filer`. -/
def defaultFiler : Filers.FilerAnswers :=
  { dateOfBirth := ⟨1990, 6, 15⟩, isBlind := false, canBeClaimed := false, willBeClaimed := false
    potentialClaimerMustFile := false, potentialClaimerDidFile := false
    isUsCitizenFullYear := true, writableCitizenAtEndOfTaxYear := false
    writableIsNoncitizenResidentFullYear := false, writableIsNational := false }

/-- Catala `Defaults.extra`. -/
def defaultExtra : FilerExtra :=
  { tin := {}, isStudent := false
    disability :=
      { isRetiredOnPermOrTotalDisability := false, employerHasMandatoryRetirementAge := false
        hasMetEmployerMandatoryRetirementAge := false, arePaymentsTaxableDisabilityIncome := false
        writableTotalTaxableDisabilityAmount := 0, hasW2Wages := false }
    hsa := KnockoutsIncome.noHsa, cdcc := {} }

/-- Catala `Defaults.filers`. -/
def defaultFilers : FilersInput :=
  { maritalStatus := .neverMarried, yearOfSpouseDeath := .diedBeforeTaxYearMinusTwo
    primaryFiler := defaultFiler, secondaryFiler := defaultFiler
    secondaryFilerDateOfDeath := ⟨2024, 12, 31⟩
    primaryFilerPotentialClaimerFiledOnlyForRefund := false, mfjRequiredToFile := false
    mfjDependentsFilingForCredits := false, livedTogetherAllYearWithSpouse := true
    spouseLivedTogetherMonths := .livedApartAllYear, writableLivedApartLastSixMonths := false
    writableSeparationAgreement := false, canFileJointlyYearOfSpouseDeath := false
    inRegisteredDomesticPartnership := false, filerResidenceAndIncomeState := .fl
    spouseItemizes := false, mfsLivingSpouseFilingReturn := false
    mfsDeceasedSpouseFilingReturn := false, mfsSpouseHasGrossIncome := false
    mfsSpouse65OrOlder := false }

/-- A return with the `Defaults` of the Catala test: one W-2. -/
def ret (fs : FilingStatus) (w2s : List FormW2s.FormW2) (household : List HouseholdMember := [])
    (filers : FilersInput := defaultFilers) : CalculatorIn :=
  { filingStatus := fs, filers, primaryExtra := defaultExtra, secondaryExtra := defaultExtra
    household
    income :=
      { w2s, combatPayElection := .noCombatPay, combatPayElectionMade := false
        interestReports := [], form1099Gs := [], form1099Miscs := [], form1099Rs := []
        ssaNetBenefits := [], ssaFederalTaxWithheld := [] }
    adjustments := {}, payments := {}, credits := {}, cdccAnswers := {}, ptcAnswers := {}
    screening := {} }

/-- The Catala assertion `cdcc.taxable_benefits = cdcc_benefits.taxable_benefits`. -/
def taxableBenefitsAgree (o : CalculatorOut) : Bool :=
  o.cdcc.benefits.taxableBenefits == o.cdccBenefits.benefits.taxableBenefits

/-- `TestSingle`. -/
def single := calculator (ret .single [mkW2 5_000_000 500_000])
#guard single.agi == 5_000_000 && single.taxableIncome == 3_540_000 && single.totalTax == 401_900
#guard single.earnedIncomeCredit == 0 && single.overpayment == 98_100 && single.balanceDue == 0
#guard !single.unsupported && single.firedKnockouts == [] && taxableBenefitsAgree single
-- TestRejectsBadOutputs
#guard single.totalTax != 401_600 && single.overpayment != 0 && single.agi != 3_540_000

/-- `TestMfj`: two children. -/
def mfj := calculator (ret .marriedFilingJointly [mkW2 8_000_000 300_000]
  [mkChild ⟨2016, 3, 1⟩, mkChild ⟨2019, 5, 1⟩] { defaultFilers with maritalStatus := .married })
#guard mfj.ctcEligibleDependents == 2 && mfj.numEitcQualifyingChildren == 2
#guard mfj.taxableIncome == 5_080_000 && mfj.totalTentativeTax == 563_500
#guard mfj.totalCtcAndOdc == 400_000 && mfj.totalTax == 163_500 && mfj.earnedIncomeCredit == 0
#guard mfj.additionalCtc == 0 && mfj.overpayment == 136_500 && !mfj.unsupported

/-- `TestMfs`: balance due. -/
def mfs := calculator (ret .marriedFilingSeparately [mkW2 3_000_000 100_000] []
  { defaultFilers with maritalStatus := .married })
#guard mfs.standardOrItemizedDeductions == 1_460_000 && mfs.taxableIncome == 1_540_000
#guard mfs.totalTax == 161_900 && mfs.earnedIncomeCredit == 0 && mfs.balanceDue == 61_900
#guard mfs.overpayment == 0 && !mfs.unsupported

/-- `TestHoh`: one child, EITC and ACTC. -/
def hoh := calculator (ret .headOfHousehold [mkW2 4_000_000 200_000] [mkChild ⟨2014, 9, 10⟩])
#guard hoh.eligibleForHoh && hoh.taxableIncome == 1_810_000 && hoh.totalTentativeTax == 184_400
#guard hoh.totalCtcAndOdc == 184_400 && hoh.totalTax == 0 && hoh.additionalCtc == 15_600
#guard hoh.earnedIncomeCredit == 144_800 && hoh.totalPayments == 360_400
#guard hoh.overpayment == 360_400 && !hoh.unsupported

/-- `TestQss`: one child. -/
def qss := calculator (ret .qualifyingSurvivingSpouse [mkW2 6_000_000 400_000] [mkChild ⟨2012, 2, 20⟩]
  { defaultFilers with
    maritalStatus := .widowed, yearOfSpouseDeath := .diedTaxYearMinusOne
    canFileJointlyYearOfSpouseDeath := true })
#guard qss.eligibleForQss && !qss.eligibleForHoh && qss.taxableIncome == 3_080_000
#guard qss.totalTentativeTax == 323_500 && qss.totalCtcAndOdc == 200_000 && qss.totalTax == 123_500
#guard qss.earnedIncomeCredit == 0 && qss.overpayment == 276_500 && !qss.unsupported

-- TestKnockout: income sources not supported
#guard (calculator { ret .single [mkW2 5_000_000 500_000] with
  screening := { incomeSourcesSupported := false } }).firedKnockouts ==
  [.incomeOrHsa .incomeSourcesNotSupported]

-- TestIneligibleStatus: head of household with no qualifying person
/-- `TestIneligibleStatus`. -/
def ineligible := calculator (ret .headOfHousehold [mkW2 5_000_000 500_000])
#guard !ineligible.eligibleForHoh && ineligible.unsupported
#guard ineligible.firedKnockouts == [.household .extraFilingStatusNotEligible]

/-- Catala `PtcPolicy`: a Form 1095-A for all of 2024 and a filer whose APTC was paid. -/
def ptcPolicy (premium slcsp aptc : Int) : PtcInput :=
  { form1095As :=
      [{ writablePolicyStartDate := ⟨2024, 1, 1⟩, writablePolicyEndDate := ⟨2024, 12, 31⟩
         writableSpecialPolicyModificationInStartingMonth := false
         writableHasPolicyDateException := false, hasCoverageMonths := true
         coverageMonths := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
         writablePremiumsOrSlcspChange := false, hasChangeInCircumstance := false
         writablePtcAnnualPremium := premium, writableSlcspAnnualPremium := slcsp
         writableAptcAnnualAmount := aptc
         writablePtcMonthlyPremium := List.replicate 12 0
         writablePtcMonthlySlcspPremium := List.replicate 12 0
         writablePtcMonthlyAptcPremium := List.replicate 12 0 }]
    writableHasPtcQualifyingPlan := true, writableHasAdvancedPtc := true }

/-- `TestPtcRepayment`: excess APTC repaid, limited to $950, added to the tax. -/
def ptcRepayment := calculator
  { ret .single [mkW2 3_000_000 200_000] with ptcAnswers := ptcPolicy 900_000 1_000_000 1_000_000 }
#guard ptcRepayment.agi == 3_000_000 && ptcRepayment.netPtcAmount == -100_000
#guard ptcRepayment.netPtcAmountWhenZeroOrPositive == 0 && ptcRepayment.netPtcAmountWhenNegative == 100_000
#guard ptcRepayment.ptcRepaymentLimitation == 95_000
#guard ptcRepayment.lesserOfNetPtcAmountAndRepaymentLimitation == 95_000
#guard ptcRepayment.totalAdditionalTaxesOwed == 95_000
#guard ptcRepayment.otherPaymentsAndRefundableCreditsTotal == 0
#guard ptcRepayment.totalTentativeTax == 256_900 && ptcRepayment.totalTax == 256_900
#guard ptcRepayment.totalOtherPaymentsRefundableCredits == 0 && ptcRepayment.balanceDue == 56_900
#guard ptcRepayment.overpayment == 0 && !ptcRepayment.unsupported

/-- `TestPtcNetCredit`: the net PTC is a payment (line 31). -/
def ptcNetCredit := calculator
  { ret .single [mkW2 3_000_000 200_000] with ptcAnswers := ptcPolicy 900_000 1_000_000 200_000 }
#guard ptcNetCredit.netPtcAmount == 700_000 && ptcNetCredit.netPtcAmountWhenZeroOrPositive == 700_000
#guard ptcNetCredit.netPtcAmountWhenNegative == 0 && ptcNetCredit.totalAdditionalTaxesOwed == 0
#guard ptcNetCredit.otherPaymentsAndRefundableCreditsTotal == 700_000 && ptcNetCredit.totalTax == 161_900
#guard ptcNetCredit.totalOtherPaymentsRefundableCredits == 700_000
#guard ptcNetCredit.totalPayments == 900_000 && ptcNetCredit.overpayment == 738_100
#guard ptcNetCredit.balanceDue == 0 && !ptcNetCredit.unsupported

/-- `TestPtcRepaymentRaisesCreditLimit`: line 17 is in the tax the credits are limited by. -/
def ptcRaisesLimit := calculator
  { ret .headOfHousehold [mkW2 4_000_000 200_000] [mkChild ⟨2014, 9, 10⟩] with
    ptcAnswers := ptcPolicy 600_000 700_000 900_000 }
#guard ptcRaisesLimit.netPtcAmount == -300_000 && ptcRaisesLimit.ptcRepaymentLimitation == 190_000
#guard ptcRaisesLimit.totalAdditionalTaxesOwed == 190_000 && ptcRaisesLimit.totalTentativeTax == 374_400
#guard ptcRaisesLimit.totalCtcAndOdc == 200_000 && ptcRaisesLimit.additionalCtc == 0
#guard ptcRaisesLimit.earnedIncomeCredit == 144_800 && ptcRaisesLimit.totalTax == 174_400
#guard ptcRaisesLimit.overpayment == 170_400 && !ptcRaisesLimit.unsupported

-- TestPtcKnockout
/-- `TestPtcKnockout`: an employer-sponsored plan as well as the Marketplace plan. -/
def ptcKnockout := calculator
  { ret .single [mkW2 3_000_000 200_000] with
    ptcAnswers := { ptcPolicy 900_000 1_000_000 200_000 with writableHasEmployerSponsoredPlan := true } }
#guard ptcKnockout.unsupported && ptcKnockout.firedKnockouts == [.household .hasEmployerSponsoredPlan]

end Tests

end UsTax.Calculator
