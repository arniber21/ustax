import UsTax.Money
import UsTax.Types
import UsTax.FormW2s
import UsTax.Params2024.EitcCtc

/-!
# Earned income credit, Form 1040 line 27 (issue #46)

Lean implementation of `catala/eitc.catala_en` (module `Eitc`: scopes `EitcTable` and
`EarnedIncomeCredit`), written by hand from the Catala source under strategy (c) of
`docs/catala-to-lean.md`, in the order of the Catala file; the code that runs. Law:
26 U.S.C. § 32, Rev. Proc. 2023-34 § 3.06, Pub. 596, Form 1040 instructions "Earned Income
Credit (EIC)".

| Catala (`Eitc`)                          | Lean (`UsTax.Eitc`)                              |
|------------------------------------------|--------------------------------------------------|
| `dollars`                                | `dollars`                                        |
| `phaseout_reduction`                     | `phaseoutReduction`                              |
| `scope EitcTable`                        | `EitcTableIn` → `EitcTableOut` (`eitcTable`)      |
| enumeration `ImproperClaimsNotice`       | `ImproperClaimsNotice`                           |
| `scope EarnedIncomeCredit`               | `EarnedIncomeCreditIn` → `EarnedIncomeCreditOut` (`earnedIncomeCredit`) |

Money is `Int` cents, decimals are `Rat`. Every `R.round_dollar` is `Money.roundDollar`,
the one `round of` of the table is `Money.roundRat`, every stdlib call is its `Money` port,
so the rounding points are Catala's: all intermediate figures are exact decimals and the
credit is rounded once, to the dollar, half away from zero. `R.stepwise_multiply of x, 50,
50 + $25` is read as Catala parses it, `(R.stepwise_multiply of x, 50, 50) + $25`: the
middle of the $50 row (the golden test against the printed table confirms it).

Lean follows Catala where Catala departs from Direct File: DF-BUG(17) (`no_credit`: no
credit without earned income or at/after the completed phase-out), and the exact decimal
evaluation (no per-product `HALF_EVEN` rounding).

`qualifyingChildren` is an `Int` as in Catala. A negative count is not a real return; as in
Catala it takes the "3 or more" column (the `else` branch). The bounds theorem
(`UsTax/Proofs/Eitc.lean`) assumes a nonnegative count.
-/

namespace UsTax.Eitc

open UsTax.Money

/-- Catala `dollars of amount`: `amount / $1`, an exact decimal. -/
def dollars (amount : Int) : Rat := divMoney amount 100

/-- Catala `phaseout_reduction`: the part of the credit taken back by the phase-out for the
row middle `roundedIncome`. No reduction below `threshold + $25`; the income is capped at the
middle of the last row, `(bottom of the row of the completed phase-out amount + completed
phase-out amount) / 2`. -/
def phaseoutReduction (roundedIncome threshold completed : Int) (percentage : Rat) : Rat :=
  let lastRowBottom := stepwiseMultiply completed Params.eitcTableRowWidth Params.eitcTableRowWidth
  let cap := (dollars lastRowBottom + dollars completed) / 2
  let income := dollars roundedIncome
  if threshold + Params.eitcTableRowMidpoint > roundedIncome then 0
  else percentage * ((if income < cap then income else cap) - dollars threshold)

/-! ### Scope `EitcTable` -/

/-- Inputs of `EitcTable`. -/
structure EitcTableIn where
  /-- Catala input `earned_income`. -/
  earnedIncome : Int
  /-- Catala input `agi`. -/
  agi : Int
  /-- Catala input `is_mfj`. -/
  isMfj : Bool
  /-- Catala input `qualifying_children`. -/
  qualifyingChildren : Int

/-- Outputs (and internals) of `EitcTable`. -/
structure EitcTableOut where
  phaseInRate : Rat
  phaseoutRate : Rat
  maxCredit : Int
  phaseoutThreshold : Int
  completedPhaseout : Int
  roundedEarnedIncome : Int
  roundedAgi : Int
  rowReachesMaxCredit : Bool
  phasedInCredit : Rat
  maxEitcFromAgi : Rat
  creditFromEarnedIncome : Rat
  noCredit : Bool
  amount : Int

