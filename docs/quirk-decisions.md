# Quirk decisions and the tests that pin them (issue #60)

One row per entry of `docs/direct-file-bugs.md` (DF-BUG-1 to DF-BUG-33) and per item of
`catala/CONVENTIONS.md` section 8 (Q1 to Q12, Q-R1 to Q-R3). Each row gives the decision, the
reason with its citation, where the decision lives in Catala and in Lean, and the test that pins
it. The policy is CONVENTIONS section 8 (changed 2026-11-01): the statute and the IRS
instructions win over the Direct File (DF) XML; engine artefacts are computed exactly.

Decision values:

* **statute**: follow the statute or the IRS instructions where DF differs;
* **reproduce DF**: keep DF's behaviour (no divergence from law, or a human decision is pending);
* **exact**: an engine artefact, computed exactly;
* **knock out**: refuse the return (an `unsupported` reason) instead of computing.

Test kinds: a Catala `#[test]` scope in `catala/tests/` (run by `clerk test`), a Lean `#guard`
or theorem (checked by `lake build`), a `knownDivergence` entry of a difftest mapping
(`difftest/mappings/*.mjs`, reported apart from passes by `make difftest`). Line numbers are at
the commit that adds this file; grep the marker to find them later (`# DF-BUG(n)` in Catala,
`DF-BUG(n)` in Lean comments).

