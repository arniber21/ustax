// Mapping for catala/tests/difftest_eitc.catala_en (scope EitcFromFilers): Filers.Filers feeding
// Eitc.EarnedIncomeCredit, issue #26. Run: make difftest SCOPE=eitc
//
// Inputs come from the oracle's writable facts and from these oracle values of facts that other
// modules compute (the orchestrator wires the real modules in later; see the PR):
//   /employerIncomeSubtotal (line 1z), /agi, /taxExemptInterest, /interestIncome: oracle values.
//   ordinary dividends and capital gains: $0 (DF out of scope, income.xml).
//   combat pay: per-W-2 `writableCombatPay`, rounded per W-2 (formW2s.xml /formW2s/*/combatPay),
//     summed per filer (/primaryFilerCombatPay, /MFJSpouseCombatPay is 0 unless MFJ, /allCombatPay).
//   /numEitcQualifyingChildren: oracle value (familyAndHousehold.xml, modules #16-#18). When the
//     oracle has it incomplete (8 scenarios) it is 0; DF's own /earnedIncomeCredit is then $0.
//   num_eitc_qualifying_children_for_calculation (/numEitcDependentsCollectionForCalculation, not in
//     the oracle): the EITC qualifying children that have an SSN valid for the calculation
//     (familyAndHousehold.xml /familyAndHousehold/*/ssnValidForEITCCalculation). The EITC qualifying
//     children themselves are not in the oracle per person; they are taken to be the household members
//     whose `qualifyingChild` is true in oracle/persons.csv, or, when that count differs from
//     /numEitcQualifyingChildren (the one scenario `single-10k-eitc-qcs-without-ssn`, whose child fails
//     the support test only), every household member.
//   filers_have_valid_ssns_for_eitc (filers.xml /filersHaveValidSSNsForEitc): ported below.
// The Filers inputs are those of difftest/mappings/filers.mjs.
import { readFileSync } from 'node:fs';
import { collectionIds, parseMoney } from '../lib.mjs';
import filersMap from './filers.mjs';

const val = (f, p) => {
  const r = f.get(p);
  return r && r.completeness !== 'Incomplete' ? r.value : undefined;
};
const bool = (f, p, d = false) => { const v = val(f, p); return v === undefined || v === '' ? d : v === 'true'; };
const cents = (f, p) => { const v = val(f, p); return v === undefined || v === '' ? 0n : parseMoney(v); };
const money = (c) => Number(c) / 100;
const upper = (s) => s.charAt(0).toUpperCase() + s.slice(1);
const roundDollar = (c) => ((c + (c >= 0n ? 50n : -50n)) / 100n) * 100n; // half away from zero
const FS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};

// ---- combat pay (formW2s.xml) ---------------------------------------------------------------
function combat(f) {
  const primaryIds = new Set(collectionIds(f, '/filers').filter((id) => bool(f, `/filers/#${id}/isPrimaryFiler`)));
  let primary = 0n, secondary = 0n;
  for (const id of collectionIds(f, '/formW2s')) {
    const c = roundDollar(cents(f, `/formW2s/#${id}/writableCombatPay`));
    if (primaryIds.has(val(f, `/formW2s/#${id}/filer`))) primary += c; else secondary += c;
  }
  const mfj = val(f, '/filingStatus') === 'marriedFilingJointly';
  return { primary, spouse: mfj ? secondary : 0n, all: roundDollar(primary + secondary) };
}

// ---- children -------------------------------------------------------------------------------
let personsByUuid;
/** Per-person facts of the household of `f`, from oracle/persons.csv (pseudo-scenario `<scenario>~<uuid>`). */
function persons(f) {
  if (!personsByUuid) {
    personsByUuid = new Map();
    const rows = readFileSync(new URL('../../oracle/persons.csv', import.meta.url), 'utf8').split('\n');
    for (const line of rows.slice(1)) {
      const m = /^[^,~]+~([^,]+),\/familyAndHousehold\/\*\/([A-Za-z0-9]+),("(?:[^"]|"")*"|[^,]*),/.exec(line);
      if (!m) continue;
      if (!personsByUuid.has(m[1])) personsByUuid.set(m[1], {});
      personsByUuid.get(m[1])[m[2]] = m[3];
    }
  }
  return collectionIds(f, '/familyAndHousehold').map((id) => personsByUuid.get(id) ?? {});
}
// familyAndHousehold.xml /familyAndHousehold/*/ssnValidForEITCCalculation (lines 3810-3860)
const personSsnValid = (p) =>
  p.tinType === 'ssn' && (['neither', 'validOnlyWithDhsAuthorizationInEffect', '', undefined].includes(p.ssnEmploymentValidity)
    || (p.ssnEmploymentValidity === 'notValid' && p.ssnOnlyForFederallyFundedBenefit !== 'true'));
const numQc = (f) => (val(f, '/numEitcQualifyingChildren') === undefined ? 0 : parseInt(val(f, '/numEitcQualifyingChildren'), 10));
function numQcForCalculation(f) {
  const n = numQc(f);
  if (n === 0) return 0;
  let cand = persons(f).filter((p) => p.qualifyingChild === 'true');
  if (cand.length !== n) cand = persons(f);
  return Math.min(n, cand.filter(personSsnValid).length);
}

