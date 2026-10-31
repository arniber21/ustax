// Mapping for catala/unemployment.catala_en (scope Unemployment), issue #21: Form 1099-G.
// Unanswered boxes are $0, as in Direct File (unemployment.xml Switch on IsComplete falling back to $0).
// Oracle path /xmlUnemploymentCompensation is /unemploymentCompensation with ExportZero (DF does not
// dump /unemploymentCompensation itself). Run: make difftest SCOPE=unemployment
import { collectionIds, toCatalaJson, parseOracleValue } from '../lib.mjs';

const val = (facts, p) => {
  const r = facts.get(p);
  return r && r.completeness !== 'Incomplete' ? r.value : undefined;
};
const money = (facts, p) => toCatalaJson('money', parseOracleValue('money', val(facts, p) || '0'));
const primaryId = (facts) =>
  collectionIds(facts, '/filers').find((id) => val(facts, `/filers/#${id}/isPrimaryFiler`) === 'true');

export const form1099Gs = (facts) =>
  collectionIds(facts, '/form1099Gs').map((id) => {
    const p = `/form1099Gs/#${id}/`;
    return {
      filer: val(facts, p + 'filer') === primaryId(facts) ? 'PrimaryFiler' : 'SecondaryFiler',
      amount: money(facts, p + 'amount'),
      writable_amount_paid_back_for_benefits_in_tax_year: money(facts, p + 'writableAmountPaidBackForBenefitsInTaxYear'),
      writable_amount_paid_back_for_benefits_before_tax_year: money(facts, p + 'writableAmountPaidBackForBenefitsBeforeTaxYear'),
      writable_federal_tax_withheld: money(facts, p + 'writableFederalTaxWithheld'),
      state_is_different_state: val(facts, p + 'writableState') === 'differentState',
    };
  });

export default {
  name: 'unemployment',
  scope: 'Unemployment',
  file: 'catala/unemployment.catala_en',
  appliesTo: () => true,
  inputs: { form_1099gs: form1099Gs },
  outputs: [
    { oracle: '/xmlUnemploymentCompensation', catala: 'unemployment_compensation', type: 'money' },
    { oracle: '/unemploymentCompRepaidAmt', catala: 'unemployment_comp_repaid_amt', type: 'money' },
    { oracle: '/receivedUnemploymentCompensation', catala: 'received_unemployment_compensation', type: 'bool' },
    { oracle: '/xmlHasRepaidUnemploymentCompensation', catala: 'has_repaid_unemployment_compensation', type: 'bool' },
  ],
};
