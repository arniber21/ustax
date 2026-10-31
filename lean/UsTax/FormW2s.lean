import UsTax.Money
import UsTax.Lists
import UsTax.Types
import UsTax.Params2024

/-!
# Forms W-2: Form 1040 lines 1a and 25a and the W-2 knockouts (issue #43)

Lean implementation of `catala/form_w2s.catala_en` (module `Form_w2s`, scopes
`FormW2Item` and `FormW2s`), written by hand from the Catala source under
strategy (c) of `docs/catala-to-lean.md`; the code that runs.

| Catala (`Form_w2s`)                | Lean (`UsTax.FormW2s`)                 |
|------------------------------------|----------------------------------------|
| `structure FormW2` (`writable_wages`, `deferrals_401k`, ...) | `FormW2` (`writableWages`, `deferrals401k`, ...) |
| `enumeration CombatPayElection`    | `CombatPayElection`                    |
| `scope FormW2Item` (`w2` → outputs) | `FormW2Item` (`formW2Item : FormW2 → FormW2Item`) |
| `scope FormW2s` (inputs/outputs)   | `FormW2sIn` → `FormW2sOut` (`formW2s`) |

Money is `Int` cents. Every `R.round_dollar` is `Money.roundDollar`, every
`Money.sum` is `Money.sum`, `Money.min/max` are the `Money` ports, so the
rounding points are those of Catala (per-W-2 rounding, quirk Q-R1).
All `FormW2` boxes default to `$0` / `false`, so a test names only the boxes it
fills in (the Catala tests' helper scope `MkW2`).
-/

namespace UsTax.FormW2s

open Money

/-- One Form W-2 as the filer typed it (Catala `FormW2`). Cents. -/
structure FormW2 where
  /-- Catala input `filer`. -/
  filer : FilerRole := .primaryFiler
  /-- Catala input `writable_wages`. -/
  writableWages : Int := 0
  /-- Catala input `writable_federal_withholding`. -/
  writableFederalWithholding : Int := 0
  /-- Catala input `writable_oasdi_wages`. -/
  writableOasdiWages : Int := 0
  /-- Catala input `writable_oasdi_withholding`. -/
  writableOasdiWithholding : Int := 0
  /-- Catala input `writable_medicare_wages`. -/
  writableMedicareWages : Int := 0
  /-- Catala input `writable_medicare_withholding`. -/
  writableMedicareWithholding : Int := 0
  /-- Catala input `writable_allocated_tips`. -/
  writableAllocatedTips : Int := 0
  /-- Catala input `writable_dependent_care_benefits`. -/
  writableDependentCareBenefits : Int := 0
  /-- Catala input `writable_non_qualified_plans`. -/
  writableNonQualifiedPlans : Int := 0
  /-- Catala input `writable_combat_pay`. -/
  writableCombatPay : Int := 0
  /-- Catala input `uncollected_oasdi_tax_on_tips`. -/
  uncollectedOasdiTaxOnTips : Int := 0
  /-- Catala input `uncollected_medicare_tax_on_tips`. -/
  uncollectedMedicareTaxOnTips : Int := 0
  /-- Catala input `taxable_life_insurance_over_50k`. -/
  taxableLifeInsuranceOver50k : Int := 0
  /-- Catala input `deferrals_401k`. -/
  deferrals401k : Int := 0
  /-- Catala input `deferrals_403b`. -/
  deferrals403b : Int := 0
  /-- Catala input `sarsep_deferrals`. -/
  sarsepDeferrals : Int := 0
  /-- Catala input `deferrals_457b`. -/
  deferrals457b : Int := 0
  /-- Catala input `deferrals_501c18`. -/
  deferrals501c18 : Int := 0
  /-- Catala input `nontaxable_sick_pay`. -/
  nontaxableSickPay : Int := 0
  /-- Catala input `golden_parachute_excise_tax`. -/
  goldenParachuteExciseTax : Int := 0
  /-- Catala input `expense_reimbursements`. -/
  expenseReimbursements : Int := 0
  /-- Catala input `uncollected_oasdi_tax_on_life_insurance_over_50k`. -/
  uncollectedOasdiTaxOnLifeInsuranceOver50k : Int := 0
  /-- Catala input `uncollected_medicare_tax_on_life_insurance_over_50k`. -/
  uncollectedMedicareTaxOnLifeInsuranceOver50k : Int := 0
  /-- Catala input `armed_forces_moving_expenses`. -/
  armedForcesMovingExpenses : Int := 0
  /-- Catala input `archer_msa_contributions`. -/
  archerMsaContributions : Int := 0
  /-- Catala input `simple_contributions`. -/
  simpleContributions : Int := 0
  /-- Catala input `adoption_benefits`. -/
  adoptionBenefits : Int := 0
  /-- Catala input `nso_income`. -/
  nsoIncome : Int := 0
  /-- Catala input `employer_hsa_contributions`. -/
  employerHsaContributions : Int := 0
  /-- Catala input `deferrals_409a`. -/
  deferrals409a : Int := 0
  /-- Catala input `nqdc_deferrals`. -/
  nqdcDeferrals : Int := 0
  /-- Catala input `roth401k_contributions`. -/
  roth401kContributions : Int := 0
  /-- Catala input `roth403b_contributions`. -/
  roth403bContributions : Int := 0
  /-- Catala input `health_coverage_cost`. -/
  healthCoverageCost : Int := 0
  /-- Catala input `roth457b_contributions`. -/
  roth457bContributions : Int := 0
  /-- Catala input `qsehra_benefits`. -/
  qsehraBenefits : Int := 0
  /-- Catala input `income_83i`. -/
  income83i : Int := 0
  /-- Catala input `deferrals_83i`. -/
  deferrals83i : Int := 0
  /-- Catala input `non_taxable_medicaid_waiver_payments`. -/
  nonTaxableMedicaidWaiverPayments : Int := 0
  /-- Catala input `plan_457b_is_governmental`. -/
  plan457bIsGovernmental : Bool := false
  /-- Catala input `statutory_employee`. -/
  statutoryEmployee : Bool := false
  /-- Catala input `third_party_sick_pay`. -/
  thirdPartySickPay : Bool := false

/-- How the filer elects to treat nontaxable combat pay (Catala
`CombatPayElection`). -/
inductive CombatPayElection where
  /-- Catala case `NoCombatPay`. -/
  | noCombatPay
  /-- Catala case `UsePrimaryCombatPay`. -/
  | usePrimaryCombatPay
  /-- Catala case `UseSpouseCombatPay`. -/
  | useSpouseCombatPay
  /-- Catala case `UseBothCombatPay`. -/
  | useBothCombatPay
  /-- Catala case `UsePrimaryNotSpouseCombatPay`. -/
  | usePrimaryNotSpouseCombatPay
  /-- Catala case `UseSpouseNotPrimaryCombatPay`. -/
  | useSpouseNotPrimaryCombatPay
  deriving DecidableEq, Repr, Inhabited

namespace CombatPayElection

/-- Parse a Catala case name. -/
def ofString? : String → Option CombatPayElection
  | "NoCombatPay" => some noCombatPay
  | "UsePrimaryCombatPay" => some usePrimaryCombatPay
  | "UseSpouseCombatPay" => some useSpouseCombatPay
  | "UseBothCombatPay" => some useBothCombatPay
  | "UsePrimaryNotSpouseCombatPay" => some usePrimaryNotSpouseCombatPay
  | "UseSpouseNotPrimaryCombatPay" => some useSpouseNotPrimaryCombatPay
  | _ => none

end CombatPayElection

/-! ### Scope `FormW2Item` -/

/-- Outputs of `FormW2Item` (the derived facts of a single W-2). -/
structure FormW2Item where
  /-- Catala field `filer`. -/
  filer : FilerRole
  /-- Catala field `wages`. -/
  wages : Int
  /-- Catala field `federal_withholding`. -/
  federalWithholding : Int
  /-- Catala field `oasdi_wages`. -/
  oasdiWages : Int
  /-- Catala field `oasdi_wages_for_knockout_calculation`. -/
  oasdiWagesForKnockoutCalculation : Int
  /-- Catala field `oasdi_withholding`. -/
  oasdiWithholding : Int
  /-- Catala field `medicare_wages`. -/
  medicareWages : Int
  /-- Catala field `medicare_withholding`. -/
  medicareWithholding : Int
  /-- Catala field `allocated_tips`. -/
  allocatedTips : Int
  /-- Catala field `dependent_care_benefits`. -/
  dependentCareBenefits : Int
  /-- Catala field `non_qualified_plans`. -/
  nonQualifiedPlans : Int
  /-- Catala field `combat_pay`. -/
  combatPay : Int
  /-- Catala field `employer_hsa_contributions_rounded`. -/
  employerHsaContributionsRounded : Int
  /-- Catala field `total_deferrals_and_contributions`. -/
  totalDeferralsAndContributions : Int
  /-- Catala field `causes_allocated_tips_ko`. -/
  causesAllocatedTipsKo : Bool
  /-- Catala field `causes_non_qualified_plans_ko`. -/
  causesNonQualifiedPlansKo : Bool
  /-- Catala field `has_box12_knockout_code`. -/
  hasBox12KnockoutCode : Bool

/-- Catala `scope FormW2Item`. Per-box rounding (quirk Q-R1); box 10 is not
rounded; the knockout code test uses the unrounded amounts. -/
def formW2Item (w2 : FormW2) : FormW2Item :=
  let oasdiWages := roundDollar w2.writableOasdiWages
  { filer := w2.filer
    wages := roundDollar w2.writableWages
    federalWithholding := roundDollar w2.writableFederalWithholding
    oasdiWages := oasdiWages
    oasdiWagesForKnockoutCalculation := Money.min oasdiWages Params.oasdiWageBase
    oasdiWithholding := roundDollar w2.writableOasdiWithholding
    medicareWages := roundDollar w2.writableMedicareWages
    medicareWithholding := roundDollar w2.writableMedicareWithholding
    allocatedTips := roundDollar w2.writableAllocatedTips
    dependentCareBenefits := w2.writableDependentCareBenefits
    nonQualifiedPlans := roundDollar w2.writableNonQualifiedPlans
    combatPay := roundDollar w2.writableCombatPay
    employerHsaContributionsRounded := roundDollar w2.employerHsaContributions
    totalDeferralsAndContributions :=
      roundDollar w2.deferrals401k + roundDollar w2.deferrals403b +
        roundDollar w2.sarsepDeferrals +
        (if w2.plan457bIsGovernmental then roundDollar w2.deferrals457b else 0) +
        roundDollar w2.deferrals501c18 + roundDollar w2.simpleContributions +
        roundDollar w2.roth401kContributions + roundDollar w2.roth403bContributions +
        roundDollar w2.roth457bContributions
    causesAllocatedTipsKo := decide (roundDollar w2.writableAllocatedTips > 0)
    causesNonQualifiedPlansKo := decide (roundDollar w2.writableNonQualifiedPlans > 0)
    hasBox12KnockoutCode :=
      decide (w2.uncollectedOasdiTaxOnTips > 0) ||                       -- A
      decide (w2.uncollectedMedicareTaxOnTips > 0) ||                    -- B
      decide (w2.sarsepDeferrals > 0) ||                                 -- F
      decide (w2.nontaxableSickPay > 0) ||                               -- J
      decide (w2.goldenParachuteExciseTax > 0) ||                        -- K
      decide (w2.expenseReimbursements > 0) ||                           -- L
      decide (w2.uncollectedOasdiTaxOnLifeInsuranceOver50k > 0) ||       -- M
      decide (w2.uncollectedMedicareTaxOnLifeInsuranceOver50k > 0) ||    -- N
      decide (w2.armedForcesMovingExpenses > 0) ||                       -- P
      decide (w2.archerMsaContributions > 0) ||                          -- R
      decide (w2.adoptionBenefits > 0) ||                                -- T
      decide (w2.nqdcDeferrals > 0) ||                                   -- Z
      decide (w2.nonTaxableMedicaidWaiverPayments > 0) }                 -- II

/-! ### Scope `FormW2s` -/

/-- Inputs of `FormW2s`. -/
structure FormW2sIn where
  /-- Catala input `w2s`. -/
  w2s : List FormW2
  /-- Catala input `filing_status`. -/
  filingStatus : FilingStatus
  /-- Catala input `primary_filer_can_be_claimed`. -/
  primaryFilerCanBeClaimed : Bool
  /-- Catala input `secondary_filer_can_be_claimed`. -/
  secondaryFilerCanBeClaimed : Bool
  /-- Catala input `combat_pay_election`. -/
  combatPayElection : CombatPayElection

/-- Outputs of `FormW2s`. -/
structure FormW2sOut where
  /-- Catala output `wages`. -/
  wages : Int
  /-- Catala output `form_w2_withholding`. -/
  formW2Withholding : Int
  /-- Catala output `social_security_taxes_withheld`. -/
  socialSecurityTaxesWithheld : Int
  /-- Catala output `primary_filer_wages`. -/
  primaryFilerWages : Int
  /-- Catala output `secondary_filer_wages`. -/
  secondaryFilerWages : Int
  /-- Catala output `primary_filer_has_w2_wages_greater_than_0`. -/
  primaryFilerHasW2WagesGreaterThan0 : Bool
  /-- Catala output `secondary_filer_has_w2_wages_greater_than_0`. -/
  secondaryFilerHasW2WagesGreaterThan0 : Bool
  /-- Catala output `primary_filer_dependent_care_benefits`. -/
  primaryFilerDependentCareBenefits : Int
  /-- Catala output `secondary_filer_dependent_care_benefits`. -/
  secondaryFilerDependentCareBenefits : Int
  /-- Catala output `primary_filer_total_deferrals_and_contributions`. -/
  primaryFilerTotalDeferralsAndContributions : Int
  /-- Catala output `secondary_filer_total_deferrals_and_contributions`. -/
  secondaryFilerTotalDeferralsAndContributions : Int
  /-- Catala output `primary_filer_total_hsa_contributions_from_w2s`. -/
  primaryFilerTotalHsaContributionsFromW2s : Int
  /-- Catala output `secondary_filer_total_hsa_contributions_from_w2s`. -/
  secondaryFilerTotalHsaContributionsFromW2s : Int
  /-- Catala output `has_primary_filer_hsa_contributions_from_w2s`. -/
  hasPrimaryFilerHsaContributionsFromW2s : Bool
  /-- Catala output `has_secondary_filer_hsa_contributions_from_w2s`. -/
  hasSecondaryFilerHsaContributionsFromW2s : Bool
  /-- Catala output `total_hsa_contributions_on_w2s`. -/
  totalHsaContributionsOnW2s : Int
  /-- Catala output `has_hsa_contributions_on_w2`. -/
  hasHsaContributionsOnW2 : Bool
  /-- Catala output `primary_filer_combat_pay`. -/
  primaryFilerCombatPay : Int
  /-- Catala output `mfj_spouse_combat_pay`. -/
  mfjSpouseCombatPay : Int
  /-- Catala output `primary_filer_has_combat_pay`. -/
  primaryFilerHasCombatPay : Bool
  /-- Catala output `mfj_spouse_has_combat_pay`. -/
  mfjSpouseHasCombatPay : Bool
  /-- Catala output `some_filer_has_combat_pay`. -/
  someFilerHasCombatPay : Bool
  /-- Catala output `only_one_filer_has_combat_pay`. -/
  onlyOneFilerHasCombatPay : Bool
  /-- Catala output `only_primary_filer_has_combat_pay`. -/
  onlyPrimaryFilerHasCombatPay : Bool
  /-- Catala output `only_mfj_spouse_has_combat_pay`. -/
  onlyMfjSpouseHasCombatPay : Bool
  /-- Catala output `both_filers_has_combat_pay`. -/
  bothFilersHasCombatPay : Bool
  /-- Catala output `both_filers_combat_pay`. -/
  bothFilersCombatPay : Int
  /-- Catala output `combat_pay_amount`. -/
  combatPayAmount : Int
  /-- Catala output `all_combat_pay`. -/
  allCombatPay : Int
  /-- Catala output `form_w2_total_medicare_wages`. -/
  formW2TotalMedicareWages : Int
  /-- Catala output `primary_filer_medicare_wages`. -/
  primaryFilerMedicareWages : Int
  /-- Catala output `secondary_filer_medicare_wages`. -/
  secondaryFilerMedicareWages : Int
  /-- Catala output `max_medicare_wages_for_any_filer_on_return`. -/
  maxMedicareWagesForAnyFilerOnReturn : Int
  /-- Catala output `medicare_wages_additional_tax_threshold`. -/
  medicareWagesAdditionalTaxThreshold : Int
  /-- Catala output `any_filer_exceeds_eligible_for_medicare_wages_credit`. -/
  anyFilerExceedsEligibleForMedicareWagesCredit : Bool
  /-- Catala output `any_filer_required_to_pay_extra_medicare_tax`. -/
  anyFilerRequiredToPayExtraMedicareTax : Bool
  /-- Catala output `primary_filer_w2s_count`. -/
  primaryFilerW2sCount : Int
  /-- Catala output `secondary_filer_w2s_count`. -/
  secondaryFilerW2sCount : Int
  /-- Catala output `primary_filer_total_oasdi_wages_for_knockout`. -/
  primaryFilerTotalOasdiWagesForKnockout : Int
  /-- Catala output `secondary_filer_total_oasdi_wages_for_knockout`. -/
  secondaryFilerTotalOasdiWagesForKnockout : Int
  /-- Catala output `primary_filer_exceeds_max_oasdi_wages`. -/
  primaryFilerExceedsMaxOasdiWages : Bool
  /-- Catala output `secondary_filer_exceeds_max_oasdi_wages`. -/
  secondaryFilerExceedsMaxOasdiWages : Bool
  /-- Catala output `ko_flow_knockout_allocated_tips`. -/
  koFlowKnockoutAllocatedTips : Bool
  /-- Catala output `ko_flow_knockout_statutory_employee`. -/
  koFlowKnockoutStatutoryEmployee : Bool
  /-- Catala output `ko_flow_knockout_third_party_sick_pay`. -/
  koFlowKnockoutThirdPartySickPay : Bool
  /-- Catala output `ko_flow_knockout_non_qualified_plans`. -/
  koFlowKnockoutNonQualifiedPlans : Bool
  /-- Catala output `ko_knockout_for_box12_value`. -/
  koKnockoutForBox12Value : Bool
  /-- Catala output `ko_knockout_for_box12_dependency`. -/
  koKnockoutForBox12Dependency : Bool
  /-- Catala output `ko_knockout_medicare_wages`. -/
  koKnockoutMedicareWages : Bool
  /-- Catala output `ko_any_filer_exceeds_max_oasdi_wages`. -/
  koAnyFilerExceedsMaxOasdiWages : Bool
  /-- The union of every knockout of this module (CONVENTIONS section 6). -/
  unsupported : Bool

/-- Catala `scope FormW2s`. -/
def formW2s (i : FormW2sIn) : FormW2sOut :=
  let items := i.w2s.map formW2Item
  let primaryItems := items.filter fun x => x.filer == .primaryFiler
  let secondaryItems := items.filter fun x => x.filer == .secondaryFiler
  let isFilingStatusMfj := i.filingStatus == .marriedFilingJointly
  let isFilingStatusMfs := i.filingStatus == .marriedFilingSeparately
  -- wages, withholding
  let wages := roundDollar (sumBy (·.wages) items)
  let formW2Withholding := roundDollar (sumBy (·.federalWithholding) items)
  let socialSecurityTaxesWithheld :=
    roundDollar (sumBy (·.oasdiWithholding) items + sumBy (·.medicareWithholding) items)
  -- per filer
  let primaryFilerWages := sumBy (·.wages) primaryItems
  let secondaryFilerWages := sumBy (·.wages) secondaryItems
  let primaryFilerTotalHsa :=
    sumBy (fun x => roundDollar x.employerHsaContributionsRounded) primaryItems
  let secondaryFilerTotalHsa := sumBy (·.employerHsaContributionsRounded) secondaryItems
  let totalHsa :=
    if isFilingStatusMfj then primaryFilerTotalHsa + secondaryFilerTotalHsa
    else primaryFilerTotalHsa
  -- combat pay
  let primaryFilerCombatPay := sumBy (·.combatPay) primaryItems
  let mfjSpouseCombatPay :=
    if isFilingStatusMfj then sumBy (·.combatPay) secondaryItems else 0
  let primaryFilerHasCombatPay := decide (primaryFilerCombatPay > 0)
  let mfjSpouseHasCombatPay := decide (mfjSpouseCombatPay > 0)
  let onlyPrimaryFilerHasCombatPay := primaryFilerHasCombatPay && !mfjSpouseHasCombatPay
  let onlyMfjSpouseHasCombatPay := mfjSpouseHasCombatPay && !primaryFilerHasCombatPay
  let bothFilersHasCombatPay := mfjSpouseHasCombatPay && primaryFilerHasCombatPay
  let combatPayAmount :=
    roundDollar
      (if onlyPrimaryFilerHasCombatPay && i.combatPayElection == .usePrimaryCombatPay then
        primaryFilerCombatPay
       else if onlyMfjSpouseHasCombatPay && i.combatPayElection == .useSpouseCombatPay then
        mfjSpouseCombatPay
       else if bothFilersHasCombatPay && i.combatPayElection == .useBothCombatPay then
        mfjSpouseCombatPay + primaryFilerCombatPay
       else if bothFilersHasCombatPay && i.combatPayElection == .usePrimaryNotSpouseCombatPay then
        primaryFilerCombatPay
       else if bothFilersHasCombatPay && i.combatPayElection == .useSpouseNotPrimaryCombatPay then
        mfjSpouseCombatPay
       else 0)
  -- Medicare wages
  let formW2TotalMedicareWages := sumBy (·.medicareWages) items
  let primaryFilerMedicareWages := sumBy (·.medicareWages) primaryItems
  let secondaryFilerMedicareWages := sumBy (·.medicareWages) secondaryItems
  let medicareWagesAdditionalTaxThreshold :=
    if isFilingStatusMfs then Params.additionalMedicareTaxThresholdMarriedSeparate
    else if isFilingStatusMfj then Params.additionalMedicareTaxThresholdJoint
    else Params.additionalMedicareTaxThresholdOther
  let anyFilerExceedsEligibleForMedicareWagesCredit :=
    isFilingStatusMfj &&
      (decide (primaryFilerMedicareWages > Params.medicareWagesIndividualLimit) ||
        decide (secondaryFilerMedicareWages > Params.medicareWagesIndividualLimit))
  let koKnockoutMedicareWages :=
    anyFilerExceedsEligibleForMedicareWagesCredit ||
      decide (formW2TotalMedicareWages > medicareWagesAdditionalTaxThreshold)
  -- social security wage base
  let primaryFilerW2sCount : Int := primaryItems.length
  let secondaryFilerW2sCount : Int := secondaryItems.length
  let primaryFilerTotalOasdi := sumBy (·.oasdiWagesForKnockoutCalculation) primaryItems
  let secondaryFilerTotalOasdi := sumBy (·.oasdiWagesForKnockoutCalculation) secondaryItems
  let primaryFilerExceedsMaxOasdiWages :=
    decide (primaryFilerW2sCount > 1) && decide (primaryFilerTotalOasdi > Params.oasdiWageBase)
  let secondaryFilerExceedsMaxOasdiWages :=
    decide (secondaryFilerW2sCount > 1) && decide (secondaryFilerTotalOasdi > Params.oasdiWageBase)
  let koAnyFilerExceedsMaxOasdiWages :=
    primaryFilerExceedsMaxOasdiWages || secondaryFilerExceedsMaxOasdiWages
  -- knockouts
  let koFlowKnockoutAllocatedTips := items.any (·.causesAllocatedTipsKo)
  let koFlowKnockoutStatutoryEmployee := i.w2s.any (·.statutoryEmployee)
  let koFlowKnockoutThirdPartySickPay := i.w2s.any (·.thirdPartySickPay)
  let koFlowKnockoutNonQualifiedPlans := items.any (·.causesNonQualifiedPlansKo)
  let koKnockoutForBox12Value := items.any (·.hasBox12KnockoutCode)
  let koKnockoutForBox12Dependency :=
    items.any fun x =>
      decide (x.employerHsaContributionsRounded > 0) &&
        ((x.filer == .primaryFiler && i.primaryFilerCanBeClaimed) ||
          (x.filer == .secondaryFiler && i.secondaryFilerCanBeClaimed))
  { wages := wages
    formW2Withholding := formW2Withholding
    socialSecurityTaxesWithheld := socialSecurityTaxesWithheld
    primaryFilerWages := primaryFilerWages
    secondaryFilerWages := secondaryFilerWages
    primaryFilerHasW2WagesGreaterThan0 := decide (primaryFilerWages > 0)
    secondaryFilerHasW2WagesGreaterThan0 := decide (secondaryFilerWages > 0)
    primaryFilerDependentCareBenefits :=
      roundDollar (sumBy (·.dependentCareBenefits) primaryItems)
    secondaryFilerDependentCareBenefits :=
      roundDollar (sumBy (·.dependentCareBenefits) secondaryItems)
    primaryFilerTotalDeferralsAndContributions :=
      sumBy (·.totalDeferralsAndContributions) primaryItems
    secondaryFilerTotalDeferralsAndContributions :=
      sumBy (·.totalDeferralsAndContributions) secondaryItems
    primaryFilerTotalHsaContributionsFromW2s := primaryFilerTotalHsa
    secondaryFilerTotalHsaContributionsFromW2s := secondaryFilerTotalHsa
    hasPrimaryFilerHsaContributionsFromW2s := decide (primaryFilerTotalHsa > 0)
    hasSecondaryFilerHsaContributionsFromW2s := decide (secondaryFilerTotalHsa > 0)
    totalHsaContributionsOnW2s := totalHsa
    hasHsaContributionsOnW2 := decide (totalHsa > 0)
    primaryFilerCombatPay := primaryFilerCombatPay
    mfjSpouseCombatPay := mfjSpouseCombatPay
    primaryFilerHasCombatPay := primaryFilerHasCombatPay
    mfjSpouseHasCombatPay := mfjSpouseHasCombatPay
    someFilerHasCombatPay := mfjSpouseHasCombatPay || primaryFilerHasCombatPay
    onlyOneFilerHasCombatPay :=
      (!isFilingStatusMfj && primaryFilerHasCombatPay) ||
      (isFilingStatusMfj && mfjSpouseHasCombatPay && !primaryFilerHasCombatPay) ||
      (isFilingStatusMfj && !mfjSpouseHasCombatPay && primaryFilerHasCombatPay)
    onlyPrimaryFilerHasCombatPay := onlyPrimaryFilerHasCombatPay
    onlyMfjSpouseHasCombatPay := onlyMfjSpouseHasCombatPay
    bothFilersHasCombatPay := bothFilersHasCombatPay
    bothFilersCombatPay := primaryFilerCombatPay + mfjSpouseCombatPay
    combatPayAmount := combatPayAmount
    allCombatPay := roundDollar (sumBy (·.combatPay) items)
    formW2TotalMedicareWages := formW2TotalMedicareWages
    primaryFilerMedicareWages := primaryFilerMedicareWages
    secondaryFilerMedicareWages := secondaryFilerMedicareWages
    maxMedicareWagesForAnyFilerOnReturn :=
      Money.max primaryFilerMedicareWages secondaryFilerMedicareWages
    medicareWagesAdditionalTaxThreshold := medicareWagesAdditionalTaxThreshold
    anyFilerExceedsEligibleForMedicareWagesCredit := anyFilerExceedsEligibleForMedicareWagesCredit
    anyFilerRequiredToPayExtraMedicareTax :=
      koKnockoutMedicareWages && !anyFilerExceedsEligibleForMedicareWagesCredit
    primaryFilerW2sCount := primaryFilerW2sCount
    secondaryFilerW2sCount := secondaryFilerW2sCount
    primaryFilerTotalOasdiWagesForKnockout := primaryFilerTotalOasdi
    secondaryFilerTotalOasdiWagesForKnockout := secondaryFilerTotalOasdi
    primaryFilerExceedsMaxOasdiWages := primaryFilerExceedsMaxOasdiWages
    secondaryFilerExceedsMaxOasdiWages := secondaryFilerExceedsMaxOasdiWages
    koFlowKnockoutAllocatedTips := koFlowKnockoutAllocatedTips
    koFlowKnockoutStatutoryEmployee := koFlowKnockoutStatutoryEmployee
    koFlowKnockoutThirdPartySickPay := koFlowKnockoutThirdPartySickPay
    koFlowKnockoutNonQualifiedPlans := koFlowKnockoutNonQualifiedPlans
    koKnockoutForBox12Value := koKnockoutForBox12Value
    koKnockoutForBox12Dependency := koKnockoutForBox12Dependency
    koKnockoutMedicareWages := koKnockoutMedicareWages
    koAnyFilerExceedsMaxOasdiWages := koAnyFilerExceedsMaxOasdiWages
    unsupported :=
      koKnockoutForBox12Value || koKnockoutForBox12Dependency ||
      koFlowKnockoutAllocatedTips || koFlowKnockoutStatutoryEmployee ||
      koFlowKnockoutThirdPartySickPay || koFlowKnockoutNonQualifiedPlans ||
      koKnockoutMedicareWages || koAnyFilerExceedsMaxOasdiWages }

/-! ### Unit tests: every assertion of `catala/tests/test_form_w2s.catala_en`

The helper `f` runs `formW2s` with the Catala tests' usual defaults (`Single`,
nobody claimable, no combat pay election); `sec` marks a spouse's W-2. -/

