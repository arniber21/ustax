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

/-- Errors of one `NonNegMoney` property `k` of the object at `p`. -/
def nonNegErrs (p : String) (kv : String × Int) : List FieldError :=
  if kv.2 < 0 then [⟨child p kv.1, .range, "must be >= 0"⟩]
  else if kv.2 > moneyCap then [⟨child p kv.1, .range, "must be <= 10000000000000"⟩]
  else []

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

/-- Errors of a date of birth. -/
def dateErrs (p : String) : Option Date → List FieldError
  | some d => if d.Valid then [] else [⟨child p "recipient_date_of_birth", .invalidDate,
      "not a calendar date"⟩]
  | none => []

/-- 1099-R errors. -/
def Form1099R.errs (st : FilingStatus) (p : String) (f : Form1099R) : List FieldError :=
  moneyErrs p f.moneyFields ++ roleErrs st p f.filer ++
  (if f.distributionCode.length ≤ maxCodeChars then []
   else [⟨child p "distribution_code", .tooManyItems,
     s!"must have at most {maxCodeChars} items"⟩]) ++
  dateErrs p f.recipientDateOfBirth

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
  (if s.netBenefits.length ≤ maxNetBenefits then []
   else [⟨q, .tooManyItems, s!"must have at most {maxNetBenefits} items"⟩]) ++
  netBenefitErrs q 0 s.netBenefits

/-- Errors of an optional section, with `f` run on the value if present. -/
def optErrs {α : Type} (f : α → List FieldError) : Option α → List FieldError
  | some x => f x
  | none => []

/-- Every violation of `Request.Valid`, in document order. -/
def Request.validate (r : Request) : List FieldError :=
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

end UsTax.Api
