import UsTax.Api.Validate
import UsTax.Audit

/-!
# Soundness of the request validation layer (issue #51; seed of issue #69)

`Request.validate r = [] ↔ r.Valid` (`validate_eq_nil_iff`), hence `Valid` is
decidable and the validator is both sound and complete for it. The parser-level
statement `parseRequest_sound` is in `Parse.lean`, built on `validate_sound`.
-/

namespace UsTax.Api

open UsTax

theorem nonNegErrs_eq_nil (p : String) (kv : String × Int) :
    nonNegErrs p kv = [] ↔ NonNegOk kv.2 := by
  unfold nonNegErrs NonNegOk
  by_cases h1 : kv.2 < 0 <;> by_cases h2 : kv.2 > moneyCap <;> simp [h1, h2]
  all_goals omega

theorem moneyErrs_eq_nil (p : String) (kvs : List (String × Int)) :
    moneyErrs p kvs = [] ↔ AllNonNeg kvs := by
  simp [moneyErrs, AllNonNeg, nonNegErrs_eq_nil]

theorem roleErrs_eq_nil (st : FilingStatus) (p : String) (r : FilerRole) :
    roleErrs st p r = [] ↔ RoleAllowed st r := by
  unfold roleErrs RoleAllowed
  split <;> simp_all

theorem itemErrs_eq_nil {α : Type} {p : String} {f : String → α → List FieldError}
    {P : α → Prop} (hf : ∀ q x, f q x = [] ↔ P x) :
    ∀ (i : Nat) (xs : List α), itemErrs p f i xs = [] ↔ ∀ x ∈ xs, P x := by
  intro i xs
  induction xs generalizing i with
  | nil => simp [itemErrs]
  | cons x xs ih => simp [itemErrs, hf, ih]

theorem listErrs_eq_nil {α : Type} {p : String} {limit : Nat} {xs : List α}
    {f : String → α → List FieldError} {P : α → Prop} (hf : ∀ q x, f q x = [] ↔ P x) :
    listErrs p limit xs f = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, P x := by
  unfold listErrs
  rw [List.append_eq_nil_iff, itemErrs_eq_nil hf]
  by_cases h : xs.length ≤ limit <;> simp [h]

theorem optErrs_eq_nil {α : Type} {f : α → List FieldError} {P : α → Prop}
    (hf : ∀ x, f x = [] ↔ P x) (o : Option α) :
    optErrs f o = [] ↔ ∀ x, o = some x → P x := by
  cases o <;> simp [optErrs, hf]

theorem w2_errs_eq_nil (st : FilingStatus) (p : String) (w : FormW2) :
    w.errs st p = [] ↔ w.Valid st := by
  simp [FormW2.errs, FormW2.Valid, moneyErrs_eq_nil, roleErrs_eq_nil, List.append_eq_nil_iff]

theorem int1099_errs_eq_nil (st : FilingStatus) (p : String) (f : Form1099Int) :
    f.errs st p = [] ↔ f.Valid st := by
  simp [Form1099Int.errs, Form1099Int.Valid, moneyErrs_eq_nil, roleErrs_eq_nil,
    List.append_eq_nil_iff]

theorem g1099_errs_eq_nil (st : FilingStatus) (p : String) (f : Form1099G) :
    f.errs st p = [] ↔ f.Valid st := by
  simp [Form1099G.errs, Form1099G.Valid, moneyErrs_eq_nil, roleErrs_eq_nil,
    List.append_eq_nil_iff]

theorem misc1099_errs_eq_nil (st : FilingStatus) (p : String) (f : Form1099Misc) :
    f.errs st p = [] ↔ f.Valid st := by
  simp [Form1099Misc.errs, Form1099Misc.Valid, moneyErrs_eq_nil, roleErrs_eq_nil,
    List.append_eq_nil_iff]

theorem dateErrs_eq_nil (p : String) (o : Option Date) :
    dateErrs p o = [] ↔ ∀ d, o = some d → d.Valid := by
  cases o with
  | none => simp [dateErrs]
  | some d => by_cases h : d.Valid <;> simp [dateErrs, h]

theorem r1099_errs_eq_nil (st : FilingStatus) (p : String) (f : Form1099R) :
    f.errs st p = [] ↔ f.Valid st := by
  simp only [Form1099R.errs, Form1099R.Valid, List.append_eq_nil_iff, moneyErrs_eq_nil,
    roleErrs_eq_nil, dateErrs_eq_nil]
  by_cases h : f.distributionCode.length ≤ maxCodeChars <;> simp [h, and_assoc]

theorem netBenefitErrs_eq_nil (p : String) :
    ∀ (i : Nat) (ns : List Int), netBenefitErrs p i ns = [] ↔ ∀ n ∈ ns, SignedOk n := by
  intro i ns
  induction ns generalizing i with
  | nil => simp [netBenefitErrs]
  | cons n ns ih =>
    simp only [netBenefitErrs, List.append_eq_nil_iff, ih, List.mem_cons, forall_eq_or_imp]
    unfold SignedOk
    by_cases h1 : n < -moneyCap <;> by_cases h2 : n > moneyCap <;> simp [h1, h2] <;> omega

theorem ss_errs_eq_nil (p : String) (s : SocialSecurity) :
    s.errs p = [] ↔ s.Valid := by
  simp only [SocialSecurity.errs, SocialSecurity.Valid, List.append_eq_nil_iff,
    netBenefitErrs_eq_nil]
  by_cases h : s.netBenefits.length ≤ maxNetBenefits <;> simp [h]

