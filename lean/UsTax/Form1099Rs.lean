import UsTax.Money
import UsTax.Lists
import UsTax.Types
import UsTax.Date

/-!
# Form 1099-R: pensions and annuities (Form 1040 lines 5a, 5b and 25b) (issue #45)

Lean implementation of `catala/form1099_rs.catala_en` (module `Form1099_rs`, scopes
`Form1099RItem` and `Form1099Rs`), written by hand from the Catala source under
strategy (c) of `docs/catala-to-lean.md`; the code that runs.

| Catala (`Form1099_rs`)            | Lean (`UsTax.Form1099Rs`)                         |
|-----------------------------------|---------------------------------------------------|
| `enumeration CodeChar`            | `CodeChar` (`code2`, ..., `otherCode`)            |
| `structure Form1099R`             | `Form1099R`                                       |
| `total_distribution_start_date`   | `totalDistributionStartDate`                      |
| `scope Form1099RItem`             | `Form1099RItem` (`form1099RItem : Form1099R → Form1099RItem`) |
| `scope Form1099Rs`                | `Form1099RsIn` → `Form1099RsOut` (`form1099Rs`)   |
| `items`, `primary_items`, ...     | `items`, `primaryItems`, ... (local `let`s)       |

Money is `Int` cents. DF-BUG(1) (the whole distribution code is tested, so `7D`
is a knockout) and DF-BUG(8) (box 8 "0.00" is not a knockout) are as in Catala.
-/

namespace UsTax.Form1099Rs

open Money

/-- One character of the box 7 distribution code (Catala `CodeChar`). -/
inductive CodeChar where
  /-- Code 2. -/
  | code2
  /-- Code 4. -/
  | code4
  /-- Code 7. -/
  | code7
  /-- Code B. -/
  | codeB
  /-- Code G. -/
  | codeG
  /-- Code H. -/
  | codeH
  /-- Any other accepted character. -/
  | otherCode
  deriving DecidableEq, Repr, Inhabited

namespace CodeChar

/-- Parse a Catala case name (`"Code7"`). -/
def ofString? : String → Option CodeChar
  | "Code2" => some code2
  | "Code4" => some code4
  | "Code7" => some code7
  | "CodeB" => some codeB
  | "CodeG" => some codeG
  | "CodeH" => some codeH
  | "OtherCode" => some otherCode
  | _ => none

end CodeChar

/-- One Form 1099-R as the filer typed it (Catala `Form1099R`). Defaults are the
Catala test helper `MkR`: a plain code 7 form with every box `$0`. -/
structure Form1099R where
  /-- Catala `filer`. -/
  filer : FilerRole := .primaryFiler
  /-- Catala `distribution_code`. -/
  distributionCode : List CodeChar := [.code7]
  /-- Catala `writable_gross_distribution`. -/
  writableGrossDistribution : Int := 0
  /-- Catala `writable_taxable_amount`. -/
  writableTaxableAmount : Int := 0
  /-- Catala `taxable_amount_blank`. -/
  taxableAmountBlank : Bool := false
  /-- Catala `taxable_amount_not_determined`. -/
  taxableAmountNotDetermined : Bool := false
  /-- Catala `total_distribution`. -/
  totalDistribution : Bool := false
  /-- Catala `writable_capital_gain`. -/
  writableCapitalGain : Int := 0
  /-- Catala `writable_federal_withholding`. -/
  writableFederalWithholding : Int := 0
  /-- Catala `writable_net_appreciation`. -/
  writableNetAppreciation : Int := 0
  /-- Catala `ira_sep_simple`. -/
  iraSepSimple : Bool := false
  /-- Catala `writable_other_dollar`. -/
  writableOtherDollar : Int := 0
  /-- Catala `other_percentage_nonzero`. -/
  otherPercentageNonzero : Bool := false
  /-- Catala `percentage_total_distribution_nonzero`. -/
  percentageTotalDistributionNonzero : Bool := false
  /-- Catala `writable_amount_allocable_to_irr`. -/
  writableAmountAllocableToIrr : Int := 0
  /-- Catala `facta_filing_requirement`. -/
  factaFilingRequirement : Bool := false
  /-- Catala `writable_state_tax_withheld`. -/
  writableStateTaxWithheld : Int := 0
  /-- Catala `payer_state_is_different`. -/
  payerStateIsDifferent : Bool := false
  /-- Catala `has_death_benefit_payment_date`. -/
  hasDeathBenefitPaymentDate : Bool := false
  /-- Catala `writable_is_indirect_rollover`. -/
  writableIsIndirectRollover : Bool := false
  /-- Catala `writable_is_distribution_from_military_retirement_plan`. -/
  writableIsDistributionFromMilitaryRetirementPlan : Bool := false
  /-- Catala `writable_qualified_disaster_distribution`. -/
  writableQualifiedDisasterDistribution : Bool := false
  /-- Catala `writeable_public_safety_officer`. -/
  writeablePublicSafetyOfficer : Bool := false
  /-- Catala `writeable_public_safety_officer_premiums`. -/
  writeablePublicSafetyOfficerPremiums : Bool := false
  /-- Catala `recipient_date_of_birth`. -/
  recipientDateOfBirth : Date := { year := 1964, month := 8, day := 2 }

