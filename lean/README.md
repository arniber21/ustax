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

`make comparator` runs `lake check` and `lake comparator` in a Linux container
(`docs/comparator.md`). `UsTax/Comparator/Challenge.lean` holds the trusted
statements with intended `sorry` proofs; it is not imported by `UsTax.lean`.

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

## Rate schedules, Form 1040 line 16 (`UsTax/TaxRates*.lean`, issue #41)

The first scope implemented in Lean, from `catala/tax_rates.catala_en`
(scope `TentativeTax`). It is the worked example of the pattern below.

- `UsTax/Types.lean`: `FilingStatus` (Catala `Types.FilingStatus`).
- `UsTax/TaxRates.lean`: the code that runs. The four 2024 schedules, the Tax
  Table midpoint (`roundedTaxableIncomeOf`), the marginal and cumulative forms,
  line 16 (`tentativeTaxFor`) and the scope (`tentativeTax : TentativeTaxIn →
  TentativeTaxOut`). Every assertion of `catala/tests/test_tax_rates.catala_en`
  is a `#guard` here.
- `UsTax/TaxRates/Spec.lean`: the readable specification `taxSpec`, written
  as the sources print it (midpoint rows; "$B plus R% of the excess over $X";
  round to the dollar), and the proofs that the code equals it for every
  filing status and every taxable income up to Catala's $1-trillion sentinel
  (`tentativeTaxFor_eq_taxSpec`, `tentativeTaxCumulativeFor_eq_taxSpec`,
  `tentativeTax_spec`). Above the sentinel the Catala marginal form, and so the
  code, stops taxing; an `example` shows they differ there. Also named
  examples and rejected bad outputs (the no-midpoint answer, the Rev. Proc.
  "$191,150" typo, a flat 10%, MFJ ≠ single).
- `UsTax/TaxRates/Lemmas.lean`: `tentativeTaxFor_nonneg` and
  `tentativeTaxFor_mono` (issue #64's key theorems for this scope), for every
  income and status with no hypothesis. The proof is pure arithmetic and does
  not use the bracket amounts, only that every rate is a nonnegative
  percentage, so it stays here (it is not deferred to #64).
- `UsTax/TaxRates/Props.lean`: plausible tests of those statements, run before
  proving and on every build, plus a negative control that must fail.
- `UsTax/TaxRates/TaxTable.lean`: golden test, 16,480 `#guard`ed checks (each
  of the 2,060 printed Tax Table rows at its lowest dollar and its highest
  cent, four columns). The data file `UsTax/TaxRates/TaxTableData.lean` is
  generated by `python3 scripts/gen_lean_tax_table.py` (run from the repository
  root) from `sources/forms-instructions/derived-tax-table-2024.csv`; do not
  edit it by hand.
- `UsTax/Cli.lean` and `Main.lean`: the `ustax` executable (`lake build ustax`).
  `ustax tentative-tax 14999 single` prints `1565.00`; `ustax run TentativeTax`
  reads Catala JSON inputs, one per line, and prints JSON outputs.
- `difftest/lean_rates.mjs` (`node difftest/lean_rates.mjs`, needs `clerk` and
  `ninja` on `PATH`): Lean vs `clerk run` of the Catala scope on 2,402
  incomes × 5 statuses, all three outputs (36,030 checks), and Lean vs the
  Direct File oracle `/tentativeTaxFromTaxableIncome` on all 157 scenarios that
  are not knocked out. `--dense 100 1000000` sweeps every dollar to $1,000,000;
  `--perturb` is the negative control (every check must fail).

Trusted for this scope: the Lean kernel and the definitions on the spec surface
(`#spec_surface UsTax.TaxRates.tentativeTaxFor_eq_taxSpec`: `taxSpec`,
`taxOnIncome`, `taxTableIncome`, `pctOf`, the code itself and the `Money`
primitives it uses). The agreement with Catala is by testing, not proof.

## Pattern for Lean modules (follow this for every later scope)

1. **One Lean file per Catala module**, `UsTax/<Module>.lean`, written by hand
   from the Catala source (strategy (c), `docs/catala-to-lean.md`), not from
   generated code. Same declarations, same order, names in lower camel case
   (`tentative_tax_for` → `tentativeTaxFor`, `schedule_mfj_qss` →
   `scheduleMfjQss`). The module docstring has a Catala ↔ Lean name table and
   cites the same sources as the Catala file. Shared enums and structures go in
   `UsTax/Types.lean`, mirroring `catala/types.catala_en`.
2. **Types.** Money is `Int` cents, decimal is `Rat`, integer is `Int` (no
   `Nat`, no `Money` alias: `omega` must see `Int`). Every Catala `money *
   decimal` is `Money.mulRate`, every `round of` is `Money.roundDollar`, every
   stdlib call is its `UsTax.Money` port; never round anywhere Catala does not.
   Definitions must be computable (no `Classical`, no `noncomputable`).
3. **Scopes.** A scope becomes a structure of its inputs (`<Scope>In`), a
   structure of its outputs (`<Scope>Out`), and a function
   `<scope> : <Scope>In → <Scope>Out`. Field names are the Catala names in
   lower camel case. Exception groups: an `if` chain plus a disjointness lemma,
   or `handleExceptions` (`UsTax/Defaults.lean`).
4. **Unit tests.** Every assertion of `catala/tests/test_<module>.catala_en`
   becomes a `#guard` at the end of the module. Generated golden data goes in a
   `*Data.lean` file made by a script in `scripts/` (header says so); the
   checks that use it are hand-written in a separate file.
5. **Specification.** `UsTax/<Module>/Spec.lean`: a readable statement of the
   rule as the source prints it, and a proof that the code meets it, for all
   inputs or with stated, satisfiable hypotheses. Add an `example` with every
   hypothesis discharged and a few `¬ spec bad` examples (CLAUDE.md section 4).
   A literal port of the Catala form plus an equality proof (as here) is worth
   it when the readable form differs from the Catala form.
6. **Properties.** `UsTax/<Module>/Props.lean` (plausible, before proving),
   then `UsTax/<Module>/Lemmas.lean` (proofs). End each proof file with
   `#audit_axioms` for its main theorems: only `propext`, `Classical.choice`,
   `Quot.sound`. No `sorry`, `native_decide` or raised `maxHeartbeats`.
7. **Driver.** Add one line to `UsTax.Cli.scopes`: a function from the
   scope's Catala JSON input (the shape `catala json-schema -s <Scope>`
   prints; money as a decimal string, enums by case name) to a JSON object of
   its outputs keyed by Catala output names, money as `"1234.56"`.
8. **Differential test.** `difftest/lean_<module>.mjs`, copied from
   `lean_rates.mjs`: build inputs, run `ustax run <Scope>` once over JSON lines
   and `clerk run` once over a batch wrapper scope
   (`catala/tests/difftest_<module>_batch.catala_en`: an input list of the
   scope's inputs, one output list per scope output), compare every output
   exactly in cents; then compare Lean with the oracle (`oracle/facts.csv`) on
   every scenario that is not knocked out. Report exact counts and keep a
   `--perturb` negative control. Single-input scopes are swept densely;
   multi-input scopes use the oracle scenarios plus a generator of valid inputs.
9. **Register** the new modules in `UsTax.lean`, build with `lake build`
   (one `lake` process at a time), and run `make forensics`.