private def f (w2s : List FormW2) (fs : FilingStatus := .single)
    (pc : Bool := false) (sc : Bool := false)
    (e : CombatPayElection := .noCombatPay) : FormW2sOut :=
  formW2s { w2s := w2s, filingStatus := fs, primaryFilerCanBeClaimed := pc,
            secondaryFilerCanBeClaimed := sc, combatPayElection := e }

-- TestPerItemRounding: per-item rounding (quirk Q-R1)
private def perItem : FormW2sOut := f [
  { writableWages := 3000040, writableFederalWithholding := 300049,
    writableOasdiWithholding := 186040, writableMedicareWithholding := 43540 },
  { writableWages := 2000040, writableFederalWithholding := 200049,
    writableOasdiWithholding := 124040, writableMedicareWithholding := 29040 }]
#guard perItem.wages == 5_000_000
#guard perItem.wages != 5_000_100
#guard perItem.formW2Withholding == 500_000
#guard perItem.socialSecurityTaxesWithheld == 382_500
#guard !perItem.unsupported

-- TestWagesTie
#guard (f [{ writableWages := 1000050 }, { writableWages := 49 }]).wages == 1_000_100

-- TestMfjSplit
private def mfjSplit : FormW2sOut := f (fs := .marriedFilingJointly) [
  { writableWages := 4000000, writableDependentCareBenefits := 100000 },
  { writableWages := 500040, writableDependentCareBenefits := 250000 },
  { filer := .secondaryFiler, writableWages := 3000070 }]