/-- Catala `total_distribution_start_date`, `|1936-01-02|`. -/
def totalDistributionStartDate : Date := { year := 1936, month := 1, day := 2 }

/-- `a < b` on calendar dates (Catala date comparison). -/
def dateBefore (a b : Date) : Bool :=
  decide (a.year < b.year) ||
    (a.year == b.year && (decide (a.month < b.month) || (a.month == b.month && decide (a.day < b.day))))

/-- Outputs of `Form1099RItem`: one 1099-R and everything the return reads from it. -/
structure Form1099RItem where
  /-- Catala `filer`. -/
  filer : FilerRole
  /-- Catala `gross_distribution` (box 1, rounded). -/
  grossDistribution : Int
  /-- Catala `taxable_amount` (box 2a, rounded). -/
  taxableAmount : Int
  /-- Catala `federal_withholding` (box 4, rounded). -/
  federalWithholding : Int
  /-- Catala `has_supported_distribution_code`. -/
  hasSupportedDistributionCode : Bool
  /-- Catala `is_direct_rollover`. -/
  isDirectRollover : Bool
  /-- Catala `not_ira_sep_simple`. -/
  notIraSepSimple : Bool
  /-- Catala `flow_ask_about_indirect_rollover`. -/
  flowAskAboutIndirectRollover : Bool
  /-- Catala `indicated_has_indirect_rollover`. -/
  indicatedHasIndirectRollover : Bool
  /-- Catala `has_distribution_code_included_in_savers_credit`. -/
  hasDistributionCodeIncludedInSaversCredit : Bool
  /-- Catala `is_reported_on_savers_credit`. -/
  isReportedOnSaversCredit : Bool
  /-- Catala `is_tax_free_pension_rollover`. -/
  isTaxFreePensionRollover : Bool
  /-- Catala `is_taxable_pension_rollover`. -/
  isTaxablePensionRollover : Bool
  /-- Catala `is_indirect_rollover`. -/
  isIndirectRollover : Bool
  /-- Catala `is_taxable_amount_not_determined`. -/
  isTaxableAmountNotDetermined : Bool
  /-- Catala `is_fully_or_partly_taxable_pension`. -/
  isFullyOrPartlyTaxablePension : Bool
  /-- Catala `is_fully_taxable`. -/
  isFullyTaxable : Bool
  /-- Catala `is_partly_taxable_pension`. -/
  isPartlyTaxablePension : Bool
  /-- Catala `ko_has_unsupported_distribution_code`. -/
  koHasUnsupportedDistributionCode : Bool
  /-- Catala `ko_ira_sep_simple`. -/
  koIraSepSimple : Bool
  /-- Catala `ko_taxable_pension_rollover`. -/
  koTaxablePensionRollover : Bool
  /-- Catala `ko_indirect_rollover`. -/
  koIndirectRollover : Bool
  /-- Catala `ko_taxable_amount_not_determined`. -/
  koTaxableAmountNotDetermined : Bool
  /-- Catala `ko_causes_rollover`. -/
  koCausesRollover : Bool
  /-- Catala `ko_causes_pre_tax_to_post_tax_rollover`. -/
  koCausesPreTaxToPostTaxRollover : Bool
  /-- Catala `ko_retirement_taxable_amount_not_determined`. -/
  koRetirementTaxableAmountNotDetermined : Bool
  /-- Catala `ko_retirement_taxable_amount_blank`. -/
  koRetirementTaxableAmountBlank : Bool
  /-- Catala `ko_retirement_total_distribution`. -/
  koRetirementTotalDistribution : Bool
  /-- Catala `ko_box_8_value`. -/
  koBox8Value : Bool
  /-- Catala `ko_box_8_percentage`. -/
  koBox8Percentage : Bool
  /-- Catala `ko_box_9a_percentage`. -/
  koBox9aPercentage : Bool
  /-- Catala `ko_capital_gain`. -/
  koCapitalGain : Bool
  /-- Catala `ko_net_unrealized_appreciation`. -/
  koNetUnrealizedAppreciation : Bool
  /-- Catala `ko_amount_allocable_to_irr`. -/
  koAmountAllocableToIrr : Bool
  /-- Catala `ko_facta_filing_requirement`. -/
  koFactaFilingRequirement : Bool
  /-- Catala `ko_death_benefit_payment`. -/
  koDeathBenefitPayment : Bool
  /-- Catala `ko_qualified_disaster_distribution`. -/
  koQualifiedDisasterDistribution : Bool
  /-- Catala `ko_public_safety_officer_premiums`. -/
  koPublicSafetyOfficerPremiums : Bool
  /-- Catala `ko_box_15`. -/
  koBox15 : Bool
  /-- Catala `unsupported` (any of the above). -/
  unsupported : Bool

