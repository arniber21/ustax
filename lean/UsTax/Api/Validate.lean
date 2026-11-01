import UsTax.Api.Spec
import UsTax.Api.Error

/-!
# Typed request to error list (issue #51), phase 2: ranges and rules

`Request.validate r` lists every violation of `Request.Valid`
(`UsTax/Api/Spec.lean`) as a `FieldError` with its RFC 6901 path, in document
order. The empty list is exactly `Valid` (`validate_eq_nil_iff`, in
`Lemmas.lean`). Messages are the ones in `api/fixtures/error-400-*.response.json`.
-/

namespace UsTax.Api

open UsTax

/-- Errors of a `NonNegMoney` value at exactly the path `q`. -/
def nonNegAt (q : String) (n : Int) : List FieldError :=
  if n < 0 then [⟨q, .range, "must be >= 0"⟩]
  else if n > moneyCap then [⟨q, .range, "must be <= 10000000000000"⟩]
  else []

/-- Errors of one `NonNegMoney` property `k` of the object at `p`. -/
def nonNegErrs (p : String) (kv : String × Int) : List FieldError :=
  nonNegAt (child p kv.1) kv.2

/-- Errors of an integer that must lie in `lo .. hi`, at the path `q`. -/
def rangeAt (lo hi : Int) (q : String) (n : Int) : List FieldError :=
  if n < lo then [⟨q, .range, s!"must be >= {lo}"⟩]
  else if n > hi then [⟨q, .range, s!"must be <= {hi}"⟩]
  else []

/-- Errors of a date at the path `q`: it must exist in the calendar. -/
def dateAt (q : String) (d : Date) : List FieldError :=
  if d.Valid then [] else [⟨q, .invalidDate, "not a calendar date"⟩]

/-- Errors of an optional value at the path `q`, with `f q x` run on the value if present. -/
def optAt {α : Type} (q : String) (f : String → α → List FieldError) : Option α → List FieldError
  | some x => f q x
  | none => []

/-- Errors of a record's `NonNegMoney` properties. -/
def moneyErrs (p : String) (kvs : List (String × Int)) : List FieldError :=
  kvs.flatMap (nonNegErrs p)

/-- Errors of a form's `filer` property. -/
def roleErrs (st : FilingStatus) (p : String) (r : FilerRole) : List FieldError :=
  if r = .secondaryFiler ∧ st ≠ .marriedFilingJointly then
    [⟨child p "filer", .filerNotAllowed,
      "SecondaryFiler requires filing_status MarriedFilingJointly"⟩]
  else []

/-- Errors of every element of a list, each at `p/index`, counting from `i`. -/
def itemErrs {α : Type} (p : String) (f : String → α → List FieldError) :
    Nat → List α → List FieldError
  | _, [] => []
  | i, x :: xs => f (p ++ "/" ++ toString i) x ++ itemErrs p f (i + 1) xs

/-- Errors of a list of at most `limit` items, each checked by `f`. -/
def listErrs {α : Type} (p : String) (limit : Nat) (xs : List α)
    (f : String → α → List FieldError) : List FieldError :=
  (if xs.length ≤ limit then []
   else [⟨p, .tooManyItems, s!"must have at most {limit} items"⟩]) ++ itemErrs p f 0 xs

/-- W-2 errors. -/
def FormW2.errs (st : FilingStatus) (p : String) (w : FormW2) : List FieldError :=
  moneyErrs p w.moneyFields ++ moneyErrs (child p "box12") w.box12.moneyFields ++
  roleErrs st p w.filer

/-- 1099-INT errors. -/
def Form1099Int.errs (st : FilingStatus) (p : String) (f : Form1099Int) : List FieldError :=
  moneyErrs p f.moneyFields ++ roleErrs st p f.filer

/-- 1099-G errors. -/
def Form1099G.errs (st : FilingStatus) (p : String) (f : Form1099G) : List FieldError :=
  moneyErrs p f.moneyFields ++ roleErrs st p f.filer

/-- 1099-MISC errors. -/
def Form1099Misc.errs (st : FilingStatus) (p : String) (f : Form1099Misc) : List FieldError :=
  moneyErrs p f.moneyFields ++ roleErrs st p f.filer

