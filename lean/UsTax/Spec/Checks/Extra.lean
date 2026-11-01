import UsTax.Proofs.Extra
import UsTax.Spec.Checks.Main
import UsTax.Spec.Checks.Requests

/-!
# Spec checks of the module specs (CLAUDE.md section 4; issues #61, #62, #68)

For each statement of `lean/comparator.extra.json` (`UsTax.Extra.<stmt>`):

* `Extra.<stmt>_sat`: the statement instantiated on a concrete input, every hypothesis
  discharged, with the concrete output computed by the kernel (`decide +kernel`);
* `Extra.<stmt>_bad_<what>`: at least two known-bad outputs on a concrete input, each rejected
  (`¬ Spec input badOutput`).

The whole-return statements (`calculator_*`, `apiCalculator_*`, `calculateRequest_ne_fault`) are
instantiated on the API contract's examples, read by the server's reader
(`UsTax/Spec/Checks/Requests.lean`): `single-w2-50k` (balance due $4,019), `family-mfj-two-kids`
(tax $5,635, $4,000 of child tax credit, refund $1,365), `eitc-hoh-one-child` (tax $1,844 wiped
out by the credits, EITC and ACTC, refund $3,604) and `knocked-out-bond-interest` (knocked out:
`FlowKnockoutHasBonds`). `make spec-checks` checks every statement has both kinds.
-/

namespace UsTax.Checks.Extra

open UsTax.Spec UsTax.Extra UsTax.Checks

/-! ## Standard deduction -/

/-- Single, 65 or older, nothing else. -/
def sdIn : StandardDeduction.StandardDeductionIn :=
  ⟨.single, false, false, true, false, false, false, false, false, false, false, 0⟩

/-- One additional item, line 12 = $14,600 + $1,950 = $16,550. -/
theorem standardDeduction_eq_spec_sat :
    (StandardDeduction.standardDeduction sdIn).standardDeduction =
      standardDeductionSpec sdIn.filingStatus
        (StandardDeduction.standardDeduction sdIn).additionalStandardDeductionItems
        sdIn.treatFilersAsDependents sdIn.employerIncomeSubtotal ∧
    (StandardDeduction.standardDeduction sdIn).additionalStandardDeductionItems = 1 ∧
    (StandardDeduction.standardDeduction sdIn).standardDeduction = 16_550_00 :=
  ⟨standardDeduction_eq_spec sdIn, by decide +kernel, by decide +kernel⟩

/-- Rejected: the age item dropped ($14,600). -/
theorem standardDeduction_eq_spec_bad_item_dropped :
    ¬ ((14_600_00 : Int) = standardDeductionSpec .single 1 false 0) := by decide

/-- Rejected: the married additional amount ($1,550) for a single filer ($16,150). -/
theorem standardDeduction_eq_spec_bad_married_amount :
    ¬ ((16_150_00 : Int) = standardDeductionSpec .single 1 false 0) := by decide

/-- The range property of `additionalItems_range` for an item count `n` on input `i`. -/
def ItemsInRange (i : StandardDeduction.StandardDeductionIn) (n : Int) : Prop :=
  0 ≤ n ∧ n ≤ 4 ∧ (i.filingStatus ≠ .marriedFilingJointly → i.treatAsMfs = false → n ≤ 2)

/-- One item on `sdIn`. -/
theorem additionalItems_range_sat :
    ItemsInRange sdIn (StandardDeduction.standardDeduction sdIn).additionalStandardDeductionItems ∧
    (StandardDeduction.standardDeduction sdIn).additionalStandardDeductionItems = 1 :=
  ⟨additionalItems_range sdIn, by decide +kernel⟩

