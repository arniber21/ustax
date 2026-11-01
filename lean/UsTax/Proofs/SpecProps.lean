import UsTax.Spec.StandardDeduction
import UsTax.Spec.Interest
import UsTax.Spec.FormW2
import UsTax.Spec.SocialSecurity
import UsTax.Spec.Adjustments
import UsTax.Spec.Form1040Lines
import UsTax.Spec.Inputs
import UsTax.Form1040Full
import Plausible

/-!
# Property tests of the module specs (plausible, issue #64)

Each statement proved in `UsTax/Proofs/{StandardDeduction, Interest, FormW2,
SocialSecurity, Adjustments, Form1040Lines}.lean` was first run here on random
inputs (CLAUDE.md section 5), and the tests run on every build. As in
`UsTax/Income/Props.lean` they use `Testable.check`, so nothing is admitted.
Amounts are random integers (cents) at several scales `k`.
-/

namespace UsTax.Spec.Props
open Plausible

/-- `#prop p`: run plausible on `p` with 300 random instances. -/
local macro "#prop " p:term : command =>
  `(command| #eval Testable.check $p { numInst := 300 })

/-- Amount in cents from a small random integer at scale `k`. -/
def amt (k a : Int) : Int := a * k

-- Standard deduction = IRC 63(c), every status, dependent or not.
#prop (∀ e : Int, ∀ b1 b2 b3 b4 dep : Bool, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  let i : StandardDeduction.StandardDeductionIn :=
    { filingStatus := fs, treatAsMfs := fs == .marriedFilingSeparately, primaryFilerIsBlind := b1,
      primaryFilerAge65OrOlder := b2, secondaryFilerIsBlind := b3, secondaryFilerAge65OrOlder := b4,
      isWidowedInTaxYear := false, mfjDeceasedSpouseReachedAge65 := false, mfsSpouse65OrOlder := b4,
      mfsSpouseProvidesNoBenefits := b3, treatFilersAsDependents := dep,
      employerIncomeSubtotal := amt k e }
  (StandardDeduction.standardDeduction i).standardDeduction ==
    standardDeductionSpec fs (StandardDeduction.standardDeduction i).additionalStandardDeductionItems dep
      (amt k e))

-- Line 2b and the Schedule B decision = the instructions.
#prop (∀ a b c : Int, ∀ f : Bool, [1, 100, 99_700].all fun k =>
  let rs : List Interest.InterestReport :=
    [{ has1099 := true, writable1099Amount := amt k a },
     { has1099 := true, writable1099Amount := amt k b, writableInterestOnGovernmentBonds := amt k c },
     { no1099Amount := amt k c }]
  let o := Interest.interest
    { interestReports := rs, hasForeignAccountsOrTrusts := f,
      filingStatus := .single, agi := 0, flowHasSeenDeductions := false }
  o.interestIncome == interestLine2b (rs.map reportTaxableInterest) f &&
    o.requiresScheduleB == scheduleBRequired (rs.map reportTaxableInterest) f)

-- W-2: line 1a, and the Medicare and social security knockouts.
#prop (∀ a b c d : Int, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  let ws : List FormW2s.FormW2 :=
    [{ writableWages := amt k a, writableMedicareWages := amt k a, writableOasdiWages := amt k a },
     { writableWages := amt k b, writableMedicareWages := amt k b, writableOasdiWages := amt k c },
     { filer := .secondaryFiler, writableWages := amt k d, writableMedicareWages := amt k d }]
  let o := FormW2s.formW2s
    { w2s := ws, filingStatus := fs, primaryFilerCanBeClaimed := false,
      secondaryFilerCanBeClaimed := false, combatPayElection := .noCombatPay }
  o.wages == totalOfBox (ws.map (·.writableWages)) &&
    o.koKnockoutMedicareWages == needsForm8959 fs (filerBox .primaryFiler (·.writableMedicareWages) ws)
      (filerBox .secondaryFiler (·.writableMedicareWages) ws) &&
    o.primaryFilerExceedsMaxOasdiWages ==
      excessSocialSecurityPossible (filerBox .primaryFiler (·.writableOasdiWages) ws))

-- Social Security: line 6b = IRC 86; 0 ≤ line 6b ≤ 85% of benefits; monotone in other income.
#prop (∀ a c d e : Int, ∀ apart : Bool, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  let i : SocialSecurity.SocialSecurityIn :=
    { reportNetBenefits := [amt k a], filingStatus := fs, livedApartAllYear := apart,
      line1z := amt k c, line2b := amt k d, line2a := 0, line3b := 0, line4b := 0, line5b := 0,
      line7CapitalGains := 0, line8OtherIncome := 0, adjustmentsExcludingStudentLoanInterest := amt k e }
  let o := SocialSecurity.socialSecurity i
  let o' := SocialSecurity.socialSecurity { i with line8OtherIncome := amt k (e * e) }
  o.line6b == taxableSocialSecurity fs apart (roundToDollar (amt k a)) (ssModifiedAgi i) &&
    decide (0 ≤ o.line6b) && decide (o.line6b ≤ roundToDollar (percentOf 85 (max 0 o.line6a))) &&
    decide (o.line6b ≤ o'.line6b))

-- Educator expenses and student loan interest = the statute; line 21 bounds and antitone.
#prop (∀ a b c d : Int, ∀ had q cl : Bool, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  let i : StudentLoanAdjustment.StudentLoanAdjustmentIn :=
    { filingStatus := fs, hadStudentLoanInterestPayments := had, studentLoansQualify := q,
      studentLoanInterestAmount := amt k (a * a), isMfjDependent := false,
      eitherFilerIsClaimedAsDependent := cl, totalIncome := amt (k * 7) b,
      adjustmentsToIncomeExcludingStudentLoanInterest := amt k c }
  let l21 := fun j => (StudentLoanAdjustment.studentLoanAdjustment j).studentLoanInterestAdjustmentAmount
  l21 i == studentLoanDeduction fs (studentLoanEligible i) (amt k (a * a)) (amt (k * 7) b - amt k c) &&
    decide (0 ≤ l21 i) && decide (l21 i ≤ min (roundToDollar (amt k (a * a))) 2_500_00) &&
    decide (l21 { i with totalIncome := amt (k * 7) b + amt k (d * d) } ≤ l21 i) &&
    (EducatorAdjustment.educatorAdjustment
      { wasK12Educators := if had then .bothDid else .tpDid, primaryEducatorExpensesWritable := amt k a,
        secondaryEducatorExpensesWritable := amt k d }).educatorExpensesAdjustment ==
      educatorDeduction true had (amt k a) (amt k d) false)

-- Form 1040: line 11, line 15, line 33, and line 24 does not drop when a W-2 is added.
#prop (∀ a b c d e : Int, ∀ dep : Bool, FilingStatus.all.all fun fs => [1, 100, 99_700].all fun k =>
  let i : Form1040.Form1040In :=
    { Form1040.run [{ writableWages := amt k a, writableFederalWithholding := amt k (b * b) }] [] fs with
      treatFilersAsDependents := dep, taxableDependentCare := amt k c,
      taxablePensionsAndAnnuities := amt k d, studentLoanInterestAdjustmentAmount := amt k (e * e),
      estimatedAndFromLastYear := amt 100 e }
  let o := Form1040.form1040 i
  let o' := Form1040.form1040 { i with w2s := { writableWages := amt k (e * e) } :: i.w2s }
  o.agi == o.totalIncome - o.adjustmentsToIncome &&
    o.taxableIncome == max 0 (o.agi - o.totalDeductions) &&
    o.totalPayments == o.totalWithholding + amt 100 e + o.totalOtherPaymentsRefundableCredits &&
    decide (o.totalTax ≤ o'.totalTax))

-- Negative control: "line 6b is at most 50% of the benefits" is false (85% tier).
#eval do
  let r ← Testable.checkIO (NamedBinder "a" <| ∀ a : Nat,
    (SocialSecurity.socialSecurity
      { reportNetBenefits := [(a : Int) * 100], filingStatus := .single, livedApartAllYear := false,
        line1z := 100_000_00, line2b := 0, line2a := 0, line3b := 0, line4b := 0, line5b := 0,
        line7CapitalGains := 0, line8OtherIncome := 0,
        adjustmentsExcludingStudentLoanInterest := 0 }).line6b ≤ (a : Int) * 50)
    { numInst := 300, quiet := true }
  unless r matches .failure .. do throw (IO.userError "plausible missed a false statement")

end UsTax.Spec.Props
