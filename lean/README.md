# ustax Lean project

Pinned per CLAUDE.md section 2: `lean-toolchain` = `leanprover/lean4:v4.35.0`
(forensics' known-good toolchain; also provides `lake check`/`lake comparator`).
`lake-manifest.json` is committed; do not run `lake update` except on purpose.

## Dependencies (no Mathlib)
- `batteries` v4.35.0: general-purpose data structures and lemmas beyond core.
- `plausible` v4.35.0: property-based testing of statements before proving them (CLAUDE.md section 5). Tag matches the toolchain exactly.

Both tags match Lean v4.35.0 exactly.

## Build
- Everything: `make lean-build` (or `cd lean && lake build`).
- One module: `cd lean && lake build UsTax.Audit` (or `lake env lean UsTax/Audit.lean`).

## Audit tooling
`UsTax/Audit.lean` provides `#spec_surface thm` (project definitions a theorem's
statement depends on; filter keeps modules rooted at `UsTax`) and
`#audit_axioms thm`. Allowed axioms: `propext`, `Classical.choice`, `Quot.sound`.

`make forensics` clones for-all-dev/forensics into `.forensics-tool/` (gitignored)
and runs, from `.forensics-tool/app`, `bun server.ts <abs path to lean/> --dump forensics-out.json`.
The project root is `lakefile.toml`, so module roots are inferred (else `--roots UsTax`).

## Money library (`UsTax/Money*.lean`, issue #39)

Catala 1.3.0 money semantics, ported from `catala_runtime.ml`, the stdlib
`Money` / `Decimal` modules and `catala/rounding.catala_en`.

- `UsTax/Money.lean`: definitions and `#guard` unit tests (tie cases $0.50,
  $1.50, $2.50, -$0.50; the `test_rounding.catala_en` cases; values printed by
  the Catala runtime). Money is a plain `Int` of cents and decimals are core
  `Rat`. There is no `Money` alias, because `omega` ignores hypotheses stated
  on an alias of `Int`. Rounding is ties away from zero (`roundRat`, `mulRate`,
  `roundDollar`). The other definitions are `truncateCents`, `stepwiseMultiply`,
  `roundDollarExact`, the stdlib `min`, `max`, `positive`, `truncate`,
  `roundByExcess`, `roundByDefault`, `sum`, and a literal port of
  `round_to_decimal` (`roundToDecimal`, `roundUpToThousand`).
- `UsTax/Money/Lemmas.lean`: an integer form of each rounding function, for
  `omega` (`roundDollar_eq`, `mulRate_div`, `truncateCents_div`,
  `stepwiseMultiply_eq`, `roundUpToThousand_eq_ceil`). Also monotonicity,
  idempotence, the `min`, `max`, `positive` and `sum` laws, and an axiom audit.
- `UsTax/Money/Props.lean`: plausible property tests. Each lemma statement was
  tested here before it was proved, and the tests run on every build.
- `UsTax/Money/Regression.lean`: reproduces the spike's rounding-placement
  counts (971 of 200,000 cents and 30,700 of 100,000 dollars).

Known differences from Catala, by design: division by zero returns `0` here,
where Catala raises `DivisionByZero`. `roundUpToThousand` is a ceiling only for
nonnegative amounts, which matches Catala.
