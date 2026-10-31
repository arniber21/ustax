# STATUS

Updated by the orchestrator after each merge round. Last update: 2026-10-31 (wave 1).

## Done
- #9 Lean project: `lean/`, Lean v4.35.0, Batteries + plausible pinned, `make lean-build`, `make forensics`.
- #6 Oracle: `oracle/facts.csv` (161 scenarios, `make oracle`). 4 scenarios flagged knocked out by the engine.

## In progress
- #5 Catala conventions (Opus)
- #8 Catala -> Lean strategy spike (Opus)

## Decisions / findings for the human
- **scope.md says 322 scenarios; there are 161** (`backend/src/test/resources/scenarios/*.json`; the other 161 files are expected-export snapshots). scope.md is not edited by agents; please correct.
- Oracle uses the pre-built Scala.js bundle committed in direct-file, not rebuilt from Scala sources (trusted as-is).
- 157/161 scenarios report `/flowIsKnockedOut=false` only as a Placeholder default, never a Complete false. The differential runner (#7) should treat "not knocked out" as "engine did not say true".
- `make forensics` writes its dump, then the upstream tool crashes (`ReferenceError ... 'judging'` at app/server.ts:75). Treat the dump as valid; exit code is unreliable.
- Policy: every Lean PR/commit must be clean under forensics (no sorry, native_decide, nonstandard axioms, vacuity/trivial flags, linter/heartbeat escape hatches). Direct commits to main are allowed per the user while a single implementer runs.
- Session runs in tmux; if it dies, in-flight worktree branches remain on disk and pushed PRs remain on GitHub.
