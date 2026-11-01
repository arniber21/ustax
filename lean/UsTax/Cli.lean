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
import UsTax.Cdcc
import UsTax.SaversCredit
import UsTax.ElderlyAndDisabled
import UsTax.Filers
import UsTax.QualifyingChild
import UsTax.DependentsBenefitSplit
import UsTax.QualifyingRelative
import UsTax.HohQssPersons
import UsTax.FilingStatus

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

/-! ### Household and filing status scopes (issue #44)

Decoders for the Catala JSON of the structs `FilerAnswers`, `Person`, `BenefitSplitAnswers`,
`DependentAnswers`, `Member` (three variants) and the six scopes the differential test runs.
Enumerations are Catala case names; dates are `"YYYY-MM-DD"`. -/

section Household

open Filers QualifyingChild DependentsBenefitSplit QualifyingRelative

/-- An enumeration field `k` decoded by `parse`. -/
def enumReq {α} (j : Json) (k : String) (what : String) (parse : String → Option α) :
    Except String α := do
  let s ← (← field j k).getStr?
  match parse s with
  | some v => .ok v
  | none => .error s!"bad {what} {s.quote}"

/-- Required date field `k`. -/
def dateReq (j : Json) (k : String) : Except String UsTax.Date := do dateOfJson (← field j k)

/-- Catala `Filers.FilerAnswers`. -/
def filerAnswersOfJson (j : Json) : Except String FilerAnswers :=
  return {
    dateOfBirth := ← dateReq j "date_of_birth", isBlind := ← boolReq j "is_blind"
    canBeClaimed := ← boolReq j "can_be_claimed", willBeClaimed := ← boolReq j "will_be_claimed"
    potentialClaimerMustFile := ← boolReq j "potential_claimer_must_file"
    potentialClaimerDidFile := ← boolReq j "potential_claimer_did_file"
    isUsCitizenFullYear := ← boolReq j "is_us_citizen_full_year"
    writableCitizenAtEndOfTaxYear := ← boolReq j "writable_citizen_at_end_of_tax_year"
    writableIsNoncitizenResidentFullYear := ← boolReq j "writable_is_noncitizen_resident_full_year"
    writableIsNational := ← boolReq j "writable_is_national" }

/-- The inputs of `Filers` (shared by `FilersStandardDeduction` and `FilingStatusReturn`);
`eligible_for_hoh` is `eh`. -/
def filersInOfJson (j : Json) (eh : Bool) : Except String FilersIn :=
  return {
    filingStatus := ← filingStatusOfJson (← field j "filing_status")
    maritalStatus := ← enumReq j "marital_status" "marital status" MaritalStatus.ofString?
    yearOfSpouseDeath := ← enumReq j "year_of_spouse_death" "year of spouse death"
      YearOfSpouseDeath.ofString?
    primaryFiler := ← filerAnswersOfJson (← field j "primary_filer")
    secondaryFiler := ← filerAnswersOfJson (← field j "secondary_filer")
    secondaryFilerDateOfDeath := ← dateReq j "secondary_filer_date_of_death"
    primaryFilerPotentialClaimerFiledOnlyForRefund :=
      ← boolReq j "primary_filer_potential_claimer_filed_only_for_refund"
    mfjRequiredToFile := ← boolReq j "mfj_required_to_file"
    mfjDependentsFilingForCredits := ← boolReq j "mfj_dependents_filing_for_credits"
    livedTogetherAllYearWithSpouse := ← boolReq j "lived_together_all_year_with_spouse"
    spouseLivedTogetherMonths := ← enumReq j "spouse_lived_together_months" "lived-together months"
      SpouseLivedTogetherMonths.ofString?
    writableLivedApartLastSixMonths := ← boolReq j "writable_lived_apart_last_six_months"
    writableSeparationAgreement := ← boolReq j "writable_separation_agreement"
    canFileJointlyYearOfSpouseDeath := ← boolReq j "can_file_jointly_year_of_spouse_death"
    inRegisteredDomesticPartnership := ← boolReq j "in_registered_domestic_partnership"
    filerResidenceAndIncomeState := ← enumReq j "filer_residence_and_income_state" "state"
      ScopedState.ofString?
    spouseItemizes := ← boolReq j "spouse_itemizes"
    mfsLivingSpouseFilingReturn := ← boolReq j "mfs_living_spouse_filing_return"
    mfsDeceasedSpouseFilingReturn := ← boolReq j "mfs_deceased_spouse_filing_return"
    mfsSpouseHasGrossIncome := ← boolReq j "mfs_spouse_has_gross_income"
    eligibleForHoh := eh }