/-- Catala `scope EitcTable`, definition by definition. -/
def eitcTable (i : EitcTableIn) : EitcTableOut :=
  let n := i.qualifyingChildren
  let phaseInRate :=
    if n = 0 then Params.eitcCreditPercentage0Children
    else if n = 1 then Params.eitcCreditPercentage1Child
    else if n = 2 then Params.eitcCreditPercentage2Children
    else Params.eitcCreditPercentage3OrMoreChildren
  let phaseoutRate :=
    if n = 0 then Params.eitcPhaseoutPercentage0Children
    else if n = 1 then Params.eitcPhaseoutPercentage1Child
    else Params.eitcPhaseoutPercentage2OrMoreChildren
  let maxCredit :=
    if n = 0 then Params.eitcMaxCredit0Children
    else if n = 1 then Params.eitcMaxCredit1Child
    else if n = 2 then Params.eitcMaxCredit2Children
    else Params.eitcMaxCredit3OrMoreChildren
  let phaseoutThreshold :=
    if i.isMfj
    then (if n = 0 then Params.eitcPhaseoutThresholdJoint0Children
          else Params.eitcPhaseoutThresholdJoint1OrMoreChildren)
    else (if n = 0 then Params.eitcPhaseoutThresholdOther0Children
          else Params.eitcPhaseoutThresholdOther1OrMoreChildren)
  let completedPhaseout :=
    if i.isMfj
    then (if n = 0 then Params.eitcCompletedPhaseoutJoint0Children
          else if n = 1 then Params.eitcCompletedPhaseoutJoint1Child
          else if n = 2 then Params.eitcCompletedPhaseoutJoint2Children
          else Params.eitcCompletedPhaseoutJoint3OrMoreChildren)
    else (if n = 0 then Params.eitcCompletedPhaseoutOther0Children
          else if n = 1 then Params.eitcCompletedPhaseoutOther1Child
          else if n = 2 then Params.eitcCompletedPhaseoutOther2Children
          else Params.eitcCompletedPhaseoutOther3OrMoreChildren)
  let roundedEarnedIncome :=
    stepwiseMultiply i.earnedIncome Params.eitcTableRowWidth Params.eitcTableRowWidth +
      Params.eitcTableRowMidpoint
  let roundedAgi :=
    stepwiseMultiply i.agi Params.eitcTableRowWidth Params.eitcTableRowWidth +
      Params.eitcTableRowMidpoint
  let rowReachesMaxCredit :=
    decide (phaseInRate * dollars (roundedEarnedIncome + Params.eitcTableRowLastDollarOffset) ≥
      dollars maxCredit)
  let phasedInCredit :=
    if rowReachesMaxCredit then dollars maxCredit
    else (if phaseInRate * dollars roundedEarnedIncome < dollars maxCredit
          then phaseInRate * dollars roundedEarnedIncome
          else dollars maxCredit)
  let maxEitcFromAgi :=
    dollars maxCredit - phaseoutReduction roundedAgi phaseoutThreshold completedPhaseout phaseoutRate
  let creditFromEarnedIncome :=
    phasedInCredit -
      phaseoutReduction roundedEarnedIncome phaseoutThreshold completedPhaseout phaseoutRate
  -- DF-BUG(17): no credit without earned income or at/after the completed phase-out.
  let noCredit :=
    decide (i.earnedIncome ≤ 0) || decide (i.earnedIncome ≥ completedPhaseout) ||
      decide (i.agi ≥ completedPhaseout)
  let amount :=
    if noCredit then 0
    else Money.max 0
      (100 * roundRat (if maxEitcFromAgi < creditFromEarnedIncome then maxEitcFromAgi
                       else creditFromEarnedIncome))
  { phaseInRate, phaseoutRate, maxCredit, phaseoutThreshold, completedPhaseout
    roundedEarnedIncome, roundedAgi, rowReachesMaxCredit, phasedInCredit, maxEitcFromAgi
    creditFromEarnedIncome, noCredit, amount }

/-! ### Scope `EarnedIncomeCredit` -/

/-- Catala `ImproperClaimsNotice`: DF `/improperClaimsNoticeOptions`; `notAnswered` stands for
the fact being incomplete. -/
inductive ImproperClaimsNotice where
  | twoYears
  | tenYears
  | zeroYears
  | notAnswered
  deriving DecidableEq, Repr, Inhabited

namespace ImproperClaimsNotice

/-- Parse a Catala case name. -/
def ofString? : String → Option ImproperClaimsNotice
  | "TwoYears" => some twoYears
  | "TenYears" => some tenYears
  | "ZeroYears" => some zeroYears
  | "NotAnswered" => some notAnswered
  | _ => none

end ImproperClaimsNotice

open FormW2s (CombatPayElection)

/-- Inputs of `EarnedIncomeCredit`, in the order of the Catala declaration. -/
structure EarnedIncomeCreditIn where
  filingStatus : FilingStatus
  employerIncomeSubtotal : Int
  agi : Int
  taxExemptInterest : Int
  interestIncome : Int
  ordinaryDividends : Int
  capitalGainsOrLosses : Int
  primaryFilerCombatPay : Int
  mfjSpouseCombatPay : Int
  allCombatPay : Int
  combatPayElectionMade : Bool
  combatPayElection : CombatPayElection
  numEitcQualifyingChildren : Int
  numEitcQualifyingChildrenForCalculation : Int
  isMarried : Bool
  treatAsMfs : Bool
  specialRuleForSeparatedSpouses : Bool
  treatFilersAsDependents : Bool
  isMfjDependent : Bool
  filersUsCitizenOrRaAllYear : Bool
  filersHaveValidSsnsForEitc : Bool
  primaryFilerAge25OrOlderForEitc : Bool
  primaryFilerAge64OrYoungerForEitc : Bool
  secondaryFilerAge25OrOlderForEitc : Bool
  secondaryFilerAge64OrYoungerForEitc : Bool
  eitcQcOfAnother : Bool
  eitcQcOfAnotherRequiredToFile : Bool
  eitcQcOfAnotherIsFiling : Bool
  eitcQcOfAnotherIsFilingRefundOnly : Bool
  eitcHadImproperClaims : Bool
  eitcImproperClaimsDueToQc : Bool
  eitcImproperClaimTakenSinceDisallowal : Bool
  eitcReceivedImproperClaimsNotice : ImproperClaimsNotice
  eitcImproperClaimsNoticeExpired : Bool

