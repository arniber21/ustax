import UsTax.PtcFamily
import UsTax.PtcAllowed
import UsTax.PtcNet
import UsTax.Hsa
import UsTax.PtcHsa.Spec
import Plausible

/-!
# Property tests for the premium tax credit and HSA modules (plausible, issue #47)

The statements of `UsTax/PtcHsa/Lemmas.lean`, run on random inputs on every build, and run before
the proofs were written (CLAUDE.md section 5). As in `UsTax/NonrefundableCredits/Props.lean` they
use `Testable.check`, so nothing is admitted. Inputs with many fields are built from random lists
of booleans and integers (`bit`, `num`), so every field varies; amounts are scaled to cents up to
tens of thousands of dollars. A negative control that must fail ends the file.
-/

namespace UsTax.PtcHsa.Props
open Plausible

/-- `#prop p`: run plausible on `p` with 300 random instances. -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 300 })

/-- `#propMany p`: 2,000 random instances, for inputs where the interesting region is rare. -/
local macro "#propMany " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 2000 })

/-- Boolean number `n` of a random list (`false` past its end). -/
def bit (bs : List Bool) (n : Nat) : Bool := bs.getD n false
/-- Integer number `n` of a random list at scale `k` (`0` past its end). -/
def num (xs : List Int) (n : Nat) (k : Int) : Int := xs.getD n 0 * k
/-- The absolute values of a random list (nonnegative amounts). -/
def nn (xs : List Int) : List Int := xs.map fun x => (x.natAbs : Int)

/-! ### Line 7 (Table 2) -/

/-- The figure is monotone on line 5 values `a / d`, `b / d`. -/
def figureMonoOk (a b d : Int) : Bool :=
  let p : Rat := (a : Rat) / (d : Rat)
  let q : Rat := (b : Rat) / (d : Rat)
  !decide (p ≤ q) || decide (PtcFamily.applicableFigureOf p ≤ PtcFamily.applicableFigureOf q)

-- Monotone in line 5, on whole percents and on fractions (several denominators, several scales).
#prop (∀ a b : Int, [1, 2, 3, 7, 100].all fun d => [1, 5, 40].all fun k =>
  figureMonoOk (a * k) (b * k) d)
-- Monotone across the joins of the pieces (150, 300, 399, 400).
#prop (∀ a b : Int, [150, 300, 399, 400].all fun c => figureMonoOk (c * 10 + a % 20) (c * 10 + b % 20) 10)
-- Between 0 and 0.085.
#prop (∀ a : Int, [1, 3, 100].all fun d =>
  let f := PtcFamily.applicableFigureOf ((a : Rat) / (d : Rat))
  decide (0 ≤ f) && decide (f ≤ 85 / 1000))
-- Line 8a is between $0 and 8.5 percent of line 3 (plus the dollar rounding), for every family.
#prop (∀ (agi te ss deps : Int) (ak hi pc sc : Bool), FilingStatus.all.all fun fs =>
  let o := PtcFamily.ptcFamily
    { filingStatus := fs, claimedDependentsCount := deps % 8
      primarySomeoneCanClaimForTaxBenefits := pc, secondarySomeoneCanClaimForTaxBenefits := sc
      livedInAk := ak, livedInHi := hi, agi := agi * 1_000, taxExemptInterest := te * 100
      nonTaxableSocialSecurityBenefits := ss * 100 }
  decide (0 ≤ o.ptcAnnualContributionAmount) && decide (0 ≤ o.householdIncomeAsPercent) &&
    decide (o.householdIncomeAsPercent ≤ 401))

/-! ### Lines 12 to 25 -/

/-- A Form 1095-A from random lists: start and end month, a 1st or 15th start day, coverage
months, every amount. -/
def formOf (bs : List Bool) (xs : List Int) (k : Int) : PtcAllowed.Form1095A :=
  let sm := (num xs 0 1 % 12).toNat + 1
  let em := Nat.max sm ((num xs 1 1 % 12).toNat + 1)
  { writablePolicyStartDate := PtcAllowed.d24 sm (if bit bs 0 then 1 else 15)
    writablePolicyEndDate := PtcAllowed.d24 em 28
    writableSpecialPolicyModificationInStartingMonth := bit bs 1
    writableHasPolicyDateException := bit bs 2, hasCoverageMonths := !bit bs 3
    coverageMonths := PtcAllowed.monthNumbers.filter fun m => !bit bs (4 + m.toNat)
    writablePremiumsOrSlcspChange := bit bs 17, hasChangeInCircumstance := bit bs 18
    writablePtcAnnualPremium := num xs 2 k, writableSlcspAnnualPremium := num xs 3 k
    writableAptcAnnualAmount := num xs 4 k
    writablePtcMonthlyPremium := PtcAllowed.monthNumbers.map fun m => num xs (5 + m.toNat) k
    writablePtcMonthlySlcspPremium := PtcAllowed.monthNumbers.map fun m => num xs (17 + m.toNat) k
    writablePtcMonthlyAptcPremium := PtcAllowed.monthNumbers.map fun m => num xs (29 + m.toNat) k }

