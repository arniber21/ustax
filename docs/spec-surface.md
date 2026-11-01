# Spec surface of the main theorems (issue #63)

A theorem means what its statement says, and the statement means what every
definition it mentions means, transitively (CLAUDE.md section 4). This file
lists, for each main theorem, those definitions (`#spec_surface`,
`lean/UsTax/Audit.lean`) and reviews them in prose.

Where things are:

| what | file | in `lake build` / `make audit` |
|---|---|---|
| the properties (`NonnegMonotone`, `RefundOrBalanceDue`, `CreditsWithinLiability`, `EitcWithinBounds`, `MatchesTaxTable`, `worksheetTax`), each with a satisfiable example and rejected bad outputs | `lean/UsTax/Spec/*.lean` | yes |
| the main theorem statements, `sorry` proofs (trusted) | `lean/UsTax/Comparator/Challenge.lean` | no (comparator challenge) |
| the same theorems, proved; concrete instances | `lean/UsTax/Proofs/Main.lean` (solution module) | yes |
| lemmas they use | `lean/UsTax/Proofs/Form1040.lean`, `lean/UsTax/Proofs/TaxTable.lean`, `lean/UsTax/Proofs/TaxWorksheet.lean`, `lean/UsTax/TaxRates/Lemmas.lean` | yes |
| main theorems not proved yet | `lean/UsTax/Comparator/Pending.lean` | no |
| names checked by `lake comparator` | `lean/comparator.json` | |

The `UsTax/Spec/*.lean` files import nothing from the calculator: only
`FilingStatus` (`UsTax/Types.lean`) and the generated Tax Table data. The
statements in `Challenge.lean` apply those properties to the calculator's
outputs (`tentativeTaxFor`, `form1040`), so every statement about a Form 1040
line also has the whole calculator on its surface. That is unavoidable for a
statement about the code that runs; what a reviewer has to read is the
property (short) and which output fields it is applied to.

## The statements

```lean
theorem tentativeTax_nonneg_monotone (fs : FilingStatus) :
    NonnegMonotone (fun ti => tentativeTaxFor ti fs)

theorem refund_balanceDue_consistent (i : Form1040In) :
    RefundOrBalanceDue (form1040 i).totalTax (form1040 i).totalPayments
      (form1040 i).overpayment (form1040 i).balanceDue

theorem credits_within_liability (i : Form1040In) :
    CreditsWithinLiability (form1040 i).totalTentativeTax (form1040 i).nonRefundableCredits
      (form1040 i).taxLessNonRefundableCredits

theorem totalTax_nonneg (i : Form1040In) : 0 ≤ (form1040 i).totalTax

theorem tentativeTax_matches_tax_table (fs : FilingStatus) (ti : Int) :
    MatchesTaxTable fs ti (tentativeTaxFor ti fs)

theorem line16_matches_tax_table (i : Form1040In) :
    MatchesTaxTable i.filingStatus (form1040 i).taxableIncome
      (form1040 i).tentativeTaxFromTaxableIncome

theorem tentativeTax_matches_worksheet (fs : FilingStatus) (ti : Int)
    (h1 : 100_000_00 ≤ ti) (h2 : ti ≤ 1_000_000_000_000_00) :
    tentativeTaxFor ti fs = worksheetTax fs ti

theorem line16_matches_worksheet (i : Form1040In)
    (h1 : 100_000_00 ≤ (form1040 i).taxableIncome)
    (h2 : (form1040 i).taxableIncome ≤ 1_000_000_000_000_00) :
    (form1040 i).tentativeTaxFromTaxableIncome =
      worksheetTax i.filingStatus (form1040 i).taxableIncome
theorem eitc_within_bounds (i : Eitc.EitcTableIn) :
    EitcWithinBounds (Eitc.caseOf i) (Eitc.eitc i)
```

All in namespace `UsTax.Main`. The first six and (4) have no hypothesis besides their
arguments (every `FilingStatus`, every `Int`, every `Form1040In`, every `EitcTableIn`).
`MatchesTaxTable` has two inside (`r ∈ rows`, `InRow r ti`); `Proofs/Main.lean`
discharges both on a concrete return. (5c) and (5d) have two: line 15 is at
least $100,000 (where the instructions switch from the Tax Table to the
worksheet) and at most $1 trillion (the code's `noUpperBound` sentinel, above
which the Catala marginal form, and so the code, stops taxing; see
`TaxRates/Spec.lean`). `Proofs/Main.lean` discharges both on a concrete return
(single, wages $200,000, line 15 $185,400, line 16 $37,539) and at $100,000
exactly. Together (5b) and (5d) cover every line 15 from $0 to $1 trillion:
below $100,000 the printed Tax Table, from $100,000 the printed worksheet.
Axioms of all nine (`#audit_axioms`): `propext`, `Classical.choice`,
`Quot.sound`.