/-- Catala `scope Form1099RItem`. -/
def form1099RItem (form : Form1099R) : Form1099RItem :=
  let grossDistribution := roundDollar form.writableGrossDistribution
  let taxableAmount := roundDollar form.writableTaxableAmount
  let codeLength := form.distributionCode.length
  let has (c : CodeChar) := form.distributionCode.any (· == c)
  let has2 := has .code2
  let has4 := has .code4
  let has7 := has .code7
  let hasB := has .codeB
  let hasG := has .codeG
  let hasH := has .codeH
  let hasSupported :=
    (codeLength == 1 && (has2 || has7 || hasG || hasH)) ||
    (codeLength == 2 &&
      ((has2 && hasB) || (has7 && hasB) || (hasB && hasG) || (has4 && hasG) || (has4 && hasH)))
  let isDirectRollover := hasG || hasH
  let notIra := !form.iraSepSimple
  let flowAsk := has2 || has7
  let indicated := flowAsk && form.writableIsIndirectRollover
  let includedInSavers :=
    (codeLength == 1 && (has2 || has7)) || (codeLength == 2 && hasB && (has2 || has7))
  let taxFreeRollover := notIra && isDirectRollover && taxableAmount == 0
  let taxableRollover := notIra && isDirectRollover && decide (taxableAmount > 0)
  let indirectRollover := notIra && !isDirectRollover && indicated
  let notDetermined := notIra && !isDirectRollover && form.taxableAmountNotDetermined
  let fullyOrPartly :=
    !form.iraSepSimple && !notDetermined && !indirectRollover && includedInSavers
  let koBox15 :=
    form.payerStateIsDifferent &&
      (decide (roundDollar form.writableStateTaxWithheld > 0) || !isDirectRollover)
  let koUnsupportedCode := !hasSupported
  let koPreTax := isDirectRollover && decide (taxableAmount > 0)
  let koNotDetermined := form.taxableAmountNotDetermined
  let koBlank := form.taxableAmountBlank && !form.taxableAmountNotDetermined
  let koTotal :=
    form.totalDistribution && dateBefore form.recipientDateOfBirth totalDistributionStartDate
  let koB8 := decide (roundDollar form.writableOtherDollar > 0)
  let koCg := decide (roundDollar form.writableCapitalGain > 0)
  let koNua := decide (roundDollar form.writableNetAppreciation > 0)
  let koIrr := decide (roundDollar form.writableAmountAllocableToIrr > 0)
  let koDisaster := flowAsk && form.writableQualifiedDisasterDistribution
  let koPso :=
    (has2 || has7) && !hasB && form.writeablePublicSafetyOfficer &&
      form.writeablePublicSafetyOfficerPremiums
  { filer := form.filer
    grossDistribution := grossDistribution
    taxableAmount := taxableAmount
    federalWithholding := roundDollar form.writableFederalWithholding
    hasSupportedDistributionCode := hasSupported
    isDirectRollover := isDirectRollover
    notIraSepSimple := notIra
    flowAskAboutIndirectRollover := flowAsk
    indicatedHasIndirectRollover := indicated
    hasDistributionCodeIncludedInSaversCredit := includedInSavers
    isReportedOnSaversCredit :=
      includedInSavers && !form.writableIsDistributionFromMilitaryRetirementPlan
    isTaxFreePensionRollover := taxFreeRollover
    isTaxablePensionRollover := taxableRollover
    isIndirectRollover := indirectRollover
    isTaxableAmountNotDetermined := notDetermined
    isFullyOrPartlyTaxablePension := fullyOrPartly
    isFullyTaxable := fullyOrPartly && grossDistribution == taxableAmount
    isPartlyTaxablePension := fullyOrPartly && grossDistribution != taxableAmount
    koHasUnsupportedDistributionCode := koUnsupportedCode
    koIraSepSimple := form.iraSepSimple
    koTaxablePensionRollover := taxableRollover
    koIndirectRollover := indirectRollover
    koTaxableAmountNotDetermined := notDetermined
    koCausesRollover := indicated
    koCausesPreTaxToPostTaxRollover := koPreTax
    koRetirementTaxableAmountNotDetermined := koNotDetermined
    koRetirementTaxableAmountBlank := koBlank
    koRetirementTotalDistribution := koTotal
    koBox8Value := koB8
    koBox8Percentage := form.otherPercentageNonzero
    koBox9aPercentage := form.percentageTotalDistributionNonzero
    koCapitalGain := koCg
    koNetUnrealizedAppreciation := koNua
    koAmountAllocableToIrr := koIrr
    koFactaFilingRequirement := form.factaFilingRequirement
    koDeathBenefitPayment := form.hasDeathBenefitPaymentDate
    koQualifiedDisasterDistribution := koDisaster
    koPublicSafetyOfficerPremiums := koPso
    koBox15 := koBox15
    unsupported :=
      koUnsupportedCode || form.iraSepSimple || taxableRollover || indirectRollover ||
      notDetermined || indicated || koPreTax || koNotDetermined || koBlank || koTotal ||
      koB8 || form.otherPercentageNonzero || form.percentageTotalDistributionNonzero ||
      koCg || koNua || koIrr || form.factaFilingRequirement || form.hasDeathBenefitPaymentDate ||
      koDisaster || koPso || koBox15 }

