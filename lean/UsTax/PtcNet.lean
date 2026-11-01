import UsTax.Money
import UsTax.Types
import UsTax.TaxRates

/-!
# Premium tax credit, part 3: net PTC, repayment limitation, routing (Form 8962 lines 26 to 29)

Lean implementation of `catala/ptc_net.catala_en` (module `Ptc_net`, scope `NetPtc`), written by
hand from the Catala source under strategy (c) of `docs/catala-to-lean.md`, in the order of the
Catala file; the code that runs. Law: 26 U.S.C. § 36B(f)(2) (`sources/statute/irc-36B.html`),
Instructions for Form 8962 (2024) pp 16 to 17 (lines 26 to 29, Table 5). Issue #47.

| Catala (`Ptc_net`)                         | Lean (`UsTax.PtcNet`)                         |
|--------------------------------------------|-----------------------------------------------|
| `ptc_repayment_limit_under_200_single` ... | `ptcRepaymentLimitUnder200Single` ...         |
| `ptc_repayment_percent_first_step` ...     | `ptcRepaymentPercentFirstStep` ...            |
| `scope NetPtc`                             | `NetPtcIn` → `NetPtcOut` (`netPtc`)           |
| `line28` (Table 5)                         | `line28` (`repaymentLimitation`)              |

Money is `Int` cents, line 5 is a `Rat`. Line 28 is given as a separate function
(`repaymentLimitation`) so that the lemmas can name it. A zero line 28 stands for a blank line
(no limitation); the tax family of size zero keeps Direct File's workaround (line 28 `$0`, so all
of line 27 is repaid), as in Catala.
-/

namespace UsTax.PtcNet

open TaxRates (usd)

/-- Table 5, line 5 less than 200, Single: $375. -/
def ptcRepaymentLimitUnder200Single : Int := usd 375
/-- Table 5, line 5 less than 200, any other filing status: $750. -/
def ptcRepaymentLimitUnder200Other : Int := usd 750
/-- Table 5, at least 200 but less than 300, Single: $950. -/
def ptcRepaymentLimitUnder300Single : Int := usd 950
/-- Table 5, at least 200 but less than 300, other: $1,900. -/
def ptcRepaymentLimitUnder300Other : Int := usd 1_900
/-- Table 5, at least 300 but less than 400, Single: $1,575. -/
def ptcRepaymentLimitUnder400Single : Int := usd 1_575
/-- Table 5, at least 300 but less than 400, other: $3,150. -/
def ptcRepaymentLimitUnder400Other : Int := usd 3_150
/-- Table 5: the first step, 200 percent. -/
def ptcRepaymentPercentFirstStep : Rat := 200
/-- Table 5: the second step, 300 percent. -/
def ptcRepaymentPercentSecondStep : Rat := 300
/-- Table 5: no limitation at 400 percent or more. -/
def ptcRepaymentPercentNoLimit : Rat := 400

/-- Inputs of `NetPtc`. -/
structure NetPtcIn where
  filingStatus : FilingStatus
  /-- Form 8962 line 5. -/
  householdIncomeAsPercent : Rat
  taxFamilySizeIsZero : Bool
  /-- Form 8962 line 24. -/
  totalPtcAmountAllowed : Int
  /-- Form 8962 line 25. -/
  totalAptcAmountTaken : Int
  deriving Repr

/-- Outputs of `NetPtc`. -/
structure NetPtcOut where
  netPtcAmount : Int
  /-- Form 8962 line 26. -/
  line26 : Int
  /-- Form 8962 line 27. -/
  line27 : Int
  /-- Form 8962 line 28 (`$0` stands for a blank line). -/
  line28 : Int
  /-- Form 8962 line 29. -/
  line29 : Int
  /-- Schedule 3 line 9. -/
  netPtcCredit : Int
  /-- Schedule 2 line 1a. -/
  excessAptcRepayment : Int
  deriving Repr

