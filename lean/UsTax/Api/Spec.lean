import UsTax.Api.Types

/-!
# What a valid request is (issue #51; seed of issue #69)

This file is the **specification** of the validation layer: the named
predicate `Request.Valid`, written to be read against `docs/api.md`
("Money: integer cents" and "Validation policy"), with no reference to the
checking code. `UsTax/Api/Validate.lean` computes error lists;
`UsTax/Api/Lemmas.lean` proves

* `Request.validate r = [] ↔ r.Valid` (so `Valid` is decidable), and
* `parseRequest s = .ok r → r.Valid` (`parseRequest_sound`).

What `Valid` says, on top of the shape the typed `Request` already has:

1. **Money caps.** Every `NonNegMoney` box is in `0 .. 10^13` cents; the one
   signed `Money` (`social_security.net_benefits`) is in `-10^13 .. 10^13`.
   Which fields those are, is in the `moneyFields` functions of `Types.lean`.
2. **List sizes.** At most 20 items in each of `w2s`, `interest_reports`,
   `form_1099g`, `form_1099misc`, `form_1099r`; at most 4 `net_benefits` and
   at most 4 `distribution_code` characters.
3. **Filer roles.** `SecondaryFiler` (on any form) and `filers.secondary` only
   when `filing_status` is `MarriedFilingJointly`.
4. **Dates.** Every date (1099-R `recipient_date_of_birth`, filers' `date_of_birth`,
   `filing_answers.secondary_filer_date_of_death`, dependents' `date_of_birth`, the
   Form 1095-A policy dates) is a real calendar date.
5. **Schema 1.2.0 sections.** `dependents` at most 20; every `NonNegMoney` box and
   money list of `filers.*`, `filing_answers`, `dependents[]`, `credits`, `cdcc`,
   `premium_tax_credit`, `adjustments.hsa` in `0 .. 10^13` with the list sizes of the
   schema (`deemed_income_month_earnings` 20, 1095-A lists 12); `coverage_months`
   entries in `1 .. 12`; `months_lived_with_tp_in_us` in `0 .. 12`;
   `social_security.federal_tax_withheld` no longer than `net_benefits`;
   `SecondaryFiler` on an HSA distribution only on a joint return.

Not here, because the typed `Request` cannot violate it: types, enumerations,
required fields, unknown fields and integer-ness of money (the decoder
rejects them), `api_version` = 1 and `tax_year` = 2024 (checked, not stored).
`duplicate_person` is reserved: the contract does not define it beyond the
name (reported in the pull request).
-/

namespace UsTax.Api

open UsTax

/-- The cap on any money amount: 10^13 cents, a hundred billion dollars. -/
def moneyCap : Int := 10000000000000

/-- A `NonNegMoney` value: `0 ≤ n ≤ 10^13`. -/
def NonNegOk (n : Int) : Prop := 0 ≤ n ∧ n ≤ moneyCap

/-- A signed `Money` value: `|n| ≤ 10^13`. -/
def SignedOk (n : Int) : Prop := -moneyCap ≤ n ∧ n ≤ moneyCap

/-- At most this many items in a list of forms. -/
def maxForms : Nat := 20
/-- At most this many `social_security.net_benefits`. -/
def maxNetBenefits : Nat := 4
/-- At most this many `distribution_code` characters. -/
def maxCodeChars : Nat := 4

/-- A bounded integer (a month number, a count). -/
def IntRange (lo hi n : Int) : Prop := lo ≤ n ∧ n ≤ hi

/-- Every listed `(name, amount)` is a `NonNegMoney`. -/
def AllNonNeg (kvs : List (String × Int)) : Prop := ∀ kv ∈ kvs, NonNegOk kv.2

/-- A form of this role may appear on a return with this filing status. -/
def RoleAllowed (st : FilingStatus) (r : FilerRole) : Prop :=
  r = .secondaryFiler → st = .marriedFilingJointly

/-- A W-2 is valid on a return with filing status `st`. -/
def FormW2.Valid (st : FilingStatus) (w : FormW2) : Prop :=
  AllNonNeg w.moneyFields ∧ AllNonNeg w.box12.moneyFields ∧ RoleAllowed st w.filer

/-- A 1099-INT is valid on a return with filing status `st`. -/
def Form1099Int.Valid (st : FilingStatus) (f : Form1099Int) : Prop :=
  AllNonNeg f.moneyFields ∧ RoleAllowed st f.filer

/-- A 1099-G is valid on a return with filing status `st`. -/
def Form1099G.Valid (st : FilingStatus) (f : Form1099G) : Prop :=
  AllNonNeg f.moneyFields ∧ RoleAllowed st f.filer

/-- A 1099-MISC is valid on a return with filing status `st`. -/
def Form1099Misc.Valid (st : FilingStatus) (f : Form1099Misc) : Prop :=
  AllNonNeg f.moneyFields ∧ RoleAllowed st f.filer

