import UsTax.Money
import UsTax.Lists
import UsTax.Types
import UsTax.Params2024

/-!
# Taxable interest: Form 1040 lines 2a, 2b and 25b part, Schedule B (issue #43)

Lean implementation of `catala/interest.catala_en` (module `Interest`, scopes
`InterestReportFacts` and `Interest`), written by hand from the Catala source
under strategy (c) of `docs/catala-to-lean.md`; the code that runs.

| Catala (`Interest`)                  | Lean (`UsTax.Interest`)                         |
|--------------------------------------|-------------------------------------------------|
| `structure InterestReport`           | `InterestReport` (fields in lower camel case)   |
| `scope InterestReportFacts`          | `InterestReportFacts` (`interestReportFacts : InterestReport → InterestReportFacts`) |
| `scope Interest` (inputs/outputs)    | `InterestIn` → `InterestOut` (`interest`)       |
| `facts` (internal)                   | `facts := reports.map interestReportFacts`      |

Money is `Int` cents; `R.round_dollar` is `Money.roundDollar`. The Schedule B
branch of `interest_income` (quirk Q-R1) is reproduced exactly.
-/

namespace UsTax.Interest

open Money

/-- One entry of DF `/interestReports` (Catala `InterestReport`). Cents. -/
structure InterestReport where
  /-- Catala input `filer`. -/
  filer : FilerRole := .primaryFiler
  /-- Catala input `has_1099`. -/
  has1099 : Bool := false
  /-- Catala input `no_1099_amount`. -/
  no1099Amount : Int := 0
  /-- Catala input `writable_1099_amount`. -/
  writable1099Amount : Int := 0
  /-- Catala input `writable_early_withdrawl_penalty_amount`. -/
  writableEarlyWithdrawlPenaltyAmount : Int := 0
  /-- Catala input `writable_interest_on_government_bonds`. -/
  writableInterestOnGovernmentBonds : Int := 0
  /-- Catala input `writable_tax_withheld`. -/
  writableTaxWithheld : Int := 0
  /-- Catala input `writable_foreign_tax_paid`. -/
  writableForeignTaxPaid : Int := 0
  /-- Catala input `writable_tax_exempt_interest`. -/
  writableTaxExemptInterest : Int := 0
  /-- Catala input `writable_specified_private_activity_bond_interest`. -/
  writableSpecifiedPrivateActivityBondInterest : Int := 0
  /-- Catala input `writable_market_discount`. -/
  writableMarketDiscount : Int := 0
  /-- Catala input `writable_bond_premium`. -/
  writableBondPremium : Int := 0
  /-- Catala input `writable_bond_premium_on_treasury_obligations`. -/
  writableBondPremiumOnTreasuryObligations : Int := 0
  /-- Catala input `writable_bond_premium_on_tax_exempt_bond`. -/
  writableBondPremiumOnTaxExemptBond : Int := 0
  /-- Catala input `state_is_different_state`. -/
  stateIsDifferentState : Bool := false
  /-- Catala input `writable_state_tax_withheld`. -/
  writableStateTaxWithheld : Int := 0
  /-- Catala input `facta_filing_required`. -/
  factaFilingRequired : Bool := false

/-- Outputs of `InterestReportFacts`. -/
structure InterestReportFacts where
  /-- Catala field `form_1099_amount`. -/
  form1099Amount : Int
  /-- Catala field `interest_on_government_bonds`. -/
  interestOnGovernmentBonds : Int
  /-- Catala field `taxable_interest`. -/
  taxableInterest : Int
  /-- Catala field `rounded_taxable_interest`. -/
  roundedTaxableInterest : Int
  /-- Catala field `tax_exempt_interest`. -/
  taxExemptInterest : Int
  /-- Catala field `tax_withheld`. -/
  taxWithheld : Int
  /-- Catala field `foreign_tax_paid`. -/
  foreignTaxPaid : Int
  /-- Catala field `early_withdrawl_penalty_amount`. -/
  earlyWithdrawlPenaltyAmount : Int
  /-- Catala field `bond_boxes_9_to_13`. -/
  bondBoxes9To13 : Int
  /-- Catala field `state_tax_withheld`. -/
  stateTaxWithheld : Int
  /-- Catala field `has_state_tax_withheld`. -/
  hasStateTaxWithheld : Bool
  /-- Catala field `has_knockout_withholding_in_different_state`. -/
  hasKnockoutWithholdingInDifferentState : Bool
  /-- Catala field `has_required_facta_filing`. -/
  hasRequiredFactaFiling : Bool

