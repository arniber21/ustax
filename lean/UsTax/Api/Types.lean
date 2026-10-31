import UsTax.Types
import UsTax.Date

/-!
# Typed request (issue #51): the Lean image of `CalculateRequest`

`api/schema.json` `$defs/CalculateRequest` and its parts, field for field.
Names are the schema's property names in lower camel case
(`federal_withholding` is `federalWithholding`). Conventions:

* money is `Int` cents (never `Nat`, never a float), as in the verified core;
* an absent money box is `0`, an absent flag is `false` (`docs/api.md`,
  "Request"), so those fields are plain `Int` / `Bool` with those defaults;
* an absent optional section whose absence differs from its defaults is an
  `Option` (`filers.primary`, `adjustments.educator_expenses`, ...);
* enumerations are Lean inductives; `ApiEnum.name` is the wire spelling, which
  is the Catala constructor name unchanged;
* `api_version` and `tax_year` are checked, not stored (they are constants).

Which fields are money, and of which sign rule, is in the `moneyFields`
functions here; the range rules that use them are in `UsTax/Api/Spec.lean`.
`FilingStatus` is `UsTax.FilingStatus`.
-/

namespace UsTax.Api

open UsTax

/-- An enumeration with a wire spelling. -/
class ApiEnum (α : Type) where
  /-- Every constructor. -/
  all : List α
  /-- The wire spelling (a Catala constructor name, or `"2"` for a box 7 digit). -/
  name : α → String

/-- Whose form this is (`FilerRole`). `SecondaryFiler` requires a joint return. -/
inductive FilerRole where
  /-- Constructor `primaryFiler`. -/
  | primaryFiler
  /-- Constructor `secondaryFiler`. -/
  | secondaryFiler
  deriving DecidableEq, Repr, Inhabited

/-- Catala `Form_w2s.CombatPayElection`. -/
inductive CombatPayElection where
  /-- Constructor `noCombatPay`. -/
  | noCombatPay
  /-- Constructor `usePrimaryCombatPay`. -/
  | usePrimaryCombatPay
  /-- Constructor `useSpouseCombatPay`. -/
  | useSpouseCombatPay
  /-- Constructor `useBothCombatPay`. -/
  | useBothCombatPay
  /-- Constructor `usePrimaryNotSpouseCombatPay`. -/
  | usePrimaryNotSpouseCombatPay
  /-- Constructor `useSpouseNotPrimaryCombatPay`. -/
  | useSpouseNotPrimaryCombatPay
  deriving DecidableEq, Repr, Inhabited

/-- Who did something (`was_k12_educators`, `paid_with_former_spouse`). -/
inductive WhoDid where
  /-- Constructor `tpDid`. -/
  | tpDid
  /-- Constructor `spouseDid`. -/
  | spouseDid
  /-- Constructor `bothDid`. -/
  | bothDid
  /-- Constructor `neither`. -/
  | neither
  deriving DecidableEq, Repr, Inhabited

/-- One character of 1099-R box 7 (`Other` is every other character). -/
inductive CodeChar where
  /-- Constructor `c2`. -/
  | c2
  /-- Constructor `c4`. -/
  | c4
  /-- Constructor `c7`. -/
  | c7
  /-- Constructor `b`. -/
  | b
  /-- Constructor `g`. -/
  | g
  /-- Constructor `h`. -/
  | h
  /-- Constructor `other`. -/
  | other
  deriving DecidableEq, Repr, Inhabited

/-- W-2 box 12 code letters accepted by the schema (no `I`, `O`, `U`, `X`). -/
inductive Box12Code where
  /-- Constructor `a`. -/
  | a
  /-- Constructor `b`. -/
  | b
  /-- Constructor `c`. -/
  | c
  /-- Constructor `d`. -/
  | d
  /-- Constructor `e`. -/
  | e
  /-- Constructor `f`. -/
  | f
  /-- Constructor `g`. -/
  | g
  /-- Constructor `h`. -/
  | h
  /-- Constructor `j`. -/
  | j
  /-- Constructor `k`. -/
  | k
  /-- Constructor `l`. -/
  | l
  /-- Constructor `m`. -/
  | m
  /-- Constructor `n`. -/
  | n
  /-- Constructor `p`. -/
  | p
  /-- Constructor `q`. -/
  | q
  /-- Constructor `r`. -/
  | r
  /-- Constructor `s`. -/
  | s
  /-- Constructor `t`. -/
  | t
  /-- Constructor `v`. -/
  | v
  /-- Constructor `w`. -/
  | w
  /-- Constructor `y`. -/
  | y
  /-- Constructor `z`. -/
  | z
  /-- Constructor `aa`. -/
  | aa
  /-- Constructor `bb`. -/
  | bb
  /-- Constructor `dd`. -/
  | dd
  /-- Constructor `ee`. -/
  | ee
  /-- Constructor `ff`. -/
  | ff
  /-- Constructor `gg`. -/
  | gg
  /-- Constructor `hh`. -/
  | hh
  /-- Constructor `ii`. -/
  | ii
  deriving DecidableEq, Repr, Inhabited

