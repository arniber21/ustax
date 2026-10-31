# Lean HTTP server: library choice (spike #50)

Status: spike result, 2026-10-31. Requested filename was `docs/lean-http-server.md`
(the issue text says `docs/server-choice.md`; same deliverable).

## Recommendation

**Use `Std.Http` from Lean core (toolchain `leanprover/lean4:v4.35.0`). Add no dependency.**

- Pin: there is no git rev to pin. The pin is `lean/lean-toolchain` =
  `leanprover/lean4:v4.35.0` (compiler commit `eb6cafb7290e8bd5f2937522d8d804f58f02bafc`).
  `lean/lakefile.toml` and `lake-manifest.json` stay unchanged.
- Entry points: `Std.Http.Server.serve`, `Std.Http.Server.Handler.ofFn`, `Std.Http.Response`,
  `Std.Http.Body.Stream.readAll`, plus `Lean.Data.Json` (also core) for JSON.
- TLS: terminate at a reverse proxy (see TLS below). This is the answer for #55.

## Evidence: prototype

A scratch project (outside the repo, `scratchpad/http-spike`, about 45 lines of Lean, no
dependencies, `lake build` in about 5 s, 103 MB debug exe linking only libc++/libSystem)
served `POST /echo` with JSON and the CORS preflight. Verified with curl against Lean 4.35.0:

| Request | Result |
|---|---|
| `POST /echo {"a":[1,2.5,"x"]}` | 200, `{"echo":{"a":[1,2.5,"x"]}}`, `Content-Type: application/json`, CORS headers |
| `OPTIONS /echo` with `Origin`, `Access-Control-Request-*` | 204, `Access-Control-Allow-{Origin,Methods,Headers}`, `Max-Age` |
| `POST /echo {bad` | 400, `{"error":"offset 1: expected \""}` |
| `GET /nope` | 404 JSON |
| `POST /echo` with 2 MB body (handler limit 1 MiB) | **500**, not 413: `readAll` throws `IO.userError`; the real handler must catch it and answer 413 |
| 200 parallel `POST /echo` | 200 x 200, no errors |

Source for the prototype is in the appendix.

## Options compared

| | Std.Http (core) | LeanServer (AfonsoBitoque) | Espal (ChristianMurphy) | algebraic-dev/http | jemmet + kroopt (nabbisen) |
|---|---|---|---|---|---|
| Toolchain | 4.35.0 (is the toolchain) | v4.29.1 per `lean-toolchain` (README says 4.27) | v4.35.0, but it is a framework on `Std.Http`; most packages are empty | 4.8.0, **archived** (moved into core) | v4.15.0 |
| Maintenance | Lean FRO (Sofia Rodrigues), active; fixes land on master | 1 author, 6 stars, last push 2026-05 | 1 author, 3 stars, active (2026-10-30), "early development" | dead | 1 author, 0 stars |
| TLS | none | own TLS 1.3 in Lean (~1k lines C FFI) | none (relies on Std.Http) | none | pure-Lean TLS (kroopt), unaudited |
| JSON | `Lean.Json` in core | own | `lean-json`, typed endpoints | none | ? |
| Concurrency | `Std.Async`, libuv, task per connection, `maxConnections` semaphore, graceful shutdown | own event loop | inherits Std.Http | n/a | ? |
| Fit | Small, owned by upstream, no new trust | Large (32k lines) trusted surface, version skew | Too heavy; wrong shape for 2 endpoints | n/a | version skew |

Other candidates seen and dismissed: `pb64-lean/tls13-lean` (TLS 1.3 over HACL*, nightly-2026-04
toolchain), `kaito2/lean-tls` (client only), `katzenpost/lean_tls`, `ttuegel/HttpServer.lean` and
`algebraic-dev/melp` (2023-24, pre-Async). None builds on 4.35.0 without porting and none has a
user base. The "verified" claims in LeanServer (935 theorems, `native_decide` for crypto
vectors) do not help us: they would enlarge, not shrink, the review surface, and the Lean-model of
TLS is not an interoperability guarantee.

## How a request is parsed

