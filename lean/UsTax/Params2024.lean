import UsTax.TaxRates

/-!
# Tax year 2024 parameters (Catala module `Params_2024`, `catala/params_2024.catala_en`)

The figures the spine modules (standard deduction, W-2, interest) use, copied
one for one with the Catala names in lower camel case. The citations are in
the Catala file; the later modules add their own figures here. Amounts are
cents (`TaxRates.usd`).
-/

namespace UsTax.Params

open TaxRates (usd)

/-- Rev. Proc. 2023-34 § 3.15(1): joint returns and surviving spouses. -/
def stdDeductionJointOrSurvivingSpouse : Int := usd 29_200
/-- Rev. Proc. 2023-34 § 3.15(1): heads of households. -/
def stdDeductionHeadOfHousehold : Int := usd 21_900
/-- Rev. Proc. 2023-34 § 3.15(1): unmarried individuals. -/
def stdDeductionUnmarried : Int := usd 14_600
/-- Rev. Proc. 2023-34 § 3.15(1): married individuals filing separately. -/
def stdDeductionMarriedSeparate : Int := usd 14_600
/-- Rev. Proc. 2023-34 § 3.15(2): the dependent's floor, $1,300. -/
def stdDeductionDependentFloor : Int := usd 1_300
/-- Rev. Proc. 2023-34 § 3.15(2): added to earned income, $450. -/
def stdDeductionDependentEarnedIncomeAddition : Int := usd 450
/-- Rev. Proc. 2023-34 § 3.15(3): additional amount, married, $1,550. -/
def stdDeductionAdditionalMarried : Int := 155_000
/-- Rev. Proc. 2023-34 § 3.15(3): additional amount, unmarried, $1,950. -/
def stdDeductionAdditionalUnmarried : Int := 195_000

/-- Form 8959 line 5, joint: $250,000. -/
def additionalMedicareTaxThresholdJoint : Int := usd 250_000
/-- Form 8959 line 5, married filing separately: $125,000. -/
def additionalMedicareTaxThresholdMarriedSeparate : Int := usd 125_000
/-- Form 8959 line 5, other: $200,000. -/
def additionalMedicareTaxThresholdOther : Int := usd 200_000
/-- Per-spouse Medicare wage limit of a joint return: $200,000. -/
def medicareWagesIndividualLimit : Int := usd 200_000
/-- Pub. 15 (2024): social security wage base, $168,600. -/
def oasdiWageBase : Int := usd 168_600
/-- Schedule B line 4 threshold, $1,500. -/
def scheduleBInterestThreshold : Int := usd 1_500
/-- IRC 1411(b): joint or surviving spouse, $250,000. -/
def niitThresholdJointOrSurvivingSpouse : Int := usd 250_000
/-- IRC 1411(b): married filing separately, $125,000. -/
def niitThresholdMarriedSeparate : Int := usd 125_000
/-- IRC 1411(b): any other case, $200,000. -/
def niitThresholdOther : Int := usd 200_000

/-- IRC 1341(a)(3): repayments over $3,000 (1099-G and SSA-1099 knockouts). -/
def claimOfRightThreshold : Int := usd 3_000
/-- Rev. Proc. 2023-34 § 3.13, IRC 62(a)(2)(D): educator expense cap, $300. -/
def educatorExpenseCapPerEducator : Int := usd 300
/-- IRC 221(b)(1): student loan interest cap, $2,500. -/
def studentLoanInterestCap : Int := usd 2_500
/-- Rev. Proc. 2023-34 § 3.30: phase-out start, other than joint, $80,000. -/
def studentLoanPhaseoutStartOther : Int := usd 80_000
/-- Rev. Proc. 2023-34 § 3.30: phase-out start, joint, $165,000. -/
def studentLoanPhaseoutStartJoint : Int := usd 165_000
/-- Rev. Proc. 2023-34 § 3.30: phase-out end, other than joint, $95,000. -/
def studentLoanPhaseoutEndOther : Int := usd 95_000
/-- Rev. Proc. 2023-34 § 3.30: phase-out end, joint, $195,000. -/
def studentLoanPhaseoutEndJoint : Int := usd 195_000
/-- IRC 86(c)(1): base amount, other than joint, $25,000. -/
def ssBaseAmountOther : Int := usd 25_000
/-- IRC 86(c)(1)(B): base amount, joint, $32,000. -/
def ssBaseAmountJoint : Int := usd 32_000
/-- IRC 86(c)(2) less (c)(1): gap to the adjusted base amount, other, $9,000. -/
def ssAdjustedBaseGapOther : Int := usd 9_000
/-- IRC 86(c)(2) less (c)(1): gap to the adjusted base amount, joint, $12,000. -/
def ssAdjustedBaseGapJoint : Int := usd 12_000

end UsTax.Params