/-- A 1099-R is valid on a return with filing status `st`: at most 4 code
characters, a real date of birth if given. -/
def Form1099R.Valid (st : FilingStatus) (f : Form1099R) : Prop :=
  AllNonNeg f.moneyFields ∧ RoleAllowed st f.filer ∧
  f.distributionCode.length ≤ maxCodeChars ∧
  (∀ d, f.recipientDateOfBirth = some d → d.Valid)

/-- Social Security: at most 4 signed amounts; at most 4 `NonNegMoney` withheld
amounts, and no more of them than benefit amounts (`docs/api.md`, "Validation
policy"). -/
def SocialSecurity.Valid (s : SocialSecurity) : Prop :=
  s.netBenefits.length ≤ maxNetBenefits ∧ (∀ n ∈ s.netBenefits, SignedOk n) ∧
  (s.federalTaxWithheld.length ≤ maxNetBenefits ∧ ∀ n ∈ s.federalTaxWithheld, NonNegOk n) ∧
  s.federalTaxWithheld.length ≤ s.netBenefits.length

/-! ### Sections added in schema 1.2.0 (generated from `api/schema.json`, then
checked in: `Valid` of each object lists its `NonNegMoney` boxes, list sizes and
integer ranges, calendar dates, and nested sections) -/

/-- `DisabilityAnswers` is valid (schema 1.2.0). -/
def DisabilityAnswers.Valid (s : DisabilityAnswers) : Prop :=
  AllNonNeg s.moneyFields

/-- `HsaFilerAnswers` is valid (schema 1.2.0). -/
def HsaFilerAnswers.Valid (s : HsaFilerAnswers) : Prop :=
  AllNonNeg s.moneyFields

/-- `CdccFilerAnswers` is valid (schema 1.2.0). -/
def CdccFilerAnswers.Valid (s : CdccFilerAnswers) : Prop :=
  AllNonNeg s.moneyFields ∧
  (s.deemedIncomeMonthEarnings.length ≤ 20 ∧ ∀ n ∈ s.deemedIncomeMonthEarnings, NonNegOk n)

/-- `FilerFlags` is valid (schema 1.2.0). -/
def FilerFlags.Valid (s : FilerFlags) : Prop :=
  (∀ d, s.dateOfBirth = some d → d.Valid) ∧
  (∀ x, s.disability = some x → x.Valid) ∧
  (∀ x, s.hsa = some x → x.Valid) ∧
  (∀ x, s.cdcc = some x → x.Valid)

/-- `FilingAnswers` is valid (schema 1.2.0). -/
def FilingAnswers.Valid (s : FilingAnswers) : Prop :=
  s.secondaryFilerDateOfDeath.Valid

/-- `CdccMemberAnswers` is valid (schema 1.2.0). -/
def CdccMemberAnswers.Valid (s : CdccMemberAnswers) : Prop :=
  AllNonNeg s.moneyFields

/-- `Dependent` is valid (schema 1.2.0). -/
def Dependent.Valid (s : Dependent) : Prop :=
  AllNonNeg s.moneyFields ∧
  s.dateOfBirth.Valid ∧
  IntRange 0 12 s.monthsLivedWithTpInUs ∧
  (∀ x, s.cdcc = some x → x.Valid)

/-- `HsaDistribution` is valid on a return with filing status `st` (schema 1.2.0). -/
def HsaDistribution.Valid (st : FilingStatus) (s : HsaDistribution) : Prop :=
  AllNonNeg s.moneyFields ∧
  RoleAllowed st s.filer

/-- `HsaInput` is valid on a return with filing status `st` (schema 1.2.0). -/
def HsaInput.Valid (st : FilingStatus) (s : HsaInput) : Prop :=
  (s.hsaDistributions.length ≤ 20 ∧ ∀ x ∈ s.hsaDistributions, x.Valid st)

/-- `CreditAnswers` is valid (schema 1.2.0). -/
def CreditAnswers.Valid (s : CreditAnswers) : Prop :=
  AllNonNeg s.moneyFields

/-- `CdccInput` is valid (schema 1.2.0). -/
def CdccInput.Valid (s : CdccInput) : Prop :=
  AllNonNeg s.moneyFields

/-- `Form1095A` is valid (schema 1.2.0). -/
def Form1095A.Valid (s : Form1095A) : Prop :=
  AllNonNeg s.moneyFields ∧
  s.writablePolicyStartDate.Valid ∧
  s.writablePolicyEndDate.Valid ∧
  (s.coverageMonths.length ≤ 12 ∧ ∀ n ∈ s.coverageMonths, IntRange 1 12 n) ∧
  (s.writablePtcMonthlyPremium.length ≤ 12 ∧ ∀ n ∈ s.writablePtcMonthlyPremium, NonNegOk n) ∧
  (s.writablePtcMonthlySlcspPremium.length ≤ 12 ∧ ∀ n ∈ s.writablePtcMonthlySlcspPremium, NonNegOk n) ∧
  (s.writablePtcMonthlyAptcPremium.length ≤ 12 ∧ ∀ n ∈ s.writablePtcMonthlyAptcPremium, NonNegOk n)

