// Mapping for catala/tests/difftest_line25b.catala_en (scope Line25bFrom1099GAndMisc), issue #21:
// the 1099-G and 1099-MISC terms of Form 1040 line 25b. Oracle /form1099Withholding also holds
// 1099-INT, SSA and 1099-R terms: 1099-INT is computed here (round of box 4 when has1099, as
// interest.xml /interestReports/*/taxWithheld), SSA reports do not occur in the oracle, and scenarios
// with 1099-R federal withholding are skipped (module #22). Run: make difftest SCOPE=line25b_1099g_misc
import { collectionIds, toCatalaJson } from '../lib.mjs';
import { form1099Gs } from './unemployment.mjs';
import { form1099Miscs } from './form1099_misc.mjs';

const val = (facts, p) => {
  const r = facts.get(p);
  return r && r.completeness !== 'Incomplete' ? r.value : undefined;
};
const cents = (v) => BigInt(Math.round(parseFloat(v || '0') * 100));
const interestTerm = (facts) =>
  collectionIds(facts, '/interestReports').reduce((a, id) => {
    const p = `/interestReports/#${id}/`;
    if (val(facts, p + 'has1099') !== 'true') return a;
    const c = cents(val(facts, p + 'writableTaxWithheld'));
    return a + ((c + (c >= 0n ? 50n : -50n)) / 100n) * 100n; // round half away from zero to dollars
  }, 0n);

export default {
  name: 'line25b_1099g_misc',
  scope: 'Line25bFrom1099GAndMisc',
  file: 'catala/tests/difftest_line25b.catala_en',
  appliesTo: (facts) => {
    if (collectionIds(facts, '/socialSecurityReports').length > 0) return 'needs SSA withholding (#23)';
    for (const id of collectionIds(facts, '/form1099Rs'))
      if (cents(val(facts, `/form1099Rs/#${id}/writableFederalWithholding`)) !== 0n) return 'needs 1099-R withholding (#22)';
    return true;
  },
  inputs: {
    form_1099gs: form1099Gs,
    form_1099miscs: form1099Miscs,
    other_terms: (facts) => toCatalaJson('money', interestTerm(facts)),
  },
  outputs: [{ oracle: '/form1099Withholding', catala: 'form_1099_withholding', type: 'money' }],
};
