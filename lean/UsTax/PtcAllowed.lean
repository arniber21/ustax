import UsTax.Money
import UsTax.Lists
import UsTax.Types
import UsTax.Date
import UsTax.Params2024.PtcHsa

/-!
# Premium tax credit, part 2: Forms 1095-A, annual and monthly PTC allowed (Form 8962 lines 9 to 25)

Lean implementation of `catala/ptc_allowed.catala_en` (module `Ptc_allowed`, scopes
`Form1095ACalculation` and `PtcAllowed`), written by hand from the Catala source under strategy
(c) of `docs/catala-to-lean.md`, in the order of the Catala file; the code that runs. Law:
26 U.S.C. § 36B(b), (c) (`sources/statute/irc-36B.html`), 26 CFR 1.36B-2 and 1.36B-3, Form 8962
(2024) and its instructions (`sources/forms-instructions/i8962--2024.pdf` pp 6 to 15). Issue #47.

| Catala (`Ptc_allowed`)                  | Lean (`UsTax.PtcAllowed`)                                  |
|-----------------------------------------|------------------------------------------------------------|
| structs `Form1095A`, `Form1095AMonth`, `PtcMonth` | the same names                                   |
| `month_amount`                          | `monthAmount`                                              |
| `List.sequence of 1, 13`                | `monthNumbers`                                             |
| `scope Form1095ACalculation`            | `Form1095ACalculationIn` → `Form1095ACalculationOut` (`form1095ACalculation`) |
| `scope PtcAllowed`                      | `PtcAllowedIn` → `PtcAllowedOut` (`ptcAllowed`)            |
| `ptc_months` (lines 12 to 23), one row  | `ptcMonthOf`                                               |
| `round of money`, `Money.*`             | `Money.roundDollar`, `Money.sum`, `Money.min`, `Money.positive` |

Money is `Int` cents, month numbers and counts are `Int`, conditions are `Bool`. Each Catala
`rule x under condition c consequence fulfilled` is `x := c`. The three Catala divergences from
Direct File are reproduced as in Catala (Lean follows Catala): DF-BUG(31) (a policy starting on
December 1 has December as a coverage month), DF-BUG(32) (no SLCSP outside coverage months, and
line 11 needs 12 coverage months) and DF-BUG(33) (line 10 "Yes" needs *every* Form 1095-A).
-/

namespace UsTax.PtcAllowed

open Money

/-- Catala `Form1095A`: one Form 1095-A as entered in Direct File (DF `ptc.xml` `/1095As/*`). The
three month lists hold twelve amounts, January first. -/
structure Form1095A where
  writablePolicyStartDate : Date
  writablePolicyEndDate : Date
  writableSpecialPolicyModificationInStartingMonth : Bool
  writableHasPolicyDateException : Bool
  hasCoverageMonths : Bool
  /-- Month numbers 1 to 12. -/
  coverageMonths : List Int
  writablePremiumsOrSlcspChange : Bool
  hasChangeInCircumstance : Bool
  /-- Form 1095-A line 33 column A. -/
  writablePtcAnnualPremium : Int
  /-- Form 1095-A line 33 column B. -/
  writableSlcspAnnualPremium : Int
  /-- Form 1095-A line 33 column C. -/
  writableAptcAnnualAmount : Int
  /-- Form 1095-A lines 21 to 32 column A. -/
  writablePtcMonthlyPremium : List Int
  /-- Form 1095-A lines 21 to 32 column B. -/
  writablePtcMonthlySlcspPremium : List Int
  /-- Form 1095-A lines 21 to 32 column C. -/
  writablePtcMonthlyAptcPremium : List Int
  deriving Repr

/-- Catala `Form1095AMonth`: one month of one Form 1095-A, as DF reads it. -/
structure Form1095AMonth where
  monthNumber : Int
  policyIsActive : Bool
  isCoverageMonth : Bool
  /-- Column A. -/
  premium : Int
  /-- Column B. -/
  slcspPremium : Int
  /-- Column C. -/
  aptc : Int
  deriving Repr

/-- Catala `PtcMonth`: one of Form 8962 lines 12 to 23, columns (a) to (f). -/
structure PtcMonth where
  monthNumber : Int
  hasActivePolicy : Bool
  /-- (a) -/
  enrollmentPremium : Int
  /-- (b) -/
  slcspPremium : Int
  /-- (c) -/
  contributionAmount : Int
  /-- (d) -/
  maxPremiumAssistance : Int
  /-- (e) -/
  ptcAllowed : Int
  /-- (f) -/
  advancePayment : Int
  deriving Repr

