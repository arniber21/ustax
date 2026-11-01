import UsTax.Spec.FormW2
import UsTax.FormW2s
import UsTax.Proofs.Rounding
import UsTax.Spec.Inputs
import UsTax.Audit

/-!
# The W-2 totals and knockouts meet their spec (issue #64)

For **every** list of Forms W-2 and filing status: line 1a and line 25a are
`Spec.totalOfBox` of box 1 and box 2; the Medicare knockout is
`Spec.needsForm8959`; the social security knockout of each filer is
`Spec.excessSocialSecurityPossible`.
-/

namespace UsTax.Proofs

open Spec (filerBox)

open Money hiding min max
open FormW2s

theorem filter_items (role : FilerRole) (w2s : List FormW2) :
    (w2s.map formW2Item).filter (fun x => x.filer == role) =
      (w2s.filter (·.filer == role)).map formW2Item := by
  rw [List.filter_map]; rfl

/-- The W-2s of the two filers partition the sum. -/
theorem sumBy_split (f : FormW2Item → Int) (l : List FormW2Item) :
    sumBy f l = sumBy f (l.filter (·.filer == .primaryFiler)) +
      sumBy f (l.filter (·.filer == .secondaryFiler)) := by
  rw [← sumBy_filter_add_not f (fun x => x.filer == .primaryFiler) l]
  congr 2
  apply List.filter_congr
  intro x _
  cases x.filer <;> rfl

/-- Summing a field of the items is summing a function of the W-2s. -/
theorem sumBy_items (f : FormW2Item → Int) (g : FormW2 → Int) (h : ∀ w, f (formW2Item w) = g w)
    (l : List FormW2) : sumBy f (l.map formW2Item) = (l.map g).sum := by
  rw [sumBy_eq_sum, List.map_map]
  congr 1
  exact List.map_congr_left fun w _ => h w

/-- Line 1a is the total of box 1, each W-2 rounded to the dollar. -/
theorem wages_eq_spec (i : FormW2sIn) :
    (formW2s i).wages = Spec.totalOfBox (i.w2s.map (·.writableWages)) := by
  simp only [formW2s, Spec.totalOfBox, List.map_map, roundDollar_eq_spec]
  rw [sumBy_items _ _ (fun w => roundDollar_eq_spec w.writableWages)]
  rfl

/-- Line 25a is the total of box 2, each W-2 rounded to the dollar. -/
theorem formW2Withholding_eq_spec (i : FormW2sIn) :
    (formW2s i).formW2Withholding = Spec.totalOfBox (i.w2s.map (·.writableFederalWithholding)) := by
  simp only [formW2s, Spec.totalOfBox, List.map_map, roundDollar_eq_spec]
  rw [sumBy_items _ _ (fun w => roundDollar_eq_spec w.writableFederalWithholding)]
  rfl

/-- One filer's Medicare wages as the calculator sums them. -/
theorem filerMedicare_eq (role : FilerRole) (l : List FormW2) :
    sumBy (·.medicareWages) ((l.map formW2Item).filter (·.filer == role)) =
      (filerBox role (·.writableMedicareWages) l).sum := by
  rw [filter_items, sumBy_items _ _ (fun w => roundDollar_eq_spec w.writableMedicareWages)]
  rfl

/-- The Medicare knockout is exactly "Form 8959 is needed". -/
theorem medicareKnockout_eq_spec (i : FormW2sIn) :
    (formW2s i).koKnockoutMedicareWages =
      Spec.needsForm8959 i.filingStatus (filerBox .primaryFiler (·.writableMedicareWages) i.w2s)
        (filerBox .secondaryFiler (·.writableMedicareWages) i.w2s) := by
  have ht := sumBy_split (·.medicareWages) (i.w2s.map formW2Item)
  rw [filerMedicare_eq, filerMedicare_eq] at ht
  simp only [formW2s]
  rw [ht, filerMedicare_eq, filerMedicare_eq]
  simp only [Spec.needsForm8959, Spec.additionalMedicareThreshold,
    Params.medicareWagesIndividualLimit, Params.additionalMedicareTaxThresholdMarriedSeparate,
    Params.additionalMedicareTaxThresholdJoint, Params.additionalMedicareTaxThresholdOther,
    TaxRates.usd]
  generalize (filerBox .primaryFiler (·.writableMedicareWages) i.w2s).sum = p
  generalize (filerBox .secondaryFiler (·.writableMedicareWages) i.w2s).sum = s
  cases i.filingStatus <;> simp <;> exact Bool.or_comm _ _