/-- Outputs of `EarnedIncomeCredit` (Catala `output` variables, plus the four sub-scope results). -/
structure EarnedIncomeCreditOut where
  withoutCombatPay : EitcTableOut
  withPrimaryCombatPay : EitcTableOut
  withSecondaryCombatPay : EitcTableOut
  withBothCombatPay : EitcTableOut
  hasEarnedIncome : Bool
  belowEitcEarnedIncomeLimit : Bool
  belowEitcAgiLimit : Bool
  belowEitcInvestmentIncomeLimit : Bool
  filersCouldQualifyForEitc : Bool
  filersAgeTestForEitcWithNoQc : Bool
  noEitcDueToSeparateFilingFromSpouse : Bool
  maybeEligibleForEitcBase : Bool
  maybeEligibleForEitcWithQc : Bool
  maybeEligibleForEitcWithoutQc : Bool
  maybeEligibleForEitc : Bool
  eitcQcTest : Bool
  failsEitcQcTest : Bool
  eitcNoticeTest : Bool
  eitcQualified : Bool
  eitcAmountWithoutCombatPay : Int
  eitcAmountWithPrimaryCombatPay : Int
  eitcAmountWithSecondaryCombatPay : Int
  eitcAmountWithBothTpCombatPay : Int
  combatPayRecommendation : CombatPayElection
  combatPayElectionAndOrRecommendation : CombatPayElection
  earnedIncomeCredit : Int
  isReceivingEitc : Bool
  eitc8862Required : Bool
  receivingEitcWhileSeparatedCheckbox : Bool
  koClaimedSpouseCombatPayWithoutMfj : Bool
  unsupported : Bool

