import UsTax.Api.Bridge
import UsTax.Api.Response
import UsTax.Api.Reasons
import UsTax.Api.Parse

/-!
# The API-facing calculator (issues #38, #48)

Lean implementation of `catala/api_calculator.catala_en` (module `Api_calculator`, scopes
`OutcomeOf`, `MaritalOf`, `ApiFilerToCalc`, `ApiDependentToCalc` and `ApiCalculator`), written by
hand from the Catala source under strategy (c) of `docs/catala-to-lean.md`. Its input is the typed,
validated request `UsTax.Api.Request` (`UsTax/Api/Types.lean`, contract 1.2.0); its outputs are
the fields of the API response (`docs/api-mapping.md`, "Encoding"):

| Output      | API response field |
|-------------|--------------------|
| `supported` | `supported` (false: HTTP 422 `CalculateUnsupported`) |
| `reasons`   | `reasons[]`: the `KnockoutReason` inside each `CalculatorKnockout`, with its category and message (`KnockoutReason.toReason`) |
| `outcome`   | `outcome` (`refund`, `balance_due`, `even`) |
| `lines`     | `lines`, the nineteen Form 1040 line items, integer cents |

| Catala (`Api_calculator`)                     | Lean |
|-----------------------------------------------|------|
| decoding (`scripts/api_decode.mjs`), `ApiRequest` | `UsTax.Api.parseRequest` (strict JSON, schema 1.2.0) to `Request` |
| `MaritalOf`                                   | `Api.maritalStatusUsed`, `Api.yearOfSpouseDeathUsed` (`UsTax/Api/Bridge.lean`) |
| `ApiFilerToCalc`                              | `Api.FilerFlags.answers`, `Api.FilerFlags.extra` |
| `ApiDependentToCalc`, `Api…ToCalc` (forms)    | `Api.Dependent.toCore`, `Api.FormW2.toCore`, … |
| the `calc` input of `ApiCalculator`           | `Api.toCalculatorInput` |
| `OutcomeOf`                                   | `outcomeOf` |
| `ApiReason`, `ApiReasonCategoryOf`            | `Calculator.CalculatorKnockout`, `Api.KnockoutReason.category` (generated) |
| `scope ApiCalculator`                         | `ApiCalculatorOut` (`apiCalculator`) |

Units: the API carries cents and so does Lean, so the Catala division by 100 on the way in and
multiplication by 100 on the way out are both the identity here. The tests at the end are the
assertions of `catala/tests/test_api_calculator.catala_en` on the requests of `api/examples`.
-/

namespace UsTax.ApiCalculator

open Api (Request Lines Outcome)

/-- Catala `OutcomeOf`: `Refund` if line 34 is positive, `BalanceDue` if line 37 is, else `Even`. -/
def outcomeOf (overpayment balanceDue : Int) : Outcome :=
  if overpayment > 0 then .refund else if balanceDue > 0 then .balanceDue else .even

/-- Outputs of `scope ApiCalculator`. `calculation` is the internal `Calculator` result (Catala `calc`). -/
structure ApiCalculatorOut where
  supported : Bool
  outcome : Outcome
  reasons : List Calculator.CalculatorKnockout
  lines : Lines
  calculation : Calculator.CalculatorOut

/-- The nineteen line items of a supported return. -/
def linesOf (c : Calculator.CalculatorOut) : Lines :=
  { wages := c.wages, employerIncomeSubtotal := c.employerIncomeSubtotal
    interestIncome := c.interestIncome, totalIncome := c.totalIncome
    adjustmentsToIncome := c.adjustmentsToIncome, agi := c.agi
    standardOrItemizedDeductions := c.standardOrItemizedDeductions
    totalDeductions := c.totalDeductions, taxableIncome := c.taxableIncome
    tentativeTaxFromTaxableIncome := c.tentativeTaxFromTaxableIncome
    totalTentativeTax := c.totalTentativeTax, nonRefundableCredits := c.nonRefundableCredits
    taxLessNonRefundableCredits := c.taxLessNonRefundableCredits, totalTax := c.totalTax
    totalWithholding := c.totalWithholding
    totalOtherPaymentsRefundableCredits := c.totalOtherPaymentsRefundableCredits
    totalPayments := c.totalPayments, overpayment := c.overpayment, balanceDue := c.balanceDue }

