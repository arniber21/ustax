import UsTax.Api.Spec
import UsTax.Form1040

/-!
# Bridge to the calculator input (issues #51, #52)

`Request` is the typed, validated image of the HTTP body. The calculator's
input is `Form1040.Form1040In` (issue #43). `toForm1040Input` is the **only**
place that knows both field vocabularies (API box names and Catala names), as
`docs/api.md` states. It is a thin, total function:

* money: `Int` cents to `Int` cents, **no arithmetic and no rounding** (the
  calculator rounds, per CONVENTIONS section 4);
* absent list = `[]`, absent box = `0`, absent flag = `false` (already applied
  by the decoder, so the bridge sees plain values);
* box 12 entries are looked up by code (absent code = `0`) and land in the
  `FormW2s.FormW2` field named in `$defs/W2Box12.description`;
* `filing_details.treat_as_mfs = none` means `treatAsMfs := (filingStatus = MFS)`;
* an absent `filers.primary` / `filers.secondary` is "no flags set".

**What is wired.** Filing status, W-2s (boxes 1 to 11, box 12, box 13),
1099-INT, per-filer blind / 65 or older / can-be-claimed flags, the
`filing_details` answers, foreign accounts, combat pay election. The other
sections validate but have no Lean module yet (`unwiredSections`): the
request's values in them are **not read**, and the server says so in the
`warnings` array of the 200 response (see `docs/api.md`, "Warnings").
-/

namespace UsTax.Api

/-- The amount of a box 12 code on a W-2; absent code is `0`. -/
def Box12.amount (b : Box12) (code : Box12Code) : Int :=
  ((b.entries.find? (·.1 == code)).map (·.2)).getD 0

/-- API filer role to the Catala `FilerRole`. -/
def FilerRole.toCore : FilerRole → UsTax.FilerRole
  | .primaryFiler => .primaryFiler
  | .secondaryFiler => .secondaryFiler

/-- API combat pay election to the Catala one (same constructors). -/
def CombatPayElection.toCore : CombatPayElection → FormW2s.CombatPayElection
  | .noCombatPay => .noCombatPay
  | .usePrimaryCombatPay => .usePrimaryCombatPay
  | .useSpouseCombatPay => .useSpouseCombatPay
  | .useBothCombatPay => .useBothCombatPay
  | .usePrimaryNotSpouseCombatPay => .usePrimaryNotSpouseCombatPay
  | .useSpouseNotPrimaryCombatPay => .useSpouseNotPrimaryCombatPay

/-- One API W-2 to the Catala `FormW2`. Box 12 code letters per `$defs/W2Box12`. -/
def FormW2.toCore (w : FormW2) : FormW2s.FormW2 :=
  { filer := w.filer.toCore
    writableWages := w.wages
    writableFederalWithholding := w.federalWithholding
    writableOasdiWages := w.oasdiWages
    writableOasdiWithholding := w.oasdiWithholding
    writableMedicareWages := w.medicareWages
    writableMedicareWithholding := w.medicareWithholding
    writableAllocatedTips := w.allocatedTips
    writableDependentCareBenefits := w.dependentCareBenefits
    writableNonQualifiedPlans := w.nonQualifiedPlans
    writableCombatPay := w.box12.amount .q
    uncollectedOasdiTaxOnTips := w.box12.amount .a
    uncollectedMedicareTaxOnTips := w.box12.amount .b
    taxableLifeInsuranceOver50k := w.box12.amount .c
    deferrals401k := w.box12.amount .d
    deferrals403b := w.box12.amount .e
    sarsepDeferrals := w.box12.amount .f
    deferrals457b := w.box12.amount .g
    deferrals501c18 := w.box12.amount .h
    nontaxableSickPay := w.box12.amount .j
    goldenParachuteExciseTax := w.box12.amount .k
    expenseReimbursements := w.box12.amount .l
    uncollectedOasdiTaxOnLifeInsuranceOver50k := w.box12.amount .m
    uncollectedMedicareTaxOnLifeInsuranceOver50k := w.box12.amount .n
    armedForcesMovingExpenses := w.box12.amount .p
    archerMsaContributions := w.box12.amount .r
    simpleContributions := w.box12.amount .s
    adoptionBenefits := w.box12.amount .t
    nsoIncome := w.box12.amount .v
    employerHsaContributions := w.box12.amount .w
    deferrals409a := w.box12.amount .y
    nqdcDeferrals := w.box12.amount .z
    roth401kContributions := w.box12.amount .aa
    roth403bContributions := w.box12.amount .bb
    healthCoverageCost := w.box12.amount .dd
    roth457bContributions := w.box12.amount .ee
    qsehraBenefits := w.box12.amount .ff
    income83i := w.box12.amount .gg
    deferrals83i := w.box12.amount .hh
    nonTaxableMedicaidWaiverPayments := w.box12.amount .ii
    plan457bIsGovernmental := w.plan457bIsGovernmental
    statutoryEmployee := w.statutoryEmployee
    thirdPartySickPay := w.thirdPartySickPay }

/-- One API 1099-INT to the Catala `InterestReport` (`$defs/Form1099Int.description`). -/
def Form1099Int.toCore (f : Form1099Int) : Interest.InterestReport :=
  { filer := f.filer.toCore
    has1099 := f.has1099
    no1099Amount := f.no1099Amount
    writable1099Amount := f.interestIncome
    writableEarlyWithdrawlPenaltyAmount := f.earlyWithdrawalPenalty
    writableInterestOnGovernmentBonds := f.governmentBondInterest
    writableTaxWithheld := f.federalTaxWithheld
    writableForeignTaxPaid := f.foreignTaxPaid
    writableTaxExemptInterest := f.taxExemptInterest
    writableSpecifiedPrivateActivityBondInterest := f.privateActivityBondInterest
    writableMarketDiscount := f.marketDiscount
    writableBondPremium := f.bondPremium
    writableBondPremiumOnTreasuryObligations := f.bondPremiumTreasury
    writableBondPremiumOnTaxExemptBond := f.bondPremiumTaxExempt
    stateIsDifferentState := f.stateIsDifferent
    writableStateTaxWithheld := f.stateTaxWithheld
    factaFilingRequired := f.factaFilingRequired }

/-- The request as the `Form1040` scope input. Plug-in slots stay at their
Catala defaults (`$0`, `false`): the sections that would fill them are listed by
`unwiredSections`. -/
def toForm1040Input (r : Request) (_h : r.Valid) : Form1040.Form1040In :=
  let p := r.filers.primary.getD {}
  let s := r.filers.secondary.getD {}
  let d := r.filingDetails
  { filingStatus := r.filingStatus
    w2s := r.w2s.map FormW2.toCore
    interestReports := r.interestReports.map Form1099Int.toCore
    hasForeignAccountsOrTrusts := d.hasForeignAccountsOrTrusts
    combatPayElection := d.combatPayElection.toCore
    primaryFilerCanBeClaimed := p.canBeClaimedAsDependent
    secondaryFilerCanBeClaimed := s.canBeClaimedAsDependent
    treatAsMfs := d.treatAsMfs.getD (r.filingStatus == .marriedFilingSeparately)
    primaryFilerIsBlind := p.isBlind
    primaryFilerAge65OrOlder := p.age65OrOlder
    secondaryFilerIsBlind := s.isBlind
    secondaryFilerAge65OrOlder := s.age65OrOlder
    isWidowedInTaxYear := d.isWidowedInTaxYear
    mfjDeceasedSpouseReachedAge65 := d.mfjDeceasedSpouseReachedAge65
    mfsSpouse65OrOlder := d.mfsSpouse65OrOlder
    mfsSpouseProvidesNoBenefits := d.mfsSpouseProvidesNoBenefits
    treatFilersAsDependents := d.treatFilersAsDependents }

/-- A request section that validates but is not yet read by the calculator. -/
structure UnwiredSection where
  /-- RFC 6901 pointer of the section. -/
  path : String
  /-- Why it has no effect yet. -/
  message : String
  deriving DecidableEq, Repr

/-- The sections of the request that are present (non-empty) but have no Lean
module behind them yet, in schema order. Their values do not reach the
calculator, so the response must say so. -/
def unwiredSections (r : Request) : List UnwiredSection :=
  let mk (path name : String) : UnwiredSection :=
    ⟨path, s!"{name} is accepted but not yet used in the calculation."⟩
  (if r.form1099g.isEmpty then [] else [mk "/form_1099g" "Form 1099-G"]) ++
  (if r.form1099misc.isEmpty then [] else [mk "/form_1099misc" "Form 1099-MISC"]) ++
  (if r.form1099r.isEmpty then [] else [mk "/form_1099r" "Form 1099-R"]) ++
  (match r.socialSecurity with
   | some _ => [mk "/social_security" "Social Security benefits"]
   | none => []) ++
  (match r.adjustments.educatorExpenses with
   | some _ => [mk "/adjustments/educator_expenses" "The educator expenses adjustment"]
   | none => []) ++
  (match r.adjustments.studentLoanInterest with
   | some _ => [mk "/adjustments/student_loan_interest" "The student loan interest adjustment"]
   | none => []) ++
  (match r.estimatedPayments with
   | some _ => [mk "/estimated_payments" "Estimated tax payments"]
   | none => [])

end UsTax.Api
