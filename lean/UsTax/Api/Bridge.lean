import UsTax.Api.Spec

/-!
# Bridge to the calculator input (issue #51; fill in when #43 merges)

`Request` is the typed, validated image of the HTTP body. The calculator's
input is the Lean `Form1040` scope input (issue #43, on another branch). The
conversion is the **only** place that knows both field vocabularies (API box
names and Catala names), as `docs/api.md` states. It is meant to be a thin,
total, obviously-correct function:

```
def toForm1040Input (r : Request) (h : r.Valid) : Form1040In
```

Its rules, to implement when `UsTax/Form1040.lean` exists:

* money: `Int` cents to `Int` cents, **no arithmetic and no rounding** (the
  calculator rounds, per CONVENTIONS section 4);
* absent list = `[]`, absent box = `0`, absent flag = `false` (already applied
  by the decoder, so the bridge sees plain values);
* `FilerRole` to the Catala `FilerRole`; box 12 entries to the `FormW2`
  fields named in `$defs/W2Box12.description`; `Box12.entries` is looked up by
  code, absent code = `0`;
* `filing_details.treat_as_mfs = none` means `filingStatus = MarriedFilingSeparately`;
* the `Valid` hypothesis is what lets the calculator assume caps (sums over
  20 forms stay far below any overflow, and `Int` has none anyway).

Until then this module only records the contract and the lookup the bridge
needs.
-/

namespace UsTax.Api

/-- The amount of a box 12 code on a W-2; absent code is `0`. -/
def Box12.amount (b : Box12) (code : Box12Code) : Int :=
  ((b.entries.find? (·.1 == code)).map (·.2)).getD 0

end UsTax.Api
