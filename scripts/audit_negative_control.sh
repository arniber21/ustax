#!/bin/sh
# Negative controls for scripts/audit.sh (issue #70): copy lean/ to a scratch
# directory, inject one violation at a time, and check the audit FAILS.
# Nothing is written to the repository. Exit 0 only if every control fails the
# audit as expected and the unmodified copy passes.
#
# Usage: scripts/audit_negative_control.sh [scratch-dir]
set -u
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="${1:-$(mktemp -d)}"
export SKIP_FORENSICS="${SKIP_FORENSICS:-0}"
bad=0

fresh() {  # fresh copy of lean/ (with its .lake build cache) in $SCRATCH/lean
  rm -rf "$SCRATCH/lean"
  mkdir -p "$SCRATCH"
  cp -R "$REPO/lean" "$SCRATCH/lean"
}

control() {  # control <name> <expected-step-regex>; injection already applied
  name="$1"; expect="$2"
  out="$(LEAN_DIR="$SCRATCH/lean" "$REPO/scripts/audit.sh" 2>&1)"; rc=$?
  if [ $rc -ne 0 ] && echo "$out" | grep -Eq "$expect"; then
    echo "ok   $name: audit failed as expected ($(echo "$out" | grep '^FAIL' | tr '\n' ';'))"
  else
    echo "BAD  $name: rc=$rc, expected failure matching '$expect'"; echo "$out" | tail -15
    bad=1
  fi
}

fresh
LEAN_DIR="$SCRATCH/lean" "$REPO/scripts/audit.sh" >/dev/null 2>&1 \
  && echo "ok   baseline copy passes" || { echo "BAD  baseline copy fails"; bad=1; }

fresh
printf '\ntheorem injected_sorry : (1 : Nat) + 1 = 2 := by sorry\n' >> "$SCRATCH/lean/UsTax/Money/Lemmas.lean"
control "sorry in an existing module" "FAIL: forbidden constructs in source.*"

fresh
printf 'import UsTax.Basic\naxiom injected_axiom : (1 : Nat) = 2\ntheorem uses_it : (1 : Nat) = 2 := injected_axiom\n' > "$SCRATCH/lean/UsTax/NegAxiom.lean"
control "axiom in a new module" "FAIL: forbidden constructs in source"

fresh
printf 'import UsTax.Basic\ntheorem injected_nd : (2 : Nat) + 2 = 4 := by native_decide\n' > "$SCRATCH/lean/UsTax/NegNative.lean"
control "native_decide" "FAIL: forbidden constructs in source"

fresh
printf 'import UsTax.Basic\nset_option maxHeartbeats 0 in\ntheorem hb : (2 : Nat) + 2 = 4 := by decide\n' > "$SCRATCH/lean/UsTax/NegHeartbeats.lean"
control "maxHeartbeats 0" "FAIL: forbidden constructs in source"

# The source scan is a text match; these bypass it (the axiom comes from a macro-built
# name), so only the environment audit and forensics can catch them.
fresh
cat > "$SCRATCH/lean/UsTax/NegHidden.lean" <<'EOF'
import Lean
import UsTax.Basic
open Lean Elab Command
elab "mk_ax" : command => liftCoreM <| addDecl <| .axiomDecl
  { name := `hidden_ax, levelParams := [], type := mkConst ``False, isUnsafe := false }
mk_ax
theorem uses_hidden : False := hidden_ax
EOF
control "axiom hidden from the text scan" "FAIL: axiom audit"

# Forensics only sees modules reachable from UsTax.lean, so import the module there.
fresh
printf 'import UsTax.Basic\ntheorem vacuous (h : False) : (1 : Nat) = 2 := h.elim\n' > "$SCRATCH/lean/UsTax/NegVacuous.lean"
echo "import UsTax.NegVacuous" >> "$SCRATCH/lean/UsTax.lean"
control "vacuous theorem (False hypothesis)" "FAIL: forensics high-severity"

rm -rf "$SCRATCH/lean"
[ $bad -eq 0 ] && echo "all negative controls behaved" || echo "NEGATIVE CONTROL FAILURE"
exit $bad
