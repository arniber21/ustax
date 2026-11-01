import UsTax.TaxRates

/-!
# Tax year 2024 parameters of the CDCC, Saver's credit and Schedule R modules (issue #46)

The `Params_2024` figures (`catala/params_2024.catala_en`) that
`UsTax/Cdcc.lean`, `UsTax/SaversCredit.lean` and `UsTax/ElderlyAndDisabled.lean`
use, copied one for one with the Catala names in lower camel case. They live in
their own file (not `Params2024.lean`) so that the two parallel ports of issue
#46 cannot conflict; the namespace is the same, `UsTax.Params`. Amounts are
cents (`TaxRates.usd`), rates are `Rat`. The citations are in the Catala file.
-/

namespace UsTax.Params

open TaxRates (usd)

/-! ### Child and dependent care (IRC 21, IRC 129) -/

/-- IRC 21(c)(1): `$3,000` of expenses for one qualifying individual. -/
def cdccExpenseCapOnePerson : Int := usd 3_000
/-- IRC 21(c)(2): `$6,000` for two or more. -/
def cdccExpenseCapTwoOrMore : Int := usd 6_000
/-- IRC 129(a)(2)(A): the exclusion cap, `$5,000`. -/
def dependentCareExclusionCap : Int := usd 5_000
/-- IRC 129(a)(2)(A): `$2,500` for a separate return by a married individual. -/
def dependentCareExclusionCapMarriedSeparate : Int := usd 2_500
/-- IRC 21(a)(2): the top percentage, 35 percent. -/
def cdccMaximumPercentage : Rat := 35 / 100
/-- IRC 21(a)(2): the floor percentage, 20 percent. -/
def cdccMinimumPercentage : Rat := 20 / 100
/-- IRC 21(a)(2): AGI above this reduces the percentage, `$15,000`. -/
def cdccPercentageReductionThreshold : Int := usd 15_000
/-- IRC 21(a)(2): one step per `$2,000` (or fraction) of AGI over the threshold. -/
def cdccPercentageStepIncome : Int := usd 2_000
/-- IRC 21(a)(2): one percentage point per step. -/
def cdccPercentageStep : Rat := 1 / 100
/-- IRC 21(d)(2)(A): deemed monthly income, one qualifying individual, `$250`. -/
def cdccDeemedMonthlyIncomeOnePerson : Int := usd 250
/-- IRC 21(d)(2)(B): deemed monthly income, two or more, `$500`. -/
def cdccDeemedMonthlyIncomeTwoOrMore : Int := usd 500
/-- IRC 21(b)(1)(A): a qualifying child has not attained age 13. -/
def cdccQualifyingChildAgeLimit : Int := 13

/-! ### Retirement savings contributions credit (IRC 25B) -/

/-- IRC 25B(a): contributions up to `$2,000` count (Form 8880 line 6). -/
def saversContributionCap : Int := usd 2_000
/-- Notice 2023-75 p 3: joint, 50 percent up to `$46,000`. -/
def saversAgiLimit50Mfj : Int := usd 46_000
/-- Joint, 20 percent up to `$50,000`. -/
def saversAgiLimit20Mfj : Int := usd 50_000
/-- Joint, 10 percent up to `$76,500`. -/
def saversAgiLimit10Mfj : Int := usd 76_500
/-- Head of household, 50 percent up to `$34,500`. -/
def saversAgiLimit50Hoh : Int := usd 34_500
/-- Head of household, 20 percent up to `$37,500`. -/
def saversAgiLimit20Hoh : Int := usd 37_500
/-- Head of household, 10 percent up to `$57,375`. -/
def saversAgiLimit10Hoh : Int := usd 57_375
/-- Any other taxpayer, 50 percent up to `$23,000`. -/
def saversAgiLimit50Other : Int := usd 23_000
/-- Any other taxpayer, 20 percent up to `$25,000`. -/
def saversAgiLimit20Other : Int := usd 25_000
/-- Any other taxpayer, 10 percent up to `$38,250`. -/
def saversAgiLimit10Other : Int := usd 38_250
/-- IRC 25B(b)(1)(A): 50 percent. -/
def saversRateHigh : Rat := 50 / 100
/-- IRC 25B(b)(1)(B): 20 percent. -/
def saversRateMiddle : Rat := 20 / 100
/-- IRC 25B(b)(1)(C): 10 percent. -/
def saversRateLow : Rat := 10 / 100

/-! ### Credit for the elderly or the disabled (IRC 22, Schedule R) -/

/-- IRC 22(c)(2)(A)(i): `$5,000`, single or a joint return with one qualified spouse. -/
def edcInitialAmountSingleOrOneQualified : Int := usd 5_000
/-- IRC 22(c)(2)(A)(ii): `$7,500`, joint with both spouses qualified. -/
def edcInitialAmountJointBothQualified : Int := usd 7_500
/-- IRC 22(c)(2)(A)(iii): `$3,750`, married filing separately. -/
def edcInitialAmountMarriedSeparate : Int := usd 3_750
/-- IRC 22(d)(1): AGI threshold, single, `$7,500`. -/
def edcAgiThresholdSingle : Int := usd 7_500
/-- IRC 22(d)(2): AGI threshold, joint, `$10,000`. -/
def edcAgiThresholdJoint : Int := usd 10_000
/-- IRC 22(d)(3): AGI threshold, married filing separately, `$5,000`. -/
def edcAgiThresholdMarriedSeparate : Int := usd 5_000
/-- Table 1, `i1040sr--2024.pdf` p R-7: AGI limit, single, head of household, QSS. -/
def edcAgiLimitSingleHohQss : Int := usd 17_500
/-- AGI limit, joint, one qualified individual. -/
def edcAgiLimitJointOneQualified : Int := usd 20_000
/-- AGI limit, joint, both qualified. -/
def edcAgiLimitJointBothQualified : Int := usd 25_000
/-- AGI limit, married filing separately. -/
def edcAgiLimitMarriedSeparate : Int := usd 12_500
/-- IRC 22(a): 15 percent. -/
def edcCreditRate : Rat := 15 / 100
/-- IRC 22(d): one-half of the excess AGI. -/
def edcAgiReductionRate : Rat := 50 / 100

end UsTax.Params
