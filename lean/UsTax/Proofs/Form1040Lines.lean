import UsTax.Spec.Form1040Lines
import UsTax.Form1040Full
import UsTax.TaxRates.Lemmas
import UsTax.Proofs.Rounding
import UsTax.Proofs.StandardDeduction
import UsTax.Proofs.Form1040
import UsTax.Audit

/-!
# Form 1040 line arithmetic, line 26, and tax monotone in wages (issue #64)

For **every** return:

* `estimatedPayments_eq_spec`: line 26 is `Spec.estimatedPaymentsLine26`;
  `estimatedPayments_close`: within 50 cents of the amount paid;
* `agi_eq`: line 11 = line 9 − line 10;
* `taxableIncome_eq`: line 15 = `max 0 (line 11 − line 14)`;
* `totalPayments_eq`: line 33 = line 25d + line 26 + line 32 when line 26 is
  whole dollars, which it always is on the whole return
  (`totalPayments_eq_full`, `Form1040Full`);
* `totalTax_mono_addW2`: adding a W-2 with nonnegative wages never lowers
  line 24. The credits on lines 19 to 21 and the refundable credits are
  inputs of `form1040`, held fixed. This is **not** a statement about the
  refund: with EITC computed from wages, more wages can lower the refund.
-/

namespace UsTax.Proofs

open Money hiding min max
open Form1040

/-! ## Line 26 -/

/-- **Line 26 is the payment in whole dollars, or `$0`.** -/
theorem estimatedPayments_eq_spec (i : EstimatedPayments.EstimatedPaymentsIn) :
    (EstimatedPayments.estimatedPayments i).estimatedAndFromLastYear =
      Spec.estimatedPaymentsLine26 i.paidEstimatedTaxesOrFromLastYear i.estimatedTaxPaymentWritable := by
  simp only [EstimatedPayments.estimatedPayments, Spec.estimatedPaymentsLine26, roundDollar_eq_spec]
  split
  · rfl
  · decide

/-- Line 26 is within 50 cents of what was paid (when something was paid),
and whole dollars. -/
theorem estimatedPayments_close (i : EstimatedPayments.EstimatedPaymentsIn)
    (h : i.paidEstimatedTaxesOrFromLastYear = true) :
    let l26 := (EstimatedPayments.estimatedPayments i).estimatedAndFromLastYear
    l26 - 50 ≤ i.estimatedTaxPaymentWritable ∧ i.estimatedTaxPaymentWritable ≤ l26 + 50 ∧
      l26 % 100 = 0 := by
  intro l26
  have := roundDollar_sub_le i.estimatedTaxPaymentWritable
  have he := roundDollar_emod i.estimatedTaxPaymentWritable
  simp only [l26, EstimatedPayments.estimatedPayments, h, ↓reduceIte]
  omega

/-! ## Line arithmetic -/

/-- `roundDollar` of a difference of whole-dollar amounts is the difference. -/
theorem roundDollar_sub_whole {a b : Int} (ha : a % 100 = 0) (hb : b % 100 = 0) :
    roundDollar (a - b) = a - b := roundDollar_of_emod (by omega)

/-- **Line 11 = line 9 − line 10.** -/
theorem agi_eq (i : Form1040In) :
    (form1040 i).agi = (form1040 i).totalIncome - (form1040 i).adjustmentsToIncome :=
  roundDollar_sub_whole (roundDollar_emod _) (roundDollar_emod _)

/-- **Line 15 = `max 0 (line 11 − line 14)`.** -/
theorem taxableIncome_eq (i : Form1040In) :
    (form1040 i).taxableIncome = max 0 ((form1040 i).agi - (form1040 i).totalDeductions) :=
  roundDollar_positive_sub (roundDollar_emod _) (roundDollar_emod _)

/-- `roundDollar` of a sum of three whole-dollar amounts is the sum. -/
theorem roundDollar_add3_whole {a b c : Int} (ha : a % 100 = 0) (hb : b % 100 = 0) (hc : c % 100 = 0) :
    roundDollar (a + b + c) = a + b + c := roundDollar_of_emod (by omega)

