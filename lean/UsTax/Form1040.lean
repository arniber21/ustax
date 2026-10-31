import UsTax.Money
import UsTax.Types
import UsTax.TaxRates
import UsTax.StandardDeduction
import UsTax.FormW2s
import UsTax.Interest

/-!
# Form 1040 assembly, lines 1a to 37 (issue #43)

Lean implementation of `catala/form_1040.catala_en` (module `Form_1040`, scope
`Form1040`), written by hand from the Catala source under strategy (c) of
`docs/catala-to-lean.md`; the code that runs. It wires the sub-scopes
`FormW2s`, `Interest` (twice), `StandardDeduction` and `TentativeTax` exactly
as the Catala scope does.

| Catala (`Form_1040`)               | Lean (`UsTax.Form1040`)               |
|------------------------------------|---------------------------------------|
| `scope Form1040` inputs (`input`)  | `Form1040In` fields without default   |
| `scope Form1040` plug-in slots (`context ... equals $0`) | `Form1040In` fields **with default `0`** (`false`) |
| `scope Form1040` outputs           | `Form1040Out` (`form1040 : Form1040In → Form1040Out`) |
| `w2`, `interest`, `interest_ko`, `std_deduction`, `tax_table` | the calls `formW2s`, `interest` (twice), `standardDeduction`, `tentativeTax` |

**Plug-in slots.** The lines that later modules compute (`taxable_dependent_care`,
`taxable_pensions_and_annuities`, ..., `other_payments_and_refundable_credits_total`)
are fields of `Form1040In` that default to `$0` / `false` as in Catala, so a
later Lean module plugs in by setting its field.

**Knockouts.** `unsupported` is the union of the W-2 and interest knockouts
(the interest scope run a second time with the real AGI) and
`knockoutHasNoPaymentsOrCredits`; the driver reports it, as Catala does.

Money is `Int` cents; the rounding points are Catala's (`Money.roundDollar` at
every `R.round_dollar`).
-/

namespace UsTax.Form1040

open Money

/-- Inputs of `Form1040`: the answers (no default) and the plug-in slots
(default `0`, as `context ... equals $0` in Catala). -/
structure Form1040In where
  /-- Catala input `filing_status`. -/
  filingStatus : FilingStatus
  /-- Catala input `w2s`. -/
  w2s : List FormW2s.FormW2
  /-- Catala input `interest_reports`. -/
  interestReports : List Interest.InterestReport
  /-- Catala input `has_foreign_accounts_or_trusts`. -/
  hasForeignAccountsOrTrusts : Bool
  /-- Catala input `combat_pay_election`. -/
  combatPayElection : FormW2s.CombatPayElection
  /-- Catala input `primary_filer_can_be_claimed`. -/
  primaryFilerCanBeClaimed : Bool
  /-- Catala input `secondary_filer_can_be_claimed`. -/
  secondaryFilerCanBeClaimed : Bool
  /-- Catala input `treat_as_mfs`. -/
  treatAsMfs : Bool
  /-- Catala input `primary_filer_is_blind`. -/
  primaryFilerIsBlind : Bool
  /-- Catala input `primary_filer_age65_or_older`. -/
  primaryFilerAge65OrOlder : Bool
  /-- Catala input `secondary_filer_is_blind`. -/
  secondaryFilerIsBlind : Bool
  /-- Catala input `secondary_filer_age65_or_older`. -/
  secondaryFilerAge65OrOlder : Bool
  /-- Catala input `is_widowed_in_tax_year`. -/
  isWidowedInTaxYear : Bool
  /-- Catala input `mfj_deceased_spouse_reached_age65`. -/
  mfjDeceasedSpouseReachedAge65 : Bool
  /-- Catala input `mfs_spouse_65_or_older`. -/
  mfsSpouse65OrOlder : Bool
  /-- Catala input `mfs_spouse_provides_no_benefits`. -/
  mfsSpouseProvidesNoBenefits : Bool
  /-- Catala input `treat_filers_as_dependents`. -/
  treatFilersAsDependents : Bool
  -- plug-in slots, default 0 / false
  /-- Catala input `taxable_dependent_care`. -/
  taxableDependentCare : Int := 0
  /-- Catala input `taxable_pensions_and_annuities`. -/
  taxablePensionsAndAnnuities : Int := 0
  /-- Catala input `taxable_social_security_benefits`. -/
  taxableSocialSecurityBenefits : Int := 0
  /-- Catala input `unemployment_compensation`. -/
  unemploymentCompensation : Int := 0
  /-- Catala input `alaska_pfd_income`. -/
  alaskaPfdIncome : Int := 0
  /-- Catala input `student_loan_interest_adjustment_amount`. -/
  studentLoanInterestAdjustmentAmount : Int := 0
  /-- Catala input `educator_expenses_adjustment`. -/
  educatorExpensesAdjustment : Int := 0
  /-- Catala input `hsa_total_deductible_amount`. -/
  hsaTotalDeductibleAmount : Int := 0
  /-- Catala input `total_additional_taxes_owed`. -/
  totalAdditionalTaxesOwed : Int := 0
  /-- Catala input `total_ctc_and_odc`. -/
  totalCtcAndOdc : Int := 0
  /-- Catala input `line8_of_schedule3`. -/
  line8OfSchedule3 : Int := 0
  /-- Catala input `other_1099_withholding`. -/
  other1099Withholding : Int := 0
  /-- Catala input `paid_estimated_taxes_or_from_last_year`. -/
  paidEstimatedTaxesOrFromLastYear : Bool := false
  /-- Catala input `estimated_and_from_last_year`. -/
  estimatedAndFromLastYear : Int := 0
  /-- Catala input `earned_income_credit`. -/
  earnedIncomeCredit : Int := 0
  /-- Catala input `additional_ctc`. -/
  additionalCtc : Int := 0
  /-- Catala input `other_payments_and_refundable_credits_total`. -/
  otherPaymentsAndRefundableCreditsTotal : Int := 0

