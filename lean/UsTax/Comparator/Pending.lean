import UsTax.Spec.Eitc
import UsTax.Spec.Credits

/-!
# Pending main theorems (not in `lean/comparator.json`)

`lake comparator` requires every theorem it is given to be proved, so the
main theorems whose implementation or proof does not exist yet are kept here,
as templates, and move to `UsTax/Comparator/Challenge.lean` (and their names
to `lean/comparator.json`) when they are proved. Not imported by
`UsTax.lean`, excluded from `make audit` like the rest of
`UsTax/Comparator/`. Listed in `docs/spec-surface.md`, section "Pending".

The statements are written as comments because the definitions they are about
do not exist yet in Lean: a `theorem ... := by sorry` over a function
variable would be a different (false) statement. The properties they use are
defined, reviewed and tested now (`UsTax/Spec/Eitc.lean`,
`UsTax/Spec/Credits.lean`).
-/

namespace UsTax.Main

open UsTax.Spec

/-! ## (4) EITC bounds, issue #67 (needs the Lean EITC, #46)

Template, with `Eitc.EitcIn` / `Eitc.eitc` the future Lean port of
`catala/eitc.catala_en` (scope `EitcTable`) and `Eitc.caseOf` reading the
four facts off its input:

```
theorem eitc_within_bounds (i : Eitc.EitcIn) :
    EitcWithinBounds (Eitc.caseOf i) (Eitc.eitc i) := by
  sorry
```

To check: all child counts (0, 1, 2, 3 or more) and both phase-out columns
(joint, other), as #67 asks; `EitcWithinBounds` covers both by its
parameters. -/

#check @EitcWithinBounds

/-! ## (3c) Credit wiring, issue #66 (needs CTC/ODC #27 and Schedule 3 in Lean)

`credits_within_liability` (in `Challenge.lean`, proved) is about line 22
given line 21. What is pending is that each nonrefundable credit, computed by
its own module, is limited by the tax left after the credits before it
(Schedule 8812 Credit Limit Worksheet A for CTC/ODC; Schedule 3 lines 1 to 7
in order), and that line 21 is their sum. Template, per credit `k` in order:

```
theorem credit_k_within_liability (i : Form1040In) :
    CreditsWithinLiability (taxLeftBefore_k i) (claimed_k i) (taxLeftAfter_k i) := by
  sorry
```

Refundable credits (EITC, additional child tax credit, net premium tax
credit) are payments (line 32), not part of this statement. -/

#check @CreditsWithinLiability

end UsTax.Main
