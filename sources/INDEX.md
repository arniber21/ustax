# sources/INDEX.md: primary sources for TY2024

Everything here was fetched on 2026-10-31 and checked to be real content (PDF magic number via `file`, page counts via `pdfinfo`, or the 2024 U.S. Code header for statute HTML). Page numbers elsewhere in this folder are PDF page indexes (first page = 1), not printed page numbers, unless marked "printed".

Statute text is the **U.S. Code, 2024 Edition** from govinfo (law as of early January 2025), not the live code. The live code was changed by Pub. L. 119-21 (2025), which alters several rules for 2025 and later. Use these files for TY2024 only.

Issue numbers refer to https://github.com/arniber21/ustax/issues. Issue titles: #5 conventions/rounding, #10 rate schedules and Tax Table, #11 standard deduction, #12 W-2, #13 interest/Sch B, #14 1040 assembly, #15 filers, #16 qualifying child, #17 qualifying relative, #18 Form 8332 split, #19 HoH/QSS persons, #20 filing status, #21 1099-G/PFD, #22 1099-R, #23 SS benefits, #24 educator/student loan, #25 estimated tax, #26 EITC, #27 CTC/ODC/ACTC, #28 CDCC, #29 Saver's, #30 Schedule R, #31 Sch 2/3 and credit order, #32-34 PTC, #35 HSA, #36-37 knockouts, #38 unsupported aggregation, #39 Lean money/rounding, #60 quirk decisions, #61-62 spec review.

## forms-instructions/

URL prefix for `--2024` files: `https://www.irs.gov/pub/irs-prior/<name>--2024.pdf`.

