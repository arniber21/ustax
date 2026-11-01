import UsTax.Money
import UsTax.Lists
import UsTax.Types
import UsTax.Params2024

/-!
# Unemployment compensation: Form 1099-G (Schedule 1 line 7, Form 1040 line 8) (issue #45)

Lean implementation of `catala/unemployment.catala_en` (module `Unemployment`, scopes
`Form1099GFacts` and `Unemployment`), written by hand from the Catala source under
strategy (c) of `docs/catala-to-lean.md`; the code that runs.

| Catala (`Unemployment`)             | Lean (`UsTax.Unemployment`)                      |
|-------------------------------------|--------------------------------------------------|
| `structure Form1099G`               | `Form1099G` (lower camel case fields)            |
| `scope Form1099GFacts`              | `Form1099GFacts` (`form1099GFacts : Form1099G → Form1099GFacts`) |
| `scope Unemployment`                | `UnemploymentIn` → `UnemploymentOut` (`unemployment`) |
| `facts` (internal)                  | `facts := form1099Gs.map form1099GFacts`         |

Money is `Int` cents. The nets are summed with cents and rounded once
(`roundDollar`); box 4 is rounded per form and the rounded amounts are added.
-/

namespace UsTax.Unemployment

open Money

/-- One entry of DF `/form1099Gs` (Catala `Form1099G`). Cents. -/
structure Form1099G where
  /-- Catala `filer`. -/
  filer : FilerRole := .primaryFiler
  /-- Catala `amount` (box 1). -/
  amount : Int := 0
  /-- Catala `writable_amount_paid_back_for_benefits_in_tax_year`. -/
  writableAmountPaidBackForBenefitsInTaxYear : Int := 0
  /-- Catala `writable_amount_paid_back_for_benefits_before_tax_year`. -/
  writableAmountPaidBackForBenefitsBeforeTaxYear : Int := 0
  /-- Catala `writable_federal_tax_withheld` (box 4). -/
  writableFederalTaxWithheld : Int := 0
  /-- Catala `state_is_different_state`. -/
  stateIsDifferentState : Bool := false

/-- Outputs of `Form1099GFacts`. -/
structure Form1099GFacts where
  /-- Catala `amount_paid_back_for_benefits_in_tax_year`. -/
  amountPaidBackForBenefitsInTaxYear : Int
  /-- Catala `net_unemployment_comp`. -/
  netUnemploymentComp : Int
  /-- Catala `amount_paid_back_for_benefits_before_tax_year`. -/
  amountPaidBackForBenefitsBeforeTaxYear : Int
  /-- Catala `federal_tax_withheld`. -/
  federalTaxWithheld : Int
  /-- Catala `has_knockout_unemployment_compensation_in_different_state`. -/
  hasKnockoutUnemploymentCompensationInDifferentState : Bool

/-- Catala `scope Form1099GFacts`. The in-year repayment is capped at box 1
(DF-BUG(candidate) kept as in Catala). -/
def form1099GFacts (form : Form1099G) : Form1099GFacts :=
  let paidBack := Money.min form.writableAmountPaidBackForBenefitsInTaxYear form.amount
  { amountPaidBackForBenefitsInTaxYear := paidBack
    netUnemploymentComp := form.amount - paidBack
    amountPaidBackForBenefitsBeforeTaxYear := form.writableAmountPaidBackForBenefitsBeforeTaxYear
    federalTaxWithheld := roundDollar form.writableFederalTaxWithheld
    hasKnockoutUnemploymentCompensationInDifferentState := form.stateIsDifferentState }

/-- Inputs of `Unemployment`. -/
structure UnemploymentIn where
  /-- Catala input `form_1099gs`. -/
  form1099Gs : List Form1099G

/-- Outputs of `Unemployment`. -/
structure UnemploymentOut where
  /-- Schedule 1 line 7. -/
  unemploymentCompensation : Int
  /-- The "Repaid" amount next to line 7. -/
  unemploymentCompRepaidAmt : Int
  /-- Catala `received_unemployment_compensation`. -/
  receivedUnemploymentCompensation : Bool
  /-- Catala `has_repaid_unemployment_compensation`. -/
  hasRepaidUnemploymentCompensation : Bool
  /-- Catala `total_amount_paid_back_for_benefits_before_tax_year`. -/
  totalAmountPaidBackForBenefitsBeforeTaxYear : Int
  /-- The 1099-G term of line 25b. -/
  form1099gFederalTaxWithheld : Int
  /-- Catala `ko_flow_knockout1099_g_repay_too_high`. -/
  koFlowKnockout1099GRepayTooHigh : Bool
  /-- Catala `ko_flow_knockout_unemployment_compensation_unsupported_state`. -/
  koFlowKnockoutUnemploymentCompensationUnsupportedState : Bool
  /-- Every knockout of this scope. -/
  unsupported : Bool

