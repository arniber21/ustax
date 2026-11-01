import UsTax.Types
import UsTax.Spec.Rounding

/-!
# Spec: taxable Social Security benefits, Form 1040 line 6b (issue #64)

IRC 86 as it reads, amounts in cents. Imports only `FilingStatus` and
`Spec.Rounding`.

* 86(b): provisional income is modified AGI (AGI without the benefits, plus
  tax-exempt interest) plus one-half of the benefits;
* 86(c)(1): base amount $32,000 joint, $0 married filing separately and not
  living apart all year, $25,000 otherwise;
* 86(c)(2): adjusted base amount $44,000, $0, $34,000 likewise;
* 86(a)(1): up to the adjusted base amount, the lesser of one-half of the
  benefits and one-half of the provisional income over the base amount;
* 86(a)(2): above it, the lesser of 85% of the benefits and 85% of the
  excess over the adjusted base amount plus the lesser of the 86(a)(1) amount
  and one-half of the difference between the two base amounts.

Every percentage is rounded to the cent, and the result to the dollar, as the
worksheet (Form 1040 instructions p 32) does. Net benefits that are negative
(repayments) give $0.
-/

namespace UsTax.Spec

/-- IRC 86(c)(1): the base amount. -/
def ssBaseAmount (fs : FilingStatus) (livedApartAllYear : Bool) : Int :=
  match fs with
  | .marriedFilingJointly => 32_000_00
  | .marriedFilingSeparately => if livedApartAllYear then 25_000_00 else 0
  | _ => 25_000_00

/-- IRC 86(c)(2): the adjusted base amount. -/
def ssAdjustedBaseAmount (fs : FilingStatus) (livedApartAllYear : Bool) : Int :=
  match fs with
  | .marriedFilingJointly => 44_000_00
  | .marriedFilingSeparately => if livedApartAllYear then 34_000_00 else 0
  | _ => 34_000_00

/-- IRC 86(a): the taxable part of `benefits` (whole dollars) for modified AGI
`modifiedAgi`, before rounding to the dollar. -/
def ssTaxableTiers (fs : FilingStatus) (livedApart : Bool) (benefits modifiedAgi : Int) : Int :=
  let base := ssBaseAmount fs livedApart
  let adjusted := ssAdjustedBaseAmount fs livedApart
  let provisional := modifiedAgi + percentOf 50 benefits
  if provisional ≤ base then 0
  else if provisional ≤ adjusted then
    min (percentOf 50 benefits) (percentOf 50 (provisional - base))          -- 86(a)(1)
  else
    min (percentOf 85 benefits)                                              -- 86(a)(2)
      (percentOf 85 (provisional - adjusted) +
        min (percentOf 50 benefits) (percentOf 50 (adjusted - base)))

/-- Form 1040 line 6b: the IRC 86 amount rounded to the dollar, `$0` for
negative net benefits. -/
def taxableSocialSecurity (fs : FilingStatus) (livedApart : Bool) (benefits modifiedAgi : Int) : Int :=
  if benefits < 0 then 0 else roundToDollar (ssTaxableTiers fs livedApart benefits modifiedAgi)

/-- Single, $20,000 of benefits, $10,000 of other income: provisional income
$20,000 is under $25,000, nothing is taxable. -/
example : taxableSocialSecurity .single false 20_000_00 10_000_00 = 0 := by decide

/-- Single, $24,000 of benefits, $30,000 of wages: provisional $42,000;
85% × $8,000 + min($12,000, $4,500) = $11,300. -/
example : taxableSocialSecurity .single false 24_000_00 30_000_00 = 11_300_00 := by decide

/-- Rejected: 85% of all benefits ($20,400) for that filer. -/
example : taxableSocialSecurity .single false 24_000_00 30_000_00 ≠ 20_400_00 := by decide

/-- Rejected: half the benefits ($12,000), i.e. 86(a)(1) used above the
adjusted base. -/
example : taxableSocialSecurity .single false 24_000_00 30_000_00 ≠ 12_000_00 := by decide

end UsTax.Spec
