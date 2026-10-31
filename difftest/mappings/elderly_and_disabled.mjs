// Mapping for catala/elderly_and_disabled.catala_en (scope ScheduleR), issue #30.
// Run: make difftest SCOPE=elderly_and_disabled
//
// Inputs from the oracle: filing status, living apart, the two filers' dates of birth (age 65 at the end
// of 2024 means born on or before 1960-01-01, the day-before-birthday rule of i1040sr--2024.pdf p R-1),
// the disability answers per filer, W-2 wages per filer (rounded per W-2, as DF does), AGI, the
// nontaxable social security (6a - 6b), the self-reported nontaxable payments, and Credit Limit
// Worksheet line 3 = /totalTentativeTax - /cdccTotalCredit (DF's Schedule 3 lines 1 and 6l are
// placeholders at $0, elderlyAndDisabled.xml /edcTaxLiabilityLimitCalc).
//
// knownDivergence DF-BUG(7): DF adds 1040 line 5a - 5b (return of cost and rollovers) to Schedule R line
// 13b; the statute and instructions exclude it (see the module). Every output that line 13b feeds is listed;
// a check that fails in a scenario where DF's line 13b differs from the self-reported amount is reported as
// "diverge" (not a pass), a check that fails elsewhere is a plain failure.
import { collectionIds, parseMoney } from '../lib.mjs';

const val = (f, p) => { const r = f.get(p); return r && r.completeness !== 'Incomplete' ? r.value : undefined; };
const cents = (f, p) => { const v = val(f, p); return v === undefined || v === '' ? 0n : parseMoney(v); };
const bool = (f, p) => val(f, p) === 'true';
const FS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};

function filerIds(f) {
  const ids = collectionIds(f, '/filers');
  const primary = ids.find((id) => val(f, `/filers/#${id}/isPrimaryFiler`) === 'true');
  if (!primary) throw new Error('no primary filer in scenario');
  return { primary, secondary: ids.find((id) => id !== primary) };
}
// born on or before 1960-01-01: 65 on the day before the 65th birthday, at the end of 2024
const is65 = (f, id) => { const d = id && val(f, `/filers/#${id}/dateOfBirth`); return !!d && d <= '1960-01-01'; };

/** Sum of the filer's W-2 wages: each box 1 rounded to whole dollars, as DF's per-W-2 wages fact. */
function w2Wages(f, id) {
  let sum = 0n;
  for (const w of collectionIds(f, '/formW2s')) {
    if (val(f, `/formW2s/#${w}/filer`) !== id) continue;
    const c = cents(f, `/formW2s/#${w}/writableWages`);
    sum += c >= 0n ? (c + 50n) / 100n : -((-c + 50n) / 100n);
  }
  return sum;
}

function answers(f, id) {
  const p = (n) => `/filers/#${id}/${n}`;
  if (!id) {
    return { is_retired_on_perm_or_total_disability: false, employer_has_mandatory_retirement_age: false,
      has_met_employer_mandatory_retirement_age: false, are_payments_taxable_disability_income: false,
      writable_total_taxable_disability_amount: 0, has_w2_wages: false };
  }
  return {
    is_retired_on_perm_or_total_disability: bool(f, p('isRetOnPermOrTotalDisability')),
    employer_has_mandatory_retirement_age: bool(f, p('employerHasMandatoryRetirementAge')),
    has_met_employer_mandatory_retirement_age: bool(f, p('hasMetEmployerMandatoryRetirementAge')),
    are_payments_taxable_disability_income: bool(f, p('arePaymentsTaxDisabilityIncome')),
    writable_total_taxable_disability_amount: Number(cents(f, p('writableTotalTaxableDisabilityAmount'))) / 100,
    has_w2_wages: w2Wages(f, id) > 0n,
  };
}