/-- Catala `Qualifying_child.Person`. -/
def personOfJson (j : Json) : Except String Person :=
  return {
    relationship := ← enumReq j "relationship" "relationship" Relationship.ofString?
    dateOfBirth := ← dateReq j "date_of_birth"
    fullTimeStudent := ← boolReq j "full_time_student"
    permanentTotalDisability := ← boolReq j "permanent_total_disability"
    residencyDuration := ← enumReq j "residency_duration" "residency duration"
      ResidencyDuration.ofString?
    ownSupport := ← boolReq j "own_support", married := ← boolReq j "married"
    writableJointReturn := ← boolReq j "writable_joint_return"
    writableRequiredToFile := ← boolReq j "writable_required_to_file"
    writableFilingOnlyForRefund := ← boolReq j "writable_filing_only_for_refund"
    writableCouldBeQualifyingChildOfAnother :=
      ← boolReq j "writable_could_be_qualifying_child_of_another"
    writablePotentialClaimerMustFile := ← boolReq j "writable_potential_claimer_must_file"
    writablePotentialClaimerDidFile := ← boolReq j "writable_potential_claimer_did_file"
    writablePotentialClaimerFiledOnlyForRefund :=
      ← boolReq j "writable_potential_claimer_filed_only_for_refund" }

/-- Catala `Dependents_benefit_split.BenefitSplitAnswers`. -/
def benefitSplitAnswersOfJson (j : Json) : Except String BenefitSplitAnswers :=
  return {
    hasOtherBiologicalOrAdoptiveParent := ← boolReq j "has_other_biological_or_adoptive_parent"
    nonParentalSomeParentNotClaiming := ← boolReq j "non_parental_some_parent_not_claiming"
    whichParentNotClaiming := ← enumReq j "which_parent_not_claiming" "written declaration"
      WrittenDeclaration.ofString?
    inParentsCustody := ← boolReq j "in_parents_custody"
    livedWithTpOrOtherBiologicalOrAdoptiveParentMoreThanSixMonths :=
      ← boolReq j "lived_with_tp_or_other_biological_or_adoptive_parent_more_than_six_months"
    biologicalOrAdoptiveParentsLiving := ← boolReq j "biological_or_adoptive_parents_living"
    nightsWithTpVsOtherParent := ← enumReq j "nights_with_tp_vs_other_parent" "nights comparison"
      NightsComparison.ofString?
    tpAgiHigherThanOtherParent := ← boolReq j "tp_agi_higher_than_other_parent"
    parentsMeetReqsRuleForChildrenOfDivorcedParents :=
      ← boolReq j "parents_meet_reqs_rule_for_children_of_divorced_parents"
    specialRuleChildUsedByCustodialParentAsQp :=
      ← boolReq j "special_rule_child_used_by_custodial_parent_as_qp"
    specialRuleAgiTest := ← boolReq j "special_rule_agi_test"
    parentalSituation := ← enumReq j "parental_situation" "parental situation"
      ParentalSituation.ofString?
    parentalSupport := ← boolReq j "parental_support"
    multipleSupportAgreement := ← boolReq j "multiple_support_agreement" }

/-- Catala `Qualifying_relative.DependentAnswers`. -/
def dependentAnswersOfJson (j : Json) : Except String DependentAnswers :=
  return {
    grossIncome := ← moneyReq j "gross_income"
    writableQrSupportTest := ← boolReq j "writable_qr_support_test"
    tinType := ← enumReq j "tin_type" "TIN type" TinType.ofString?
    isUsCitizenFullYear := ← boolReq j "is_us_citizen_full_year"
    writableUsResident := ← boolReq j "writable_us_resident"
    writableUsNational := ← boolReq j "writable_us_national"
    writableCanadaMexicoResident := ← boolReq j "writable_canada_mexico_resident"
    tpClaims := ← boolReq j "tp_claims" }

/-- `Dependents_benefit_split.Member`. -/
def splitMemberOfJson (j : Json) : Except String DependentsBenefitSplit.Member :=
  return { person := ← personOfJson (← field j "person")
           answers := ← benefitSplitAnswersOfJson (← field j "answers") }

/-- `Qualifying_relative.Member`. -/
def depMemberOfJson (j : Json) : Except String QualifyingRelative.Member :=
  return { person := ← personOfJson (← field j "person")
           answers := ← dependentAnswersOfJson (← field j "answers")
           split := ← benefitSplitAnswersOfJson (← field j "split") }

/-- `Hoh_qss_persons.Member`. -/
def hohMemberOfJson (j : Json) : Except String HohQssPersons.Member := do
  let u ← field j "upkeep"
  return { dependent := ← depMemberOfJson (← field j "dependent")
           upkeep := { tpPaidMostOfHomeUpkeep := ← boolReq u "tp_paid_most_of_home_upkeep"
                       tpPaidMostOfParentHomeUpkeep :=
                         ← boolReq u "tp_paid_most_of_parent_home_upkeep" } }

private def bj (b : Bool) : Json := Json.bool b

