import UsTax.Unemployment
import UsTax.Form1099Misc
import UsTax.SocialSecurity
import UsTax.EducatorAdjustment
import UsTax.StudentLoanAdjustment
import UsTax.EstimatedPayments
import UsTax.Form1040Full
import Plausible

/-!
# Property tests for the income and adjustment modules (plausible, issue #45)

Each statement here was tested before it was proved in `UsTax/Income/Lemmas.lean`
(CLAUDE.md section 5), and the tests run on every build. As in
`UsTax/Form1040/Props.lean` they use `Testable.check`, so nothing is admitted.
Amounts are random integers (cents) at several scales.
-/

namespace UsTax.Income.Props
open Plausible

/-- `#prop p`: run plausible on `p` with 300 random instances. -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 300 })

/-- Amount in cents from small random integers at scale `k`. -/
def amt (k a : Int) : Int := a * k

-- Line 7 is never negative, whatever the forms (the repayment is capped at box 1).
#prop (∀ a b c d : Int, [1, 100, 99_700].all fun k =>
  0 ≤ (Unemployment.unemployment { form1099Gs :=
    [{ amount := amt k a, writableAmountPaidBackForBenefitsInTaxYear := amt k b },
     { amount := amt k c, writableAmountPaidBackForBenefitsInTaxYear := amt k d }] }).unemploymentCompensation)

-- Educator adjustment: between $0 and $600 for nonnegative expenses.
#prop (∀ a b : Nat, [1, 100, 99_700].all fun k =>
  FilingStatus.all.all fun _ =>
  let o := EducatorAdjustment.educatorAdjustment
    { wasK12Educators := .bothDid, primaryEducatorExpensesWritable := amt k a,
      secondaryEducatorExpensesWritable := amt k b }
  0 ≤ o.educatorExpensesAdjustment && o.educatorExpensesAdjustment ≤ 60_000)

-- Student loan interest: between $0 and $2,500 for nonnegative interest, in every status.
#prop (∀ a b c : Nat, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  let o := StudentLoanAdjustment.studentLoanAdjustment
    { filingStatus := fs, hadStudentLoanInterestPayments := true, studentLoansQualify := true,
      studentLoanInterestAmount := amt k a, isMfjDependent := false,
      eitherFilerIsClaimedAsDependent := false, totalIncome := amt (k * 7) b,
      adjustmentsToIncomeExcludingStudentLoanInterest := amt k c }
  0 ≤ o.studentLoanInterestAdjustmentAmount && o.studentLoanInterestAdjustmentAmount ≤ 250_000)

-- Taxable Social Security (line 6b) is never negative, and never above 85% of benefits (rounded).
#prop (∀ a b c d e : Int, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  let o := SocialSecurity.socialSecurity
    { reportNetBenefits := [amt k a], filingStatus := fs, livedApartAllYear := b % 2 == 0,
      line1z := amt k c, line2b := amt k d, line2a := 0, line3b := 0, line4b := 0, line5b := 0,
      line7CapitalGains := 0, line8OtherIncome := 0,
      adjustmentsExcludingStudentLoanInterest := amt k e }
  0 ≤ o.line6b)

-- Estimated payments (line 26) are nonnegative for a nonnegative payment.
#prop (∀ a : Nat, [1, 100, 99_700].all fun k =>
  0 ≤ (EstimatedPayments.estimatedPayments
    { paidEstimatedTaxesOrFromLastYear := true, estimatedTaxPaymentWritable := amt k a,
      paidEstimatedTaxesOrFromLastYearUnderDifferentName := false,
      paidEstimatedTaxesWithFormerSpouse := .neither }).estimatedAndFromLastYear)

-- Alaska PFD income is nonnegative for nonnegative box 3.
#prop (∀ a b : Nat, [1, 100, 99_700].all fun k =>
  0 ≤ (Form1099Misc.form1099Miscs { form1099Miscs :=
    [{ writableOtherIncome := amt k a }, { writableOtherIncome := amt k b }] }).alaskaPfdIncome)

-- Composition: refund and balance due stay exclusive with the modules plugged in.
#prop (∀ a b c d e : Nat, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  let o := (Form1040Full.form1040Full
    { base := Form1040.run [{ writableWages := amt k a, writableFederalWithholding := amt k b }] [] fs
      form1099Gs := [{ amount := amt k c }]
      socialSecurityNetBenefits := [amt k d]
      estimated :=
        { paidEstimatedTaxesOrFromLastYear := true, estimatedTaxPaymentWritable := amt k e,
          paidEstimatedTaxesOrFromLastYearUnderDifferentName := false,
          paidEstimatedTaxesWithFormerSpouse := .neither } }).form1040
  o.overpayment = 0 || o.balanceDue = 0)

-- Negative control: "the educator adjustment is always positive" is false.
#eval do
  let r ← Testable.checkIO (NamedBinder "a" <| ∀ a : Nat,
    0 < (EducatorAdjustment.educatorAdjustment
      { wasK12Educators := .tpDid, primaryEducatorExpensesWritable := (a : Int) * 100 }).educatorExpensesAdjustment)
    { numInst := 300, quiet := true }
  unless r matches .failure .. do throw (IO.userError "plausible missed a false statement")

end UsTax.Income.Props