## The properties (review these)

**`NonnegMonotone f`** (`Spec/TaxMonotone.lean`): `(∀ x, 0 ≤ f x) ∧ ∀ a b,
a ≤ b → f a ≤ f b`. Not strict: a Tax Table row has one tax for all its
incomes, so strict monotonicity is false. Satisfied by `max 0 x / 10`;
rejects a cliff (`$100` below $10,000, `$0` above) and `x - 100`.

**`RefundOrBalanceDue tax payments over owe`** (`Spec/RefundBalance.lean`):
`0 ≤ over ∧ 0 ≤ owe ∧ (over = 0 ∨ owe = 0) ∧ over - owe = payments - tax`.
The issue wrote `over * owe = 0`; `over = 0 ∨ owe = 0` is the same over `Int`
and needs no multiplication. It determines both lines
(`RefundOrBalanceDue.overpayment_eq`: `over = max 0 (payments - tax)`,
`owe = max 0 (tax - payments)`), so it is a full specification of lines 34 and
37, not only a sanity check. Rejects: refund and amount owed together, a
refund off by one cent, a negative amount owed.

**`CreditsWithinLiability before credits after`** (`Spec/Credits.lean`):
`after = max 0 (before - credits)`, the text of line 22. Proved consequences:
credits used (`before - after`) `≤ before` and `≤ credits`, and `0 ≤ after`.
Rejects: unused credit paid out as negative tax; credits ignored.

**`MatchesTaxTable fs ti tax`** (`Spec/TaxTable.lean`): `∀ r ∈ rows, InRow r
ti → tax = dollars (printedTax r fs)`, with `InRow r ti := dollars r.atLeast ≤
ti ∧ ti < dollars r.butLessThan` (cents), `dollars d := d * 100`, and
`printedTax` picking the column (qualifying surviving spouse uses the married
filing jointly column, as the printed header says). Satisfied by single
$50,000 → $6,059; rejects $6,053 (the tax on the exact income, without the
row midpoint) and the single column used for a joint return.

**`worksheetTax fs ti`** (`Spec/TaxWorksheet.lean`): the 2024 Tax Computation
Worksheet (Form 1040 instructions p 76; p 33 says to use it when line 15 is
$100,000 or more). `worksheetRow fs ti` is the p 76 table typed from the PDF:
the section of the filing status (A single, B joint and qualifying surviving
spouse, C separate, D head of household), the row whose "over $X but not over
$Y" contains `ti`, and its (b) multiplication amount (percent) and (d)
subtraction amount (cents). `worksheetTax` is `roundHalfUp (c - d) 100 * 100`
with `c := roundHalfUp (ti * rate) 100`: column (c) rounded to the cent, the
tax rounded to the whole dollar (p 23, "drop amounts under 50 cents and
increase amounts from 50 to 99 cents"); `roundHalfUp n d := (2n + d) / (2d)`.
Choice to confirm: (c) is rounded to the cent before subtracting. This only
matters for a line 15 with cents, and is what the code (Catala `money *
decimal`) does. Satisfied by single $185,400 → $37,539; rejects $37,538
(rounded down), the Section B row for a single filer, 24% with nothing
subtracted, and Section A for married filing separately at $400,000.
Cross-check: each (d) equals `X × R − B` for the Rev. Proc. 2023-34 row "over
$X: $B plus R% of the excess" (`#guard` in `Proofs/TaxWorksheet.lean`, and
implied by the proof of `taxSpec_eq_worksheetTax`, which equates the worksheet
with the rate schedules for every income from $100,000). `#guard`s also
compare both at $100,000, every $1,000 to $2,000,000, and one cent either side
of every bracket edge, for all five statuses.

