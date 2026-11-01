import UsTax.Household.Props
import UsTax.Audit

/-!
# Structural lemmas for the household and filing-status modules (issue #44)

Cheap, unconditional facts about the hand-translated Catala rules, each tested first in
`UsTax/Household/Props.lean`. They are not a full specification of IRC 152 or IRC 2; they
pin down the shape of the rules (QSS preempts HoH, a valid chosen status is not knocked
out, the recommendation is eligible, counts do not exceed the household, a qualifying
relative is not a qualifying child, DF-BUG(15)).
-/

namespace UsTax.Household
open QualifyingChild DependentsBenefitSplit QualifyingRelative

theorem band_left {a b : Bool} (h : (a && b) = true) : a = true := by
  cases a <;> simp_all

theorem bor_cases {a b : Bool} (h : (a || b) = true) : a = true ∨ b = true := by
  cases a <;> simp_all

/-- The recommended filing status is among the eligible ones, provided MFJ eligibility
implies that the marital status allows filing as married (true for the inputs
`filingStatusReturn` builds, see `filers_mfj_implies_mfs`; false for arbitrary inputs, which
plausible found: MFJ eligible, marriage not allowed, MFS chosen). -/
theorem recommended_eligible (i : FilingStatusMod.EligibilityIn)
    (hc : i.eligibleForMfj = true → i.maritalStatusAllowsFilingMarried = true) :
    Props.recOk (FilingStatusMod.eligibility i) i.eligibleForMfj = true := by
  rcases i with ⟨fs, a, b, c, d, h, q⟩
  simp only at hc
  simp only [Props.recOk, FilingStatusMod.eligibility]
  by_cases hh : 0 < h <;> by_cases hq : 0 < q <;> cases fs <;> cases a <;> cases b <;> cases c <;>
    cases d <;> simp [hh, hq] <;> simp_all

/-- `Filers`: MFJ eligibility implies MFS eligibility (both need the marital status). -/
theorem filers_mfj_implies_mfs (i : Filers.FilersIn) :
    (Filers.filers i).eligibleForMfj = true → (Filers.filers i).eligibleForMfs = true := by
  intro h
  simp only [Filers.filers] at h ⊢
  exact band_left h

/-- A qualifying child passes the age, residency, support and joint-return tests. -/
theorem qualifyingChild_tests (i : QualifyingChildTestIn) :
    (qualifyingChildTest i).qualifyingChild = true →
      (qualifyingChildTest i).ageTest = true ∧ (qualifyingChildTest i).residencyTest = true ∧
      (qualifyingChildTest i).qcSupportTest = true ∧
      (qualifyingChildTest i).jointReturnTest = true := by
  intro h
  simp only [qualifyingChildTest, Bool.and_eq_true] at h ⊢
  obtain ⟨⟨⟨⟨_, a⟩, b⟩, c⟩, d⟩ := h
  exact ⟨a, b, c, d⟩

/-- The tie-breaker knockout needs a qualifying child. -/
theorem ko_tieBreaker_qualifyingChild (i : QualifyingChildTestIn) :
    (qualifyingChildTest i).koQualifyingChildTieBreaker = true →
      (qualifyingChildTest i).qualifyingChild = true := by
  intro h
  simp only [qualifyingChildTest, Bool.and_eq_true] at h ⊢
  exact h.1

/-- The number of qualifying children is at most the household size. -/
theorem qualifyingChildren_count_le (i : QualifyingChildrenIn) :
    (qualifyingChildren i).qualifyingChildCount ≤ i.persons.length := by
  simp only [qualifyingChildren]
  have := Money.countBy_le_length (fun r : QualifyingChildTestOut => r.qualifyingChild)
    (i.persons.map fun p => qualifyingChildTest
      { person := p, minimumFilerDateOfBirth := i.minimumFilerDateOfBirth })
  simp only [List.length_map] at this
  omega

