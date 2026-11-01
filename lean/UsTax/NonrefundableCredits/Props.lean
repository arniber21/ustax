import UsTax.SaversCredit
import UsTax.ElderlyAndDisabled
import UsTax.Cdcc
import Plausible

/-!
# Property tests for the CDCC, Saver's credit and Schedule R modules (plausible, issue #46)

The statements of `UsTax/NonrefundableCredits/Lemmas.lean`, run on random inputs on every build
(CLAUDE.md section 5). As in `UsTax/Income/Props.lean` they use `Testable.check`, so nothing is
admitted. Amounts are random integers (cents) at several scales, so the tests cross the AGI
bands, the caps and the tax limit. A negative control that must fail ends the file.
-/

namespace UsTax.NonrefundableCredits.Props
open Plausible

/-- `#prop p`: run plausible on `p` with 300 random instances. -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 300 })

/-- Amount in cents from a small random integer at scale `k`. -/
def amt (k a : Int) : Int := a * k

/-! ### Saver's credit -/

/-- A Saver's credit input from random integers. -/
def savers (fs : FilingStatus) (k agi d1 d2 x1 x2 tax cd ed : Int) : SaversCredit.SaversCreditIn :=
  { SaversCredit.base with
      filingStatus := fs, agi := amt (k * 40) agi
      primaryFilerTotalDeferralsAndContributions := amt k d1
      secondaryFilerTotalDeferralsAndContributions := amt k d2
      primaryFilerSaversGrossDistributions := amt k x1
      secondaryFilerSaversGrossDistributions := amt k x2
      totalTentativeTax := amt k tax, cdccTotalCredit := amt k cd, totalEdc := amt k ed }

/-- The bounds of `Savers.credit_nonneg`, `credit_le_ratioed`, `credit_le_limitation`, `credit_le_2000`. -/
def saversBoundsOk (i : SaversCredit.SaversCreditIn) : Bool :=
  let o := SaversCredit.saversCredit i
  decide (0 ≤ o.qualifiedSaverCreditAmount) &&
    decide (o.qualifiedSaverCreditAmount ≤ o.ratioedCombinedCreditLimit) &&
    decide (o.qualifiedSaverCreditAmount ≤ o.limitationBasedOnTaxLiability) &&
    decide (o.qualifiedSaverCreditAmount ≤ 200_000)

/-- The statement of `Savers.credit_pos_imp_sum_le_tax`. -/
def saversFitsOk (i : SaversCredit.SaversCreditIn) : Bool :=
  let o := SaversCredit.saversCredit i
  !decide (0 < o.qualifiedSaverCreditAmount) ||
    decide (i.cdccTotalCredit + i.totalEdc + o.qualifiedSaverCreditAmount ≤ i.totalTentativeTax)

-- 0 <= credit <= min(line 10, line 11), and <= $2,000, in every status.
#prop (∀ agi d1 d2 x tax cd : Int, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  saversBoundsOk (savers fs k agi d1 d2 x (x / 3) tax cd (cd / 2)))

-- A positive credit fits in the tax left after the CDCC and Schedule R.
#prop (∀ agi d1 d2 x tax cd : Int, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  saversFitsOk (savers fs k agi d1 d2 x (x / 3) tax cd (cd / 2)))

-- Each column's line 6 is between $0 and $2,000.
#prop (∀ a b c : Int, [1, 100, 99_700].all fun k =>
  let o := SaversCredit.saversColumn { line1 := amt k a, line2 := amt k b, line4 := amt k c }
  0 ≤ o.line6 && o.line6 ≤ 200_000)

/-! ### Schedule R -/

/-- A Schedule R input from random integers: one or two filers, ages and disability varied. -/
def schr (fs : FilingStatus) (k a b c d e f : Int) : ElderlyAndDisabled.ScheduleRIn :=
  let ans (w : Bool) (n : Int) : ElderlyAndDisabled.DisabilityAnswers :=
    ElderlyAndDisabled.runAnswers w (amt k n)
  { filingStatus := fs, livedApartAllYear := e % 2 == 0, primaryAge65OrOlder := a % 3 == 0
    secondaryAge65OrOlder := b % 3 == 0, primaryAnswers := ans (c % 2 == 0) (c / 2)
    secondaryAnswers := ans (d % 2 == 0) (d / 2), agi := amt (k * 3) e
    nonTaxableSocialSecurityBenefits := amt k (f % 7)
    selfReportedNonTaxablePayments := amt k (f / 7), creditLimitWorksheetLine3 := amt (k * 5) f }

-- 0 <= credit <= min(line 20, positive line 3), and <= $1,125, in every status.
#prop (∀ a b c d e f : Int, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  let i := schr fs k a b c d e f
  let o := ElderlyAndDisabled.scheduleR i
  0 ≤ o.totalEdc && o.totalEdc ≤ o.netEdcAmount && o.totalEdc ≤ max 0 i.creditLimitWorksheetLine3 &&
    o.totalEdc ≤ 112_500)

-- Line 19 is between $0 and $7,500.
#prop (∀ a b c d e f : Int, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  let o := ElderlyAndDisabled.scheduleR (schr fs k a b c d e f)
  0 ≤ o.edcNetCreditAmount && o.edcNetCreditAmount ≤ 750_000)

/-! ### Child and dependent care credit -/

open Cdcc in
/-- A Form 2441 input from random integers, on the CDCC test helper `Case`. -/
def cdcc (k agi wages exp ben tax : Int) (mfj : Bool) : Form2441In :=
  ({ agi := amt (k * 10) agi, primaryWages := amt (k * 10) wages, childExpenses := amt k exp,
     primaryBenefits := amt k (ben % 9), primaryPlanMax := amt k (ben % 9), line16 := amt k exp,
     taxLimit := amt k tax,
     filingStatus := if mfj then .marriedFilingJointly else .headOfHousehold,
     secondaryWages := amt k wages } : Case).input

-- The applicable percentage is between 20 and 35 percent, at every AGI.
#prop (∀ agi : Int, [1, 100, 99_700].all fun k =>
  decide (20 / 100 ≤ Cdcc.applicablePercentage (agi * k)) &&
    decide (Cdcc.applicablePercentage (agi * k) ≤ 35 / 100))

-- 0 <= credit <= positive tax, and <= $2,100 (no Part III, so the caps apply directly).
#prop (∀ agi wages exp tax : Int, [true, false].all fun mfj => [1, 100, 99_700].all fun k =>
  let o := Cdcc.form2441 (cdcc k agi wages exp 0 tax mfj)
  0 ≤ o.cdccTotalCredit && o.cdccTotalCredit ≤ max 0 o.line9c &&
    o.cdccTotalCredit ≤ max 0 (amt k tax) && o.cdccTotalCredit ≤ 210_000)

-- A positive credit fits in the tax.
#prop (∀ agi wages exp ben tax : Int, [true, false].all fun mfj => [1, 100, 99_700].all fun k =>
  let o := Cdcc.form2441 (cdcc k agi wages exp ben tax mfj)
  !decide (0 < o.cdccTotalCredit) || decide (o.cdccTotalCredit ≤ amt k tax))

-- Negative control: "the CDCC is at most $1,000" is false, and plausible must find that.
#eval do
  let r ← Testable.checkIO (NamedBinder "agi" <| ∀ agi : Int,
    (Cdcc.form2441 (cdcc 99_700 (agi % 20) 1000 3 0 100_000 false)).cdccTotalCredit ≤ 100_000)
    { numInst := 300, quiet := true }
  unless r matches .failure .. do throw (IO.userError "plausible missed a false statement")

end UsTax.NonrefundableCredits.Props
