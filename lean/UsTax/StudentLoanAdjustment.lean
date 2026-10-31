import UsTax.Money
import UsTax.Types
import UsTax.Params2024

/-!
# Student loan interest deduction (Schedule 1 line 21) (issue #45)

Lean implementation of `catala/student_loan_adjustment.catala_en` (module
`Student_loan_adjustment`, scope `StudentLoanAdjustment`), written by hand from the
Catala source under strategy (c) of `docs/catala-to-lean.md`; the code that runs.
IRC 221, Rev. Proc. 2023-34 § 3.30, Student Loan Interest Deduction Worksheet.

| Catala (`Student_loan_adjustment`)   | Lean (`UsTax.StudentLoanAdjustment`)        |
|--------------------------------------|---------------------------------------------|
| `round_half_even_cents`              | `roundHalfEvenCents` (test reference only)  |
| `df_phase_out_amount`                | `dfPhaseOutAmount` (test reference only; DF-BUG(7)) |
| `exact_phase_out_amount`             | `exactPhaseOutAmount`                       |
| `scope StudentLoanAdjustment`        | `StudentLoanAdjustmentIn` → `StudentLoanAdjustmentOut` (`studentLoanAdjustment`) |

**Where Lean follows Catala, not Direct File.** The phase-out ratio is the exact
fraction `excess / range` (a `Rat`), and line 21 is rounded once to the dollar
(`roundDollarExact`), as in Catala (DF-BUG(7): DF rounds the ratio to three
decimals). Money is `Int` cents.
-/

namespace UsTax.StudentLoanAdjustment

open Money

/-- Catala `round_half_even_cents`: `value` dollars to the cent, ties to the even
cent (Java `HALF_EVEN`), as cents. Used only by `dfPhaseOutAmount`. -/
def roundHalfEvenCents (value : Rat) : Int :=
  let cents := value * 100
  let below : Int := cents.floor
  let fraction := cents - (below : Rat)
  if fraction < 1 / 2 then below
  else if fraction > 1 / 2 then below + 1
  else if Int.tdiv below 2 * 2 = below then below
  else below + 1

/-- Catala `df_phase_out_amount`: Direct File's three-decimal computation, kept
only so the tests can show the divergence; the scope does not use it. -/
def dfPhaseOutAmount (excess range cappedInterest : Int) : Int :=
  let ratioTimesTen := roundHalfEvenCents (divMoney (mulRate excess 10) range)
  let product :=
    roundHalfEvenCents (divMoney ratioTimesTen 100 * divMoney cappedInterest 100)
  roundHalfEvenCents (divMoney product 100 / 10)

/-- Catala `exact_phase_out_amount`: the statute's phase-out, to the cent. -/
def exactPhaseOutAmount (excess range cappedInterest : Int) : Int :=
  mulRate cappedInterest (divMoney excess range)

/-- Worksheet line 7, exact: `Decimal.min of 1.0, (excess / range)`. -/
def phaseOutRatio (excess range : Int) : Rat :=
  let r := divMoney excess range
  if r < 1 then r else 1

/-- Inputs of `StudentLoanAdjustment`. -/
structure StudentLoanAdjustmentIn where
  /-- Catala input `filing_status`. -/
  filingStatus : FilingStatus
  /-- Catala input `had_student_loan_interest_payments`. -/
  hadStudentLoanInterestPayments : Bool
  /-- Catala input `student_loans_qualify`. -/
  studentLoansQualify : Bool
  /-- Catala input `student_loan_interest_amount`. -/
  studentLoanInterestAmount : Int
  /-- Catala input `is_mfj_dependent`. -/
  isMfjDependent : Bool
  /-- Catala input `either_filer_is_claimed_as_dependent`. -/
  eitherFilerIsClaimedAsDependent : Bool
  /-- Catala input `total_income`. -/
  totalIncome : Int
  /-- Catala input `adjustments_to_income_excluding_student_loan_interest`. -/
  adjustmentsToIncomeExcludingStudentLoanInterest : Int

