#!/usr/bin/env python3
"""Spec checks of the comparator statements (CLAUDE.md section 4; issues #61, #62, #68).

Usage: python3 -I scripts/gen_spec_checks.py [--check]     (`make spec-checks`)

For every statement of `lean/comparator.json` (`UsTax.Main.<s>`) and
`lean/comparator.extra.json` (`UsTax.Extra.<s>`), looks in the Lean environment
(modules `UsTax.Spec.Checks.Main` and `UsTax.Spec.Checks.Extra`) for

* `UsTax.Checks.<Main|Extra>.<s>_sat`: a satisfiable instance. It must be a
  closed proposition (no hypotheses left: its type is not a `∀`/`→`) and its
  proof must use the statement `<s>` itself;
* `UsTax.Checks.<Main|Extra>.<s>_bad_<what>`: rejected bad outputs, at least two,
  each of type `¬ ...` (or `a ≠ b`).

The environment is read by a generated Lean file run with `lake env lean` (the
modules must be built: `cd lean && lake build`). It also checks that the request
texts embedded in `lean/UsTax/Spec/Checks/Requests.lean` are the
`api/examples/*.request.json` files (same JSON value).

Writes `docs/spec-checks.md` (with `--check`: fails if it is stale instead).
Exits 1 if any statement lacks a satisfiable instance or two bad outputs.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEAN = os.path.join(REPO, "lean")
DOC = os.path.join(REPO, "docs", "spec-checks.md")
REQUESTS = os.path.join(LEAN, "UsTax", "Spec", "Checks", "Requests.lean")
EXAMPLES = {  # Lean def -> api/examples file
    "singleW2Text": "single-w2-50k.request.json",
    "mfjKidsText": "family-mfj-two-kids.request.json",
    "hohEitcText": "eitc-hoh-one-child.request.json",
    "bondKoText": "knocked-out-bond-interest.request.json",
}
MIN_BAD = 2


def statements():
    out = []
    for cfg, group in (("comparator.json", "Main"), ("comparator.extra.json", "Extra")):
        with open(os.path.join(LEAN, cfg)) as f:
            names = json.load(f)["theorem_names"]
        for n in names:
            prefix = f"UsTax.{group}."
            if not n.startswith(prefix):
                sys.exit(f"{cfg}: {n} is not in namespace UsTax.{group}")
            out.append((cfg, group, n, n[len(prefix):]))
    return out


LEAN_META = r"""
import UsTax
open Lean Elab Command

/-- (statement, group, short name). -/
def specCheckStatements : List (Name × String × String) := [
%s]

/-- Constants used by the proof of `n`, following the auxiliary lemmas (`n._proof_1`, ...) that
Lean abstracts out of it. -/
partial def usedThroughAux (env : Environment) (root : Name) : NameSet :=
  let rec go (todo : List Name) (seen : NameSet) : NameSet :=
    match todo with
    | [] => seen
    | c :: rest =>
      if seen.contains c then go rest seen else
      let seen := seen.insert c
      let next := match env.find? c with
        | some (.thmInfo t) => t.value.getUsedConstants.toList
        | some (.defnInfo d) => d.value.getUsedConstants.toList
        | _ => []
      go ((next.filter fun x => root.isPrefixOf x && x != root) ++ rest) (seen.insertMany next)
  go [root] {}

elab "#spec_checks" : command => do
  let env ← getEnv
  let mut names : Array Name := #[]
  for m in [`UsTax.Spec.Checks.Main, `UsTax.Spec.Checks.Extra] do
    match env.getModuleIdx? m with
    | some idx => names := names ++ (env.header.moduleData[idx.toNat]!).constNames
    | none => throwError "module {m} is not imported"
  for (stmt, group, short) in specCheckStatements do
    if (env.find? stmt).isNone then
      logInfo m!"SPECCHECK {stmt} missing-statement"
    let ns := Name.mkSimple "UsTax" |>.str "Checks" |>.str group
    let base := s!"{short}"
    let mut sat := "-"
    let mut satOk := false
    let mut bads : Array String := #[]
    let mut badOk := true
    for n in names do
      -- only the user-facing theorems `UsTax.Checks.<group>.<last>`, not auxiliary lemmas
      unless n.getPrefix == ns && !n.isInternal do continue
      let last := match n with
        | .str _ s => s
        | _ => ""
      if last == base ++ "_sat" then
        sat := n.toString
        if let some ci := env.find? n then
          let closed := !ci.type.isForall
          satOk := closed && (usedThroughAux env n).contains stmt
      else if last.startsWith (base ++ "_bad_") then
        bads := bads.push n.toString
        if let some ci := env.find? n then
          let t := ci.type
          unless t.isAppOfArity ``Not 1 || t.isAppOfArity ``Ne 3 do badOk := false
    logInfo m!"SPECCHECK {stmt} sat={sat} satok={satOk} badok={badOk} bad={",".intercalate bads.toList}"

