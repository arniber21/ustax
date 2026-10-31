import UsTax.Api.Json

/-!
# Error values (issue #51): `ErrorResponse` and `FieldError` of the contract

`docs/api.md`, "Errors". `ErrorCode` is `error.code`, `FieldCode` is
`details[].code`; the HTTP status is a function of the error code
(`ErrorCode.status`). Serialisation is `ApiError.toJ` / `ApiError.render`;
the 400 fixtures in `api/fixtures/error-400-*.response.json` are reproduced
byte for byte by the tests (modulo key order, which JSON does not define).
-/

namespace UsTax.Api

/-- `ErrorResponse.error.code`. -/
inductive ErrorCode where
  /-- Constructor `invalidJson`. -/
  | invalidJson
  /-- Constructor `invalidRequest`. -/
  | invalidRequest
  /-- Constructor `unknownField`. -/
  | unknownField
  /-- Constructor `unsupportedApiVersion`. -/
  | unsupportedApiVersion
  /-- Constructor `unsupportedTaxYear`. -/
  | unsupportedTaxYear
  /-- Constructor `notFound`. -/
  | notFound
  /-- Constructor `methodNotAllowed`. -/
  | methodNotAllowed
  /-- Constructor `payloadTooLarge`. -/
  | payloadTooLarge
  /-- Constructor `unsupportedMediaType`. -/
  | unsupportedMediaType
  /-- Constructor `internalError`. -/
  | internalError
  deriving DecidableEq, Repr, Inhabited

/-- The wire spelling of an error code. -/
def ErrorCode.name : ErrorCode → String
  | .invalidJson => "invalid_json" | .invalidRequest => "invalid_request"
  | .unknownField => "unknown_field" | .unsupportedApiVersion => "unsupported_api_version"
  | .unsupportedTaxYear => "unsupported_tax_year" | .notFound => "not_found"
  | .methodNotAllowed => "method_not_allowed" | .payloadTooLarge => "payload_too_large"
  | .unsupportedMediaType => "unsupported_media_type" | .internalError => "internal_error"

/-- The HTTP status of an error code (`docs/api.md`, "Errors"). -/
def ErrorCode.status : ErrorCode → Nat
  | .invalidJson | .invalidRequest | .unknownField | .unsupportedApiVersion
  | .unsupportedTaxYear => 400
  | .notFound | .methodNotAllowed => 404
  | .payloadTooLarge => 413
  | .unsupportedMediaType => 415
  | .internalError => 500

/-- `FieldError.code`. -/
inductive FieldCode where
  /-- Constructor `required`. -/
  | required
  /-- Constructor `type`. -/
  | type
  /-- Constructor `enum`. -/
  | enum
  /-- Constructor `range`. -/
  | range
  /-- Constructor `notInteger`. -/
  | notInteger
  /-- Constructor `unknownField`. -/
  | unknownField
  /-- Constructor `duplicatePerson`. -/
  | duplicatePerson
  /-- Constructor `filerNotAllowed`. -/
  | filerNotAllowed
  /-- Constructor `tooManyItems`. -/
  | tooManyItems
  /-- Constructor `invalidDate`. -/
  | invalidDate
  deriving DecidableEq, Repr, Inhabited

/-- The wire spelling of a field error code. -/
def FieldCode.name : FieldCode → String
  | .required => "required" | .type => "type" | .enum => "enum" | .range => "range"
  | .notInteger => "not_integer" | .unknownField => "unknown_field"
  | .duplicatePerson => "duplicate_person" | .filerNotAllowed => "filer_not_allowed"
  | .tooManyItems => "too_many_items" | .invalidDate => "invalid_date"

/-- One problem in the body: an RFC 6901 pointer, a code, and text. -/
structure FieldError where
  /-- Property `path`. -/
  path : String
  /-- Property `code`. -/
  code : FieldCode
  /-- Property `message`. -/
  message : String
  deriving DecidableEq, Repr, Inhabited

/-- Every non-200, non-422 response. `details` is non-empty for 400 field errors only. -/
structure ApiError where
  /-- Property `code`. -/
  code : ErrorCode
  /-- Property `message`. -/
  message : String
  /-- Property `details`. -/
  details : List FieldError := []
  deriving DecidableEq, Repr, Inhabited

namespace ApiError

/-- HTTP status. -/
def status (e : ApiError) : Nat := e.code.status

/-- The `ErrorResponse` object. -/
def toJ (e : ApiError) : J :=
  let base := [("code", J.str e.code.name), ("message", J.str e.message)]
  let det := if e.details.isEmpty then [] else
    [("details", J.arr (e.details.map fun d =>
      J.obj [("path", J.str d.path), ("code", J.str d.code.name), ("message", J.str d.message)]))]
  J.obj [("api_version", J.int 1), ("error", J.obj (base ++ det))]

/-- The response body text. -/
def render (e : ApiError) : String := e.toJ.render

/-- 400 `invalid_json`. -/
def invalidJson (msg : String) : ApiError := { code := .invalidJson, message := msg }
/-- 404. -/
def notFound : ApiError := { code := .notFound, message := "No such endpoint." }
/-- 405. -/
def methodNotAllowed : ApiError := { code := .methodNotAllowed, message := "Use POST for /calculate." }
/-- 413: the body is over the cap. -/
def payloadTooLarge : ApiError :=
  { code := .payloadTooLarge, message := "Request body exceeds 262144 bytes." }
/-- 415: `Content-Type` is not `application/json`. -/
def unsupportedMediaType : ApiError :=
  { code := .unsupportedMediaType, message := "Content-Type must be application/json." }
/-- 500: a server fault; no detail is exposed. -/
def internal : ApiError := { code := .internalError, message := "Internal error." }

end ApiError

/-- RFC 6901 child pointer. -/
def child (p k : String) : String :=
  p ++ "/" ++ (k.replace "~" "~0").replace "/" "~1"

/-- The body cap in bytes: 256 KiB (`docs/api.md`). -/
def maxBodyBytes : Nat := 262144

end UsTax.Api
