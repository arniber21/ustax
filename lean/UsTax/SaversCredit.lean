import UsTax.Money
import UsTax.Types
import UsTax.ParamsCredits

/-!
# Retirement savings contributions credit (Saver's credit), Form 8880 (issue #46)

Lean implementation of `catala/savers_credit.catala_en` (module `Savers_credit`, scopes
`SaversColumn` and `SaversCredit`), written by hand from the Catala source under strategy (c)
of `docs/catala-to-lean.md`, in the order of the Catala file; the code that runs. Law:
26 U.S.C. 25B, Notice 2023-75 section 3, Form 8880 (2024) and its Credit Limit Worksheet.

| Catala (`Savers_credit`)              | Lean (`UsTax.SaversCredit`)                          |
|---------------------------------------|------------------------------------------------------|
| enum `SaversCreditMultiplier`         | `SaversCreditMultiplier` (`fifty` ... `zero`)        |
| `scope SaversColumn`                  | `SaversColumnIn` → `SaversColumnOut` (`saversColumn`) |
| `scope SaversCredit`                  | `SaversCreditIn` → `SaversCreditOut` (`saversCredit`) |
| `Money.positive`, `Money.min`         | `Money.positive`, `Money.min`                        |
| `R.round_dollar`                      | `Money.roundDollar`                                  |

Money is `Int` cents; the multiplier is a `Rat`. Conditions are `Bool`. `DF-BUG(14)` is
reproduced as in Catala: on a joint return both columns of line 4 hold the sum of both
spouses' 1099-R amounts (Lean follows Catala, not Direct File).
-/

namespace UsTax.SaversCredit

open Money

/-- Catala `SaversCreditMultiplier`: the decimal amount on Form 8880 line 9. -/
inductive SaversCreditMultiplier where
  | fifty | twenty | ten | zero
  deriving DecidableEq, Repr, Inhabited

/-- Catala case name, for the JSON driver. -/
def SaversCreditMultiplier.catalaName : SaversCreditMultiplier → String
  | .fifty => "Fifty" | .twenty => "Twenty" | .ten => "Ten" | .zero => "Zero"

/-! ### Scope `SaversColumn`: Form 8880 lines 1 to 6 for one person -/

/-- Inputs of `SaversColumn` (lines 1, 2 and 4, already filtered by eligibility). -/
structure SaversColumnIn where
  line1 : Int
  line2 : Int
  line4 : Int

/-- Outputs of `SaversColumn`. -/
structure SaversColumnOut where
  line3 : Int
  line5 : Int
  line6 : Int

/-- Catala `scope SaversColumn`. Line 3 adds lines 1 and 2, line 5 subtracts line 4 (not below
`$0`), line 6 is the smaller of line 5 and `$2,000` (IRC 25B(a), (d)(2)(A)). -/
def saversColumn (i : SaversColumnIn) : SaversColumnOut :=
  let line3 := i.line1 + i.line2
  let line5 := positive (line3 - i.line4)
  { line3, line5, line6 := Money.min Params.saversContributionCap line5 }

/-! ### Scope `SaversCredit` -/

/-- Inputs of `SaversCredit`. -/
structure SaversCreditIn where
  filingStatus : FilingStatus
  agi : Int
  isMfjDependent : Bool
  primaryFilerIsUnder18 : Bool
  primaryFilerIsStudent : Bool
  primaryFilerIsClaimedAsDependent : Bool
  secondaryFilerIsUnder18 : Bool
  secondaryFilerIsStudent : Bool
  secondaryFilerIsClaimedAsDependent : Bool
  primaryFilerTotalDeferralsAndContributions : Int
  secondaryFilerTotalDeferralsAndContributions : Int
  primaryFilerSaversGrossDistributions : Int
  secondaryFilerSaversGrossDistributions : Int
  /-- Form 1040 line 18. -/
  totalTentativeTax : Int
  /-- Schedule 3 line 2. -/
  cdccTotalCredit : Int
  /-- Schedule 3 line 6d. -/
  totalEdc : Int
  hasDistributionsInLastThreeYears : Bool
  hasCurrentYearDistributions : Bool
  hasSelfReportedContributions : Bool

