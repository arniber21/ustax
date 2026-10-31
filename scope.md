# scope.md: what IRS Direct File covers, and how to formalize it

Survey of the IRS Direct File source release (`../direct-file`), written to seed a Catala formalization of the same slice of US individual income tax law.

**Provenance.** Compiled by four read-only survey passes over the dump, then merged. Fact paths, dollar amounts and line numbers below are quoted from the XML. Items marked **(unverified)** were reported but not independently re-read. Before encoding any rule, re-read the cited XML yourself. This is a map, not a source of truth.

## 0. Headline facts

| | |
|---|---|
| Tax year | **TY2024** (`/taxYear` = 2024; filing deadline 2025-04-15). Federal only. |
| License | US-government public domain plus CC0 1.0 waiver, so you can copy rules and test data freely. |
| Status | Archived, "not for production". |
| Repo root | `../direct-file` (README, docs, `LICENSE`) with code in `../direct-file/direct-file` (`DF/` below). |
| Tax logic | `DF/backend/src/main/resources/tax/*.xml`: 36 modules, about 3,030 facts, about 65k lines. This is the formalization source. |
| Engine | `DF/fact-graph-scala` (Scala 3 / Scala.js, about 30k LOC). The reference interpreter of the XML, and your oracle. |
| Filing scope | Standard deduction only, ordinary-rate tax only, a deliberately narrow income set (section 3). Everything else is a **knockout** (section 9). |
| Missing from the dump | The MeF XML builder (external `MEF_REPO`), all XSDs, and the Java `FactGraphServiceScenarioTest` that produced the PDF goldens. |

The XML was authored by IRS engineers from the Code and Pubs, so it is a second-hand formalization. Where it disagrees with the statute, you must decide which wins (section 11 lists suspected disagreements).

## 1. Recommended formalization plan

