---
title: What "verified" means here
order: 1
summary: Two kinds of assurance, proved in Lean and verified in Catala, what each one covers, and what you still have to trust.
---

# What "verified" means here

US Tax uses the word *verified* for two different things. They give different guarantees, so they are
labelled differently everywhere on the site.

| | **Proved in Lean** | **Verified in Catala** |
|---|---|---|
| What it is | A theorem about the calculator's own code, checked by the Lean kernel | The tax rules written as readable, executable law, checked by the Catala compiler and tests |
| Strength | A **proof**: it holds for every input, not just the ones we tried | **Evidence**: it agrees with the IRS reference engine on every scenario we have |
| Example | "You never get both a refund and a bill" | "Our rules give the same answer as IRS Direct File on 157 sample returns" |
| Can it be wrong? | Only if the theorem statement itself says the wrong thing (a human reviews those) | Yes: a rule could be wrong in a way no sample return exercises |

> [!NOTE]
> **Proved** = a Lean theorem holds for every input.
> **Verified** = the Catala rules agree with IRS Direct File on every scenario we have. It is not a proof.

## Proved in Lean

The calculator that runs behind this site is written directly in Lean. Statements about it are checked by
Lean's kernel, with no `sorry` and no extra axioms.

- **Comparator-checked statements** (`lean/comparator.json`, 9 theorems): the tax on taxable income
  never goes down as income goes up and is never negative; line 16 equals the printed IRS Tax Table
  for every cent below $100,000 and the Tax Computation Worksheet above it; refund and amount owed are
  both non-negative, at most one is non-zero, and their difference is payments minus tax; credits never
  exceed the tax they offset; the earned income credit stays between zero and its maximum.
- **Additional statements** (`lean/comparator.extra.json`, 31 theorems): for example that the standard
  deduction, interest, W-2 totals, Social Security and the adjustments equal a plain statement of the
  statute for all inputs, and that on the whole return `supported = false` exactly when the list of
  reasons is non-empty.
- **The checks around them:** `make audit` rejects `sorry`, new axioms and `native_decide`, and runs a
  scan for vacuous or contradictory statements; `make comparator` replays the proofs in a sandbox
  against a fixed file of statements.

See [Spec surface](/docs/spec-surface) for the exact definitions each theorem depends on, and
[Comparator and lake check](../comparator.md) for how the checks run.

## Verified in Catala

The tax rules were written first in [Catala](https://catala-lang.org), a language designed for law. A
Catala file reads like the statute: the law's text is quoted, and the rule sits right under it.

What "verified" means for the Catala side:

1. **The compiler checks the logic.** Catala type-checks every rule and flags overlapping or conflicting
   exceptions, which catches a class of legal-drafting mistakes.
2. **Named tests.** Each module has tests with hand-worked examples, and tests that a known-wrong
   answer is rejected.
3. **Agreement with the IRS engine.** The whole return was run against 157 scenarios from the IRS Direct
   File project (the ones that are not knocked out). All 5,360 fact checks agree, except where we
   deliberately follow the statute instead, and every such case is logged.

This tier is **not a proof**. The Catala rules and the Lean code are linked by *differential testing*:
we run both on the same inputs and compare. [Catala to Lean](/docs/catala-to-lean) explains why we did
not build a translator, and what that choice costs.

## Where Catala found problems

Because the Catala rules are explicit, they showed up places where the IRS reference implementation
disagrees with the law. Thirty-three are logged in [Direct File bugs](/docs/direct-file-bugs). One is
confirmed by running the IRS engine itself; the rest are candidates. Where they differ, the calculator
follows the statute.

## What you still have to trust

- The Lean kernel, and the Lean server and JSON reader that sit between your browser and the calculator.
- The theorem **statements** (the spec files). A proof only shows the code meets the statement, so a
  human has to confirm the statements say what they should. See [Spec surface](/docs/spec-surface).
- The IRS Direct File engine, as the reference we compare against. It is a government project, but it
  has bugs, which is why we log them.
- The Catala toolchain, but only for tests: the running calculator does not use it.

## What is not covered

Federal income tax for tax year 2024 only, with the standard deduction only. Anything outside the
supported situations is refused with a reason, not guessed. Nothing is filed, and this is not tax
advice.