instance : ApiEnum FilingStatus := ⟨FilingStatus.all, FilingStatus.catalaName⟩

instance : ApiEnum FilerRole where
  all := [.primaryFiler, .secondaryFiler]
  name | .primaryFiler => "PrimaryFiler" | .secondaryFiler => "SecondaryFiler"

instance : ApiEnum CombatPayElection where
  all := [.noCombatPay, .usePrimaryCombatPay, .useSpouseCombatPay, .useBothCombatPay,
    .usePrimaryNotSpouseCombatPay, .useSpouseNotPrimaryCombatPay]
  name
    | .noCombatPay => "NoCombatPay" | .usePrimaryCombatPay => "UsePrimaryCombatPay"
    | .useSpouseCombatPay => "UseSpouseCombatPay" | .useBothCombatPay => "UseBothCombatPay"
    | .usePrimaryNotSpouseCombatPay => "UsePrimaryNotSpouseCombatPay"
    | .useSpouseNotPrimaryCombatPay => "UseSpouseNotPrimaryCombatPay"

instance : ApiEnum WhoDid where
  all := [.tpDid, .spouseDid, .bothDid, .neither]
  name | .tpDid => "TpDid" | .spouseDid => "SpouseDid" | .bothDid => "BothDid" | .neither => "Neither"

instance : ApiEnum CodeChar where
  all := [.c2, .c4, .c7, .b, .g, .h, .other]
  name | .c2 => "2" | .c4 => "4" | .c7 => "7" | .b => "B" | .g => "G" | .h => "H"
       | .other => "Other"

instance : ApiEnum Box12Code where
  all := [.a, .b, .c, .d, .e, .f, .g, .h, .j, .k, .l, .m, .n, .p, .q, .r, .s, .t, .v, .w, .y,
    .z, .aa, .bb, .dd, .ee, .ff, .gg, .hh, .ii]
  name
    | .a => "A" | .b => "B" | .c => "C" | .d => "D" | .e => "E" | .f => "F" | .g => "G"
    | .h => "H" | .j => "J" | .k => "K" | .l => "L" | .m => "M" | .n => "N" | .p => "P"
    | .q => "Q" | .r => "R" | .s => "S" | .t => "T" | .v => "V" | .w => "W" | .y => "Y"
    | .z => "Z" | .aa => "AA" | .bb => "BB" | .dd => "DD" | .ee => "EE" | .ff => "FF"
    | .gg => "GG" | .hh => "HH" | .ii => "II"

/-- Per-filer answers the standard deduction needs (`FilerFlags`). -/
structure FilerFlags where
  /-- Property `is_blind`. -/
  isBlind : Bool := false
  /-- Property `age65_or_older`. -/
  age65OrOlder : Bool := false
  /-- Property `can_be_claimed_as_dependent`. -/
  canBeClaimedAsDependent : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- `filers`: each side is absent or a flags object. -/
structure Filers where
  /-- Property `primary`. -/
  primary : Option FilerFlags := none
  /-- Property `secondary`. -/
  secondary : Option FilerFlags := none
  deriving DecidableEq, Repr, Inhabited

/-- `filing_details`. `treatAsMfs = none` means "filing status is separate". -/
structure FilingDetails where
  /-- Property `treat_as_mfs`. -/
  treatAsMfs : Option Bool := none
  /-- Property `is_widowed_in_tax_year`. -/
  isWidowedInTaxYear : Bool := false
  /-- Property `mfj_deceased_spouse_reached_age65`. -/
  mfjDeceasedSpouseReachedAge65 : Bool := false
  /-- Property `mfs_spouse65_or_older`. -/
  mfsSpouse65OrOlder : Bool := false
  /-- Property `mfs_spouse_provides_no_benefits`. -/
  mfsSpouseProvidesNoBenefits : Bool := false
  /-- Property `treat_filers_as_dependents`. -/
  treatFilersAsDependents : Bool := false
  /-- Property `has_foreign_accounts_or_trusts`. -/
  hasForeignAccountsOrTrusts : Bool := false
  /-- Property `combat_pay_election`. -/
  combatPayElection : CombatPayElection := .noCombatPay
  deriving DecidableEq, Repr, Inhabited

