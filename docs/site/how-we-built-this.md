---
title: How we built this
order: 10
summary: The author's write-up of how Catala and Lean were used, and where this goes next.
---

# Income Tax Calculator
## Overview
`ustax` is a formally verified income tax calculator. It leverages a formalization of a subset of US income tax law in the [Catala DSL](https://catala-lang.org/en/doc) to ensure that tax calculation business logic is consistent with the law as written. `ustax` supports the subset of US tax law implemented in the IRS' [Direct File](https://github.com/IRS-Public/direct-file), whose source is publicly available on GitHub. Formalized tax calculations in Catala are converted (via an LLM, but ideally, through transpilation) into Lean code, where we prove additional properties (for example, that tentative tax never decreases as taxable income rises).
### Catala
Catala is a DSL for the law. It allows people to write laws with code. Crucially, it removes ambiguity in interpretation and enables type-checking. For the subset of the law that deals with numerics, calculations, logic, etc., Catala can be transpiled into either OCaml or Java for automated decision-making and calculation. The French government used Catala to translate, verify, and derive automated calculations for both [income tax](https://gitlab.adullact.net/dgfip/impots-nationaux-revenu-patrimoine-particuliers/ir-catala) and [housing benefits](https://catala-lang.org/en/examples/housing-benefits). 

Thus, the entry point for developing `ustax` was first to create the requisite Catala formalization. To do so, I pointed a swarm of agents at a source dump of Direct File. They were first to establish a set of tax laws that they could infer from the program; separately, subagents would search through [US revenue code](https://www.govinfo.gov/app/details/USCODE-2024-title26/) and find the actual tax law based on the inferred specification. Next, another wave of subagents would collaboratively formalize the tax laws in Catala. With a comprehensive Catala specification in hand, I then turned to Lean.
### Lean
Lean is the language of choice for this hackathon. Furthermore, it would enable supplemental verification to Catala's guarantees. Unfortunately, Catala only supports code generation to OCaml, Java, JavaScript, Python, and C. Ideally, we would write a backend for Lean -- unfortunately, an entire compiler backend to a proof verifier is quite a bit to chew off for a weekend hackathon, so I decided to use agents to guide the translation from Catala to Lean. However, in an ideal world, this would be automated.

The generated Lean business logic was augmented with a suite of additional correctness theorems for tax calculations, including matching figures between calculation areas, credit calculations, EITC calculations, and more. Finally, I integrated the module with a typical Lean web-server setup with Lean's HTTP library (opportunity: a web server framework for Lean, when we don't want to deal with complexity). Finally, we paired it with a basic frontend written in React and Typescript. 
### Trusted Base
Unfortunately, this program has quite a few trusted bases: the Lean compiler, libraries, JSON parsing, etc. A more fleshed-out non-hackathon version could certainly tackle many of these. In particular, we rely on a correct Catala-to-Lean translation -- this should be automated with a compiler. We also rely on correct interpretation of the law text to Catala -- while this is generally subjective, US tax law is usually explicit (though less so than other countries). A fuller version would remove these from the trusted base by compiling Catala to Lean and by having people review the formal spec against the statute.