/-- Outputs of `Form1040` (Catala `output` variables), cents. -/
structure Form1040Out where
  /-- Line 1a. -/
  wages : Int
  /-- Line 1z. -/
  employerIncomeSubtotal : Int
  /-- Line 2b. -/
  interestIncome : Int
  /-- Catala output `schedule1_total_other_income`. -/
  schedule1TotalOtherIncome : Int
  /-- Line 8. -/
  otherIncome : Int
  /-- Line 9. -/
  totalIncome : Int
  /-- Line 10. -/
  adjustmentsToIncome : Int
  /-- Line 11. -/
  agi : Int
  /-- Line 12. -/
  standardOrItemizedDeductions : Int
  /-- Line 13. -/
  qualifiedBusinessIncomeDeduction : Int
  /-- Line 14. -/
  totalDeductions : Int
  /-- Line 15. -/
  taxableIncome : Int
  /-- Line 16. -/
  tentativeTaxFromTaxableIncome : Int
  /-- Line 18. -/
  totalTentativeTax : Int
  /-- Line 21. -/
  nonRefundableCredits : Int
  /-- Line 22. -/
  taxLessNonRefundableCredits : Int
  /-- Line 23. -/
  line21OfSchedule2 : Int
  /-- Line 24. -/
  totalTax : Int
  /-- Line 25a. -/
  formW2Withholding : Int
  /-- Line 25b. -/
  form1099Withholding : Int
  /-- Line 25c. -/
  otherFormWithholding : Int
  /-- Line 25d. -/
  totalWithholding : Int
  /-- Line 29. -/
  americanOpportunityCredit : Int
  /-- Line 32. -/
  totalOtherPaymentsRefundableCredits : Int
  /-- Line 33. -/
  totalPayments : Int
  /-- Line 34. -/
  overpayment : Int
  /-- Line 37. -/
  balanceDue : Int
  /-- Catala output `ko_knockout_has_no_payments_or_credits`. -/
  koKnockoutHasNoPaymentsOrCredits : Bool
  /-- Catala output `unsupported`. -/
  unsupported : Bool

