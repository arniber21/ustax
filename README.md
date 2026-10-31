# ustax

A formally verified US individual income tax calculator, written in
[Catala](https://catala-lang.org) and covering the subset of the law implemented
by the IRS Direct File source release.

- `scope.md`: survey of what Direct File covers, and how to formalize it.
- `catala/`: Catala sources (currently only a toolchain smoke test).

Sibling project: catax.

## Status
Scaffold only. `make install` installs Catala through opam; `make check` type-checks `catala/*.catala_en`.
Neither has been run yet on this machine (opam/catala not installed when the scaffold was written).

## Trusted base (to fill in)
Catala compiler, any Lean translation of the Catala output, accepted axioms.