/-- Outputs of `SaversCredit` (the Catala `internal` variables are included as fields
too, because the unit tests and the lemmas read them). -/
structure SaversCreditOut where
  isFilingStatusMfj : Bool
  isFilingStatusHoh : Bool
  primaryFilerIsEligible : Bool
  secondaryFilerIsEligible : Bool
  secondaryFilerIsApplicableAndEligible : Bool
  saversCreditMaxAgiLimit : Int
  saversCreditAgiLimitForFiftyPercent : Int
  saversCreditAgiLimitForTwentyPercent : Int
  isAgiEligibleForSaversCredit : Bool
  eligibleForSaversCredit : Bool
  primaryFilerIraAndAbleContributions : Int
  secondaryFilerIraAndAbleContributions : Int
  primaryFilersDeferralsAndContributions : Int
  secondaryFilersDeferralsAndContributions : Int
  primaryFilerGrossDistributions : Int
  secondaryFilerGrossDistributions : Int
  primaryColumn : SaversColumnOut
  secondaryColumn : SaversColumnOut
  primaryFilerTotalContributions : Int
  secondaryFilerTotalContributions : Int
  primaryFilerTotalContributionsLessDistributions : Int
  secondaryFilerTotalContributionsLessDistributions : Int
  primaryFilerMaxCreditCalc : Int
  secondaryFilerMaxCreditCalc : Int
  /-- Form 8880 line 7. -/
  combinedCreditLimit : Int
  /-- Form 8880 line 9. -/
  saversCreditMultiplier : SaversCreditMultiplier
  saversCreditMultiplierAsRational : Rat
  /-- Form 8880 line 10. -/
  ratioedCombinedCreditLimit : Int
  /-- Form 8880 line 11, the Credit Limit Worksheet. -/
  limitationBasedOnTaxLiability : Int
  qualifiedForSaverCreditWoTaxLiability : Bool
  qualifiedForSaverCredit : Bool
  /-- Form 8880 line 12; Schedule 3 line 4. -/
  qualifiedSaverCreditAmount : Int
  isReceivingSaversCredit : Bool
  koSaversCreditKnockouts : Bool
  unsupported : Bool

/-- The decimal amount of a multiplier (Catala `savers_credit_multiplier_as_rational`). -/
def multiplierAsRational : SaversCreditMultiplier → Rat
  | .fifty => Params.saversRateHigh
  | .twenty => Params.saversRateMiddle
  | .ten => Params.saversRateLow
  | .zero => 0