#guard mfjSplit.primaryFilerWages == 4_500_000
#guard mfjSplit.secondaryFilerWages == 3_000_100
#guard mfjSplit.wages == 7_500_100
#guard mfjSplit.primaryFilerHasW2WagesGreaterThan0
#guard mfjSplit.secondaryFilerHasW2WagesGreaterThan0
#guard mfjSplit.primaryFilerDependentCareBenefits == 350_000
#guard mfjSplit.secondaryFilerDependentCareBenefits == 0
#guard mfjSplit.primaryFilerW2sCount == 2
#guard mfjSplit.secondaryFilerW2sCount == 1
#guard !mfjSplit.unsupported

-- TestSecondaryW2NotMfj
private def notMfj : FormW2sOut := f (fs := .marriedFilingSeparately) [
  { writableWages := 1000000 },
  { filer := .secondaryFiler, writableWages := 2000000, writableCombatPay := 70000 }]
#guard notMfj.wages == 3_000_000
#guard notMfj.mfjSpouseCombatPay == 0
#guard notMfj.allCombatPay == 70_000
#guard !notMfj.someFilerHasCombatPay

-- TestDeferrals
private def deferralsW2 (gov : Bool) : FormW2 :=
  { writableWages := 5000000, deferrals401k := 400040, deferrals403b := 100000,
    deferrals457b := 200060, deferrals501c18 := 30000, simpleContributions := 15000,
    roth401kContributions := 50000, roth403bContributions := 25000,
    roth457bContributions := 12500, plan457bIsGovernmental := gov }
