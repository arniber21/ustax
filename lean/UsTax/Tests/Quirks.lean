import UsTax.Calculator
import UsTax.Cdcc
import UsTax.PtcAllowed
import UsTax.Proofs.Main
import UsTax.Spec.Adjustments
import UsTax.Spec.FormW2
import UsTax.Spec.Interest

/-!
# Pinning tests for the Direct File quirk decisions (issue #60)

`docs/quirk-decisions.md` records, for every row of `docs/direct-file-bugs.md` and every
`catala/CONVENTIONS.md` section 8 item, the decision and the test that pins it. The rows that
had no pinning test got one in `catala/tests/` (named below) and its mirror here. Each check
states the value the decision gives and that Direct File's value is not produced. Values are
computed by the kernel (`decide +kernel`); nothing here changes behaviour.
-/

namespace UsTax.Tests.Quirks

open UsTax UsTax.Money

/-! ## DF-BUG-2, QUIRK(Q4): QBI (line 13) and the AOC (line 29) are `$0` stubs

Catala `TestQ4QbiAndAocStubs` (`catala/tests/test_form_1040.catala_en`). -/

theorem q4_qbi_and_aoc_stubs :
    (Form1040.form1040 Main.sampleReturn).qualifiedBusinessIncomeDeduction = 0 ∧
    (Form1040.form1040 Main.sampleReturn).americanOpportunityCredit = 0 ∧
    (Form1040.form1040 Main.sampleReturn).totalOtherPaymentsRefundableCredits = 0 ∧
    (Form1040.form1040 Main.sampleReturn).taxableIncome = 35_400_00 := by
  decide +kernel

/-! ## DF-BUG-5, QUIRK(Q10): exact arithmetic, not a 32-bit float

Catala `TestDfBug5ExactAboveFloat` (`catala/tests/test_rounding.catala_en`): half of
$167,772.99 is $83,886.495, so $83,886; Direct File's float turns 16,777,299 cents into
16,777,300 and gets $83,887. -/

theorem dfBug5_exact_above_float :
    roundDollarExact 16_777_299 (1 / 2) = 83_886_00 ∧
    roundDollarExact 16_777_299 (1 / 2) ≠ 83_887_00 ∧
    (16_777_217 : Int) + 16_777_217 = 33_554_434 := by
  decide +kernel

/-! ## DF-BUG(25) to DF-BUG(28): the child and dependent care credit

Catala `TestDfBug25MfsExceptionOnePerson`, `TestDfBug26QssLine19`,
`TestDfBug27ForfeitedWithoutBox10`, `TestDfBug28UnclaimedChildQualifies`
(`catala/tests/test_cdcc.catala_en`). The input is the `Cdcc.Case` helper (the Catala `Case`)
with the household changed as the Catala test does. -/

/-- A household member of the CDCC tests with the given upkeep, residency and claim answers. -/
def cdccChild (dob : Date) (expenses : Int) (upkeep : Bool := true)
    (residency : QualifyingChild.ResidencyDuration := .allYear) (claims : Bool := true) :
    Cdcc.CdccMember :=
  let c := Cdcc.mkChild dob expenses false
  { c with
    member := { c.member with
      person := { c.member.person with residencyDuration := residency }
      answers := { c.member.answers with tpClaims := claims } }
    cdcc := { c.cdcc with tpPaidMostOfHomeUpkeep := upkeep } }

/-- DF-BUG(25), married filing separately, lived apart, with the given household. -/
def mfsApart (household : List Cdcc.CdccMember) : Cdcc.Form2441In :=
  { ({ filingStatus := .marriedFilingSeparately } : Cdcc.Case).input with
    livedApartLastSixMonths := true, household }

/-- DF-BUG(25): no single person passes both home tests, so no credit (DF allows it); with the
upkeep paid for the son who lives with the filer, $1,050. -/
theorem dfBug25_mfs_exception_one_person :
    (Cdcc.form2441 (mfsApart [cdccChild ⟨2020, 3, 1⟩ 3_000_00 (upkeep := false),
      cdccChild ⟨2018, 5, 5⟩ 0 (residency := .lessThanSixMonths)])).benefits.mfsButEligibleForCdcc
      = false ∧
    (Cdcc.form2441 (mfsApart [cdccChild ⟨2020, 3, 1⟩ 3_000_00 (upkeep := false),
      cdccChild ⟨2018, 5, 5⟩ 0 (residency := .lessThanSixMonths)])).cdccTotalCredit = 0 ∧
    (Cdcc.form2441 (mfsApart [cdccChild ⟨2020, 3, 1⟩ 3_000_00 (upkeep := false),
      cdccChild ⟨2018, 5, 5⟩ 0 (residency := .lessThanSixMonths)])).cdccTotalCredit ≠ 1_050_00 ∧
    (Cdcc.form2441 (mfsApart [cdccChild ⟨2020, 3, 1⟩ 3_000_00])).cdccTotalCredit = 1_050_00 := by
  decide +kernel

