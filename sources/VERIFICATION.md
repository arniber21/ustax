# sources/VERIFICATION.md: scope.md constants checked against official TY2024 sources

Checked 2026-10-31 against the files in this folder. "p" = PDF page index. Rev. Proc. = `revproc/rp-23-34.pdf` unless noted.

## Result

**One citation MISMATCH, zero value MISMATCHes.** Every dollar constant, rate, bracket and table in scope.md §2.1, §6 and §7 that we could check equals the official figure. Items that could not be checked are listed at the end as NOT FOUND or NOT CHECKED.

> **MISMATCH (citation, value is right).** scope.md §5.2 says the qualifying-relative gross income limit of **5,050** comes from "Rev. Proc. 24-40". Rev. Proc. 2024-40 is the **TY2025** revenue procedure and gives **$5,200** (`rp-24-40.pdf` p 14, §3.24). The TY2024 figure of $5,050 is in **Rev. Proc. 2023-34 §3.24** (`rp-23-34.pdf` p 14), and Pub 501 p 4/10/12/19. If Direct File's XML cites 24-40 for 5,050, its comment is wrong or its constant is the 2025 file's neighbour; either way the TY2024 value is 5,050. Cite 2023-34 in Catala.

> **Source typo to know about (not a scope.md mismatch).** Rev. Proc. 2023-34 Tables 2, 3 and 4 print "the excess over $191,150" in the 32% bracket (`rp-23-34.pdf` pp 5-6). The correct lower bound is **$191,950**, as the row header "Over $191,950" and the printed Tax Table show. scope.md has 191,950. Do not copy the typo.

## Rate schedules (scope.md §2.1) and Tax Table

| Constant | scope.md | Official | Source | Result |
|---|---|---|---|---|
| MFJ/QSS brackets (23,200; 94,300; 201,050; 383,900; 487,450; 731,200) with bases 2,320; 10,852; 34,337; 78,221; 111,357; 196,669.50 | as listed | identical | Rev. Proc. Table 1, p 5 (§3.01) | MATCH |
| Head of household (16,550; 63,100; 100,500; 191,950; 243,700; 609,350) bases 1,655; 7,241; 15,469; 37,417; 53,977; 181,954.50 | as listed | identical (apart from the 191,150 typo above) | Table 2, pp 5-6 | MATCH |
| Single (11,600; 47,150; 100,525; 191,950; 243,725; 609,350) bases 1,160; 5,426; 17,168.50; 39,110.50; 55,678.50; 183,647.25 | as listed | identical | Table 3, p 6 | MATCH |
| MFS: same as single to 243,725; 365,600 at 35%; above 98,334.75 + 37% | as listed | identical | Table 4, pp 6-7 | MATCH |
| Rates 10/12/22/24/32/35/37 | as listed | identical | Tables 1-4 | MATCH |
| Tax Table midpoint method: TI<5 uses 2.50; <15 uses 10; <25 uses 20; <3,000 uses $25-row midpoint (+12.50); <100,000 uses $50-row midpoint (+25); then schedule, round half up | as listed | Reproduces all 2,060 published rows for all four statuses: 8,240 of 8,240 values equal | `i1040gi--2024.pdf` pp 64-75; script output in `forms-instructions/derived-tax-table-2024.csv` | MATCH |
| Use of Tax Computation Worksheet at TI >= 100,000 | "TI itself" | 1040 instructions say use the worksheet (exact income, no midpoint) from 100,000 | `i1040gi` p 64, p 76 | MATCH |

## Standard deduction and dependents (scope.md §4.2, §5.2)

