// Mapping for catala/form_w2s.catala_en (scope FormW2s), issue #12: W-2 wages, withholding, combat pay.
// Unanswered W-2 boxes are $0, as in Direct File (formW2s.xml Switch on IsComplete falling back to $0).
import { collectionIds, toCatalaJson, parseOracleValue } from '../lib.mjs';

// oracle (DF) W-2 field -> FormW2 struct field
const MONEY = {
  writableWages: 'writable_wages',
  writableFederalWithholding: 'writable_federal_withholding',
  writableOasdiWages: 'writable_oasdi_wages',
  writableOasdiWithholding: 'writable_oasdi_withholding',
  writableMedicareWages: 'writable_medicare_wages',
  writableMedicareWithholding: 'writable_medicare_withholding',
  writableAllocatedTips: 'writable_allocated_tips',
  writableDependentCareBenefits: 'writable_dependent_care_benefits',
  writableNonQualifiedPlans: 'writable_non_qualified_plans',
  writableCombatPay: 'writable_combat_pay',
  uncollectedOasdiTaxOnTips: 'uncollected_oasdi_tax_on_tips',
  uncollectedMedicareTaxOnTips: 'uncollected_medicare_tax_on_tips',
  taxableLifeInsuranceOver50k: 'taxable_life_insurance_over_50k',
  '401kDeferrals': 'deferrals_401k',
  '403bDeferrals': 'deferrals_403b',
  sarsepDeferrals: 'sarsep_deferrals',
  '457bDeferrals': 'deferrals_457b',
  '501c18Deferrals': 'deferrals_501c18',
  nontaxableSickPay: 'nontaxable_sick_pay',
  goldenParachuteExciseTax: 'golden_parachute_excise_tax',
  expenseReimbursements: 'expense_reimbursements',
  uncollectedOasdiTaxOnLifeInsuranceOver50k: 'uncollected_oasdi_tax_on_life_insurance_over_50k',
  uncollectedMedicareTaxOnLifeInsuranceOver50k: 'uncollected_medicare_tax_on_life_insurance_over_50k',
  armedForcesMovingExpenses: 'armed_forces_moving_expenses',
  archerMsaContributions: 'archer_msa_contributions',
  simpleContributions: 'simple_contributions',
  adoptionBenefits: 'adoption_benefits',
  nsoIncome: 'nso_income',
  employerHsaContributions: 'employer_hsa_contributions',
  '409aDeferrals': 'deferrals_409a',
  nqdcDeferrals: 'nqdc_deferrals',
  roth401kContributions: 'roth401k_contributions',
  roth403bContributions: 'roth403b_contributions',
  healthCoverageCost: 'health_coverage_cost',
  roth457bContributions: 'roth457b_contributions',
  qsehraBenefits: 'qsehra_benefits',
  '83iIncome': 'income_83i',
  '83iDeferrals': 'deferrals_83i',
  nonTaxableMedicaidWaiverPayments: 'non_taxable_medicaid_waiver_payments',
};
const BOOL = {
  '457bIsGovernmentalPlan': 'plan_457b_is_governmental',
  statutoryEmployee: 'statutory_employee',
  thirdPartySickPay: 'third_party_sick_pay',
};
const STATUS = {
  single: 'Single',
  marriedFilingJointly: 'MarriedFilingJointly',
  marriedFilingSeparately: 'MarriedFilingSeparately',
  headOfHousehold: 'HeadOfHousehold',
  qualifiedSurvivingSpouse: 'QualifyingSurvivingSpouse',
};
const ELECTION = {
  noCombatPay: 'NoCombatPay',
  usePrimaryCombatPay: 'UsePrimaryCombatPay',
  useSpouseCombatPay: 'UseSpouseCombatPay',
  useBothCombatPay: 'UseBothCombatPay',
  usePrimaryNotSpouseCombatPay: 'UsePrimaryNotSpouseCombatPay',
  useSpouseNotPrimaryCombatPay: 'UseSpouseNotPrimaryCombatPay',
};

const val = (facts, p) => {
  const r = facts.get(p);
  return r && r.completeness !== 'Incomplete' ? r.value : undefined;
};
const primaryId = (facts) =>
  collectionIds(facts, '/filers').find((id) => val(facts, `/filers/#${id}/isPrimaryFiler`) === 'true');
const secondaryId = (facts) => collectionIds(facts, '/filers').find((id) => id !== primaryId(facts));
const canBeClaimed = (id) => (facts) => (id(facts) !== undefined && val(facts, `/filers/#${id(facts)}/canBeClaimed`) === 'true');

export default {
  name: 'form_w2s',
  scope: 'FormW2s',
  file: 'catala/form_w2s.catala_en',
  appliesTo: () => true,

  inputs: {
    w2s: (facts) =>
      collectionIds(facts, '/formW2s').map((id) => {
        const w = { filer: val(facts, `/formW2s/#${id}/filer`) === primaryId(facts) ? 'PrimaryFiler' : 'SecondaryFiler' };
        for (const [df, c] of Object.entries(MONEY)) {
          const v = val(facts, `/formW2s/#${id}/${df}`);
          w[c] = toCatalaJson('money', parseOracleValue('money', v === undefined || v === '' ? '0' : v));
        }
        for (const [df, c] of Object.entries(BOOL)) w[c] = val(facts, `/formW2s/#${id}/${df}`) === 'true';
        return w;
      }),
    filing_status: (facts) => STATUS[val(facts, '/filingStatus')],
    primary_filer_can_be_claimed: canBeClaimed(primaryId),
    secondary_filer_can_be_claimed: canBeClaimed(secondaryId),
    combat_pay_election: (facts) => ELECTION[val(facts, '/combatPayElection') ?? 'noCombatPay'],
  },

  outputs: [
    { oracle: '/wages', catala: 'wages', type: 'money' },
    { oracle: '/formW2Withholding', catala: 'form_w2_withholding', type: 'money' },
    { oracle: '/socialSecurityTaxesWithheld', catala: 'social_security_taxes_withheld', type: 'money' },
    { oracle: '/allCombatPay', catala: 'all_combat_pay', type: 'money' },
    { oracle: '/combatPayAmount', catala: 'combat_pay_amount', type: 'money' },
  ],
};