/-- Catala `scope Form1040`. -/
def form1040 (i : Form1040In) : Form1040Out :=
  -- sub-scopes
  let w2 := FormW2s.formW2s
    { w2s := i.w2s, filingStatus := i.filingStatus,
      primaryFilerCanBeClaimed := i.primaryFilerCanBeClaimed,
      secondaryFilerCanBeClaimed := i.secondaryFilerCanBeClaimed,
      combatPayElection := i.combatPayElection }
  let interestIn : Interest.InterestIn :=
    { interestReports := i.interestReports,
      hasForeignAccountsOrTrusts := i.hasForeignAccountsOrTrusts,
      filingStatus := i.filingStatus, agi := 0, flowHasSeenDeductions := true }
  let interest := Interest.interest interestIn
  -- Second Interest instance, used only for its AGI-based knockouts
  let interestKo (agi : Int) := Interest.interest { interestIn with agi := agi }
  -- Income
  let wages := w2.wages
  let employerIncomeSubtotal :=
    roundDollar ((w2.primaryFilerWages + 0 + 0 + 0 + 0 + 0 + 0)
      + (w2.secondaryFilerWages + 0 + 0 + 0 + 0 + 0 + 0) + i.taxableDependentCare)
  let interestIncome := interest.interestIncome
  let schedule1TotalOtherIncome := roundDollar i.alaskaPfdIncome
  let otherIncome := roundDollar (i.unemploymentCompensation + schedule1TotalOtherIncome)
  let totalIncome :=
    roundDollar (employerIncomeSubtotal + interestIncome + 0 + 0
      + i.taxablePensionsAndAnnuities + i.taxableSocialSecurityBenefits + 0 + otherIncome)
  -- Adjustments, AGI, deductions, taxable income
  let adjustmentsToIncome :=
    roundDollar (i.studentLoanInterestAdjustmentAmount + i.educatorExpensesAdjustment
      + i.hsaTotalDeductibleAmount)
  let agi := roundDollar (totalIncome - adjustmentsToIncome)
  let stdDeduction := StandardDeduction.standardDeduction
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
      employerIncomeSubtotal := employerIncomeSubtotal }
  let standardOrItemizedDeductions := roundDollar stdDeduction.standardDeduction
  -- QUIRK(Q4): line 13 is a $0 stub and line 14 does not add it.
  let totalDeductions := roundDollar standardOrItemizedDeductions
  let taxableIncome := roundDollar (positive (agi - totalDeductions))
  -- Tax and credits
  let taxTable := TaxRates.tentativeTax { taxableIncome := taxableIncome, filingStatus := i.filingStatus }
  let tentativeTaxFromTaxableIncome := taxTable.tentativeTaxFromTaxableIncome
  let totalTentativeTax := roundDollar (tentativeTaxFromTaxableIncome + i.totalAdditionalTaxesOwed)
  let nonRefundableCredits := roundDollar (i.totalCtcAndOdc + i.line8OfSchedule3)
  let taxLessNonRefundableCredits :=
    roundDollar (positive (totalTentativeTax - nonRefundableCredits))
  -- QUIRK(Q3): line 23 is defined (0) but never added.
  let totalTax := roundDollar taxLessNonRefundableCredits
  -- Payments
  let formW2Withholding := w2.formW2Withholding
  let form1099Withholding := interest.totalTaxWithheld + i.other1099Withholding
  let totalWithholding := roundDollar (formW2Withholding + form1099Withholding)
  -- QUIRK(Q4): line 29 is a $0 stub.
  let americanOpportunityCredit := 0
  let totalOtherPaymentsRefundableCredits :=
    roundDollar (i.earnedIncomeCredit + i.additionalCtc + americanOpportunityCredit
      + i.otherPaymentsAndRefundableCreditsTotal)
  let totalPayments :=
    roundDollar (totalWithholding + i.estimatedAndFromLastYear + totalOtherPaymentsRefundableCredits)
  -- Refund or amount owed
  let koNoPayments :=
    !i.paidEstimatedTaxesOrFromLastYear && totalIncome == 0 && agi == 0 &&
      totalTentativeTax == 0 && nonRefundableCredits == 0 && totalTax == 0 && totalPayments == 0
  { wages := wages
    employerIncomeSubtotal := employerIncomeSubtotal
    interestIncome := interestIncome
    schedule1TotalOtherIncome := schedule1TotalOtherIncome
    otherIncome := otherIncome
    totalIncome := totalIncome
    adjustmentsToIncome := adjustmentsToIncome
    agi := agi
    standardOrItemizedDeductions := standardOrItemizedDeductions
    qualifiedBusinessIncomeDeduction := 0
    totalDeductions := totalDeductions
    taxableIncome := taxableIncome
    tentativeTaxFromTaxableIncome := tentativeTaxFromTaxableIncome
    totalTentativeTax := totalTentativeTax
    nonRefundableCredits := nonRefundableCredits
    taxLessNonRefundableCredits := taxLessNonRefundableCredits
    line21OfSchedule2 := 0
    totalTax := totalTax
    formW2Withholding := formW2Withholding
    form1099Withholding := form1099Withholding
    otherFormWithholding := 0
    totalWithholding := totalWithholding
    americanOpportunityCredit := americanOpportunityCredit
    totalOtherPaymentsRefundableCredits := totalOtherPaymentsRefundableCredits
    totalPayments := totalPayments
    overpayment := roundDollar (positive (totalPayments - totalTax))
    balanceDue := roundDollar (positive (totalTax - totalPayments))
    koKnockoutHasNoPaymentsOrCredits := koNoPayments
    unsupported := w2.unsupported || interest.unsupported || (interestKo agi).unsupported ||
      koNoPayments }

