# Catala to Lean: strategy and trust story (spike, issue #8)

Status: decision proposal, 2026-10-31. Toolchain used: Catala 1.3.0 (`clerk`), Lean 4.35.0 (core only), OCaml 5 via opam `default` switch.

## 1. Recommendation

**Option (c): write the calculator directly in Lean. Catala stays the readable spec, written next to the law, and acts as the test oracle. A three-way differential test (Catala-generated OCaml, Lean, Direct File oracle CSV) closes the gap between them. The Part 3 server calls the Lean calculator, so the proofs are about the code that runs.**

Use a refinement proof where it is cheap. On the pilot scope the spike proved that a line-by-line port of the Catala-generated code equals the readable Lean function for every input (§4.3). That pattern can be reused for a few scopes. It is not required for every module.

Do not choose option (a), a hand port of the generated code: it has the costs of (b) and (c) together and the assurance of neither. Keep option (b), a Catala to Lean translator written as a Catala backend plugin, as a funded stretch goal, not the baseline (§4.2).

**Decisions the human must make** (the orchestrator should raise these):

1. **(c) baseline versus (b) translator.** (c) is about 40 to 85 h for about 15 modules. (b) is about 50 to 80 h before any proof work, and its output has the shape of compiler IR, so proofs need a readable layer anyway (§5). Choosing (c) means the rules.md verification answer is "proofs about the Lean code that runs; its agreement with the Catala spec is established by exhaustive and scenario differential testing, not by proof". Choosing (b) upgrades that to "proofs about a static translation of the Catala code" at the cost of an unverified translator of about 1,000 lines of OCaml.
2. **What the Part 3 server runs.** The recommendation assumes the server calls the compiled Lean calculator. If the server runs the Catala-generated OCaml or Python instead, the Lean proofs become proofs about a model, and the rules.md verification score drops. This is a Part 3 decision that follows from this one.
3. **Treatment of Catala conflicts and empty definitions in Lean** (§3.4). Catala raises `Conflict` or `NoValue` at run time. A Lean `if` chain silently picks one branch. The proposal: every module states, for each exception group with overlapping conditions, either a disjointness lemma or uses the `handleExceptions` combinator. The human should confirm this is the policy.

## 2. Upstream status (option d)

