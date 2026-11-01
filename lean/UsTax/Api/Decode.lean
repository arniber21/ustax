import UsTax.Api.Json
import UsTax.Api.Error
import UsTax.Api.Types

/-!
# JSON to typed request (issue #51), phase 1: shape

`decRequest : J → D Request` reads a parsed JSON value into a `Request` and
logs, in the state, **every** shape problem it finds (it keeps going after the
first): wrong JSON type, float or string money, bad enumeration value, missing
required property, unknown property, malformed date. When the log is empty the
result is the request; when it is not, the returned value is a default and must
be ignored (`runDecode` enforces that).

Unknown properties are found without a separate list of allowed names: every
property accessor records the key it read, and an object's unread keys are the
unknown ones. A property that exists in `Types.lean` but is never read cannot
be silently dropped, because it would then be reported as unknown.

Range, list-size and cross-field rules are phase 2 (`Validate.lean`), over the
typed value. The two phases together are `parseRequest` (`Parse.lean`).
-/

namespace UsTax.Api

open UsTax

/-- Decoder state: problems found so far, and the keys read in the current object. -/
structure DS where
  /-- Property `errs`. -/
  errs : Array FieldError := #[]
  /-- Property `used`. -/
  used : Array String := #[]

/-- The decoder monad: total, accumulating. -/
abbrev D := StateM DS

/-- Log a problem at path `p`. -/
def report (p : String) (c : FieldCode) (m : String) : D Unit :=
  modify fun s => { s with errs := s.errs.push ⟨p, c, m⟩ }

/-- A boolean. -/
def asBool (p : String) : J → D Bool
  | .bool b => pure b
  | _ => do report p .type "must be a boolean"; pure false

/-- An integer literal (money cents). Floats get `not_integer`. -/
def asInt (p : String) : J → D Int
  | .int n => pure n
  | .float _ => do report p .notInteger "money must be an integer number of cents"; pure 0
  | _ => do report p .type "must be an integer number of cents"; pure 0

/-- The constant integer `n` (for `api_version` and `tax_year`). -/
def asConst (n : Int) (p : String) : J → D Unit
  | .int m => if m == n then pure () else report p .enum s!"must be {n}"
  | .float _ => report p .notInteger "must be an integer"
  | _ => report p .type "must be an integer"

/-- A string naming a constructor of `α`. -/
def asEnum {α : Type} [ApiEnum α] [Inhabited α] (p : String) : J → D α
  | .str s =>
    match (ApiEnum.all : List α).find? (fun a => ApiEnum.name a == s) with
    | some a => pure a
    | none => do
      report p .enum ("must be one of: " ++ ", ".intercalate ((ApiEnum.all : List α).map ApiEnum.name))
      pure default
  | _ => do report p .type "must be a string"; pure default

/-- `YYYY-MM-DD` (four, two, two digits). Whether it is a real date is phase 2. -/
def parseIsoDate (s : String) : Option Date :=
  match s.toList with
  | [y1, y2, y3, y4, '-', m1, m2, '-', d1, d2] =>
    let ds := [y1, y2, y3, y4, m1, m2, d1, d2]
    if ds.all (fun c => '0' ≤ c ∧ c ≤ '9') then
      some { year := (Json.natOfDigits [y1, y2, y3, y4] : Nat), month := Json.natOfDigits [m1, m2],
             day := Json.natOfDigits [d1, d2] }
    else none
  | _ => none

/-- An ISO date string, or `none` after logging. -/
def asDate (p : String) : J → D (Option Date)
  | .str s =>
    match parseIsoDate s with
    | some d => pure (some d)
    | none => do report p .type "must match YYYY-MM-DD"; pure none
  | _ => do report p .type "must be a string"; pure none

/-- An ISO date string; a placeholder date after logging (the result is then ignored). -/
def asDateD (p : String) (j : J) : D Date := do
  return (← asDate p j).getD default

/-- An array, each element read by `f` at its own index path. -/
def asArray {α : Type} (p : String) (f : String → J → D α) : J → D (List α)
  | .arr xs => do
    let mut out : Array α := #[]
    let mut i := 0
    for x in xs do
      out := out.push (← f (p ++ "/" ++ toString i) x)
      i := i + 1
    pure out.toList
  | _ => do report p .type "must be an array"; pure []

