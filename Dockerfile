# syntax=docker/dockerfile:1
# Reproducible container for the ustax Lean server and web app (issue #58, docs/deploy.md).
#
#   docker build -t ustax-server .                    # default target: the Lean HTTP API
#   docker build --target web -t ustax-web .          # static web app + same-origin proxy (Caddy)
#
# Works with Apple's `container build` as well. Build context is the repo root.

ARG UBUNTU_TAG=24.04
ARG NODE_TAG=22.12-bookworm-slim
ARG CADDY_TAG=2.8.4-alpine
# Must equal lean/lean-toolchain (checked by `make docker-build`).
ARG LEAN_TOOLCHAIN=leanprover/lean4:v4.35.0
ARG ELAN_VERSION=v4.2.4

# ---- 1. Lean server -----------------------------------------------------------------------
FROM ubuntu:${UBUNTU_TAG} AS lean-build
ARG LEAN_TOOLCHAIN
ARG ELAN_VERSION
ENV DEBIAN_FRONTEND=noninteractive ELAN_HOME=/opt/elan PATH=/opt/elan/bin:$PATH
# git: lake clones batteries and plausible (pinned by rev in lean/lake-manifest.json).
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl ca-certificates xz-utils zstd \
 && rm -rf /var/lib/apt/lists/*
RUN curl -sSfL "https://github.com/leanprover/elan/releases/download/${ELAN_VERSION}/elan-$(uname -m)-unknown-linux-gnu.tar.gz" \
      | tar -xz -C /tmp \
 && /tmp/elan-init -y --no-modify-path --default-toolchain "${LEAN_TOOLCHAIN}" \
 && rm -f /tmp/elan-init \
 && lean --version
WORKDIR /src/lean
# Dependencies first so they are cached until the manifest changes.
COPY lean/lean-toolchain lean/lakefile.toml lean/lake-manifest.json ./
RUN lake resolve-deps
COPY lean/ ./
RUN lake build ustax-server

# ---- 2. Web app ---------------------------------------------------------------------------
FROM node:${NODE_TAG} AS web-build
WORKDIR /src
COPY api/ ./api/
COPY web/package.json web/package-lock.json ./web/
RUN cd web && npm ci --no-audit --no-fund
COPY web/ ./web/
# Empty API URL: the browser calls /calculate on the page's own origin; the proxy forwards it.
ENV VITE_API_URL=""
RUN cd web && npm run build

# ---- 3. Static web + reverse proxy (Caddy) ------------------------------------------------
FROM caddy:${CADDY_TAG} AS web
COPY deploy/Caddyfile.docker /etc/caddy/Caddyfile
COPY --from=web-build /src/web/dist /srv
ENV UPSTREAM=server:8080
EXPOSE 80 443

# ---- 4. Lean server runtime (default target; keep last) -----------------------------------
FROM ubuntu:${UBUNTU_TAG} AS server
# tzdata is required: Std.Http reads /usr/share/zoneinfo/UTC to build the Date header, and without it
# the server accepts the request, logs "OK", then closes the socket with no response (empty reply).
RUN apt-get update \
 && apt-get install -y --no-install-recommends tzdata \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 10001 --no-create-home ustax
COPY --from=lean-build /src/lean/.lake/build/bin/ustax-server /usr/local/bin/ustax-server
USER ustax
# Plain HTTP. In a container the process must listen on all interfaces; publish the port only
# to trusted networks, or put Caddy in front (docs/tls.md).
ENV HOST=0.0.0.0 PORT=8080 ALLOW_ORIGIN=http://localhost:8081
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/ustax-server"]
