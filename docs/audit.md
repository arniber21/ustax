# Proof audit and CI (issue #70)

`make audit` (= `scripts/audit.sh`) fails if the Lean project under
`lean/UsTax` uses any proof escape hatch, or if a theorem is vacuous. CI
(`.github/workflows/ci.yml`) runs it after `lake build`, `lake check` and
`lake comparator`. CLAUDE.md section 7 is the source of the rules.

## What `make audit` checks

All three steps run; the exit status is 1 if any fails. `SKIP_FORENSICS=1`
skips step 3. `LEAN_DIR=<copy>` audits another copy of the project.

1. **Source scan** (`scripts/audit_scan.py`). After removing comments and
   string literals, no file under `lean/UsTax` may contain `sorry`, `admit`,
   `native_decide`, `bv_decide`, an `axiom` declaration, `skipKernelTC`,
   `maxHeartbeats 0`, `implemented_by`, `extern` or `unsafe`.
2. **Axiom audit.** Builds `UsTax` and every module file under `lean/UsTax`
   (also those `UsTax.lean` does not import), fails on the build warning
   "declaration uses sorry", then elaborates a generated file that imports all
   of them and runs `#audit_all` (`lean/UsTax/Audit.lean`). `#audit_all` takes
   every non-internal declaration from modules under `UsTax` (theorems,
   definitions, opaques, axioms), computes its axioms with `collectAxioms`, and
   fails if any is an `axiom` itself or depends on something other than
   `propext`, `Classical.choice`, `Quot.sound`. `sorryAx` and the
   `Lean.ofReduceBool`/`native_decide` axioms are therefore rejected even if the
   source scan is bypassed (a macro that declares an axiom, for example). It
   also logs one line per theorem it checked, and `AUDIT OK: N theorems and M
   definitions ...`.
3. **Forensics** ([for-all-dev/forensics](https://github.com/for-all-dev/forensics),
   pinned to a commit in `scripts/audit.sh`; cloned to `.forensics-tool/`,
   needs `bun`). The extractor writes a JSON dump
   (`scripts/audit_forensics.py` reads it). The upstream server throws a
   `ReferenceError` ("Cannot access 'judging' before initialization") right
   AFTER writing the dump, so the script treats "dump written and parseable" as
   success and ignores the exit status. Severity-high findings fail, for
   declarations under `UsTax`:
   - flags `sorry`, `nativeDecide`, `nonstandardAxiom`;
   - smells `trivialConclusion`, `conclusionUnfoldsToTrue`, `falseHypothesis`,
     `contradictoryHypotheses`;
   - flags `partial`, `opaque`, `implementedBy`, `extern`, `unsafe`, except in
     the module `UsTax.Audit` (the tooling: `partial def specSurface.go` walks the
     environment and is never part of a statement);
   - a failed build inside forensics.

   Other smells (`unusedHypothesis`, `unusedVariable`, ...) are counted and
   printed, not failed. Forensics only sees modules reachable from
   `UsTax.lean`; the source scan and `#audit_all` also cover modules that are
   not imported there.

## Why `lean/UsTax/Comparator/` is excluded

`UsTax/Comparator/Challenge.lean` is the trusted statement file for
`lake comparator`: each theorem is stated and proved with `sorry` on purpose.
Comparator then checks that the solution module proves the same statements
with only the permitted axioms (`lean/comparator.json`). The module is not
imported by `UsTax.lean`, so `lake check` and the audit never see it as part of
the library; the audit also skips its directory so that the by-design `sorry`
does not fail the scan. If someone imported it from the library, `lake check` would fail (it replays
everything `UsTax` imports and rejects `sorryAx`); the audit's own exclusion is
by module name, so it would not.

## Negative controls

`scripts/audit_negative_control.sh [scratch-dir]` copies `lean/` to a scratch
directory (the repository is never modified), injects one violation at a time
and requires the audit to fail:

| injected into the copy | caught by |
| --- | --- |
| `sorry` appended to `Money/Lemmas.lean` | scan, build warning, `#audit_all`, forensics |
| new module with `axiom` | scan, `#audit_all` |
| new module with `native_decide` | scan, `#audit_all` |
| `set_option maxHeartbeats 0 in` | scan |
| axiom added by a macro (no `axiom` in the text) | `#audit_all` only |
| `theorem (h : False) : 1 = 2` | forensics only |

Last run: 6 of 6 injections failed the audit and the unmodified copy passed.

## CI

`.github/workflows/ci.yml` has two jobs on `ubuntu-latest` (Ubuntu 24.04).

- **catala**: `jetify-com/devbox-install-action` (packages from `devbox.lock`,
  nix store cached), `devbox run catala-setup` (OCaml 5.4.1 and
  `catala.1.3.0` into the project-local opam root `.opam`, cached),
  `devbox run check`, then `make difftest SCOPE=all`. The difftest summary
  is written to the job summary and does not gate the job (known Direct File
  differences are listed in docs/direct-file-bugs.md).
- **lean**: devbox provides bubblewrap and elan; the pinned toolchain from
  `lean/lean-toolchain` goes to `/opt/elan` (cached); copies `lean/` to `/opt/ustax-lean`
  (outside `/home` and `/root`, which the sandbox covers with a tmpfs, as in the
  container setup of `docs/comparator.md`; `.lake` is cached there); runs
  `make lean-build`, `make lean-check`, `make lean-comparator`
  (`lake build`, `lake check`, `lake comparator --config comparator.json`; `LEAN_DIR` points
  at the copy), then `devbox run audit` on that copy.

`lake check` and `lake comparator` refuse to run outside Linux. This is why CI
runs them natively and a Mac runs them in a container (`make comparator`).

### bwrap on GitHub's Ubuntu 24.04 runners

Ubuntu 23.10 and later set `kernel.apparmor_restrict_unprivileged_userns=1`,
which stops an unprivileged `bwrap` from creating a user namespace
(`bwrap: setting up uid map: Permission denied`). The usual fix is
`sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`. The workflow
probes the devbox `bwrap` first and applies the sysctl only when the probe fails, so it
works whether or not the runner image already allows it. **Not verified here**:
this repository's owner cannot run GitHub Actions from the development
machine, so the first CI run is the test. If it still fails, look at the
"Allow unprivileged user namespaces for bwrap" step: the probe prints the
bwrap error.

What was validated locally: the workflow with `actionlint` (clean) and PyYAML;
`scripts/audit.sh` and the negative controls on macOS (neither needs Linux);
the `lake check`/`lake comparator` commands in the Linux container
(`docs/comparator.md`). The workflow's runner-specific steps (setup actions,
cache, the sysctl) were not executed.

## Not covered

The audit says nothing about whether the theorem statements are the right
ones (a reviewer reads the spec files, CLAUDE.md section 4); the final trusted
statements for `lake comparator` replace the placeholders in
`Challenge.lean` under issue #63.
