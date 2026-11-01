# STATUS

Updated by the orchestrator after each merge round. Last update: 2026-11-01 (wave 4).

## Done (merged, each re-verified by the orchestrator)
Catala (whole 1040, all modules incl. PTC): `Calculator` scope passes 157/157 non-knocked-out Direct File scenarios, 5,360/5,360 fact checks; `ApiCalculator` (#38) 157/157, 3,105/3,105 through the API request shape.
Lean: money lib, helpers, rate schedule, spine, income types, household/filing status, CDCC/Saver's/Schedule R (#139), request validation. Proofs: Comparator set (tax table <$100k and >=$100k worksheet, refund/balance-due, credits within liability, total tax nonneg) + `make comparator-extra` (23 spec-vs-implementation theorems). `make audit` passes.
Product: devbox + CI, shadcn "US Tax" UI, provenance index (data side), README + write-up draft, Docker, TLS doc, API contract 1.2.0 (dependents, credits, PTC inputs).
DF bug log: 33 entries (docs/direct-file-bugs.md), DF-BUG-8 confirmed.

## Milestone: end-to-end whole-return calculator (2026-11-01)
`POST /calculate` runs the Lean ApiCalculator (#48/#151): W-2, interest, 1099-G/MISC/R, SS, adjustments, estimated payments, HSA, dependents, CTC/ODC/ACTC, EITC, CDCC, Saver's, Schedule R, PTC, knockouts. Verified: `make test-server` 46 passed / 0 failed / 1 skipped (error-500 not provokable); Lean vs Catala vs Direct File oracle: calculator 5,360 agree, api_calculator 3,105 agree; `make audit` PASS (7,790 declarations, 0 high-severity). Seen in the UI: MFJ, $80,000 wages, two kids -> refund $1,365 (matches hand-computed Catala test).

## In progress
Comparator + comparator-extra runs on main (serial, ~25 min). Then: regenerate provenance if stale, close #65/#66 if Comparator-extra passes.

## Not yet done
Lean Calculator (#48) + server sync (#52/#53/#57), provenance viewer in the UI, wizard steps for dependents/credits, Lean PTC/HSA port (#47), proofs #66/#69 composed over the Calculator, spec review by the human (docs/spec-surface.md), #60 quirk decisions, #59/#71 README trusted-surface, LICENSE decision, fresh-clone `make install && make run` check on Linux/CI.

## Process notes
- Merge guard (after the #143 incident, where a stale-base squash deleted merged work): before every merge, `git diff --diff-filter=D --name-only origin/main...<branch>` must be empty and the branch must contain origin/main.
- Local `sources/reference-catala/` (gitignored) breaks `make check` in the main checkout (clerk finds it); move it aside when running there.

## DECISIONS NEEDING THE HUMAN (defaults applied; reversible)
1. **Catala -> Lean strategy (#8): DECIDED by human: option (c)**: write the calculator directly in Lean, keep Catala as readable spec + test oracle, link them by differential testing (docs/catala-to-lean.md). Alternative (b) translator plugin is 50-80h. Part 2 issues (#39-48, #63, #64, #70) need re-scoping from "port" to "implement in Lean, difftest vs Catala". Server runs the Lean calculator.
2. Conflict policy: each overlapping Catala exception group gets a Lean proof of non-overlap or a combinator reproducing `Conflict`.
3. DECIDED by human: no TLS in critical path; plain HTTP on localhost via core Std.Http. Body cap 256 KiB (default).
4. Comparator needs Linux: trying Apple `container` (human suggestion).
5. CONVENTIONS.md open questions (see PR #85): Q2 1099-R code stripping, Q4 AOC stub = 0 without knockout, Q6 no tie-breakers, Q10 exact instead of Float, Q-R1 per-item rounding, Q-R2 cent ties.

## Findings
- scope.md says 322 scenarios; there are 161. scope.md §5.2 "Rev Proc .24" cite is actually §.24 of Rev. Proc. 2023-34 (not 2024-40); §11 item 5 only description wrong; item 1 matches the 1040 instructions. scope.md not edited (human-owned).
- Oracle uses the prebuilt Scala.js bundle; 157/161 `flowIsKnockedOut` are Placeholder false.
- `make forensics` writes its dump, then upstream tool crashes (`judging` ReferenceError). Dump is valid.
- Comparator/lake check Linux only; never use native_decide.
- **Policy (human, 2026-11-01): statute beats Direct File bugs.** Fix them; log in docs/direct-file-bugs.md (12 entries so far, DF-BUG-8 confirmed by running the DF engine: 1099-R box 8 StripChars "0." bug). Credit: discovered by the user's project.
- Difftest runner now supports `knownDivergence` reporting (via #35); verify behaviour when next touching it.