/-- Inputs of `Form1099Rs`. -/
structure Form1099RsIn where
  /-- Catala input `forms`. -/
  forms : List Form1099R

/-- Outputs of `Form1099Rs`. -/
structure Form1099RsOut where
  /-- Catala `tax_free_pension_rollovers`. -/
  taxFreePensionRollovers : Int
  /-- Catala `partly_taxable_pensions`. -/
  partlyTaxablePensions : Int
  /-- Catala `fully_taxable_pensions`. -/
  fullyTaxablePensions : Int
  /-- Catala `taxable_amounts_of_partially_taxable_pensions`. -/
  taxableAmountsOfPartiallyTaxablePensions : Int
  /-- Form 1040 line 5a. -/
  line5a : Int
  /-- Form 1040 line 5b. -/
  line5b : Int
  /-- Catala `line_5b_is_blank`. -/
  line5bIsBlank : Bool
  /-- Catala `has_direct_rollover`. -/
  hasDirectRollover : Bool
  /-- Catala `non_taxable_pensions_and_annuities`. -/
  nonTaxablePensionsAndAnnuities : Int
  /-- The 1099-R part of line 25b. -/
  form1099rFederalIncomeTaxWithheld : Int
  /-- Form 8880 line 4, primary filer. -/
  primaryFilerSaversGrossDistributions : Int
  /-- Form 8880 line 4, secondary filer. -/
  secondaryFilerSaversGrossDistributions : Int
  /-- Catala `ko_knockout_for_form1099_r_distribution_code`. -/
  koKnockoutForForm1099RDistributionCode : Bool
  /-- Catala `ko_knockout_ira_sep_simple`. -/
  koKnockoutIraSepSimple : Bool
  /-- Catala `ko_knockout_taxable_pension_rollover`. -/
  koKnockoutTaxablePensionRollover : Bool
  /-- Catala `ko_knockout_indirect_rollover`. -/
  koKnockoutIndirectRollover : Bool
  /-- Catala `ko_knockout_taxable_amount_not_determined`. -/
  koKnockoutTaxableAmountNotDetermined : Bool
  /-- Catala `ko_flow_knockout_for_rollover`. -/
  koFlowKnockoutForRollover : Bool
  /-- Catala `ko_flow_knockout_for_pre_tax_to_post_tax_rollover`. -/
  koFlowKnockoutForPreTaxToPostTaxRollover : Bool
  /-- Catala `ko_flow_knockout_retirement_taxable_amount_not_determined`. -/
  koFlowKnockoutRetirementTaxableAmountNotDetermined : Bool
  /-- Catala `ko_flow_knockout_retirement_taxable_amount_blank`. -/
  koFlowKnockoutRetirementTaxableAmountBlank : Bool
  /-- Catala `ko_flow_knockout_retirement_total_distribution`. -/
  koFlowKnockoutRetirementTotalDistribution : Bool
  /-- Catala `ko_knockout_for_form1099_r_box8_value`. -/
  koKnockoutForForm1099RBox8Value : Bool
  /-- Catala `ko_knockout_for_form1099_r_box8_percentage`. -/
  koKnockoutForForm1099RBox8Percentage : Bool
  /-- Catala `ko_knockout_for_form1099_r_box9a_percentage`. -/
  koKnockoutForForm1099RBox9aPercentage : Bool
  /-- Catala `ko_flow_knockout_retirement_capital_gain`. -/
  koFlowKnockoutRetirementCapitalGain : Bool
  /-- Catala `ko_flow_knockout_retirement_net_unrealized_appreciation`. -/
  koFlowKnockoutRetirementNetUnrealizedAppreciation : Bool
  /-- Catala `ko_flow_knockout_retirement_amount_allocable_to_irr`. -/
  koFlowKnockoutRetirementAmountAllocableToIrr : Bool
  /-- Catala `ko_flow_knockout_retirement_facta_filing_requirement`. -/
  koFlowKnockoutRetirementFactaFilingRequirement : Bool
  /-- Catala `ko_flow_knockout_for_death_benefit_payment_date`. -/
  koFlowKnockoutForDeathBenefitPaymentDate : Bool
  /-- Catala `ko_flow_knockout_retirement_qualified_disaster_distribution`. -/
  koFlowKnockoutRetirementQualifiedDisasterDistribution : Bool
  /-- Catala `ko_flow_knockout_retirement_public_safety_officer`. -/
  koFlowKnockoutRetirementPublicSafetyOfficer : Bool
  /-- Catala `ko_flow_knockout_box15`. -/
  koFlowKnockoutBox15 : Bool
  /-- Every knockout above. -/
  unsupported : Bool