/-- Catala scope `Filers.FilersStandardDeduction`. -/
def runFilersStandardDeduction (j : Json) : Except String Json := do
  let o := filersStandardDeduction
    { toFilersIn := ← filersInOfJson j (← boolReq j "eligible_for_hoh")
      mfsSpouse65OrOlder := ← boolReq j "mfs_spouse_65_or_older"
      employerIncomeSubtotal := ← moneyReq j "employer_income_subtotal" }
  return Json.mkObj [
    ("standard_deduction", mj o.standardDeduction),
    ("additional_standard_deduction_items", toJson o.additionalStandardDeductionItems),
    ("is_spouse_65_or_older", bj o.isSpouse65OrOlder),
    ("secondary_filer_is_blind_indicator_xml", bj o.secondaryFilerIsBlindIndicatorXml),
    ("xml_over65_sr_indicator", bj o.xmlOver65SrIndicator),
    ("primary_some_one_can_claim_for_tax_benefits", bj o.primarySomeOneCanClaimForTaxBenefits),
    ("secondary_some_one_can_claim_for_tax_benefits", bj o.secondarySomeOneCanClaimForTaxBenefits),
    ("unsupported", bj o.unsupported)]

/-- Catala scope `Qualifying_child.QualifyingChildTest`. -/
def runQualifyingChildTest (j : Json) : Except String Json := do
  let o := qualifyingChildTest
    { person := ← personOfJson (← field j "person")
      minimumFilerDateOfBirth := ← dateReq j "minimum_filer_date_of_birth" }
  return Json.mkObj
    [("age", toJson o.age), ("age_at_first_half_of_year", toJson o.ageAtFirstHalfOfYear),
     ("younger_than_oldest_filer", bj o.youngerThanOldestFiler),
     ("qc_relationship_test", bj o.qcRelationshipTest),
     ("student_status_may_affect_benefits", bj o.studentStatusMayAffectBenefits),
     ("is_a_student_under24", bj o.isAStudentUnder24),
     ("disability_status_may_affect_benefits", bj o.disabilityStatusMayAffectBenefits),
     ("age_test", bj o.ageTest), ("residency_test", bj o.residencyTest),
     ("qc_support_test", bj o.qcSupportTest), ("joint_return", bj o.jointReturn),
     ("required_to_file", bj o.requiredToFile),
     ("filing_only_for_refund", bj o.filingOnlyForRefund),
     ("joint_return_test", bj o.jointReturnTest), ("qualifying_child", bj o.qualifyingChild),
     ("qc_of_another_but_not", bj o.qcOfAnotherButNot),
     ("other_taxpayer_can_claim_as_qualifying_child", bj o.otherTaxpayerCanClaimAsQualifyingChild),
     ("ko_qualifying_child_tie_breaker", bj o.koQualifyingChildTieBreaker)]

/-- Catala scope `Dependents_benefit_split.BenefitSplitTest`. -/
def runBenefitSplitTest (j : Json) : Except String Json := do
  let o := benefitSplitTest
    { member := ← splitMemberOfJson (← field j "member")
      minimumFilerDateOfBirth := ← dateReq j "minimum_filer_date_of_birth"
      treatAsMfj := ← boolReq j "treat_as_mfj" }
  return Json.mkObj
    [("child_may_qualify_for_benefit_split", bj o.childMayQualifyForBenefitSplit),
     ("tp_is_parent", bj o.tpIsParent), ("tp_is_not_parent", bj o.tpIsNotParent),
     ("parental_some_parent_not_claiming", bj o.parentalSomeParentNotClaiming),
     ("primary_filer_not_claiming", bj o.primaryFilerNotClaiming),
     ("both_filers_not_claiming", bj o.bothFilersNotClaiming),
     ("other_parent_not_claiming", bj o.otherParentNotClaiming),
     ("had_equal_number_of_nights_with_parents", bj o.hadEqualNumberOfNightsWithParents),
     ("parents_are_divorced_separated_or_living_apart",
       bj o.parentsAreDivorcedSeparatedOrLivingApart),
     ("tp_is_custodial_parent", bj o.tpIsCustodialParent),
     ("section_152e_applies_despite_support_agreements",
       bj o.section152eAppliesDespiteSupportAgreements),
     ("eligible_for_benefit_split", bj o.eligibleForBenefitSplit),
     ("reached_non_parental_benefit_split", bj o.reachedNonParentalBenefitSplit),
     ("tp_can_claim_split_benefits_hoh_eitc_cdcc", bj o.tpCanClaimSplitBenefitsHohEitcCdcc),
     ("disqualified_due_to_parental_custody", bj o.disqualifiedDueToParentalCustody),
     ("contradictory8832_tp_is_custodial_parent", bj o.contradictory8832TpIsCustodialParent),
     ("contradictory8832_tp_not_custodial_parent", bj o.contradictory8832TpNotCustodialParent),
     ("contradictory8832_knockout", bj o.contradictory8832Knockout),
     ("causes_noncustodial_parent_benefit_split_knockout",
       bj o.causesNoncustodialParentBenefitSplitKnockout),
     ("unsupported", bj o.unsupported)]

