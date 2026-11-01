import UsTax.Money
import UsTax.Types
import UsTax.Params2024.PtcHsa

/-!
# Premium tax credit, part 1: Form 8962 lines 1 to 8 (issue #47)

Lean implementation of `catala/ptc_family.catala_en` (module `Ptc_family`, scope `PtcFamily`),
written by hand from the Catala source under strategy (c) of `docs/catala-to-lean.md`, in the
order of the Catala file; the code that runs. Law: 26 U.S.C. § 36B(d) (`sources/statute/irc-36B.html`),
26 CFR 1.36B-1, Form 8962 (2024) and its instructions (`sources/forms-instructions/i8962--2024.pdf`:
Worksheet 1-1 and Tables 1-1 to 1-3 p 8, Worksheet 2 p 9, Table 2 p 10, lines 8a and 8b p 11).

| Catala (`Ptc_family`)                        | Lean (`UsTax.PtcFamily`)                         |
|----------------------------------------------|--------------------------------------------------|
| enum `FederalPovertyLocation`                | `FederalPovertyLocation` (`alaska`, `hawaii`, `other`) |
| `scope PtcFamily`                            | `PtcFamilyIn` → `PtcFamilyOut` (`ptcFamily`)     |
| `tax_family_size` (line 1)                   | `taxFamilySize`                                  |
| `federal_poverty_level_threshold` (line 4)   | `federalPovertyLevelThreshold`                   |
| `ptc_magi` (line 2a), `household_income` (3) | `ptcMagi`, `householdIncome`                     |
| `household_income_as_percent` (line 5)       | `householdIncomeAsPercent` (`householdIncomeAsPercentOf`) |
| `applicable_figure` (line 7)                 | `applicableFigure` (`applicableFigureOf`)        |
| `ptc_annual_contribution_amount` (line 8a)   | `ptcAnnualContributionAmount`                    |
| `ptc_monthly_contribution_amount` (line 8b)  | `ptcMonthlyContributionAmount`                   |
| `R.round_dollar`, `R.round_dollar_exact`     | `Money.roundDollar`, `Money.roundDollarExact`    |
| `Decimal.truncate`, `Money.positive`         | `Money.truncateRat`, `Money.positive`            |

Money is `Int` cents, decimals are `Rat`, Catala integers are `Int`, conditions are `Bool`.
Line 7 and line 5 are given as separate functions of their inputs (`applicableFigureOf`,
`householdIncomeAsPercentOf`) so that the lemmas can state them; the scope calls them.

Known difference from Catala, by design (as everywhere in `UsTax.Money`): a poverty line that
rounds to `$0` with a nonzero family size would make Catala raise `DivisionByZero` on line 5;
Lean returns `0` there. No family size gives such a line (the smallest line, size `-1` with two
claimable filers and no dependent, is $4,300).
-/

namespace UsTax.PtcFamily

open Money

/-- Catala `FederalPovertyLocation`: which poverty line table applies (Form 8962 line 4 check
boxes; DF `ptc.xml` `/federalPovertyLocationOptions`). -/
inductive FederalPovertyLocation where
  | alaska | hawaii | other
  deriving DecidableEq, Repr, Inhabited

/-- Catala case name, for the JSON driver. -/
def FederalPovertyLocation.catalaName : FederalPovertyLocation → String
  | .alaska => "Alaska" | .hawaii => "Hawaii" | .other => "Other"

/-- Inputs of `PtcFamily` (all wired by the orchestrator; see the Catala file). -/
structure PtcFamilyIn where
  filingStatus : FilingStatus
  claimedDependentsCount : Int
  primarySomeoneCanClaimForTaxBenefits : Bool
  secondarySomeoneCanClaimForTaxBenefits : Bool
  livedInAk : Bool
  livedInHi : Bool
  /-- Form 1040 line 11. -/
  agi : Int
  /-- Form 1040 line 2a. -/
  taxExemptInterest : Int
  /-- Form 1040 line 6a minus 6b. -/
  nonTaxableSocialSecurityBenefits : Int
  deriving Repr