| File | Official URL | Governs | Feeds |
|---|---|---|---|
| `f1040--2024.pdf` (2 pp) | irs-prior/f1040--2024.pdf | Form 1040 line chain | #14, #5 |
| `i1040gi--2024.pdf` (113 pp) | irs-prior/i1040gi--2024.pdf | 1040 instructions. Contains: Tax Table (PDF pp 64-75), Tax Computation Worksheet (p 76), Standard Deduction charts (p 34), Social Security Benefits Worksheet (p 32), EIC worksheets and EIC Table (pp 43-47), Schedule 1-3 line instructions, Presidential Election Campaign Fund (p 13) | #10, #11, #14, #23, #24, #26, #31 |
| `f1040s1--2024.pdf` | irs-prior/f1040s1--2024.pdf | Schedule 1: other income (PFD, unemployment), adjustments (educator, HSA, student loan) | #21, #24, #35 |
| `f1040s2--2024.pdf` | irs-prior/f1040s2--2024.pdf | Schedule 2: excess APTC repayment (line 1a) feeds 1040 line 17 | #31, #34 |
| `f1040s3--2024.pdf` | irs-prior/f1040s3--2024.pdf | Schedule 3: nonrefundable credit lines, line 8; line 15 to 1040 line 31 | #31 |
| `f1040sb--2024.pdf`, `i1040sb--2024.pdf` | irs-prior/f1040sb--2024.pdf, i1040sb--2024.pdf | Schedule B ($1,500 threshold) and instructions | #13 |
| `f1040sr--2024.pdf`, `i1040sr--2024.pdf` | irs-prior/f1040sr--2024.pdf, i1040sr--2024.pdf | Schedule R (credit for the elderly or disabled): form and instructions (income limits, Table 1) | #30 |
| `f1040s8--2024.pdf`, `i1040s8--2024.pdf` | irs-prior/f1040s8--2024.pdf, i1040s8--2024.pdf | Schedule 8812 (CTC, ODC, ACTC). IRS names it `s8`, not `s8812`. Instructions include Credit Limit Worksheet A and the ACTC worksheets | #27 |
| `f1040sei--2024.pdf` | irs-prior/f1040sei--2024.pdf | Schedule EIC. Its instructions are inside `i1040gi` and Pub 596 | #26 |
| `f2441--2024.pdf`, `i2441--2024.pdf` | irs-prior/f2441--2024.pdf, i2441--2024.pdf | Form 2441 (CDCC) and instructions. Percentage table: `i2441` p 7, `f2441` p 1 | #28 |
| `f8880--2024.pdf` (2 pp) | irs-prior/f8880--2024.pdf | Form 8880 (Saver's credit). Page 2 holds the instructions and the Credit Limit Worksheet. There is no separate `i8880` for 2024 | #29 |
| `f8889--2024.pdf`, `i8889--2024.pdf` | irs-prior/f8889--2024.pdf, i8889--2024.pdf | Form 8889 (HSA) and instructions | #35 |
| `f8962--2024.pdf`, `i8962--2024.pdf` | irs-prior/f8962--2024.pdf, i8962--2024.pdf | Form 8962 (PTC) and instructions. Table 2 applicable figure (`i8962` p 10), Table 5 repayment limits (p 17), FPL (p 8), Worksheet 2 (p 9) | #32, #33, #34 |
| `f8862--2024.pdf`, `i8862--2024.pdf` | irs-prior/f8862--2024.pdf, i8862--2024.pdf | Form 8862 (disallowed EIC/CTC/etc.), knockout reasoning | #26, #27, #37 |
| `f8332.pdf` | https://www.irs.gov/pub/irs-pdf/f8332.pdf | Form 8332, release of claim to exemption. **Revision December 2025, not a 2024 revision.** The prior-year file `f8332--2024.pdf` does not exist on irs.gov. The substance (custodial parent release) is unchanged but check the text before quoting | #18 |
| `f8959--2024.pdf`, `i8959--2024.pdf` | irs-prior/f8959--2024.pdf, i8959--2024.pdf | Form 8959 (Additional Medicare Tax): thresholds 125k/200k/250k, for W-2 knockout | #12, #36 |
| `derived-tax-table-2024.csv` | **derived by us**, not an IRS file | Machine-readable copy of the 2,060 Tax Table rows (`i1040gi` pp 64-75), parsed with `pdftotext -layout`. Columns: at_least, but_less_than, single, mfj, mfs, hoh. Use as a golden test for #10. Checked: 8,240 values reproduced exactly by the rate schedules plus the midpoint method | #10, #6, #7 |

## pubs/

URL: `https://www.irs.gov/pub/irs-prior/<name>--2024.pdf`.

| File | Governs | Feeds |
|---|---|---|
| `p501--2024.pdf` (30 pp) | Dependents, standard deduction, filing status. $5,050 gross income test, dependent std deduction | #11, #15-#20 |
| `p596--2024.pdf` (40 pp) | EITC rules and the 2024 limits (investment income $11,600, completed phase-out amounts) | #26 |
| `p503--2024.pdf` (20 pp) | Child and dependent care, employer dependent care benefits | #28 |
| `p554--2024.pdf` (37 pp) | Older Americans: Social Security taxation, Schedule R | #23, #30 |
| `p505--2024.pdf` (44 pp) | Tax withholding and estimated tax | #25 |
| `p969--2024.pdf` (24 pp) | HSAs, limits and worked examples | #35 |
| `p15--2024.pdf` (57 pp) | Circular E. Used only as an official source for the 2024 Social Security wage base $168,600 (p 2). The SSA page for this is blocked to scripts | #12 |

## revproc/

URL: `https://www.irs.gov/pub/irs-drop/<name>.pdf`.

| File | Governs | Feeds |
|---|---|---|
| `rp-23-34.pdf` (27 pp) | **Rev. Proc. 2023-34**: TY2024 inflation adjustments. Rate tables (pp 5-7), CTC refundable limit (p 8), EITC (pp 9-10), standard deduction (p 12), educator expense (p 11), 152(d) exemption amount (p 14), student loan interest phase-out (p 16) | #10, #11, #17, #24, #26, #27 |
| `rp-24-40.pdf` (27 pp) | **Rev. Proc. 2024-40**: TY2025 adjustments. Included only because Direct File cites it. Its 152(d) amount is $5,200 for 2025, not the 2024 figure | #17 (cross-check) |
| `rp-23-23.pdf` (3 pp) | Rev. Proc. 2023-23: HSA limits for 2024 ($4,150 / $8,300). Not on your list, but the HSA limits are not in 2023-34 | #35 |
| `rp-23-29.pdf` (3 pp) | Rev. Proc. 2023-29: 2024 PTC items (applicable percentage table, required contribution percentage). Not on your list; kept as the underlying revenue procedure for Form 8962 Table 2 | #32 |
| `n-23-75.pdf` (5 pp) | **Notice 2023-75**: 2024 retirement limits, including the Saver's credit AGI limits (p 3) | #29 |

## statute/ (U.S. Code 2024 Edition, HTML, from govinfo)

URL pattern: `https://www.govinfo.gov/link/uscode/26/<section>?year=2024&type=usc&link-type=html` (redirects to `https://www.govinfo.gov/content/pkg/USCODE-2024-title26/html/...`). A PDF form of each section is available by replacing `html` with `pdf` in the redirected URL.

| File | Section | Governs | Feeds |
|---|---|---|---|
| `irc-1.html` | IRC 1 | Tax rates, 1(j) 2018-2025 schedules | #10 |
| `irc-2.html` | IRC 2 | Definitions: surviving spouse, head of household | #19, #20 |
| `irc-21.html` | IRC 21 | CDCC | #28 |
| `irc-22.html` | IRC 22 | Credit for the elderly or disabled | #30 |
| `irc-24.html` | IRC 24 | CTC, ODC, ACTC | #27 |
| `irc-25B.html` | IRC 25B | Saver's credit | #29 |
| `irc-32.html` | IRC 32 | EITC | #26 |
| `irc-36B.html` | IRC 36B | PTC | #32-#34 |
| `irc-62.html` | IRC 62 | AGI, adjustments (educator, student loan, HSA references) | #24, #35 |
| `irc-63.html` | IRC 63 | Taxable income, standard deduction | #11 |
| `irc-86.html` | IRC 86 | Taxation of Social Security benefits | #23 |
| `irc-129.html` | IRC 129 | Dependent care assistance programs ($5,000 / $2,500) | #28 |
| `irc-151.html`, `irc-152.html` | IRC 151, 152 | Dependents, qualifying child, qualifying relative, 152(e) divorced parents | #15-#18 |
| `irc-221.html` | IRC 221 | Student loan interest deduction | #24 |
| `irc-223.html` | IRC 223 | HSAs | #35 |
| `irc-7703.html` | IRC 7703 | Marital status, "considered unmarried" | #19, #20 |
| `irc-6012.html`, `irc-6013.html` | IRC 6012, 6013 | Who must file; joint returns (6013(g)/(h) elections) | #15, #20 |
| `irc-1411.html` | IRC 1411 | NIIT thresholds (scope.md §3.3 knockout) | #36 |
| `irc-1341.html` | IRC 1341 | Claim of right, the $3,000 repayment threshold (scope.md §3.4, §3.5 knockouts) | #36 |

## regs/ (eCFR, point-in-time 2024-12-31, XML)

URL pattern: `https://www.ecfr.gov/api/versioner/v1/full/2024-12-31/title-26.xml?part=1&section=<n>` (needs `--compressed`).

| Files | Governs | Feeds |
|---|---|---|
| `cfr-1.2-2.xml` | Treas. Reg. 1.2-2: surviving spouse and head of household details | #19, #20 |
| `cfr-1.21-1.xml`, `-2`, `-3` | 1.21-1..3: CDCC expenses, qualifying individuals, earned income | #28 |
| `cfr-1.24-1.xml` | 1.24-1: partial credit for certain other dependents (short) | #27 |
| `cfr-1.32-2.xml` | 1.32-2: EITC (short; the only EITC reg in Part 1) | #26 |
| `cfr-1.36B-1..6.xml` | PTC regulations: 1 definitions, 2 eligibility (incl. family size, household income), 3 computing the credit, 4 reconciliation with advance payments (repayment), 5 Exchange reporting, 6 minimum value | #32-#34 |
| `cfr-1.63-1.xml` | 1.63-1: change of treatment re zero bracket amount (short, historical) | #11 |
| `cfr-1.151-1.xml`, `cfr-1.152-1..4.xml` | Dependents; 1.152-4 is the divorced/separated parents rule | #16-#18 |
| `cfr-1.7703-1.xml` | Determination of marital status | #19, #20 |
| `cfr-1.6013-4.xml` | Joint return, special rules | #20 |

## Could not fetch (or does not exist)

| Item | Status |
|---|---|
| Instructions for Form 8880 (`i8880`) | 404 on irs-pdf and irs-prior for 2021-2024. The 2024 instructions and Credit Limit Worksheet are on page 2 of `f8880--2024.pdf`. |
| Form 8332 and instructions, 2024 revision | `f8332--2024.pdf`, `i8332*` return 404. Only the current (Rev. 12-2025) form is available. |
| Standalone instructions for Schedules 1, 2, 3 and EIC (`i1040s1`, etc.) | 404. These instructions are in `i1040gi--2024.pdf`. |
| SSA 2024 contribution and benefit base page | 403 to scripts. Substituted Pub 15 (2024) for the $168,600 figure. |
| Regs 1.32-1, 1.25B-1, 1.223-1, 1.63-3 | Do not exist in eCFR (EITC regs are 1.32-2 only; no 25B or 223 regs in Part 1). |
| IRC sections 3402, 7701 | Skipped on purpose (not needed). |
| Form 8863 and AOC | Not requested (stubbed to $0 in Direct File). |

Pubs 590-A/590-B and 17 were also downloaded in a first pass and then deleted as not relevant.