/-- Catala `scope EarnedIncomeCredit`, definition by definition, in the order of the Catala file. -/
def earnedIncomeCredit (i : EarnedIncomeCreditIn) : EarnedIncomeCreditOut :=
  -- Earned income
  let isFilingStatusMfj := i.filingStatus == .marriedFilingJointly
  let earnedIncomePlusPrimaryCombatPay := i.primaryFilerCombatPay + i.employerIncomeSubtotal
  let earnedIncomePlusSpouseCombatPay := i.mfjSpouseCombatPay + i.employerIncomeSubtotal
  let earnedIncomePlusBothTpCombatPay :=
    i.primaryFilerCombatPay + i.mfjSpouseCombatPay + i.employerIncomeSubtotal
  let earnedIncomeWithAllCombatPay := roundDollar (i.employerIncomeSubtotal + i.allCombatPay)
  let hasEarnedIncome := decide (earnedIncomeWithAllCombatPay > 0)
  -- The four calculations
  let table (earnedIncome : Int) : EitcTableOut :=
    eitcTable { earnedIncome, agi := i.agi, isMfj := isFilingStatusMfj
                qualifyingChildren := i.numEitcQualifyingChildrenForCalculation }
  let withoutCombatPay := table i.employerIncomeSubtotal
  let withPrimaryCombatPay := table earnedIncomePlusPrimaryCombatPay
  let withSecondaryCombatPay := table earnedIncomePlusSpouseCombatPay
  let withBothCombatPay := table earnedIncomePlusBothTpCombatPay
  let eitcAmountWithoutCombatPay := withoutCombatPay.amount
  let eitcAmountWithPrimaryCombatPay := withPrimaryCombatPay.amount
  let eitcAmountWithSecondaryCombatPay := withSecondaryCombatPay.amount
  let eitcAmountWithBothTpCombatPay := withBothCombatPay.amount
  -- Income limits
  let completedPhaseoutAmount := withoutCombatPay.completedPhaseout
  let belowEitcEarnedIncomeLimit := decide (i.employerIncomeSubtotal < completedPhaseoutAmount)
  let belowEitcAgiLimit := decide (i.agi < completedPhaseoutAmount)
  let belowEitcInvestmentIncomeLimit :=
    decide (i.taxExemptInterest + i.interestIncome + i.ordinaryDividends +
      Money.max i.capitalGainsOrLosses 0 ≤ Params.eitcInvestmentIncomeLimit)
  -- The filers
  let hasZeroEitcQualifyingChildren := decide (i.numEitcQualifyingChildren = 0)
  let filersAgeTestForEitcWithNoQc :=
    if isFilingStatusMfj
    then (i.primaryFilerAge25OrOlderForEitc && i.primaryFilerAge64OrYoungerForEitc) ||
         (i.secondaryFilerAge25OrOlderForEitc && i.secondaryFilerAge64OrYoungerForEitc)
    else i.primaryFilerAge25OrOlderForEitc && i.primaryFilerAge64OrYoungerForEitc
  let filersCouldQualifyForEitc :=
    !i.isMfjDependent && i.filersUsCitizenOrRaAllYear && i.filersHaveValidSsnsForEitc &&
      (if i.treatAsMfs then i.specialRuleForSeparatedSpouses else true)
  let noEitcDueToSeparateFilingFromSpouse :=
    i.isMarried && !isFilingStatusMfj &&
      (!i.specialRuleForSeparatedSpouses || decide (i.numEitcQualifyingChildren = 0))
  -- May the filer be eligible
  let maybeEligibleForEitcBase :=
    hasEarnedIncome && belowEitcEarnedIncomeLimit && belowEitcAgiLimit &&
      belowEitcInvestmentIncomeLimit && filersCouldQualifyForEitc
  let maybeEligibleForEitcWithQc := decide (i.numEitcQualifyingChildren > 0)
  let maybeEligibleForEitcWithoutQc :=
    decide (i.numEitcQualifyingChildren = 0) && (isFilingStatusMfj || !i.isMarried) &&
      !i.treatFilersAsDependents && filersAgeTestForEitcWithNoQc
  let maybeEligibleForEitc :=
    maybeEligibleForEitcBase && !noEitcDueToSeparateFilingFromSpouse &&
      (maybeEligibleForEitcWithQc || maybeEligibleForEitcWithoutQc)
  -- Qualifying child of another
  let eitcQcTest :=
    !i.eitcQcOfAnother ||
      (i.eitcQcOfAnother && !i.eitcQcOfAnotherRequiredToFile &&
        (!i.eitcQcOfAnotherIsFiling || (i.eitcQcOfAnotherIsFiling && i.eitcQcOfAnotherIsFilingRefundOnly)))
  let failsEitcQcTest := !eitcQcTest
  -- Improper claims
  let hasImproperClaimsAndNoQc := i.eitcHadImproperClaims && hasZeroEitcQualifyingChildren
  let flowHasImproperClaimsAndAskAboutLastClaimedCredit :=
    (hasImproperClaimsAndNoQc && !i.eitcImproperClaimsDueToQc) ||
      (i.eitcHadImproperClaims && maybeEligibleForEitcWithQc)
  let eitcNoticeTest :=
    !i.eitcHadImproperClaims ||
      (hasImproperClaimsAndNoQc && i.eitcImproperClaimsDueToQc) ||
      (flowHasImproperClaimsAndAskAboutLastClaimedCredit && i.eitcImproperClaimTakenSinceDisallowal) ||
      (i.eitcHadImproperClaims && i.eitcReceivedImproperClaimsNotice == .zeroYears) ||
      (i.eitcHadImproperClaims && i.eitcImproperClaimsNoticeExpired)
  let eitcQualified := maybeEligibleForEitc && eitcQcTest && eitcNoticeTest
  -- The combat pay election and the recommendation
  let primaryFilerHasCombatPay := decide (i.primaryFilerCombatPay > 0)
  let mfjSpouseHasCombatPay := decide (i.mfjSpouseCombatPay > 0)
  let someFilerHasCombatPay := mfjSpouseHasCombatPay || primaryFilerHasCombatPay
  let bothFilersHasCombatPay := mfjSpouseHasCombatPay && primaryFilerHasCombatPay
  let onlyPrimaryFilerHasCombatPay := primaryFilerHasCombatPay && !mfjSpouseHasCombatPay
  let onlyMfjSpouseHasCombatPay := mfjSpouseHasCombatPay && !primaryFilerHasCombatPay
  let primaryBeatsWithout :=
    onlyPrimaryFilerHasCombatPay &&
      decide (eitcAmountWithPrimaryCombatPay ≥ eitcAmountWithoutCombatPay)
  let secondaryBeatsWithout :=
    onlyMfjSpouseHasCombatPay &&
      decide (eitcAmountWithSecondaryCombatPay ≥ eitcAmountWithoutCombatPay)
  let largestAmount :=
    Money.max (Money.max eitcAmountWithBothTpCombatPay eitcAmountWithPrimaryCombatPay)
      (Money.max eitcAmountWithSecondaryCombatPay eitcAmountWithoutCombatPay)
  let combatPayRecommendation : CombatPayElection :=
    if primaryBeatsWithout then .usePrimaryCombatPay
    else if secondaryBeatsWithout then .useSpouseCombatPay
    else if bothFilersHasCombatPay && largestAmount == eitcAmountWithBothTpCombatPay
    then .useBothCombatPay
    else if bothFilersHasCombatPay && largestAmount == eitcAmountWithPrimaryCombatPay
    then .usePrimaryNotSpouseCombatPay
    else if bothFilersHasCombatPay && largestAmount == eitcAmountWithSecondaryCombatPay
    then .useSpouseNotPrimaryCombatPay
    else .noCombatPay
  let combatPayElectionAndOrRecommendation :=
    if i.combatPayElectionMade then i.combatPayElection else combatPayRecommendation
  -- Line 27
  let e := combatPayElectionAndOrRecommendation
  let earnedIncomeCredit :=
    if !eitcQualified then 0
    else if someFilerHasCombatPay && (e == .usePrimaryCombatPay || e == .usePrimaryNotSpouseCombatPay)
    then eitcAmountWithPrimaryCombatPay
    else if someFilerHasCombatPay && (e == .useSpouseCombatPay || e == .useSpouseNotPrimaryCombatPay)
    then eitcAmountWithSecondaryCombatPay
    else if someFilerHasCombatPay && e == .useBothCombatPay
    then eitcAmountWithBothTpCombatPay
    else eitcAmountWithoutCombatPay
  let isReceivingEitc := decide (earnedIncomeCredit > 0)
  let receivingEitcWhileSeparatedCheckbox := i.isMarried && !isFilingStatusMfj && isReceivingEitc
  -- Form 8862
  let eitc8862Required :=
    flowHasImproperClaimsAndAskAboutLastClaimedCredit &&
      !i.eitcImproperClaimTakenSinceDisallowal &&
      (i.eitcReceivedImproperClaimsNotice == .zeroYears ||
        (i.eitcReceivedImproperClaimsNotice != .notAnswered && i.eitcImproperClaimsNoticeExpired)) &&
      isReceivingEitc
  -- Knockouts
  let koClaimedSpouseCombatPayWithoutMfj :=
    i.combatPayElectionMade && !isFilingStatusMfj &&
      (i.combatPayElection == .useSpouseCombatPay || i.combatPayElection == .useBothCombatPay)
  { withoutCombatPay, withPrimaryCombatPay, withSecondaryCombatPay, withBothCombatPay
    hasEarnedIncome, belowEitcEarnedIncomeLimit, belowEitcAgiLimit
    belowEitcInvestmentIncomeLimit, filersCouldQualifyForEitc, filersAgeTestForEitcWithNoQc
    noEitcDueToSeparateFilingFromSpouse, maybeEligibleForEitcBase, maybeEligibleForEitcWithQc
    maybeEligibleForEitcWithoutQc, maybeEligibleForEitc, eitcQcTest, failsEitcQcTest
    eitcNoticeTest, eitcQualified, eitcAmountWithoutCombatPay, eitcAmountWithPrimaryCombatPay
    eitcAmountWithSecondaryCombatPay, eitcAmountWithBothTpCombatPay, combatPayRecommendation
    combatPayElectionAndOrRecommendation, earnedIncomeCredit, isReceivingEitc
    eitc8862Required, receivingEitcWhileSeparatedCheckbox, koClaimedSpouseCombatPayWithoutMfj
    unsupported := koClaimedSpouseCombatPayWithoutMfj }