/-- Catala `scope Form1099Rs`. -/
def form1099Rs (i : Form1099RsIn) : Form1099RsOut :=
  let items := i.forms.map form1099RItem
  let primaryItems := items.filter (·.filer == .primaryFiler)
  let secondaryItems := items.filter (·.filer == .secondaryFiler)
  let taxFree := sumBy (·.grossDistribution) (items.filter (·.isTaxFreePensionRollover))
  let partlyItems := items.filter (·.isPartlyTaxablePension)
  let partly := sumBy (·.grossDistribution) partlyItems
  let fully := sumBy (·.grossDistribution) (items.filter (·.isFullyTaxable))
  let taxableOfPartly := sumBy (·.taxableAmount) partlyItems
  let line5a := taxFree + partly
  let line5b := fully + taxableOfPartly
  let ko (p : Form1099RItem → Bool) := items.any p
  let kDistributionCode := ko (·.koHasUnsupportedDistributionCode)
  let kIra := ko (·.koIraSepSimple)
  let kTaxableRollover := ko (·.koTaxablePensionRollover)
  let kIndirect := ko (·.koIndirectRollover)
  let kNotDetermined := ko (·.koTaxableAmountNotDetermined)
  let kRollover := ko (·.koCausesRollover)
  let kPreTax := ko (·.koCausesPreTaxToPostTaxRollover)
  let kRetNotDetermined := ko (·.koRetirementTaxableAmountNotDetermined)
  let kBlank := ko (·.koRetirementTaxableAmountBlank)
  let kTotal := ko (·.koRetirementTotalDistribution)
  let kB8 := ko (·.koBox8Value)
  let kB8p := ko (·.koBox8Percentage)
  let kB9a := ko (·.koBox9aPercentage)
  let kCg := ko (·.koCapitalGain)
  let kNua := ko (·.koNetUnrealizedAppreciation)
  let kIrr := ko (·.koAmountAllocableToIrr)
  let kFacta := ko (·.koFactaFilingRequirement)
  let kDeath := ko (·.koDeathBenefitPayment)
  let kDisaster := ko (·.koQualifiedDisasterDistribution)
  let kPso := ko (·.koPublicSafetyOfficerPremiums)
  let kBox15 := ko (·.koBox15)
  { taxFreePensionRollovers := taxFree
    partlyTaxablePensions := partly
    fullyTaxablePensions := fully
    taxableAmountsOfPartiallyTaxablePensions := taxableOfPartly
    line5a := line5a
    line5b := line5b
    line5bIsBlank := !decide (line5b > 0) && !(items.any (·.isTaxFreePensionRollover))
    hasDirectRollover := items.any (·.isDirectRollover)
    nonTaxablePensionsAndAnnuities := line5a - line5b
    form1099rFederalIncomeTaxWithheld := sumBy (·.federalWithholding) items
    primaryFilerSaversGrossDistributions :=
      sumBy (·.grossDistribution) (primaryItems.filter (·.isReportedOnSaversCredit))
    secondaryFilerSaversGrossDistributions :=
      sumBy (·.grossDistribution) (secondaryItems.filter (·.isReportedOnSaversCredit))
    koKnockoutForForm1099RDistributionCode := kDistributionCode
    koKnockoutIraSepSimple := kIra
    koKnockoutTaxablePensionRollover := kTaxableRollover
    koKnockoutIndirectRollover := kIndirect
    koKnockoutTaxableAmountNotDetermined := kNotDetermined
    koFlowKnockoutForRollover := kRollover
    koFlowKnockoutForPreTaxToPostTaxRollover := kPreTax
    koFlowKnockoutRetirementTaxableAmountNotDetermined := kRetNotDetermined
    koFlowKnockoutRetirementTaxableAmountBlank := kBlank
    koFlowKnockoutRetirementTotalDistribution := kTotal
    koKnockoutForForm1099RBox8Value := kB8
    koKnockoutForForm1099RBox8Percentage := kB8p
    koKnockoutForForm1099RBox9aPercentage := kB9a
    koFlowKnockoutRetirementCapitalGain := kCg
    koFlowKnockoutRetirementNetUnrealizedAppreciation := kNua
    koFlowKnockoutRetirementAmountAllocableToIrr := kIrr
    koFlowKnockoutRetirementFactaFilingRequirement := kFacta
    koFlowKnockoutForDeathBenefitPaymentDate := kDeath
    koFlowKnockoutRetirementQualifiedDisasterDistribution := kDisaster
    koFlowKnockoutRetirementPublicSafetyOfficer := kPso
    koFlowKnockoutBox15 := kBox15
    unsupported :=
      kDistributionCode || kIra || kTaxableRollover || kIndirect || kNotDetermined ||
      kRollover || kPreTax || kRetNotDetermined || kBlank || kTotal || kB8 || kB8p || kB9a ||
      kCg || kNua || kIrr || kFacta || kDeath || kDisaster || kPso || kBox15 }

