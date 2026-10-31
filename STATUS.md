# STATUS

Updated by the orchestrator after each merge round. Last update: 2026-11-01 (wave 4).

## Done (merged, each verified by the orchestrator by rebuilding and rerunning difftests)
M0: #5 #6 #7 #8 #9. Spikes: #50 (Std.Http), #55 (TLS doc; TLS not in critical path).
Catala: #10 rates, #11 std ded, #12 W-2, #13 interest, #14 1040 spine, #15 filers, #16 QC, #17 QR, #18 benefit split, #21 1099-G/PFD, #22 1099-R, #23 SS, #24 adjustments, #25 est. payments, #26 EITC, #27 CTC/ODC/ACTC, #29 Saver's, #30 Schedule R, #35 HSA, #36 knockouts A.
Lean: #39 money lib, #40 helpers, #41 rate schedule (+nonneg/monotone proofs), #42 three-way difftest harness, #43 spine (std ded, W-2, interest, 1040; refund/balance-due exclusivity proven), #51 request parsing/validation (+soundness proof).
Contract/FE/infra: #49 JSON contract, #74 FE API client, #70 (partial) CI + `make audit` + Comparator in Apple container (`make comparator`).

## In progress
Catala #19 HoH/QSS persons (+ wiring benefit split into QR). Lean #45 income types port. #63 Lean spec file (Opus; human must review the spec). Server vertical slice (#52/#54/#56/#53/#57). FE shell (#73/#75).

## Not yet done
CDCC #28, filing status #20, Sch 2/3 + credit order #31, PTC #32-34, knockouts B/aggregation #37/#38, wiring merged Catala modules into Form_1040, Lean ports #44/#46/#47/#48, FE screens #76-#82, proofs #64-#69, README trusted surface #59/#71, quirk decisions #60, spec reviews #61/#62/#68, final fresh-clone check.

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