/-- Catala `scope InterestReportFacts`. Boxes 3, 4, 6 and 8 count only with a
Form 1099-INT; box 2 is not gated. -/
def interestReportFacts (report : InterestReport) : InterestReportFacts :=
  let form1099Amount := report.writable1099Amount
  let interestOnGovernmentBonds :=
    if report.has1099 then report.writableInterestOnGovernmentBonds else 0
  let taxableInterest :=
    if report.has1099 then interestOnGovernmentBonds + form1099Amount else report.no1099Amount
  let stateTaxWithheld := report.writableStateTaxWithheld
  { form1099Amount := form1099Amount
    interestOnGovernmentBonds := interestOnGovernmentBonds
    taxableInterest := taxableInterest
    roundedTaxableInterest := roundDollar taxableInterest
    taxExemptInterest := if report.has1099 then report.writableTaxExemptInterest else 0
    taxWithheld := roundDollar (if report.has1099 then report.writableTaxWithheld else 0)
    foreignTaxPaid := if report.has1099 then report.writableForeignTaxPaid else 0
    earlyWithdrawlPenaltyAmount := report.writableEarlyWithdrawlPenaltyAmount
    bondBoxes9To13 :=
      report.writableSpecifiedPrivateActivityBondInterest + report.writableMarketDiscount +
        report.writableBondPremium + report.writableBondPremiumOnTreasuryObligations +
        report.writableBondPremiumOnTaxExemptBond
    stateTaxWithheld := stateTaxWithheld
    hasStateTaxWithheld := decide (stateTaxWithheld > 0)
    hasKnockoutWithholdingInDifferentState := report.stateIsDifferentState
    hasRequiredFactaFiling := report.factaFilingRequired && report.has1099 }

/-- Inputs of `Interest`. -/
structure InterestIn where
  /-- Catala input `interest_reports`. -/
  interestReports : List InterestReport
  /-- Catala input `has_foreign_accounts_or_trusts`. -/
  hasForeignAccountsOrTrusts : Bool
  /-- Catala input `filing_status`. -/
  filingStatus : FilingStatus
  /-- DF `/agi` (Form 1040 line 11), cents. -/
  agi : Int
  /-- Catala input `flow_has_seen_deductions`. -/
  flowHasSeenDeductions : Bool

/-- Outputs of `Interest`. -/
structure InterestOut where
  /-- Catala output `requires_schedule_b`. -/
  requiresScheduleB : Bool
  /-- Form 1040 line 2b. -/
  interestIncome : Int
  /-- Form 1040 line 2a. -/
  taxExemptInterest : Int
  /-- The 1099-INT part of line 25b. -/
  totalTaxWithheld : Int
  /-- Catala output `has_interest_income`. -/
  hasInterestIncome : Bool
  /-- Catala output `ko_flow_knockout_has_early_withdrawl_penalty`. -/
  koFlowKnockoutHasEarlyWithdrawlPenalty : Bool
  /-- Catala output `ko_flow_knockout_has_bonds`. -/
  koFlowKnockoutHasBonds : Bool
  /-- Catala output `ko_flow_knockout_has_foreign_tax_paid`. -/
  koFlowKnockoutHasForeignTaxPaid : Bool
  /-- Catala output `ko_flow_knockout_tax_exempt_interest`. -/
  koFlowKnockoutTaxExemptInterest : Bool
  /-- Catala output `ko_flow_knockout_state_tax_withheld`. -/
  koFlowKnockoutStateTaxWithheld : Bool
  /-- Catala output `ko_flow_knockout_withholding_unsupported_state`. -/
  koFlowKnockoutWithholdingUnsupportedState : Bool
  /-- Catala output `ko_has_required_facta_filings`. -/
  koHasRequiredFactaFilings : Bool
  /-- Catala output `ko_has_interest_income_and_agi_above_threshold_for_mfs`. -/
  koHasInterestIncomeAndAgiAboveThresholdForMfs : Bool
  /-- Catala output `ko_has_interest_income_and_agi_above_threshold_for_mfj_or_qss`. -/
  koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss : Bool
  /-- Catala output `ko_has_interest_income_and_agi_above_threshold_for_single_or_hoh`. -/
  koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh : Bool
  /-- Every knockout of this scope. -/
  unsupported : Bool