/-- A `PtcAllowed` input from random lists: the defaults of the Catala test helper with every
answer, line 5, lines 8a and 8b and zero to two forms drawn at random. -/
def allowedOf (bs : List Bool) (xs ys zs : List Int) (k : Int) : PtcAllowed.PtcAllowedIn :=
  let nForms := (num xs 0 1 % 3).toNat
  { PtcAllowed.base with
      filingStatus := FilingStatus.all.getD (num xs 1 1 % 5).toNat .single
      isMfjDependent := bit bs 0
      notMfjAndPrimaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits := bit bs 1
      primaryFilerIsClaimedAsDependent := bit bs 2, isMarried := bit bs 3
      hasQsehra := bit bs 4, householdIncomeAsPercent := ((num xs 2 1 % 420 : Int) : Rat)
      ptcAnnualContributionAmount := num xs 3 k, ptcMonthlyContributionAmount := num xs 4 (k / 12)
      form1095As := ([ys, zs].take nForms).map fun l => formOf (bs.drop 20) l k
      writableHasPtcQualifyingPlan := !bit bs 5, writableHasAdvancedPtc := bit bs 6
      dependentTpSelfEnrolled := bit bs 7, dependentTpEnrolledSomeoneElse := bit bs 8
      writableHasMfsException := bit bs 9
      writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus := bit bs 10 }

/-- Column (e) is at most column (a) and column (d) is nonnegative, in every month; line 11(e) is
at most line 11(a); there are twelve months. -/
def allowedOk (i : PtcAllowed.PtcAllowedIn) : Bool :=
  let o := PtcAllowed.ptcAllowed i
  o.ptcMonths.all (fun r => decide (r.ptcAllowed ≤ r.enrollmentPremium) &&
      decide (0 ≤ r.maxPremiumAssistance) && decide (r.ptcAllowed ≤ r.maxPremiumAssistance)) &&
    decide (o.annualPtcAllowed ≤ o.totalPtcAnnualPremium) &&
    decide (0 ≤ o.annualMaxPremiumAssistance) && o.ptcMonths.length == 12

/-- Line 24 is at most the premiums it covers: line 11(a) on the annual path, the sum of column
(a) on the monthly path. -/
def line24Ok (i : PtcAllowed.PtcAllowedIn) : Bool :=
  let o := PtcAllowed.ptcAllowed i
  decide (o.totalPtcAmountAllowed ≤
    if !o.mayNeedToFileForm8962 then 0
    else if o.ptcCanReportAnnualTotals then o.totalPtcAnnualPremium
    else Money.sumBy (·.enrollmentPremium) o.ptcMonths)

/-- With nonnegative amounts, column (e) and line 24 are nonnegative. -/
def allowedNonnegOk (i : PtcAllowed.PtcAllowedIn) : Bool :=
  let o := PtcAllowed.ptcAllowed i
  o.ptcMonths.all (fun r => decide (0 ≤ r.ptcAllowed)) && decide (0 ≤ o.totalPtcAmountAllowed)

#propMany (∀ (bs : List Bool) (xs ys zs : List Int), [1, 100, 10_000].all fun k =>
  allowedOk (allowedOf bs xs ys zs k))
#propMany (∀ (bs : List Bool) (xs ys zs : List Int), [1, 100, 10_000].all fun k =>
  line24Ok (allowedOf bs xs ys zs k))
#propMany (∀ (bs : List Bool) (xs ys zs : List Int), [1, 100, 10_000].all fun k =>
  allowedNonnegOk (allowedOf bs (nn xs) (nn ys) (nn zs) k))

/-! ### Lines 26 to 29 (Table 5) -/