**`EitcWithinBounds c credit`** (`Spec/Eitc.lean`, now theorem (4), proved): `0 ≤ credit ∧
credit ≤ eitcMaxCredit children ∧ (eitcCompletedPhaseout children mfj ≤ max
earned agi → credit = 0)`. Amounts typed from Rev. Proc. 2023-34 § 3.06(1)
(checked against `catala/params_2024.catala_en`). Rejects: $1 over the
maximum, a credit at the completed phase-out, a negative credit.

## `#spec_surface` output, reviewed

`#spec_surface` lists constants from modules under `UsTax`. Below, structure
projections, constructors and recursors are dropped (they are fixed by the
structure they belong to); counts are of the raw output.

### (1) `tentativeTax_nonneg_monotone`: 37 constants, 26 definitions and types

- `UsTax.Spec.TaxMonotone`: `NonnegMonotone`
- `UsTax.TaxRates`: `Bracket`, `marginalTax`, `noUpperBound`, `pct`,
  `roundedTaxableIncomeOf`, `scheduleFor`, `scheduleHeadOfHousehold`,
  `scheduleMarriedSeparate`, `scheduleMfjQss`, `scheduleSingle`,
  `tentativeTaxFor`, `usd`
- `UsTax.Money`: `divMoney`, `floor`, `max`, `min`, `mulRate`, `positive`,
  `roundDollar`, `roundRat`, `stepwiseMultiply`, `sum`, `truncate`,
  `truncateRat`
- `UsTax.Types`: `FilingStatus`

Review. `NonnegMonotone` as above. `tentativeTaxFor` and everything under it
is the line 16 calculation (Tax Table midpoint, then the marginal sum over
the 2024 brackets, rounded to the dollar). It is the object of the theorem,
not an assumption: the theorem holds for whatever the brackets are, as long
as rates are nonnegative. Its agreement with the printed rate schedules is a
separate theorem (`TaxRates.tentativeTaxFor_eq_taxSpec`, not in the
comparator set; see "Choices to confirm").

### (2) `refund_balanceDue_consistent`: 273 constants, 90 definitions and types

- `UsTax.Spec.RefundBalance`: `RefundOrBalanceDue`
- the calculator surface below

### (3a) `credits_within_liability`: 272 constants, 90 definitions and types

- `UsTax.Spec.Credits`: `CreditsWithinLiability`
- the calculator surface below

### (3b) `totalTax_nonneg`: 269 constants, 89 definitions and types

- no property definition; the calculator surface below

### (5a) `tentativeTax_matches_tax_table`: 70 constants, 52 definitions and types

- `UsTax.Spec.TaxTable`: `InRow`, `MatchesTaxTable`, `dollars`, `printedTax`
- `UsTax.TaxRates.TaxTableData` (generated): `Row`, `rows`, `rows0` ... `rows20`
- the line 16 surface of (1): `UsTax.TaxRates` and `UsTax.Money` as there,
  `FilingStatus`

### (5b) `line16_matches_tax_table`: 304 constants, 116 definitions and types

- `UsTax.Spec.TaxTable` and `UsTax.TaxRates.TaxTableData` as in (5a)
- the calculator surface below

### (5c) `tentativeTax_matches_worksheet`: 39 constants, 28 definitions and types

- `UsTax.Spec.TaxWorksheet`: `roundHalfUp`, `worksheetRow`, `worksheetTax`
- the line 16 surface of (1): `UsTax.TaxRates` and `UsTax.Money` as there,
  `FilingStatus`

### (5d) `line16_matches_worksheet`: 273 constants, 92 definitions and types

- `UsTax.Spec.TaxWorksheet` as in (5c)
- the calculator surface below

Review. The three worksheet definitions are short and import nothing from the
calculator; what to check is that `worksheetRow` matches p 76 (bounds, rates,
subtraction amounts, "not over" inclusive) and the rounding.


### (4) `eitc_within_bounds`: 54 constants (50 definitions and types)

- `UsTax.Spec.Eitc`: `EitcWithinBounds`, `EitcCase`, `eitcMaxCredit`, `eitcCompletedPhaseout`
- `UsTax.Eitc.Case`: `caseOf`, `eitc` (read off `EitcTableIn`, take `.amount`)
- `UsTax.Eitc`: `EitcTableIn`, `EitcTableOut`, `eitcTable`, `phaseoutReduction`, `dollars`
- `UsTax.Params.*` (`UsTax/Params2024/EitcCtc.lean`): the eight credit and phase-out
  percentages (`decPct`), the four maximum credits, the four thresholds, the eight completed
  phase-out amounts, `eitcTableRowWidth`, `eitcTableRowMidpoint`, `eitcTableRowLastDollarOffset`
