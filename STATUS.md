# STATUS

Updated by the orchestrator after each merge round. Last update: 2026-11-01 (final documentation pass,
issues #59, #71).

## Done (merged, each re-verified by the orchestrator)

- **Catala, whole 1040** (37 modules, 20,802 lines, every module incl. PTC): `make check` 602/602 tests;
  `make difftest SCOPE=calculator` 157/157 non-knocked-out Direct File scenarios, 5,360/5,360 fact checks, 9 known divergences (re-run 2026-11-01); `ApiCalculator` (#38) 157/157, 3,105/3,105 through
  the API request shape.
- **Lean, whole return** (#48, PR #151): every module ported (money, rates, spine, income, adjustments,
  household and filing status, HSA, PTC, CDCC, Saver's, Schedule R, EITC, CTC/ODC/ACTC, knockouts),
  `Calculator` and `ApiCalculator`. Three-way difftest: calculator 5,360 agree, api_calculator 3,105
  agree, 0 failures; perturbed runs fail as they must.
- **Server**: `POST /calculate` runs the Lean `ApiCalculator` on the whole return. `make test-server`
  46 passed / 0 failed / 1 skipped (error-500 not provokable, and proved impossible:
  `calculateRequest_ne_fault`); server = CLI on 315 requests.
- **Proofs**: `lean/comparator.json` 9 theorems, `lean/comparator.extra.json` 31; `make comparator` and
  `make comparator-extra` PASS on 2026-11-01 (issues #65, #66). `make audit` PASS on the PR #156 tree
  (`lean/` unchanged since): axiom step 2,212 theorems, 6,681 definitions, axioms
  `propext`/`Classical.choice`/`Quot.sound` only; forensics 7,981 declarations, 0 high-severity. Spec
  checks: each of the 40 statements has a `_sat` instance and 2+ `_bad_` outputs, 82 in all
  (`docs/spec-checks.md`).
- **Quirks** (#60, PR #156): every DF-BUG row and CONVENTIONS item has a decision and a pinning test
  (`docs/quirk-decisions.md`); open questions below.
- **Product**: devbox + CI; shadcn "US Tax" UI with wizard for dependents, household, credits and care;
  running estimate; Law & proof drawer on every line (`api/provenance.json`, `make provenance-check`
  OK); ⌘K palette; Verification page; docs site at `/docs` (`docs/site/`); API reference at `/docs/api`
  (`api/openapi.json`); Docker; TLS doc; API contract 1.2.0; e2e tests (`make e2e`); screenshots in
  `docs/screenshots/`; demo script `scripts/demo.md`.
- **Docs**: README (proved / verified / tested / trusted table, trusted base, server trusted surface),
  `docs/trusted-base.md`, write-up `docs/writeup.md`, `docs/site/what-verified-means.md`.
- **DF bug log**: 33 entries (`docs/direct-file-bugs.md`); DF-BUG-8 confirmed by running the DF engine
  (credit: Arnab Ghosh).
- **Install**: `make install` builds Lean + web only; Catala is opt-in (`make install-all`).

## Open

- Fresh-clone `make install && make run` check (in progress on this machine; also on Linux/CI).
- CI runs on `main` were cancelled by newer pushes on 2026-11-01; one green run on the final commit is
  still to be seen.
- Pending statement: per-credit limits in Schedule 3 order (`lean/UsTax/Comparator/Pending.lean`).

## Known gaps (documented, not planned for the submission)

- Catala-to-Lean link is differential testing, not proof.
- JSON reader, response serialisation, `ServerMain.lean` and `Std.Http`: tested, not proved.
- Web UI not verified. Tax year 2024, federal, standard deduction only.
- AOC (education credit) is `$0` as in Direct File (DF-BUG-2).
- `docs/site/how-we-built-this.md` (the owner's page) still says 7,790 declarations; the measured count on this commit is 7,981 (`make audit`, 0 high-severity).

## DECISIONS NEEDING THE HUMAN

1. **Spec review**: read `docs/spec-surface.md` (both "Choices to confirm (human)" lists) and the spec
   files `lean/UsTax/Spec/`, `Comparator/Challenge.lean`, `Comparator/Extra.lean`, `Api/Spec.lean`; sign
   off or change them. Also decide which of the 8 whole-return theorems in `comparator.extra.json` become
   main theorems.
2. **Quirk questions** (`docs/quirk-decisions.md`, "Questions for the human"):
   1. DF-BUG-2 (AOC): keep the `$0` stub, or knock out filers who may qualify (needs a new input).
   2. DF-BUG-4 / Q-R1: per-item rounding is reproduced in W-2s, interest and 1099-R but HSA line 2 rounds
      once. Pick one rule.
   3. DF-BUG-10: keep the box-1 cap on unemployment repayment, or follow the instructions.
   4. Q6 / DF-BUG-3: the code knocks out; update CONVENTIONS §8 and the bug table to say so.
   5. Q-R3: double rounding reproduced, or exact.
   6. Q12: reproduce DF's CDCC allocation including the apparent slip, or not.
   7. DF-BUG-13, DF-BUG-23: add unit tests (today only difftest `knownDivergence`).
   8. Inconsistent DF-BUG labels in comments: fix or leave.
   9. Promote DF-BUG statuses from `candidate` to `confirmed`/`fixed`.
3. **LICENSE**: the repository has none. Choose one (for example Apache-2.0, matching Lean and Catala).
4. **Your own docs page**: `docs/site/how-we-built-this.md` is yours to write (sections marked
   `TODO(you)`).

Decided earlier: Catala -> Lean option (c) (#8); statute beats Direct File (2026-11-01); no TLS in the
critical path, plain HTTP on localhost via `Std.Http`, body cap 256 KiB; Comparator on Linux via Apple
`container`; conflict policy for overlapping Catala exceptions (none occur: one definition per variable).

## Submission checklist (deadline 2026-11-01 16:30)

- [x] `make install && make run` targets exist; `make install` skips Catala
- [ ] Fresh-clone `make install && make run` passes (in progress)
- [x] Comparator: `make comparator` (9) and `make comparator-extra` (31) PASS on 2026-11-01
- [x] `make audit` PASS (PR #156 tree: 7,981 declarations, 0 high-severity)
- [x] Difftests green (Catala 5,360/5,360; Lean 5,360 and 3,105; re-run Catala 2026-11-01)
- [x] `make test-server` 46/0/1
- [x] README: what is proved / verified / tested / trusted; trusted base; not verified (#59, #71)
- [x] Write-up `docs/writeup.md` final, no `TODO(final)` left
- [x] Demo script `scripts/demo.md`, screenshots `docs/screenshots/`
- [ ] Human spec review of `docs/spec-surface.md`
- [ ] LICENSE
- [ ] `docs/site/how-we-built-this.md` (human)
- [ ] Final green CI run on `main`

## Process notes

- Merge guard (after the #143 incident, where a stale-base squash deleted merged work; reverted and
  re-applied): before every merge, `git diff --diff-filter=D --name-only origin/main...<branch>` must be
  empty and the branch must contain origin/main. Force-push only with `--force-with-lease`.
- Local `sources/reference-catala/` (gitignored) breaks `make check` in the main checkout (clerk finds
  it); move it aside when running there.
- Run Comparator jobs one at a time (memory).

## Findings

- scope.md says 322 scenarios; there are 161. scope.md §5.2 "Rev Proc .24" cite is actually §.24 of
  Rev. Proc. 2023-34 (not 2024-40); §11 item 5 only description wrong; item 1 matches the 1040
  instructions. scope.md not edited (human-owned).
- Oracle uses the prebuilt Scala.js bundle; 157/161 `flowIsKnockedOut` are Placeholder false.
- `make forensics` writes its dump, then the upstream tool crashes (`judging` ReferenceError). The dump
  is valid.
- Comparator/lake check are Linux only; never use native_decide.
