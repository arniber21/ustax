import UsTax.TaxRates.Spec
import Plausible

/-!
# Property tests for the rate schedules (plausible)

Each statement was tested here before its proof in `UsTax/TaxRates/Lemmas.lean`
or `UsTax/TaxRates/Spec.lean` was written (CLAUDE.md section 5), and the tests
run on every build: a counterexample fails the build. As in
`UsTax/Money/Props.lean` they use `Testable.check`, not the `plausible`
tactic, so nothing is admitted.

Plausible's random integers are small, so incomes are built as `a * k + c`
with several scales `k` (cents, dollars, $97, $9,973) to reach every bracket,
up to about $10 million. Filing statuses are enumerated (five checks each).
-/

namespace UsTax.TaxRates.Props
open Plausible

/-- `#prop p`: run plausible on `p` with 300 random instances; a
counterexample is an error. -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 300 })

/-- Income in cents from small random integers, at scale `k`. -/
def inc (k a c : Int) : Int := a * k + c

-- Line 16 is never negative (`tentativeTaxFor_nonneg`).
#prop (∀ a c : Int, FilingStatus.all.all fun fs =>
  0 ≤ tentativeTaxFor (inc 1 a c) fs ∧ 0 ≤ tentativeTaxFor (inc 9_700 a c) fs ∧
  0 ≤ tentativeTaxFor (inc 997_300 a c) fs)

-- Line 16 is monotone in taxable income (`tentativeTaxFor_mono`).
#prop (∀ a c : Int, ∀ d e : Nat, FilingStatus.all.all fun fs =>
  [1, 100, 9_700, 997_300].all fun k =>
    tentativeTaxFor (inc k a c) fs ≤ tentativeTaxFor (inc k a c + inc k d e) fs)

-- The code equals the readable specification (`tentativeTaxFor_eq_taxSpec`),
-- and Catala's cumulative form equals it too.
#prop (∀ a c : Int, FilingStatus.all.all fun fs =>
  [1, 100, 9_700, 997_300].all fun k =>
    tentativeTaxFor (inc k a c) fs = taxSpec fs (inc k a c) ∧
    tentativeTaxCumulativeFor (inc k a c) fs = taxSpec fs (inc k a c))

-- The midpoint: equal to the integer form, nonnegative, monotone.
#prop (∀ a c : Int, [1, 100, 2_500, 97_300].all fun k =>
  roundedTaxableIncomeOf (inc k a c) = taxTableIncome (inc k a c))
#prop (∀ a c : Int, ∀ d e : Nat, [1, 100, 2_500, 97_300].all fun k =>
  0 ≤ taxTableIncome (inc k a c) ∧
  taxTableIncome (inc k a c) ≤ taxTableIncome (inc k a c + inc k d e))

-- Negative control: the statement "line 16 is at most 10% of taxable income"
-- is false (above the 10% bracket), and plausible must find that.
#eval do
  let r ← Testable.checkIO (NamedBinder "a" <| ∀ a : Nat,
    tentativeTaxFor (inc 997_300 a 0) .single ≤ inc 997_300 a 0 / 10)
    { numInst := 300, quiet := true }
  unless r matches .failure .. do throw (IO.userError "plausible missed a false statement")

end UsTax.TaxRates.Props