- `UsTax.Money`: `divMoney`, `mulRate`, `roundRat`, `roundDollar`, `stepwiseMultiply`, `truncate`,
  `truncateRat`, `max`; `UsTax.TaxRates.usd`

Review. This is the whole `EitcTable` scope (the printed-table emulation), not the
eligibility rules of `EarnedIncomeCredit`: the property is about the credit for four facts
(children, joint or not, earned income, AGI), as #67 asks. Two choices to confirm:
(a) `caseOf` reads a *negative* child count as 3 (the code's `else` column), so the theorem
needs no hypothesis; a count is never negative in a real return. (b) The maximum credits and
completed phase-out amounts are typed twice, in `Spec/Eitc.lean` from the Rev. Proc. and in
`Params2024/EitcCtc.lean` from `catala/params_2024.catala_en`; the proof (not the statement)
shows they agree, so a typo in either makes the theorem unprovable, not wrong. The 1,337-row
printed EIC Table golden test (`UsTax/Eitc/EicTable.lean`) is what ties `eitcTable` to the
IRS table; the theorem does not claim that.

### The calculator surface (shared by 2, 3a, 3b, 5b, 5d)

- `UsTax.Form1040`: `Form1040In`, `Form1040Out`, `form1040`
- `UsTax.FormW2s`: `CombatPayElection`, `FormW2`, `FormW2Item`, `FormW2sIn`,
  `FormW2sOut`, `formW2Item`, `formW2s`, `instDecidableEqCombatPayElection`
- `UsTax.Interest`: `InterestIn`, `InterestOut`, `InterestReport`,
  `InterestReportFacts`, `interest`, `interestIncome`, `interestReportFacts`,
  `requiresScheduleB`
- `UsTax.StandardDeduction`: `StandardDeductionIn`, `StandardDeductionOut`,
  `additionalStandardDeduction`, `additionalStandardDeductionItems`,
  `additionalStandardDeductionMultiplier`, `bit`,
  `filerMfsAndSpouseIsEligibleForStandardDeductions`,
  `filingStatusStandardDeduction`, `isSpouseInfoApplicableForStandardDeductions`,
  `minimumStandardDeduction`, `normalStandardDeduction`,
  `secondaryFilerAdditionalStandardDeductionItems`,
  `secondaryFilerIs65OrOlderForDeduction`, `standardDeduction`,
  `standardDeductionAmount`
- `UsTax.TaxRates`: as in (1), plus `TentativeTaxIn`, `TentativeTaxOut`,
  `tentativeTax`, `cumulativeTax`, `tentativeTaxCumulativeFor`
- `UsTax.Params2024` (`UsTax.Params.*`): `additionalMedicareTaxThreshold{Joint,MarriedSeparate,Other}`,
  `medicareWagesIndividualLimit`, `niitThreshold{JointOrSurvivingSpouse,MarriedSeparate,Other}`,
  `oasdiWageBase`, `scheduleBInterestThreshold`, `stdDeduction{AdditionalMarried,AdditionalUnmarried,DependentEarnedIncomeAddition,DependentFloor,HeadOfHousehold,JointOrSurvivingSpouse,MarriedSeparate,Unmarried}`
- `UsTax.Money` as in (1), plus `mulInt`; `UsTax.Lists`: `Money.sumBy`
- `UsTax.Types`: `FilerRole`, `FilingStatus` and their `DecidableEq` instances

Review. This is the calculator up to line 37; the theorems are about its
outputs, so it is on the surface but it is not assumed correct. What the
theorems rely on is only *which field is which line*: `totalTax` is line 24,
`totalPayments` line 33, `overpayment` line 34, `balanceDue` line 37,
`totalTentativeTax` line 18, `nonRefundableCredits` line 21,
`taxLessNonRefundableCredits` line 22, `taxableIncome` line 15,
`tentativeTaxFromTaxableIncome` line 16 (field docstrings in
`UsTax/Form1040.lean`). The proofs of (2), (3a), (3b) do not depend on the
values of any parameter: they hold for every input, including every plug-in
slot (`Form1040In` fields with default `0`) and negative ones.

The data `rows` is part of the spec of (5): it is generated from
`sources/forms-instructions/derived-tax-table-2024.csv` by
`scripts/gen_lean_tax_table.py` and is what "the printed Tax Table" means in
Lean. A wrong CSV row makes (5) say something wrong.

## Pending (not in `comparator.json`)

Templates in `lean/UsTax/Comparator/Pending.lean`:

- **(3c) Credit wiring** (#66): each nonrefundable credit, computed by its own
  module, satisfies `CreditsWithinLiability` against the tax left after the
  credits before it (Schedule 8812 Credit Limit Worksheet A, Schedule 3 order),
  and line 21 is their sum. Needs CTC/ODC (#27) and Schedule 3 in Lean. Today
  line 21 is a plug-in slot, and (3a) holds for whatever value it has.

Each moves into `Challenge.lean` and `comparator.json` when proved. (4), the EITC bounds, moved in with the Lean EITC (#46, #67).

## Choices to confirm (human)

1. **(5) covers all taxable income up to $1 trillion.** Below $100,000 the
   Tax Table (5a, 5b); from $100,000 the Tax Computation Worksheet (5c, 5d),
   written from the printed worksheet, not from `taxSpec` (three definitions
   on the surface instead of about ten). The upper bound is the code's
   `noUpperBound` sentinel (from Catala); above it line 16 is wrong (proved,
   `TaxRates/Spec.lean`), so (5c, 5d) need it. Removing it means changing the
   Catala source and the code. Rounding (c) to the cent: see `worksheetTax`.
2. **The table data covers every cent below $100,000.** An earlier version
   of the CSV lacked the printed rows [$5, $15) ($1) and [$15, $25) ($2); fixed.
   `Proofs.rows_chain` (kernel) shows the 2,062 rows tile $0 to $100,000 with no
   gap or overlap, and `Proofs.rows_cover` that every cent below $100,000 is in
   a row, so (5) constrains line 16 for all of them.
3. **Credits (3a) are stated at line 22 given line 21**, not per credit. Line
   21 is today an input slot; the per-credit statement is pending (3c).
4. **(3b) is `0 ≤ totalTax` with line 23 not added** (QUIRK(Q3) in
   `UsTax/Form1040.lean`). When line 23 is wired, (3b) still holds only if
   line 23 is nonnegative; the proof will need that.
5. **`RefundOrBalanceDue` uses `over = 0 ∨ owe = 0`** instead of the issue's
   `over * owe = 0` (equivalent over `Int`).
6. **EITC "zero at the completed phase-out" uses `max earned agi`** (IRC
   32(a)(2)(B)) and `≤` (zero at exactly the completed amount). MFS uses the
   "other" column, as in Direct File.

## Module specs (second challenge, `comparator.extra.json`)

Not main theorems: these say that each merged module of the calculator equals
a short statute-style spec, for **every** input, plus bounds and
monotonicity. The specs import nothing from the calculator except
`FilingStatus` (and `Spec/Inputs.lean`, which reads plain amounts off the
input records). Rounding is restated from scratch (`Spec/Rounding.lean`:
`roundHalfAway`, `roundToDollar`, `percentOf`) and proved equal to the
calculator's `Money` functions (`Proofs/Rounding.lean`).

| where | what |
|---|---|
| `lean/UsTax/Spec/{Rounding,StandardDeduction,Interest,FormW2,SocialSecurity,Adjustments,Form1040Lines,Inputs}.lean` | the specs, each with examples and rejected bad outputs |
| `lean/UsTax/Proofs/{StandardDeduction,Interest,FormW2,SocialSecurity,Adjustments,Form1040Lines}.lean` | the proofs; each theorem on a concrete input (hypotheses discharged) and a rejected bad output |
| `lean/UsTax/Proofs/SpecProps.lean` | plausible tests of every statement (run before proving; run on every build), plus a negative control |
| `lean/UsTax/Comparator/Extra.lean` | the 23 statements with `sorry` (challenge) |
| `lean/UsTax/Proofs/Extra.lean` | the same, proved (solution) |
| `lean/comparator.extra.json` | `make comparator-extra` |

### The statements (namespace `UsTax.Extra`)

| theorem | says |
|---|---|
| `standardDeduction_eq_spec` | line 12 = `standardDeductionSpec fs items canBeClaimed earned` (IRC 63(c): basic + items × additional; dependent: `min(basic, max($1,300, earned + $450)) + additional`) |
| `additionalItems_range` | `0 ≤ items ≤ 4`, and `≤ 2` unless joint or treated as MFS |
| `requiresScheduleB_eq_spec` | Schedule B iff taxable interest > $1,500 or a foreign account/trust |
| `interestIncome_eq_spec` | line 2b = Σ per-payer rounded amounts with Schedule B, else the total rounded once |
| `wages_eq_spec`, `formW2Withholding_eq_spec` | lines 1a, 25a = Σ of box 1 / box 2, each W-2 rounded to the dollar |
| `medicareKnockout_eq_spec` | knockout iff Medicare wages > $250k MFJ / $125k MFS / $200k other, or a joint spouse > $200k (IRC 3101(b)(2), 3102(f)) |
| `oasdiKnockout_eq_spec` | per filer: knockout iff more than one W-2 and Σ min(box 3, $168,600) > $168,600 |
| `line6b_eq_spec` | line 6b = `taxableSocialSecurity` (IRC 86(a)(1)/(a)(2) tiers on provisional income, base/adjusted base $25k/$34k, $32k/$44k joint, $0/$0 MFS together) |
| `line6b_bounds` | `0 ≤ line 6b ≤ roundToDollar(85% × max 0 line 6a)` |
| `line6b_mono_otherIncome` | more other income never lowers line 6b |
| `educatorAdjustment_eq_spec` | line 11 = Σ min($300, expenses) of each educator, rounded; `$0` for MFJ dependents |
| `educatorAdjustment_bounds` | `0 ≤ line 11 ≤ $300 × number of educators` (nonnegative expenses) |
| `studentLoanAdjustment_eq_spec` | line 21 = `round(min(interest, $2,500) × (1 − min(1, (MAGI − start)⁺ / range)))`, `$0` if MFS or not eligible |
| `studentLoanAdjustment_bounds` | `0 ≤ line 21 ≤ min(round(interest), $2,500)` (nonnegative interest) |
| `studentLoanAdjustment_zero_of_magi_ge_end` | `$0` from MAGI $95,000 ($195,000 joint) |
| `studentLoanAdjustment_antitone` | more total income never raises line 21 (nonnegative interest) |
| `estimatedPayments_eq_spec` | line 26 = payment rounded to the dollar, or `$0` |
| `agi_eq` | line 11 = line 9 − line 10 |
| `taxableIncome_eq` | line 15 = `max 0 (line 11 − line 14)` |
| `totalPayments_eq` | line 33 = 25d + 26 + 32 when line 26 is whole dollars |
| `totalPayments_eq_full` | the same on `Form1040Full`, unconditionally |
| `totalTax_mono_addW2` | adding a W-2 with box 1 ≥ 0 never lowers line 24 (everything else fixed) |

Every theorem is instantiated on a concrete input with each hypothesis
discharged, and a known-bad output is rejected, next to the proof. Axioms of
all 23: `propext`, `Classical.choice`, `Quot.sound`.

### `#spec_surface` output, reviewed

Counts are of the raw `#spec_surface` output (constants), then of the
definitions and types after dropping projections, constructors, recursors and
instances. "Spec" lists the spec-side definitions (review these); the rest is
the module under test, on the surface because the statement is about it.

| theorem | constants | defs | spec definitions |
|---|---|---|---|
| `standardDeduction_eq_spec` | 57 | 33 | `standardDeductionSpec`, `basicStandardDeduction`, `additionalAmountPerItem` |
| `additionalItems_range` | 53 | 30 | none |
| `requiresScheduleB_eq_spec` | 63 | 20 | `scheduleBRequired`, `reportTaxableInterest` |
| `interestIncome_eq_spec` | 66 | 23 | `interestLine2b`, `scheduleBRequired`, `reportTaxableInterest`, `roundToDollar`, `roundHalfAway` |
| `wages_eq_spec`, `formW2Withholding_eq_spec` | 107 | 24 | `totalOfBox`, `roundToDollar`, `roundHalfAway` |
| `medicareKnockout_eq_spec` | 109 | 26 | `needsForm8959`, `additionalMedicareThreshold`, `filerBox`, `roundToDollar`, `roundHalfAway` |
| `oasdiKnockout_eq_spec` | 110 | 25 | `excessSocialSecurityPossible`, `filerBox`, `roundToDollar`, `roundHalfAway` |
| `line6b_eq_spec` | 54 | 31 | `taxableSocialSecurity`, `ssTaxableTiers`, `ssBaseAmount`, `ssAdjustedBaseAmount`, `ssModifiedAgi`, `percentOf`, `roundToDollar`, `roundHalfAway` |
| `line6b_bounds` | 50 | 26 | `percentOf`, `roundToDollar`, `roundHalfAway` |
| `line6b_mono_otherIncome` | 47 | 23 | none |
| `educatorAdjustment_eq_spec` | 29 | 15 | `educatorDeduction`, `educatorShare`, `tpIsEducator`, `spouseIsEducator`, `roundToDollar`, `roundHalfAway` |
| `educatorAdjustment_bounds` | 25 | 11 | `tpIsEducator`, `spouseIsEducator` |
| `studentLoanAdjustment_eq_spec` | 41 | 22 | `studentLoanDeduction`, `studentLoanEligible`, `studentLoanPhaseoutStart`, `studentLoanPhaseoutRange`, `roundHalfAway` |
| `studentLoanAdjustment_bounds` | 38 | 19 | `roundToDollar`, `roundHalfAway` |
| `studentLoanAdjustment_zero_of_magi_ge_end` | 38 | 19 | `studentLoanPhaseoutStart`, `studentLoanPhaseoutRange` |
| `studentLoanAdjustment_antitone` | 37 | 17 | none |
| `estimatedPayments_eq_spec` | 23 | 9 | `estimatedPaymentsLine26`, `roundToDollar`, `roundHalfAway` |
| `agi_eq`, `taxableIncome_eq`, `totalPayments_eq` | 271 | 83 | none (the calculator surface above) |
| `totalPayments_eq_full` | 506 | 138 | none (calculator + every `Form1040Full` module) |
| `totalTax_mono_addW2` | 270 | 83 | none |

Review. Each spec definition is a few lines with its IRC / instruction
citation in the docstring (`lean/UsTax/Spec/*.lean`). The module-side names
(`StandardDeduction.*`, `Params.*`, `Money.*`, `SocialSecurity.*`, ...) are the
object of the theorem, not assumptions: a wrong parameter in `Params2024`
makes the `_eq_spec` theorem fail to prove, because the spec types the 2024
amounts itself.

### Choices to confirm (human)

1. **Rounding is part of the spec.** Line 6b's bound is `≤ roundToDollar(85%
   × line 6a)`, not `≤ 0.85 × line 6a`: $1 of benefits gives 85 cents, line
   6b $1 (the worksheet rounds to the dollar). Likewise line 21 `≤
   min(round(interest), $2,500)`: $10.60 of interest deducts $11. Stated
   honestly rather than with whole-dollar hypotheses.
2. **Line 6b's bound uses `max 0 line6a`**: net benefits can be negative
   (repayments); then line 6b is `$0` and 85% of a negative amount would be
   below it.
3. **Who counts as a standard-deduction item** (the spouse rules) is taken
   from the calculator's own count, with only its range proved. The spouse
   rules themselves are not restated.
4. **Dependent's earned income** is line 1z (wages), as in Direct File; IRC
   63(c)(5) also counts self-employment income, which is out of scope.
5. **Educator cap per educator, not per filing status**: the module never
   looks at the filing status; "spouse is an educator" on a non-joint return
   is the interview's job. The bound is `$300 × number of educators`.
6. **Student loan uses the exact fraction**, rounded once (DF-BUG(7));
   Direct File's three-decimal ratio differs by up to a few dollars (the spec
   rejects DF's $1,668 at $85,000 MAGI).
7. **Line 33 needs line 26 in whole dollars** on the strict `form1040` (a
   plug-in slot that callers may set to cents); on `Form1040Full` the
   estimated-payments module guarantees it, so `totalPayments_eq_full` has no
   hypothesis.
8. **Line 24 is monotone in wages only with credits held fixed.** On
   `form1040` every credit is an input slot, so adding a W-2 changes no
   credit. Not claimed: refund (line 34) monotone, or anything with EITC or
   CTC computed from wages (false: more wages can lower EITC). The theorem
   holds for dependents too (their standard deduction grows by at most the
   added wages).
9. **Monotone in "other income"** for line 6b is stated by changing line 8 of
   the worksheet input; the proof covers any change of modified AGI
   (`Proofs.tiers_mono`).
