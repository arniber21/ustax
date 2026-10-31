import UsTax.Api.Decode
import UsTax.Api.Lemmas

/-!
# `parseRequest`: untrusted text to a validated typed request (issue #51)

```
body bytes --parseBody--> text --parseJson--> J --runDecode--> Request --validate--> Request
              415 / 413 / invalid_json     invalid_request / unknown_field      invalid_request
```

`parseRequest : String → Except ApiError Request` is total (no `partial`, no
`sorry`). The error values are the `ErrorResponse` shapes of `docs/api.md`.

Order of reporting, so that a client sees the most useful error first:

1. not JSON (or duplicate keys, or nesting over 32): 400 `invalid_json`;
2. top-level value not an object: 400 `invalid_request`;
3. `api_version` an integer other than 1: 400 `unsupported_api_version`;
   `tax_year` an integer other than 2024: 400 `unsupported_tax_year`;
4. shape problems (phase 1, all of them, `Decode.lean`): 400 `unknown_field`
   if any is an unknown property, else 400 `invalid_request`;
5. range, size and cross-field problems (phase 2, all of them,
   `Validate.lean`): 400 `invalid_request`.

Phases 4 and 5 are not merged: a body with both a wrong type and an over-cap
amount reports the wrong type first; the over-cap amount appears once that is
fixed. Every error produced here has HTTP status 400 (`parse_error_status`).
-/

namespace UsTax.Api

open UsTax

/-- A 400 whose details are `es`: `unknown_field` if any detail is one, else
`invalid_request`. -/
def fieldFailure (es : List FieldError) : ApiError :=
  { code := if es.any (·.code == .unknownField) then .unknownField else .invalidRequest,
    message := "The request body is invalid.", details := es }

/-- 400 `unsupported_api_version`. -/
def badVersion : ApiError :=
  { code := .unsupportedApiVersion, message := "Only api_version 1 is supported.",
    details := [⟨"/api_version", .enum, "must be 1"⟩] }

/-- 400 `unsupported_tax_year`. -/
def badYear : ApiError :=
  { code := .unsupportedTaxYear, message := "Only tax_year 2024 is supported.",
    details := [⟨"/tax_year", .enum, "must be 2024"⟩] }

/-- The version and year are reported before anything else, with their own codes. -/
def versionError (j : J) : Option ApiError :=
  match j with
  | .obj fs =>
    match J.lookup fs "api_version", J.lookup fs "tax_year" with
    | some (.int n), _ => if n ≠ 1 then some badVersion else
        (match J.lookup fs "tax_year" with
         | some (.int y) => if y ≠ 2024 then some badYear else none
         | _ => none)
    | _, some (.int y) => if y ≠ 2024 then some badYear else none
    | _, _ => none
  | _ => none

/-- Phases 1 and 2 on a parsed value. -/
def checkJson (j : J) : Except ApiError Request :=
  match versionError j with
  | some e => .error e
  | none =>
    match runDecode j with
    | .error es => .error (fieldFailure es)
    | .ok r =>
      match r.validate with
      | [] => .ok r
      | es => .error (fieldFailure es)

/-- Untrusted JSON text to a validated request, or the 400 to answer with. -/
def parseRequest (s : String) : Except ApiError Request :=
  match parseJson s with
  | .error m => .error (ApiError.invalidJson m)
  | .ok j => checkJson j

theorem checkJson_sound {j : J} {r : Request} (h : checkJson j = .ok r) : r.Valid := by
  unfold checkJson at h
  split at h
  · cases h
  · split at h
    · cases h
    · rename_i r' _ _
      split at h
      · cases h; rename_i hv; exact validate_sound _ hv
      · cases h

/-- Soundness of the validation layer: **every accepted request is `Valid`**
(money in range, caps, list sizes, filer roles, dates). -/
theorem parseRequest_sound {s : String} {r : Request} (h : parseRequest s = .ok r) :
    r.Valid := by
  unfold parseRequest at h
  split at h
  · cases h
  · exact checkJson_sound h

theorem fieldFailure_status (es : List FieldError) : (fieldFailure es).status = 400 := by
  unfold fieldFailure ApiError.status
  split <;> rfl

theorem versionError_status {j : J} {e : ApiError} (h : versionError j = some e) :
    e.status = 400 := by
  unfold versionError at h
  split at h
  all_goals first | (cases h; done) | skip
  all_goals (split at h)
  all_goals (try split at h)
  all_goals (try split at h)
  all_goals (try split at h)
  all_goals first | (cases h; done) | (cases h; rfl)

/-- Every parse failure is a 400. -/
theorem parseRequest_error_status {s : String} {e : ApiError} (h : parseRequest s = .error e) :
    e.status = 400 := by
  unfold parseRequest at h
  split at h
  · cases h; rfl
  · unfold checkJson at h
    split at h
    · cases h; rename_i hv; exact versionError_status hv
    · split at h
      · cases h; exact fieldFailure_status _
      · split at h
        · cases h
        · cases h; exact fieldFailure_status _

/-- `Content-Type` is `application/json`, parameters (`; charset=utf-8`) ignored,
case-insensitive. -/
def isJsonContentType (ct : String) : Bool :=
  ((ct.splitOn ";").headD "").trimAscii.toString.toLower == "application/json"

/-- The whole request pipeline for `POST /calculate`: `Content-Type` (415), body
cap (413), UTF-8 (400 `invalid_json`), then `parseRequest`. A missing
`Content-Type` is 415. -/
def parseBody (contentType : Option String) (body : ByteArray) : Except ApiError Request :=
  match contentType with
  | none => .error ApiError.unsupportedMediaType
  | some ct =>
    if !isJsonContentType ct then .error ApiError.unsupportedMediaType
    else if body.size > maxBodyBytes then .error ApiError.payloadTooLarge
    else
      match String.fromUTF8? body with
      | none => .error (ApiError.invalidJson "body is not valid UTF-8")
      | some s => parseRequest s

#spec_surface parseRequest_sound
#audit_axioms parseRequest_sound
#audit_axioms parseRequest_error_status

end UsTax.Api
