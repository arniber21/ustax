# ustax

A formally verified US individual income tax calculator, written in
[Catala](https://catala-lang.org) and covering the subset of the law implemented
by the IRS Direct File source release.

- `scope.md`: survey of what Direct File covers, and how to formalize it.
- `catala/`: Catala sources (currently only a toolchain smoke test).

Sibling project: catax.

Roadmap: issue #1 (https://github.com/arniber21/ustax/issues/1), grouped by milestone M0-M9, with native sub-issue and blocked-by links.

## Status
Scaffold only. `make install` installs Catala through opam (needs `eval $(opam env)`); `make check` type-checks `catala/*.catala_en`.
Verified: Catala 1.3.0 (OCaml 5.5.2) type-checks the smoke test with `clerk`.

## Trusted base (to fill in)
Catala compiler, any Lean translation of the Catala output, accepted axioms.
