// Mapping for catala/ptc_net.catala_en (scope NetPtc): Form 8962 lines 26 to 29 and Table 5, issue #34
// (Lean port #47). Run: make difftest SCOPE=ptc_net, make lean-difftest SCOPE=ptc_net
//
// The return-level comparison stays the `calculator` mapping (this module feeds Form 1040 lines 17 and 31);
// this mapping checks the scope on its own. Inputs are the oracle's derived rows for the facts parts 1 and 2
// own:
//   filing_status                 /filingStatus
//   household_income_as_percent   /householdIncomeAsPercent (Complete in every scenario)
//   tax_family_size_is_zero       /taxFamilySize = 0 (ptc.xml /taxFamilySizeIsZero is not an oracle row)
//   total_ptc_amount_allowed      /totalPtcAmountAllowed (Incomplete without a Form 8962: $0, as Ptc_allowed)
//   total_aptc_amount_taken       /totalAptcAmountTaken (same)
// Compared: /netPtcAmount, /netPtcAmountWhenZeroOrPositive (line 26), /netPtcAmountWhenNegative (line 27),
// /ptcRepaymentLimitation (line 28) and /lesserOfNetPtcAmountAndRepaymentLimitation (line 29). Most rows are
// Incomplete in the scenarios with no Form 8962 and are counted as unchecked; line 29 is Complete everywhere.

const val = (f, p) => { const r = f.get(p); return r && r.completeness !== 'Incomplete' ? r.value : undefined; };
const money = (f, p) => { const v = val(f, p); return v === undefined || v === '' ? 0 : Number(v); };
const FS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};

export default {
  name: 'ptc_net',
  scope: 'NetPtc',
  file: 'catala/ptc_net.catala_en',
  appliesTo: () => true,
  inputs: {
    filing_status: (f) => FS[val(f, '/filingStatus')],
    household_income_as_percent: (f) => Number(val(f, '/householdIncomeAsPercent') ?? 0),
    tax_family_size_is_zero: (f) => Number(val(f, '/taxFamilySize') ?? 0) === 0,
    total_ptc_amount_allowed: (f) => money(f, '/totalPtcAmountAllowed'),
    total_aptc_amount_taken: (f) => money(f, '/totalAptcAmountTaken'),
  },
  outputs: [
    { oracle: '/netPtcAmount', catala: 'net_ptc_amount', type: 'money' },
    { oracle: '/netPtcAmountWhenZeroOrPositive', catala: 'line26', type: 'money' },
    { oracle: '/netPtcAmountWhenNegative', catala: 'line27', type: 'money' },
    { oracle: '/ptcRepaymentLimitation', catala: 'line28', type: 'money' },
    { oracle: '/lesserOfNetPtcAmountAndRepaymentLimitation', catala: 'line29', type: 'money' },
  ],
  extraOutputs: [
    { catala: 'net_ptc_credit', type: 'money' },
    { catala: 'excess_aptc_repayment', type: 'money' },
  ],
  knownDivergence: [],
};
