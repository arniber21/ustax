import { describe, expect, it } from 'vitest';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { contractProblems, type CalculateRequest } from '../api';
import {
  buildRequest,
  canBuildRequest,
  DraftIncompleteError,
  draftFromRequest,
  emptyDraft,
  emptyFlags,
  newDependent,
  isIsoDate,
  isDraftValid,
  loadDraft,
  newInterest,
  newRetirement,
  newSsa,
  newUnemployment,
  newW2,
  STORAGE_KEY,
  tryBuildRequest,
  validateStep,
  type Draft,
} from '.';

const EXAMPLES_DIR = join(__dirname, '../../../api/examples');
const examples = readdirSync(EXAMPLES_DIR)
  .filter((f) => f.endsWith('.request.json'))
  .map((f) => [f, JSON.parse(readFileSync(join(EXAMPLES_DIR, f), 'utf8')) as CalculateRequest] as const);

const single = (patch: Partial<Draft> = {}): Draft => ({ ...emptyDraft(), filingStatus: 'Single', ...patch });

describe('buildRequest', () => {
  it('refuses to build without a filing status', () => {
    expect(canBuildRequest(emptyDraft())).toBe(false);
    expect(() => buildRequest(emptyDraft())).toThrow(DraftIncompleteError);
    expect(tryBuildRequest(emptyDraft())).toBeNull();
  });

  it('smallest draft is just the required keys', () => {
    expect(buildRequest(single())).toEqual({ api_version: 1, tax_year: 2024, filing_status: 'Single' });
  });

  it('is pure: same draft, same request, draft untouched', () => {
    const d = single({ w2s: [{ ...newW2(), wages: 5000000 }] });
    const before = JSON.stringify(d);
    expect(buildRequest(d)).toEqual(buildRequest(d));
    expect(JSON.stringify(d)).toBe(before);
  });

  it.each(examples)('round trips api/examples/%s', (_name, req) => {
    const draft = draftFromRequest(req);
    expect(buildRequest(draft)).toEqual(req);
    expect(contractProblems('CalculateRequest', buildRequest(draft))).toEqual([]);
  });

  it('keeps money as integer cents and leaves blank boxes out', () => {
    const r = buildRequest(single({ w2s: [{ ...newW2(), wages: 5000050, withholding: 0 }] }));
    expect(r.w2s).toEqual([{ filer: 'PrimaryFiler', wages: 5000050, federal_withholding: 0 }]);
  });

  it('turns box 12 rows into the keyed object and adds up repeated codes', () => {
    const w = newW2();
    w.wages = 1;
    w.box12 = [
      { id: 'a', code: 'D', amount: 100 },
      { id: 'b', code: 'D', amount: 50 },
      { id: 'c', code: 'W', amount: 25 },
      { id: 'd', code: '', amount: 9 },
    ];
    expect(buildRequest(single({ w2s: [w] })).w2s?.[0]?.box12).toEqual({ D: 150, W: 25 });
  });

  it('only joint returns carry a spouse', () => {
    const w = { ...newW2('SecondaryFiler'), wages: 100 };
    const spouse = { ...emptyFlags(), blind: true };
    const sep = buildRequest(single({ w2s: [w], spouse }));
    expect(sep.w2s?.[0]?.filer).toBe('PrimaryFiler');
    expect(sep.filers).toBeUndefined();
    const joint = buildRequest({ ...single({ w2s: [w], spouse }), filingStatus: 'MarriedFilingJointly' });
    expect(joint.w2s?.[0]?.filer).toBe('SecondaryFiler');
    expect(joint.filers).toEqual({ secondary: { is_blind: true } });
  });

  it('maps flags and filing details', () => {
    const r = buildRequest(
      single({ primary: { ...emptyFlags(), blind: true, age65: true }, foreignAccounts: true }),
    );
    expect(r.filers).toEqual({ primary: { is_blind: true, age65_or_older: true } });
    expect(r.filing_details).toEqual({ has_foreign_accounts_or_trusts: true });
    const mfs = buildRequest({ ...single({ mfsSpouse65: true }), filingStatus: 'MarriedFilingSeparately' });
    expect(mfs.filing_details).toEqual({ mfs_spouse_65_or_older: true });
  });

  it('maps the other income documents', () => {
    const r = buildRequest(
      single({
        interest: [{ ...newInterest(), interest: 100000, withheld: 10000 }],
        unemployment: [{ ...newUnemployment(), amount: 200000 }],
        retirement: [{ ...newRetirement(), codes: ['7'], gross: 1000, taxable: 900, iraSepSimple: true }],
        ssa: [{ ...newSsa(), netBenefits: -500 }],
      }),
    );
    expect(r.interest_reports).toEqual([
      { filer: 'PrimaryFiler', has_1099: true, interest_income: 100000, federal_tax_withheld: 10000 },
    ]);
    expect(r.form_1099g).toEqual([{ filer: 'PrimaryFiler', unemployment_compensation: 200000 }]);
    expect(r.form_1099r).toEqual([
      { filer: 'PrimaryFiler', distribution_code: ['7'], gross_distribution: 1000, taxable_amount: 900, ira_sep_simple: true },
    ]);
    expect(r.social_security).toEqual({ net_benefits: [-500] });
    expect(contractProblems('CalculateRequest', r)).toEqual([]);
  });

  it('blank taxable box on a 1099-R sends zero plus the blank flag', () => {
    const r = buildRequest(single({ retirement: [{ ...newRetirement(), codes: ['G'], gross: 5, taxableBlank: true }] }));
    expect(r.form_1099r?.[0]).toMatchObject({ taxable_amount: 0, taxable_amount_blank: true });
  });

  it('maps adjustments and estimated payments', () => {
    const d = single({
      educator: { primary: true, spouse: true, primaryExpenses: 30000, spouseExpenses: 99 },
      studentLoan: { hadPayments: true, loansQualify: true, interest: 120000 },
      estimated: { paid: true, amount: 400000, differentName: false },
    });
    const r = buildRequest(d);
    // Not joint: the spouse's educator answer is ignored.
    expect(r.adjustments?.educator_expenses).toEqual({ was_k12_educators: 'TpDid', primary_expenses: 30000 });
    expect(r.adjustments?.student_loan_interest).toEqual({ had_payments: true, loans_qualify: true, interest_amount: 120000 });
    expect(r.estimated_payments).toEqual({ paid_estimated_taxes_or_from_last_year: true, amount: 400000 });
    const joint = buildRequest({ ...d, filingStatus: 'MarriedFilingJointly' });
    expect(joint.adjustments?.educator_expenses).toEqual({
      was_k12_educators: 'BothDid', primary_expenses: 30000, secondary_expenses: 99,
    });
    expect(contractProblems('CalculateRequest', joint)).toEqual([]);
  });

  it('a fully loaded draft validates against api/schema.json', () => {
    const w = { ...newW2(), wages: 9, withholding: 1, ssWages: 9, ssTax: 1, medicareWages: 9, medicareTax: 1,
      allocatedTips: 1, dependentCare: 1, nonQualified: 1, statutoryEmployee: true, thirdPartySickPay: true,
      plan457bGovernmental: true, box12: [{ id: 'x', code: 'AA', amount: 5 }] };
    const r = buildRequest({
      ...single({
        w2s: [w],
        interest: [{ ...newInterest(), interest: 1, earlyWithdrawalPenalty: 1, governmentBondInterest: 1, foreignTax: 1, taxExempt: 1 }],
        ssa: [{ ...newSsa(), netBenefits: 1 }],
        livedApartAllYear: true,
        spouseDiedThisYear: true,
      }),
      filingStatus: 'MarriedFilingSeparately',
    });
    expect(contractProblems('CalculateRequest', r)).toEqual([]);
  });
});