/-- Catala `month_amount`: the amount for month `m` (1 to 12) of a twelve-amount list (Catala
`List.nth_element` counts from 1); `$0` if the list is shorter. -/
def monthAmount (amounts : List Int) (m : Int) : Int :=
  if m < 1 then 0 else amounts.getD (m - 1).toNat 0

/-- Catala `List.sequence of 1, 13`: the month numbers 1 to 12. -/
def monthNumbers : List Int := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

/-! ### Scope `Form1095ACalculation`: the per-form facts (IRC 36B(c)(2)) -/

/-- Inputs of `Form1095ACalculation`. -/
structure Form1095ACalculationIn where
  form : Form1095A
  potentiallyApplicableTaxPayer : Bool
  hasAdvancedPtc : Bool

/-- Outputs of `Form1095ACalculation` (internals included). -/
structure Form1095ACalculationOut where
  startMonth : Int
  startDay : Int
  endMonth : Int
  hasPolicyDateException : Bool
  eligibleForCoverageMonths : Bool
  hasPolicyForAllMonths : Bool
  coverageMonthNumbers : List Int
  months : List Form1095AMonth
  numberOfCoverageMonths : Int
  hasZeroCoverageMonths : Bool
  hasAtLeastOneCoverageMonth : Bool
  premiumsOrSlcspChangeIsAsked : Bool
  ptcAnnualPremiumIsKnown : Bool
  noChangesAnd12MonthPolicy : Bool
  aptcAnnualAmountIsKnown : Bool
  aptcAnnualAmount : Int
  hasCoverageMonthsOrAptc : Bool
  canReportAnnualTotals : Bool
  annualPremium : Int
  annualSlcspPremium : Int
  deriving Repr

/-- Catala `scope Form1095ACalculation`, definition by definition. -/
def form1095ACalculation (i : Form1095ACalculationIn) : Form1095ACalculationOut :=
  let f := i.form
  let pat := i.potentiallyApplicableTaxPayer
  let startMonth : Int := f.writablePolicyStartDate.month
  let startDay : Int := f.writablePolicyStartDate.day
  let endMonth : Int := f.writablePolicyEndDate.month
  -- 26 CFR 1.36B-3(c)(2)
  let hasPolicyDateException := pat && f.writableSpecialPolicyModificationInStartingMonth &&
    decide (startDay ≠ 1) && f.writableHasPolicyDateException
  let eligible := f.hasCoverageMonths && pat
  let forAllMonths := pat && decide (startMonth = 1) && decide (endMonth = 12)
  -- IRC 36B(c)(2)(A)(i); DF-BUG(31): the "starts on the 1st" case applies to December too.
  let coverage := monthNumbers.filter fun m =>
    ((decide (startMonth = m) && (decide (startDay = 1) || hasPolicyDateException)) ||
      (decide (startMonth < m) && decide (m ≤ endMonth))) &&
    f.coverageMonths.contains m && eligible
  let n : Int := coverage.length
  let zero := decide (n = 0)
  let atLeastOne := decide (n ≥ 1)
  let asked := atLeastOne && forAllMonths
  let annualPremiumKnown := asked && !f.writablePremiumsOrSlcspChange
  let noChanges := asked && !f.writablePremiumsOrSlcspChange && !f.hasChangeInCircumstance
  let aptcKnown := noChanges || zero
  let aptcAnnual := if i.hasAdvancedPtc && aptcKnown then f.writableAptcAnnualAmount else 0
  let months := monthNumbers.map fun m =>
    let active := pat && decide (startMonth ≤ m) && decide (m ≤ endMonth)
    let isCov := coverage.contains m
    { monthNumber := m, policyIsActive := active, isCoverageMonth := isCov
      premium :=
        if !active then 0
        else if annualPremiumKnown then mulRate f.writablePtcAnnualPremium (1 / 12)
        else monthAmount f.writablePtcMonthlyPremium m
      -- DF-BUG(32): $0 outside coverage months
      slcspPremium :=
        if !isCov then 0
        else if noChanges then mulRate f.writableSlcspAnnualPremium (1 / 12)
        else monthAmount f.writablePtcMonthlySlcspPremium m
      aptc :=
        if aptcKnown then mulRate aptcAnnual (1 / 12)
        else if i.hasAdvancedPtc && active then monthAmount f.writablePtcMonthlyAptcPremium m
        else 0 : Form1095AMonth }
  { startMonth, startDay, endMonth, hasPolicyDateException
    eligibleForCoverageMonths := eligible, hasPolicyForAllMonths := forAllMonths
    coverageMonthNumbers := coverage, months, numberOfCoverageMonths := n
    hasZeroCoverageMonths := zero, hasAtLeastOneCoverageMonth := atLeastOne
    premiumsOrSlcspChangeIsAsked := asked, ptcAnnualPremiumIsKnown := annualPremiumKnown
    noChangesAnd12MonthPolicy := noChanges, aptcAnnualAmountIsKnown := aptcKnown
    aptcAnnualAmount := aptcAnnual
    hasCoverageMonthsOrAptc := atLeastOne || i.hasAdvancedPtc
    -- DF-BUG(32), second part
    canReportAnnualTotals := (noChanges && decide (n = 12)) || (zero && i.hasAdvancedPtc)
    annualPremium := if annualPremiumKnown then f.writablePtcAnnualPremium else 0
    annualSlcspPremium := if noChanges then f.writableSlcspAnnualPremium else 0 }