| Constant | scope.md | Official | Source | Result |
|---|---|---|---|---|
| Std deduction MFJ/QSS | 29,200 | 29,200 | Rev. Proc. §3.15(1), p 12 | MATCH |
| Std deduction single / MFS | 14,600 | 14,600 | same | MATCH |
| Std deduction HoH | 21,900 | 21,900 | same | MATCH |
| Additional, married or QSS | 1,550 | 1,550 | §3.15(3), p 12; `i1040gi` p 34 | MATCH |
| Additional, single/HoH | 1,950 | 1,950 | same | MATCH |
| Dependent filer: greater of 1,300 or earned + 450 | 1,300 / 450 | 1,300 / 450 | §3.15(2), p 12; Pub 501 p 24 | MATCH |
| Qualifying relative gross income limit | 5,050 | 5,050 (TY2024) | Rev. Proc. 2023-34 §3.24, p 14; Pub 501 | MATCH (value). **MISMATCH (cited source, see top)** |

## Credits: CTC, EITC, CDCC, Saver's, Schedule R

| Constant | scope.md | Official | Source | Result |
|---|---|---|---|---|
| CTC per child | 2,000 | 2,000 | IRC 24(h)(2), `statute/irc-24.html`; Sch 8812 line 5, p 1 | MATCH |
| ODC per dependent | 500 | 500 | IRC 24(h)(4); Sch 8812 line 7, p 1 | MATCH |
| ACTC refundable cap per child | 1,700 | 1,700 | Rev. Proc. §3.05, p 8; Sch 8812 p 2 | MATCH |
| ACTC earned income floor / rate | 2,500 / 15% | 2,500 / 15% | Sch 8812 lines 19-20, p 2 | MATCH |
| CTC phase-out threshold MFJ / other | 400,000 / 200,000 | 400,000 / 200,000 | IRC 24(b)(2); Sch 8812 line 9, p 1 | MATCH |
| Phase-out: $50 per $1,000 or fraction | 5% of excess rounded up to next 1,000 | $50 reduction per $1,000 (or fraction) | IRC 24(b)(1); Sch 8812 line 10 | MATCH |
| EITC phase-in rates 0/1/2/3+ children | 7.65 / 34 / 40 / 45 % | same | IRC 32(b)(1), `statute/irc-32.html` | MATCH |
| EITC earned income amounts | 8,260 / 12,390 / 17,400 / 17,400 | same | Rev. Proc. §3.06(1), p 9 | MATCH |
| EITC maximum credits | 632 / 4,213 / 6,960 / 7,830 | same | same | MATCH |
| EITC phase-out rates | 7.65 / 15.98 / 21.06 % | same | IRC 32(b)(1) | MATCH |
| Phase-out threshold, non-joint | 10,330 (0 children); 22,720 (1+) | same | Rev. Proc. §3.06(1), pp 9-10 | MATCH |
| Phase-out threshold, MFJ | 17,250; 29,640 | same | same | MATCH |
| Completed phase-out, non-joint 0/1/2/3+ | 18,591 / 49,084 / 55,768 / 59,899 | same | same; Pub 596 pp 2-4 | MATCH |
| Completed phase-out, MFJ 0/1/2/3+ | 25,511 / 56,004 / 62,688 / 66,819 | same | same; Pub 596 | MATCH |
| EITC investment income limit | 11,600 | 11,600 | Rev. Proc. §3.06(2), p 9; Pub 596 p 3; `i1040gi` p 38 | MATCH |
| EITC age range without child | 25 to 64 | attained 25 but not attained 65 | IRC 32(c)(1)(A)(ii) | MATCH |
| CDCC expense cap | 3,000 / 6,000 | 3,000 / 6,000 | IRC 21(c); `f2441` p 2 line 27 | MATCH |
| CDCC rate | 35% down 1 point per 2,000 to 20% | 35% to 20%, 20% from AGI 43,000 | IRC 21(a)(2); `i2441` p 7 table | MATCH |
| CDCC deemed earned income, student/disabled spouse | 250 / 500 per month | 250 / 500 | IRC 21(d)(2); `f2441` p 1; `i2441` p 4 | MATCH |
| Employer dependent care exclusion | 5,000 (2,500 MFS) | 5,000 (2,500 MFS) | IRC 129(a)(2)(A); `f2441` p 2 line 21 | MATCH |
| Saver's 50% band top: MFJ / HoH / other | 46,000 / 34,500 / 23,000 | same | Notice 2023-75 p 3 (25B(b)(1)(A)) | MATCH |
| Saver's 20% band top | 50,000 / 37,500 / 25,000 | same | same (25B(b)(1)(B)) | MATCH |
| Saver's 10% band top | 76,500 / 57,375 / 38,250 | same | same (25B(b)(1)(C)-(D)) | MATCH |
| Saver's contribution cap per person | 2,000 | "smaller of line 5 or $2,000" per column | `f8880` p 1 line 6; IRC 25B(a) | MATCH |
| Saver's credit limit ordering | after Sch 3 lines 1-3, 6d, 6l | Credit Limit Worksheet: Form 1040 line 18 minus Sch 3 lines 1-3, 6d, 6l | `f8880--2024.pdf` p 2 | MATCH |
| Schedule R AGI limits: single/HoH/QSS; MFJ one; MFJ both; MFS | 17,500; 20,000; 25,000; 12,500 | same | `i1040sr` p 7 Table 1 | MATCH |
| Schedule R nontaxable pension limits | 5,000 / 5,000 / 7,500 / 3,750 | same, same order as the rows above | `i1040sr` p 7 | MATCH |
| Schedule R initial amounts (line 10) | 5,000 / 7,500 / 3,750 | boxes 1,2,4,7: 5,000; 3,5,6: 7,500; 8,9: 3,750 | `f1040sr` p 2 | MATCH |
| Schedule R line 15 exemption amounts | 7,500 (boxes 1-2); 10,000 (boxes 3-7); 5,000 (boxes 8-9) | same | `f1040sr` p 2 | MATCH |
| Schedule R rate | 15% | 15% | `f1040sr` p 2 line 20 | MATCH |