/-- W-2 box 12: the codes present, in the order given (JSON keys are unique). -/
structure Box12 where
  /-- Property `entries`. -/
  entries : List (Box12Code × Int) := []
  deriving DecidableEq, Repr, Inhabited

/-- One Form W-2. -/
structure FormW2 where
  /-- Property `filer`. -/
  filer : FilerRole
  /-- Property `wages`. -/
  wages : Int
  /-- Property `federal_withholding`. -/
  federalWithholding : Int := 0
  /-- Property `oasdi_wages`. -/
  oasdiWages : Int := 0
  /-- Property `oasdi_withholding`. -/
  oasdiWithholding : Int := 0
  /-- Property `medicare_wages`. -/
  medicareWages : Int := 0
  /-- Property `medicare_withholding`. -/
  medicareWithholding : Int := 0
  /-- Property `allocated_tips`. -/
  allocatedTips : Int := 0
  /-- Property `dependent_care_benefits`. -/
  dependentCareBenefits : Int := 0
  /-- Property `non_qualified_plans`. -/
  nonQualifiedPlans : Int := 0
  /-- Property `box12`. -/
  box12 : Box12 := {}
  /-- Property `statutory_employee`. -/
  statutoryEmployee : Bool := false
  /-- Property `third_party_sick_pay`. -/
  thirdPartySickPay : Bool := false
  /-- Property `plan457b_is_governmental`. -/
  plan457bIsGovernmental : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- One Form 1099-INT. -/
structure Form1099Int where
  /-- Property `filer`. -/
  filer : FilerRole
  /-- Property `has1099`. -/
  has1099 : Bool
  /-- Property `no1099_amount`. -/
  no1099Amount : Int := 0
  /-- Property `interest_income`. -/
  interestIncome : Int := 0
  /-- Property `early_withdrawal_penalty`. -/
  earlyWithdrawalPenalty : Int := 0
  /-- Property `government_bond_interest`. -/
  governmentBondInterest : Int := 0
  /-- Property `federal_tax_withheld`. -/
  federalTaxWithheld : Int := 0
  /-- Property `foreign_tax_paid`. -/
  foreignTaxPaid : Int := 0
  /-- Property `tax_exempt_interest`. -/
  taxExemptInterest : Int := 0
  /-- Property `private_activity_bond_interest`. -/
  privateActivityBondInterest : Int := 0
  /-- Property `market_discount`. -/
  marketDiscount : Int := 0
  /-- Property `bond_premium`. -/
  bondPremium : Int := 0
  /-- Property `bond_premium_treasury`. -/
  bondPremiumTreasury : Int := 0
  /-- Property `bond_premium_tax_exempt`. -/
  bondPremiumTaxExempt : Int := 0
  /-- Property `state_is_different`. -/
  stateIsDifferent : Bool := false
  /-- Property `state_tax_withheld`. -/
  stateTaxWithheld : Int := 0
  /-- Property `facta_filing_required`. -/
  factaFilingRequired : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- One Form 1099-G. -/
structure Form1099G where
  /-- Property `filer`. -/
  filer : FilerRole
  /-- Property `unemployment_compensation`. -/
  unemploymentCompensation : Int
  /-- Property `repaid_this_year_for_this_year`. -/
  repaidThisYearForThisYear : Int := 0
  /-- Property `repaid_this_year_for_earlier_year`. -/
  repaidThisYearForEarlierYear : Int := 0
  /-- Property `federal_tax_withheld`. -/
  federalTaxWithheld : Int := 0
  /-- Property `state_is_different`. -/
  stateIsDifferent : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- One Form 1099-MISC. -/
structure Form1099Misc where
  /-- Property `filer`. -/
  filer : FilerRole
  /-- Property `is_alaska_pfd`. -/
  isAlaskaPfd : Bool
  /-- Property `other_income`. -/
  otherIncome : Int
  /-- Property `federal_withholding`. -/
  federalWithholding : Int := 0
  deriving DecidableEq, Repr, Inhabited

