# US Tax: a formally verified income tax calculator

*Draft hackathon write-up. Numbers are as of 2026-11-01 unless marked otherwise, and each says where it
came from. Places where a number will change before the final version carry a `TODO(final)` marker;
they are listed at the end.*

## Why

Tax software is a program that tells you how much money you owe the government. People trust it
because they cannot check it. Mistakes happen in commercial and government software alike, and when
they do, they repeat on every return that takes the same path.

The tax code is also unusually well suited to being written as code. It is long, but each rule is
small and precise: "line 15 is line 11 minus line 14, but not less than zero." There is a movement
called *rules as code* that argues the law should be published in a form a computer can run, so that
everyone runs the same rules. [Catala](https://catala-lang.org), a programming language built for
writing laws, came out of that movement.

We wanted to push one step further: not only run the rules, but **prove** things about the program
that runs them. And then check that program, as carefully as we could, against both the law and the
IRS's own implementation.

## What we built

US Tax is a web app that computes a 2024 US federal income tax return (Form 1040) for the kinds of
returns IRS Direct File handled: wages, interest, unemployment, Social Security, some retirement income,
the standard deduction and the common credits. You answer questions; it shows your refund or balance
due, line by line. If your return is outside its scope (for example, you have bond interest), it stops
and says so, instead of guessing. Direct File calls this a *knockout*.

Under the web app there are three layers:

```
  Law (forms, instructions, IRC, Rev. Proc. 2023-34)
    -> Catala rules        readable spec, written next to the legal text; test oracle
    -> Lean code + proofs  the calculator that runs, and theorems about it
    -> Lean HTTP server    Std.Http from Lean core, plain HTTP
    -> React web app       questions and results; no tax logic
```

Our yardstick is **IRS Direct File**, the IRS's free filing tool, whose source code was released into
the public domain. It contains a tax engine and 161 test returns. We run that engine on its own test
returns and record every value it produces (83,488 rows in `oracle/facts.csv`, per `oracle/README.md`).
That gives us a third, independent opinion on every number.

## Why Catala and Lean, and why both

**Catala** reads like the law. A rule in Catala sits next to the paragraph of the statute it implements,
and its exceptions are written the way the statute writes them ("except when..."). A tax expert who does
not program can review it. As of 2026-11-01 there are 33 Catala source files in `catala/` and 40 test files
in `catala/tests/`, and `make check` reported 531 of 531 Catala tests passing (PR #135).
<!-- TODO(final): update numbers -->

**Lean** is a programming language with a proof checker built in. A Lean theorem is checked by a small
kernel, so you do not have to trust whoever (or whatever) wrote the proof, only the statement.

The obvious plan was to write the rules in Catala and translate them into Lean automatically. We looked
for a translator first (`docs/catala-to-lean.md`, §2). Catala 1.3.0 has no Lean backend, and nothing
upstream was close. Writing one was estimated at 50 to 80 hours before any proof work, and its output
would look like compiler internals, so we would need a readable layer on top anyway. Writing the
calculator directly in Lean was estimated at 40 to 85 hours for about 15 modules (same document, §1).

So the decision (made by the human, recorded in `STATUS.md`) was:

- **Write the calculator directly in Lean.** The proofs are about the code that runs.
- **Keep Catala as the readable spec and test oracle.**
- **Link the two by differential testing**: run Catala, Lean and Direct File on the same inputs and
  compare every value, exactly, in cents.

This means the link between "the law as written in Catala" and "the Lean program" is a test, not a
proof. We say that everywhere, including in the README.

Doing this by hand meant copying Catala's arithmetic exactly. The spike measured why that matters
(`docs/catala-to-lean.md`, §3.2). If you drop one cent-rounding step in the tax calculation, single-filer
tax changes on 971 of 200,000 cent values between $100,000 and $102,000. If you round half to even instead
of half away from zero, it changes on 30,700 of 100,000 dollar values below $100,000. Rounding is not a
detail. The Lean money library reproduces both counts as a regression test
(`lean/UsTax/Money/Regression.lean`).

## What is proved

The main theorems are about the Lean calculator's own functions (`tentativeTaxFor`, `form1040`). Their
statements live in `lean/UsTax/Comparator/Challenge.lean`, the properties they use in
`lean/UsTax/Spec/`, and the proofs in `lean/UsTax/Proofs/Main.lean`. `docs/spec-surface.md` lists every
definition each statement depends on and reviews them. All of them hold for every input, with no
hypotheses beyond the arguments.

| Theorem (namespace `UsTax.Main`) | In plain words |
|---|---|
| `tentativeTax_nonneg_monotone` | The tax on Form 1040 line 16 is never negative, and never decreases when taxable income increases, for each filing status. |
| `tentativeTax_matches_tax_table` | For every taxable income below $100,000, line 16 equals the amount printed in the 2024 Tax Table, in the right column for the filing status. |
| `line16_matches_tax_table` | The same, for line 16 as computed inside a full Form 1040. |
| `refund_balanceDue_consistent` | Refund and amount owed are both nonnegative, at most one is nonzero, and refund minus owed equals payments minus tax. This pins down lines 34 and 37 exactly. |
| `credits_within_liability` | Line 22 equals the larger of zero and line 18 minus line 21: credits can bring tax to zero, not below. |
| `totalTax_nonneg` | Total tax (line 24) is never negative. |

These six are the set that **Comparator** checks (`lean/comparator.json`). `lake check` replays the whole
build through the Lean kernel; `lake comparator` checks that the proved statements are exactly the trusted
ones in `Challenge.lean` and use only the allowed axioms (`propext`, `Quot.sound`, `Classical.choice`).

Some supporting results are worth naming:

- `TaxRates.tentativeTaxFor_eq_taxSpec` (`lean/UsTax/TaxRates/Spec.lean`): the code equals a readable
  version of the rate schedules ("$B plus R% of the excess over $X"), for every filing status and every
  income up to $1 trillion. It is proved but not yet in the Comparator set.
- `Proofs.rows_chain` and `Proofs.rows_cover` (`lean/UsTax/Proofs/TaxTable.lean`): the 2,062 Tax Table
  rows cover every cent from $0 to $100,000 with no gap or overlap. They were added in PR #132, which
  fixed a real gap: the first version of our table data was missing the rows for $5 to $25. These theorems
  would now catch such a gap.
- `Api.parseRequest_sound` and `Api.validate_sound` / `validate_complete` (`lean/UsTax/Api/`): the
  server only computes on requests that satisfy the validity predicate, and accepts all that do.

Counting: `make audit` reported 901 theorems passing the axiom audit (PR #134, 2026-11-01). That number
includes many small lemmas. We would rather be judged on the six above. <!-- TODO(final): update numbers -->

Two statements are written but not proved yet (`lean/UsTax/Comparator/Pending.lean`): the earned income
credit stays within its legal bounds, and each nonrefundable credit is limited by the tax left after the
credits before it. They wait on the Lean credit modules. <!-- TODO(final): update numbers -->

## What is tested

The differential-testing harness (`difftest/`) runs each Catala module, and each Lean module, on the
inputs of every Direct File test return, and compares each output with the Direct File value. Of the 161
returns, the Direct File engine refuses 4 because of a bug we found (DF-BUG-8 below), leaving 157.
A *known divergence* is a value where we deliberately follow the law instead of Direct File; each one is
logged.

| What | Result | Source |
|---|---|---|
| Whole-return Catala calculator vs Direct File | 151 of 151 runnable returns pass; 4,677 of 4,677 values; 9 known divergences; 6 returns waiting on the premium tax credit | PR #133 |
| Catala premium tax credit (Form 8962 lines 9 to 25) | 157 of 157 returns; 4,221 of 4,221 values | PR #135 |
| Lean Form 1040 with income modules plugged in, three-way | 3,297 values agree across 157 returns; 0 failures | PRs #117, #125 |
| Lean household modules (filers, filing status, dependents), three-way | 0 failures; 4 known divergences on filing-status test graphs (DF-BUG-19) | PR #134 |

<!-- TODO(final): update numbers (scenario counts, PTC status) -->

Every harness has a **negative control**: `DIFFTEST_PERTURB=1` and `LEAN_DIFFTEST_PERTURB=1` change the
outputs on purpose, and the run must fail. It does (PRs #111, #117, #135). A harness that cannot fail
proves nothing.

The honest gap: today the **running server** uses less of the Lean calculator than the Catala calculator
covers. The server computes W-2 wages, interest, the standard deduction, tax, withholding and the refund
or balance due. It accepts other income and adjustments but reports them as "not yet used"
(`lean/UsTax/Api/Bridge.lean`, `unwiredSections`). The Lean credit modules are not written yet.
<!-- TODO(final): update which modules the server runs -->

## Bugs in the reference implementation

Writing each rule next to the statute means reading Direct File's configuration and the law side by
side. Where they disagree, our policy (set by the human) is that **the statute wins**, and we log the
difference in `docs/direct-file-bugs.md`. As of 2026-11-01 the log has 33 entries:

- **1 confirmed by running the Direct File engine (DF-BUG-8).** Direct File decides whether the Form 1099-R
  box 8 percentage is zero by stripping the characters `0` and `.` and checking whether anything is left.
  The configuration reader turns the literal `0.` into the number 0, so the `.` is never stripped and
  `0.00` looks nonzero. Direct File then wrongly knocks out 4 of its own test returns. Discovered by
  Arnab Ghosh.
- **1 marked confirmed in the engine code (DF-BUG-5)**: exact fractions converted to dollars through
  32-bit floating point.
- **2 marked fixed** in our code (DF-BUG-1, the 1099-R distribution code; DF-BUG-7, student loan
  phase-out rounding).
- **29 candidates.** We read both the XML and the law and believe they differ, but have not reproduced
  the difference by running Direct File. Most do not change any value in the 157 test returns. Examples:
  every Form 1099-MISC treated as Alaska Permanent Fund income (DF-BUG-9); a health insurance policy that
  starts December 1 never counting December as covered (DF-BUG-31).

We want to be careful here: a candidate is our reading, not a finding the IRS has agreed with.
<!-- TODO(final): update numbers -->

## How it was built

US Tax was built during a hackathon by one person and an orchestrated team of AI agents (Claude). Git
history starts 2026-10-31; as of 2026-11-01 there were 54 merged pull requests. One orchestrator agent
split the work into issues (the roadmap is issue #1), started worker agents in separate git worktrees,
rebuilt and re-ran the difftests on each pull request before merging, and kept `STATUS.md` up to date.

The division of labour follows `CLAUDE.md` §8:

- **Humans own the specification**: the properties in `lean/UsTax/Spec/`, the theorem statements in
  `Challenge.lean`, the list in `comparator.json`, and the policy decisions (Catala-to-Lean strategy,
  "statute beats Direct File", no TLS in the critical path). `STATUS.md` lists the decisions that went to
  the human.
- **Models write code and proofs.**
- **A mechanical check accepts or rejects.**

Models are good at proofs and weak at choosing what to prove; when stuck they may weaken a statement or
reach for `sorry`. So the check is layered:

1. **`make audit`** (`docs/audit.md`): a source scan for `sorry`, `admit`, `native_decide`, `axiom`,
   `implemented_by`, `unsafe` and similar; an axiom audit of every declaration under `UsTax`; and
   [for-all-dev/forensics](https://github.com/for-all-dev/forensics), which flags vacuous theorems
   (false or contradictory hypotheses, conclusions that reduce to `True`).
2. **Negative controls for the audit itself**: `scripts/audit_negative_control.sh` injects six kinds of
   cheat into a scratch copy (a `sorry`, an axiom, `native_decide`, `maxHeartbeats 0`, an axiom hidden in a
   macro, a theorem with a `False` hypothesis); each must make the audit fail (PR #116).
3. **Comparator in a Linux container** (`make comparator`, `docs/comparator.md`). `lake check` and
   `lake comparator` need Linux sandboxing, so on a Mac they run in Apple's `container`. Two negative
   controls were run (PR #105): a `sorry` (which `lake build` alone accepted, exit 0) and an extra
   `axiom cheat : False` plus a changed statement. Both were rejected.
4. **Property-based testing before proving.** Each lemma is first tested with `plausible`. This caught a
   false statement: a filing-status lemma needed an extra hypothesis (PR #134).
5. **Satisfiability and rejection examples.** Each spec property has a concrete example where it holds
   and examples of wrong outputs it rejects (for instance, the Tax Table property rejects $6,053, the tax
   without the table's midpoint rule, for a single filer at $50,000).

What we did not do: no human has yet done the full review of the spec files that `CLAUDE.md` calls for
(`STATUS.md` lists the spec reviews as not done). Until then, the theorem statements were written by a
model and checked by tools, not signed off by a person. <!-- TODO(final): update after human spec review -->

## Limitations

- Tax year 2024 only. Federal only. Standard deduction only.
- Only the situations Direct File supported. Everything else is a knockout; Direct File's list of
  98 knockout conditions and our coverage of them is in `docs/knockout-inventory.md`.
- The link from Catala to Lean is differential testing, not proof. The link from the law to Catala is
  human reading.
- The running server covers less than the Catala rules (see above).
- The trusted base includes the Lean kernel, compiler and runtime, `Std.Http`, our JSON reader (tested,
  not proved), the spec files, the Tax Table data file, and, for testing only, the Catala toolchain and
  the prebuilt Direct File engine bundle.
- Not tax advice.

## Future work

- Port the credit modules (earned income credit, child tax credit, child and dependent care, saver's,
  elderly or disabled, premium tax credit) to Lean, wire the whole return into the server, and prove the
  two pending theorems.
- Add `tentativeTaxFor_eq_taxSpec` (Tax Table above $100,000) to the Comparator set.
- A human review of every spec file, recorded in `docs/spec-surface.md`.
- Report the confirmed Direct File bugs upstream, and try to confirm more candidates by running the engine.
- A Catala-to-Lean translator, which would turn the testing link into a proof about a translation.
  Catala PR #1088 (a JSON IR export, open as of 2026-10-31) would help.

---

## TODO(final) markers in this file

1. Catala module, test-file and test counts ("Why Catala and Lean").
2. Theorem count from `make audit` ("What is proved").
3. Status of the two pending theorems ("What is proved").
4. Difftest table: scenario counts, value counts, PTC status ("What is tested").
5. Which modules the running server uses ("What is tested").
6. Direct File bug counts by status ("Bugs in the reference implementation").
7. Whether the human spec review is done ("How it was built").
