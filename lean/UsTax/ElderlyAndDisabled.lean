import UsTax.Money
import UsTax.Types
import UsTax.ParamsCredits

/-!
# Credit for the elderly or the disabled, Schedule R lines 1 to 22 (issue #46)

Lean implementation of `catala/elderly_and_disabled.catala_en` (module
`Elderly_and_disabled`, scopes `EdcFiler` and `ScheduleR`, struct `DisabilityAnswers`),
written by hand from the Catala source under strategy (c) of `docs/catala-to-lean.md`, in the
order of the Catala file; the code that runs. Law: IRC 22, Schedule R (2024) and its
instructions (`i1040sr--2024.pdf` pp R-1 to R-7).

| Catala (`Elderly_and_disabled`)  | Lean (`UsTax.ElderlyAndDisabled`)                      |
|----------------------------------|--------------------------------------------------------|
| struct `DisabilityAnswers`       | `DisabilityAnswers`                                    |
| `scope EdcFiler`                 | `EdcFilerIn` → `EdcFilerOut` (`edcFiler`)              |
| `scope ScheduleR`                | `ScheduleRIn` → `ScheduleROut` (`scheduleR`)           |
| `Money.positive`, `Money.min`    | `Money.positive`, `Money.min`                          |
| `R.round_dollar`                 | `Money.roundDollar`                                    |

Money is `Int` cents. Conditions are `Bool`. `DF-BUG(13)` is reproduced as in Catala: line 13b
is the self-reported figure only (Lean follows Catala, not Direct File).
-/

namespace UsTax.ElderlyAndDisabled

open Money

/-- Catala struct `DisabilityAnswers`: the answers about disability for one filer. -/
structure DisabilityAnswers where
  isRetiredOnPermOrTotalDisability : Bool
  employerHasMandatoryRetirementAge : Bool
  hasMetEmployerMandatoryRetirementAge : Bool
  arePaymentsTaxableDisabilityIncome : Bool
  writableTotalTaxableDisabilityAmount : Int
  hasW2Wages : Bool

/-! ### Scope `EdcFiler`: one filer's disability facts (IRC 22(b)(2)) -/

/-- Inputs of `EdcFiler`. -/
structure EdcFilerIn where
  countsForReturn : Bool
  maybeEligibleForCredit : Bool
  age65OrOlder : Bool
  answers : DisabilityAnswers

/-- Outputs of `EdcFiler`. -/
structure EdcFilerOut where
  hasDisabilityIncome : Bool
  hasTaxableDisabilityPayments : Bool
  totalTaxableDisabilityAmount : Int
  isQualifiedThroughDisability : Bool

/-- Catala `scope EdcFiler`. -/
def edcFiler (i : EdcFilerIn) : EdcFilerOut :=
  let a := i.answers
  let hasDisabilityIncome :=
    i.countsForReturn && i.maybeEligibleForCredit && !i.age65OrOlder && a.hasW2Wages &&
      a.isRetiredOnPermOrTotalDisability &&
      (!a.employerHasMandatoryRetirementAge || !a.hasMetEmployerMandatoryRetirementAge)
  let hasTaxable := hasDisabilityIncome && a.arePaymentsTaxableDisabilityIncome
  let total := if hasTaxable then a.writableTotalTaxableDisabilityAmount else 0
  { hasDisabilityIncome, hasTaxableDisabilityPayments := hasTaxable
    totalTaxableDisabilityAmount := total
    isQualifiedThroughDisability := hasTaxable && decide (total ≠ 0) }

/-! ### Scope `ScheduleR` -/

/-- Inputs of `ScheduleR`. -/
structure ScheduleRIn where
  filingStatus : FilingStatus
  /-- Only read for married filing separately. -/
  livedApartAllYear : Bool
  primaryAge65OrOlder : Bool
  /-- Read only on a joint return. -/
  secondaryAge65OrOlder : Bool
  primaryAnswers : DisabilityAnswers
  secondaryAnswers : DisabilityAnswers
  /-- Form 1040 line 11 (Schedule R line 14). -/
  agi : Int
  /-- Schedule R line 13a. -/
  nonTaxableSocialSecurityBenefits : Int
  /-- Schedule R line 13b, as the filer reports it. -/
  selfReportedNonTaxablePayments : Int
  /-- Credit Limit Worksheet line 3: Form 1040 line 18 less Schedule 3 lines 1, 2 and 6l. -/
  creditLimitWorksheetLine3 : Int