/-- Catala scope `Qualifying_relative.DependentTest`. -/
def runDependentTest (j : Json) : Except String Json := do
  let o := dependentTest
    { member := ← depMemberOfJson (← field j "member")
      minimumFilerDateOfBirth := ← dateReq j "minimum_filer_date_of_birth"
      treatFilersAsDependents := ← boolReq j "treat_filers_as_dependents"
      eitherFilerUsCitizenOrNational := ← boolReq j "either_filer_us_citizen_or_national"
      treatAsMfj := ← boolReq j "treat_as_mfj" }
  return Json.mkObj
    [("qualifying_child", bj o.qualifyingChild),
     ("ask_about_qc_of_another", bj o.askAboutQcOfAnother),
     ("is_qualifying_child_of_another", bj o.isQualifyingChildOfAnother),
     ("could_be_qualifying_child_of_some_taxpayer", bj o.couldBeQualifyingChildOfSomeTaxpayer),
     ("not_qualifying_child_test", bj o.notQualifyingChildTest),
     ("qr_relationship_test", bj o.qrRelationshipTest),
     ("member_of_household_test", bj o.memberOfHouseholdTest),
     ("relationship_member_of_household_test", bj o.relationshipMemberOfHouseholdTest),
     ("gross_income_test", bj o.grossIncomeTest), ("qr_support_test", bj o.qrSupportTest),
     ("qualifying_relative_minus_not_qc_test", bj o.qualifyingRelativeMinusNotQcTest),
     ("qualifying_relative", bj o.qualifyingRelative), ("us_resident", bj o.usResident),
     ("us_national", bj o.usNational), ("canada_mexico_resident", bj o.canadaMexicoResident),
     ("child_is_adopted", bj o.childIsAdopted),
     ("adopted_child_exception", bj o.adoptedChildException),
     ("citizen_or_us_resident_test", bj o.citizenOrUsResidentTest),
     ("citizen_or_resident_test", bj o.citizenOrResidentTest), ("qc_or_qr", bj o.qcOrQr),
     ("eligible_dependent_minus_filer_information", bj o.eligibleDependentMinusFilerInformation),
     ("eligible_dependent", bj o.eligibleDependent),
     ("is_claimed_dependent", bj o.isClaimedDependent),
     ("is_claimed_if_claimable", bj o.isClaimedIfClaimable)]

/-- Catala scope `Hoh_qss_persons.HohQssPersonTest`. -/
def runHohQssPersonTest (j : Json) : Except String Json := do
  let o := HohQssPersons.hohQssPersonTest
    { member := ← hohMemberOfJson (← field j "member")
      minimumFilerDateOfBirth := ← dateReq j "minimum_filer_date_of_birth"
      treatFilersAsDependents := ← boolReq j "treat_filers_as_dependents"
      eitherFilerUsCitizenOrNational := ← boolReq j "either_filer_us_citizen_or_national"
      treatAsMfj := ← boolReq j "treat_as_mfj", eligibleForMfj := ← boolReq j "eligible_for_mfj"
      filerCouldQualifyForHoh := ← boolReq j "filer_could_qualify_for_hoh"
      filerCouldQualifyForQss := ← boolReq j "filer_could_qualify_for_qss" }
  return Json.mkObj
    [("married_hoh_relationship_test", bj o.marriedHohRelationshipTest),
     ("is_biological_adopted_foster_or_stepchild", bj o.isBiologicalAdoptedFosterOrStepchild),
     ("is_parent", bj o.isParent), ("qss_person_residency_test", bj o.qssPersonResidencyTest),
     ("flow_add_person_keeping_up_home", bj o.flowAddPersonKeepingUpHome),
     ("flow_add_person_keeping_up_parents_home", bj o.flowAddPersonKeepingUpParentsHome),
     ("considered_unmarried_child", bj o.consideredUnmarriedChild),
     ("married_child_not_excluded", bj o.marriedChildNotExcluded),
     ("hoh_qualifying_child_path", bj o.hohQualifyingChildPath),
     ("hoh_parent_path", bj o.hohParentPath),
     ("hoh_other_relative_path", bj o.hohOtherRelativePath),
     ("hoh_qualifying_person", bj o.hohQualifyingPerson),
     ("person_qualifies_tp_for_hoh", bj o.personQualifiesTpForHoh),
     ("hoh_qp_has_tin", bj o.hohQpHasTin), ("qss_qualifying_person", bj o.qssQualifyingPerson),
     ("person_qualifies_tp_for_qss", bj o.personQualifiesTpForQss)]

