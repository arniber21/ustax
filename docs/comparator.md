# `lake check` and `lake comparator` in a Linux container (issue #70)

Lean v4.35 ships two checkers in Lake (CLAUDE.md section 7):

- **`lake check`** builds the project's default targets (`UsTax`), exports the
  whole imported environment with `leanexport`, replays it through the kernel
  (`leanchecker`), and fails if any constant uses an axiom other than
  `propext`, `Classical.choice`, `Quot.sound`. `sorry` is the axiom
  `sorryAx`, so it fails too.
- **`lake comparator`** builds a *challenge* module (trusted statements, proofs
  `sorry`) and a *solution* module, and checks that each named theorem has the
  same statement in both (and every constant those statements mention,
  transitively, is identical), that the solution's proofs use only the
  permitted axioms, and that the kernel accepts the solution.

Both run the project's code (its lakefile, its build, its exporter run) inside
a bubblewrap (`bwrap`) sandbox and refuse to start outside Linux. On a Mac we
run them in a Linux VM container with Apple's `container` CLI.

## How to run

One-time setup (Apple `container` 1.0.0 is at `/usr/local/bin/container`):

```sh
container system start      # starts the apiserver; downloads a kernel the first time
```

Then, from the repository root:

```sh
make comparator             # = scripts/comparator.sh all
make comparator MODE=check  # only lake build + lake check
FRESH=1 make comparator     # drop the cached .lake volume and rebuild everything
```

`scripts/comparator.sh`:

1. builds the image `ustax-comparator` from `deploy/comparator/Containerfile`
   (Ubuntu 24.04, bubblewrap, git, elan, the toolchain in `lean/lean-toolchain`);
2. mounts `lean/` read-only at `/src` and a named volume
   `ustax-comparator-lake` at `/work/.lake` (dependency clones and Linux build
   output; the host's `lean/.lake` is never touched);
3. runs `deploy/comparator/entrypoint.sh`, which probes bwrap, copies the
   sources to `/work`, checks the toolchain matches, and runs
   `lake build`, `lake check`, then `lake comparator --config comparator.json`.

It exits 0 only if every step passed. Set `LEAN_DIR=<path>` to check another
copy of the project (this is how the negative controls below were run).
`RUNTIME=docker` is accepted but untested (Docker on this machine is OrbStack).

## bwrap inside the container

It works with no extra flags. In an Apple `container` (kata 6.18 kernel, own
VM per container) the default process has `CapEff 00000000a80425fb`
(includes `CAP_SYS_ADMIN`), `Seccomp: 0` and
`/proc/sys/user/max_user_namespaces = 4505`. A bwrap with
`--unshare-all --ro-bind / / --dev /dev --proc /proc` succeeds both as root
and as an unprivileged user (unprivileged user namespaces are enabled). No
`--cap-add`, no privileged mode, no setuid bwrap needed. The entrypoint
re-probes on every run and exits 2 with a pointer here if that ever changes.

Elan lives in `/opt/elan`, not `/root/.elan`: the sandbox covers `/home` and
`/root` with a tmpfs (Lake binds the toolchain back, but `/opt` avoids
depending on that).

## What is checked, and what is not

Checked by `lake check` (default targets of `lean/lakefile.toml`, i.e. `UsTax`
and everything it imports):

- every declaration in the imported environment is re-checked by the kernel
  from the export (not trusted from `.olean` files);
- no declaration uses an axiom beyond `propext`, `Classical.choice`,
  `Quot.sound`. `sorry`, a new `axiom`, and `native_decide`
  (`Lean.ofReduceBool`) are all rejected. If we ever accept `native_decide`,
  `lake check` cannot express that; use `lake comparator`, whose
  `permitted_axioms` is configurable.

Checked by `lake comparator` (driven by `lean/comparator.json`):

- every theorem in `theorem_names` exists in both modules with an identical
  statement, and every constant reachable from those statements (the spec
  surface: `roundDollar`, `mulRate`, `Rat`, ...) is identical in both;
- those theorems use only `permitted_axioms`;
- the kernel accepts the solution export.

Not checked:

- **Whether the statements are the right ones.** The challenge module is the
  spec; a human reviews it (CLAUDE.md section 4).
- Modules not reachable from `UsTax.lean` (for `lake check`), and theorems not
  listed in `comparator.json` (for `lake comparator`).
- `#guard` / `#eval` tests: they run during `lake build`, which the script also
  runs, but the checkers judge proofs, not tests.
- `implemented_by` / `extern` replacing a definition's compiled code: the
  kernel sees the Lean body, so proofs are about the body, but `#eval` and the
  compiled binary run the replacement. Audit those by hand (CLAUDE.md
  section 7).
- Catala, the oracle and Direct File: entirely outside this check.

## Trusted base

- The Lean v4.35.0 kernel (`leanchecker`), `leanexport`, and Lake's comparator
  code (`Lake/Check/*.lean` in the toolchain). `--paranoid` additionally runs
  `leanchecker-paranoid`, `lean4lean`, `nanoda`, `con-leche` and `con-ron`
  from the toolchain; not enabled by default.
- The three standard axioms.
- bubblewrap and the Linux kernel of the container VM, for isolation of the
  build from the process that reports the verdict. Inside our own container
  the isolation is defence in depth: the Apple VM is already a sandbox.
- The image: Ubuntu 24.04 packages, elan from GitHub releases, the toolchain
  from `releases.lean-lang.org`. Not pinned by digest.
- For `lake comparator`: the challenge module and `comparator.json` (the list
  of theorem names and permitted axioms). These are the spec.

## Authoring the trusted-statements file (#63, #70)

The "trusted statements file" is two artifacts, both reviewed by a human and
changed only on purpose:

1. `lean/UsTax/Comparator/Challenge.lean`: imports only the *definitions* the
   statements need (never the module with the proofs), and states each main
   theorem with the exact name the solution uses and a `sorry` proof. It must
   not be imported by `UsTax.lean`, or `lake check` would fail on its `sorry`s.
2. `lean/comparator.json`:

   ```json
   {
     "challenge_module": "UsTax.Comparator.Challenge",
     "solution_module": "UsTax.Money.Lemmas",
     "theorem_names": ["UsTax.Money.roundDollar_eq", "..."],
     "definition_names": [],
     "permitted_axioms": ["propext", "Quot.sound", "Classical.choice"]
   }
   ```

   `solution_module` is one module; when the main theorems live in several,
   add a module (e.g. `UsTax/Comparator/Solution.lean`) that imports them all.
   `definition_names` is for definition *holes*: a definition the challenge
   leaves as `sorry` that the solution fills in. We have none: our
   definitions are part of the spec, so they must be identical, which the
   transitive comparison already enforces.

Since #63 the file holds the main tax theorems (eight statements, solution
module `UsTax.Proofs.Main`); `docs/spec-surface.md` lists what each depends on.
Main theorems not yet proved are templates in `UsTax/Comparator/Pending.lean`
and are not in `comparator.json`.
Workflow for a new main theorem: write the statement in `Challenge.lean`,
review it, add its name to `theorem_names`, then prove it in the library. A
proof that quietly weakens the statement fails with `Challenge and solution
theorem statement do not match`; a changed definition in the spec surface
fails with `Const does not match between challenge and target`.