/** DF /edcSelfReportedNonTaxablePaymentAmount: asked via writableHasSelfReportedNonTaxablePayments, rounded. */
function selfReported(f) {
  if (!bool(f, '/writableHasSelfReportedNonTaxablePayments')) return 0n;
  const c = cents(f, '/writableEdcSelfReportedNonTaxablePaymentAmount');
  return c >= 0n ? ((c + 50n) / 100n) * 100n : -(((-c + 50n) / 100n) * 100n);
}

// DF line 13b differs from the self-reported amount: the 5a - 5b part is non-zero (DF-BUG(7)).
const bug7 = (f) => cents(f, '/edcNonTaxableIncomeNotIncludingSocialSecurityAndRrb') !== selfReported(f);
const BUG7_PATHS = [
  '/edcNonTaxableIncomeNotIncludingSocialSecurityAndRrb', '/edcTotalNonTaxableAmount', '/edcAdjustedCreditAmount',
  '/edcNetCreditAmount', '/netEdcAmount', '/totalEdc', '/isReceivingEdc',
];

const money = (oracle, catala) => ({ oracle, catala, type: 'money' });

export default {
  name: 'elderly_and_disabled',
  scope: 'ScheduleR',
  file: 'catala/elderly_and_disabled.catala_en',
  appliesTo: () => true,
  inputs: {
    filing_status: (f) => FS[val(f, '/filingStatus')],
    // DF /livedApartAllYear (filers.catala_en); only read for MFS.
    lived_apart_all_year: (f) => val(f, '/livedTogetherAllYearWithSpouse') === 'false'
      && val(f, '/spouseLivedTogetherMonths') === 'livedApartAllYear',
    primary_age65_or_older: (f) => is65(f, filerIds(f).primary),
    secondary_age65_or_older: (f) => is65(f, filerIds(f).secondary),
    primary_answers: (f) => answers(f, filerIds(f).primary),
    secondary_answers: (f) => answers(f, filerIds(f).secondary),
    agi: (f) => Number(cents(f, '/agi')) / 100,
    non_taxable_social_security_benefits: (f) =>
      Number(cents(f, '/socialSecurityBenefits') - cents(f, '/taxableSocialSecurityBenefits')) / 100,
    self_reported_non_taxable_payments: (f) => Number(selfReported(f)) / 100,
    credit_limit_worksheet_line_3: (f) => Number(cents(f, '/totalTentativeTax') - cents(f, '/cdccTotalCredit')) / 100,
  },
  outputs: [
    ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => ({ oracle: `/edcLine${n}`, catala: `edc_line${n}`, type: 'bool' })),
    money('/edcFilingStatusAmt', 'edc_filing_status_amt'),
    money('/statusBasedDisabilityIncome', 'status_based_disability_income'),
    money('/lesserOfFilingStatusAmountAndTaxableDisabilityIncome', 'lesser_of_filing_status_amount_and_taxable_disability_income'),
    money('/edcNonTaxableSocialSecurityAndRailroadBenefits', 'edc_non_taxable_social_security_and_railroad_benefits'),
    money('/edcNonTaxableIncomeNotIncludingSocialSecurityAndRrb', 'edc_non_taxable_income_not_including_social_security_and_rrb'),
    money('/edcTotalNonTaxableAmount', 'edc_total_non_taxable_amount'),
    money('/edcExemptionAmount', 'edc_exemption_amount'),
    money('/edcMagi', 'edc_magi'),
    money('/edcHalfMagi', 'edc_half_magi'),
    money('/edcAdjustedCreditAmount', 'edc_adjusted_credit_amount'),
    money('/edcNetCreditAmount', 'edc_net_credit_amount'),
    money('/netEdcAmount', 'net_edc_amount'),
    money('/edcTaxLiabilityLimit', 'edc_tax_liability_limit'),
    money('/totalEdc', 'total_edc'),
    { oracle: '/isReceivingEdc', catala: 'is_receiving_edc', type: 'bool' },
  ],
  knownDivergence: BUG7_PATHS.map((oracle) => ({ oracle, bug: 'DF-BUG(7)', when: bug7 })),
};
