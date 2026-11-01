# Differential tests: Catala vs the Direct File oracle

`make difftest SCOPE=<name>` (default `smoke`; `SCOPE=all` runs every mapping; `ARGS=--verbose` lists each
fact check; `ARGS="--scenario ats-1"` runs one scenario) feeds each oracle scenario's inputs to a Catala scope
and compares every mapped output with `oracle/facts.csv`. Needs node >= 18 and `clerk` on `PATH`
(`export PATH=$HOME/.opam/default/bin:$PATH`). `make difftest-selftest` unit-tests the runner itself.
Exit status is 1 if any fact check fails or errors.

## How it works

- **Scenario inputs come from the oracle CSV**, not the scenario JSON. `facts.csv` already contains every
  writable fact of each scenario, flattened (Dollar `15205.00`, Enum options joined by `;`, Collection item ids
  joined by `;`, item facts at `/formW2s/#<uuid>/writableWages`). This keeps the runner independent of a
  Direct File checkout. Inputs and expected outputs are both rows of the same file; a mapping names which is which.
- **Catala input is JSON.** The runner writes `_build/difftest/<name>/<scenario>.input.json` (kept for
  reproducing) and runs `clerk run -s <Scope> --input=<file> <catala file>`. Verified against Catala 1.3.0:
  `catala json-schema -s <Scope> <file>` prints the accepted input/output schema (money may be a JSON number,
  struct = object, list = array). `clerk run` is used rather than `catala interpret` because it builds the stdlib.
  `catala interpret` has no JSON output option, so outputs are parsed from the `[RESULT]` block
  (`name = value`; money `$39,674.00`, bool, int, enum name). Structured outputs (structs, lists) are not parsed:
  map each scalar field to its own `output` variable.
- **Exclusions, honest counts.** A scenario is skipped when the oracle has `/flowIsKnockedOut = true`
  (4 of 161; `oracle/README.md`). `flowIsKnockedOut = false` is always `Placeholder` (157 scenarios) and means
  "not knocked out", so those run. A mapping's `appliesTo(facts)` may also skip scenarios the module does not
  cover, returning a reason string; they are listed, never silently dropped. Only `Complete` oracle rows are
  compared; `Incomplete`/`Placeholder` rows are counted as `unchecked`, never as pass. The report prints scenarios
  total, skipped (knocked out / outside module, with names), scenarios all-pass, scenarios with failures,
  and fact-check counts pass/fail/error/unchecked.
- **Failure output** names scenario, fact path, expected, actual, plus a `clerk run` line to reproduce:
  `FAIL scenario=ticket-12386 path=/wages expected=60002.00 actual=60001.16`.
- Money is compared as exact integer cents. `DIFFTEST_PERTURB=1` adds $1 to every money output, a negative
  control proving the comparison can fail.

## Adding a module (the only thing a module issue needs to do)

Create `difftest/mappings/<name>.mjs` (copy `smoke.mjs`):

```js
import { listFromCollection, scalar } from '../lib.mjs';
export default {
  name: 'wages', scope: 'W2Wages', file: 'catala/wages.catala_en',
  appliesTo: (facts) => true,                       // or a reason string to skip a scenario
  inputs: {                                         // Catala input variable -> f(facts) -> JSON value
    w2_box1_wages: listFromCollection('/formW2s', 'writableWages', { type: 'money', missing: '0' }),
    some_flag: scalar('/someBoolFact', { type: 'bool', missing: 'false' }),
  },
  outputs: [{ oracle: '/wages', catala: 'line_1a', type: 'money' }],   // money | int | bool | string
};
```

Helpers in `difftest/lib.mjs`: `listFromCollection(collectionPath, field, {type, missing})` (a Catala `list of T`,
one element per collection item; `missing: null` drops items lacking the fact), `scalar(path, {type, missing})`.
Any other input is just a function `facts => json` (`facts` is `Map<path, {value, completeness}>` for one
scenario), so enums, structs and lists of structs can be built with ordinary code. `missing` encodes the Direct
File default for an unanswered optional fact; state it from the XML. Add oracle paths for derived facts you
want checked (for example `/agi`, `/totalIncome`); each becomes one fact check per scenario.

## Smoke scope result

`catala/difftest_smoke.catala_en` (scope `SmokeWages`) models only `/wages` (1040 line 1a):
`Round(sum over W-2s of Round(writableWages or 0))`. Result: 157/157 scenarios, 157/157 fact checks pass
(4 knocked out skipped). The first version summed unrounded amounts and failed 5 scenarios
(for example `ticket-12386`, expected 60002.00, actual 60001.16), which is how the per-W-2 `Round` in
`formW2s.xml:1149` was found. Delete the smoke scope and mapping once a real module covers `/wages`.