/-- Catala `scope Unemployment`. -/
def unemployment (i : UnemploymentIn) : UnemploymentOut :=
  let facts := i.form1099Gs.map form1099GFacts
  let unemploymentCompensation := roundDollar (sumBy (·.netUnemploymentComp) facts)
  let repaid := roundDollar (sumBy (·.amountPaidBackForBenefitsInTaxYear) facts)
  let received := i.form1099Gs.any fun f => decide (f.amount > 0)
  let before := sumBy (·.amountPaidBackForBenefitsBeforeTaxYear) facts
  let koRepay := decide (before > Params.claimOfRightThreshold)
  let koState := facts.any (·.hasKnockoutUnemploymentCompensationInDifferentState)
  { unemploymentCompensation := unemploymentCompensation
    unemploymentCompRepaidAmt := repaid
    receivedUnemploymentCompensation := received
    hasRepaidUnemploymentCompensation := received && decide (repaid > 0)
    totalAmountPaidBackForBenefitsBeforeTaxYear := before
    form1099gFederalTaxWithheld := sumBy (·.federalTaxWithheld) facts
    koFlowKnockout1099GRepayTooHigh := koRepay
    koFlowKnockoutUnemploymentCompensationUnsupportedState := koState
    unsupported := koRepay || koState }

/-! ### Unit tests: every assertion of `catala/tests/test_unemployment.catala_en` -/

/-- Catala helper `MkG`. -/
private def mkG (amount : Int) (inYear before withheld : Int := 0) (diff : Bool := false) : Form1099G :=
  { amount := amount, writableAmountPaidBackForBenefitsInTaxYear := inYear,
    writableAmountPaidBackForBenefitsBeforeTaxYear := before,
    writableFederalTaxWithheld := withheld, stateIsDifferentState := diff }

private def run (fs : List Form1099G) : UnemploymentOut := unemployment { form1099Gs := fs }

-- TestRepaidInYearIsSubtracted
private def t1 := run [mkG 500_000 (inYear := 120_000)]
#guard t1.unemploymentCompensation == 380_000
#guard t1.unemploymentCompRepaidAmt == 120_000
#guard t1.receivedUnemploymentCompensation
#guard !t1.unsupported
#guard t1.unemploymentCompensation != 500_000
#guard t1.unemploymentCompensation != 620_000

-- TestRepaymentClampsToBox1
private def t2 := run [mkG 200_000 (inYear := 250_000)]
#guard t2.unemploymentCompensation == 0
#guard t2.unemploymentCompRepaidAmt == 200_000
#guard decide (t2.unemploymentCompensation ≥ 0)

-- TestSumRoundedOnce
private def t3 := run [mkG 10_040, mkG 10_040]
#guard t3.unemploymentCompensation == 20_100
#guard t3.unemploymentCompensation != 20_000

-- TestWithholdingRoundedPerForm
private def t4 := run [mkG 100_000 (withheld := 5_040), mkG 100_000 (withheld := 5_040)]
#guard t4.form1099gFederalTaxWithheld == 10_000
#guard t4.form1099gFederalTaxWithheld != 10_100

-- TestRepayAt3000IsAllowed
private def t5 := run [mkG 1_000_000 (before := 300_000)]
#guard !t5.koFlowKnockout1099GRepayTooHigh
#guard !t5.unsupported
#guard t5.totalAmountPaidBackForBenefitsBeforeTaxYear == 300_000

-- TestRepayAbove3000IsKnockedOut
private def t6 := run [mkG 1_000_000 (before := 300_001)]
#guard t6.koFlowKnockout1099GRepayTooHigh
#guard t6.unsupported

-- TestRepayTotalOverTwoFormsIsKnockedOut
private def t7 := run [mkG 1_000_000 (before := 200_000),
  mkG 1_000_000 (inYear := 900_000) (before := 150_000)]
#guard t7.koFlowKnockout1099GRepayTooHigh
#guard t7.unsupported

-- TestDifferentStateIsKnockedOut
private def t8 := run [mkG 100_000 (diff := true)]
#guard t8.koFlowKnockoutUnemploymentCompensationUnsupportedState
#guard !t8.koFlowKnockout1099GRepayTooHigh
#guard t8.unsupported

-- TestNoForms
private def t9 := run []
#guard t9.unemploymentCompensation == 0
#guard !t9.receivedUnemploymentCompensation
#guard !t9.unsupported

end UsTax.Unemployment