Rows marked **added** had no pinning test before this change; the test named was added with
it (Catala in the module's test file, Lean mirror in `lean/UsTax/Tests/Quirks.lean`). Each added
test asserts the decided value and that DF's value is not produced, and was checked to fail
when the assertion is flipped to DF's value.

## Direct File discrepancies (`docs/direct-file-bugs.md`)

| ID | Decision | Justification | Catala | Lean | Pinning test |
|---|---|---|---|---|---|
| DF-BUG-1 | statute (knock out unsupported codes) | A 1099-R distribution code is read as a whole (IRS Instructions for Forms 1099-R, box 7 table: `7D` is not `7`). DF strips characters and accepts `7D` as `7` (`form1099Rs.xml` l.276). | `catala/form1099_rs.catala_en:181`, `:340` | `lean/UsTax/Form1099Rs.lean:22` | Catala `TestWholeCode` (`test_form1099_rs.catala_en:207`); Lean `-- TestWholeCode` (`Form1099Rs.lean:496`). No oracle scenario (comment in `difftest/mappings/form1099_rs.mjs:12`). |
| DF-BUG-2 | reproduce DF ($0 stub), **[HUMAN]** | IRC 25A grants the American opportunity credit; DF hard-codes `$0` with no knockout (`taxCalculations.xml` l.1473). Kept as DF (CONVENTIONS Q4) pending the owner's decision; see Questions. | `catala/form_1040.catala_en:511` (`QUIRK(Q4)`) | `lean/UsTax/Form1040.lean:235` | **added**: Catala `TestQ4QbiAndAocStubs` (`test_form_1040.catala_en`); Lean `q4_qbi_and_aoc_stubs`. |
| DF-BUG-3 | knock out | IRC 152(c)(4) tie-breakers need the other claimant's return, which the inputs do not have. A child who is also another taxpayer's qualifying child is knocked out (`ExtraQualifyingChildTieBreaker`). | `catala/qualifying_child.catala_en:574`, `:618`; `catala/knockouts_household.catala_en:98` | `lean/UsTax/QualifyingChild.lean:372`, `lean/UsTax/KnockoutsHousehold.lean:139` | Catala `TestTieBreakerKnockout` (`test_qualifying_child.catala_en:559`), `TestExtraQualifyingChildTieBreaker` (`test_knockouts_household.catala_en:413`); Lean `-- TestTieBreakerKnockout` (`QualifyingChild.lean:372`); knownDivergence `qss_35K_1 dependent-signed` (`difftest/mappings/calculator.mjs:191`, `qualifying_child.mjs:84`). |
| DF-BUG-4 | reproduce DF (per-item rounding), **[HUMAN]** | 1040 instructions p 23 (`i1040gi--2024.pdf`): "round off only the total". DF rounds each item (Q-R1). Reproduced except in HSA line 2, which rounds once; see Questions. | `catala/form_w2s.catala_en:250`, `catala/interest.catala_en:289`, `catala/form1099_rs.catala_en:308` (`QUIRK(Q-R1)`); HSA: `catala/hsa.catala_en:1025` | `lean/UsTax/FormW2s.lean:190`, `lean/UsTax/Interest.lean:175`, `lean/UsTax/Hsa.lean:452` | Catala `TestPerItemRounding` (`test_form_w2s.catala_en:162`), `TestTotal1501ScheduleBSumsPerItemRounded` (`test_interest.catala_en:78`); Lean `-- TestPerItemRounding` (`FormW2s.lean:507`), `-- TestTotal1501...` (`Interest.lean:241`), `qR1_per_item_rounding` (`Tests/Quirks.lean`), the rejected outputs in `Spec/FormW2.lean:71`, `Spec/Interest.lean:43`. |
| DF-BUG-5 | exact | Engine artefact (`types/Dollar.scala`: `numerator.toFloat / denominator`), not a tax rule (CONVENTIONS Q10). | Catala `decimal`/`money` are exact (no marker) | `Int`/`Rat` are exact (`lean/UsTax/Money.lean`) | **added**: Catala `TestDfBug5ExactAboveFloat` (`test_rounding.catala_en`); Lean `dfBug5_exact_above_float`. |
| DF-BUG-6 | statute (same value) | Form 1040 line 24 = line 22 + line 23; line 23 is `$0` for the supported subset, so equal to DF (CONVENTIONS Q3). | `catala/form_1040.catala_en:447`, `:464` (`QUIRK(Q3)`) | `lean/UsTax/Form1040.lean:229`; `lean/UsTax/Proofs/Form1040.lean:50` | Catala `TestLine23NotAdded` (`test_form_1040.catala_en:456`); Lean `-- TestLine23NotAdded` (`Form1040.lean:389`), `q3_line23_not_added`. |
| DF-BUG-7 | statute | IRC 221(b)(2)(B): the exact ratio; DF rounds it to 3 decimals. | `catala/student_loan_adjustment.catala_en:82`, `:127`, `:296` | `lean/UsTax/StudentLoanAdjustment.lean:16`, `:162`; `lean/UsTax/Spec/Adjustments.lean:26` | Catala `TestThreeDecimalRatio` (`test_student_loan_adjustment.catala_en:130`); Lean `-- TestThreeDecimalRatio` (`StudentLoanAdjustment.lean:162`), `dfBug7_exact_ratio`, `Checks.Extra.studentLoanAdjustment_eq_spec_bad_df_ratio`; no oracle scenario in the phase-out (`difftest/mappings/student_loan_adjustment.mjs:8`). |
| DF-BUG-8 | statute | A zero box 8 percentage is no knockout; DF's `StripChars("0.")` turns `0.00` into nonzero. | `catala/form1099_rs.catala_en:485` | `lean/UsTax/Form1099Rs.lean:23` | Catala `TestKnockouts` (`test_form1099_rs.catala_en:347`, the `b8zero` case); Lean `-- TestKnockouts` (`Form1099Rs.lean:531`); knownDivergence `1099r-box-2b-total-distribution`, `ats-2-1099r`, `ats-2-1099r-blank-taxable`, `ats-2-1099r-nonzero-taxable` (`difftest/mappings/knockouts_income.mjs:38`). |
| DF-BUG-9 | statute + knock out | Schedule 1 line 8g is only for the Alaska PFD; any other 1099-MISC is a knockout. | `catala/form1099_misc.catala_en` (`is_alaska_pfd`) | `lean/UsTax/Form1099Misc.lean` | Catala `TestNonPfdKnockedOut` (`test_form1099_misc.catala_en:91`), `TestNonPfd1099Misc` (`test_knockouts_income.catala_en:343`); Lean `-- TestNonPfdKnockedOut` (`Form1099Misc.lean:97`), `KnockoutsIncome.lean:736`. |
| DF-BUG-10 | reproduce DF, **[HUMAN]** | The 1040 instructions have no per-form cap on in-year repayment; DF caps it at box 1. Kept because the issue (#21) asks for it and it matters only on inconsistent input. | `catala/unemployment.catala_en` (clamp rule) | `lean/UsTax/Unemployment.lean:130` | Catala `TestRepaymentClampsToBox1` (`test_unemployment.catala_en:63`); Lean `-- TestRepaymentClampsToBox1` (`Unemployment.lean:130`). |
| DF-BUG-11 | statute | IRC 152(c)(3)(B): a totally and permanently disabled person passes the age test whatever the age (CONVENTIONS Q5). | `catala/qualifying_child.catala_en:406` | `lean/UsTax/QualifyingChild.lean:166` | Catala `TestDisabledTwinOfFiler` (`test_qualifying_child.catala_en:518`; its comment says `DF-BUG(16-a)`); Lean `QualifyingChild.lean:359`; knownDivergence `(none in the oracle)` (`difftest/mappings/qualifying_child.mjs:90`). |
| DF-BUG-12 | statute | IRC 223(b)(5)(B)(ii), Form 8889 line 6: split the family limit equally unless the spouses agree otherwise. | `catala/hsa.catala_en:1117`, `:1133` | `lean/UsTax/Hsa.lean:28`, `:482` | Catala `TestMfjEqualDivision` (`test_hsa.catala_en:354`; its comment says `DF-BUG(7)`); Lean `Hsa.lean:927`. |
| DF-BUG-13 | statute | IRC 22(c)(3)(A) and Schedule R instructions p R-5 exclude cost recovery and rollovers from line 13b. | `catala/elderly_and_disabled.catala_en:30`, `:387`, `:405` | `lean/UsTax/ElderlyAndDisabled.lean:22`, `:216` | knownDivergence: 21 oracle scenarios with a 1099-R (`difftest/mappings/elderly_and_disabled.mjs:82`, downstream `calculator.mjs:201`). No unit test reaches it: `ScheduleR` has no line 5a/5b input, so the rule cannot be violated at that level. |
| DF-BUG-14 | statute | IRC 25B(d)(2)(D), Form 8880 line 4: both spouses' distributions count in both columns. | `catala/savers_credit.catala_en:371`, `:390` | `lean/UsTax/SaversCredit.lean:21`, `:170`, `:329` | Catala `TestMfjIneligibleSpouseDistributions` (`test_savers_credit.catala_en:371`; its comment says `DF-BUG(29-a)`); Lean `SaversCredit.lean:329`; knownDivergence `1099r-savers-mfj-primary`, `1099r-savers-mfj-spouse-eligible` (`difftest/mappings/savers_credit.mjs:100`, `:102`). |
| DF-BUG-15 | statute | IRC 152(d)(1)(D): a qualifying relative is "not a qualifying child of such taxpayer". | `catala/qualifying_relative.catala_en:49`, `:250`, `:266`; `catala/hoh_qss_persons.catala_en:373` | `lean/UsTax/QualifyingRelative.lean:20`, `:130`; `lean/UsTax/Household/Lemmas.lean:90` | Catala `TestOwnQualifyingChildNotQualifyingRelative` (`test_qualifying_relative.catala_en:534`); Lean `QualifyingRelative.lean:359`; knownDivergence `hoh-cdcc-combat-pay`, `hoh-cdcc-multiple-careproviders` persons (`difftest/mappings/qualifying_relative.mjs:88`). |
| DF-BUG-16 | statute | IRC 152(c), (d)(1)(D): the "qualifying child of another" answer applies whenever the person could be anyone's qualifying child. | `catala/qualifying_relative.catala_en:130`, `:323`, `:346`; `catala/hoh_qss_persons.catala_en:593` | `lean/UsTax/QualifyingRelative.lean:122` | Catala `TestOlderSiblingQualifyingChildOfParent` (`:570`), `TestOwnSupportChildCannotBeAnyonesQualifyingChild` (`:645`, `test_qualifying_relative.catala_en`); Lean `QualifyingRelative.lean:370`, `:400`; knownDivergence `(none in the oracle)` (`qualifying_relative.mjs:94`). |
| DF-BUG-17 | statute | IRC 32: the credit is a percentage of earned income, `$0` when there is none. | `catala/eitc.catala_en:306` | `lean/UsTax/Eitc.lean:30`, `:138`; `lean/UsTax/Proofs/Eitc.lean:23` | Catala `TestCombatPayAloneIsNotEarnedIncome` (`test_eitc.catala_en:902`); Lean `-- TestCombatPayAloneIsNotEarnedIncome` (`Eitc.lean:631`), `Checks.Main.eitc_within_bounds_bad_negative`. |
| DF-BUG-18 | statute | IRC 152(e)(5): no Form 8332 split under a multiple support agreement. | `catala/dependents_benefit_split.catala_en:50`, `:134`, `:188`, `:467` | `lean/UsTax/DependentsBenefitSplit.lean:73` | Catala `TestMultipleSupportAgreement` (`test_dependents_benefit_split.catala_en:433`); Lean `DependentsBenefitSplit.lean:322`; knownDivergence `(none in the oracle)` (`dependents_benefit_split.mjs:92`). |
| DF-BUG-19 | statute | IRC 7703(b)(1): considered unmarried only through a child the filer can claim. | `catala/hoh_qss_persons.catala_en:66`, `:132`, `:464`, `:490`; `catala/filing_status.catala_en:49` | `lean/UsTax/HohQssPersons.lean:17`, `:99` | Catala `TestDfBug19aMarriedChildNoTin` (`test_hoh_qss_persons.catala_en:546`); Lean `HohQssPersons.lean:411`; knownDivergence `mfj-50k-ctc-odc` person (`hoh_qss_persons.mjs:65`) and two filing-status graphs (`filing_status.mjs:77`). |
| DF-BUG-20 | statute | IRC 2(b)(1)(A)(ii), 2(a)(1)(B): the filer must be *entitled* to claim the dependent. | `catala/hoh_qss_persons.catala_en:519`, `:588`, `:602`; `catala/calculator.catala_en:392` | `lean/UsTax/HohQssPersons.lean:103`, `:109` | Catala `TestDfBug19bUnclaimed` (`test_hoh_qss_persons.catala_en:569`); Lean `HohQssPersons.lean:419`; knownDivergence `(none in the oracle)` (`hoh_qss_persons.mjs:72`). |
| DF-BUG-21 | statute | IRC 2(b)(1)(A)(i): a married child is excluded only for filing jointly or failing the citizenship test. | `catala/hoh_qss_persons.catala_en:135`, `:250`, `:389` | `lean/UsTax/HohQssPersons.lean:76` | Catala `TestDfBug19cMarriedChild` (`:591`); Lean `HohQssPersons.lean:426`; knownDivergence `(none in the oracle)` (`hoh_qss_persons.mjs:77`). |
| DF-BUG-22 | statute | IRC 2(b)(1)(A)(ii): an other relative must be one the filer can claim. | `catala/hoh_qss_persons.catala_en:378`, `:406` | `lean/UsTax/HohQssPersons.lean:92` | Catala `TestDfBug19dSplitRelative` (`:627`); Lean `HohQssPersons.lean:437`; knownDivergence `(none in the oracle)` (`hoh_qss_persons.mjs:82`). |
| DF-BUG-23 | statute | IRC 21(e)(5), i2441 p 1, Pub 503 p 4: only the custodial parent gets the child through the release. | `catala/cdcc.catala_en:41`, `:167`, `:277` | `lean/UsTax/Cdcc.lean:27`, `:119` | knownDivergence `hoh-cdcc-multiple-careproviders` (6 facts: `difftest/mappings/cdcc.mjs:120`, `calculator.mjs:200`). |
| DF-BUG-24 | statute | IRC 21(a)(2): 35 percent at AGI of $15,000 or less, including zero and below. | `catala/cdcc.catala_en:45`, `:790`, `:1078` | `lean/UsTax/Cdcc.lean:386`, `:575` | Catala `TestNegativeAgi` (`test_cdcc.catala_en:287`); Lean `-- TestNegativeAgi` (`Cdcc.lean:575`); knownDivergence `edc-ats-1`, `edc-disqualified-disability-income`, `ptc-no-aptc-negative-magi` (`cdcc.mjs:191`). |
| DF-BUG-25 | statute | IRC 21(e)(4): one home, the abode of a qualifying individual, upkeep paid by the filer; both tests on the same person. | `catala/cdcc.catala_en:47`, `:494` | `lean/UsTax/Cdcc.lean:233` (`mfsButEligible`) | **added**: Catala `TestDfBug25MfsExceptionOnePerson` (`test_cdcc.catala_en`); Lean `dfBug25_mfs_exception_one_person`. |
| DF-BUG-26 | statute | Form 2441 line 19: "All others, enter the amount from line 18". | `catala/cdcc.catala_en:51`, `:602` | `lean/UsTax/Cdcc.lean:273` | **added**: Catala `TestDfBug26QssLine19`; Lean `dfBug26_qss_line19`. |
| DF-BUG-27 | statute | Form 2441 line 14 covers amounts on line 12 *or 13*. | `catala/cdcc.catala_en:54`, `:537`, `:567` | `lean/UsTax/Cdcc.lean:255` | **added**: Catala `TestDfBug27ForfeitedWithoutBox10`; Lean `dfBug27_forfeited_without_box10`. (The difftest mappings `cdcc.mjs:146`, `calculator.mjs:107` only feed the input; they are not a test.) |
| DF-BUG-28 | statute | IRC 21(b)(1)(A): a dependent the filer *may* claim. | `catala/cdcc.catala_en:56`, `:244` | `lean/UsTax/Cdcc.lean:108` | **added**: Catala `TestDfBug28UnclaimedChildQualifies`; Lean `dfBug28_unclaimed_child_qualifies`. |
| DF-BUG-29 | statute | IRC 32(c)(3): a qualifying child; no claim required. | `catala/calculator.catala_en:389`, `:446` | `lean/UsTax/Calculator.lean:324`, `:359` | **added**: Catala `TestDfBug29UnclaimedChildEitc` (`test_calculator.catala_en`); Lean `dfBug29_unclaimed_child_eitc`. |
| DF-BUG-30 | statute | IRC 32(c)(3)(B): a married child needs only that the filer be *entitled* to claim them. | `catala/calculator.catala_en:393`, `:446` | `lean/UsTax/Calculator.lean:323`, `:359` | **added**: Catala `TestDfBug30MarriedUnclaimedChildEitc`; Lean `dfBug30_married_unclaimed_child_eitc`. |
| DF-BUG-31 | statute | Form 8962 instructions: a month counts if a policy is in effect on the 1st. | `catala/ptc_allowed.catala_en:543`, `:593` | `lean/UsTax/PtcAllowed.lean:28`, `:146` | Catala `TestDecemberFirstStartIsCoverageMonth` (`test_ptc_allowed.catala_en:319`); Lean `PtcAllowed.lean:549`. |
| DF-BUG-32 | statute | Form 8962 instructions, line 11: annual totals only with coverage all 12 months. | `catala/ptc_allowed.catala_en:558`, `:618`, `:681` | `lean/UsTax/PtcAllowed.lean:29`, `:167`, `:184` | Catala `TestFullYearPolicyWithElevenCoverageMonths` (`:394`); Lean `PtcAllowed.lean:566`. |
| DF-BUG-33 | statute | Form 8962 instructions, line 11: the conditions hold "for each qualified health plan". | `catala/ptc_allowed.catala_en:770`, `:781` | `lean/UsTax/PtcAllowed.lean:30`, `:352` | **added**: Catala `TestDfBug33EveryFormMustAllowAnnualTotals` (`test_ptc_allowed.catala_en`); Lean `dfBug33_every_form_must_allow_annual`. Two forms are a knockout in DF and here, so no oracle value changes. |

## CONVENTIONS section 8 items

| Item | Decision | Justification | Catala | Lean | Pinning test |
|---|---|---|---|---|---|
| Q1 line 5a omits fully taxable pensions | reproduce DF (= instructions) | i1040gi p 28: fully taxable pensions go on 5b, "don't make an entry on line 5a". Not a divergence. | `catala/form1099_rs.catala_en:695` | `lean/UsTax/Form1099Rs.lean` (line 5a) | Catala `TestFullyTaxable` (`test_form1099_rs.catala_en:109`), `TestPartlyTaxable` (`:131`); Lean `Form1099Rs.lean:454`, `:464`. |
| Q2 distribution code chars | = DF-BUG-1 (statute) | | | | as DF-BUG-1 |
| Q3 Schedule 2 line 21 | = DF-BUG-6 | | | | as DF-BUG-6 |
| Q4 QBI and AOC stubs | QBI: reproduce DF (`$0` by law for the supported income: no business income, IRC 199A). AOC: = DF-BUG-2, **[HUMAN]** | | `catala/form_1040.catala_en:402`, `:511` | `lean/UsTax/Form1040.lean:219`, `:235` | **added**: `TestQ4QbiAndAocStubs`; Lean `q4_qbi_and_aoc_stubs`. |
| Q5 `disabilityStatusMayAffectBenefits` | = DF-BUG-11 (statute; DF's code is right, its description is wrong) | | | | as DF-BUG-11 |
| Q6 tie-breakers | = DF-BUG-3 (knock out); CONVENTIONS still says "Reproduce", see Questions | | `catala/calculator.catala_en:397` | | as DF-BUG-3 |
| Q7 `lastYearAgiFromOLA` | not modelled | Identity verification, not tax (scope.md 4.4). No test: there is nothing to compute. | | | n/a |
| Q8 TY2023 descriptions | official TY2024 values | Constants from `Params_2024`. | `catala/params_2024.catala_en` | `lean/UsTax/Params2024.lean` | Every module test uses them; e.g. `TestBase`, `TestAdditional` (`test_standard_deduction.catala_en`), `Spec/StandardDeduction.lean:52`, the Tax Table golden tests (`test_tax_rates_table.catala_en`, `Proofs/TaxTable.lean`). |
| Q9 untagged Schedule R constants | official values (= DF) | IRC 22(c), (d); `i1040sr--2024.pdf` p 7. | `catala/elderly_and_disabled.catala_en` | `lean/UsTax/ElderlyAndDisabled.lean` | Catala `TestCases` (`test_elderly_and_disabled.catala_en`, single 66: $563; instructions examples Jesse $51, Riley and Parker $0); Lean `-- TestCases` (`ElderlyAndDisabled.lean:292`). |
| Q10 Rational via Float | = DF-BUG-5 (exact) | | `catala/eitc.catala_en:78` | | as DF-BUG-5 |
| Q11 scoped states | reproduce DF | `constants.xml` l.327-360: 25 states plus `moreThanOne`, `noneOfThese`. | `catala/types.catala_en` (`ScopedState`) | `lean/UsTax/Types.lean` | Catala `TestLocalFlowKnockoutUnsupportedState` (`test_knockouts_income.catala_en`, `MoreThanOne`); Lean `KnockoutsIncome.lean:709`. |
| Q12 CDCC benefit allocation | reproduce DF | The form is silent on which spouse's earned income takes the taxable benefits; DF's rule (with the apparent slip in its second alternative) is reproduced. | `catala/cdcc.catala_en:983` | `lean/UsTax/Cdcc.lean:413` | **added**: Catala `TestQ12AllocationReproduced` (`test_cdcc.catala_en`), a case where the slip alternative decides; Lean `q12_allocation_reproduced`. |
| Q-R1 per-item rounding | = DF-BUG-4 | | | | as DF-BUG-4 |
| Q-R2 HALF_EVEN cents vs ties away | accept the divergence (Catala and Lean round ties away from zero) | Differs only on exact half cents; reproducing HALF_EVEN would need a helper on every product. | `catala/rounding.catala_en`, `catala/tax_rates.catala_en:245` | `lean/UsTax/Money.lean` | Catala `TestRoundDollarTies` (`test_rounding.catala_en:17`); Lean `Money.lean` `#guard roundDollar 250 ≠ 200`, `qR2_ties_away_from_zero`. |
| Q-R3 double rounding of `round(x * rate)` | reproduce DF | Both DF and Catala round the product to the cent, then the dollar; `round_dollar_exact` kept for the statute reading. | `catala/rounding.catala_en` | `lean/UsTax/Money.lean:184` | Catala `TestRoundProduct` (`test_rounding.catala_en:54`); Lean `Money.lean` `#guard`s after `-- Double rounding`, `qR3_double_rounding`. |

## Rows that had no pinning test (tests added here)

| Row | Catala test added | Lean mirror (`lean/UsTax/Tests/Quirks.lean`) |
|---|---|---|
| DF-BUG-2 / Q4 | `TestQ4QbiAndAocStubs` (`test_form_1040.catala_en`) | `q4_qbi_and_aoc_stubs` |
| DF-BUG-5 / Q10 | `TestDfBug5ExactAboveFloat` (`test_rounding.catala_en`) | `dfBug5_exact_above_float` |
| DF-BUG-25 | `TestDfBug25MfsExceptionOnePerson` (`test_cdcc.catala_en`) | `dfBug25_mfs_exception_one_person` |
| DF-BUG-26 | `TestDfBug26QssLine19` | `dfBug26_qss_line19` |
| DF-BUG-27 | `TestDfBug27ForfeitedWithoutBox10` | `dfBug27_forfeited_without_box10` |
| DF-BUG-28 | `TestDfBug28UnclaimedChildQualifies` | `dfBug28_unclaimed_child_qualifies` |
| DF-BUG-29 | `TestDfBug29UnclaimedChildEitc` (`test_calculator.catala_en`) | `dfBug29_unclaimed_child_eitc` |
| DF-BUG-30 | `TestDfBug30MarriedUnclaimedChildEitc` | `dfBug30_married_unclaimed_child_eitc` |
| DF-BUG-33 | `TestDfBug33EveryFormMustAllowAnnualTotals` (`test_ptc_allowed.catala_en`) | `dfBug33_every_form_must_allow_annual` |
| Q12 | `TestQ12AllocationReproduced` (`test_cdcc.catala_en`) | `q12_allocation_reproduced` |

To write the CDCC tests, the `MkChild` and `Case` helpers of `test_cdcc.catala_en` got optional
contexts (`tp_claims`, `upkeep`, `residency`, `lived_apart`, ...). Their defaults are the
previous fixed values, so the existing tests are unchanged. The Run1040 helper of
`test_form_1040.catala_en` gained two outputs (lines 13 and 29). Lean restates four existing pins by
name (`dfBug7_exact_ratio`, `qR1_per_item_rounding`, `q3_line23_not_added`, `qR3_double_rounding`).

## Questions for the human

No behaviour was changed. These decisions look inconsistent with the 2026-11-01 policy, or
with each other:

1. **DF-BUG-2 (AOC)**: `docs/direct-file-bugs.md` gives our behaviour as "Knock out (Form 8863
   unsupported)", but the code reproduces DF's `$0` stub (`QUIRK(Q4)`, no knockout). Under the
   policy, a filer who qualifies under IRC 25A should be refused, not under-credited. That
   needs an input (education expenses or a 1098-T screen) that the API does not have yet.
2. **DF-BUG-4 / Q-R1 (per-item rounding)**: reproduced in W-2s, interest and 1099-R, against
   i1040gi p 23 ("round off only the total") and against the new policy. But HSA line 2
   (`hsa.catala_en:1025`, labelled `DF-BUG(4)`) follows the instructions and rounds once. One
   rule should hold everywhere.
3. **DF-BUG-10**: the cap at box 1 is kept against the policy (the comment says "Human
   decision").
4. **Q6 / DF-BUG-3**: CONVENTIONS section 8 still says "Reproduce", and the bug table says
   "candidate: implement tie-breaker or knock out". The code knocks out
   (`ExtraQualifyingChildTieBreaker`). The two documents should say so.
5. **Q-R3 (double rounding)**: the policy computes engine artefacts exactly, and cent rounding
   before dollar rounding is arguably one (`TestRoundProduct`: $1,116 against $1,115 exact). If
   it becomes **exact**, `TestDfBug5ExactAboveFloat` already uses the exact helper.
6. **Q12**: DF's allocation rule is reproduced, including what looks like a slip ("secondary
   minus primary" compared with "primary plus adjustment"). `TestQ12AllocationReproduced` pins
   a case where the slip alternative decides.
7. **DF-BUG-13, DF-BUG-23** are pinned only by difftest `knownDivergence` entries, with no unit
   test. DF-BUG-23 could get a Catala test like `TestDfBug28...` (a foster-parent household).
8. **Inconsistent labels** in comments (not edited): `test_hsa.catala_en:345`,
   `difftest/mappings/hsa.mjs:97` and `lean/UsTax/Hsa.lean:927` say `DF-BUG(7)` for row 12.
   `test_qualifying_child.catala_en:527`, `qualifying_child.mjs:90` and
   `QualifyingChild.lean:359` say `DF-BUG(16-a)` for row 11. `test_savers_credit.catala_en:365`
   says `DF-BUG(29-a)` for row 14. `test_form1099_rs.catala_en:367` and `form1099_rs.mjs:13`
   say "DF-BUG proposal 7" for row 8. `hsa.catala_en:1025` and `Hsa.lean:27` say `DF-BUG(4)`
   for an HSA-specific rounding fix.
9. **Statuses**: most rows are still `candidate` in `docs/direct-file-bugs.md`, though each one
   now has a test and a citation. Issue #60 asks for agreement on each decision; promoting the
   rows to `confirmed`/`fixed` is for the owner.