/-- Outputs of `StudentLoanAdjustment`. -/
structure StudentLoanAdjustmentOut where
  /-- Worksheet line 4. -/
  magiForStudentLoanInterestDeduction : Int
  /-- Catala `income_too_high_not_mfj`. -/
  incomeTooHighNotMfj : Bool
  /-- Catala `income_too_high_mfj`. -/
  incomeTooHighMfj : Bool
  /-- Catala `cannot_deduct_because_income_or_filing_status`. -/
  cannotDeductBecauseIncomeOrFilingStatus : Bool
  /-- Catala `cannot_deduct_because_dependents`. -/
  cannotDeductBecauseDependents : Bool
  /-- Catala `cannot_deduct_because_loans_dont_qualify`. -/
  cannotDeductBecauseLoansDontQualify : Bool
  /-- Catala `cannot_deduct_student_loan_interest`. -/
  cannotDeductStudentLoanInterest : Bool
  /-- Worksheet line 8, to the cent, for display. -/
  studentLoanAmountPhaseOutAmount : Int
  /-- Schedule 1 line 21. -/
  studentLoanInterestAdjustmentAmount : Int
  /-- Catala `is_receiving_student_loan_interest_adjustment`. -/
  isReceivingStudentLoanInterestAdjustment : Bool

/-- Catala `scope StudentLoanAdjustment`. -/
def studentLoanAdjustment (i : StudentLoanAdjustmentIn) : StudentLoanAdjustmentOut :=
  let mfj := i.filingStatus == .marriedFilingJointly
  let mfs := i.filingStatus == .marriedFilingSeparately
  let magi := i.totalIncome - i.adjustmentsToIncomeExcludingStudentLoanInterest
  let tooHighNotMfj := !mfj && decide (magi > Params.studentLoanPhaseoutEndOther)
  let tooHighMfj := mfj && decide (magi > Params.studentLoanPhaseoutEndJoint)
  let incomeOrStatus := mfs || tooHighNotMfj || tooHighMfj
  let dependents := !incomeOrStatus && i.eitherFilerIsClaimedAsDependent
  let loansDont := !incomeOrStatus && i.hadStudentLoanInterestPayments &&
    !i.eitherFilerIsClaimedAsDependent && !i.studentLoansQualify
  let cannot := dependents || loansDont || incomeOrStatus || i.isMfjDependent
  let capped := Money.min i.studentLoanInterestAmount Params.studentLoanInterestCap
  let start := if mfj then Params.studentLoanPhaseoutStartJoint else Params.studentLoanPhaseoutStartOther
  let range :=
    if mfj then Params.studentLoanPhaseoutEndJoint - Params.studentLoanPhaseoutStartJoint
    else Params.studentLoanPhaseoutEndOther - Params.studentLoanPhaseoutStartOther
  let excess := Money.max 0 (magi - start)
  let ratio := phaseOutRatio excess range
  let adjustment :=
    if cannot || !i.hadStudentLoanInterestPayments then 0
    else roundDollarExact capped (1 - ratio)
  { magiForStudentLoanInterestDeduction := magi
    incomeTooHighNotMfj := tooHighNotMfj
    incomeTooHighMfj := tooHighMfj
    cannotDeductBecauseIncomeOrFilingStatus := incomeOrStatus
    cannotDeductBecauseDependents := dependents
    cannotDeductBecauseLoansDontQualify := loansDont
    cannotDeductStudentLoanInterest := cannot
    studentLoanAmountPhaseOutAmount := mulRate capped ratio
    studentLoanInterestAdjustmentAmount := adjustment
    isReceivingStudentLoanInterestAdjustment := decide (adjustment > 0) }

/-! ### Unit tests: every assertion of `catala/tests/test_student_loan_adjustment.catala_en` -/

/-- Catala helper scope `Base`: single, $3,000 of interest, $70,000 total income. -/
private def base (fs : FilingStatus := .single) (hadPayments : Bool := true)
    (qualify : Bool := true) (interest : Int := 300_000) (dep : Bool := false)
    (claimed : Bool := false) (income : Int := 7_000_000) (otherAdj : Int := 0) :
    StudentLoanAdjustmentOut :=
  studentLoanAdjustment
    { filingStatus := fs, hadStudentLoanInterestPayments := hadPayments,
      studentLoansQualify := qualify, studentLoanInterestAmount := interest,
      isMfjDependent := dep, eitherFilerIsClaimedAsDependent := claimed, totalIncome := income,
      adjustmentsToIncomeExcludingStudentLoanInterest := otherAdj }