/-- Outputs of `ScheduleR` (the Catala `internal` variables are included as fields too). -/
structure ScheduleROut where
  primary : EdcFilerOut
  secondary : EdcFilerOut
  isMfj : Bool
  isMfs : Bool
  isSingleHohQss : Bool
  primaryIs65 : Bool
  secondaryIs65 : Bool
  numberQualifiedThroughDisability : Int
  mfjAndOnlyOneQualified : Bool
  relaxedAgiLimit : Int
  relaxedNonTaxableLimit : Int
  atLeastOneTpIsUnder65 : Bool
  maybeEligibleForCredit : Bool
  edcLine1 : Bool
  edcLine2 : Bool
  edcLine3 : Bool
  edcLine4 : Bool
  edcLine5 : Bool
  edcLine6 : Bool
  edcLine7 : Bool
  edcLine8 : Bool
  edcLine9 : Bool
  /-- Line 10. -/
  edcFilingStatusAmt : Int
  /-- Line 11. -/
  statusBasedDisabilityIncome : Int
  /-- Line 12. -/
  lesserOfFilingStatusAmountAndTaxableDisabilityIncome : Int
  /-- Line 13a. -/
  edcNonTaxableSocialSecurityAndRailroadBenefits : Int
  /-- Line 13b. -/
  edcNonTaxableIncomeNotIncludingSocialSecurityAndRrb : Int
  /-- Line 13c. -/
  edcTotalNonTaxableAmount : Int
  /-- Line 15. -/
  edcExemptionAmount : Int
  /-- Line 16. -/
  edcMagi : Int
  /-- Line 17. -/
  edcHalfMagi : Int
  /-- Line 18. -/
  edcAdjustedCreditAmount : Int
  /-- Line 19. -/
  edcNetCreditAmount : Int
  /-- Line 20. -/
  netEdcAmount : Int
  /-- Line 21. -/
  edcTaxLiabilityLimit : Int
  edcAgiLimit : Int
  edcNonTaxableLimit : Int
  isQualifiedBasedOnAgeOrDisability : Bool
  qualifiedForCreditForElderlyAndDisabled : Bool
  /-- Line 22; Schedule 3 line 6d. -/
  totalEdc : Int
  isReceivingEdc : Bool

