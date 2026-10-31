import UsTax.Form1040
import Plausible

/-!
# Property tests for the Form 1040 assembly (plausible, issue #43)

Each statement here was tested before it was proved in
`UsTax/Form1040/Lemmas.lean` (CLAUDE.md section 5), and the tests run on every
build. As in `UsTax/TaxRates/Props.lean` they use `Testable.check`, so nothing
is admitted. Returns are built from random W-2 wages and withholding at several
scales, in every filing status, with random plug-in slots, so both a refund and
a balance due occur.
-/

namespace UsTax.Form1040.Props
open Plausible Form1040

/-- `#prop p`: run plausible on `p` with 300 random instances. -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 300 })

/-- Amount in cents from small random integers at scale `k`. -/
def amt (k a c : Int) : Int := a * k + c

/-- A return with one W-2, one 1099-INT and random slots, in status `fs`. -/
def ret (fs : FilingStatus) (wages whold int slot credit : Int) : Form1040In :=
  { run [{ writableWages := wages, writableFederalWithholding := whold }]
      [{ has1099 := true, writable1099Amount := int }] fs with
    estimatedAndFromLastYear := slot, totalCtcAndOdc := credit }

-- Refund and balance due are exclusive (`overpayment_eq_zero_or_balanceDue_eq_zero`).
#prop (∀ a b c d e : Int, FilingStatus.all.all fun fs =>
  [1, 100, 9_700, 997_300].all fun k =>
    let o := form1040 (ret fs (amt k a 0) (amt k b 0) (amt 100 c 0) (amt k d 0) (amt k e 0))
    o.overpayment = 0 || o.balanceDue = 0)

-- Both are nonnegative.
#prop (∀ a b c d e : Int, FilingStatus.all.all fun fs =>
  [1, 100, 9_700, 997_300].all fun k =>
    let o := form1040 (ret fs (amt k a 0) (amt k b 0) (amt 100 c 0) (amt k d 0) (amt k e 0))
    0 ≤ o.overpayment && 0 ≤ o.balanceDue)

-- Refund minus balance due is payments minus tax, to the dollar (both are whole dollars).
#prop (∀ a b c d e : Int, FilingStatus.all.all fun fs =>
  [1, 100, 9_700, 997_300].all fun k =>
    let o := form1040 (ret fs (amt k a 0) (amt k b 0) (amt 100 c 0) (amt k d 0) (amt k e 0))
    o.overpayment - o.balanceDue = Money.roundDollar (o.totalPayments - o.totalTax))

-- Taxable income is never negative (line 15 "if zero or less, enter -0-").
#prop (∀ a b c d e : Int, FilingStatus.all.all fun fs =>
  [1, 100, 9_700, 997_300].all fun k =>
    let o := form1040 (ret fs (amt k a 0) (amt k b 0) (amt 100 c 0) (amt k d 0) (amt k e 0))
    0 ≤ o.taxableIncome)

-- Negative control: "a refund is always owed" is false, and plausible must find that.
#eval do
  let r ← Testable.checkIO (NamedBinder "a" <| ∀ a : Nat,
    (form1040 (ret .single (amt 100 a 0) 0 0 0 0)).overpayment > 0)
    { numInst := 300, quiet := true }
  unless r matches .failure .. do throw (IO.userError "plausible missed a false statement")

end UsTax.Form1040.Props
