import UsTax.Eitc.Case
import UsTax.CtcOdc
import Plausible

/-!
# Property tests for the EITC and CTC/ODC modules (plausible, issue #46)

Each statement here was tested before it was proved (`UsTax/Proofs/Eitc.lean`,
`UsTax/Proofs/CtcOdc.lean`; CLAUDE.md section 5), and the tests run on every build. As in
`UsTax/TaxRates/Props.lean` they use `Testable.check`, so nothing is admitted. Random
integers are scaled to several magnitudes (cents up to millions of dollars) so that every
region of the credit is visited: phase-in, plateau, phase-out, past the completed
phase-out.
-/

namespace UsTax.Eitc.Props
open Plausible Eitc

/-- `#prop p`: run plausible on `p` with 300 random instances. -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 300 })

/-- `EitcWithinBounds` is decidable (a conjunction of integer comparisons). -/
instance (c : Spec.EitcCase) (x : Int) : Decidable (Spec.EitcWithinBounds c x) := by
  unfold Spec.EitcWithinBounds; infer_instance

/-- Cents from a small random integer at scale `k`. -/
def amt (k a : Int) : Int := a * k

/-- An `EitcTable` input from random figures: `n` is reduced to 0 to 5 children. -/
def tin (k a b : Int) (mfj : Bool) (n : Nat) : EitcTableIn :=
  { earnedIncome := amt k a, agi := amt k b, isMfj := mfj, qualifyingChildren := (n % 6 : Nat) }

-- The credit is never negative.
#prop (∀ (a b : Int) (mfj : Bool) (n : Nat), [1, 100, 10_000, 50_000, 300_000].all fun k =>
  0 ≤ eitc (tin k a b mfj n))

-- The credit is at most the maximum credit of the column.
#prop (∀ (a b : Int) (mfj : Bool) (n : Nat), [1, 100, 10_000, 50_000, 300_000].all fun k =>
  eitc (tin k a b mfj n) ≤ Spec.eitcMaxCredit (caseOf (tin k a b mfj n)).qualifyingChildren)

-- It is zero once the larger of earned income and AGI reaches the completed phase-out amount.
#prop (∀ (a b : Int) (mfj : Bool) (n : Nat), [1, 100, 10_000, 50_000, 300_000].all fun k =>
  let c := caseOf (tin k a b mfj n)
  !decide (Spec.eitcCompletedPhaseout c.qualifyingChildren c.marriedFilingJointly ≤
    max c.earnedIncome c.agi) || eitc (tin k a b mfj n) == 0)

-- All of it together, as stated in the spec.
#prop (∀ (a b : Int) (mfj : Bool) (n : Nat), [1, 100, 10_000, 50_000, 300_000].all fun k =>
  decide (Spec.EitcWithinBounds (caseOf (tin k a b mfj n)) (eitc (tin k a b mfj n))))

-- The completed phase-out of the code is the one of the spec (Rev. Proc. 2023-34).
#prop (∀ (a b : Int) (mfj : Bool) (n : Nat), [1, 100, 10_000, 50_000, 300_000].all fun k =>
  (eitcTable (tin k a b mfj n)).completedPhaseout ==
    Spec.eitcCompletedPhaseout (caseOf (tin k a b mfj n)).qualifyingChildren mfj)

-- The maximum credit of the code is the one of the spec.
#prop (∀ (a b : Int) (mfj : Bool) (n : Nat), [1, 100, 10_000, 50_000, 300_000].all fun k =>
  (eitcTable (tin k a b mfj n)).maxCredit ==
    Spec.eitcMaxCredit (caseOf (tin k a b mfj n)).qualifyingChildren)

end UsTax.Eitc.Props

namespace UsTax.CtcOdc.Props
open Plausible CtcOdc

/-- `#prop p`: run plausible on `p` with 300 random instances. -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 300 })

/-- A Schedule 8812 from random figures: `ctc`, `odc` children (0 to 5), status `s`. -/
def sched (k : Int) (ctc odc : Nat) (s : Nat) (agi tax earned ss eic cdcc : Int) :
    Schedule8812Out :=
  schedule8812
    { ctcEligibleDependents := (ctc % 6 : Nat), odcEligibleDependents := (odc % 6 : Nat)
      filingStatus := FilingStatus.all.getD (s % 5) .single, agi := agi * k
      totalTentativeTax := tax * k, cdccTotalCredit := (cdcc.natAbs : Int) * k, qualifiedSaverCreditAmount := 0
      totalEdc := 0, employerIncomeSubtotal := earned * k, allCombatPay := 0
      socialSecurityTaxesWithheld := ss * k, earnedIncomeCredit := eic * k
      receivedImproperClaims := false, receivedImproperClaimsNotice := .notAnswered
      improperClaimsNoticeExpired := false, hasFiledCtcOdcSinceNoticeExpired := false }

-- The CTC/ODC (Form 1040 line 19) is never negative.
#prop (∀ (c o s : Nat) (a t e ss eic cd : Int), [100, 10_000, 1_000_000].all fun k =>
  0 ≤ (sched k c o s a t e ss eic cd).totalCtcAndOdc)

-- The additional child tax credit (line 28) is never negative.
#prop (∀ (c o s : Nat) (a t e ss eic cd : Int), [100, 10_000, 1_000_000].all fun k =>
  0 ≤ (sched k c o s a t e ss eic cd).additionalCtc)

-- The additional child tax credit is at most $1,700 per qualifying child.
#prop (∀ (c o s : Nat) (a t e ss eic cd : Int), [100, 10_000, 1_000_000].all fun k =>
  (sched k c o s a t e ss eic cd).additionalCtc ≤ 170_000 * (c % 6 : Nat))

-- The CTC/ODC never exceeds the potential credit before the phase-out ($2,000 and $500 each).
#prop (∀ (c o s : Nat) (a t e ss eic cd : Int), [100, 10_000, 1_000_000].all fun k =>
  (sched k c o s a t e ss eic cd).totalCtcAndOdc ≤ 200_000 * (c % 6 : Nat) + 50_000 * (o % 6 : Nat))

-- The CTC/ODC never exceeds the tax (the credit limit; the other credits are nonnegative:
-- with a negative child care credit the limit would exceed the tax, which this test found).
#prop (∀ (c o s : Nat) (a t e ss eic cd : Int), [100, 10_000, 1_000_000].all fun k =>
  (sched k c o s a t e ss eic cd).totalCtcAndOdc ≤ max 0 (t * k))

-- The phase-out reduction does not decrease when AGI grows.
#prop (∀ (c o s : Nat) (a a' t : Int), [100, 10_000, 1_000_000].all fun k =>
  a ≤ a' →
    (sched k c o s a t 0 0 0 0).dependentCreditPhaseout ≤
      (sched k c o s a' t 0 0 0 0).dependentCreditPhaseout)

end UsTax.CtcOdc.Props