// ---- filers' SSNs (filers.xml /filers/*/ssnValidForEitc, /filersHaveValidSSNsForEitc) --------
const tinIsSsn = (tin) => !!tin && !(tin.startsWith('9') || tin.endsWith('0000'));
function filerSsnValid(f, id, validityPath) {
  const tin = val(f, `/filers/#${id}/tin`);
  if (!tinIsSsn(tin)) return false;
  const citizen = bool(f, `/filers/#${id}/isUsCitizenFullYear`);
  const needsWorkStatus = !citizen; // not a citizen and tin is an SSN
  if (!needsWorkStatus) return true;
  const v = val(f, validityPath);
  return v === 'validOnlyWithDhsAuthorization' || v === 'neither'
    || (v === 'notValid' && !bool(f, `/filers/#${id}/writableHasSSNOnlyForBenefits`));
}
function filersValidSsns(f) {
  const ids = collectionIds(f, '/filers');
  const primary = ids.find((id) => bool(f, `/filers/#${id}/isPrimaryFiler`));
  const secondary = ids.find((id) => id !== primary);
  const p = filerSsnValid(f, primary, '/primaryFilerSsnEmploymentValidity');
  if (val(f, '/filingStatus') !== 'marriedFilingJointly') return p;
  return p && filerSsnValid(f, secondary, '/secondaryFilerSsnEmploymentValidity');
}

const NOTICE = { twoYears: 'TwoYears', tenYears: 'TenYears', zeroYears: 'ZeroYears' };
const filerInputs = [
  'filing_status', 'marital_status', 'year_of_spouse_death', 'primary_filer', 'secondary_filer',
  'secondary_filer_date_of_death', 'primary_filer_potential_claimer_filed_only_for_refund', 'mfj_required_to_file',
  'mfj_dependents_filing_for_credits', 'lived_together_all_year_with_spouse', 'spouse_lived_together_months',
  'writable_lived_apart_last_six_months', 'writable_separation_agreement', 'can_file_jointly_year_of_spouse_death',
  'in_registered_domestic_partnership', 'filer_residence_and_income_state', 'spouse_itemizes',
  'mfs_living_spouse_filing_return', 'mfs_deceased_spouse_filing_return', 'mfs_spouse_has_gross_income', 'eligible_for_hoh',
];

export default {
  name: 'eitc',
  scope: 'EitcFromFilers',
  file: 'catala/tests/difftest_eitc.catala_en',
  appliesTo: () => true,
  inputs: {
    ...Object.fromEntries(filerInputs.map((k) => [k, filersMap.inputs[k]])),
    employer_income_subtotal: (f) => money(cents(f, '/employerIncomeSubtotal')),
    agi: (f) => money(cents(f, '/agi')),
    tax_exempt_interest: (f) => money(cents(f, '/taxExemptInterest')),
    interest_income: (f) => money(cents(f, '/interestIncome')),
    ordinary_dividends: () => 0,
    capital_gains_or_losses: () => 0,
    primary_filer_combat_pay: (f) => money(combat(f).primary),
    mfj_spouse_combat_pay: (f) => money(combat(f).spouse),
    all_combat_pay: (f) => money(combat(f).all),
    combat_pay_election_made: (f) => val(f, '/combatPayElection') !== undefined && val(f, '/combatPayElection') !== '',
    combat_pay_election: (f) => upper(val(f, '/combatPayElection') || 'noCombatPay'),
    num_eitc_qualifying_children: numQc,
    num_eitc_qualifying_children_for_calculation: numQcForCalculation,
    filers_have_valid_ssns_for_eitc: filersValidSsns,
    eitc_qc_of_another: (f) => bool(f, '/eitcQcOfAnother'),
    eitc_qc_of_another_required_to_file: (f) => bool(f, '/eitcQcOfAnotherRequiredToFile'),
    eitc_qc_of_another_is_filing: (f) => bool(f, '/eitcQcOfAnotherIsFiling'),
    eitc_qc_of_another_is_filing_refund_only: (f) => bool(f, '/eitcQcOfAnotherIsFilingRefundOnly'),
    eitc_had_improper_claims: (f) => bool(f, '/eitcHadImproperClaims'),
    eitc_improper_claims_due_to_qc: (f) => bool(f, '/eitcImproperClaimsDueToQc'),
    eitc_improper_claim_taken_since_disallowal: (f) => bool(f, '/eitcImproperClaimTakenSinceDisallowal'),
    eitc_received_improper_claims_notice: (f) => NOTICE[val(f, '/eitcReceivedImproperClaimsNotice')] ?? 'NotAnswered',
    eitc_improper_claims_notice_expired: (f) => bool(f, '/eitcImproperClaimsNoticeExpired'),
  },
  outputs: [
    { oracle: '/earnedIncomeCredit', catala: 'earned_income_credit', type: 'money' },
    { oracle: '/isReceivingEitc', catala: 'is_receiving_eitc', type: 'bool' },
    { oracle: '/eitc8862Required', catala: 'eitc8862_required', type: 'bool' },
    { oracle: '/failsEitcQcTest', catala: 'fails_eitc_qc_test', type: 'bool' },
    { oracle: '/receivingEitcWhileSeparatedCheckbox', catala: 'receiving_eitc_while_separated_checkbox', type: 'bool' },
  ],
  knownDivergence: [],
};
