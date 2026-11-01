import UsTax.Eitc
import UsTax.Spec.Eitc

/-!
# The EITC bounds statement, applied to the calculator (issues #46, #67)

`EitcWithinBounds` (`UsTax/Spec/Eitc.lean`, reviewed, unchanged) says what the credit may be
given four facts (`EitcCase`). This file says which four facts of the calculator's input
they are and which number is "the credit": the two small definitions the statement in
`UsTax/Comparator/Challenge.lean` mentions besides the calculator itself.

* `caseOf i`: the number of qualifying children (`Int` in the calculator, as in Catala;
  `Nat` in the spec, "3 means 3 or more"), the joint flag, earned income and AGI of the
  input `i` of scope `EitcTable`. A negative count is no return; the calculator gives it the
  "3 or more" column (the `else` branch of Catala's `if` chain), and so does `caseOf`, so the
  bounds hold for every input without a hypothesis.
* `eitc i`: the output `amount` of scope `EitcTable`, the credit the printed EIC Table gives.
-/

namespace UsTax.Eitc

/-- The four facts of an `EitcTable` input that the bounds depend on. -/
def caseOf (i : EitcTableIn) : Spec.EitcCase :=
  { qualifyingChildren := if i.qualifyingChildren < 0 then 3 else i.qualifyingChildren.toNat
    marriedFilingJointly := i.isMfj, earnedIncome := i.earnedIncome, agi := i.agi }

/-- The credit the calculator computes for an `EitcTable` input (cents). -/
def eitc (i : EitcTableIn) : Int := (eitcTable i).amount

end UsTax.Eitc
