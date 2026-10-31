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
4. **Dates.** A 1099-R `recipient_date_of_birth` is a real calendar date.

Not here, because the typed `Request` cannot violate it: types, enumerations,
required fields, unknown fields and integer-ness of money (the decoder
rejects them), `api_version` = 1 and `tax_year` = 2024 (checked, not stored).
`duplicate_person` is reserved until the household section lands.
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

/-- Social Security: at most 4 signed amounts. -/
def SocialSecurity.Valid (s : SocialSecurity) : Prop :=
  s.netBenefits.length ≤ maxNetBenefits ∧ ∀ n ∈ s.netBenefits, SignedOk n

/-- The request is valid: every rule of the list in the module docstring. -/
def Request.Valid (r : Request) : Prop :=
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

end UsTax.Api