/-- Catala scope `Filing_status.FilingStatusReturn`. -/
def runFilingStatusReturn (j : Json) : Except String Json := do
  let b ← filersInOfJson j false
  let ms ← listReq j "members" hohMemberOfJson
  let o := FilingStatusMod.filingStatusReturn
    { filingStatus := b.filingStatus, maritalStatus := b.maritalStatus
      yearOfSpouseDeath := b.yearOfSpouseDeath, primaryFiler := b.primaryFiler
      secondaryFiler := b.secondaryFiler, secondaryFilerDateOfDeath := b.secondaryFilerDateOfDeath
      primaryFilerPotentialClaimerFiledOnlyForRefund := b.primaryFilerPotentialClaimerFiledOnlyForRefund
      mfjRequiredToFile := b.mfjRequiredToFile
      mfjDependentsFilingForCredits := b.mfjDependentsFilingForCredits
      livedTogetherAllYearWithSpouse := b.livedTogetherAllYearWithSpouse
      spouseLivedTogetherMonths := b.spouseLivedTogetherMonths
      writableLivedApartLastSixMonths := b.writableLivedApartLastSixMonths
      writableSeparationAgreement := b.writableSeparationAgreement
      canFileJointlyYearOfSpouseDeath := b.canFileJointlyYearOfSpouseDeath
      inRegisteredDomesticPartnership := b.inRegisteredDomesticPartnership
      filerResidenceAndIncomeState := b.filerResidenceAndIncomeState
      spouseItemizes := b.spouseItemizes, mfsLivingSpouseFilingReturn := b.mfsLivingSpouseFilingReturn
      mfsDeceasedSpouseFilingReturn := b.mfsDeceasedSpouseFilingReturn
      mfsSpouseHasGrossIncome := b.mfsSpouseHasGrossIncome, members := ms }
  return Json.mkObj
    [("marital_status_allows_filing_married", bj o.maritalStatusAllowsFilingMarried),
     ("eligible_for_mfj", bj o.eligibleForMfj), ("eligible_for_mfs", bj o.eligibleForMfs),
     ("eligible_for_single", bj o.eligibleForSingle), ("eligible_for_hoh", bj o.eligibleForHoh),
     ("eligible_for_qss", bj o.eligibleForQss),
     ("filer_could_qualify_for_hoh", bj o.filerCouldQualifyForHoh),
     ("filer_could_qualify_for_qss", bj o.filerCouldQualifyForQss),
     ("hoh_qualifying_people_count", toJson o.hohQualifyingPeopleCount),
     ("qss_qualifying_people_count", toJson o.qssQualifyingPeopleCount),
     ("is_filing_status_valid", bj o.isFilingStatusValid),
     ("has_multiple_eligible_filing_statuses", bj o.hasMultipleEligibleFilingStatuses),
     ("recommended_is_single", bj o.recommendedIsSingle),
     ("recommended_is_mfj", bj o.recommendedIsMfj), ("recommended_is_mfs", bj o.recommendedIsMfs),
     ("recommended_is_hoh", bj o.recommendedIsHoh), ("recommended_is_qss", bj o.recommendedIsQss),
     ("treat_as_mfj", bj o.treatAsMfj), ("treat_as_mfs", bj o.treatAsMfs),
     ("treat_as_hoh", bj o.treatAsHoh),
     ("ko_filing_status_not_eligible", bj o.koFilingStatusNotEligible),
     ("unsupported", bj o.unsupported)]

end Household

/-! ### CDCC, Saver's credit and Schedule R scopes (issue #46)

Decoders and drivers for `Form2441`, `SaversCredit` and `ScheduleR`. Same conventions as above:
money as a decimal string or number of dollars, enumerations by Catala case name, dates
`"YYYY-MM-DD"`, every input required. -/

section Credits

/-- Catala `Cdcc.CdccAnswers`. -/
def cdccAnswersOfJson (j : Json) : Except String Cdcc.CdccAnswers :=
  return {
    unableToCareForSelf := ← boolReq j "unable_to_care_for_self"
    hasDependentCareExpenses := ← boolReq j "has_dependent_care_expenses"
    expensesPaidToQualifyingProvider := ← boolReq j "expenses_paid_to_qualifying_provider"
    writableQualifyingExpenseAmount := ← moneyReq j "writable_qualifying_expense_amount"
    tpPaidMostOfHomeUpkeep := ← boolReq j "tp_paid_most_of_home_upkeep" }

/-- Catala `Cdcc.CdccMember`. -/
def cdccMemberOfJson (j : Json) : Except String Cdcc.CdccMember :=
  return { member := ← depMemberOfJson (← field j "member")
           cdcc := ← cdccAnswersOfJson (← field j "cdcc") }

/-- Catala `Cdcc.CdccFiler`. -/
def cdccFilerOfJson (j : Json) : Except String Cdcc.CdccFiler :=
  return {
    employerIncomeSubtotalBase := ← moneyReq j "employer_income_subtotal_base"
    nontaxableCombatPay := ← moneyReq j "nontaxable_combat_pay"
    electCombatPayForCredit := ← boolReq j "elect_combat_pay_for_credit"
    electCombatPayForBenefits := ← boolReq j "elect_combat_pay_for_benefits"
    dependentCareBenefits := ← moneyReq j "dependent_care_benefits"
    dependentCarePlanMaximum := ← moneyReq j "dependent_care_plan_maximum"
    isDisabled := ← boolReq j "is_disabled"
    deemedIncomeMonthEarnings := ← listReq j "deemed_income_month_earnings" moneyOfJson
    hasDependentCareExpenses := ← boolReq j "has_dependent_care_expenses"
    expensesPaidToQualifyingProvider := ← boolReq j "expenses_paid_to_qualifying_provider"
    writableQualifyingExpenseAmount := ← moneyReq j "writable_qualifying_expense_amount" }

