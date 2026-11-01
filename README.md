# US Tax

**A US federal income tax calculator for tax year 2024, with the math checked by a computer proof.**

You answer a few questions about your 2024 return: your filing status, your W-2s, your interest income.
US Tax works out your Form 1040, line by line, and tells you whether you get a refund or owe money.
If your situation is outside what it can handle, it says so plainly instead of guessing.

What makes it different: the calculator is written in [Lean](https://lean-lang.org), a programming
language that is also a proof checker. Some of the important promises the calculator makes
(for example, "you never get both a refund and a bill") are proved for every possible input,
not just tested on a few. The rest is tested against the IRS's own reference engine.
The sections below say exactly which is which.

> US Tax is a research and hackathon project. It does not file anything, and it is not tax advice.

<!-- Screenshots: add docs/screenshots/*.png here when the redesign PR lands. Link only files that exist. -->

## Try it

You need [devbox](https://www.jetify.com/devbox). Everything else (Lean, Node, Catala) is installed
for you inside the project folder.

```sh
curl -fsSL https://get.jetify.com/devbox | bash   # once; or: INSTALL_DEVBOX=1 make install
make install && make run
```

- `make install` downloads the pinned Lean toolchain, builds the calculator, installs the web app,
  and builds the Catala tools. The first run takes a while. `SKIP_CATALA=1 make install` skips Catala,
  which you only need for the tests.
- `make run` starts two things. Press Ctrl-C to stop both.
  - The calculator API at <http://localhost:8080> (`POST /calculate`, `GET /health`, `GET /version`).
  - The web app at <http://localhost:5173>. Open this one.

In the web app, click through the steps: about you, household, income, adjustments, review.
Then you see your results. To try something quick, use one wage earner with $50,000 on a W-2.
The app also has a "trust" page that explains what was checked.

Other ways to run it:

- `make server`: only the API, on port 8080.
- `make docker-run`: API on 127.0.0.1:8080 and web app on <http://localhost:8081>, with Docker Compose.
- `make tls`: an HTTPS front on <https://localhost:8443> through Caddy (optional; see `docs/tls.md`).

## How it works

There are three layers. Each one is checked against the one before it.

```
  The law                IRS forms, instructions, the Internal Revenue Code, Rev. Proc. 2023-34
     |                   (copies in sources/)
     v
  Catala rules           catala/*.catala_en: the rules written next to the legal text they come from.
     |                   Readable by a tax expert. Used as the reference and as a test oracle.
     |   checked by differential testing (not a proof)
     v
  Lean code + proofs     lean/UsTax: the calculator that actually runs, and the theorems about it.
     |
     v
  Lean web server        lean/ServerMain.lean: plain HTTP on Lean's built-in Std.Http library.
     |
     v
  Web app                web/: React. Asks the questions, shows the result. Holds no tax logic.
```

A few words on the tools:

- **[Catala](https://catala-lang.org)** is a language designed for writing laws as code. Its programs
  read a lot like the statute, so a tax expert can check them paragraph by paragraph.
- **[Lean](https://lean-lang.org)** is a programming language with a built-in proof checker. When Lean
  accepts a theorem, a small, well-studied core (the "kernel") has checked every step.
- **Differential testing** means running two programs on the same inputs and comparing every output.
- **IRS Direct File** was the IRS's free filing tool. Its source code is public. We run its tax engine
  on its own test returns and use the results as a third opinion.

Why both Catala and Lean? We first looked at translating Catala into Lean automatically. No such
translator exists, and writing one would have been a big job with its own bugs. So we write the
calculator directly in Lean and keep Catala as the readable spec. The reasoning, with measurements,
is in [`docs/catala-to-lean.md`](docs/catala-to-lean.md).

## What is proved, and what is only tested

We try hard to be precise here.

**Proved in Lean, about the Lean code that runs.** The six main theorems are listed and explained in
[`docs/spec-surface.md`](docs/spec-surface.md). In plain words:

- Tax on Form 1040 line 16 is never negative, and never goes down when taxable income goes up.
- Line 16 matches the printed 2024 Tax Table for every taxable income below $100,000, for every
  filing status.
- You get a refund or you owe money, never both, and the amount is exactly the difference between
  what you paid and your tax.
- Nonrefundable credits can bring your tax down to zero but not below.
- Total tax is never negative.

The theorems are also checked by Comparator (see below). Separately, there are proofs that the request
parser only accepts valid requests, and many smaller lemmas.

**Tested, not proved.** That the Lean code does what the Catala rules say, and that both agree with
Direct File, is established by differential testing. Direct File ships 161 test returns; its engine
rejects 4 of them (because of a bug, see below), which leaves 157. On those, as of 2026-11-01:

- The whole-return Catala calculator agrees with Direct File on all 4,677 checked values in the 151
  returns it can run (the other 6 need the premium tax credit, which was not wired in yet), apart from
  9 known differences where we follow the law instead (source: PR #133).
- Each Lean module agrees with Catala and Direct File on every value it computes, with no failures.
  For example, the Lean Form 1040 with its income modules plugged in agrees on 3,297 values across
  157 returns (sources: PRs #117, #125, #134).

This is strong evidence. It is not a proof. <!-- TODO(final): update numbers -->

**Not yet in the running server.** The Catala rules cover much more of the return than the Lean
server uses today. The server computes W-2 wages, interest, the standard deduction, the tax, withholding,
and the refund or balance due. It does not compute credits yet. It accepts 1099-G, 1099-MISC, 1099-R,
Social Security, adjustments and estimated payments, but says in a `warnings` list that it did not use them.
<!-- TODO(final): update which modules the server runs -->

### What you have to trust

Everything a proof cannot cover. If one of these is wrong, a result can be wrong even though the proofs pass.

- **The Lean kernel** and the Lean compiler and runtime (v4.35.0), which turn the checked code into a program.
- **The web server layer**: `Std.Http` from Lean core, and our socket glue in `lean/ServerMain.lean`.
- **Our JSON reader** (`lean/UsTax/Api/Json.lean`). It is tested, not proved.
- **The spec files a human reviews**: the properties in `lean/UsTax/Spec/`, the theorem statements in
  `lean/UsTax/Comparator/Challenge.lean`, and the Tax Table data generated from
  `sources/forms-instructions/derived-tax-table-2024.csv`. A theorem only means what its statement says.
- **Caddy**, if you use the optional HTTPS front.
- **For the tests only**: the Catala toolchain (1.3.0) and the Direct File engine bundle we run as the
  oracle (the prebuilt Scala.js bundle from the Direct File repository; see `oracle/README.md`).
- **The web app** shows what the server returns. It is not verified.

Accepted axioms: `propext`, `Classical.choice`, `Quot.sound` (Lean's standard ones). Nothing else, and no
`native_decide`. `make audit` enforces this.

## Bugs we found in the IRS reference implementation

Writing the rules carefully, next to the statute, turned up places where Direct File seems to disagree
with the law. When that happens we follow the law and record the difference.

The full log is [`docs/direct-file-bugs.md`](docs/direct-file-bugs.md). As of 2026-11-01 it has 33 entries.
Most are **candidates**: we read the Direct File code and the law and think they differ, but have not
proved it by running Direct File. Two are marked fixed (our code follows the law), and two are
confirmed by running the Direct File engine:

- **DF-BUG-8, Form 1099-R box 8.** Direct File checks "is the box 8 percentage zero?" by deleting the
  characters `0` and `.` from the text and checking whether anything is left. Because of how the
  configuration file is read, the `.` is lost, so `0.00` does not look like zero. Direct File then
  wrongly refuses four of its own test returns. Discovered by Arnab Ghosh.
- **DF-BUG-5, rounding.** Direct File converts exact fractions to dollars through 32-bit floating point.

<!-- TODO(final): update numbers -->

## Project layout

| Folder | What is in it |
|---|---|
| `catala/` | The rules in Catala, one module per form or topic, with tests in `catala/tests/` |
| `lean/` | The Lean calculator (`UsTax/`), specs (`UsTax/Spec/`), proofs (`UsTax/Proofs/`), web server (`ServerMain.lean`) |
| `web/` | The React web app |
| `api/` | The JSON contract between web app and server: schema, examples, fixtures |
| `oracle/` | Values from the Direct File engine on its test returns (`facts.csv`) |
| `difftest/` | The differential-testing harness (Catala vs Direct File, and Direct File vs Catala vs Lean) |
| `sources/` | The law: forms, instructions, statute, revenue procedures |
| `scripts/`, `deploy/` | Install, run, audit, Docker, Caddy, and the Comparator container |
| `docs/` | Design notes; start with [`docs/writeup.md`](docs/writeup.md) |

## Running the checks

Every command runs inside devbox automatically.

| Command | What it does |
|---|---|
| `make check` | Type-check all Catala rules and run their tests |
| `make difftest SCOPE=all` | Compare each Catala module with Direct File, scenario by scenario |
| `make lean-difftest SCOPE=<name>` | Three-way comparison: Direct File, Catala, Lean. `<name>` is a file in `difftest/mappings/`, for example `form_1040_plugged` |
| `make lean-build` | Build the Lean library, including all proofs |
| `make audit` | Fail on `sorry`, `admit`, `native_decide`, new axioms, or theorems that are vacuous |
| `make comparator` | Replay the proofs through the kernel and check them against the trusted statements, in a Linux container |
| `make test-server` | Start the server and run the HTTP integration tests |
| `make web-test` | Web app unit tests |

`make comparator` runs Lean's `lake check` and `lake comparator`, which only work on Linux. On a Mac
it uses Apple's `container` tool (`container system start` once first). See
[`docs/comparator.md`](docs/comparator.md) and [`docs/audit.md`](docs/audit.md).

## How to contribute

- Read [`catala/CONVENTIONS.md`](catala/CONVENTIONS.md) for naming, money and rounding rules, and
  [`CLAUDE.md`](CLAUDE.md) for how we verify Lean code.
- Humans own the specs: `lean/UsTax/Spec/`, `lean/UsTax/Comparator/Challenge.lean`, `lean/comparator.json`.
  Changes there need a careful human review, because they change what the proofs mean.
- A change is done when `make check`, the relevant `make difftest` / `make lean-difftest`, `make audit`
  and `make comparator` all pass.
- If you find a place where Direct File disagrees with the law, add a row to `docs/direct-file-bugs.md`.

The roadmap is [issue #1](https://github.com/arniber21/ustax/issues/1).

## Limitations

- **Tax year 2024 only**, and **federal only** (no state returns).
- **Standard deduction only.** No itemized deductions.
- **Only what Direct File covered**: mostly W-2 wages, interest, unemployment, Social Security,
  some retirement income, and the common credits. See [`scope.md`](scope.md).
- **Some situations are "knocked out"**: the calculator stops and tells you it cannot handle them,
  as Direct File did. The list is in [`docs/knockout-inventory.md`](docs/knockout-inventory.md).
- **The running server covers less than the Catala rules** (see "Not yet wired" above).
- **Not tax advice.** Check your real return with the IRS or a professional.

## License and credits

- This repository does not have a license file yet. <!-- TODO(final): add a LICENSE -->
- IRS Direct File is US-government work in the public domain, with a CC0 1.0 waiver. We use its rules,
  test returns and engine as a reference.
- [Catala](https://github.com/CatalaLang/catala) is Apache-2.0.
- Lean and its standard library are Apache-2.0. We also use Batteries and plausible.
- Built by Arnab Ghosh with a team of AI agents; see [`docs/writeup.md`](docs/writeup.md) for how.
