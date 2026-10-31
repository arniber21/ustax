# Direct File discrepancies found by the formalization

Policy: statute and IRS instructions win over the Direct File XML (catala/CONVENTIONS.md §8). Each entry links the XML, the law, and what we do. Status: `candidate` (suspected, needs confirmation), `confirmed` (read in XML and law, reproduced in a test), `fixed` (our code follows the law, difftest lists the scenarios that diverge).

Credit: discovered by the ustax formal verification project (Arnab Ghosh).

| ID | Status | Where (DF XML) | What DF does | What the law says | Our behaviour | Owner |
|---|---|---|---|---|---|---|
| DF-BUG-1 | candidate | `form1099Rs.xml` l.276, `constants.xml` l.915 | Strips characters in `247BGH` from the 1099-R code, then whitelists: `7D`, `7M` etc. are accepted as `7`; code `1` strips to empty and is knocked out | Distribution code meaning differs per code (early distribution, disability, etc.); `7D` is not the same as `7` | Treat the code as a whole; knock out unsupported combinations | #22, #60 |
| DF-BUG-2 | candidate | `taxCalculations.xml` l.1473 | American opportunity credit hard-coded `$0` with no knockout | IRC 25A: eligible filers get the credit | Knock out (Form 8863 unsupported) instead of silently under-crediting | #37, #60 |
| DF-BUG-3 | candidate | `familyAndHousehold.xml` | No qualifying-child tie-breaker | IRC 152(c)(4) | Implement tie-breaker or knock out when two claimants | #16, #60 |
| DF-BUG-4 | candidate | `*` per-item rounding (scope.md §3.1) | Rounds each item then sums | 1040 instructions p 23: round only the total | Decide in #60 after measuring oracle impact | #60 |
| DF-BUG-5 | confirmed (engine) | `types/Dollar.scala` | Rational to Dollar via 32-bit Float | exact arithmetic | exact | #60 |
| DF-BUG-6 | candidate | `taxCalculations.xml` l.1388-1410 | `line21OfSchedule2` defined but not added into `totalTax` | Form 1040 line 24 = line 22 + line 23 | We add line 23 (value 0 today) | #14, #60 |

Add rows as modules find more; keep one row per distinct defect.