1. **Spine first.** Encode the Form 1040 chain (section 2) with standard deduction and the tax-rate schedule, for wages and interest only. That gives an end-to-end tax calculator you can test against the oracle.
2. **Add modules in this order:** filing status and standard deduction, then dependents, then credits (CTC/ODC/ACTC, EITC, CDCC, Saver's, Schedule R), then remaining income types (1099-G, SS, 1099-R, HSA), and PTC last. PTC is the largest module (9.8k lines) but is mostly 12-month repetition.
3. **Model knockouts as part of the spec.** Each scope-limiting condition becomes a Catala exception or an explicit `unsupported` output. This tells the reader what the program refuses to do.
4. **Differential-test continuously** against the reference engine on the 322 scenarios (section 10).
5. Keep specs in their own files and review them as the trusted surface, per `CLAUDE.md` sections 4 and 7.

### Mapping the fact graph to Catala

| Fact graph | Catala |
|---|---|
| module (`filers.xml`, `eitc.xml`, ...) | scope or module |
| `Writable` fact | `input` variable |
| `Derived` fact | `output` or `internal` variable with a `definition` |
| `Switch/Case/When/Then` | `match` or conditional definitions with exceptions |
| `Dependency module=m path=/p` | scope call or module import |
| Collections `/familyAndHousehold/*/x`, `CollectionSum`, `Filter`, `Count` | `list of Struct` with `map`, `filter`, `sum` |
| `Round` (HALF_UP to whole dollar), `TruncateCents` | explicit `round` and truncation in `money` / `decimal`. Check the semantics: see section 8. |
| `Placeholder` and `Incomplete` | see section 8; probably not modelled (assume complete inputs) |
| `BlockSubmissionOnTrue` facts and `flowIsKnockedOut` | an `unsupported` boolean output, plus a lemma that `unsupported = false` implies the computation is the intended one |

The tax logic is mostly pure arithmetic and boolean tests, so it translates directly. The hard parts are the dependency tests (section 5) and the circular-looking dependencies between filing status, dependents and credits (section 5.4).

## 2. The Form 1040 computation chain (`taxCalculations.xml`, 1778 lines)

Every fact in this module is derived. `Round` = nearest whole dollar, half up.

| 1040 line | Fact | Definition |
|---|---|---|
| 1a | `formW2s/wages` | `Round(sum of W-2 box 1)` |
| 1z | `income/employerIncomeSubtotal` | `Round(primary W-2 wages + secondary W-2 wages + taxableDependentCare)`. Other earned-income lines 1b to 1h are hard-wired 0. |
| 2b | `interest/interestIncome` | rounded 1099-INT box 1 + box 3 (per item if Schedule B required) |
| 3, 4, 7 | dividends, IRA distributions, capital gains | **hard-wired 0** ("OUT OF SCOPE") |
| 5b | `income/taxablePensionsAndAnnuities` | `fullyTaxablePensions + taxableAmountsOfPartiallyTaxablePensions` |
| 6b | `socialSecurity/taxableSocialSecurityBenefits` | SS benefits worksheet (section 3.5) |
| 8 | `income/otherIncome` | `Round(unemploymentCompensation + schedule1TotalOtherIncome)`. The Alaska PFD is the only "other income" besides unemployment. |
| 9 | `income/totalIncome` | `Round(employerIncomeSubtotal + interestIncome + ordinaryDividends + taxableIraDistributions + taxablePensionsAndAnnuities + taxableSocialSecurityBenefits + capitalGainsOrLosses + otherIncome)` |
| 10 | `adjustmentsToIncome` | `Round(studentLoanInterestAdjustmentAmount + educatorExpensesAdjustment + hsaTotalDeductibleAmount)`. No other Schedule 1 adjustments. |
| 11 | `agi` | `Round(totalIncome - adjustmentsToIncome)` |
| 12 | `standardOrItemizedDeductions` | standard deduction only (`wantsStandardDeduction` is hard-coded `True`) |
| 13 | `qualifiedBusinessIncomeDeduction` | stub `$0` |
| 14 | `totalDeductions` | `Round(standardOrItemizedDeductions)` (QBI not added) |
| 15 | `taxableIncome` | `Round(GreaterOf(agi - totalDeductions, 0))` |
| 16 | `tentativeTaxFromTaxableIncome` | rate schedule applied to a rounded income (section 2.1) |
| 17 | `schedule2/totalAdditionalTaxesOwed` | excess APTC repayment only (PTC module) |
| 18 | `totalTentativeTax` | `Round(line16 + line17)` |
| 19 | `ctcOdc/totalCtcAndOdc` | Schedule 8812 line 14 |
| 20 | `schedule3/line8OfSchedule3` | CDCC + Saver's + Schedule R credit (+ zero placeholders) |
| 21 | `nonRefundableCredits` | `Round(line19 + line20)` |
| 22 | `taxLessNonRefundableCredits` | `Round(GreaterOf(totalTentativeTax - nonRefundableCredits, 0))` |
| 23 | `line21OfSchedule2` | stub `$0`. **It is defined but not added into `totalTax`.** |
| 24 | `totalTax` | `Round(taxLessNonRefundableCredits)` |
| 25a, b, c | W-2 withholding; 1099 withholding (INT, SSA, G, MISC, R); other (`$0`) | |
| 25d | `totalWithholding` | `Round(formW2Withholding + form1099Withholding)` |
| 26 | `estimatedPayments/estimatedAndFromLastYear` | writable dollar amount, if the user said they paid |
| 27 | `eitc/earnedIncomeCredit` | section 6.2 |
| 28 | `ctcOdc/additionalCtc` | ACTC, section 6.1 |
| 29 | `americanOpportunityCredit` | stub `$0` (Form 8863 unsupported) |
| 31 | `schedule3/otherPaymentsAndRefundableCreditsTotal` | net PTC when positive |
| 32 | `totalOtherPaymentsRefundableCredits` | `Round(eitc + additionalCtc + aoc + line31)` |
| 33 | `totalPayments` | `Round(totalWithholding + estimatedPayments + line32)` |
| 34 | `overpayment` | `Round(GreaterOf(totalPayments - totalTax, 0))` |
| 37 | `balanceDue` | `Round(GreaterOf(totalTax - totalPayments, 0))` |

Not computed anywhere: line 38 estimated-tax penalty, line 36 (hard-wired 0), Form 8888.

### 2.1 Tax computation: table midpoint, then rate schedule

Direct File does **not** store the printed Tax Table. `roundedTaxableIncome` (the lookup key) is:

| Taxable income TI | `roundedTaxableIncome` |
|---|---|
| TI <= 0 | 0 |
| TI < 5 | 2.50 |
| TI < 15 | 10 |
| TI < 25 | 20 |
| TI < 3,000 | `StepwiseMultiply(TI, 25/25) + 12.50` (midpoint of the $25 row) |
| TI < 100,000 | `StepwiseMultiply(TI, 50/50) + 25` (midpoint of the $50 row) |
| TI >= 100,000 | TI itself |

The rate schedule is applied to that value and then rounded. That reproduces the IRS Tax Table rows. Hard-coded **2024 schedules** (upper bound, then base tax plus rate on the excess over the previous bound):

- **MFJ and QSS:** 23,200 at 10%; 94,300: 2,320 + 12%; 201,050: 10,852 + 22%; 383,900: 34,337 + 24%; 487,450: 78,221 + 32%; 731,200: 111,357 + 35%; above: 196,669.50 + 37%.
- **Head of household:** 16,550 at 10%; 63,100: 1,655 + 12%; 100,500: 7,241 + 22%; 191,950: 15,469 + 24%; 243,700: 37,417 + 32%; 609,350: 53,977 + 35%; above: 181,954.50 + 37%.
- **Single:** 11,600 at 10%; 47,150: 1,160 + 12%; 100,525: 5,426 + 22%; 191,950: 17,168.50 + 24%; 243,725: 39,110.50 + 32%; 609,350: 55,678.50 + 35%; above: 183,647.25 + 37%.
- **MFS:** same as Single through 243,725; then 365,600: 55,678.50 + 35%; above: 98,334.75 + 37%.

These match my recollection of the published 2024 schedules, but I did not re-check them against Rev. Proc. 2023-34; do that. Not handled: the qualified dividends / capital gain worksheet (0/15/20%), Schedule D tax, kiddie tax (Forms 8814/8615), Form 4972, foreign earned income tax worksheet.

## 3. Income side (what is supported)

Supported income: W-2 wages, 1099-INT interest, 1099-G unemployment, 1099-R pensions (codes 2, 7, G, H only), SSA-1099 / RRB-1099, and Alaska PFD via 1099-MISC box 3. HSA (Form 8889) is a separate adjustment module. Everything else is hard-wired zero or a knockout.

### 3.1 Pattern used everywhere

A `writableX` input plus a derived `X` that defaults to `$0` when the input is incomplete, usually wrapped in `Round`. Dollar boxes are rounded **per item before summing**. Schedule B is the exception: `interestIncome` sums per-item rounded amounts only when `requiresScheduleB`, otherwise it rounds the raw sum. Per-filer collections are `*/filer`-tagged for MFJ.

### 3.2 W-2 (`formW2s.xml`, 6970 lines)

- Wages (line 1a) is the rounded sum of box 1 over `/formW2s/*/wages`. Per-filer sums come from `/primaryFilerWages` and `/secondaryFilerWages`.
- `/socialSecurityTaxesWithheld` = `Round(sum OASDI withholding + sum Medicare withholding)`. This feeds the ACTC three-child alternative.
- Form 8880 line 2 (`~/totalDeferralsAndContributions`) sums the box 12 deferral amounts (exact letter codes not recorded by the survey; check the XML): 401k, 403b, SARSEP, 457b (only if governmental), 501(c)(18)(D), SIMPLE, Roth variants.
- Combat pay (box 12 code Q) aggregates per filer. `combatPayAmount` (1040 line 1i) follows the EITC election.
- Constants: `/w2MinAmount` 600; Medicare-wage thresholds 125,000 (MFS) / 250,000 (MFJ) / 200,000 (others); OASDI cap **168,600** (TY2024).
- W-2 boxes 12 and 14 produce many MeF-only helper facts (`...Needed`, `...Rounded`). You can ignore these.

### 3.3 Interest (`interest.xml`)

- `~/taxableInterest` = box 1 + box 3 if a 1099-INT exists, else the no-1099 amount. `/interestIncome` is line 2b. `/taxExemptInterest` (2a) feeds EITC investment-income test, SS worksheet and PTC.
- `/requiresScheduleB` = taxable interest > **1,500** OR foreign accounts/trusts.
- NIIT disqualifiers: interest income > 0 and AGI above 200,000 (single/HoH), 250,000 (MFJ/QSS) or 125,000 (MFS) is a knockout.

### 3.4 Unemployment, Alaska PFD, 1099-R

- **1099-G:** `/unemploymentCompensation` = `Round(sum(amount - amountPaidBackInTaxYear))`, with repayment capped at box 1 per form. Repayment of prior-year benefits above **3,000** is a knockout.
- **1099-MISC:** every form is treated as an Alaska PFD (`isAlaskaPfd` always true). `/alaskaPfdIncome` = rounded sum of box 3, feeding Schedule 1 line 8g.
- **1099-R:** distribution code is cleaned with `StripChars(ToUpper(Trim(code)), "247BGH")` and must be one of `2, 7, G, H, 2B, B2, 7B, B7, BG, GB, 4G, G4, 4H, H4`. Classification: tax-free rollover (code G or H, taxable 0), fully taxable (gross = taxable), partly taxable. Line 5b = `fullyTaxablePensions + taxableAmountsOfPartiallyTaxablePensions`. IRA/SEP/SIMPLE, indirect and taxable rollovers, early distributions (code 1), disability (code 3) are all knockouts.

### 3.5 Social Security (`socialSecurity.xml`): the benefits worksheet

Let `B` = net benefits (SSA box 5 or RRB box 5, can be negative).

- Line 3 = wages + interest + dividends + IRA + pensions + capital gains + other income (excludes SS).
- Line 7 = `max(0, 0.50 B + line3 + taxExemptInterest - adjustmentsExcludingStudentLoanInterest)`.
- Line 8 = 32,000 (MFJ) else 25,000. Line 9 = line7 - line8. Line 10 = 12,000 (MFJ) else 9,000. Line 11 = `max(0, line9 - line10)`.
- Line 16: MFS and not lived apart all year: `0.85 * line7`; else if line7 < line8: 0; else `0.85 * line11 + LesserOf(0.50 B, 0.50 * LesserOf(line9, line10))`.
- Taxable benefits (6b) = 0 if `B < 0`, else `Round(LesserOf(line16, 0.85 B))`.
- Net repayment above 3,000 (a section 1341 case) is a knockout; lump-sum election is hard-wired off.

### 3.6 HSA (`hsa.xml`, Form 8889)

TY2024 limits: self-only **4,150**, family **8,300**, age-55 catch-up **1,000**. Chain: line 3 initial limit, 5, 6 (family allocation), 7 (catch-up), 8 total limit, 11 (employer contributions from W-2 box 12 W), 12, 13 `hsaTotalDeductibleAmount = LesserOf(nonemployer contributions, line12)`. Distributions: line 14a/b/c and 15 are computed, but line 16 (taxable distributions) is hard-wired 0, and distributions beyond qualified expenses are a knockout. About 25 HSA knockouts (excess contributions, other coverage, testing period, mid-year marital change...).

### 3.7 Estimated payments

Single writable dollar amount plus name-change and former-spouse flags. Payments made under a different last name are a knockout.

## 4. Filing status, deductions, adjustments

### 4.1 Filing status (`filingStatus.xml`)

Only `/filingStatus` and `/filingStatusChoice` are writable.

- `eligibleForMFJ` = (married OR widowed in tax year) AND spouse is full-year citizen/resident (no 6013(g)/(h) election).
- `eligibleForMFS` = married or widowed in tax year. `eligibleForSingle` = not married.
- `eligibleForHoh` = at least one `hohQualifyingPerson` AND `filerCouldQualifyForHoh` AND NOT `eligibleForQss`. `filerCouldQualifyForHoh` = NOT eligibleForMFJ OR lived apart last six months ("considered unmarried", IRC 7703(b)).
- `eligibleForQss` = widowed, spouse died in `taxYear - 1` or `- 2`, `canFileJointlyYearOfSpouseDeath`, and a `qssQualifyingPerson` exists. QSS preempts HoH.
- `treatAsMFJ/MFS/HoH` let downstream modules compute before the status is finalized.

### 4.2 Standard deduction (`standardDeduction.xml`)

| | Amount |
|---|---|
| MFJ and QSS | **29,200** |
| Single and MFS | **14,600** |
| Head of household | **21,900** |
| Additional per blind or 65+ item | **1,950** (single/HoH), **1,550** (MFJ/QSS/MFS) |
| Dependent filer minimum | `GreaterOf(1,300, employerIncomeSubtotal + 450) + additional`, and the deduction is `LesserOf(minimum, normal)` |

Spouse items count only if MFJ, or MFS with a spouse who is eligible for the deduction. Age 65 uses the **day-before-birthday rule** (`ageCalculatedDayBeforeDOB >= 65`). A deceased MFJ spouse uses age at death.

### 4.3 Adjustments

- **Educator** (Schedule 1 line 11): `LesserOf(300, expenses)` per educator, so up to 600 MFJ. Zero for an MFJ-dependent filer.
- **Student loan interest**: `LesserOf(interest, 2,500)` minus a pro-rata phase-out. MAGI = `totalIncome - adjustmentsExcludingStudentLoanInterest`. Phase-out starts at **80,000** (non-MFJ) / **165,000** (MFJ) and ends at **95,000** / **195,000**. Disallowed for MFS, for a filer claimed as a dependent, or for MAGI above the end. The XML computes the ratio at three decimals (a `x10 / 10` trick around dollar rounding), so its result can differ from the exact fraction by a dollar. Mirror it if you want exact agreement with the oracle.
- **HSA** (section 3.6).

### 4.4 Other small modules

`refundPrefs.xml` (third-party designee, language/format preference, Presidential Election Campaign Fund, $3 each or $6 MFJ), `paymentMethod.xml` (ACH dates, bank account, refund disbursement code), `signing.xml` (prior-year AGI or PIN identity, paper-path fallback). These are mostly I/O and not worth formalizing for a tax-correctness proof.

## 5. Households and dependents (`filers`, `familyAndHousehold`, `dependents*`)

This is the most legally intricate part and the best target for a Catala rules-as-code treatment.

### 5.1 Filer facts (`filers.xml`, 5544 lines)

- `age` = 2024 - birth year (age at 12/31). `age65OrOlder` uses the day-before-birthday rule. EITC min age 25 uses day-before-birthday; EITC max age 64 uses actual birthday.
- Marital: `isMarried`, `isWidowed`, `isWidowedInTaxYear`; `livedApartLastSixMonths`; `specialRuleForSeparatedSpouses`.
- "Filer is claimed as a dependent" (`treatFilersAsDependents`) drives the reduced standard deduction and kills dependents and several credits. For MFJ, one spouse may be a "MFJ dependent" (refund-only return).
- `minimumFilerDateOfBirth` (oldest filer's date of birth) is used for "younger than the taxpayer" child tests.

### 5.2 Qualifying child, qualifying relative, eligible dependent

All per-person, in `familyAndHousehold.xml`.

**Qualifying child** = all of:
1. Relationship in {biological, adopted, step, foster child; sibling, half-sibling, step-sibling; descendants of those}.
2. Age: (under 19 AND younger than the oldest filer) OR (full-time student, strictly older than 18 and younger than 24 at year end, AND younger than oldest filer) OR permanently and totally disabled.
3. Residency: lived with taxpayer more than half the year (anything but "less than six months").
4. Not self-supporting (`ownSupport` false).
5. Joint-return test: not married, or not filing jointly, or filing only for refund and not required to file.

**Qualifying relative** = not a qualifying child of another AND (relationship in the qualifying-relative set OR lived with taxpayer all year) AND gross income < **5,050** (`/grossIncomeLimit`; Rev. Proc. 2023-34 §3.24 and Pub 501. Direct File's own comment cites Rev. Proc. 24-40, which is the TY2025 procedure and gives 5,200) AND taxpayer provided over half support.

**Eligible dependent** = (QC or QR) AND not disqualified by parental custody rules AND not a benefit-split case AND citizen/resident test AND joint-return test AND has a TIN. `isClaimedDependent` also requires the taxpayer to elect `tpClaims`.

### 5.3 Credit-specific person tests

- **CTC**: claimed, qualifying child, age < 17 at 12/31, SSN valid for employment, citizen/resident test.
- **ODC**: claimed, not CTC-eligible, citizen/resident test.
- **EITC qualifying child**: relationship + age + residency + joint-return test (no support test), claimed-if-claimable, special rules for children of another.
- **CDCC qualifying person**: QC under 13 (or turning 13 after Jan 1), or a dependent or spouse unable to care for self.
- **HoH qualifying person**: three paths: a qualifying child for whom the taxpayer paid most of home upkeep; a parent (need not live with taxpayer) with parent-home upkeep; another qualifying relative who lived there over half the year. If the taxpayer is married but considered unmarried, only biological/adopted/step/foster child qualifies.
- **QSS qualifying person**: biological/adopted/step child who lived with the taxpayer all year, taxpayer paid most of home upkeep. Foster children excluded.

### 5.4 Circularity (watch for this)

Filing status depends on HoH and QSS qualifying persons. Those depend on dependent facts, which depend on `treatFilersAsDependents`, which depends on MFJ status. Direct File breaks cycles with `treatAsMFJ` and `filerCouldQualifyForHoh` (which uses `eligibleForMFJ`, not `eligibleForHoh`). In Catala, define eligibility first, choose the status as an **input**, then compute everything else, and add a lemma that the chosen status is among the eligible ones.

### 5.5 Divorced/separated parents (`dependentsBenefitSplit.xml`)

Form 8332 / IRC 152(e) logic: custodial parent = more nights, or equal nights and higher AGI. A custodial parent who released the claim keeps HoH, EITC and CDCC. Noncustodial claimants and contradictory 8332 answers are knockouts. Age of majority is assumed 18 (no MS/PR 21 or AL/NE 19).

### 5.6 Known simplifications

QC tie-breakers (two taxpayers both able to claim the same child) are explicitly **not** implemented (TODO in the XML). Only Canada/Mexico residency is allowed for non-US dependents.

## 6. Credits

All amounts are TY2024.

### 6.1 CTC / ODC / ACTC (`ctcOdc.xml`, Schedule 8812)

- Per-child **2,000** (CTC), per-dependent **500** (ODC), refundable cap **1,700** per child (ACTC), earned-income floor **2,500** at rate **15%**.
- MAGI = AGI. Phase-out threshold **400,000** (MFJ) / **200,000** (others). Reduction is 5% of MAGI over threshold **rounded up to the next 1,000** (`StepwiseMultiply(excess + 999.99, 1000/1000)`).
- Line 13 credit limit = `max(0, totalTentativeTax - (sched3 line 1 + CDCC + sched3 line 3 + saver's + sched3 line 5b + Schedule R + other nonrefundable))`. So CTC/ODC come **last** in the nonrefundable ordering.
- Line 14 `totalCtcAndOdc = Round(LesserOf(creditAfterPhaseout, creditLimit))`. ODC is applied first and reduced first in the split.
- ACTC (line 27 = 1040 line 28) = `Round(LesserOf(remainingPotentialActc, maximumActc))`, where `maximumActc` is the regular amount, or, with three or more CTC children, `GreaterOf(regular, socialSecurityTaxesWithheld - earnedIncomeCredit)`.
- Improper-claims ban (Form 8862) is a writable-input gate.
- Circular reference: ACTC uses the EITC; the Part I limit uses `totalTentativeTax`. Both are acyclic as written.

### 6.2 EITC (`eitc.xml`, Pub 596)

- Phase-in rates: 0 children 7.65%, 1 child 34%, 2 children 40%, 3+ 45%. Phase-in ends at earned income **8,260 / 12,390 / 17,400 / 17,400**. Max credit **632 / 4,213 / 6,960 / 7,830**.
- Phase-out rates **7.65% / 15.98% / 21.06%** (0 / 1 / 2+ children). Thresholds: single/HoH/QSS/MFS **10,330** (0 children) or **22,720** (1+); MFJ **17,250** or **29,640**.
- Completed phase-out: non-MFJ 18,591 / 49,084 / 55,768 / 59,899; MFJ 25,511 / 56,004 / 62,688 / 66,819.
- Investment-income limit **11,600**: `taxExemptInterest + interestIncome + dividends + max(capitalGains, 0) <= 11,600`.
- The Pub 596 table is **emulated by evaluating the formula at the midpoint of the $50 row**: `StepwiseMultiply(income, 50/50) + 25`, then the lesser of the earned-income-based and AGI-based amounts. Match this exactly to agree with the IRS table, and read the phase-in "+24" adjustment closely.
- Eligibility: earned income > 0, below the completed phase-out on both earned income and AGI, investment-income limit, `filersCouldQualifyForEitc`, MFS only under the separated-spouse special rule, age 25 to 64 if no qualifying child, QC-of-another test, and improper-claims notice.
- Combat pay is elective. The app computes four variants (no / primary / secondary / both) and recommends the largest.

### 6.3 CDCC (`cdcc.xml`, Form 2441)

- Expense cap **3,000** (one qualifying person) / **6,000** (two or more). Percentage by AGI: 35% at AGI <= 15,000 falling 1 point per 2,000 to **20%** above 43,000 (`cdccCareExpensesDecimalAmount`).
- Credit = `LesserOf(tentative amount, creditLimit)` where creditLimit = `totalTentativeTax`. Earned income limit: lesser of both spouses' earned income, with deemed income of **250 / 500 per month** for a student or disabled spouse.
- Dependent care benefits (Part III): exclusion cap **5,000** (**2,500** MFS). Excluded benefits reduce the expense cap.
- Unsupported: prior-year expenses paid in 2024 (Worksheet A), household employees, sole-proprietorship benefits.

### 6.4 Saver's credit (`saversCredits.xml`, Form 8880)

AGI bands (Notice 2023-75): 50% up to **46,000** MFJ / **34,500** HoH / **23,000** other; 20% up to **50,000** / **37,500** / **25,000**; 10% up to **76,500** / **57,375** / **38,250**; zero above. Per-person cap **2,000** of contributions. Counts **W-2 elective deferrals only**; IRA and ABLE contributions are placeholders at zero. Contributions are reduced by 1099-R distributions. Limited by remaining tax liability after CDCC and Schedule R credit. Ineligible: under 18, full-time student, or claimed as dependent.

### 6.5 Credit for the elderly or disabled (`elderlyAndDisabled.xml`, Schedule R)

AGI limits: **17,500** (single/HoH/QSS), **12,500** (MFS), **25,000** (MFJ both qualify), **20,000** (MFJ one qualifies). Nontaxable-payment limits **5,000 / 3,750 / 7,500 / 5,000**. Filing-status amounts 5,000 / 7,500 / 3,750 (line 10); AGI exemption amount 5,000 (MFS cases), 7,500 (lines 1 and 2), else 10,000. Credit is the net amount (line 19) limited by remaining tax; the 15% rate step was not read by the survey, so check `netEdcAmount`. Those thresholds are not tagged with a tax year in the XML. Verify them against the Schedule R instructions.

### 6.6 Premium tax credit (`ptc.xml`, Form 8962)

By far the largest module (9,760 lines, about 147 writable inputs) because the 1095-A data repeats for 12 months across premium / SLCSP / APTC columns.

- Tax family size = 1 or 2, plus claimed dependents. FPL (2023 guidelines) = **14,580 + 5,140 per extra person** (48 states and DC), Alaska **18,210 + 6,430**, Hawaii **16,770 + 5,910**.
- Household income = AGI + tax-exempt interest + nontaxable SS. Percent of FPL is truncated, and set to 401 above 400%.
- Applicable figure (2024 table): 0 up to 150%; `(pct - 150) * 0.0004` for 151 to 300%; then 0.06 rising by 0.00025 per point to 399%; 8.5% from 400%.
- Annual path (if any 1095-A has no changes and 12 months) or monthly path; allowed PTC = lesser of max assistance (SLCSP - contribution) and premium.
- Net PTC positive goes to 1040 line 31. Negative goes through the **repayment limitation** (single / other): under 200% FPL 375 / 750, under 300% 950 / 1,900, under 400% 1,575 / 3,150, none above. The result goes to Schedule 2 line 1a and 1040 line 17.
- Many knockouts: shared policy allocations, multiple 1095-As in some cases, QSEHRA, employer plans, alternative marriage-year calculation, dependent-taxpayer branches.
- **Recommendation:** formalize PTC last, and only if time permits.

### 6.7 Schedules 2 and 3

Schedule 2 supports only excess APTC repayment (line 1a). Schedule 3 sums CDCC + Saver's + Schedule R, with six placeholder lines held at `$0`. **Credit application order:** CDCC, then Schedule R, then Saver's, then CTC/ODC.

## 7. Constants cheat-sheet (TY2024)

| Item | Value | Source |
|---|---|---|
| Standard deduction | 14,600 / 21,900 / 29,200 | `standardDeduction.xml` |
| Additional (65+/blind) | 1,950 / 1,550 | same |
| Dependent minimum | 1,300 (+450 earned) | same |
| Qualifying relative gross income | 5,050 | `familyAndHousehold.xml` |
| CTC / ODC / ACTC | 2,000 / 500 / 1,700 | `ctcOdc.xml` |
| CTC phase-out | 200k / 400k | same |
| EITC investment income limit | 11,600 | `eitc.xml` |
| CDCC caps | 3,000 / 6,000 | `cdcc.xml` |
| Student loan | 2,500; 80k to 95k / 165k to 195k | `studentLoanAdjustment.xml` |
| Educator | 300 each | `educatorAdjustment.xml` |
| HSA | 4,150 / 8,300 / +1,000 | `constants.xml` |
| OASDI wage cap | 168,600 | `formW2s.xml` |
| Schedule B threshold | 1,500 | `interest.xml` |
| SS worksheet bases | 25,000 / 32,000; gaps 9,000 / 12,000 | `socialSecurity.xml` |
| NIIT-style AGI thresholds | 125k / 200k / 250k | `interest.xml` |
| Presidential Election Campaign Fund | 3 (6 MFJ) | `refundPrefs.xml` |

## 8. Engine semantics you must decide on

Source: `DF/fact-graph-scala`, schema `tax/FactDictionaryModule.rng`.

- **Facts**: `Writable` (typed input with limits) or `Derived` (one expression tree), optional `Placeholder` default, flags `Export` (mef / downstreamFacts / stateSystems), `ExportZero`, `BlockSubmissionOnTrue`, `TaxYear`. There is no "Significant" attribute.
- **Operators**: Add, Subtract, Multiply, Divide, StepwiseMultiply, Round, RoundToInt, TruncateCents, GreaterOf, LesserOf, Minimum, Maximum; Equal, NotEqual, four ordering comparisons, Not, All, Any, Switch, IsComplete, EnumOptionsContains; Dependency; CollectionSum, CollectionSize, Count, Filter, Find, IndexOf, FirstNCollectionItems; string operations (Paste, ToUpper, Trim, StripChars, Regex...).
- **Dollar** is `BigDecimal` with scale 2, constructed with HALF_EVEN. `Round` is HALF_UP to whole dollars. `TruncateCents` truncates down. Rationals (`n/d`) convert to `Dollar` through a **Float** division in at least one conversion (a possible precision quirk worth testing).
- **Completeness**: every fact evaluates to `Complete | Placeholder | Incomplete`. Binary operators return Incomplete if either side is. `Switch`, `Any` and `All` are Incomplete only when needed operands are. `Placeholder` keeps downstream math running with a default while marking the answer unconfirmed. A formal spec can **assume complete inputs** and separately state a total-function version. Say which you chose in the README.
- **Collections**: addressed `/collection/#<uuid>/child`; `*` returns a vector. Derived facts inside collections use `../` relative paths.

## 9. What is NOT supported (knockouts)

`/flowIsKnockedOut` in `flow.xml` is an `Any` over about 110 module-level knockout facts; the UI blocks submission when it is true. Screens live in `DF/df-client/df-client-app/src/flow` (92 `isKnockout` screens). Categories:

1. **Household:** filer under 16, community-property state with a married/ineligible status, itemizing MFS spouse, registered domestic partnership, non-resident-alien spouse, unsupported state, noncustodial claimant, contradictory Form 8332, person without a TIN, HoH qualifying person without a TIN.
2. **W-2:** unsupported box 12 codes (13 of them), allocated tips, nonqualified plans, statutory employee, third-party sick pay, other-state box 15, Medicare wages triggering Form 8959, OASDI wages over the cap across employers, NY RRTA / Yonkers part-year.
3. **1099-INT:** early-withdrawal penalty, bonds, foreign tax, tax-exempt interest, state withholding, FATCA.
4. **1099-G / 1099-R / SS:** large repayments; unsupported 1099-R codes and rollovers; SS repayments over 3,000; SS lump-sum.
5. **HSA, PTC, Saver's, CDCC, EITC, CTC:** as listed in section 6.
6. **Income scope:** digital assets, foreign accounts or trusts, IRA contributions, anything on Schedules C/D/E, dividends, capital gains.
7. **Process:** return too late to file, no income or credits at all (`knockoutHasNoPaymentsOrCredits`).

**Not computed:** itemized deductions, QBI, self-employment tax, Additional Medicare Tax, NIIT, AMT, education credits, foreign tax credit, estimated-tax penalty, capital gains rates.

## 10. Test assets for differential testing

All under `DF/backend/src/test/resources` unless noted.

- **`scenarios/*.json`**: **322** tax-return scenarios. Each holds the writable facts only: `{ "facts": { "/path": { "$type": "gov.irs.factgraph.persisters.<Type>Wrapper", "item": ... } } }`. Names indicate coverage (`single-*`, `mfj-*`, `hoh-*`, `mfs-*`, `ptc-*`, `hsa-*`, `cdcc-*`, `1099r-*`, `apf-*`, `ats-*`, `mef-ats-*`). Symlinked into the client tests.
- **`pdf-expected/{en,es}/*.yml`**: 176 per language. Filled-PDF field to value maps (Form 1040 and schedules). This is the best golden output, but the driver that matched scenario to YAML is missing. Re-derive the mapping from file names.
- **`scenarios/state-api-exported-data-snapshots/`**: 4 expected-export JSON files.
- **`docs/testing/fact-graphs/*.json`**: 28 small filing-status graphs.
- **Reference engine as oracle**: evaluate `/agi`, `/totalTax`, `/overpayment`, `/balanceDue` and every `Export mef="true"` fact on each scenario. Either run `sbt` in `DF/fact-graph-scala`, or the JS bundle in `DF/df-client/js-factgraph-scala` through the vitest harness in `DF/df-client/df-client-app/src/test/factDictionaryTests` (helpers `setupFactGraph.ts`, `testData.ts`). About 30 vitest files there already assert module behaviour.
- `goldenScenarios.ts` holds a single self-described unvetted golden. Tax-amount goldens are otherwise sparse.
- `scenarioTests/flow-snapshots/*.csv` (175) record screen routing, which is not tax math.

Recommended workflow: dump `(scenario, fact, value)` triples from the oracle into a single CSV in this repo, then check Catala output against that CSV with `clerk test` or a small script.

## 11. Things in the reference implementation that look wrong or surprising

Each may be a bug in Direct File, a deliberate simplification, or a misreading by the survey. **Check each against the XML and the law before encoding.** Decide per item whether the formalization reproduces the reference or the statute, and record that decision.

1. `/pensionsAndAnnuities` (1040 line 5a) = `taxFreePensionRollovers + partlyTaxablePensions`, with no `fullyTaxablePensions` term (income slice).
2. `form1099RsDistributionCodeValidChars` is `"247BGH"`, so codes 1 and 3 are stripped before use, and the code-1/code-3 branches look unreachable (income slice).
3. `/line21OfSchedule2` is a `$0` stub and is **not** added into `/totalTax` (credits slice).
4. `/qualifiedBusinessIncomeDeduction` and `/americanOpportunityCredit` are stubs at `$0`.
5. `disabilityStatusMayAffectBenefits` direction: the survey flagged the sub-18 branch as "as coded" and possibly inverted (household slice, **unverified**).
6. Qualifying-child tie-breakers are not implemented (explicit TODO in the XML).
7. `lastYearAgiFromOLA` is typed `Int` with a comment saying it should be `Dollar`.
8. Descriptions mention TY2023 while constants are tagged `<TaxYear>2024</TaxYear>` (income slice).
9. Schedule R thresholds and a few other constants carry no `TaxYear` tag.
10. The `Rational` to `Dollar` conversion goes through `Float` in at least one place (engine slice).
11. The survey's list of `scopedStateOptions` was reconstructed from a stripped grep and may be missing codes (credits slice, **unverified**). Re-read `constants.xml`.

## 12. Source map

| Topic | File (under `DF/backend/src/main/resources/tax/`) | Lines |
|---|---|---|
| 1040 chain, tax schedules | `taxCalculations.xml` | 1778 |
| Constants, enums, dates | `constants.xml` | 1035 |
| Income aggregation | `income.xml` | 1779 |
| W-2 | `formW2s.xml` | 6970 |
| Interest | `interest.xml` | 1626 |
| 1099-G | `unemployment.xml` | 841 |
| 1099-MISC (Alaska PFD) | `form1099Misc.xml` | 441 |
| 1099-R | `form1099Rs.xml` | 3538 |
| Social Security | `socialSecurity.xml` | 901 |
| HSA | `hsa.xml` | 4064 |
| Estimated payments | `estimatedPayments.xml` | 261 |
| Filing status | `filingStatus.xml` | 1116 |
| Filers, residency, marital | `filers.xml` | 5544 |
| Spouse section | `spouseSection.xml` | 815 |
| Dependents | `familyAndHousehold.xml`, `dependentsRelationship.xml`, `dependentsBenefitSplit.xml` | 5204, 1321, 687 |
| Standard deduction, educator, student loan | `standardDeduction.xml`, `educatorAdjustment.xml`, `studentLoanAdjustment.xml` | 355, 289, 440 |
| CTC / ODC | `ctcOdc.xml` | 1596 |
| EITC | `eitc.xml` | 2671 |
| CDCC | `cdcc.xml` | 4152 |
| PTC | `ptc.xml` | 9760 |
| Saver's | `saversCredits.xml` | 1705 |
| Schedule R | `elderlyAndDisabled.xml` | 1810 |
| Schedules 2, 3 | `schedule2.xml`, `schedule3.xml` | 43, 240 |
| Knockout aggregation | `flow.xml`, `validations.xml` | 790, 40 |
| Output formatting (MeF regexes) | `mefTypes.xml` | 59 |
| Schema | `FactDictionaryModule.rng` | 1147 |

Docs worth reading in `../direct-file/docs`: `adr/tax-logic-testing-strategy.md`, `adr/adr-fact-modules.md`, `adr/adr-fact-dictionary-tests.md`, `adr/adr-optional-facts.md`, `engineering/tax-flow/writing-facts.md`, `engineering/tax-flow/Tax_Code_to_Factgraph.pdf`, `engineering/Tax-Logic.md`, `testing/fact-graph-library.md`, and `DF/fact-graph-scala/README.md`.
