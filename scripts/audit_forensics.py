"""Judge a forensics dump (scripts/audit.sh, step 3).

Usage: python3 -I scripts/audit_forensics.py <forensics-out.json>

Fails (exit 1) on severity-high findings in declarations of modules under
UsTax, except UsTax.Comparator (challenge file, sorry by design):
  flags  sorry, nativeDecide, nonstandardAxiom
  smells trivialConclusion, conclusionUnfoldsToTrue, falseHypothesis,
         contradictoryHypotheses
  flags  partial, opaque, implementedBy, extern, unsafe, except in UsTax.Audit
         (audit tooling: `partial def specSurface.go` walks the environment)
Also fails if the project build inside forensics failed. Other smells
(unusedHypothesis, unusedVariable, ...) are counted as notes only.
"""
import json
import sys
from collections import Counter

HIGH_FLAGS = {"sorry", "nativeDecide", "nonstandardAxiom"}
HIGH_SMELLS = {"trivialConclusion", "conclusionUnfoldsToTrue",
               "falseHypothesis", "contradictoryHypotheses"}
TOOLING_FLAGS = {"partial", "opaque", "implementedBy", "extern", "unsafe"}
TOOLING_MODULES = {"UsTax.Audit"}

d = json.load(open(sys.argv[1]))
bad, notes = [], Counter()
if not d["build"]["ok"]:
    bad.append("forensics: lake build failed")
n = 0
for x in d["decls"]:
    m = x["module"]
    if m.split(".")[0] != "UsTax" or m.startswith("UsTax.Comparator"):
        continue
    n += 1
    for f in x["flags"]:
        if f in HIGH_FLAGS or (f in TOOLING_FLAGS and m not in TOOLING_MODULES):
            bad.append(f"{x['name']} ({m}): flag {f}")
    for s in x["smells"]:
        if s["code"] in HIGH_SMELLS:
            bad.append(f"{x['name']} ({m}): {s['code']}: {s['msg']}")
        else:
            notes[s["code"]] += 1
for g in d["diagnostics"]:
    if g.get("kind") == "hasSorry" and not g["file"].startswith("UsTax/Comparator"):
        bad.append(f"{g['file']}: hasSorry")
for b in bad:
    print("  " + b)
print(f"forensics: {n} declarations under UsTax, {len(bad)} high-severity finding(s); "
      f"notes (not failing): {dict(notes) or 'none'}")
sys.exit(1 if bad else 0)
