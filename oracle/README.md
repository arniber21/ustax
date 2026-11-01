# Oracle: Direct File reference-engine values

`oracle/facts.csv` holds `scenario,path,value,completeness` rows produced by running Direct File's own
fact-graph engine on its backend test scenarios. It is the differential-testing oracle for the Catala
(and later Lean) formalization. Nothing here is hand-written; every value comes from the engine.

## Regenerate

```
export DIRECT_FILE=/path/to/direct-file/direct-file   # dir containing backend/ and df-client/
make oracle                                            # = cd oracle && npm ci && node generate.mjs
```

Output is deterministic (two consecutive runs gave identical SHA-256). Also written:
`oracle/facts.summary.json` (counts below).

### Requirements

- node >= 18 (developed on v26.9.0) and npm. One npm dependency, `fast-xml-parser@4.5.7` (locked;
  installed with `--ignore-scripts`). No Java, sbt or Scala needed.
- A checkout of the Direct File repo (generated against commit `e365f9f43446010af36cccf7edecc52953c00fe9`).
  If `DIRECT_FILE` is unset, the script looks for `../../direct-file/direct-file` relative to `oracle/`.

### How it works (route chosen: JS bundle + node)

The sbt route (`fact-graph-scala`, Java 21, Scala 3.3.3, ScalaJS 1.13.2) was not attempted. This machine has
sbt and a Java 21 JDK (GraalVM CE 21.0.2, not the default Java 25), but the Scala library has no XML loader
(the backend builds the dictionary in Java), so a JVM route would need extra glue plus a Scala toolchain download.
Instead `generate.mjs` loads the **pre-built Scala.js bundle committed in the Direct File repo**
(`df-client/js-factgraph-scala/src/main.js`, CommonJS, linker 1.13.2, non-production build) and drives it the same
way `df-client-app`'s `InterceptingFactGraph` does:
`tax/*.xml` -> digest (`DigestNodeWrapper`) -> `FactDictionaryFactory.fromConfig` -> `JSPersister.create(scenario facts)`
-> `GraphFactory.apply` -> `graph.get(path)`. The XML-to-digest step is a JS port of
`generate-src/readRawFacts.ts` + `processFactsToDigestWrapper.ts` (tax year `2024`). The vitest harness itself
(`setupFactGraph.ts`) is not run, because it needs the whole df-client app and a generated TS dictionary;
its extra setup (inventing filers/email/TIN when `/primaryFiler` is missing) is not applied, so the
engine sees exactly the scenario facts.

Caveat: I did not rebuild `main.js` from the Scala sources, so I rely on the committed bundle being in sync with
`fact-graph-scala`. The spot-check below is an independent check that it is consistent with the filed PDFs.

## CSV format

- `scenario`: scenario file name without `.json`.
- `path`: fact path. Input rows keep their concrete path (`/filers/#<uuid>/firstName`).
- `value`: engine value as a string (`Dollar` prints with 2 decimals, e.g. `2777.00`). Empty when Incomplete.
  Input rows are flattened: Enum -> option(s) joined by `;`, Day -> date, Collection -> item ids joined by `;`,
  Tin -> `AAA-GG-SSSS`, Ein -> `PP-SSSSSSS`, other structured items (Address, BankAccount, phone, ...) -> compact JSON.
- `completeness`: `Complete`, `Placeholder` (engine returned its declared placeholder default; not confirmed
  by inputs) or `Incomplete` (no value). All scenario input rows are `Complete`.