/-! ### Unit tests: every assertion of `catala/tests/test_eitc.catala_en`

`ret` is the Catala helper scope `Ret`: a single filer aged 40, a citizen with a valid SSN,
no children, no combat pay, wages and AGI $8,260. Amounts in cents (`d 8260` is $8,260). -/

private def d (dollars : Int) : Int := dollars * 100

/-- The Catala test helper `Ret`. -/
def ret : EarnedIncomeCreditIn :=
  { filingStatus := .single, employerIncomeSubtotal := d 8260, agi := d 8260,
    taxExemptInterest := 0, interestIncome := 0, ordinaryDividends := 0,
    capitalGainsOrLosses := 0, primaryFilerCombatPay := 0, mfjSpouseCombatPay := 0,
    allCombatPay := 0, combatPayElectionMade := false, combatPayElection := .noCombatPay,
    numEitcQualifyingChildren := 0, numEitcQualifyingChildrenForCalculation := 0,
    isMarried := false, treatAsMfs := false, specialRuleForSeparatedSpouses := false,
    treatFilersAsDependents := false, isMfjDependent := false,
    filersUsCitizenOrRaAllYear := true, filersHaveValidSsnsForEitc := true,
    primaryFilerAge25OrOlderForEitc := true, primaryFilerAge64OrYoungerForEitc := true,
    secondaryFilerAge25OrOlderForEitc := true, secondaryFilerAge64OrYoungerForEitc := true,
    eitcQcOfAnother := false, eitcQcOfAnotherRequiredToFile := false,
    eitcQcOfAnotherIsFiling := false, eitcQcOfAnotherIsFilingRefundOnly := false,
    eitcHadImproperClaims := false, eitcImproperClaimsDueToQc := false,
    eitcImproperClaimTakenSinceDisallowal := false,
    eitcReceivedImproperClaimsNotice := .notAnswered, eitcImproperClaimsNoticeExpired := false }

/-- Run `Ret` after the overrides `f`. As in the Catala helper, `all_combat_pay` is the sum
of the two combat pay figures and the children counted in the table default to the number of
qualifying children; `forCalc` overrides the latter. -/
private def r (f : EarnedIncomeCreditIn → EarnedIncomeCreditIn) (forCalc : Option Int := none) :
    EarnedIncomeCreditOut :=
  let i := f ret
  earnedIncomeCredit
    { i with allCombatPay := i.primaryFilerCombatPay + i.mfjSpouseCombatPay,
             numEitcQualifyingChildrenForCalculation := forCalc.getD i.numEitcQualifyingChildren }

private def income (x : Int) (a : Int := x) (k : Int := 0) (i : EarnedIncomeCreditIn := ret) :
    EarnedIncomeCreditIn :=
  { i with employerIncomeSubtotal := d x, agi := d a, numEitcQualifyingChildren := k }

private def jointOf (i : EarnedIncomeCreditIn) : EarnedIncomeCreditIn :=
  { i with filingStatus := .marriedFilingJointly, isMarried := true }

-- TestMaximumCreditIsRateTimesEarnedIncomeAmount
#guard 100 * roundRat (dollars Params.eitcEarnedIncomeAmount0Children *
  Params.eitcCreditPercentage0Children) = Params.eitcMaxCredit0Children
#guard 100 * roundRat (dollars Params.eitcEarnedIncomeAmount1Child *
  Params.eitcCreditPercentage1Child) = Params.eitcMaxCredit1Child
#guard 100 * roundRat (dollars Params.eitcEarnedIncomeAmount2OrMoreChildren *
  Params.eitcCreditPercentage2Children) = Params.eitcMaxCredit2Children