## Results

Run on 2026-10-31, Apple `container` 1.0.0, macOS 27 arm64, Lean 4.35.0
(`aarch64-unknown-linux-gnu`). First image build about 2.5 minutes (most of
it the toolchain download); later runs reuse the image and the `.lake` volume.

Current `lean/` (`make comparator`), trimmed:

```
== lake check
Building and exporting
Running Lean default kernel on solution
Lean default kernel accepts the solution
Uses axioms: propext, Quot.sound, Classical.choice
== exit 0: lake check
== lake comparator --config comparator.json
Building UsTax.Comparator.Challenge
warning: UsTax/Comparator/Challenge.lean:22:8: declaration uses `sorry`   (x3, intended)
Exporting #[..., UsTax.Money.roundDollar_eq, UsTax.Money.roundDollar_mono, UsTax.Money.mulRate_le_self, ...] from UsTax.Comparator.Challenge
Building UsTax.Money.Lemmas
Exporting #[...] from UsTax.Money.Lemmas
Running Lean default kernel on solution
Lean default kernel accepts the solution
Your solution is okay!
== exit 0: lake comparator --config comparator.json
== overall: PASS
```

Negative controls, on scratch copies of `lean/` (`LEAN_DIR=...`, not
committed):

1. `roundDollar_mono`'s proof replaced by `sorry` in `UsTax/Money/Lemmas.lean`:

   ```
   error: Axiom 'sorryAx' is not permitted; it is used by 'UsTax.Money.roundDollar_mono'
   == exit 1: lake check
   error: Illegal axiom detected: 'sorryAx'
   == exit 1: lake comparator --config comparator.json
   == overall: FAIL
   ```

   Note `lake build` itself exits 0 here (only a warning), which is why the
   build alone is not a check.

2. A module `UsTax/Bad.lean` imported from `UsTax.lean` with
   `axiom cheat : False` and `theorem UsTax.bad : (1 : Nat) = 2 := cheat.elim`;
   plus the challenge's `roundDollar_mono` hypothesis changed to `m < n`:

   ```
   error: Axiom 'cheat' is not permitted; it is used by 'UsTax.bad'
   == exit 1: lake check
   error: Challenge and solution theorem statement do not match: 'UsTax.Money.roundDollar_mono'
   == exit 1: lake comparator --config comparator.json
   == overall: FAIL
   ```

Problem found on the way: with a stock `ubuntu:24.04` image, both commands
failed at once with `bwrap: Can't mkdir /run/user: Read-only file system`.
Lake binds `/` read-only and then mounts a tmpfs on `/run/user`, which must
already exist. The Containerfile creates it.

## CI

All tools come from devbox (`docs/devbox.md`); on Linux, bubblewrap is a devbox package and `make lean-check` / `make lean-comparator` run the two commands natively. `.github/workflows/ci.yml` runs `lake build`, `lake check` and `lake comparator` natively on Ubuntu (they need Linux and bwrap), followed by `make audit`. bwrap setup on the runners: `docs/audit.md`.

## Second challenge: module specs (`make comparator-extra`)

`lean/comparator.extra.json` judges `UsTax.Comparator.Extra` (23 statements:
each merged module equals its statute-style spec in `lean/UsTax/Spec/`, plus
bounds and monotonicity) against the solution `UsTax.Proofs.Extra`. It is
kept apart from `comparator.json` so that the human-chosen main theorems stay
a short list. `make comparator-extra` runs `scripts/comparator.sh extra`
(same container, `lake comparator --config comparator.extra.json`). The
statements are reviewed in `docs/spec-surface.md`, section "Module specs".