#guard (f [deferralsW2 true]).primaryFilerTotalDeferralsAndContributions == 832_600
#guard (f [deferralsW2 false]).primaryFilerTotalDeferralsAndContributions == 632_500
#guard (f [deferralsW2 false]).primaryFilerTotalDeferralsAndContributions != 832_600
#guard (f [deferralsW2 true]).secondaryFilerTotalDeferralsAndContributions == 0
#guard !(f [deferralsW2 true]).unsupported
#guard !(f [deferralsW2 false]).unsupported

-- TestCombatPay
private def combatW2s : List FormW2 :=
  [{ writableCombatPay := 500040 }, { filer := .secondaryFiler, writableCombatPay := 300000 }]
private def combat (e : CombatPayElection) : FormW2sOut :=
  f (fs := .marriedFilingJointly) (e := e) combatW2s
#guard (combat .noCombatPay).primaryFilerCombatPay == 500_000
#guard (combat .noCombatPay).mfjSpouseCombatPay == 300_000
#guard (combat .noCombatPay).bothFilersHasCombatPay
#guard !(combat .noCombatPay).onlyOneFilerHasCombatPay
#guard (combat .noCombatPay).allCombatPay == 800_000
#guard (combat .noCombatPay).combatPayAmount == 0
#guard (combat .usePrimaryNotSpouseCombatPay).combatPayAmount == 500_000
#guard (combat .useBothCombatPay).combatPayAmount == 800_000
#guard (combat .useSpouseNotPrimaryCombatPay).combatPayAmount == 300_000