/-- `PtcInput` is valid (schema 1.2.0). -/
def PtcInput.Valid (s : PtcInput) : Prop :=
  (s.form1095As.length ≤ 20 ∧ ∀ x ∈ s.form1095As, x.Valid)


/-- The rules that predate schema 1.2.0 (items 1 to 4 of the module docstring
for the schema 1.0 sections). -/
def Request.ValidBase (r : Request) : Prop :=
  (r.filers.secondary ≠ none → r.filingStatus = .marriedFilingJointly) ∧
  r.w2s.length ≤ maxForms ∧ (∀ w ∈ r.w2s, w.Valid r.filingStatus) ∧
  r.interestReports.length ≤ maxForms ∧ (∀ f ∈ r.interestReports, f.Valid r.filingStatus) ∧
  r.form1099g.length ≤ maxForms ∧ (∀ f ∈ r.form1099g, f.Valid r.filingStatus) ∧
  r.form1099misc.length ≤ maxForms ∧ (∀ f ∈ r.form1099misc, f.Valid r.filingStatus) ∧
  r.form1099r.length ≤ maxForms ∧ (∀ f ∈ r.form1099r, f.Valid r.filingStatus) ∧
  (∀ s, r.socialSecurity = some s → s.Valid) ∧
  (∀ e, r.adjustments.educatorExpenses = some e → AllNonNeg e.moneyFields) ∧
  (∀ s, r.adjustments.studentLoanInterest = some s → AllNonNeg s.moneyFields) ∧
  (∀ e, r.estimatedPayments = some e → AllNonNeg e.moneyFields)

/-- The rules of the sections added in schema 1.2.0 (item 5 of the module docstring). -/
def Request.ValidSections (r : Request) : Prop :=
  (∀ f, r.filers.primary = some f → f.Valid) ∧
  (∀ f, r.filers.secondary = some f → f.Valid) ∧
  (∀ h, r.adjustments.hsa = some h → h.Valid r.filingStatus) ∧
  (∀ a, r.filingAnswers = some a → a.Valid) ∧
  r.dependents.length ≤ maxForms ∧ (∀ d ∈ r.dependents, d.Valid) ∧
  (∀ c, r.credits = some c → c.Valid) ∧
  (∀ c, r.cdcc = some c → c.Valid) ∧
  (∀ x, r.premiumTaxCredit = some x → x.Valid)

/-- The request is valid: every rule of the list in the module docstring. -/
def Request.Valid (r : Request) : Prop := r.ValidBase ∧ r.ValidSections

/-! ### Named examples (CLAUDE.md section 4: hypotheses satisfiable, bad outputs rejected) -/

/-- `api/examples/single-w2-50k.request.json`. -/
def exampleSingleW2 : Request :=
  { filingStatus := .single,
    w2s := [{ filer := .primaryFiler, wages := 5000000, federalWithholding := 0 }] }

/-- A W-2 over the cap. -/
def exampleOverCap : Request :=
  { exampleSingleW2 with w2s := [{ filer := .primaryFiler, wages := moneyCap + 1 }] }

/-- A negative wage. -/
def exampleNegativeWages : Request :=
  { exampleSingleW2 with w2s := [{ filer := .primaryFiler, wages := -1 }] }

/-- A secondary-filer W-2 on a single return. -/
def exampleSecondaryOnSingle : Request :=
  { exampleSingleW2 with w2s := [{ filer := .secondaryFiler, wages := 1 }] }

/-- 21 W-2s. -/
def exampleTooMany : Request :=
  { exampleSingleW2 with w2s := List.replicate 21 { filer := .primaryFiler, wages := 1 } }

/-- A joint return with a child (`api/examples/family-mfj-two-kids.request.json`, one child). -/
def exampleHousehold : Request :=
  { filingStatus := .marriedFilingJointly,
    filers := { primary := some { dateOfBirth := some { year := 1986, month := 4, day := 12 } } },
    dependents := [{ relationship := .biologicalChild,
                     dateOfBirth := { year := 2016, month := 3, day := 1 }, tinType := .ssn }] }

/-- The same child, living with the taxpayer 13 months of the year. -/
def exampleThirteenMonths : Request :=
  { exampleHousehold with
    dependents := [{ relationship := .biologicalChild,
                     dateOfBirth := { year := 2016, month := 3, day := 1 }, tinType := .ssn,
                     monthsLivedWithTpInUs := 13 }] }

/-- The same child, born on a day that does not exist. -/
def exampleImpossibleBirthday : Request :=
  { exampleHousehold with
    dependents := [{ relationship := .biologicalChild,
                     dateOfBirth := { year := 2023, month := 2, day := 30 }, tinType := .ssn }] }

/-- More federal tax withheld amounts than benefit amounts. -/
def exampleWithheldTooLong : Request :=
  { exampleSingleW2 with
    socialSecurity := some { netBenefits := [100], federalTaxWithheld := [1, 2] } }

end UsTax.Api