/-- The inputs `Form2441PartIII` and `Form2441` share. -/
def form2441PartIIIInOfJson (j : Json) : Except String Cdcc.Form2441PartIIIIn :=
  return {
    filingStatus := ← filingStatusOfJson (← field j "filing_status")
    household := ← listReq j "household" cdccMemberOfJson
    minimumFilerDateOfBirth := ← dateReq j "minimum_filer_date_of_birth"
    treatFilersAsDependents := ← boolReq j "treat_filers_as_dependents"
    eitherFilerUsCitizenOrNational := ← boolReq j "either_filer_us_citizen_or_national"
    treatAsMfj := ← boolReq j "treat_as_mfj"
    livedApartLastSixMonths := ← boolReq j "lived_apart_last_six_months"
    spouseSameAbodeMoreThanHalfYear := ← boolReq j "spouse_same_abode_more_than_half_year"
    primaryFiler := ← cdccFilerOfJson (← field j "primary_filer")
    secondaryFiler := ← cdccFilerOfJson (← field j "secondary_filer")
    hasMfsSpouseEarnedIncome := ← boolReq j "has_mfs_spouse_earned_income"
    writableMfsSpouseEarnedIncome := ← moneyReq j "writable_mfs_spouse_earned_income"
    writableTotalQualifiedDependentCareExpenses :=
      ← moneyReq j "writable_total_qualified_dependent_care_expenses"
    writableCarryoverAmount := ← moneyReq j "writable_carryover_amount"
    writableForfeitedAmount := ← moneyReq j "writable_forfeited_amount"
    hasCreditForPriorYearExpenses := ← boolReq j "has_credit_for_prior_year_expenses"
    claimedCreditForPriorYearExpenses := ← boolReq j "claimed_credit_for_prior_year_expenses"
    claimedMaxCreditForPriorTaxYear := ← boolReq j "claimed_max_credit_for_prior_tax_year"
    hasHouseholdEmployee := ← boolReq j "has_household_employee"
    benefitsFromSoleProprietorshipOrPartnership :=
      ← boolReq j "benefits_from_sole_proprietorship_or_partnership" }

/-- Catala scope `Cdcc.Form2441` (the flat outputs; `benefits` is the sub-scope result). -/
def runForm2441 (j : Json) : Except String Json := do
  let o := Cdcc.form2441
    { toForm2441PartIIIIn := ← form2441PartIIIInOfJson j
      agi := ← moneyReq j "agi", totalTentativeTax := ← moneyReq j "total_tentative_tax" }
  let b := o.benefits
  return Json.mkObj
    [("taxable_benefits", mj b.taxableBenefits),
     ("count_of_qualifying_persons", toJson b.countOfQualifyingPersons),
     ("has_qualifying_persons", bj b.hasQualifyingPersons),
     ("has_more_than_three_qualifying_persons", bj o.hasMoreThanThreeQualifyingPersons),
     ("mfs_but_eligible_for_cdcc", bj b.mfsButEligibleForCdcc),
     ("line12_dependent_care_benefits", mj b.line12DependentCareBenefits),
     ("line13_carryover", mj b.line13Carryover), ("line14_forfeited", mj b.line14Forfeited),
     ("line15_adjusted_benefits", mj b.line15AdjustedBenefits),
     ("line17_lesser", mj b.line17Lesser),
     ("line20_tentative_exclusion", mj b.line20TentativeExclusion),
     ("line21_specified_exclusion", mj b.line21SpecifiedExclusion),
     ("line24_deductible_benefits", mj b.line24DeductibleBenefits),
     ("line25_excluded_benefits", mj b.line25ExcludedBenefits),
     ("line28", mj b.line28), ("line29_net_allowable", mj b.line29NetAllowable),
     ("line31", mj b.line31), ("line3", mj o.line3),
     ("primary_earned_income_before_benefits", mj o.primaryEarnedIncomeBeforeBenefits),
     ("secondary_earned_income_before_benefits", mj o.secondaryEarnedIncomeBeforeBenefits),
     ("primary_adjustment", mj o.primaryAdjustment),
     ("secondary_adjustment", mj o.secondaryAdjustment),
     ("allocate_all_to_primary", bj o.allocateAllToPrimary),
     ("allocate_all_to_secondary", bj o.allocateAllToSecondary),
     ("primary_taxable_benefits", mj o.primaryTaxableBenefits),
     ("secondary_taxable_benefits", mj o.secondaryTaxableBenefits),
     ("line4_earned_income", mj o.line4EarnedIncome), ("line5_earned_income", mj o.line5EarnedIncome),
     ("lower_of_earned_income", mj o.lowerOfEarnedIncome), ("line6", mj o.line6),
     ("line8_decimal_amount", mj o.line8DecimalAmount), ("line9a", mj o.line9a),
     ("line9b", mj o.line9b), ("line9c", mj o.line9c),
     ("line10_tax_liability_limit", mj o.line10TaxLiabilityLimit),
     ("has_qualifying_expenses", bj o.hasQualifyingExpenses),
     ("cdcc_total_credit", mj o.cdccTotalCredit),
     ("is_receiving_cdcc_credit", bj o.isReceivingCdccCredit),
     ("should_submit_form_2441", bj o.shouldSubmitForm2441),
     ("ko_flow_knockout_benefits_distribution", bj o.koFlowKnockoutBenefitsDistribution),
     ("unsupported", bj o.unsupported)]