/-- Catala `scope ScheduleR`, definition by definition. -/
def scheduleR (i : ScheduleRIn) : ScheduleROut :=
  let isMfj := decide (i.filingStatus = .marriedFilingJointly)
  let isMfs := decide (i.filingStatus = .marriedFilingSeparately)
  let isSingleHohQss := !(isMfj || isMfs)
  let primaryIs65 := i.primaryAge65OrOlder
  let secondaryIs65 := isMfj && i.secondaryAge65OrOlder
  -- Catala `maybe_eligible_for_credit` (read by both filers)
  let relaxedAgiLimit :=
    if isMfj then Params.edcAgiLimitJointBothQualified
    else if isMfs then Params.edcAgiLimitMarriedSeparate
    else Params.edcAgiLimitSingleHohQss
  let relaxedNonTaxableLimit :=
    if isMfj then Params.edcInitialAmountJointBothQualified
    else if isMfs then Params.edcInitialAmountMarriedSeparate
    else Params.edcInitialAmountSingleOrOneQualified
  let atLeastOneTpIsUnder65 :=
    if isMfj then !i.primaryAge65OrOlder || !i.secondaryAge65OrOlder else !i.primaryAge65OrOlder
  let maybeEligible :=
    decide (i.creditLimitWorksheetLine3 > 0) &&
      (primaryIs65 || secondaryIs65 ||
        (atLeastOneTpIsUnder65 && (i.primaryAnswers.hasW2Wages || i.secondaryAnswers.hasW2Wages))) &&
      decide (i.agi < relaxedAgiLimit) &&
      decide (i.nonTaxableSocialSecurityBenefits < relaxedNonTaxableLimit) &&
      (!isMfs || i.livedApartAllYear)
  let primary := edcFiler {
    countsForReturn := true, maybeEligibleForCredit := maybeEligible,
    age65OrOlder := i.primaryAge65OrOlder, answers := i.primaryAnswers }
  let secondary := edcFiler {
    countsForReturn := isMfj, maybeEligibleForCredit := maybeEligible,
    age65OrOlder := i.secondaryAge65OrOlder, answers := i.secondaryAnswers }
  let numberQualified : Int :=
    (if primary.isQualifiedThroughDisability then 1 else 0) +
      (if secondary.isQualifiedThroughDisability then 1 else 0)
  -- Part I boxes
  let line1 := isSingleHohQss && primaryIs65
  let line2 := isSingleHohQss && primary.isQualifiedThroughDisability
  let line3 := isMfj && primaryIs65 && secondaryIs65
  let line4 := isMfj && !primaryIs65 && !secondaryIs65 && decide (numberQualified = 1)
  let line5 := isMfj && !primaryIs65 && !secondaryIs65 && decide (numberQualified = 2)
  let line6 := isMfj &&
    ((primaryIs65 && !secondaryIs65 && secondary.isQualifiedThroughDisability) ||
      (secondaryIs65 && !primaryIs65 && primary.isQualifiedThroughDisability))
  let line7 := isMfj &&
    ((primaryIs65 && !secondaryIs65 && !secondary.isQualifiedThroughDisability) ||
      (secondaryIs65 && !primaryIs65 && !primary.isQualifiedThroughDisability))
  let line8 := isMfs && primaryIs65
  let line9 := isMfs && !primaryIs65 && primary.isQualifiedThroughDisability
  -- lines 10 to 12
  let line10 :=
    if line1 || line2 || line4 || line7 then Params.edcInitialAmountSingleOrOneQualified
    else if line3 || line5 || line6 then Params.edcInitialAmountJointBothQualified
    else if line8 || line9 then Params.edcInitialAmountMarriedSeparate
    else 0
  let line11 :=
    if line6 then
      (if primary.isQualifiedThroughDisability
       then primary.totalTaxableDisabilityAmount + Params.edcInitialAmountSingleOrOneQualified
       else secondary.totalTaxableDisabilityAmount + Params.edcInitialAmountSingleOrOneQualified)
    else if line2 || line9 then primary.totalTaxableDisabilityAmount
    else if line4 then
      (if primary.isQualifiedThroughDisability
       then primary.totalTaxableDisabilityAmount
       else secondary.totalTaxableDisabilityAmount)
    else if line5 then primary.totalTaxableDisabilityAmount + secondary.totalTaxableDisabilityAmount
    else 0
  let line12 := if decide (numberQualified > 0) then Money.min line10 line11 else line10
  -- line 13
  let line13a := i.nonTaxableSocialSecurityBenefits
  -- DF-BUG(13): the self-reported figure only
  let line13b := i.selfReportedNonTaxablePayments
  let line13c := roundDollar (positive (line13a + line13b))
  -- lines 15 to 18
  let line15 :=
    if line8 || line9 then Params.edcAgiThresholdMarriedSeparate
    else if line1 || line2 then Params.edcAgiThresholdSingle
    else if line3 || line4 || line5 || line6 || line7 then Params.edcAgiThresholdJoint
    else 0
  let line16 := roundDollar (positive (i.agi - line15))
  let line17 := roundDollar (mulRate line16 Params.edcAgiReductionRate)
  let line18 := line13c + line17
  -- lines 19 to 22
  let line19 := positive (line12 - line18)
  let line20 := roundDollar (mulRate line19 Params.edcCreditRate)
  let line21 := positive i.creditLimitWorksheetLine3
  let qualifiedThrough (f : EdcFilerOut) (is65 : Bool) : Int :=
    if is65 || f.isQualifiedThroughDisability then 1 else 0
  let mfjAndOnlyOne := isMfj &&
    decide (qualifiedThrough primary primaryIs65 + qualifiedThrough secondary secondaryIs65 = 1)
  let agiLimit :=
    if mfjAndOnlyOne then Params.edcAgiLimitJointOneQualified
    else if isMfj then Params.edcAgiLimitJointBothQualified
    else if isMfs then Params.edcAgiLimitMarriedSeparate
    else Params.edcAgiLimitSingleHohQss
  let nonTaxableLimit :=
    if mfjAndOnlyOne then Params.edcInitialAmountSingleOrOneQualified
    else if isMfj then Params.edcInitialAmountJointBothQualified
    else if isMfs then Params.edcInitialAmountMarriedSeparate
    else Params.edcInitialAmountSingleOrOneQualified
  let qualifiedAgeOrDisability := primaryIs65 || secondaryIs65 || decide (numberQualified > 0)
  let qualified :=
    decide (line21 > 0) && maybeEligible && qualifiedAgeOrDisability &&
      decide (i.agi < agiLimit) && decide (line19 > 0) && decide (line13c < nonTaxableLimit)
  let totalEdc := if qualified then Money.min line20 line21 else 0
  { primary, secondary, isMfj, isMfs, isSingleHohQss, primaryIs65, secondaryIs65
    numberQualifiedThroughDisability := numberQualified
    mfjAndOnlyOneQualified := mfjAndOnlyOne
    relaxedAgiLimit, relaxedNonTaxableLimit, atLeastOneTpIsUnder65
    maybeEligibleForCredit := maybeEligible
    edcLine1 := line1, edcLine2 := line2, edcLine3 := line3, edcLine4 := line4
    edcLine5 := line5, edcLine6 := line6, edcLine7 := line7, edcLine8 := line8
    edcLine9 := line9
    edcFilingStatusAmt := line10, statusBasedDisabilityIncome := line11
    lesserOfFilingStatusAmountAndTaxableDisabilityIncome := line12
    edcNonTaxableSocialSecurityAndRailroadBenefits := line13a
    edcNonTaxableIncomeNotIncludingSocialSecurityAndRrb := line13b
    edcTotalNonTaxableAmount := line13c, edcExemptionAmount := line15, edcMagi := line16
    edcHalfMagi := line17, edcAdjustedCreditAmount := line18, edcNetCreditAmount := line19
    netEdcAmount := line20, edcTaxLiabilityLimit := line21
    edcAgiLimit := agiLimit, edcNonTaxableLimit := nonTaxableLimit
    isQualifiedBasedOnAgeOrDisability := qualifiedAgeOrDisability
    qualifiedForCreditForElderlyAndDisabled := qualified
    totalEdc
    isReceivingEdc := qualified && decide (totalEdc > 0) }

