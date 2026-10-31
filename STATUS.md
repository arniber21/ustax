# STATUS

Updated by the orchestrator after each merge round. Last update: 2026-10-31 (wave 1).

## Done
- M0: #5 conventions, #6 oracle (161 scenarios), #7 difftest runner, #8 Catala->Lean spike, #9 Lean project
- #50 Lean HTTP server spike (Std.Http from core)
- #10 rate schedules (Tax Table: 16,480/16,480; oracle 157/157), #11 standard deduction (314/314), #13 interest (161/161)

## In progress
- #12 W-2

## DECISIONS NEEDING THE HUMAN (defaults applied; reversible)
1. **Catala -> Lean strategy (#8): default = option (c)**: write the calculator directly in Lean, keep Catala as readable spec + test oracle, link them by differential testing (docs/catala-to-lean.md). Alternative (b) translator plugin is 50-80h. Part 2 issues (#39-48, #63, #64, #70) need re-scoping from "port" to "implement in Lean, difftest vs Catala". Server runs the Lean calculator.
2. Conflict policy: each overlapping Catala exception group gets a Lean proof of non-overlap or a combinator reproducing `Conflict`.
3. TLS via reverse proxy (default yes); request body cap 256 KiB (default).
4. Comparator needs Linux (bwrap): #70 needs a Linux machine/CI.
5. CONVENTIONS.md open questions (see PR #85): Q2 1099-R code stripping, Q4 AOC stub = 0 without knockout, Q6 no tie-breakers, Q10 exact instead of Float, Q-R1 per-item rounding, Q-R2 cent ties.

## Findings
- scope.md says 322 scenarios; there are 161. scope.md §5.2 "Rev Proc .24" cite is actually §.24 of Rev. Proc. 2023-34 (not 2024-40); §11 item 5 only description wrong; item 1 matches the 1040 instructions. scope.md not edited (human-owned).
- Oracle uses the prebuilt Scala.js bundle; 157/161 `flowIsKnockedOut` are Placeholder false.
- `make forensics` writes its dump, then upstream tool crashes (`judging` ReferenceError). Dump is valid.
- Comparator/lake check Linux only; never use native_decide.