/-- 1099-R errors. -/
def Form1099R.errs (st : FilingStatus) (p : String) (f : Form1099R) : List FieldError :=
  moneyErrs p f.moneyFields ++ roleErrs st p f.filer ++
  (if f.distributionCode.length ≤ maxCodeChars then []
   else [⟨child p "distribution_code", .tooManyItems,
     s!"must have at most {maxCodeChars} items"⟩]) ++
  optAt (child p "recipient_date_of_birth") dateAt f.recipientDateOfBirth

/-- Errors of the signed `net_benefits` list. -/
def netBenefitErrs (p : String) : Nat → List Int → List FieldError
  | _, [] => []
  | i, n :: ns =>
    (if n < -moneyCap then [⟨p ++ "/" ++ toString i, .range, "must be >= -10000000000000"⟩]
     else if n > moneyCap then [⟨p ++ "/" ++ toString i, .range, "must be <= 10000000000000"⟩]
     else []) ++ netBenefitErrs p (i + 1) ns

/-- Social Security errors. -/
def SocialSecurity.errs (p : String) (s : SocialSecurity) : List FieldError :=
  let q := child p "net_benefits"
  let f := child p "federal_tax_withheld"
  (if s.netBenefits.length ≤ maxNetBenefits then []
   else [⟨q, .tooManyItems, s!"must have at most {maxNetBenefits} items"⟩]) ++
  (netBenefitErrs q 0 s.netBenefits ++
  (listErrs f maxNetBenefits s.federalTaxWithheld nonNegAt ++
  (if s.federalTaxWithheld.length ≤ s.netBenefits.length then []
   else [⟨f, .range, "must not have more items than net_benefits"⟩])))

/-- Errors of an optional section, with `f` run on the value if present. -/
def optErrs {α : Type} (f : α → List FieldError) : Option α → List FieldError
  | some x => f x
  | none => []

/-! ### Sections added in schema 1.2.0 (generated from `api/schema.json`, then checked in) -/

/-- Errors of `DisabilityAnswers` at `p`. -/
def DisabilityAnswers.errs (p : String) (s : DisabilityAnswers) : List FieldError :=
  moneyErrs p s.moneyFields

/-- Errors of `HsaFilerAnswers` at `p`. -/
def HsaFilerAnswers.errs (p : String) (s : HsaFilerAnswers) : List FieldError :=
  moneyErrs p s.moneyFields

/-- Errors of `CdccFilerAnswers` at `p`. -/
def CdccFilerAnswers.errs (p : String) (s : CdccFilerAnswers) : List FieldError :=
  moneyErrs p s.moneyFields ++
  (listErrs (child p "deemed_income_month_earnings") 20 s.deemedIncomeMonthEarnings nonNegAt)

/-- Errors of `FilerFlags` at `p`. -/
def FilerFlags.errs (p : String) (s : FilerFlags) : List FieldError :=
  optAt (child p "date_of_birth") dateAt s.dateOfBirth ++
  (optAt (child p "disability") DisabilityAnswers.errs s.disability ++
  (optAt (child p "hsa") HsaFilerAnswers.errs s.hsa ++
  (optAt (child p "cdcc") CdccFilerAnswers.errs s.cdcc)))

/-- Errors of `FilingAnswers` at `p`. -/
def FilingAnswers.errs (p : String) (s : FilingAnswers) : List FieldError :=
  dateAt (child p "secondary_filer_date_of_death") s.secondaryFilerDateOfDeath

/-- Errors of `CdccMemberAnswers` at `p`. -/
def CdccMemberAnswers.errs (p : String) (s : CdccMemberAnswers) : List FieldError :=
  moneyErrs p s.moneyFields

/-- Errors of `Dependent` at `p`. -/
def Dependent.errs (p : String) (s : Dependent) : List FieldError :=
  moneyErrs p s.moneyFields ++
  (dateAt (child p "date_of_birth") s.dateOfBirth ++
  (rangeAt 0 12 (child p "months_lived_with_tp_in_us") s.monthsLivedWithTpInUs ++
  (optAt (child p "cdcc") CdccMemberAnswers.errs s.cdcc)))