/-- The QSS case of DF-BUG(26): $45,000 of wages, $1,000 of benefits. -/
def qssCase : Cdcc.Case :=
  { filingStatus := .qualifyingSurvivingSpouse, primaryBenefits := 1_000_00, primaryPlanMax := 5_000_00 }

/-- DF-BUG(26): a qualifying surviving spouse's line 19 is line 18, $45,000 (DF: `$0`). -/
theorem dfBug26_qss_line19 :
    (Cdcc.form2441 qssCase.input).benefits.line19EarnedIncome = 45_000_00 ∧
    (Cdcc.form2441 qssCase.input).benefits.line19EarnedIncome ≠ 0 := by
  decide +kernel

/-- The DF-BUG(27) case: a $1,000 carryover, $400 forfeited, no box 10. -/
def forfeitCase : Cdcc.Case := { carryover := 1_000_00, forfeited := 400_00 }

/-- DF-BUG(27): line 14 $400, line 15 $600 (DF: $1,000). -/
theorem dfBug27_forfeited_without_box10 :
    (Cdcc.form2441 forfeitCase.input).benefits.line14Forfeited = 400_00 ∧
    (Cdcc.form2441 forfeitCase.input).benefits.line15AdjustedBenefits = 600_00 ∧
    (Cdcc.form2441 forfeitCase.input).benefits.line15AdjustedBenefits ≠ 1_000_00 := by
  decide +kernel

/-- DF-BUG(28): the son is not claimed but can be: one qualifying person, $1,050 (DF: `$0`). -/
theorem dfBug28_unclaimed_child_qualifies :
    (Cdcc.form2441 { ({} : Cdcc.Case).input with
      household := [cdccChild ⟨2020, 3, 1⟩ 3_000_00 (claims := false)] }).benefits.countOfQualifyingPersons
      = 1 ∧
    (Cdcc.form2441 { ({} : Cdcc.Case).input with
      household := [cdccChild ⟨2020, 3, 1⟩ 3_000_00 (claims := false)] }).cdccTotalCredit = 1_050_00 ∧
    (Cdcc.form2441 { ({} : Cdcc.Case).input with
      household := [cdccChild ⟨2020, 3, 1⟩ 3_000_00 (claims := false)] }).cdccTotalCredit ≠ 0 := by
  decide +kernel

/-- QUIRK(Q12): married filing jointly, wages $10,000 and $40,000, $3,000 of benefits each. -/
def q12Case : Cdcc.Case :=
  { filingStatus := .marriedFilingJointly
    primaryWages := 10_000_00
    secondaryWages := 40_000_00
    primaryBenefits := 3_000_00
    secondaryBenefits := 3_000_00
    primaryPlanMax := 5_000_00
    secondaryPlanMax := 5_000_00
    childExpenses := 1_000_00
    agi := 50_000_00 }

/-- QUIRK(Q12), reproduced: DF's second alternative ($40,000 − $10,000 ≥ $10,000 + $3,000)
allocates to the primary filer. Catala `TestQ12AllocationReproduced`. -/
theorem q12_allocation_reproduced :
    (Cdcc.form2441 q12Case.input).benefits.taxableBenefits = 6_000_00 ∧
    (Cdcc.form2441 q12Case.input).allocateAllToPrimary = true ∧
    (Cdcc.form2441 q12Case.input).allocateAllToSecondary = false ∧
    (Cdcc.form2441 q12Case.input).primaryTaxableBenefits = 3_000_00 ∧
    (Cdcc.form2441 q12Case.input).secondaryTaxableBenefits = 3_000_00 ∧
    (Cdcc.form2441 q12Case.input).cdccTotalCredit = 200_00 := by
  decide +kernel

/-! ## DF-BUG(29), DF-BUG(30): the EITC child need not be claimed

Catala `TestDfBug29UnclaimedChildEitc`, `TestDfBug30MarriedUnclaimedChildEitc`
(`catala/tests/test_calculator.catala_en`). -/

open Calculator Calculator.Tests in
/-- A child of the calculator tests, not claimed, married or not. -/
def unclaimedChild (dob : Date) (married : Bool) : HouseholdMember :=
  let c := mkChild dob
  { c with dependent := { c.dependent with
      answers := { c.dependent.answers with tpClaims := false }
      person := { c.dependent.person with married } } }

open Calculator Calculator.Tests in
/-- DF-BUG(29): `TestHoh` with the son not claimed: EITC $1,448 (DF: `$0`), no child tax credit. -/
theorem dfBug29_unclaimed_child_eitc :
    (calculator (ret .headOfHousehold [mkW2 4_000_000 200_000]
      [unclaimedChild ⟨2014, 9, 10⟩ false])).earnedIncomeCredit = 1_448_00 ∧
    (calculator (ret .headOfHousehold [mkW2 4_000_000 200_000]
      [unclaimedChild ⟨2014, 9, 10⟩ false])).earnedIncomeCredit ≠ 0 ∧
    (calculator (ret .headOfHousehold [mkW2 4_000_000 200_000]
      [unclaimedChild ⟨2014, 9, 10⟩ false])).totalCtcAndOdc = 0 ∧
    (calculator (ret .headOfHousehold [mkW2 4_000_000 200_000]
      [unclaimedChild ⟨2014, 9, 10⟩ false])).unsupported = false := by
  decide +kernel