`Std.Http.Protocol.H1` (core, pure Lean) parses the request line and headers into
`Request.Head`. Limits come from `Std.Http.Config`: `maxHeaders` 50, `maxHeaderBytes` 64 KiB,
`maxRequests` 100 per connection, `maxBodySize` 64 MiB, `maxConnections` 1024,
`lingeringTimeout` 10 s. The body arrives as a `Body.Stream`; the handler calls
`req.body.readAll (maximumSize := some n)`, which is the real body cap we should use (a few
KiB for a tax return, not 64 MiB). The path is available as `req.line.uri.pathOrRoot`
(typed `URI.Path`; the prototype compared its `toString`). Methods are a typed enum
(`.get`, `.post`, `.options`, ...). JSON: `Lean.Json.parse` / `Json.compress`. A handler is a
`Request Body.Stream → ContextAsync (Response Body.Any)`, cancellable on shutdown.

## Trusted code and axioms

Adds **no `axiom`, no `opaque`, no `implemented_by`/`unsafe` in our repo**, and no new
dependency. Trust added (all upstream, none written or proved by us):

1. `Std.Http` H1 parser/serializer and server loop (about 1,100 lines in `Std/Http/Server*`,
   plus `Std/Http/Protocol/H1`, `Std/Http/Data`).
2. `Std.Async` and the C++ libuv wrapper in Lean's runtime (sockets, timers, event loop).
3. `Lean.Json` parse/print, which defines how request numbers become `Float`/`JsonNumber`.

None of this touches the verified computation if the boundary is kept thin: the handler
should (a) parse bytes with `Lean.Json`, (b) convert to the verified input type in a
separate pure function with a stated spec, (c) call the verified calculator, (d) encode. Only
(a) and (d) and the socket layer are trusted; (b) and (c) can be specified and proved. Number
handling in (a)/(b) deserves its own tests (money as integer cents or `JsonNumber` mantissa,
never `Float`); this belongs in #51. These items go in the README trusted-surface section (#59).

Our own audit tooling (`#audit_axioms`, forensics) applies to the pure functions; `serve` is
`IO` and has no theorem about it.

## Known issues in 4.35.0 (found or confirmed)

- **`Date` header is malformed**: observed `Date: Sat, 31 Oct 2026 22:31:33 +0000`, HTTP
  requires `GMT` (upstream fix lean4#15469, not in 4.35.0). Browsers and curl tolerate it. If
  strictness matters, the handler can set `Date` itself; `Std.Http` then leaves it alone.
- **Throughput is low** (lean4#13469; third-party benchmark `keithadler/lean-http-bench` on
  4.34.1: roughly 2-4k req/s per connection, degrading with 64+ connections, 10-70x slower
  than Go). Fixes #15174 etc. are on master, not in 4.35.0. Irrelevant for this app (one pure
  calculation per request, a hackathon workload), but do not promise performance numbers.