/-! ### Unit tests: every assertion of `catala/tests/test_form1099_rs.catala_en` -/

private def r (fs : List Form1099R) : Form1099RsOut := form1099Rs { forms := fs }

-- TestFullyTaxable
private def fullyTaxable := r [{ writableGrossDistribution := 1_000_000, writableTaxableAmount := 1_000_000 }]
#guard fullyTaxable.fullyTaxablePensions == 1_000_000
#guard fullyTaxable.partlyTaxablePensions == 0
#guard fullyTaxable.line5a == 0
#guard fullyTaxable.line5b == 1_000_000
#guard !(fullyTaxable.line5a == 1_000_000)
#guard !fullyTaxable.line5bIsBlank
#guard !fullyTaxable.unsupported

-- TestPartlyTaxable
private def partlyTaxable := r [{ writableGrossDistribution := 1_000_000, writableTaxableAmount := 600_000 }]
#guard partlyTaxable.partlyTaxablePensions == 1_000_000
#guard partlyTaxable.fullyTaxablePensions == 0
#guard partlyTaxable.line5a == 1_000_000
#guard partlyTaxable.line5b == 600_000
#guard partlyTaxable.nonTaxablePensionsAndAnnuities == 400_000
#guard !partlyTaxable.unsupported

-- TestTaxFreeRollover
private def taxFreeRollover := r [{ distributionCode := [.codeG], writableGrossDistribution := 400_000 }]
#guard taxFreeRollover.taxFreePensionRollovers == 400_000
#guard taxFreeRollover.line5a == 400_000
#guard taxFreeRollover.line5b == 0
#guard !taxFreeRollover.line5bIsBlank
#guard taxFreeRollover.hasDirectRollover
#guard !taxFreeRollover.unsupported

