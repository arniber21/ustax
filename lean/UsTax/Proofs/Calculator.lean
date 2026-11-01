import UsTax.Spec.Calculator
import UsTax.Spec.RefundBalance
import UsTax.Spec.Credits
import UsTax.Calculator
import UsTax.ApiCalculator
import UsTax.Api.Calculate
import UsTax.Proofs.Main
import UsTax.Proofs.Form1040Lines
import UsTax.NonrefundableCredits.Lemmas
import UsTax.PtcHsa.Lemmas
import UsTax.KnockoutsIncome.Lemmas
import UsTax.Audit

/-!
# The whole return, proved (issues #48, #65, #66)

Every Form 1040 line the calculator outputs is a line of its final pass `fFinal`, a
`Form1040.form1040` call (`calculator_fFinal`), so the Form 1040 main theorems carry over:

* `calculator_refund_balanceDue_consistent` (#65): refund and amount owed are exclusive and
  consistent on the whole return;
* `calculator_credits_within_liability`, `calculator_totalTax_nonneg` (#66): the nonrefundable
  credits used (lines 19 + 20 = 21) never exceed line 18, and line 24 is not negative;
* `calculator_credits_le_tax` (#66): the per-credit lemmas of `NonrefundableCredits/Lemmas.lean`
  composed in the calculator's wiring: CDCC, Schedule R and Saver's credits together are within
  line 18 of the tax pass (which includes line 17);
* `calculator_unsupported_iff` and `apiCalculator_supported_iff`: the knockout table is sound, a
  return is unsupported exactly when a reason fired;
* `apiCalculator_outcome_refund_iff`: `outcome = refund` exactly when line 34 is positive.

The statements were tested first in `UsTax/Calculator/Props.lean`. Axioms: `propext`,
`Classical.choice`, `Quot.sound`.
-/

namespace UsTax.Proofs

open UsTax.Spec UsTax.Calculator

/-! ## The outputs are the final Form 1040 pass -/

/-- The final pass is `Form1040.form1040` on its input. -/
theorem calculator_fFinal (i : CalculatorIn) :
    (calculator i).fFinal = Form1040.form1040 (calculator i).fFinalIn := rfl

theorem calculator_totalTax (i : CalculatorIn) : (calculator i).totalTax = (calculator i).fFinal.totalTax := rfl
theorem calculator_totalPayments (i : CalculatorIn) :
    (calculator i).totalPayments = (calculator i).fFinal.totalPayments := rfl
theorem calculator_overpayment (i : CalculatorIn) :
    (calculator i).overpayment = (calculator i).fFinal.overpayment := rfl
theorem calculator_balanceDue (i : CalculatorIn) :
    (calculator i).balanceDue = (calculator i).fFinal.balanceDue := rfl
theorem calculator_totalTentativeTax (i : CalculatorIn) :
    (calculator i).totalTentativeTax = (calculator i).fFinal.totalTentativeTax := rfl
theorem calculator_nonRefundableCredits (i : CalculatorIn) :
    (calculator i).nonRefundableCredits = (calculator i).fFinal.nonRefundableCredits := rfl
theorem calculator_taxLessNonRefundableCredits (i : CalculatorIn) :
    (calculator i).taxLessNonRefundableCredits = (calculator i).fFinal.taxLessNonRefundableCredits := rfl

/-! ## Refund and balance due (#65), credits within the tax (#66) -/

/-- **Refund and amount owed on the whole return**: both nonnegative, at most one nonzero, and
refund minus amount owed is payments minus total tax. -/
theorem calculator_refund_balanceDue_consistent (i : CalculatorIn) :
    RefundOrBalanceDue (calculator i).totalTax (calculator i).totalPayments
      (calculator i).overpayment (calculator i).balanceDue := by
  rw [calculator_totalTax, calculator_totalPayments, calculator_overpayment, calculator_balanceDue,
    calculator_fFinal]
  exact UsTax.Main.refund_balanceDue_consistent _

/-- **Nonrefundable credits used never exceed the tax**: line 22 is line 18 less line 21 (lines
19 + 20), floored at zero. -/
theorem calculator_credits_within_liability (i : CalculatorIn) :
    CreditsWithinLiability (calculator i).totalTentativeTax (calculator i).nonRefundableCredits
      (calculator i).taxLessNonRefundableCredits := by
  rw [calculator_totalTentativeTax, calculator_nonRefundableCredits,
    calculator_taxLessNonRefundableCredits, calculator_fFinal]
  exact UsTax.Main.credits_within_liability _

/-- **Total tax is never negative** on the whole return. -/
theorem calculator_totalTax_nonneg (i : CalculatorIn) : 0 ≤ (calculator i).totalTax := by
  rw [calculator_totalTax, calculator_fFinal]
  exact UsTax.Main.totalTax_nonneg _

/-- The tax pass is `Form1040.form1040` on an input whose line 17 is the excess APTC repayment. -/
theorem calculator_fTax (i : CalculatorIn) :
    ∃ x : Form1040.Form1040In, (calculator i).fTax = Form1040.form1040 x ∧
      x.totalAdditionalTaxesOwed = (calculator i).ptcNet.excessAptcRepayment :=
  ⟨_, rfl, rfl⟩

/-- Line 18 of the tax pass is nonnegative: line 16 and the excess APTC repayment are. -/
theorem calculator_fTax_totalTentativeTax_nonneg (i : CalculatorIn) :
    0 ≤ (calculator i).fTax.totalTentativeTax := by
  obtain ⟨x, hx, h17⟩ := calculator_fTax i
  rw [hx, totalTentativeTax_eq, tentativeTax_eq, h17]
  apply Money.roundDollar_nonneg
  have h1 := TaxRates.tentativeTaxFor_nonneg (Form1040.form1040 x).taxableIncome x.filingStatus
  have h2 : 0 ≤ (calculator i).ptcNet.excessAptcRepayment := by
    have : (calculator i).ptcNet.excessAptcRepayment = (calculator i).ptcNet.line29 := by
      obtain ⟨y, hy⟩ : ∃ y, (calculator i).ptcNet = PtcNet.netPtc y := ⟨_, rfl⟩
      rw [hy]; rfl
    rw [this]
    obtain ⟨y, hy⟩ : ∃ y, (calculator i).ptcNet = PtcNet.netPtc y := ⟨_, rfl⟩
    rw [hy]; exact PtcHsa.Net.line29_nonneg y
  omega

/-- **The CDCC, Schedule R and Saver's credits together are within line 18** (issue #66): the
per-credit limits of `NonrefundableCredits/Lemmas.lean` (`credits_within_tax`), composed in the
calculator's wiring (Schedule R line 3 is line 18 less CDCC; Saver's reads line 18, CDCC and
Schedule R). -/
theorem calculator_credits_le_tax (i : CalculatorIn) :
    CreditsWithinTax (calculator i).cdccTotalCredit (calculator i).totalEdc
      (calculator i).qualifiedSaverCreditAmount (calculator i).fTax.totalTentativeTax := by
  have hc : (calculator i).cdcc = Cdcc.form2441 (calculator i).cdccIn := rfl
  have hr : (calculator i).scheduleR = ElderlyAndDisabled.scheduleR (calculator i).scheduleRIn := rfl
  have hs : (calculator i).savers = SaversCredit.saversCredit (calculator i).saversIn := rfl
  have h3 : (calculator i).scheduleRIn.creditLimitWorksheetLine3 =
      (calculator i).cdccIn.totalTentativeTax - (Cdcc.form2441 (calculator i).cdccIn).cdccTotalCredit :=
    rfl
  have hsIn : (calculator i).saversIn.totalTentativeTax = (calculator i).cdccIn.totalTentativeTax ∧
      (calculator i).saversIn.cdccTotalCredit = (Cdcc.form2441 (calculator i).cdccIn).cdccTotalCredit ∧
      (calculator i).saversIn.totalEdc =
        (ElderlyAndDisabled.scheduleR (calculator i).scheduleRIn).totalEdc := ⟨rfl, rfl, rfl⟩
  have htax : (calculator i).cdccIn.totalTentativeTax = (calculator i).fTax.totalTentativeTax := rfl
  have hnn := calculator_fTax_totalTentativeTax_nonneg i
  have := NonrefundableCredits.credits_within_tax (calculator i).cdccIn (calculator i).scheduleRIn
    (calculator i).saversIn h3 hsIn (by rw [htax]; exact hnn)
  have e1 : (calculator i).cdccTotalCredit = (Cdcc.form2441 (calculator i).cdccIn).cdccTotalCredit := rfl
  have e2 : (calculator i).totalEdc = (ElderlyAndDisabled.scheduleR (calculator i).scheduleRIn).totalEdc :=
    rfl
  have e3 : (calculator i).qualifiedSaverCreditAmount =
      (SaversCredit.saversCredit (calculator i).saversIn).qualifiedSaverCreditAmount := rfl
  unfold CreditsWithinTax
  rw [e1, e2, e3, ← htax]
  exact this

/-! ## Knockout soundness -/

/-- An `Interest` instance at AGI $0 knocks out only where the same instance at any AGI does:
the three AGI knockouts need an AGI above a positive threshold. -/
theorem interest_unsupported_of_agi_zero (j : Interest.InterestIn) (a : Int) (h0 : j.agi = 0)
    (h : (Interest.interest j).unsupported = true) :
    (Interest.interest { j with agi := a }).unsupported = true := by
  rw [KnockoutsIncome.interest_unsupported] at h ⊢
  have e1 : (Interest.interest j).koHasInterestIncomeAndAgiAboveThresholdForMfs = false := by
    simp [Interest.interest, h0, Params.niitThresholdMarriedSeparate, TaxRates.usd]
  have e2 : (Interest.interest j).koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss = false := by
    simp [Interest.interest, h0, Params.niitThresholdJointOrSurvivingSpouse, TaxRates.usd]
  have e3 : (Interest.interest j).koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh = false := by
    simp [Interest.interest, h0, Params.niitThresholdOther, TaxRates.usd]
  have r1 : (Interest.interest { j with agi := a }).koHasRequiredFactaFilings =
    (Interest.interest j).koHasRequiredFactaFilings := rfl
  have r2 : (Interest.interest { j with agi := a }).koFlowKnockoutHasEarlyWithdrawlPenalty =
    (Interest.interest j).koFlowKnockoutHasEarlyWithdrawlPenalty := rfl
  have r3 : (Interest.interest { j with agi := a }).koFlowKnockoutHasBonds =
    (Interest.interest j).koFlowKnockoutHasBonds := rfl
  have r4 : (Interest.interest { j with agi := a }).koFlowKnockoutHasForeignTaxPaid =
    (Interest.interest j).koFlowKnockoutHasForeignTaxPaid := rfl
  have r5 : (Interest.interest { j with agi := a }).koFlowKnockoutWithholdingUnsupportedState =
    (Interest.interest j).koFlowKnockoutWithholdingUnsupportedState := rfl
  have r6 : (Interest.interest { j with agi := a }).koFlowKnockoutStateTaxWithheld =
    (Interest.interest j).koFlowKnockoutStateTaxWithheld := rfl
  have r7 : (Interest.interest { j with agi := a }).koFlowKnockoutTaxExemptInterest =
    (Interest.interest j).koFlowKnockoutTaxExemptInterest := rfl
  rw [e1, e2, e3] at h
  rw [r1, r2, r3, r4, r5, r6, r7]
  revert h
  generalize (Interest.interest j).koHasRequiredFactaFilings = b1
  generalize (Interest.interest j).koFlowKnockoutHasEarlyWithdrawlPenalty = b2
  generalize (Interest.interest j).koFlowKnockoutHasBonds = b3
  generalize (Interest.interest j).koFlowKnockoutHasForeignTaxPaid = b4
  generalize (Interest.interest j).koFlowKnockoutWithholdingUnsupportedState = b5
  generalize (Interest.interest j).koFlowKnockoutStateTaxWithheld = b6
  generalize (Interest.interest j).koFlowKnockoutTaxExemptInterest = b7
  intro h
  cases b1 <;> cases b2 <;> cases b3 <;> cases b4 <;> cases b5 <;> cases b6 <;> cases b7 <;>
    simp_all

/-- **Form 1040's own knockouts are income knockouts**: the W-2 and interest knockouts
`Form1040.form1040` reports, and `/knockoutHasNoPaymentsOrCredits`, are members of
`KnockoutsIncome` when it reads the same forms, the same foreign-accounts answer (it decides Schedule B, and so the interest rounding), the
same AGI and the same no-payments flag. -/
theorem form1040_unsupported_imp (x : Form1040.Form1040In) (k : KnockoutsIncome.KnockoutsIncomeIn)
    (hw : k.w2s = x.w2s) (hfs : k.filingStatus = x.filingStatus)
    (hp : k.primaryFilerCanBeClaimed = x.primaryFilerCanBeClaimed)
    (hs : k.secondaryFilerCanBeClaimed = x.secondaryFilerCanBeClaimed)
    (hc : k.combatPayElection = x.combatPayElection) (hi : k.interestReports = x.interestReports)
    (hf : KnockoutsIncome.hasForeignAccountsOrTrusts k = x.hasForeignAccountsOrTrusts)
    (hagi : k.agi = (Form1040.form1040 x).agi)
    (hko : k.knockoutHasNoPaymentsOrCredits = (Form1040.form1040 x).koKnockoutHasNoPaymentsOrCredits)
    (h : (Form1040.form1040 x).unsupported = true) :
    KnockoutsIncome.unsupportedIncomeOrHsa k = true := by
  let ii : Interest.InterestIn :=
    { interestReports := x.interestReports, hasForeignAccountsOrTrusts := x.hasForeignAccountsOrTrusts,
      filingStatus := x.filingStatus, agi := 0, flowHasSeenDeductions := true }
  let wi : FormW2s.FormW2sIn :=
    { w2s := x.w2s, filingStatus := x.filingStatus
      primaryFilerCanBeClaimed := x.primaryFilerCanBeClaimed
      secondaryFilerCanBeClaimed := x.secondaryFilerCanBeClaimed
      combatPayElection := x.combatPayElection }
  have e : (Form1040.form1040 x).unsupported =
      ((FormW2s.formW2s wi).unsupported ||
        (Interest.interest ii).unsupported ||
        (Interest.interest { ii with agi := (Form1040.form1040 x).agi }).unsupported ||
        (Form1040.form1040 x).koKnockoutHasNoPaymentsOrCredits) := rfl
  have ew : (KnockoutsIncome.w2 k).unsupported = (FormW2s.formW2s wi).unsupported := by
    simp only [KnockoutsIncome.w2, hw, hfs, hp, hs, hc]; rfl
  have ei : (KnockoutsIncome.interest k).unsupported =
      (Interest.interest { ii with agi := (Form1040.form1040 x).agi }).unsupported := by
    simp only [KnockoutsIncome.interest, hi, hfs, hagi, hf]; rfl
  have el : k.knockoutHasNoPaymentsOrCredits = true → KnockoutsIncome.unsupportedLocal k = true := by
    intro hk; simp [KnockoutsIncome.unsupportedLocal, KnockoutsIncome.localKnockouts, hk]
  rw [e] at h
  simp only [Bool.or_eq_true] at h
  unfold KnockoutsIncome.unsupportedIncomeOrHsa
  rcases h with ((h | h) | h) | h
  · rw [← ew] at h; simp [h]
  · have := interest_unsupported_of_agi_zero ii (Form1040.form1040 x).agi rfl h
    rw [← ei] at this; simp [this]
  · rw [← ei] at h; simp [h]
  · rw [← hko] at h; simp [el h]

/-- The no-reason flags each merged household, credit and premium tax credit module reports are
exactly the `ko_` conditions it passes to `KnockoutsHousehold`. -/
theorem calculator_householdKo (i : CalculatorIn) :
    (calculator i).householdKo.unsupportedHousehold = true ↔
      (KnockoutsHousehold.bornAndDiedInTaxYearWithoutTin i.screening.memberVitals = true ∨
        (calculator i).filersKo.unsupported = true ∨ (calculator i).hohQss.unsupported = true ∨
        (calculator i).benefitSplit.unsupported = true ∨ (calculator i).savers.unsupported = true ∨
        (calculator i).cdcc.unsupported = true ∨ (calculator i).ptcAllowed.unsupported = true ∨
        (calculator i).qualifyingChildren.unsupported = true ∨ (calculator i).eitc.unsupported = true ∨
        (calculator i).filingStatusCheck.unsupported = true) := by
  obtain ⟨y1, h1⟩ : ∃ y, (calculator i).filersKo = Filers.filers y := ⟨_, rfl⟩
  obtain ⟨y2, h2⟩ : ∃ y, (calculator i).hohQss = HohQssPersons.hohQssPersons y := ⟨_, rfl⟩
  obtain ⟨y3, h3⟩ : ∃ y, (calculator i).benefitSplit = DependentsBenefitSplit.benefitSplit y := ⟨_, rfl⟩
  obtain ⟨y4, h4⟩ : ∃ y, (calculator i).savers = SaversCredit.saversCredit y := ⟨_, rfl⟩
  obtain ⟨y5, h5⟩ : ∃ y, (calculator i).cdcc = Cdcc.form2441 y := ⟨_, rfl⟩
  obtain ⟨y6, h6⟩ : ∃ y, (calculator i).ptcAllowed = PtcAllowed.ptcAllowed y := ⟨_, rfl⟩
  obtain ⟨y7, h7⟩ : ∃ y, (calculator i).qualifyingChildren = QualifyingChild.qualifyingChildren y :=
    ⟨_, rfl⟩
  obtain ⟨y8, h8⟩ : ∃ y, (calculator i).eitc = Eitc.earnedIncomeCredit y := ⟨_, rfl⟩
  obtain ⟨y9, h9⟩ : ∃ y, (calculator i).filingStatusCheck = FilingStatusMod.eligibility y := ⟨_, rfl⟩
  have hk : (calculator i).householdKo.unsupportedHousehold =
      (KnockoutsHousehold.bornAndDiedInTaxYearWithoutTin i.screening.memberVitals ||
        (calculator i).filersKo.koFlowKnockoutFilerAgeYoungerThan16 ||
        (calculator i).filersKo.koSpouseItemizesKnockout ||
        (calculator i).filersKo.koPrimaryFilerResidencyKnockout ||
        (calculator i).filersKo.koFlowKnockoutHasApplicableRegisteredDomesticPartnership ||
        (calculator i).filersKo.koKnockoutSubjectToCommunityPropertyLaws ||
        (calculator i).hohQss.koKnockoutHohQpHasNoTin ||
        (calculator i).benefitSplit.koKnockedOutByNonCustodialParentBenefitSplit ||
        (calculator i).benefitSplit.koKnockedOutByContradictory8832 ||
        (calculator i).savers.koSaversCreditKnockouts ||
        (calculator i).cdcc.koFlowKnockoutBenefitsDistribution ||
        (calculator i).cdcc.benefits.koKnockoutCdccWorksheetA ||
        (calculator i).cdcc.benefits.koKnockoutHouseholdEmployee ||
        (calculator i).ptcAllowed.koDependentTpRequiresAllocations ||
        (calculator i).ptcAllowed.koHasPtcQualifyingPlanAndQsehra ||
        (calculator i).ptcAllowed.koNeedsAllocations ||
        (calculator i).ptcAllowed.koHasEmployerSponsoredPlan ||
        (calculator i).ptcAllowed.koDependentsRequiredToFile ||
        (calculator i).ptcAllowed.koSelfReportedHasMultiple1095As ||
        (calculator i).ptcAllowed.koHasImmigrationStatusNotEligibleForMarketplace ||
        (calculator i).ptcAllowed.koWantsToUseAltCalculations ||
        (calculator i).qualifyingChildren.koQualifyingChildTieBreaker ||
        (calculator i).eitc.koClaimedSpouseCombatPayWithoutMfj ||
        (calculator i).filingStatusCheck.koFilingStatusNotEligible ||
        (calculator i).cdcc.benefits.koSoleProprietorshipBenefits ||
        (calculator i).cdcc.benefits.koBothSpousesDeemedIncome ||
        (calculator i).ptcAllowed.koTpNeedsToAdd1095A ||
        (calculator i).ptcAllowed.koTpNeedsToDelete1095A) := rfl
  have u1 : (Filers.filers y1).unsupported = ((Filers.filers y1).koFlowKnockoutFilerAgeYoungerThan16 ||
      (Filers.filers y1).koSpouseItemizesKnockout || (Filers.filers y1).koPrimaryFilerResidencyKnockout ||
      (Filers.filers y1).koFlowKnockoutHasApplicableRegisteredDomesticPartnership ||
      (Filers.filers y1).koKnockoutSubjectToCommunityPropertyLaws) := rfl
  have u2 : (HohQssPersons.hohQssPersons y2).unsupported =
      (HohQssPersons.hohQssPersons y2).koKnockoutHohQpHasNoTin := rfl
  have u3 : (DependentsBenefitSplit.benefitSplit y3).unsupported =
      ((DependentsBenefitSplit.benefitSplit y3).koKnockedOutByContradictory8832 ||
        (DependentsBenefitSplit.benefitSplit y3).koKnockedOutByNonCustodialParentBenefitSplit) := rfl
  have u4 : (SaversCredit.saversCredit y4).unsupported =
      (SaversCredit.saversCredit y4).koSaversCreditKnockouts := rfl
  have u5 : (Cdcc.form2441 y5).unsupported = (((Cdcc.form2441 y5).benefits.koKnockoutCdccWorksheetA ||
      (Cdcc.form2441 y5).benefits.koKnockoutHouseholdEmployee ||
      (Cdcc.form2441 y5).benefits.koSoleProprietorshipBenefits ||
      (Cdcc.form2441 y5).benefits.koBothSpousesDeemedIncome) ||
      (Cdcc.form2441 y5).koFlowKnockoutBenefitsDistribution) := rfl
  have u6 : (PtcAllowed.ptcAllowed y6).unsupported =
      let o := PtcAllowed.ptcAllowed y6
      (o.koDependentTpRequiresAllocations || o.koHasPtcQualifyingPlanAndQsehra || o.koNeedsAllocations ||
        o.koHasEmployerSponsoredPlan || o.koDependentsRequiredToFile || o.koSelfReportedHasMultiple1095As ||
        o.koHasImmigrationStatusNotEligibleForMarketplace || o.koWantsToUseAltCalculations ||
        o.koTpNeedsToAdd1095A || o.koTpNeedsToDelete1095A) := rfl
  have u7 : (QualifyingChild.qualifyingChildren y7).unsupported =
      (QualifyingChild.qualifyingChildren y7).koQualifyingChildTieBreaker := rfl
  have u8 : (Eitc.earnedIncomeCredit y8).unsupported =
      (Eitc.earnedIncomeCredit y8).koClaimedSpouseCombatPayWithoutMfj := rfl
  have u9 : (FilingStatusMod.eligibility y9).unsupported =
      (FilingStatusMod.eligibility y9).koFilingStatusNotEligible := rfl
  rw [hk]
  rw [h1, h2, h3, h4, h5, h6, h7, h8, h9] at *
  rw [u1, u2, u3, u4, u5, u6, u7, u8, u9]
  simp only [Bool.or_eq_true, or_assoc]
  constructor <;> intro h <;>
    rcases h with h | h | h | h | h | h | h | h | h | h | h | h | h | h | h | h | h | h | h |
      h | h | h | h | h | h | h | h | h <;> simp [h]

/-- The final Form 1040 pass knocks out only where `KnockoutsIncome` does: the calculator gives
both the same forms, AGI and no-payments flag (each hypothesis of `form1040_unsupported_imp` is
`rfl` on the calculator's wiring). -/
theorem calculator_fFinal_unsupported (i : CalculatorIn) (h : (calculator i).fFinal.unsupported = true) :
    (calculator i).incomeKo.unsupportedIncomeOrHsa = true := by
  rw [calculator_fFinal] at h
  exact form1040_unsupported_imp (calculator i).fFinalIn (calculator i).incomeKoIn
    rfl rfl rfl rfl rfl rfl rfl rfl rfl h

/-- The calculator's `unsupported` (every module's own flag, `flow.xml` `/flowIsKnockedOut`) is
exactly "an income/HSA/process knockout or a household/credit/PTC knockout of the two tables". -/
theorem calculator_unsupported_iff_tables (i : CalculatorIn) :
    (calculator i).unsupported = true ↔
      ((calculator i).incomeKo.unsupportedIncomeOrHsa = true ∨
        (calculator i).householdKo.unsupportedHousehold = true) := by
  have e : (calculator i).unsupported =
      ((calculator i).incomeKo.unsupportedIncomeOrHsa || (calculator i).fFinal.unsupported ||
        (calculator i).householdKo.unsupportedHousehold || (calculator i).filersKo.unsupported ||
        (calculator i).qualifyingChildren.unsupported || (calculator i).benefitSplit.unsupported ||
        (calculator i).hohQss.unsupported || (calculator i).eitc.unsupported ||
        (calculator i).savers.unsupported || (calculator i).filingStatusCheck.unsupported ||
        (calculator i).cdcc.unsupported || (calculator i).ptcAllowed.unsupported) := rfl
  have hf := calculator_fFinal_unsupported i
  have hk := (calculator_householdKo i).2
  rw [e]
  simp only [Bool.or_eq_true, or_assoc]
  constructor
  · rintro (h | h | h | h | h | h | h | h | h | h | h | h)
    · exact Or.inl h
    · exact Or.inl (hf h)
    · exact Or.inr h
    all_goals exact Or.inr (hk (by simp [h]))
  · rintro (h | h) <;> simp [h]

/-- The reason list is the two tables' lists, one after the other. -/
theorem calculator_firedKnockouts_eq_nil_iff (i : CalculatorIn) :
    (calculator i).firedKnockouts = [] ↔
      ((calculator i).incomeKo.firedKnockouts = [] ∧ (calculator i).householdKo.firedKnockouts = []) := by
  have e : (calculator i).firedKnockouts =
      (((calculator i).incomeKo.firedKnockouts.map
          (fun r => (⟨.incomeOrHsa r, true⟩ : CalculatorKnockoutEntry)) ++
        (calculator i).householdKo.firedKnockouts.map
          (fun r => (⟨.household r, true⟩ : CalculatorKnockoutEntry))).filter (·.fired)).map
        (·.reason) := rfl
  rw [e]
  simp only [List.filter_append, List.filter_map, Function.comp_def,
    List.map_append, List.map_map, List.append_eq_nil_iff, List.map_eq_nil_iff]
  have hf : ∀ l : List Api.KnockoutReason, List.filter (fun _ => true) l = l := by
    intro l
    induction l with
    | nil => rfl
    | cons a l ih => simp only [List.filter_cons, ↓reduceIte, ih]
  rw [hf, hf]

/-- **Knockout soundness of the whole return**: the return is unsupported exactly when at least
one reason fired. -/
theorem calculator_unsupported_iff (i : CalculatorIn) :
    (calculator i).unsupported = true ↔ (calculator i).firedKnockouts ≠ [] := by
  rw [calculator_unsupported_iff_tables, Ne, calculator_firedKnockouts_eq_nil_iff]
  obtain ⟨k, hk⟩ : ∃ k, (calculator i).incomeKo = KnockoutsIncome.knockoutsIncome k := ⟨_, rfl⟩
  obtain ⟨y, hy⟩ : ∃ y, (calculator i).householdKo = KnockoutsHousehold.knockoutsHousehold y := ⟨_, rfl⟩
  rw [hk, hy, KnockoutsIncome.firedKnockouts_eq_nil_iff, KnockoutsHousehold.firedKnockouts_eq_nil_iff]
  cases (KnockoutsIncome.knockoutsIncome k).unsupportedIncomeOrHsa <;>
    cases (KnockoutsHousehold.knockoutsHousehold y).unsupportedHousehold <;> simp

/-! ## The API answer -/

open ApiCalculator in
/-- **The API answer is sound**: `supported` is false exactly when `reasons` is non-empty. -/
theorem apiCalculator_supported_iff (r : Api.Request) :
    KnockoutSound (apiCalculator r).supported (apiCalculator r).reasons := by
  have h := calculator_unsupported_iff (Api.toCalculatorInput r)
  unfold KnockoutSound apiCalculator
  generalize Calculator.calculator (Api.toCalculatorInput r) = c at h ⊢
  cases hu : c.unsupported <;> simp_all

open ApiCalculator in
/-- **`outcome = refund` exactly when line 34 is positive** (an unsupported return has
`outcome = even` and no lines). -/
theorem apiCalculator_outcome_refund_iff (r : Api.Request) :
    RefundOutcome (apiCalculator r).outcome (apiCalculator r).lines.overpayment := by
  unfold RefundOutcome apiCalculator
  generalize Calculator.calculator (Api.toCalculatorInput r) = c
  dsimp only
  cases hu : c.unsupported
  · simp only [Bool.false_eq_true, ↓reduceIte, linesOf]
    by_cases ho : 0 < c.overpayment <;> by_cases hb : 0 < c.balanceDue <;>
      simp [outcomeOf, ho, hb]
  · simp [zeroLines]

open ApiCalculator in
/-- Refund and amount owed in the API `lines` are exclusive and consistent (#65), for every
request (an unsupported return's lines are all zero). -/
theorem apiCalculator_refund_balanceDue_consistent (r : Api.Request) :
    RefundOrBalanceDue (apiCalculator r).lines.totalTax (apiCalculator r).lines.totalPayments
      (apiCalculator r).lines.overpayment (apiCalculator r).lines.balanceDue := by
  have h := calculator_refund_balanceDue_consistent (Api.toCalculatorInput r)
  unfold apiCalculator
  generalize Calculator.calculator (Api.toCalculatorInput r) = c at h ⊢
  dsimp only
  cases hu : c.unsupported
  · simpa [linesOf] using h
  · simp [zeroLines, RefundOrBalanceDue]

/-- **The pure calculator never returns its internal-inconsistency result**: an unsupported
return always has a reason to report. HTTP and runtime exceptions are outside this theorem. -/
theorem calculateRequest_ne_fault (r : Api.Request) (h : r.Valid) :
    Api.calculateRequest r h ≠ .fault := by
  have hs := apiCalculator_supported_iff r
  unfold KnockoutSound at hs
  unfold Api.calculateRequest
  generalize ApiCalculator.apiCalculator r = o at hs ⊢
  cases hsup : o.supported
  · have hne := hs.1 hsup
    simp only [hsup, Bool.false_eq_true, ↓reduceIte, ApiCalculator.ApiCalculatorOut.unsupportedReasons]
    cases hr : o.reasons with
    | nil => exact absurd hr hne
    | cons x xs => simp
  · simp only [hsup, ↓reduceIte]
    split <;> simp

/-! ## The theorems on concrete returns (CLAUDE.md section 4)

The statements have no hypothesis (but `calculateRequest_ne_fault`, whose `r.Valid` every parsed
request has, `Api.parseRequest_sound`); here each is instantiated on a return of the Catala tests
(`Calculator.Tests`, whose values are `#guard`ed there: `hoh` is a $3,604 refund, `ineligible`
is knocked out with `ExtraFilingStatusNotEligible`, `mfj` has $4,000 of child tax credit). -/

open Calculator.Tests in
example : RefundOrBalanceDue hoh.totalTax hoh.totalPayments hoh.overpayment hoh.balanceDue :=
  calculator_refund_balanceDue_consistent _

open Calculator.Tests in
example : ineligible.unsupported = true ↔ ineligible.firedKnockouts ≠ [] :=
  calculator_unsupported_iff _

open Calculator.Tests in
example : CreditsWithinTax mfj.cdccTotalCredit mfj.totalEdc mfj.qualifiedSaverCreditAmount
    mfj.fTax.totalTentativeTax ∧ 0 ≤ mfj.totalTax :=
  ⟨calculator_credits_le_tax _, calculator_totalTax_nonneg _⟩

/-- `calculateRequest_ne_fault`: its hypothesis is what the parser proves of every request. -/
example (body : String) (r : Api.Request) (h : Api.parseRequest body = .ok r) :
    Api.calculateRequest r (Api.parseRequest_sound h) ≠ .fault :=
  calculateRequest_ne_fault _ _

end UsTax.Proofs

#audit_axioms UsTax.Proofs.calculator_refund_balanceDue_consistent
#audit_axioms UsTax.Proofs.calculator_credits_within_liability
#audit_axioms UsTax.Proofs.calculator_totalTax_nonneg
#audit_axioms UsTax.Proofs.calculator_credits_le_tax
#audit_axioms UsTax.Proofs.calculator_unsupported_iff
#audit_axioms UsTax.Proofs.apiCalculator_supported_iff
#audit_axioms UsTax.Proofs.apiCalculator_outcome_refund_iff
#audit_axioms UsTax.Proofs.apiCalculator_refund_balanceDue_consistent
#audit_axioms UsTax.Proofs.calculateRequest_ne_fault
