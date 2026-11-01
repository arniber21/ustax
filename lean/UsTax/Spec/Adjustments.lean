import UsTax.Types
import UsTax.Spec.Rounding

/-!
# Spec: educator expenses and student loan interest (issue #64)

Two Schedule 1 adjustments, as the statute reads. Amounts in cents. Imports
only `FilingStatus` and `Spec.Rounding`.

**Educator expenses** (Schedule 1 line 11), IRC 62(a)(2)(D), Rev. Proc.
2023-34 § 3.13: each eligible educator deducts their expenses up to $300; on
a joint return where both are educators, up to $300 each. Nothing if the
filers are dependents on someone else's joint return.

**Student loan interest** (Schedule 1 line 21), IRC 221, Rev. Proc. 2023-34
§ 3.30:

* 221(b)(1): at most $2,500;
* 221(b)(2): reduced by the fraction (MAGI − $80,000) / $15,000, or
  (MAGI − $165,000) / $30,000 on a joint return, capped at 1 (so nothing from
  $95,000 / $195,000);
* 221(e)(2): nothing if married filing separately; 221(c): nothing if the
  filer can be claimed as a dependent; also nothing without qualifying
  interest paid.

The result is rounded once to the dollar (DF-BUG(7): Direct File rounds the
fraction to three decimals first; we follow the statute).
-/

namespace UsTax.Spec

/-- IRC 62(a)(2)(D): one educator's deductible expenses, up to $300. -/
def educatorShare (isEducator : Bool) (expenses : Int) : Int :=
  if isEducator then min 300_00 expenses else 0

/-- Schedule 1 line 11: the two filers' shares, rounded to the dollar; `$0`
for dependents on another joint return. -/
def educatorDeduction (tpIsEducator spouseIsEducator : Bool) (tpExpenses spouseExpenses : Int)
    (dependentOnJointReturn : Bool) : Int :=
  if dependentOnJointReturn then 0
  else roundToDollar (educatorShare tpIsEducator tpExpenses + educatorShare spouseIsEducator spouseExpenses)

/-- IRC 221(b)(2)(B): where the phase-out starts. -/
def studentLoanPhaseoutStart (fs : FilingStatus) : Int :=
  if fs = .marriedFilingJointly then 165_000_00 else 80_000_00

/-- IRC 221(b)(2)(B): the width of the phase-out range. -/
def studentLoanPhaseoutRange (fs : FilingStatus) : Int :=
  if fs = .marriedFilingJointly then 30_000_00 else 15_000_00

/-- Schedule 1 line 21: `capped × (1 − excess / range)` rounded to the dollar,
where `capped = min(interest, $2,500)` and `excess` is MAGI over the start,
between `0` and `range`. Written in integers: `capped × (range − excess)`
cents divided by `range`, rounded to the dollar. -/
def studentLoanDeduction (fs : FilingStatus) (eligible : Bool) (interestPaid magi : Int) : Int :=
  if fs = .marriedFilingSeparately ∨ eligible = false then 0
  else
    let capped := min interestPaid 2_500_00
    let range := studentLoanPhaseoutRange fs
    let excess := min (max 0 (magi - studentLoanPhaseoutStart fs)) range
    roundHalfAway (capped * (range - excess)) (100 * range) * 100

/-- One educator with $450 of expenses: $300. Both, $450 and $120: $420. -/
example : educatorDeduction true false 450_00 0 false = 300_00 ∧
    educatorDeduction true true 450_00 120_00 false = 420_00 := by decide

/-- Rejected: $450 (no cap) for one educator; $600 when the spouse is not an
educator. -/
example : educatorDeduction true false 450_00 450_00 false ≠ 450_00 ∧
    educatorDeduction true false 450_00 450_00 false ≠ 600_00 := by decide

/-- Single, $3,000 of interest: $2,500 at $70,000 of MAGI, $1,250 halfway
through the phase-out ($87,500), $1,667 at $85,000 (one third phased out:
$2,500 × 2/3 = $1,666.67), `$0` at $95,000. -/
example : studentLoanDeduction .single true 3_000_00 70_000_00 = 2_500_00 ∧
    studentLoanDeduction .single true 3_000_00 87_500_00 = 1_250_00 ∧
    studentLoanDeduction .single true 3_000_00 85_000_00 = 1_667_00 ∧
    studentLoanDeduction .single true 3_000_00 95_000_00 = 0 := by decide

/-- Rejected: Direct File's three-decimal ratio would give $1,668 (0.333
phased out); married filing separately gets nothing. -/
example : studentLoanDeduction .single true 3_000_00 85_000_00 ≠ 1_668_00 ∧
    studentLoanDeduction .marriedFilingSeparately true 3_000_00 50_000_00 ≠ 2_500_00 := by decide

end UsTax.Spec