/-- Outputs of `PtcFamily` (the Catala `internal` variables are included as fields too). -/
structure PtcFamilyOut where
  taxFamilySizeNegation : Int
  /-- Form 8962 line 1. -/
  taxFamilySize : Int
  taxFamilySizeIsZero : Bool
  federalPovertyLocation : FederalPovertyLocation
  povertyLineFamilyOfOne : Int
  povertyLineIncrement : Int
  /-- Form 8962 line 4. -/
  federalPovertyLevelThreshold : Int
  /-- Form 8962 line 2a. -/
  ptcMagi : Int
  /-- Form 8962 line 3. -/
  householdIncome : Int
  /-- Form 8962 line 5 (a decimal with a whole value). -/
  householdIncomeAsPercent : Rat
  /-- Form 8962 line 7. -/
  applicableFigure : Rat
  /-- Form 8962 line 8a. -/
  ptcAnnualContributionAmount : Int
  /-- Form 8962 line 8b. -/
  ptcMonthlyContributionAmount : Int
  deriving Repr

/-- Line 5 (Worksheet 2) from line 3, line 4 and whether the tax family is empty: `0` for an
empty family; `401` above four times the line; else the ratio of the whole-dollar amounts,
times 100, truncated. -/
def householdIncomeAsPercentOf (isZero : Bool) (householdIncome threshold : Int) : Rat :=
  if isZero then 0
  else if householdIncome > mulRate threshold (Params.ptcPovertyPercentCapMultiple : Rat)
  then Params.ptcPovertyPercentOverCap
  else truncateRat (divMoney (roundDollar householdIncome) (roundDollar threshold) * 100)

/-- Line 7, Table 2, as the Catala definition computes it from line 5. -/
def applicableFigureOf (p : Rat) : Rat :=
  if p ≤ (Params.ptcApplicableFigureZeroThrough : Rat) then 0
  else if p ≤ (Params.ptcApplicableFigureLinearThrough : Rat) then
    (p - (Params.ptcApplicableFigureZeroThrough : Rat)) * Params.ptcApplicableFigurePerPointLow
  else if p ≤ (Params.ptcApplicableFigureLastRow : Rat) then
    (roundRat ((Params.ptcApplicableFigureAt300 + Params.ptcApplicableFigurePerPointHigh *
        (p - (Params.ptcApplicableFigureLinearThrough : Rat))) * 10000) : Rat) / 10000
  else Params.ptcApplicableFigureMax

/-- Catala `scope PtcFamily`, definition by definition. -/
def ptcFamily (i : PtcFamilyIn) : PtcFamilyOut :=
  -- Line 1 (instructions for line 1, p 7)
  let negation : Int :=
    (if i.primarySomeoneCanClaimForTaxBenefits then 1 else 0) +
    (if i.secondarySomeoneCanClaimForTaxBenefits then 1 else 0)
  let base : Int := match i.filingStatus with
    | .marriedFilingJointly => 2
    | .single | .marriedFilingSeparately | .headOfHousehold | .qualifyingSurvivingSpouse => 1
  let size := base + i.claimedDependentsCount - negation
  let isZero := decide (size = 0)
  -- Line 4 (Tables 1-1 to 1-3); DF checks Alaska first, then Hawaii.
  let location : FederalPovertyLocation :=
    if i.livedInAk then .alaska else if i.livedInHi then .hawaii else .other
  let ofOne := match location with
    | .alaska => Params.ptcPovertyLineFamilyOfOneAlaska
    | .hawaii => Params.ptcPovertyLineFamilyOfOneHawaii
    | .other => Params.ptcPovertyLineFamilyOfOneOther
  let increment := match location with
    | .alaska => Params.ptcPovertyLineIncrementAlaska
    | .hawaii => Params.ptcPovertyLineIncrementHawaii
    | .other => Params.ptcPovertyLineIncrementOther
  let threshold := if isZero then 0 else ofOne + mulRate increment ((size - 1 : Int) : Rat)
  -- Lines 2a and 3 (Worksheet 1-1)
  let magi := if isZero then 0 else i.agi + i.taxExemptInterest + i.nonTaxableSocialSecurityBenefits
  let income := positive magi
  -- Line 5 (Worksheet 2), line 7 (Table 2)
  let percent := householdIncomeAsPercentOf isZero income threshold
  let figure := applicableFigureOf percent
  -- Lines 8a and 8b
  let annual := roundDollarExact (roundDollar income) figure
  let monthly := roundDollarExact annual (1 / 12)
  { taxFamilySizeNegation := negation, taxFamilySize := size, taxFamilySizeIsZero := isZero
    federalPovertyLocation := location, povertyLineFamilyOfOne := ofOne
    povertyLineIncrement := increment, federalPovertyLevelThreshold := threshold
    ptcMagi := magi, householdIncome := income, householdIncomeAsPercent := percent
    applicableFigure := figure, ptcAnnualContributionAmount := annual
    ptcMonthlyContributionAmount := monthly }