/-! ### Unit tests: every assertion of `catala/tests/test_elderly_and_disabled.catala_en`

`run` is the Catala test helper `Run`: `pd` and `sd` say that the primary or secondary filer is
retired on permanent and total disability with taxable disability income `pinc` or `sinc` (and
has W-2 wages and no mandatory retirement age). -/

/-- The answers of the Catala test helper `Run` for one filer. -/
def runAnswers (d : Bool) (inc : Int) : DisabilityAnswers :=
  { isRetiredOnPermOrTotalDisability := d, employerHasMandatoryRetirementAge := false
    hasMetEmployerMandatoryRetirementAge := false, arePaymentsTaxableDisabilityIncome := d
    writableTotalTaxableDisabilityAmount := inc, hasW2Wages := d }

/-- The Catala test helper `Run`. -/
def run (fs : FilingStatus) (apart p65 s65 pd : Bool) (pinc : Int) (sd : Bool) (sinc agi ss o13b tax : Int) :
    ScheduleROut :=
  scheduleR { filingStatus := fs, livedApartAllYear := apart, primaryAge65OrOlder := p65
              secondaryAge65OrOlder := s65, primaryAnswers := runAnswers pd pinc
              secondaryAnswers := runAnswers sd sinc, agi, nonTaxableSocialSecurityBenefits := ss
              selfReportedNonTaxablePayments := o13b, creditLimitWorksheetLine3 := tax }

