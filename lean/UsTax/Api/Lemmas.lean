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

theorem nonNegAt_eq_nil (q : String) (n : Int) : nonNegAt q n = [] ↔ NonNegOk n := by
  unfold nonNegAt NonNegOk
  by_cases h1 : n < 0 <;> by_cases h2 : n > moneyCap <;> simp [h1, h2]
  all_goals omega

theorem nonNegErrs_eq_nil (p : String) (kv : String × Int) :
    nonNegErrs p kv = [] ↔ NonNegOk kv.2 := nonNegAt_eq_nil _ _

theorem rangeAt_eq_nil (lo hi : Int) (q : String) (n : Int) :
    rangeAt lo hi q n = [] ↔ IntRange lo hi n := by
  unfold rangeAt IntRange
  by_cases h1 : n < lo <;> by_cases h2 : n > hi <;> simp [h1, h2]
  all_goals omega

theorem dateAt_eq_nil (q : String) (d : Date) : dateAt q d = [] ↔ d.Valid := by
  unfold dateAt
  by_cases h : d.Valid <;> simp [h]

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

theorem optAt_eq_nil {α : Type} {f : String → α → List FieldError} {P : α → Prop}
    (hf : ∀ q x, f q x = [] ↔ P x) (q : String) (o : Option α) :
    optAt q f o = [] ↔ ∀ x, o = some x → P x := by
  cases o <;> simp [optAt, hf]

theorem nnList_eq_nil {q : String} {limit : Nat} {xs : List Int} :
    listErrs q limit xs nonNegAt = [] ↔ xs.length ≤ limit ∧ ∀ n ∈ xs, NonNegOk n :=
  listErrs_eq_nil nonNegAt_eq_nil

theorem rangeList_eq_nil {lo hi : Int} {q : String} {limit : Nat} {xs : List Int} :
    listErrs q limit xs (rangeAt lo hi) = [] ↔ xs.length ≤ limit ∧ ∀ n ∈ xs, IntRange lo hi n :=
  listErrs_eq_nil (rangeAt_eq_nil lo hi)

theorem optRange_eq_nil {lo hi : Int} {q : String} (o : Option Int) :
    optAt q (rangeAt lo hi) o = [] ↔ ∀ n, o = some n → IntRange lo hi n :=
  optAt_eq_nil (rangeAt_eq_nil lo hi) q o

theorem optDate_eq_nil {q : String} (o : Option Date) :
    optAt q dateAt o = [] ↔ ∀ d, o = some d → d.Valid :=
  optAt_eq_nil dateAt_eq_nil q o

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

theorem r1099_errs_eq_nil (st : FilingStatus) (p : String) (f : Form1099R) :
    f.errs st p = [] ↔ f.Valid st := by
  simp only [Form1099R.errs, Form1099R.Valid, List.append_eq_nil_iff, moneyErrs_eq_nil,
    roleErrs_eq_nil, optDate_eq_nil]
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
    netBenefitErrs_eq_nil, nnList_eq_nil]
  by_cases h : s.netBenefits.length ≤ maxNetBenefits <;>
    by_cases h' : s.federalTaxWithheld.length ≤ s.netBenefits.length <;> simp [h, h']

theorem DisabilityAnswers_errs_eq_nil (p : String) (s : DisabilityAnswers) :
    s.errs p = [] ↔ s.Valid := by
  simp only [DisabilityAnswers.errs, DisabilityAnswers.Valid, moneyErrs_eq_nil]

theorem opt_DisabilityAnswers_eq_nil (p : String) (o : Option DisabilityAnswers) :
    optAt p (DisabilityAnswers.errs) o = [] ↔ ∀ x, o = some x → x.Valid :=
  optAt_eq_nil (fun q x => DisabilityAnswers_errs_eq_nil q x) p o

theorem list_DisabilityAnswers_eq_nil (p : String) (limit : Nat) (xs : List DisabilityAnswers) :
    listErrs p limit xs (DisabilityAnswers.errs) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid :=
  listErrs_eq_nil (fun q x => DisabilityAnswers_errs_eq_nil q x)