/-- Line 28 is Table 5 as printed, never negative; line 29 is between `$0` and line 27 and, with a
limitation, at most the Table 5 amount; line 26 and line 27 are not both positive. -/
def netOk (fs : FilingStatus) (p : Rat) (zero : Bool) (allowed taken : Int) : Bool :=
  let o := PtcNet.netPtc {
    filingStatus := fs, householdIncomeAsPercent := p,
    taxFamilySizeIsZero := zero, totalPtcAmountAllowed := allowed, totalAptcAmountTaken := taken }
  let cap := Spec.table5Limit (decide (fs = .single)) p
  decide (0 ≤ o.line28) && decide (0 ≤ o.line29) && decide (o.line29 ≤ o.line27) &&
    decide (0 ≤ o.line26) && (o.line26 == 0 || o.line27 == 0) &&
    (zero || o.line28 == cap.getD 0) &&
    (zero || match cap with | some c => decide (o.line29 ≤ c) | none => o.line29 == o.line27) &&
    decide (o.line29 ≤ Spec.table5Max ∨ zero ∨ cap.isNone)

#prop (∀ (p a t : Int) (zero : Bool), FilingStatus.all.all fun fs => [1, 100, 10_000].all fun k =>
  netOk fs ((p % 450 : Int) : Rat) zero (a * k) (t * k))
#prop (∀ (p a t : Int) (zero : Bool), FilingStatus.all.all fun fs =>
  netOk fs ((p : Rat) / 7) zero (a * 1_000) (t * 1_000))

/-! ### HSA (Form 8889) -/

/-- An enum value from a random integer. -/
def pick {α} (l : List α) (d : α) (x : Int) : α := l.getD (x % (l.length : Int)).toNat d

/-- A filer's answers from random lists (bits `o` on, amounts `o` on). -/
def answersOf (bs : List Bool) (xs : List Int) (o : Nat) (k : Int) : Hsa.HsaFilerAnswers :=
  { writablePrimaryFilerHasMadeContributionsToHsa := !bit bs o
    writableSecondaryFilerHasMadeContributionsToHsa := !bit bs (o + 1)
    enrolledInMedicare := pick [.medicareNoneOfYear, .medicareNoneOfYear, .medicareAllYear,
      .medicarePartOfYear] .medicareNoneOfYear (num xs o 1)
    hsaHdhpCoverageStatus := pick [.hdhpAllYear, .hdhpAllYear, .hdhpPartOfYear, .hdhpNoneOfYear]
      .hdhpAllYear (num xs (o + 1) 1)
    typeOfHdhp := pick [.selfOnly, .family, .bothSelfAndFamily] .selfOnly (num xs (o + 2) 1)
    hadOtherCoverageIneligibleForHsa := pick [.otherCoverageNoneOfYear, .otherCoverageNoneOfYear,
      .otherCoverageWholeYear, .otherCoveragePartOfYear] .otherCoverageNoneOfYear (num xs (o + 3) 1)
    writableMfsLine6Check := bit bs (o + 2)
    writableChangeInMaritalStatusDuringTaxYear := if bit bs (o + 3)
      then .wasMarriedOrDivorcedThisYear else .wasNotMarriedNorDivorcedThisYear
    writableMaritalChangeAffectContributionLimitBool := bit bs (o + 4)
    hasMadeQualifiedHsaFundingDistribution := bit bs (o + 5)
    writableHsaNonemployerContributionsTaxYear := num xs (o + 4) k
    writableHsaNonemployerContributionsTaxYearPlusOne := num xs (o + 5) k }

/-- An `Hsa` input from random lists; distributions from `ds`. -/
def hsaOf (bs : List Bool) (xs : List Int) (ds : List (Int × Int)) (k : Int) : Hsa.HsaIn :=
  let married := bit bs 1
  { isFilingStatusMfj := married && !bit bs 0, isMarried := married, isSingle := !married
    primaryFilerAge55OrOlder := bit bs 2, secondaryFilerAge55OrOlder := bit bs 3
    primaryFilerCanBeClaimed := bit bs 4, secondaryFilerCanBeClaimed := bit bs 5
    primaryFilerTotalHsaContributionsFromW2s := num xs 0 k
    secondaryFilerTotalHsaContributionsFromW2s := num xs 1 k
    hasPrimaryFilerHsaContributionsFromW2s := decide (num xs 0 k > 0)
    hasSecondaryFilerHsaContributionsFromW2s := decide (num xs 1 k > 0)
    knockoutHasNoPaymentsOrCredits := bit bs 6, paidEstimatedTaxesOrFromLastYear := bit bs 7
    taxExemptInterest := 0, pensionsAndAnnuities := 0, socialSecurityBenefits := 0
    primaryFiler := answersOf bs xs 20 k, secondaryFiler := answersOf bs xs 40 k
    someFilerHadNonW2HsaActivity := !bit bs 8
    writablePrimaryFilerHadNonW2HsaActivity := !bit bs 9
    writableSecondaryFilerHadNonW2HsaActivity := !bit bs 10
    hasHsaMedicalSavingsAccountType := bit bs 11 && bit bs 12
    writableHasHsaExcessContributionsPreviousYear := bit bs 13 && bit bs 14
    writableHasHsaWithdrawnExcessContributionsYesNo := bit bs 15 && bit bs 16
    someFilersMadeTestingPeriodContribution := bit bs 17
    someFilersHaveTestingPeriodAdditionalIncome := bit bs 18
    hsaDistributions := ds.map fun (g, e) => { Hsa.normalDistribution (g * k) (e * k) with
      filer := if g % 2 = 0 then .primaryFiler else .secondaryFiler } }