-- TestCombatPayOptionMismatch
#guard (f (fs := .marriedFilingJointly) (e := .usePrimaryCombatPay)
  [{ writableCombatPay := 500000 }, { filer := .secondaryFiler, writableCombatPay := 300000 }]
  ).combatPayAmount == 0

-- TestHsaContributions
private def hsaW2s : List FormW2 :=
  [{ employerHsaContributions := 120040 }, { filer := .secondaryFiler, employerHsaContributions := 80000 }]
#guard (f (fs := .marriedFilingJointly) hsaW2s).primaryFilerTotalHsaContributionsFromW2s == 120_000
#guard (f (fs := .marriedFilingJointly) hsaW2s).secondaryFilerTotalHsaContributionsFromW2s == 80_000
#guard (f (fs := .marriedFilingJointly) hsaW2s).hasPrimaryFilerHsaContributionsFromW2s
#guard (f (fs := .marriedFilingJointly) hsaW2s).hasSecondaryFilerHsaContributionsFromW2s
#guard (f (fs := .marriedFilingJointly) hsaW2s).totalHsaContributionsOnW2s == 200_000
#guard (f hsaW2s).totalHsaContributionsOnW2s == 120_000
#guard (f hsaW2s).hasHsaContributionsOnW2

-- TestW2Knockouts
#guard (f [{ writableAllocatedTips := 10000 }]).koFlowKnockoutAllocatedTips
#guard (f [{ writableAllocatedTips := 10000 }]).unsupported
#guard !(f [{ writableAllocatedTips := 49 }]).koFlowKnockoutAllocatedTips
#guard !(f [{ writableAllocatedTips := 49 }]).unsupported
#guard (f [{ writableNonQualifiedPlans := 100000 }]).koFlowKnockoutNonQualifiedPlans
#guard (f [{ writableNonQualifiedPlans := 100000 }]).unsupported
#guard (f [{ statutoryEmployee := true }]).koFlowKnockoutStatutoryEmployee
#guard (f [{ statutoryEmployee := true }]).unsupported
#guard (f [{ thirdPartySickPay := true }]).koFlowKnockoutThirdPartySickPay
#guard (f [{ thirdPartySickPay := true }]).unsupported

