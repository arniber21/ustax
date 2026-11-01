#!/bin/sh
# `make install` / `devbox run install`: set up everything the server and web app need. No sudo.
# The tools (elan, Node, opam, ninja, ...) come from devbox.json; this script then installs the
# project-level parts:
#   1. the Lean toolchain pinned in lean/lean-toolchain (via elan) -> lake build
#   2. npm ci in web/ (when web/package.json exists)
#   3. OPTIONAL: Catala 1.3.0 + clerk in a project-local opam root (.opam), scripts/catala-setup.sh. It compiles
#      OCaml and Catala from source (10-20 minutes) and is only needed for the Catala tests (`make check`,
#      `make difftest`), never for the server or the web app, so it is OFF by default.
#      Turn it on with INSTALL_CATALA=1 (or `make install-all`).
# Run outside devbox it first hands over to devbox (see scripts/devbox-exec.sh: installs or
# explains how to install devbox) and re-runs itself inside.
set -u
if [ -z "${DEVBOX_SHELL_ENABLED:-}" ] && [ "${USTAX_NO_DEVBOX:-0}" != 1 ]; then
  exec "$(dirname "$0")/devbox-exec.sh" "$0" "$@"
fi
REPO="$(cd "$(dirname "$0")/.." && pwd)"
die() { echo "error: $1" >&2; exit 1; }

echo "== Lean"
command -v elan >/dev/null 2>&1 || die "elan not found. It comes with devbox (docs/devbox.md); with USTAX_NO_DEVBOX=1 install it yourself: https://elan.lean-lang.org"
TOOLCHAIN="$(cat "$REPO/lean/lean-toolchain")"
elan toolchain install "$TOOLCHAIN" || die "could not install Lean toolchain $TOOLCHAIN"
(cd "$REPO/lean" && lake build UsTax ustax ustax-server) || die "lake build failed"

echo "== Node"
command -v node >/dev/null 2>&1 || die "node not found (devbox provides it; see docs/devbox.md)"
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 18 ] || die "node $NODE_MAJOR is too old; need >= 18"
command -v npm >/dev/null 2>&1 || die "npm not found (it ships with Node.js)"
if [ -f "$REPO/web/package.json" ]; then
  (cd "$REPO/web" && npm ci --no-audit --no-fund) || die "npm ci failed in web/"
fi

echo "== Catala (optional, for 'make check' and difftest only)"
if [ "${INSTALL_CATALA:-0}" != "1" ] || [ "${SKIP_CATALA:-0}" = "1" ]; then
  echo "skipped: the server and web app do not need it. To run the Catala tests: make install-all  (10-20 min first time)"
elif command -v opam >/dev/null 2>&1; then
  "$REPO/scripts/catala-setup.sh" || echo "warning: Catala install failed; the server does not need it ('make run' still works). Retry: devbox run catala-setup" >&2
else
  echo "warning: opam not found; skipping Catala (the server does not need it)" >&2
fi

echo "install complete: run 'make run'"