/-! ### Scope `PtcAllowed` -/

/-- Inputs of `PtcAllowed`. -/
structure PtcAllowedIn where
  filingStatus : FilingStatus
  isMfjDependent : Bool
  notMfjAndPrimaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits : Bool
  primaryFilerIsClaimedAsDependent : Bool
  isMarried : Bool
  secondaryFilerResidencyEligibleForMfj : Bool
  livedApartLastSixMonths : Bool
  allEligibleFilersAreUsCitizensOrNationals : Bool
  claimedDependentsCount : Int
  hasQsehra : Bool
  /-- Form 8962 line 5. -/
  householdIncomeAsPercent : Rat
  /-- Form 8962 line 8a. -/
  ptcAnnualContributionAmount : Int
  /-- Form 8962 line 8b. -/
  ptcMonthlyContributionAmount : Int
  form1095As : List Form1095A
  writableHasPtcQualifyingPlan : Bool
  writableHasAdvancedPtc : Bool
  dependentTpSelfEnrolled : Bool
  dependentTpEnrolledSomeoneElse : Bool
  writableDependentTpOtherMembersArePartOfDifferentTaxFamily : Bool
  writableHasMfsException : Bool
  writableClaimingMfsExceptionForFourthStraightYear : Bool
  writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus : Bool
  writableHasEmployerSponsoredPlan : Bool
  writableDependentsRequiredToFile : Bool
  writableSelfReportedHasMultiple1095As : Bool
  writableIsAdditionalPersonInEnrollmentFamily : Bool
  writableIsAdditionalPersonPartofDifferentTaxFamily : Bool
  writableIsEnrolledWithOtherFamily : Bool
  writableHasImmigrationStatusNotEligibleForMarketplace : Bool
  writableWantsToUseAltCalculations : Bool

/-- Outputs of `PtcAllowed` (internals included). -/
structure PtcAllowedOut where
  maybeEligibleForPtc : Bool
  dependentTpOtherMembersArePartOfDifferentTaxFamily : Bool
  dependentTpNeedToCollectMoreInfo : Bool
  hasPtcQualifyingPlan : Bool
  hasAdvancedPtc : Bool
  isMfsAndCantBeClaimed : Bool
  hasMfsException : Bool
  claimingMfsExceptionForFourthStraightYear : Bool
  notPtcApplicableTaxPayerSoFar : Bool
  isBelow100PercentFederalPovertyLevel : Bool
  maybeApplicableTpAndNoAptcAndBelow100PovertyThreshold : Bool
  filerNotQualifiedForPtcBecauseOfStatusAndResidenceInfo : Bool
  notPtcApplicableTaxPayer : Bool
  potentiallyApplicableTaxPayer : Bool
  applicableTaxPayerOrHasAptc : Bool
  forms : List Form1095ACalculationOut
  allMonths : List Form1095AMonth
  mayNeedToFileForm8962 : Bool
  needsToFileForm8962 : Bool
  ptcHasZeroCoverageMonths : Bool
  qualifiedForPtc : Bool
  /-- Form 8962 line 10 "Yes". -/
  ptcCanReportAnnualTotals : Bool
  /-- Line 11(a). -/
  totalPtcAnnualPremium : Int
  /-- Line 11(b). -/
  totalAnnualSlcspPremium : Int
  /-- Line 11(f). -/
  totalAnnualAptcAmount : Int
  /-- Line 11(d). -/
  annualMaxPremiumAssistance : Int
  /-- Line 11(e). -/
  annualPtcAllowed : Int
  needsToFileForm8962Monthly : Bool
  /-- Lines 12 to 23. -/
  ptcMonths : List PtcMonth
  /-- Line 24. -/
  totalPtcAmountAllowed : Int
  /-- Line 25. -/
  totalAptcAmountTaken : Int
  netPtcAmount : Int
  koDependentTpRequiresAllocations : Bool
  koHasPtcQualifyingPlanAndQsehra : Bool
  isAdditionalPersonInEnrollmentFamily : Bool
  isAdditionalPersonPartofDifferentTaxFamily : Bool
  isEnrolledWithOtherFamily : Bool
  koNeedsAllocations : Bool
  koHasEmployerSponsoredPlan : Bool
  koDependentsRequiredToFile : Bool
  koSelfReportedHasMultiple1095As : Bool
  mayPotentiallyHaveTaxFamilyWithNonEligibleImmigrationStatus : Bool
  koHasImmigrationStatusNotEligibleForMarketplace : Bool
  koWantsToUseAltCalculations : Bool
  koTpNeedsToAdd1095A : Bool
  koTpNeedsToDelete1095A : Bool
  unsupported : Bool