describe('dependents and credits (contract 1.2.0)', () => {
  const byName = (n: string) => examples.find(([f]) => f.startsWith(n))![1];

  it('the family example is a joint return with two children and nothing else', () => {
    const req = byName('family-mfj-two-kids');
    const d = draftFromRequest(req);
    expect(d.hasDependents).toBe(true);
    expect(d.dependents.map((p) => p.dob)).toEqual(['2016-03-01', '2019-05-01']);
    expect(d.spouse.dob).toBe('1987-09-30');
    expect(d.maritalStatus).toBe('Married');
    expect(buildRequest(d)).toEqual(req);
    expect(isDraftValid(d)).toBe(true);
  });

  it('the EITC example keeps the home upkeep answer on the child', () => {
    const req = byName('eitc-hoh-one-child');
    const d = draftFromRequest(req);
    expect(d.paidHomeUpkeep).toBe(true);
    expect(buildRequest(d)).toEqual(req);
    expect(buildRequest({ ...d, paidHomeUpkeep: false }).dependents?.[0]).not.toHaveProperty('tp_paid_most_of_home_upkeep');
  });

  it('sends nothing for dependents until the gate is on, and never sends names', () => {
    const p = { ...newDependent(), name: 'Sam', relationship: 'BiologicalChild' as const, dob: '2018-01-02' };
    const off = buildRequest(single({ dependents: [p], hasDependents: false }));
    expect(off.dependents).toBeUndefined();
    const on = buildRequest(single({ dependents: [p], hasDependents: true }));
    expect(on.dependents).toEqual([{ relationship: 'BiologicalChild', date_of_birth: '2018-01-02', tin_type: 'Ssn' }]);
    expect(JSON.stringify(on)).not.toContain('Sam');
  });

  it('maps every per-person answer and validates against the schema', () => {
    const p = {
      ...newDependent(), relationship: 'ChildOfSibling' as const, dob: '2010-05-05', residency: 'SixToElevenMonths' as const, months: 8,
      tinType: 'Itin' as const, citizenship: 'resident' as const, student: true, disabled: true, ownSupport: true, youSupport: true,
      claimableByOther: true, married: true, jointReturn: true, grossIncome: 123400, claim: false,
      unableToSelfCare: true, careExpenses: 250000, careProviderQualifies: true,
    };
    const r = buildRequest(single({ hasDependents: true, dependents: [p], cdcc: { paid: true, totalQualified: 300000 } }));
    expect(r.dependents?.[0]).toEqual({
      relationship: 'ChildOfSibling', date_of_birth: '2010-05-05', tin_type: 'Itin', full_time_student: true,
      permanent_total_disability: true, residency_duration: 'SixToElevenMonths', months_lived_with_tp_in_us: 8,
      own_support: true, married: true, joint_return: true, could_be_qualifying_child_of_another: true, gross_income: 123400,
      qr_support_test: true, is_us_citizen_full_year: false, us_resident: true, tp_claims: false,
      cdcc: { unable_to_care_for_self: true, has_dependent_care_expenses: true, expenses_paid_to_qualifying_provider: true, writable_qualifying_expense_amount: 250000 },
    });
    expect(r.cdcc).toEqual({ writable_total_qualified_dependent_care_expenses: 300000 });
    expect(contractProblems('CalculateRequest', r)).toEqual([]);
    expect(buildRequest(draftFromRequest(r))).toEqual(r);
  });

  it('sends a date of birth instead of the 65 flag, and per-filer details only when they differ from the default', () => {
    const d = single({ primary: { ...emptyFlags(), dob: '1950-01-01', age65: true, citizenship: 'resident', hasSsn: false, student: true, retiredOnDisability: true } });
    expect(buildRequest(d).filers).toEqual({
      primary: {
        date_of_birth: '1950-01-01', noncitizen_resident_full_year: true, is_us_citizen_full_year: false, is_student: true,
        tin: { tin_is_ssn: false }, disability: { is_retired_on_perm_or_total_disability: true },
      },
    });
    expect(contractProblems('CalculateRequest', buildRequest(d))).toEqual([]);
  });

  it('maps filing answers, credits, screening and HSA, and the whole request validates', () => {
    const hsa = { ...emptyFlags().hsa, contributed: true, coverage: 'HdhpAllYear' as const, type: 'SelfOnly' as const, medicare: 'MedicareNoneOfYear' as const, directContributions: 100000 };
    const r = buildRequest(
      single({
        filingStatus: 'MarriedFilingSeparately', maritalStatus: 'Married', spouseLivedTogether: 'LivedApartAllYear',
        credits: { eitcImproperClaims: true, ctcImproperClaims: true, eitcQcOfAnother: false },
        screening: { digitalReceived: true, digitalDisposed: false, iraContributions: true, foreignTrustGrantor: false },
        hsa: { has: true }, primary: { ...emptyFlags(), hsa },
      }),
    );
    expect(r.filing_answers).toEqual({ marital_status: 'Married', spouse_lived_together_months: 'LivedApartAllYear' });
    expect(r.credits).toEqual({ eitc_had_improper_claims: true, received_improper_claims: true });
    expect(r.screening).toEqual({ received_digital_assets: true, made_ira_contributions: true });
    expect(r.adjustments?.hsa).toEqual({ some_filer_had_non_w2_hsa_activity: true, writable_primary_filer_had_non_w2_hsa_activity: true });
    expect(r.filers?.primary?.hsa).toEqual({
      writable_primary_filer_has_made_contributions_to_hsa: true, hsa_hdhp_coverage_status: 'HdhpAllYear', type_of_hdhp: 'SelfOnly',
      enrolled_in_medicare: 'MedicareNoneOfYear', writable_hsa_nonemployer_contributions_tax_year: 100000,
    });
    expect(contractProblems('CalculateRequest', r)).toEqual([]);
  });

  it('only sends the lived-together answer to married people filing separately', () => {
    expect(buildRequest(single({ spouseLivedTogether: 'LivedApartAllYear' })).filing_answers).toBeUndefined();
  });

  it('validates dates and the dependents step', () => {
    expect(isIsoDate('2024-02-29')).toBe(true);
    expect(isIsoDate('2023-02-29')).toBe(false);
    expect(isIsoDate('24-1-1')).toBe(false);
    expect(validateStep(single({ primary: { ...emptyFlags(), dob: '2025-01-01' } }), 'about')).toHaveProperty(['primary.dob']);
    expect(validateStep(single({ primary: { ...emptyFlags(), dob: '1985-13-40' } }), 'about')).toHaveProperty(['primary.dob']);
    expect(validateStep(single({ hasDependents: true }), 'dependents')).toHaveProperty('dependents');
    const p = newDependent();
    const e = validateStep(single({ hasDependents: true, dependents: [{ ...p, residency: 'SixToElevenMonths' }] }), 'dependents');
    expect(Object.keys(e).sort()).toEqual([`dep.${p.id}.dob`, `dep.${p.id}.months`, `dep.${p.id}.relationship`]);
    const twentyOne = Array.from({ length: 21 }, () => ({ ...newDependent(), relationship: 'Parent' as const, dob: '1950-01-01' }));
    expect(validateStep(single({ hasDependents: true, dependents: twentyOne }), 'dependents').dependents).toMatch(/up to 20/);
    // Answering No skips the whole list.
    expect(validateStep(single({ hasDependents: false, dependents: [p] }), 'dependents')).toEqual({});
  });

  it('asks who provided the care once there is an amount', () => {
    const p = { ...newDependent(), relationship: 'BiologicalChild' as const, dob: '2018-01-01', careExpenses: 100 };
    const e = validateStep(single({ hasDependents: true, dependents: [p], cdcc: { paid: true, totalQualified: null } }), 'credits');
    expect(Object.keys(e)).toEqual([`dep.${p.id}.careProviderQualifies`]);
  });

  it('fills the new nested defaults when an older saved draft is loaded', () => {
    const old = { version: 1, filingStatus: 'Single', primary: { blind: true, age65: false, canBeClaimed: false } };
    const d = loadDraft({ getItem: () => JSON.stringify(old) });
    expect(d.primary).toEqual({ ...emptyFlags(), blind: true });
    expect(d.dependents).toEqual([]);
  });
});