/-! ### Unit tests: every assertion of `catala/tests/test_ptc_family.catala_en`

`base` is the Catala helper `Case` with its defaults: a single filer in the 48 states, no
dependents, nobody can claim the filer, AGI `$0`, no tax-exempt interest, no nontaxable Social
Security. Table 2 in full is `UsTax/Ptc/Table2.lean`. -/

/-- The defaults of the Catala test helper `Case`. -/
def base : PtcFamilyIn :=
  { filingStatus := .single, claimedDependentsCount := 0
    primarySomeoneCanClaimForTaxBenefits := false, secondarySomeoneCanClaimForTaxBenefits := false
    livedInAk := false, livedInHi := false, agi := 0, taxExemptInterest := 0
    nonTaxableSocialSecurityBenefits := 0 }

private def run (f : PtcFamilyIn → PtcFamilyIn) : PtcFamilyOut := ptcFamily (f base)
private def withAgi (dollars : Int) : PtcFamilyOut := run fun c => { c with agi := dollars * 100 }
private def withDeps (n : Int) : PtcFamilyOut := run fun c => { c with claimedDependentsCount := n }

-- TestSingleFamilySizeOne
#guard (run id).taxFamilySize == 1
#guard (run id).taxFamilySize != 2
#guard (run id).federalPovertyLevelThreshold == 1_458_000
-- TestMfjWithOneChildFamilySizeThree
private def mfj1 := run fun c => { c with filingStatus := .marriedFilingJointly, claimedDependentsCount := 1 }
#guard mfj1.taxFamilySize == 3
#guard mfj1.federalPovertyLevelThreshold == 2_486_000
#guard mfj1.federalPovertyLevelThreshold != 1_972_000
-- TestHohWithTwoChildrenFamilySizeThree
private def hoh2 := run fun c => { c with filingStatus := .headOfHousehold, claimedDependentsCount := 2 }
#guard hoh2.taxFamilySize == 3
#guard hoh2.federalPovertyLevelThreshold == 2_486_000
-- TestClaimableFilerIsNotCounted
private def claimable := run fun c => { c with primarySomeoneCanClaimForTaxBenefits := true }
#guard claimable.taxFamilySize == 0
#guard claimable.federalPovertyLevelThreshold == 0
#guard claimable.householdIncomeAsPercent == 0
#guard claimable.ptcAnnualContributionAmount == 0
-- TestMfjOneSpouseClaimable
#guard (run fun c => { c with
    filingStatus := .marriedFilingJointly,
    secondarySomeoneCanClaimForTaxBenefits := true }).taxFamilySize == 1
-- TestPovertyLineTable11
#guard (withDeps 0).federalPovertyLevelThreshold == 1_458_000
#guard (withDeps 1).federalPovertyLevelThreshold == 1_972_000
#guard (withDeps 3).federalPovertyLevelThreshold == 3_000_000
#guard (withDeps 4).federalPovertyLevelThreshold == 3_514_000
#guard (withDeps 7).federalPovertyLevelThreshold == 5_056_000
#guard (withDeps 10).taxFamilySize == 11
#guard (withDeps 10).federalPovertyLevelThreshold == 6_598_000
-- TestPovertyLineAlaska
private def ak (n : Int) := run fun c => { c with livedInAk := true, claimedDependentsCount := n }
#guard (ak 0).federalPovertyLevelThreshold == 1_821_000
#guard (ak 2).federalPovertyLevelThreshold == 3_107_000
#guard (ak 10).federalPovertyLevelThreshold == 8_251_000
-- TestPovertyLineHawaii
private def hi (n : Int) := run fun c => { c with livedInHi := true, claimedDependentsCount := n }
#guard (hi 0).federalPovertyLevelThreshold == 1_677_000
#guard (hi 2).federalPovertyLevelThreshold == 2_859_000
#guard (hi 10).federalPovertyLevelThreshold == 7_587_000
-- TestModifiedAgiAddsInterestAndSocialSecurity
private def magi := run fun c => { c with
    agi := 4_000_000, taxExemptInterest := 120_000,
    nonTaxableSocialSecurityBenefits := 300_000 }