## Income-side constants (scope.md §3, §4.3, §7)

| Constant | scope.md | Official | Source | Result |
|---|---|---|---|---|
| Student loan interest cap | 2,500 | 2,500 | IRC 221(b)(1) | MATCH |
| Student loan phase-out, non-joint | 80,000 to 95,000 | 80,000 to 95,000 | Rev. Proc. §3.30, p 16 | MATCH |
| Student loan phase-out, MFJ | 165,000 to 195,000 | 165,000 to 195,000 | same | MATCH |
| Educator expenses | 300 each | 300 | Rev. Proc. §3.13, p 11 | MATCH |
| HSA limits self-only / family | 4,150 / 8,300 | 4,150 / 8,300 | Rev. Proc. 2023-23 p 2; `f8889` p 1; Pub 969 | MATCH |
| HSA age-55 catch-up | 1,000 | 1,000 | IRC 223(b)(3); `i8889` p 4 | MATCH |
| OASDI wage base | 168,600 | 168,600 | Pub 15 (2024) p 2 | MATCH |
| Schedule B threshold | 1,500 | over 1,500 | `f1040sb` p 1; `i1040gi` p 25 | MATCH |
| Social Security worksheet bases | 25,000 / 32,000 | 25,000 / 32,000 (MFS living together: no base, 85% rule) | `i1040gi` p 32; IRC 86(c) | MATCH |
| Social Security worksheet gaps | 9,000 / 12,000 | 9,000 / 12,000 | `i1040gi` p 32 line 10 | MATCH |
| SS worksheet shape (lines 1-18: 50%, 85%, lesser of line 16 and 85% of benefits) | §3.5 | same | `i1040gi` p 32 | MATCH |
| NIIT-style AGI thresholds | 125k (MFS) / 200k / 250k (MFJ) | same | IRC 1411(b); Form 8959 p 1 | MATCH |
| Medicare wage thresholds for Form 8959 | 125,000 / 250,000 / 200,000 | same | `f8959` p 1 | MATCH |
| Presidential Election Campaign Fund | 3 (6 MFJ) | 3 (6 MFJ) | `i1040gi` p 13 | MATCH |
| Repayment of claim of right (1099-G/SS knockout threshold) | 3,000 | "exceeds $3,000" | IRC 1341(a)(3) | MATCH |