/-- One row of Form 8962 lines 12 to 23 (the body of Catala `ptc_months`): month `m` of the
monthly path, from every form's month `m`. A month is filled only on the monthly path and when
some policy is active that month; each column sum is rounded to whole dollars. -/
def ptcMonthOf (needsMonthly : Bool) (monthlyContribution : Int) (allMonths : List Form1095AMonth)
    (m : Int) : PtcMonth :=
  let rows := allMonths.filter fun r => r.monthNumber == m
  let hasActive := rows.any fun r => r.policyIsActive
  let filled := needsMonthly && hasActive
  let enrollment := if filled then roundDollar (sumBy (·.premium) rows) else 0
  let slcsp := if filled then roundDollar (sumBy (·.slcspPremium) rows) else 0
  let contribution := if filled then monthlyContribution else 0
  -- (d) IRC 36B(b)(2)(B)
  let maxAssistance := positive (slcsp - contribution)
  { monthNumber := m, hasActivePolicy := hasActive, enrollmentPremium := enrollment
    slcspPremium := slcsp, contributionAmount := contribution
    maxPremiumAssistance := maxAssistance
    -- (e) IRC 36B(b)(2)
    ptcAllowed := Money.min maxAssistance enrollment
    advancePayment := if filled then roundDollar (sumBy (·.aptc) rows) else 0 }

