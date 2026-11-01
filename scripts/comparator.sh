#!/bin/sh
# Run `lake build`, `lake check` and (if lean/comparator.json exists)
# `lake comparator` on the Lean project inside a Linux container.
# See docs/comparator.md.
#
# Usage: scripts/comparator.sh [all|check|comparator|extra]
#   extra: `lake comparator` against lean/comparator.extra.json (module specs)
#
# Environment:
#   LEAN_DIR      Lean project to check (default: <repo>/lean). Point it at a
#                 copy to run a negative control without touching the repo.
#   RUNTIME       container runtime CLI (default: container, Apple's). `docker`
#                 should also work; only `container` was tested.
#   IMAGE         image tag (default: ustax-comparator)
#   CACHE_VOLUME  volume caching /work/.lake (default: ustax-comparator-lake).
#                 Set FRESH=1 to delete it first and build everything again.
#   MEMORY, CPUS  container resources (default: 8g, 8)
set -eu

REPO="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-all}"
LEAN_DIR="$(cd "${LEAN_DIR:-$REPO/lean}" && pwd)"
RUNTIME="${RUNTIME:-container}"
IMAGE="${IMAGE:-ustax-comparator}"
CACHE_VOLUME="${CACHE_VOLUME:-ustax-comparator-lake}"
MEMORY="${MEMORY:-8g}"
CPUS="${CPUS:-8}"

case "$MODE" in all|check|comparator|extra) ;; *)
  echo "usage: $0 [all|check|comparator|extra]" >&2; exit 2 ;;
esac

if [ "$RUNTIME" = container ] && ! container system status >/dev/null 2>&1; then
  echo "Apple container services are not running. Start them with:" >&2
  echo "  container system start" >&2
  exit 2
fi

TOOLCHAIN="$(cat "$LEAN_DIR/lean-toolchain")"
echo "== building image $IMAGE for $TOOLCHAIN"
"$RUNTIME" build -t "$IMAGE" --build-arg "LEAN_TOOLCHAIN=$TOOLCHAIN" \
  -f "$REPO/deploy/comparator/Containerfile" "$REPO/deploy/comparator"

if [ "${FRESH:-0}" = 1 ]; then
  "$RUNTIME" volume rm "$CACHE_VOLUME" >/dev/null 2>&1 || true
fi
"$RUNTIME" volume inspect "$CACHE_VOLUME" >/dev/null 2>&1 \
  || "$RUNTIME" volume create "$CACHE_VOLUME" >/dev/null

echo "== checking $LEAN_DIR"
exec "$RUNTIME" run --rm --memory "$MEMORY" --cpus "$CPUS" \
  -v "$LEAN_DIR:/src:ro" \
  -v "$CACHE_VOLUME:/work/.lake" \
  "$IMAGE" "$MODE"
