#!/bin/sh
# `make run`: build and start the Lean server (:8080) and, when the web app has a UI, the Vite dev
# server (:5173) together. Ctrl-C (or either process dying) stops both.
# Env: PORT (server, default 8080), WEB_PORT (default 5173), ALLOW_ORIGIN (CORS, default http://localhost:$WEB_PORT).
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8080}"
WEB_PORT="${WEB_PORT:-5173}"
export PORT
export ALLOW_ORIGIN="${ALLOW_ORIGIN:-http://localhost:$WEB_PORT}"
export VITE_API_URL="${VITE_API_URL:-http://localhost:$PORT}"

command -v lake >/dev/null 2>&1 || { echo "error: lake not found. Run 'make install' first (needs elan: https://elan.lean-lang.org)." >&2; exit 1; }
(cd "$REPO/lean" && lake build ustax-server) || { echo "error: lake build failed" >&2; exit 1; }

SERVER_PID=""; WEB_PID=""
cleanup() {
  trap '' INT TERM EXIT
  [ -n "$WEB_PID" ] && kill "$WEB_PID" 2>/dev/null
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
  wait 2>/dev/null
}
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM
trap cleanup EXIT

"$REPO/lean/.lake/build/bin/ustax-server" &
SERVER_PID=$!

# wait for the server (up to 10 s)
i=0
until curl -fs "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; do
  kill -0 "$SERVER_PID" 2>/dev/null || { echo "error: ustax-server exited at startup (is port $PORT free?)" >&2; exit 1; }
  i=$((i + 1)); [ "$i" -gt 100 ] && { echo "error: ustax-server did not answer on port $PORT" >&2; exit 1; }
  sleep 0.1
done
echo "API:  http://localhost:$PORT  (POST /calculate, GET /health, GET /version)"

if [ -f "$REPO/web/index.html" ] && [ -d "$REPO/web/node_modules" ]; then
  (cd "$REPO/web" && exec npm run dev -- --port "$WEB_PORT" --strictPort) &
  WEB_PID=$!
  echo "Web:  http://localhost:$WEB_PORT"
else
  echo "Web:  not started (web/index.html not present yet, or 'make install' not run); API only."
fi

# stop when either process exits
while kill -0 "$SERVER_PID" 2>/dev/null && { [ -z "$WEB_PID" ] || kill -0 "$WEB_PID" 2>/dev/null; }; do
  sleep 1
done
echo "a process exited; stopping" >&2
exit 1