/-- Catala `scope SaversCredit`, definition by definition. -/
def saversCredit (i : SaversCreditIn) : SaversCreditOut :=
  let isMfj := decide (i.filingStatus = .marriedFilingJointly)
  let isHoh := decide (i.filingStatus = .headOfHousehold)
  -- IRC 25B(c): eligible individual
  let primaryEligible := !i.primaryFilerIsUnder18 && !i.primaryFilerIsClaimedAsDependent &&
    !i.primaryFilerIsStudent
  let secondaryEligible := !i.secondaryFilerIsUnder18 && !i.secondaryFilerIsClaimedAsDependent &&
    !i.secondaryFilerIsStudent
  let secondaryApplicableAndEligible := isMfj && secondaryEligible
  -- applicable percentage (Form 8880 line 9)
  let limit50 := if isMfj then Params.saversAgiLimit50Mfj
    else if isHoh then Params.saversAgiLimit50Hoh else Params.saversAgiLimit50Other
  let limit20 := if isMfj then Params.saversAgiLimit20Mfj
    else if isHoh then Params.saversAgiLimit20Hoh else Params.saversAgiLimit20Other
  let maxLimit := if isMfj then Params.saversAgiLimit10Mfj
    else if isHoh then Params.saversAgiLimit10Hoh else Params.saversAgiLimit10Other
  let agiEligible := decide (i.agi ≤ maxLimit)
  let multiplier :=
    if i.agi ≤ limit50 then SaversCreditMultiplier.fifty
    else if i.agi ≤ limit20 then .twenty
    else if i.agi ≤ maxLimit then .ten
    else .zero
  let multiplierRat := multiplierAsRational multiplier
  let eligible := !i.isMfjDependent &&
    (if isMfj then primaryEligible || secondaryEligible else primaryEligible) && agiEligible
  -- lines 1, 2
  let iraP : Int := 0
  let iraS : Int := 0
  let defP := if primaryEligible then roundDollar i.primaryFilerTotalDeferralsAndContributions else 0
  let defS := if secondaryApplicableAndEligible
    then roundDollar i.secondaryFilerTotalDeferralsAndContributions else 0
  -- line 4 (DF-BUG(14): the statute counts both spouses' distributions in both columns)
  let distP := if isMfj
    then roundDollar (i.primaryFilerSaversGrossDistributions + i.secondaryFilerSaversGrossDistributions)
    else roundDollar i.primaryFilerSaversGrossDistributions
  let distS := if isMfj
    then roundDollar (i.primaryFilerSaversGrossDistributions + i.secondaryFilerSaversGrossDistributions)
    else roundDollar i.secondaryFilerSaversGrossDistributions
  let pc := saversColumn { line1 := iraP, line2 := defP, line4 := distP }
  let sc := saversColumn { line1 := iraS, line2 := defS, line4 := distS }
  let combined := pc.line6 + sc.line6
  let ratioed := roundDollar (mulRate combined multiplierRat)
  let limitation := positive (i.totalTentativeTax - (i.cdccTotalCredit + i.totalEdc))
  let qualifiedWo := eligible && decide (combined > 0)
  let qualified := qualifiedWo && decide (limitation > 0)
  let amount := if qualified then Money.min ratioed limitation else 0
  let ko := qualified &&
    (i.hasDistributionsInLastThreeYears || i.hasCurrentYearDistributions ||
      i.hasSelfReportedContributions)
  { isFilingStatusMfj := isMfj, isFilingStatusHoh := isHoh
    primaryFilerIsEligible := primaryEligible, secondaryFilerIsEligible := secondaryEligible
    secondaryFilerIsApplicableAndEligible := secondaryApplicableAndEligible
    saversCreditMaxAgiLimit := maxLimit
    saversCreditAgiLimitForFiftyPercent := limit50
    saversCreditAgiLimitForTwentyPercent := limit20
    isAgiEligibleForSaversCredit := agiEligible, eligibleForSaversCredit := eligible
    primaryFilerIraAndAbleContributions := iraP, secondaryFilerIraAndAbleContributions := iraS
    primaryFilersDeferralsAndContributions := defP
    secondaryFilersDeferralsAndContributions := defS
    primaryFilerGrossDistributions := distP, secondaryFilerGrossDistributions := distS
    primaryColumn := pc, secondaryColumn := sc
    primaryFilerTotalContributions := pc.line3, secondaryFilerTotalContributions := sc.line3
    primaryFilerTotalContributionsLessDistributions := pc.line5
    secondaryFilerTotalContributionsLessDistributions := sc.line5
    primaryFilerMaxCreditCalc := pc.line6, secondaryFilerMaxCreditCalc := sc.line6
    combinedCreditLimit := combined
    saversCreditMultiplier := multiplier, saversCreditMultiplierAsRational := multiplierRat
    ratioedCombinedCreditLimit := ratioed, limitationBasedOnTaxLiability := limitation
    qualifiedForSaverCreditWoTaxLiability := qualifiedWo, qualifiedForSaverCredit := qualified
    qualifiedSaverCreditAmount := amount
    isReceivingSaversCredit := decide (amount > 0)
    koSaversCreditKnockouts := ko, unsupported := ko }

/-! ### Unit tests: every assertion of `catala/tests/test_savers_credit.catala_en`

`base` is the Catala helper `Case` with its defaults: a single adult filer who is not a
student and is not claimed, AGI `$20,000`, no distributions, tax `$10,000`, no CDCC or
Schedule R credit. -/

/-- The defaults of the Catala test helper `Case`. -/
def base : SaversCreditIn :=
  { filingStatus := .single, agi := 2_000_000
    isMfjDependent := false
    primaryFilerIsUnder18 := false, primaryFilerIsStudent := false
    primaryFilerIsClaimedAsDependent := false
    secondaryFilerIsUnder18 := false, secondaryFilerIsStudent := false
    secondaryFilerIsClaimedAsDependent := false
    primaryFilerTotalDeferralsAndContributions := 0
    secondaryFilerTotalDeferralsAndContributions := 0
    primaryFilerSaversGrossDistributions := 0, secondaryFilerSaversGrossDistributions := 0
    totalTentativeTax := 1_000_000, cdccTotalCredit := 0, totalEdc := 0
    hasDistributionsInLastThreeYears := false, hasCurrentYearDistributions := false
    hasSelfReportedContributions := false }

private def run (f : SaversCreditIn → SaversCreditIn) : SaversCreditOut := saversCredit (f base)

-- TestSingle23000
private def t1 := run fun c => { c with agi := 2_300_000, primaryFilerTotalDeferralsAndContributions := 200_000 }
#guard t1.qualifiedSaverCreditAmount == 100_000
#guard t1.combinedCreditLimit == 200_000
#guard t1.saversCreditMultiplierAsRational == 1 / 2
#guard t1.ratioedCombinedCreditLimit == 100_000
#guard t1.qualifiedForSaverCredit
#guard !t1.unsupported
#guard t1.qualifiedSaverCreditAmount != 40_000 && t1.qualifiedSaverCreditAmount != 200_000
-- TestSingle23001
private def t2 := run fun c => { c with agi := 2_300_100, primaryFilerTotalDeferralsAndContributions := 200_000 }
#guard t2.qualifiedSaverCreditAmount == 40_000
#guard t2.saversCreditMultiplierAsRational == 1 / 5
#guard t2.qualifiedSaverCreditAmount != 100_000
-- TestSingle25001
private def t3 := run fun c => { c with agi := 2_500_100, primaryFilerTotalDeferralsAndContributions := 200_000 }
#guard t3.qualifiedSaverCreditAmount == 20_000
#guard t3.saversCreditMultiplierAsRational == 1 / 10
-- TestSingle38250
private def t4 := run fun c => { c with agi := 3_825_000, primaryFilerTotalDeferralsAndContributions := 200_000 }
#guard t4.qualifiedSaverCreditAmount == 20_000
#guard t4.saversCreditMultiplierAsRational == 1 / 10
-- TestSingle38251
private def t5 := run fun c => { c with agi := 3_825_100, primaryFilerTotalDeferralsAndContributions := 200_000 }
#guard t5.qualifiedSaverCreditAmount == 0
#guard t5.saversCreditMultiplierAsRational == 0
#guard !t5.qualifiedForSaverCredit
#guard t5.qualifiedSaverCreditAmount != 20_000
-- TestMfs
private def t6 := run fun c => { c with
      filingStatus := .marriedFilingSeparately, agi := 2_400_000,
      primaryFilerTotalDeferralsAndContributions := 150_000 }
#guard t6.saversCreditMultiplierAsRational == 1 / 5
#guard t6.qualifiedSaverCreditAmount == 30_000
-- TestHohBands
private def t7 := run fun c => { c with
      filingStatus := .headOfHousehold, agi := 3_700_000,
      primaryFilerTotalDeferralsAndContributions := 100_000 }
#guard t7.saversCreditMultiplierAsRational == 1 / 5
#guard t7.qualifiedSaverCreditAmount == 20_000
-- TestHoh57376
private def t8 := run fun c => { c with
      filingStatus := .headOfHousehold, agi := 5_737_600,
      primaryFilerTotalDeferralsAndContributions := 200_000 }
#guard t8.qualifiedSaverCreditAmount == 0
-- TestMfjTwoFilers46000
private def t9 := run fun c => { c with
      filingStatus := .marriedFilingJointly, agi := 4_600_000,
      primaryFilerTotalDeferralsAndContributions := 200_000,
      secondaryFilerTotalDeferralsAndContributions := 200_000 }
#guard t9.combinedCreditLimit == 400_000
#guard t9.saversCreditMultiplierAsRational == 1 / 2
#guard t9.ratioedCombinedCreditLimit == 200_000
#guard t9.qualifiedSaverCreditAmount == 200_000
#guard t9.qualifiedSaverCreditAmount != 100_000
-- TestMfj50000
private def t10 := run fun c => { c with
      filingStatus := .marriedFilingJointly, agi := 5_000_000,
      primaryFilerTotalDeferralsAndContributions := 250_000,
      secondaryFilerTotalDeferralsAndContributions := 100_000 }
#guard t10.combinedCreditLimit == 300_000
#guard t10.qualifiedSaverCreditAmount == 60_000
-- TestMfj76501
private def t11 := run fun c => { c with
      filingStatus := .marriedFilingJointly, agi := 7_650_100,
      primaryFilerTotalDeferralsAndContributions := 200_000,
      secondaryFilerTotalDeferralsAndContributions := 200_000 }
#guard t11.qualifiedSaverCreditAmount == 0
-- TestDeferralsCapped
private def t12 := run fun c => { c with primaryFilerTotalDeferralsAndContributions := 500_000 }
#guard t12.combinedCreditLimit == 200_000
#guard t12.qualifiedSaverCreditAmount == 100_000
-- TestDistributionsReduce
private def t13 := run fun c => { c with
      primaryFilerTotalDeferralsAndContributions := 200_000,
      primaryFilerSaversGrossDistributions := 150_000 }
#guard t13.combinedCreditLimit == 50_000
#guard t13.qualifiedSaverCreditAmount == 25_000
#guard t13.qualifiedSaverCreditAmount != 100_000
-- TestDistributionsExceed
private def t14 := run fun c => { c with
      primaryFilerTotalDeferralsAndContributions := 200_000,
      primaryFilerSaversGrossDistributions := 300_000 }
#guard t14.combinedCreditLimit == 0
#guard t14.qualifiedSaverCreditAmount == 0
#guard !t14.qualifiedForSaverCredit
-- TestMfjDistributionsBothColumns
private def t15 := run fun c => { c with
      filingStatus := .marriedFilingJointly, agi := 4_000_000,
      primaryFilerTotalDeferralsAndContributions := 200_000,
      secondaryFilerTotalDeferralsAndContributions := 100_000,
      secondaryFilerSaversGrossDistributions := 50_000 }
#guard t15.combinedCreditLimit == 200_000
#guard t15.qualifiedSaverCreditAmount == 100_000
-- TestMfjIneligibleSpouseDistributions (DF-BUG(14))
private def t16 := run fun c => { c with
      filingStatus := .marriedFilingJointly, agi := 4_000_000,
      primaryFilerTotalDeferralsAndContributions := 200_000, secondaryFilerIsStudent := true,
      secondaryFilerSaversGrossDistributions := 150_000 }
#guard t16.combinedCreditLimit == 50_000
#guard t16.qualifiedSaverCreditAmount == 25_000
#guard t16.qualifiedSaverCreditAmount != 100_000
-- TestUnder18
private def t17 := run fun c => { c with
      primaryFilerIsUnder18 := true,
      primaryFilerTotalDeferralsAndContributions := 200_000 }
#guard t17.qualifiedSaverCreditAmount == 0
#guard t17.combinedCreditLimit == 0
#guard !t17.qualifiedForSaverCredit
-- TestStudent
#guard (run fun c => { c with
      primaryFilerIsStudent := true,
      primaryFilerTotalDeferralsAndContributions := 200_000 }).qualifiedSaverCreditAmount == 0
