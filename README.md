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
`make install && make run`: `install` needs [elan](https://elan.lean-lang.org) and Node >= 18 (no sudo), builds the pinned Lean project, runs `npm ci` in `web/`, and installs Catala through opam when opam exists (`SKIP_CATALA=1` skips it); `run` starts the Lean API on http://localhost:8080 and, once `web/` has a UI, the dev server on :5173. `make test-server` runs the HTTP integration tests; `make check` type-checks `catala/*.catala_en` (needs `eval $(opam env)`).
Verified: Catala 1.3.0 (OCaml 5.5.2) type-checks the smoke test with `clerk`.

## Trusted base (to fill in)
Catala compiler, any Lean translation of the Catala output, accepted axioms.
