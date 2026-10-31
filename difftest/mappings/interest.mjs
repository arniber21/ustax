// Mapping for catala/interest.catala_en (scope Interest), issue #43: Form 1040 lines 2a and 2b, Schedule B.
// Run: make difftest SCOPE=interest ; make lean-difftest SCOPE=interest
//
// Inputs are the oracle's writable facts (same 1099-INT field mapping as difftest/form_1040_inputs.mjs and
// catala/tests/gen_oracle_interest.py). The oracle has no interest knockout facts: `unsupported` and
// `total_tax_withheld` are extraOutputs (compared Lean = Catala only; the 157 non-knocked-out scenarios
// are supported returns, so Catala's `unsupported` is expected to be false there).
import { interestReports } from '../form_1040_inputs.mjs';
import { scalar } from '../lib.mjs';

const val = (f, p) => {
  const r = f.get(p);
  return r && r.completeness !== 'Incomplete' ? r.value : undefined;
};
const STATUS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};

export default {
  name: 'interest',
  scope: 'Interest',
  file: 'catala/interest.catala_en',
  appliesTo: () => true,
  inputs: {
    interest_reports: interestReports,
    // as in gen_oracle_interest.py: any of the three foreign facts
    has_foreign_accounts_or_trusts: (f) =>
      val(f, '/hasForeignAccounts') === 'true' || val(f, '/isForeignTrustsGrantor') === 'true' ||
      val(f, '/hasForeignTrustsTransactions') === 'true',
    filing_status: (f) => STATUS[val(f, '/filingStatus')],
    agi: scalar('/agi', { type: 'money', missing: '0' }),
    flow_has_seen_deductions: (f) => val(f, '/flowHasSeenDeductions') === 'true',
  },
  outputs: [
    { oracle: '/interestIncome', catala: 'interest_income', type: 'money' },
    { oracle: '/taxExemptInterest', catala: 'tax_exempt_interest', type: 'money' },
    { oracle: '/requiresScheduleB', catala: 'requires_schedule_b', type: 'bool' },
  ],
  extraOutputs: [
    { catala: 'total_tax_withheld', type: 'money' },
    { catala: 'unsupported', type: 'bool' },
  ],
};