describe('validateStep', () => {
  it('needs a filing status on the first step', () => {
    expect(validateStep(emptyDraft(), 'about')).toHaveProperty('filingStatus');
    expect(validateStep(single(), 'about')).toEqual({});
  });

  it('asks for the required W-2 box and complete box 12 rows', () => {
    const w = newW2();
    w.box12 = [{ id: 'r', code: '', amount: null }];
    const e = validateStep(single({ w2s: [w] }), 'income');
    expect(e[`w2.${w.id}.wages`]).toBeDefined();
    expect(e[`w2.${w.id}.box12.r.code`]).toBeDefined();
    expect(e[`w2.${w.id}.box12.r.amount`]).toBeDefined();
  });

  it('enforces the money cap and list caps from the schema', () => {
    const w = { ...newW2(), wages: 10_000_000_000_001 };
    expect(validateStep(single({ w2s: [w] }), 'income')[`w2.${w.id}.wages`]).toMatch(/too big/);
    const many = Array.from({ length: 21 }, () => ({ ...newW2(), wages: 1 }));
    expect(validateStep(single({ w2s: many }), 'income').w2s).toBeDefined();
    const ssa = Array.from({ length: 5 }, () => ({ ...newSsa(), netBenefits: 1 }));
    expect(validateStep(single({ ssa }), 'income').ssa).toBeDefined();
  });

  it('checks 1099-R codes (1 to 4) and SSA may be negative', () => {
    const r = { ...newRetirement(), gross: 1, taxable: 1 };
    expect(validateStep(single({ retirement: [r] }), 'income')[`retirement.${r.id}.codes`]).toBeDefined();
    const five = { ...r, codes: ['7', '7', '7', '7', '7'] };
    expect(validateStep(single({ retirement: [five] }), 'income')[`retirement.${r.id}.codes`]).toMatch(/at most 4/);
    const s = { ...newSsa(), netBenefits: -100 };
    expect(validateStep(single({ ssa: [s] }), 'income')).toEqual({});
  });

  it('adjustment follow-ups are required only when switched on', () => {
    expect(validateStep(single(), 'adjustments')).toEqual({});
    const e = validateStep(
      single({
        educator: { primary: true, spouse: false, primaryExpenses: null, spouseExpenses: null },
        studentLoan: { hadPayments: true, loansQualify: true, interest: null },
        estimated: { paid: true, amount: null, differentName: false },
      }),
      'adjustments',
    );
    expect(Object.keys(e).sort()).toEqual(['educator.primaryExpenses', 'estimated.amount', 'studentLoan.interest']);
  });

  it('every valid example draft passes all steps', () => {
    for (const [, req] of examples) expect(isDraftValid(draftFromRequest(req))).toBe(true);
  });
});

describe('loadDraft', () => {
  const store = (v: string | null) => ({ getItem: (k: string) => (k === STORAGE_KEY ? v : null) });
  it('returns an empty draft for nothing, junk or an old version', () => {
    expect(loadDraft(store(null))).toEqual(emptyDraft());
    expect(loadDraft(store('{nope'))).toEqual(emptyDraft());
    expect(loadDraft(store('{"version":0,"filingStatus":"Single"}'))).toEqual(emptyDraft());
  });
  it('restores a saved draft and fills missing keys', () => {
    const d = loadDraft(store('{"version":1,"filingStatus":"HeadOfHousehold"}'));
    expect(d.filingStatus).toBe('HeadOfHousehold');
    expect(d.w2s).toEqual([]);
  });
});