theorem HsaFilerAnswers_errs_eq_nil (p : String) (s : HsaFilerAnswers) :
    s.errs p = [] ↔ s.Valid := by
  simp only [HsaFilerAnswers.errs, HsaFilerAnswers.Valid, moneyErrs_eq_nil]

theorem opt_HsaFilerAnswers_eq_nil (p : String) (o : Option HsaFilerAnswers) :
    optAt p (HsaFilerAnswers.errs) o = [] ↔ ∀ x, o = some x → x.Valid :=
  optAt_eq_nil (fun q x => HsaFilerAnswers_errs_eq_nil q x) p o

theorem list_HsaFilerAnswers_eq_nil (p : String) (limit : Nat) (xs : List HsaFilerAnswers) :
    listErrs p limit xs (HsaFilerAnswers.errs) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid :=
  listErrs_eq_nil (fun q x => HsaFilerAnswers_errs_eq_nil q x)

theorem CdccFilerAnswers_errs_eq_nil (p : String) (s : CdccFilerAnswers) :
    s.errs p = [] ↔ s.Valid := by
  simp only [CdccFilerAnswers.errs, CdccFilerAnswers.Valid, List.append_eq_nil_iff, moneyErrs_eq_nil, nnList_eq_nil]

theorem opt_CdccFilerAnswers_eq_nil (p : String) (o : Option CdccFilerAnswers) :
    optAt p (CdccFilerAnswers.errs) o = [] ↔ ∀ x, o = some x → x.Valid :=
  optAt_eq_nil (fun q x => CdccFilerAnswers_errs_eq_nil q x) p o

theorem list_CdccFilerAnswers_eq_nil (p : String) (limit : Nat) (xs : List CdccFilerAnswers) :
    listErrs p limit xs (CdccFilerAnswers.errs) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid :=
  listErrs_eq_nil (fun q x => CdccFilerAnswers_errs_eq_nil q x)

theorem FilerFlags_errs_eq_nil (p : String) (s : FilerFlags) :
    s.errs p = [] ↔ s.Valid := by
  simp only [FilerFlags.errs, FilerFlags.Valid, List.append_eq_nil_iff, optDate_eq_nil, opt_DisabilityAnswers_eq_nil, opt_HsaFilerAnswers_eq_nil, opt_CdccFilerAnswers_eq_nil]

theorem opt_FilerFlags_eq_nil (p : String) (o : Option FilerFlags) :
    optAt p (FilerFlags.errs) o = [] ↔ ∀ x, o = some x → x.Valid :=
  optAt_eq_nil (fun q x => FilerFlags_errs_eq_nil q x) p o

theorem list_FilerFlags_eq_nil (p : String) (limit : Nat) (xs : List FilerFlags) :
    listErrs p limit xs (FilerFlags.errs) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid :=
  listErrs_eq_nil (fun q x => FilerFlags_errs_eq_nil q x)

theorem FilingAnswers_errs_eq_nil (p : String) (s : FilingAnswers) :
    s.errs p = [] ↔ s.Valid := by
  simp only [FilingAnswers.errs, FilingAnswers.Valid, dateAt_eq_nil]

theorem opt_FilingAnswers_eq_nil (p : String) (o : Option FilingAnswers) :
    optAt p (FilingAnswers.errs) o = [] ↔ ∀ x, o = some x → x.Valid :=
  optAt_eq_nil (fun q x => FilingAnswers_errs_eq_nil q x) p o

theorem list_FilingAnswers_eq_nil (p : String) (limit : Nat) (xs : List FilingAnswers) :
    listErrs p limit xs (FilingAnswers.errs) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid :=
  listErrs_eq_nil (fun q x => FilingAnswers_errs_eq_nil q x)

theorem CdccMemberAnswers_errs_eq_nil (p : String) (s : CdccMemberAnswers) :
    s.errs p = [] ↔ s.Valid := by
  simp only [CdccMemberAnswers.errs, CdccMemberAnswers.Valid, moneyErrs_eq_nil]