## PTC (scope.md §6.6)

| Constant | scope.md | Official | Source | Result |
|---|---|---|---|---|
| FPL (2023 guidelines used for TY2024), 48 states + DC | 14,580 + 5,140 per extra person | 14,580 for 1; 5,140 per additional person beyond 8 | `i8962` p 8 (lines table; "the 2023 federal poverty lines are used") | MATCH |
| FPL Alaska | 18,210 + 6,430 | same | `i8962` p 8 | MATCH |
| FPL Hawaii | 16,770 + 5,910 | same | `i8962` p 8 | MATCH |
| Percent of FPL: drop decimals; 401 if above 400% | truncated, 401 | "drop any numbers after the decimal point"; "Enter 401" | `i8962` p 9 | MATCH |
| Applicable figure: 0 up to 150%; (pct-150)*0.0004 for 151-300; 0.06 + 0.00025 per point 301-399; 8.5% from 400 | as listed | All 250 table rows (150 to 399) reproduced exactly using round-half-up to 4 decimals; "400 or more: 0.0850" | `i8962` p 10, Table 2 | MATCH |
| Repayment limit, single / other, below 200% | 375 / 750 | 375 / 750 | `i8962` p 17, Table 5 | MATCH |
| Below 300% | 950 / 1,900 | 950 / 1,900 | same | MATCH |
| Below 400% | 1,575 / 3,150 | 1,575 / 3,150 | same | MATCH |
| No cap at 400% and above | none | no limit | same | MATCH |
| Household income = AGI + tax-exempt interest + nontaxable SS (+ excluded foreign income) | omits foreign income | MAGI includes foreign earned income exclusions | IRC 36B(d)(2)(B); `i8962` p 8 | MATCH for the Direct File subset (foreign income is out of scope) |
| Aside: the 400% cliff is waived for 2021-2025 | scope applies applicable figure at 400+ = 8.5% | Table 2 gives 0.0850 for 400+, and the form allows PTC above 400% FPL for TY2024 | `i8962` p 1, p 10 | MATCH (note for #32: do not cut off eligibility at 400%) |

## 1040 line chain (scope.md §2)

All line numbers in scope.md §2 were checked against the TY2024 Form 1040 and Schedules 2, 3 (`f1040--2024`, `f1040s2--2024`, `f1040s3--2024`): lines 12-24, 25d-34, 37, 38, 1040 line 17 = Sch 2 line 3, line 20 = Sch 3 line 8, line 23 = Sch 2 line 21, line 31 = Sch 3 line 15, line 30 reserved. MATCH. Sch 3 line 8 adds lines 1-4, 5a, 5b and 7 (scope.md's "CDCC + Saver's + Schedule R" lands on lines 2, 4 and 6d via line 7).

## NOT FOUND or NOT CHECKED

| Item | Why |
|---|---|
| Direct File's `/w2MinAmount` 600 (scope.md §3.2) | Not in scope.md §7; no IRS source identified. It is probably a MeF or UX constant, not a tax-law number. |
| Day-before-birthday age rule (scope.md §4.2, §5.1) | Described in `i1040gi` (age 65 as of the day before the birthday) but the exact page was not located. Pub 501 / IRC 63(f) discussion applies. NOT CHECKED. |
| ACTC three-or-more-children alternative formula (scope.md §6.1) | Present in Sch 8812 instructions (`i1040s8` p 5) but the exact formula was not compared line by line. NOT CHECKED. |
| Qualifying-child and relative age/residency rules (scope.md §5.2) | Rule text, not constants. See IRC 152 and Pub 501. Not compared. |
| 1099-R distribution codes (scope.md §3.4) | Governed by Form 1099-R instructions, not downloaded (not on the request list). NOT FOUND. |
| Educator "up to 600 MFJ" | Follows from the 300 amount per eligible educator (IRC 62(a)(2)(D) and `i1040gi`); not separately sourced. |