/-! ### Unit tests: every assertion of `catala/tests/test_form_1040.catala_en`

`run` is the Catala helper scope `Run1040`: a single filer, standard deduction
only, every slot at its default unless the test sets it. -/

open FormW2s Interest in
/-- A single filer with the given W-2s and interest reports. -/
def run (w2s : List FormW2) (interestReports : List InterestReport := [])
    (fs : FilingStatus := .single) : Form1040In :=
  { filingStatus := fs, w2s := w2s, interestReports := interestReports,
    hasForeignAccountsOrTrusts := false, combatPayElection := .noCombatPay,
    primaryFilerCanBeClaimed := false, secondaryFilerCanBeClaimed := false,
    treatAsMfs := fs == .marriedFilingSeparately,
    primaryFilerIsBlind := false, primaryFilerAge65OrOlder := false,
    secondaryFilerIsBlind := false, secondaryFilerAge65OrOlder := false,
    isWidowedInTaxYear := false, mfjDeceasedSpouseReachedAge65 := false,
    mfsSpouse65OrOlder := false, mfsSpouseProvidesNoBenefits := false,
    treatFilersAsDependents := false }

private def w2 (wages : Int) (withholding : Int := 0) (stat : Bool := false)
    (filer : FilerRole := .primaryFiler) : FormW2s.FormW2 :=
  { filer := filer, writableWages := wages, writableFederalWithholding := withholding,
    statutoryEmployee := stat }

private def int1099 (box1 : Int) (withheld : Int := 0) (exempt : Int := 0) : Interest.InterestReport :=
  { has1099 := true, writable1099Amount := box1, writableTaxWithheld := withheld,
    writableTaxExemptInterest := exempt }

-- TestSingle50k
private def single50k := form1040 (run [w2 5_000_000])
#guard single50k.wages == 5_000_000
#guard single50k.employerIncomeSubtotal == 5_000_000
#guard single50k.totalIncome == 5_000_000
#guard single50k.adjustmentsToIncome == 0
#guard single50k.agi == 5_000_000
#guard single50k.standardOrItemizedDeductions == 1_460_000
#guard single50k.taxableIncome == 3_540_000
#guard single50k.tentativeTaxFromTaxableIncome == 401_900
#guard single50k.totalTentativeTax == 401_900
#guard single50k.nonRefundableCredits == 0
#guard single50k.totalTax == 401_900
#guard single50k.totalPayments == 0
#guard single50k.overpayment == 0
#guard single50k.balanceDue == 401_900
#guard !single50k.unsupported

-- TestRefundAndBalanceDue
private def refund := form1040 (run [w2 5_000_000 500_000])
private def owe := form1040 (run [w2 5_000_000 300_000])
private def even := form1040 (run [w2 5_000_000 401_900])
#guard refund.totalWithholding == 500_000
#guard refund.totalPayments == 500_000
#guard refund.overpayment == 98_100
#guard refund.balanceDue == 0
#guard owe.totalPayments == 300_000
#guard owe.overpayment == 0
#guard owe.balanceDue == 101_900
#guard even.overpayment == 0
#guard even.balanceDue == 0
#guard refund.overpayment == 0 || refund.balanceDue == 0
#guard owe.overpayment == 0 || owe.balanceDue == 0
#guard even.overpayment == 0 || even.balanceDue == 0