#guard 100 * roundRat (dollars Params.eitcEarnedIncomeAmount2OrMoreChildren *
  Params.eitcCreditPercentage3OrMoreChildren) = Params.eitcMaxCredit3OrMoreChildren

-- TestNoChildrenAtPhaseInEnd
private def t1 := r id
#guard t1.earnedIncomeCredit = d 632
#guard t1.eitcQualified
#guard t1.earnedIncomeCredit != d 631
#guard t1.earnedIncomeCredit ≤ Params.eitcMaxCredit0Children
-- TestOneChildAtPhaseInEnd
#guard (r fun _ => income 12390 (k := 1)).earnedIncomeCredit = d 4213
#guard (r fun _ => income 12390 (k := 1)).earnedIncomeCredit != d 4208
-- TestOneChildJustBelowPhaseInRow
#guard (r fun _ => income 12349 (k := 1)).earnedIncomeCredit = d 4191
-- TestTwoChildrenAtPhaseInEnd
#guard (r fun _ => income 17400 (k := 2)).earnedIncomeCredit = d 6960
-- TestThreeChildrenAtPhaseInEnd
#guard (r fun _ => income 17400 (k := 3)).earnedIncomeCredit = d 7830
-- TestFourChildrenSameAsThree
#guard (r fun _ => income 17400 (k := 4)).earnedIncomeCredit = d 7830

-- TestCompletedPhaseoutSingle
#guard (r fun _ => income 18591).earnedIncomeCredit = 0
#guard (r fun _ => income 49084 (k := 1)).earnedIncomeCredit = 0
#guard (r fun _ => income 55768 (k := 2)).earnedIncomeCredit = 0
#guard (r fun _ => income 59899 (k := 3)).earnedIncomeCredit = 0
#guard !(r fun _ => income 18591).maybeEligibleForEitc
#guard !(r fun _ => income 59899 (k := 3)).maybeEligibleForEitc
#guard (r fun _ => income 18590).earnedIncomeCredit = d 2
#guard (r fun _ => income 49083 (k := 1)).earnedIncomeCredit = d 3
#guard (r fun _ => income 55767 (k := 2)).earnedIncomeCredit = d 2
#guard (r fun _ => income 59898 (k := 3)).earnedIncomeCredit = d 5
-- TestCompletedPhaseoutJoint
#guard (r fun _ => jointOf (income 25511)).earnedIncomeCredit = 0
#guard (r fun _ => jointOf (income 56004 (k := 1))).earnedIncomeCredit = 0
#guard (r fun _ => jointOf (income 62688 (k := 2))).earnedIncomeCredit = 0
#guard (r fun _ => jointOf (income 66819 (k := 3))).earnedIncomeCredit = 0
#guard (r fun _ => jointOf (income 25510)).earnedIncomeCredit = 0
#guard (r fun _ => jointOf (income 56003 (k := 1))).earnedIncomeCredit = 0
#guard (r fun _ => jointOf (income 62687 (k := 2))).earnedIncomeCredit = d 4
#guard (r fun _ => jointOf (income 66818 (k := 3))).earnedIncomeCredit = d 2

-- TestJointVersusSingleNoChildren
#guard (r fun _ => income 20000).earnedIncomeCredit = 0
#guard (r fun _ => jointOf (income 20000)).earnedIncomeCredit = d 420
-- TestJointVersusSingleOneChild
#guard (r fun _ => income 30000 (k := 1)).earnedIncomeCredit = d 3046
#guard (r fun _ => jointOf (income 30000 (k := 1))).earnedIncomeCredit = d 4151
#guard (r fun _ => jointOf (income 30000 (k := 1))).earnedIncomeCredit >
  (r fun _ => income 30000 (k := 1)).earnedIncomeCredit
-- TestAgiAboveEarnedIncome
#guard (r fun _ => income 12390 (a := 40000) (k := 1)).earnedIncomeCredit = d 1448
#guard (r fun _ => income 12390 (a := 40000) (k := 1)).earnedIncomeCredit != d 4213
-- TestLowEarnedIncomeHighAgi
#guard (r fun _ => income 5000 (a := 30000) (k := 1)).earnedIncomeCredit = d 1709

-- TestInvestmentIncomeAtLimit
private def inv1 := r fun _ =>
  { income 20000 (a := 31600) (k := 1) with interestIncome := d 11600 }
#guard inv1.belowEitcInvestmentIncomeLimit
#guard inv1.earnedIncomeCredit = d 2790
-- TestInvestmentIncomeOverLimit
private def inv2 := r fun _ =>
  { income 20000 (a := 31601) (k := 1) with interestIncome := d 11601 }
#guard !inv2.belowEitcInvestmentIncomeLimit
#guard !inv2.eitcQualified
#guard inv2.earnedIncomeCredit = 0
#guard inv2.earnedIncomeCredit != d 2790
-- TestInvestmentIncomeCountsEveryLine
private def invMix (agi gains : Int) := r fun _ =>
  { income 20000 (a := agi) (k := 1) with taxExemptInterest := d 5000, interestIncome := d 3000,
                                          ordinaryDividends := d 2000, capitalGainsOrLosses := d gains }