/-- An unsupported return has no lines (the response is HTTP 422): all zero. -/
def zeroLines : Lines :=
  { wages := 0, employerIncomeSubtotal := 0, interestIncome := 0, totalIncome := 0
    adjustmentsToIncome := 0, agi := 0, standardOrItemizedDeductions := 0, totalDeductions := 0
    taxableIncome := 0, tentativeTaxFromTaxableIncome := 0, totalTentativeTax := 0
    nonRefundableCredits := 0, taxLessNonRefundableCredits := 0, totalTax := 0
    totalWithholding := 0, totalOtherPaymentsRefundableCredits := 0, totalPayments := 0
    overpayment := 0, balanceDue := 0 }

/-- Catala `scope ApiCalculator`. -/
def apiCalculator (r : Request) : ApiCalculatorOut :=
  let c := Calculator.calculator (Api.toCalculatorInput r)
  { supported := !c.unsupported
    reasons := if c.unsupported then c.firedKnockouts else []
    lines := if c.unsupported then zeroLines else linesOf c
    outcome := if c.unsupported then .even else outcomeOf c.overpayment c.balanceDue
    calculation := c }

/-- The response `reasons[]` of an unsupported return: code, category and message of the
`KnockoutReason` inside each entry. -/
def ApiCalculatorOut.unsupportedReasons (o : ApiCalculatorOut) : List Api.UnsupportedReason :=
  o.reasons.map (·.reason.toReason)

/-! ### Tests: `catala/tests/test_api_calculator.catala_en` on the contract's examples

Each request is parsed by the server's own reader (`Api.parseRequest`), so these checks run the
whole path the endpoint runs. Expected values are the `api/examples` and `api/fixtures` responses
(generated from the Catala `ApiCalculator`). -/

/-- The output on a request body, or `none` if it does not parse. -/
def onBody (body : String) : Option ApiCalculatorOut :=
  match Api.parseRequest body with
  | .ok r => some (apiCalculator r)
  | .error _ => none

/-- `single-w2-50k`: $50,000 wages, $5,000 withheld; refund $981. -/
private def single50k : String :=
  "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\"," ++
  "\"wages\":5000000,\"federal_withholding\":500000}]}"

#guard (onBody single50k).any fun o =>
  o.supported && o.outcome == .refund && o.lines.agi == 5_000_000 &&
    o.lines.taxableIncome == 3_540_000 && o.lines.totalTax == 401_900 &&
    o.lines.overpayment == 98_100 && o.lines.balanceDue == 0 && o.reasons == []

/-- `refund-below-standard-deduction`: $10,000 wages, $500 withheld, no children: the earned
income credit ($632) is computed. -/
private def single10k : String :=
  "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\"," ++
  "\"wages\":1000000,\"federal_withholding\":50000}]}"

#guard (onBody single10k).any fun o =>
  o.supported && o.lines.taxableIncome == 0 && o.lines.totalTax == 0 &&
    o.lines.totalOtherPaymentsRefundableCredits == 63_200 && o.lines.overpayment == 113_200

-- head of household without a qualifying person: 422 ExtraFilingStatusNotEligible, no lines
#guard (onBody "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"HeadOfHousehold\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]}").any
  fun o => !o.supported && o.outcome == .even && o.lines == zeroLines &&
    o.unsupportedReasons.map (·.code) == ["ExtraFilingStatusNotEligible"] &&
    o.unsupportedReasons.map (·.category) == ["household"]

-- the legacy foreign-accounts flag is or-ed into the screening answer: an income knockout
#guard (onBody "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}],\"filing_details\":{\"has_foreign_accounts_or_trusts\":true}}").any
  fun o => !o.supported && o.reasons == [.incomeOrHsa .hasForeignAccountsOrTrusts]

-- head of household with one child: child tax credit, EITC and ACTC (`eitc-hoh-one-child` shape)
#guard (onBody ("{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"HeadOfHousehold\"," ++
    "\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":4000000,\"federal_withholding\":200000}]," ++
    "\"dependents\":[{\"relationship\":\"BiologicalChild\",\"date_of_birth\":\"2014-09-10\"," ++
    "\"tin_type\":\"Ssn\",\"tp_paid_most_of_home_upkeep\":true}]}")).any fun o =>
  o.supported && o.lines.totalTax == 0 && o.lines.totalPayments == 360_400 &&
    o.lines.overpayment == 360_400 && o.outcome == .refund

-- a balance due
#guard (onBody "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\",\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]}").any
  fun o => o.supported && o.outcome == .balanceDue && o.lines.balanceDue == 401_900

end UsTax.ApiCalculator
