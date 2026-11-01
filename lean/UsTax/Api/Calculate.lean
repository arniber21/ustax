import UsTax.Api.Parse
import UsTax.Api.Response
import UsTax.Api.Bridge
import UsTax.Api.Reasons
import UsTax.ApiCalculator

/-!
# `POST /calculate` without HTTP (issues #52, #48)

```
body text --parseRequest--> Request --toCalculatorInput--> CalculatorIn --calculator--> CalculatorOut
           (ApiCalculator.apiCalculator = toCalculatorInput, then calculator, then the outputs)
                                                       |--> Lines (200)  or  reasons (422)
```

`calculate : String → Reply` is the whole endpoint minus sockets. It holds **no
tax logic**: the bridge maps names (`Api.toCalculatorInput`), the whole-return
`Calculator.calculator` computes (via `ApiCalculator.apiCalculator`, the Lean port of
the Catala `ApiCalculator`), and this file only reads the result out.

**Knockout reasons** are the `Calculator`'s `firedKnockouts` (income, HSA and process
reasons first, then household, credit and premium tax credit reasons), each with the code,
category and message of `api/knockout-reasons.json`. `Reply.fault` (HTTP 500) is returned if
the return is unsupported but no reason fired; `UsTax.Proofs.apiCalculator_supported_iff`
proves that this never happens.

**Warnings** (`docs/api.md` "Warnings"): `warnings` lists the schema 1.0 fields that
schema 1.2.0 supersedes (`field_superseded`). Every section of the request is read, so
there is no `section_not_used` since schema 1.2.0.
-/

namespace UsTax.Api

/-- A non-fatal note on a 200 response (`Warning` in the schema). -/
structure Warning where
  /-- Stable machine code. -/
  code : String
  /-- RFC 6901 pointer of the request part concerned. -/
  path : String
  /-- English text. -/
  message : String
  deriving DecidableEq, Repr

/-- 200 body with the optional `warnings` array (omitted when empty, so a
request that uses only wired sections gets exactly the contract's body). -/
def calculateSuccessW (l : Lines) (ws : List Warning) : J :=
  match calculateSuccess l with
  | .obj kvs =>
    .obj (kvs ++ if ws.isEmpty then [] else
      [("warnings", .arr (ws.map fun w => J.obj [("code", .str w.code), ("path", .str w.path),
        ("message", .str w.message)]))])
  | j => j

/-- The warnings for a request: the schema 1.0 `filing_details` fields that schema 1.2.0
supersedes (`field_superseded`). -/
def warnings (r : Request) : List Warning :=
  (supersededFields r).map fun u => ⟨"field_superseded", u.path, u.message⟩

/-- What `POST /calculate` answers, before HTTP framing. -/
inductive Reply where
  /-- 200: the return was computed (`warnings` possibly empty). -/
  | success (lines : Lines) (warnings : List Warning)
  /-- 422: at least one knockout fired. -/
  | unsupported (reasons : List UnsupportedReason)
  /-- 400: the body was rejected by the request layer. -/
  | rejected (err : ApiError)
  /-- 500: internal inconsistency (reasons and `unsupported` disagree). -/
  | fault
  deriving Repr

/-- The HTTP status of a reply. -/
def Reply.status : Reply → Nat
  | .success .. => 200
  | .unsupported _ => 422
  | .rejected e => e.status
  | .fault => 500

/-- The body of a reply. -/
def Reply.body : Reply → J
  | .success l ws => calculateSuccessW l ws
  | .unsupported rs => calculateUnsupported rs
  | .rejected e => e.toJ
  | .fault => ApiError.internal.toJ

/-- The calculation on a validated request: the whole return (`ApiCalculator.apiCalculator`). -/
def calculateRequest (r : Request) (_h : r.Valid) : Reply :=
  let o := ApiCalculator.apiCalculator r
  if o.supported then .success o.lines (warnings r)
  else match o.unsupportedReasons with
    | [] => .fault
    | rs => .unsupported rs

/-- Request text to reply. Validation failures are 400s. -/
def calculate (body : String) : Reply :=
  match h : parseRequest body with
  | .error e => .rejected e
  | .ok r => calculateRequest r (parseRequest_sound h)

/-! ### Tests: the contract's worked examples (`api/examples`, `api/fixtures`) -/

private def single50k : String :=
  "{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"Single\"," ++
  "\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]"

#guard match calculate (single50k ++ "}") with
  | .success l ws =>
    l.agi == 5000000 && l.standardOrItemizedDeductions == 1460000 &&
    l.taxableIncome == 3540000 && l.totalTax == 401900 && l.balanceDue == 401900 && ws.isEmpty
  | _ => false

-- a 1099-G is read: $1 of unemployment compensation adds to line 9, no warning
#guard match calculate (single50k ++
    ",\"form_1099g\":[{\"filer\":\"PrimaryFiler\",\"unemployment_compensation\":100}]}") with
  | .success l ws => l.totalIncome == 5000100 && ws.isEmpty
  | _ => false

-- head of household with no qualifying person: 422 with the household reason
#guard match calculate ("{\"api_version\":1,\"tax_year\":2024,\"filing_status\":\"HeadOfHousehold\"," ++
    "\"w2s\":[{\"filer\":\"PrimaryFiler\",\"wages\":5000000}]}") with
  | .unsupported rs => rs.map (·.code) == ["ExtraFilingStatusNotEligible"]
  | _ => false

-- foreign accounts: 422 with that reason only
#guard match calculate (single50k ++
    ",\"filing_details\":{\"has_foreign_accounts_or_trusts\":true}}") with
  | .unsupported rs => rs.map (·.code) == ["HasForeignAccountsOrTrusts"]
  | _ => false

-- a bad body is a 400
#guard (calculate "{bad").status == 400

end UsTax.Api
