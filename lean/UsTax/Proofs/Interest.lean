import UsTax.Spec.Interest
import UsTax.Interest
import UsTax.Proofs.Rounding
import UsTax.Spec.Inputs
import UsTax.Audit

/-!
# Taxable interest meets its spec (issue #64)

For **every** list of interest reports, the Schedule B decision and line 2b
as computed equal `Spec.scheduleBRequired` and `Spec.interestLine2b` of the
per-report taxable interest.
-/

namespace UsTax.Proofs

open Spec (reportTaxableInterest)

open Money Interest

theorem taxableInterest_facts (r : InterestReport) :
    (interestReportFacts r).taxableInterest = reportTaxableInterest r := by
  unfold interestReportFacts reportTaxableInterest; split <;> simp_all <;> omega

/-- Schedule B is required exactly as the instructions say. -/
theorem requiresScheduleB_eq_spec (i : InterestIn) :
    (interest i).requiresScheduleB =
      Spec.scheduleBRequired (i.interestReports.map reportTaxableInterest) i.hasForeignAccountsOrTrusts := by
  simp only [interest, requiresScheduleB, Spec.scheduleBRequired, sumBy_eq_sum, List.map_map,
    Params.scheduleBInterestThreshold, TaxRates.usd]
  rw [show ((fun x => x.taxableInterest) ∘ interestReportFacts) = reportTaxableInterest from
    funext taxableInterest_facts]
  rfl

/-- Line 2b is the spec's amount. -/
theorem interestIncome_eq_spec (i : InterestIn) :
    (interest i).interestIncome =
      Spec.interestLine2b (i.interestReports.map reportTaxableInterest) i.hasForeignAccountsOrTrusts := by
  have hb := requiresScheduleB_eq_spec i
  simp only [interest] at hb
  simp only [interest, interestIncome, Spec.interestLine2b, ← hb, sumBy_eq_sum, List.map_map,
    roundDollar_eq_spec]
  have h1 : (fun r => (interestReportFacts r).taxableInterest) = reportTaxableInterest :=
    funext taxableInterest_facts
  have h2 : (fun r => (interestReportFacts r).roundedTaxableInterest) =
      Spec.roundToDollar ∘ reportTaxableInterest := by
    funext r; simp only [Function.comp, ← taxableInterest_facts]
    simp only [interestReportFacts, roundDollar_eq_spec]
  simp only [Function.comp_def] at h1 h2 ⊢
  rw [h1, h2]
  split <;> rfl

/-! ## On concrete inputs -/

/-- Three 1099-INTs of $500.51 each. -/
def threeReports : InterestIn :=
  { interestReports := List.replicate 3 { has1099 := true, writable1099Amount := 500_51 },
    hasForeignAccountsOrTrusts := false, filingStatus := .single, agi := 0,
    flowHasSeenDeductions := false }

/-- Every hypothesis discharged: Schedule B is required and line 2b is $1,503. -/
example : (interest threeReports).requiresScheduleB = true ∧
    (interest threeReports).interestIncome = 1_503_00 := by
  rw [requiresScheduleB_eq_spec, interestIncome_eq_spec]; decide

/-- Rejected: $1,502 (the total rounded once). -/
example : (interest threeReports).interestIncome ≠ 1_502_00 := by
  rw [interestIncome_eq_spec]; decide

end UsTax.Proofs

#audit_axioms UsTax.Proofs.requiresScheduleB_eq_spec
#audit_axioms UsTax.Proofs.interestIncome_eq_spec
