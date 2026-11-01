#!/usr/bin/env python3
"""Generate lean/UsTax/Api/Reasons.lean from api/knockout-reasons.json.

The Lean enumeration `KnockoutReason` has one constructor per entry of
`api/knockout-reasons.json` (the 422 `reasons[].code`), in file order, with the
category and English message of the entry. `ReasonCategory` is the schema's
`$defs/ReasonCategory`. Output is deterministic.

Run from the repository root:
  python3 scripts/gen_lean_api_reasons.py           write the file
  python3 scripts/gen_lean_api_reasons.py --check   exit 1 if the checked-in file is stale
Then rebuild: cd lean && lake build UsTax.Api.Reasons
`ustax api-reasons` prints the table the binary was built with; `make api-conformance`
compares it with the JSON (scripts/api_conformance.mjs).
"""
import json
import sys

SRC = "api/knockout-reasons.json"
OUT = "lean/UsTax/Api/Reasons.lean"


def lower_first(s):
    return s[:1].lower() + s[1:]


def build():
    data = json.load(open(SRC))
    cats = data["categories"]
    reasons = data["reasons"]
    codes = [r["code"] for r in reasons]
    assert len(set(codes)) == len(codes), "duplicate code"
    for r in reasons:
        assert r["category"] in cats, r
        assert r["code"].isalnum() and r["code"][0].isupper(), r["code"]
        assert '"' not in r["message"] and "\\" not in r["message"], r
    L = []
    L.append("""import UsTax.Api.Response

/-!
# Knockout reasons of the 422 response (issue #51, #52)

**Generated** by `scripts/gen_lean_api_reasons.py` from `api/knockout-reasons.json`
(itself generated from the Catala `KnockoutReason` enums by `make api-reasons`).
Do not edit by hand. `KnockoutReason` has %d constructors, one per `reasons[].code`
of the contract, in file order; `ReasonCategory` is the schema's `ReasonCategory`.
`ustax api-reasons` prints the table and `scripts/api_conformance.mjs` compares it with
the JSON file, so a stale file fails `make api-conformance`.
-/

namespace UsTax.Api
""" % len(reasons))
    L.append("/-- `UnsupportedReason.category` (schema `ReasonCategory`). -/\ninductive ReasonCategory where")
    for c in cats:
        L.append("  /-- Wire value `%s`. -/\n  | %s" % (c, c))
    L.append("  deriving DecidableEq, Repr, Inhabited\n")
    L.append("/-- The wire spelling of a category. -/\ndef ReasonCategory.name : ReasonCategory → String")
    for c in cats:
        L.append('  | .%s => "%s"' % (c, c))
    L.append("")
    L.append("/-- `UnsupportedReason.code`: the Catala `KnockoutReason` constructor names. -/\ninductive KnockoutReason where")
    for r in reasons:
        L.append("  /-- Code `%s`. -/\n  | %s" % (r["code"], lower_first(r["code"])))
    L.append("  deriving DecidableEq, Repr, Inhabited\n")
    L.append("/-- Every reason, in `api/knockout-reasons.json` order. -/\ndef KnockoutReason.all : List KnockoutReason :=\n  [" +
             ",\n   ".join("." + lower_first(c) for c in codes) + "]\n")
    L.append("/-- The wire code (the Catala constructor name). -/\ndef KnockoutReason.code : KnockoutReason → String")
    for r in reasons:
        L.append('  | .%s => "%s"' % (lower_first(r["code"]), r["code"]))
    L.append("")
    L.append("/-- The category. -/\ndef KnockoutReason.category : KnockoutReason → ReasonCategory")
    for r in reasons:
        L.append("  | .%s => .%s" % (lower_first(r["code"]), r["category"]))
    L.append("")
    L.append("/-- English fallback text. -/\ndef KnockoutReason.message : KnockoutReason → String")
    for r in reasons:
        L.append('  | .%s => "%s"' % (lower_first(r["code"]), r["message"]))
    L.append("")
    L.append("""/-- The `UnsupportedReason` of the response. -/
def KnockoutReason.toReason (k : KnockoutReason) : UnsupportedReason :=
  { code := k.code, category := k.category.name, message := k.message }

/-- The table as JSON text, `[{"code":..,"category":..,"message":..}, ...]`, for the conformance check. -/
def reasonTableJson : String :=
  "[" ++ ",".intercalate (KnockoutReason.all.map fun k =>
    "{\\"code\\":\\"" ++ k.code ++ "\\",\\"category\\":\\"" ++ k.category.name ++
    "\\",\\"message\\":\\"" ++ k.message ++ "\\"}") ++ "]"

#guard KnockoutReason.all.length == %d
#guard (KnockoutReason.all.map KnockoutReason.code).eraseDups.length == %d

end UsTax.Api""" % (len(reasons), len(reasons)))
    return "\n".join(L) + "\n"


if __name__ == "__main__":
    text = build()
    if "--check" in sys.argv:
        if open(OUT).read() != text:
            print("%s is stale: run python3 scripts/gen_lean_api_reasons.py" % OUT)
            sys.exit(1)
        print("%s is up to date" % OUT)
    else:
        open(OUT, "w").write(text)
        print("wrote %s" % OUT)