theorem opt_CdccMemberAnswers_eq_nil (p : String) (o : Option CdccMemberAnswers) :
    optAt p (CdccMemberAnswers.errs) o = [] ↔ ∀ x, o = some x → x.Valid :=
  optAt_eq_nil (fun q x => CdccMemberAnswers_errs_eq_nil q x) p o

theorem list_CdccMemberAnswers_eq_nil (p : String) (limit : Nat) (xs : List CdccMemberAnswers) :
    listErrs p limit xs (CdccMemberAnswers.errs) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid :=
  listErrs_eq_nil (fun q x => CdccMemberAnswers_errs_eq_nil q x)

theorem Dependent_errs_eq_nil (p : String) (s : Dependent) :
    s.errs p = [] ↔ s.Valid := by
  simp only [Dependent.errs, Dependent.Valid, List.append_eq_nil_iff, moneyErrs_eq_nil, dateAt_eq_nil, rangeAt_eq_nil, opt_CdccMemberAnswers_eq_nil]

theorem opt_Dependent_eq_nil (p : String) (o : Option Dependent) :
    optAt p (Dependent.errs) o = [] ↔ ∀ x, o = some x → x.Valid :=
  optAt_eq_nil (fun q x => Dependent_errs_eq_nil q x) p o

theorem list_Dependent_eq_nil (p : String) (limit : Nat) (xs : List Dependent) :
    listErrs p limit xs (Dependent.errs) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid :=
  listErrs_eq_nil (fun q x => Dependent_errs_eq_nil q x)

theorem HsaDistribution_errs_eq_nil (st : FilingStatus) (p : String) (s : HsaDistribution) :
    s.errs st p = [] ↔ s.Valid st := by
  simp only [HsaDistribution.errs, HsaDistribution.Valid, List.append_eq_nil_iff, moneyErrs_eq_nil, roleErrs_eq_nil]

theorem opt_HsaDistribution_eq_nil (st : FilingStatus) (p : String) (o : Option HsaDistribution) :
    optAt p (HsaDistribution.errs st) o = [] ↔ ∀ x, o = some x → x.Valid st :=
  optAt_eq_nil (fun q x => HsaDistribution_errs_eq_nil st q x) p o

theorem list_HsaDistribution_eq_nil (st : FilingStatus) (p : String) (limit : Nat) (xs : List HsaDistribution) :
    listErrs p limit xs (HsaDistribution.errs st) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid st :=
  listErrs_eq_nil (fun q x => HsaDistribution_errs_eq_nil st q x)

theorem HsaInput_errs_eq_nil (st : FilingStatus) (p : String) (s : HsaInput) :
    s.errs st p = [] ↔ s.Valid st := by
  simp only [HsaInput.errs, HsaInput.Valid, list_HsaDistribution_eq_nil]

theorem opt_HsaInput_eq_nil (st : FilingStatus) (p : String) (o : Option HsaInput) :
    optAt p (HsaInput.errs st) o = [] ↔ ∀ x, o = some x → x.Valid st :=
  optAt_eq_nil (fun q x => HsaInput_errs_eq_nil st q x) p o

theorem list_HsaInput_eq_nil (st : FilingStatus) (p : String) (limit : Nat) (xs : List HsaInput) :
    listErrs p limit xs (HsaInput.errs st) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid st :=
  listErrs_eq_nil (fun q x => HsaInput_errs_eq_nil st q x)

theorem CreditAnswers_errs_eq_nil (p : String) (s : CreditAnswers) :
    s.errs p = [] ↔ s.Valid := by
  simp only [CreditAnswers.errs, CreditAnswers.Valid, moneyErrs_eq_nil]

theorem opt_CreditAnswers_eq_nil (p : String) (o : Option CreditAnswers) :
    optAt p (CreditAnswers.errs) o = [] ↔ ∀ x, o = some x → x.Valid :=
  optAt_eq_nil (fun q x => CreditAnswers_errs_eq_nil q x) p o

