import UsTax.Api.Error

/-!
# Response serialisation (issue #51)

The 200 `CalculateSuccess`, 422 `CalculateUnsupported`, `HealthResponse` and
`VersionResponse` shapes of `api/schema.json`, as typed values with `toJ` and
`render`. `ErrorResponse` is `ApiError` (`Error.lean`). Money is integer cents,
never a float.

`Lines` holds the 19 required `lines` keys (the order is the schema's
`Lines.required`); new keys are additive and arrive with later scopes. The
calculator (#38, #52) builds a `Lines`; this module only fixes the wire format.
-/

namespace UsTax.Api

/-- `Outcome`: refund when line 34 is positive, balance due when line 37 is. -/
inductive Outcome where
  /-- Constructor `refund`. -/
  | refund
  /-- Constructor `balanceDue`. -/
  | balanceDue
  /-- Constructor `even`. -/
  | even
  deriving DecidableEq, Repr, Inhabited

/-- The wire spelling. -/
def Outcome.name : Outcome → String
  | .refund => "refund" | .balanceDue => "balance_due" | .even => "even"

/-- Form 1040 line items, integer cents (`Lines` in the schema). -/
structure Lines where
  /-- Property `wages`. -/
  wages : Int
  /-- Property `employer_income_subtotal`. -/
  employerIncomeSubtotal : Int
  /-- Property `interest_income`. -/
  interestIncome : Int
  /-- Property `total_income`. -/
  totalIncome : Int
  /-- Property `adjustments_to_income`. -/
  adjustmentsToIncome : Int
  /-- Property `agi`. -/
  agi : Int
  /-- Property `standard_or_itemized_deductions`. -/
  standardOrItemizedDeductions : Int
  /-- Property `total_deductions`. -/
  totalDeductions : Int
  /-- Property `taxable_income`. -/
  taxableIncome : Int
  /-- Property `tentative_tax_from_taxable_income`. -/
  tentativeTaxFromTaxableIncome : Int
  /-- Property `total_tentative_tax`. -/
  totalTentativeTax : Int
  /-- Property `non_refundable_credits`. -/
  nonRefundableCredits : Int
  /-- Property `tax_less_non_refundable_credits`. -/
  taxLessNonRefundableCredits : Int
  /-- Property `total_tax`. -/
  totalTax : Int
  /-- Property `total_withholding`. -/
  totalWithholding : Int
  /-- Property `total_other_payments_refundable_credits`. -/
  totalOtherPaymentsRefundableCredits : Int
  /-- Property `total_payments`. -/
  totalPayments : Int
  /-- Property `overpayment`. -/
  overpayment : Int
  /-- Property `balance_due`. -/
  balanceDue : Int
  deriving DecidableEq, Repr, Inhabited

/-- `outcome` is derived from the lines, as the schema says. -/
def Lines.outcome (l : Lines) : Outcome :=
  if l.overpayment > 0 then .refund else if l.balanceDue > 0 then .balanceDue else .even

/-- The `lines` object, keys in schema order. -/
def Lines.toJ (l : Lines) : J :=
  J.obj [("wages", .int l.wages), ("employer_income_subtotal", .int l.employerIncomeSubtotal),
    ("interest_income", .int l.interestIncome), ("total_income", .int l.totalIncome),
    ("adjustments_to_income", .int l.adjustmentsToIncome), ("agi", .int l.agi),
    ("standard_or_itemized_deductions", .int l.standardOrItemizedDeductions),
    ("total_deductions", .int l.totalDeductions), ("taxable_income", .int l.taxableIncome),
    ("tentative_tax_from_taxable_income", .int l.tentativeTaxFromTaxableIncome),
    ("total_tentative_tax", .int l.totalTentativeTax),
    ("non_refundable_credits", .int l.nonRefundableCredits),
    ("tax_less_non_refundable_credits", .int l.taxLessNonRefundableCredits),
    ("total_tax", .int l.totalTax), ("total_withholding", .int l.totalWithholding),
    ("total_other_payments_refundable_credits", .int l.totalOtherPaymentsRefundableCredits),
    ("total_payments", .int l.totalPayments), ("overpayment", .int l.overpayment),
    ("balance_due", .int l.balanceDue)]

/-- 200 body. -/
def calculateSuccess (l : Lines) : J :=
  J.obj [("api_version", .int 1), ("tax_year", .int 2024), ("supported", .bool true),
    ("reasons", .arr []), ("outcome", .str l.outcome.name), ("lines", l.toJ)]

/-- One knockout that fired (`UnsupportedReason`): the Catala constructor name,
its category, and English fallback text. -/
structure UnsupportedReason where
  /-- Property `code`. -/
  code : String
  /-- Property `category`. -/
  category : String
  /-- Property `message`. -/
  message : String
  deriving DecidableEq, Repr

/-- 422 body; `reasons` must be non-empty (the caller's invariant). -/
def calculateUnsupported (rs : List UnsupportedReason) : J :=
  J.obj [("api_version", .int 1), ("tax_year", .int 2024), ("supported", .bool false),
    ("reasons", .arr (rs.map fun r => J.obj [("code", .str r.code),
      ("category", .str r.category), ("message", .str r.message)]))]

/-- `GET /health` body. -/
def healthResponse : J := J.obj [("status", .str "ok")]

/-- `GET /version` body. -/
def versionResponse (calculatorVersion : String) : J :=
  J.obj [("api_version", .int 1), ("schema_version", .str "1.2.0"), ("tax_year", .int 2024),
    ("calculator_version", .str calculatorVersion)]

/-- A success response never has both an overpayment and a balance due when the
lines come from the calculator; the outcome then agrees with the lines. -/
theorem Lines.outcome_refund {l : Lines} (h : 0 < l.overpayment) : l.outcome = .refund := by
  simp [Lines.outcome, h]

end UsTax.Api
