#!/bin/sh
# `make install`: check and install what the server and web app need. No sudo, nothing is removed.
#   1. elan (required) -> the Lean toolchain pinned in lean/lean-toolchain -> lake build
#   2. node/npm (required) -> npm ci in web/ (when web/package.json exists)
#   3. opam (optional, only for the Catala sources) -> catala + clerk. SKIP_CATALA=1 skips it.
# Elan is not installed for you (it is a curl-to-sh installer); the error says how.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
die() { echo "error: $1" >&2; exit 1; }

echo "== Lean"
command -v elan >/dev/null 2>&1 || die "elan not found. Install it (no sudo needed): curl https://elan.lean-lang.org/elan-init.sh -sSf | sh   then restart the shell (or: source \$HOME/.elan/env)"
TOOLCHAIN="$(cat "$REPO/lean/lean-toolchain")"
elan toolchain install "$TOOLCHAIN" || die "could not install Lean toolchain $TOOLCHAIN"
(cd "$REPO/lean" && lake build UsTax ustax ustax-server) || die "lake build failed"

echo "== Node"
command -v node >/dev/null 2>&1 || die "node not found. Install Node.js >= 18 (https://nodejs.org, or your package manager) and re-run make install"
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 18 ] || die "node $NODE_MAJOR is too old; need >= 18"
command -v npm >/dev/null 2>&1 || die "npm not found (it ships with Node.js)"
if [ -f "$REPO/web/package.json" ]; then
  (cd "$REPO/web" && npm ci --no-audit --no-fund) || die "npm ci failed in web/"
fi

echo "== Catala (optional, for 'make check' and difftest only)"
if [ "${SKIP_CATALA:-0}" = "1" ]; then
  echo "skipped (SKIP_CATALA=1)"
elif command -v opam >/dev/null 2>&1; then
  opam install -y catala.1.3.0 && clerk start || echo "warning: Catala install failed; the server does not need it ('make run' still works)" >&2
else
  echo "warning: opam not found; skipping Catala (the server does not need it). To check the Catala sources: https://opam.ocaml.org/doc/Install.html" >&2
fi

echo "install complete: run 'make run'"
