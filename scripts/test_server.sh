#!/bin/sh
# `make test-server`: start ustax-server on a test port, run scripts/server_integration.mjs, stop it.
# Env: TEST_PORT (default 18080). Needs node >= 18 and a built lean/.lake/build/bin/ustax-server.
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TEST_PORT="${TEST_PORT:-18080}"
BIN="$REPO/lean/.lake/build/bin/ustax-server"
[ -x "$BIN" ] || { echo "error: $BIN missing; run 'cd lean && lake build ustax-server'" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo "error: node (>= 18) not found" >&2; exit 1; }

LOG="${TMPDIR:-/tmp}/ustax-server-test.$$.log"
PORT="$TEST_PORT" ALLOW_ORIGIN="http://localhost:5173" "$BIN" >/dev/null 2>"$LOG" &
PID=$!
trap 'kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; rm -f "$LOG"' EXIT INT TERM

i=0
until curl -fs "http://127.0.0.1:$TEST_PORT/health" >/dev/null 2>&1; do
  kill -0 "$PID" 2>/dev/null || { echo "error: server exited at startup (port $TEST_PORT busy?)" >&2; exit 1; }
  i=$((i + 1)); [ "$i" -gt 100 ] && { echo "error: server did not start" >&2; exit 1; }
  sleep 0.1
done
URL="http://127.0.0.1:$TEST_PORT"
status=0
ALLOW_ORIGIN="http://localhost:5173" node "$REPO/scripts/server_integration.mjs" "$URL" || status=1
# differential test against the Lean CLI (`make test-server` builds it)
if [ -x "$REPO/lean/.lake/build/bin/ustax" ]; then
  node "$REPO/scripts/server_vs_cli.mjs" "$URL" "$REPO/lean/.lake/build/bin/ustax" || status=1
else
  echo "SKIP server_vs_cli: lean/.lake/build/bin/ustax not built"
fi
exit $status