#spec_checks
"""


def run_lean(stmts):
    items = ",\n".join(f'  (`{n}, "{g}", "{s}")' for (_, g, n, s) in stmts)
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "SpecChecks.lean")
        with open(path, "w") as f:
            f.write(LEAN_META % items)
        p = subprocess.run(["lake", "env", "lean", path], cwd=LEAN, capture_output=True, text=True)
    out = p.stdout + p.stderr
    if p.returncode != 0 and "SPECCHECK" not in out:
        sys.exit("lake env lean failed (build lean/ first):\n" + out[-3000:])
    res = {}
    for m in re.finditer(r"SPECCHECK (\S+) sat=(\S+) satok=(\w+) badok=(\w+) bad=(\S*)", out):
        res[m.group(1)] = {
            "sat": None if m.group(2) == "-" else m.group(2),
            "satok": m.group(3) == "true",
            "badok": m.group(4) == "true",
            "bad": sorted(b for b in m.group(5).split(",") if b),
        }
    for m in re.finditer(r"SPECCHECK (\S+) missing-statement", out):
        res.setdefault(m.group(1), {})["missing"] = True
    return res


def lean_string(src, name):
    """The value of `def <name> : String := "..."` in Lean source, unescaped."""
    m = re.search(r"def %s : String := \"((?:[^\"\\]|\\.)*)\"" % re.escape(name), src, re.S)
    if not m:
        return None
    return m.group(1).encode("utf-8").decode("unicode_escape")


def check_requests():
    problems = []
    with open(REQUESTS) as f:
        src = f.read()
    for name, fname in EXAMPLES.items():
        text = lean_string(src, name)
        with open(os.path.join(REPO, "api", "examples", fname)) as f:
            want = json.load(f)
        if text is None:
            problems.append(f"{REQUESTS}: no def {name}")
        elif json.loads(text) != want:
            problems.append(f"{name} differs from api/examples/{fname}")
    return problems


def short(n):
    return n.split(".")[-1] if n else "-"


def render(stmts, res):
    lines = [
        "# Spec checks: satisfiable instances and rejected bad outputs",
        "",
        "Generated by `scripts/gen_spec_checks.py` (`make spec-checks`); do not edit by hand.",
        "",
        "For every statement judged by `lake comparator` (`lean/comparator.json`, main",
        "theorems; `lean/comparator.extra.json`, module specs), CLAUDE.md section 4 asks for",
        "a concrete instance with every hypothesis discharged and for known-bad outputs the",
        "spec rejects. They are theorems in `lean/UsTax/Spec/Checks/Main.lean` and",
        "`lean/UsTax/Spec/Checks/Extra.lean` (namespace `UsTax.Checks.Main` / `UsTax.Checks.Extra`).",
        "The script checks, in the Lean environment, that each `_sat` theorem is a closed",
        "proposition whose proof uses the statement, and that each `_bad_` theorem is a",
        "negation; it fails if a statement has no `_sat` or fewer than two `_bad_`.",
        "The whole-return statements are instantiated on `api/examples` requests read by the",
        "server's reader (`lean/UsTax/Spec/Checks/Requests.lean`).",
        "",
    ]
    for cfg in ("comparator.json", "comparator.extra.json"):
        group = [x for x in stmts if x[0] == cfg]
        lines += [f"## `lean/{cfg}` ({len(group)} statements)", "",
                  "| Statement | Satisfiable instance | Rejected bad outputs |", "|---|---|---|"]
        for (_, g, n, s) in group:
            r = res.get(n, {})
            sat = f"`{short(r.get('sat'))}`" if r.get("sat") else "**missing**"
            bad = ", ".join(f"`{short(b)}`" for b in r.get("bad", [])) or "**missing**"
            lines.append(f"| `{n}` | {sat} | {bad} |")
        lines.append("")
    return "\n".join(lines)


def main():
    check = "--check" in sys.argv[1:]
    stmts = statements()
    res = run_lean(stmts)
    fails = []
    for (_, _, n, _) in stmts:
        r = res.get(n)
        if r is None:
            fails.append(f"{n}: no result from Lean"); continue
        if r.get("missing"):
            fails.append(f"{n}: statement not in the environment")
        if not r.get("sat"):
            fails.append(f"{n}: no satisfiable instance (_sat)")
        elif not r["satok"]:
            fails.append(f"{n}: {r['sat']} is not a closed instance that uses the statement")
        if len(r.get("bad", [])) < MIN_BAD:
            fails.append(f"{n}: {len(r.get('bad', []))} bad output(s), need {MIN_BAD}")
        if not r.get("badok", True):
            fails.append(f"{n}: a _bad_ theorem is not a negation")
    fails += check_requests()
    doc = render(stmts, res)
    if check:
        with open(DOC) as f:
            if f.read() != doc + "\n":
                fails.append("docs/spec-checks.md is stale: run make spec-checks")
    else:
        with open(DOC, "w") as f:
            f.write(doc + "\n")
    n_bad = sum(len(res.get(n, {}).get("bad", [])) for (_, _, n, _) in stmts)
    print(f"spec-checks: {len(stmts)} statements, {sum(1 for (_, _, n, _) in stmts if res.get(n, {}).get('sat'))} "
          f"satisfiable instances, {n_bad} rejected bad outputs, {len(fails)} problem(s)")
    for x in fails:
        print("  FAIL " + x)
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