/-- One Form 1099-R. -/
structure Form1099R where
  /-- Property `filer`. -/
  filer : FilerRole
  /-- Property `distribution_code`. -/
  distributionCode : List CodeChar
  /-- Property `gross_distribution`. -/
  grossDistribution : Int
  /-- Property `taxable_amount`. -/
  taxableAmount : Int
  /-- Property `taxable_amount_blank`. -/
  taxableAmountBlank : Bool := false
  /-- Property `taxable_amount_not_determined`. -/
  taxableAmountNotDetermined : Bool := false
  /-- Property `total_distribution`. -/
  totalDistribution : Bool := false
  /-- Property `capital_gain`. -/
  capitalGain : Int := 0
  /-- Property `federal_withholding`. -/
  federalWithholding : Int := 0
  /-- Property `net_appreciation`. -/
  netAppreciation : Int := 0
  /-- Property `ira_sep_simple`. -/
  iraSepSimple : Bool := false
  /-- Property `other_dollar`. -/
  otherDollar : Int := 0
  /-- Property `other_percentage_nonzero`. -/
  otherPercentageNonzero : Bool := false
  /-- Property `percentage_total_distribution_nonzero`. -/
  percentageTotalDistributionNonzero : Bool := false
  /-- Property `amount_allocable_to_irr`. -/
  amountAllocableToIrr : Int := 0
  /-- Property `facta_filing_requirement`. -/
  factaFilingRequirement : Bool := false
  /-- Property `state_tax_withheld`. -/
  stateTaxWithheld : Int := 0
  /-- Property `payer_state_is_different`. -/
  payerStateIsDifferent : Bool := false
  /-- Property `has_death_benefit_payment_date`. -/
  hasDeathBenefitPaymentDate : Bool := false
  /-- Property `is_indirect_rollover`. -/
  isIndirectRollover : Bool := false
  /-- Property `is_distribution_from_military_retirement_plan`. -/
  isDistributionFromMilitaryRetirementPlan : Bool := false
  /-- Property `qualified_disaster_distribution`. -/
  qualifiedDisasterDistribution : Bool := false
  /-- Property `public_safety_officer`. -/
  publicSafetyOfficer : Bool := false
  /-- Property `public_safety_officer_premiums`. -/
  publicSafetyOfficerPremiums : Bool := false
  /-- Property `recipient_date_of_birth`. -/
  recipientDateOfBirth : Option Date := none
  deriving DecidableEq, Repr, Inhabited

/-- `social_security`: `netBenefits` (box 5 of each SSA-1099) may be negative. -/
structure SocialSecurity where
  /-- Property `net_benefits`. -/
  netBenefits : List Int
  /-- Property `lived_apart_all_year`. -/
  livedApartAllYear : Bool := false
  deriving DecidableEq, Repr, Inhabited

/-- `adjustments.educator_expenses`. -/
structure EducatorExpenses where
  /-- Property `was_k12_educators`. -/
  wasK12Educators : WhoDid
  /-- Property `primary_expenses`. -/
  primaryExpenses : Int := 0
  /-- Property `secondary_expenses`. -/
  secondaryExpenses : Int := 0
  deriving DecidableEq, Repr, Inhabited

/-- `adjustments.student_loan_interest`. -/
structure StudentLoanInterest where
  /-- Property `had_payments`. -/
  hadPayments : Bool
  /-- Property `loans_qualify`. -/
  loansQualify : Bool := false
  /-- Property `interest_amount`. -/
  interestAmount : Int := 0
  deriving DecidableEq, Repr, Inhabited

/-- `adjustments`. -/
structure Adjustments where
  /-- Property `educator_expenses`. -/
  educatorExpenses : Option EducatorExpenses := none
  /-- Property `student_loan_interest`. -/
  studentLoanInterest : Option StudentLoanInterest := none
  deriving DecidableEq, Repr, Inhabited

/-- `estimated_payments`. -/
structure EstimatedPayments where
  /-- Property `paid_estimated_taxes_or_from_last_year`. -/
  paidEstimatedTaxesOrFromLastYear : Bool
  /-- Property `amount`. -/
  amount : Int := 0
  /-- Property `paid_under_different_name`. -/
  paidUnderDifferentName : Bool := false
  /-- Property `paid_with_former_spouse`. -/
  paidWithFormerSpouse : Option WhoDid := none
  deriving DecidableEq, Repr, Inhabited

