import UsTax.Calculator
import UsTax.ApiCalculator
import Plausible

/-!
# Property tests for the whole return (plausible, issue #48)

Each statement of `UsTax/Proofs/Calculator.lean` was tested here before it was proved
(CLAUDE.md section 5), and the tests run on every build. As in `UsTax/Form1040/Props.lean` they
use `Testable.check`, so nothing is admitted. Returns are built from random wages, withholding,
estimated payments, interest and a random number of children in every filing status (so refunds,
balances due, credits up to the tax, the EITC and knockouts all occur); the knockout statements
also flip random screening answers.
-/

namespace UsTax.Calculator.Props
open Plausible Calculator Tests

/-- `#prop p`: run plausible on `p` with 200 random instances. -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 200 })

/-- A return in status `fs` from small random integers: wages `a × $97`, withholding `b × $13`,
`kids` children (0 to 3), estimated payments `e × $7`, interest `n × $11`, the screening answers
`ira` and `digital`. -/
def gen (fs : FilingStatus) (a b kids e n : Int) (ira digital : Bool) : CalculatorIn :=
  let base := ret fs [mkW2 (a.natAbs * 9_700) (b.natAbs * 1_300)]
    ((List.range (kids.natAbs % 4)).map fun k => mkChild ⟨((2010 + k : Nat) : Int), 5, 1⟩)
    (if fs == .marriedFilingJointly || fs == .marriedFilingSeparately then
      { defaultFilers with maritalStatus := .married }
     else if fs == .qualifyingSurvivingSpouse then
      { defaultFilers with maritalStatus := .widowed, yearOfSpouseDeath := .diedTaxYearMinusOne
                           canFileJointlyYearOfSpouseDeath := true }
     else defaultFilers)
  { base with
    income := { base.income with
      interestReports := [{ has1099 := true, writable1099Amount := n.natAbs * 1_100 }] }
    payments := { paidEstimatedTaxesOrFromLastYear := e != 0
                  estimatedTaxPaymentWritable := e.natAbs * 700 }
    screening := { madeIraContributions := ira, receivedDigitalAssets := digital } }

-- Refund and balance due (`calculator_refund_balanceDue_consistent`).
#prop (∀ a b k e n : Int, FilingStatus.all.all fun fs =>
  let o := calculator (gen fs a b k e n false false)
  0 ≤ o.overpayment && 0 ≤ o.balanceDue && (o.overpayment == 0 || o.balanceDue == 0) &&
    o.overpayment - o.balanceDue == Money.roundDollar (o.totalPayments - o.totalTax))

-- Nonrefundable credits used never exceed the tax; total tax is never negative
-- (`calculator_credits_within_liability`, `calculator_totalTax_nonneg`).
#prop (∀ a b k e n : Int, FilingStatus.all.all fun fs =>
  let o := calculator (gen fs a b k e n false false)
  o.taxLessNonRefundableCredits == max 0 (o.totalTentativeTax - o.nonRefundableCredits) &&
    0 ≤ o.totalTax)

-- The CDCC, Schedule R and Saver's credits together are within the tax they are limited by
-- (`calculator_credits_le_tax`, issue #66).
#prop (∀ a b k e n : Int, FilingStatus.all.all fun fs =>
  let o := calculator (gen fs a b k e n false false)
  o.cdccTotalCredit + o.totalEdc + o.qualifiedSaverCreditAmount ≤ o.fTax.totalTentativeTax)

-- Knockout soundness: unsupported exactly when a reason fired (`calculator_unsupported_iff`).
#prop (∀ a b k e n : Int, ∀ ira digital : Bool, FilingStatus.all.all fun fs =>
  let o := calculator (gen fs a b k e n ira digital)
  o.unsupported == !o.firedKnockouts.isEmpty)

-- The API outputs: supported exactly when no reason; refund exactly when line 34 is positive
-- (`apiCalculator_supported_iff`, `apiCalculator_outcome_refund_iff`).
#prop (∀ a b k e n : Int, ∀ ira digital : Bool, FilingStatus.all.all fun fs =>
  let c := calculator (gen fs a b k e n ira digital)
  let o : ApiCalculator.ApiCalculatorOut :=
    { supported := !c.unsupported, reasons := if c.unsupported then c.firedKnockouts else []
      lines := if c.unsupported then ApiCalculator.zeroLines else ApiCalculator.linesOf c
      outcome := if c.unsupported then .even else ApiCalculator.outcomeOf c.overpayment c.balanceDue
      calculation := c }
  (o.supported == o.reasons.isEmpty) && ((o.outcome == .refund) == decide (0 < o.lines.overpayment)))

-- Negative control: "every return gets a refund" is false, and plausible must find that.
#eval do
  let r ← Testable.checkIO (NamedBinder "a" <| ∀ a : Nat,
    (calculator (gen .single a 0 0 0 0 false false)).overpayment > 0)
    { numInst := 200, quiet := true }
  unless r matches .failure .. do throw (IO.userError "plausible missed a false statement")

end UsTax.Calculator.Props
