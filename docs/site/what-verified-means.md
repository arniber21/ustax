---
title: What "verified" means here
order: 1
summary: The tax law written as type-checked Catala that quotes the statute, checked against the IRS's own engine, which surfaced 33 disagreements with the law; then Lean proofs of the arithmetic. What each covers and what you still have to trust.
---

# What "verified" means here

> [!IMPORTANT]
> **Judges' summary**
>
> - **The law is the code.** The federal 1040 rules for tax year 2024 are written in
>   [Catala](https://catala-lang.org): 37 modules, 20,802 lines, with the statute and IRS instructions
>   quoted next to each rule. The Catala compiler type-checks all of it, and 602 named tests pass.
> - **It found 33 places where the IRS's own reference engine (Direct File) does not follow the law.**
>   One (DF-BUG-8) is confirmed by running the IRS engine; the others are cited candidates. 25 were
>   found while writing the statute as Catala next to the Direct File XML, 7 in an earlier review of
>   the Direct File code, and 1 from running Direct File's own test returns. **The type checker
>   itself found none of them**; what it did is make the rules precise enough to compare line by line.
> - **Lean then proves the arithmetic.** The calculator that runs on this site is written in Lean, with
>   9 checked theorems about the whole return and 31 more that tie its pieces to the statute. Lean and
>   Catala are linked by differential testing, not by a proof.

## The headline

The unusual part of this project is the Catala layer, not the Lean layer. The tax law is written as
executable code that reads like the statute: each section of the Internal Revenue Code or the IRS
instructions is quoted, and the rule that implements it sits directly under the quote. The Catala
compiler checks the types and the structure of every rule. The rules then run against the IRS's own
engine on its own test returns.

Writing the law down this precisely, and checking it against the IRS engine, showed where the IRS
reference implementation disagrees with the statute or the instructions. The log has 33 entries
([Direct File bugs](../direct-file-bugs.md)). The calculator follows the law in 30 of them; for 3
(DF-BUG-2, 4 and 10) it keeps Direct File's behaviour until the project owner decides. Every entry is
pinned by a test.

The Lean proofs come after that. They do not say the law is right. They say that the calculator's
arithmetic has properties that hold for every input: for example, you never get a refund and a bill
on the same return.

| | **Verified in Catala** (the headline) | **Proved in Lean** |
|---|---|---|
| What it is | The tax rules written as readable, executable law, checked by the Catala compiler, named tests and the IRS engine | A theorem about the calculator's own code, checked by the Lean kernel |
| Strength | **Evidence**: it agrees with the IRS reference engine on every scenario we have, except where we follow the statute on purpose (each case logged) | A **proof**: it holds for every input, not only the ones we tried |
| Example | "Our rules give the same answer as IRS Direct File on 157 sample returns" | "You never get both a refund and a bill" |
| What it found | 33 places where Direct File disagrees with the law | Nothing about the law. It locks the arithmetic of the calculator. |
| Can it be wrong? | Yes: a rule can be wrong in a way that no sample return exercises | Only if the theorem statement itself says the wrong thing (a human reviews the statements) |

> [!NOTE]
> **Proved** = a Lean theorem holds for every input.
> **Verified** = the Catala rules agree with IRS Direct File on every scenario we have. It is not a proof.

## What the Catala compiler and type checker catch

Measured on Catala 1.3.0. Each error message below comes from running `catala typecheck` or
`catala interpret` on a small file written for this page.

| Check | When | What happens | Message (Catala 1.3.0) |
|---|---|---|---|
| **Static types.** `money` (whole cents), `decimal` (exact fractions), `integer`, `date`, `boolean`, records and enumerations are different types. | Compile time | Rejected | `I don't know how to apply operator + on types money and decimal` |
| **Exhaustive matches.** A `match` on an enumeration must handle every case, for example all five filing statuses. | Compile time | Rejected | `The constructor HeadOfHousehold of enum Status is missing from this pattern matching` |
| **Dependency cycles.** No value can depend on itself, even through a sub-scope (a module call). | Compile time | Rejected | `Cyclic dependency detected between the following variables of scope Return: agi → interest → agi` |
| **Undefined or unused variables.** | Compile time | Warning only | `the variable "amount" is declared but never defined`; `Unused variable: age does not contribute to computing any of scope S outputs` |
| **Conflicting rules.** Two definitions of one variable apply at the same time, and neither is declared an `exception` to the other. | **Run time**, only on an input that triggers both | Evaluation stops | `conflict between multiple valid consequences for assigning the same variable` |
| **No applicable rule.** No definition applies to an input. | **Run time** | Evaluation stops | `no applicable rule to define this variable in this situation` |

> [!WARNING]
> Catala 1.3.0 does **not** find overlapping or missing rules at compile time. A `Conflict` or a
> `NoValue` shows up only when a test or a difftest input reaches it. This page used to say that the
> compiler "flags overlapping or conflicting exceptions"; that was too strong.

**How this code uses the default logic.** The modules do not use Catala's `exception` and `label`
mechanism (0 occurrences). Each scope variable has exactly one definition: 1,417 definitions in the 37
modules, none of them a second definition of the same variable (counted by a script on 2026-11-01).
Choices are written as `if`/`match` inside that one definition. So a `Conflict` cannot happen in this
code. A `NoValue` can, from a conditional definition with no default, and none happened in the 602 tests
or in the difftest runs.

### What the compiler caught or forced in this repository

The history does not record individual type errors. Agents fixed those before committing, and the PRs
report only "typecheck OK". Today `clerk typecheck` on all 37 modules and 42 test files gives
"Typechecking successful!" with one deprecation warning (2026-11-01). The cases below are the ones the
PRs and the source comments record.

| What was written | What the compiler said or forced | How it was resolved | Where |
|---|---|---|---|
| Form 1040 passed the real AGI into the single `Interest` module call. `Interest` needs AGI only for three knockouts, but its interest amount feeds AGI. | A dependency cycle. Catala treats a module call as one node, so one call is a cycle. The PR says "a dependency cycle (verified)". | Two calls: `interest_ko` gets the real AGI and gives only the knockouts; `interest` gets `$0` and gives the amounts. | [`form_1040.catala_en` "Wiring the sub-scopes"](https://github.com/arniber21/ustax/blob/main/catala/form_1040.catala_en), [PR #94](https://github.com/arniber21/ustax/pull/94) |
| Whole return: the HSA knockout reads Social Security line 6a, and line 6b reads the HSA deduction. | A cycle between the two modules. | A second call of the Social Security module, used only for the knockout. | [PR #133](https://github.com/arniber21/ustax/pull/133), [`calculator.catala_en`](https://github.com/arniber21/ustax/blob/main/catala/calculator.catala_en) |
| Whole return: Form 2441 Part III gives line 1e (taxable care benefits, part of income), but the credit needs AGI and tax. | A cycle through income. | Part III is called first with AGI and tax at `$0`, and the credit call gets the real values. A run-time `assertion` checks that both calls give the same line 1e. | [PR #133](https://github.com/arniber21/ustax/pull/133), `calculator.catala_en` (the one `assertion` in the modules) |
| Filing status depends on head-of-household and surviving-spouse qualifying persons, which depend on the dependent tests, which depend on whether the filers file jointly. | A cycle, unless one link is cut. Catala has no fixed point, so a staged design was needed. | The filing status is an input. A status the household does not qualify for is a knockout. | [`CONVENTIONS.md` §7](https://github.com/arniber21/ustax/blob/main/catala/CONVENTIONS.md), [PR #85](https://github.com/arniber21/ustax/pull/85), [PR #128](https://github.com/arniber21/ustax/pull/128) |
| The 1099-R distribution code as a list of `CodeChar` enumeration values. | Each code letter has to be a named case, and every `match` handles them all. | Codes are read as a whole. Unsupported combinations (`7D`, `1`, ...) are knockouts (DF-BUG-1). | [`form1099_rs.catala_en`](https://github.com/arniber21/ustax/blob/main/catala/form1099_rs.catala_en), [PR #102](https://github.com/arniber21/ustax/pull/102) |
| Form 8962 line 5 (household income as a percent of the poverty line) as an integer. | Catala 1.3 has no cast from `decimal` to `integer`. | The value is kept as a `decimal` with a whole value. | [`ptc_family.catala_en`](https://github.com/arniber21/ustax/blob/main/catala/ptc_family.catala_en) |
| A `but replace` record update nested inside a module-call record. | Not a type error: a **bug in Catala 1.3's OCaml backend**. `clerk run` generated OCaml that does not compile. | The updates were moved into their own internal variables (`primary_disability`, `secondary_disability`). | [PR #133](https://github.com/arniber21/ustax/pull/133) |

### Forced explicit decisions

The type system and the literate style also forced decisions that a spreadsheet or a loosely typed
engine can leave implicit:

- **Units and rounding.** `money` is whole cents and `decimal` is an exact fraction, so every place a
  dollar amount is multiplied by a rate has to say how it rounds. Each Direct File `Round` became one
  explicit `R.round_dollar` call with the DF fact path in a comment, and the rounding helpers have their
  own tests ([`CONVENTIONS.md` §4](https://github.com/arniber21/ustax/blob/main/catala/CONVENTIONS.md)).
  This is how three rounding decisions were made and recorded: per-item rounding (DF-BUG-4), cent ties
  (Q-R2) and double rounding (Q-R3).
- **Exact arithmetic.** `decimal` is exact, so Direct File's conversion of a fraction to a dollar
  amount through a 32-bit `Float` (DF-BUG-5) could not be copied by accident. Matching it would have
  needed extra code on purpose.
- **Every deviation is marked.** A rule that keeps a Direct File choice the law does not make has a
  `# QUIRK(Qn)` comment. A rule that follows the law against Direct File has a `# DF-BUG(n)` comment and
  a citation (94 such markers in the modules). Each one is listed in
  [Quirk decisions](https://github.com/arniber21/ustax/blob/main/docs/quirk-decisions.md) with the test
  that pins it.
- **Inputs are complete, and functions are total.** A situation the rules cannot compute is an explicit
  knockout with a reason. The rules never guess.

## Disagreements with the law that formalising in Catala surfaced

We logged 33 places where Direct File (the IRS's open-source reference implementation, "DF" below)
disagrees with the statute or the IRS instructions. The calculator follows the law in 30 of them
(including knocking out a return it cannot compute); for DF-BUG-2, 4 and 10 it keeps Direct File's
behaviour until the project owner decides.

**Discovered by Arnab Ghosh's ustax project.** Full log with the XML line numbers:
[Direct File bugs](../direct-file-bugs.md). The decision for each entry and the test that pins it:
[Quirk decisions](https://github.com/arniber21/ustax/blob/main/docs/quirk-decisions.md).

**How they were found** (counted from the table below; source: the PR bodies and the `# DF-BUG(n)`
comments in `catala/*.catala_en`):

| How found | Count | Entries |
|---|---|---|
| **Encoding**: writing the rule in Catala with the statute quoted, and the DF XML open side by side | 25 | 7, 9, 10, 12 to 33 |
| **Survey**: flagged in the review of the DF code before any Catala was written ([`scope.md`](https://github.com/arniber21/ustax/blob/main/scope.md) §11 and §3.1), then checked against the XML and the law while writing the Catala conventions ([PR #85](https://github.com/arniber21/ustax/pull/85)) | 7 | 1 to 6, 11 |
| **Oracle run, confirmed in the engine**: DF knocked out 4 of its own test returns; tracing it led to the bug, which was confirmed by evaluating the fact in DF's engine | 1 | 8 |
| **Catala compiler or type checker** | **0** | none |

For 8 entries (3, 8, 13, 14, 15, 19, 23, 24) the differential test also shows the difference on real
DF test returns, listed as `knownDivergence` entries in `difftest/mappings/*.mjs`. The other 25 do not
change any value in DF's test returns and are pinned by unit tests only.

> [!NOTE]
> **Status.** Exactly one entry is **confirmed by running the IRS engine**: DF-BUG-8. DF-BUG-5 is an
> arithmetic artefact read in the engine's source (`types/Dollar.scala`), not a tax rule; the log marks
> it "confirmed (engine)". The other 31 are **candidates**: each has a citation and a test, but no one
> outside the project has confirmed them. (The log marks DF-BUG-1 and DF-BUG-7 as "fixed", which means
> our code follows the law; the DF behaviour is still a candidate.)

| ID | What Direct File does | What the law says | Status | How found | Catala |
|---|---|---|---|---|---|
| [DF-BUG-1](../direct-file-bugs.md) | **1099-R codes.** Strips characters from the distribution code, so `7D` is accepted as `7`, and `1` is knocked out as empty | The IRS 1099-R box 7 table: each code has its own meaning; `7D` is not `7` | candidate (fixed) | Survey (#85); encoded in [#102](https://github.com/arniber21/ustax/pull/102) | [form1099_rs:181](https://github.com/arniber21/ustax/blob/main/catala/form1099_rs.catala_en#L181) |
| [DF-BUG-2](../direct-file-bugs.md) | **Education credit.** American opportunity credit is a `$0` stub with no knockout | IRC 25A: eligible filers get the credit | candidate (DF kept, owner to decide) | Survey (#85) | [form_1040:511](https://github.com/arniber21/ustax/blob/main/catala/form_1040.catala_en#L511) |
| [DF-BUG-3](../direct-file-bugs.md) | **Qualifying child.** No tie-breaker when two taxpayers can claim a child | IRC 152(c)(4) | candidate | Survey (#85); difftest: 1 return | [qualifying_child:574](https://github.com/arniber21/ustax/blob/main/catala/qualifying_child.catala_en#L574) |
| [DF-BUG-4](../direct-file-bugs.md) | **Rounding.** Rounds each item, then the sum | 1040 instructions p 23: round only the total | candidate (DF kept, owner to decide) | Survey (scope.md §3.1) | [form_w2s:250](https://github.com/arniber21/ustax/blob/main/catala/form_w2s.catala_en#L250) |
| [DF-BUG-5](../direct-file-bugs.md) | **Engine arithmetic.** Converts a fraction to dollars through a 32-bit `Float` | Exact arithmetic (not a tax rule) | engine source | Survey (scope.md §11) | [test_rounding:78](https://github.com/arniber21/ustax/blob/main/catala/tests/test_rounding.catala_en#L78) |
| [DF-BUG-6](../direct-file-bugs.md) | **Total tax.** Schedule 2 line 21 is defined but not added to total tax | Form 1040 line 24 = line 22 + line 23 | candidate (same value today) | Survey (#85) | [form_1040:447](https://github.com/arniber21/ustax/blob/main/catala/form_1040.catala_en#L447) |
| [DF-BUG-7](../direct-file-bugs.md) | **Student loan interest.** Rounds the phase-out ratio to 3 decimals, then rounds twice more | IRC 221(b)(2)(B): exact ratio | candidate (fixed) | Encoding, [#101](https://github.com/arniber21/ustax/pull/101) | [student_loan_adjustment:82](https://github.com/arniber21/ustax/blob/main/catala/student_loan_adjustment.catala_en#L82) |
| [DF-BUG-8](../direct-file-bugs.md) | **1099-R box 8.** `StripChars(text, "0.")`: its XML reader turns the literal `0.` into the number `0`, so `0.00` looks nonzero. **Wrongly knocks out 4 of Direct File's own test returns.** | A zero percentage is no knockout | **confirmed, engine run** | Oracle run; traced in [#102](https://github.com/arniber21/ustax/pull/102), engine-checked in [#109](https://github.com/arniber21/ustax/pull/109) | [form1099_rs:485](https://github.com/arniber21/ustax/blob/main/catala/form1099_rs.catala_en#L485) |
| [DF-BUG-9](../direct-file-bugs.md) | **1099-MISC.** Treats every 1099-MISC as Alaska Permanent Fund dividend income | Schedule 1 line 8g is only for the Alaska PFD | candidate | Encoding, [#100](https://github.com/arniber21/ustax/pull/100) | [form1099_misc:75](https://github.com/arniber21/ustax/blob/main/catala/form1099_misc.catala_en#L75) |
| [DF-BUG-10](../direct-file-bugs.md) | **Unemployment.** Caps the in-year repayment at box 1 on each form | The 1040 instructions have no such cap | candidate (DF kept, owner to decide) | Encoding, [#100](https://github.com/arniber21/ustax/pull/100) | [unemployment:96](https://github.com/arniber21/ustax/blob/main/catala/unemployment.catala_en#L96) |
| [DF-BUG-11](../direct-file-bugs.md) | **Qualifying child.** A disabled child born on the same day as the filer (a twin) fails the age test | IRC 152(c)(3)(B): a disabled person passes at any age | candidate | Survey; pinned while re-reading the XML (#85); encoded in [#103](https://github.com/arniber21/ustax/pull/103) | [qualifying_child:406](https://github.com/arniber21/ustax/blob/main/catala/qualifying_child.catala_en#L406) |
| [DF-BUG-12](../direct-file-bugs.md) | **HSA.** Splits the family limit by what each spouse contributed ($7,000 where the law gives $5,150) | IRC 223(b)(5)(B)(ii): split equally unless agreed | candidate | Encoding, [#104](https://github.com/arniber21/ustax/pull/104) | [hsa:1117](https://github.com/arniber21/ustax/blob/main/catala/hsa.catala_en#L1117) |
| [DF-BUG-13](../direct-file-bugs.md) | **Schedule R.** Adds cost recovery and rollovers to line 13b | IRC 22(c)(3)(A), Schedule R instructions p R-5 | candidate | Encoding, [#106](https://github.com/arniber21/ustax/pull/106); difftest: 33 checks in 21 returns | [elderly_and_disabled:30](https://github.com/arniber21/ustax/blob/main/catala/elderly_and_disabled.catala_en#L30) |
| [DF-BUG-14](../direct-file-bugs.md) | **Saver's credit.** Zeroes an ineligible spouse's distributions in both columns | IRC 25B(d)(2)(D), Form 8880 line 4 | candidate | Encoding, [#107](https://github.com/arniber21/ustax/pull/107); difftest: 2 returns | [savers_credit:371](https://github.com/arniber21/ustax/blob/main/catala/savers_credit.catala_en#L371) |
| [DF-BUG-15](../direct-file-bugs.md) | **Qualifying relative.** Counts the filer's own qualifying child as a qualifying relative | IRC 152(d)(1)(D): "not a qualifying child of such taxpayer" | candidate | Encoding, [#108](https://github.com/arniber21/ustax/pull/108); difftest: 2 persons | [qualifying_relative:49](https://github.com/arniber21/ustax/blob/main/catala/qualifying_relative.catala_en#L49) |
| [DF-BUG-16](../direct-file-bugs.md) | **Qualifying relative.** Reads "qualifying child of another taxpayer?" only behind its own age gate | IRC 152(c), (d)(1)(D) | candidate | Encoding, [#108](https://github.com/arniber21/ustax/pull/108) | [qualifying_relative:130](https://github.com/arniber21/ustax/blob/main/catala/qualifying_relative.catala_en#L130) |
| [DF-BUG-17](../direct-file-bugs.md) | **Earned income credit.** Combat-pay variants pay $1 to $2 where the credit is $0 | IRC 32: $0 with no earned income or past the phase-out | candidate | Encoding, [#112](https://github.com/arniber21/ustax/pull/112) | [eitc:306](https://github.com/arniber21/ustax/blob/main/catala/eitc.catala_en#L306) |
| [DF-BUG-18](../direct-file-bugs.md) | **Divorced parents.** Never asks about a multiple support agreement | IRC 152(e)(5): no Form 8332 split under one | candidate | Encoding, [#115](https://github.com/arniber21/ustax/pull/115) | [dependents_benefit_split:50](https://github.com/arniber21/ustax/blob/main/catala/dependents_benefit_split.catala_en#L50) |
| [DF-BUG-19](../direct-file-bugs.md) | **Head of household.** "Considered unmarried" through any child, claimable or not | IRC 7703(b)(1): only a child the filer can claim | candidate | Encoding, [#121](https://github.com/arniber21/ustax/pull/121); difftest: 1 person, 4 filing-status graphs ([#128](https://github.com/arniber21/ustax/pull/128)) | [hoh_qss_persons:66](https://github.com/arniber21/ustax/blob/main/catala/hoh_qss_persons.catala_en#L66) |
| [DF-BUG-20](../direct-file-bugs.md) | **Head of household.** The dependent must actually be claimed | IRC 2(b)(1)(A)(ii): the filer must be entitled to claim | candidate | Encoding, [#121](https://github.com/arniber21/ustax/pull/121) | [hoh_qss_persons:519](https://github.com/arniber21/ustax/blob/main/catala/hoh_qss_persons.catala_en#L519) |
| [DF-BUG-21](../direct-file-bugs.md) | **Head of household.** Excludes a married child also for no TIN or a custody release | IRC 2(b)(1)(A)(i): only joint return or citizenship | candidate | Encoding, [#121](https://github.com/arniber21/ustax/pull/121) | [hoh_qss_persons:135](https://github.com/arniber21/ustax/blob/main/catala/hoh_qss_persons.catala_en#L135) |
| [DF-BUG-22](../direct-file-bugs.md) | **Head of household.** Admits a relative the filer cannot claim (custody split) | IRC 2(b)(1)(A)(ii) | candidate | Encoding, [#121](https://github.com/arniber21/ustax/pull/121) | [hoh_qss_persons:378](https://github.com/arniber21/ustax/blob/main/catala/hoh_qss_persons.catala_en#L378) |
| [DF-BUG-23](../direct-file-bugs.md) | **Child care credit.** A foster parent or grandparent gets the credit through the Form 8332 split (credit $702 where the law gives $602) | IRC 21(e)(5), Form 2441 instructions p 1, Pub 503 p 4: custodial parent only | candidate | Encoding, [#129](https://github.com/arniber21/ustax/pull/129); difftest: 6 facts, 1 return | [cdcc:41](https://github.com/arniber21/ustax/blob/main/catala/cdcc.catala_en#L41) |
| [DF-BUG-24](../direct-file-bugs.md) | **Child care credit.** AGI of $0 or less gives a 0 percentage | IRC 21(a)(2): 35% | candidate | Encoding, [#129](https://github.com/arniber21/ustax/pull/129); difftest: 3 facts, no credit changes | [cdcc:45](https://github.com/arniber21/ustax/blob/main/catala/cdcc.catala_en#L45) |
| [DF-BUG-25](../direct-file-bugs.md) | **Child care credit.** Married filing separately exception tests two possibly different people | IRC 21(e)(4): one household | candidate | Encoding, [#129](https://github.com/arniber21/ustax/pull/129) | [cdcc:47](https://github.com/arniber21/ustax/blob/main/catala/cdcc.catala_en#L47) |
| [DF-BUG-26](../direct-file-bugs.md) | **Child care credit.** Surviving spouse's line 19 comes out `$0` | Form 2441 line 19: "all others" use line 18 | candidate | Encoding, [#129](https://github.com/arniber21/ustax/pull/129) | [cdcc:51](https://github.com/arniber21/ustax/blob/main/catala/cdcc.catala_en#L51) |
| [DF-BUG-27](../direct-file-bugs.md) | **Child care credit.** Ignores forfeited benefits unless W-2 box 10 is positive | Form 2441 line 14 covers line 12 or 13 | candidate | Encoding, [#129](https://github.com/arniber21/ustax/pull/129) | [cdcc:54](https://github.com/arniber21/ustax/blob/main/catala/cdcc.catala_en#L54) |
| [DF-BUG-28](../direct-file-bugs.md) | **Child care credit.** Requires the filer to have chosen to claim the child | IRC 21(b)(1)(A): a dependent the filer may claim | candidate | Encoding, [#129](https://github.com/arniber21/ustax/pull/129) | [cdcc:56](https://github.com/arniber21/ustax/blob/main/catala/cdcc.catala_en#L56) |
| [DF-BUG-29](../direct-file-bugs.md) | **Earned income credit.** The qualifying child must be claimed | IRC 32(c)(3): no claim required | candidate | Encoding, [#133](https://github.com/arniber21/ustax/pull/133) | [calculator:389](https://github.com/arniber21/ustax/blob/main/catala/calculator.catala_en#L389) |
| [DF-BUG-30](../direct-file-bugs.md) | **Earned income credit.** A married child must be a claimed dependent | IRC 32(c)(3)(B): the filer need only be entitled to claim | candidate | Encoding, [#133](https://github.com/arniber21/ustax/pull/133) | [calculator:393](https://github.com/arniber21/ustax/blob/main/catala/calculator.catala_en#L393) |
| [DF-BUG-31](../direct-file-bugs.md) | **Premium tax credit.** A policy starting December 1 never counts December ($0 where the law gives $500) | Form 8962 instructions: in effect on the 1st counts | candidate | Encoding, [#135](https://github.com/arniber21/ustax/pull/135) | [ptc_allowed:543](https://github.com/arniber21/ustax/blob/main/catala/ptc_allowed.catala_en#L543) |
| [DF-BUG-32](../direct-file-bugs.md) | **Premium tax credit.** Uses annual totals for a January-to-December policy with fewer than 12 coverage months ($6,000 where the law gives $5,500) | Form 8962 instructions: annual only with all 12 months | candidate | Encoding, [#135](https://github.com/arniber21/ustax/pull/135) | [ptc_allowed:558](https://github.com/arniber21/ustax/blob/main/catala/ptc_allowed.catala_en#L558) |
| [DF-BUG-33](../direct-file-bugs.md) | **Premium tax credit.** Annual totals if *any* Form 1095-A qualifies | Form 8962 instructions: *each* plan | candidate | Encoding, [#135](https://github.com/arniber21/ustax/pull/135) | [ptc_allowed:770](https://github.com/arniber21/ustax/blob/main/catala/ptc_allowed.catala_en#L770) |

Line numbers in the Catala column are on `main` on 2026-11-01. To find a marker after the files change,
search for `DF-BUG(n)`. Some older comments use provisional labels; see Questions 8 in
[Quirk decisions](https://github.com/arniber21/ustax/blob/main/docs/quirk-decisions.md).

## How Catala is checked against the IRS

1. **The type checker.** `clerk typecheck` on all 37 modules and 42 test files: "Typechecking
   successful!" (2026-11-01, Catala 1.3.0; one deprecation warning). It runs in `make check` and in CI.
2. **Named tests.** `clerk test`: 602 of 602 test scopes pass (2026-11-01). Each module has
   hand-worked examples from the forms and instructions, tests that a known-wrong output is rejected,
   and one test per DF-BUG entry that asserts the law's value and not Direct File's
   ([Quirk decisions](https://github.com/arniber21/ustax/blob/main/docs/quirk-decisions.md)).
3. **Differential test against the Direct File engine.** The IRS Direct File project ships 161 test
   returns. We run its engine on them to get the expected value of every fact (`oracle/facts.csv`), then
   run the whole-return Catala scope on the same answers and compare. 4 returns are knocked out by DF
   itself (all 4 are DF-BUG-8), so 157 are compared. Result for `make difftest SCOPE=calculator`:
   **157 of 157 returns and 5,360 of 5,360 fact checks pass** (754 oracle values are incomplete and not
   checked). 9 checks are reported apart as known divergences and never counted as passes: DF-BUG-3,
   DF-BUG-23, and one return whose chosen filing status DF's own validity check rejects. Source:
   [STATUS.md](https://github.com/arniber21/ustax/blob/main/STATUS.md), [PR #136](https://github.com/arniber21/ustax/pull/136),
   re-run on 2026-11-01.

The runner, its mappings and the knocked-out scenarios are described in
[`catala/DIFFTEST.md`](https://github.com/arniber21/ustax/blob/main/catala/DIFFTEST.md).

## What Lean adds

The calculator that runs behind this site is written directly in Lean. Statements about it are checked
by Lean's kernel, with no `sorry` and no extra axioms.

- **Comparator-checked statements** (`lean/comparator.json`, 9 theorems): the tax on taxable income
  never decreases as taxable income increases with filing status fixed, and is never negative; line 16
  equals the printed IRS Tax Table for every cent below $100,000 and the Tax Computation Worksheet
  from $100,000 through $1 trillion; refund and amount owed are both non-negative, at most one is non-zero, and their difference is payments minus tax; credits never
  exceed the tax they offset; the earned income credit stays between zero and its maximum.
- **Additional statements** (`lean/comparator.extra.json`, 31 theorems): for example, the standard
  deduction, interest, W-2 totals, Social Security and the adjustments equal a plain statement of the
  statute for every input, and on the whole return `supported = false` exactly when the list of
  reasons is not empty.
- **The checks around them.** `make audit` rejects `sorry`, new axioms and `native_decide`, and scans
  for vacuous or contradictory statements. `make comparator` replays the proofs in a sandbox against a
  fixed file of statements.

> [!WARNING]
> **The honest limit.** The Lean calculator and the Catala rules are linked by **differential testing,
> not by a proof**: both run on the same inputs and the results are compared. A Lean theorem proves a
> property of the Lean code. It does not prove that the Lean code computes the Catala rules, or that the
> Catala rules are the law. [Catala to Lean](../catala-to-lean.md) explains why we did not build a
> translator, and what that choice costs.

See [Spec surface](../spec-surface.md) for the exact definitions each theorem depends on, and
[Comparator and lake check](../comparator.md) for how the checks run.

## What you still have to trust

- The Lean kernel, and the Lean server and JSON reader that sit between your browser and the calculator.
- The theorem **statements** (the spec files). A proof only shows the code meets the statement, so a
  human has to confirm the statements say what they should. See [Spec surface](../spec-surface.md).
- The Catala rules as a reading of the law. They are written next to the quoted text so that a person
  can check them, but no tool checks that a rule means what the statute means.
- The IRS Direct File engine, as the reference we compare against. It is a government project, but it
  has bugs, which is why we log them.
- The Catala toolchain, but only for tests: the running calculator does not use it.

## What is not covered

Federal income tax for tax year 2024 only, with the standard deduction only. Anything outside the
supported situations is refused with a reason, not guessed. Nothing is filed, and this is not tax
advice.