-- TestCases
private def c_single66_agi10000 := run .single false true false false 0 false 0 1000000 0 0 1000000
private def c_single66_tax_limited := run .single false true false false 0 false 0 1000000 0 0 50000
private def c_single66_agi17500 := run .single false true false false 0 false 0 1750000 0 0 1000000
private def c_single66_agi17499 := run .single false true false false 0 false 0 1749900 0 0 1000000
private def c_single66_agi17498 := run .single false true false false 0 false 0 1749800 0 0 1000000
private def c_single66_agi7500_full := run .single false true false false 0 false 0 750000 0 0 1000000
private def c_single66_no_tax := run .single false true false false 0 false 0 1000000 0 0 0
private def c_single66_ss1000 := run .single false true false false 0 false 0 1000000 100000 0 1000000
private def c_single66_ss5000 := run .single false true false false 0 false 0 0 500000 0 1000000
private def c_single66_ss4999 := run .single false true false false 0 false 0 0 499900 0 1000000
private def c_single66_13b := run .single false true false false 0 false 0 0 0 42500 1000000
private def c_mfj_both65_agi24000 := run .marriedFilingJointly false true true false 0 false 0 2400000 0 0 1000000
private def c_mfj_both65_agi25000 := run .marriedFilingJointly false true true false 0 false 0 2500000 0 0 1000000
private def c_mfj_both65_agi10000 := run .marriedFilingJointly false true true false 0 false 0 1000000 0 0 1000000
private def c_mfj_secondary65_only_box7 := run .marriedFilingJointly false false true false 0 false 0 1500000 0 0 1000000
private def c_mfj_one65_agi20000 := run .marriedFilingJointly false true false false 0 false 0 2000000 0 0 1000000
private def c_mfj_both_under65_nobody_disabled := run .marriedFilingJointly false false false false 0 false 0 500000 0 0 1000000
private def c_mfs65_apart_agi8000 := run .marriedFilingSeparately true true false false 0 false 0 800000 0 0 1000000
private def c_mfs65_together := run .marriedFilingSeparately false true false false 0 false 0 800000 0 0 1000000
private def c_mfs65_apart_agi12500 := run .marriedFilingSeparately true true false false 0 false 0 1250000 0 0 1000000
private def c_mfs_disabled_apart := run .marriedFilingSeparately true false false true 200000 false 0 600000 0 0 1000000
private def c_mfs_disabled_together := run .marriedFilingSeparately false false false true 200000 false 0 600000 0 0 1000000
private def c_jesse := run .single false false false true 1500000 false 0 1510000 70000 0 5100
private def c_single_disabled_small_income := run .single false false false true 300000 false 0 300000 0 0 1000000
private def c_mfj_box6 := run .marriedFilingJointly false true false false 0 true 400000 2000000 0 0 1000000
private def c_mfj_box6_primary_disabled := run .marriedFilingJointly false false true true 400000 false 0 2000000 0 0 1000000
private def c_mfj_box4 := run .marriedFilingJointly false false false true 300000 false 0 1200000 0 0 1000000
private def c_mfj_box5 := run .marriedFilingJointly false false false true 300000 true 600000 1200000 0 0 1000000
private def c_riley_parker := run .marriedFilingJointly false false false true 640000 true 170000 2935000 200000 0 1000000
private def c_riley_parker_agi24000 := run .marriedFilingJointly false false false true 640000 true 170000 2400000 200000 0 1000000
private def c_mfj_box4_no_tax := run .marriedFilingJointly false false false true 300000 false 0 1200000 0 0 0
private def c_hoh_70 := run .headOfHousehold false true false false 0 false 0 900000 0 0 1000000
#guard c_single66_agi10000.edcLine1 == true
#guard c_single66_agi10000.edcFilingStatusAmt == 500000
#guard c_single66_agi10000.edcMagi == 250000
#guard c_single66_agi10000.edcHalfMagi == 125000
#guard c_single66_agi10000.edcAdjustedCreditAmount == 125000
#guard c_single66_agi10000.edcNetCreditAmount == 375000
#guard c_single66_agi10000.netEdcAmount == 56300
#guard c_single66_agi10000.qualifiedForCreditForElderlyAndDisabled == true
#guard c_single66_agi10000.totalEdc == 56300
#guard c_single66_agi10000.isReceivingEdc == true
#guard c_single66_agi10000.edcAgiLimit == 1750000
#guard c_single66_tax_limited.netEdcAmount == 56300
#guard c_single66_tax_limited.edcTaxLiabilityLimit == 50000
#guard c_single66_tax_limited.totalEdc == 50000
#guard c_single66_agi17500.qualifiedForCreditForElderlyAndDisabled == false
#guard c_single66_agi17500.totalEdc == 0
#guard c_single66_agi17500.isReceivingEdc == false
#guard c_single66_agi17500.edcNetCreditAmount == 0
#guard c_single66_agi17499.edcHalfMagi == 500000
#guard c_single66_agi17499.edcNetCreditAmount == 0
#guard c_single66_agi17499.qualifiedForCreditForElderlyAndDisabled == false
#guard c_single66_agi17499.totalEdc == 0
#guard c_single66_agi17498.edcHalfMagi == 499900
#guard c_single66_agi17498.edcNetCreditAmount == 100
#guard c_single66_agi17498.netEdcAmount == 0
#guard c_single66_agi17498.qualifiedForCreditForElderlyAndDisabled == true
#guard c_single66_agi17498.totalEdc == 0
#guard c_single66_agi17498.isReceivingEdc == false
#guard c_single66_agi7500_full.edcHalfMagi == 0
#guard c_single66_agi7500_full.edcNetCreditAmount == 500000
#guard c_single66_agi7500_full.netEdcAmount == 75000
#guard c_single66_agi7500_full.totalEdc == 75000
#guard c_single66_no_tax.edcTaxLiabilityLimit == 0
#guard c_single66_no_tax.qualifiedForCreditForElderlyAndDisabled == false
#guard c_single66_no_tax.totalEdc == 0
#guard c_single66_ss1000.edcTotalNonTaxableAmount == 100000
#guard c_single66_ss1000.edcAdjustedCreditAmount == 225000
#guard c_single66_ss1000.edcNetCreditAmount == 275000
#guard c_single66_ss1000.netEdcAmount == 41300
#guard c_single66_ss1000.totalEdc == 41300
#guard c_single66_ss5000.qualifiedForCreditForElderlyAndDisabled == false
#guard c_single66_ss5000.totalEdc == 0
#guard c_single66_ss5000.edcNonTaxableLimit == 500000
#guard c_single66_ss4999.qualifiedForCreditForElderlyAndDisabled == true
#guard c_single66_ss4999.edcNetCreditAmount == 100
#guard c_single66_ss4999.totalEdc == 0
#guard c_single66_13b.edcTotalNonTaxableAmount == 42500
#guard c_single66_13b.edcNetCreditAmount == 457500
#guard c_single66_13b.netEdcAmount == 68600
#guard c_single66_13b.totalEdc == 68600
#guard c_mfj_both65_agi24000.edcLine3 == true
#guard c_mfj_both65_agi24000.edcFilingStatusAmt == 750000
#guard c_mfj_both65_agi24000.edcExemptionAmount == 1000000
#guard c_mfj_both65_agi24000.edcHalfMagi == 700000
#guard c_mfj_both65_agi24000.edcNetCreditAmount == 50000
#guard c_mfj_both65_agi24000.netEdcAmount == 7500
#guard c_mfj_both65_agi24000.qualifiedForCreditForElderlyAndDisabled == true
#guard c_mfj_both65_agi24000.totalEdc == 7500
#guard c_mfj_both65_agi24000.edcAgiLimit == 2500000
#guard c_mfj_both65_agi24000.edcNonTaxableLimit == 750000
#guard c_mfj_both65_agi25000.qualifiedForCreditForElderlyAndDisabled == false
#guard c_mfj_both65_agi25000.totalEdc == 0
#guard c_mfj_both65_agi10000.edcNetCreditAmount == 750000
#guard c_mfj_both65_agi10000.netEdcAmount == 112500
#guard c_mfj_both65_agi10000.totalEdc == 112500
#guard c_mfj_secondary65_only_box7.edcLine7 == true
#guard c_mfj_secondary65_only_box7.edcFilingStatusAmt == 500000
#guard c_mfj_secondary65_only_box7.edcExemptionAmount == 1000000
#guard c_mfj_secondary65_only_box7.edcHalfMagi == 250000
#guard c_mfj_secondary65_only_box7.edcNetCreditAmount == 250000
#guard c_mfj_secondary65_only_box7.netEdcAmount == 37500
#guard c_mfj_secondary65_only_box7.qualifiedForCreditForElderlyAndDisabled == true
#guard c_mfj_secondary65_only_box7.totalEdc == 37500
#guard c_mfj_secondary65_only_box7.edcAgiLimit == 2000000
#guard c_mfj_secondary65_only_box7.edcNonTaxableLimit == 500000
#guard c_mfj_one65_agi20000.qualifiedForCreditForElderlyAndDisabled == false
#guard c_mfj_one65_agi20000.totalEdc == 0
#guard c_mfj_one65_agi20000.edcAgiLimit == 2000000
#guard c_mfj_both_under65_nobody_disabled.qualifiedForCreditForElderlyAndDisabled == false
#guard c_mfj_both_under65_nobody_disabled.totalEdc == 0
#guard c_mfj_both_under65_nobody_disabled.edcFilingStatusAmt == 0
#guard c_mfs65_apart_agi8000.edcLine8 == true
#guard c_mfs65_apart_agi8000.edcFilingStatusAmt == 375000
#guard c_mfs65_apart_agi8000.edcExemptionAmount == 500000
#guard c_mfs65_apart_agi8000.edcHalfMagi == 150000
#guard c_mfs65_apart_agi8000.edcNetCreditAmount == 225000
#guard c_mfs65_apart_agi8000.netEdcAmount == 33800
#guard c_mfs65_apart_agi8000.qualifiedForCreditForElderlyAndDisabled == true
#guard c_mfs65_apart_agi8000.totalEdc == 33800
#guard c_mfs65_apart_agi8000.edcAgiLimit == 1250000
#guard c_mfs65_apart_agi8000.edcNonTaxableLimit == 375000
#guard c_mfs65_together.edcLine8 == true
#guard c_mfs65_together.qualifiedForCreditForElderlyAndDisabled == false
#guard c_mfs65_together.totalEdc == 0
#guard c_mfs65_apart_agi12500.qualifiedForCreditForElderlyAndDisabled == false
#guard c_mfs65_apart_agi12500.totalEdc == 0
#guard c_mfs_disabled_apart.edcLine9 == true
#guard c_mfs_disabled_apart.edcFilingStatusAmt == 375000
#guard c_mfs_disabled_apart.statusBasedDisabilityIncome == 200000
#guard c_mfs_disabled_apart.lesserOfFilingStatusAmountAndTaxableDisabilityIncome == 200000
#guard c_mfs_disabled_apart.edcExemptionAmount == 500000
#guard c_mfs_disabled_apart.edcHalfMagi == 50000
#guard c_mfs_disabled_apart.edcNetCreditAmount == 150000
#guard c_mfs_disabled_apart.netEdcAmount == 22500
#guard c_mfs_disabled_apart.qualifiedForCreditForElderlyAndDisabled == true
#guard c_mfs_disabled_apart.totalEdc == 22500
#guard c_mfs_disabled_together.edcLine9 == false
#guard c_mfs_disabled_together.qualifiedForCreditForElderlyAndDisabled == false
#guard c_mfs_disabled_together.totalEdc == 0
#guard c_jesse.edcLine2 == true
#guard c_jesse.edcFilingStatusAmt == 500000
#guard c_jesse.statusBasedDisabilityIncome == 1500000
#guard c_jesse.lesserOfFilingStatusAmountAndTaxableDisabilityIncome == 500000
#guard c_jesse.edcTotalNonTaxableAmount == 70000
#guard c_jesse.edcHalfMagi == 380000
#guard c_jesse.edcAdjustedCreditAmount == 450000
#guard c_jesse.edcNetCreditAmount == 50000
#guard c_jesse.netEdcAmount == 7500
#guard c_jesse.edcTaxLiabilityLimit == 5100
#guard c_jesse.qualifiedForCreditForElderlyAndDisabled == true
#guard c_jesse.totalEdc == 5100
#guard c_single_disabled_small_income.edcLine2 == true
#guard c_single_disabled_small_income.lesserOfFilingStatusAmountAndTaxableDisabilityIncome == 300000
#guard c_single_disabled_small_income.edcHalfMagi == 0
#guard c_single_disabled_small_income.edcNetCreditAmount == 300000
#guard c_single_disabled_small_income.netEdcAmount == 45000
#guard c_single_disabled_small_income.totalEdc == 45000
#guard c_mfj_box6.edcLine6 == true
#guard c_mfj_box6.edcLine7 == false
#guard c_mfj_box6.edcFilingStatusAmt == 750000
#guard c_mfj_box6.statusBasedDisabilityIncome == 900000
#guard c_mfj_box6.lesserOfFilingStatusAmountAndTaxableDisabilityIncome == 750000
#guard c_mfj_box6.edcHalfMagi == 500000
#guard c_mfj_box6.edcNetCreditAmount == 250000
#guard c_mfj_box6.netEdcAmount == 37500
#guard c_mfj_box6.qualifiedForCreditForElderlyAndDisabled == true
#guard c_mfj_box6.totalEdc == 37500
#guard c_mfj_box6.edcAgiLimit == 2500000
#guard c_mfj_box6_primary_disabled.edcLine6 == true
#guard c_mfj_box6_primary_disabled.statusBasedDisabilityIncome == 900000
#guard c_mfj_box6_primary_disabled.lesserOfFilingStatusAmountAndTaxableDisabilityIncome == 750000
#guard c_mfj_box6_primary_disabled.totalEdc == 37500
#guard c_mfj_box4.edcLine4 == true
#guard c_mfj_box4.edcFilingStatusAmt == 500000
#guard c_mfj_box4.statusBasedDisabilityIncome == 300000
#guard c_mfj_box4.lesserOfFilingStatusAmountAndTaxableDisabilityIncome == 300000
#guard c_mfj_box4.edcHalfMagi == 100000
#guard c_mfj_box4.edcNetCreditAmount == 200000
#guard c_mfj_box4.netEdcAmount == 30000
#guard c_mfj_box4.qualifiedForCreditForElderlyAndDisabled == true
#guard c_mfj_box4.totalEdc == 30000
#guard c_mfj_box4.edcAgiLimit == 2000000
#guard c_mfj_box5.edcLine5 == true
#guard c_mfj_box5.edcFilingStatusAmt == 750000
#guard c_mfj_box5.statusBasedDisabilityIncome == 900000
#guard c_mfj_box5.lesserOfFilingStatusAmountAndTaxableDisabilityIncome == 750000
#guard c_mfj_box5.edcHalfMagi == 100000
#guard c_mfj_box5.edcNetCreditAmount == 650000
#guard c_mfj_box5.netEdcAmount == 97500
#guard c_mfj_box5.qualifiedForCreditForElderlyAndDisabled == true
#guard c_mfj_box5.totalEdc == 97500
#guard c_mfj_box5.edcAgiLimit == 2500000
#guard c_riley_parker.edcLine5 == false
#guard c_riley_parker.edcNetCreditAmount == 0
#guard c_riley_parker.qualifiedForCreditForElderlyAndDisabled == false
#guard c_riley_parker.totalEdc == 0
#guard c_riley_parker_agi24000.edcLine5 == true
#guard c_riley_parker_agi24000.statusBasedDisabilityIncome == 810000
#guard c_riley_parker_agi24000.lesserOfFilingStatusAmountAndTaxableDisabilityIncome == 750000
#guard c_riley_parker_agi24000.edcHalfMagi == 700000
#guard c_riley_parker_agi24000.edcAdjustedCreditAmount == 900000
#guard c_riley_parker_agi24000.edcNetCreditAmount == 0
#guard c_riley_parker_agi24000.qualifiedForCreditForElderlyAndDisabled == false
#guard c_riley_parker_agi24000.totalEdc == 0
#guard c_mfj_box4_no_tax.edcLine4 == false
#guard c_mfj_box4_no_tax.edcFilingStatusAmt == 0
#guard c_mfj_box4_no_tax.qualifiedForCreditForElderlyAndDisabled == false
#guard c_mfj_box4_no_tax.totalEdc == 0
#guard c_hoh_70.edcLine1 == true
#guard c_hoh_70.edcNetCreditAmount == 425000
#guard c_hoh_70.netEdcAmount == 63800
#guard c_hoh_70.totalEdc == 63800
-- TestRejectsBad
private def r_a := run .single false true false false 0 false 0 1000000 0 0 1000000
private def r_b := run .single false true false false 0 false 0 1750000 0 0 1000000
private def r_c := run .marriedFilingSeparately false true false false 0 false 0 800000 0 0 1000000
private def r_d := run .marriedFilingJointly false true false false 0 false 0 2200000 0 0 1000000
private def r_e := run .single false true false false 0 false 0 1000000 0 0 10000
#guard r_a.totalEdc == 56300
#guard r_a.totalEdc != 375000
#guard r_a.totalEdc != 56250
#guard r_a.totalEdc != 56200
#guard r_b.totalEdc == 0
#guard !r_b.qualifiedForCreditForElderlyAndDisabled
#guard r_c.totalEdc == 0
#guard r_c.totalEdc != 33800
#guard r_d.edcAgiLimit == 2000000
#guard r_d.totalEdc == 0
#guard r_e.totalEdc == 10000
#guard r_e.totalEdc != 56300

