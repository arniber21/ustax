# sources/CATALA_PATTERNS.md: what existing Catala code teaches us

Toolchain here: Catala 1.3.0, `clerk`. Snippets marked **[verified 1.3.0]** were compiled and run with `clerk test` in a scratch directory outside the repo on 2026-10-31. Snippets quoted from `reference-catala/` are shown as-is and are **not** verified against 1.3.0 (a compile of the us_tax_code example was blocked by the sandbox, so treat its older syntax with care; it was written for an earlier Catala).

## What is cloned, and licenses

All under `sources/reference-catala/` (shallow, depth 1, taken 2026-10-28 to 2026-10-31). Sizes include `.git`.

| Repo | Size | License | Reuse? |
|---|---|---|---|
| `catala-examples` (https://github.com/CatalaLang/catala-examples) | 13 MB | Apache-2.0 (`LICENSE.txt`). **Exception:** `impot_revenu/` carries its own `LICENSE` (CeCILL v2.1, copyleft) | Yes for `us_tax_code/`, `smic/`, `polish_taxes/` etc. Do not copy from `impot_revenu/` |
| `catala` (compiler, stdlib, runtime, tests) | 17 MB | Apache-2.0 (`LICENSE.txt`) | Yes. Most useful: `stdlib/*.catala_en`, `runtimes/ocaml/catala_runtime.ml` (rounding), `tests/` |
| `catala-book` (docs) | 12 MB | CC-BY-4.0 (`LICENCE.txt`) | Quote with attribution; read `src/en/` |
| `french-law` | not cloned (33 MB) | Apache-2.0 | Skipped; `catala-examples` already holds the French examples |

Total `reference-catala/` is about 42 MB; all of `sources/` is about 62 MB. `reference-catala/*/.git` is the bulk of what is not source. Delete the `.git` directories if you want to commit the trees; note that Apache-2.0 requires keeping the license files.

**There is no IRC section 2, 21, 24 or 32 in any Catala repo.** The only US tax code in the Catala organisation is `catala-examples/us_tax_code/`, which formalizes **IRC 121** (home sale exclusion, 486 lines plus 201 lines of tests) and **IRC 132** (fringe benefits, 141 lines plus 67 lines of tests). It is useful as a style model for citing statute, not as reusable logic.

## 1. Money and rounding

- `money` is an integer number of cents. `money * decimal` and `money of decimal` round to the nearest cent, **half away from zero** (`runtimes/ocaml/catala_runtime.ml` lines 107-139: `round`, `money_of_decimal`, `money_round`). `round of <money>` rounds to the nearest whole dollar with the same half-away rule (`$12.50` gives `$13`, `-$12.50` gives `-$13`).
- Consequence for us: Direct File's `Round` is `HALF_UP` on `BigDecimal`, which is also "away from zero" on ties, so `round of` agrees with it for all signs. Direct File builds `Dollar` values with `HALF_EVEN` at scale 2 (scope.md §8). A tie only matters for sub-cent products such as `0.0765 * $x` where the exact product ends in half a cent; Catala will round that up where HALF_EVEN may not. Log this under issue #60 and test it in #6/#7.
- Intermediate rounding is the programmer's job; the book says to round at each step so a reviewer can follow with a desk calculator (`catala-book/src/en/4-2-catala-specific.md`, "How to round money up or down to a specific precision?").
- Stdlib helpers (in `catala/stdlib/money_en.catala_en`, no `> Using` needed, referenced as `Money.xxx`): `min`, `max`, `ceiling`, `floor`, `positive` (floor at `$0`), `truncate`, `round_by_excess` (round up to next dollar), `round_by_default`, `round_to_decimal of m, n`, `sum`.
- **[verified 1.3.0]** Round up to the next 1,000 (the Schedule 8812 line 10 rule): `Money.round_to_decimal of (excess + $499.99), -3` gives `$1,000` for `$1,000` and `$2,000` for `$1,000.01`.
- Percentages are decimals: `12%` is `0.12`, `15%` literal is allowed.

## 2. Scopes versus modules, and file naming

- One **module per file**: first line `> Module Foo`. Other files import with `> Using Foo` or `> Using Foo as F` and reference `F.Scope`, `F.Struct` (`catala-book/src/en/5-6-modules.md`). The standard library (`Money`, `Decimal`, `List`, `Date`, ...) is always available with no import (`5-7-standard-library.md`).
- us_tax_code uses a master module that only includes the pieces, so one module spans several files:

```
# catala-examples/us_tax_code/us_tax_code.catala_en
> Module Us_tax_code
> Include: preamble.catala_en
> Include: section_121.catala_en
> Include: section_132.catala_en
```

  and `preamble.catala_en` holds shared types (`Person`). Tests live in `us_tax_code/tests/test_section_121.catala_en` with `> Using Us_tax_code as T`. The `clerk.toml` target is:

```toml
# catala-examples/clerk.toml
[[target]]
name = "us-tax-code"
modules = ["Us_tax_code"]
backends = ["ocaml"]
tests = ["us_tax_code/tests/"]
```

- File naming: `<topic>.catala_en` for code, `tests/test_<topic>.catala_en` for tests. Suggested for us: `catala/irc_32.catala_en` (module `Irc_32`), `catala/irc_24.catala_en`, and a single `catala/params_2024.catala_en` for inflation-adjusted figures with a citation per constant.
- Scope design in us_tax_code: a scope holds `input`, `internal`, `context`, and `output` variables; a larger scope calls smaller ones as sub-scopes, one variable per sub-scope instance (`section121Person1 scope Section121SinglePerson`) and wires arguments with `definition section121Person1.date_of_sale_or_exchange equals ...`. A two-pass scope is used to break a circular dependency between "who qualifies" and "what the cap is" (`Section121TwoPasses` in `section_121.catala_en`). **This is the pattern for the filing status / dependents / credits cycle in scope.md §5.4**: run the same scope twice, feed pass-one outputs into pass two as inputs.
- Catala has no recursion and no mutual recursion between scope variables. The source says so directly: "in the current semantics we can't do that because we don't allow for recursion" (comment above `income_excluded_from_gross_income` in `section_121.catala_en`).

## 3. Citing statute: literate programming

Catala files are Markdown. Headings carry the legal structure; plain text carries the **verbatim law**; ` ```catala ` blocks carry the rules. Declarations go in ` ```catala-metadata ` blocks, usually near the top.

From `us_tax_code/section_121.catala_en` (older syntax in this file, shown for structure):

~~~~
## Section 121
...
### (a) Exclusion

Gross income shall not include gain from the sale or exchange of property if,
during the 5-year period ending on the date of the sale or exchange, such
property has been owned and used by the taxpayer as the taxpayer’s principal
residence for periods aggregating 2 years or more.

```catala
scope Section121SinglePerson:
  # Regulation 1.121-1(c)(1): 2 years = 730 days
  rule requirements_ownership_met
  under condition aggregate_periods_from_last_five_years of property_ownage >= 730 day
  consequence fulfilled
```

#### (1) In general
The amount of gain excluded ... shall not exceed $250,000.
...
~~~~

Conventions seen: `##` section, `###` subsection (a), `####` paragraph (1), `#####` subparagraph (A), clauses `(i)` as plain paragraphs; regulation citations in code comments; open questions as `# TODO` and `# Reasonably it should.` comments next to the code.

French-law style pairs the heading with the official identifier (`catala-examples/smic/smic.catala_fr`): `### Article 1 | JORFARTI000037833214`. For the US there is no equivalent id. Use a heading plus a stable cite, for example:

```
### 26 U.S.C. § 32(b)(1) | uscode:2024:26:32:b:1
```

and keep the quoted text identical to `sources/statute/irc-32.html`. For IRS-authored rules (forms, Rev. Proc.) quote the line text and add a comment with file and PDF page, for example `# Rev. Proc. 2023-34 §3.06(1), sources/revproc/rp-23-34.pdf p 9`.

## 4. Exceptions and justifications for legal override

Catala's default-logic model: a `definition` can have an `under condition`; several definitions of one variable that fire together conflict (a runtime error) unless one is declared an `exception` to the other (`catala-book/src/en/5-4-definitions-exceptions.md`). Exceptions form a tree; use `label` on the base case and `exception <label>` on the override.

**[verified 1.3.0]** Dependent-filer standard deduction as an override of the base amount (IRC 63(c)(5), Rev. Proc. 2023-34 §3.15):

~~~~catala
> Module Sd

```catala-metadata
declaration enumeration FilingStatus:
  -- Single
  -- MarriedFilingJointly
  -- HeadOfHousehold

declaration scope StandardDeduction:
  input filing_status content FilingStatus
  input is_dependent condition
  input earned_income content money
  output amount content money

scope StandardDeduction:
  label base definition amount equals
    match filing_status with pattern
    -- Single : $14,600
    -- MarriedFilingJointly : $29,200
    -- HeadOfHousehold : $21,900

  exception base definition amount
  under condition is_dependent
  consequence equals
    Money.min of
      (match filing_status with pattern
       -- Single : $14,600
       -- MarriedFilingJointly : $29,200
       -- HeadOfHousehold : $21,900),
      (Money.max of $1,300, earned_income + $450)
```
~~~~

us_tax_code uses the same mechanism for the IRC 121(b)(2)(A) joint-return override of the $250,000 cap:

```catala
  exception
  definition gain_cap
  under condition section_121_b_2_A_condition
  consequence equals
    $500,000
```

Use cases for us: standard deduction for dependents (above), the CTC/ODC ordering (last, limited by remaining tax), Form 8332 release overriding the custodial parent rule, MFS special rules in EITC, and all **knockouts**: model each as a boolean `rule unsupported_x under condition ... consequence fulfilled` and aggregate with `or`; the bool conditions are `condition`-typed variables that default to `false` (`catala-book/src/en/5-4-definitions-exceptions.md`, "Scope variables that are `condition`"). Keep legal-override exceptions separate from the "reference-implementation quirks" decided under issue #60 by labelling quirk rules in comments (`# QUIRK: Direct File ...`).

Time dependence: `smic/smic.catala_fr` gates each year's amounts with `sous condition date_courante >= |2019-01-01| et date_courante <= |2019-12-31|` and asserts a minimum date at scope level. For TY2024-only code a single `> Module Params_2024` module avoids that; if later years are added, copy the smic pattern.

## 5. Tests

- Assertion tests are the Catala team's recommended primary method (`catala-book/src/en/3-3-0-test-ci.md`). Mark a scope `#[test]`, call the scope under test as a sub-scope, and `assertion` on outputs. Run with `clerk test`.
- **[verified 1.3.0]**:

```catala
#[test]
declaration scope T1:
  s scope Tax.Schedule
  s2 scope Tax.Schedule

scope T1:
  definition s.taxable_income equals $50,000
  definition s2.taxable_income equals $1,000,000
  assertion (s.tax = $6,053)
  assertion (s2.tax = $328,188)
```

- Pitfall: a `#[test]` scope with no `assertion` always passes (book warning).
- `clerk run file.catala_en --scope=Name` prints outputs for exploration. "Cram" tests compare terminal output text, an alternative.
- Test data layout in us_tax_code: a `Data` scope with named `output` fixtures (`person_ok_1`, `person_ko_1`), then `Test1`, `Test2`, ... scopes using them (`us_tax_code/tests/test_section_121.catala_en`). Good fit for the oracle scenarios: one fixture scope per scenario.
- Catala has no property-based testing and no proofs. Rounding of the Tax Table and PTC applicable figure should be checked with the generated CSV in `sources/forms-instructions/derived-tax-table-2024.csv` and a driver script (#6/#7).

## 6. Tax brackets in Catala

No existing Catala code implements US brackets. Best idea: store brackets as a `list of Bracket` with lower bound, upper bound and rate, and sum the slice of income in each bracket (marginal form). This reproduces Rev. Proc. 2023-34 tables exactly without storing the cumulative bases, which removes one class of transcription error. **[verified 1.3.0]** Single filer 2024:

~~~~catala
> Module Tax

```catala-metadata
declaration structure Bracket:
  data lower content money
  data upper content money
  data rate content decimal

declaration scope Schedule:
  input taxable_income content money
  internal brackets content list of Bracket
  output tax content money

scope Schedule:
  definition brackets equals [
    Bracket { -- lower: $0 -- upper: $11,600 -- rate: 10% };
    Bracket { -- lower: $11,600 -- upper: $47,150 -- rate: 12% };
    Bracket { -- lower: $47,150 -- upper: $100,525 -- rate: 22% };
    Bracket { -- lower: $100,525 -- upper: $191,950 -- rate: 24% };
    Bracket { -- lower: $191,950 -- upper: $243,725 -- rate: 32% };
    Bracket { -- lower: $243,725 -- upper: $609,350 -- rate: 35% };
    Bracket { -- lower: $609,350 -- upper: $100,000,000 -- rate: 37% }
  ]
  definition tax equals
    round of Money.sum of
      (map each b among brackets to
        (Money.positive of ((Money.min of taxable_income, b.upper) - b.lower)) * b.rate)
```
~~~~

Gotchas found while writing this: `maximum init ...` / `such that ... is maximum` aggregation syntax from older versions does not parse in 1.3.0; use `map each ... among ... to` with `Money.sum`. The module has `> Module Tax` at the top and tests use `> Using Tax`; `Money_en` must not be imported (the stdlib is automatic, and `> Using Money_en` fails with "Required module not found").

For the published Tax Table (TI under 100,000), compute the midpoint per scope.md §2.1 and then apply the schedule; the CSV in `forms-instructions/` confirms 8,240 of 8,240 values.

## 7. The five most reusable findings

1. **Two-pass scopes break circular dependencies** (`us_tax_code/section_121.catala_en`, scopes `Section121TwoPersons` and `Section121TwoPasses`). Directly applicable to the filing-status / dependent / credit cycle (scope.md §5.4) and to the Saver's credit and Schedule 8812 limits that depend on earlier credits.
2. **Statute as the document**: quote the law verbatim under headings that mirror the section numbering, put rules in ` ```catala ` blocks directly under the paragraph they implement, put regulation cites and open questions in comments (`us_tax_code/section_121.catala_en`; `smic/smic.catala_fr` for the `| id` heading convention). Reviewers then read the spec as the law.
3. **`label` / `exception <label>` is the legal-override mechanism** and it is verified to work on 1.3.0 (std deduction example above). Use it for all "except as provided in..." clauses and the knockout structure; the compiler flags ambiguous or conflicting definitions, which makes missing exceptions visible.
4. **Rounding is explicit and half-away-from-zero**: `round of` for dollars, `Money.round_to_decimal of x, -3` for round-up-to-1,000, `Money.positive/min/max` for floors and caps. Matches Direct File `Round` HALF_UP; the only divergence risk is Direct File's HALF_EVEN dollar construction (issue #60) and its Float-based rational conversion (scope.md §11 item 10).
5. **`#[test]` scopes with `assertion`, run by `clerk test`**, plus `clerk run --scope=` for ad hoc output. No special framework needed; one fixture scope per oracle scenario in the `Data` / `TestN` layout of `us_tax_code/tests/`. Pair with the derived Tax Table CSV for the rate-schedule pilot (#10, #41).

## Other notes

- `Ideas for pair programming.md` in `us_tax_code/` is a collaboration note, not code.
- `catala/tests/` holds the compiler's regression suite by feature (`exception`, `money`, `modules`, `enum`, ...). It is the best place to look up valid 1.3.0 syntax for any single feature.
- Not yet explored: JSON support (`catala-book/src/en/5-8-3-json-support.md`) for #49 (API schema), and `Date`/`Duration` for age and day-before-birthday rules (`catala/stdlib/date_en.catala_en`).
