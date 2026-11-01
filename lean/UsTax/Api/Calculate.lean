import UsTax.Api.Parse
import UsTax.Api.Response
import UsTax.Api.Bridge
import UsTax.Api.Reasons

/-!
# `POST /calculate` without HTTP (issue #52)

```
body text --parseRequest--> Request --toForm1040Input--> Form1040In --form1040--> Form1040Out
                                                                      |--> Lines (200)  or  reasons (422)
```

`calculate : String → Reply` is the whole endpoint minus sockets. It holds **no
tax logic**: the bridge maps names, `Form1040.form1040` computes, and this file
only reads the result out.

**Knockout reasons.** `Form1040Out.unsupported` is one Boolean. The reason
list is read from the same sub-scopes `form1040` calls (`FormW2s.formW2s`,
`Interest.interest` with the real AGI) plus the two reasons `form1040` itself
decides (`HasForeignAccountsOrTrusts`, which `form1040` only passes down, and
`KnockoutHasNoPaymentsOrCredits`), in the order of the Catala `KnockoutReason`
enumeration. When #38 lands, `knockoutReasons` is replaced by the `Calculator`
scope's `fired_knockouts`. `Reply.fault` is returned (HTTP 500) if the two
ever disagree about whether the return is supported.

**Warnings** (`docs/api.md` "Warnings"): `warnings` lists request sections that were
accepted but not read by this slice (`section_not_used`) and schema 1.0 fields that
schema 1.2.0 supersedes (`field_superseded`).
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

/-- The warnings for a request: first the schema 1.0 `filing_details` fields that
schema 1.2.0 supersedes (`field_superseded`), then each section the slice does not
read (`section_not_used`). -/
def warnings (r : Request) : List Warning :=
  (supersededFields r).map (fun u => ⟨"field_superseded", u.path, u.message⟩) ++
  (unwiredSections r).map fun u => ⟨"section_not_used", u.path, u.message⟩

/-- Form 1040 output to the response `lines`. -/
def Lines.ofOut (o : Form1040.Form1040Out) : Lines :=
  { wages := o.wages, employerIncomeSubtotal := o.employerIncomeSubtotal
    interestIncome := o.interestIncome, totalIncome := o.totalIncome
    adjustmentsToIncome := o.adjustmentsToIncome, agi := o.agi
    standardOrItemizedDeductions := o.standardOrItemizedDeductions
    totalDeductions := o.totalDeductions, taxableIncome := o.taxableIncome
    tentativeTaxFromTaxableIncome := o.tentativeTaxFromTaxableIncome
    totalTentativeTax := o.totalTentativeTax, nonRefundableCredits := o.nonRefundableCredits
    taxLessNonRefundableCredits := o.taxLessNonRefundableCredits, totalTax := o.totalTax
    totalWithholding := o.totalWithholding
    totalOtherPaymentsRefundableCredits := o.totalOtherPaymentsRefundableCredits
    totalPayments := o.totalPayments, overpayment := o.overpayment, balanceDue := o.balanceDue }

/-- The knockout table, `(fired, code, category, message)`, in `KnockoutReason`
order. Codes, categories and messages are those of `api/knockout-reasons.json`. -/
def knockoutReasons (i : Form1040.Form1040In) (o : Form1040.Form1040Out) :
    List UnsupportedReason :=
  let w2 := FormW2s.formW2s
    { w2s := i.w2s, filingStatus := i.filingStatus,
      primaryFilerCanBeClaimed := i.primaryFilerCanBeClaimed,
      secondaryFilerCanBeClaimed := i.secondaryFilerCanBeClaimed,
      combatPayElection := i.combatPayElection }
  let int := Interest.interest
    { interestReports := i.interestReports, hasForeignAccountsOrTrusts := i.hasForeignAccountsOrTrusts,
      filingStatus := i.filingStatus, agi := o.agi, flowHasSeenDeductions := true }
  let table : List (Bool × KnockoutReason) :=
    [(int.koHasRequiredFactaFilings, .hasRequiredFactaFilings),
     (int.koFlowKnockoutHasEarlyWithdrawlPenalty, .flowKnockoutHasEarlyWithdrawlPenalty),
     (int.koFlowKnockoutHasBonds, .flowKnockoutHasBonds),
     (int.koFlowKnockoutHasForeignTaxPaid, .flowKnockoutHasForeignTaxPaid),
     (int.koFlowKnockoutWithholdingUnsupportedState, .flowKnockoutWithholdingUnsupportedState),
     (int.koFlowKnockoutStateTaxWithheld, .flowKnockoutStateTaxWithheld),
     (int.koHasInterestIncomeAndAgiAboveThresholdForMfs, .hasInterestIncomeAndAgiAboveThresholdForMfs),
     (int.koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss, .hasInterestIncomeAndAgiAboveThresholdForMfjOrQss),
     (int.koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh, .hasInterestIncomeAndAgiAboveThresholdForSingleOrHoh),
     (int.koFlowKnockoutTaxExemptInterest, .flowKnockoutTaxExemptInterest),
     (w2.koKnockoutForBox12Value, .knockoutForBox12Value),
     (w2.koKnockoutForBox12Dependency, .knockoutForBox12Dependency),
     (w2.koFlowKnockoutAllocatedTips, .flowKnockoutAllocatedTips),
     (w2.koFlowKnockoutStatutoryEmployee, .flowKnockoutStatutoryEmployee),
     (w2.koFlowKnockoutThirdPartySickPay, .flowKnockoutThirdPartySickPay),
     (w2.koFlowKnockoutNonQualifiedPlans, .flowKnockoutNonQualifiedPlans),
     (w2.koKnockoutMedicareWages, .knockoutMedicareWages),
     (w2.koAnyFilerExceedsMaxOasdiWages, .anyFilerExceedsMaxOasdiWages),
     (i.hasForeignAccountsOrTrusts, .hasForeignAccountsOrTrusts),
     (o.koKnockoutHasNoPaymentsOrCredits, .knockoutHasNoPaymentsOrCredits)]
  (table.filter (·.1)).map (·.2.toReason)

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

/-- The calculation on a validated request. -/
def calculateRequest (r : Request) (h : r.Valid) : Reply :=
  let i := toForm1040Input r h
  let o := Form1040.form1040 i
  let rs := knockoutReasons i o
  if rs.isEmpty then
    if o.unsupported then .fault else .success (Lines.ofOut o) (warnings r)
  else .unsupported rs

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

-- a 1099-G is accepted but not read: the response says so
#guard match calculate (single50k ++
    ",\"form_1099g\":[{\"filer\":\"PrimaryFiler\",\"unemployment_compensation\":100}]}") with
  | .success l ws => l.totalTax == 401900 && ws.map (·.path) == ["/form_1099g"]
  | _ => false

-- foreign accounts: 422 with that reason only
#guard match calculate (single50k ++
    ",\"filing_details\":{\"has_foreign_accounts_or_trusts\":true}}") with
  | .unsupported rs => rs.map (·.code) == ["HasForeignAccountsOrTrusts"]
  | _ => false

-- a bad body is a 400
#guard (calculate "{bad").status == 400

end UsTax.Api
