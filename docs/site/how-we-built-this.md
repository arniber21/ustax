---
title: How we built this
order: 10
summary: The author's write-up of how Catala and Lean were used, and where this goes next.
---

# How we built this

<!-- TODO(you): one or two sentences that say what this page is and who it is for. Delete this comment when done. -->

*Who is this page for, and what should they know after reading it?*

> [!NOTE]
> This page is a scaffold. The headings and questions below are prompts for the author to answer in
> their own words. Delete each italic question and each `TODO(you)` comment as you write the section.

> [!TIP]
> **Facts you can cite.** Each item exists in the repository today. Figures come from
> [`STATUS.md`](../../STATUS.md), last updated 2026-11-01; re-check them there before you quote them.
>
> - Spec surface of the main theorems: [`docs/spec-surface.md`](../spec-surface.md)
> - Direct File reference-implementation bug log: [`docs/direct-file-bugs.md`](../direct-file-bugs.md), 33 entries as of 2026-11-01 (`STATUS.md`)
> - Catala to Lean strategy and trust story: [`docs/catala-to-lean.md`](../catala-to-lean.md)
> - Comparator and `lake check`: [`docs/comparator.md`](../comparator.md)
> - Proof audit (`make audit`): [`docs/audit.md`](../audit.md); last result in `STATUS.md`: PASS, 7,790 declarations, 0 high-severity (2026-11-01)
> - Catala `Calculator` scope: 157/157 non-knocked-out Direct File scenarios and 5,360/5,360 fact checks; `ApiCalculator`: 157/157 and 3,105/3,105 through the API request shape (`STATUS.md`, 2026-11-01)
> - Lean vs Catala vs Direct File oracle: calculator 5,360 agree, api_calculator 3,105 agree (`STATUS.md`, 2026-11-01)
> - Server tests: `make test-server` 46 passed, 0 failed, 1 skipped (`STATUS.md`, 2026-11-01)
> - Comparator-extra: 23 spec-vs-implementation theorems (`STATUS.md`, 2026-11-01)
> - Tax year 2024, federal income tax only (site footer)

## Why formal verification for taxes

<!-- TODO(you): your motivation. What went wrong, or could go wrong, with tax software? Why does a proof help? -->

*What made you want a proof, rather than only tests, for a tax calculator?*

## How we used Catala

<!-- TODO(you): law as code. Show one short rule next to the statute text it quotes (a catala code block works here). -->

*What does it look like to write the law as code, with the statute quoted in the same file?*

<!-- TODO(you): the Catala tests you wrote, and what they cover. -->

*What do the Catala tests check, and who wrote the expected values?*

<!-- TODO(you): the differential test against the IRS Direct File engine. What was compared, what matched, what did not. -->

*How did you compare the Catala code against IRS Direct File, and what did the comparison show?*

## How we used Lean

<!-- TODO(you): the hand-written implementation. Why write it by hand in Lean rather than generate it. -->

*Why is the calculator written by hand in Lean?*

<!-- TODO(you): the spec files, and what a reviewer should read first. -->

*Where are the specs, and what should a reviewer read first?*

<!-- TODO(you): Comparator, and why it matters for trusting the theorem statements. -->

*What does Comparator check that a normal build does not?*

<!-- TODO(you): the audit and forensics tooling. -->

*What do `make audit` and the forensics dump catch?*

## Connecting Catala and Lean

<!-- TODO(you): differential testing as the link between the two, and why you chose it. -->

*How do the Catala and Lean calculators agree, and how do you know?*

<!-- TODO(you): why not a translator. Summarise the decision in docs/catala-to-lean.md in your own words. -->

*Why did you not write a Catala-to-Lean translator?*

## The reference implementation bugs we found

<!-- TODO(you): pick the entries worth telling a story about. The full log is docs/direct-file-bugs.md. -->

*Which one or two bugs in the reference implementation best show why this approach is useful?*

## How the agent team worked

<!-- TODO(you): how the work was split, who (or what) did which part, and what a human still had to decide. -->

*How was the work divided between you and the agents, and what did you keep for yourself?*

## What is proved, what is tested, what is trusted

<!-- TODO(you): three short lists. docs/spec-surface.md and the verification page on the site are the source. -->

*What exactly is proved, what is only tested, and what do you ask the reader to trust?*

## Future directions

<!-- TODO(you): for each bullet below, keep it, cut it, or add a sentence on why it matters. -->

*Which of these do you most want to do next, and why?*

- More of the tax code
- 2025 changes
- Itemized deductions
- A verified Catala-to-Lean translator
- A proof of the full Catala semantics
- State taxes
- E-file

## Acknowledgements

<!-- TODO(you): people, projects and tools you want to thank. -->

*Who and what helped?*
