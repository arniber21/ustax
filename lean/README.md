# ustax Lean project

Pinned per CLAUDE.md section 2: `lean-toolchain` = `leanprover/lean4:v4.35.0`
(forensics' known-good toolchain; also provides `lake check`/`lake comparator`).
`lake-manifest.json` is committed; do not run `lake update` except on purpose.

## Dependencies (no Mathlib)
- `batteries` v4.35.0: general-purpose data structures and lemmas beyond core.
- `plausible` v4.35.0: property-based testing of statements before proving them (CLAUDE.md section 5). Tag matches the toolchain exactly.

Both tags match Lean v4.35.0 exactly.

## Build
- Everything: `make lean-build` (or `cd lean && lake build`).
- One module: `cd lean && lake build UsTax.Audit` (or `lake env lean UsTax/Audit.lean`).

## Audit tooling
`UsTax/Audit.lean` provides `#spec_surface thm` (project definitions a theorem's
statement depends on; filter keeps modules rooted at `UsTax`) and
`#audit_axioms thm`. Allowed axioms: `propext`, `Classical.choice`, `Quot.sound`.

`make comparator` runs `lake check` and `lake comparator` in a Linux container
(`docs/comparator.md`). `UsTax/Comparator/Challenge.lean` holds the trusted
statements with intended `sorry` proofs; it is not imported by `UsTax.lean`.

Main theorems (issue #63): the properties are defined in `UsTax/Spec/*.lean`
(no calculator imports), the statements are in `UsTax/Comparator/Challenge.lean`,
the proofs in `UsTax/Proofs/Main.lean` (the comparator solution module), and
statements still to be proved in `UsTax/Comparator/Pending.lean`. The spec
surface of each, reviewed, is `docs/spec-surface.md`.

Tools (elan, bun, ninja, ...) come from devbox: see `docs/devbox.md`.

`make forensics` clones for-all-dev/forensics into `.forensics-tool/` (gitignored)
and runs, from `.forensics-tool/app`, `bun server.ts <abs path to lean/> --dump forensics-out.json`.
The project root is `lakefile.toml`, so module roots are inferred (else `--roots UsTax`).

## Money library (`UsTax/Money*.lean`, issue #39)

Catala 1.3.0 money semantics, ported from `catala_runtime.ml`, the stdlib
`Money` / `Decimal` modules and `catala/rounding.catala_en`.

- `UsTax/Money.lean`: definitions and `#guard` unit tests (tie cases $0.50,
  $1.50, $2.50, -$0.50; the `test_rounding.catala_en` cases; values printed by
  the Catala runtime). Money is a plain `Int` of cents and decimals are core
  `Rat`. There is no `Money` alias, because `omega` ignores hypotheses stated
  on an alias of `Int`. Rounding is ties away from zero (`roundRat`, `mulRate`,
  `roundDollar`). The other definitions are `truncateCents`, `stepwiseMultiply`,
  `roundDollarExact`, the stdlib `min`, `max`, `positive`, `truncate`,
  `roundByExcess`, `roundByDefault`, `sum`, and a literal port of
  `round_to_decimal` (`roundToDecimal`, `roundUpToThousand`).
- `UsTax/Money/Lemmas.lean`: an integer form of each rounding function, for
  `omega` (`roundDollar_eq`, `mulRate_div`, `truncateCents_div`,
  `stepwiseMultiply_eq`, `roundUpToThousand_eq_ceil`). Also monotonicity,
  idempotence, the `min`, `max`, `positive` and `sum` laws, and an axiom audit.
- `UsTax/Money/Props.lean`: plausible property tests. Each lemma statement was
  tested here before it was proved, and the tests run on every build.
- `UsTax/Money/Regression.lean`: reproduces the spike's rounding-placement
  counts (971 of 200,000 cents and 30,700 of 100,000 dollars).

Known differences from Catala, by design: division by zero returns `0` here,
where Catala raises `DivisionByZero`. `roundUpToThousand` is a ceiling only for
nonnegative amounts, which matches Catala.

## Rate schedules, Form 1040 line 16 (`UsTax/TaxRates*.lean`, issue #41)

The first scope implemented in Lean, from `catala/tax_rates.catala_en`
(scope `TentativeTax`). It is the worked example of the pattern below.

- `UsTax/Types.lean`: `FilingStatus` (Catala `Types.FilingStatus`).
- `UsTax/TaxRates.lean`: the code that runs. The four 2024 schedules, the Tax
  Table midpoint (`roundedTaxableIncomeOf`), the marginal and cumulative forms,
  line 16 (`tentativeTaxFor`) and the scope (`tentativeTax : TentativeTaxIn →
  TentativeTaxOut`). Every assertion of `catala/tests/test_tax_rates.catala_en`
  is a `#guard` here.
- `UsTax/TaxRates/Spec.lean`: the readable specification `taxSpec`, written
  as the sources print it (midpoint rows; "$B plus R% of the excess over $X";
  round to the dollar), and the proofs that the code equals it for every
  filing status and every taxable income up to Catala's $1-trillion sentinel
  (`tentativeTaxFor_eq_taxSpec`, `tentativeTaxCumulativeFor_eq_taxSpec`,
  `tentativeTax_spec`). Above the sentinel the Catala marginal form, and so the
  code, stops taxing; an `example` shows they differ there. Also named
  examples and rejected bad outputs (the no-midpoint answer, the Rev. Proc.
  "$191,150" typo, a flat 10%, MFJ ≠ single).
- `UsTax/TaxRates/Lemmas.lean`: `tentativeTaxFor_nonneg` and
  `tentativeTaxFor_mono` (issue #64's key theorems for this scope), for every
  income and status with no hypothesis. The proof is pure arithmetic and does
  not use the bracket amounts, only that every rate is a nonnegative
  percentage, so it stays here (it is not deferred to #64).
- `UsTax/TaxRates/Props.lean`: plausible tests of those statements, run before
  proving and on every build, plus a negative control that must fail.
- `UsTax/TaxRates/TaxTable.lean`: golden test, 16,496 `#guard`ed checks (each
  of the 2,062 printed Tax Table rows at its lowest dollar and its highest
  cent, four columns). The data file `UsTax/TaxRates/TaxTableData.lean` is
  generated by `python3 scripts/gen_lean_tax_table.py` (run from the repository
  root) from `sources/forms-instructions/derived-tax-table-2024.csv`; do not
  edit it by hand.
- `UsTax/Cli.lean` and `Main.lean`: the `ustax` executable (`lake build ustax`).
  `ustax tentative-tax 14999 single` prints `1565.00`; `ustax run TentativeTax`
  reads Catala JSON inputs, one per line, and prints JSON outputs.
- `difftest/lean_rates.mjs` (`node difftest/lean_rates.mjs`, needs `clerk` and
  `ninja` on `PATH`): Lean vs `clerk run` of the Catala scope on 2,402
  incomes × 5 statuses, all three outputs (36,030 checks), and Lean vs the
  Direct File oracle `/tentativeTaxFromTaxableIncome` on all 157 scenarios that
  are not knocked out. `--dense 100 1000000` sweeps every dollar to $1,000,000;
  `--perturb` is the negative control (every check must fail).

Trusted for this scope: the Lean kernel and the definitions on the spec surface
(`#spec_surface UsTax.TaxRates.tentativeTaxFor_eq_taxSpec`: `taxSpec`,
`taxOnIncome`, `taxTableIncome`, `pctOf`, the code itself and the `Money`
primitives it uses). The agreement with Catala is by testing, not proof.

## Calculator spine (issue #43)

Hand-translations (strategy (c)) of four Catala modules; each file has a
Catala <-> Lean name table and every assertion of the matching
`catala/tests/test_*.catala_en` is a `#guard`.

- `UsTax/Params2024.lean`: the `Params_2024` figures the spine uses.
- `UsTax/StandardDeduction.lean`: scopes `Age65DayBeforeBirthday` and
  `StandardDeduction` (Form 1040 line 12). The age rules of
  `catala/filers.catala_en` (`completed_years`, day-before-birthday) are
  `UsTax/Date.lean`.
- `UsTax/FormW2s.lean`: `FormW2Item` and `FormW2s` (lines 1a, 25a, combat pay,
  W-2 knockouts). `FormW2`'s boxes default to `$0` so tests name only what they fill.
- `UsTax/Interest.lean`: `InterestReportFacts` and `Interest` (lines 2a, 2b,
  25b part, Schedule B quirk Q-R1, knockouts).
- `UsTax/Form1040.lean`: scope `Form1040`. The plug-in slots (Catala `context ... equals $0`)
  are `Form1040In` fields **with default `0`/`false`**, so a later module plugs in by
  setting its field. `unsupported` is the Catala knockout union.
- `UsTax/Form1040/Props.lean` (plausible, run before proving) and
  `UsTax/Form1040/Lemmas.lean`: for every input, `overpayment = 0 ∨ balanceDue = 0`
  (refund and balance due exclusive, issue #65), both nonnegative, line 15 nonnegative.
  Axioms: `propext`, `Classical.choice`, `Quot.sound`.
- `UsTax/Cli.lean` registers `Age65DayBeforeBirthday`, `StandardDeduction`, `FormW2s`,
  `Interest`, `Form1040`. `make lean-difftest SCOPE=<standard_deduction|form_w2s|interest|form_1040|form_1040_plugged>`.
  `difftest/mappings/interest.mjs` is new (oracle `/interestIncome`, `/taxExemptInterest`,
  `/requiresScheduleB`; `unsupported` and `total_tax_withheld` are Lean = Catala only).

## Request parsing and validation (`UsTax/Api/*.lean`, issue #51)

Turns an untrusted `POST /calculate` body into a typed `Request`, or the 400
`ErrorResponse` of `docs/api.md`. Total functions only, no `partial`.

- `Json.lean`: strict JSON reader (`parseJson`) and `J.render`. Not
  `Lean.Json.parse`, because the contract needs integer literals told apart
  from `100.0` / `1e2` (money is rejected as `not_integer`), duplicate keys
  rejected and a nesting limit (32). Fuel-based, structural.
- `Types.lean`: the typed request, field for field with `$defs/CalculateRequest`
  (money `Int` cents, absent box 0, absent flag false). `moneyFields` lists every
  money box. Contract 1.2.0 (the filers' extra answers, `filing_answers`, `dependents[]`,
  `credits`, `cdcc`, `premium_tax_credit` with Forms 1095-A, `screening`, `adjustments.hsa`,
  `social_security.federal_tax_withheld`, `filing_details.combat_pay_election_made`,
  `Dependent.deceased`) is typed field for field: an answer with a schema default is a plain
  `Bool` / enum / `Int`, one without is an `Option`, and an absent section is `none`. The 1.2.0
  structures, decoders and `errs`/`Valid`/lemma triples were generated once from
  `api/schema.json` and are checked in as ordinary source (edit them by hand from now on).
- `Decode.lean`: phase 1 (shape: types, enums, required, unknown fields,
  integer-ness), accumulating every problem. Unknown fields are found as "keys
  no accessor read", so a field cannot be dropped silently.
- `Spec.lean`: **the specification**, `Request.Valid` (caps `|n| <= 10^13`,
  `NonNegMoney` vs signed, list sizes 20/4/4 (and 12 for the 1095-A lists), integer ranges
  for months, `SecondaryFiler` only on joint returns (forms, HSA distributions,
  `filers.secondary`), `federal_tax_withheld` no longer than `net_benefits`, real dates),
  with named examples. Review this file. `Request.Valid` is `ValidBase` (schema 1.0
  sections) and `ValidSections` (1.2.0 sections).
- `Validate.lean`: phase 2, `Request.validate : List FieldError` with paths.
- `Lemmas.lean`: `validate_eq_nil_iff` (so `Valid` is decidable),
  `validate_sound`; `Parse.lean`: `parseRequest_sound` (**every accepted request
  is `Valid`**), `parseRequest_error_status` (every failure is a 400), `parseBody`
  (415, 413, UTF-8). This is the seed of issue #69.
- `Response.lean`: `CalculateSuccess`, `CalculateUnsupported`, health and version
  serialisation (`schema_version` 1.2.0). `Reasons.lean`: **generated** by
  `scripts/gen_lean_api_reasons.py` from `api/knockout-reasons.json`, the 104-constructor
  `KnockoutReason` enumeration with code, category and message (`make api-conformance` checks
  the file is current and that `ustax api-reasons` equals the JSON). `Bridge.lean`:
  `toForm1040Input`, and the documented stub `toCalculatorInput` (the seam for the Lean
  `Calculator`, #48; not called by the server).
- `Props.lean` (plausible, before the lemmas) and `Tests.lean` (55 table-driven
  bodies, accepted-value checks, the 400 fixtures byte for byte, responses).
- `ustax api-parse` (stdin lines to `status TAB body`) and
  `scripts/api_conformance.mjs` (`make api-conformance`): the Lean validator vs
  `api/schema.json` via ajv on all examples, fixtures and about 2,100 generated
  mutants (every property of every 1.2.0 section included). Lean must be stricter than the schema only for integer-valued float
  literals, cross-field roles and impossible dates, and the script checks that.

Trusted for this layer: `Json.lean` (it parses untrusted bytes), the
definitions on `#spec_surface UsTax.Api.parseRequest_sound` (`Request.Valid` and
what it mentions), the Lean kernel. The ajv script is untrusted test code.
Not proved: that the JSON reader implements RFC 8259 (tested only), that
`Decode` reads each key into the field of the same name (tested by the
distinct-value checks above), and the 322-scenario oracle conversion (needs a
converter, left to #52).

## HTTP server (`ServerMain.lean`, `UsTax/Api/{Bridge,Calculate}.lean`, issues #52 to #54, #56, #57)

`lake build ustax-server`; `make server` / `make run` (root `Makefile`). Plain HTTP on `Std.Http`
(`docs/lean-http-server.md`), env `PORT` (8080), `HOST` (127.0.0.1), `ALLOW_ORIGIN` (comma separated,
default `http://localhost:5173`). `POST /calculate`, `GET /health`, `GET /version`, `OPTIONS` preflight;
body cap 256 KiB (413), 415 for a non-JSON content type, 404/405, 422 knockouts, 500 generic.

* `Bridge.lean`: `toForm1040Input : Request → r.Valid → Form1040In`, the one place that knows both
  vocabularies. Wired: filing status, W-2s (boxes 1 to 13 incl. box 12), 1099-INT, blind / 65 / claimed
  flags, `filing_details`. `unwiredSections` lists what validates but is not read (1099-G, 1099-MISC,
  1099-R, SSA-1099, educator and student loan adjustments, estimated payments, and the 1.2.0 sections:
  the filers' extra answers, `filing_answers`, `dependents`, `credits`, `cdcc`, `premium_tax_credit`,
  `screening`, `adjustments.hsa`, `combat_pay_election_made`); the 200 response then carries `warnings`
  with code `section_not_used`, and `field_superseded` for the five schema 1.0 `filing_details` fields
  that 1.2.0 derives (`docs/api.md` "Warnings"). `toCalculatorInput` is a typed, documented stub for the
  whole-return Lean `Calculator` (#48); the full mapping is not written.
* `Calculate.lean`: `calculate : String → Reply`, the whole endpoint minus sockets, with `#guard`s for the
  $50,000 example, warnings, a knockout and a 400. No tax logic: it calls `Form1040.form1040` and reads
  the knockout reasons from the same sub-scopes (`FormW2s.formW2s`, `Interest.interest`). Until the
  `Calculator` scope (#38) exists, `knockoutReasons` is the list of flags `form1040` itself uses plus
  `HasForeignAccountsOrTrusts` (which `form1040` only passes down); a disagreement with
  `Form1040Out.unsupported` is `Reply.fault` (HTTP 500).
* Tests: `make test-server` starts the server and runs `scripts/server_integration.mjs` (every
  `api/fixtures` entry, error classes, CORS, warnings; the six fixtures whose answer needs the
  `Calculator` (EITC, child tax credit, household knockouts) are listed as `SKIP ... needs Lean
  Calculator (#48)` and refused as skips once the server matches them) and `scripts/server_vs_cli.mjs` (the server against
  `ustax run Form1040` on an independent re-mapping of about 300 random requests).

**Trusted code added by the server.** `ServerMain.lean` (IO only, no theorem; routing, CORS, body cap,
content-type check, logging of method, path and status only, generic 500), `Std.Http` and `Std.Async`
from the Lean toolchain (parser, serializer, libuv sockets), and `Lean.Json` is *not* used (the strict
reader `Api/Json.lean` is). The server binds to loopback by default and speaks no TLS (`docs/tls.md`).
Not proved: that the handler maps every `Reply` to the right status line (checked by the integration
test), and that the exception text never reaches a client (by construction: `handle` discards it).
`ServerMain` is outside `lean/UsTax`, so `make audit` neither scans nor lints it; the audit's forensics
step runs with `--roots UsTax` because the extractor cannot import two modules that each define `main`.

## Income types and adjustments (issue #45)

Hand-translations (strategy (c)) of seven Catala modules; each file has a Catala <-> Lean
name table, and every assertion of the matching `catala/tests/test_*.catala_en` is a `#guard`.

- `UsTax/Unemployment.lean`: `Form1099GFacts`, `Unemployment` (Schedule 1 line 7, 1099-G part of 25b).
- `UsTax/Form1099Misc.lean`: `Form1099Miscs` (Alaska PFD, line 8g).
- `UsTax/Form1099Rs.lean`: `Form1099RItem`, `Form1099Rs` (lines 5a, 5b, 1099-R part of 25b, Form 8880 line 4).
- `UsTax/SocialSecurity.lean`: `SocialSecurity` (the worksheet, lines 6a and 6b).
- `UsTax/EducatorAdjustment.lean`, `UsTax/StudentLoanAdjustment.lean`: Schedule 1 lines 11 and 21.
  The student loan phase-out is the exact fraction (DF-BUG(7)): Lean follows Catala, not Direct File.
- `UsTax/EstimatedPayments.lean`: Form 1040 line 26.
- `UsTax/Params2024.lean`: the extra figures. `UsTax/Cli.lean`: seven new `scopes` lines.
- `make lean-difftest SCOPE=<unemployment|form1099_misc|form1099_rs|form1099_rs_withholding|social_security|educator_adjustment|student_loan_adjustment|estimated_payments>`
  (same mappings as `make difftest`; none needed a change).
- `UsTax/Form1040Full.lean`: the **composition layer**. `UsTax/Form1040.lean` is untouched (strict
  difftests `form_1040` 441 and `form_1040_plugged` 3297 unchanged). `form1040Full` runs the seven
  modules, fills the `Form1040In` slots they own and calls `form1040` (three passes: Social
  Security needs lines 1z/2a/2b/8, student loan needs line 9). No Catala scope exists for this
  composition, so it is `#guard`-tested only. Not wired: HSA, EITC, credits.
- `UsTax/Income/Props.lean` (plausible, run first) and `UsTax/Income/Lemmas.lean`: line 7, 8g, 11,
  21, 6b and 26 nonnegative (hypotheses stated where needed), line 11 at most $600, and refund/balance
  due exclusive for `form1040Full`. Axioms: `propext`, `Classical.choice`, `Quot.sound`. The Rat
  facts use `decide +kernel` (kernel evaluation, no extra axiom).

## Household and filing status (issue #44)

Hand-translations (strategy (c)) of six Catala modules, each file with a Catala <-> Lean name
table and every assertion of the matching `catala/tests/test_*.catala_en` as a `#guard`:

- `UsTax/Filers.lean`: `FilerFacts`, `Filers`, `FilersStandardDeduction` (feeds `StandardDeduction`).
- `UsTax/QualifyingChild.lean`, `UsTax/DependentsBenefitSplit.lean`, `UsTax/QualifyingRelative.lean`,
  `UsTax/HohQssPersons.lean`: the per-person scopes (`QualifyingChildTest`, `BenefitSplitTest`,
  `DependentTest`, `HohQssPersonTest`) and their household scopes (`List.map` over members, counts
  by `Money.countBy` from `UsTax/Lists.lean`).
- `UsTax/FilingStatus.lean`: `FilingStatusEligibility` and `FilingStatusReturn` (stage 1 `Filers`,
  stage 2 household, stage 3 eligibility), plus the cheap lemmas QSS preempts HoH and valid
  implies not knocked out.
- `UsTax/Household/Props.lean` (plausible, run first) and `UsTax/Household/Lemmas.lean`. Plausible
  caught that the recommendation is eligible only if MFJ eligibility implies the marital status
  allows marriage; the lemma carries that hypothesis and `filers_mfj_implies_mfs` discharges it.
- `UsTax/Date.lean`: `Date.lt`, `Date.toIso`; `UsTax/Types.lean`: `ScopedState`;
  `UsTax/Params2024.lean`: `qualifyingRelativeGrossIncomeLimit`.
- `UsTax/Cli.lean` registers `FilersStandardDeduction`, `QualifyingChildTest`, `BenefitSplitTest`,
  `DependentTest`, `HohQssPersonTest`, `FilingStatusReturn`.
- `make lean-difftest SCOPE=<filers|filing_status>`; per household member (one pseudo-scenario per
  person in `oracle/persons.csv`): `make lean-difftest-persons`; the filing-status fact graphs:
  `make lean-difftest-filing-status-graphs`. `difftest/lean.mjs` needed no change (it already takes
  `--oracle`); knownDivergence lists are those of the Catala mappings (DF-BUG(15), (19)).

## CDCC, Saver's credit and Schedule R (issue #46, second half)

Hand-translations (strategy (c)) of three Catala modules, in the order of the Catala files. Each file
has a Catala <-> Lean name table, and every assertion of the matching `catala/tests/test_*.catala_en`
is a `#guard`. The figures are in `UsTax/ParamsCredits.lean` (namespace `UsTax.Params`, a separate
file from `Params2024.lean`).

- `UsTax/Cdcc.lean`: `CdccPersonTest`, `Form2441PartIII` (lines 12 to 31, Form 1040 line 1e) and
  `Form2441` (lines 3 to 11, Schedule 3 line 2). The percentage table is `applicablePercentage`
  (35 percent, minus one point per started `$2,000` of AGI over `$15,000`, floor 20 percent); caps are
  `$3,000` / `$6,000` (one / two or more qualifying persons); deemed income is
  `deemedIncomeUplift` (`$250` / `$500` a month, the higher of deemed and actual income per month).
  DF-BUG(23) to (28) are reproduced as in Catala (Lean follows Catala).
- `UsTax/SaversCredit.lean`: `SaversColumn` and `SaversCredit` (Form 8880 lines 1 to 12). DF-BUG(14)
  reproduced.
- `UsTax/ElderlyAndDisabled.lean`: `EdcFiler` and `ScheduleR` (lines 1 to 22). DF-BUG(13) reproduced.
- `UsTax/Cli.lean` registers `Form2441`, `SaversCredit` and `ScheduleR` (section `Credits`).
  `make lean-difftest SCOPE=<cdcc|savers_credit|elderly_and_disabled>`; the mappings are the Catala
  ones, none changed. `Form2441PartIII` is Lean-only (no mapping reads it separately).
- `UsTax/NonrefundableCredits/Props.lean` (plausible) and `Lemmas.lean` (proofs, axioms `propext`,
  `Classical.choice`, `Quot.sound`): each credit is nonnegative and at most the tax limit its scope
  was given (CDCC: `credit_le_limit`, `credit_pos_imp_le_tax`, `credit_le_2100`; Saver's:
  `credit_le_limitation`, `credit_le_2000`, `sum_le_tax_of_covered`; Schedule R: `totalEdc_le_limit`,
  `totalEdc_le_1125`, `cdcc_add_edc_le_tax`) and `credits_within_tax`, the three together within the
  tax, in the wiring the Calculator uses (Schedule R line 3 is tax less CDCC). Feeds issue #66.
  `CdccLemmas.credit_le_2100` takes the hypothesis `isFillingPartIii → 0 ≤ line28` (satisfied by
  every return without Part III; negative benefits are not real).
## EITC and CTC/ODC/ACTC (issue #46, first half)

Hand-translations (strategy (c)) of `catala/eitc.catala_en` and `catala/ctc_odc.catala_en`; each file
has a Catala <-> Lean name table and every assertion of `catala/tests/test_eitc.catala_en` and
`test_ctc_odc.catala_en` is a `#guard`.

- `UsTax/Eitc.lean`: `EitcTable` (the printed-table emulation: $50 row middle, `+ $24` max-credit
  row, capped phase-out income, exact decimals rounded once) and `EarnedIncomeCredit` (line 27:
  eligibility, four combat pay calculations, election or recommendation, Form 8862 flag).
- `UsTax/CtcOdc.lean`: `CtcOdcPersonTest`, `CtcOdcDependents`, `Schedule8812` (lines 4 to 27).
- `UsTax/Params2024/EitcCtc.lean`: the `Params_2024` figures they read (separate file so parallel
  modules do not edit `Params2024.lean`).
- `UsTax/EitcCtcDifftest.lean`: the Lean ports of the difftest scaffolds `EitcFromFilers` and
  `CtcOdcFromHousehold`, so the existing mappings run unchanged.
- Golden: `UsTax/Eitc/EicTable.lean` checks all 1,337 rows of the printed 2024 EIC Table, 8 columns, at the
  lowest and highest whole dollar (21,392 evaluations; 15,774 compared, 5,618 at or past the column's
  completed phase-out, which the table prints as "can't take the credit"; 0 differ) and the 3,000
  earned-income / AGI pairs of the Catala golden test. Data: `UsTax/Eitc/EicTableData.lean`, generated by
  `python3 scripts/gen_lean_eic_table.py` (do not edit).
- `make lean-difftest SCOPE=<eitc|ctc_odc|ctc_odc_household>` and `make lean-difftest-persons`
  (now includes `ctc_odc_person`): same mappings as `make difftest`; no `knownDivergence` in these
  modules.
- Proofs: `UsTax/Proofs/Eitc.lean` proves `eitc_within_bounds` (issue #67; statement in
  `Comparator/Challenge.lean`, in `comparator.json`): for every `EitcTableIn` the credit is within
  `[0, maxCredit]` and `0` at or after the completed phase-out, with the unchanged spec property
  `EitcWithinBounds`. `UsTax/Proofs/CtcOdc.lean`: line 19 nonnegative and at most line 8, line 28
  nonnegative and at most $1,700 per qualifying child, phase-out monotone in AGI.
  `UsTax/Eitc/Props.lean` (plausible) ran first; it found that the credit limit needs nonnegative
  other credits. Axioms: `propext`, `Classical.choice`, `Quot.sound`.

## Pattern for Lean modules (follow this for every later scope)

1. **One Lean file per Catala module**, `UsTax/<Module>.lean`, written by hand
   from the Catala source (strategy (c), `docs/catala-to-lean.md`), not from
   generated code. Same declarations, same order, names in lower camel case
   (`tentative_tax_for` → `tentativeTaxFor`, `schedule_mfj_qss` →
   `scheduleMfjQss`). The module docstring has a Catala ↔ Lean name table and
   cites the same sources as the Catala file. Shared enums and structures go in
   `UsTax/Types.lean`, mirroring `catala/types.catala_en`.
2. **Types.** Money is `Int` cents, decimal is `Rat`, integer is `Int` (no
   `Nat`, no `Money` alias: `omega` must see `Int`). Every Catala `money *
   decimal` is `Money.mulRate`, every `round of` is `Money.roundDollar`, every
   stdlib call is its `UsTax.Money` port; never round anywhere Catala does not.
   Definitions must be computable (no `Classical`, no `noncomputable`).
3. **Scopes.** A scope becomes a structure of its inputs (`<Scope>In`), a
   structure of its outputs (`<Scope>Out`), and a function
   `<scope> : <Scope>In → <Scope>Out`. Field names are the Catala names in
   lower camel case. Exception groups: an `if` chain plus a disjointness lemma,
   or `handleExceptions` (`UsTax/Defaults.lean`).
4. **Unit tests.** Every assertion of `catala/tests/test_<module>.catala_en`
   becomes a `#guard` at the end of the module. Generated golden data goes in a
   `*Data.lean` file made by a script in `scripts/` (header says so); the
   checks that use it are hand-written in a separate file.
5. **Specification.** `UsTax/<Module>/Spec.lean`: a readable statement of the
   rule as the source prints it, and a proof that the code meets it, for all
   inputs or with stated, satisfiable hypotheses. Add an `example` with every
   hypothesis discharged and a few `¬ spec bad` examples (CLAUDE.md section 4).
   A literal port of the Catala form plus an equality proof (as here) is worth
   it when the readable form differs from the Catala form.
6. **Properties.** `UsTax/<Module>/Props.lean` (plausible, before proving),
   then `UsTax/<Module>/Lemmas.lean` (proofs). End each proof file with
   `#audit_axioms` for its main theorems: only `propext`, `Classical.choice`,
   `Quot.sound`. No `sorry`, `native_decide` or raised `maxHeartbeats`.
7. **Driver.** Add one line to `UsTax.Cli.scopes`: a function from the
   scope's Catala JSON input (the shape `catala json-schema -s <Scope>`
   prints; money as a decimal string, enums by case name) to a JSON object of
   its outputs keyed by Catala output names, money as `"1234.56"`.
8. **Differential test.** Add (or reuse) the Catala mapping
   `difftest/mappings/<scope>.mjs` (oracle path -> Catala input and output;
   `extraOutputs` for Catala outputs with no oracle fact; `knownDivergence`),
   the same file `make difftest SCOPE=<scope>` uses, then run
   `make lean-difftest SCOPE=<scope>`. `difftest/lean.mjs` writes each
   scenario's input JSON once (the file the Catala runner reads), feeds the
   same text to `ustax run <CatalaScope>` and `clerk run`, and reports Direct
   File / Catala / Lean per fact: three-way agreement, lean = catala where the
   oracle row is not Complete, knownDivergence (Lean must equal Catala) and
   failures; knocked-out scenarios are skipped and listed. Nothing else is
   added per module. `LEAN_DIFFTEST_PERTURB=1` is the negative control (every
   check must fail). Optional extra: a dense sweep script like
   `difftest/lean_rates.mjs` (`make lean-difftest-rates`) with a batch wrapper
   scope (`catala/tests/difftest_<module>_batch.catala_en`).
   **Trust:** the harness, the mappings and the JSON handling of the scenario
   subset are untrusted test code (JavaScript). Lean parses its input with
   `Lean.Json.parse` in `UsTax/Cli.lean`; there is no parsing script.
9. **Register** the new modules in `UsTax.lean`, build with `lake build`
   (one `lake` process at a time), and run `make forensics`.

CI and the proof audit (`make audit`, `.github/workflows/ci.yml`): see `docs/audit.md`.