-- TestBox12Knockouts
#guard (f [{ uncollectedOasdiTaxOnTips := 40 }]).koKnockoutForBox12Value
#guard (f [{ uncollectedOasdiTaxOnTips := 40 }]).unsupported
#guard (f [{ goldenParachuteExciseTax := 5000 }]).koKnockoutForBox12Value
#guard (f [{ nonTaxableMedicaidWaiverPayments := 100 }]).koKnockoutForBox12Value
#guard !(f [{ taxableLifeInsuranceOver50k := 1234 }]).koKnockoutForBox12Value
#guard !(f [{ taxableLifeInsuranceOver50k := 1234 }]).unsupported
#guard !(f [{ writableCombatPay := 50000 }]).koKnockoutForBox12Value
#guard !(f [{ writableCombatPay := 50000 }]).unsupported
#guard !(f [{ employerHsaContributions := 100000 }]).koKnockoutForBox12Value
#guard !(f [{ employerHsaContributions := 100000 }]).koKnockoutForBox12Dependency
#guard !(f [{ employerHsaContributions := 100000 }]).unsupported
#guard (f (pc := true) [{ employerHsaContributions := 100000 }]).koKnockoutForBox12Dependency
#guard !(f (pc := true) [{ employerHsaContributions := 100000 }]).koKnockoutForBox12Value
#guard (f (pc := true) [{ employerHsaContributions := 100000 }]).unsupported

