import UsTax.KnockoutsIncome
import UsTax.Audit

/-!
# Knockouts A: the reason list is sound (issue #48)

`unsupportedIncomeOrHsa` (the disjunction of each module's own `unsupported` and the local
knockouts) is exactly "some row of the reason table fired", so the list of reasons
(`firedKnockouts`) is empty exactly when the return is supported by these modules. The proof needs
each module's `unsupported` to be the disjunction of the `ko_` outputs the table lists (true by
definition of each module, `rfl` below); the Form 1099-R module lists them in another order, which
`ac_rfl` absorbs. Axioms: `propext`, `Classical.choice`, `Quot.sound` (or fewer).
-/

namespace UsTax.KnockoutsIncome

theorem interest_unsupported (x : Interest.InterestIn) : (Interest.interest x).unsupported =
    ((Interest.interest x).koHasRequiredFactaFilings ||
      (Interest.interest x).koFlowKnockoutHasEarlyWithdrawlPenalty ||
      (Interest.interest x).koFlowKnockoutHasBonds || (Interest.interest x).koFlowKnockoutHasForeignTaxPaid ||
      (Interest.interest x).koFlowKnockoutWithholdingUnsupportedState ||
      (Interest.interest x).koFlowKnockoutStateTaxWithheld ||
      (Interest.interest x).koHasInterestIncomeAndAgiAboveThresholdForMfs ||
      (Interest.interest x).koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss ||
      (Interest.interest x).koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh ||
      (Interest.interest x).koFlowKnockoutTaxExemptInterest) := rfl

theorem w2_unsupported (x : FormW2s.FormW2sIn) : (FormW2s.formW2s x).unsupported =
    ((FormW2s.formW2s x).koKnockoutForBox12Value || (FormW2s.formW2s x).koKnockoutForBox12Dependency ||
      (FormW2s.formW2s x).koFlowKnockoutAllocatedTips || (FormW2s.formW2s x).koFlowKnockoutStatutoryEmployee ||
      (FormW2s.formW2s x).koFlowKnockoutThirdPartySickPay ||
      (FormW2s.formW2s x).koFlowKnockoutNonQualifiedPlans ||
      (FormW2s.formW2s x).koKnockoutMedicareWages || (FormW2s.formW2s x).koAnyFilerExceedsMaxOasdiWages) :=
  rfl

theorem unemp_unsupported (x : Unemployment.UnemploymentIn) : (Unemployment.unemployment x).unsupported =
    ((Unemployment.unemployment x).koFlowKnockout1099GRepayTooHigh ||
      (Unemployment.unemployment x).koFlowKnockoutUnemploymentCompensationUnsupportedState) := rfl

theorem misc_unsupported (x : Form1099Misc.Form1099MiscsIn) :
    (Form1099Misc.form1099Miscs x).unsupported = (Form1099Misc.form1099Miscs x).koNonPfd1099Misc := rfl

theorem rs_unsupported (x : Form1099Rs.Form1099RsIn) : (Form1099Rs.form1099Rs x).unsupported =
    let o := Form1099Rs.form1099Rs x
    (o.koKnockoutForForm1099RDistributionCode || o.koKnockoutIraSepSimple ||
      o.koKnockoutTaxablePensionRollover || o.koKnockoutIndirectRollover ||
      o.koKnockoutTaxableAmountNotDetermined || o.koFlowKnockoutForRollover ||
      o.koFlowKnockoutForPreTaxToPostTaxRollover || o.koFlowKnockoutRetirementTaxableAmountNotDetermined ||
      o.koFlowKnockoutRetirementTaxableAmountBlank || o.koFlowKnockoutRetirementTotalDistribution ||
      o.koKnockoutForForm1099RBox8Value || o.koKnockoutForForm1099RBox8Percentage ||
      o.koKnockoutForForm1099RBox9aPercentage || o.koFlowKnockoutRetirementCapitalGain ||
      o.koFlowKnockoutRetirementNetUnrealizedAppreciation || o.koFlowKnockoutRetirementAmountAllocableToIrr ||
      o.koFlowKnockoutRetirementFactaFilingRequirement || o.koFlowKnockoutForDeathBenefitPaymentDate ||
      o.koFlowKnockoutRetirementQualifiedDisasterDistribution ||
      o.koFlowKnockoutRetirementPublicSafetyOfficer || o.koFlowKnockoutBox15) := rfl

theorem ep_unsupported (x : EstimatedPayments.EstimatedPaymentsIn) :
    (EstimatedPayments.estimatedPayments x).unsupported =
      (EstimatedPayments.estimatedPayments x).koKnockoutPaidEstimatedTaxesUnderDifferentLastName := rfl

theorem hsa_unsupported (x : Hsa.HsaIn) : (Hsa.hsa x).unsupported =
    let o := Hsa.hsa x
    (o.koNoPaymentsHsaDistribution || o.koHsaMedicalSavingsAccountType || o.koHsaDistributionCode ||
      o.koOtherCoveragePartOfYear || o.koOtherCoverageWholeYear || o.koEarningsOnExcessContributions ||
      o.koHsaTestingPeriodAdditionalIncomeYes || o.koHsaUnqualifiedDistributions ||
      o.koHsaDistributionFmv || o.koMaritalChangeAffectsContributionLimit || o.koMfsLine6Check ||
      o.koHsaContributionsOverLimit || o.koHsaExcessContributions ||
      o.koContributionSummaryNoneAllowed || o.koHdhpCoverageStatusNotNeeded || o.koNotEnrolledInHdhp ||
      o.koMadeQualifiedHsaFundingDistribution || o.koHsaCoverage ||
      o.koFilerIsDependentAndContributesToHsa || o.koHasHsaDistributionsWithoutActivity ||
      o.koHsaDistributionsSecondaryFilerUsedWithoutMfj) := rfl

/-- The combined flag is exactly "some row of the table fired". -/
theorem unsupportedIncomeOrHsa_eq_any (i : KnockoutsIncomeIn) :
    unsupportedIncomeOrHsa i = (knockoutTable i).any (·.fired) := by
  simp only [unsupportedIncomeOrHsa, unsupportedLocal, interest, w2, unemp, misc, rs, ep, hsa,
    interest_unsupported, w2_unsupported, unemp_unsupported, misc_unsupported, rs_unsupported,
    ep_unsupported, hsa_unsupported, knockoutTable, interestKnockouts, formW2Knockouts,
    unemploymentKnockouts, form1099MiscKnockouts, form1099RKnockouts, socialSecurityKnockouts,
    estimatedPaymentsKnockouts, hsaKnockouts, List.any_cons, List.any_nil, Bool.or_false]
  ac_rfl

/-- **Soundness of the reason list**: it is empty exactly when no income, HSA or process
knockout fired. -/
theorem firedKnockouts_eq_nil_iff (i : KnockoutsIncomeIn) :
    (knockoutsIncome i).firedKnockouts = [] ↔ (knockoutsIncome i).unsupportedIncomeOrHsa = false := by
  simp only [knockoutsIncome, firedOf_eq_nil_iff, unsupportedIncomeOrHsa_eq_any]

end UsTax.KnockoutsIncome

#audit_axioms UsTax.KnockoutsIncome.unsupportedIncomeOrHsa_eq_any
#audit_axioms UsTax.KnockoutsIncome.firedKnockouts_eq_nil_iff
