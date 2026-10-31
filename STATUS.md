# STATUS

Updated by the orchestrator after each merge round. Last update: 2026-11-01 (wave 4).

## Done (merged, verified by orchestrator)
M0: #5 #6 #7 #8 #9. Spikes: #50 (Std.Http), #55 (Caddy optional, TLS not required for demo).
M1: #10 rates, #11 std deduction, #12 W-2, #13 interest, #14 Form 1040 spine.
M2: #15 filers, #16 qualifying child.
M3: #21 1099-G/PFD, #22 1099-R, #23 SS, #24 adjustments, #25 estimated tax. M5: #35 HSA.
Lean: #39 money lib, #40 Catala-semantics helpers.
All Catala modules match the oracle on every non-knocked-out scenario they cover (see PRs for counts).

## In progress
#41 Lean rate-schedule pilot; #30 Schedule R; Comparator in Apple container (Refs #70).

## Not yet wired
Merged modules are NOT yet plugged into Form_1040 slots (21,22,23,24,25,35 and filers/std-deduction wiring); a dedicated integration step is due.

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
