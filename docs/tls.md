# TLS strategy (issue #55)

## Decision

**Terminate TLS at a reverse proxy (Caddy). The Lean server speaks plain HTTP/1.1 on loopback.**

Rationale (from the server spike, `docs/lean-http-server.md`): `Std.Http` has no TLS. The Lean-native
options are our own OpenSSL FFI (new C code to write and audit, est. 2-4 days) or a one-author,
unreviewed pure-Lean TLS 1.3 stack pinned to other toolchains. A proxy gives a small, widely audited
TLS surface and keeps the Lean proof boundary about the calculator, not about cryptography.

Fallback if a rule ever demands "the Lean process itself speaks HTTPS": a `Transport` instance over an
OpenSSL FFI (see the spike). Not planned.

```
browser --HTTPS :8443--> Caddy --HTTP/1.1 127.0.0.1:8080--> Lean server (Std.Http)
browser --HTTP  :8088--> Caddy --308 redirect to https://localhost:8443/
```

## Local HTTPS: single command

Config: `deploy/Caddyfile`. Prerequisite: `caddy` v2 on PATH (`brew install caddy`, or your distro's
package). `make install` does not install it, to avoid global side effects.

```sh
make tls            # caddy run --config deploy/Caddyfile  (Lean server on 127.0.0.1:8080 behind it)
curl -k https://localhost:8443/<any route>   # -k: cert is from Caddy's local CA
make tls-trust      # optional, once: trust Caddy's local root CA so browsers and curl accept it
make tls-check      # validate the Caddyfile
```

Caddy generates a root CA and a leaf certificate for `localhost` on first start (automatic for
`localhost`); no cert files live in the repo.

## HTTP is redirected

Every site with a host name gets an automatic HTTP listener (`HTTP_PORT`, default 8088) that answers
`308 Permanent Redirect` to the HTTPS URL. Verify:

```sh
curl -si http://localhost:8088/ | head -3     # HTTP/1.1 308 ... Location: https://localhost:8443/
```

The Lean server must bind only `127.0.0.1` (the spike prototype does), so its plain-HTTP port is never
reachable from outside the machine. In Docker (#58) do not publish port 8080; publish only the proxy.

## Configuration (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `SITE_ADDRESS` | `localhost` | Host name served and certified |
| `UPSTREAM` | `127.0.0.1:8080` | Lean server address |
| `HTTP_PORT` | `8088` | Redirect-only listener (use 80 in prod) |
| `HTTPS_PORT` | `8443` | TLS listener (use 443 in prod) |

Dev ports are unprivileged on purpose, so no `sudo` is needed. Production example:
`SITE_ADDRESS=tax.example.com HTTP_PORT=80 HTTPS_PORT=443 caddy run --config deploy/Caddyfile`;
Caddy then obtains and renews a public ACME certificate itself. Certificate issuance automation beyond
Caddy's built-in behaviour is out of scope.

## Plugging into the Makefile

- `make tls`, `make tls-trust`, `make tls-check` sit next to the existing targets.
- The existing `run` target is unchanged (it runs the Catala checks). When #56 adds the Lean server
  target, `make run` should start the Lean server on loopback and, if `caddy` is on PATH, also start
  `make tls` and print the HTTPS URL. If `caddy` is missing it must print the install hint and still
  serve plain HTTP on `127.0.0.1:8080`, so `make install && make run` never fails on a fresh clone.
  Suggested shape for #56:
  ```make
  run: check
  	@command -v caddy >/dev/null && ($(MAKE) tls &) || echo "caddy not found: HTTP only on 127.0.0.1:8080 (see docs/tls.md)"
  	cd lean && lake exe ustax-server 8080
  ```
- Docker (#58): compose with two services, `server` (no published ports) and `caddy` (publishes 80/443,
  mounts `deploy/Caddyfile`, sets `UPSTREAM=server:8080`). Persist `/data` so Caddy keeps its CA.

## Interaction with CORS (#54)

- Caddy does **not** add CORS headers and passes `OPTIONS` preflights through; the Lean server is the
  single owner of CORS, so headers are never duplicated.
- The allowed origin is the frontend's origin, e.g. `http://localhost:5173` (Vite dev) or the deployed
  HTTPS site. The `*` in the spike prototype should become that configurable value.
- The frontend calls the **HTTPS** proxy origin (`https://localhost:8443`). An HTTPS API called from an
  HTTP dev page is fine (no mixed content); an HTTPS page calling the plain HTTP port would be blocked.
- In dev the browser must trust the Caddy CA (`make tls-trust`), otherwise `fetch` fails with a
  certificate error that looks like a CORS failure.
- The Lean server sees the proxy as its only client. If it needs the client IP, use `X-Forwarded-For`,
  which `reverse_proxy` sets.

## Trusted components (outside the Lean proof boundary)

| Component | Trusted for |
|---|---|
| Caddy (and Go `crypto/tls`) | TLS 1.2/1.3 termination, cert issuance/renewal, HTTP to HTTPS redirect, HSTS, 1 MB body cap |
| Caddy local CA / ACME CA | Authenticity of the certificate (dev: a local root you chose to trust) |
| Loopback / private network between proxy and Lean | Confidentiality of the proxy-to-server hop (plaintext) |
| `Std.Http` in Lean core | HTTP/1.1 parsing (see `docs/lean-http-server.md`) |
| OS and container runtime | Binding to loopback only, not publishing 8080 |

Proven in Lean: the tax calculation and request validation, not TLS or HTTP framing. Copy this list
into the README "Trusted base" section (#59).

## Not verified here

`caddy` was not installed in the authoring environment, so the Caddyfile has not been executed. It uses
only stock Caddy v2 directives (`reverse_proxy`, `encode`, `header`, `request_body`, global
`http_port`/`https_port`). Run `make tls-check` first.
