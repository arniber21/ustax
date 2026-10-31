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
