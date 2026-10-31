// Mapping for catala/tax_rates.catala_en (scope TentativeTax): Form 1040 line 16, issue #41.
// Run: make difftest SCOPE=tax_rates (Catala vs oracle) or make lean-difftest SCOPE=tax_rates
// (Direct File / Catala / Lean). The first Lean-ported scope; see lean/README.md.
//
// Oracle: /tentativeTaxFromTaxableIncome from /taxableIncome and /filingStatus. The other two Catala outputs
// (the Tax Table midpoint and the cumulative form) have no oracle fact; `extraOutputs` lists them so the Lean
// harness also compares Lean with Catala on them.
import { scalar } from '../lib.mjs';

const FS = {
  single: 'Single',
  marriedFilingJointly: 'MarriedFilingJointly',
  marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold',
  qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse', // Direct File spells it "qualified"
};

export default {
  name: 'tax_rates',
  scope: 'TentativeTax',
  file: 'catala/tax_rates.catala_en',
  appliesTo: (f) => {
    const t = f.get('/taxableIncome'), s = f.get('/filingStatus');
    return t && t.completeness === 'Complete' && s && s.completeness === 'Complete' && FS[s.value]
      ? true : 'no complete /taxableIncome or /filingStatus';
  },
  inputs: {
    taxable_income: scalar('/taxableIncome'),
    filing_status: (f) => FS[f.get('/filingStatus').value],
  },
  outputs: [
    { oracle: '/tentativeTaxFromTaxableIncome', catala: 'tentative_tax_from_taxable_income', type: 'money' },
  ],
  extraOutputs: [
    { catala: 'rounded_taxable_income', type: 'money' },
    { catala: 'tentative_tax_cumulative_form', type: 'money' },
  ],
};