/-- Being able to claim the split benefits means being eligible for the benefit split. -/
theorem splitBenefits_eligible (i : BenefitSplitTestIn) :
    (benefitSplitTest i).tpCanClaimSplitBenefitsHohEitcCdcc = true →
      (benefitSplitTest i).eligibleForBenefitSplit = true := by
  intro h
  simp only [benefitSplitTest] at h ⊢
  exact band_left h

/-- A benefit-split knockout needs eligibility for the split. -/
theorem benefitSplit_unsupported_eligible (i : BenefitSplitTestIn) :
    (benefitSplitTest i).unsupported = true →
      (benefitSplitTest i).eligibleForBenefitSplit = true := by
  intro h
  simp only [benefitSplitTest] at h ⊢
  rcases bor_cases h with h | h
  · exact band_left h
  · exact band_left (band_left h)

/-- DF-BUG(15) (Lean follows Catala): a qualifying relative is not a qualifying child. -/
theorem qualifyingRelative_not_qualifyingChild (i : DependentTestIn) :
    (dependentTest i).qualifyingRelative = true → (dependentTest i).qualifyingChild = false := by
  intro h
  simp only [dependentTest, Bool.and_eq_true, Bool.not_eq_true'] at h ⊢
  exact h.1.1

/-- An eligible dependent is a qualifying child or a qualifying relative. -/
theorem eligibleDependent_qcOrQr (i : DependentTestIn) :
    (dependentTest i).eligibleDependent = true → (dependentTest i).qcOrQr = true := by
  intro h
  simp only [dependentTest, Bool.and_eq_true] at h ⊢
  exact h.2.1.1.1.1.1

/-- A claimed dependent is an eligible dependent. -/
theorem claimedDependent_eligible (i : DependentTestIn) :
    (dependentTest i).isClaimedDependent = true → (dependentTest i).eligibleDependent = true := by
  intro h
  simp only [dependentTest, Bool.and_eq_true] at h ⊢
  exact h.2

/-- An eligible dependent does not exist when the filers are treated as dependents. -/
theorem eligibleDependent_not_treatAsDependent (i : DependentTestIn) :
    (dependentTest i).eligibleDependent = true → i.treatFilersAsDependents = false := by
  intro h
  simp only [dependentTest, Bool.and_eq_true, Bool.not_eq_true'] at h
  exact h.1

/-- A head-of-household qualifying person is not disqualified by parental custody. -/
theorem hohQualifyingPerson_not_disqualified (i : HohQssPersons.HohQssPersonTestIn) :
    (HohQssPersons.hohQssPersonTest i).hohQualifyingPerson = true →
      (HohQssPersons.hohQssPersonTest i).dep.split.disqualifiedDueToParentalCustody = false := by
  intro h
  simp only [HohQssPersons.hohQssPersonTest, Bool.and_eq_true, Bool.not_eq_true'] at h ⊢
  exact h.1.2

/-- A person who qualifies the taxpayer for HoH is a HoH qualifying person. -/
theorem personQualifiesTpForHoh_qualifying (i : HohQssPersons.HohQssPersonTestIn) :
    (HohQssPersons.hohQssPersonTest i).personQualifiesTpForHoh = true →
      (HohQssPersons.hohQssPersonTest i).hohQualifyingPerson = true := by
  intro h
  simp only [HohQssPersons.hohQssPersonTest, Bool.and_eq_true] at h ⊢
  exact h.1

/-- The household-level head-of-household knockout needs the filing status to be HoH. -/
theorem hoh_ko_needs_hoh (i : HohQssPersons.HohQssPersonsIn) :
    (HohQssPersons.hohQssPersons i).koKnockoutHohQpHasNoTin = true →
      i.filingStatus = .headOfHousehold := by
  intro h
  simp only [HohQssPersons.hohQssPersons, Bool.and_eq_true, beq_iff_eq] at h
  exact h.1.1

/-- In the full filing-status check, QSS preempts HoH. -/
theorem return_qss_preempts_hoh (i : FilingStatusMod.FilingStatusReturnIn) :
    (FilingStatusMod.filingStatusReturn i).eligibleForQss = true →
      (FilingStatusMod.filingStatusReturn i).eligibleForHoh = false :=
  fun h => FilingStatusMod.eligibility_qss_preempts_hoh _ h

/-- In the full filing-status check, a valid chosen status clears the status knockout. -/
theorem return_valid_not_ko (i : FilingStatusMod.FilingStatusReturnIn) :
    (FilingStatusMod.filingStatusReturn i).isFilingStatusValid = true →
      (FilingStatusMod.filingStatusReturn i).koFilingStatusNotEligible = false :=
  fun h => FilingStatusMod.eligibility_valid_not_ko _ h

/-- A chosen status of HoH can be valid only when the filer is not QSS-eligible. -/
theorem hoh_valid_not_qss (i : FilingStatusMod.EligibilityIn) (hs : i.filingStatus = .headOfHousehold) :
    (FilingStatusMod.eligibility i).isFilingStatusValid = true →
      (FilingStatusMod.eligibility i).eligibleForQss = false := by
  intro h
  have hh : (FilingStatusMod.eligibility i).eligibleForHoh = true := by
    simp only [FilingStatusMod.eligibility, hs] at h ⊢
    simp_all
  cases hq : (FilingStatusMod.eligibility i).eligibleForQss
  · rfl
  · have := FilingStatusMod.eligibility_qss_preempts_hoh i hq
    simp_all

/-- Examples with every hypothesis discharged: a divorced single filer with no dependents. -/
example : (FilingStatusMod.eligibility
    { filingStatus := .single, maritalStatusAllowsFilingMarried := false, eligibleForMfj := false
      filerCouldQualifyForHoh := false, filerCouldQualifyForQss := false
      hohQualifyingPeopleCount := 0, qssQualifyingPeopleCount := 0 }).isFilingStatusValid = true := by
  decide +kernel

/-- A rejected bad output: HoH is not valid for a filer with no qualifying person. -/
example : ¬ (FilingStatusMod.eligibility
    { filingStatus := .headOfHousehold, maritalStatusAllowsFilingMarried := false
      eligibleForMfj := false, filerCouldQualifyForHoh := true, filerCouldQualifyForQss := false
      hohQualifyingPeopleCount := 0, qssQualifyingPeopleCount := 0 }).isFilingStatusValid = true := by
  decide +kernel

end UsTax.Household

#audit_axioms UsTax.Household.recommended_eligible
#audit_axioms UsTax.Household.qualifyingChild_tests
#audit_axioms UsTax.Household.ko_tieBreaker_qualifyingChild
#audit_axioms UsTax.Household.qualifyingChildren_count_le
#audit_axioms UsTax.Household.splitBenefits_eligible
#audit_axioms UsTax.Household.benefitSplit_unsupported_eligible
#audit_axioms UsTax.Household.qualifyingRelative_not_qualifyingChild
#audit_axioms UsTax.Household.eligibleDependent_qcOrQr
#audit_axioms UsTax.Household.claimedDependent_eligible
#audit_axioms UsTax.Household.eligibleDependent_not_treatAsDependent
#audit_axioms UsTax.Household.hohQualifyingPerson_not_disqualified
#audit_axioms UsTax.Household.personQualifiesTpForHoh_qualifying
#audit_axioms UsTax.Household.hoh_ko_needs_hoh
#audit_axioms UsTax.Household.return_qss_preempts_hoh
#audit_axioms UsTax.Household.return_valid_not_ko
#audit_axioms UsTax.Household.hoh_valid_not_qss
#audit_axioms UsTax.FilingStatusMod.eligibility_qss_preempts_hoh
#audit_axioms UsTax.FilingStatusMod.eligibility_valid_not_ko
#audit_axioms UsTax.HohQssPersons.hohQssPersons_counts_le
