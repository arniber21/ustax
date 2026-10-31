import type {
  CalculateRequest,
  FilerFlags,
  Form1099G,
  Form1099Int,
  Form1099R,
  Form1099RCodeChar,
  FormW2,
  W2Box12,
} from '../api';
import { isJoint, type Cents, type Draft, type FlagsDraft, type Role } from './types';

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

function flagsOut(f: FlagsDraft): FilerFlags | undefined {
  const o: FilerFlags = {};
  putTrue(o, 'is_blind', f.blind);
  putTrue(o, 'age65_or_older', f.age65);
  putTrue(o, 'can_be_claimed_as_dependent', f.canBeClaimed);
  return Object.keys(o).length ? o : undefined;
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
  const primary = flagsOut(d.primary);
  if (primary) filers.primary = primary;
  const secondary = joint ? flagsOut(d.spouse) : undefined;
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
    if (d.filingStatus === 'MarriedFilingSeparately') putTrue(ss, 'lived_apart_all_year', d.livedApartAllYear);
    req.social_security = ss;
  }

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
