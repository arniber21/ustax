import UsTax.Spec.Rounding
import UsTax.Interest
import UsTax.FormW2s
import UsTax.SocialSecurity
import UsTax.EducatorAdjustment
import UsTax.StudentLoanAdjustment

/-!
# Spec: reading the statutory quantities off the calculator's inputs (issue #64)

The module specs (`Spec/Interest.lean`, `Spec/FormW2.lean`, ...) take plain
amounts. The theorems apply them to the calculator's input records; these
small functions say which input fields those amounts are. They are part of
the statements, so they are here, reviewed with the specs, and not in the
proof files. Imports the calculator's modules for their input **types** only.
-/

namespace UsTax.Spec

open Interest FormW2s SocialSecurity EducatorAdjustment StudentLoanAdjustment

/-- The taxable interest of one report: with a Form 1099-INT, box 1 plus box 3
(interest on U.S. savings bonds and Treasury obligations, taxable federally);
without one, the amount the filer typed. -/
def reportTaxableInterest (r : InterestReport) : Int :=
  if r.has1099 then r.writable1099Amount + r.writableInterestOnGovernmentBonds else r.no1099Amount

/-- One box of the W-2s of one filer, each rounded to the dollar. -/
def filerBox (role : FilerRole) (box : FormW2 → Int) (w2s : List FormW2) : List Int :=
  (w2s.filter (·.filer == role)).map (fun w => roundToDollar (box w))

/-- IRC 86(b)(2): modified AGI, from the worksheet inputs (lines 1z, 2b, 3b,
4b, 5b, 7 and 8 of Form 1040, plus tax-exempt interest line 2a, less the
Schedule 1 adjustments other than student loan interest). -/
def ssModifiedAgi (i : SocialSecurityIn) : Int :=
  i.line1z + i.line2b + i.line3b + i.line4b + i.line5b + i.line7CapitalGains + i.line8OtherIncome +
    i.line2a - i.adjustmentsExcludingStudentLoanInterest

/-- The taxpayer was an eligible educator. -/
def tpIsEducator (o : K12EducatorOptions) : Bool := o == .tpDid || o == .bothDid

/-- The spouse was an eligible educator. -/
def spouseIsEducator (o : K12EducatorOptions) : Bool := o == .spouseDid || o == .bothDid

/-- Student loan interest can be deducted at all: qualifying interest was paid
and nobody is a dependent (IRC 221(c), 221(d)). -/
def studentLoanEligible (i : StudentLoanAdjustmentIn) : Bool :=
  i.hadStudentLoanInterestPayments && i.studentLoansQualify &&
    !i.eitherFilerIsClaimedAsDependent && !i.isMfjDependent

/-- A 1099-INT with $500.51 in box 1 and $20 in box 3: $520.51 of taxable
interest; the amount typed without a 1099 ($99) is ignored. -/
example :
    reportTaxableInterest
      { has1099 := true, writable1099Amount := 500_51, writableInterestOnGovernmentBonds := 20_00,
        no1099Amount := 99_00 } = 520_51 := by
  decide

end UsTax.Spec
