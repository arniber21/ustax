# Deployment (issue #58)

One `Dockerfile` (repo root), two images, one `docker-compose.yml`. Cloud-specific infrastructure is out of scope.

| Image / target | Contents | Port |
|---|---|---|
| `server` (default) | Lean `ustax-server`, built with the pinned toolchain `leanprover/lean4:v4.35.0` (elan `v4.2.4`; dependency revs from `lean/lake-manifest.json`), on `ubuntu:24.04`, non-root | plain HTTP `8080` |
| `web` | Vite production build of `web/` served by Caddy (`caddy:2.8.4-alpine`), which also proxies `/calculate`, `/health`, `/version` to the server (same origin, no CORS) | `80` (HTTP), `443` (HTTPS if enabled) |

Stages: `lean-build` (elan, `lake resolve-deps`, `lake build ustax-server`) and `web-build` (`node:22.12-bookworm-slim`, `npm ci`, `npm run build` with an empty `VITE_API_URL`) feed the two final images. Base images are pinned by tag, not digest.

## Run

```sh
make docker-run          # docker compose up --build
```

- API: `http://127.0.0.1:8080` (`POST /calculate`, `GET /health`, `GET /version`)
- Web app: `http://localhost:8081`
- `make docker-build` only builds both images. `DOCKER=container make docker-build` uses Apple's `container` CLI (it has no compose, see below).

```sh
curl -s -X POST localhost:8080/calculate -H 'content-type: application/json' \
  --data @api/examples/single-w2-50k.request.json     # agi 5000000, total_tax 401900 (cents)
```

## HTTPS (optional, Caddy)

Per `docs/tls.md`, TLS is terminated by Caddy; the Lean process only speaks plain HTTP. The `web` container is that Caddy (`deploy/Caddyfile.docker`). Set `SITE_ADDRESS` to a host name and Caddy enables HTTPS:

```sh
SITE_ADDRESS=localhost docker compose up --build      # https://localhost:8443 (Caddy local CA; curl -k)
SITE_ADDRESS=tax.example.com docker compose up -d     # publish 80/443 (edit ports), public ACME cert
```

Caddy's CA and certificates live in the `caddy-data` volume. With `SITE_ADDRESS=localhost` the HTTP port answers a 308 to `https://localhost/` (no port), so use the HTTPS port directly. In production, publish only the `web` ports: delete the `8080` line under `server` in `docker-compose.yml`, so the plain-HTTP API is reachable only through Caddy. Without a proxy, `ALLOW_ORIGIN` (comma separated) must list the page's origin.

## Without compose (Apple `container`)

```sh
container system start        # once
container build --target server -t ustax-server .
container build --target web -t ustax-web .
container network create ustax-net
container run -d --name ustax-server --network ustax-net -p 127.0.0.1:8080:8080 ustax-server
container ls                  # note the server's IP
container run -d --name ustax-web --network ustax-net -p 8081:80 -e UPSTREAM=<server-ip>:8080 ustax-web
```

Container names did not resolve as host names in Apple `container` 1.0.0, so `UPSTREAM` takes the IP. (Compose service names, `server:8080`, work under Docker.)

## Verified

Built and run with Apple `container` 1.0.0 (arm64). Docker/compose were not run (the Docker daemon, OrbStack, was not running); `docker-compose.yml` is untested.
`POST /calculate` with `api/examples/single-w2-50k.request.json` returns `agi` 5000000, `taxable_income` 3540000, `total_tax` 401900 (cents: $50,000 and $4,019), both direct on `:8080` and through the web proxy on `:8081`. `GET /health` over HTTPS (`SITE_ADDRESS=localhost`) returns `HTTP/2 200 {"status":"ok"}`.

## Gotchas

- The runtime image needs `tzdata`. `Std.Http` reads `/usr/share/zoneinfo/UTC` for the `Date` header; without it the server logs `GET /health OK` and then closes the socket with an empty reply.
- The container binds `HOST=0.0.0.0` (the default elsewhere is `127.0.0.1`). Do not publish `8080` beyond loopback without a proxy.
- `calculator_version` reports `unknown`: the image has no `.git`, which `gitVersion` shells out to.

## Trusted components

Add to the README trusted base (#59): Docker/OCI runtime and base images (`ubuntu`, `node`, `caddy`), elan release download, Caddy (see `docs/tls.md`).
