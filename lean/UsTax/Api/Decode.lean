import UsTax.Api.Json
import UsTax.Api.Error
import UsTax.Api.Types

/-!
# JSON to typed request (issue #51), phase 1: shape

`decRequest : J → D Request` reads a parsed JSON value into a `Request` and
logs, in the state, **every** shape problem it finds (it keeps going after the
first): wrong JSON type, float or string money, bad enumeration value, missing
required property, unknown property, malformed date. When the log is empty the
result is the request; when it is not, the returned value is a default and must
be ignored (`runDecode` enforces that).

Unknown properties are found without a separate list of allowed names: every
property accessor records the key it read, and an object's unread keys are the
unknown ones. A property that exists in `Types.lean` but is never read cannot
be silently dropped, because it would then be reported as unknown.

Range, list-size and cross-field rules are phase 2 (`Validate.lean`), over the
typed value. The two phases together are `parseRequest` (`Parse.lean`).
-/

namespace UsTax.Api

open UsTax

/-- Decoder state: problems found so far, and the keys read in the current object. -/
structure DS where
  /-- Property `errs`. -/
  errs : Array FieldError := #[]
  /-- Property `used`. -/
  used : Array String := #[]

/-- The decoder monad: total, accumulating. -/
abbrev D := StateM DS

/-- Log a problem at path `p`. -/
def report (p : String) (c : FieldCode) (m : String) : D Unit :=
  modify fun s => { s with errs := s.errs.push ⟨p, c, m⟩ }

/-- A boolean. -/
def asBool (p : String) : J → D Bool
  | .bool b => pure b
  | _ => do report p .type "must be a boolean"; pure false

/-- An integer literal (money cents). Floats get `not_integer`. -/
def asInt (p : String) : J → D Int
  | .int n => pure n
  | .float _ => do report p .notInteger "money must be an integer number of cents"; pure 0
  | _ => do report p .type "must be an integer number of cents"; pure 0

/-- The constant integer `n` (for `api_version` and `tax_year`). -/
def asConst (n : Int) (p : String) : J → D Unit
  | .int m => if m == n then pure () else report p .enum s!"must be {n}"
  | .float _ => report p .notInteger "must be an integer"
  | _ => report p .type "must be an integer"

/-- A string naming a constructor of `α`. -/
def asEnum {α : Type} [ApiEnum α] [Inhabited α] (p : String) : J → D α
  | .str s =>
    match (ApiEnum.all : List α).find? (fun a => ApiEnum.name a == s) with
    | some a => pure a
    | none => do
      report p .enum ("must be one of: " ++ ", ".intercalate ((ApiEnum.all : List α).map ApiEnum.name))
      pure default
  | _ => do report p .type "must be a string"; pure default

/-- `YYYY-MM-DD` (four, two, two digits). Whether it is a real date is phase 2. -/
def parseIsoDate (s : String) : Option Date :=
  match s.toList with
  | [y1, y2, y3, y4, '-', m1, m2, '-', d1, d2] =>
    let ds := [y1, y2, y3, y4, m1, m2, d1, d2]
    if ds.all (fun c => '0' ≤ c ∧ c ≤ '9') then
      some { year := (Json.natOfDigits [y1, y2, y3, y4] : Nat), month := Json.natOfDigits [m1, m2],
             day := Json.natOfDigits [d1, d2] }
    else none
  | _ => none

/-- An ISO date string, or `none` after logging. -/
def asDate (p : String) : J → D (Option Date)
  | .str s =>
    match parseIsoDate s with
    | some d => pure (some d)
    | none => do report p .type "must match YYYY-MM-DD"; pure none
  | _ => do report p .type "must be a string"; pure none

/-- An array, each element read by `f` at its own index path. -/
def asArray {α : Type} (p : String) (f : String → J → D α) : J → D (List α)
  | .arr xs => do
    let mut out : Array α := #[]
    let mut i := 0
    for x in xs do
      out := out.push (← f (p ++ "/" ++ toString i) x)
      i := i + 1
    pure out.toList
  | _ => do report p .type "must be an array"; pure []

