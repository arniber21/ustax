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
```

All in namespace `UsTax.Main`. The first six have no hypothesis besides their
arguments (every `FilingStatus`, every `Int`, every `Form1040In`).
`MatchesTaxTable` has two inside (`r ∈ rows`, `InRow r ti`); `Proofs/Main.lean`
discharges both on a concrete return. (5c) and (5d) have two: line 15 is at
least $100,000 (where the instructions switch from the Tax Table to the
worksheet) and at most $1 trillion (the code's `noUpperBound` sentinel, above
which the Catala marginal form, and so the code, stops taxing; see
`TaxRates/Spec.lean`). `Proofs/Main.lean` discharges both on a concrete return
(single, wages $200,000, line 15 $185,400, line 16 $37,539) and at $100,000
exactly. Together (5b) and (5d) cover every line 15 from $0 to $1 trillion:
below $100,000 the printed Tax Table, from $100,000 the printed worksheet.
Axioms of all eight (`#audit_axioms`): `propext`, `Classical.choice`,
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

**`EitcWithinBounds c credit`** (`Spec/Eitc.lean`, pending): `0 ≤ credit ∧
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

- **(4) EITC bounds** (#67): `EitcWithinBounds (Eitc.caseOf i) (Eitc.eitc i)`
  for every input. Needs the Lean EITC (#46). `EitcWithinBounds` and its
  examples are written and built now.
- **(3c) Credit wiring** (#66): each nonrefundable credit, computed by its own
  module, satisfies `CreditsWithinLiability` against the tax left after the
  credits before it (Schedule 8812 Credit Limit Worksheet A, Schedule 3 order),
  and line 21 is their sum. Needs CTC/ODC (#27) and Schedule 3 in Lean. Today
  line 21 is a plug-in slot, and (3a) holds for whatever value it has.

Each moves into `Challenge.lean` and `comparator.json` when proved.

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
