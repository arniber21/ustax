// Line 25b, 1099-R part (issue #22): /form1099Withholding is the sum over 1099-INT, SSA-1099, 1099-G,
// 1099-MISC and 1099-R, so it equals our 1099-R withholding only in scenarios with no other 1099.
import { formsInput } from './form1099_rs.mjs';
import { collectionIds } from '../lib.mjs';

export default {
  name: 'form1099_rs_withholding',
  scope: 'Form1099Rs',
  file: 'catala/form1099_rs.catala_en',
  appliesTo: (f) => {
    if (collectionIds(f, '/form1099Rs').length === 0) return 'no 1099-R';
    for (const c of ['/interestReports', '/form1099Gs', '/socialSecurityReports', '/form1099Miscs'])
      if (collectionIds(f, c).length > 0) return `other 1099 form (${c})`;
    return true;
  },
  knownDivergence: [],
  inputs: { forms: formsInput },
  outputs: [{ oracle: '/form1099Withholding', catala: 'form_1099r_federal_income_tax_withheld', type: 'money' }],
};