/-- Catala scope `Savers_credit.SaversCredit`. -/
def runSaversCredit (j : Json) : Except String Json := do
  let o := SaversCredit.saversCredit
    { filingStatus := ← filingStatusOfJson (← field j "filing_status")
      agi := ← moneyReq j "agi", isMfjDependent := ← boolReq j "is_mfj_dependent"
      primaryFilerIsUnder18 := ← boolReq j "primary_filer_is_under18"
      primaryFilerIsStudent := ← boolReq j "primary_filer_is_student"
      primaryFilerIsClaimedAsDependent := ← boolReq j "primary_filer_is_claimed_as_dependent"
      secondaryFilerIsUnder18 := ← boolReq j "secondary_filer_is_under18"
      secondaryFilerIsStudent := ← boolReq j "secondary_filer_is_student"
      secondaryFilerIsClaimedAsDependent := ← boolReq j "secondary_filer_is_claimed_as_dependent"
      primaryFilerTotalDeferralsAndContributions :=
        ← moneyReq j "primary_filer_total_deferrals_and_contributions"
      secondaryFilerTotalDeferralsAndContributions :=
        ← moneyReq j "secondary_filer_total_deferrals_and_contributions"
      primaryFilerSaversGrossDistributions := ← moneyReq j "primary_filer_savers_gross_distributions"
      secondaryFilerSaversGrossDistributions :=
        ← moneyReq j "secondary_filer_savers_gross_distributions"
      totalTentativeTax := ← moneyReq j "total_tentative_tax"
      cdccTotalCredit := ← moneyReq j "cdcc_total_credit", totalEdc := ← moneyReq j "total_edc"
      hasDistributionsInLastThreeYears := ← boolReq j "has_distributions_in_last_three_years"
      hasCurrentYearDistributions := ← boolReq j "has_current_year_distributions"
      hasSelfReportedContributions := ← boolReq j "has_self_reported_contributions" }
  return Json.mkObj
    [("primary_filer_is_eligible", bj o.primaryFilerIsEligible),
     ("secondary_filer_is_eligible", bj o.secondaryFilerIsEligible),
     ("secondary_filer_is_applicable_and_eligible", bj o.secondaryFilerIsApplicableAndEligible),
     ("is_agi_eligible_for_savers_credit", bj o.isAgiEligibleForSaversCredit),
     ("eligible_for_savers_credit", bj o.eligibleForSaversCredit),
     ("primary_filer_ira_and_able_contributions", mj o.primaryFilerIraAndAbleContributions),
     ("secondary_filer_ira_and_able_contributions", mj o.secondaryFilerIraAndAbleContributions),
     ("primary_filers_deferrals_and_contributions", mj o.primaryFilersDeferralsAndContributions),
     ("secondary_filers_deferrals_and_contributions", mj o.secondaryFilersDeferralsAndContributions),
     ("primary_filer_gross_distributions", mj o.primaryFilerGrossDistributions),
     ("secondary_filer_gross_distributions", mj o.secondaryFilerGrossDistributions),
     ("primary_filer_total_contributions", mj o.primaryFilerTotalContributions),
     ("secondary_filer_total_contributions", mj o.secondaryFilerTotalContributions),
     ("primary_filer_total_contributions_less_distributions",
       mj o.primaryFilerTotalContributionsLessDistributions),
     ("secondary_filer_total_contributions_less_distributions",
       mj o.secondaryFilerTotalContributionsLessDistributions),
     ("primary_filer_max_credit_calc", mj o.primaryFilerMaxCreditCalc),
     ("secondary_filer_max_credit_calc", mj o.secondaryFilerMaxCreditCalc),
     ("combined_credit_limit", mj o.combinedCreditLimit),
     ("savers_credit_multiplier", Json.str o.saversCreditMultiplier.catalaName),
     ("ratioed_combined_credit_limit", mj o.ratioedCombinedCreditLimit),
     ("limitation_based_on_tax_liability", mj o.limitationBasedOnTaxLiability),
     ("qualified_for_saver_credit_wo_tax_liability", bj o.qualifiedForSaverCreditWoTaxLiability),
     ("qualified_for_saver_credit", bj o.qualifiedForSaverCredit),
     ("qualified_saver_credit_amount", mj o.qualifiedSaverCreditAmount),
     ("is_receiving_savers_credit", bj o.isReceivingSaversCredit),
     ("ko_savers_credit_knockouts", bj o.koSaversCreditKnockouts),
     ("unsupported", bj o.unsupported)]

