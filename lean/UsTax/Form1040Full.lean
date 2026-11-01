import UsTax.Form1040
import UsTax.Unemployment
import UsTax.Form1099Misc
import UsTax.Form1099Rs
import UsTax.SocialSecurity
import UsTax.EducatorAdjustment
import UsTax.StudentLoanAdjustment
import UsTax.EstimatedPayments

/-!
# Form 1040 with the income and adjustment modules plugged in (issue #45)

`UsTax.Form1040` is the strict Lean port of `catala/form_1040.catala_en`: its
plug-in slots (`taxableDependentCare`, ..., `estimatedAndFromLastYear`) default to
`$0`, and its difftest counts (`form_1040` 441, `form_1040_plugged` 3297) depend on
that. This file is the **separate composition layer**: it runs the seven new
modules and fills the slots they own, then calls `form1040`. Nothing in
`UsTax/Form1040.lean` changes.

| Slot of `Form1040In`                       | Filled from                                   |
|--------------------------------------------|-----------------------------------------------|
| `taxablePensionsAndAnnuities`              | `Form1099Rs.line5b`                           |
| `taxableSocialSecurityBenefits`            | `SocialSecurity.line6b`                       |
| `unemploymentCompensation`                 | `Unemployment.unemploymentCompensation`       |
| `alaskaPfdIncome`                          | `Form1099Misc.alaskaPfdIncome`                |
| `studentLoanInterestAdjustmentAmount`      | `StudentLoanAdjustment.studentLoanInterestAdjustmentAmount` |
| `educatorExpensesAdjustment`               | `EducatorAdjustment.educatorExpensesAdjustment` |
| `other1099Withholding`                     | 1099-G + 1099-MISC + 1099-R box 4 (plus the caller's own `base.other1099Withholding`) |
| `paidEstimatedTaxesOrFromLastYear`, `estimatedAndFromLastYear` | `EstimatedPayments`        |

**Order of evaluation** (the worksheet inputs come from the same return): pass 1 is
`form1040` without Social Security and student loan, which yields lines 1z, 2b and 8;
Social Security uses them (and line 2a from `Interest`); pass 2 adds line 6b and gives
line 9, the student loan modified AGI base; pass 3 adds line 21. The Schedule 1
adjustments the Social Security worksheet subtracts (line 6) are the educator
expenses plus the caller's HSA slot, as in `difftest/mappings/social_security.mjs`.

There is no Catala scope for this composition, so it has no Catala difftest of its
own; it is unit-tested here (`#guard`) and its structural properties are proved in
`UsTax/Form1040Full/Lemmas.lean`. Not wired: HSA, EITC, credits (later modules).
-/

namespace UsTax.Form1040Full

open Money

/-- Inputs: a strict `Form1040In` (whose module-owned slots are overridden) plus the
raw inputs of the seven modules. -/
structure Form1040FullIn where
  /-- The Form 1040 inputs. Slots owned by the modules below are overwritten;
  the others (`hsaTotalDeductibleAmount`, credits, ...) are kept as given. -/
  base : Form1040.Form1040In
  /-- Forms 1099-G. -/
  form1099Gs : List Unemployment.Form1099G := []
  /-- Forms 1099-MISC. -/
  form1099Miscs : List Form1099Misc.Form1099Misc := []
  /-- Forms 1099-R. -/
  form1099Rs : List Form1099Rs.Form1099R := []
  /-- Net benefits (box 5) of each SSA-1099 / RRB-1099. -/
  socialSecurityNetBenefits : List Int := []
  /-- `/livedApartAllYear`. -/
  livedApartAllYear : Bool := false
  /-- Educator expenses inputs. -/
  educator : EducatorAdjustment.EducatorAdjustmentIn := {}
  /-- `/hadStudentLoanInterestPayments`. -/
  hadStudentLoanInterestPayments : Bool := false
  /-- `/studentLoansQualify`. -/
  studentLoansQualify : Bool := false
  /-- `/studentLoanInterestAmount`. -/
  studentLoanInterestAmount : Int := 0
  /-- `/eitherFilerIsClaimedAsDependent`. -/
  eitherFilerIsClaimedAsDependent : Bool := false
  /-- Estimated payments inputs. -/
  estimated : EstimatedPayments.EstimatedPaymentsIn :=
    { paidEstimatedTaxesOrFromLastYear := false, estimatedTaxPaymentWritable := 0,
      paidEstimatedTaxesOrFromLastYearUnderDifferentName := false,
      paidEstimatedTaxesWithFormerSpouse := .neither }

/-- Outputs: the full Form 1040 and every module output. -/
structure Form1040FullOut where
  /-- The Form 1040 with the slots filled. -/
  form1040 : Form1040.Form1040Out
  /-- Unemployment (line 7). -/
  unemployment : Unemployment.UnemploymentOut
  /-- Alaska PFD (line 8g). -/
  misc : Form1099Misc.Form1099MiscsOut
  /-- 1099-R (lines 5a, 5b). -/
  retirement : Form1099Rs.Form1099RsOut
  /-- Social Security (lines 6a, 6b). -/
  socialSecurity : SocialSecurity.SocialSecurityOut
  /-- Educator expenses (line 11). -/
  educator : EducatorAdjustment.EducatorAdjustmentOut
  /-- Student loan interest (line 21). -/
  studentLoan : StudentLoanAdjustment.StudentLoanAdjustmentOut
  /-- Estimated payments (line 26). -/
  estimated : EstimatedPayments.EstimatedPaymentsOut
  /-- Union of the return-level knockout and every module knockout. -/
  unsupported : Bool

/-- The composition: three passes of `form1040` around the Social Security and
student loan modules. -/
def form1040Full (i : Form1040FullIn) : Form1040FullOut :=
  let unemp := Unemployment.unemployment { form1099Gs := i.form1099Gs }
  let misc := Form1099Misc.form1099Miscs { form1099Miscs := i.form1099Miscs }
  let ret := Form1099Rs.form1099Rs { forms := i.form1099Rs }
  let edu := EducatorAdjustment.educatorAdjustment i.educator
  let est := EstimatedPayments.estimatedPayments i.estimated
  let b := i.base
  -- pass 1: everything but Social Security and student loan
  let slots1 : Form1040.Form1040In :=
    { b with
      taxablePensionsAndAnnuities := ret.line5b
      unemploymentCompensation := unemp.unemploymentCompensation
      alaskaPfdIncome := misc.alaskaPfdIncome
      educatorExpensesAdjustment := edu.educatorExpensesAdjustment
      studentLoanInterestAdjustmentAmount := 0
      taxableSocialSecurityBenefits := 0
      other1099Withholding :=
        b.other1099Withholding + unemp.form1099gFederalTaxWithheld +
          misc.form1099MiscFederalIncomeTaxWithheld + ret.form1099rFederalIncomeTaxWithheld
      paidEstimatedTaxesOrFromLastYear := i.estimated.paidEstimatedTaxesOrFromLastYear
      estimatedAndFromLastYear := est.estimatedAndFromLastYear }
  let r1 := Form1040.form1040 slots1
  let interest := Interest.interest
    { interestReports := b.interestReports, hasForeignAccountsOrTrusts := b.hasForeignAccountsOrTrusts,
      filingStatus := b.filingStatus, agi := 0, flowHasSeenDeductions := true }
  let ss := SocialSecurity.socialSecurity
    { reportNetBenefits := i.socialSecurityNetBenefits, filingStatus := b.filingStatus,
      livedApartAllYear := i.livedApartAllYear, line1z := r1.employerIncomeSubtotal,
      line2b := r1.interestIncome, line2a := interest.taxExemptInterest, line3b := 0, line4b := 0,
      line5b := ret.line5b, line7CapitalGains := 0, line8OtherIncome := r1.otherIncome,
      adjustmentsExcludingStudentLoanInterest :=
        edu.educatorExpensesAdjustment + b.hsaTotalDeductibleAmount }
  -- pass 2: add Social Security, to get line 9 for the student loan modified AGI
  let slots2 := { slots1 with taxableSocialSecurityBenefits := ss.line6b }
  let r2 := Form1040.form1040 slots2
  let sl := StudentLoanAdjustment.studentLoanAdjustment
    { filingStatus := b.filingStatus,
      hadStudentLoanInterestPayments := i.hadStudentLoanInterestPayments,
      studentLoansQualify := i.studentLoansQualify,
      studentLoanInterestAmount := i.studentLoanInterestAmount,
      isMfjDependent := i.educator.isMfjDependent,
      eitherFilerIsClaimedAsDependent := i.eitherFilerIsClaimedAsDependent,
      totalIncome := r2.totalIncome,
      adjustmentsToIncomeExcludingStudentLoanInterest :=
        edu.educatorExpensesAdjustment + b.hsaTotalDeductibleAmount }
  -- pass 3: add the student loan adjustment
  let r3 := Form1040.form1040
    { slots2 with studentLoanInterestAdjustmentAmount := sl.studentLoanInterestAdjustmentAmount }
  { form1040 := r3
    unemployment := unemp
    misc := misc
    retirement := ret
    socialSecurity := ss
    educator := edu
    studentLoan := sl
    estimated := est
    unsupported :=
      r3.unsupported || unemp.unsupported || misc.unsupported || ret.unsupported || est.unsupported }

/-! ### Unit tests

A single filer with a $50,000 W-2 (as in `UsTax/Form1040.lean`'s `TestSingle50k`),
then one module at a time. The strict `form1040` is unchanged: the same return with
all module inputs empty reproduces its numbers. -/

private def w2 (wages : Int) (withholding : Int := 0) : FormW2s.FormW2 :=
  { writableWages := wages, writableFederalWithholding := withholding }

private def mk (b : Form1040.Form1040In) : Form1040FullIn := { base := b }

private def single50k : Form1040.Form1040In := Form1040.run [w2 5_000_000]

-- No module input: identical to the strict port.
#guard (form1040Full (mk single50k)).form1040.totalTax == 401_900
#guard (form1040Full (mk single50k)).form1040.balanceDue == 401_900
#guard (form1040Full (mk single50k)).unsupported == (Form1040.form1040 single50k).unsupported

-- Unemployment $3,000 with $300 withheld: line 8 and line 25b.
private def withG := form1040Full
  { mk single50k with form1099Gs := [{ amount := 300_000, writableFederalTaxWithheld := 30_000 }] }
#guard withG.form1040.otherIncome == 300_000
#guard withG.form1040.totalIncome == 5_300_000
#guard withG.form1040.form1099Withholding == 30_000
#guard !withG.unsupported

-- Alaska PFD $1,702: line 8g.
private def withPfd := form1040Full
  { mk single50k with form1099Miscs := [{ writableOtherIncome := 170_200 }] }
#guard withPfd.form1040.schedule1TotalOtherIncome == 170_200
#guard withPfd.form1040.totalIncome == 5_170_200

-- Pension fully taxable $10,000: line 5b, flows into line 9.
private def withR := form1040Full
  { mk single50k with
    form1099Rs := [{ writableGrossDistribution := 1_000_000, writableTaxableAmount := 1_000_000,
                     writableFederalWithholding := 100_000 }] }
#guard withR.form1040.totalIncome == 6_000_000
#guard withR.form1040.form1099Withholding == 100_000
#guard !withR.unsupported

-- Social Security: single, $24,000 benefits, $30,000 wages (test_social_security: 85% tier).
private def withSs := form1040Full
  { mk (Form1040.run [w2 3_000_000]) with socialSecurityNetBenefits := [2_400_000] }
#guard withSs.socialSecurity.line6b == 1_130_000
#guard withSs.form1040.totalIncome == 4_130_000

-- Educator $300 and student loan $2,500 at MAGI below the phase-out.
private def withAdj := form1040Full
  { mk single50k with
    educator := { wasK12Educators := .tpDid, primaryEducatorExpensesWritable := 45_000 },
    hadStudentLoanInterestPayments := true, studentLoansQualify := true,
    studentLoanInterestAmount := 300_000 }
#guard withAdj.form1040.adjustmentsToIncome == 280_000
#guard withAdj.form1040.agi == 4_720_000
#guard withAdj.educator.educatorExpensesAdjustment == 30_000
#guard withAdj.studentLoan.studentLoanInterestAdjustmentAmount == 250_000

-- Estimated payments $500.49 become $500 on line 26 and in total payments.
private def withEst := form1040Full
  { mk single50k with
    estimated :=
      { paidEstimatedTaxesOrFromLastYear := true, estimatedTaxPaymentWritable := 50_049,
        paidEstimatedTaxesOrFromLastYearUnderDifferentName := false,
        paidEstimatedTaxesWithFormerSpouse := .neither } }
#guard withEst.form1040.totalPayments == 50_000
#guard withEst.form1040.balanceDue == 351_900

-- A module knockout reaches the union.
#guard (form1040Full { mk single50k with
  form1099Gs := [{ amount := 100_000, stateIsDifferentState := true }] }).unsupported

end UsTax.Form1040Full