#guard magi.ptcMagi == 4_420_000
#guard magi.householdIncome == 4_420_000
#guard magi.householdIncome != 4_000_000
-- TestNegativeMagiGivesZeroHouseholdIncome
#guard (withAgi (-300)).ptcMagi == -30_000
#guard (withAgi (-300)).householdIncome == 0
#guard (withAgi (-300)).householdIncomeAsPercent == 0
#guard (withAgi (-300)).ptcAnnualContributionAmount == 0
-- TestExactlyFourTimesIsFourHundred
#guard (withAgi 58_320).householdIncomeAsPercent == 400
#guard (withAgi 58_320).householdIncomeAsPercent != 401
#guard (withAgi 58_320).applicableFigure == 85 / 1000
-- TestJustAboveFourTimesIsFourHundredOne
#guard (withAgi 58_321).householdIncomeAsPercent == 401
#guard (withAgi 58_321).householdIncomeAsPercent != 400
#guard (withAgi 58_321).applicableFigure == 85 / 1000
#guard (withAgi 58_321).ptcAnnualContributionAmount == 495_700
-- TestPercentIsTruncatedNotRounded
#guard (withAgi 14_579).householdIncomeAsPercent == 99
#guard (withAgi 14_579).householdIncomeAsPercent != 100
#guard (withAgi 27_000).householdIncomeAsPercent == 185
#guard (withAgi 58_300).householdIncomeAsPercent == 399
#guard (withAgi 58_300).householdIncomeAsPercent != 400
-- TestFigureAt150PercentIsZero
#guard (withAgi 21_870).householdIncomeAsPercent == 150
#guard (withAgi 21_870).applicableFigure == 0
#guard (withAgi 21_870).ptcAnnualContributionAmount == 0
#guard (withAgi 21_870).ptcMonthlyContributionAmount == 0
-- TestFigureAt300PercentIsSixPercent
#guard (withAgi 43_740).householdIncomeAsPercent == 300
#guard (withAgi 43_740).applicableFigure == 6 / 100
#guard (withAgi 43_740).applicableFigure != 603 / 10000
#guard (withAgi 43_740).ptcAnnualContributionAmount == 262_400
#guard (withAgi 43_740).ptcMonthlyContributionAmount == 21_900
-- TestFigureAtFourHundredPercentIsEightAndAHalf
#guard (withAgi 58_320).ptcAnnualContributionAmount == 495_700
#guard (withAgi 58_320).ptcMonthlyContributionAmount == 41_300
-- TestFigureHalfUpRows
#guard (withAgi 43_886).householdIncomeAsPercent == 301
#guard (withAgi 43_886).applicableFigure == 603 / 10000
#guard (withAgi 44_032).householdIncomeAsPercent == 302
#guard (withAgi 44_032).applicableFigure == 605 / 10000
#guard (withAgi 58_175).householdIncomeAsPercent == 399
#guard (withAgi 58_175).applicableFigure == 848 / 10000
#guard (withAgi 43_886).applicableFigure != 602 / 10000
-- TestAnnualContributionRoundsOnce
#guard (withAgi 45_100).householdIncomeAsPercent == 309
#guard (withAgi 45_100).applicableFigure == 623 / 10000
#guard (withAgi 45_100).ptcAnnualContributionAmount == 281_000
#guard (withAgi 45_100).ptcMonthlyContributionAmount == 23_400
-- TestFigureMiddleRows
#guard (withAgi 22_016).householdIncomeAsPercent == 151
#guard (withAgi 22_016).applicableFigure == 4 / 10000
#guard (withAgi 29_160).applicableFigure == 2 / 100
#guard (withAgi 36_450).applicableFigure == 4 / 100
#guard (withAgi 29_160).ptcAnnualContributionAmount == 58_300
-- TestMfjUsesFamilyOfTwoLine
private def mfj50 := run fun c => { c with filingStatus := .marriedFilingJointly, agi := 5_000_000 }
#guard mfj50.federalPovertyLevelThreshold == 1_972_000
#guard mfj50.householdIncomeAsPercent == 253
#guard mfj50.applicableFigure == 412 / 10000
#guard mfj50.ptcAnnualContributionAmount == 206_000
#guard mfj50.ptcMonthlyContributionAmount == 17_200
-- TestBadOutputsRejected
#guard !((withAgi 14_579).householdIncomeAsPercent == 100)
#guard !((withAgi 58_320).householdIncomeAsPercent == 401)
#guard !((withAgi 58_320).applicableFigure == 0)

end UsTax.PtcFamily