/-- Schedule B Part III (interest half): total taxable interest over $1,500, or
a foreign account or trust. DF `/requiresScheduleB`. -/
def requiresScheduleB (i : InterestIn) : Bool :=
  decide (sumBy (·.taxableInterest) (i.interestReports.map interestReportFacts) >
      Params.scheduleBInterestThreshold)
    || i.hasForeignAccountsOrTrusts

/-- Form 1040 line 2b. Quirk Q-R1: per-item rounded amounts are summed only when
Schedule B is required; otherwise the raw sum is rounded once. -/
def interestIncome (i : InterestIn) : Int :=
  let facts := i.interestReports.map interestReportFacts
  roundDollar
    (if requiresScheduleB i then sumBy (·.roundedTaxableInterest) facts
     else sumBy (·.taxableInterest) facts)

/-- Catala `scope Interest`. -/
def interest (i : InterestIn) : InterestOut :=
  let facts := i.interestReports.map interestReportFacts
  let interestIncome := interestIncome i
  let koEarly := decide (sumBy (·.earlyWithdrawlPenaltyAmount) facts > 0)
  let koBonds := decide (sumBy (·.bondBoxes9To13) facts > 0)
  let koForeign := facts.any fun f => decide (f.foreignTaxPaid ≠ 0)
  let koTaxExempt := facts.any fun f => decide (f.taxExemptInterest ≠ 0)
  let koState := facts.any (·.hasStateTaxWithheld)
  let koUnsupportedState := facts.any (·.hasKnockoutWithholdingInDifferentState)
  let koFacta := facts.any (·.hasRequiredFactaFiling)
  let koMfs :=
    i.flowHasSeenDeductions && i.filingStatus == .marriedFilingSeparately &&
      decide (interestIncome > 0) && decide (i.agi > Params.niitThresholdMarriedSeparate)
  let koJoint :=
    i.flowHasSeenDeductions &&
      (i.filingStatus == .marriedFilingJointly || i.filingStatus == .qualifyingSurvivingSpouse) &&
      decide (interestIncome > 0) &&
      decide (i.agi > Params.niitThresholdJointOrSurvivingSpouse)
  let koOther :=
    i.flowHasSeenDeductions &&
      (i.filingStatus == .single || i.filingStatus == .headOfHousehold) &&
      decide (interestIncome > 0) && decide (i.agi > Params.niitThresholdOther)
  { requiresScheduleB := requiresScheduleB i
    interestIncome := interestIncome
    taxExemptInterest := roundDollar (sumBy (·.taxExemptInterest) facts)
    totalTaxWithheld := sumBy (·.taxWithheld) facts
    hasInterestIncome := decide (interestIncome > 0)
    koFlowKnockoutHasEarlyWithdrawlPenalty := koEarly
    koFlowKnockoutHasBonds := koBonds
    koFlowKnockoutHasForeignTaxPaid := koForeign
    koFlowKnockoutTaxExemptInterest := koTaxExempt
    koFlowKnockoutStateTaxWithheld := koState
    koFlowKnockoutWithholdingUnsupportedState := koUnsupportedState
    koHasRequiredFactaFilings := koFacta
    koHasInterestIncomeAndAgiAboveThresholdForMfs := koMfs
    koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss := koJoint
    koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh := koOther
    unsupported :=
      koFacta || koEarly || koBonds || koForeign || koUnsupportedState || koState ||
      koMfs || koJoint || koOther || koTaxExempt }

/-! ### Unit tests: every assertion of `catala/tests/test_interest.catala_en` -/

private def mk (rs : List InterestReport) (fs : FilingStatus := .single) (agi : Int := 0)
    (foreign : Bool := false) (seen : Bool := true) : InterestOut :=
  interest { interestReports := rs, hasForeignAccountsOrTrusts := foreign, filingStatus := fs,
             agi := agi, flowHasSeenDeductions := seen }

private def box1 (amount : Int) : InterestReport := { has1099 := true, writable1099Amount := amount }

-- TestTotal1500NoScheduleBRoundsRawSum
private def t1500 := mk [box1 50049, box1 50049, box1 49902] (seen := false)
#guard !t1500.requiresScheduleB
#guard t1500.interestIncome == 150_000
#guard t1500.interestIncome != 149_900
#guard !t1500.unsupported

-- TestTotal1501ScheduleBSumsPerItemRounded
private def t1501 := mk [box1 50051, box1 50051, box1 50051] (seen := false)
#guard t1501.requiresScheduleB
#guard t1501.interestIncome == 150_300
#guard t1501.interestIncome != 150_200
#guard t1501.interestIncome != 150_153