open Calculator Calculator.Tests in
/-- DF-BUG(30): single, a married 16-year-old daughter not claimed: EITC $1,448 (DF: `$0`). -/
theorem dfBug30_married_unclaimed_child_eitc :
    (calculator (ret .single [mkW2 4_000_000 200_000]
      [unclaimedChild ⟨2008, 9, 10⟩ true])).earnedIncomeCredit = 1_448_00 ∧
    (calculator (ret .single [mkW2 4_000_000 200_000]
      [unclaimedChild ⟨2008, 9, 10⟩ true])).earnedIncomeCredit ≠ 0 ∧
    (calculator (ret .single [mkW2 4_000_000 200_000]
      [unclaimedChild ⟨2008, 9, 10⟩ true])).unsupported = false := by
  decide +kernel

/-! ## DF-BUG(33): annual totals only if every Form 1095-A allows them

Catala `TestDfBug33EveryFormMustAllowAnnualTotals` (`catala/tests/test_ptc_allowed.catala_en`). -/

open PtcAllowed in
/-- A full-year form and a January-June form: the monthly path, $4,200 (DF: annual totals). -/
theorem dfBug33_every_form_must_allow_annual :
    (ptcAllowed { base with form1095As := [fullYearForm 4_000_00 3_600_00 0,
      partYearForm (d24 1 1) (d24 6 30) 1 6 300_00 300_00 0] }).ptcCanReportAnnualTotals = false ∧
    (ptcAllowed { base with form1095As := [fullYearForm 4_000_00 3_600_00 0,
      partYearForm (d24 1 1) (d24 6 30) 1 6 300_00 300_00 0] }).totalPtcAmountAllowed = 4_200_00 ∧
    (ptcAllowed { base with form1095As := [fullYearForm 4_000_00 3_600_00 0,
      partYearForm (d24 1 1) (d24 6 30) 1 6 300_00 300_00 0] }).koTpNeedsToDelete1095A = true := by
  decide +kernel

/-! ## Existing pins restated by name (rows whose Lean pin was an anonymous `example` or a
`#guard` inside a module) -/

/-- DF-BUG-7: the exact phase-out ratio gives $1,667 at $85,000 single, not DF's $1,668. -/
theorem dfBug7_exact_ratio :
    UsTax.Spec.studentLoanDeduction .single true 3_000_00 85_000_00 = 1_667_00 ∧
    UsTax.Spec.studentLoanDeduction .single true 3_000_00 85_000_00 ≠ 1_668_00 := by
  decide

/-- QUIRK(Q-R1), DF-BUG-4: per-item rounding. Two W-2s of $1,000.40: line 1a is $2,000 (rounding
only the total, as the 1040 instructions say, would give $2,001); three payers of $500.51 with
Schedule B: line 2b $1,503 (not $1,502). -/
theorem qR1_per_item_rounding :
    UsTax.Spec.totalOfBox [1_000_40, 1_000_40] = 2_000_00 ∧
    UsTax.Spec.totalOfBox [1_000_40, 1_000_40] ≠ 2_001_00 ∧
    UsTax.Spec.interestLine2b [500_51, 500_51, 500_51] false = 1_503_00 ∧
    UsTax.Spec.interestLine2b [500_51, 500_51, 500_51] false ≠ 1_502_00 := by
  decide

/-- QUIRK(Q3), DF-BUG-6: line 23 is `$0` and line 24 = line 22 on the sample return. -/
theorem q3_line23_not_added :
    (Form1040.form1040 Main.sampleReturn).line21OfSchedule2 = 0 ∧
    (Form1040.form1040 Main.sampleReturn).totalTax =
      (Form1040.form1040 Main.sampleReturn).taxLessNonRefundableCredits := by
  decide +kernel

/-- QUIRK(Q-R2): ties round away from zero (`HALF_UP`), not to even. -/
theorem qR2_ties_away_from_zero :
    roundDollar 50 = 100 ∧ roundDollar 250 = 300 ∧ roundDollar (-50) = -100 := by
  decide +kernel

/-- QUIRK(Q-R3): `round(x * rate)` rounds to the cent, then to the dollar ($1,116), as Direct
File does; `roundDollarExact` (the statute reading, kept for #60) gives $1,115. -/
theorem qR3_double_rounding :
    roundDollar (mulRate 10_000_00 (11154958 / 100000000)) = 1_116_00 ∧
    roundDollarExact 10_000_00 (11154958 / 100000000) = 1_115_00 := by
  decide +kernel

end UsTax.Tests.Quirks