/-- Catala `scope PtcAllowed`, definition by definition. -/
def ptcAllowed (i : PtcAllowedIn) : PtcAllowedOut :=
  let dependentTp :=
    i.notMfjAndPrimaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits
  let isMfj := decide (i.filingStatus = .marriedFilingJointly)
  -- Who may claim the credit (IRC 36B(c)(1))
  let maybeEligible := !(isMfj && i.isMfjDependent)
  let otherMembersDifferent := i.dependentTpEnrolledSomeoneElse &&
    i.writableDependentTpOtherMembersArePartOfDifferentTaxFamily
  let needMoreInfo :=
    (!i.primaryFilerIsClaimedAsDependent && i.dependentTpSelfEnrolled &&
        !i.dependentTpEnrolledSomeoneElse) ||
      (!i.dependentTpSelfEnrolled && i.dependentTpEnrolledSomeoneElse && !otherMembersDifferent) ||
      (!i.primaryFilerIsClaimedAsDependent && i.dependentTpSelfEnrolled &&
        i.dependentTpEnrolledSomeoneElse && !otherMembersDifferent)
  let hasPlan := maybeEligible &&
    (if dependentTp then needMoreInfo else i.writableHasPtcQualifyingPlan)
  let hasAptc := hasPlan && i.writableHasAdvancedPtc
  let isMfsCantBeClaimed := decide (i.filingStatus = .marriedFilingSeparately) && !dependentTp
  let mfsException := isMfsCantBeClaimed && i.writableHasMfsException
  let fourthYear := mfsException && i.writableClaimingMfsExceptionForFourthStraightYear
  let notSoFar := (isMfsCantBeClaimed && (!mfsException || fourthYear)) || dependentTp
  let below100 := decide (i.householdIncomeAsPercent < Params.ptcApplicableTaxpayerPovertyPercentFloor)
  let below100NoAptc := !notSoFar && !hasAptc && below100
  let statusResidence :=
    (hasPlan && decide (i.filingStatus = .headOfHousehold) && i.isMarried &&
        !i.secondaryFilerResidencyEligibleForMfj && !i.livedApartLastSixMonths) ||
      (!hasAptc && dependentTp && !i.primaryFilerIsClaimedAsDependent &&
        (i.dependentTpSelfEnrolled || (i.dependentTpEnrolledSomeoneElse && !otherMembersDifferent)))
  let notApplicable := notSoFar ||
    (below100NoAptc &&
      !i.writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus) ||
    statusResidence
  let applicable := !notApplicable
  let applicableOrAptc := applicable || hasAptc
  -- The Forms 1095-A
  let forms := i.form1095As.map fun f =>
    form1095ACalculation
      { form := f, potentiallyApplicableTaxPayer := applicable, hasAdvancedPtc := hasAptc }
  let allMonths := forms.foldl (fun acc c => acc ++ c.months) []
  let mayNeed := forms.any (·.hasCoverageMonthsOrAptc) && maybeEligible && hasPlan &&
    applicableOrAptc
  let zeroCoverage := applicableOrAptc && decide (forms.length > 0) &&
    forms.all (·.hasZeroCoverageMonths)
  let qualified := hasPlan && !statusResidence && applicable && decide (forms.length > 0) &&
    !zeroCoverage
  -- Line 11; DF-BUG(33): every form, not any form.
  let annualTotals := decide (forms.length > 0) && forms.all (·.canReportAnnualTotals)
  let totalPremium := roundDollar (sumBy (·.annualPremium) forms)
  let totalSlcsp := roundDollar (sumBy (·.annualSlcspPremium) forms)
  let totalAptc := roundDollar (sumBy (·.aptcAnnualAmount) forms)
  let annualMax := positive (totalSlcsp - i.ptcAnnualContributionAmount)
  let annualAllowed := Money.min annualMax totalPremium
  -- Lines 12 to 23
  let needsMonthly := mayNeed && !annualTotals
  let ptcMonths := monthNumbers.map (ptcMonthOf needsMonthly i.ptcMonthlyContributionAmount allMonths)
  -- Lines 24 and 25
  let line24 := if !mayNeed then 0 else if annualTotals then annualAllowed
    else sumBy (·.ptcAllowed) ptcMonths
  let line25 := if !mayNeed then 0 else if annualTotals then totalAptc
    else sumBy (·.advancePayment) ptcMonths
  let net := line24 - line25
  -- Knockouts (flow.xml lines 96 to 103) and blocked submissions
  let koAllocations := dependentTp && i.dependentTpSelfEnrolled && i.dependentTpEnrolledSomeoneElse &&
    ((i.primaryFilerIsClaimedAsDependent && !otherMembersDifferent) ||
      (!i.primaryFilerIsClaimedAsDependent && otherMembersDifferent))
  let koQsehra := hasPlan && i.hasQsehra
  let additionalPerson := hasPlan && !dependentTp && i.writableIsAdditionalPersonInEnrollmentFamily
  let additionalDifferent := additionalPerson &&
    i.writableIsAdditionalPersonPartofDifferentTaxFamily
  let otherFamily := !additionalDifferent && i.writableIsEnrolledWithOtherFamily
  let koNeedsAllocations := hasPlan && (additionalDifferent || otherFamily)
  let koEmployer := maybeEligible && hasPlan && i.writableHasEmployerSponsoredPlan
  let koDependentsFile := hasPlan && decide (i.claimedDependentsCount ≥ 1) &&
    i.writableDependentsRequiredToFile
  let koMultiple := hasPlan && i.writableSelfReportedHasMultiple1095As
  let mayImmigration := (additionalPerson && !otherFamily) ||
    !i.allEligibleFilersAreUsCitizensOrNationals || decide (i.claimedDependentsCount ≥ 1)
  let koImmigration := hasPlan && mayImmigration &&
    i.writableHasImmigrationStatusNotEligibleForMarketplace
  let koAlt := hasAptc && decide (net < 0) && i.isMarried && isMfj &&
    i.writableWantsToUseAltCalculations
  let koAdd := hasPlan && applicableOrAptc && decide (i.form1095As.length = 0)
  let koDelete := hasPlan && applicableOrAptc && decide (i.form1095As.length ≥ 2)
  { maybeEligibleForPtc := maybeEligible
    dependentTpOtherMembersArePartOfDifferentTaxFamily := otherMembersDifferent
    dependentTpNeedToCollectMoreInfo := needMoreInfo
    hasPtcQualifyingPlan := hasPlan, hasAdvancedPtc := hasAptc
    isMfsAndCantBeClaimed := isMfsCantBeClaimed, hasMfsException := mfsException
    claimingMfsExceptionForFourthStraightYear := fourthYear
    notPtcApplicableTaxPayerSoFar := notSoFar
    isBelow100PercentFederalPovertyLevel := below100
    maybeApplicableTpAndNoAptcAndBelow100PovertyThreshold := below100NoAptc
    filerNotQualifiedForPtcBecauseOfStatusAndResidenceInfo := statusResidence
    notPtcApplicableTaxPayer := notApplicable, potentiallyApplicableTaxPayer := applicable
    applicableTaxPayerOrHasAptc := applicableOrAptc
    forms, allMonths
    mayNeedToFileForm8962 := mayNeed, needsToFileForm8962 := mayNeed
    ptcHasZeroCoverageMonths := zeroCoverage, qualifiedForPtc := qualified
    ptcCanReportAnnualTotals := annualTotals
    totalPtcAnnualPremium := totalPremium, totalAnnualSlcspPremium := totalSlcsp
    totalAnnualAptcAmount := totalAptc, annualMaxPremiumAssistance := annualMax
    annualPtcAllowed := annualAllowed
    needsToFileForm8962Monthly := needsMonthly, ptcMonths
    totalPtcAmountAllowed := line24, totalAptcAmountTaken := line25, netPtcAmount := net
    koDependentTpRequiresAllocations := koAllocations
    koHasPtcQualifyingPlanAndQsehra := koQsehra
    isAdditionalPersonInEnrollmentFamily := additionalPerson
    isAdditionalPersonPartofDifferentTaxFamily := additionalDifferent
    isEnrolledWithOtherFamily := otherFamily
    koNeedsAllocations := koNeedsAllocations
    koHasEmployerSponsoredPlan := koEmployer
    koDependentsRequiredToFile := koDependentsFile
    koSelfReportedHasMultiple1095As := koMultiple
    mayPotentiallyHaveTaxFamilyWithNonEligibleImmigrationStatus := mayImmigration
    koHasImmigrationStatusNotEligibleForMarketplace := koImmigration
    koWantsToUseAltCalculations := koAlt
    koTpNeedsToAdd1095A := koAdd, koTpNeedsToDelete1095A := koDelete
    unsupported := koAllocations || koQsehra || koNeedsAllocations || koEmployer ||
      koDependentsFile || koMultiple || koImmigration || koAlt || koAdd || koDelete }

