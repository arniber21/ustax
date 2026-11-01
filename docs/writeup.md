# US Tax: the tax law as checked code, and a calculator with proofs

*Hackathon write-up. Numbers are as of 2026-11-01, and each says where it came from. The short,
non-technical version is [What "verified" means here](site/what-verified-means.md); the author's own
account is [How we built this](site/how-we-built-this.md).*

## Why

Tax software is a program that tells you how much money you owe the government. People trust it
because they cannot check it. Mistakes happen in commercial and government software alike, and when
they do, they repeat on every return that takes the same path.

The tax code is also unusually well suited to being written as code. It is long, but each rule is
small and precise: "line 15 is line 11 minus line 14, but not less than zero." The *rules as code*
movement argues that the law should be published in a form a computer can run, so that everyone runs
the same rules. [Catala](https://catala-lang.org), a programming language built for writing laws, came
out of that movement.

We wanted to do two things with that idea. First, write the 2024 federal income tax rules as code that
a tax expert can read next to the statute, and check them against the IRS's own implementation. Second,
run a calculator whose arithmetic is **proved**, not just tested, and say exactly where the line
between the two falls.

## What we built

US Tax is a web app that computes a 2024 US federal income tax return (Form 1040) for the kinds of
returns IRS Direct File handled: wages, interest, unemployment, Social Security, retirement income, the
common adjustments, the standard deduction, the child tax credit, the earned income credit, the child
and dependent care credit, the saver's credit, the credit for the elderly or disabled, and the premium
tax credit. You answer questions in plain language; it shows your refund or balance due, line by line.

Each line has a **Law & proof** drawer: the statute and IRS instructions it comes from, the Catala rule
that computes it, the Lean theorems about it, and the tests that pin it (`api/provenance.json`,
19 line items, checked current by `make provenance-check`). If your return is outside its scope, it
stops and says why, instead of guessing. Direct File calls this a *knockout*.

The app also has a docs section at `/docs` (markdown files in `docs/site/` and a few others), an
interactive API reference at `/docs/api`, a ⌘K command palette, and a Verification page whose numbers
a unit test checks against the repository (PR #155).

Under the web app there are three layers:

```
  Law (forms, instructions, IRC, Rev. Proc. 2023-34; copies in sources/)
    -> Catala rules        37 modules, the statute quoted next to each rule; the test oracle
    -> Lean code + proofs  the calculator that runs, and theorems about it
    -> Lean HTTP server    Std.Http from Lean core, plain HTTP
    -> React web app       questions and results; no tax logic
```

Our yardstick is **IRS Direct File**, the IRS's free filing tool, whose source code was released into
the public domain. It contains a tax engine and 161 test returns. We run that engine on its own test
returns and record every value it produces (83,488 rows in `oracle/facts.csv`). That gives us an
independent opinion on every number.

## The headline: the law as Catala

The unusual part of this project is the Catala layer. The rules are 37 Catala modules, 20,802 lines.
Each section of the Internal Revenue Code or the IRS instructions is quoted, and the rule that
implements it sits directly under the quote, so a tax expert who does not program can check it
paragraph by paragraph. The Catala compiler type-checks all of it (`clerk typecheck`: "Typechecking
successful!"), and **602 of 602** named tests pass (`make check`, 2026-11-01, per
[What "verified" means here](site/what-verified-means.md)). Each module has hand-worked examples from the
forms and instructions, tests that a known-wrong output is rejected, and one test per Direct File
discrepancy that asserts the law's value and not Direct File's.

Then the whole-return Catala scope runs on the inputs of every Direct File test return, and every
output is compared with the Direct File engine, exactly, in cents. Direct File wrongly knocks out 4 of
its own returns (DF-BUG-8, below), leaving 157. Result of `make difftest SCOPE=calculator`, re-run for
this write-up on 2026-11-01: **157 of 157 returns and 5,360 of 5,360 values agree**. 9 values are
reported apart as known divergences, where we follow the law on purpose: DF-BUG-3, DF-BUG-23, and one
return whose filing status Direct File's own validity check rejects. A known divergence is never
counted as a pass.

**What the type checker did and did not do.** It is tempting to say "the compiler found bugs in the
IRS's code". It did not. Catala 1.3.0 rejects type errors (money plus a decimal), non-exhaustive
matches and dependency cycles at compile time, and it forced several real design decisions: two calls
of the interest module to break a cycle through AGI, a staged filing status, explicit rounding at every
place a dollar amount meets a rate, exact fractions instead of floating point. But **none of the 33
disagreements with Direct File came from the type checker**. 25 came from writing each rule in Catala
with the statute quoted and Direct File's XML open beside it; 7 from a review of the Direct File code
before any Catala was written; 1 from running Direct File's test returns. What Catala gave us is a
form precise enough to compare line by line. The full table, with how each was found, is in
[What "verified" means here](site/what-verified-means.md).

## Bugs in the reference implementation

Where Direct File and the law disagree, our policy (set by the human) is that **the statute wins**,
and we log the difference in [`docs/direct-file-bugs.md`](direct-file-bugs.md). The log has 33
entries. The calculator follows the law in 30 of them; for 3 (DF-BUG-2, 4 and 10) it keeps Direct
File's behaviour until the owner decides. Every entry is pinned by a test
([`docs/quirk-decisions.md`](quirk-decisions.md)).

| Status | Count | Entries |
|---|---|---|
| **Confirmed by running the Direct File engine** | 1 | DF-BUG-8 |
| Read in the engine's source (arithmetic, not a tax rule) | 1 | DF-BUG-5 |
| Candidate, our code already follows the law ("fixed") | 2 | DF-BUG-1, DF-BUG-7 |
| Candidate | 29 | the rest |
| Visible as a different value on a Direct File test return | 8 | 3, 8, 13, 14, 15, 19, 23, 24 |

- **DF-BUG-8 (confirmed).** Direct File decides whether the Form 1099-R box 8 percentage is zero by
  stripping the characters `0` and `.` and checking whether anything is left. Its configuration reader
  turns the literal `0.` into the number 0, so the `.` is never stripped and `0.00` looks nonzero.
  Direct File then wrongly knocks out 4 of its own test returns. **Discovered by Arnab Ghosh.**
- **DF-BUG-5.** Exact fractions converted to dollars through 32-bit floating point (`types/Dollar.scala`).
- **Candidates**, for example: every Form 1099-MISC treated as Alaska Permanent Fund income
  (DF-BUG-9); a foster parent getting the child care credit through a custody release, $702 where the
  law gives $602 (DF-BUG-23); a health insurance policy that starts December 1 never counting December
  (DF-BUG-31).

A candidate is our reading, with a citation and a test, not a finding the IRS has agreed with.

## Why Lean, and why not a translator

**Lean** is a programming language with a proof checker built in. A Lean theorem is checked by a small
kernel, so you do not have to trust whoever (or whatever) wrote the proof, only the statement.

The obvious plan was to translate the Catala rules into Lean automatically. Catala 1.3.0 has no Lean
backend, and nothing upstream was close ([`docs/catala-to-lean.md`](catala-to-lean.md), section 2).
Writing one was estimated at 50 to 80 hours before any proof work, and its output would look like
compiler internals. So the human decided:

- **Write the calculator directly in Lean**, one Lean file per Catala module. The proofs are about the
  code that runs.
- **Keep Catala as the readable spec and test oracle.**
- **Link the two by differential testing**: run Direct File, Catala and Lean on the same inputs and
  compare every value.

So the link between "the law as written in Catala" and "the Lean program" is a test, not a proof. We
say that everywhere.

Copying Catala's arithmetic exactly by hand matters. The spike measured it
([`docs/catala-to-lean.md`](catala-to-lean.md), section 3.2): drop one cent-rounding step and
single-filer tax changes on 971 of 200,000 cent values between $100,000 and $102,000; round half to
even instead of half away from zero and it changes on 30,700 of 100,000 dollar values below $100,000.
The Lean money library reproduces both counts as a regression test (`lean/UsTax/Money/Regression.lean`).

## What is proved

The Lean project is 125 files and about 40,000 lines under `lean/UsTax`, with no Mathlib. The
theorems are about the calculator's own functions. Statements are in
`lean/UsTax/Comparator/Challenge.lean` and `Extra.lean`, the properties in `lean/UsTax/Spec/`, and
[`docs/spec-surface.md`](spec-surface.md) lists every definition each statement depends on and reviews
it.

**The 9 main theorems** (`lean/comparator.json`, namespace `UsTax.Main`), none with hypotheses beyond
its arguments:

| Theorem | In plain words |
|---|---|
| `tentativeTax_nonneg_monotone` | Tax on taxable income (line 16) is never negative and never decreases as income increases, for each filing status. |
| `tentativeTax_matches_tax_table` | For every taxable income below $100,000, line 16 equals the 2024 Tax Table, in the right column. |
| `line16_matches_tax_table` | The same, for line 16 inside a full Form 1040. |
| `tentativeTax_matches_worksheet` | From $100,000 up, line 16 equals the printed Tax Computation Worksheet. |
| `line16_matches_worksheet` | The same, inside a full Form 1040. |
| `refund_balanceDue_consistent` | Refund and amount owed are nonnegative, at most one is nonzero, and refund minus owed equals payments minus tax. |
| `credits_within_liability` | Credits can bring the tax to zero, not below (line 22 = max(0, line 18 − line 21)). |
| `totalTax_nonneg` | Total tax (line 24) is never negative. |
| `eitc_within_bounds` | The earned income credit is between zero and its legal maximum, and zero past the phase-out. |

**31 more** (`lean/comparator.extra.json`, namespace `UsTax.Extra`). 23 tie modules to a plain reading
of the statute for every input: the standard deduction, interest, W-2 wages and withholding, taxable
Social Security, the educator and student loan adjustments, estimated payments, AGI, taxable income,
total payments. 8 are about the whole return the server runs: refund or bill and credits within the
tax on the whole return, the child care, elderly and saver's credits together within the tax,
knockout soundness (`supported = false` exactly when a reason is listed), `outcome = refund` exactly when
line 34 is positive, and **no pure internal-inconsistency result on any valid request** (HTTP/runtime exceptions are outside this theorem) (`calculateRequest_ne_fault`).

Supporting results worth naming:

- `Api.parseRequest_sound`: every request the server accepts satisfies `Request.Valid`
  (`lean/UsTax/Api/Spec.lean`); `parseRequest_error_status`: every rejection is a 400.
- `Proofs.rows_chain`, `Proofs.rows_cover`: the 2,062 Tax Table rows cover every cent from $0 to
  $100,000 with no gap or overlap. They were added in PR #132, which fixed a real gap: the first version
  of our table data was missing the rows for $5 to $25.

**Checks on the proofs.** `make comparator` and `make comparator-extra` passed on 2026-11-01 for all
9 + 31 statements (recorded when issues #65 and #66 were closed): `lake check` replays the build
through the kernel, and `lake comparator` checks that the proved statements are exactly the trusted
ones and use only `propext`, `Quot.sound` and `Classical.choice`. `make audit` passed on the tree
merged as PR #156 (`lean/` has not changed since): the axiom step found **2,212 theorems and 6,681
definitions** using only those three axioms, with no `sorry` or `native_decide`, and the forensics
step checked **7,981 declarations under `UsTax` with 0 high-severity findings** (no false or
contradictory hypotheses, no conclusion that reduces to `True`). Those counts include many small
lemmas; we would rather be judged on the 40 above. Each of the 40 has a satisfiable instance and at
least two rejected bad outputs, 82 in all ([`docs/spec-checks.md`](spec-checks.md), `make
spec-checks`); for example, the Tax Table statement rejects $4,016 (the exact tax without the
table's midpoint rule) for a single filer with taxable income of $35,400, where the table prints
$4,019.

One statement is still pending (`lean/UsTax/Comparator/Pending.lean`): each nonrefundable credit,
in Schedule 3 order, limited by the tax left after the credits before it. What is proved instead is
the whole-return bound (`calculator_credits_within_liability`) and the three credits whose limits chain
on line 18 (`calculator_credits_le_tax`).

## What is tested

| What | Result (2026-11-01) | Source |
|---|---|---|
| Catala whole return vs Direct File (`make difftest SCOPE=calculator`) | 157/157 returns, 5,360/5,360 values; 9 known divergences; 4 knocked-out returns skipped | re-run for this write-up |
| Lean vs Catala vs Direct File, whole return (`make lean-difftest SCOPE=calculator`) | 157 returns, 5,360 three-way agree, 0 failures; 754 more values Lean = Catala where the oracle is incomplete | PR #151 |
| The same through the API request shape (`SCOPE=api_calculator`) | 157 returns, 3,105 agree, 0 failures | PR #151 |
| Catala named tests (`make check`) | 602/602 | [What "verified" means here](site/what-verified-means.md) |
| Server (`make test-server`) | 46 passed, 0 failed, 1 skipped (a 500 cannot be provoked); server = command line on 315 requests | PR #151 |
| Request validator vs JSON schema (`make api-conformance`) | about 2,100 generated requests agree | PR #151 |
| EIC Table golden test | 1,337 rows by 8 columns, 0 differ | PR #141 |

Every harness has a **negative control**: `DIFFTEST_PERTURB=1` and `LEAN_DIFFTEST_PERTURB=1` change the
outputs on purpose, and the run must fail. It does (for example, 6,123 of 6,123 perturbed checks fail
for `SCOPE=calculator`, PR #151). A harness that cannot fail proves nothing.

## How it was built

US Tax was built during the hackathon by one person and an orchestrated team of AI agents (Claude).
Git history starts 2026-10-31; by 2026-11-01 there were 77 merged pull requests. One orchestrator agent
split the work into issues (the roadmap is issue #1), started worker agents in separate git worktrees,
re-ran the builds and difftests on each pull request before merging, and kept
[`STATUS.md`](../STATUS.md) current.

The division of labour follows `CLAUDE.md` section 8:

- **The human owns the specification and the policy**: the properties in `lean/UsTax/Spec/`, the
  statements Comparator checks, and the decisions (write the calculator directly in Lean; statute beats
  Direct File; no TLS in the Lean process; which quirks to keep). `STATUS.md` lists the open ones.
- **Models write code and proofs.**
- **A mechanical check accepts or rejects.**

Models are good at proofs and weak at choosing what to prove; when stuck they may weaken a statement or
reach for `sorry`. So the checks are layered:

1. **`make audit`** ([`docs/audit.md`](audit.md)): a source scan for `sorry`, `admit`, `native_decide`,
   `axiom`, `implemented_by`, `unsafe` and similar; an axiom audit of every declaration under `UsTax`;
   and [for-all-dev/forensics](https://github.com/for-all-dev/forensics), which flags vacuous theorems
   (false or contradictory hypotheses, conclusions that reduce to `True`).
2. **Negative controls for the audit itself**: `scripts/audit_negative_control.sh` injects six kinds of
   cheat into a scratch copy (a `sorry`, an axiom, `native_decide`, `maxHeartbeats 0`, an axiom hidden in
   a macro, a theorem with a `False` hypothesis); each must make the audit fail (PR #116).
3. **Comparator in a Linux container** ([`docs/comparator.md`](comparator.md)). `lake check` and
   `lake comparator` need Linux sandboxing, so on a Mac they run in Apple's `container`. Two negative
   controls were run (PR #105): a `sorry` (which `lake build` alone accepted, exit 0) and an extra
   `axiom cheat : False` plus a changed statement. Both were rejected.
4. **Property-based testing before proving** with `plausible`. This caught a false statement: a
   filing-status lemma needed an extra hypothesis (PR #134).
5. **Satisfiable instances and rejected bad outputs** for every judged statement, checked by
   `make spec-checks`.

**What went wrong, and the merge guard.** Parallel agents on one repository are fast, and they can
step on each other. On 2026-10-31, PR #143 was squash-merged from a branch based on an old `main`.
The squash silently undid work that had been merged after that base: the provenance index, the
household knockouts and their tests. It was caught, reverted and re-applied the same night. Since then
every merge goes through a guard: `git diff --diff-filter=D --name-only origin/main...<branch>` must be
empty (a branch may not delete files it did not mean to), and the branch must contain `origin/main`.

**What we did not do.** No human has yet done the full review of the spec files that `CLAUDE.md` asks
for. Until then, the theorem statements were written by a model and checked by tools
(`docs/spec-surface.md` lists the "choices to confirm"), not signed off by a person.

> **Spec review sign-off: PENDING HUMAN REVIEW.** The owner has not yet reviewed or signed off the
> spec files (`lean/UsTax/Spec/`, `lean/UsTax/Comparator/Challenge.lean`, `Extra.lean`,
> `lean/UsTax/Api/Spec.lean`, with `docs/spec-surface.md` as the guide). This note is replaced by
> the sign-off statement once that review is done.

## Trusted base and what is not verified

The full list, with the reason for each item, is [`docs/trusted-base.md`](trusted-base.md). In short:
the Lean kernel, compiler and runtime; `Std.Http` and our socket glue (`lean/ServerMain.lean`); the JSON
reader and response writer (tested, not proved); the spec files a human must review; the Tax Table
and EIC Table data we derived from the IRS PDFs; the Catala rules as a reading of the law; and, for
tests only, the Direct File engine bundle, the Catala toolchain, Comparator's sandbox and devbox/Nix.
The accepted axioms are `propext`, `Classical.choice` and `Quot.sound`.

Not verified: HTTP framing, the browser UI, the Catala-to-Lean link (tested, not proved), the meaning
of the Catala rules against the statute, tax years after 2024, itemized deductions, state taxes, and
any return that knocks out.

## Limitations

- Tax year 2024 only. Federal only. Standard deduction only.
- Only the situations Direct File supported. Everything else is a knockout; Direct File's knockout
  conditions and our coverage of them are in [`docs/knockout-inventory.md`](knockout-inventory.md).
- The American opportunity credit is `$0`, as in Direct File (DF-BUG-2, owner to decide).
- The link from Catala to Lean is differential testing, not proof. The link from the law to Catala is
  human reading.
- Not tax advice. Nothing is filed.

## Future work

- A human review of every spec file, recorded in `docs/spec-surface.md`, and decisions on the open
  quirk questions ([`docs/quirk-decisions.md`](quirk-decisions.md), "Questions for the human").
- Prove the pending per-credit statement, and decide which of the whole-return theorems become main
  theorems.
- Report the confirmed Direct File bug upstream, and try to confirm more candidates by running the
  engine.
- A Catala-to-Lean translator, which would turn the testing link into a proof about a translation.
  Catala PR #1088 (a JSON IR export, open as of 2026-10-31) would help.
- Tax year 2025.

---

## Numbers not re-verified for this version

Every number above was either re-run on 2026-11-01 for this write-up (`make difftest SCOPE=calculator`,
`make provenance-check`, file and line counts, `lean/comparator*.json`) or copied from the source named
next to it. These were **not** re-run, because building Lean was off limits while this was written:

- `make audit`: 2,212 theorems and 6,681 definitions from the axiom step on the PR #156 branch
  (`SKIP_FORENSICS=1`, PR #156 description); 7,981 declarations and 0 high-severity findings from the
  full run, forensics included, on the rebased tree before PR #156 was merged.
- `make comparator` / `make comparator-extra` PASS on all 40 statements: issue #65 and #66 closing
  comments.
- `make lean-difftest` (5,360 and 3,105), `make test-server` (46/0/1), `make api-conformance`: PR #151.
- 602 Catala tests: [What "verified" means here](site/what-verified-means.md). A plain count of
  `#[test]` markers in `catala/tests/` gives 601.
