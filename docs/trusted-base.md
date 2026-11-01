# Trusted base (issues #59, #71)

A proof shows that the code meets its statement. Everything the proof does not cover is *trusted*:
if one of the items below is wrong, an answer can be wrong even though every proof and every test
passes. This page lists each item, what it does, and why we accept it (CLAUDE.md section 7). The
short version is in the [README](../README.md#trusted-surface); the framing of "proved" versus
"verified" is in [What "verified" means here](site/what-verified-means.md).

## 1. What runs when you press "Calculate"

```
browser (web/, React)  --HTTP JSON-->  ustax-server (lean/ServerMain.lean on Std.Http)
                                          |  parseBody, parseRequest   (lean/UsTax/Api/Parse.lean)   proved sound
                                          |  apiCalculator             (lean/UsTax/ApiCalculator.lean) Lean, theorems
                                          |  render response           (lean/UsTax/Api/Response.lean)  tested
                                          v
                                       JSON reply (lines, outcome, knockout reasons)
```

| Item | What it does | Proved, tested or trusted | Why we accept it |
|---|---|---|---|
| **Lean kernel** (v4.35.0, `lean/lean-toolchain`) | Checks every proof | Trusted | Small, well-studied core; Comparator replays the proofs through it again in a sandbox (`make comparator`). |
| **Lean compiler and runtime** (v4.35.0) | Turns the checked definitions into the `ustax-server` binary | Trusted | The proofs are about the definitions; that the compiled code computes the same is the compiler's job. We use no `implemented_by`, `extern` or `unsafe` in `lean/UsTax` (`make audit` source scan). |
| **`Std.Http` and `Std.Async`** (Lean core) | HTTP/1.1 parsing and serialisation, libuv sockets | Trusted | Part of the pinned toolchain. We have no proof about HTTP framing. Checked by `make test-server` (46 passed, 0 failed, 1 skipped on 2026-11-01, PR #151). |
| **`lean/ServerMain.lean`** (181 lines) | Routing, CORS, body cap, content-type check, logging, generic 500 | Trusted, tested | IO only, no theorem, and no tax logic. It is outside `lean/UsTax`, so `make audit` does not scan it. |
| **JSON reader** `lean/UsTax/Api/Json.lean` | Parses the untrusted request bytes | Tested, not proved | Strict reader written for the contract (rejects `100.0` as money, duplicate keys, nesting over 32). Not proved to implement RFC 8259. Checked by `make api-conformance` (about 2,100 generated requests against `api/schema.json` with ajv). |
| **Decode and validate** `lean/UsTax/Api/{Decode,Validate,Parse}.lean` | Turns JSON into a typed `Request`, or a 400 | **Proved**: `Api.parseRequest_sound` (every accepted request satisfies `Request.Valid`), `validate_sound`, `validate_eq_nil_iff`, `parseRequest_error_status` (every failure is a 400) | The meaning of "valid" is `Request.Valid` in `lean/UsTax/Api/Spec.lean`, which a human must read. Not proved: that `Decode` puts each key into the field of the same name (tested with distinct-value checks). |
| **The calculator** `lean/UsTax/ApiCalculator.lean`, `Calculator.lean` and the modules under them | The whole 2024 return | Theorems about it (see the README table); its agreement with the Catala rules and Direct File is **tested** | The theorems are checked by the kernel. That the code computes what the law says is evidence, not proof (section 3). |
| **No 500 on a valid request** | | **Proved**: `Extra.calculateRequest_ne_fault` | |
| **Response serialisation** `lean/UsTax/Api/Response.lean`, `J.render` | Writes the reply JSON | Tested, not proved | `make test-server` compares every fixture in `api/fixtures` byte for byte; `server_vs_cli.mjs` compares the server with `ustax api-calc` on 315 requests. |
| **Port, host and CORS** | Binds `HOST` (default `127.0.0.1`), `PORT` (default 8080); allows the origins in `ALLOW_ORIGIN` (default `http://localhost:5173`) | Configuration | Loopback by default, so the plain-HTTP API is not reachable from the network unless you change `HOST`. |
| **Body cap** | Requests over 256 KiB get 413; a non-JSON content type gets 415 | Tested (`make test-server`) | Human decision (STATUS.md, "Decided earlier"). |
| **Data** | The server stores nothing. It logs method, path and status only, never the request body. An internal error's text goes to the server's stderr, not to the client. The web app keeps your answers in your own browser (local storage) so a reload does not lose them. | By construction (`ServerMain.lean`) | |
| **TLS** | None in the Lean process | Optional: Caddy | `Std.Http` has no TLS. `make tls` and `make docker-run` put Caddy in front (`docs/tls.md`, `docs/deploy.md`). Caddy is trusted only if you use it. |
| **The web app** `web/` | Asks the questions, shows the reply | Not verified | It holds no tax logic: it displays the server's numbers. Unit tests (`make web-test`) and end-to-end tests (`make e2e`) only. |

There are no `opaque` contracts and no `axiom` declarations in `lean/UsTax`. The accepted axioms are
Lean's standard three: `propext`, `Classical.choice`, `Quot.sound`. No `native_decide`. `make audit`
enforces this on every declaration under `UsTax`; Comparator enforces it on the 40 judged theorems.

## 2. What a human must review: the specification

A theorem means what its statement says, and the statement means what every definition it mentions
means. These files are the specification. They are written by a model, checked by tools, and still
need a human to confirm that they say the right thing (not done yet; see `STATUS.md`).

- `lean/UsTax/Spec/*.lean`: the properties (`NonnegMonotone`, `RefundOrBalanceDue`,
  `CreditsWithinLiability`, `EitcWithinBounds`, `MatchesTaxTable`, `worksheetTax`, the module specs,
  `KnockoutSound`, `RefundOutcome`, `CreditsWithinTax`). Each has a satisfiable example and at least
  two rejected bad outputs (`docs/spec-checks.md`).
- `lean/UsTax/Comparator/Challenge.lean` and `lean/UsTax/Comparator/Extra.lean`: the theorem
  statements Comparator checks against, listed in `lean/comparator.json` (9) and
  `lean/comparator.extra.json` (31).
- `lean/UsTax/Api/Spec.lean`: `Request.Valid`, what the server accepts.
- [`docs/spec-surface.md`](spec-surface.md): for each theorem, every definition its statement depends
  on, with a prose review and a list of "Choices to confirm (human)".

## 3. Data and references

| Item | What it is | Why it is trusted |
|---|---|---|
| `sources/forms-instructions/derived-tax-table-2024.csv` | The 2024 Tax Table, 2,062 rows. **Derived by us from the IRS PDF** (`i1040gi--2024.pdf`), not an IRS file. `scripts/gen_lean_tax_table.py` generates `lean/UsTax/TaxRates/TaxTableData.lean` from it. | `MatchesTaxTable` refers to this data, so the main Tax Table theorems mean "matches this file". `Proofs.rows_chain` and `rows_cover` prove the rows tile $0 to $100,000 with no gap or overlap (a gap was found and fixed in PR #132). That each row equals the printed PDF is checked by reading, not by proof. |
| `sources/forms-instructions/derived-eic-table-2024.csv` | The 2024 EIC Table, derived from the PDF the same way (`lean/UsTax/Eitc/EicTableData.lean`) | Golden test: 1,337 rows by 8 columns compared, 0 differ (PR #141). |
| Form 8962 Table 2 (`lean/UsTax/Ptc/Table2Data.lean`) | Generated from the Catala test's 255 rows, extracted from `i8962--2024.pdf` | Same rows in Catala and Lean tests. |
| Constants (`lean/UsTax/Params2024*`, `catala/params_2024.catala_en`) | Rev. Proc. 2023-34 amounts | Each checked against the source in `sources/VERIFICATION.md`. |
| The Catala rules (`catala/*.catala_en`) | The law as readable code, quoting the statute | Human reading: no tool checks that a rule means what the statute means. |
| **Direct File engine bundle** (the prebuilt Scala.js bundle from the Direct File repository, `oracle/README.md`) | The test oracle: `oracle/facts.csv` (83,488 values on 161 test returns) | Used for tests only. It has bugs (33 logged, `docs/direct-file-bugs.md`), which is why disagreements are logged and the statute wins. |

## 4. Tools used only to build or test

None of these runs when you use the calculator; a fault in them could hide a bug, not create one in
an answer.

| Tool | Used for |
|---|---|
| **Catala 1.3.0** (`catala`, `clerk`) | `make check` (602 tests) and `make difftest`. Opt-in: `make install-all`. |
| **Comparator** (`lake check`, `lake comparator`) and its **bubblewrap** sandbox, inside an Apple `container` Linux VM on a Mac (`docs/comparator.md`) | Replays the build through the kernel and checks the proved statements equal the trusted ones, with only the allowed axioms. |
| **for-all-dev/forensics** (pinned commit, `scripts/audit.sh`) | Flags vacuous theorems in `make audit`. |
| **plausible** (v4.35.0) | Property-based tests before proving. |
| **devbox** (and Nix under it) | Pins Node, elan, bun, ninja, opam and the rest of the tooling (`docs/devbox.md`). |
| **Docker / OCI images** (`ubuntu`, `node`, `caddy`) | Only for `make docker-run` (`docs/deploy.md`). |
| Node, ajv, the difftest harness (`difftest/`) | Test code. Untrusted by design: each harness has a negative control that must fail. |

## 5. What we did NOT verify

- **HTTP framing** beyond what `Std.Http` does: no proof about requests, responses or sockets.
- **The browser UI**: not verified; tested only.
- **The Catala-to-Lean link by proof.** The Lean calculator and the Catala rules are linked by
  differential testing on 157 Direct File returns, not by a proof or a verified translation
  (`docs/catala-to-lean.md`).
- **The Catala rules against the law**: human reading only.
- **The JSON reader and the response writer**: tested, not proved.
- **Tax year 2025 or later.** Only tax year 2024.
- **Itemized deductions** (standard deduction only), **state taxes**, business income, and anything
  else Direct File did not support.
- **Any situation that knocks out.** The calculator refuses it with a reason
  (`docs/knockout-inventory.md`); nothing about such a return is computed or claimed.
- **Filing.** Nothing is filed. This is not tax advice.