-- TestW2PlusInterest
private def w2PlusInterest := form1040 (run [w2 5_000_000] [int1099 100_000 10_000])
#guard w2PlusInterest.interestIncome == 100_000
#guard w2PlusInterest.totalIncome == 5_100_000
#guard w2PlusInterest.agi == 5_100_000
#guard w2PlusInterest.taxableIncome == 3_640_000
#guard w2PlusInterest.tentativeTaxFromTaxableIncome == 413_900
#guard w2PlusInterest.totalTax == 413_900
#guard w2PlusInterest.totalWithholding == 10_000
#guard w2PlusInterest.balanceDue == 403_900
#guard w2PlusInterest.overpayment == 0
#guard !w2PlusInterest.unsupported

-- TestMfjTwoW2s
private def mfj := form1040 (run [w2 4_000_000, w2 3_000_000 (filer := .secondaryFiler)] (fs := .marriedFilingJointly))
#guard mfj.wages == 7_000_000
#guard mfj.agi == 7_000_000
#guard mfj.standardOrItemizedDeductions == 2_920_000
#guard mfj.taxableIncome == 4_080_000
#guard mfj.totalTax == 443_500

-- TestTaxableIncomeFloor
private def floor0 := form1040 (run [w2 1_000_000 50_000])
#guard floor0.taxableIncome == 0
#guard floor0.totalTax == 0
#guard floor0.overpayment == 50_000
#guard floor0.balanceDue == 0

-- TestSlots
private def slotsBase := run [w2 5_000_000 100_000]
private def adj := form1040 { slotsBase with educatorExpensesAdjustment := 30_000, studentLoanInterestAdjustmentAmount := 250_000, hsaTotalDeductibleAmount := 70_000 }
#guard adj.adjustmentsToIncome == 350_000
#guard adj.agi == 4_650_000
#guard adj.taxableIncome == 3_190_000
#guard adj.totalTax == 359_900
private def cred := form1040 { slotsBase with totalCtcAndOdc := 200_000, line8OfSchedule3 := 50_000, estimatedAndFromLastYear := 40_000, earnedIncomeCredit := 30_000, additionalCtc := 20_000, otherPaymentsAndRefundableCreditsTotal := 10_000 }
#guard cred.nonRefundableCredits == 250_000
#guard cred.taxLessNonRefundableCredits == 151_900
#guard cred.totalTax == 151_900
#guard cred.totalOtherPaymentsRefundableCredits == 60_000
#guard cred.totalPayments == 200_000
#guard cred.overpayment == 48_100
#guard cred.balanceDue == 0
#guard (form1040 { slotsBase with totalCtcAndOdc := 500_000 }).taxLessNonRefundableCredits == 0
#guard (form1040 { slotsBase with totalCtcAndOdc := 500_000 }).totalTax == 0
private def sch2 := form1040 { slotsBase with totalAdditionalTaxesOwed := 10_900 }
#guard sch2.totalTentativeTax == 412_800
#guard sch2.totalTax == 412_800

-- TestLine23NotAdded
#guard single50k.line21OfSchedule2 == 0
#guard single50k.totalTax == single50k.taxLessNonRefundableCredits

-- TestUnsupported
#guard (form1040 (run [w2 5_000_000 (stat := true)])).unsupported
#guard (form1040 (run [w2 5_000_000] [int1099 100_000 (exempt := 500)])).unsupported
private def rich := form1040 (run [w2 25_000_000] [int1099 100_000])
#guard rich.agi == 25_100_000
#guard rich.unsupported
#guard (form1040 (run [])).totalIncome == 0
#guard (form1040 (run [])).unsupported
#guard !(form1040 (run [w2 5_000_000] [int1099 100_000])).unsupported

-- TestRejectsBadOutputs
private def bad := form1040 (run [w2 5_000_000 300_000])
#guard bad.taxableIncome != 5_000_000
#guard bad.totalTax != 605_900
#guard !(bad.overpayment > 0 && bad.balanceDue > 0)
#guard bad.totalTax != bad.tentativeTaxFromTaxableIncome + 100
#guard bad.balanceDue == bad.totalTax - bad.totalPayments

end UsTax.Form1040