theorem secondary_errs_eq_nil (r : Request) :
    ((if r.filers.secondary ≠ none ∧ r.filingStatus ≠ .marriedFilingJointly
      then [(⟨"/filers/secondary", .filerNotAllowed,
        "filers.secondary requires filing_status MarriedFilingJointly"⟩ : FieldError)]
      else []) = []) ↔ (r.filers.secondary ≠ none → r.filingStatus = .marriedFilingJointly) := by
  by_cases h1 : r.filers.secondary ≠ none <;> by_cases h2 : r.filingStatus = .marriedFilingJointly <;>
    simp_all

/-- The validator is exact for `Valid`. -/
theorem validate_eq_nil_iff (r : Request) : r.validate = [] ↔ r.Valid := by
  have hw := listErrs_eq_nil (p := "/w2s") (limit := maxForms) (xs := r.w2s)
    (fun q x => w2_errs_eq_nil r.filingStatus q x)
  have hi := listErrs_eq_nil (p := "/interest_reports") (limit := maxForms) (xs := r.interestReports)
    (fun q x => int1099_errs_eq_nil r.filingStatus q x)
  have hg := listErrs_eq_nil (p := "/form_1099g") (limit := maxForms) (xs := r.form1099g)
    (fun q x => g1099_errs_eq_nil r.filingStatus q x)
  have hm := listErrs_eq_nil (p := "/form_1099misc") (limit := maxForms) (xs := r.form1099misc)
    (fun q x => misc1099_errs_eq_nil r.filingStatus q x)
  have hr := listErrs_eq_nil (p := "/form_1099r") (limit := maxForms) (xs := r.form1099r)
    (fun q x => r1099_errs_eq_nil r.filingStatus q x)
  have hs := optErrs_eq_nil (f := SocialSecurity.errs "/social_security") (P := SocialSecurity.Valid)
    (fun s => ss_errs_eq_nil "/social_security" s) r.socialSecurity
  have he := optErrs_eq_nil (f := fun e : EducatorExpenses =>
      moneyErrs "/adjustments/educator_expenses" e.moneyFields) (P := fun e => AllNonNeg e.moneyFields)
    (fun e => moneyErrs_eq_nil _ e.moneyFields) r.adjustments.educatorExpenses
  have hl := optErrs_eq_nil (f := fun e : StudentLoanInterest =>
      moneyErrs "/adjustments/student_loan_interest" e.moneyFields) (P := fun e => AllNonNeg e.moneyFields)
    (fun e => moneyErrs_eq_nil _ e.moneyFields) r.adjustments.studentLoanInterest
  have hp := optErrs_eq_nil (f := fun e : EstimatedPayments =>
      moneyErrs "/estimated_payments" e.moneyFields) (P := fun e => AllNonNeg e.moneyFields)
    (fun e => moneyErrs_eq_nil _ e.moneyFields) r.estimatedPayments
  simp only [Request.validate, Request.Valid, List.append_eq_nil_iff, hw, hi, hg, hm, hr, hs, he, hl, hp]
  rw [secondary_errs_eq_nil]
  simp only [and_assoc]

/-- `Valid` is decidable, by running the validator. -/
instance : DecidablePred Request.Valid := fun r =>
  decidable_of_iff (r.validate = []) (validate_eq_nil_iff r)

/-- Soundness: no error means every range, cap, size and role rule holds. -/
theorem validate_sound (r : Request) (h : r.validate = []) : r.Valid :=
  (validate_eq_nil_iff r).1 h

/-- Completeness: a valid request has no error. -/
theorem validate_complete (r : Request) (h : r.Valid) : r.validate = [] :=
  (validate_eq_nil_iff r).2 h

/-! ### Corollaries a reader can check without unfolding -/

/-- A valid request has every W-2 wage in `0 .. 10^13`. -/
theorem Valid.w2_wages {r : Request} (h : r.Valid) {w : FormW2} (hw : w ∈ r.w2s) :
    0 ≤ w.wages ∧ w.wages ≤ moneyCap := by
  have := (h.2.2.1 w hw).1 ("wages", w.wages) (by simp [FormW2.moneyFields])
  exact this

/-- A valid request has at most 20 W-2s. -/
theorem Valid.w2_length {r : Request} (h : r.Valid) : r.w2s.length ≤ 20 := h.2.1

/-- A valid request on a non-joint return has no secondary-filer W-2. -/
theorem Valid.no_secondary_w2 {r : Request} (h : r.Valid) (hs : r.filingStatus ≠ .marriedFilingJointly)
    {w : FormW2} (hw : w ∈ r.w2s) : w.filer ≠ .secondaryFiler :=
  fun e => hs ((h.2.2.1 w hw).2.2 e)

/-- A valid request has a signed net benefit within the cap. -/
theorem Valid.net_benefits {r : Request} (h : r.Valid) {s : SocialSecurity}
    (hs : r.socialSecurity = some s) {n : Int} (hn : n ∈ s.netBenefits) :
    -moneyCap ≤ n ∧ n ≤ moneyCap :=
  (h.2.2.2.2.2.2.2.2.2.2.2.1 s hs).2 n hn

/-! ### Satisfiable hypotheses, bad inputs rejected (CLAUDE.md section 4) -/

example : exampleSingleW2.Valid := by decide
example : ¬ exampleOverCap.Valid := by decide
example : ¬ exampleNegativeWages.Valid := by decide
example : ¬ exampleSecondaryOnSingle.Valid := by decide
example : ¬ exampleTooMany.Valid := by decide

#audit_axioms validate_eq_nil_iff
#audit_axioms validate_sound
#audit_axioms Valid.w2_wages

end UsTax.Api