-- TestStudentLoanCases
#guard (base).studentLoanInterestAdjustmentAmount == 250_000
#guard (base (income := 8_750_000)).studentLoanAmountPhaseOutAmount == 125_000
#guard (base (income := 8_750_000)).studentLoanInterestAdjustmentAmount == 125_000
#guard (base (fs := .marriedFilingSeparately)).studentLoanInterestAdjustmentAmount == 0
#guard (base (fs := .marriedFilingSeparately)).cannotDeductStudentLoanInterest
#guard (base (income := 9_500_100)).studentLoanInterestAdjustmentAmount == 0
#guard (base (income := 9_500_100)).cannotDeductStudentLoanInterest
#guard (base (income := 9_500_000)).studentLoanInterestAdjustmentAmount == 0
#guard !(base (income := 9_500_000)).cannotDeductStudentLoanInterest
#guard (base (fs := .marriedFilingJointly) (income := 18_000_000)).studentLoanInterestAdjustmentAmount == 125_000
#guard (base (income := 8_000_000)).studentLoanInterestAdjustmentAmount == 250_000
#guard (base (fs := .marriedFilingJointly) (income := 16_500_000)).studentLoanInterestAdjustmentAmount == 250_000
#guard (base (income := 9_000_000) (otherAdj := 250_000)).magiForStudentLoanInterestDeduction == 8_750_000
#guard (base (income := 9_000_000) (otherAdj := 250_000)).studentLoanInterestAdjustmentAmount == 125_000

-- TestThreeDecimalRatio (DF-BUG(7): Lean follows Catala, i.e. the exact fraction)
#guard (base (income := 8_500_000)).studentLoanAmountPhaseOutAmount == 83_333
#guard (base (income := 8_500_000)).studentLoanInterestAdjustmentAmount == 166_700
#guard exactPhaseOutAmount 500_000 1_500_000 250_000 == 83_333
#guard dfPhaseOutAmount 500_000 1_500_000 250_000 == 83_250
#guard (base (income := 8_500_000)).studentLoanInterestAdjustmentAmount - 166_700 == 0
#guard (base (income := 8_500_000)).studentLoanInterestAdjustmentAmount != 166_800
#guard (base (fs := .marriedFilingJointly) (income := 16_501_500)).studentLoanInterestAdjustmentAmount == 249_900
#guard dfPhaseOutAmount 1_500 3_000_000 250_000 == 0
#guard roundHalfEvenCents (5 / 1000) == 0
#guard roundHalfEvenCents (15 / 1000) == 2
#guard roundHalfEvenCents (25 / 1000) == 2
#guard roundHalfEvenCents (35 / 1000) == 4
#guard roundHalfEvenCents (49 / 10000) == 0
#guard roundHalfEvenCents (51 / 10000) == 1
#guard roundHalfEvenCents 1 == 100
#guard roundHalfEvenCents (0 - 5 / 1000) == 0
#guard roundHalfEvenCents (0 - 15 / 1000) == -2

-- TestStudentLoanZero
#guard (base (claimed := true)).studentLoanInterestAdjustmentAmount == 0
#guard (base (qualify := false)).studentLoanInterestAdjustmentAmount == 0
#guard (base (hadPayments := false)).studentLoanInterestAdjustmentAmount == 0
#guard !(base (hadPayments := false)).cannotDeductStudentLoanInterest
#guard (base (fs := .marriedFilingJointly) (dep := true)).studentLoanInterestAdjustmentAmount == 0
#guard (base (interest := 7_500)).studentLoanInterestAdjustmentAmount == 7_500
#guard (base (fs := .marriedFilingJointly) (interest := 50_000)).studentLoanInterestAdjustmentAmount == 50_000

-- TestStudentLoanRejectsBad
#guard (base (income := 8_750_000)).studentLoanInterestAdjustmentAmount != 250_000
#guard (base (income := 8_750_000)).studentLoanInterestAdjustmentAmount != 0
#guard (base (fs := .marriedFilingSeparately)).studentLoanInterestAdjustmentAmount != 250_000
#guard (base (income := 9_500_100)).studentLoanInterestAdjustmentAmount != 250_000

end UsTax.StudentLoanAdjustment
