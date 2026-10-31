import UsTax.Money
import UsTax.Lists
import UsTax.Types
import UsTax.Params2024

/-!
# Social Security benefits: Form 1040 lines 6a and 6b (issue #45)

Lean implementation of `catala/social_security.catala_en` (module `Social_security`,
scope `SocialSecurity`), written by hand from the Catala source under strategy (c)
of `docs/catala-to-lean.md`; the code that runs. The Social Security Benefits
Worksheet of the 2024 Form 1040 instructions (p 32), IRC 86.

| Catala (`Social_security`)            | Lean (`UsTax.SocialSecurity`)              |
|---------------------------------------|--------------------------------------------|
| `ss_half`, `ss_eighty_five_percent`   | `ssHalf`, `ssEightyFivePercent`            |
| `scope SocialSecurity` (inputs)       | `SocialSecurityIn` (field names in lower camel case; `line_7_capital_gains` is `line7CapitalGains`) |
| `scope SocialSecurity` (outputs)      | `SocialSecurityOut` (`socialSecurity`)     |

Money is `Int` cents. Every `money * decimal` is `Money.mulRate` (a cent-rounding
point); the final line 18 is `roundDollar`.
-/

namespace UsTax.SocialSecurity

open Money

/-- § 86(a)(1): one-half. Worksheet lines 2 and 13. -/
def ssHalf : Rat := 1 / 2
/-- § 86(a)(2): 85 percent. Worksheet lines 15, 16 (MFS shortcut) and 17. -/
def ssEightyFivePercent : Rat := 85 / 100

/-- Worksheet line 8: the § 86(c)(1) base amount, $32,000 for a joint return, else $25,000. -/
def wkshtLine8Of (fs : FilingStatus) : Int :=
  if fs == .marriedFilingJointly then Params.ssBaseAmountJoint else Params.ssBaseAmountOther

/-- Worksheet line 10: $12,000 for a joint return, else $9,000. -/
def wkshtLine10Of (fs : FilingStatus) : Int :=
  if fs == .marriedFilingJointly then Params.ssAdjustedBaseGapJoint else Params.ssAdjustedBaseGapOther

/-- Worksheet line 16 from line 7 and line 6a (lines 8 to 15 inlined as in Catala). -/
def wkshtLine16Of (fs : FilingStatus) (livedApartAllYear : Bool) (line6a wkshtLine7 : Int) : Int :=
  let wkshtLine8 := wkshtLine8Of fs
  let wkshtLine9 := wkshtLine7 - wkshtLine8
  let wkshtLine10 := wkshtLine10Of fs
  let wkshtLine11 := positive (wkshtLine9 - wkshtLine10)
  if fs == .marriedFilingSeparately && !livedApartAllYear then
    mulRate wkshtLine7 ssEightyFivePercent
  else if wkshtLine7 < wkshtLine8 then 0
  else
    mulRate wkshtLine11 ssEightyFivePercent +
      Money.min (mulRate line6a ssHalf) (mulRate (Money.min wkshtLine9 wkshtLine10) ssHalf)

/-- Inputs of `SocialSecurity`. -/
structure SocialSecurityIn where
  /-- Catala input `report_net_benefits`. -/
  reportNetBenefits : List Int
  /-- Catala input `filing_status`. -/
  filingStatus : FilingStatus
  /-- Catala input `lived_apart_all_year`. -/
  livedApartAllYear : Bool
  /-- Catala input `line_1z`. -/
  line1z : Int
  /-- Catala input `line_2b`. -/
  line2b : Int
  /-- Catala input `line_2a`. -/
  line2a : Int
  /-- Catala input `line_3b`. -/
  line3b : Int
  /-- Catala input `line_4b`. -/
  line4b : Int
  /-- Catala input `line_5b`. -/
  line5b : Int
  /-- Catala input `line_7_capital_gains`. -/
  line7CapitalGains : Int
  /-- Catala input `line_8_other_income`. -/
  line8OtherIncome : Int
  /-- Catala input `adjustments_excluding_student_loan_interest`. -/
  adjustmentsExcludingStudentLoanInterest : Int

/-- Outputs of `SocialSecurity`. -/
structure SocialSecurityOut where
  /-- Form 1040 line 6a, worksheet line 1. -/
  line6a : Int
  /-- Worksheet line 3. -/
  wkshtLine3 : Int
  /-- Worksheet line 7. -/
  wkshtLine7 : Int
  /-- Worksheet line 8. -/
  wkshtLine8 : Int
  /-- Worksheet line 9. -/
  wkshtLine9 : Int
  /-- Worksheet line 10. -/
  wkshtLine10 : Int
  /-- Worksheet line 11. -/
  wkshtLine11 : Int
  /-- Worksheet line 16. -/
  wkshtLine16 : Int
  /-- Form 1040 line 6b, worksheet line 18. -/
  line6b : Int
  /-- Schedule R line 13a. -/
  nonTaxableBenefits : Int
  /-- Catala `has_benefits`. -/
  hasBenefits : Bool
  /-- Catala `benefit_code_d`. -/
  benefitCodeD : Bool
  /-- Catala `repayment_over_3k`. -/
  repaymentOver3k : Bool