Rows per scenario: every writable fact in the scenario (inputs), the 16 required outputs
(`/agi /totalIncome /taxableIncome /totalTax /totalPayments /overpayment /balanceDue /standardDeduction
/earnedIncomeCredit /totalCtcAndOdc /additionalCtc /cdccTotalCredit /qualifiedSaverCreditAmount /totalEdc
/netPtcAmount /flowIsKnockedOut`), plus 313 further derived facts marked `Export mef="true"` that have no `*` in
their path (excluding the 16 above), plus the non-MeF derived facts of the `EXTRA` list in `generate.mjs`
(append only; issue #20 added 14 filing-status facts such as `/eligibleForHoh` and `/recommendedFilingStatus`).
Total 79,463 rows, 5.7 MB, so the CSV is committed directly.

`oracle/fact_graphs.csv` (`make oracle-fact-graphs`, issue #20) is the same dump for the 27 filing-status fact
graphs of `direct-file/docs/testing/fact-graphs/` (bare fact graphs, not `{ "facts": ... }` scenarios), produced by
`generate.mjs --scenario-dir <that directory> --out fact_graphs.csv`. 10,720 rows; SHA-256
`63c368c81da2ccdeed8fb1b11dd675ce8cc24c92512fe37dd3501aa3de4522bd`.

Sample:

```
ats-1,/agi,39674.00,Complete
ats-1,/taxableIncome,25074.00,Complete
ats-1,/totalTax,2777.00,Complete
ats-1,/overpayment,4497.00,Complete
ats-1,/netPtcAmount,,Incomplete
ats-1,/flowIsKnockedOut,false,Placeholder
```

SHA-256 of `facts.csv`: `812bf3bd52d15f96c14141c550bbb7c25b9f0a7177271159e6a3bd103071d44c` (before the issue #20
EXTRA rows: `a238501f6b8efcb25012e7a423e4dfa46a4ce748a93759459e182e47e7ef8a00`; those 77,209 rows are unchanged)

## Counts

**The "322 scenarios" in scope.md and issue #6 is wrong.** `backend/src/test/resources/scenarios/` has
**161** scenario files; the other 161 JSON files live in `scenarios/state-api-exported-data-snapshots/`
(`<name>-directFileData.json`, expected state-export payloads, not inputs). 161 + 161 = 322 files. The oracle covers the 161 scenarios.

| Measure | Scenarios |
|---|---|
| Scenarios processed, engine errors | 161, 0 |
| `/agi /totalIncome /taxableIncome /totalTax /totalPayments /overpayment /balanceDue` all `Complete` | 161 |
| `/flowIsKnockedOut` = `true`, Complete (knocked out) | 4 |
| `/flowIsKnockedOut` = `false`, Complete | 0 |
| `/flowIsKnockedOut` = `false`, **Placeholder** (not knocked out, but some knockout input is unanswered) | 157 |
| Core outputs complete and not knocked out | 157 |

Knocked-out scenarios: `1099r-box-2b-total-distribution`, `ats-2-1099r`, `ats-2-1099r-blank-taxable`,
`ats-2-1099r-nonzero-taxable`. Their tax numbers are still computed (the engine does not stop), so for these
four the Direct File numbers are not what a filer would see; a formalization should treat them as out of scope.

Why 0 Complete-false: `/flowIsKnockedOut` is an `Any` over ~110 knockout facts with a placeholder of `false`.
Scenarios are submitted returns that never answered every knockout screen, so the `Any` is never fully Complete
unless one operand is `true`. Treat `Placeholder false` as "not knocked out".

## Hand spot-check against `pdf-expected/en/olf-*.yml` (Form 1040 fields)

Mapping used (TY2024 Form 1040 fields): `f1_54` line 9 total income, `f1_56` line 11 AGI, `f1_57` line 12
standard deduction, `f1_60` line 15 taxable income, `f2_02` line 16 tax, `f2_10` line 24 total tax,
`f2_22` line 33 total payments, `f2_23` line 34 overpayment, `f2_24` line 35a refund,
`f2_16` line 27 EIC, `f2_17`/`dummy.f2_3` line 28 additional CTC, `f2_07`/`f2_04` credits (line 19 CTC/ODC).

| Scenario | Field (PDF value) vs oracle | Result |
|---|---|---|
| `ats-1` | L9 39674.00 / `/totalIncome` 39674.00; L11 39674.00 / `/agi` 39674.00; L12 14600.00 / `/standardDeduction` 14600.00; L15 25074.00 / `/taxableIncome` 25074.00; L24 2777.00 / `/totalTax` 2777.00; L33 7274.00 / `/totalPayments` 7274.00; L34 4497.00 / `/overpayment` 4497.00 | all match |
| `mfj-30k-eitc-ctc-actc` | L9 31444.00; L11 31194.00; L12 30750.00; L15 444.00; L16 tax 44.00 then L19 credit 44.00 so L24 0.00 / `/totalTax` 0.00; L19 44.00 / `/totalCtcAndOdc` 44.00; L27 EIC 3968.00 / `/earnedIncomeCredit` 3968.00; L28 ACTC 1700.00 / `/additionalCtc` 1700.00; L33 8168.00 / `/totalPayments` 8168.00; L34 8168.00 / `/overpayment` 8168.00 | all match |
| `HOH-32k-EITC` | L9/L11 32034.00; L12 23850.00; L15 8184.00; L24 818.00 / `/totalTax` 818.00; L27 2726.00 / `/earnedIncomeCredit` 2726.00; L33 10726.00 / `/totalPayments` 10726.00; L34 9908.00 / `/overpayment` 9908.00 | all match |

No mismatches in these three. The check is by eye from the YAML fields, not automated, and the
field-to-line mapping above is my reading of the form layout (the pdf-expected files carry no line labels).
Matching all 176 PDFs to scenarios is out of scope (issue #6); the file-name map is `olf-<scenario>.yml`
(plus `ero-<scenario>.yml` for some).

## Notes for consumers

- `Placeholder` rows carry the engine's default; do not compare them as confirmed values.
- A formal spec that assumes complete inputs can use the 157 not-knocked-out rows directly.
- `scope.md` section 11 item 10 (Rational to Dollar via Float) can be probed by differential tests against this CSV.
