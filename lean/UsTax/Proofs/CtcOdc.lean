import UsTax.CtcOdc
import UsTax.Money.Lemmas
import UsTax.Audit

/-!
# Structural lemmas of Schedule 8812 (issue #46)

Cheap facts about the Lean `schedule8812` (`UsTax/CtcOdc.lean`), property-tested first in
`UsTax/Eitc/Props.lean`:

* `totalCtcAndOdc_nonneg`: Form 1040 line 19 (CTC and ODC) is never negative, for every input.
* `totalCtcAndOdc_le_potential`: it is at most Schedule 8812 line 8 (the credits before the
  phase-out), for nonnegative dependent counts.
* `additionalCtc_nonneg`, `additionalCtc_le_cap`: the additional child tax credit (line 27,
  Form 1040 line 28) is never negative and is at most $1,700 per qualifying child (the
  refundable cap of Rev. Proc. 2023-34 § 3.05), for a nonnegative count.
* `dependentCreditPhaseout_mono`: the phase-out (line 11) does not decrease when AGI grows,
  the other figures and the filing status staying the same.

Each is stated with the fields of the output; the field equations are `rfl` (the `let`s of the
scope are definitional).
-/

namespace UsTax.Proofs

open UsTax.CtcOdc UsTax.Money

section FieldEquations

variable (i : Schedule8812In)

theorem s8812_totalCtcAndOdc_eq : (schedule8812 i).totalCtcAndOdc =
    roundDollar (Money.min (schedule8812 i).dependentCreditLessPhaseout
      (schedule8812 i).sched8812CreditLimit) := rfl

theorem s8812_lessPhaseout_eq : (schedule8812 i).dependentCreditLessPhaseout =
    roundDollar (positive ((schedule8812 i).totalPotentialDependentCredits -
      (schedule8812 i).dependentCreditPhaseout)) := rfl

theorem s8812_creditLimit_eq : (schedule8812 i).sched8812CreditLimit =
    positive (i.totalTentativeTax - (i.cdccTotalCredit + i.qualifiedSaverCreditAmount + i.totalEdc)) :=
  rfl

theorem s8812_potentialDependent_eq : (schedule8812 i).totalPotentialDependentCredits =
    roundDollar ((schedule8812 i).totalPotentialCtc + (schedule8812 i).totalPotentialOdc) := rfl

theorem s8812_phaseout_eq : (schedule8812 i).dependentCreditPhaseout =
    roundDollar (mulRate (schedule8812 i).roundedDependentCreditMagiAboveThreshold
      (divMoney Params.ctcPhaseoutReductionPerStep Params.ctcPhaseoutStep)) := rfl

theorem s8812_rounded_eq : (schedule8812 i).roundedDependentCreditMagiAboveThreshold =
    roundDollar (stepwiseMultiply ((schedule8812 i).dependentCreditMagiAboveThreshold +
      Params.ctcPhaseoutStep - 1) 1000 1000) := rfl

theorem s8812_above_eq : (schedule8812 i).dependentCreditMagiAboveThreshold =
    positive ((schedule8812 i).dependentCreditMagi -
      (schedule8812 i).dependentCreditPhaseoutThreshold) := rfl

theorem s8812_magi_eq : (schedule8812 i).dependentCreditMagi = roundDollar i.agi := rfl

theorem s8812_threshold_eq : (schedule8812 i).dependentCreditPhaseoutThreshold =
    if i.filingStatus == .marriedFilingJointly then Params.ctcPhaseoutThresholdJoint
    else Params.ctcPhaseoutThresholdOther := rfl

theorem s8812_potentialCtc_eq : (schedule8812 i).totalPotentialCtc =
    roundDollar (if (schedule8812 i).ctcOdcDisqualifiedForImproperClaims ||
        !(schedule8812 i).maybeEligibleForCtc then 0
      else mulRate Params.ctcPerQualifyingChild (i.ctcEligibleDependents : Rat)) := rfl

theorem s8812_potentialOdc_eq : (schedule8812 i).totalPotentialOdc =
    roundDollar (if (schedule8812 i).ctcOdcDisqualifiedForImproperClaims ||
        !(schedule8812 i).maybeEligibleForOdc then 0
      else mulRate Params.odcPerOtherDependent (i.odcEligibleDependents : Rat)) := rfl

