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