-- TestMedicareWages
private def med (v : Int) (filer : FilerRole := .primaryFiler) : FormW2 :=
  { filer := filer, writableMedicareWages := v }
private def singleAt := f [med 20_000_000]
private def singleOver := f (fs := .headOfHousehold) [med 20_000_100]
private def mfsOver := f (fs := .marriedFilingSeparately) [med 12_500_100]
private def mfsAt := f (fs := .marriedFilingSeparately) [med 12_500_000]
private def jointAt := f (fs := .marriedFilingJointly) [med 12_500_000, med 12_500_000 .secondaryFiler]
private def jointOver := f (fs := .marriedFilingJointly) [med 20_000_100, med 12_500_000 .secondaryFiler]
private def splitOver := f (fs := .marriedFilingJointly) [med 20_000_100, med 1_000_000 .secondaryFiler]
#guard singleAt.medicareWagesAdditionalTaxThreshold == Params.additionalMedicareTaxThresholdOther
#guard singleAt.formW2TotalMedicareWages == 20_000_000
#guard !singleAt.koKnockoutMedicareWages
#guard !singleAt.unsupported
#guard singleOver.koKnockoutMedicareWages
#guard singleOver.anyFilerRequiredToPayExtraMedicareTax
#guard singleOver.unsupported
#guard mfsAt.medicareWagesAdditionalTaxThreshold == 12_500_000
#guard !mfsAt.koKnockoutMedicareWages
#guard mfsOver.koKnockoutMedicareWages
#guard jointAt.medicareWagesAdditionalTaxThreshold == 25_000_000
#guard !jointAt.koKnockoutMedicareWages
#guard !jointAt.anyFilerExceedsEligibleForMedicareWagesCredit
#guard !jointAt.unsupported
#guard jointOver.koKnockoutMedicareWages
#guard jointOver.anyFilerExceedsEligibleForMedicareWagesCredit
#guard !jointOver.anyFilerRequiredToPayExtraMedicareTax
#guard splitOver.formW2TotalMedicareWages == 21_000_100
#guard splitOver.anyFilerExceedsEligibleForMedicareWagesCredit
#guard splitOver.koKnockoutMedicareWages
#guard splitOver.unsupported
#guard splitOver.maxMedicareWagesForAnyFilerOnReturn == 20_000_100

