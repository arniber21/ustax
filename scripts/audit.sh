#!/bin/sh
# Proof audit for the Lean project (issue #70, CLAUDE.md section 7). `make audit`.
#
# Steps (all run; exit 1 if any fails):
#  1. source scan  : no sorry/admit/native_decide/bv_decide/axiom/skipKernelTC/
#                    maxHeartbeats 0/implemented_by/extern/unsafe in lean/UsTax
#  2. axiom audit  : build every module under lean/UsTax (not Comparator), fail
#                    on "declaration uses sorry", then `#audit_all` (UsTax/Audit.lean)
#                    over a generated file importing all of them: every theorem and
#                    definition may use only propext, Classical.choice, Quot.sound
#  3. forensics    : for-all-dev/forensics extractor; severity-high smells fail
#
# lean/UsTax/Comparator/ is excluded everywhere: Challenge.lean holds the trusted
# statements with `sorry` proofs BY DESIGN (docs/comparator.md). It is not imported
# by UsTax.lean and is judged by `lake comparator`, not by this script.
#
# Environment:
#   LEAN_DIR          project to audit (default <repo>/lean); point at a copy for
#                     negative controls (scripts/audit_negative_control.sh)
#   SKIP_FORENSICS=1  skip step 3 (needs bun and network on first run)
#   FORENSICS_REV     forensics commit (default pinned below)
#   FORENSICS_DIR     where its clone lives (default <repo>/.forensics-tool)
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LEAN_DIR="$(cd "${LEAN_DIR:-$REPO/lean}" && pwd)"
FORENSICS_REV="${FORENSICS_REV:-e5b80ca2590bab3129013cbdf61ec67a32fd9e2c}"
FORENSICS_DIR="${FORENSICS_DIR:-$REPO/.forensics-tool}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
status=0
fail() { echo "FAIL: $1"; status=1; }

echo "== 1. source scan ($LEAN_DIR/UsTax, excluding Comparator/)"
python3 -I "$REPO/scripts/audit_scan.py" "$LEAN_DIR" || fail "forbidden constructs in source"

echo "== 2. axiom audit"
cd "$LEAN_DIR" || exit 2
MODS="$(find UsTax -name '*.lean' ! -path 'UsTax/Comparator/*' | sort | sed 's/\.lean$//; s#/#.#g')"
{ echo "import UsTax"; for m in $MODS; do echo "import $m"; done
  echo "open UsTax.Audit"; echo "#audit_all"; } > "$WORK/AuditAll.lean"
# shellcheck disable=SC2086
if lake build UsTax $MODS > "$WORK/build.log" 2>&1; then
  if grep -q "declaration uses .sorry" "$WORK/build.log"; then
    grep "declaration uses" "$WORK/build.log" | sed 's/^/  /'
    fail "build reports declaration uses sorry"
  fi
else
  tail -20 "$WORK/build.log"; fail "lake build"
fi
if lake env lean "$WORK/AuditAll.lean" > "$WORK/axioms.log" 2>&1; then
  grep -E "AUDIT OK" "$WORK/axioms.log"
else
  grep -v "^info: .*theorem " "$WORK/axioms.log" | sed 's/^/  /'
  fail "axiom audit (#audit_all)"
fi

if [ "${SKIP_FORENSICS:-0}" = 1 ]; then
  echo "== 3. forensics: skipped (SKIP_FORENSICS=1)"
else
  echo "== 3. forensics (rev $FORENSICS_REV)"
  if [ ! -d "$FORENSICS_DIR/app" ]; then
    git clone -q https://github.com/for-all-dev/forensics "$FORENSICS_DIR" || fail "clone forensics"
  fi
  # Always (re)pin: a clone made by `make forensics` may be at another revision.
  (cd "$FORENSICS_DIR" && git checkout -q "$FORENSICS_REV") || fail "checkout forensics rev"
  (cd "$FORENSICS_DIR/app" && bun install --frozen-lockfile >/dev/null 2>&1)
  DUMP="$WORK/forensics-out.json"
  # The upstream server throws ReferenceError ('judging' before initialization)
  # right AFTER writing the dump, so its exit status is meaningless: success
  # means a complete, parseable dump exists.
  (cd "$FORENSICS_DIR/app" && bun server.ts "$LEAN_DIR" --dump "$DUMP") > "$WORK/forensics.log" 2>&1
  if [ -s "$DUMP" ] && python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$DUMP" 2>/dev/null; then
    python3 -I "$REPO/scripts/audit_forensics.py" "$DUMP" || fail "forensics high-severity findings"
  else
    tail -20 "$WORK/forensics.log"; fail "forensics wrote no dump"
  fi
fi

echo "== audit: $([ $status -eq 0 ] && echo PASS || echo FAIL)"
exit $status