/-- One filer's capped social security wages as the calculator sums them. -/
theorem filerOasdi_eq (role : FilerRole) (l : List FormW2) :
    sumBy (·.oasdiWagesForKnockoutCalculation) ((l.map formW2Item).filter (·.filer == role)) =
      ((filerBox role (·.writableOasdiWages) l).map (min 168_600_00)).sum := by
  rw [filter_items, sumBy_items _ (fun w => min 168_600_00 (Spec.roundToDollar w.writableOasdiWages))]
  · simp only [filerBox, List.map_map]; rfl
  · intro w
    simp only [formW2Item, roundDollar_eq_spec, Money.min, Params.oasdiWageBase, TaxRates.usd]
    split <;> omega

/-- Each filer's social security knockout is exactly "excess social security
withholding is possible", and the return's knockout is either filer's. -/
theorem oasdiKnockout_eq_spec (i : FormW2sIn) :
    (formW2s i).primaryFilerExceedsMaxOasdiWages =
      Spec.excessSocialSecurityPossible (filerBox .primaryFiler (·.writableOasdiWages) i.w2s) ∧
    (formW2s i).secondaryFilerExceedsMaxOasdiWages =
      Spec.excessSocialSecurityPossible (filerBox .secondaryFiler (·.writableOasdiWages) i.w2s) ∧
    (formW2s i).koAnyFilerExceedsMaxOasdiWages =
      ((formW2s i).primaryFilerExceedsMaxOasdiWages || (formW2s i).secondaryFilerExceedsMaxOasdiWages) := by
  simp only [formW2s]
  rw [filerOasdi_eq, filerOasdi_eq]
  simp only [filter_items, filerBox, Spec.excessSocialSecurityPossible, List.length_map,
    Params.oasdiWageBase, TaxRates.usd, and_true]
  constructor <;> congr 1 <;> simp only [decide_eq_decide] <;> omega

/-! ## On concrete inputs -/

/-- A joint return: primary $210,000 of Medicare wages on one W-2, spouse
$30,000.40. -/
def jointW2s : FormW2sIn :=
  { w2s := [{ writableWages := 210_000_00, writableMedicareWages := 210_000_00 },
            { filer := .secondaryFiler, writableWages := 30_000_40, writableMedicareWages := 30_000_40 }],
    filingStatus := .marriedFilingJointly, primaryFilerCanBeClaimed := false,
    secondaryFilerCanBeClaimed := false, combatPayElection := .noCombatPay }

/-- Every hypothesis discharged: line 1a is $240,000, and Form 8959 is needed
(one spouse over $200,000, though the total is under $250,000). -/
example : (formW2s jointW2s).wages = 240_000_00 ∧ (formW2s jointW2s).koKnockoutMedicareWages = true := by
  rw [wages_eq_spec, medicareKnockout_eq_spec]; decide

/-- Rejected: no knockout because the joint total is under $250,000. -/
example : (formW2s jointW2s).koKnockoutMedicareWages ≠ false := by
  rw [medicareKnockout_eq_spec]; decide

/-- Rejected: line 1a with the cents kept. -/
example : (formW2s jointW2s).wages ≠ 240_000_40 := by
  rw [wages_eq_spec]; decide

end UsTax.Proofs

#audit_axioms UsTax.Proofs.wages_eq_spec
#audit_axioms UsTax.Proofs.formW2Withholding_eq_spec
#audit_axioms UsTax.Proofs.medicareKnockout_eq_spec
#audit_axioms UsTax.Proofs.oasdiKnockout_eq_spec