/-- Rejected: three items for a single filer (a spouse's items counted). -/
theorem additionalItems_range_bad_three_single : ¬ ItemsInRange sdIn 3 := by
  unfold ItemsInRange; decide +kernel

/-- Rejected: a negative count. -/
theorem additionalItems_range_bad_negative : ¬ ItemsInRange sdIn (-1) := by
  unfold ItemsInRange; decide +kernel

/-! ## Interest -/

/-- Three 1099-INTs of $500.51, no foreign account. -/
def intIn : Interest.InterestIn :=
  ⟨List.replicate 3 { has1099 := true, writable1099Amount := 500_51 }, false, .single, 0, false⟩

/-- One 1099-INT of exactly $1,500. -/
def intIn1500 : Interest.InterestIn :=
  ⟨[{ has1099 := true, writable1099Amount := 1_500_00 }], false, .single, 0, false⟩

/-- $1,501.53 of interest requires Schedule B; $1,500.00 does not. -/
theorem requiresScheduleB_eq_spec_sat :
    (Interest.interest intIn).requiresScheduleB =
      scheduleBRequired (intIn.interestReports.map reportTaxableInterest) intIn.hasForeignAccountsOrTrusts ∧
    (Interest.interest intIn).requiresScheduleB = true ∧
    (Interest.interest intIn1500).requiresScheduleB = false :=
  ⟨requiresScheduleB_eq_spec intIn, by decide +kernel, by decide +kernel⟩

/-- Rejected: no Schedule B for $1,501.53. -/
theorem requiresScheduleB_eq_spec_bad_missed :
    ¬ (false = scheduleBRequired (intIn.interestReports.map reportTaxableInterest) false) := by
  decide +kernel

/-- Rejected: Schedule B at exactly $1,500 (the threshold is "over $1,500"). -/
theorem requiresScheduleB_eq_spec_bad_at_threshold :
    ¬ (true = scheduleBRequired (intIn1500.interestReports.map reportTaxableInterest) false) := by
  decide +kernel

/-- Line 2b: each payer rounded, $501 × 3 = $1,503. -/
theorem interestIncome_eq_spec_sat :
    (Interest.interest intIn).interestIncome =
      interestLine2b (intIn.interestReports.map reportTaxableInterest) intIn.hasForeignAccountsOrTrusts ∧
    (Interest.interest intIn).interestIncome = 1_503_00 :=
  ⟨interestIncome_eq_spec intIn, by decide +kernel⟩

/-- Rejected: the total rounded once ($1,502). -/
theorem interestIncome_eq_spec_bad_round_total :
    ¬ ((1_502_00 : Int) = interestLine2b (intIn.interestReports.map reportTaxableInterest) false) := by
  decide +kernel

/-- Rejected: not rounded ($1,501.53). -/
theorem interestIncome_eq_spec_bad_unrounded :
    ¬ ((1_501_53 : Int) = interestLine2b (intIn.interestReports.map reportTaxableInterest) false) := by
  decide +kernel

/-! ## Forms W-2 -/

/-- Two W-2s, each $1,000.40 of wages and $100.60 withheld. -/
def w2In : FormW2s.FormW2sIn :=
  ⟨List.replicate 2 { writableWages := 1_000_40, writableFederalWithholding := 100_60 },
    .single, false, false, .noCombatPay⟩

/-- Line 1a = $1,000 + $1,000. -/
theorem wages_eq_spec_sat :
    (FormW2s.formW2s w2In).wages = totalOfBox (w2In.w2s.map (·.writableWages)) ∧
    (FormW2s.formW2s w2In).wages = 2_000_00 :=
  ⟨wages_eq_spec w2In, by decide +kernel⟩

/-- Rejected: the total rounded once ($2,001). -/
theorem wages_eq_spec_bad_round_total :
    ¬ ((2_001_00 : Int) = totalOfBox (w2In.w2s.map (·.writableWages))) := by decide +kernel

/-- Rejected: not rounded ($2,000.80). -/
theorem wages_eq_spec_bad_unrounded :
    ¬ ((2_000_80 : Int) = totalOfBox (w2In.w2s.map (·.writableWages))) := by decide +kernel

/-- Line 25a = $101 + $101. -/
theorem formW2Withholding_eq_spec_sat :
    (FormW2s.formW2s w2In).formW2Withholding = totalOfBox (w2In.w2s.map (·.writableFederalWithholding)) ∧
    (FormW2s.formW2s w2In).formW2Withholding = 202_00 :=
  ⟨formW2Withholding_eq_spec w2In, by decide +kernel⟩

/-- Rejected: the total rounded once ($201). -/
theorem formW2Withholding_eq_spec_bad_round_total :
    ¬ ((201_00 : Int) = totalOfBox (w2In.w2s.map (·.writableFederalWithholding))) := by decide +kernel

/-- Rejected: not rounded ($201.20). -/
theorem formW2Withholding_eq_spec_bad_unrounded :
    ¬ ((201_20 : Int) = totalOfBox (w2In.w2s.map (·.writableFederalWithholding))) := by decide +kernel

/-- Single, two W-2s of Medicare wages $150,000 and $60,000 ($210,000 > $200,000). -/
def medIn : FormW2s.FormW2sIn :=
  ⟨[{ writableMedicareWages := 150_000_00 }, { writableMedicareWages := 60_000_00 }],
    .single, false, false, .noCombatPay⟩

/-- Single, Medicare wages $100,000 and $50,000. -/
def medInLow : FormW2s.FormW2sIn :=
  ⟨[{ writableMedicareWages := 100_000_00 }, { writableMedicareWages := 50_000_00 }],
    .single, false, false, .noCombatPay⟩

/-- Knocked out at $210,000, not at $150,000. -/
theorem medicareKnockout_eq_spec_sat :
    (FormW2s.formW2s medIn).koKnockoutMedicareWages =
      needsForm8959 medIn.filingStatus (filerBox .primaryFiler (·.writableMedicareWages) medIn.w2s)
        (filerBox .secondaryFiler (·.writableMedicareWages) medIn.w2s) ∧
    (FormW2s.formW2s medIn).koKnockoutMedicareWages = true ∧
    (FormW2s.formW2s medInLow).koKnockoutMedicareWages = false :=
  ⟨medicareKnockout_eq_spec medIn, by decide +kernel, by decide +kernel⟩

/-- Rejected: no knockout for $210,000 (only one W-2 compared with the threshold). -/
theorem medicareKnockout_eq_spec_bad_per_w2 :
    ¬ (false = needsForm8959 .single [150_000_00, 60_000_00] []) := by decide

/-- Rejected: a knockout for $150,000. -/
theorem medicareKnockout_eq_spec_bad_low :
    ¬ (true = needsForm8959 .single [100_000_00, 50_000_00] []) := by decide

/-- Two W-2s of the primary filer, $100,000 of social security wages each. -/
def oasdiIn : FormW2s.FormW2sIn :=
  ⟨List.replicate 2 { writableOasdiWages := 100_000_00 }, .single, false, false, .noCombatPay⟩

/-- The property of `oasdiKnockout_eq_spec` for flags `(p, s, a)` on `oasdiIn`. -/
def OasdiFlags (p s a : Bool) : Prop :=
  p = excessSocialSecurityPossible (filerBox .primaryFiler (·.writableOasdiWages) oasdiIn.w2s) ∧
  s = excessSocialSecurityPossible (filerBox .secondaryFiler (·.writableOasdiWages) oasdiIn.w2s) ∧
  a = (p || s)

/-- Primary filer flagged, spouse not, knockout. -/
theorem oasdiKnockout_eq_spec_sat :
    OasdiFlags (FormW2s.formW2s oasdiIn).primaryFilerExceedsMaxOasdiWages
      (FormW2s.formW2s oasdiIn).secondaryFilerExceedsMaxOasdiWages
      (FormW2s.formW2s oasdiIn).koAnyFilerExceedsMaxOasdiWages ∧
    (FormW2s.formW2s oasdiIn).koAnyFilerExceedsMaxOasdiWages = true :=
  ⟨oasdiKnockout_eq_spec oasdiIn, by decide +kernel⟩

/-- Rejected: nothing flagged (each W-2 is under the wage base). -/
theorem oasdiKnockout_eq_spec_bad_none : ¬ OasdiFlags false false false := by
  unfold OasdiFlags; decide +kernel

/-- Rejected: the primary filer flagged but no knockout. -/
theorem oasdiKnockout_eq_spec_bad_no_knockout : ¬ OasdiFlags true false false := by
  unfold OasdiFlags; decide +kernel

/-! ## Social Security -/

/-- Single, $24,000 of benefits, $30,000 of wages, `other` of other income. -/
def ssIn (other : Int := 0) : SocialSecurity.SocialSecurityIn :=
  ⟨[24_000_00], .single, false, 30_000_00, 0, 0, 0, 0, 0, 0, other, 0⟩

/-- Provisional income $42,000: 85% × $8,000 + $4,500 = $11,300. -/
theorem line6b_eq_spec_sat :
    (SocialSecurity.socialSecurity (ssIn)).line6b =
      taxableSocialSecurity (ssIn).filingStatus (ssIn).livedApartAllYear
        (roundToDollar (ssIn).reportNetBenefits.sum) (ssModifiedAgi (ssIn)) ∧
    (SocialSecurity.socialSecurity (ssIn)).line6b = 11_300_00 :=
  ⟨line6b_eq_spec _, by decide +kernel⟩

/-- Rejected: 85% of all benefits ($20,400). -/
theorem line6b_eq_spec_bad_85_percent :
    ¬ ((20_400_00 : Int) = taxableSocialSecurity .single false 24_000_00 (ssModifiedAgi (ssIn))) := by
  decide +kernel

/-- Rejected: half the benefits ($12,000). -/
theorem line6b_eq_spec_bad_half :
    ¬ ((12_000_00 : Int) = taxableSocialSecurity .single false 24_000_00 (ssModifiedAgi (ssIn))) := by
  decide +kernel

/-- The bound of `line6b_bounds` for a line 6b of `b` and a line 6a of `a`. -/
def Line6bInBounds (a b : Int) : Prop := 0 ≤ b ∧ b ≤ roundToDollar (percentOf 85 (max 0 a))

/-- Line 6a $24,000, line 6b $11,300 ≤ $20,400. -/
theorem line6b_bounds_sat :
    Line6bInBounds (SocialSecurity.socialSecurity (ssIn)).line6a (SocialSecurity.socialSecurity (ssIn)).line6b ∧
    (SocialSecurity.socialSecurity (ssIn)).line6a = 24_000_00 :=
  ⟨line6b_bounds _, by decide +kernel⟩

/-- Rejected: more than 85% of the benefits ($20,401). -/
theorem line6b_bounds_bad_above : ¬ Line6bInBounds 24_000_00 20_401_00 := by
  unfold Line6bInBounds; decide

/-- Rejected: a negative line 6b. -/
theorem line6b_bounds_bad_negative : ¬ Line6bInBounds 24_000_00 (-1) := by
  unfold Line6bInBounds; decide

/-- $0 → $10,000 of other income: line 6b $11,300 → $19,800 (85% × $18,000 + $4,500). -/
theorem line6b_mono_otherIncome_sat :
    (SocialSecurity.socialSecurity { ssIn with line8OtherIncome := 0 }).line6b ≤
      (SocialSecurity.socialSecurity { ssIn with line8OtherIncome := 10_000_00 }).line6b ∧
    (SocialSecurity.socialSecurity { ssIn with line8OtherIncome := 0 }).line6b = 11_300_00 ∧
    (SocialSecurity.socialSecurity { ssIn with line8OtherIncome := 10_000_00 }).line6b = 19_800_00 :=
  ⟨line6b_mono_otherIncome ssIn (by decide), by decide +kernel, by decide +kernel⟩

/-- Rejected: line 6b falling from $19,800 to $11,300 as other income rises. -/
theorem line6b_mono_otherIncome_bad_reversed : ¬ ((19_800_00 : Int) ≤ 11_300_00) := by decide

/-- Rejected: line 6b falling by one cent. -/
theorem line6b_mono_otherIncome_bad_one_cent : ¬ ((11_300_00 : Int) ≤ 11_299_99) := by decide

/-! ## Educator expenses, student loan interest -/

/-- The taxpayer is an educator with $450 of expenses. -/
def edIn : EducatorAdjustment.EducatorAdjustmentIn :=
  { wasK12Educators := .tpDid, primaryEducatorExpensesWritable := 450_00 }

/-- Capped at $300. -/
theorem educatorAdjustment_eq_spec_sat :
    (EducatorAdjustment.educatorAdjustment edIn).educatorExpensesAdjustment =
      educatorDeduction (tpIsEducator edIn.wasK12Educators) (spouseIsEducator edIn.wasK12Educators)
        edIn.primaryEducatorExpensesWritable edIn.secondaryEducatorExpensesWritable edIn.isMfjDependent ∧
    (EducatorAdjustment.educatorAdjustment edIn).educatorExpensesAdjustment = 300_00 :=
  ⟨educatorAdjustment_eq_spec edIn, by decide +kernel⟩

/-- Rejected: no cap ($450). -/
theorem educatorAdjustment_eq_spec_bad_uncapped :
    ¬ ((450_00 : Int) = educatorDeduction true false 450_00 0 false) := by decide

/-- Rejected: the joint cap $600 for one educator. -/
theorem educatorAdjustment_eq_spec_bad_joint_cap :
    ¬ ((600_00 : Int) = educatorDeduction true false 450_00 0 false) := by decide

/-- The bound of `educatorAdjustment_bounds` for one educator. -/
def EducatorInBounds (x : Int) : Prop := 0 ≤ x ∧ x ≤ 300_00 * (1 + 0)

/-- $300, within [$0, $300]; both hypotheses discharged. -/
theorem educatorAdjustment_bounds_sat :
    (0 ≤ (EducatorAdjustment.educatorAdjustment edIn).educatorExpensesAdjustment ∧
      (EducatorAdjustment.educatorAdjustment edIn).educatorExpensesAdjustment ≤
        300_00 * ((if tpIsEducator edIn.wasK12Educators then 1 else 0) +
          (if spouseIsEducator edIn.wasK12Educators then 1 else 0))) ∧
    EducatorInBounds (EducatorAdjustment.educatorAdjustment edIn).educatorExpensesAdjustment :=
  ⟨educatorAdjustment_bounds edIn (by decide) (by decide), by unfold EducatorInBounds; decide +kernel⟩

/-- Rejected: $301 for one educator. -/
theorem educatorAdjustment_bounds_bad_above : ¬ EducatorInBounds 301_00 := by
  unfold EducatorInBounds; decide

/-- Rejected: a negative adjustment. -/
theorem educatorAdjustment_bounds_bad_negative : ¬ EducatorInBounds (-1) := by
  unfold EducatorInBounds; decide

/-- Single, $3,000 of qualifying interest, total income `ti`, no other adjustment. -/
def slIn (ti : Int) : StudentLoanAdjustment.StudentLoanAdjustmentIn :=
  ⟨.single, true, true, 3_000_00, false, false, ti, 0⟩

/-- MAGI $85,000: one third phased out, $2,500 × 2/3 = $1,666.67, entered as $1,667. -/
theorem studentLoanAdjustment_eq_spec_sat :
    (StudentLoanAdjustment.studentLoanAdjustment (slIn 85_000_00)).studentLoanInterestAdjustmentAmount =
      studentLoanDeduction (slIn 85_000_00).filingStatus (studentLoanEligible (slIn 85_000_00))
        (slIn 85_000_00).studentLoanInterestAmount
        ((slIn 85_000_00).totalIncome - (slIn 85_000_00).adjustmentsToIncomeExcludingStudentLoanInterest) ∧
    (StudentLoanAdjustment.studentLoanAdjustment (slIn 85_000_00)).studentLoanInterestAdjustmentAmount =
      1_667_00 :=
  ⟨studentLoanAdjustment_eq_spec _, by decide +kernel⟩

/-- Rejected: Direct File's three-decimal ratio, $1,668 (DF-BUG-7). -/
theorem studentLoanAdjustment_eq_spec_bad_df_ratio :
    ¬ ((1_668_00 : Int) = studentLoanDeduction .single true 3_000_00 85_000_00) := by decide

/-- Rejected: no phase-out ($2,500). -/
theorem studentLoanAdjustment_eq_spec_bad_no_phaseout :
    ¬ ((2_500_00 : Int) = studentLoanDeduction .single true 3_000_00 85_000_00) := by decide

/-- The bound of `studentLoanAdjustment_bounds` with $3,000 of interest. -/
def StudentLoanInBounds (x : Int) : Prop := 0 ≤ x ∧ x ≤ min (roundToDollar 3_000_00) 2_500_00

/-- $1,667 within [$0, $2,500]; the hypothesis discharged. -/
theorem studentLoanAdjustment_bounds_sat :
    (0 ≤ (StudentLoanAdjustment.studentLoanAdjustment (slIn 85_000_00)).studentLoanInterestAdjustmentAmount ∧
      (StudentLoanAdjustment.studentLoanAdjustment (slIn 85_000_00)).studentLoanInterestAdjustmentAmount ≤
        min (roundToDollar (slIn 85_000_00).studentLoanInterestAmount) 2_500_00) ∧
    StudentLoanInBounds
      (StudentLoanAdjustment.studentLoanAdjustment (slIn 85_000_00)).studentLoanInterestAdjustmentAmount :=
  ⟨studentLoanAdjustment_bounds _ (by decide), by unfold StudentLoanInBounds; decide +kernel⟩

/-- Rejected: above the $2,500 cap. -/
theorem studentLoanAdjustment_bounds_bad_cap : ¬ StudentLoanInBounds 2_501_00 := by
  unfold StudentLoanInBounds; decide

/-- Rejected: all the interest paid ($3,000). -/
theorem studentLoanAdjustment_bounds_bad_all_interest : ¬ StudentLoanInBounds 3_000_00 := by
  unfold StudentLoanInBounds; decide

/-- MAGI $95,000 is the end of the single phase-out (hypothesis discharged): `$0`. -/
theorem studentLoanAdjustment_zero_of_magi_ge_end_sat :
    (StudentLoanAdjustment.studentLoanAdjustment (slIn 95_000_00)).studentLoanInterestAdjustmentAmount = 0 :=
  studentLoanAdjustment_zero_of_magi_ge_end _ (by decide +kernel)

/-- Rejected: one dollar left at the end of the phase-out. -/
theorem studentLoanAdjustment_zero_of_magi_ge_end_bad_one_dollar : ¬ ((1_00 : Int) = 0) := by decide

/-- Rejected: an unfloored negative deduction past the phase-out (−$1,250 at $100,000). -/
theorem studentLoanAdjustment_zero_of_magi_ge_end_bad_negative : ¬ ((-1_250_00 : Int) = 0) := by decide

/-- Total income $85,000 → $95,000 (both hypotheses discharged): $1,667 → `$0`. -/
theorem studentLoanAdjustment_antitone_sat :
    (StudentLoanAdjustment.studentLoanAdjustment
        { slIn 0 with totalIncome := 95_000_00 }).studentLoanInterestAdjustmentAmount ≤
      (StudentLoanAdjustment.studentLoanAdjustment
        { slIn 0 with totalIncome := 85_000_00 }).studentLoanInterestAdjustmentAmount ∧
    (StudentLoanAdjustment.studentLoanAdjustment
        { slIn 0 with totalIncome := 85_000_00 }).studentLoanInterestAdjustmentAmount = 1_667_00 :=
  ⟨studentLoanAdjustment_antitone _ (by decide) (by decide), by decide +kernel⟩

/-- Rejected: the deduction rising from `$0` to $1,667 as income rises. -/
theorem studentLoanAdjustment_antitone_bad_rising : ¬ ((1_667_00 : Int) ≤ 0) := by decide

/-- Rejected: the deduction rising from $1,667 to $2,500. -/
theorem studentLoanAdjustment_antitone_bad_cap_regained : ¬ ((2_500_00 : Int) ≤ 1_667_00) := by decide

/-! ## Line 26 and the Form 1040 arithmetic -/

/-- $500.49 paid. -/
def epIn : EstimatedPayments.EstimatedPaymentsIn := ⟨true, 500_49, false, .neither⟩

/-- Line 26 is $500. -/
theorem estimatedPayments_eq_spec_sat :
    (EstimatedPayments.estimatedPayments epIn).estimatedAndFromLastYear =
      estimatedPaymentsLine26 epIn.paidEstimatedTaxesOrFromLastYear epIn.estimatedTaxPaymentWritable ∧
    (EstimatedPayments.estimatedPayments epIn).estimatedAndFromLastYear = 500_00 :=
  ⟨estimatedPayments_eq_spec epIn, by decide +kernel⟩

/-- Rejected: the cents kept ($500.49). -/
theorem estimatedPayments_eq_spec_bad_cents : ¬ ((500_49 : Int) = estimatedPaymentsLine26 true 500_49) := by
  decide

/-- Rejected: an amount counted although "no payments" was answered. -/
theorem estimatedPayments_eq_spec_bad_answered_no :
    ¬ ((500_00 : Int) = estimatedPaymentsLine26 false 500_00) := by decide

/-- The $50,000 return with $300 of educator expenses. -/
def adjReturn : Form1040.Form1040In := { Main.sampleReturn with educatorExpensesAdjustment := 300_00 }

/-- Line 11 = $50,000 − $300. -/
theorem agi_eq_sat :
    (Form1040.form1040 adjReturn).agi =
      (Form1040.form1040 adjReturn).totalIncome - (Form1040.form1040 adjReturn).adjustmentsToIncome ∧
    (Form1040.form1040 adjReturn).totalIncome = 50_000_00 ∧
    (Form1040.form1040 adjReturn).adjustmentsToIncome = 300_00 ∧
    (Form1040.form1040 adjReturn).agi = 49_700_00 :=
  ⟨agi_eq _, by decide +kernel, by decide +kernel, by decide +kernel⟩

/-- Rejected: the adjustment ignored. -/
theorem agi_eq_bad_ignored : ¬ ((50_000_00 : Int) = 50_000_00 - 300_00) := by decide

/-- Rejected: the adjustment added. -/
theorem agi_eq_bad_added : ¬ ((50_300_00 : Int) = 50_000_00 - 300_00) := by decide

/-- One W-2 of $10,000: line 11 $10,000, line 14 $14,600. -/
def lowReturn : Form1040.Form1040In := Form1040.run [{ writableWages := 10_000_00 }]

/-- Line 15 = `max 0 ($10,000 − $14,600)` = `$0`. -/
theorem taxableIncome_eq_sat :
    (Form1040.form1040 lowReturn).taxableIncome =
      max 0 ((Form1040.form1040 lowReturn).agi - (Form1040.form1040 lowReturn).totalDeductions) ∧
    (Form1040.form1040 lowReturn).agi = 10_000_00 ∧
    (Form1040.form1040 lowReturn).totalDeductions = 14_600_00 ∧
    (Form1040.form1040 lowReturn).taxableIncome = 0 :=
  ⟨taxableIncome_eq _, by decide +kernel, by decide +kernel, by decide +kernel⟩

/-- Rejected: not floored (−$4,600). -/
theorem taxableIncome_eq_bad_unfloored : ¬ ((-4_600_00 : Int) = max 0 (10_000_00 - 14_600_00)) := by
  decide

/-- Rejected: the deduction ignored. -/
theorem taxableIncome_eq_bad_no_deduction : ¬ ((10_000_00 : Int) = max 0 (10_000_00 - 14_600_00)) := by
  decide

/-- The $50,000 return with $500 of estimated payments. -/
def estReturn : Form1040.Form1040In :=
  { Main.sampleReturn with paidEstimatedTaxesOrFromLastYear := true, estimatedAndFromLastYear := 500_00 }

/-- Line 33 = $5,000 + $500 + `$0` (hypothesis: $500 is whole dollars). -/
theorem totalPayments_eq_sat :
    (Form1040.form1040 estReturn).totalPayments =
      (Form1040.form1040 estReturn).totalWithholding + estReturn.estimatedAndFromLastYear +
        (Form1040.form1040 estReturn).totalOtherPaymentsRefundableCredits ∧
    (Form1040.form1040 estReturn).totalPayments = 5_500_00 :=
  ⟨totalPayments_eq _ (by decide +kernel), by decide +kernel⟩

/-- Rejected: line 26 left out. -/
theorem totalPayments_eq_bad_no_line26 : ¬ ((5_000_00 : Int) = 5_000_00 + 500_00 + 0) := by decide

/-- Rejected: line 26 counted twice. -/
theorem totalPayments_eq_bad_twice : ¬ ((6_000_00 : Int) = 5_000_00 + 500_00 + 0) := by decide

/-- The whole return of the $50,000 filer who paid $500.49 of estimated tax. -/
def fullIn : Form1040Full.Form1040FullIn := { base := Main.sampleReturn, estimated := epIn }

/-- Line 26 is $500 (cents dropped), line 33 = $5,000 + $500. -/
theorem totalPayments_eq_full_sat :
    (Form1040Full.form1040Full fullIn).form1040.totalPayments =
      (Form1040Full.form1040Full fullIn).form1040.totalWithholding +
        (Form1040Full.form1040Full fullIn).estimated.estimatedAndFromLastYear +
        (Form1040Full.form1040Full fullIn).form1040.totalOtherPaymentsRefundableCredits ∧
    (Form1040Full.form1040Full fullIn).form1040.totalPayments = 5_500_00 :=
  ⟨totalPayments_eq_full _, by decide +kernel⟩

/-- Rejected: the cents of line 26 kept ($5,500.49). -/
theorem totalPayments_eq_full_bad_cents : ¬ ((5_500_49 : Int) = 5_000_00 + 500_00 + 0) := by decide

/-- Rejected: line 26 left out. -/
theorem totalPayments_eq_full_bad_no_line26 : ¬ ((5_000_00 : Int) = 5_000_00 + 500_00 + 0) := by decide

/-- A second W-2 of $10,000 (hypothesis: nonnegative wages): line 24 $4,019 → $5,219. -/
theorem totalTax_mono_addW2_sat :
    (Form1040.form1040 Main.sampleReturn).totalTax ≤
      (Form1040.form1040 { Main.sampleReturn with
        w2s := { writableWages := 10_000_00 } :: Main.sampleReturn.w2s }).totalTax ∧
    (Form1040.form1040 { Main.sampleReturn with
        w2s := { writableWages := 10_000_00 } :: Main.sampleReturn.w2s }).totalTax = 5_219_00 :=
  ⟨totalTax_mono_addW2 _ _ (by decide), by decide +kernel⟩

/-- Rejected: the tax falling from $5,219 to $4,019 when the W-2 is added. -/
theorem totalTax_mono_addW2_bad_reversed : ¬ ((5_219_00 : Int) ≤ 4_019_00) := by decide

/-- Rejected: the tax falling by one cent. -/
theorem totalTax_mono_addW2_bad_one_cent : ¬ ((4_019_00 : Int) ≤ 4_018_99) := by decide

/-! ## The whole return (API examples) -/

/-- The calculator on a request. -/
abbrev wholeReturn (r : Api.Request) : Calculator.CalculatorOut := Calculator.calculator (Api.toCalculatorInput r)

/-- `family-mfj-two-kids`: tax $1,635, payments $3,000, refund $1,365, nothing owed. -/
theorem calculator_refund_balanceDue_consistent_sat :
    RefundOrBalanceDue (wholeReturn mfjKidsReq).totalTax (wholeReturn mfjKidsReq).totalPayments
      (wholeReturn mfjKidsReq).overpayment (wholeReturn mfjKidsReq).balanceDue ∧
    (wholeReturn mfjKidsReq).totalTax = 1_635_00 ∧ (wholeReturn mfjKidsReq).totalPayments = 3_000_00 ∧
    (wholeReturn mfjKidsReq).overpayment = 1_365_00 ∧ (wholeReturn mfjKidsReq).balanceDue = 0 :=
  ⟨calculator_refund_balanceDue_consistent _, by decide +kernel, by decide +kernel,
    by decide +kernel, by decide +kernel⟩

/-- Rejected: refund and amount owed both $1,365. -/
theorem calculator_refund_balanceDue_consistent_bad_both :
    ¬ RefundOrBalanceDue 1_635_00 3_000_00 1_365_00 1_365_00 := by
  unfold RefundOrBalanceDue; omega

/-- Rejected: the child tax credit forgotten in the refund (tax $5,635: $2,635 owed). -/
theorem calculator_refund_balanceDue_consistent_bad_credit_forgotten :
    ¬ RefundOrBalanceDue 1_635_00 3_000_00 0 2_635_00 := by
  unfold RefundOrBalanceDue; omega

/-- `family-mfj-two-kids`: line 18 $5,635, credits $4,000, line 22 $1,635. -/
theorem calculator_credits_within_liability_sat :
    CreditsWithinLiability (wholeReturn mfjKidsReq).totalTentativeTax (wholeReturn mfjKidsReq).nonRefundableCredits
      (wholeReturn mfjKidsReq).taxLessNonRefundableCredits ∧
    (wholeReturn mfjKidsReq).totalTentativeTax = 5_635_00 ∧ (wholeReturn mfjKidsReq).nonRefundableCredits = 4_000_00 ∧
    (wholeReturn mfjKidsReq).taxLessNonRefundableCredits = 1_635_00 :=
  ⟨calculator_credits_within_liability _, by decide +kernel, by decide +kernel, by decide +kernel⟩

/-- Rejected: the credits ignored. -/
theorem calculator_credits_within_liability_bad_ignored :
    ¬ CreditsWithinLiability 5_635_00 4_000_00 5_635_00 := by
  unfold CreditsWithinLiability; omega

/-- Rejected: one dollar off. -/
theorem calculator_credits_within_liability_bad_one_dollar :
    ¬ CreditsWithinLiability 5_635_00 4_000_00 1_636_00 := by
  unfold CreditsWithinLiability; omega

/-- `eitc-hoh-one-child`: $1,844 of tax and $2,000 of child tax credit, line 24 `$0`. -/
theorem calculator_totalTax_nonneg_sat :
    0 ≤ (wholeReturn hohEitcReq).totalTax ∧ (wholeReturn hohEitcReq).totalTax = 0 ∧
    (wholeReturn hohEitcReq).totalTentativeTax = 1_844_00 :=
  ⟨calculator_totalTax_nonneg _, by decide +kernel, by decide +kernel⟩

/-- Rejected: the full $2,000 of child tax credit taken against $1,844 (line 24 −$156). -/
theorem calculator_totalTax_nonneg_bad_unfloored : ¬ (0 ≤ (1_844_00 - 2_000_00 : Int)) := by decide

/-- Rejected: one cent below zero. -/
theorem calculator_totalTax_nonneg_bad_one_cent : ¬ (0 ≤ (-1 : Int)) := by decide

/-- `single-w2-50k`: no CDCC, Schedule R or Saver's credit, line 18 $4,019. -/
theorem calculator_credits_le_tax_sat :
    CreditsWithinTax (wholeReturn singleW2Req).cdccTotalCredit (wholeReturn singleW2Req).totalEdc
      (wholeReturn singleW2Req).qualifiedSaverCreditAmount (wholeReturn singleW2Req).fTax.totalTentativeTax ∧
    (wholeReturn singleW2Req).fTax.totalTentativeTax = 4_019_00 ∧
    (wholeReturn singleW2Req).cdccTotalCredit + (wholeReturn singleW2Req).totalEdc +
      (wholeReturn singleW2Req).qualifiedSaverCreditAmount = 0 :=
  ⟨calculator_credits_le_tax _, by decide +kernel, by decide +kernel⟩

/-- Rejected: CDCC and Schedule R credit each limited by the full $4,019. -/
theorem calculator_credits_le_tax_bad_each_full : ¬ CreditsWithinTax 4_019_00 4_019_00 0 4_019_00 := by
  unfold CreditsWithinTax; omega

/-- Rejected: one dollar over line 18. -/
theorem calculator_credits_le_tax_bad_one_dollar : ¬ CreditsWithinTax 2_000_00 1_000_00 1_020_00 4_019_00 := by
  unfold CreditsWithinTax; omega

/-- The property of `calculator_unsupported_iff` for a flag and a reason list. -/
def UnsupportedIff (u : Bool) (reasons : List Calculator.CalculatorKnockout) : Prop :=
  u = true ↔ reasons ≠ []

/-- `knocked-out-bond-interest`: unsupported, one reason; `single-w2-50k`: supported, none. -/
theorem calculator_unsupported_iff_sat :
    UnsupportedIff (wholeReturn bondKoReq).unsupported (wholeReturn bondKoReq).firedKnockouts ∧
    (wholeReturn bondKoReq).unsupported = true ∧ (wholeReturn bondKoReq).firedKnockouts.length = 1 ∧
    UnsupportedIff (wholeReturn singleW2Req).unsupported (wholeReturn singleW2Req).firedKnockouts ∧
    (wholeReturn singleW2Req).unsupported = false :=
  ⟨calculator_unsupported_iff _, by decide +kernel, by decide +kernel,
    calculator_unsupported_iff _, by decide +kernel⟩

/-- Rejected: unsupported with no reason. -/
theorem calculator_unsupported_iff_bad_silent : ¬ UnsupportedIff true [] := by
  simp [UnsupportedIff]

/-- Rejected: supported, but a reason fired. -/
theorem calculator_unsupported_iff_bad_stray :
    ¬ UnsupportedIff false (wholeReturn bondKoReq).firedKnockouts := by
  have h : (wholeReturn bondKoReq).firedKnockouts.length = 1 := by decide +kernel
  unfold UnsupportedIff
  intro hiff
  have : (wholeReturn bondKoReq).firedKnockouts ≠ [] := by
    intro he; rw [he] at h; simp at h
  simpa using hiff.2 this

/-- `knocked-out-bond-interest`: `supported = false`, one reason. -/
theorem apiCalculator_supported_iff_sat :
    KnockoutSound (ApiCalculator.apiCalculator bondKoReq).supported
      (ApiCalculator.apiCalculator bondKoReq).reasons ∧
    (ApiCalculator.apiCalculator bondKoReq).supported = false ∧
    (ApiCalculator.apiCalculator bondKoReq).reasons.length = 1 :=
  ⟨apiCalculator_supported_iff _, by decide +kernel, by decide +kernel⟩

/-- Rejected: a 422 with an empty reason list. -/
theorem apiCalculator_supported_iff_bad_silent :
    ¬ KnockoutSound false ([] : List Calculator.CalculatorKnockout) := by
  simp [KnockoutSound]

/-- Rejected: `supported = true` with the bond reason still listed. -/
theorem apiCalculator_supported_iff_bad_stray :
    ¬ KnockoutSound true (wholeReturn bondKoReq).firedKnockouts := by
  have h : (wholeReturn bondKoReq).firedKnockouts.length = 1 := by decide +kernel
  unfold KnockoutSound
  intro hiff
  have : (wholeReturn bondKoReq).firedKnockouts ≠ [] := by
    intro he; rw [he] at h; simp at h
  simpa using hiff.2 this

/-- `eitc-hoh-one-child`: `refund`, $3,604; `single-w2-50k`: `balance_due`, nothing overpaid. -/
theorem apiCalculator_outcome_refund_iff_sat :
    RefundOutcome (ApiCalculator.apiCalculator hohEitcReq).outcome
      (ApiCalculator.apiCalculator hohEitcReq).lines.overpayment ∧
    (ApiCalculator.apiCalculator hohEitcReq).outcome = .refund ∧
    (ApiCalculator.apiCalculator hohEitcReq).lines.overpayment = 3_604_00 ∧
    RefundOutcome (ApiCalculator.apiCalculator singleW2Req).outcome
      (ApiCalculator.apiCalculator singleW2Req).lines.overpayment ∧
    (ApiCalculator.apiCalculator singleW2Req).outcome = .balanceDue :=
  ⟨apiCalculator_outcome_refund_iff _, by decide +kernel, by decide +kernel,
    apiCalculator_outcome_refund_iff _, by decide +kernel⟩

/-- Rejected: `refund` for `single-w2-50k`, which overpaid nothing. -/
theorem apiCalculator_outcome_refund_iff_bad_refund_zero : ¬ RefundOutcome .refund 0 := by
  simp [RefundOutcome]

/-- Rejected: `balance_due` for the $3,604 refund. -/
theorem apiCalculator_outcome_refund_iff_bad_balance_due : ¬ RefundOutcome .balanceDue 3_604_00 := by
  simp [RefundOutcome]

/-- `single-w2-50k` (its `Valid` hypothesis discharged by the reader): HTTP 200;
`knocked-out-bond-interest`: HTTP 422. Neither is the 500 `fault`. -/
theorem calculateRequest_ne_fault_sat :
    Api.calculateRequest singleW2Req singleW2_valid ≠ .fault ∧
    (Api.calculateRequest singleW2Req singleW2_valid).status = 200 ∧
    Api.calculateRequest bondKoReq bondKo_valid ≠ .fault ∧
    (Api.calculateRequest bondKoReq bondKo_valid).status = 422 :=
  ⟨calculateRequest_ne_fault _ _, by decide +kernel, calculateRequest_ne_fault _ _, by decide +kernel⟩

/-- Rejected: the 500 answer itself (the only bad value of the reply type). -/
theorem calculateRequest_ne_fault_bad_fault : ¬ (Api.Reply.fault ≠ Api.Reply.fault) := by
  simp

/-- A wrong endpoint: answers 500 instead of 422 on every unsupported return. -/
def faultyEndpoint (r : Api.Request) (_h : r.Valid) : Api.Reply :=
  if (ApiCalculator.apiCalculator r).supported then .success (ApiCalculator.apiCalculator r).lines []
  else .fault

/-- Rejected: that endpoint, on `knocked-out-bond-interest`. -/
theorem calculateRequest_ne_fault_bad_faulty_endpoint :
    ¬ (∀ (r : Api.Request) (h : r.Valid), faultyEndpoint r h ≠ .fault) := by
  intro hall
  have hs : (ApiCalculator.apiCalculator bondKoReq).supported = false := by decide +kernel
  exact hall bondKoReq bondKo_valid (by simp [faultyEndpoint, hs])

end UsTax.Checks.Extra