/-- Catala `Elderly_and_disabled.DisabilityAnswers`. -/
def disabilityAnswersOfJson (j : Json) : Except String ElderlyAndDisabled.DisabilityAnswers :=
  return {
    isRetiredOnPermOrTotalDisability := ← boolReq j "is_retired_on_perm_or_total_disability"
    employerHasMandatoryRetirementAge := ← boolReq j "employer_has_mandatory_retirement_age"
    hasMetEmployerMandatoryRetirementAge := ← boolReq j "has_met_employer_mandatory_retirement_age"
    arePaymentsTaxableDisabilityIncome := ← boolReq j "are_payments_taxable_disability_income"
    writableTotalTaxableDisabilityAmount := ← moneyReq j "writable_total_taxable_disability_amount"
    hasW2Wages := ← boolReq j "has_w2_wages" }

/-- Catala scope `Elderly_and_disabled.ScheduleR`. -/
def runScheduleR (j : Json) : Except String Json := do
  let o := ElderlyAndDisabled.scheduleR
    { filingStatus := ← filingStatusOfJson (← field j "filing_status")
      livedApartAllYear := ← boolReq j "lived_apart_all_year"
      primaryAge65OrOlder := ← boolReq j "primary_age65_or_older"
      secondaryAge65OrOlder := ← boolReq j "secondary_age65_or_older"
      primaryAnswers := ← disabilityAnswersOfJson (← field j "primary_answers")
      secondaryAnswers := ← disabilityAnswersOfJson (← field j "secondary_answers")
      agi := ← moneyReq j "agi"
      nonTaxableSocialSecurityBenefits := ← moneyReq j "non_taxable_social_security_benefits"
      selfReportedNonTaxablePayments := ← moneyReq j "self_reported_non_taxable_payments"
      creditLimitWorksheetLine3 := ← moneyReq j "credit_limit_worksheet_line_3" }
  return Json.mkObj
    [("is_mfj", bj o.isMfj), ("is_mfs", bj o.isMfs), ("is_single_hoh_qss", bj o.isSingleHohQss),
     ("primary_is_65", bj o.primaryIs65), ("secondary_is_65", bj o.secondaryIs65),
     ("number_qualified_through_disability", toJson o.numberQualifiedThroughDisability),
     ("mfj_and_only_one_qualified", bj o.mfjAndOnlyOneQualified),
     ("relaxed_agi_limit", mj o.relaxedAgiLimit),
     ("relaxed_non_taxable_limit", mj o.relaxedNonTaxableLimit),
     ("at_least_one_tp_is_under_65", bj o.atLeastOneTpIsUnder65),
     ("maybe_eligible_for_credit", bj o.maybeEligibleForCredit),
     ("edc_line1", bj o.edcLine1), ("edc_line2", bj o.edcLine2), ("edc_line3", bj o.edcLine3),
     ("edc_line4", bj o.edcLine4), ("edc_line5", bj o.edcLine5), ("edc_line6", bj o.edcLine6),
     ("edc_line7", bj o.edcLine7), ("edc_line8", bj o.edcLine8), ("edc_line9", bj o.edcLine9),
     ("edc_filing_status_amt", mj o.edcFilingStatusAmt),
     ("status_based_disability_income", mj o.statusBasedDisabilityIncome),
     ("lesser_of_filing_status_amount_and_taxable_disability_income",
       mj o.lesserOfFilingStatusAmountAndTaxableDisabilityIncome),
     ("edc_non_taxable_social_security_and_railroad_benefits",
       mj o.edcNonTaxableSocialSecurityAndRailroadBenefits),
     ("edc_non_taxable_income_not_including_social_security_and_rrb",
       mj o.edcNonTaxableIncomeNotIncludingSocialSecurityAndRrb),
     ("edc_total_non_taxable_amount", mj o.edcTotalNonTaxableAmount),
     ("edc_exemption_amount", mj o.edcExemptionAmount), ("edc_magi", mj o.edcMagi),
     ("edc_half_magi", mj o.edcHalfMagi),
     ("edc_adjusted_credit_amount", mj o.edcAdjustedCreditAmount),
     ("edc_net_credit_amount", mj o.edcNetCreditAmount), ("net_edc_amount", mj o.netEdcAmount),
     ("edc_tax_liability_limit", mj o.edcTaxLiabilityLimit),
     ("total_edc", mj o.totalEdc), ("edc_agi_limit", mj o.edcAgiLimit),
     ("edc_non_taxable_limit", mj o.edcNonTaxableLimit),
     ("is_qualified_based_on_age_or_disability", bj o.isQualifiedBasedOnAgeOrDisability),
     ("qualified_for_credit_for_elderly_and_disabled", bj o.qualifiedForCreditForElderlyAndDisabled),
     ("is_receiving_edc", bj o.isReceivingEdc)]

end Credits

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
   ("EstimatedPayments", runEstimatedPayments),
   ("FilersStandardDeduction", runFilersStandardDeduction),
   ("QualifyingChildTest", runQualifyingChildTest),
   ("BenefitSplitTest", runBenefitSplitTest),
   ("DependentTest", runDependentTest),
   ("HohQssPersonTest", runHohQssPersonTest),
   ("FilingStatusReturn", runFilingStatusReturn),
   ("Form2441", runForm2441),
   ("SaversCredit", runSaversCredit),
   ("ScheduleR", runScheduleR)]

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
