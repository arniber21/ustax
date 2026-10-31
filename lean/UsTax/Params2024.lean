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

end UsTax.Params
