import UsTax.Params2024

/-!
# Tax year 2024 parameters of the EITC and CTC/ODC modules

The `Params_2024` figures `catala/eitc.catala_en` and `catala/ctc_odc.catala_en` read
(`catala/params_2024.catala_en`, sections "Child tax credit and credit for other
dependents (IRC 24)" and "Earned income credit (IRC 32)"), copied one for one with the
Catala names in lower camel case. Kept in this file, not in `Params2024.lean`, so that
parallel modules do not edit the same file. Amounts are cents (`TaxRates.usd`); rates are
exact `Rat`s.
-/

namespace UsTax.Params

open TaxRates (usd)

/-- A percentage as an exact decimal: `decPct 765 100` is 7.65%, that is `765/10000`. -/
def decPct (num den : Int) : Rat := (num : Rat) / (den : Rat) / 100

/-! ### Child tax credit, credit for other dependents (IRC 24) -/

/-- IRC 24(h)(2): $2,000. -/
def ctcPerQualifyingChild : Int := usd 2_000
/-- IRC 24(h)(4)(A): $500. -/
def odcPerOtherDependent : Int := usd 500
/-- IRC 24(h)(3): $400,000. -/
def ctcPhaseoutThresholdJoint : Int := usd 400_000
/-- IRC 24(h)(3): $200,000. -/
def ctcPhaseoutThresholdOther : Int := usd 200_000
/-- IRC 24(b)(1): $50 per step. -/
def ctcPhaseoutReductionPerStep : Int := usd 50
/-- IRC 24(b)(1): the step, $1,000. -/
def ctcPhaseoutStep : Int := usd 1_000
/-- Rev. Proc. 2023-34 § 3.05: refundable part per qualifying child, $1,700. -/
def actcPerQualifyingChildCap : Int := usd 1_700
/-- IRC 24(h)(6): $2,500. -/
def actcEarnedIncomeFloor : Int := usd 2_500
/-- IRC 24(d)(1)(B)(i): 15%. -/
def actcEarnedIncomeRate : Rat := decPct 15 1

/-! ### Earned income credit (IRC 32) -/

/-- Rev. Proc. 2023-34 § 3.06(2): investment income limit, $11,600. -/
def eitcInvestmentIncomeLimit : Int := usd 11_600
/-- IRC 32(b)(1): credit percentage, no children, 7.65%. -/
def eitcCreditPercentage0Children : Rat := decPct 765 100
/-- IRC 32(b)(1): 34%. -/
def eitcCreditPercentage1Child : Rat := decPct 34 1
/-- IRC 32(b)(1): 40%. -/
def eitcCreditPercentage2Children : Rat := decPct 40 1
/-- IRC 32(b)(1): 45%. -/
def eitcCreditPercentage3OrMoreChildren : Rat := decPct 45 1
/-- IRC 32(b)(1): phase-out percentage, no children, 7.65%. -/
def eitcPhaseoutPercentage0Children : Rat := decPct 765 100
/-- IRC 32(b)(1): 15.98%. -/
def eitcPhaseoutPercentage1Child : Rat := decPct 1598 100
/-- IRC 32(b)(1): 21.06%. -/
def eitcPhaseoutPercentage2OrMoreChildren : Rat := decPct 2106 100
/-- Rev. Proc. 2023-34 § 3.06(1): earned income amount, no children, $8,260. -/
def eitcEarnedIncomeAmount0Children : Int := usd 8_260
/-- Earned income amount, one child, $12,390. -/
def eitcEarnedIncomeAmount1Child : Int := usd 12_390
/-- Earned income amount, two or more children, $17,400. -/
def eitcEarnedIncomeAmount2OrMoreChildren : Int := usd 17_400
/-- Maximum credit, no children, $632. -/
def eitcMaxCredit0Children : Int := usd 632
/-- Maximum credit, one child, $4,213. -/
def eitcMaxCredit1Child : Int := usd 4_213
/-- Maximum credit, two children, $6,960. -/
def eitcMaxCredit2Children : Int := usd 6_960
/-- Maximum credit, three or more children, $7,830. -/
def eitcMaxCredit3OrMoreChildren : Int := usd 7_830
/-- Threshold phase-out amount, other statuses, no children, $10,330. -/
def eitcPhaseoutThresholdOther0Children : Int := usd 10_330
/-- Threshold phase-out amount, other statuses, one or more children, $22,720. -/
def eitcPhaseoutThresholdOther1OrMoreChildren : Int := usd 22_720
/-- Threshold phase-out amount, joint, no children, $17,250. -/
def eitcPhaseoutThresholdJoint0Children : Int := usd 17_250
/-- Threshold phase-out amount, joint, one or more children, $29,640. -/
def eitcPhaseoutThresholdJoint1OrMoreChildren : Int := usd 29_640
/-- Completed phase-out amount, other statuses, no children, $18,591. -/
def eitcCompletedPhaseoutOther0Children : Int := usd 18_591
/-- Completed phase-out amount, other statuses, one child, $49,084. -/
def eitcCompletedPhaseoutOther1Child : Int := usd 49_084
/-- Completed phase-out amount, other statuses, two children, $55,768. -/
def eitcCompletedPhaseoutOther2Children : Int := usd 55_768
/-- Completed phase-out amount, other statuses, three or more children, $59,899. -/
def eitcCompletedPhaseoutOther3OrMoreChildren : Int := usd 59_899
/-- Completed phase-out amount, joint, no children, $25,511. -/
def eitcCompletedPhaseoutJoint0Children : Int := usd 25_511
/-- Completed phase-out amount, joint, one child, $56,004. -/
def eitcCompletedPhaseoutJoint1Child : Int := usd 56_004
/-- Completed phase-out amount, joint, two children, $62,688. -/
def eitcCompletedPhaseoutJoint2Children : Int := usd 62_688
/-- Completed phase-out amount, joint, three or more children, $66,819. -/
def eitcCompletedPhaseoutJoint3OrMoreChildren : Int := usd 66_819
/-- The EIC Table row width, the `50` of the 50/50 rate. -/
def eitcTableRowWidth : Int := 50
/-- Middle of a row, $25. -/
def eitcTableRowMidpoint : Int := usd 25
/-- Last whole dollar of a row relative to its middle, $24. -/
def eitcTableRowLastDollarOffset : Int := usd 24

#guard eitcCreditPercentage0Children == 765 / 10000
#guard eitcPhaseoutPercentage1Child == 1598 / 10000
#guard actcEarnedIncomeRate == 15 / 100

end UsTax.Params