/-- Line 13 is at most line 12, for each filer. -/
def hsaLe12Ok (i : Hsa.HsaIn) : Bool :=
  [FilerRole.primaryFiler, .secondaryFiler].all fun r =>
    decide (Hsa.filerHsaTotalDeductibleAmount i r ≤ Hsa.hsaContributionLimitLessLine11 i r)

/-- With nonnegative contributions: line 13 is nonnegative, line 12 is at most line 8, line 8
is at most $9,300 (the family limit plus the catch-up), and the total deduction is between $0 and
twice that. -/
def hsaBoundsOk (i : Hsa.HsaIn) : Bool :=
  ([FilerRole.primaryFiler, .secondaryFiler].all fun r =>
    decide (0 ≤ Hsa.filerHsaTotalDeductibleAmount i r) &&
      decide (Hsa.hsaContributionLimitLessLine11 i r ≤ Hsa.hsaTotalContributionLimit i r) &&
      decide (Hsa.hsaTotalContributionLimit i r ≤ Spec.hsaFilerLimitMax)) &&
    decide (0 ≤ Hsa.hsaTotalDeductibleAmount i) &&
    decide (Hsa.hsaTotalDeductibleAmount i ≤ 2 * Spec.hsaFilerLimitMax)

#propMany (∀ (bs : List Bool) (xs : List Int) (ds : List (Int × Int)), [1, 100, 10_000].all fun k =>
  hsaLe12Ok (hsaOf bs xs ds k))
#propMany (∀ (bs : List Bool) (xs : List Int) (ds : List (Int × Int)), [1, 100, 10_000].all fun k =>
  hsaBoundsOk (hsaOf bs (nn xs) ds k))
-- The region of the bounds is reached: some random input has a positive deduction.
#guard ([1, 2, 3, 4, 5, 6].map fun s => Hsa.hsaTotalDeductibleAmount
  (hsaOf [] [s, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3_000] [] 100))
  |>.any (· > 0)

/-! ### Negative control: a false statement must be refuted -/

-- "Line 13 is always line 2" is false (line 12 caps it); plausible must find a counterexample.
#eval do
  let r ← Testable.checkIO (NamedBinder "bs" <| ∀ bs : List Bool, NamedBinder "xs" <| ∀ xs : List Int,
    Hsa.filerHsaTotalDeductibleAmount (hsaOf bs (nn xs) [] 10_000) .primaryFiler =
      Hsa.hsaNonemployerContributionsTotal (hsaOf bs (nn xs) [] 10_000) .primaryFiler)
    { numInst := 2000, quiet := true }
  unless r matches .failure .. do throw (IO.userError "plausible missed a false statement")

/-- Single at 150 percent with an excess APTC of `t * $100`. -/
def excessAt (t : Int) : PtcNet.NetPtcIn :=
  { filingStatus := .single, householdIncomeAsPercent := 150, taxFamilySizeIsZero := false
    totalPtcAmountAllowed := 0, totalAptcAmountTaken := t * 10_000 }

-- "Line 29 is always line 27" is false (Table 5 limits it).
#eval do
  let r ← Testable.checkIO (NamedBinder "t" <| ∀ t : Int,
    (PtcNet.netPtc (excessAt t)).line29 = (PtcNet.netPtc (excessAt t)).line27)
    { numInst := 300, quiet := true }
  unless r matches .failure .. do throw (IO.userError "plausible missed a false statement")

end UsTax.PtcHsa.Props