theorem list_CreditAnswers_eq_nil (p : String) (limit : Nat) (xs : List CreditAnswers) :
    listErrs p limit xs (CreditAnswers.errs) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid :=
  listErrs_eq_nil (fun q x => CreditAnswers_errs_eq_nil q x)

theorem CdccInput_errs_eq_nil (p : String) (s : CdccInput) :
    s.errs p = [] ↔ s.Valid := by
  simp only [CdccInput.errs, CdccInput.Valid, moneyErrs_eq_nil]

theorem opt_CdccInput_eq_nil (p : String) (o : Option CdccInput) :
    optAt p (CdccInput.errs) o = [] ↔ ∀ x, o = some x → x.Valid :=
  optAt_eq_nil (fun q x => CdccInput_errs_eq_nil q x) p o

theorem list_CdccInput_eq_nil (p : String) (limit : Nat) (xs : List CdccInput) :
    listErrs p limit xs (CdccInput.errs) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid :=
  listErrs_eq_nil (fun q x => CdccInput_errs_eq_nil q x)

theorem Form1095A_errs_eq_nil (p : String) (s : Form1095A) :
    s.errs p = [] ↔ s.Valid := by
  simp only [Form1095A.errs, Form1095A.Valid, List.append_eq_nil_iff, moneyErrs_eq_nil, dateAt_eq_nil, rangeList_eq_nil, nnList_eq_nil]

theorem opt_Form1095A_eq_nil (p : String) (o : Option Form1095A) :
    optAt p (Form1095A.errs) o = [] ↔ ∀ x, o = some x → x.Valid :=
  optAt_eq_nil (fun q x => Form1095A_errs_eq_nil q x) p o

theorem list_Form1095A_eq_nil (p : String) (limit : Nat) (xs : List Form1095A) :
    listErrs p limit xs (Form1095A.errs) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid :=
  listErrs_eq_nil (fun q x => Form1095A_errs_eq_nil q x)

theorem PtcInput_errs_eq_nil (p : String) (s : PtcInput) :
    s.errs p = [] ↔ s.Valid := by
  simp only [PtcInput.errs, PtcInput.Valid, list_Form1095A_eq_nil]

theorem opt_PtcInput_eq_nil (p : String) (o : Option PtcInput) :
    optAt p (PtcInput.errs) o = [] ↔ ∀ x, o = some x → x.Valid :=
  optAt_eq_nil (fun q x => PtcInput_errs_eq_nil q x) p o

theorem list_PtcInput_eq_nil (p : String) (limit : Nat) (xs : List PtcInput) :
    listErrs p limit xs (PtcInput.errs) = [] ↔ xs.length ≤ limit ∧ ∀ x ∈ xs, x.Valid :=
  listErrs_eq_nil (fun q x => PtcInput_errs_eq_nil q x)


theorem secondary_errs_eq_nil (r : Request) :
    ((if r.filers.secondary ≠ none ∧ r.filingStatus ≠ .marriedFilingJointly
      then [(⟨"/filers/secondary", .filerNotAllowed,
        "filers.secondary requires filing_status MarriedFilingJointly"⟩ : FieldError)]
      else []) = []) ↔ (r.filers.secondary ≠ none → r.filingStatus = .marriedFilingJointly) := by
  by_cases h1 : r.filers.secondary ≠ none <;> by_cases h2 : r.filingStatus = .marriedFilingJointly <;>
    simp_all

theorem validateBase_eq_nil_iff (r : Request) : r.validateBase = [] ↔ r.ValidBase := by
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
  simp only [Request.validateBase, Request.ValidBase, List.append_eq_nil_iff, hw, hi, hg, hm, hr, hs,
    he, hl, hp]
  rw [secondary_errs_eq_nil]
  simp only [and_assoc]

