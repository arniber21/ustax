// Mapping for catala/cdcc.catala_en (scope Form2441), issue #28. Run: make difftest SCOPE=cdcc
//
// Inputs come from oracle/facts.csv (filers, W-2s, the cdcc writable facts, AGI and the tax before
// credits) and oracle/persons.csv (the household members, as in ctc_odc_household.mjs).
// Defaults for unanswered DF facts: every optional amount is $0, every optional yes/no is false.
// When DF's /writableCdccHasQualifyingExpenses is not true, no person has expenses (DF does not
// ask the per-person expense questions then).
// Scenario-level filer facts (/treatAsMFJ and so on) are DF's own values from persons.csv; for a
// scenario without household members they are derived from the filing status.
import { collectionIds, loadOracle } from '../lib.mjs';
import { person } from './qualifying_child.mjs';
import { answers } from './qualifying_relative.mjs';
import { splitAnswers } from './dependents_benefit_split.mjs';

const P = '/familyAndHousehold/*/';
const STATUS = {
  single: 'Single', marriedFilingJointly: 'MarriedFilingJointly', marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold', qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};
const val = (f, p) => f.get(p)?.value;
const bool = (f, p) => val(f, p) === 'true';
const money = (f, p) => {
  const r = f.get(p);
  return r && r.completeness !== 'Incomplete' && r.value !== '' ? Number(r.value) : 0;
};
const round = (x) => Math.sign(x) * Math.round(Math.abs(x));

let scenarios;
let persons;
function scenarioName(f) {
  if (!scenarios) scenarios = loadOracle(new URL('../../oracle/facts.csv', import.meta.url).pathname);
  for (const [name, g] of scenarios) {
    if (g.size !== f.size) continue;
    let same = true;
    for (const [p, r] of f) {
      const q = g.get(p);
      if (!q || q.value !== r.value || q.completeness !== r.completeness) { same = false; break; }
    }
    if (same) return name;
  }
  throw new Error('scenario not found in oracle/facts.csv');
}
function members(f) {
  const ids = collectionIds(f, '/familyAndHousehold');
  if (ids.length === 0) return [];
  if (!persons) persons = loadOracle(new URL('../../oracle/persons.csv', import.meta.url).pathname);
  const s = scenarioName(f);
  return ids.map((id) => {
    const p = persons.get(`${s}~${id}`);
    if (!p) throw new Error(`no per-person oracle for ${s}~${id}`);
    return p;
  });
}
const filerFact = (path, dflt) => (f) => {
  const ms = members(f);
  if (ms.length === 0) return dflt(f);
  const r = ms[0].get(path);
  if (!r || r.completeness !== 'Complete') throw new Error(`oracle fact ${path} not Complete`);
  return typeof dflt(f) === 'boolean' ? r.value === 'true' : r.value;
};
const isMfj = (f) => val(f, '/filingStatus') === 'marriedFilingJointly';
const hasExpenses = (f) => bool(f, '/writableCdccHasQualifyingExpenses');

function cdccMember(f) {
  return (pf) => ({
    member: { person: person(pf), answers: answers(pf), split: splitAnswers(pf) },
    cdcc: {
      unable_to_care_for_self: bool(pf, P + 'unableToCareForSelf'),
      has_dependent_care_expenses: hasExpenses(f) && bool(pf, P + 'cdccHasDependentCareExpenses'),
      expenses_paid_to_qualifying_provider: bool(pf, P + 'cdccHadExpensesPaidToQualifyingProvider'),
      writable_qualifying_expense_amount: money(pf, P + 'writableCdccQualifyingExpenseAmount'),
      tp_paid_most_of_home_upkeep: bool(pf, P + 'tpPaidMostOfHomeUpkeep'),
    },
  });
}

// Filer role of a filers item and of a W-2.
function filerIds(f) {
  const ids = collectionIds(f, '/filers');
  const primary = ids.find((id) => bool(f, `/filers/#${id}/isPrimaryFiler`));
  return { primary, secondary: ids.find((id) => id !== primary) };
}
const election = (f, p) => val(f, p) ?? '';
function filer(f, which) {
  const { primary, secondary } = filerIds(f);
  const id = which === 'primary' ? primary : secondary;
  const empty = {
    employer_income_subtotal_base: 0, nontaxable_combat_pay: 0, elect_combat_pay_for_credit: false,
    elect_combat_pay_for_benefits: false, dependent_care_benefits: 0, dependent_care_plan_maximum: 0,
    is_disabled: false, deemed_income_month_earnings: [], has_dependent_care_expenses: false,
    expenses_paid_to_qualifying_provider: false, writable_qualifying_expense_amount: 0,
  };
  if (!id) return empty;
  const w2s = collectionIds(f, '/formW2s').filter((w) => val(f, `/formW2s/#${w}/filer`) === id);
  const sum = (field, g = (x) => x) => w2s.reduce((a, w) => a + g(money(f, `/formW2s/#${w}/${field}`)), 0);
  const el = (p) => election(f, p);
  const own = which === 'primary'
    ? ['usePrimaryCombatPay', 'useBothCombatPay', 'usePrimaryNotSpouseCombatPay']
    : ['useSpouseCombatPay', 'useBothCombatPay', 'useSpouseNotPrimaryCombatPay'];
  const plan = which === 'primary' ? '/writablePrimaryFilerDependentCarePlanMaximum'
    : '/writableSecondaryFilerDependentCarePlanMaximum';
  const it = `/filers/#${id}/`;
  return {
    employer_income_subtotal_base: sum('writableWages', round),
    nontaxable_combat_pay: sum('writableCombatPay', round),
    elect_combat_pay_for_credit: own.includes(el('/cdccCombatPayElection')),
    elect_combat_pay_for_benefits: own.includes(el('/cdccCombatPayElectionForBenefits')),
    dependent_care_benefits: sum('writableDependentCareBenefits'),
    dependent_care_plan_maximum: money(f, plan),
    is_disabled: bool(f, it + 'isDisabled'),
    deemed_income_month_earnings: [],
    has_dependent_care_expenses: hasExpenses(f) && bool(f, it + 'cdccHasDependentCareExpenses'),
    expenses_paid_to_qualifying_provider: bool(f, it + 'cdccHadExpensesPaidToQualifyingProvider'),
    writable_qualifying_expense_amount: money(f, it + 'writableCdccQualifyingExpenseAmount'),
  };
}

const m = (o, c) => ({ oracle: `/${o}`, catala: c, type: 'money' });
const b = (o, c) => ({ oracle: `/${o}`, catala: c, type: 'bool' });
const FOSTER = { scenario: 'hoh-cdcc-multiple-careproviders', bug: 'DF-BUG(28-a)',
  note: 'the foster child of the non-parent Form 8332 split ($500 of expenses) is a qualifying person in DF; ' +
    'IRC 21(e)(5) gives the child to the custodial parent only' };

export default {
  name: 'cdcc',
  scope: 'Form2441',
  file: 'catala/cdcc.catala_en',
  appliesTo: () => true,
  inputs: {
    filing_status: (f) => STATUS[val(f, '/filingStatus')],
    household: (f) => members(f).map(cdccMember(f)),
    minimum_filer_date_of_birth: filerFact('/minimumFilerDateOfBirth', () => '1980-01-01'),
    treat_filers_as_dependents: filerFact('/treatFilersAsDependents', () => false),
    either_filer_us_citizen_or_national: filerFact('/eitherFilerUSCitizenOrNational', () => true),
    treat_as_mfj: filerFact('/treatAsMFJ', isMfj),
    lived_apart_last_six_months: filerFact('/mfsFilerCouldBeConsiderUnmarriedForCdcc', () => false),
    spouse_same_abode_more_than_half_year: (f) => bool(f, '/livedTogetherAllYearWithSpouse')
      || val(f, '/spouseLivedTogetherMonths') === 'livedTogetherMoreThanSixMonths',
    primary_filer: (f) => filer(f, 'primary'),
    secondary_filer: (f) => (isMfj(f) ? filer(f, 'secondary') : filer(f, 'none')),
    has_mfs_spouse_earned_income: (f) => bool(f, '/hasMfjSpouseEarnedIncome'),
    writable_mfs_spouse_earned_income: (f) => money(f, '/writableMfsSpouseEarnedIncome'),
    writable_total_qualified_dependent_care_expenses: (f) => money(f, '/writableCdccTotalQualifiedDependentCareExpenses'),
    writable_carryover_amount: (f) => (bool(f, '/hasCdccCarryoverAmountFromPriorTaxYear')
      ? money(f, '/writableCdccCarryoverAmountFromPriorTaxYear') : 0),
    // DF-BUG(28-e): the statute counts the amount whatever box 10 says.
    writable_forfeited_amount: (f) => (bool(f, '/writableHasCdccForfeitedCredits')
      ? money(f, '/writableCdccForfeitedCredits') : 0),
    has_credit_for_prior_year_expenses: (f) => bool(f, '/cdccHasCreditForPriorYearExpenses'),
    claimed_credit_for_prior_year_expenses: (f) => bool(f, '/cdccClaimedCreditForPriorYearExpenses'),
    claimed_max_credit_for_prior_tax_year: (f) => bool(f, '/cdccClaimedMaxCreditForPriorTaxYear'),
    has_household_employee: (f) => bool(f, '/flowKnockoutHouseholdEmployee'),
    benefits_from_sole_proprietorship_or_partnership: () => false,
    agi: (f) => money(f, '/agi'),
    total_tentative_tax: (f) => money(f, '/totalTentativeTax'),
  },
  outputs: [
    m('cdccTotalCredit', 'cdcc_total_credit'),
    m('cdccTaxableBenefits', 'taxable_benefits'),
    m('cdccQualifyingExpenses', 'line3'),
    m('cdccLowerOfEarnedIncomeAndExpenses', 'line6'),
    m('cdccTentativeExpenseAmount', 'line9a'),
    m('cdccTotalEligibleCDCCAmount', 'line9c'),
    m('cdccCreditLimit', 'line10_tax_liability_limit'),
    m('xmlCdccCareExpensesDecimalAmount', 'line8_decimal_amount'),
    m('cdccEarnedIncomePrimaryFilerLine4', 'line4_earned_income'),
    m('cdccEarnedIncomeLine5', 'line5_earned_income'),
    m('cdccDependentCareBenefitsAmount', 'line12_dependent_care_benefits'),
    m('cdccCarryoverAmountFromPriorTaxYear', 'line13_carryover'),
    m('cdccForfeitedCredits', 'line14_forfeited'),
    m('cdccAdjustedDependentCareBenefitsAmount', 'line15_adjusted_benefits'),
    m('cdccLesserOfAdjustBenefitsAndQualifiedExpenses', 'line17_lesser'),
    m('cdccTentativeExclusionAmount', 'line20_tentative_exclusion'),
    m('cdccSpecifiedExclusionAmount', 'line21_specified_exclusion'),
    m('cdccDeductibleBenefitsAmount', 'line24_deductible_benefits'),
    m('cdccExcludedBenefitsAmount', 'line25_excluded_benefits'),
    m('cdccSumOfDeductibleAndExcludedBenefitsAmount', 'line28'),
    m('cdccNetAllowableAmount', 'line29_net_allowable'),
    m('cdccSmallerOfTotalQualifyingExpensesAmount', 'line31'),
    b('cdccHasQualifyingPersons', 'has_qualifying_persons'),
    b('cdccHasMoreThanThreeQualifyingPersons', 'has_more_than_three_qualifying_persons'),
    b('mfsButEligibleForCdcc', 'mfs_but_eligible_for_cdcc'),
  ],
  knownDivergence: [
    ...['/cdccQualifyingExpenses', '/cdccLowerOfEarnedIncomeAndExpenses', '/cdccTentativeExpenseAmount',
      '/cdccTotalEligibleCDCCAmount', '/cdccTotalCredit', '/cdccSmallerOfTotalQualifyingExpensesAmount']
      .map((path) => ({ ...FOSTER, path })),
    // DF gives a $0.00 decimal amount at AGI <= 0; IRC 21(a)(2) gives 35 percent. No credit changes
    // (these returns have no qualifying expenses).
    ...['edc-ats-1', 'edc-disqualified-disability-income', 'ptc-no-aptc-negative-magi'].map((scenario) => ({
      scenario, path: '/xmlCdccCareExpensesDecimalAmount', bug: 'DF-BUG(28-b)',
      note: 'AGI is zero or less: DF decimal amount 0.00, statute 35 percent',
    })),
  ],
};
