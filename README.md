# ustax

A formally verified US individual income tax calculator, written in
[Catala](https://catala-lang.org) and covering the subset of the law implemented
by the IRS Direct File source release.

- `scope.md`: survey of what Direct File covers, and how to formalize it.
- `catala/`: Catala sources (currently only a toolchain smoke test).
- [`catala/CONVENTIONS.md`](catala/CONVENTIONS.md): Catala conventions (naming, money and rounding, complete-inputs policy, knockouts, quirk policy).

Sibling project: catax.

Roadmap: issue #1 (https://github.com/arniber21/ustax/issues/1), grouped by milestone M0-M9, with native sub-issue and blocked-by links.

## Status
Dependencies and CI use [devbox](https://www.jetify.com/devbox) (`devbox.json`, `devbox.lock`; see `docs/devbox.md`). `make install && make run`: the only prerequisite is devbox (`curl -fsSL https://get.jetify.com/devbox | bash`, or `INSTALL_DEVBOX=1 make install`); every `make` target runs inside it automatically. `install` builds the pinned Lean project (elan), runs `npm ci` in `web/`, and builds Catala 1.3.0 into a project-local opam root `.opam` (`SKIP_CATALA=1` skips it); `run` starts the Lean API on http://localhost:8080 and, once `web/` has a UI, the dev server on :5173. `make test-server` runs the HTTP integration tests; `make check` type-checks `catala/*.catala_en`. Also: `devbox run install|check|test|audit|run|comparator`.
Verified: Catala 1.3.0 (OCaml 5.5.2) type-checks the smoke test with `clerk`.

## Trusted base (to fill in)
Catala compiler, any Lean translation of the Catala output, accepted axioms.