/-- Read an object with `f`; keys `f` did not read are reported as unknown. -/
def withObj {α : Type} [Inhabited α] (p : String) (j : J)
    (f : List (String × J) → D α) : D α :=
  match j with
  | .obj fs => do
    let saved := (← get).used
    modify fun s => { s with used := #[] }
    let a ← f fs
    let u := (← get).used
    for (k, _) in fs do
      unless u.contains k do report (child p k) .unknownField "unknown property"
    modify fun s => { s with used := saved }
    pure a
  | _ => do report p .type "must be an object"; pure default

/-- Mark `k` as read. -/
def touch (k : String) : D Unit := modify fun s => { s with used := s.used.push k }

/-- Optional property: `none` when absent. -/
def opt {α : Type} (fs : List (String × J)) (p k : String) (dec : String → J → D α) :
    D (Option α) := do
  touch k
  match J.lookup fs k with
  | none => pure none
  | some j => some <$> dec (child p k) j

/-- Optional property with a default. -/
def optD {α : Type} (fs : List (String × J)) (p k : String) (dec : String → J → D α) (d : α) :
    D α := do
  return (← opt fs p k dec).getD d

/-- Required property. -/
def req {α : Type} [Inhabited α] (fs : List (String × J)) (p k : String)
    (dec : String → J → D α) : D α := do
  touch k
  match J.lookup fs k with
  | none => report (child p k) .required "required property"; pure default
  | some j => dec (child p k) j

/-- Optional money box, `0` when absent. -/
def money (fs : List (String × J)) (p k : String) : D Int := optD fs p k asInt 0

/-- Optional flag, `false` when absent. -/
def flag (fs : List (String × J)) (p k : String) : D Bool := optD fs p k asBool false

/-- Optional list of forms, empty when absent. -/
def optList {α : Type} (fs : List (String × J)) (p k : String) (f : String → J → D α) :
    D (List α) := do
  return (← opt fs p k (asArray · f)).getD []

/-- `FilerTin`. -/
def decFilerTin (p : String) (j : J) : D FilerTin :=
  withObj p j fun fs => do
    return { tinIsSsn := ← optD fs p "tin_is_ssn" asBool true,
             ssnEmploymentValidity := ← optD fs p "ssn_employment_validity" asEnum .neither,
             hasSsnOnlyForBenefits := ← opt fs p "has_ssn_only_for_benefits" asBool }

/-- `DisabilityAnswers`. -/
def decDisabilityAnswers (p : String) (j : J) : D DisabilityAnswers :=
  withObj p j fun fs => do
    return { isRetiredOnPermOrTotalDisability := ← opt fs p "is_retired_on_perm_or_total_disability" asBool,
             employerHasMandatoryRetirementAge := ← opt fs p "employer_has_mandatory_retirement_age" asBool,
             hasMetEmployerMandatoryRetirementAge := ← opt fs p "has_met_employer_mandatory_retirement_age" asBool,
             arePaymentsTaxableDisabilityIncome := ← opt fs p "are_payments_taxable_disability_income" asBool,
             writableTotalTaxableDisabilityAmount := ← opt fs p "writable_total_taxable_disability_amount" asInt,
             hasW2Wages := ← opt fs p "has_w2_wages" asBool }

/-- `HsaFilerAnswers`. -/
def decHsaFilerAnswers (p : String) (j : J) : D HsaFilerAnswers :=
  withObj p j fun fs => do
    return { writablePrimaryFilerHasMadeContributionsToHsa := ← opt fs p "writable_primary_filer_has_made_contributions_to_hsa" asBool,
             writableSecondaryFilerHasMadeContributionsToHsa := ← opt fs p "writable_secondary_filer_has_made_contributions_to_hsa" asBool,
             enrolledInMedicare := ← optD fs p "enrolled_in_medicare" asEnum .medicareNoneOfYear,
             hsaHdhpCoverageStatus := ← optD fs p "hsa_hdhp_coverage_status" asEnum .hdhpAllYear,
             typeOfHdhp := ← optD fs p "type_of_hdhp" asEnum .selfOnly,
             hadOtherCoverageIneligibleForHsa := ← optD fs p "had_other_coverage_ineligible_for_hsa" asEnum .otherCoverageNoneOfYear,
             writableMfsLine6Check := ← opt fs p "writable_mfs_line6_check" asBool,
             writableChangeInMaritalStatusDuringTaxYear := ← optD fs p "writable_change_in_marital_status_during_tax_year" asEnum .wasNotMarriedNorDivorcedThisYear,
             writableMaritalChangeAffectContributionLimitBool := ← opt fs p "writable_marital_change_affect_contribution_limit_bool" asBool,
             hasMadeQualifiedHsaFundingDistribution := ← opt fs p "has_made_qualified_hsa_funding_distribution" asBool,
             writableHsaNonemployerContributionsTaxYear := ← opt fs p "writable_hsa_nonemployer_contributions_tax_year" asInt,
             writableHsaNonemployerContributionsTaxYearPlusOne := ← opt fs p "writable_hsa_nonemployer_contributions_tax_year_plus_one" asInt }

/-- `CdccFilerAnswers`. -/
def decCdccFilerAnswers (p : String) (j : J) : D CdccFilerAnswers :=
  withObj p j fun fs => do
    return { electCombatPayForCredit := ← opt fs p "elect_combat_pay_for_credit" asBool,
             electCombatPayForBenefits := ← opt fs p "elect_combat_pay_for_benefits" asBool,
             dependentCarePlanMaximum := ← opt fs p "dependent_care_plan_maximum" asInt,
             isDisabled := ← opt fs p "is_disabled" asBool,
             deemedIncomeMonthEarnings := ← optList fs p "deemed_income_month_earnings" asInt,
             hasDependentCareExpenses := ← opt fs p "has_dependent_care_expenses" asBool,
             expensesPaidToQualifyingProvider := ← opt fs p "expenses_paid_to_qualifying_provider" asBool,
             writableQualifyingExpenseAmount := ← opt fs p "writable_qualifying_expense_amount" asInt }

/-- `FilerFlags`. -/
def decFilerFlags (p : String) (j : J) : D FilerFlags :=
  withObj p j fun fs => do
    return { isBlind := ← flag fs p "is_blind",
             age65OrOlder := ← flag fs p "age65_or_older",
             canBeClaimedAsDependent := ← flag fs p "can_be_claimed_as_dependent",
             dateOfBirth := ← opt fs p "date_of_birth" asDateD,
             willBeClaimed := ← flag fs p "will_be_claimed",
             potentialClaimerMustFile := ← flag fs p "potential_claimer_must_file",
             potentialClaimerDidFile := ← flag fs p "potential_claimer_did_file",
             isUsCitizenFullYear := ← optD fs p "is_us_citizen_full_year" asBool true,
             citizenAtEndOfTaxYear := ← flag fs p "citizen_at_end_of_tax_year",
             noncitizenResidentFullYear := ← flag fs p "noncitizen_resident_full_year",
             isNational := ← flag fs p "is_national",
             isStudent := ← flag fs p "is_student",
             tin := ← opt fs p "tin" decFilerTin,
             disability := ← opt fs p "disability" decDisabilityAnswers,
             hsa := ← opt fs p "hsa" decHsaFilerAnswers,
             cdcc := ← opt fs p "cdcc" decCdccFilerAnswers }

/-- `FilingDetails`. -/
def decFilingDetails (p : String) (j : J) : D FilingDetails :=
  withObj p j fun fs => do
    return { treatAsMfs := ← opt fs p "treat_as_mfs" asBool,
             isWidowedInTaxYear := ← opt fs p "is_widowed_in_tax_year" asBool,
             mfjDeceasedSpouseReachedAge65 := ← opt fs p "mfj_deceased_spouse_reached_age65" asBool,
             mfsSpouse65OrOlder := ← flag fs p "mfs_spouse_65_or_older",
             mfsSpouseProvidesNoBenefits := ← opt fs p "mfs_spouse_provides_no_benefits" asBool,
             treatFilersAsDependents := ← opt fs p "treat_filers_as_dependents" asBool,
             hasForeignAccountsOrTrusts := ← flag fs p "has_foreign_accounts_or_trusts",
             combatPayElection := ← optD fs p "combat_pay_election" asEnum .noCombatPay,
             combatPayElectionMade := ← flag fs p "combat_pay_election_made" }

/-- `FilingAnswers`. -/
def decFilingAnswers (p : String) (j : J) : D FilingAnswers :=
  withObj p j fun fs => do
    return { maritalStatus := ← opt fs p "marital_status" asEnum,
             yearOfSpouseDeath := ← opt fs p "year_of_spouse_death" asEnum,
             secondaryFilerDateOfDeath := ← optD fs p "secondary_filer_date_of_death" asDateD { year := 2024, month := 12, day := 31 },
             primaryFilerPotentialClaimerFiledOnlyForRefund := ← flag fs p "primary_filer_potential_claimer_filed_only_for_refund",
             mfjRequiredToFile := ← flag fs p "mfj_required_to_file",
             mfjDependentsFilingForCredits := ← flag fs p "mfj_dependents_filing_for_credits",
             livedTogetherAllYearWithSpouse := ← optD fs p "lived_together_all_year_with_spouse" asBool true,
             spouseLivedTogetherMonths := ← optD fs p "spouse_lived_together_months" asEnum .livedApartAllYear,
             livedApartLastSixMonths := ← flag fs p "lived_apart_last_six_months",
             separationAgreement := ← flag fs p "separation_agreement",
             canFileJointlyYearOfSpouseDeath := ← flag fs p "can_file_jointly_year_of_spouse_death",
             inRegisteredDomesticPartnership := ← flag fs p "in_registered_domestic_partnership",
             residenceState := ← optD fs p "residence_state" asEnum .fl,
             spouseItemizes := ← flag fs p "spouse_itemizes",
             mfsLivingSpouseFilingReturn := ← flag fs p "mfs_living_spouse_filing_return",
             mfsDeceasedSpouseFilingReturn := ← flag fs p "mfs_deceased_spouse_filing_return",
             mfsSpouseHasGrossIncome := ← flag fs p "mfs_spouse_has_gross_income" }

/-- `BenefitSplitAnswers`. -/
def decBenefitSplitAnswers (p : String) (j : J) : D BenefitSplitAnswers :=
  withObj p j fun fs => do
    return { hasOtherBiologicalOrAdoptiveParent := ← opt fs p "has_other_biological_or_adoptive_parent" asBool,
             nonParentalSomeParentNotClaiming := ← opt fs p "non_parental_some_parent_not_claiming" asBool,
             whichParentNotClaiming := ← optD fs p "which_parent_not_claiming" asEnum .nobodyDid,
             inParentsCustody := ← opt fs p "in_parents_custody" asBool,
             livedWithTpOrOtherBiologicalOrAdoptiveParentMoreThanSixMonths := ← opt fs p "lived_with_tp_or_other_biological_or_adoptive_parent_more_than_six_months" asBool,
             biologicalOrAdoptiveParentsLiving := ← opt fs p "biological_or_adoptive_parents_living" asBool,
             nightsWithTpVsOtherParent := ← optD fs p "nights_with_tp_vs_other_parent" asEnum .less,
             tpAgiHigherThanOtherParent := ← opt fs p "tp_agi_higher_than_other_parent" asBool,
             parentsMeetReqsRuleForChildrenOfDivorcedParents := ← opt fs p "parents_meet_reqs_rule_for_children_of_divorced_parents" asBool,
             specialRuleChildUsedByCustodialParentAsQp := ← opt fs p "special_rule_child_used_by_custodial_parent_as_qp" asBool,
             specialRuleAgiTest := ← opt fs p "special_rule_agi_test" asBool,
             parentalSituation := ← optD fs p "parental_situation" asEnum .other,
             parentalSupport := ← opt fs p "parental_support" asBool,
             multipleSupportAgreement := ← opt fs p "multiple_support_agreement" asBool }

/-- `CdccMemberAnswers`. -/
def decCdccMemberAnswers (p : String) (j : J) : D CdccMemberAnswers :=
  withObj p j fun fs => do
    return { unableToCareForSelf := ← opt fs p "unable_to_care_for_self" asBool,
             hasDependentCareExpenses := ← opt fs p "has_dependent_care_expenses" asBool,
             expensesPaidToQualifyingProvider := ← opt fs p "expenses_paid_to_qualifying_provider" asBool,
             writableQualifyingExpenseAmount := ← opt fs p "writable_qualifying_expense_amount" asInt }

/-- `Dependent`. -/
def decDependent (p : String) (j : J) : D Dependent :=
  withObj p j fun fs => do
    return { relationship := ← req fs p "relationship" asEnum,
             dateOfBirth := ← req fs p "date_of_birth" asDateD,
             fullTimeStudent := ← flag fs p "full_time_student",
             permanentTotalDisability := ← flag fs p "permanent_total_disability",
             residencyDuration := ← optD fs p "residency_duration" asEnum .allYear,
             ownSupport := ← flag fs p "own_support",
             married := ← flag fs p "married",
             jointReturn := ← flag fs p "joint_return",
             requiredToFile := ← flag fs p "required_to_file",
             filingOnlyForRefund := ← flag fs p "filing_only_for_refund",
             couldBeQualifyingChildOfAnother := ← flag fs p "could_be_qualifying_child_of_another",
             potentialClaimerMustFile := ← flag fs p "potential_claimer_must_file",
             potentialClaimerDidFile := ← flag fs p "potential_claimer_did_file",
             potentialClaimerFiledOnlyForRefund := ← flag fs p "potential_claimer_filed_only_for_refund",
             grossIncome := ← money fs p "gross_income",
             qrSupportTest := ← flag fs p "qr_support_test",
             tinType := ← req fs p "tin_type" asEnum,
             isUsCitizenFullYear := ← optD fs p "is_us_citizen_full_year" asBool true,
             usResident := ← flag fs p "us_resident",
             usNational := ← flag fs p "us_national",
             canadaMexicoResident := ← flag fs p "canada_mexico_resident",
             tpClaims := ← optD fs p "tp_claims" asBool true,
             deceased := ← flag fs p "deceased",
             custody := ← opt fs p "custody" decBenefitSplitAnswers,
             tpPaidMostOfHomeUpkeep := ← flag fs p "tp_paid_most_of_home_upkeep",
             tpPaidMostOfParentHomeUpkeep := ← flag fs p "tp_paid_most_of_parent_home_upkeep",
             ssnEmploymentValidity := ← optD fs p "ssn_employment_validity" asEnum .neither,
             ssnOnlyForFederallyFundedBenefit := ← flag fs p "ssn_only_for_federally_funded_benefit",
             monthsLivedWithTpInUs := ← optD fs p "months_lived_with_tp_in_us" asInt 12,
             cdcc := ← opt fs p "cdcc" decCdccMemberAnswers }

/-- `HsaDistribution`. -/
def decHsaDistribution (p : String) (j : J) : D HsaDistribution :=
  withObj p j fun fs => do
    return { filer := ← req fs p "filer" asEnum,
             writableDistributionsRolloverBool := ← req fs p "writable_distributions_rollover_bool" asBool,
             writableDistributionsRolloverAmount := ← req fs p "writable_distributions_rollover_amount" asInt,
             writableGrossDistribution := ← req fs p "writable_gross_distribution" asInt,
             hasWithdrawnExcessContributions := ← req fs p "has_withdrawn_excess_contributions" asBool,
             writableWithdrawnExcessContributionsAmount := ← req fs p "writable_withdrawn_excess_contributions_amount" asInt,
             writableEarningsOnExcessContributions := ← req fs p "writable_earnings_on_excess_contributions" asInt,
             hsaDistributionCode := ← req fs p "hsa_distribution_code" asEnum,
             writableFmvOnDateOfDeath := ← req fs p "writable_fmv_on_date_of_death" asInt,
             writableQualifiedMedExpenses := ← req fs p "writable_qualified_med_expenses" asInt }

/-- `HsaInput`. -/
def decHsaInput (p : String) (j : J) : D HsaInput :=
  withObj p j fun fs => do
    return { someFilerHadNonW2HsaActivity := ← opt fs p "some_filer_had_non_w2_hsa_activity" asBool,
             writablePrimaryFilerHadNonW2HsaActivity := ← opt fs p "writable_primary_filer_had_non_w2_hsa_activity" asBool,
             writableSecondaryFilerHadNonW2HsaActivity := ← opt fs p "writable_secondary_filer_had_non_w2_hsa_activity" asBool,
             hasHsaMedicalSavingsAccountType := ← opt fs p "has_hsa_medical_savings_account_type" asBool,
             writableHasHsaExcessContributionsPreviousYear := ← opt fs p "writable_has_hsa_excess_contributions_previous_year" asBool,
             writableHasHsaWithdrawnExcessContributionsYesNo := ← opt fs p "writable_has_hsa_withdrawn_excess_contributions_yes_no" asBool,
             someFilersMadeTestingPeriodContribution := ← opt fs p "some_filers_made_testing_period_contribution" asBool,
             someFilersHaveTestingPeriodAdditionalIncome := ← opt fs p "some_filers_have_testing_period_additional_income" asBool,
             hsaDistributions := ← optList fs p "hsa_distributions" decHsaDistribution }

/-- `CreditAnswers`. -/
def decCreditAnswers (p : String) (j : J) : D CreditAnswers :=
  withObj p j fun fs => do
    return { eitcQcOfAnother := ← opt fs p "eitc_qc_of_another" asBool,
             eitcQcOfAnotherRequiredToFile := ← opt fs p "eitc_qc_of_another_required_to_file" asBool,
             eitcQcOfAnotherIsFiling := ← opt fs p "eitc_qc_of_another_is_filing" asBool,
             eitcQcOfAnotherIsFilingRefundOnly := ← opt fs p "eitc_qc_of_another_is_filing_refund_only" asBool,
             eitcHadImproperClaims := ← opt fs p "eitc_had_improper_claims" asBool,
             eitcImproperClaimsDueToQc := ← opt fs p "eitc_improper_claims_due_to_qc" asBool,
             eitcImproperClaimTakenSinceDisallowal := ← opt fs p "eitc_improper_claim_taken_since_disallowal" asBool,
             eitcReceivedImproperClaimsNotice := ← optD fs p "eitc_received_improper_claims_notice" asEnum .notAnswered,
             eitcImproperClaimsNoticeExpired := ← opt fs p "eitc_improper_claims_notice_expired" asBool,
             receivedImproperClaims := ← opt fs p "received_improper_claims" asBool,
             receivedImproperClaimsNotice := ← optD fs p "received_improper_claims_notice" asEnum .notAnswered,
             improperClaimsNoticeExpired := ← opt fs p "improper_claims_notice_expired" asBool,
             hasFiledCtcOdcSinceNoticeExpired := ← opt fs p "has_filed_ctc_odc_since_notice_expired" asBool,
             hasDistributionsInLastThreeYears := ← opt fs p "has_distributions_in_last_three_years" asBool,
             hasCurrentYearDistributions := ← opt fs p "has_current_year_distributions" asBool,
             hasSelfReportedContributions := ← opt fs p "has_self_reported_contributions" asBool,
             hasSelfReportedNonTaxablePayments := ← opt fs p "has_self_reported_non_taxable_payments" asBool,
             selfReportedNonTaxablePaymentAmount := ← opt fs p "self_reported_non_taxable_payment_amount" asInt }

/-- `CdccInput`. -/
def decCdccInput (p : String) (j : J) : D CdccInput :=
  withObj p j fun fs => do
    return { hasMfsSpouseEarnedIncome := ← opt fs p "has_mfs_spouse_earned_income" asBool,
             writableMfsSpouseEarnedIncome := ← opt fs p "writable_mfs_spouse_earned_income" asInt,
             writableTotalQualifiedDependentCareExpenses := ← opt fs p "writable_total_qualified_dependent_care_expenses" asInt,
             writableCarryoverAmount := ← opt fs p "writable_carryover_amount" asInt,
             writableForfeitedAmount := ← opt fs p "writable_forfeited_amount" asInt,
             hasCreditForPriorYearExpenses := ← opt fs p "has_credit_for_prior_year_expenses" asBool,
             claimedCreditForPriorYearExpenses := ← opt fs p "claimed_credit_for_prior_year_expenses" asBool,
             claimedMaxCreditForPriorTaxYear := ← opt fs p "claimed_max_credit_for_prior_tax_year" asBool,
             hasHouseholdEmployee := ← opt fs p "has_household_employee" asBool,
             benefitsFromSoleProprietorshipOrPartnership := ← opt fs p "benefits_from_sole_proprietorship_or_partnership" asBool }

/-- `Form1095A`. -/
def decForm1095A (p : String) (j : J) : D Form1095A :=
  withObj p j fun fs => do
    return { writablePolicyStartDate := ← req fs p "writable_policy_start_date" asDateD,
             writablePolicyEndDate := ← req fs p "writable_policy_end_date" asDateD,
             writableSpecialPolicyModificationInStartingMonth := ← req fs p "writable_special_policy_modification_in_starting_month" asBool,
             writableHasPolicyDateException := ← req fs p "writable_has_policy_date_exception" asBool,
             hasCoverageMonths := ← req fs p "has_coverage_months" asBool,
             coverageMonths := ← req fs p "coverage_months" (asArray · asInt),
             writablePremiumsOrSlcspChange := ← req fs p "writable_premiums_or_slcsp_change" asBool,
             hasChangeInCircumstance := ← req fs p "has_change_in_circumstance" asBool,
             writablePtcAnnualPremium := ← req fs p "writable_ptc_annual_premium" asInt,
             writableSlcspAnnualPremium := ← req fs p "writable_slcsp_annual_premium" asInt,
             writableAptcAnnualAmount := ← req fs p "writable_aptc_annual_amount" asInt,
             writablePtcMonthlyPremium := ← req fs p "writable_ptc_monthly_premium" (asArray · asInt),
             writablePtcMonthlySlcspPremium := ← req fs p "writable_ptc_monthly_slcsp_premium" (asArray · asInt),
             writablePtcMonthlyAptcPremium := ← req fs p "writable_ptc_monthly_aptc_premium" (asArray · asInt) }

/-- `PtcInput`. -/
def decPtcInput (p : String) (j : J) : D PtcInput :=
  withObj p j fun fs => do
    return { form1095As := ← optList fs p "form1095_as" decForm1095A,
             writableHasPtcQualifyingPlan := ← opt fs p "writable_has_ptc_qualifying_plan" asBool,
             writableHasAdvancedPtc := ← opt fs p "writable_has_advanced_ptc" asBool,
             dependentTpSelfEnrolled := ← opt fs p "dependent_tp_self_enrolled" asBool,
             dependentTpEnrolledSomeoneElse := ← opt fs p "dependent_tp_enrolled_someone_else" asBool,
             writableDependentTpOtherMembersArePartOfDifferentTaxFamily := ← opt fs p "writable_dependent_tp_other_members_are_part_of_different_tax_family" asBool,
             writableHasMfsException := ← opt fs p "writable_has_mfs_exception" asBool,
             writableClaimingMfsExceptionForFourthStraightYear := ← opt fs p "writable_claiming_mfs_exception_for_fourth_straight_year" asBool,
             writableBelow100ThresholdAndNotEligibleForMedicaidBecauseOfImmigrationStatus := ← opt fs p "writable_below100_threshold_and_not_eligible_for_medicaid_because_of_immigration_status" asBool,
             writableHasEmployerSponsoredPlan := ← opt fs p "writable_has_employer_sponsored_plan" asBool,
             writableDependentsRequiredToFile := ← opt fs p "writable_dependents_required_to_file" asBool,
             writableSelfReportedHasMultiple1095As := ← opt fs p "writable_self_reported_has_multiple1095_as" asBool,
             writableIsAdditionalPersonInEnrollmentFamily := ← opt fs p "writable_is_additional_person_in_enrollment_family" asBool,
             writableIsAdditionalPersonPartofDifferentTaxFamily := ← opt fs p "writable_is_additional_person_partof_different_tax_family" asBool,
             writableIsEnrolledWithOtherFamily := ← opt fs p "writable_is_enrolled_with_other_family" asBool,
             writableHasImmigrationStatusNotEligibleForMarketplace := ← opt fs p "writable_has_immigration_status_not_eligible_for_marketplace" asBool,
             writableWantsToUseAltCalculations := ← opt fs p "writable_wants_to_use_alt_calculations" asBool }

/-- `ScreeningAnswers`. -/
def decScreeningAnswers (p : String) (j : J) : D ScreeningAnswers :=
  withObj p j fun fs => do
    return { incomeSourcesSupported := ← optD fs p "income_sources_supported" asBool true,
             receivedDigitalAssets := ← opt fs p "received_digital_assets" asBool,
             disposedDigitalAssets := ← opt fs p "disposed_digital_assets" asBool,
             hasForeignAccounts := ← opt fs p "has_foreign_accounts" asBool,
             isForeignTrustsGrantor := ← opt fs p "is_foreign_trusts_grantor" asBool,
             hasForeignTrustsTransactions := ← opt fs p "has_foreign_trusts_transactions" asBool,
             madeIraContributions := ← opt fs p "made_ira_contributions" asBool,
             w2Box15IncomeFromDifferentState := ← opt fs p "w2_box15_income_from_different_state" asBool,
             w2HasBox14NyrrtaKnockoutCode := ← opt fs p "w2_has_box14_nyrrta_knockout_code" asBool,
             w2HasRrtaCodesInBox14 := ← opt fs p "w2_has_rrta_codes_in_box14" asBool,
             livedInNy := ← opt fs p "lived_in_ny" asBool,
             w2PaidYonkersTaxes := ← opt fs p "w2_paid_yonkers_taxes" asBool,
             partYearYonkersResident := ← opt fs p "part_year_yonkers_resident" asBool,
             primaryFilerFormsAnotherState := ← opt fs p "primary_filer_forms_another_state" asBool,
             receivedAlaskaPfd := ← opt fs p "received_alaska_pfd" asBool,
             spouseReceivedAlaskaPfd := ← opt fs p "spouse_received_alaska_pfd" asBool,
             spouseLivesInOtherOrMultipleStates := ← opt fs p "spouse_lives_in_other_or_multiple_states" asBool,
             spouseFormsAnotherState := ← opt fs p "spouse_forms_another_state" asBool,
             isAfterTaxDayAndNotResubmitting := ← opt fs p "is_after_tax_day_and_not_resubmitting" asBool,
             isAfterResubmissionDeadline := ← opt fs p "is_after_resubmission_deadline" asBool }


/-- `Filers`. -/
def decFilers (p : String) (j : J) : D Filers :=
  withObj p j fun fs => do
    return { primary := ← opt fs p "primary" decFilerFlags,
             secondary := ← opt fs p "secondary" decFilerFlags }

/-- `W2Box12`: keys are code letters, values amounts. -/
def decBox12 (p : String) : J → D Box12
  | .obj fs => do
    let mut es : Array (Box12Code × Int) := #[]
    for (k, v) in fs do
      match (ApiEnum.all : List Box12Code).find? (fun code => ApiEnum.name code == k) with
      | some code => es := es.push (code, ← asInt (child p k) v)
      | none => report (child p k) .unknownField "unknown property"
    pure ⟨es.toList⟩
  | _ => do report p .type "must be an object"; pure {}

/-- `FormW2`. -/
def decW2 (p : String) (j : J) : D FormW2 :=
  withObj p j fun fs => do
    return { filer := ← req fs p "filer" asEnum, wages := ← req fs p "wages" asInt,
             federalWithholding := ← money fs p "federal_withholding",
             oasdiWages := ← money fs p "oasdi_wages",
             oasdiWithholding := ← money fs p "oasdi_withholding",
             medicareWages := ← money fs p "medicare_wages",
             medicareWithholding := ← money fs p "medicare_withholding",
             allocatedTips := ← money fs p "allocated_tips",
             dependentCareBenefits := ← money fs p "dependent_care_benefits",
             nonQualifiedPlans := ← money fs p "non_qualified_plans",
             box12 := ← optD fs p "box12" decBox12 {},
             statutoryEmployee := ← flag fs p "statutory_employee",
             thirdPartySickPay := ← flag fs p "third_party_sick_pay",
             plan457bIsGovernmental := ← flag fs p "plan_457b_is_governmental" }

/-- `Form1099Int`. -/
def decInt1099 (p : String) (j : J) : D Form1099Int :=
  withObj p j fun fs => do
    return { filer := ← req fs p "filer" asEnum, has1099 := ← req fs p "has_1099" asBool,
             no1099Amount := ← money fs p "no_1099_amount",
             interestIncome := ← money fs p "interest_income",
             earlyWithdrawalPenalty := ← money fs p "early_withdrawal_penalty",
             governmentBondInterest := ← money fs p "government_bond_interest",
             federalTaxWithheld := ← money fs p "federal_tax_withheld",
             foreignTaxPaid := ← money fs p "foreign_tax_paid",
             taxExemptInterest := ← money fs p "tax_exempt_interest",
             privateActivityBondInterest := ← money fs p "private_activity_bond_interest",
             marketDiscount := ← money fs p "market_discount",
             bondPremium := ← money fs p "bond_premium",
             bondPremiumTreasury := ← money fs p "bond_premium_treasury",
             bondPremiumTaxExempt := ← money fs p "bond_premium_tax_exempt",
             stateIsDifferent := ← flag fs p "state_is_different",
             stateTaxWithheld := ← money fs p "state_tax_withheld",
             factaFilingRequired := ← flag fs p "facta_filing_required" }

/-- `Form1099G`. -/
def decG1099 (p : String) (j : J) : D Form1099G :=
  withObj p j fun fs => do
    return { filer := ← req fs p "filer" asEnum,
             unemploymentCompensation := ← req fs p "unemployment_compensation" asInt,
             repaidThisYearForThisYear := ← money fs p "repaid_this_year_for_this_year",
             repaidThisYearForEarlierYear := ← money fs p "repaid_this_year_for_earlier_year",
             federalTaxWithheld := ← money fs p "federal_tax_withheld",
             stateIsDifferent := ← flag fs p "state_is_different" }

/-- `Form1099Misc`. -/
def decMisc1099 (p : String) (j : J) : D Form1099Misc :=
  withObj p j fun fs => do
    return { filer := ← req fs p "filer" asEnum, isAlaskaPfd := ← req fs p "is_alaska_pfd" asBool,
             otherIncome := ← req fs p "other_income" asInt,
             federalWithholding := ← money fs p "federal_withholding" }

/-- `Form1099R`. -/
def decR1099 (p : String) (j : J) : D Form1099R :=
  withObj p j fun fs => do
    return { filer := ← req fs p "filer" asEnum,
             distributionCode := ← req fs p "distribution_code" (asArray · asEnum),
             grossDistribution := ← req fs p "gross_distribution" asInt,
             taxableAmount := ← req fs p "taxable_amount" asInt,
             taxableAmountBlank := ← flag fs p "taxable_amount_blank",
             taxableAmountNotDetermined := ← flag fs p "taxable_amount_not_determined",
             totalDistribution := ← flag fs p "total_distribution",
             capitalGain := ← money fs p "capital_gain",
             federalWithholding := ← money fs p "federal_withholding",
             netAppreciation := ← money fs p "net_appreciation",
             iraSepSimple := ← flag fs p "ira_sep_simple",
             otherDollar := ← money fs p "other_dollar",
             otherPercentageNonzero := ← flag fs p "other_percentage_nonzero",
             percentageTotalDistributionNonzero := ← flag fs p "percentage_total_distribution_nonzero",
             amountAllocableToIrr := ← money fs p "amount_allocable_to_irr",
             factaFilingRequirement := ← flag fs p "facta_filing_requirement",
             stateTaxWithheld := ← money fs p "state_tax_withheld",
             payerStateIsDifferent := ← flag fs p "payer_state_is_different",
             hasDeathBenefitPaymentDate := ← flag fs p "has_death_benefit_payment_date",
             isIndirectRollover := ← flag fs p "is_indirect_rollover",
             isDistributionFromMilitaryRetirementPlan :=
               ← flag fs p "is_distribution_from_military_retirement_plan",
             qualifiedDisasterDistribution := ← flag fs p "qualified_disaster_distribution",
             publicSafetyOfficer := ← flag fs p "public_safety_officer",
             publicSafetyOfficerPremiums := ← flag fs p "public_safety_officer_premiums",
             recipientDateOfBirth := (← opt fs p "recipient_date_of_birth" asDate).getD none }

/-- `SocialSecurity`. -/
def decSocialSecurity (p : String) (j : J) : D SocialSecurity :=
  withObj p j fun fs => do
    return { netBenefits := ← req fs p "net_benefits" (asArray · asInt),
             livedApartAllYear := ← flag fs p "lived_apart_all_year",
             federalTaxWithheld := ← optList fs p "federal_tax_withheld" asInt }

/-- `EducatorExpenses`. -/
def decEducator (p : String) (j : J) : D EducatorExpenses :=
  withObj p j fun fs => do
    return { wasK12Educators := ← req fs p "was_k12_educators" asEnum,
             primaryExpenses := ← money fs p "primary_expenses",
             secondaryExpenses := ← money fs p "secondary_expenses" }

/-- `StudentLoanInterest`. -/
def decStudentLoan (p : String) (j : J) : D StudentLoanInterest :=
  withObj p j fun fs => do
    return { hadPayments := ← req fs p "had_payments" asBool,
             loansQualify := ← flag fs p "loans_qualify",
             interestAmount := ← money fs p "interest_amount" }

/-- `Adjustments`. -/
def decAdjustments (p : String) (j : J) : D Adjustments :=
  withObj p j fun fs => do
    return { educatorExpenses := ← opt fs p "educator_expenses" decEducator,
             studentLoanInterest := ← opt fs p "student_loan_interest" decStudentLoan,
             hsa := ← opt fs p "hsa" decHsaInput }

/-- `EstimatedPayments`. -/
def decEstimated (p : String) (j : J) : D EstimatedPayments :=
  withObj p j fun fs => do
    return { paidEstimatedTaxesOrFromLastYear :=
               ← req fs p "paid_estimated_taxes_or_from_last_year" asBool,
             amount := ← money fs p "amount",
             paidUnderDifferentName := ← flag fs p "paid_under_different_name",
             paidWithFormerSpouse := ← opt fs p "paid_with_former_spouse" asEnum }

/-- `CalculateRequest`, phase 1. `api_version` must be 1 and `tax_year` 2024
(the caller reports those two first, with their own error codes). -/
def decRequest (j : J) : D Request :=
  withObj "" j fun fs => do
    let _ ← req fs "" "api_version" (asConst 1)
    let _ ← req fs "" "tax_year" (asConst 2024)
    return { filingStatus := ← req fs "" "filing_status" asEnum,
             filers := ← optD fs "" "filers" decFilers {},
             filingDetails := ← optD fs "" "filing_details" decFilingDetails {},
             w2s := ← optList fs "" "w2s" decW2,
             interestReports := ← optList fs "" "interest_reports" decInt1099,
             form1099g := ← optList fs "" "form_1099g" decG1099,
             form1099misc := ← optList fs "" "form_1099misc" decMisc1099,
             form1099r := ← optList fs "" "form_1099r" decR1099,
             socialSecurity := ← opt fs "" "social_security" decSocialSecurity,
             adjustments := ← optD fs "" "adjustments" decAdjustments {},
             estimatedPayments := ← opt fs "" "estimated_payments" decEstimated,
             filingAnswers := ← opt fs "" "filing_answers" decFilingAnswers,
             dependents := ← optList fs "" "dependents" decDependent,
             credits := ← opt fs "" "credits" decCreditAnswers,
             cdcc := ← opt fs "" "cdcc" decCdccInput,
             premiumTaxCredit := ← opt fs "" "premium_tax_credit" decPtcInput,
             screening := ← opt fs "" "screening" decScreeningAnswers }

/-- Run phase 1: the request, or every shape problem found. -/
def runDecode (j : J) : Except (List FieldError) Request :=
  let (r, s) := (decRequest j).run {}
  if s.errs.isEmpty then .ok r else .error s.errs.toList

end UsTax.Api
