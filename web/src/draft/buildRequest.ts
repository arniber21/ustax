import type {
  CalculateRequest,
  Dependent,
  FilerFlags,
  Form1099G,
  Form1099Int,
  Form1099R,
  Form1099RCodeChar,
  FormW2,
  W2Box12,
} from '../api';
import { isJoint, type Cents, type DependentDraft, type Draft, type FlagsDraft, type Role } from './types';

/** Thrown by `buildRequest` when the draft has no filing status yet. Use `canBuildRequest` to check first. */
export class DraftIncompleteError extends Error {
  constructor(message = 'Pick a filing status before building a request.') {
    super(message);
    this.name = 'DraftIncompleteError';
  }
}

export const canBuildRequest = (d: Draft): boolean => d.filingStatus !== null;

/** Copies `value` to `out[key]` only when the user entered something. */
function put<T extends object, K extends string>(out: T, key: K, value: Cents): void {
  if (value !== null) (out as Record<string, unknown>)[key] = value;
}
function putTrue<T extends object, K extends string>(out: T, key: K, value: boolean): void {
  if (value) (out as Record<string, unknown>)[key] = true;
}

type Obj = Record<string, unknown>;
const nonEmpty = (o: Obj): Obj | undefined => (Object.keys(o).length ? o : undefined);

function hsaFilerOut(f: FlagsDraft, who: 'primary' | 'secondary'): Obj | undefined {
  const h = f.hsa;
  if (!h.contributed) return undefined;
  const o: Obj = { [`writable_${who}_filer_has_made_contributions_to_hsa`]: true };
  if (h.coverage) o.hsa_hdhp_coverage_status = h.coverage;
  if (h.type) o.type_of_hdhp = h.type;
  if (h.medicare) o.enrolled_in_medicare = h.medicare;
  put(o, 'writable_hsa_nonemployer_contributions_tax_year', h.directContributions);
  return o;
}

/** One filer's facts. `date_of_birth` replaces `age65_or_older` in the contract, so only one of them is sent. */
function filerOut(f: FlagsDraft, who: 'primary' | 'secondary', hsa: boolean): FilerFlags | undefined {
  const o: Obj = {};
  putTrue(o, 'is_blind', f.blind);
  if (f.dob) o.date_of_birth = f.dob;
  else putTrue(o, 'age65_or_older', f.age65);
  putTrue(o, 'can_be_claimed_as_dependent', f.canBeClaimed);
  if (f.citizenship !== 'citizen') o.is_us_citizen_full_year = false;
  putTrue(o, 'noncitizen_resident_full_year', f.citizenship === 'resident');
  putTrue(o, 'is_student', f.student);
  if (!f.hasSsn) o.tin = { tin_is_ssn: false };
  if (f.retiredOnDisability) o.disability = { is_retired_on_perm_or_total_disability: true };
  const h = hsa ? hsaFilerOut(f, who) : undefined;
  if (h) o.hsa = h;
  return nonEmpty(o) as FilerFlags | undefined;
}

function dependentOut(p: DependentDraft, d: Draft, cdcc: boolean): Dependent {
  const o: Obj = { relationship: p.relationship, date_of_birth: p.dob, tin_type: p.tinType };
  putTrue(o, 'full_time_student', p.student);
  putTrue(o, 'permanent_total_disability', p.disabled);
  if (p.residency !== 'AllYear') {
    o.residency_duration = p.residency;
    if (p.residency === 'SixToElevenMonths' && p.months !== null) o.months_lived_with_tp_in_us = p.months;
  }
  putTrue(o, 'own_support', p.ownSupport);
  putTrue(o, 'married', p.married);
  putTrue(o, 'joint_return', p.married && p.jointReturn);
  putTrue(o, 'could_be_qualifying_child_of_another', p.claimableByOther);
  put(o, 'gross_income', p.grossIncome);
  putTrue(o, 'qr_support_test', p.youSupport);
  if (p.citizenship !== 'citizen') {
    o.is_us_citizen_full_year = false;
    putTrue(o, 'us_resident', p.citizenship === 'resident');
    putTrue(o, 'us_national', p.citizenship === 'national');
    putTrue(o, 'canada_mexico_resident', p.citizenship === 'canadaMexico');
  }
  if (!p.claim) o.tp_claims = false;
  putTrue(o, 'tp_paid_most_of_home_upkeep', d.paidHomeUpkeep);
  if (cdcc) {
    const c: Obj = {};
    putTrue(c, 'unable_to_care_for_self', p.unableToSelfCare);
    if (p.careExpenses !== null && p.careExpenses > 0) {
      c.has_dependent_care_expenses = true;
      c.expenses_paid_to_qualifying_provider = p.careProviderQualifies === true;
      c.writable_qualifying_expense_amount = p.careExpenses;
    }
    if (Object.keys(c).length) o.cdcc = c;
  }
  return o as unknown as Dependent;
}

