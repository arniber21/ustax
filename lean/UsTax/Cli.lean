import Lean.Data.Json
import UsTax.TaxRates
import UsTax.Date
import UsTax.StandardDeduction
import UsTax.FormW2s
import UsTax.Interest
import UsTax.Form1040
import UsTax.Unemployment
import UsTax.Form1099Misc
import UsTax.Form1099Rs
import UsTax.SocialSecurity
import UsTax.EducatorAdjustment
import UsTax.StudentLoanAdjustment
import UsTax.EstimatedPayments

/-!
# Command-line and JSON boundary of the Lean calculator

The `ustax` executable (`lean/Main.lean`) is a thin wrapper over this module.
Each Catala scope implemented in Lean gets one entry in `scopes`: a function
from the scope's **Catala JSON input** (the object `clerk run -s <Scope>
--input=<file>` accepts; `catala json-schema -s <Scope>` prints its shape) to
a JSON object of the scope's outputs, keyed by the Catala output names. So the
differential test feeds the same input object to Catala and to Lean and
compares outputs by name.

Money crosses the boundary as a decimal string or JSON number of dollars with
at most two decimals (`"14999"`, `"123456.78"`, `-3.5`), parsed exactly to
cents: never through a float. Outputs are strings with two decimals
(`"1565.00"`). Enumerations are their Catala case names (`"Single"`); Direct
File's spelling (`"single"`) is accepted too.
-/

namespace UsTax.Cli

open Lean (Json JsonNumber toJson)
open UsTax (FilerRole)

/-- Parse dollars (`"1,234.5"`, `"-$3.50"`, `"7"`) to cents, exactly. At most
two decimals; anything else is `none`. -/
def parseMoney (s : String) : Option Int := do
  let s := s.trimAscii.toString
  let (neg, s) := if s.startsWith "-" then (true, (s.drop 1).toString) else (false, s)
  let s := if s.startsWith "$" then (s.drop 1).toString else s
  let s := s.replace "," ""
  let (whole, frac) ← match s.splitOn "." with
    | [w] => some (w, "")
    | [w, f] => some (w, f)
    | _ => none
  guard (whole.length > 0 && frac.length ≤ 2)
  guard ((whole ++ frac).all Char.isDigit)
  let cents := whole.toNat! * 100 + (frac ++ "00".drop frac.length).toNat!
  return if neg then -(cents : Int) else cents

/-- Cents to dollars with two decimals: `156500` is `"1565.00"`. -/
def showMoney (c : Int) : String :=
  let a := c.natAbs
  let cents := toString (a % 100)
  (if c < 0 then "-" else "") ++ toString (a / 100) ++ "." ++
    (if cents.length < 2 then "0" ++ cents else cents)

/-- Money from a Catala JSON input value: a string or an exact JSON number. -/
def moneyOfJson : Json → Except String Int
  | .str s => match parseMoney s with
    | some c => .ok c
    | none => .error s!"bad money {s.quote}"
  | .num n =>
    if n.exponent ≤ 2 then .ok (n.mantissa * 10 ^ (2 - n.exponent))
    else
      let d : Int := 10 ^ (n.exponent - 2)
      if n.mantissa % d = 0 then .ok (n.mantissa / d)
      else .error s!"money with more than two decimals: {n}"
  | j => .error s!"bad money {j.compress}"

/-- A filing status from its Catala or Direct File name. -/
def filingStatusOfJson (j : Json) : Except String FilingStatus := do
  let s ← j.getStr?
  match FilingStatus.ofString? s with
  | some fs => .ok fs
  | none => .error s!"bad filing status {s.quote}"

/-- Field `k` of a JSON object. -/
def field (j : Json) (k : String) : Except String Json :=
  match j.getObjVal? k with
  | .ok v => .ok v
  | .error _ => .error s!"missing input {k}"

/-- Catala scope `Tax_rates.TentativeTax` on its JSON input. -/
def runTentativeTax (j : Json) : Except String Json := do
  let i : TaxRates.TentativeTaxIn :=
    { taxableIncome := ← moneyOfJson (← field j "taxable_income")
      filingStatus := ← filingStatusOfJson (← field j "filing_status") }
  let o := TaxRates.tentativeTax i
  return Json.mkObj [
    ("rounded_taxable_income", showMoney o.roundedTaxableIncome),
    ("tentative_tax_from_taxable_income", showMoney o.tentativeTaxFromTaxableIncome),
    ("tentative_tax_cumulative_form", showMoney o.tentativeTaxCumulativeForm)]

/-! ### Decoding the Catala JSON input of the spine scopes

Booleans are JSON booleans, enumerations are Catala case names (Direct File's
spelling is accepted for filing status), lists are arrays, dates are
`"YYYY-MM-DD"`, money is as in `moneyOfJson`. The fields of a struct and the
inputs of a scope are required, exactly as for `clerk run`; only the
`context` plug-in slots of `Form1040` are optional (Catala default `$0`/`false`). -/

/-- Required money field `k` of object `j`. -/
def moneyReq (j : Json) (k : String) : Except String Int := do moneyOfJson (← field j k)

/-- Optional money field `k`: absent means `$0` (a Catala `context` default). -/
def moneyOpt (j : Json) (k : String) : Except String Int :=
  match j.getObjVal? k with
  | .ok v => moneyOfJson v
  | .error _ => .ok 0

/-- Required boolean field `k`. -/
def boolReq (j : Json) (k : String) : Except String Bool := do (← field j k).getBool?

/-- Optional boolean field `k`: absent means `false`. -/
def boolOpt (j : Json) (k : String) : Except String Bool :=
  match j.getObjVal? k with
  | .ok v => v.getBool?
  | .error _ => .ok false

/-- Required list field `k`, each element decoded by `f`. -/
def listReq {α} (j : Json) (k : String) (f : Json → Except String α) : Except String (List α) := do
  let arr ← (← field j k).getArr?
  arr.toList.mapM f

/-- A date `"YYYY-MM-DD"`. -/
def dateOfJson (j : Json) : Except String UsTax.Date := do
  let s ← j.getStr?
  match s.splitOn "-" with
  | [y, m, d] =>
    match y.toInt?, m.toNat?, d.toNat? with
    | some y, some m, some d => .ok { year := y, month := m, day := d }
    | _, _, _ => .error s!"bad date {s.quote}"
  | _ => .error s!"bad date {s.quote}"

/-- A filer role from its Catala case name. -/
def filerRoleOfJson (j : Json) : Except String FilerRole := do
  let s ← j.getStr?
  match FilerRole.ofString? s with
  | some r => .ok r
  | none => .error s!"bad filer role {s.quote}"

/-- A combat pay election from its Catala case name. -/
def combatPayElectionOfJson (j : Json) : Except String FormW2s.CombatPayElection := do
  let s ← j.getStr?
  match FormW2s.CombatPayElection.ofString? s with
  | some r => .ok r
  | none => .error s!"bad combat pay election {s.quote}"

/-- Catala `Form_w2s.FormW2`. -/
def w2OfJson (j : Json) : Except String FormW2s.FormW2 :=
  return {
      filer := ← filerRoleOfJson (← field j "filer"),
      writableWages := ← moneyReq j "writable_wages",
      writableFederalWithholding := ← moneyReq j "writable_federal_withholding",
      writableOasdiWages := ← moneyReq j "writable_oasdi_wages",
      writableOasdiWithholding := ← moneyReq j "writable_oasdi_withholding",
      writableMedicareWages := ← moneyReq j "writable_medicare_wages",
      writableMedicareWithholding := ← moneyReq j "writable_medicare_withholding",
      writableAllocatedTips := ← moneyReq j "writable_allocated_tips",
      writableDependentCareBenefits := ← moneyReq j "writable_dependent_care_benefits",
      writableNonQualifiedPlans := ← moneyReq j "writable_non_qualified_plans",
      uncollectedOasdiTaxOnTips := ← moneyReq j "uncollected_oasdi_tax_on_tips",
      uncollectedMedicareTaxOnTips := ← moneyReq j "uncollected_medicare_tax_on_tips",
      taxableLifeInsuranceOver50k := ← moneyReq j "taxable_life_insurance_over_50k",
      deferrals401k := ← moneyReq j "deferrals_401k",
      deferrals403b := ← moneyReq j "deferrals_403b",
      sarsepDeferrals := ← moneyReq j "sarsep_deferrals",
      deferrals457b := ← moneyReq j "deferrals_457b",
      deferrals501c18 := ← moneyReq j "deferrals_501c18",
      nontaxableSickPay := ← moneyReq j "nontaxable_sick_pay",
      goldenParachuteExciseTax := ← moneyReq j "golden_parachute_excise_tax",
      expenseReimbursements := ← moneyReq j "expense_reimbursements",
      uncollectedOasdiTaxOnLifeInsuranceOver50k := ← moneyReq j "uncollected_oasdi_tax_on_life_insurance_over_50k",
      uncollectedMedicareTaxOnLifeInsuranceOver50k := ← moneyReq j "uncollected_medicare_tax_on_life_insurance_over_50k",
      armedForcesMovingExpenses := ← moneyReq j "armed_forces_moving_expenses",
      writableCombatPay := ← moneyReq j "writable_combat_pay",
      archerMsaContributions := ← moneyReq j "archer_msa_contributions",
      simpleContributions := ← moneyReq j "simple_contributions",
      adoptionBenefits := ← moneyReq j "adoption_benefits",
      nsoIncome := ← moneyReq j "nso_income",
      employerHsaContributions := ← moneyReq j "employer_hsa_contributions",
      deferrals409a := ← moneyReq j "deferrals_409a",
      nqdcDeferrals := ← moneyReq j "nqdc_deferrals",
      roth401kContributions := ← moneyReq j "roth401k_contributions",
      roth403bContributions := ← moneyReq j "roth403b_contributions",
      healthCoverageCost := ← moneyReq j "health_coverage_cost",
      roth457bContributions := ← moneyReq j "roth457b_contributions",
      qsehraBenefits := ← moneyReq j "qsehra_benefits",
      income83i := ← moneyReq j "income_83i",
      deferrals83i := ← moneyReq j "deferrals_83i",
      nonTaxableMedicaidWaiverPayments := ← moneyReq j "non_taxable_medicaid_waiver_payments",
      plan457bIsGovernmental := ← boolReq j "plan_457b_is_governmental",
      statutoryEmployee := ← boolReq j "statutory_employee",
      thirdPartySickPay := ← boolReq j "third_party_sick_pay"
  }

/-- Catala `Interest.InterestReport`. -/
def interestReportOfJson (j : Json) : Except String Interest.InterestReport :=
  return {
      filer := ← filerRoleOfJson (← field j "filer"),
      has1099 := ← boolReq j "has_1099",
      no1099Amount := ← moneyReq j "no_1099_amount",
      writable1099Amount := ← moneyReq j "writable_1099_amount",
      writableEarlyWithdrawlPenaltyAmount := ← moneyReq j "writable_early_withdrawl_penalty_amount",
      writableInterestOnGovernmentBonds := ← moneyReq j "writable_interest_on_government_bonds",
      writableTaxWithheld := ← moneyReq j "writable_tax_withheld",
      writableForeignTaxPaid := ← moneyReq j "writable_foreign_tax_paid",
      writableTaxExemptInterest := ← moneyReq j "writable_tax_exempt_interest",
      writableSpecifiedPrivateActivityBondInterest := ← moneyReq j "writable_specified_private_activity_bond_interest",
      writableMarketDiscount := ← moneyReq j "writable_market_discount",
      writableBondPremium := ← moneyReq j "writable_bond_premium",
      writableBondPremiumOnTreasuryObligations := ← moneyReq j "writable_bond_premium_on_treasury_obligations",
      writableBondPremiumOnTaxExemptBond := ← moneyReq j "writable_bond_premium_on_tax_exempt_bond",
      stateIsDifferentState := ← boolReq j "state_is_different_state",
      writableStateTaxWithheld := ← moneyReq j "writable_state_tax_withheld",
      factaFilingRequired := ← boolReq j "facta_filing_required"
  }

/-- Catala scope `Standard_deduction.Age65DayBeforeBirthday`. -/
def runAge65 (j : Json) : Except String Json := do
  let o := StandardDeduction.age65DayBeforeBirthday
    { dateOfBirth := ← dateOfJson (← field j "date_of_birth"),
      asOf := ← dateOfJson (← field j "as_of") }
  return Json.mkObj [("age", toJson o.age), ("is_65_or_older", Json.bool o.is65OrOlder)]

/-- The inputs of `StandardDeduction` from Catala JSON. -/
def standardDeductionInOfJson (j : Json) : Except String StandardDeduction.StandardDeductionIn :=
  return {
    filingStatus := ← filingStatusOfJson (← field j "filing_status"),
    treatAsMfs := ← boolReq j "treat_as_mfs",
    primaryFilerIsBlind := ← boolReq j "primary_filer_is_blind",
    primaryFilerAge65OrOlder := ← boolReq j "primary_filer_age65_or_older",
    secondaryFilerIsBlind := ← boolReq j "secondary_filer_is_blind",
    secondaryFilerAge65OrOlder := ← boolReq j "secondary_filer_age65_or_older",
    isWidowedInTaxYear := ← boolReq j "is_widowed_in_tax_year",
    mfjDeceasedSpouseReachedAge65 := ← boolReq j "mfj_deceased_spouse_reached_age65",
    mfsSpouse65OrOlder := ← boolReq j "mfs_spouse_65_or_older",
    mfsSpouseProvidesNoBenefits := ← boolReq j "mfs_spouse_provides_no_benefits",
    treatFilersAsDependents := ← boolReq j "treat_filers_as_dependents",
    employerIncomeSubtotal := ← moneyReq j "employer_income_subtotal" }

/-- Catala scope `Standard_deduction.StandardDeduction`. -/
def runStandardDeduction (j : Json) : Except String Json := do
  let o := StandardDeduction.standardDeduction (← standardDeductionInOfJson j)
  return Json.mkObj [
    ("is_spouse_info_applicable_for_standard_deductions", Json.bool o.isSpouseInfoApplicableForStandardDeductions),
    ("is_spouse_65_or_older", Json.bool o.isSpouse65OrOlder),
    ("additional_standard_deduction_items", toJson o.additionalStandardDeductionItems),
    ("standard_deduction", Json.str (showMoney o.standardDeduction))
  ]

/-- Catala scope `Form_w2s.FormW2s`. -/
def runFormW2s (j : Json) : Except String Json := do
  let o := FormW2s.formW2s
    { w2s := ← listReq j "w2s" w2OfJson,
      filingStatus := ← filingStatusOfJson (← field j "filing_status"),
      primaryFilerCanBeClaimed := ← boolReq j "primary_filer_can_be_claimed",
      secondaryFilerCanBeClaimed := ← boolReq j "secondary_filer_can_be_claimed",
      combatPayElection := ← combatPayElectionOfJson (← field j "combat_pay_election") }
  return Json.mkObj [
    ("wages", Json.str (showMoney o.wages)),
    ("form_w2_withholding", Json.str (showMoney o.formW2Withholding)),
    ("social_security_taxes_withheld", Json.str (showMoney o.socialSecurityTaxesWithheld)),
    ("primary_filer_wages", Json.str (showMoney o.primaryFilerWages)),
    ("secondary_filer_wages", Json.str (showMoney o.secondaryFilerWages)),
    ("primary_filer_has_w2_wages_greater_than_0", Json.bool o.primaryFilerHasW2WagesGreaterThan0),
    ("secondary_filer_has_w2_wages_greater_than_0", Json.bool o.secondaryFilerHasW2WagesGreaterThan0),
    ("primary_filer_dependent_care_benefits", Json.str (showMoney o.primaryFilerDependentCareBenefits)),
    ("secondary_filer_dependent_care_benefits", Json.str (showMoney o.secondaryFilerDependentCareBenefits)),
    ("primary_filer_total_deferrals_and_contributions", Json.str (showMoney o.primaryFilerTotalDeferralsAndContributions)),
    ("secondary_filer_total_deferrals_and_contributions", Json.str (showMoney o.secondaryFilerTotalDeferralsAndContributions)),
    ("primary_filer_total_hsa_contributions_from_w2s", Json.str (showMoney o.primaryFilerTotalHsaContributionsFromW2s)),
    ("secondary_filer_total_hsa_contributions_from_w2s", Json.str (showMoney o.secondaryFilerTotalHsaContributionsFromW2s)),
    ("has_primary_filer_hsa_contributions_from_w2s", Json.bool o.hasPrimaryFilerHsaContributionsFromW2s),
    ("has_secondary_filer_hsa_contributions_from_w2s", Json.bool o.hasSecondaryFilerHsaContributionsFromW2s),
    ("total_hsa_contributions_on_w2s", Json.str (showMoney o.totalHsaContributionsOnW2s)),
    ("has_hsa_contributions_on_w2", Json.bool o.hasHsaContributionsOnW2),
    ("primary_filer_combat_pay", Json.str (showMoney o.primaryFilerCombatPay)),
    ("mfj_spouse_combat_pay", Json.str (showMoney o.mfjSpouseCombatPay)),
    ("primary_filer_has_combat_pay", Json.bool o.primaryFilerHasCombatPay),
    ("mfj_spouse_has_combat_pay", Json.bool o.mfjSpouseHasCombatPay),
    ("some_filer_has_combat_pay", Json.bool o.someFilerHasCombatPay),
    ("only_one_filer_has_combat_pay", Json.bool o.onlyOneFilerHasCombatPay),
    ("only_primary_filer_has_combat_pay", Json.bool o.onlyPrimaryFilerHasCombatPay),
    ("only_mfj_spouse_has_combat_pay", Json.bool o.onlyMfjSpouseHasCombatPay),
    ("both_filers_has_combat_pay", Json.bool o.bothFilersHasCombatPay),
    ("both_filers_combat_pay", Json.str (showMoney o.bothFilersCombatPay)),
    ("combat_pay_amount", Json.str (showMoney o.combatPayAmount)),
    ("all_combat_pay", Json.str (showMoney o.allCombatPay)),
    ("form_w2_total_medicare_wages", Json.str (showMoney o.formW2TotalMedicareWages)),
    ("primary_filer_medicare_wages", Json.str (showMoney o.primaryFilerMedicareWages)),
    ("secondary_filer_medicare_wages", Json.str (showMoney o.secondaryFilerMedicareWages)),
    ("max_medicare_wages_for_any_filer_on_return", Json.str (showMoney o.maxMedicareWagesForAnyFilerOnReturn)),
    ("medicare_wages_additional_tax_threshold", Json.str (showMoney o.medicareWagesAdditionalTaxThreshold)),
    ("any_filer_exceeds_eligible_for_medicare_wages_credit", Json.bool o.anyFilerExceedsEligibleForMedicareWagesCredit),
    ("any_filer_required_to_pay_extra_medicare_tax", Json.bool o.anyFilerRequiredToPayExtraMedicareTax),
    ("primary_filer_w2s_count", toJson o.primaryFilerW2sCount),
    ("secondary_filer_w2s_count", toJson o.secondaryFilerW2sCount),
    ("primary_filer_total_oasdi_wages_for_knockout", Json.str (showMoney o.primaryFilerTotalOasdiWagesForKnockout)),
    ("secondary_filer_total_oasdi_wages_for_knockout", Json.str (showMoney o.secondaryFilerTotalOasdiWagesForKnockout)),
    ("primary_filer_exceeds_max_oasdi_wages", Json.bool o.primaryFilerExceedsMaxOasdiWages),
    ("secondary_filer_exceeds_max_oasdi_wages", Json.bool o.secondaryFilerExceedsMaxOasdiWages),
    ("ko_flow_knockout_allocated_tips", Json.bool o.koFlowKnockoutAllocatedTips),
    ("ko_flow_knockout_statutory_employee", Json.bool o.koFlowKnockoutStatutoryEmployee),
    ("ko_flow_knockout_third_party_sick_pay", Json.bool o.koFlowKnockoutThirdPartySickPay),
    ("ko_flow_knockout_non_qualified_plans", Json.bool o.koFlowKnockoutNonQualifiedPlans),
    ("ko_knockout_for_box12_value", Json.bool o.koKnockoutForBox12Value),
    ("ko_knockout_for_box12_dependency", Json.bool o.koKnockoutForBox12Dependency),
    ("ko_knockout_medicare_wages", Json.bool o.koKnockoutMedicareWages),
    ("ko_any_filer_exceeds_max_oasdi_wages", Json.bool o.koAnyFilerExceedsMaxOasdiWages),
    ("unsupported", Json.bool o.unsupported)
  ]

/-- Catala scope `Interest.Interest`. -/
def runInterest (j : Json) : Except String Json := do
  let o := Interest.interest
    { interestReports := ← listReq j "interest_reports" interestReportOfJson,
      hasForeignAccountsOrTrusts := ← boolReq j "has_foreign_accounts_or_trusts",
      filingStatus := ← filingStatusOfJson (← field j "filing_status"),
      agi := ← moneyReq j "agi",
      flowHasSeenDeductions := ← boolReq j "flow_has_seen_deductions" }
  return Json.mkObj [
    ("requires_schedule_b", Json.bool o.requiresScheduleB),
    ("interest_income", Json.str (showMoney o.interestIncome)),
    ("tax_exempt_interest", Json.str (showMoney o.taxExemptInterest)),
    ("total_tax_withheld", Json.str (showMoney o.totalTaxWithheld)),
    ("has_interest_income", Json.bool o.hasInterestIncome),
    ("ko_flow_knockout_has_early_withdrawl_penalty", Json.bool o.koFlowKnockoutHasEarlyWithdrawlPenalty),
    ("ko_flow_knockout_has_bonds", Json.bool o.koFlowKnockoutHasBonds),
    ("ko_flow_knockout_has_foreign_tax_paid", Json.bool o.koFlowKnockoutHasForeignTaxPaid),
    ("ko_flow_knockout_tax_exempt_interest", Json.bool o.koFlowKnockoutTaxExemptInterest),
    ("ko_flow_knockout_state_tax_withheld", Json.bool o.koFlowKnockoutStateTaxWithheld),
    ("ko_flow_knockout_withholding_unsupported_state", Json.bool o.koFlowKnockoutWithholdingUnsupportedState),
    ("ko_has_required_facta_filings", Json.bool o.koHasRequiredFactaFilings),
    ("ko_has_interest_income_and_agi_above_threshold_for_mfs", Json.bool o.koHasInterestIncomeAndAgiAboveThresholdForMfs),
    ("ko_has_interest_income_and_agi_above_threshold_for_mfj_or_qss", Json.bool o.koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss),
    ("ko_has_interest_income_and_agi_above_threshold_for_single_or_hoh", Json.bool o.koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh),
    ("unsupported", Json.bool o.unsupported)
  ]

/-- Catala scope `Form_1040.Form1040`. The plug-in slots (Catala `context`
variables) are optional and default to `$0` / `false`. -/
def runForm1040 (j : Json) : Except String Json := do
  let o := Form1040.form1040
    { filingStatus := ← filingStatusOfJson (← field j "filing_status"),
      w2s := ← listReq j "w2s" w2OfJson,
      interestReports := ← listReq j "interest_reports" interestReportOfJson,
      hasForeignAccountsOrTrusts := ← boolReq j "has_foreign_accounts_or_trusts",
      combatPayElection := ← combatPayElectionOfJson (← field j "combat_pay_election"),
      primaryFilerCanBeClaimed := ← boolReq j "primary_filer_can_be_claimed",
      secondaryFilerCanBeClaimed := ← boolReq j "secondary_filer_can_be_claimed",
      treatAsMfs := ← boolReq j "treat_as_mfs",
      primaryFilerIsBlind := ← boolReq j "primary_filer_is_blind",
      primaryFilerAge65OrOlder := ← boolReq j "primary_filer_age65_or_older",
      secondaryFilerIsBlind := ← boolReq j "secondary_filer_is_blind",
      secondaryFilerAge65OrOlder := ← boolReq j "secondary_filer_age65_or_older",
      isWidowedInTaxYear := ← boolReq j "is_widowed_in_tax_year",
      mfjDeceasedSpouseReachedAge65 := ← boolReq j "mfj_deceased_spouse_reached_age65",
      mfsSpouse65OrOlder := ← boolReq j "mfs_spouse_65_or_older",
      mfsSpouseProvidesNoBenefits := ← boolReq j "mfs_spouse_provides_no_benefits",
      treatFilersAsDependents := ← boolReq j "treat_filers_as_dependents",
      taxableDependentCare := ← moneyOpt j "taxable_dependent_care",
      taxablePensionsAndAnnuities := ← moneyOpt j "taxable_pensions_and_annuities",
      taxableSocialSecurityBenefits := ← moneyOpt j "taxable_social_security_benefits",
      unemploymentCompensation := ← moneyOpt j "unemployment_compensation",
      alaskaPfdIncome := ← moneyOpt j "alaska_pfd_income",
      studentLoanInterestAdjustmentAmount := ← moneyOpt j "student_loan_interest_adjustment_amount",
      educatorExpensesAdjustment := ← moneyOpt j "educator_expenses_adjustment",
      hsaTotalDeductibleAmount := ← moneyOpt j "hsa_total_deductible_amount",
      totalAdditionalTaxesOwed := ← moneyOpt j "total_additional_taxes_owed",
      totalCtcAndOdc := ← moneyOpt j "total_ctc_and_odc",
      line8OfSchedule3 := ← moneyOpt j "line8_of_schedule3",
      other1099Withholding := ← moneyOpt j "other_1099_withholding",
      paidEstimatedTaxesOrFromLastYear := ← boolOpt j "paid_estimated_taxes_or_from_last_year",
      estimatedAndFromLastYear := ← moneyOpt j "estimated_and_from_last_year",
      earnedIncomeCredit := ← moneyOpt j "earned_income_credit",
      additionalCtc := ← moneyOpt j "additional_ctc",
      otherPaymentsAndRefundableCreditsTotal :=
        ← moneyOpt j "other_payments_and_refundable_credits_total" }
  return Json.mkObj [
    ("wages", Json.str (showMoney o.wages)),
    ("employer_income_subtotal", Json.str (showMoney o.employerIncomeSubtotal)),
    ("interest_income", Json.str (showMoney o.interestIncome)),
    ("schedule1_total_other_income", Json.str (showMoney o.schedule1TotalOtherIncome)),
    ("other_income", Json.str (showMoney o.otherIncome)),
    ("total_income", Json.str (showMoney o.totalIncome)),
    ("adjustments_to_income", Json.str (showMoney o.adjustmentsToIncome)),
    ("agi", Json.str (showMoney o.agi)),
    ("standard_or_itemized_deductions", Json.str (showMoney o.standardOrItemizedDeductions)),
    ("qualified_business_income_deduction", Json.str (showMoney o.qualifiedBusinessIncomeDeduction)),
    ("total_deductions", Json.str (showMoney o.totalDeductions)),
    ("taxable_income", Json.str (showMoney o.taxableIncome)),
    ("tentative_tax_from_taxable_income", Json.str (showMoney o.tentativeTaxFromTaxableIncome)),
    ("total_tentative_tax", Json.str (showMoney o.totalTentativeTax)),
    ("non_refundable_credits", Json.str (showMoney o.nonRefundableCredits)),
    ("tax_less_non_refundable_credits", Json.str (showMoney o.taxLessNonRefundableCredits)),
    ("line21_of_schedule2", Json.str (showMoney o.line21OfSchedule2)),
    ("total_tax", Json.str (showMoney o.totalTax)),
    ("form_w2_withholding", Json.str (showMoney o.formW2Withholding)),
    ("form_1099_withholding", Json.str (showMoney o.form1099Withholding)),
    ("other_form_withholding", Json.str (showMoney o.otherFormWithholding)),
    ("total_withholding", Json.str (showMoney o.totalWithholding)),
    ("american_opportunity_credit", Json.str (showMoney o.americanOpportunityCredit)),
    ("total_other_payments_refundable_credits", Json.str (showMoney o.totalOtherPaymentsRefundableCredits)),
    ("total_payments", Json.str (showMoney o.totalPayments)),
    ("overpayment", Json.str (showMoney o.overpayment)),
    ("balance_due", Json.str (showMoney o.balanceDue)),
    ("ko_knockout_has_no_payments_or_credits", Json.bool o.koKnockoutHasNoPaymentsOrCredits),
    ("unsupported", Json.bool o.unsupported)
  ]

/-! ### Decoding and encoding the income and adjustment modules (issue #45) -/

/-- A money output value. -/
private def mj (c : Int) : Json := Json.str (showMoney c)

/-- Catala `Unemployment.Form1099G`. -/
def form1099GOfJson (j : Json) : Except String Unemployment.Form1099G :=
  return {
    filer := ← filerRoleOfJson (← field j "filer"),
    amount := ← moneyReq j "amount",
    writableAmountPaidBackForBenefitsInTaxYear :=
      ← moneyReq j "writable_amount_paid_back_for_benefits_in_tax_year",
    writableAmountPaidBackForBenefitsBeforeTaxYear :=
      ← moneyReq j "writable_amount_paid_back_for_benefits_before_tax_year",
    writableFederalTaxWithheld := ← moneyReq j "writable_federal_tax_withheld",
    stateIsDifferentState := ← boolReq j "state_is_different_state" }

/-- Catala scope `Unemployment.Unemployment`. -/
def runUnemployment (j : Json) : Except String Json := do
  let o := Unemployment.unemployment { form1099Gs := ← listReq j "form_1099gs" form1099GOfJson }
  return Json.mkObj [
    ("unemployment_compensation", mj o.unemploymentCompensation),
    ("unemployment_comp_repaid_amt", mj o.unemploymentCompRepaidAmt),
    ("received_unemployment_compensation", Json.bool o.receivedUnemploymentCompensation),
    ("has_repaid_unemployment_compensation", Json.bool o.hasRepaidUnemploymentCompensation),
    ("total_amount_paid_back_for_benefits_before_tax_year",
      mj o.totalAmountPaidBackForBenefitsBeforeTaxYear),
    ("form_1099g_federal_tax_withheld", mj o.form1099gFederalTaxWithheld),
    ("ko_flow_knockout1099_g_repay_too_high", Json.bool o.koFlowKnockout1099GRepayTooHigh),
    ("ko_flow_knockout_unemployment_compensation_unsupported_state",
      Json.bool o.koFlowKnockoutUnemploymentCompensationUnsupportedState),
    ("unsupported", Json.bool o.unsupported)]

/-- Catala `Form1099_misc.Form1099Misc`. -/
def form1099MiscOfJson (j : Json) : Except String Form1099Misc.Form1099Misc :=
  return {
    filer := ← filerRoleOfJson (← field j "filer"),
    isAlaskaPfd := ← boolReq j "is_alaska_pfd",
    writableOtherIncome := ← moneyReq j "writable_other_income",
    writableFederalWithholding := ← moneyReq j "writable_federal_withholding" }

/-- Catala scope `Form1099_misc.Form1099Miscs`. -/
def runForm1099Miscs (j : Json) : Except String Json := do
  let o := Form1099Misc.form1099Miscs
    { form1099Miscs := ← listReq j "form_1099miscs" form1099MiscOfJson }
  return Json.mkObj [
    ("alaska_pfd_income", mj o.alaskaPfdIncome),
    ("has_alaska_pfd_income", Json.bool o.hasAlaskaPfdIncome),
    ("has_1099_misc", Json.bool o.has1099Misc),
    ("form_1099_misc_federal_income_tax_withheld", mj o.form1099MiscFederalIncomeTaxWithheld),
    ("ko_non_pfd_1099_misc", Json.bool o.koNonPfd1099Misc),
    ("unsupported", Json.bool o.unsupported)]

/-- A `Form1099_rs.CodeChar` from its Catala case name. -/
def codeCharOfJson (j : Json) : Except String Form1099Rs.CodeChar := do
  let s ← j.getStr?
  match Form1099Rs.CodeChar.ofString? s with
  | some c => .ok c
  | none => .error s!"bad code char {s.quote}"

/-- Catala `Form1099_rs.Form1099R`. -/
def form1099ROfJson (j : Json) : Except String Form1099Rs.Form1099R :=
  return {
    filer := ← filerRoleOfJson (← field j "filer"),
    distributionCode := ← listReq j "distribution_code" codeCharOfJson,
    writableGrossDistribution := ← moneyReq j "writable_gross_distribution",
    writableTaxableAmount := ← moneyReq j "writable_taxable_amount",
    taxableAmountBlank := ← boolReq j "taxable_amount_blank",
    taxableAmountNotDetermined := ← boolReq j "taxable_amount_not_determined",
    totalDistribution := ← boolReq j "total_distribution",
    writableCapitalGain := ← moneyReq j "writable_capital_gain",
    writableFederalWithholding := ← moneyReq j "writable_federal_withholding",
    writableNetAppreciation := ← moneyReq j "writable_net_appreciation",
    iraSepSimple := ← boolReq j "ira_sep_simple",
    writableOtherDollar := ← moneyReq j "writable_other_dollar",
    otherPercentageNonzero := ← boolReq j "other_percentage_nonzero",
    percentageTotalDistributionNonzero := ← boolReq j "percentage_total_distribution_nonzero",
    writableAmountAllocableToIrr := ← moneyReq j "writable_amount_allocable_to_irr",
    factaFilingRequirement := ← boolReq j "facta_filing_requirement",
    writableStateTaxWithheld := ← moneyReq j "writable_state_tax_withheld",
    payerStateIsDifferent := ← boolReq j "payer_state_is_different",
    hasDeathBenefitPaymentDate := ← boolReq j "has_death_benefit_payment_date",
    writableIsIndirectRollover := ← boolReq j "writable_is_indirect_rollover",
    writableIsDistributionFromMilitaryRetirementPlan :=
      ← boolReq j "writable_is_distribution_from_military_retirement_plan",
    writableQualifiedDisasterDistribution := ← boolReq j "writable_qualified_disaster_distribution",
    writeablePublicSafetyOfficer := ← boolReq j "writeable_public_safety_officer",
    writeablePublicSafetyOfficerPremiums := ← boolReq j "writeable_public_safety_officer_premiums",
    recipientDateOfBirth := ← dateOfJson (← field j "recipient_date_of_birth") }

/-- Catala scope `Form1099_rs.Form1099Rs`. -/
def runForm1099Rs (j : Json) : Except String Json := do
  let o := Form1099Rs.form1099Rs { forms := ← listReq j "forms" form1099ROfJson }
  return Json.mkObj [
    ("tax_free_pension_rollovers", mj o.taxFreePensionRollovers),
    ("partly_taxable_pensions", mj o.partlyTaxablePensions),
    ("fully_taxable_pensions", mj o.fullyTaxablePensions),
    ("taxable_amounts_of_partially_taxable_pensions", mj o.taxableAmountsOfPartiallyTaxablePensions),
    ("line_5a", mj o.line5a),
    ("line_5b", mj o.line5b),
    ("line_5b_is_blank", Json.bool o.line5bIsBlank),
    ("has_direct_rollover", Json.bool o.hasDirectRollover),
    ("non_taxable_pensions_and_annuities", mj o.nonTaxablePensionsAndAnnuities),
    ("form_1099r_federal_income_tax_withheld", mj o.form1099rFederalIncomeTaxWithheld),
    ("primary_filer_savers_gross_distributions", mj o.primaryFilerSaversGrossDistributions),
    ("secondary_filer_savers_gross_distributions", mj o.secondaryFilerSaversGrossDistributions),
    ("ko_knockout_for_form1099_r_distribution_code", Json.bool o.koKnockoutForForm1099RDistributionCode),
    ("ko_knockout_ira_sep_simple", Json.bool o.koKnockoutIraSepSimple),
    ("ko_knockout_taxable_pension_rollover", Json.bool o.koKnockoutTaxablePensionRollover),
    ("ko_knockout_indirect_rollover", Json.bool o.koKnockoutIndirectRollover),
    ("ko_knockout_taxable_amount_not_determined", Json.bool o.koKnockoutTaxableAmountNotDetermined),
    ("ko_flow_knockout_for_rollover", Json.bool o.koFlowKnockoutForRollover),
    ("ko_flow_knockout_for_pre_tax_to_post_tax_rollover", Json.bool o.koFlowKnockoutForPreTaxToPostTaxRollover),
    ("ko_flow_knockout_retirement_taxable_amount_not_determined",
      Json.bool o.koFlowKnockoutRetirementTaxableAmountNotDetermined),
    ("ko_flow_knockout_retirement_taxable_amount_blank", Json.bool o.koFlowKnockoutRetirementTaxableAmountBlank),
    ("ko_flow_knockout_retirement_total_distribution", Json.bool o.koFlowKnockoutRetirementTotalDistribution),
    ("ko_knockout_for_form1099_r_box8_value", Json.bool o.koKnockoutForForm1099RBox8Value),
    ("ko_knockout_for_form1099_r_box8_percentage", Json.bool o.koKnockoutForForm1099RBox8Percentage),
    ("ko_knockout_for_form1099_r_box9a_percentage", Json.bool o.koKnockoutForForm1099RBox9aPercentage),
    ("ko_flow_knockout_retirement_capital_gain", Json.bool o.koFlowKnockoutRetirementCapitalGain),
    ("ko_flow_knockout_retirement_net_unrealized_appreciation",
      Json.bool o.koFlowKnockoutRetirementNetUnrealizedAppreciation),
    ("ko_flow_knockout_retirement_amount_allocable_to_irr",
      Json.bool o.koFlowKnockoutRetirementAmountAllocableToIrr),
    ("ko_flow_knockout_retirement_facta_filing_requirement",
      Json.bool o.koFlowKnockoutRetirementFactaFilingRequirement),
    ("ko_flow_knockout_for_death_benefit_payment_date", Json.bool o.koFlowKnockoutForDeathBenefitPaymentDate),
    ("ko_flow_knockout_retirement_qualified_disaster_distribution",
      Json.bool o.koFlowKnockoutRetirementQualifiedDisasterDistribution),
    ("ko_flow_knockout_retirement_public_safety_officer",
      Json.bool o.koFlowKnockoutRetirementPublicSafetyOfficer),
    ("ko_flow_knockout_box15", Json.bool o.koFlowKnockoutBox15),
    ("unsupported", Json.bool o.unsupported)]

/-- Catala scope `Social_security.SocialSecurity`. -/
def runSocialSecurity (j : Json) : Except String Json := do
  let o := SocialSecurity.socialSecurity
    { reportNetBenefits := ← listReq j "report_net_benefits" moneyOfJson,
      filingStatus := ← filingStatusOfJson (← field j "filing_status"),
      livedApartAllYear := ← boolReq j "lived_apart_all_year",
      line1z := ← moneyReq j "line_1z",
      line2b := ← moneyReq j "line_2b",
      line2a := ← moneyReq j "line_2a",
      line3b := ← moneyReq j "line_3b",
      line4b := ← moneyReq j "line_4b",
      line5b := ← moneyReq j "line_5b",
      line7CapitalGains := ← moneyReq j "line_7_capital_gains",
      line8OtherIncome := ← moneyReq j "line_8_other_income",
      adjustmentsExcludingStudentLoanInterest :=
        ← moneyReq j "adjustments_excluding_student_loan_interest" }
  return Json.mkObj [
    ("line_6a", mj o.line6a),
    ("wksht_line_3", mj o.wkshtLine3),
    ("wksht_line_7", mj o.wkshtLine7),
    ("wksht_line_8", mj o.wkshtLine8),
    ("wksht_line_9", mj o.wkshtLine9),
    ("wksht_line_10", mj o.wkshtLine10),
    ("wksht_line_11", mj o.wkshtLine11),
    ("wksht_line_16", mj o.wkshtLine16),
    ("line_6b", mj o.line6b),
    ("non_taxable_benefits", mj o.nonTaxableBenefits),
    ("has_benefits", Json.bool o.hasBenefits),
    ("benefit_code_d", Json.bool o.benefitCodeD),
    ("repayment_over_3k", Json.bool o.repaymentOver3k)]

/-- Catala scope `Educator_adjustment.EducatorAdjustment`. -/
def runEducatorAdjustment (j : Json) : Except String Json := do
  let s ← (← field j "was_k12_educators").getStr?
  let opt ← match EducatorAdjustment.K12EducatorOptions.ofString? s with
    | some o => pure o
    | none => throw s!"bad K12 educator option {s.quote}"
  let o := EducatorAdjustment.educatorAdjustment
    { wasK12Educators := opt,
      primaryEducatorExpensesWritable := ← moneyReq j "primary_educator_expenses_writable",
      secondaryEducatorExpensesWritable := ← moneyReq j "secondary_educator_expenses_writable",
      isMfjDependent := ← boolReq j "is_mfj_dependent" }
  return Json.mkObj [
    ("tp_was_k12_educator", Json.bool o.tpWasK12Educator),
    ("spouse_was_k12_educator", Json.bool o.spouseWasK12Educator),
    ("primary_educator_expenses", mj o.primaryEducatorExpenses),
    ("secondary_educator_expenses", mj o.secondaryEducatorExpenses),
    ("educator_expenses_adjustment", mj o.educatorExpensesAdjustment),
    ("is_receiving_educator_expenses_adjustment", Json.bool o.isReceivingEducatorExpensesAdjustment)]

/-- Catala scope `Student_loan_adjustment.StudentLoanAdjustment`. -/
def runStudentLoanAdjustment (j : Json) : Except String Json := do
  let o := StudentLoanAdjustment.studentLoanAdjustment
    { filingStatus := ← filingStatusOfJson (← field j "filing_status"),
      hadStudentLoanInterestPayments := ← boolReq j "had_student_loan_interest_payments",
      studentLoansQualify := ← boolReq j "student_loans_qualify",
      studentLoanInterestAmount := ← moneyReq j "student_loan_interest_amount",
      isMfjDependent := ← boolReq j "is_mfj_dependent",
      eitherFilerIsClaimedAsDependent := ← boolReq j "either_filer_is_claimed_as_dependent",
      totalIncome := ← moneyReq j "total_income",
      adjustmentsToIncomeExcludingStudentLoanInterest :=
        ← moneyReq j "adjustments_to_income_excluding_student_loan_interest" }
  return Json.mkObj [
    ("magi_for_student_loan_interest_deduction", mj o.magiForStudentLoanInterestDeduction),
    ("income_too_high_not_mfj", Json.bool o.incomeTooHighNotMfj),
    ("income_too_high_mfj", Json.bool o.incomeTooHighMfj),
    ("cannot_deduct_because_income_or_filing_status", Json.bool o.cannotDeductBecauseIncomeOrFilingStatus),
    ("cannot_deduct_because_dependents", Json.bool o.cannotDeductBecauseDependents),
    ("cannot_deduct_because_loans_dont_qualify", Json.bool o.cannotDeductBecauseLoansDontQualify),
    ("cannot_deduct_student_loan_interest", Json.bool o.cannotDeductStudentLoanInterest),
    ("student_loan_amount_phase_out_amount", mj o.studentLoanAmountPhaseOutAmount),
    ("student_loan_interest_adjustment_amount", mj o.studentLoanInterestAdjustmentAmount),
    ("is_receiving_student_loan_interest_adjustment", Json.bool o.isReceivingStudentLoanInterestAdjustment)]

/-- Catala scope `Estimated_payments.EstimatedPayments`. -/
def runEstimatedPayments (j : Json) : Except String Json := do
  let s ← (← field j "paid_estimated_taxes_with_former_spouse").getStr?
  let former ← match EstimatedPayments.PaidWithFormerSpouse.ofString? s with
    | some o => pure o
    | none => throw s!"bad former spouse option {s.quote}"
  let o := EstimatedPayments.estimatedPayments
    { paidEstimatedTaxesOrFromLastYear := ← boolReq j "paid_estimated_taxes_or_from_last_year",
      estimatedTaxPaymentWritable := ← moneyReq j "estimated_tax_payment_writable",
      paidEstimatedTaxesOrFromLastYearUnderDifferentName :=
        ← boolReq j "paid_estimated_taxes_or_from_last_year_under_different_name",
      paidEstimatedTaxesWithFormerSpouse := former }
  return Json.mkObj [
    ("estimated_and_from_last_year", mj o.estimatedAndFromLastYear),
    ("spouse_paid_estimated_taxes_with_former_spouse", Json.bool o.spousePaidEstimatedTaxesWithFormerSpouse),
    ("tp_paid_estimated_taxes_with_former_spouse", Json.bool o.tpPaidEstimatedTaxesWithFormerSpouse),
    ("some_tp_paid_estimated_taxes_with_former_spouse", Json.bool o.someTpPaidEstimatedTaxesWithFormerSpouse),
    ("ko_knockout_paid_estimated_taxes_under_different_last_name",
      Json.bool o.koKnockoutPaidEstimatedTaxesUnderDifferentLastName),
    ("unsupported", Json.bool o.unsupported)]

/-- The scopes implemented in Lean, by Catala scope name. Add one line per
new module. -/
def scopes : List (String × (Json → Except String Json)) :=
  [("TentativeTax", runTentativeTax),
   ("Age65DayBeforeBirthday", runAge65),
   ("StandardDeduction", runStandardDeduction),
   ("FormW2s", runFormW2s),
   ("Interest", runInterest),
   ("Form1040", runForm1040),
   ("Unemployment", runUnemployment),
   ("Form1099Miscs", runForm1099Miscs),
   ("Form1099Rs", runForm1099Rs),
   ("SocialSecurity", runSocialSecurity),
   ("EducatorAdjustment", runEducatorAdjustment),
   ("StudentLoanAdjustment", runStudentLoanAdjustment),
   ("EstimatedPayments", runEstimatedPayments)]

/-- Run scope `name` on one JSON input. -/
def runScope (name : String) (input : Json) : Except String Json :=
  match scopes.lookup name with
  | some f => f input
  | none => .error s!"unknown scope {name}; known: {scopes.map (·.1)}"

#guard parseMoney "14999" == some 1499900
#guard parseMoney "123,456.78" == some 12345678
#guard parseMoney "-$3.5" == some (-350)
#guard parseMoney "0.01" == some 1
#guard parseMoney "1.234" == none
#guard parseMoney "abc" == none
#guard parseMoney "" == none
#guard showMoney 156500 == "1565.00"
#guard showMoney (-350) == "-3.50"
#guard showMoney 7 == "0.07"
#guard (do moneyOfJson (← Json.parse "123456.78")).toOption == some 12345678
#guard (do moneyOfJson (← Json.parse "-3.5")).toOption == some (-350)
#guard (do moneyOfJson (← Json.parse "1e3")).toOption == some 100000
#guard ((do moneyOfJson (← Json.parse "0.125")) matches .error _)
#guard (do let o ← runScope "TentativeTax" (← Json.parse
    "{\"taxable_income\": \"14999\", \"filing_status\": \"Single\"}"); return o.compress).toOption ==
  some "{\"rounded_taxable_income\":\"14975.00\",\"tentative_tax_cumulative_form\":\"1565.00\",\"tentative_tax_from_taxable_income\":\"1565.00\"}"

-- The spine scopes through the JSON driver (the same JSON shapes `clerk run` takes).
/-- Output `k` of scope `name` on the JSON text `input`, for the tests below. -/
private def runOut (name input k : String) : Option Json :=
  (do let o ← runScope name (← Json.parse input); o.getObjVal? k).toOption

#guard runOut "Age65DayBeforeBirthday"
    "{\"date_of_birth\": \"1960-01-01\", \"as_of\": \"2024-12-31\"}" "age" == some 65
#guard runOut "Age65DayBeforeBirthday"
    "{\"date_of_birth\": \"1960-01-02\", \"as_of\": \"2024-12-31\"}" "is_65_or_older" ==
  some (Json.bool false)
#guard runOut "StandardDeduction"
    ("{\"filing_status\": \"Single\", \"treat_as_mfs\": false, \"primary_filer_is_blind\": false," ++
     "\"primary_filer_age65_or_older\": true, \"secondary_filer_is_blind\": false," ++
     "\"secondary_filer_age65_or_older\": false, \"is_widowed_in_tax_year\": false," ++
     "\"mfj_deceased_spouse_reached_age65\": false, \"mfs_spouse_65_or_older\": false," ++
     "\"mfs_spouse_provides_no_benefits\": false, \"treat_filers_as_dependents\": false," ++
     "\"employer_income_subtotal\": 0}") "standard_deduction" == some (Json.str "16550.00")
#guard runOut "Interest"
    ("{\"interest_reports\": [], \"has_foreign_accounts_or_trusts\": false," ++
     "\"filing_status\": \"Single\", \"agi\": 0, \"flow_has_seen_deductions\": true}")
    "unsupported" == some (Json.bool false)
#guard runOut "FormW2s"
    ("{\"w2s\": [], \"filing_status\": \"Single\", \"primary_filer_can_be_claimed\": false," ++
     "\"secondary_filer_can_be_claimed\": false, \"combat_pay_election\": \"NoCombatPay\"}")
    "wages" == some (Json.str "0.00")
-- a missing required input is an error, not a default
#guard runOut "FormW2s" "{\"w2s\": []}" "wages" == none

end UsTax.Cli