-- TestForeignAccountsWith10RequiresScheduleB
#guard (mk [box1 1000] (foreign := true) (seen := false)).requiresScheduleB
#guard (mk [box1 1000] (foreign := true) (seen := false)).interestIncome == 1000

-- TestNoReports
private def none0 := mk [] (seen := false)
#guard !none0.requiresScheduleB
#guard none0.interestIncome == 0
#guard none0.taxExemptInterest == 0
#guard none0.totalTaxWithheld == 0
#guard !none0.hasInterestIncome
#guard !none0.unsupported

-- TestBoxesAndNo1099
private def boxes := mk [
  { has1099 := true, no1099Amount := 99900, writable1099Amount := 10020,
    writableInterestOnGovernmentBonds := 5040, writableTaxWithheld := 1250,
    writableTaxExemptInterest := 2050 },
  { has1099 := false, no1099Amount := 3010, writable1099Amount := 700,
    writableInterestOnGovernmentBonds := 700, writableTaxWithheld := 700,
    writableForeignTaxPaid := 700, writableTaxExemptInterest := 700 }] (seen := false)
#guard !boxes.requiresScheduleB
#guard boxes.interestIncome == 18_100
#guard boxes.taxExemptInterest == 2_100
#guard boxes.totalTaxWithheld == 1_300
#guard boxes.koFlowKnockoutTaxExemptInterest
#guard boxes.unsupported

-- Knockouts: one report, "KnockoutCase"
private def ko (penalty bonds foreign stateTax : Int) (differentState facta : Bool)
    (interest : Int) (fs : FilingStatus) (agi : Int) (seen : Bool) : InterestOut :=
  mk [{ has1099 := true, writable1099Amount := interest,
        writableEarlyWithdrawlPenaltyAmount := penalty,
        writableSpecifiedPrivateActivityBondInterest := bonds,
        writableForeignTaxPaid := foreign, writableStateTaxWithheld := stateTax,
        stateIsDifferentState := differentState, factaFilingRequired := facta }]
    fs agi false seen

private def koPenalty := ko 500 0 0 0 false false 10000 .single 5000000 true
#guard koPenalty.koFlowKnockoutHasEarlyWithdrawlPenalty
#guard koPenalty.unsupported
#guard !koPenalty.koFlowKnockoutHasBonds

private def koBonds := ko 0 100 0 0 false false 10000 .single 5000000 true
#guard koBonds.koFlowKnockoutHasBonds
#guard koBonds.unsupported

private def koForeign := ko 0 0 200 0 false false 10000 .single 5000000 true
#guard koForeign.koFlowKnockoutHasForeignTaxPaid
#guard koForeign.unsupported

private def koState := ko 0 0 0 300 false false 10000 .single 5000000 true
private def koState2 := ko 0 0 0 0 true false 10000 .single 5000000 true
#guard koState.koFlowKnockoutStateTaxWithheld
#guard !koState.koFlowKnockoutWithholdingUnsupportedState
#guard koState.unsupported
#guard koState2.koFlowKnockoutWithholdingUnsupportedState
#guard !koState2.koFlowKnockoutStateTaxWithheld
#guard koState2.unsupported

private def koFacta := ko 0 0 0 0 false true 10000 .single 5000000 true
#guard koFacta.koHasRequiredFactaFilings
#guard koFacta.unsupported

#guard !(ko 0 0 0 0 false false 10000 .single 5000000 true).unsupported

-- TestNiitThresholds
private def niit (fs : FilingStatus) (agi : Int) (interest : Int := 10000) (seen : Bool := true) :=
  ko 0 0 0 0 false false interest fs agi seen
#guard !(niit .single 20_000_000).unsupported
#guard (niit .single 20_000_100).koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh
#guard (niit .single 20_000_100).unsupported
#guard !(niit .single 20_000_100 (seen := false)).unsupported
#guard (niit .marriedFilingJointly 25_000_100).koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss
#guard !(niit .marriedFilingJointly 25_000_000).unsupported
#guard (niit .marriedFilingSeparately 12_500_100).koHasInterestIncomeAndAgiAboveThresholdForMfs
#guard !(niit .marriedFilingSeparately 12_500_000).unsupported
#guard (niit .headOfHousehold 20_000_100).koHasInterestIncomeAndAgiAboveThresholdForSingleOrHoh
#guard (niit .qualifyingSurvivingSpouse 25_000_100).koHasInterestIncomeAndAgiAboveThresholdForMfjOrQss
#guard !(niit .single 90_000_000 (interest := 0)).unsupported

end UsTax.Interest