/-- Errors of `HsaDistribution` at `p`. -/
def HsaDistribution.errs (st : FilingStatus) (p : String) (s : HsaDistribution) : List FieldError :=
  moneyErrs p s.moneyFields ++
  (roleErrs st p s.filer)

/-- Errors of `HsaInput` at `p`. -/
def HsaInput.errs (st : FilingStatus) (p : String) (s : HsaInput) : List FieldError :=
  listErrs (child p "hsa_distributions") 20 s.hsaDistributions (HsaDistribution.errs st)

/-- Errors of `CreditAnswers` at `p`. -/
def CreditAnswers.errs (p : String) (s : CreditAnswers) : List FieldError :=
  moneyErrs p s.moneyFields

/-- Errors of `CdccInput` at `p`. -/
def CdccInput.errs (p : String) (s : CdccInput) : List FieldError :=
  moneyErrs p s.moneyFields

/-- Errors of `Form1095A` at `p`. -/
def Form1095A.errs (p : String) (s : Form1095A) : List FieldError :=
  moneyErrs p s.moneyFields ++
  (dateAt (child p "writable_policy_start_date") s.writablePolicyStartDate ++
  (dateAt (child p "writable_policy_end_date") s.writablePolicyEndDate ++
  (listErrs (child p "coverage_months") 12 s.coverageMonths (rangeAt 1 12) ++
  (listErrs (child p "writable_ptc_monthly_premium") 12 s.writablePtcMonthlyPremium nonNegAt ++
  (listErrs (child p "writable_ptc_monthly_slcsp_premium") 12 s.writablePtcMonthlySlcspPremium nonNegAt ++
  (listErrs (child p "writable_ptc_monthly_aptc_premium") 12 s.writablePtcMonthlyAptcPremium nonNegAt))))))

/-- Errors of `PtcInput` at `p`. -/
def PtcInput.errs (p : String) (s : PtcInput) : List FieldError :=
  listErrs (child p "form1095_as") 20 s.form1095As (Form1095A.errs)


/-- Every violation of `Request.ValidBase`, in document order. -/
def Request.validateBase (r : Request) : List FieldError :=
  let st := r.filingStatus
  (if r.filers.secondary ≠ none ∧ st ≠ .marriedFilingJointly
   then [⟨"/filers/secondary", .filerNotAllowed,
     "filers.secondary requires filing_status MarriedFilingJointly"⟩]
   else []) ++
  listErrs "/w2s" maxForms r.w2s (FormW2.errs st) ++
  listErrs "/interest_reports" maxForms r.interestReports (Form1099Int.errs st) ++
  listErrs "/form_1099g" maxForms r.form1099g (Form1099G.errs st) ++
  listErrs "/form_1099misc" maxForms r.form1099misc (Form1099Misc.errs st) ++
  listErrs "/form_1099r" maxForms r.form1099r (Form1099R.errs st) ++
  optErrs (SocialSecurity.errs "/social_security") r.socialSecurity ++
  optErrs (fun e => moneyErrs "/adjustments/educator_expenses" e.moneyFields)
    r.adjustments.educatorExpenses ++
  optErrs (fun s => moneyErrs "/adjustments/student_loan_interest" s.moneyFields)
    r.adjustments.studentLoanInterest ++
  optErrs (fun e => moneyErrs "/estimated_payments" e.moneyFields) r.estimatedPayments

/-- Every violation of `Request.ValidSections`, in document order. -/
def Request.validateSections (r : Request) : List FieldError :=
  optErrs (FilerFlags.errs "/filers/primary") r.filers.primary ++
  optErrs (FilerFlags.errs "/filers/secondary") r.filers.secondary ++
  optErrs (HsaInput.errs r.filingStatus "/adjustments/hsa") r.adjustments.hsa ++
  optErrs (FilingAnswers.errs "/filing_answers") r.filingAnswers ++
  listErrs "/dependents" maxForms r.dependents Dependent.errs ++
  optErrs (CreditAnswers.errs "/credits") r.credits ++
  optErrs (CdccInput.errs "/cdcc") r.cdcc ++
  optErrs (PtcInput.errs "/premium_tax_credit") r.premiumTaxCredit

/-- Every violation of `Request.Valid`, in document order. -/
def Request.validate (r : Request) : List FieldError :=
  r.validateBase ++ r.validateSections

end UsTax.Api