## Form 1040 scopes (issue #14)

`catala/form_1040.catala_en` (scope `Form1040`) has three mappings over the same inputs
(`difftest/form_1040_inputs.mjs`):

- `form_1040` (strict): scenarios that use only W-2 + interest and no credits, adjustments or other income.
  A scenario is skipped, with a reason naming the later module, when the oracle holds a non-zero value
  for a fact that module computes (the plug-in slots of `Form1040`). Result: 21/21 scenarios, 441/441 checks.
- `form_1040_plugged`: all 157 non-knocked-out scenarios, each plug-in slot filled with the oracle's own
  value (for example `/earnedIncomeCredit`). Tests the 1040 chain wiring everywhere, not the later modules.
- `form_1040_unplugged` (`reportOnly`: excluded from `SCOPE=all`, never sets the exit code): all 157
  scenarios with the slots at `$0`. Its failures are exactly the scenarios the strict scope skips; they go
  away as the later modules are wired in.

## Knockout aggregation (issue #36)

`knockouts_income` (scope `KnockoutsIncome`, `catala/knockouts_income.catala_en`) compares the income/HSA/process
`unsupported_income_or_hsa` with `/flowIsKnockedOut` on all 161 scenarios. Two optional mapping flags support it:
`includeKnockedOut: true` (also run the scenarios the oracle marks knocked out) and, on an output,
`placeholderFalse: true` (a Placeholder `false` is checked as an expected `false`; it means "not knocked out",
`oracle/README.md`). Result: 157/157 checks pass; the 4 knocked-out scenarios are DF-BUG-8 and are listed as
`knownDivergence`. `docs/knockout-inventory.md` lists every `flow.xml` member and its status.

## Lean vs Catala (issue #41, #42 and later Lean modules)

`make lean-difftest SCOPE=<mapping name>` (`node difftest/lean.mjs`) is the three-way comparison Direct File /
Catala / Lean, per scenario and fact, using the same `difftest/mappings/<name>.mjs` as `make difftest`
(one source of truth for the oracle-path -> input/output mapping and for `knownDivergence`). The input JSON is
written once per scenario to `_build/difftest/<name>/<scenario>.input.json`; Catala reads that file
(`clerk run`) and Lean reads the same text (`ustax run <CatalaScope>`, JSON lines, one process). A Lean port
only adds its scope to `UsTax.Cli.scopes`. Counts: three-way agree; lean = catala where the oracle row is not
Complete (never counted as agreement with Direct File) or has no oracle fact (mapping `extraOutputs`);
knownDivergence (Catala differs from Direct File as listed; Lean must equal Catala); failures split into
lean != catala and catala != oracle. Knocked-out scenarios are skipped and listed. Exit status 1 on any failure.
`LEAN_DIFFTEST_PERTURB=1` perturbs every Lean output (negative control: all checks must fail).
The harness and mappings are untrusted test code; JSON for Lean is parsed by `Lean.Json.parse` in `lean/UsTax/Cli.lean`.
`clerk` needs `ninja` on `PATH`. Pilot: `make lean-difftest SCOPE=tax_rates` gives 157 facts three-way agree
(+314 Lean = Catala on the two outputs without an oracle fact).

`make lean-difftest-rates` (`node difftest/lean_rates.mjs`) is the dense extra sweep for the rate schedule: one
`clerk run` of the batch wrapper `catala/tests/difftest_tax_rates_batch.catala_en` (2,402 incomes x 5 statuses,
three outputs each, exact cents), then Lean against the oracle. `--perturb` is its negative control;
`--dense 100 1000000` sweeps every dollar to $1,000,000. The pattern for later modules is in
`lean/README.md`, "Pattern for Lean modules".

## Whole return (issues #38, #48)

`calculator` (scope `Calculator`, `catala/calculator.catala_en`) runs the whole return with every merged module
(including CDCC #28 and filing status #20) plugged into `Form1040` and no oracle value as input: every input is a
writable fact of the scenario (per-person facts from the `/familyAndHousehold/#<uuid>/...` rows of `facts.csv`).
Scenarios that need the unmerged PTC (#32-#34) are skipped as `blocked by #32-#34 (PTC)` (non-zero
`/totalAdditionalTaxesOwed` or `/otherPaymentsAndRefundableCreditsTotal`); `CALC_INCLUDE_BLOCKED=1` runs them
anyway (they then differ only on lines 17/31 and what follows). Result: 151/151 scenarios, 4677/4677 fact checks over
32 paths, 9 known divergences (DF-BUG-3, DF-BUG(23), and `mfs-4300-none`, whose own DF `/isFilingStatusValid` is
false), 6 blocked, 4 knocked out (DF-BUG-8).