theorem s8812_potentialActc_eq : (schedule8812 i).totalPotentialActc =
    roundDollar (if (schedule8812 i).ctcOdcDisqualifiedForImproperClaims ||
        !(schedule8812 i).maybeEligibleForCtc then 0
      else mulRate Params.actcPerQualifyingChildCap (i.ctcEligibleDependents : Rat)) := rfl

theorem s8812_remaining_eq : (schedule8812 i).remainingCtcAndOdc =
    roundDollar (positive ((schedule8812 i).dependentCreditLessPhaseout -
      (schedule8812 i).totalCtcAndOdc)) := rfl

theorem s8812_remainingPotential_eq : (schedule8812 i).remainingPotentialActc =
    roundDollar (Money.min (schedule8812 i).remainingCtcAndOdc
      (schedule8812 i).totalPotentialActc) := rfl

theorem s8812_regularMax_eq : (schedule8812 i).regularMaximumActc =
    roundDollar (mulRate (schedule8812 i).earnedIncomeAboveActcRefundabilityThreshold
      Params.actcEarnedIncomeRate) := rfl

theorem s8812_earnedAbove_eq : (schedule8812 i).earnedIncomeAboveActcRefundabilityThreshold =
    roundDollar (positive ((schedule8812 i).earnedIncomeWithAllCombatPay -
      Params.actcEarnedIncomeFloor)) := rfl

theorem s8812_ssOverEitc_eq : (schedule8812 i).socialSecurityOverEitc =
    roundDollar (positive (i.socialSecurityTaxesWithheld - i.earnedIncomeCredit)) := rfl

theorem s8812_maximumActc_eq : (schedule8812 i).maximumActc =
    roundDollar (if (schedule8812 i).threeOrMoreCtcEligibleDependents then
      Money.max (schedule8812 i).regularMaximumActc (schedule8812 i).socialSecurityOverEitc
      else (schedule8812 i).regularMaximumActc) := rfl

theorem s8812_additionalCtc_eq : (schedule8812 i).additionalCtc =
    roundDollar (Money.min (schedule8812 i).remainingPotentialActc (schedule8812 i).maximumActc) :=
  rfl

end FieldEquations

/-- `Money.min` of two nonnegative amounts is nonnegative. -/
theorem min_nonneg' {a b : Int} (ha : 0 ≤ a) (hb : 0 ≤ b) : 0 ≤ Money.min a b :=
  le_min ha hb

/-- Form 1040 line 19 is never negative. -/
theorem totalCtcAndOdc_nonneg (i : Schedule8812In) : 0 ≤ (schedule8812 i).totalCtcAndOdc := by
  rw [s8812_totalCtcAndOdc_eq]
  apply roundDollar_nonneg
  apply min_nonneg'
  · rw [s8812_lessPhaseout_eq]; exact roundDollar_nonneg (positive_nonneg _)
  · rw [s8812_creditLimit_eq]; exact positive_nonneg _

/-- Schedule 8812 line 5 and line 7 are nonnegative for nonnegative counts. -/
theorem totalPotential_nonneg (i : Schedule8812In) (hc : 0 ≤ i.ctcEligibleDependents)
    (ho : 0 ≤ i.odcEligibleDependents) :
    0 ≤ (schedule8812 i).totalPotentialCtc ∧ 0 ≤ (schedule8812 i).totalPotentialOdc := by
  constructor
  · rw [s8812_potentialCtc_eq]
    apply roundDollar_nonneg
    split
    · exact Int.le_refl 0
    · exact mulRate_nonneg (by decide) (Rat.intCast_nonneg.mpr hc)
  · rw [s8812_potentialOdc_eq]
    apply roundDollar_nonneg
    split
    · exact Int.le_refl 0
    · exact mulRate_nonneg (by decide) (Rat.intCast_nonneg.mpr ho)