-- TestClaimedAsDependent
#guard (run fun c => { c with
      primaryFilerIsClaimedAsDependent := true,
      primaryFilerTotalDeferralsAndContributions := 200_000 }).qualifiedSaverCreditAmount == 0
-- TestMfjOneSpouseStudent
private def t18 := run fun c => { c with
      filingStatus := .marriedFilingJointly, agi := 3_000_000,
      primaryFilerTotalDeferralsAndContributions := 200_000,
      secondaryFilerTotalDeferralsAndContributions := 200_000, secondaryFilerIsStudent := true }
#guard t18.combinedCreditLimit == 200_000
#guard t18.qualifiedSaverCreditAmount == 100_000
-- TestMfjDependent
#guard (run fun c => { c with
      filingStatus := .marriedFilingJointly, isMfjDependent := true,
      primaryFilerTotalDeferralsAndContributions := 200_000 }).qualifiedSaverCreditAmount == 0
-- TestLimitedByTax
private def t19 := run fun c => { c with
      primaryFilerTotalDeferralsAndContributions := 200_000,
      totalTentativeTax := 100_000, cdccTotalCredit := 30_000, totalEdc := 20_000 }
#guard t19.ratioedCombinedCreditLimit == 100_000
#guard t19.limitationBasedOnTaxLiability == 50_000
#guard t19.qualifiedSaverCreditAmount == 50_000
#guard t19.qualifiedSaverCreditAmount != 100_000
-- TestNoTaxLeft
private def t20 := run fun c => { c with
      primaryFilerTotalDeferralsAndContributions := 200_000,
      totalTentativeTax := 40_000, cdccTotalCredit := 40_000 }
#guard t20.limitationBasedOnTaxLiability == 0
#guard t20.qualifiedSaverCreditAmount == 0
#guard !t20.qualifiedForSaverCredit
#guard t20.ratioedCombinedCreditLimit == 100_000
-- TestRoundHalf
#guard (run fun c => { c with
      agi := 3_000_000,
      primaryFilerTotalDeferralsAndContributions := 500 }).ratioedCombinedCreditLimit == 100
-- TestKnockout
#guard (run fun c => { c with
      primaryFilerTotalDeferralsAndContributions := 200_000,
      hasDistributionsInLastThreeYears := true }).unsupported
-- TestNoKnockoutWithoutCredit
#guard !(run fun c => { c with
      agi := 9_000_000, primaryFilerTotalDeferralsAndContributions := 200_000,
      hasCurrentYearDistributions := true }).unsupported

end UsTax.SaversCredit
