// Mapping for catala/savers_credit.catala_en (scope SaversCredit), issue #29. Run: make difftest SCOPE=savers_credit
//
// Oracle outputs checked (Form 8880): /qualifiedSaverCreditAmount (line 12), /qualifiedForSaverCredit,
// /combinedCreditLimit (7), /ratioedCombinedCreditLimit (10), /primaryFilerTotalContributions (3a),
// /secondaryFilerTotalContributions (3b), /primaryFilersDeferralsAndContributions (2a),
// /secondaryFilersDeferralsAndContributions (2b), /primaryFilerIraAndAbleContributions (1a),
// /secondaryFilerIraAndAbleContributions (1b), /limitationBasedOnTaxLiability (11).
// /saversCreditMultiplier is an enum in the oracle ('fifty', ...) and a constructor name here
// ('Fifty'), which the runner cannot compare; it is covered through lines 10 and 12.
//
// Inputs come from the oracle's writable facts; the values other modules own are rebuilt here the way those modules
// compute them (the same approach as mappings/hsa.mjs):
//   W-2 box 12 deferrals per filer: Round of each rounded code D, E, F, G (only if governmental 457(b)), H, S, AA,
//     BB, EE, summed per W-2 and per filer (formW2s.xml /formW2s/*/totalDeferralsAndContributions);
//   1099-R savers distributions per filer: codes 2, 7, 2B, B2, 7B, B7 and not a military plan (form1099Rs.xml),
//     summed per filer (Round is applied by the scope);
//   under 18: 2024 - year(dateOfBirth - 1 day) < 18 (filers.xml /filers/*/ageCalculatedDayBeforeDOB);
//   claimed as dependent (filers.xml /primaryFilerIsClaimedAsDependent): for a return that is not joint,
//     canBeClaimed and (potentialClaimerMustFile or (potentialClaimerDidFile and not filed only for refund)) and
//     willBeClaimed. APPROXIMATION: "filed only for refund" is not in the oracle and is taken as false; for a
//     joint return the Filers chain (/isMFJDependent, /taxpayerCannotBeClaimed) is not rebuilt and both flags are
//     false. No scenario with a credit-relevant deferral amount depends on this (checked by hand: the MFJ scenarios
//     with canBeClaimed have $0 deferrals).
//   1040 line 18 (/totalTentativeTax), CDCC (/cdccTotalCredit) and Schedule R (/totalEdc) are the oracle's values.
//
// knownDivergence: DF-BUG(29-a): DF leaves line 4 at $0 in the column of a spouse who is not an eligible individual (a
// student), and drops that spouse's distributions from the other column. The statute and the form say both spouses'
// amounts go in both columns. In these two scenarios the credit is unchanged (the ineligible spouse's line 2 is $0,
// so line 5 is $0 either way); only the printed line 4 differs. No oracle scenario has an ineligible spouse with
// distributions of his own, so the credit-changing case is covered by the unit test only.
import { collectionIds, parseMoney } from '../lib.mjs';

const val = (f, p) => { const r = f.get(p); return r && r.completeness !== 'Incomplete' && r.value !== '' ? r.value : undefined; };
const bool = (f, p, d = false) => { const v = val(f, p); return v === undefined ? d : v === 'true'; };
const cents = (f, p) => { const v = val(f, p); return v === undefined ? 0n : parseMoney(v); };
const dollars = (c) => Number(c) / 100;
const roundDollar = (c) => (c >= 0n ? (c + 50n) / 100n * 100n : -((-c + 50n) / 100n * 100n));
const STATUS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};

function filerIds(f) {
  const ids = collectionIds(f, '/filers');
  const primary = ids.find((id) => val(f, `/filers/#${id}/isPrimaryFiler`) === 'true');
  if (!primary) throw new Error('no primary filer in scenario');
  return { primary, secondary: ids.find((id) => id !== primary) };
}

const isMfj = (f) => val(f, '/filingStatus') === 'marriedFilingJointly';

function under18(f, id) {
  const dob = id && val(f, `/filers/#${id}/dateOfBirth`);
  if (!dob) return false;
  const d = new Date(`${dob}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() - 1);
  return 2024 - d.getUTCFullYear() < 18;
}

const DEFERRAL_FIELDS = ['401kDeferrals', '403bDeferrals', 'sarsepDeferrals', '501c18Deferrals', 'simpleContributions',
  'roth401kContributions', 'roth403bContributions', 'roth457bContributions'];
function deferrals(f, id) {
  let sum = 0n;
  for (const w of collectionIds(f, '/formW2s')) {
    if (val(f, `/formW2s/#${w}/filer`) !== id) continue;
    for (const k of DEFERRAL_FIELDS) sum += roundDollar(cents(f, `/formW2s/#${w}/${k}`));
    if (bool(f, `/formW2s/#${w}/457bIsGovernmentalPlan`)) sum += roundDollar(cents(f, `/formW2s/#${w}/457bDeferrals`));
  }
  return roundDollar(sum);
}