-- TestTaxableRolloverRejected
private def taxableRollover :=
  r [{ distributionCode := [.codeH], writableGrossDistribution := 400_000, writableTaxableAmount := 50_000 }]
#guard taxableRollover.koKnockoutTaxablePensionRollover
#guard taxableRollover.koFlowKnockoutForPreTaxToPostTaxRollover
#guard taxableRollover.unsupported

-- TestCodeOneUnsupported
private def codeOne :=
  r [{ distributionCode := [.otherCode], writableGrossDistribution := 1_000_000,
       writableTaxableAmount := 1_000_000 }]
#guard codeOne.koKnockoutForForm1099RDistributionCode
#guard codeOne.unsupported

-- TestWholeCode
private def code (cs : List CodeChar) : Form1099RsOut := r [{ distributionCode := cs }]
#guard (code [.code7, .otherCode]).unsupported
#guard (code []).unsupported
#guard (code [.code7, .code7]).unsupported
#guard (code [.code2, .code7]).unsupported
#guard !(code [.code7, .codeB]).unsupported
#guard !(code [.codeB, .code7]).unsupported
#guard !(code [.code4, .codeG]).unsupported
#guard (code [.code4]).unsupported

-- TestOracleWithholdingsScenario
private def oracleScenario := r [
  { distributionCode := [.codeG, .codeB], writableGrossDistribution := 5_799_281 },
  { writableGrossDistribution := 1_299_275, writableTaxableAmount := 912_204,
    writableFederalWithholding := 91_175 },
  { distributionCode := [.code7, .codeB], writableGrossDistribution := 2_000_000,
    writableTaxableAmount := 2_000_000, writableFederalWithholding := 150_751 }]
