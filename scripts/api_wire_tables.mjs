// TEST-ONLY, UNTRUSTED: API form field <-> Catala Calculator input field (renames only; every other field keeps
// its name after stripping `writable_`/`writeable_`). Used by scripts/oracle_to_api_request.mjs. The Catala side
// of the same mapping is catala/api_calculator.catala_en; docs/api-mapping.md has the tables.
export const BOX12 = {
  A: 'uncollected_oasdi_tax_on_tips', B: 'uncollected_medicare_tax_on_tips', C: 'taxable_life_insurance_over_50k',
  D: 'deferrals_401k', E: 'deferrals_403b', F: 'sarsep_deferrals', G: 'deferrals_457b', H: 'deferrals_501c18',
  J: 'nontaxable_sick_pay', K: 'golden_parachute_excise_tax', L: 'expense_reimbursements',
  M: 'uncollected_oasdi_tax_on_life_insurance_over_50k', N: 'uncollected_medicare_tax_on_life_insurance_over_50k',
  P: 'armed_forces_moving_expenses', Q: 'writable_combat_pay', R: 'archer_msa_contributions', S: 'simple_contributions',
  T: 'adoption_benefits', V: 'nso_income', W: 'employer_hsa_contributions', Y: 'deferrals_409a', Z: 'nqdc_deferrals',
  AA: 'roth401k_contributions', BB: 'roth403b_contributions', DD: 'health_coverage_cost', EE: 'roth457b_contributions',
  FF: 'qsehra_benefits', GG: 'income_83i', HH: 'deferrals_83i', II: 'non_taxable_medicaid_waiver_payments',
};
export const INT_RENAME = {
  interest_income: 'writable_1099_amount',
  early_withdrawal_penalty: 'writable_early_withdrawl_penalty_amount',
  government_bond_interest: 'writable_interest_on_government_bonds',
  federal_tax_withheld: 'writable_tax_withheld',
  private_activity_bond_interest: 'writable_specified_private_activity_bond_interest',
  bond_premium_treasury: 'writable_bond_premium_on_treasury_obligations',
  bond_premium_tax_exempt: 'writable_bond_premium_on_tax_exempt_bond',
  state_is_different: 'state_is_different_state',
};
export const G_RENAME = {
  unemployment_compensation: 'amount',
  repaid_this_year_for_this_year: 'writable_amount_paid_back_for_benefits_in_tax_year',
  repaid_this_year_for_earlier_year: 'writable_amount_paid_back_for_benefits_before_tax_year',
  federal_tax_withheld: 'writable_federal_tax_withheld',
  state_is_different: 'state_is_different_state',
};
export const MISC_RENAME = { other_income: 'writable_other_income', federal_withholding: 'writable_federal_withholding' };
// Form 1099-R: API name -> Catala name (the rest are identical)
export const R_RENAME = {
  gross_distribution: 'writable_gross_distribution', taxable_amount: 'writable_taxable_amount',
  capital_gain: 'writable_capital_gain', federal_withholding: 'writable_federal_withholding',
  net_appreciation: 'writable_net_appreciation', other_dollar: 'writable_other_dollar',
  amount_allocable_to_irr: 'writable_amount_allocable_to_irr', state_tax_withheld: 'writable_state_tax_withheld',
  is_indirect_rollover: 'writable_is_indirect_rollover',
  is_distribution_from_military_retirement_plan: 'writable_is_distribution_from_military_retirement_plan',
  qualified_disaster_distribution: 'writable_qualified_disaster_distribution',
  public_safety_officer: 'writeable_public_safety_officer', public_safety_officer_premiums: 'writeable_public_safety_officer_premiums',
};
export const W2_RENAME = {
  wages: 'writable_wages', federal_withholding: 'writable_federal_withholding', oasdi_wages: 'writable_oasdi_wages',
  oasdi_withholding: 'writable_oasdi_withholding', medicare_wages: 'writable_medicare_wages',
  medicare_withholding: 'writable_medicare_withholding', allocated_tips: 'writable_allocated_tips',
  dependent_care_benefits: 'writable_dependent_care_benefits', non_qualified_plans: 'writable_non_qualified_plans',
};
// Dependent (household member): API name -> [path in Catala HouseholdMember]
export const DEP = {
  relationship: 'dependent.person.relationship', date_of_birth: 'dependent.person.date_of_birth',
  full_time_student: 'dependent.person.full_time_student', permanent_total_disability: 'dependent.person.permanent_total_disability',
  residency_duration: 'dependent.person.residency_duration', own_support: 'dependent.person.own_support',
  married: 'dependent.person.married', joint_return: 'dependent.person.writable_joint_return',
  required_to_file: 'dependent.person.writable_required_to_file', filing_only_for_refund: 'dependent.person.writable_filing_only_for_refund',
  could_be_qualifying_child_of_another: 'dependent.person.writable_could_be_qualifying_child_of_another',
  potential_claimer_must_file: 'dependent.person.writable_potential_claimer_must_file',
  potential_claimer_did_file: 'dependent.person.writable_potential_claimer_did_file',
  potential_claimer_filed_only_for_refund: 'dependent.person.writable_potential_claimer_filed_only_for_refund',
  gross_income: 'dependent.answers.gross_income', qr_support_test: 'dependent.answers.writable_qr_support_test',
  tin_type: 'dependent.answers.tin_type', is_us_citizen_full_year: 'dependent.answers.is_us_citizen_full_year',
  us_resident: 'dependent.answers.writable_us_resident', us_national: 'dependent.answers.writable_us_national',
  canada_mexico_resident: 'dependent.answers.writable_canada_mexico_resident', tp_claims: 'dependent.answers.tp_claims',
  custody: 'dependent.split',
  tp_paid_most_of_home_upkeep: 'upkeep.tp_paid_most_of_home_upkeep',
  tp_paid_most_of_parent_home_upkeep: 'upkeep.tp_paid_most_of_parent_home_upkeep',
  ssn_employment_validity: 'ssn_employment_validity', ssn_only_for_federally_funded_benefit: 'ssn_only_for_federally_funded_benefit',
  months_lived_with_tp_in_us: 'months_lived_with_tp_in_us', cdcc: 'cdcc',
};
