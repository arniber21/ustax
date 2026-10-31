import Std.Http
import UsTax.Api.Calculate

/-!
# `ustax-server`: the HTTP front of the Lean calculator (issues #52 to #54, #56)

Build with `cd lean && lake build ustax-server`; run `.lake/build/bin/ustax-server`.
Plain HTTP/1.1 on `Std.Http` (docs/lean-http-server.md); TLS is a reverse
proxy's job (docs/tls.md).

| Method and path | Answer |
|---|---|
| `POST /calculate` | 200 lines, 422 knockout reasons, 400/413/415/500 `ErrorResponse` |
| `GET /health`, `GET /version` | 200 |
| `OPTIONS` any known path | 204 preflight (CORS headers only for an allowed origin) |
| other method on a known path | 405; other path 404 |

Environment: `PORT` (default 8080), `HOST` (default 127.0.0.1),
`ALLOW_ORIGIN` (comma separated origins, default `http://localhost:5173`;
`USTAX_ALLOWED_ORIGINS` is read when `ALLOW_ORIGIN` is unset).

**Trusted code.** This file is IO only and has no theorem. All tax logic and
request validation live in `UsTax.Api.calculate` (pure, proved sound). The
handler decides routing, CORS and the 256 KiB body cap, never touches a field of
the body, and never echoes an exception text to the client (500 is generic).
Request bodies are not logged.
-/

open Std Http Async Lean

namespace UsTaxServer

/-- Configuration read once at startup. -/
structure Config where
  /-- Listen address. -/
  host : String
  /-- Listen port. -/
  port : UInt16
  /-- Allowed `Origin` values (exact match). `*` allows any origin. -/
  origins : List String
  /-- `calculator_version` for `GET /version`. -/
  version : String

/-- The status code as an `Std.Http.Status`. -/
def statusOf : Nat → Status
  | 200 => .ok | 204 => .noContent | 400 => .badRequest | 404 => .notFound
  | 405 => .methodNotAllowed | 413 => .payloadTooLarge | 415 => .unsupportedMediaType
  | 422 => .unprocessableEntity | _ => .internalServerError

/-- The origin to echo in `Access-Control-Allow-Origin`, if the request's origin is allowed. -/
def allowedOrigin (cfg : Config) (req : Request Body.Stream) : Option String := do
  let o ← req.line.headers.get? Header.Name.origin
  let o := o.value
  if cfg.origins.contains "*" || cfg.origins.contains o then some o else none

/-- Add CORS response headers for an allowed origin; nothing otherwise. -/
def withCors (cfg : Config) (req : Request Body.Stream) (preflight : Bool)
    (b : Response.Builder) : Response.Builder :=
  match allowedOrigin cfg req with
  | none => b
  | some o =>
    let b := b.header! "Access-Control-Allow-Origin" o |>.header! "Vary" "Origin"
    if preflight then
      b.header! "Access-Control-Allow-Methods" "GET, POST, OPTIONS"
        |>.header! "Access-Control-Allow-Headers" "Content-Type"
        |>.header! "Access-Control-Max-Age" "600"
    else b

/-- A JSON response with the CORS headers. -/
def jsonReply (cfg : Config) (req : Request Body.Stream) (status : Nat) (body : String) :
    ContextAsync (Response Body.Any) := do
  let b := withCors cfg req false (Response.withStatus (statusOf status))
    |>.header! "Content-Type" "application/json; charset=utf-8"
    |>.header! "Cache-Control" "no-store"
  let r ← b.fromBytes body.toUTF8
  return (r : Response Body.Any)

/-- An `ApiError` response. -/
def errReply (cfg : Config) (req : Request Body.Stream) (e : UsTax.Api.ApiError) :
    ContextAsync (Response Body.Any) :=
  jsonReply cfg req e.status e.render

/-- `Content-Type` is `application/json`, parameters (`charset`) ignored. -/
def isJson (req : Request Body.Stream) : Bool :=
  match req.line.headers.get? Header.Name.contentType with
  | none => false
  | some v =>
    let mt := (v.value.splitOn ";").head!.trimAscii.toString.toLower
    mt == "application/json"

/-- Does an IO error come from `readAll` hitting its `maximumSize`? -/
def isTooLarge (e : IO.Error) : Bool :=
  (toString e).startsWith "body exceeded maximum size"