- **No Lean backend exists in Catala 1.3.0** (backends: c, java, ocaml, python; IR dumps: scopelang, dcalc, lcalc, scalc). A search of `CatalaLang/catala` issues, PRs and branches on 2026-10-31 found no Lean backend work.
- Related upstream items:
  - Open PR [CatalaLang/catala#1088](https://github.com/CatalaLang/catala/pull/1088) (external contributor, not merged; a maintainer said on the PR that they want to discuss it first) adds `catala dcalc --output-format=json`. Its stated motivation is "differential testing against external oracles (e.g. formal ports such as a Lean 4 runtime)". If it merges, it would give option (b) a stable machine-readable IR. It is not in 1.3.0.
  - Branch `coq_backend` (last commit 2024-01-08, never merged): `compiler/dcalc/to_coq.ml`, 526 lines, prints dcalc as a *deep embedding* (Coq terms of a default-calculus AST). It shows the size of a printer, but it is stale against the 1.3.0 AST.
  - Catala's own formal work (the 2021 paper) proves the dcalc to lcalc compilation correct in F\*, about 3,500 lines. It is not Lean.
  - [arnavdandu/catala-lean](https://github.com/arnavdandu/catala-lean) and its fork ludovicc/catala-lean: a Lean (Mathlib) formalization of a *core* default calculus with only integers, booleans and pairs, plus a small-step semantics and a Python differential harness. It has no money, decimal, structs or enums, and it cannot run our programs. It is not usable here.
- **Conclusion:** nothing upstream reduces the cost of (a), (b) or (c) within this project's time frame. Re-check PR #1088 before starting (b).

## 3. Catala runtime semantics Lean must replicate

Verified by reading `sources/reference-catala/catala/runtimes/ocaml/catala_runtime.ml` (1.3.0) and `stdlib/`, and by running the runtime: `docs/spike/ocaml/rt.ml` prints primitive results, and the Lean `#guard`s in `docs/spike/lean/Spike/Runtime.lean` reproduce them.

### 3.1 Numbers

| Catala | Runtime representation | Lean (core) |
|---|---|---|
| `money` | `Z.t`, an integer number of **cents**, unbounded | `Int` cents |
| `decimal` | `Q.t`, an **exact arbitrary-precision rational** (Zarith) | `Rat` (in core since about 4.2x, so no Mathlib or Batteries needed) |
| `integer` | `Z.t`, unbounded | `Int` |

There is no overflow and no floating point anywhere in the calculation path. Floats appear only in printing and in `decimal_of_float`, which we must never use.

### 3.2 Rounding (all half away from zero)

- `round q = sgn(q) * floor(|q| + 1/2)`, implemented as `fdiv (2n + d) (2d)` on `|q|`. Checked: `round(5/2) = 3`, `round(-1/2) = -1`, `round(-5/2) = -3`.
- `money * decimal` (`o_mult_mon_rat`): exact product in cents, then `round` to the **nearest cent**. Checked: 1 cent * 1/2 = 1 cent; -1 cent * 1/2 = -1 cent. Every `money * rate` in a Catala source is therefore a cent-rounding point.
- `money * integer`: goes through `decimal`, so it is exact.
- `money / decimal`, `money / integer`: multiply by the inverse, then round to the cent ($1.00 / 3 = 33 cents). `money / money` returns a **decimal** with no rounding. Division by zero is the `DivisionByZero` error.
- `round of money` (`money_round`): to the nearest **dollar**, half away from zero ($12.50 gives $13; -$12.50 gives -$13; -$12.49 gives -$12).
- `integer of decimal` (`Q.to_bigint`): **truncates toward zero** (-7/2 gives -3), unlike `round`. It is used for "floor to a multiple of $50" when the value is positive.
- `money of decimal`: rounds to the nearest cent, half away from zero.
- Stdlib `Money.*` is Catala code compiled with the program: `min`, `max`, `positive` (floor at $0), `truncate`, `round_by_excess`, `round_by_default`, `in_excess`, `in_default`, `sum` (a fold from $0). `Money.round_to_decimal` is an OCaml **external** (`stdlib/ocaml/money_internal.ml`). For `n <= 0` it computes `money_round (m / 10^-n) * 10^-n` with `Z.div` (truncation) on cents. It is exact for the "round to the next $1,000" pattern, but a Lean port must copy it literally, not "round to 10^k".
- The Lean model in the spike computes `round` with Lean's `/` (Euclidean division) instead of `Int.fdiv`. The divisor `2 * den` is positive, so the two agree, and `omega` understands `/` but not `fdiv` (found while proving; §4.3).

**Consequences the spike measured** (`docs/spike/lean/Probe.lean`):
- If the per-slice cent rounding is dropped (exact sum, then round to the dollar), single-filer tax differs on **971 of 200,000** cent values in $100,000 to $102,000.
- If half-to-even replaces half-away-from-zero at the dollar step, single-filer tax differs on **30,700 of 100,000** dollar values below $100,000. Tax Table midpoints often produce exactly $x.50.

Rounding placement is therefore not a detail. The Lean code must round where Catala rounds, and the differential test catches it when it does not.

### 3.3 Lists

`list of T` is an OCaml `array`. The operations are `map`, `map2` (lists of different length raise `NotSameLength`), `filter`, `fold` (`combine all ... initially`), `reduce` (an empty list gives `Absent`, which the caller handles or turns into an error), `find` (first match), `sort_asc` and `sort_desc` (stable), `length`, `concat`, and `ArrayAccess`. In Lean, `List` with `map`, `foldl`, `filter`, `find?` and `mergeSort` (stable) is enough. Note that `Money.sum` folds from the left starting at $0. Order does not matter for `Int`, but it does for the per-element cent rounding, which happens *inside* the `map`.

### 3.4 Default logic: exceptions, conflicts, empty

- Each scope variable compiles to an `Optional` (`Absent | Present (value, position)`). An exception group is evaluated by `handle_exceptions`: no exception present means the base rule applies, if its condition holds. Exactly one present means it wins. **Two or more present raise `Conflict`** at run time.
- A chain of single exceptions (`label a ... exception a` nested), as in the spike's Tax Table key, compiles to nested `match ... Absent -> next level`. No conflict is possible, so it is exactly an `if/else if` chain in priority order (seen in `out/rate.ml` and `rate.scalc`).
- A variable with no applicable rule raises `NoValue`. Assertions raise `AssertionFailed`. A `condition` variable defaults to `false`.
- In Lean under (c): write the priority chain as `if` and state as a lemma that conditions in the same group are disjoint, or use the spike's `handleExceptions` (`Except Error (Option α)`) where the Catala source really has sibling exceptions. Totality: a Lean function always returns a value where Catala would raise `NoValue`, so the differential driver must record Catala errors as outcomes (not crash), and the comparison treats "Catala error" as a mismatch to investigate.

### 3.5 Other

- Dates and durations (`dates_calc`) matter for ages (65 or older, EITC 25 to 64, born-on-January-1 rules). If modules use `date` arithmetic, Lean needs a port of the parts used (`add_dates` with rounding mode, `sub_dates`, `compare_periods`, which errors on ambiguous month or day comparison). That costs about 4 to 8 h if needed. Preferred: compute ages as integers at the input boundary, so dates stay out of the proved core.
- Positions (`code_location`), trace and JSON embedding (`Value.*`) are not semantics. Drop them.

## 4. Options, prototyped

The toy is `docs/spike/catala/spike_rate.catala_en`: the TY2024 rate schedule for all five filing statuses, with the Tax Table midpoint key from scope.md §2.1. It exercises an enum `match`, a `list of Bracket` literal, `map each ... among ... to` with `Money.sum`, `money * decimal` cent rounding, `round of` dollar rounding, `integer of (money / money)` truncation, and a three-level `label`/`exception` tree. The four `#[test]` assertions pass with `clerk test`; the Single $50,000 case gives $6,059, which matches the 2024 Tax Table.

Generated artifact sizes for this 90-line Catala file: OCaml 348 lines (plus a 49-line `.mli`), Python 229, Java 357, C 550 (plus a 59-line `.h`), scalc 145, lcalc 147, dcalc 188.

### 4.1 Option (a): hand-port the generated OCaml or scalc to Lean

Prototype: `docs/spike/lean/Spike/RateA.lean` (91 lines), a line-by-line port of `out/rate.ml`, built on `Spike/Runtime.lean` (93 lines: `round`, `mulMonRat`, `divMonMon`, `intOfRat`, `roundMoney`, `Money.*`, `handleExceptions`, `default`, `errorOnEmpty`). Effort: about 30 minutes for the toy, plus about 1 h for the runtime.

- **Shape.** The code follows the IR: an `Option` per exception level, `Except Error` for `DivisionByZero` and `NoValue`, inlined bracket literals. The scalc dump is the easiest IR to read for porting (imperative, but every default is explicit). The OCaml output is the easiest to port mechanically (it is already functional).
- **Cost for about 15 modules.** Runtime 10 to 12 h. Each real module generates about 500 to 2,000 lines of OCaml, so a careful port is about 4 to 8 h per module: **70 to 130 h**, repeated for every Catala change. Every human transcription is a new trusted step that cannot be regenerated.
- **Trusted.** The person or model doing the port, the Lean runtime model, the Catala front end, and the OCaml backend (only as the test oracle).
- **Verdict.** Not recommended. It is the worst trade: IR-shaped code that is hard to prove things about, *and* an unrepeatable manual translation.

### 4.2 Option (b): a Catala to Lean translator over lcalc (or scalc)

Prototype: `docs/spike/plugin/lean_spike.ml` (about 100 lines), a **Catala backend plugin** built with `dune` against the installed `catala.driver` library and loaded with `catala lean-spike --plugin-dir=...`. It calls `Driver.Passes.lcalc`, emits Lean `inductive` and `structure` declarations for every enum and struct, and prints a histogram of the lcalc nodes the toy uses. It built and ran on the first attempt after two small API fixes. So the plugin route is real and needs no Catala fork. Build and run it from a copy outside the repo, because dune writes `_build/` next to the sources.

What a full translator has to handle (from the histogram and `compiler/lcalc/to_ocaml.ml`, 1,032 lines, the closest model):
- **Expressions:** `ELit`, `EVar`, `EAbs`/`EApp` (lets are `EApp (EAbs ...)`), `EStruct`/`EStructAccess`, `EInj`/`EMatch`, `EIfThenElse`, `EArray`, `ETuple`/`ETupleAccess`, `EExternal` (cross-module references), `EAppOp` (about 60 runtime operators such as `o_mult_mon_rat`, `o_map`, `o_toint_rat`), and `EFatalError_pos`.
- **Errors.** OCaml uses `raise`. Lean needs a monadic translation (everything in `Except Error`), or `panic!`, which is unprovable. This is the largest design item and makes the output harder to prove things about.
- **Names.** Catala identifiers can collide with Lean keywords (the stdlib struct `Period` has a field `end`, which needs `«end»`). The `Optional` enum is polymorphic and needs a type parameter. Modules map to Lean namespaces.
- **Stdlib.** `Money_en`, `Date_en` and the others are Catala code and translate with the program. The OCaml externals (`Money_internal`, `Decimal_internal`, `Date_internal`, `List_internal`, `Period_internal`) must be hand-written in Lean.
- **Representation.** lcalc dumps are pretty-printed text, not machine-readable, so (b) has to be a plugin over the typed AST, unless PR #1088 (dcalc JSON) lands.

Cost for about 15 modules: translator plugin 30 to 50 h, Lean runtime 12 to 16 h (plus 4 to 8 h for dates if needed), about 0.5 to 1 h per module to regenerate and fix: **50 to 80 h before any proof**. Proofs then face the IR shape (see §4.3). In practice you write the readable Lean anyway and prove a refinement. So **(b) for proof purposes costs (c) plus 50 to 80 h plus 2 to 6 h per module of refinement proof**.

- **Trusted.** The translator (unverified OCaml, about 1,000 lines), Catala's front end and its passes down to lcalc (proved correct on paper in F\* for the core calculus, not for the 1.3.0 implementation), and the hand-written Lean runtime. The differential test against Catala's own OCaml backend checks the translator plus runtime on the tested inputs. That OCaml backend shares the front end, so the test does not check the front end.
- **Version risk.** The plugin uses internal compiler APIs (GADT ASTs, `Driver.Passes` signatures), which change between Catala releases. Pin Catala 1.3.0 (see `catala.opam.locked`).

### 4.3 Option (c): the calculator written in Lean, with Catala as spec and oracle

Prototype: `docs/spike/lean/Spike/RateC.lean` (70 lines). It has total functions, no `Option` or `Except`, the exception tree flattened into an `if` chain, and it reuses the runtime's `mulMonRat` and `roundMoney` so money semantics match Catala exactly. Effort: about 20 minutes. The two lemmas `tableKey_nonneg` and `tableKey_mono` (the "monotone bucket function" step of issue #64) close with `unfold; repeat' split; all_goals omega`.

**Refinement probe** (`docs/spike/lean/Refine.lean`, 121 lines, about 1.5 h): `theorem rateA_eq_rateC : RateA.tax fs ti = some (RateC.tax (fsMap fs) ti)` holds for **all** five filing statuses and **all** integer cent inputs. The IR-shaped port never errors, and it equals the readable function. `#print axioms` shows only `propext`, `Classical.choice` and `Quot.sound`. Reusable bridge lemmas, proved in core with no Mathlib: `intOfRat ((a:Rat)/(c:Rat)) = a / c` for `a, c > 0`, `round (z : Rat) = z`, and `ratLit` (rational literal equality through `divInt`).

Friction found (feeds #39, #64):
- `decide` cannot prove `(12 : Rat) / 100 = 3/25`: kernel reduction gets stuck on `Rat.inv`/`Rat.mul` normalization. Use the `ratLit` lemma (cross-multiply on `Int`). Never use `native_decide`: it adds an axiom that Comparator will reject.
- `omega` ignores hypotheses stated on `abbrev Money := Int`. Lemmas about money must be stated on `Int`, or `Money` must be a `structure` with its own lemma set. Decide this in #39.
- `omega` does not understand `Int.fdiv`. Model OCaml's `Z.fdiv` by positive divisors as `/`.

Cost for about 15 modules: runtime (money, rounding, list helpers, conflict combinator) 6 to 10 h, then 2 to 5 h per module to write from the Catala source with `#guard` copies of the Catala unit tests: **about 40 to 85 h**. Each optional refinement proof against an IR-shaped port costs 2 to 6 h per module and needs that port written first (option (a) for that module).

- **Trusted.** Only the Lean kernel, and the statements and definitions on the spec surface (CLAUDE.md §4). The Catala-to-Lean agreement is **not** proved. It is established by testing (§6). Catala, its OCaml backend and the Direct File oracle become test oracles, not trusted components of the shipped calculator.

### 4.4 Differential test: run on the toy

- OCaml side: `docs/spike/ocaml/driver.ml`, linked with `ocamlfind` against `catala.runtime_ocaml`, the clerk-built stdlib objects in `_build/libcatala/ocaml/*.cmx` (link order: List before Date) and the generated module. It prints `status,ti_cents,tax_cents`.
- Lean side: `docs/spike/lean/Main.lean` prints the same CSV for `RateA` or `RateC`. Compare with `cmp`.
- **Results (all byte-identical: OCaml = Lean (a) = Lean (c)):**
  - every cent from -$5 to $10,000, five statuses: 5,002,505 rows;
  - every dollar from -$5 to $1,000,000, five statuses: 5,000,030 rows (the issue #41 acceptance range);
  - every 7 cents from -$5 to $150,000, five statuses: 10,714,645 rows. This range covers the bracket edges where sub-cent products appear.
- Speed: OCaml about 2 s and Lean (`Rat`) about 8 s per 5 M rows. Exhaustive sweeps of single-variable scopes are cheap. Multi-input scopes need scenario and random sampling instead.

## 5. Comparison

| | (a) hand port of IR | (b) translator plugin | (c) Lean-native, Catala as oracle |
|---|---|---|---|
| Up-front | runtime 10-12 h | plugin 30-50 h + runtime 12-24 h | runtime 6-10 h |
| Per module (about 15) | 4-8 h, redone on every Catala change | 0.5-1 h regenerate | 2-5 h write + tests |
| Total before proofs | 70-130 h | 50-80 h | 40-85 h |
| Code shape for proofs | IR (Option, Except, inlined literals): poor | IR: poor, so a readable layer and refinement are needed | readable, total: good (`omega` closes the monotone key in 3 lines) |
| Extra trusted base | the hand transcription | translator (about 1,000 lines OCaml) + Catala passes + Lean runtime | none beyond the kernel and the spec surface |
| Catala-Lean link | test only | static translation + test | test only (or optional refinement proof per scope) |
| rules.md verification axis | "hand-written model of the code" | "static translation of the code" (best for Catala-as-code) | "proofs about the code itself" if the server runs Lean; Catala is the spec |
| Comparator | generated or ported defs in the challenge | generated defs in the challenge; regenerating changes the challenge | Lean defs in the challenge; stable |
| Main risk | silent transcription bugs, drift | schedule (largest up-front cost), Catala API churn | Lean and Catala drift, caught only by tests |

## 6. How the differential test closes the gap (option c)

1. **Lean vs Catala** (`make lean-difftest`, #42): the same inputs go through the Catala-generated OCaml (built by `clerk`, linked into a small OCaml driver as in the spike) and the Lean executable. All outputs are compared, and Catala run-time errors (`NoValue`, `Conflict`, ...) are recorded as outcomes. Single-input scopes (rate schedule, EITC tables) are swept exhaustively at cent or dollar resolution. Multi-input scopes are covered by every oracle scenario plus random inputs from a generator, not a filter (CLAUDE.md §5).
2. **Catala vs Direct File** (#6, #7): the oracle CSV. Combined with step 1, this gives the three-way agreement Part 2 already plans.
3. **What it does not close.** Inputs that are neither enumerated nor sampled. For the rate schedule, the spike shows the residual can be closed by proof (`rateA_eq_rateC`). For other modules the residual is what remains of the trust in the test-based link, and the README must say so.
4. **Sensitivity.** The spike's rounding variants (§3.2) would have been caught (thousands of mismatches each). The flattened exception chain would *not* be caught if a conflict-raising input is never generated, which is why §1 item 3 asks for disjointness lemmas.

## 7. Comparator and the audit (#70)

- `lake comparator` exists in the pinned Lean 4.35.0 (checked with `lake comparator --help`). It reads `comparator.json` (`challenge_module`, `solution_module`, `theorem_names`, `permitted_axioms`, optional `definition_names` holes), checks that the named solution theorems prove exactly the challenge statements, that they use only permitted axioms, and that the kernel accepts them. It sandboxes the build with **`bwrap` (bubblewrap), so it is Linux only**. On this macOS machine it cannot run, so #70 needs a Linux CI job or VM.
- Under (c), the challenge module imports the calculator definitions and the spec (`Spec.lean`, #63) and states the main theorems with `sorry`. The solution proves them. The calculator definitions are therefore part of the trusted statement surface: any change to calculator code changes the challenge. This is intended. List them with `#spec_surface`.
- Permitted axioms: `propext`, `Quot.sound`, `Classical.choice`. That rules out `native_decide` (`Lean.ofReduceBool`), which the spike showed is unnecessary for `Rat` literals.

## 8. Required changes to Part 2 issues

- **#9 (Lean setup):** core only. `Rat`, `Int`, `omega` and `List.mergeSort` are in core 4.35; no Batteries or Mathlib was needed for the spike, including the refinement proof. Pin `leanprover/lean4:v4.35.0` (it has `lake comparator` and `lake check`).
- **#39 (Money library):** rename `roundDollar (half-up)` to **half away from zero** (it matches Catala; it equals Direct File `HALF_UP` on all signs). Add `mulRate : Int -> Rat -> Int` (exact product, round to the cent: **the** Catala rounding point), `divRate`, `intOfRat` (truncation toward zero), `Money.truncate`, `round_by_excess`, `round_by_default`, and a literal port of `Money.round_to_decimal`. Add `#guard`s copied from `docs/spike/ocaml/rt.ml` output. Decide `Money` as plain `Int` versus `structure` (an `abbrev` blocks `omega`). Include the `ratLit`, `intOfRat_div` and `round_intCast` lemmas from `docs/spike/lean/Refine.lean`.
- **#40 (Runtime):** shrinks to small (S). Under (c) there is no `Optional`, positions or closure plumbing: only list helpers, `handleExceptions` for real sibling-exception groups, and (if needed) the date subset. Acceptance item "Default-calculus conflict/empty cases have a documented Lean behavior" stays, as the policy in §1 item 3.
- **#41 (Pilot):** output is `lean/Ustax/Rate.lean` written directly from the Catala source (not a port of generated code). The spike already shows the 0 to 1,000,000 sweep is cheap (about 8 s). Add, as optional, the refinement theorem against a mechanical port, reusing `docs/spike/lean/Refine.lean`. `docs/porting.md` describes "write from the Catala source" plus rounding placement.
- **#42 (Lean difftest):** the OCaml side links the clerk-built stdlib `.cmx` files (see `docs/spike/ocaml/driver.ml`). It must record Catala errors as outcomes. The Lean side is a `lean_exe` that prints CSV (the spike's `Main.lean`).
- **#43 to #48 (module ports):** "Port" means "write in Lean from the Catala module". Each adds acceptance: (1) every Catala `#[test]` as a `#guard`; (2) for each exception group with overlapping conditions, a disjointness lemma or use of `handleExceptions`; (3) money operations placed where Catala rounds. Sizes hold at M. Retitle from "Port ..." to "Lean implementation of ..." if desired.
- **#63 (Spec surface):** the calculator definitions are on the surface (they are the code being proved); `#spec_surface` output must include them.
- **#64:** the monotone bucket lemma (`tableKey_mono`) is already shown cheap. The remaining work is monotonicity of the bracket sum with per-slice cent rounding (each slice `mulMonRat (positive (min x u - l)) r` is monotone in `x`, and `roundMoney` is monotone).
- **#70 (Comparator):** needs a Linux runner (bwrap). The challenge module imports calculator definitions. Forbid `native_decide`.
- **README (trust list, CLAUDE.md §7):** the Lean kernel; the spec surface; for the Catala link, "differential testing against Catala 1.3.0's OCaml backend, plus a refinement proof for the rate schedule". If (b) is later adopted, add the translator plugin and the Catala front end.
- **New optional issue, if the human wants (b):** "Catala to Lean translator plugin (lcalc)", about 50 to 80 h. It depends on #40. Start from `docs/spike/plugin/lean_spike.ml` and `compiler/lcalc/to_ocaml.ml`, and re-check upstream PR #1088 first.

## 9. Reproducing the spike

Run everything in a scratch directory outside the repo (CLAUDE.md §3; `dune` and `lake` write build directories). Commands assume `export PATH=$HOME/.opam/default/bin:$PATH OPAM_SWITCH_PREFIX=$HOME/.opam/default`.

1. Copy `docs/spike/catala/` to `<scratch>/catala/`, then run `clerk test`. Generate code with `catala ocaml catala/spike_rate.catala_en --stdlib=_build/libcatala -o out/spike_rate.ml`; `catala scalc|lcalc|dcalc ...` print the IRs.
2. OCaml driver: compile `docs/spike/ocaml/driver.ml` with `ocamlfind ocamlopt -package catala.runtime_ocaml,zarith -linkpkg -I _build/libcatala/ocaml <stdlib .cmx in dependency order: List_internal List_en Date_internal Date_en Duration_en MonthYear_en Period_internal Period_en Money_internal Money_en Integer_en Decimal_internal Decimal_en Stdlib_en> Spike_rate.mli Spike_rate.ml driver.ml`. Then run `./driver STEP_CENTS MAX_CENTS`.
3. Lean: copy `docs/spike/lean/` to scratch, run `lake build`, then `.lake/build/bin/spike a|c STEP MAX`. Run `lake env lean Refine.lean` (the refinement proof and `#print axioms`) and `lake env lean Probe.lean` (rounding-variant counts).
4. Plugin: copy `docs/spike/plugin/` to scratch, run `dune build ./lean_spike.cmxs`, then `catala lean-spike --plugin-dir=_build/default <file> --stdlib=... -o -`.