/-- Read an object with `f`; keys `f` did not read are reported as unknown. -/
def withObj {α : Type} [Inhabited α] (p : String) (j : J)
    (f : List (String × J) → D α) : D α :=
  match j with
  | .obj fs => do
    let saved := (← get).used
    modify fun s => { s with used := #[] }
    let a ← f fs
    let u := (← get).used
    for (k, _) in fs do
      unless u.contains k do report (child p k) .unknownField "unknown property"
    modify fun s => { s with used := saved }
    pure a
  | _ => do report p .type "must be an object"; pure default

/-- Mark `k` as read. -/
def touch (k : String) : D Unit := modify fun s => { s with used := s.used.push k }

/-- Optional property: `none` when absent. -/
def opt {α : Type} (fs : List (String × J)) (p k : String) (dec : String → J → D α) :
    D (Option α) := do
  touch k
  match J.lookup fs k with
  | none => pure none
  | some j => some <$> dec (child p k) j

/-- Optional property with a default. -/
def optD {α : Type} (fs : List (String × J)) (p k : String) (dec : String → J → D α) (d : α) :
    D α := do
  return (← opt fs p k dec).getD d

/-- Required property. -/
def req {α : Type} [Inhabited α] (fs : List (String × J)) (p k : String)
    (dec : String → J → D α) : D α := do
  touch k
  match J.lookup fs k with
  | none => report (child p k) .required "required property"; pure default
  | some j => dec (child p k) j

/-- Optional money box, `0` when absent. -/
def money (fs : List (String × J)) (p k : String) : D Int := optD fs p k asInt 0

/-- Optional flag, `false` when absent. -/
def flag (fs : List (String × J)) (p k : String) : D Bool := optD fs p k asBool false

/-- Optional list of forms, empty when absent. -/
def optList {α : Type} (fs : List (String × J)) (p k : String) (f : String → J → D α) :
    D (List α) := do
  return (← opt fs p k (asArray · f)).getD []

/-- `FilerFlags`. -/
def decFilerFlags (p : String) (j : J) : D FilerFlags :=
  withObj p j fun fs => do
    return { isBlind := ← flag fs p "is_blind", age65OrOlder := ← flag fs p "age65_or_older",
             canBeClaimedAsDependent := ← flag fs p "can_be_claimed_as_dependent" }

/-- `Filers`. -/
def decFilers (p : String) (j : J) : D Filers :=
  withObj p j fun fs => do
    return { primary := ← opt fs p "primary" decFilerFlags,
             secondary := ← opt fs p "secondary" decFilerFlags }

/-- `FilingDetails`. -/
def decFilingDetails (p : String) (j : J) : D FilingDetails :=
  withObj p j fun fs => do
    return { treatAsMfs := ← opt fs p "treat_as_mfs" asBool,
             isWidowedInTaxYear := ← flag fs p "is_widowed_in_tax_year",
             mfjDeceasedSpouseReachedAge65 := ← flag fs p "mfj_deceased_spouse_reached_age65",
             mfsSpouse65OrOlder := ← flag fs p "mfs_spouse_65_or_older",
             mfsSpouseProvidesNoBenefits := ← flag fs p "mfs_spouse_provides_no_benefits",
             treatFilersAsDependents := ← flag fs p "treat_filers_as_dependents",
             hasForeignAccountsOrTrusts := ← flag fs p "has_foreign_accounts_or_trusts",
             combatPayElection := ← optD fs p "combat_pay_election" asEnum .noCombatPay }

/-- `W2Box12`: keys are code letters, values amounts. -/
def decBox12 (p : String) : J → D Box12
  | .obj fs => do
    let mut es : Array (Box12Code × Int) := #[]
    for (k, v) in fs do
      match (ApiEnum.all : List Box12Code).find? (fun code => ApiEnum.name code == k) with
      | some code => es := es.push (code, ← asInt (child p k) v)
      | none => report (child p k) .unknownField "unknown property"
    pure ⟨es.toList⟩
  | _ => do report p .type "must be an object"; pure {}

/-- `FormW2`. -/
def decW2 (p : String) (j : J) : D FormW2 :=
  withObj p j fun fs => do
    return { filer := ← req fs p "filer" asEnum, wages := ← req fs p "wages" asInt,
             federalWithholding := ← money fs p "federal_withholding",
             oasdiWages := ← money fs p "oasdi_wages",
             oasdiWithholding := ← money fs p "oasdi_withholding",
             medicareWages := ← money fs p "medicare_wages",
             medicareWithholding := ← money fs p "medicare_withholding",
             allocatedTips := ← money fs p "allocated_tips",
             dependentCareBenefits := ← money fs p "dependent_care_benefits",
             nonQualifiedPlans := ← money fs p "non_qualified_plans",
             box12 := ← optD fs p "box12" decBox12 {},
             statutoryEmployee := ← flag fs p "statutory_employee",
             thirdPartySickPay := ← flag fs p "third_party_sick_pay",
             plan457bIsGovernmental := ← flag fs p "plan_457b_is_governmental" }

/-- `Form1099Int`. -/
def decInt1099 (p : String) (j : J) : D Form1099Int :=
  withObj p j fun fs => do
    return { filer := ← req fs p "filer" asEnum, has1099 := ← req fs p "has_1099" asBool,
             no1099Amount := ← money fs p "no_1099_amount",
             interestIncome := ← money fs p "interest_income",
             earlyWithdrawalPenalty := ← money fs p "early_withdrawal_penalty",
             governmentBondInterest := ← money fs p "government_bond_interest",
             federalTaxWithheld := ← money fs p "federal_tax_withheld",
             foreignTaxPaid := ← money fs p "foreign_tax_paid",
             taxExemptInterest := ← money fs p "tax_exempt_interest",
             privateActivityBondInterest := ← money fs p "private_activity_bond_interest",
             marketDiscount := ← money fs p "market_discount",
             bondPremium := ← money fs p "bond_premium",
             bondPremiumTreasury := ← money fs p "bond_premium_treasury",
             bondPremiumTaxExempt := ← money fs p "bond_premium_tax_exempt",
             stateIsDifferent := ← flag fs p "state_is_different",
             stateTaxWithheld := ← money fs p "state_tax_withheld",
             factaFilingRequired := ← flag fs p "facta_filing_required" }

/-- `Form1099G`. -/
def decG1099 (p : String) (j : J) : D Form1099G :=
  withObj p j fun fs => do
    return { filer := ← req fs p "filer" asEnum,
             unemploymentCompensation := ← req fs p "unemployment_compensation" asInt,
             repaidThisYearForThisYear := ← money fs p "repaid_this_year_for_this_year",
             repaidThisYearForEarlierYear := ← money fs p "repaid_this_year_for_earlier_year",
             federalTaxWithheld := ← money fs p "federal_tax_withheld",
             stateIsDifferent := ← flag fs p "state_is_different" }

/-- `Form1099Misc`. -/
def decMisc1099 (p : String) (j : J) : D Form1099Misc :=
  withObj p j fun fs => do
    return { filer := ← req fs p "filer" asEnum, isAlaskaPfd := ← req fs p "is_alaska_pfd" asBool,
             otherIncome := ← req fs p "other_income" asInt,
             federalWithholding := ← money fs p "federal_withholding" }

/-- `Form1099R`. -/
def decR1099 (p : String) (j : J) : D Form1099R :=
  withObj p j fun fs => do
    return { filer := ← req fs p "filer" asEnum,
             distributionCode := ← req fs p "distribution_code" (asArray · asEnum),
             grossDistribution := ← req fs p "gross_distribution" asInt,
             taxableAmount := ← req fs p "taxable_amount" asInt,
             taxableAmountBlank := ← flag fs p "taxable_amount_blank",
             taxableAmountNotDetermined := ← flag fs p "taxable_amount_not_determined",
             totalDistribution := ← flag fs p "total_distribution",
             capitalGain := ← money fs p "capital_gain",
             federalWithholding := ← money fs p "federal_withholding",
             netAppreciation := ← money fs p "net_appreciation",
             iraSepSimple := ← flag fs p "ira_sep_simple",
             otherDollar := ← money fs p "other_dollar",
             otherPercentageNonzero := ← flag fs p "other_percentage_nonzero",
             percentageTotalDistributionNonzero := ← flag fs p "percentage_total_distribution_nonzero",
             amountAllocableToIrr := ← money fs p "amount_allocable_to_irr",
             factaFilingRequirement := ← flag fs p "facta_filing_requirement",
             stateTaxWithheld := ← money fs p "state_tax_withheld",
             payerStateIsDifferent := ← flag fs p "payer_state_is_different",
             hasDeathBenefitPaymentDate := ← flag fs p "has_death_benefit_payment_date",
             isIndirectRollover := ← flag fs p "is_indirect_rollover",
             isDistributionFromMilitaryRetirementPlan :=
               ← flag fs p "is_distribution_from_military_retirement_plan",
             qualifiedDisasterDistribution := ← flag fs p "qualified_disaster_distribution",
             publicSafetyOfficer := ← flag fs p "public_safety_officer",
             publicSafetyOfficerPremiums := ← flag fs p "public_safety_officer_premiums",
             recipientDateOfBirth := (← opt fs p "recipient_date_of_birth" asDate).getD none }

/-- `SocialSecurity`. -/
def decSocialSecurity (p : String) (j : J) : D SocialSecurity :=
  withObj p j fun fs => do
    return { netBenefits := ← req fs p "net_benefits" (asArray · asInt),
             livedApartAllYear := ← flag fs p "lived_apart_all_year" }

/-- `EducatorExpenses`. -/
def decEducator (p : String) (j : J) : D EducatorExpenses :=
  withObj p j fun fs => do
    return { wasK12Educators := ← req fs p "was_k12_educators" asEnum,
             primaryExpenses := ← money fs p "primary_expenses",
             secondaryExpenses := ← money fs p "secondary_expenses" }

/-- `StudentLoanInterest`. -/
def decStudentLoan (p : String) (j : J) : D StudentLoanInterest :=
  withObj p j fun fs => do
    return { hadPayments := ← req fs p "had_payments" asBool,
             loansQualify := ← flag fs p "loans_qualify",
             interestAmount := ← money fs p "interest_amount" }

/-- `Adjustments`. -/
def decAdjustments (p : String) (j : J) : D Adjustments :=
  withObj p j fun fs => do
    return { educatorExpenses := ← opt fs p "educator_expenses" decEducator,
             studentLoanInterest := ← opt fs p "student_loan_interest" decStudentLoan }

/-- `EstimatedPayments`. -/
def decEstimated (p : String) (j : J) : D EstimatedPayments :=
  withObj p j fun fs => do
    return { paidEstimatedTaxesOrFromLastYear :=
               ← req fs p "paid_estimated_taxes_or_from_last_year" asBool,
             amount := ← money fs p "amount",
             paidUnderDifferentName := ← flag fs p "paid_under_different_name",
             paidWithFormerSpouse := ← opt fs p "paid_with_former_spouse" asEnum }

/-- `CalculateRequest`, phase 1. `api_version` must be 1 and `tax_year` 2024
(the caller reports those two first, with their own error codes). -/
def decRequest (j : J) : D Request :=
  withObj "" j fun fs => do
    let _ ← req fs "" "api_version" (asConst 1)
    let _ ← req fs "" "tax_year" (asConst 2024)
    return { filingStatus := ← req fs "" "filing_status" asEnum,
             filers := ← optD fs "" "filers" decFilers {},
             filingDetails := ← optD fs "" "filing_details" decFilingDetails {},
             w2s := ← optList fs "" "w2s" decW2,
             interestReports := ← optList fs "" "interest_reports" decInt1099,
             form1099g := ← optList fs "" "form_1099g" decG1099,
             form1099misc := ← optList fs "" "form_1099misc" decMisc1099,
             form1099r := ← optList fs "" "form_1099r" decR1099,
             socialSecurity := ← opt fs "" "social_security" decSocialSecurity,
             adjustments := ← optD fs "" "adjustments" decAdjustments {},
             estimatedPayments := ← opt fs "" "estimated_payments" decEstimated }

/-- Run phase 1: the request, or every shape problem found. -/
def runDecode (j : J) : Except (List FieldError) Request :=
  let (r, s) := (decRequest j).run {}
  if s.errs.isEmpty then .ok r else .error s.errs.toList

end UsTax.Api