/-! `RunSingleDisabled` of the Catala tests: a single filer under 65, AGI `$4,000`. -/

private def runSingleDisabled (ret has met pay : Bool) (inc : Int) (w2 : Bool) : ScheduleROut :=
  scheduleR { filingStatus := .single, livedApartAllYear := false, primaryAge65OrOlder := false
              secondaryAge65OrOlder := false
              primaryAnswers := { isRetiredOnPermOrTotalDisability := ret
                                  employerHasMandatoryRetirementAge := has
                                  hasMetEmployerMandatoryRetirementAge := met
                                  arePaymentsTaxableDisabilityIncome := pay
                                  writableTotalTaxableDisabilityAmount := inc, hasW2Wages := w2 }
              secondaryAnswers := runAnswers false 0, agi := 400_000
              nonTaxableSocialSecurityBenefits := 0, selfReportedNonTaxablePayments := 0
              creditLimitWorksheetLine3 := 1_000_000 }

-- TestDisabilityAnswers
private def mandatoryRetirementMet := runSingleDisabled true true true true 400_000 true
private def mandatoryRetirementNotMet := runSingleDisabled true true false true 400_000 true
private def noDisabilityPayments := runSingleDisabled true false false false 400_000 true
private def zeroDisabilityIncome := runSingleDisabled true false false true 0 true
private def notRetired := runSingleDisabled false false false true 400_000 true
private def noW2Wages := runSingleDisabled true false false true 400_000 false
#guard !mandatoryRetirementMet.edcLine2
#guard !mandatoryRetirementMet.qualifiedForCreditForElderlyAndDisabled
#guard mandatoryRetirementMet.totalEdc == 0
#guard mandatoryRetirementNotMet.edcLine2
#guard mandatoryRetirementNotMet.qualifiedForCreditForElderlyAndDisabled
#guard mandatoryRetirementNotMet.edcNetCreditAmount == 400_000
#guard mandatoryRetirementNotMet.totalEdc == 60_000
#guard !noDisabilityPayments.edcLine2
#guard !noDisabilityPayments.qualifiedForCreditForElderlyAndDisabled
#guard noDisabilityPayments.totalEdc == 0
#guard !zeroDisabilityIncome.edcLine2
#guard !zeroDisabilityIncome.qualifiedForCreditForElderlyAndDisabled
#guard zeroDisabilityIncome.totalEdc == 0
#guard !notRetired.edcLine2
#guard !notRetired.qualifiedForCreditForElderlyAndDisabled
#guard notRetired.totalEdc == 0

end UsTax.ElderlyAndDisabled
