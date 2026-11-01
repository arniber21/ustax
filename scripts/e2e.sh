#!/bin/sh
# `make e2e`: Playwright end-to-end tests against the REAL stack (Lean server + Vite dev server).
# Playwright's webServer config (web/playwright.config.ts) starts both servers and stops them at the end.
# Env (all optional):
#   SKIP_LEAN_BUILD=1   do not run `lake build ustax-server` (use an existing binary)
#   USTAX_SERVER_BIN    server binary (default lean/.lake/build/bin/ustax-server)
#   E2E_API_PORT / E2E_WEB_PORT   ports (defaults 8190 / 5190; not 8080 / 5173)
#   E2E_CHANNEL=chrome  use the installed Google Chrome instead of Playwright's Chromium
#   ARGS="-g single"    extra arguments for `playwright test`
set -eu
REPO="$(cd "$(dirname "$0")/.." && pwd)"
API_PORT="${E2E_API_PORT:-8190}"
WEB_PORT="${E2E_WEB_PORT:-5190}"
export E2E_API_PORT="$API_PORT" E2E_WEB_PORT="$WEB_PORT"

for p in "$API_PORT" "$WEB_PORT"; do
  if curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$p/" 2>/dev/null; then
    echo "error: port $p is already in use; set E2E_API_PORT / E2E_WEB_PORT" >&2
    exit 1
  fi
done

if [ -z "${SKIP_LEAN_BUILD:-}" ]; then
  (cd "$REPO/lean" && lake build ustax-server)
fi
export USTAX_SERVER_BIN="${USTAX_SERVER_BIN:-$REPO/lean/.lake/build/bin/ustax-server}"
[ -x "$USTAX_SERVER_BIN" ] || { echo "error: $USTAX_SERVER_BIN missing" >&2; exit 1; }

cd "$REPO/web"
[ -d node_modules ] || npm ci --no-audit --no-fund
if [ -z "${E2E_CHANNEL:-}" ]; then
  npx playwright install chromium
fi
# shellcheck disable=SC2086
exec npx playwright test ${ARGS:-}