/-! ### Unit tests: every assertion of `catala/tests/test_ptc_allowed.catala_en`

`fullYearForm` and `partYearForm` are the Catala helpers `full_year_form` and `part_year_form`;
`base` is the helper `Case` with its defaults: a single applicable taxpayer at 200 percent with
a qualifying plan, no APTC, contribution $1,200 a year and $100 a month, one full-year
Form 1095-A with $8,000 of premiums and a $7,200 SLCSP, every knockout answer no. -/

/-- Catala test helper `amounts_in`: `amount` in months `first` to `last`, `$0` in the others. -/
def amountsIn (first last amount : Int) : List Int :=
  monthNumbers.map fun m => if first ≤ m && m ≤ last then amount else 0

/-- Catala test helper `months_between`: the month numbers `first` to `last`. -/
def monthsBetween (first last : Int) : List Int :=
  monthNumbers.filter fun m => first ≤ m && m ≤ last

/-- A 2024 date. -/
def d24 (m d : Nat) : Date := { year := 2024, month := m, day := d }

/-- Catala test helper `full_year_form`. -/
def fullYearForm (premium slcsp aptc : Int) : Form1095A :=
  { writablePolicyStartDate := d24 1 1, writablePolicyEndDate := d24 12 31
    writableSpecialPolicyModificationInStartingMonth := false
    writableHasPolicyDateException := false, hasCoverageMonths := true
    coverageMonths := monthsBetween 1 12, writablePremiumsOrSlcspChange := false
    hasChangeInCircumstance := false, writablePtcAnnualPremium := premium
    writableSlcspAnnualPremium := slcsp, writableAptcAnnualAmount := aptc
    writablePtcMonthlyPremium := amountsIn 1 12 0
    writablePtcMonthlySlcspPremium := amountsIn 1 12 0
    writablePtcMonthlyAptcPremium := amountsIn 1 12 0 }

/-- Catala test helper `part_year_form`. -/
def partYearForm (start ends : Date) (first last premium slcsp aptc : Int) : Form1095A :=
  { writablePolicyStartDate := start, writablePolicyEndDate := ends
    writableSpecialPolicyModificationInStartingMonth := false
    writableHasPolicyDateException := false, hasCoverageMonths := true
    coverageMonths := monthsBetween first last, writablePremiumsOrSlcspChange := false
    hasChangeInCircumstance := false, writablePtcAnnualPremium := 0
    writableSlcspAnnualPremium := 0, writableAptcAnnualAmount := 0
    writablePtcMonthlyPremium := amountsIn first last premium
    writablePtcMonthlySlcspPremium := amountsIn first last slcsp
    writablePtcMonthlyAptcPremium := amountsIn first last aptc }