function hsaWho(d: Draft): Obj {
  const o: Obj = {};
  putTrue(o, 'writable_primary_filer_had_non_w2_hsa_activity', d.primary.hsa.contributed);
  putTrue(o, 'writable_secondary_filer_had_non_w2_hsa_activity', isJoint(d) && d.spouse.hsa.contributed);
  return o;
}

/**
 * Maps the wizard draft to the typed `POST /calculate` body. Pure: no I/O, no clock, no randomness.
 *
 * - Money stays integer cents; empty money boxes are left out (absent means $0 to the calculator).
 * - Spouse data and `SecondaryFiler` rows are only sent for joint returns (the API rejects them otherwise).
 * - Empty lists and false flags are omitted, so the smallest draft gives the smallest request.
 * - Does not validate ranges: run `validateDraft` first (and `contractProblems` as a last check).
 *
 * @throws DraftIncompleteError when no filing status has been chosen.
 */
export function buildRequest(d: Draft): CalculateRequest {
  if (d.filingStatus === null) throw new DraftIncompleteError();
  const joint = isJoint(d);
  const role = (r: Role): Role => (joint ? r : 'PrimaryFiler');
  const req: Record<string, unknown> = { api_version: 1, tax_year: 2024, filing_status: d.filingStatus };

  const filers: { primary?: FilerFlags; secondary?: FilerFlags } = {};
  const primary = filerOut(d.primary, 'primary', d.hsa.has);
  if (primary) filers.primary = primary;
  const secondary = joint ? filerOut(d.spouse, 'secondary', d.hsa.has) : undefined;
  if (secondary) filers.secondary = secondary;
  if (Object.keys(filers).length) req.filers = filers;

  const details: Record<string, boolean> = {};
  if (joint && d.spouseDiedThisYear) {
    details.is_widowed_in_tax_year = true;
    putTrue(details, 'mfj_deceased_spouse_reached_age65', d.deceasedSpouseWas65);
  }
  if (d.filingStatus === 'MarriedFilingSeparately') putTrue(details, 'mfs_spouse_65_or_older', d.mfsSpouse65);
  putTrue(details, 'has_foreign_accounts_or_trusts', d.foreignAccounts);
  if (Object.keys(details).length) req.filing_details = details;

  if (d.w2s.length) {
    req.w2s = d.w2s.map((w) => {
      const o: FormW2 = { filer: role(w.filer), wages: w.wages ?? 0 };
      put(o, 'federal_withholding', w.withholding);
      put(o, 'oasdi_wages', w.ssWages);
      put(o, 'oasdi_withholding', w.ssTax);
      put(o, 'medicare_wages', w.medicareWages);
      put(o, 'medicare_withholding', w.medicareTax);
      put(o, 'allocated_tips', w.allocatedTips);
      put(o, 'dependent_care_benefits', w.dependentCare);
      put(o, 'non_qualified_plans', w.nonQualified);
      const box12: Record<string, number> = {};
      for (const row of w.box12) {
        if (row.code === '' || row.amount === null) continue;
        box12[row.code] = (box12[row.code] ?? 0) + row.amount; // the same code twice adds up
      }
      if (Object.keys(box12).length) o.box12 = box12 as W2Box12;
      putTrue(o, 'statutory_employee', w.statutoryEmployee);
      putTrue(o, 'third_party_sick_pay', w.thirdPartySickPay);
      putTrue(o, 'plan_457b_is_governmental', w.plan457bGovernmental);
      return o;
    });
  }

  if (d.interest.length) {
    req.interest_reports = d.interest.map((i) => {
      const o: Form1099Int = { filer: role(i.filer), has_1099: true };
      put(o, 'interest_income', i.interest);
      put(o, 'early_withdrawal_penalty', i.earlyWithdrawalPenalty);
      put(o, 'government_bond_interest', i.governmentBondInterest);
      put(o, 'federal_tax_withheld', i.withheld);
      put(o, 'foreign_tax_paid', i.foreignTax);
      put(o, 'tax_exempt_interest', i.taxExempt);
      put(o, 'private_activity_bond_interest', i.privateActivityBond);
      return o;
    });
  }

  if (d.unemployment.length) {
    req.form_1099g = d.unemployment.map((u) => {
      const o: Form1099G = { filer: role(u.filer), unemployment_compensation: u.amount ?? 0 };
      put(o, 'federal_tax_withheld', u.withheld);
      return o;
    });
  }

  if (d.retirement.length) {
    req.form_1099r = d.retirement.map((r) => {
      const o: Form1099R = {
        filer: role(r.filer),
        distribution_code: r.codes as Form1099RCodeChar[] as Form1099R['distribution_code'],
        gross_distribution: r.gross ?? 0,
        taxable_amount: r.taxableBlank ? 0 : (r.taxable ?? 0),
      };
      putTrue(o, 'taxable_amount_blank', r.taxableBlank);
      putTrue(o, 'total_distribution', r.totalDistribution);
      put(o, 'federal_withholding', r.withheld);
      putTrue(o, 'ira_sep_simple', r.iraSepSimple);
      return o;
    });
  }

  if (d.ssa.length) {
    const ss: Record<string, unknown> = { net_benefits: d.ssa.map((s) => s.netBenefits ?? 0) };
    if (d.ssa.some((s) => s.withheld !== null)) ss.federal_tax_withheld = d.ssa.map((s) => s.withheld ?? 0);
    if (d.filingStatus === 'MarriedFilingSeparately') putTrue(ss, 'lived_apart_all_year', d.livedApartAllYear);
    req.social_security = ss;
  }

  const fa: Obj = {};
  if (d.maritalStatus) fa.marital_status = d.maritalStatus;
  if (d.yearOfSpouseDeath && d.maritalStatus === 'Widowed') fa.year_of_spouse_death = d.yearOfSpouseDeath;
  if (d.spouseLivedTogether && d.filingStatus === 'MarriedFilingSeparately') fa.spouse_lived_together_months = d.spouseLivedTogether;
  if (Object.keys(fa).length) req.filing_answers = fa;

  const people = d.hasDependents ? d.dependents : [];
  if (people.length) req.dependents = people.map((p) => dependentOut(p, d, d.cdcc.paid));

  const credits: Obj = {};
  putTrue(credits, 'eitc_had_improper_claims', d.credits.eitcImproperClaims);
  putTrue(credits, 'received_improper_claims', d.credits.ctcImproperClaims);
  putTrue(credits, 'eitc_qc_of_another', d.credits.eitcQcOfAnother);
  if (Object.keys(credits).length) req.credits = credits;

  if (d.cdcc.paid && d.cdcc.totalQualified !== null) {
    req.cdcc = { writable_total_qualified_dependent_care_expenses: d.cdcc.totalQualified };
  }

  const screening: Obj = {};
  putTrue(screening, 'received_digital_assets', d.screening.digitalReceived);
  putTrue(screening, 'disposed_digital_assets', d.screening.digitalDisposed);
  putTrue(screening, 'made_ira_contributions', d.screening.iraContributions);
  putTrue(screening, 'is_foreign_trusts_grantor', d.screening.foreignTrustGrantor);
  if (Object.keys(screening).length) req.screening = screening;

  const adjustments: Record<string, unknown> = {};
  const ed = d.educator;
  const educatorWho = joint ? (ed.primary && ed.spouse ? 'BothDid' : ed.primary ? 'TpDid' : ed.spouse ? 'SpouseDid' : 'Neither') : ed.primary ? 'TpDid' : 'Neither';
  if (educatorWho !== 'Neither') {
    const o: Record<string, unknown> = { was_k12_educators: educatorWho };
    if (educatorWho === 'TpDid' || educatorWho === 'BothDid') put(o, 'primary_expenses', ed.primaryExpenses);
    if (educatorWho === 'SpouseDid' || educatorWho === 'BothDid') put(o, 'secondary_expenses', ed.spouseExpenses);
    adjustments.educator_expenses = o;
  }
  if (d.studentLoan.hadPayments) {
    const o: Record<string, unknown> = { had_payments: true, loans_qualify: d.studentLoan.loansQualify };
    put(o, 'interest_amount', d.studentLoan.interest);
    adjustments.student_loan_interest = o;
  }
  if (d.hsa.has) adjustments.hsa = { some_filer_had_non_w2_hsa_activity: true, ...hsaWho(d) };
  if (Object.keys(adjustments).length) req.adjustments = adjustments;

  if (d.estimated.paid) {
    const o: Record<string, unknown> = { paid_estimated_taxes_or_from_last_year: true };
    put(o, 'amount', d.estimated.amount);
    putTrue(o, 'paid_under_different_name', d.estimated.differentName);
    req.estimated_payments = o;
  }

  return req as unknown as CalculateRequest;
}

/** `buildRequest`, or null when the draft is not ready. Handy for hooks that should not throw. */
export function tryBuildRequest(d: Draft): CalculateRequest | null {
  return canBuildRequest(d) ? buildRequest(d) : null;
}