/-- The phase-out (line 11) is nonnegative. -/
theorem dependentCreditPhaseout_nonneg (i : Schedule8812In) :
    0 ≤ (schedule8812 i).dependentCreditPhaseout := by
  rw [s8812_phaseout_eq]
  apply roundDollar_nonneg
  apply mulRate_nonneg
  · rw [s8812_rounded_eq]
    apply roundDollar_nonneg
    have hab := positive_nonneg ((schedule8812 i).dependentCreditMagi -
      (schedule8812 i).dependentCreditPhaseoutThreshold)
    have hstep : Params.ctcPhaseoutStep = 100000 := rfl
    have hge : 0 ≤ (schedule8812 i).dependentCreditMagiAboveThreshold + Params.ctcPhaseoutStep - 1 := by
      rw [s8812_above_eq]; omega
    have h := stepwiseMultiply_mono (num := 1000) (den := 1000) (by decide) (by decide) hge
    have h0 : stepwiseMultiply 0 1000 1000 = 0 := by decide +kernel
    omega
  · have : (0 : Rat) ≤ divMoney Params.ctcPhaseoutReductionPerStep Params.ctcPhaseoutStep := by
      decide +kernel
    exact this

/-- Line 19 is at most line 8, for nonnegative counts. -/
theorem totalCtcAndOdc_le_potential (i : Schedule8812In) (hc : 0 ≤ i.ctcEligibleDependents)
    (ho : 0 ≤ i.odcEligibleDependents) :
    (schedule8812 i).totalCtcAndOdc ≤ (schedule8812 i).totalPotentialDependentCredits := by
  obtain ⟨h1, h2⟩ := totalPotential_nonneg i hc ho
  have hpot : 0 ≤ (schedule8812 i).totalPotentialDependentCredits := by
    rw [s8812_potentialDependent_eq]; exact roundDollar_nonneg (by omega)
  have hph := dependentCreditPhaseout_nonneg i
  have hmod : (schedule8812 i).totalPotentialDependentCredits % 100 = 0 := by
    rw [s8812_potentialDependent_eq]; exact roundDollar_emod _
  have hless : (schedule8812 i).dependentCreditLessPhaseout ≤
      (schedule8812 i).totalPotentialDependentCredits := by
    rw [s8812_lessPhaseout_eq]
    have := roundDollar_mono (positive_mono (m := (schedule8812 i).totalPotentialDependentCredits -
      (schedule8812 i).dependentCreditPhaseout) (n := (schedule8812 i).totalPotentialDependentCredits)
      (by omega))
    rw [positive_of_nonneg hpot] at this
    have h3 : roundDollar (schedule8812 i).totalPotentialDependentCredits =
        (schedule8812 i).totalPotentialDependentCredits := by
      rw [s8812_potentialDependent_eq, roundDollar_idem]
    omega
  have hlessmod : (schedule8812 i).dependentCreditLessPhaseout % 100 = 0 := by
    rw [s8812_lessPhaseout_eq]; exact roundDollar_emod _
  rw [s8812_totalCtcAndOdc_eq]
  have := roundDollar_mono (min_le_left (schedule8812 i).dependentCreditLessPhaseout
    (schedule8812 i).sched8812CreditLimit)
  have h4 : roundDollar (schedule8812 i).dependentCreditLessPhaseout =
      (schedule8812 i).dependentCreditLessPhaseout := by
    rw [s8812_lessPhaseout_eq, roundDollar_idem]
  omega

/-- The refundable cap: line 16b is at most $1,700 per qualifying child. -/
theorem totalPotentialActc_le_cap (i : Schedule8812In) (hc : 0 ≤ i.ctcEligibleDependents) :
    0 ≤ (schedule8812 i).totalPotentialActc ∧
      (schedule8812 i).totalPotentialActc ≤ Params.actcPerQualifyingChildCap * i.ctcEligibleDependents := by
  rw [s8812_potentialActc_eq]
  have hcap : Params.actcPerQualifyingChildCap = 100 * 1700 := rfl
  split
  · rw [roundDollar_zero]; rw [hcap]; constructor <;> omega
  · rw [mulRate_intCast, hcap]
    have : 100 * 1700 * i.ctcEligibleDependents = 100 * (1700 * i.ctcEligibleDependents) := by
      rw [Int.mul_assoc]
    rw [this, roundDollar_mul_100]
    constructor <;> omega

