# catala/CONVENTIONS.md: project-wide Catala conventions

Rules every Catala module in this repository follows. Fixed by issue #5 before
any tax module is written. Sources: `scope.md` sections 1, 3.1, 5.4, 8, 9 and
11; `sources/CATALA_PATTERNS.md`; the Direct File XML under
`../direct-file/direct-file/backend/src/main/resources/tax/` ("DF" below) and
its reference engine under `../direct-file/direct-file/fact-graph-scala/`.

Toolchain: Catala 1.3.0 through `clerk` (`clerk typecheck`, `clerk test`,
`clerk run --scope=...`). `make check` type-checks `catala/*.catala_en` and
`catala/tests/*.catala_en`, then runs `clerk test`.

## 1. Layout and naming

### Files and modules

- One module per file. The file `catala/<name>.catala_en` starts with
  `> Module <Name>`, where `<Name>` is `<name>` with the first letter in
  upper case (`params_2024.catala_en` is `> Module Params_2024`).
- Topic modules are named after their DF XML module, in snake_case:
  `standardDeduction.xml` becomes `catala/standard_deduction.catala_en`,
  module `Standard_deduction`. One DF module maps to one Catala module (see
  the map in section 9). Split a module only when its file passes about
  1,500 lines, and then with `> Include:` from a master file, as in
  `catala-examples/us_tax_code`.
- Shared modules, already present:
  - `types.catala_en` (`Types`): enumerations and structures used by more
    than one module (`FilingStatus`, `FilerRole`, `ScopedState`).
  - `params_2024.catala_en` (`Params_2024`): every TY2024 constant, one
    declaration per figure, each with a source file and PDF page. No rules.
  - `rounding.catala_en` (`Rounding`): the DF arithmetic operators that need
    a helper (section 4).
- Import them as `> Using Types`, `> Using Params_2024 as P`,
  `> Using Rounding as R`. The standard library (`Money`, `Decimal`, `List`,
  `Date`) is always in scope; never write `> Using Money_en`.