/-- The defaults of the Catala test helper `Case`. -/
def base : PtcAllowedIn :=
  { filingStatus := .single, isMfjDependent := false
    notMfjAndPrimaryFilerCouldBeDependentAndClaimerIsRequiredToFileOrFilingForCredits := false
    primaryFilerIsClaimedAsDependent := false, isMarried := false
    secondaryFilerResidencyEligibleForMfj := true, livedApartLastSixMonths := false
    allEligibleFilersAreUsCitizensOrNationals := true, claimedDependentsCount := 0
    hasQsehra := false, householdIncomeAsPercent := 200
    ptcAnnualContributionAmount := 120_000, ptcMonthlyContributionAmount := 10_000
    form1095As := [fullYearForm 800_000 720_000 0]
    writableHasPtcQualifyingPlan := true, writableHasAdvancedPtc := false
    dependentTpSelfEnrolled := false, dependentTpEnrolledSomeoneElse := false
    writableDependentTpOtherMembersArePartOfDifferentTaxFamily := false
    writableHasMfsException := false
    writableClaimingMfsExceptionForFourthStraightYear := false
    writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus := false
    writableHasEmployerSponsoredPlan := false, writableDependentsRequiredToFile := false
    writableSelfReportedHasMultiple1095As := false
    writableIsAdditionalPersonInEnrollmentFamily := false
    writableIsAdditionalPersonPartofDifferentTaxFamily := false
    writableIsEnrolledWithOtherFamily := false
    writableHasImmigrationStatusNotEligibleForMarketplace := false
    writableWantsToUseAltCalculations := false }

private def run (f : PtcAllowedIn → PtcAllowedIn) : PtcAllowedOut := ptcAllowed (f base)
private def withForms (fs : List Form1095A) : PtcAllowedOut := run fun c => { c with form1095As := fs }

-- TestTwelveMonthPolicyAnnualPath
private def t1 := run id
#guard t1.ptcCanReportAnnualTotals
#guard t1.needsToFileForm8962
#guard t1.totalPtcAmountAllowed == 600_000
#guard t1.annualPtcAllowed == 600_000
#guard t1.totalAptcAmountTaken == 0
#guard t1.totalPtcAmountAllowed != 720_000
#guard t1.totalPtcAmountAllowed != 800_000
#guard !t1.unsupported
-- TestJulyStartMonthlyPath
private def t2 := run fun c => { c with
  writableHasAdvancedPtc := true,
  form1095As := [partYearForm (d24 7 1) (d24 12 31) 7 12 50_000 60_000 5_000] }
#guard !t2.ptcCanReportAnnualTotals
#guard t2.totalPtcAmountAllowed == 300_000
#guard t2.totalAptcAmountTaken == 30_000
#guard t2.totalPtcAmountAllowed != 600_000
#guard (t2.ptcMonths.filter (·.ptcAllowed > 0)).length == 6
#guard (t2.ptcMonths.filter (·.contributionAmount > 0)).length == 6
#guard t2.ptcMonths.any fun r => r.monthNumber == 7 && r.enrollmentPremium == 50_000 &&
  r.slcspPremium == 60_000 && r.contributionAmount == 10_000 && r.maxPremiumAssistance == 50_000 &&
  r.ptcAllowed == 50_000 && r.advancePayment == 5_000
#guard t2.ptcMonths.any fun r => r.monthNumber == 6 && r.enrollmentPremium == 0 &&
  r.ptcAllowed == 0 && !r.hasActivePolicy
-- TestTwo1095As
private def t3 := withForms
  [partYearForm (d24 1 1) (d24 6 30) 1 6 40_000 45_000 0,
   partYearForm (d24 7 1) (d24 12 31) 7 12 30_000 50_000 0]
#guard !t3.ptcCanReportAnnualTotals
#guard t3.totalPtcAmountAllowed == 390_000
#guard t3.totalPtcAmountAllowed != 210_000
#guard t3.koTpNeedsToDelete1095A
#guard t3.unsupported
-- TestSlcspBelowContributionAllowsNothing
private def t4 := withForms [fullYearForm 800_000 60_000 0]
#guard t4.ptcCanReportAnnualTotals
#guard t4.totalPtcAmountAllowed == 0
#guard t4.totalPtcAmountAllowed != -60_000
-- TestMonthlySlcspBelowContribution
private def t5 := withForms [partYearForm (d24 3 1) (d24 5 31) 3 5 50_000 9_000 0]
#guard t5.totalPtcAmountAllowed == 0
#guard t5.totalPtcAmountAllowed != -3_000
-- TestAllowedCappedByPremium
private def t6 := withForms [fullYearForm 400_000 720_000 0]
#guard t6.totalPtcAmountAllowed == 400_000
#guard t6.totalPtcAmountAllowed != 600_000
-- TestAnnualAptcRounded
private def t7 := run fun c => { c with
  writableHasAdvancedPtc := true, form1095As := [fullYearForm 800_000 720_000 240_060] }