#guard !(invMix 26601 1601).belowEitcInvestmentIncomeLimit
#guard (invMix 26600 1600).belowEitcInvestmentIncomeLimit
private def invLoss1 := r fun _ =>
  { income 20000 (a := 28600) (k := 1) with interestIncome := d 11600, capitalGainsOrLosses := d (-3000) }
#guard invLoss1.belowEitcInvestmentIncomeLimit
#guard invLoss1.eitcQualified
#guard !(r fun _ =>
  { income 20000 (a := 28601) (k := 1) with interestIncome := d 11601, capitalGainsOrLosses := d (-3000) }).belowEitcInvestmentIncomeLimit

-- TestNoChildAge24
#guard !(r fun i => { i with primaryFilerAge25OrOlderForEitc := false }).maybeEligibleForEitc
#guard (r fun i => { i with primaryFilerAge25OrOlderForEitc := false }).earnedIncomeCredit = 0
#guard (r fun i => { i with primaryFilerAge25OrOlderForEitc := false }).earnedIncomeCredit != d 632
-- TestNoChildAge25AndAge65
#guard (r id).earnedIncomeCredit = d 632
#guard (r fun i => { i with primaryFilerAge64OrYoungerForEitc := false }).earnedIncomeCredit = 0
#guard (r fun _ => { income 12390 (k := 1) with primaryFilerAge25OrOlderForEitc := false }).earnedIncomeCredit
  = d 4213
-- TestJointNoChildOneSpouseInAgeRange
#guard (r fun i => { jointOf i with primaryFilerAge25OrOlderForEitc := false }).earnedIncomeCredit = d 632
-- TestNoChildDependent
#guard (r fun i => { i with treatFilersAsDependents := true }).earnedIncomeCredit = 0

-- TestFilerLevelRequirements
#guard (r fun i => { i with filersHaveValidSsnsForEitc := false }).earnedIncomeCredit = 0
#guard (r fun i => { i with filersUsCitizenOrRaAllYear := false }).earnedIncomeCredit = 0
#guard (r fun i => { jointOf i with isMfjDependent := true }).earnedIncomeCredit = 0
-- TestChildlessMarriedFilingSeparately
private def mfs (i : EarnedIncomeCreditIn) : EarnedIncomeCreditIn :=
  { i with filingStatus := .marriedFilingSeparately, isMarried := true, treatAsMfs := true }
#guard (r mfs).earnedIncomeCredit = 0
-- TestSeparatedSpouseRule
private def sepWithChild := r fun _ =>
  { mfs (income 12390 (k := 1)) with specialRuleForSeparatedSpouses := true }
#guard sepWithChild.earnedIncomeCredit = d 4213
#guard sepWithChild.receivingEitcWhileSeparatedCheckbox
#guard (r fun i => { mfs i with specialRuleForSeparatedSpouses := true }).earnedIncomeCredit = 0
#guard (r fun _ => mfs (income 12390 (k := 1))).earnedIncomeCredit = 0
-- TestChildWithoutValidSsn
private def noSsnChild := r (fun _ => { ret with numEitcQualifyingChildren := 1 }) (forCalc := some 0)
#guard noSsnChild.eitcQualified
#guard noSsnChild.earnedIncomeCredit = d 632
#guard noSsnChild.earnedIncomeCredit != d 4213

-- TestQualifyingChildOfAnother
#guard (r id).eitcQcTest
#guard (r id).earnedIncomeCredit = d 632
private def mustFile := r fun i => { i with eitcQcOfAnother := true, eitcQcOfAnotherRequiredToFile := true }
#guard !mustFile.eitcQcTest
#guard mustFile.earnedIncomeCredit = 0
private def notFiling := r fun i => { i with eitcQcOfAnother := true }
#guard notFiling.eitcQcTest
#guard notFiling.earnedIncomeCredit = d 632
#guard (r fun i => { i with eitcQcOfAnother := true, eitcQcOfAnotherIsFiling := true
                            eitcQcOfAnotherIsFilingRefundOnly := true }).earnedIncomeCredit = d 632
private def filesFully := r fun i => { i with eitcQcOfAnother := true, eitcQcOfAnotherIsFiling := true }
#guard !filesFully.eitcQcTest
#guard filesFully.earnedIncomeCredit = 0

-- TestImproperClaims
private def banned := r fun i =>
  { i with eitcHadImproperClaims := true, eitcReceivedImproperClaimsNotice := .twoYears }
#guard !banned.eitcNoticeTest
#guard banned.earnedIncomeCredit = 0
private def expired := r fun i =>
  { i with eitcHadImproperClaims := true, eitcReceivedImproperClaimsNotice := .twoYears,
           eitcImproperClaimsNoticeExpired := true }
#guard expired.earnedIncomeCredit = d 632
#guard expired.eitc8862Required
private def zeroYr := r fun i =>
  { i with eitcHadImproperClaims := true, eitcReceivedImproperClaimsNotice := .zeroYears }
#guard zeroYr.earnedIncomeCredit = d 632
#guard zeroYr.eitc8862Required
private def qcOnly := r fun i =>
  { i with eitcHadImproperClaims := true, eitcImproperClaimsDueToQc := true }
#guard qcOnly.earnedIncomeCredit = d 632
#guard !qcOnly.eitc8862Required
private def taken := r fun i =>
  { i with eitcHadImproperClaims := true, eitcImproperClaimTakenSinceDisallowal := true }
