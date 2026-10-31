// Mapping for catala/estimated_payments.catala_en (scope EstimatedPayments), issue #25: 1040 line 26.
// Unanswered facts default as in Direct File: flag false, amount $0, name-change false, former spouse neither.
import { parseOracleValue, toCatalaJson } from '../lib.mjs';

const val = (facts, p) => {
  const r = facts.get(p);
  return r && r.completeness !== 'Incomplete' && r.value !== '' ? r.value : undefined;
};
const FORMER = { spouseDid: 'SpouseDid', bothDid: 'BothDid', tpDid: 'TpDid', neither: 'Neither' };

export default {
  name: 'estimated_payments',
  scope: 'EstimatedPayments',
  file: 'catala/estimated_payments.catala_en',
  appliesTo: () => true,
  inputs: {
    paid_estimated_taxes_or_from_last_year: (f) => val(f, '/paidEstimatedTaxesOrFromLastYear') === 'true',
    estimated_tax_payment_writable: (f) =>
      toCatalaJson('money', parseOracleValue('money', val(f, '/estimatedTaxPaymentWritable') ?? '0')),
    paid_estimated_taxes_or_from_last_year_under_different_name: (f) =>
      val(f, '/paidEstimatedTaxesOrFromLastYearUnderDifferentName') === 'true',
    paid_estimated_taxes_with_former_spouse: (f) =>
      FORMER[val(f, '/paidEstimatedTaxesWithFormerSpouse') ?? 'neither'],
  },
  outputs: [{ oracle: '/estimatedAndFromLastYear', catala: 'estimated_and_from_last_year', type: 'money' }],
};