#guard t7.ptcCanReportAnnualTotals
#guard t7.totalPtcAmountAllowed == 600_000
#guard t7.totalAptcAmountTaken == 240_100
-- TestDecemberFirstStartIsCoverageMonth (DF-BUG(31))
private def t8 := withForms [partYearForm (d24 12 1) (d24 12 31) 12 12 50_000 60_000 0]
#guard t8.totalPtcAmountAllowed == 50_000
#guard t8.totalPtcAmountAllowed != 0
-- TestMidDecemberStartNoCoverageMonth
#guard (withForms [partYearForm (d24 12 15) (d24 12 31) 12 12 50_000 60_000 0]).totalPtcAmountAllowed
  == 0
-- TestPolicyDateExceptionCountsStartMonth
private def t9 := withForms
  [{ partYearForm (d24 3 15) (d24 4 30) 3 4 50_000 60_000 0 with
      writableSpecialPolicyModificationInStartingMonth := true
      writableHasPolicyDateException := true, coverageMonths := [3, 4] }]
#guard t9.totalPtcAmountAllowed == 100_000
-- TestMidMonthStartWithoutException
private def t10 := withForms [partYearForm (d24 3 15) (d24 4 30) 3 4 50_000 60_000 0]
#guard t10.totalPtcAmountAllowed == 50_000
#guard t10.totalPtcAmountAllowed != 100_000
-- TestFullYearPolicyWithElevenCoverageMonths (DF-BUG(32))
private def t11 := withForms
  [{ fullYearForm 800_000 720_000 0 with writablePolicyStartDate := d24 1 20 }]
#guard !t11.ptcCanReportAnnualTotals
#guard t11.totalPtcAmountAllowed == 550_000
#guard t11.totalPtcAmountAllowed != 600_000
-- TestMfsWithoutExceptionRepaysAllAptc
private def t12 := run fun c => { c with
  filingStatus := .marriedFilingSeparately, isMarried := true, writableHasAdvancedPtc := true,
  form1095As := [fullYearForm 800_000 720_000 300_000] }
#guard !t12.potentiallyApplicableTaxPayer
#guard t12.needsToFileForm8962
#guard t12.totalPtcAmountAllowed == 0
#guard t12.totalAptcAmountTaken == 300_000
#guard t12.totalPtcAmountAllowed != 600_000
-- TestMfsWithExceptionIsApplicable
private def t13 := run fun c => { c with
  filingStatus := .marriedFilingSeparately, isMarried := true, writableHasMfsException := true }
#guard t13.potentiallyApplicableTaxPayer
#guard t13.totalPtcAmountAllowed == 600_000
-- TestBelowPovertyLineNoAptcNotApplicable
private def t14 := run fun c => { c with
  householdIncomeAsPercent := 90, ptcAnnualContributionAmount := 0,
  ptcMonthlyContributionAmount := 0 }
#guard !t14.potentiallyApplicableTaxPayer
#guard !t14.needsToFileForm8962
#guard t14.totalPtcAmountAllowed == 0
-- TestBelowPovertyLineWithAptcApplicable
private def t15 := run fun c => { c with
  householdIncomeAsPercent := 90, ptcAnnualContributionAmount := 0,
  ptcMonthlyContributionAmount := 0, writableHasAdvancedPtc := true,
  form1095As := [fullYearForm 800_000 720_000 700_000] }
#guard t15.potentiallyApplicableTaxPayer
#guard t15.totalPtcAmountAllowed == 720_000
#guard t15.totalAptcAmountTaken == 700_000
-- TestQsehraKnockedOut, TestEmployerPlanKnockedOut, TestSelfReportedMultipleKnockedOut
#guard (run fun c => { c with hasQsehra := true }).unsupported
#guard (run fun c => { c with writableHasEmployerSponsoredPlan := true }).unsupported
#guard (run fun c => { c with writableSelfReportedHasMultiple1095As := true }).unsupported
-- TestAltCalculationKnockedOut
#guard (run fun c => { c with
  filingStatus := .marriedFilingJointly, isMarried := true, writableHasAdvancedPtc := true,
  writableWantsToUseAltCalculations := true,
  form1095As := [fullYearForm 800_000 720_000 700_000] }).unsupported
-- TestAltCalculationNotAskedWithoutExcessAptc
#guard !(run fun c => { c with
  filingStatus := .marriedFilingJointly, isMarried := true, writableHasAdvancedPtc := true,
  writableWantsToUseAltCalculations := true,
  form1095As := [fullYearForm 800_000 720_000 500_000] }).unsupported

end UsTax.PtcAllowed
