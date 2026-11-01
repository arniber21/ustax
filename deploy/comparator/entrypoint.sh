#!/bin/sh
# Runs inside the comparator image (see Containerfile, docs/comparator.md).
#
# /src  : the Lean project, mounted read-only from the host.
# /work : a container-local copy of it. /work/.lake is a volume that caches
#         dependency clones and builds between runs. It is never the host's
#         lean/.lake, so Linux build output does not mix with macOS output.
#
# Usage: comparator-entrypoint [all|check|comparator|extra]   (default: all)
#   extra: lake comparator against comparator.extra.json (second challenge)
set -u
MODE="${1:-all}"

echo "== bwrap probe"
if ! bwrap --ro-bind / / --tmpfs /tmp --dev /dev --proc /proc \
      --unshare-all --die-with-parent --new-session -- true; then
  echo "error: bwrap cannot create namespaces in this container." >&2
  echo "See docs/comparator.md, section 'bwrap inside the container'." >&2
  exit 2
fi
echo "bwrap $(bwrap --version | cut -d' ' -f2): namespaces OK"

echo "== sync /src -> /work (excluding .lake)"
find /work -mindepth 1 -maxdepth 1 ! -name .lake -exec rm -rf {} +
tar -C /src --exclude=./.lake -cf - . | tar -C /work -xf -

want="$(cat /work/lean-toolchain)"
have="$(lean --version)"
echo "lean-toolchain: $want"
echo "container lean: $have"
case "$want" in
  *"$(lean --version | sed -n 's/^Lean (version \([^,]*\),.*/\1/p')") ;;
  *) echo "error: image toolchain does not match lean-toolchain; rebuild the image" >&2; exit 2 ;;
esac

status=0
run() {
  echo "== $*"
  "$@"
  rc=$?
  echo "== exit $rc: $*"
  [ $rc -eq 0 ] || status=1
  return $rc
}

run lake build || { echo "build failed; skipping checks"; exit 1; }

if [ "$MODE" = all ] || [ "$MODE" = check ]; then
  run lake check
fi

if [ "$MODE" = all ] || [ "$MODE" = comparator ]; then
  if [ -f /work/comparator.json ]; then
    run lake comparator --config comparator.json
  else
    echo "== no comparator.json; skipping lake comparator"
  fi
fi

if [ "$MODE" = extra ]; then
  run lake comparator --config comparator.extra.json
fi

echo "== overall: $([ $status -eq 0 ] && echo PASS || echo FAIL)"
exit $status