/-- **Line 33 = line 25d + line 26 + line 32**, when line 26 is whole dollars. -/
theorem totalPayments_eq (i : Form1040In) (h26 : i.estimatedAndFromLastYear % 100 = 0) :
    (form1040 i).totalPayments =
      (form1040 i).totalWithholding + i.estimatedAndFromLastYear +
        (form1040 i).totalOtherPaymentsRefundableCredits := by
  exact roundDollar_add3_whole (roundDollar_emod _) h26 (roundDollar_emod _)

/-- On the whole return (`Form1040Full`), line 26 comes from the estimated
payments module, so line 33 = line 25d + line 26 + line 32 always. -/
theorem totalPayments_eq_full (i : Form1040Full.Form1040FullIn) :
    (Form1040Full.form1040Full i).form1040.totalPayments =
      (Form1040Full.form1040Full i).form1040.totalWithholding +
        (Form1040Full.form1040Full i).estimated.estimatedAndFromLastYear +
        (Form1040Full.form1040Full i).form1040.totalOtherPaymentsRefundableCredits :=
  totalPayments_eq _ (roundDollar_emod _)

/-! ## Line 24 does not decrease with wages -/

/-- Rounding a sum to the dollar: adding whole dollars `100 k` (`k ≥ 0`) adds
at least `100 k`. -/
theorem roundDollar_add_whole_ge (z k : Int) (hk : 0 ≤ k) :
    roundDollar z + 100 * k ≤ roundDollar (z + 100 * k) := by
  rw [roundDollar_eq, roundDollar_eq]; (repeat' split) <;> omega

/-- The standard deduction input that `form1040` builds, with earned income `e`. -/
def sdIn (i : Form1040In) (e : Int) : StandardDeduction.StandardDeductionIn :=
  { filingStatus := i.filingStatus, treatAsMfs := i.treatAsMfs,
    primaryFilerIsBlind := i.primaryFilerIsBlind,
    primaryFilerAge65OrOlder := i.primaryFilerAge65OrOlder,
    secondaryFilerIsBlind := i.secondaryFilerIsBlind,
    secondaryFilerAge65OrOlder := i.secondaryFilerAge65OrOlder,
    isWidowedInTaxYear := i.isWidowedInTaxYear,
    mfjDeceasedSpouseReachedAge65 := i.mfjDeceasedSpouseReachedAge65,
    mfsSpouse65OrOlder := i.mfsSpouse65OrOlder,
    mfsSpouseProvidesNoBenefits := i.mfsSpouseProvidesNoBenefits,
    treatFilersAsDependents := i.treatFilersAsDependents,
    employerIncomeSubtotal := e }

theorem totalDeductions_eq (i : Form1040In) :
    (form1040 i).totalDeductions =
      roundDollar (roundDollar (StandardDeduction.standardDeduction
        (sdIn i (form1040 i).employerIncomeSubtotal)).standardDeduction) := rfl

/-- The standard deduction grows by at most the growth of earned income, and
is whole dollars when earned income is. -/
theorem standardDeduction_step (i : Form1040In) {e d : Int} (he : e % 100 = 0) (hd : 0 ≤ d) :
    (StandardDeduction.standardDeduction (sdIn i (e + d))).standardDeduction ≤
        (StandardDeduction.standardDeduction (sdIn i e)).standardDeduction + d ∧
      (StandardDeduction.standardDeduction (sdIn i e)).standardDeduction % 100 = 0 := by
  rw [standardDeduction_eq_spec, standardDeduction_eq_spec]
  have hitems : (StandardDeduction.standardDeduction (sdIn i (e + d))).additionalStandardDeductionItems =
      (StandardDeduction.standardDeduction (sdIn i e)).additionalStandardDeductionItems := rfl
  rw [hitems]
  generalize (StandardDeduction.standardDeduction (sdIn i e)).additionalStandardDeductionItems = n
  clear hitems
  simp only [sdIn, Spec.standardDeductionSpec]
  cases i.filingStatus <;>
    simp only [Spec.basicStandardDeduction, Spec.additionalAmountPerItem] <;>
    by_cases ht : i.treatFilersAsDependents = true <;> simp only [ht, Bool.false_eq_true, ↓reduceIte] <;>
    exact ⟨by omega, by omega⟩

/-- The W-2 input that `form1040` builds. -/
def w2In (i : Form1040In) : FormW2s.FormW2sIn :=
  { w2s := i.w2s, filingStatus := i.filingStatus,
    primaryFilerCanBeClaimed := i.primaryFilerCanBeClaimed,
    secondaryFilerCanBeClaimed := i.secondaryFilerCanBeClaimed,
    combatPayElection := i.combatPayElection }

/-- Line 1z as `form1040` computes it. -/
theorem employerIncomeSubtotal_eq (i : Form1040In) :
    (form1040 i).employerIncomeSubtotal =
      roundDollar ((FormW2s.formW2s (w2In i)).primaryFilerWages +
        (FormW2s.formW2s (w2In i)).secondaryFilerWages + i.taxableDependentCare) := by
  simp only [form1040, w2In, Int.add_zero]

/-- The rest of line 9 besides line 1z. -/
def restOfTotalIncome (i : Form1040In) : Int :=
  (form1040 i).interestIncome + i.taxablePensionsAndAnnuities + i.taxableSocialSecurityBenefits +
    (form1040 i).otherIncome

/-- Line 9 as `form1040` computes it. -/
theorem totalIncome_eq (i : Form1040In) :
    (form1040 i).totalIncome =
      roundDollar ((form1040 i).employerIncomeSubtotal + restOfTotalIncome i) := by
  simp only [restOfTotalIncome]
  show roundDollar _ = roundDollar _
  congr 1
  simp only [form1040, Int.add_zero]
  omega

/-- Adding a W-2 adds its rounded box 1 to the filers' wages. -/
theorem filerWages_cons (i : Form1040In) (w : FormW2s.FormW2) :
    (FormW2s.formW2s (w2In { i with w2s := w :: i.w2s })).primaryFilerWages +
        (FormW2s.formW2s (w2In { i with w2s := w :: i.w2s })).secondaryFilerWages =
      (FormW2s.formW2s (w2In i)).primaryFilerWages + (FormW2s.formW2s (w2In i)).secondaryFilerWages +
        roundDollar w.writableWages := by
  simp only [w2In, FormW2s.formW2s, List.map_cons, List.filter_cons]
  cases h : w.filer <;> simp [FormW2s.formW2Item, h, sumBy_cons] <;> omega

/-- Line 1z after adding a W-2: its rounded box 1 is added inside the rounding. -/
theorem employerIncomeSubtotal_cons (i : Form1040In) (w : FormW2s.FormW2) :
    (form1040 { i with w2s := w :: i.w2s }).employerIncomeSubtotal =
      roundDollar ((FormW2s.formW2s (w2In i)).primaryFilerWages +
        (FormW2s.formW2s (w2In i)).secondaryFilerWages + i.taxableDependentCare +
        roundDollar w.writableWages) := by
  rw [employerIncomeSubtotal_eq]
  have h := filerWages_cons i w
  have hdc : ({ i with w2s := w :: i.w2s } : Form1040In).taxableDependentCare = i.taxableDependentCare := rfl
  congr 1
  omega

theorem restOfTotalIncome_cons (i : Form1040In) (w : FormW2s.FormW2) :
    restOfTotalIncome { i with w2s := w :: i.w2s } = restOfTotalIncome i := by
  simp only [restOfTotalIncome, form1040]

theorem adjustmentsToIncome_cons (i : Form1040In) (w : FormW2s.FormW2) :
    (form1040 { i with w2s := w :: i.w2s }).adjustmentsToIncome = (form1040 i).adjustmentsToIncome := by
  simp only [form1040]

theorem nonRefundableCredits_cons (i : Form1040In) (w : FormW2s.FormW2) :
    (form1040 { i with w2s := w :: i.w2s }).nonRefundableCredits = (form1040 i).nonRefundableCredits := by
  simp only [form1040]

/-- Line 16 is the tax on line 15. -/
theorem tentativeTax_eq (i : Form1040In) :
    (form1040 i).tentativeTaxFromTaxableIncome =
      TaxRates.tentativeTaxFor (form1040 i).taxableIncome i.filingStatus := rfl

/-- Line 18 is line 16 plus Schedule 2 line 3, rounded. -/
theorem totalTentativeTax_eq (i : Form1040In) :
    (form1040 i).totalTentativeTax =
      roundDollar ((form1040 i).tentativeTaxFromTaxableIncome + i.totalAdditionalTaxesOwed) := rfl

/-- **Adding a W-2 with nonnegative wages never lowers line 24**, every other
input (filing status, other income, adjustments, credits) unchanged. -/
theorem totalTax_mono_addW2 (i : Form1040In) (w : FormW2s.FormW2) (hw : 0 ≤ w.writableWages) :
    (form1040 i).totalTax ≤ (form1040 { i with w2s := w :: i.w2s }).totalTax := by
  -- line 1z grows by `D ≥ 0`, whole dollars
  have hr := roundDollar_nonneg hw
  have hre := roundDollar_emod w.writableWages
  have hEge : (form1040 i).employerIncomeSubtotal + roundDollar w.writableWages ≤
      (form1040 { i with w2s := w :: i.w2s }).employerIncomeSubtotal := by
    rw [employerIncomeSubtotal_eq, employerIncomeSubtotal_cons]
    have := roundDollar_add_whole_ge
      ((FormW2s.formW2s (w2In i)).primaryFilerWages + (FormW2s.formW2s (w2In i)).secondaryFilerWages +
        i.taxableDependentCare) (roundDollar w.writableWages / 100) (by omega)
    rw [show 100 * (roundDollar w.writableWages / 100) = roundDollar w.writableWages by omega] at this
    exact this
  have hEw : (form1040 i).employerIncomeSubtotal % 100 = 0 := roundDollar_emod _
  have hEw' : (form1040 { i with w2s := w :: i.w2s }).employerIncomeSubtotal % 100 = 0 :=
    roundDollar_emod _
  generalize hD : (form1040 { i with w2s := w :: i.w2s }).employerIncomeSubtotal -
    (form1040 i).employerIncomeSubtotal = D
  -- line 9, line 11 grow by at least `D`
  have hTI : (form1040 i).totalIncome + D ≤ (form1040 { i with w2s := w :: i.w2s }).totalIncome := by
    rw [totalIncome_eq, totalIncome_eq, restOfTotalIncome_cons]
    have := roundDollar_add_whole_ge ((form1040 i).employerIncomeSubtotal + restOfTotalIncome i)
      (D / 100) (by omega)
    rw [show (form1040 { i with w2s := w :: i.w2s }).employerIncomeSubtotal + restOfTotalIncome i =
      (form1040 i).employerIncomeSubtotal + restOfTotalIncome i + 100 * (D / 100) by omega]
    omega
  have hagi : (form1040 i).agi + D ≤ (form1040 { i with w2s := w :: i.w2s }).agi := by
    rw [agi_eq, agi_eq, adjustmentsToIncome_cons]; omega
  -- line 14 grows by at most `D`
  have hsd := standardDeduction_step i hEw (d := D) (by omega)
  have hsd' := (standardDeduction_step i (e := (form1040 i).employerIncomeSubtotal + D) (d := 0)
    (by omega) (Int.le_refl 0)).2
  have hsdi : sdIn { i with w2s := w :: i.w2s } = sdIn i := rfl
  have hded : (form1040 { i with w2s := w :: i.w2s }).totalDeductions ≤
      (form1040 i).totalDeductions + D := by
    rw [totalDeductions_eq, totalDeductions_eq, hsdi,
      show (form1040 { i with w2s := w :: i.w2s }).employerIncomeSubtotal =
        (form1040 i).employerIncomeSubtotal + D by omega]
    rw [roundDollar_of_emod hsd.2, roundDollar_of_emod hsd.2, roundDollar_of_emod hsd',
      roundDollar_of_emod hsd']
    exact hsd.1
  -- lines 15, 16, 18, 22, 24
  have hti : (form1040 i).taxableIncome ≤ (form1040 { i with w2s := w :: i.w2s }).taxableIncome := by
    rw [taxableIncome_eq, taxableIncome_eq]; omega
  have h16 : (form1040 i).tentativeTaxFromTaxableIncome ≤
      (form1040 { i with w2s := w :: i.w2s }).tentativeTaxFromTaxableIncome := by
    rw [tentativeTax_eq, tentativeTax_eq]
    exact TaxRates.tentativeTaxFor_mono _ hti
  have h18 : (form1040 i).totalTentativeTax ≤ (form1040 { i with w2s := w :: i.w2s }).totalTentativeTax := by
    rw [totalTentativeTax_eq, totalTentativeTax_eq]
    have hadd : ({ i with w2s := w :: i.w2s } : Form1040In).totalAdditionalTaxesOwed =
      i.totalAdditionalTaxesOwed := rfl
    exact roundDollar_mono (by omega)
  rw [totalTax_eq, totalTax_eq, taxLessNonRefundableCredits_eq, taxLessNonRefundableCredits_eq,
    nonRefundableCredits_cons]
  omega

/-! ## On concrete inputs -/

/-- Every hypothesis discharged on a concrete return: a single filer with a
$50,000 W-2 gets a second W-2 of $10,000; line 24 goes from $4,019 to $5,219. -/
example : (form1040 (run [{ writableWages := 50_000_00 }])).totalTax ≤
    (form1040 { run [{ writableWages := 50_000_00 }] with
      w2s := { writableWages := 10_000_00 } :: (run [{ writableWages := 50_000_00 }]).w2s }).totalTax :=
  totalTax_mono_addW2 _ _ (by decide)

/-- The line arithmetic on that return: AGI $50,000, taxable income $35,400. -/
example : (form1040 (run [{ writableWages := 50_000_00 }])).agi = 50_000_00 ∧
    (form1040 (run [{ writableWages := 50_000_00 }])).taxableIncome = 35_400_00 := by
  rw [taxableIncome_eq, agi_eq]; decide +kernel

/-- Rejected: line 15 is not AGI minus the deduction when that is negative
(a $10,000 return: $10,000 − $14,600 is −$4,600, line 15 is `$0`). -/
example : (form1040 (run [{ writableWages := 10_000_00 }])).taxableIncome ≠ -4_600_00 := by
  rw [taxableIncome_eq]; omega

/-- Line 26 on a concrete answer: $500.49 paid is $500; rejected: $500.49. -/
example : (EstimatedPayments.estimatedPayments
      { paidEstimatedTaxesOrFromLastYear := true, estimatedTaxPaymentWritable := 500_49,
        paidEstimatedTaxesOrFromLastYearUnderDifferentName := false,
        paidEstimatedTaxesWithFormerSpouse := .neither }).estimatedAndFromLastYear = 500_00 ∧
    (EstimatedPayments.estimatedPayments
      { paidEstimatedTaxesOrFromLastYear := true, estimatedTaxPaymentWritable := 500_49,
        paidEstimatedTaxesOrFromLastYearUnderDifferentName := false,
        paidEstimatedTaxesWithFormerSpouse := .neither }).estimatedAndFromLastYear ≠ 500_49 := by
  rw [estimatedPayments_eq_spec]; decide

end UsTax.Proofs

#audit_axioms UsTax.Proofs.estimatedPayments_eq_spec
#audit_axioms UsTax.Proofs.agi_eq
#audit_axioms UsTax.Proofs.taxableIncome_eq
#audit_axioms UsTax.Proofs.totalPayments_eq
#audit_axioms UsTax.Proofs.totalPayments_eq_full
#audit_axioms UsTax.Proofs.totalTax_mono_addW2