#guard taken.earnedIncomeCredit = d 632
#guard !taken.eitc8862Required
-- TestNoImproperClaimsNo8862
#guard (r id).earnedIncomeCredit = d 632
#guard !(r id).eitc8862Required

-- TestCombatPayRaisesCredit
private def cp1 (f : EarnedIncomeCreditIn → EarnedIncomeCreditIn) :=
  r fun _ => f { income 7000 with primaryFilerCombatPay := d 3000 }
#guard (cp1 id).eitcAmountWithoutCombatPay = d 537
#guard (cp1 id).eitcAmountWithPrimaryCombatPay = d 632
#guard (cp1 id).combatPayRecommendation == .usePrimaryCombatPay
#guard (cp1 id).earnedIncomeCredit = d 632
#guard (cp1 fun i => { i with combatPayElectionMade := true
                              combatPayElection := .usePrimaryCombatPay }).earnedIncomeCredit = d 632
#guard (cp1 fun i => { i with combatPayElectionMade := true
                              combatPayElection := .noCombatPay }).earnedIncomeCredit = d 537
-- TestCombatPayLowersCredit
private def cp2 (f : EarnedIncomeCreditIn → EarnedIncomeCreditIn) :=
  r fun _ => f { income 10000 with primaryFilerCombatPay := d 5000 }
#guard (cp2 id).eitcAmountWithoutCombatPay = d 632
#guard (cp2 id).eitcAmountWithPrimaryCombatPay = d 273
#guard (cp2 id).combatPayRecommendation == .noCombatPay
#guard (cp2 id).earnedIncomeCredit = d 632
private def forced := cp2 fun i =>
  { i with combatPayElectionMade := true, combatPayElection := .usePrimaryCombatPay }
#guard forced.earnedIncomeCredit = d 273
#guard forced.earnedIncomeCredit != d 632
-- TestCombatPayBothSpouses
private def cpBoth (f : EarnedIncomeCreditIn → EarnedIncomeCreditIn) :=
  r fun _ => f { jointOf (income 10000 (k := 1)) with primaryFilerCombatPay := d 1500,
                                                      mfjSpouseCombatPay := d 1500 }
#guard (r fun _ => jointOf (income 10000 (k := 1))).earnedIncomeCredit = d 3409
#guard (cpBoth id).eitcAmountWithoutCombatPay = d 3409
#guard (cpBoth id).eitcAmountWithPrimaryCombatPay = d 3919
#guard (cpBoth id).eitcAmountWithSecondaryCombatPay = d 3919
#guard (cpBoth id).eitcAmountWithBothTpCombatPay = d 4213
#guard (cpBoth id).combatPayRecommendation == .useBothCombatPay
#guard (cpBoth id).earnedIncomeCredit = d 4213
#guard (cpBoth fun i => { i with combatPayElectionMade := true
                                 combatPayElection := .usePrimaryNotSpouseCombatPay }).earnedIncomeCredit
  = d 3919
#guard (cpBoth fun i => { i with combatPayElectionMade := true
                                 combatPayElection := .useSpouseNotPrimaryCombatPay }).earnedIncomeCredit
  = d 3919
-- TestCombatPayOnlySpouse
private def onlySpouse := r fun _ =>
  { jointOf (income 10000 (k := 1)) with mfjSpouseCombatPay := d 2390 }
#guard onlySpouse.combatPayRecommendation == .useSpouseCombatPay
#guard onlySpouse.earnedIncomeCredit = d 4213
-- TestCombatPayAloneIsNotEarnedIncome (DF-BUG(17))
#guard (r fun _ => { income 0 with primaryFilerCombatPay := d 5000, combatPayElectionMade := true
                                   combatPayElection := .noCombatPay }).earnedIncomeCredit = 0
-- TestSpouseCombatPayWithoutJointReturn
private def spouseKo := r fun i =>
  { i with combatPayElectionMade := true, combatPayElection := .useSpouseCombatPay }
#guard spouseKo.koClaimedSpouseCombatPayWithoutMfj
#guard spouseKo.unsupported
-- TestNoKnockoutOnPlainReturn
#guard !(r id).unsupported

-- TestRoundHalfUp
#guard (r fun _ => income 5000 (k := 1)).earnedIncomeCredit = d 1709
#guard (r fun _ => income 5000 (k := 1)).earnedIncomeCredit != d 1708

-- TestTableRowMiddles
private def tbl (ei agi : Int) (mfj : Bool) (n : Int) : EitcTableOut :=
  eitcTable { earnedIncome := ei, agi, isMfj := mfj, qualifyingChildren := n }
#guard (tbl 1239999 1239999 false 1).roundedEarnedIncome = d 12375
#guard (tbl (d 12400) (d 12400) false 1).roundedEarnedIncome = d 12425
#guard (tbl 1239999 1239999 false 1).roundedAgi = d 12375
#guard (tbl 1239999 1239999 false 1).rowReachesMaxCredit
#guard (tbl 1239999 1239999 false 1).amount = d 4213
#guard (tbl (d 12400) (d 12400) false 1).amount = d 4213
-- TestTableNoCredit
#guard (tbl 0 0 false 0).noCredit
#guard (tbl 0 0 false 0).amount = 0
#guard (tbl (-10000) (-10000) false 0).amount = 0

end UsTax.Eitc