- Tests live in `catala/tests/test_<name>.catala_en`, with no `> Module`
  line, as `#[test]` scopes that hold at least one `assertion` (a test scope
  with no assertion always passes). Oracle fixtures (issue #6) follow the
  `Data` / `TestN` layout of `catala-examples/us_tax_code/tests/`.
- `catala/hello.catala_en` is the toolchain smoke test. It stays until the
  first topic module lands, because the Lean work (#8, #9) may still point
  at it.

### Names inside a module

| Thing | Convention | Example |
|---|---|---|
| Scope | UpperCamelCase, named after the form, worksheet or statute unit it computes | `StandardDeduction`, `Schedule8812`, `SocialSecurityBenefitsWorksheet` |
| Variable for a DF fact | the last segment of the DF fact path in snake_case, unchanged otherwise | `/taxableSocialSecurityBenefits` is `taxable_social_security_benefits` |
| Variable for a DF `Writable` | same rule, so the `writable` prefix stays | `/formW2s/*/writableWages` is `writable_wages`; the derived `/formW2s/*/wages` is `wages` |
| Variable with no DF fact | descriptive snake_case, with a comment saying why it exists | `remaining_tax_after_cdcc` |
| Knockout condition | `ko_` plus the DF fact name in snake_case | `/knockoutForForm1099RDistributionCode` is `ko_knockout_for_form1099_r_distribution_code` |
| Structure | UpperCamelCase singular of the DF collection | `/formW2s` holds `FormW2`; `/familyAndHousehold` holds `Person` |
| Enumeration and constructors | UpperCamelCase | `FilingStatus`, `HeadOfHousehold` |
| Constant in `Params_2024` | snake_case `<topic>_<item>` | `std_deduction_head_of_household` |

Keeping DF fact names makes the oracle comparison (issue #6) a mechanical
rename, not a judgment call.

### Literate style and citations

Follow `sources/CATALA_PATTERNS.md` section 3:

- Markdown headings carry the legal structure (`## 26 U.S.C. § 63`,
  `### (c) Standard deduction`, `#### (2) Basic standard deduction`).
- Quote the law in prose, copied exactly from `sources/statute/*.html` or the
  form PDF, inside quotation marks. Do not use Markdown `>` block quotes in a
  `.catala_en` file: a line starting with `>` is parsed as a directive
  (`> Module`, `> Using`) and fails to compile.
- Put the rule in a ` ```catala ` block directly under the text it
  implements. Declarations go in ` ```catala-metadata ` blocks.
- Every definition carries two comments: the law (`# IRC 63(c)(5)`, or a form
  line with file and page, `# Sch 8812 line 10, f1040s8--2024.pdf p 1`) and
  the DF fact it mirrors (`# DF: standardDeduction.xml /standardDeduction`).
- Every TY2024 dollar amount or rate is a `Params_2024` constant, never a
  literal in a rule. Literals are allowed only for `$0`, `0`, `1` and
  structural numbers such as the 50/50 rate of a table lookup.
- Open questions use `# TODO(#n):` with the issue number.

## 2. Mapping the fact graph to Catala

| DF construct | Catala |
|---|---|
| `Writable` fact | `input` of the scope that owns it. Only the top-level return scope (#14) takes user data; sub-scopes receive it with `definition sub.x equals ...`. |
| `Derived` fact read by another module, exported (`Export mef` or `downstreamFacts`), or a form line | `output` with a `definition` |
| Any other `Derived` fact | `internal` with a `definition` |
| `Dollar` | `money` (integer cents) |
| `Rational` | `decimal` (exact). Rates are written as percentages (`34%`) or decimals |
| `Int` | `integer` |
| `Boolean` | `condition` when the DF expression is a test that defaults to false; `boolean` for data |
| `Day` | `date` |
| `Enum` | `enumeration`, in `Types` if more than one module uses it |
| Collection `/c` with child facts `/c/*/x` | `list of C` where `C` is a structure with field `x`; `*/filer` becomes a `Types.FilerRole` field |
| `CollectionSum`, `Filter`, `Count`, `CollectionSize` | `Money.sum of (map each ...)`, `list of x among l such that ...`, `number of ...` |
| Per-item derived fact `/c/*/y` | a scope applied to each item: `map each i among items to (output of ItemScope with { -- item: i })` (verified on 1.3.0) |
| `Switch` / `Case` | `if ... then ... else`, `match`, or a base `label` plus `exception` definitions when the law says "except as provided in ..." |
| `Dependency module=m` | `> Using M` plus a sub-scope or a scope call |
| `Round`, `TruncateCents`, `StepwiseMultiply`, ... | section 4 |
| `Placeholder`, `IsComplete`, `Incomplete` | not modelled (section 3) |
| `BlockSubmissionOnTrue`, `flowIsKnockedOut` | section 6 |
| MeF-only, PDF-only and copy facts (`...Needed`, `...Rounded` for MeF, `copy.xml`, `mefTypes.xml`, flow screens) | not modelled |

## 3. Inputs are complete

The spec assumes **complete inputs**. Every input has a value; there are no
`Placeholder` or `Incomplete` states, and no `IsComplete` tests.

- A DF `Switch` of the form "if `IsComplete(writableX)` then `writableX` else
  `$0`" (the pattern of scope.md section 3.1) becomes plain `writable_x`. An
  absent form is an absent list element, and an empty box is an explicit
  `$0` in the input.
- A DF `Placeholder` default is not a rule. If the scenario leaves a fact
  unanswered, the oracle harness (#6) fills in the value DF would have used
  and records that it did so.
- Facts that DF only asks under a UI condition (for example
  `/familyAndHousehold/*/disabilityStatusMayAffectBenefits`) are still
  inputs here; where the gate changes a tax result, the gate is reproduced as
  a rule (quirk Q5).
- `/filingStatus` is a `Writable` fact, so it is an input like any other.
  Section 7 explains why this breaks the filing-status cycle.
- No total-function version (Complete / Placeholder / Incomplete) is
  provided. The Lean theorems (#9) are stated for complete inputs only.

## 4. Money and rounding

### Types

`money` is an integer number of cents. `money * decimal` and
`money of decimal` round to the cent, ties away from zero. `decimal` is an
exact rational, so `decimal` arithmetic never rounds. Negative money is
allowed (net Social Security benefits can be negative).

### DF operators and their Catala form

| DF operator (engine source) | Semantics in DF | Catala |
|---|---|---|
| `Round` (`compnodes/Round.scala`, `types/Dollar.scala`) | `setScale(0, HALF_UP)`: whole dollar, ties away from zero | `R.round_dollar of x` (same as `round of x`) |
| `TruncateCents` (`compnodes/TruncateCents.scala`) | `Rational` to two decimals, `RoundingMode.DOWN` (toward zero) | `R.truncate_cents of d` (decimal in, money out) |
| `StepwiseMultiply(x, n/d)` (`compnodes/StepwiseMultiply.scala`) | `Dollar(x.intValue / d * n)`: drop cents, integer-divide (toward zero), multiply | `R.stepwise_multiply of x, n, d` |
| `RoundToInt` (`compnodes/RoundToInt.scala`) | `round` then `intValue` | `R.round_dollar`; add an integer-valued helper in `Rounding` when PTC (#32) needs one |
| `GreaterOf`, `LesserOf`, `Maximum`, `Minimum` | max / min | `Money.max`, `Money.min`; `GreaterOf(x, 0)` is `Money.positive of x` |
| `Multiply` Dollar by Rational (`compnodes/Multiply.scala`) | `(x * n) / d` stored at 2 decimals, HALF_EVEN | `x * r` (2 decimals, ties away from zero: see Q-R2) |
| `Add`, `Subtract` Dollar with Rational (`compnodes/Add.scala`) | converts the Rational through `Float` (`types/Dollar.scala`, `Conversion[Rational, Dollar]`) | exact (see Q10) |
| `Divide` | `BigDecimal` division, stored at 2 decimals | `money / money` is a `decimal`; convert back with `$1 * d` or `R.truncate_cents` as DF does |
| `CollectionSum` | exact sum | `Money.sum of (...)` |

The helpers are in `catala/rounding.catala_en` and tested in
`catala/tests/test_rounding.catala_en`, including the tie cases
$0.50 to $1, $1.50 to $2, $2.50 to $3 and -$0.50 to -$1.

### Rounding rules

1. **Round where DF rounds, and nowhere else.** Every `<Round>` in the XML
   becomes one `R.round_dollar`, and the DF fact path comment makes it
   checkable. Do not add a rounding step that DF does not have, even where
   the form says "round".
2. **Per-item rounding (scope.md section 3.1).** DF rounds dollar boxes per
   item before summing (for example `/formW2s/*/wages` is `Round` of the box,
   then `/wages` in `formW2s.xml` rounds the sum again). Reproduce it exactly: round
   each item where DF does, then round the sum where DF does. The Schedule B
   exception is reproduced too: `/interestIncome` sums per-item rounded
   amounts only when `/requiresScheduleB`, otherwise it rounds the raw sum.
   This differs from the 1040 instructions (quirk Q-R1).
3. **Products are rounded the DF way.** `round of (x * rate)` first rounds
   to the cent, then to the dollar, as DF does. `R.round_dollar_exact`
   (one rounding of the exact product) is only for places where a quirk
   decision says to follow the statute.
4. **Table lookups use `R.stepwise_multiply`**, as in DF (Tax Table midpoint,
   scope.md section 2.1; EIC table, section 6.2; Schedule 8812 line 10,
   section 6.1).

## 5. Exceptions versus quirks

Catala `label` / `exception` is reserved for the law's own override
structure ("except as provided in paragraph (5)"). Places where we
reproduce a DF choice that the law does not make are marked with a comment
on the line above the definition, in this exact form, so they can be found
with `grep -rn "QUIRK(" catala/`:

```
# QUIRK(Q3): DF omits line 23 from /totalTax. We add line 23, which is $0
# in scope, so the value equals DF. Decision: reproduce (#60).
```

`Qn` is the item number in section 8. A new quirk found later gets the next
free number in section 8 of this file and a line in the quirk-decision
issue #60.

## 6. Knockouts and the `unsupported` output

scope.md section 1 item 3 and section 9. DF aggregates about 110 knockout
facts into `/flowIsKnockedOut` (`flow.xml`). The pattern here:

1. Each DF knockout fact becomes a `condition` named `ko_<fact name>` in the
   scope of its topic, defined by `rule ko_x under condition ... consequence
   fulfilled`, with the DF fact path in a comment. It is an `output`, so the
   oracle can compare each knockout on its own.
2. Each topic scope has one `output unsupported condition` that lists every
   `ko_` of that scope in a single explicit disjunction:

   ```
   rule unsupported under condition
     ko_a or ko_b or sub_scope.unsupported
   consequence fulfilled
   ```

   One place per scope lists the whole set, so a reviewer can check it
   against `flow.xml`.
3. The return scope (#14, #38) defines its `unsupported` as the `or` of the
   topic scopes' `unsupported`, plus the return-level knockouts
   (`knockoutHasNoPaymentsOrCredits`, the filing-status check of section 7).
4. All other outputs are still computed when `unsupported` is true; they
   are just not meaningful. Knockouts are never `assertion`s (that aborts the
   computation) and never Catala exceptions.
5. A line DF hard-wires to `$0` because it is out of scope ("OUT OF SCOPE"
   in the XML) is a definition equal to `$0` with a `# OUT OF SCOPE:` comment
   naming the knockout that keeps the user away from it.
6. The Lean side (#9) states its main theorems under the hypothesis
   `unsupported = false`.

## 7. Scope structure for filing status, dependents and credits

The cycle in scope.md section 5.4: filing status depends on HoH and QSS
qualifying persons, those depend on the dependent tests, those depend on
`/treatFilersAsDependents`, which depends on `/treatAsMFJ`.

**Decision: a staged single pass with the filing status as an input. No
two-pass scope.** Reason: `/filingStatus` is `Writable` (`filingStatus.xml`,
fact `/filingStatus`). With complete inputs, DF's `/treatAsMFJ` reduces to
"`/filingStatus` is MFJ and `/eligibleForMFJ`" (`filingStatus.xml`, fact
`/treatAsMFJ`), and `/eligibleForMFJ` reads marital facts only. Nothing in
the chain reads its own output, so there is no fixed point to compute.

Stages, each a scope (or a group of scopes) that takes only earlier stages'
outputs:

1. **Filers and basic eligibility** (`Filers`, `FilingStatus` part 1):
   marital facts, `eligible_for_mfj`, `eligible_for_mfs`,
   `eligible_for_single`, `filer_could_qualify_for_hoh` (`filers.xml` line
   4730, which uses `eligibleForMFJ`, not `eligibleForHoh`). Input: `filing_status`.
   Output: `treat_as_mfj`, `treat_filers_as_dependents`.
2. **Household** (`Family_and_household`, `Dependents_relationship`,
   `Dependents_benefit_split`): per-person tests, one scope call per person,
   using `filing_status` and stage 1 outputs. Outputs: claimed dependents,
   HoH and QSS qualifying persons, credit-specific person flags.
3. **Filing status check** (`FilingStatus` part 2): `eligible_for_hoh`,
   `eligible_for_qss` from stage 2, and `filing_status_is_eligible` for the
   chosen status. DF's UI only offers eligible statuses, so an ineligible
   input cannot happen there; here it is a knockout,
   `ko_filing_status_not_eligible`, so the function stays total. Lean lemma
   (#9, scope.md section 5.4): `unsupported = false` implies the chosen
   status is among the eligible ones.
4. **Income, AGI, deductions, tax** in Form 1040 line order (#14).
5. **Credits in DF's application order** (scope.md section 6.7): CDCC, then
   Schedule R, then Saver's, then CTC/ODC, each taking the remaining tax
   after the previous ones as an input; EITC before ACTC (ACTC reads it).
   scope.md section 6.1 notes these are acyclic as written.

The two-pass pattern (`Section121TwoPasses` in
`catala-examples/us_tax_code/section_121.catala_en`: the same scope run
twice, pass two fed with pass one's outputs) is kept in reserve for a real
fixed point. None is known. If one appears, document it here before using
the pattern. Running the same scope several times for **alternatives**
(EITC with and without each combat-pay election, scope.md section 6.2) is a
different pattern: several sub-scope instances and a `Money.max` of their
outputs.

## 8. Quirk policy (scope.md section 11)

Default: **reproduce the reference**, mark the definition with a
`# QUIRK(Qn):` comment (section 5), and track the item in issue #60. Where
the statute or the IRS instructions clearly differ, the line below says so
and the item is flagged **[HUMAN]** for a decision. Items were re-read in the
XML on 2026-10-31; the result of the re-read is part of each line.

| # | scope.md section 11 item | Policy |
|---|---|---|
| Q1 | `/pensionsAndAnnuities` (line 5a) omits `fullyTaxablePensions` | **Reproduce.** Confirmed in `income.xml` lines 528-555. It agrees with the 1040 instructions: fully taxable pensions go "on line 5b; don't make an entry on line 5a" (`i1040gi--2024.pdf` p 28). Not a divergence. Owner #22. |
| Q2 | `form1099RsDistributionCodeValidChars` is `"247BGH"` | **Reproduce, [HUMAN].** Confirmed (`constants.xml` line 915). Worse than scope.md says: `/form1099Rs/*/hasUnsupportedDistributionCode` (`form1099Rs.xml` line 276) checks the *stripped* code against its whitelist, so a two-character code with one character outside `247BGH` (for example `7D`, `7M`) is stripped to a supported code (`7`) and accepted, while `1` alone strips to the empty string and is knocked out. IRS meaning of `7D` and `7` differ. Owner #22. |
| Q3 | `/line21OfSchedule2` is `$0` and not added into `/totalTax` | **Follow the form, same value.** Confirmed (`taxCalculations.xml` lines 1388-1410). Line 24 is written as line 22 + line 23 with line 23 = `$0` (`# OUT OF SCOPE`), which equals DF on every input. Owner #14. |
| Q4 | `/qualifiedBusinessIncomeDeduction` and `/americanOpportunityCredit` are `$0` stubs | **Reproduce.** QBI is `$0` by law for the supported income set (no business income). AOC: **[HUMAN]**, a filer who qualifies for the American opportunity credit (IRC 25A) gets `$0` here. A search of the tax XML for `8863`, `1098-T`, `tuition` and education credits finds no knockout, only the stub (`taxCalculations.xml` line 1473), so DF appears to under-credit such filers rather than refuse them. |
| Q5 | `disabilityStatusMayAffectBenefits` "possibly inverted" | **Reproduce; not inverted.** Re-read (`familyAndHousehold.xml` lines 803-845): the description says "younger than the filer" but the code tests `dateOfBirth < minimumFilerDateOfBirth`, i.e. *older* than the oldest filer, which is exactly the case where disability matters for the QC age test (IRC 152(c)(3)(B)). The description is wrong, the code is right. The gate is ANDed into `/familyAndHousehold/*/ageTest` (line 1853), so it is reproduced; it differs from the statute only for a disabled person under 18 born on the same day as the oldest filer. Owner #16, #18. |
| Q6 | Qualifying-child tie-breakers (IRC 152(c)(4)) not implemented | **Reproduce, [HUMAN].** DF takes "is the qualifying child of another taxpayer" as answers, not computed from a second return. We model the same inputs and do not encode 152(c)(4). Results differ from the statute when two taxpayers can claim the same child and the other has priority. Owner #16. |
| Q7 | `lastYearAgiFromOLA` typed `Int` | **Not modelled.** `signing.xml` is identity verification, not tax computation (scope.md section 4.4). |
| Q8 | Descriptions mention TY2023 while constants are tagged 2024 | **Use official TY2024 values.** Constants come from `Params_2024`, each checked in `sources/VERIFICATION.md`; DF descriptions are ignored. A DF constant that differs from the official value is a new quirk. None found so far. |
| Q9 | Schedule R and other constants carry no `TaxYear` tag | **Use official values, which equal DF.** Schedule R amounts come from IRC 22(c), (d) and are not indexed; checked against `i1040sr--2024.pdf` p 7 and `f1040sr--2024.pdf` p 2 in `sources/VERIFICATION.md`. Owner #30. |
| Q10 | `Rational` to `Dollar` conversion through `Float` | **Do not reproduce; compute exactly, [HUMAN].** Confirmed in `types/Dollar.scala` (`Conversion[Rational, Dollar]`, `numerator.toFloat / denominator`), used by `Add` and `Subtract` of a Dollar and a Rational. It is an engine artefact, not a tax rule, and a `Float` (24-bit mantissa) loses cents once a numerator passes 16,777,216. The oracle (#6) reports any case where this changes a result. Owner #60. |
| Q11 | `scopedStateOptions` reconstructed from a grep | **Reproduce.** Re-read (`constants.xml` lines 327-360): 25 states plus `moreThanOne` and `noneOfThese`, Louisiana commented out. Encoded as `Types.ScopedState`. Owner #36. |

Rounding items found while writing section 4 (not in scope.md section 11):

| # | Item | Policy |
|---|---|---|
| Q-R1 | Per-item rounding before sums (scope.md section 3.1) | **Reproduce, [HUMAN].** The 1040 instructions say "If you have to add two or more amounts to figure the amount to enter on a line, include cents when adding the amounts and round off only the total" (`i1040gi--2024.pdf` p 23). DF rounds each item first, so a sum of several items can differ from the instruction by $1 or more. |
| Q-R2 | Cent rounding of products: DF `HALF_EVEN`, Catala ties away from zero | **Accept the divergence.** DF stores every `Dollar` at 2 decimals with `HALF_EVEN` (`types/Dollar.scala`); Catala `money * decimal` rounds ties away from zero. They differ only when an exact product ends in exactly half a cent. Reproducing `HALF_EVEN` would need a helper on every product; the oracle (#6) measures whether it ever matters. Owner #60. |
| Q-R3 | Double rounding of `round(x * rate)` | **Reproduce.** Both DF and Catala round the product to the cent before the dollar (section 4, rule 3). `R.round_dollar_exact` exists for the statute reading if #60 decides otherwise. |

## 9. Module map

DF module (36 files) to Catala file, with the issue that writes it. Modules
marked "not modelled" hold no tax computation.

| DF XML | Catala file | Issue |
|---|---|---|
| `constants.xml` | `params_2024.catala_en`, `types.catala_en` | #5 (this) and each topic issue |
| `taxCalculations.xml` | `tax_calculations.catala_en` | #10 (rate schedule, Tax Table), #14 (1040 chain) |
| `income.xml` | `income.catala_en` | #14 |
| `formW2s.xml` | `form_w2s.catala_en` | #12 |
| `interest.xml` | `interest.catala_en` | #13 |
| `unemployment.xml`, `form1099Misc.xml` | `unemployment.catala_en`, `form1099_misc.catala_en` | #21 |
| `form1099Rs.xml` | `form1099_rs.catala_en` | #22 |
| `socialSecurity.xml` | `social_security.catala_en` | #23 |
| `educatorAdjustment.xml`, `studentLoanAdjustment.xml` | `educator_adjustment.catala_en`, `student_loan_adjustment.catala_en` | #24 |
| `estimatedPayments.xml` | `estimated_payments.catala_en` | #25 |
| `hsa.xml` | `hsa.catala_en` | #35 |
| `standardDeduction.xml` | `standard_deduction.catala_en` | #11 |
| `filers.xml`, `spouseSection.xml` | `filers.catala_en`, `spouse_section.catala_en` | #15 |
| `familyAndHousehold.xml`, `dependentsRelationship.xml` | `family_and_household.catala_en`, `dependents_relationship.catala_en` | #16, #17 |
| `dependentsBenefitSplit.xml` | `dependents_benefit_split.catala_en` | #18 |
| `filingStatus.xml` | `filing_status.catala_en` | #19, #20 |
| `eitc.xml` | `eitc.catala_en` | #26 |
| `ctcOdc.xml` | `ctc_odc.catala_en` | #27 |
| `cdcc.xml` | `cdcc.catala_en` | #28 |
| `saversCredits.xml` | `savers_credits.catala_en` | #29 |
| `elderlyAndDisabled.xml` | `elderly_and_disabled.catala_en` | #30 |
| `schedule2.xml`, `schedule3.xml` | `schedule2.catala_en`, `schedule3.catala_en` | #31 |
| `ptc.xml` | `ptc.catala_en` | #32, #33, #34 |
| `flow.xml`, `validations.xml` | knockouts in each topic module; aggregation in the return scope | #36, #37, #38 |
| `refundPrefs.xml`, `paymentMethod.xml`, `signing.xml`, `imported.xml` | not modelled (I/O, identity, imported filer profile data) | none |
| `copy.xml`, `mefTypes.xml` | not modelled (UI text, MeF formats) | none |

No empty skeleton files are committed: an empty scope would fix interface
decisions (inputs, structures) that belong to the topic issues. Each topic
issue creates its file under the name above.
