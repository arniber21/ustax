// Mapping for catala/form1099_misc.catala_en (scope Form1099Miscs), issue #21: Alaska PFD.
// Run: make difftest SCOPE=form1099_misc
import { collectionIds, toCatalaJson, parseOracleValue } from '../lib.mjs';

const val = (facts, p) => {
  const r = facts.get(p);
  return r && r.completeness !== 'Incomplete' ? r.value : undefined;
};
const money = (facts, p) => toCatalaJson('money', parseOracleValue('money', val(facts, p) || '0'));
const primaryId = (facts) =>
  collectionIds(facts, '/filers').find((id) => val(facts, `/filers/#${id}/isPrimaryFiler`) === 'true');

export const form1099Miscs = (facts) =>
  collectionIds(facts, '/form1099Miscs').map((id) => {
    const p = `/form1099Miscs/#${id}/`;
    return {
      filer: val(facts, p + 'filer') === primaryId(facts) ? 'PrimaryFiler' : 'SecondaryFiler',
      is_alaska_pfd: true, // DF: isAlaskaPfd is always true
      writable_other_income: money(facts, p + 'writableOtherIncome'),
      writable_federal_withholding: money(facts, p + 'writableFederalWithholding'),
    };
  });

export default {
  name: 'form1099_misc',
  scope: 'Form1099Miscs',
  file: 'catala/form1099_misc.catala_en',
  appliesTo: () => true,
  inputs: { form_1099miscs: form1099Miscs },
  outputs: [{ oracle: '/alaskaPfdIncome', catala: 'alaska_pfd_income', type: 'money' }],
};