/-- Catala `line28`: Table 5 for the filing status and line 5; `$0` for an empty tax family and
at 400 percent or more. -/
def repaymentLimitation (fs : FilingStatus) (percent : Rat) (taxFamilySizeIsZero : Bool) : Int :=
  let single := decide (fs = .single)
  if taxFamilySizeIsZero then 0
  else if percent < ptcRepaymentPercentFirstStep then
    (if single then ptcRepaymentLimitUnder200Single else ptcRepaymentLimitUnder200Other)
  else if percent < ptcRepaymentPercentSecondStep then
    (if single then ptcRepaymentLimitUnder300Single else ptcRepaymentLimitUnder300Other)
  else if percent < ptcRepaymentPercentNoLimit then
    (if single then ptcRepaymentLimitUnder400Single else ptcRepaymentLimitUnder400Other)
  else 0

/-- Catala `scope NetPtc`, definition by definition. -/
def netPtc (i : NetPtcIn) : NetPtcOut :=
  let net := i.totalPtcAmountAllowed - i.totalAptcAmountTaken
  let line26 := if net ≥ 0 then net else 0
  let line27 := if net < 0 then -net else 0
  let line28 := repaymentLimitation i.filingStatus i.householdIncomeAsPercent i.taxFamilySizeIsZero
  let line29 := if line28 = 0 then line27 else if line27 < line28 then line27 else line28
  { netPtcAmount := net, line26, line27, line28, line29
    netPtcCredit := line26, excessAptcRepayment := line29 }

/-! ### Unit tests: every assertion of `catala/tests/test_ptc_net.catala_en` -/

/-- Catala test helper `Excess2000`: line 24 $3,000, line 25 $5,000; the repayment. -/
def excess2000 (fs : FilingStatus) (percent : Rat) : Int :=
  (netPtc { filingStatus := fs, householdIncomeAsPercent := percent, taxFamilySizeIsZero := false
            totalPtcAmountAllowed := 300_000, totalAptcAmountTaken := 500_000 }).excessAptcRepayment

private def caseOf (fs : FilingStatus) (p : Rat) (allowed taken : Int) (zero := false) : NetPtcOut :=
  netPtc { filingStatus := fs, householdIncomeAsPercent := p, taxFamilySizeIsZero := zero
           totalPtcAmountAllowed := allowed, totalAptcAmountTaken := taken }

-- TestSingleBands
#guard excess2000 .single 190 == 37_500
#guard excess2000 .single 250 == 95_000
#guard excess2000 .single 350 == 157_500
#guard excess2000 .single 400 == 200_000
#guard excess2000 .single 401 == 200_000
#guard excess2000 .single 190 != 200_000
#guard excess2000 .single 190 != 75_000
#guard excess2000 .single 250 != 190_000
#guard excess2000 .single 350 != 315_000
-- TestOtherBands
#guard excess2000 .marriedFilingJointly 190 == 75_000
#guard excess2000 .marriedFilingSeparately 250 == 190_000
#guard excess2000 .headOfHousehold 350 == 200_000
#guard excess2000 .qualifyingSurvivingSpouse 100 == 75_000
#guard excess2000 .marriedFilingJointly 350 == 200_000
#guard excess2000 .headOfHousehold 400 == 200_000
-- TestBandEdges
#guard (caseOf .single 200 0 500_000).line28 == 95_000
#guard (caseOf .single 200 0 500_000).excessAptcRepayment == 95_000
#guard (caseOf .single 300 0 500_000).line28 == 157_500
#guard (caseOf .single 399 0 500_000).line28 == 157_500
#guard (caseOf .single 150 10_000 30_000).line27 == 20_000
#guard (caseOf .single 150 10_000 30_000).excessAptcRepayment == 20_000
#guard (caseOf .single 150 10_000 30_000).netPtcCredit == 0
-- TestNetPositive
private def pos := caseOf .single 190 480_000 180_000
#guard pos.netPtcAmount == 300_000
#guard pos.line26 == 300_000
#guard pos.netPtcCredit == 300_000
#guard pos.line27 == 0
#guard pos.excessAptcRepayment == 0
#guard pos.netPtcCredit != 0
#guard pos.excessAptcRepayment != 300_000
-- TestNetZero
#guard (caseOf .marriedFilingJointly 250 200_000 200_000).netPtcCredit == 0
#guard (caseOf .marriedFilingJointly 250 200_000 200_000).excessAptcRepayment == 0
-- TestFamilySizeZero
#guard (caseOf .single 0 0 200_000 (zero := true)).line28 == 0
#guard (caseOf .single 0 0 200_000 (zero := true)).excessAptcRepayment == 200_000

end UsTax.PtcNet