// Distribution code (box 7) is the supported set 2, 7 (with an optional B): "2", "7", "2B", "B2", "7B", "B7".
const SAVERS_CODES = new Set(['2', '7', '2B', 'B2', '7B', 'B7']);
function distributions(f, id) {
  let sum = 0n;
  for (const r of collectionIds(f, '/form1099Rs')) {
    if (val(f, `/form1099Rs/#${r}/filer`) !== id) continue;
    const code = (val(f, `/form1099Rs/#${r}/writableDistributionCode`) ?? '').trim().toUpperCase();
    if (!SAVERS_CODES.has(code)) continue;
    if (bool(f, `/form1099Rs/#${r}/writableIsDistributionFromMilitaryRetirementPlan`)) continue;
    sum += cents(f, `/form1099Rs/#${r}/writableGrossDistribution`);
  }
  return sum;
}

function claimed(f, id) {
  if (isMfj(f) || !id) return false;
  const p = (n) => `/filers/#${id}/${n}`;
  const could = bool(f, p('canBeClaimed'))
    && (bool(f, p('potentialClaimerMustFile')) || bool(f, p('potentialClaimerDidFile')));
  return could && bool(f, p('willBeClaimed'));
}

export default {
  name: 'savers_credit',
  scope: 'SaversCredit',
  file: 'catala/savers_credit.catala_en',
  appliesTo: () => true,
  knownDivergence: [
    { scenario: '1099r-savers-mfj-primary', path: '/secondaryFilerGrossDistributions', bug: 'DF-BUG(29-a)',
      note: 'line 4b of the student spouse: DF $0, statute and form include both spouses (4000)' },
    { scenario: '1099r-savers-mfj-spouse-eligible', path: '/primaryFilerGrossDistributions', bug: 'DF-BUG(29-a)',
      note: 'line 4a of the student primary filer: DF $0, statute and form include both spouses (4000)' },
  ],
  inputs: {
    filing_status: (f) => STATUS[val(f, '/filingStatus')],
    agi: (f) => dollars(cents(f, '/agi')),
    is_mfj_dependent: () => false,
    primary_filer_is_under18: (f) => under18(f, filerIds(f).primary),
    primary_filer_is_student: (f) => bool(f, `/filers/#${filerIds(f).primary}/isStudent`),
    primary_filer_is_claimed_as_dependent: (f) => claimed(f, filerIds(f).primary),
    secondary_filer_is_under18: (f) => under18(f, filerIds(f).secondary),
    secondary_filer_is_student: (f) => bool(f, `/filers/#${filerIds(f).secondary}/isStudent`),
    secondary_filer_is_claimed_as_dependent: () => false,
    primary_filer_total_deferrals_and_contributions: (f) => dollars(deferrals(f, filerIds(f).primary)),
    secondary_filer_total_deferrals_and_contributions: (f) => dollars(deferrals(f, filerIds(f).secondary)),
    primary_filer_savers_gross_distributions: (f) => dollars(distributions(f, filerIds(f).primary)),
    secondary_filer_savers_gross_distributions: (f) => dollars(distributions(f, filerIds(f).secondary)),
    total_tentative_tax: (f) => dollars(cents(f, '/totalTentativeTax')),
    cdcc_total_credit: (f) => dollars(cents(f, '/cdccTotalCredit')),
    total_edc: (f) => dollars(cents(f, '/totalEdc')),
    has_distributions_in_last_three_years: (f) => bool(f, '/hasDistributionsInLastThreeYears'),
    has_current_year_distributions: (f) => bool(f, '/hasCurrentYearDistributions'),
    has_self_reported_contributions: (f) => bool(f, '/hasSelfReportedContributions'),
  },
  outputs: [
    { oracle: '/qualifiedSaverCreditAmount', catala: 'qualified_saver_credit_amount', type: 'money' },
    { oracle: '/qualifiedForSaverCredit', catala: 'qualified_for_saver_credit', type: 'bool' },
    { oracle: '/combinedCreditLimit', catala: 'combined_credit_limit', type: 'money' },
    { oracle: '/ratioedCombinedCreditLimit', catala: 'ratioed_combined_credit_limit', type: 'money' },
    { oracle: '/limitationBasedOnTaxLiability', catala: 'limitation_based_on_tax_liability', type: 'money' },
    { oracle: '/primaryFilerTotalContributions', catala: 'primary_filer_total_contributions', type: 'money' },
    { oracle: '/secondaryFilerTotalContributions', catala: 'secondary_filer_total_contributions', type: 'money' },
    { oracle: '/primaryFilersDeferralsAndContributions', catala: 'primary_filers_deferrals_and_contributions', type: 'money' },
    { oracle: '/secondaryFilersDeferralsAndContributions', catala: 'secondary_filers_deferrals_and_contributions', type: 'money' },
    { oracle: '/primaryFilerIraAndAbleContributions', catala: 'primary_filer_ira_and_able_contributions', type: 'money' },
    { oracle: '/secondaryFilerIraAndAbleContributions', catala: 'secondary_filer_ira_and_able_contributions', type: 'money' },
    { oracle: '/primaryFilerGrossDistributions', catala: 'primary_filer_gross_distributions', type: 'money' },
    { oracle: '/secondaryFilerGrossDistributions', catala: 'secondary_filer_gross_distributions', type: 'money' },
  ],
};