#guard oracleScenario.line5a == 7_098_600
#guard oracleScenario.line5b == 2_912_200
#guard oracleScenario.form1099rFederalIncomeTaxWithheld == 242_000
#guard !oracleScenario.unsupported

-- TestSaversDistributions
private def savers := r [
  { writableGrossDistribution := 400_049, writableTaxableAmount := 300_000 },
  { distributionCode := [.codeB, .codeG], writableGrossDistribution := 500_000 },
  { filer := .secondaryFiler, distributionCode := [.codeB, .code2],
    writableGrossDistribution := 120_000, writableTaxableAmount := 100_000 },
  { writableGrossDistribution := 90_000, writableTaxableAmount := 90_000,
    writableIsDistributionFromMilitaryRetirementPlan := true }]
#guard savers.primaryFilerSaversGrossDistributions == 400_000
#guard savers.secondaryFilerSaversGrossDistributions == 120_000
#guard !savers.unsupported

-- TestKnockouts
private def base : Form1099R := {}
#guard !(r [base, { base with otherPercentageNonzero := false }]).unsupported
#guard (r [{ base with iraSepSimple := true }]).koKnockoutIraSepSimple
#guard (r [{ base with writableCapitalGain := 100 }]).koFlowKnockoutRetirementCapitalGain
#guard (r [{ base with writableNetAppreciation := 100 }]).koFlowKnockoutRetirementNetUnrealizedAppreciation
#guard (r [{ base with otherPercentageNonzero := true }]).koKnockoutForForm1099RBox8Percentage
#guard (r [{ base with payerStateIsDifferent := true, writableStateTaxWithheld := 1_700 }]).koFlowKnockoutBox15
#guard (r [{ base with writeablePublicSafetyOfficer := true, writeablePublicSafetyOfficerPremiums := true }]).koFlowKnockoutRetirementPublicSafetyOfficer
#guard (r [{ base with factaFilingRequirement := true }]).koFlowKnockoutRetirementFactaFilingRequirement
#guard (r [{ base with iraSepSimple := true }]).unsupported
#guard (r [{ base with writableCapitalGain := 100 }]).unsupported
#guard (r [{ base with writableNetAppreciation := 100 }]).unsupported
#guard (r [{ base with otherPercentageNonzero := true }]).unsupported
#guard (r [{ base with payerStateIsDifferent := true, writableStateTaxWithheld := 1_700 }]).unsupported
#guard (r [{ base with writeablePublicSafetyOfficer := true, writeablePublicSafetyOfficerPremiums := true }]).unsupported
#guard (r [{ base with factaFilingRequirement := true }]).unsupported
#guard !(r [base]).unsupported

-- TestTotalDistribution
#guard (r [{ base with totalDistribution := true, recipientDateOfBirth := { year := 1935, month := 12, day := 31 } }]).koFlowKnockoutRetirementTotalDistribution
#guard !(r [{ base with totalDistribution := true }]).unsupported

end UsTax.Form1099Rs
