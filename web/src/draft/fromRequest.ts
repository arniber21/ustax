import type { CalculateRequest } from '../api';
import {
  emptyDraft,
  newId,
  type Draft,
  type FlagsDraft,
  type Role,
} from './types';

const flags = (f: { is_blind?: boolean; age65_or_older?: boolean; can_be_claimed_as_dependent?: boolean } | undefined): FlagsDraft => ({
  blind: f?.is_blind ?? false,
  age65: f?.age65_or_older ?? false,
  canBeClaimed: f?.can_be_claimed_as_dependent ?? false,
});

const m = (v: number | undefined): number | null => v ?? null;

/**
 * Inverse of `buildRequest` for the facts the wizard collects (used to preload api/examples
 * and in round-trip tests). Request properties the wizard has no question for are dropped.
 */
export function draftFromRequest(req: CalculateRequest): Draft {
  const d = emptyDraft();
  d.filingStatus = req.filing_status;
  d.primary = flags(req.filers?.primary);
  d.spouse = flags(req.filers?.secondary);
  const fd = req.filing_details;
  d.spouseDiedThisYear = fd?.is_widowed_in_tax_year ?? false;
  d.deceasedSpouseWas65 = fd?.mfj_deceased_spouse_reached_age65 ?? false;
  d.mfsSpouse65 = fd?.mfs_spouse_65_or_older ?? false;
  d.foreignAccounts = fd?.has_foreign_accounts_or_trusts ?? false;

  d.w2s = (req.w2s ?? []).map((w) => ({
    id: newId(),
    filer: w.filer as Role,
    wages: w.wages,
    withholding: m(w.federal_withholding),
    ssWages: m(w.oasdi_wages),
    ssTax: m(w.oasdi_withholding),
    medicareWages: m(w.medicare_wages),
    medicareTax: m(w.medicare_withholding),
    allocatedTips: m(w.allocated_tips),
    dependentCare: m(w.dependent_care_benefits),
    nonQualified: m(w.non_qualified_plans),
    box12: Object.entries(w.box12 ?? {}).map(([code, amount]) => ({ id: newId(), code, amount: amount ?? null })),
    statutoryEmployee: w.statutory_employee ?? false,
    thirdPartySickPay: w.third_party_sick_pay ?? false,
    plan457bGovernmental: w.plan_457b_is_governmental ?? false,
  }));
  d.interest = (req.interest_reports ?? []).map((i) => ({
    id: newId(),
    filer: i.filer as Role,
    interest: m(i.interest_income),
    earlyWithdrawalPenalty: m(i.early_withdrawal_penalty),
    governmentBondInterest: m(i.government_bond_interest),
    withheld: m(i.federal_tax_withheld),
    foreignTax: m(i.foreign_tax_paid),
    taxExempt: m(i.tax_exempt_interest),
    privateActivityBond: m(i.private_activity_bond_interest),
  }));
  d.unemployment = (req.form_1099g ?? []).map((u) => ({
    id: newId(),
    filer: u.filer as Role,
    amount: u.unemployment_compensation,
    withheld: m(u.federal_tax_withheld),
  }));
  d.retirement = (req.form_1099r ?? []).map((r) => ({
    id: newId(),
    filer: r.filer as Role,
    codes: [...r.distribution_code],
    gross: r.gross_distribution,
    taxable: r.taxable_amount_blank ? null : r.taxable_amount,
    taxableBlank: r.taxable_amount_blank ?? false,
    withheld: m(r.federal_withholding),
    iraSepSimple: r.ira_sep_simple ?? false,
    totalDistribution: r.total_distribution ?? false,
  }));
  d.ssa = (req.social_security?.net_benefits ?? []).map((n) => ({ id: newId(), netBenefits: n }));
  d.livedApartAllYear = req.social_security?.lived_apart_all_year ?? false;

  const ed = req.adjustments?.educator_expenses;
  if (ed) {
    d.educator = {
      primary: ed.was_k12_educators === 'TpDid' || ed.was_k12_educators === 'BothDid',
      spouse: ed.was_k12_educators === 'SpouseDid' || ed.was_k12_educators === 'BothDid',
      primaryExpenses: m(ed.primary_expenses),
      spouseExpenses: m(ed.secondary_expenses),
    };
  }
  const sl = req.adjustments?.student_loan_interest;
  if (sl) d.studentLoan = { hadPayments: sl.had_payments, loansQualify: sl.loans_qualify ?? false, interest: m(sl.interest_amount) };
  const ep = req.estimated_payments;
  if (ep) {
    d.estimated = {
      paid: ep.paid_estimated_taxes_or_from_last_year,
      amount: m(ep.amount),
      differentName: ep.paid_under_different_name ?? false,
    };
  }
  return d;
}