/-- `POST /calculate`. -/
def calculate (cfg : Config) (req : Request Body.Stream) : ContextAsync (Response Body.Any) := do
  if !isJson req then return ← errReply cfg req UsTax.Api.ApiError.unsupportedMediaType
  let raw : Except IO.Error ByteArray ← try
      pure (.ok (← req.body.readAll (maximumSize := some UsTax.Api.maxBodyBytes.toUInt64)))
    catch e => pure (.error e)
  match raw with
  | .error e =>
    if isTooLarge e then errReply cfg req UsTax.Api.ApiError.payloadTooLarge
    else throw e
  | .ok bytes =>
    match String.fromUTF8? bytes with
    | none => errReply cfg req (UsTax.Api.ApiError.invalidJson "Body is not valid UTF-8.")
    | some text =>
      let reply := UsTax.Api.calculate text
      jsonReply cfg req reply.status reply.body.render

/-- Route a request. Exceptions are handled by `handle`. -/
def route (cfg : Config) (req : Request Body.Stream) : ContextAsync (Response Body.Any) := do
  let path := toString req.line.uri.pathOrRoot
  let known := ["/calculate", "/health", "/version"]
  if req.line.method == .options && known.contains path then
    let r ← (withCors cfg req true (Response.withStatus .noContent)).empty
    return (r : Response Body.Any)
  match path with
  | "/calculate" =>
    if req.line.method == .post then calculate cfg req
    else errReply cfg req UsTax.Api.ApiError.methodNotAllowed
  | "/health" =>
    if req.line.method == .get then jsonReply cfg req 200 UsTax.Api.healthResponse.render
    else errReply cfg req { UsTax.Api.ApiError.methodNotAllowed with message := "Use GET for /health." }
  | "/version" =>
    if req.line.method == .get then
      jsonReply cfg req 200 (UsTax.Api.versionResponse cfg.version).render
    else errReply cfg req { UsTax.Api.ApiError.methodNotAllowed with message := "Use GET for /version." }
  | _ => errReply cfg req UsTax.Api.ApiError.notFound

/-- Route, logging method, path and status only; any exception becomes a generic 500. -/
def handle (cfg : Config) (req : Request Body.Stream) : ContextAsync (Response Body.Any) := do
  let path := toString req.line.uri.pathOrRoot
  try
    let r ← route cfg req
    IO.eprintln s!"{req.line.method} {path} {r.line.status}"
    return r
  catch e =>
    IO.eprintln s!"{req.line.method} {path} internal error: {e}"
    errReply cfg req UsTax.Api.ApiError.internal

/-- `git rev-parse --short HEAD`, or `unknown`. -/
def gitVersion : IO String := do
  try
    let out ← IO.Process.output { cmd := "git", args := #["rev-parse", "--short", "HEAD"] }
    if out.exitCode == 0 then return out.stdout.trimAscii.toString else return "unknown"
  catch _ => return "unknown"

/-- Read the configuration; `Except` message on a bad value. -/
def readConfig : IO (Except String Config) := do
  let port ← match ← IO.getEnv "PORT" with
    | none => pure (some 8080)
    | some s => pure (s.toNat?.filter (· < 65536))
  let host := (← IO.getEnv "HOST").getD "127.0.0.1"
  let origins := (← IO.getEnv "ALLOW_ORIGIN").orElse (fun _ => none)
  let origins ← match origins with
    | some s => pure s
    | none => pure ((← IO.getEnv "USTAX_ALLOWED_ORIGINS").getD "http://localhost:5173")
  let origins := (origins.splitOn ",").map (·.trimAscii.toString) |>.filter (· ≠ "")
  match port with
  | none => return .error "PORT must be a number below 65536"
  | some p => return .ok { host, port := p.toUInt16, origins, version := ← gitVersion }

end UsTaxServer

open UsTaxServer in
/-- Entry point. -/
def main : IO UInt32 := do
  match ← readConfig with
  | .error m => IO.eprintln s!"ustax-server: {m}"; return 2
  | .ok cfg =>
    let some ip := Net.IPv4Addr.ofString cfg.host
      | IO.eprintln s!"ustax-server: HOST must be an IPv4 address, got {cfg.host}"; return 2
    let addr : Net.SocketAddress := .v4 ⟨ip, cfg.port⟩
    IO.println s!"ustax-server {cfg.version} listening on http://{cfg.host}:{cfg.port} (CORS: {", ".intercalate cfg.origins})"
    (← IO.getStdout).flush
    Async.block do
      let srv ← Server.serve addr (Server.Handler.ofFn (handle cfg))
      srv.waitShutdown
    return 0