- **Errors escape as 500** (body-size overflow, handler exceptions). Wrap the handler in
  `try ... catch` and map to 4xx/5xx JSON (#53).
- `Std.Http` is young and its API moved within 2026 (a `@[deprecated]` appears in
  `Headers/Name.lean`). Staying on the pinned toolchain makes this a non-issue; a toolchain
  bump needs a rebuild and a glance at the Http changelog.
- Not evaluated: HTTP/2, WebSocket (Std.Http is HTTP/1.1 only; we do not need more).

## TLS story (feeds #55)

`Std.Http` has no TLS. `Server.serveConnection` is generic over a `Transport` class (`recv`,
`sendAll`, `recvSelector`, `close`), so a TLS layer could be inserted without forking, but
every Lean-native TLS option today is either (a) our own FFI to OpenSSL (new C code to write,
audit and build on every platform), or (b) a one-author pure-Lean TLS 1.3 stack that has had no
independent review and is pinned to other toolchains.

Recommendation for #55: **terminate TLS at a reverse proxy** (Caddy: one-line automatic
certificates; or nginx / the host platform's edge), with the Lean server bound to
`127.0.0.1` or a private network and speaking plain HTTP/1.1. Consequences:

- Trusted surface stays small and well-known: the proxy owns TLS, certificates, HTTP/2.
- The Lean server must not be exposed directly; document this in the Dockerfile (#58) and
  README (#59). Use a `docker compose` with Caddy, or Fly/Render/Cloud Run style managed TLS.
- If a hackathon rule demands "the Lean process itself speaks HTTPS", the fallback is a
  `Transport` instance over an OpenSSL FFI (estimate M-L, about 2-4 days including cert
  handling and tests). Do not adopt LeanServer/kroopt for this.
- The React frontend must call the HTTPS origin of the proxy. CORS is still the server's job
  (see below), but the allowed origin comes from the deployment config.

## Sizing for #51-#58

Assumes the recommendation. Size labels follow the repo's `size:` scheme (S < 1 day,
M 1-2 days, L 3-5 days).

| Issue | Work with Std.Http | Size | Risk / note |
|---|---|---|---|
| #51 Request parsing and validation | Pure `Json -> Except Err Input` layer plus body-size cap and Content-Type check; decimal/cents policy. Lean-side, proved/specified separately from IO | M | Depends on the shape of the Lean input type from the Catala port; no HTTP risk |
| #52 Wire `POST /calculate` | Router (match on method and path; no router library is needed for 2-3 routes) and calling the calculator | S | Blocked on the port |
| #53 Errors and knockout responses | One `try/catch` wrapper; map `IO.userError` from `readAll` to 413, parse errors to 400, knockout to a typed 200/422 payload | S | Need a stable error JSON schema |
| #54 CORS | Preflight handler already works in the prototype; configurable origin list, `Vary: Origin`, `Max-Age` | S | Prototype uses `*`; tighten to the frontend origin |
| #55 TLS | Proxy config (Caddyfile or compose) plus docs; fallback FFI is L | S (proxy) / L (FFI) | Decision for the human: is a proxy acceptable? |
| #56 Makefile install/run | `lake exe` binary, `PORT` arg or env var, `make run` | S | Binary is about 100 MB debug; use release build for the Docker image |
| #57 Integration tests | Start the exe on an ephemeral port (`serve` supports port 0 and `localAddr`), drive with curl or a Lean `Std.Http` client; `Std.Http.Internal` has a mock connection usable for in-process tests | M | Process lifecycle in CI |
| #58 Dockerfile | Multi-stage with elan pinned to v4.35.0, `lake build`, run non-root; proxy sidecar | S-M | Image build time (toolchain download) |

Total server-side path about 5-7 working days excluding #52's dependency on the calculator.

## Decisions for the human

1. Accept `Std.Http` from core as trusted (new upstream code, young, no TLS)? Recommended: yes.
2. Accept a reverse proxy for TLS (#55)? Recommended: yes; the alternative is custom FFI.
3. Body size cap value for `/calculate` (suggest 256 KiB) and the JSON number policy (#51).

## Appendix: prototype source

`Main.lean` (the only file; `lakefile.toml` declares one `lean_exe`, no `require`):

```lean
import Std.Http
import Lean.Data.Json
open Std Http Async Lean

def cors : Response.Builder → Response.Builder := fun b =>
  b.header! "Access-Control-Allow-Origin" "*"
   |>.header! "Access-Control-Allow-Methods" "POST, OPTIONS"
   |>.header! "Access-Control-Allow-Headers" "Content-Type"
   |>.header! "Access-Control-Max-Age" "600"

def jsonResp (st : Status) (j : Json) : ContextAsync (Response Body.Any) := do
  let r ← (cors (Response.withStatus st)).json j.compress
  return (r : Response Body.Any)

def handle (req : Request Body.Stream) : ContextAsync (Response Body.Any) := do
  let path := toString req.line.uri.pathOrRoot
  match req.line.method, path with
  | .options, "/echo" =>
      let r ← (cors (Response.withStatus .noContent)).empty
      return (r : Response Body.Any)
  | .post, "/echo" =>
      let s : String ← req.body.readAll (maximumSize := some 1048576)
      match Json.parse s with
      | .ok j => jsonResp .ok (Json.mkObj [("echo", j)])
      | .error e => jsonResp .badRequest (Json.mkObj [("error", Json.str e)])
  | _, "/echo" => jsonResp .methodNotAllowed (Json.mkObj [("error", "method not allowed")])
  | _, _ => jsonResp .notFound (Json.mkObj [("error", "not found")])

def main (args : List String) : IO UInt32 := do
  let port : UInt16 := (args.head?.bind String.toNat?).getD 8080 |>.toUInt16
  let addr : Net.SocketAddress := .v4 ⟨.ofParts 127 0 0 1, port⟩
  IO.println s!"listening on 127.0.0.1:{port}"
  Async.block do
    let srv ← Server.serve addr (Server.Handler.ofFn handle)
    srv.waitShutdown
  return 0
```

Sources consulted (all 2026-10-31): `Std/Http/**` in the v4.35.0 toolchain; GitHub repos
`AfonsoBitoque/LeanServer`, `ChristianMurphy/espal`, `algebraic-dev/http`, `nabbisen/jemmet`,
`nabbisen/kroopt`, `pb64-lean/tls13-lean`, `keithadler/lean-http-bench`.