theorem validateSections_eq_nil_iff (r : Request) :
    r.validateSections = [] ↔ r.ValidSections := by
  have hfp := optErrs_eq_nil (f := FilerFlags.errs "/filers/primary") (P := FilerFlags.Valid)
    (fun x => FilerFlags_errs_eq_nil "/filers/primary" x) r.filers.primary
  have hfs := optErrs_eq_nil (f := FilerFlags.errs "/filers/secondary") (P := FilerFlags.Valid)
    (fun x => FilerFlags_errs_eq_nil "/filers/secondary" x) r.filers.secondary
  have hh := optErrs_eq_nil (f := HsaInput.errs r.filingStatus "/adjustments/hsa")
    (P := HsaInput.Valid r.filingStatus)
    (fun x => HsaInput_errs_eq_nil r.filingStatus "/adjustments/hsa" x) r.adjustments.hsa
  have hfa := optErrs_eq_nil (f := FilingAnswers.errs "/filing_answers") (P := FilingAnswers.Valid)
    (fun x => FilingAnswers_errs_eq_nil "/filing_answers" x) r.filingAnswers
  have hd := list_Dependent_eq_nil "/dependents" maxForms r.dependents
  have hc := optErrs_eq_nil (f := CreditAnswers.errs "/credits") (P := CreditAnswers.Valid)
    (fun x => CreditAnswers_errs_eq_nil "/credits" x) r.credits
  have hcd := optErrs_eq_nil (f := CdccInput.errs "/cdcc") (P := CdccInput.Valid)
    (fun x => CdccInput_errs_eq_nil "/cdcc" x) r.cdcc
  have hpt := optErrs_eq_nil (f := PtcInput.errs "/premium_tax_credit") (P := PtcInput.Valid)
    (fun x => PtcInput_errs_eq_nil "/premium_tax_credit" x) r.premiumTaxCredit
  simp only [Request.validateSections, Request.ValidSections, List.append_eq_nil_iff, hfp, hfs, hh,
    hfa, hd, hc, hcd, hpt, and_assoc]

/-- The validator is exact for `Valid`. -/
theorem validate_eq_nil_iff (r : Request) : r.validate = [] ↔ r.Valid := by
  simp only [Request.validate, Request.Valid, List.append_eq_nil_iff, validateBase_eq_nil_iff,
    validateSections_eq_nil_iff]

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
  have := (h.1.2.2.1 w hw).1 ("wages", w.wages) (by simp [FormW2.moneyFields])
  exact this

/-- A valid request has at most 20 W-2s. -/
theorem Valid.w2_length {r : Request} (h : r.Valid) : r.w2s.length ≤ 20 := h.1.2.1

/-- A valid request on a non-joint return has no secondary-filer W-2. -/
theorem Valid.no_secondary_w2 {r : Request} (h : r.Valid) (hs : r.filingStatus ≠ .marriedFilingJointly)
    {w : FormW2} (hw : w ∈ r.w2s) : w.filer ≠ .secondaryFiler :=
  fun e => hs ((h.1.2.2.1 w hw).2.2 e)

/-- A valid request has a signed net benefit within the cap. -/
theorem Valid.net_benefits {r : Request} (h : r.Valid) {s : SocialSecurity}
    (hs : r.socialSecurity = some s) {n : Int} (hn : n ∈ s.netBenefits) :
    -moneyCap ≤ n ∧ n ≤ moneyCap :=
  (h.1.2.2.2.2.2.2.2.2.2.2.2.1 s hs).2.1 n hn

/-! ### Satisfiable hypotheses, bad inputs rejected (CLAUDE.md section 4) -/

example : exampleSingleW2.Valid := by decide
example : ¬ exampleOverCap.Valid := by decide
example : ¬ exampleNegativeWages.Valid := by decide
example : ¬ exampleSecondaryOnSingle.Valid := by decide
example : ¬ exampleTooMany.Valid := by decide
example : exampleHousehold.Valid := by decide
example : ¬ exampleThirteenMonths.Valid := by decide
example : ¬ exampleImpossibleBirthday.Valid := by decide
example : ¬ exampleWithheldTooLong.Valid := by decide

#audit_axioms validate_eq_nil_iff
#audit_axioms validate_sound
#audit_axioms Valid.w2_wages
#audit_axioms validateSections_eq_nil_iff

end UsTax.Api
