import UsTax.Money

/-!
# Estimated tax payments: Form 1040 line 26 (issue #45)

Lean implementation of `catala/estimated_payments.catala_en` (module
`Estimated_payments`, scope `EstimatedPayments`), written by hand from the Catala
source under strategy (c) of `docs/catala-to-lean.md`; the code that runs.

| Catala (`Estimated_payments`)        | Lean (`UsTax.EstimatedPayments`)             |
|--------------------------------------|----------------------------------------------|
| `enumeration PaidWithFormerSpouse`   | `PaidWithFormerSpouse` (`spouseDid`, `bothDid`, `tpDid`, `neither`) |
| `scope EstimatedPayments`            | `EstimatedPaymentsIn` → `EstimatedPaymentsOut` (`estimatedPayments`) |

Money is `Int` cents.
-/

namespace UsTax.EstimatedPayments

open Money

/-- Catala `PaidWithFormerSpouse`. -/
inductive PaidWithFormerSpouse where
  /-- The spouse paid with the former spouse. -/
  | spouseDid
  /-- Both did. -/
  | bothDid
  /-- The taxpayer did. -/
  | tpDid
  /-- Neither did. -/
  | neither
  deriving DecidableEq, Repr, Inhabited

namespace PaidWithFormerSpouse

/-- Parse a Catala case name (`"SpouseDid"`) or a Direct File option (`"spouseDid"`). -/
def ofString? : String → Option PaidWithFormerSpouse
  | "SpouseDid" | "spouseDid" => some spouseDid
  | "BothDid" | "bothDid" => some bothDid
  | "TpDid" | "tpDid" => some tpDid
  | "Neither" | "neither" => some neither
  | _ => none

end PaidWithFormerSpouse

/-- Inputs of `EstimatedPayments`. -/
structure EstimatedPaymentsIn where
  /-- Catala input `paid_estimated_taxes_or_from_last_year`. -/
  paidEstimatedTaxesOrFromLastYear : Bool
  /-- Catala input `estimated_tax_payment_writable`. -/
  estimatedTaxPaymentWritable : Int
  /-- Catala input `paid_estimated_taxes_or_from_last_year_under_different_name`. -/
  paidEstimatedTaxesOrFromLastYearUnderDifferentName : Bool
  /-- Catala input `paid_estimated_taxes_with_former_spouse`. -/
  paidEstimatedTaxesWithFormerSpouse : PaidWithFormerSpouse

/-- Outputs of `EstimatedPayments`. -/
structure EstimatedPaymentsOut where
  /-- Form 1040 line 26. -/
  estimatedAndFromLastYear : Int
  /-- Catala `spouse_paid_estimated_taxes_with_former_spouse`. -/
  spousePaidEstimatedTaxesWithFormerSpouse : Bool
  /-- Catala `tp_paid_estimated_taxes_with_former_spouse`. -/
  tpPaidEstimatedTaxesWithFormerSpouse : Bool
  /-- Catala `some_tp_paid_estimated_taxes_with_former_spouse`. -/
  someTpPaidEstimatedTaxesWithFormerSpouse : Bool
  /-- Catala `ko_knockout_paid_estimated_taxes_under_different_last_name`. -/
  koKnockoutPaidEstimatedTaxesUnderDifferentLastName : Bool
  /-- Every knockout of this scope. -/
  unsupported : Bool

/-- Catala `scope EstimatedPayments`. -/
def estimatedPayments (i : EstimatedPaymentsIn) : EstimatedPaymentsOut :=
  let spouse := i.paidEstimatedTaxesWithFormerSpouse == .bothDid ||
    i.paidEstimatedTaxesWithFormerSpouse == .spouseDid
  let tp := i.paidEstimatedTaxesWithFormerSpouse == .bothDid ||
    i.paidEstimatedTaxesWithFormerSpouse == .tpDid
  let ko := i.paidEstimatedTaxesOrFromLastYear && i.paidEstimatedTaxesOrFromLastYearUnderDifferentName
  { estimatedAndFromLastYear :=
      roundDollar (if i.paidEstimatedTaxesOrFromLastYear then i.estimatedTaxPaymentWritable else 0)
    spousePaidEstimatedTaxesWithFormerSpouse := spouse
    tpPaidEstimatedTaxesWithFormerSpouse := tp
    someTpPaidEstimatedTaxesWithFormerSpouse := spouse || tp
    koKnockoutPaidEstimatedTaxesUnderDifferentLastName := ko
    unsupported := ko }

/-! ### Unit tests: every assertion of `catala/tests/test_estimated_payments.catala_en` -/

private def mk (paid : Bool) (amount : Int) (diffName : Bool) (former : PaidWithFormerSpouse) :
    EstimatedPaymentsOut :=
  estimatedPayments
    { paidEstimatedTaxesOrFromLastYear := paid, estimatedTaxPaymentWritable := amount,
      paidEstimatedTaxesOrFromLastYearUnderDifferentName := diffName,
      paidEstimatedTaxesWithFormerSpouse := former }

-- TestFlagFalseIgnoresAmount
#guard (mk false 50_000 false .neither).estimatedAndFromLastYear == 0
#guard !(mk false 50_000 false .neither).unsupported

-- TestRoundsDown
#guard (mk true 50_049 false .neither).estimatedAndFromLastYear == 50_000
#guard (mk true 50_049 false .neither).estimatedAndFromLastYear != 50_049
#guard (mk true 50_049 false .neither).estimatedAndFromLastYear != 0
#guard !(mk true 50_049 false .neither).unsupported

-- TestRoundsHalfUp
#guard (mk true 1_050 false .neither).estimatedAndFromLastYear == 1_100

-- TestNameChangeKnockout
#guard (mk true 50_000 true .neither).koKnockoutPaidEstimatedTaxesUnderDifferentLastName
#guard (mk true 50_000 true .neither).unsupported
#guard (mk true 50_000 true .neither).estimatedAndFromLastYear == 50_000
#guard !(mk false 0 true .neither).unsupported

-- TestFormerSpouse
#guard (mk true 100 false .tpDid).tpPaidEstimatedTaxesWithFormerSpouse
#guard !(mk true 100 false .tpDid).spousePaidEstimatedTaxesWithFormerSpouse
#guard (mk true 100 false .spouseDid).spousePaidEstimatedTaxesWithFormerSpouse
#guard !(mk true 100 false .spouseDid).tpPaidEstimatedTaxesWithFormerSpouse
#guard (mk true 100 false .bothDid).tpPaidEstimatedTaxesWithFormerSpouse
#guard (mk true 100 false .bothDid).spousePaidEstimatedTaxesWithFormerSpouse
#guard !(mk true 100 false .neither).someTpPaidEstimatedTaxesWithFormerSpouse
#guard (mk true 100 false .tpDid).someTpPaidEstimatedTaxesWithFormerSpouse
#guard !(mk true 100 false .tpDid).unsupported

end UsTax.EstimatedPayments
