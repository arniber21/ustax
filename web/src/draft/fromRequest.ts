import type { CalculateRequest, Dependent, FilerFlags } from '../api';
import {
  emptyDraft,
  emptyFlags,
  type Citizenship,
  type DependentDraft,
  newId,
  type Draft,
  type FlagsDraft,
  type Role,
} from './types';

const flags = (f: FilerFlags | undefined, who: 'primary' | 'secondary'): FlagsDraft => {
  const h = f?.hsa;
  const mine = who === 'primary' ? h?.writable_primary_filer_has_made_contributions_to_hsa : h?.writable_secondary_filer_has_made_contributions_to_hsa;
  return {
    ...emptyFlags(),
    blind: f?.is_blind ?? false,
    age65: f?.age65_or_older ?? false,
    canBeClaimed: f?.can_be_claimed_as_dependent ?? false,
    dob: f?.date_of_birth ?? '',
    citizenship: f?.noncitizen_resident_full_year ? 'resident' : f?.is_us_citizen_full_year === false ? 'other' : 'citizen',
    hasSsn: f?.tin?.tin_is_ssn ?? true,
    student: f?.is_student ?? false,
    retiredOnDisability: f?.disability?.is_retired_on_perm_or_total_disability ?? false,
    hsa: {
      contributed: mine ?? false,
      coverage: h?.hsa_hdhp_coverage_status ?? '',
      type: h?.type_of_hdhp ?? '',
      medicare: h?.enrolled_in_medicare ?? '',
      directContributions: h?.writable_hsa_nonemployer_contributions_tax_year ?? null,
    },
  };
};

const dependent = (p: Dependent): DependentDraft => {
  const c = p.cdcc;
  const citizenship: Citizenship =
    p.is_us_citizen_full_year === false
      ? p.us_resident ? 'resident' : p.us_national ? 'national' : p.canada_mexico_resident ? 'canadaMexico' : 'other'
      : 'citizen';
  return {
    id: newId(),
    name: '',
    relationship: p.relationship,
    dob: p.date_of_birth,
    residency: p.residency_duration ?? 'AllYear',
    months: p.months_lived_with_tp_in_us !== undefined && p.months_lived_with_tp_in_us >= 6 && p.months_lived_with_tp_in_us < 12 ? p.months_lived_with_tp_in_us : null,
    tinType: p.tin_type,
    citizenship,
    student: p.full_time_student ?? false,
    disabled: p.permanent_total_disability ?? false,
    ownSupport: p.own_support ?? false,
    youSupport: p.qr_support_test ?? false,
    claimableByOther: p.could_be_qualifying_child_of_another ?? false,
    married: p.married ?? false,
    jointReturn: p.joint_return ?? false,
    grossIncome: m(p.gross_income),
    claim: p.tp_claims ?? true,
    unableToSelfCare: c?.unable_to_care_for_self ?? false,
    careExpenses: m(c?.writable_qualifying_expense_amount),
    careProviderQualifies: c?.has_dependent_care_expenses ? (c.expenses_paid_to_qualifying_provider ?? false) : null,
  };
};

const m = (v: number | undefined): number | null => v ?? null;

/**
 * Inverse of `buildRequest` for the facts the wizard collects (used to preload api/examples
 * and in round-trip tests). Request properties the wizard has no question for are dropped.
 */
export function draftFromRequest(req: CalculateRequest): Draft {
  const d = emptyDraft();
  d.filingStatus = req.filing_status;
  d.primary = flags(req.filers?.primary, 'primary');
  d.spouse = flags(req.filers?.secondary, 'secondary');
  const fd = req.filing_details;
  d.spouseDiedThisYear = fd?.is_widowed_in_tax_year ?? false;
  d.deceasedSpouseWas65 = fd?.mfj_deceased_spouse_reached_age65 ?? false;
  d.mfsSpouse65 = fd?.mfs_spouse_65_or_older ?? false;
  d.foreignAccounts = fd?.has_foreign_accounts_or_trusts ?? false;

  const fa = req.filing_answers;
  d.maritalStatus = fa?.marital_status ?? '';
  d.yearOfSpouseDeath = fa?.year_of_spouse_death ?? '';
  d.spouseLivedTogether = fa?.spouse_lived_together_months ?? '';
  d.dependents = (req.dependents ?? []).map(dependent);
  d.hasDependents = d.dependents.length > 0;
  d.paidHomeUpkeep = (req.dependents ?? []).some((p) => p.tp_paid_most_of_home_upkeep === true);
  const cr = req.credits;
  d.credits = {
    eitcImproperClaims: cr?.eitc_had_improper_claims ?? false,
    ctcImproperClaims: cr?.received_improper_claims ?? false,
    eitcQcOfAnother: cr?.eitc_qc_of_another ?? false,
  };
  const sc = req.screening;
  d.screening = {
    digitalReceived: sc?.received_digital_assets ?? false,
    digitalDisposed: sc?.disposed_digital_assets ?? false,
    iraContributions: sc?.made_ira_contributions ?? false,
    foreignTrustGrantor: sc?.is_foreign_trusts_grantor ?? false,
  };
  d.cdcc = {
    paid: (req.dependents ?? []).some((p) => p.cdcc?.has_dependent_care_expenses || p.cdcc?.unable_to_care_for_self) || req.cdcc !== undefined,
    totalQualified: m(req.cdcc?.writable_total_qualified_dependent_care_expenses),
  };
  d.hsa = { has: req.adjustments?.hsa?.some_filer_had_non_w2_hsa_activity ?? false };

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