/-- Catala `scope SocialSecurity`, worksheet lines 1 to 18. -/
def socialSecurity (i : SocialSecurityIn) : SocialSecurityOut :=
  let line6a := roundDollar (sum i.reportNetBenefits)
  let hasBenefits := decide (line6a > 0)
  let wkshtLine3 :=
    i.line1z + i.line2b + i.line3b + i.line4b + i.line5b + i.line7CapitalGains + i.line8OtherIncome
  let wkshtLine7 :=
    positive (mulRate line6a ssHalf + wkshtLine3 + i.line2a - i.adjustmentsExcludingStudentLoanInterest)
  let wkshtLine8 := wkshtLine8Of i.filingStatus
  let wkshtLine9 := wkshtLine7 - wkshtLine8
  let wkshtLine10 := wkshtLine10Of i.filingStatus
  let wkshtLine11 := positive (wkshtLine9 - wkshtLine10)
  let wkshtLine16 := wkshtLine16Of i.filingStatus i.livedApartAllYear line6a wkshtLine7
  let line6b :=
    if line6a < 0 then 0
    else roundDollar (Money.min wkshtLine16 (mulRate line6a ssEightyFivePercent))
  { line6a := line6a
    wkshtLine3 := wkshtLine3
    wkshtLine7 := wkshtLine7
    wkshtLine8 := wkshtLine8
    wkshtLine9 := wkshtLine9
    wkshtLine10 := wkshtLine10
    wkshtLine11 := wkshtLine11
    wkshtLine16 := wkshtLine16
    line6b := line6b
    nonTaxableBenefits := line6a - line6b
    hasBenefits := hasBenefits
    benefitCodeD :=
      hasBenefits && i.filingStatus == .marriedFilingSeparately && i.livedApartAllYear
    repaymentOver3k := decide (line6a < -Params.claimOfRightThreshold) }

/-! ### Unit tests: every assertion of `catala/tests/test_social_security.catala_en` -/

/-- Catala helper scope `Run`: every income component not named is `$0`. -/
private def run (fs : FilingStatus) (livedApart : Bool) (net : Int) (wages interest other exempt adj : Int) :
    SocialSecurityOut :=
  socialSecurity
    { reportNetBenefits := [net], filingStatus := fs, livedApartAllYear := livedApart,
      line1z := wages, line2b := interest, line2a := exempt, line3b := 0, line4b := 0, line5b := 0,
      line7CapitalGains := 0, line8OtherIncome := other,
      adjustmentsExcludingStudentLoanInterest := adj }

-- TestIssueCases
private def belowBase := run .single false 2_000_000 0 0 1_000_000 0 0
private def eightyFive := run .single false 2_400_000 0 0 3_000_000 0 0
private def mfsTogether := run .marriedFilingSeparately false 1_000_000 200_000 0 0 0 0
private def mfsTogetherCapped := run .marriedFilingSeparately false 1_000_000 2_000_000 0 0 0 0
private def negative := run .single false (-30_000) 4_000_000 0 0 0 0
#guard belowBase.line6b == 0
#guard belowBase.wkshtLine16 == 0
#guard eightyFive.wkshtLine7 == 4_200_000
#guard eightyFive.wkshtLine16 == 1_130_000
#guard eightyFive.line6b == 1_130_000
#guard eightyFive.nonTaxableBenefits == 1_270_000
#guard mfsTogether.wkshtLine7 == 700_000
#guard mfsTogether.wkshtLine16 == 595_000
#guard mfsTogether.line6b == 595_000
#guard mfsTogetherCapped.wkshtLine16 == 2_125_000
#guard mfsTogetherCapped.line6b == 850_000
#guard negative.line6a == -30_000
#guard negative.line6b == 0
#guard negative.nonTaxableBenefits == -30_000
#guard eightyFive.line6b != 2_400_000
#guard eightyFive.line6b != 1_200_000
#guard negative.line6b != 30_000
#guard belowBase.line6b != 1_000_000

-- TestOthers
private def mfjTie := run .marriedFilingJointly false 2_910_200 2_446_900 149_900 0 0 0
private def mfsApart := run .marriedFilingSeparately true 1_000_000 3_000_000 0 0 0 0
private def adjusted := run .single false 1_000_000 3_000_000 0 0 0 500_000
private def exempt := run .single false 1_000_000 1_500_000 0 0 600_000 0
private def capped := run .single false 1_000_000 6_000_000 0 0 0 0
private def repaid3500 := run .single false (-350_000) 0 0 0 0 0
private def repaid3000 := run .single false (-300_000) 0 0 0 0 0
#guard mfjTie.wkshtLine7 == 4_051_900
#guard mfjTie.line6b == 426_000
#guard !mfjTie.benefitCodeD
#guard mfsApart.wkshtLine7 == 3_500_000
#guard mfsApart.wkshtLine16 == 535_000
#guard mfsApart.line6b == 535_000
#guard mfsApart.benefitCodeD
#guard adjusted.wkshtLine7 == 3_000_000
#guard adjusted.line6b == 250_000
#guard exempt.wkshtLine7 == 2_600_000
#guard exempt.line6b == 50_000
#guard capped.wkshtLine16 == 3_085_000
#guard capped.line6b == 850_000
#guard repaid3500.repaymentOver3k
#guard !repaid3000.repaymentOver3k
#guard repaid3500.line6b == 0

end UsTax.SocialSecurity
