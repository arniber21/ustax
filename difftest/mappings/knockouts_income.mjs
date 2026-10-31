// Mapping for catala/knockouts_income.catala_en (scope KnockoutsIncome), issue #36.
// Run: make difftest SCOPE=knockouts_income
//
// Compares `unsupported_income_or_hsa` with the oracle's /flowIsKnockedOut on ALL 161 scenarios
// (`includeKnockedOut`). /flowIsKnockedOut is Complete only for the 4 knocked-out scenarios; for the other
// 157 it is a Placeholder `false` that means "not knocked out" (oracle/README.md), checked here as an expected
// false (`placeholderFalse`). So:
//   * 157 scenarios: no income/HSA/process knockout may fire (a false alarm of any merged module shows up here);
//   * 4 scenarios (1099r-box-2b-total-distribution, ats-2-1099r*): DF's only true member is
//     /knockoutForForm1099RBox8Percentage, which is DF-BUG-8 (box 8 "0.00" counted as nonzero); the Catala
//     module follows the law, so these are reported as known divergences, not passes.
// Inputs are built from the same oracle facts as the module mappings, which are reused.
import { scalar } from '../lib.mjs';
import { unpluggedInputs } from '../form_1040_inputs.mjs';
import w2 from './form_w2s.mjs';
import unemployment from './unemployment.mjs';
import misc from './form1099_misc.mjs';
import { formsInput } from './form1099_rs.mjs';
import ss from './social_security.mjs';
import ep from './estimated_payments.mjs';
import hsa from './hsa.mjs';

const val = (f, p) => { const r = f.get(p); return r && r.completeness !== 'Incomplete' ? r.value : undefined; };
const bool = (p) => (f) => val(f, p) === 'true';
const zero = (f, p) => { const v = val(f, p); return v === undefined || v === '' || Number(v) === 0; };

const { primary_filer, secondary_filer, knockout_has_no_payments_or_credits: _k, paid_estimated_taxes_or_from_last_year: _p, ...hsaRest } = hsa.inputs;

export default {
  name: 'knockouts_income',
  scope: 'KnockoutsIncome',
  file: 'catala/knockouts_income.catala_en',
  includeKnockedOut: true,
  // DF-BUG-8 (docs/direct-file-bugs.md): DF's /knockoutForForm1099RBox8Percentage fires on a box 8 percentage of
  // "0.00" (StripChars quirk); the formalization follows the law and does not. These are the only knockouts in
  // all four scenarios (checked by evaluating every flow.xml member on the DF engine).
  knownDivergence: ['1099r-box-2b-total-distribution', 'ats-2-1099r', 'ats-2-1099r-blank-taxable', 'ats-2-1099r-nonzero-taxable']
    .map((scenario) => ({ scenario, path: '/flowIsKnockedOut', bug: 'DF-BUG-8' })),
  appliesTo: () => true,
  inputs: {
    filing_status: unpluggedInputs.filing_status,
    agi: scalar('/agi', { type: 'money', missing: '0' }),
    primary_filer_can_be_claimed: w2.inputs.primary_filer_can_be_claimed,
    secondary_filer_can_be_claimed: w2.inputs.secondary_filer_can_be_claimed,
    paid_estimated_taxes_or_from_last_year: ep.inputs.paid_estimated_taxes_or_from_last_year,
    // taxCalculations.xml /knockoutHasNoPaymentsOrCredits, from the oracle's own totals
    knockout_has_no_payments_or_credits: (f) => val(f, '/paidEstimatedTaxesOrFromLastYear') !== 'true'
      && ['/totalIncome', '/agi', '/totalTax', '/totalPayments'].every((p) => zero(f, p)),
    income_sources_supported: bool('/incomeSourcesSupported'),
    received_digital_assets: bool('/receivedDigitalAssets'),
    disposed_digital_assets: bool('/disposedDigitalAssets'),
    has_foreign_accounts: bool('/hasForeignAccounts'),
    // the oracle exports only the Or of the two trust facts
    is_foreign_trusts_grantor: bool('/isForeignTrustsGrantorOrHasForeignTrustsTransactions'),
    has_foreign_trusts_transactions: () => false,
    made_ira_contributions: bool('/madeIraContributions'),
    interest_reports: unpluggedInputs.interest_reports,
    w2s: w2.inputs.w2s,
    combat_pay_election: w2.inputs.combat_pay_election,
    // W-2 boxes 14 and 15 are not in the oracle's writable facts that matter here: no scenario sets them
    w2_box15_income_from_different_state: () => false,
    w2_has_box14_nyrrta_knockout_code: () => false,
    w2_has_rrta_codes_in_box14: () => false,
    lived_in_ny: () => false,
    w2_paid_yonkers_taxes: () => false,
    part_year_yonkers_resident: () => false,
    // filers.xml /flowKnockoutUnsupportedState = Not(/hasIncomeInScope)
    filer_residence_and_income_state: (f) => (val(f, '/filerResidenceAndIncomeState') ?? 'fl').toUpperCase(),
    primary_filer_forms_another_state: (f) => val(f, '/primaryFilerW2And1099IntInScopedState') === 'anotherState',
    received_alaska_pfd: bool('/receivedAlaskaPfd'),
    spouse_received_alaska_pfd: bool('/spouseReceivedAlaskaPfd'),
    treat_as_mfj: (f) => val(f, '/filingStatus') === 'marriedFilingJointly',
    spouse_lives_in_other_or_multiple_states: (f) => ['moreThanOne', 'noneOfTheAbove'].includes(val(f, '/spouseLivesInTPState')),
    // /allSpouseFormsInScopedState: /spouseIncomeFormsInScopedState if answered, else the W-2/1099-INT answer
    spouse_forms_another_state: (f) => (val(f, '/spouseIncomeFormsInScopedState') ?? val(f, '/spouseW2And1099IntInScopedState')) === 'anotherState',
    form_1099gs: unemployment.inputs.form_1099gs,
    form_1099miscs: misc.inputs.form_1099miscs,
    form_1099rs: formsInput,
    ...ss.inputs,
    estimated_tax_payment_writable: ep.inputs.estimated_tax_payment_writable,
    paid_estimated_taxes_or_from_last_year_under_different_name: ep.inputs.paid_estimated_taxes_or_from_last_year_under_different_name,
    paid_estimated_taxes_with_former_spouse: ep.inputs.paid_estimated_taxes_with_former_spouse,
    ...hsaRest,
    hsa_primary_filer: primary_filer,
    hsa_secondary_filer: secondary_filer,
    // flow.xml: both are the constant False in DF
    is_after_tax_day_and_not_resubmitting: () => false,
    is_after_resubmission_deadline: () => false,
  },
  outputs: [
    { oracle: '/flowIsKnockedOut', catala: 'unsupported_income_or_hsa', type: 'bool', placeholderFalse: true },
  ],
};