/-- The additional child tax credit (line 27, Form 1040 line 28) is never negative, for a
nonnegative count. -/
theorem additionalCtc_nonneg (i : Schedule8812In) (hc : 0 ≤ i.ctcEligibleDependents) :
    0 ≤ (schedule8812 i).additionalCtc := by
  obtain ⟨hpot, _⟩ := totalPotentialActc_le_cap i hc
  rw [s8812_additionalCtc_eq]
  apply roundDollar_nonneg
  apply min_nonneg'
  · rw [s8812_remainingPotential_eq]
    apply roundDollar_nonneg
    apply min_nonneg' _ hpot
    rw [s8812_remaining_eq]; exact roundDollar_nonneg (positive_nonneg _)
  · rw [s8812_maximumActc_eq]
    apply roundDollar_nonneg
    have hreg : 0 ≤ (schedule8812 i).regularMaximumActc := by
      rw [s8812_regularMax_eq]
      apply roundDollar_nonneg
      apply mulRate_nonneg _ (by decide +kernel)
      rw [s8812_earnedAbove_eq]; exact roundDollar_nonneg (positive_nonneg _)
    have hss : 0 ≤ (schedule8812 i).socialSecurityOverEitc := by
      rw [s8812_ssOverEitc_eq]; exact roundDollar_nonneg (positive_nonneg _)
    split
    · unfold Money.max; split <;> omega
    · exact hreg

/-- **The ACTC cap**: the additional child tax credit is at most $1,700 per qualifying child
(Rev. Proc. 2023-34 § 3.05; Schedule 8812 line 17), for a nonnegative count. -/
theorem additionalCtc_le_cap (i : Schedule8812In) (hc : 0 ≤ i.ctcEligibleDependents) :
    (schedule8812 i).additionalCtc ≤ Params.actcPerQualifyingChildCap * i.ctcEligibleDependents := by
  obtain ⟨_, hcap⟩ := totalPotentialActc_le_cap i hc
  have hpotmod : (schedule8812 i).totalPotentialActc =
      roundDollar (schedule8812 i).totalPotentialActc := by
    rw [s8812_potentialActc_eq, roundDollar_idem]
  have hrem : (schedule8812 i).remainingPotentialActc ≤ (schedule8812 i).totalPotentialActc := by
    rw [s8812_remainingPotential_eq]
    have := roundDollar_mono (min_le_right (schedule8812 i).remainingCtcAndOdc
      (schedule8812 i).totalPotentialActc)
    omega
  have hremmod : (schedule8812 i).remainingPotentialActc =
      roundDollar (schedule8812 i).remainingPotentialActc := by
    rw [s8812_remainingPotential_eq, roundDollar_idem]
  rw [s8812_additionalCtc_eq]
  have := roundDollar_mono (min_le_left (schedule8812 i).remainingPotentialActc
    (schedule8812 i).maximumActc)
  omega

/-- **The phase-out is monotone**: a higher AGI, the filing status and the other figures
unchanged, never lowers the reduction (line 11). -/
theorem dependentCreditPhaseout_mono (i : Schedule8812In) {a : Int} (h : i.agi ≤ a) :
    (schedule8812 i).dependentCreditPhaseout ≤
      (schedule8812 { i with agi := a }).dependentCreditPhaseout := by
  rw [s8812_phaseout_eq, s8812_phaseout_eq]
  apply roundDollar_mono
  apply mulRate_mono (by decide +kernel)
  rw [s8812_rounded_eq, s8812_rounded_eq]
  apply roundDollar_mono
  apply stepwiseMultiply_mono (by decide) (by decide)
  have hth : (schedule8812 { i with agi := a }).dependentCreditPhaseoutThreshold =
      (schedule8812 i).dependentCreditPhaseoutThreshold := rfl
  have hmagi : (schedule8812 i).dependentCreditMagi ≤
      (schedule8812 { i with agi := a }).dependentCreditMagi := by
    rw [s8812_magi_eq, s8812_magi_eq]; exact roundDollar_mono h
  rw [s8812_above_eq, s8812_above_eq, hth]
  have := positive_mono (m := (schedule8812 i).dependentCreditMagi -
      (schedule8812 i).dependentCreditPhaseoutThreshold)
    (n := (schedule8812 { i with agi := a }).dependentCreditMagi -
      (schedule8812 i).dependentCreditPhaseoutThreshold) (by omega)
  omega

#audit_axioms UsTax.Proofs.totalCtcAndOdc_nonneg
#audit_axioms UsTax.Proofs.totalCtcAndOdc_le_potential
#audit_axioms UsTax.Proofs.additionalCtc_nonneg
#audit_axioms UsTax.Proofs.additionalCtc_le_cap
#audit_axioms UsTax.Proofs.dependentCreditPhaseout_mono

end UsTax.Proofs