-- TestOasdiWageBase
private def oas (v : Int) (filer : FilerRole := .primaryFiler) : FormW2 :=
  { filer := filer, writableOasdiWages := v }
private def atBase := f [oas 10_000_000, oas 6_860_000]
private def overBase := f [oas 10_000_000, oas 6_860_100]
private def oneW2 := f [oas 20_000_000]
private def spousesApart := f (fs := .marriedFilingJointly) [oas 10_000_000, oas 10_000_000 .secondaryFiler]
#guard atBase.primaryFilerTotalOasdiWagesForKnockout == 16_860_000
#guard !atBase.koAnyFilerExceedsMaxOasdiWages
#guard overBase.primaryFilerTotalOasdiWagesForKnockout == 16_860_100
#guard overBase.primaryFilerExceedsMaxOasdiWages
#guard overBase.koAnyFilerExceedsMaxOasdiWages
#guard overBase.unsupported
#guard oneW2.primaryFilerTotalOasdiWagesForKnockout == 16_860_000
#guard !oneW2.koAnyFilerExceedsMaxOasdiWages
#guard !spousesApart.koAnyFilerExceedsMaxOasdiWages
#guard spousesApart.primaryFilerW2sCount == 1
#guard spousesApart.secondaryFilerW2sCount == 1

-- TestOrdinaryReturn
private def ordinary : FormW2sOut := f [
  { writableWages := 5200000, writableFederalWithholding := 410000, writableOasdiWages := 5200000,
    writableOasdiWithholding := 322400, writableMedicareWages := 5200000,
    writableMedicareWithholding := 75400 }]
#guard ordinary.wages == 5_200_000
#guard ordinary.formW2Withholding == 410_000
#guard ordinary.socialSecurityTaxesWithheld == 397_800
#guard !ordinary.unsupported
#guard ordinary.wages != 5_199_900
#guard ordinary.formW2Withholding != 0
#guard ordinary.socialSecurityTaxesWithheld != 322_400

end UsTax.FormW2s