/-- The validated-shape request body (`POST /calculate`). A value of this type
has the right shape and types; whether its numbers, list sizes and cross-field
rules hold is `Request.Valid` (`UsTax/Api/Spec.lean`). Absent list = empty. -/
structure Request where
  /-- Property `filing_status`. -/
  filingStatus : FilingStatus
  /-- Property `filers`. -/
  filers : Filers := {}
  /-- Property `filing_details`. -/
  filingDetails : FilingDetails := {}
  /-- Property `w2s`. -/
  w2s : List FormW2 := []
  /-- Property `interest_reports`. -/
  interestReports : List Form1099Int := []
  /-- Property `form1099g`. -/
  form1099g : List Form1099G := []
  /-- Property `form1099misc`. -/
  form1099misc : List Form1099Misc := []
  /-- Property `form1099r`. -/
  form1099r : List Form1099R := []
  /-- Property `social_security`. -/
  socialSecurity : Option SocialSecurity := none
  /-- Property `adjustments`. -/
  adjustments : Adjustments := {}
  /-- Property `estimated_payments`. -/
  estimatedPayments : Option EstimatedPayments := none
  deriving DecidableEq, Repr, Inhabited

/-! ### Money fields

Each record lists its money amounts with the schema property name (the last
segment of the error path). Every `NonNegMoney` box is here, so the range rule
in `Spec.lean` covers it; `socialSecurity.netBenefits` is the only signed one. -/

/-- Box 12 amounts, keyed by code letter. -/
def Box12.moneyFields (b : Box12) : List (String × Int) :=
  b.entries.map fun (code, n) => (ApiEnum.name code, n)

/-- `NonNegMoney` properties of a W-2 (box 12 is separate). -/
def FormW2.moneyFields (w : FormW2) : List (String × Int) :=
  [("wages", w.wages), ("federal_withholding", w.federalWithholding),
   ("oasdi_wages", w.oasdiWages), ("oasdi_withholding", w.oasdiWithholding),
   ("medicare_wages", w.medicareWages), ("medicare_withholding", w.medicareWithholding),
   ("allocated_tips", w.allocatedTips), ("dependent_care_benefits", w.dependentCareBenefits),
   ("non_qualified_plans", w.nonQualifiedPlans)]

/-- `NonNegMoney` properties of a 1099-INT. -/
def Form1099Int.moneyFields (f : Form1099Int) : List (String × Int) :=
  [("no_1099_amount", f.no1099Amount), ("interest_income", f.interestIncome),
   ("early_withdrawal_penalty", f.earlyWithdrawalPenalty),
   ("government_bond_interest", f.governmentBondInterest),
   ("federal_tax_withheld", f.federalTaxWithheld), ("foreign_tax_paid", f.foreignTaxPaid),
   ("tax_exempt_interest", f.taxExemptInterest),
   ("private_activity_bond_interest", f.privateActivityBondInterest),
   ("market_discount", f.marketDiscount), ("bond_premium", f.bondPremium),
   ("bond_premium_treasury", f.bondPremiumTreasury),
   ("bond_premium_tax_exempt", f.bondPremiumTaxExempt),
   ("state_tax_withheld", f.stateTaxWithheld)]

/-- `NonNegMoney` properties of a 1099-G. -/
def Form1099G.moneyFields (f : Form1099G) : List (String × Int) :=
  [("unemployment_compensation", f.unemploymentCompensation),
   ("repaid_this_year_for_this_year", f.repaidThisYearForThisYear),
   ("repaid_this_year_for_earlier_year", f.repaidThisYearForEarlierYear),
   ("federal_tax_withheld", f.federalTaxWithheld)]

/-- `NonNegMoney` properties of a 1099-MISC. -/
def Form1099Misc.moneyFields (f : Form1099Misc) : List (String × Int) :=
  [("other_income", f.otherIncome), ("federal_withholding", f.federalWithholding)]

/-- `NonNegMoney` properties of a 1099-R. -/
def Form1099R.moneyFields (f : Form1099R) : List (String × Int) :=
  [("gross_distribution", f.grossDistribution), ("taxable_amount", f.taxableAmount),
   ("capital_gain", f.capitalGain), ("federal_withholding", f.federalWithholding),
   ("net_appreciation", f.netAppreciation), ("other_dollar", f.otherDollar),
   ("amount_allocable_to_irr", f.amountAllocableToIrr),
   ("state_tax_withheld", f.stateTaxWithheld)]

/-- `NonNegMoney` properties of the educator expenses. -/
def EducatorExpenses.moneyFields (e : EducatorExpenses) : List (String × Int) :=
  [("primary_expenses", e.primaryExpenses), ("secondary_expenses", e.secondaryExpenses)]

/-- `NonNegMoney` properties of the student loan interest. -/
def StudentLoanInterest.moneyFields (s : StudentLoanInterest) : List (String × Int) :=
  [("interest_amount", s.interestAmount)]

/-- `NonNegMoney` properties of the estimated payments. -/
def EstimatedPayments.moneyFields (e : EstimatedPayments) : List (String × Int) :=
  [("amount", e.amount)]

end UsTax.Api
