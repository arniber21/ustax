// Differential test of the HTTP server against `ustax run Form1040` (issue #52). Test-only.
//
//   node scripts/server_vs_cli.mjs <base-url> <path to ustax binary> [cases=300]
//
// An independent re-mapping of the API request to the Catala JSON input (API box names to Catala
// names, written here from the descriptions in api/schema.json, not from lean/UsTax/Api/Bridge.lean)
// is run through the Lean CLI; the server's answer must agree: same line items, and a 422 exactly
// when the CLI says `unsupported` or the request sets has_foreign_accounts_or_trusts.
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const api = join(dirname(fileURLToPath(import.meta.url)), '..', 'api');
const base = (process.argv[2] ?? 'http://127.0.0.1:8080').replace(/\/$/, '');
const cli = process.argv[3] ?? join(api, '..', 'lean/.lake/build/bin/ustax');
const N = Number(process.argv[4] ?? 300);

const BOX12 = { A: 'uncollected_oasdi_tax_on_tips', B: 'uncollected_medicare_tax_on_tips', C: 'taxable_life_insurance_over_50k',
  D: 'deferrals_401k', E: 'deferrals_403b', F: 'sarsep_deferrals', G: 'deferrals_457b', H: 'deferrals_501c18',
  J: 'nontaxable_sick_pay', K: 'golden_parachute_excise_tax', L: 'expense_reimbursements',
  M: 'uncollected_oasdi_tax_on_life_insurance_over_50k', N: 'uncollected_medicare_tax_on_life_insurance_over_50k',
  P: 'armed_forces_moving_expenses', Q: 'writable_combat_pay', R: 'archer_msa_contributions', S: 'simple_contributions',
  T: 'adoption_benefits', V: 'nso_income', W: 'employer_hsa_contributions', Y: 'deferrals_409a', Z: 'nqdc_deferrals',
  AA: 'roth401k_contributions', BB: 'roth403b_contributions', DD: 'health_coverage_cost', EE: 'roth457b_contributions',
  FF: 'qsehra_benefits', GG: 'income_83i', HH: 'deferrals_83i', II: 'non_taxable_medicaid_waiver_payments' };
const W2_BOXES = { wages: 'writable_wages', federal_withholding: 'writable_federal_withholding', oasdi_wages: 'writable_oasdi_wages',
  oasdi_withholding: 'writable_oasdi_withholding', medicare_wages: 'writable_medicare_wages',
  medicare_withholding: 'writable_medicare_withholding', allocated_tips: 'writable_allocated_tips',
  dependent_care_benefits: 'writable_dependent_care_benefits', non_qualified_plans: 'writable_non_qualified_plans' };
const INT_BOXES = { no_1099_amount: 'no_1099_amount', interest_income: 'writable_1099_amount',
  early_withdrawal_penalty: 'writable_early_withdrawl_penalty_amount', government_bond_interest: 'writable_interest_on_government_bonds',
  federal_tax_withheld: 'writable_tax_withheld', foreign_tax_paid: 'writable_foreign_tax_paid',
  tax_exempt_interest: 'writable_tax_exempt_interest', private_activity_bond_interest: 'writable_specified_private_activity_bond_interest',
  market_discount: 'writable_market_discount', bond_premium: 'writable_bond_premium',
  bond_premium_treasury: 'writable_bond_premium_on_treasury_obligations', bond_premium_tax_exempt: 'writable_bond_premium_on_tax_exempt_bond',
  state_tax_withheld: 'writable_state_tax_withheld' };

const cents = (c) => (c ?? 0) / 100; // JSON number of dollars, exact for integer cents (<= 2 decimals)
function toCatala(r) {
  const f = r.filers ?? {}, d = r.filing_details ?? {};
  const p = f.primary ?? {}, s = f.secondary ?? {};
  return {
    filing_status: r.filing_status,
    w2s: (r.w2s ?? []).map((w) => ({
      filer: w.filer,
      ...Object.fromEntries(Object.values(W2_BOXES).map((k) => [k, 0])),
      ...Object.fromEntries(Object.values(BOX12).map((k) => [k, 0])),
      ...Object.fromEntries(Object.entries(W2_BOXES).map(([k, v]) => [v, cents(w[k])])),
      ...Object.fromEntries(Object.entries(w.box12 ?? {}).map(([c, v]) => [BOX12[c], cents(v)])),
      plan_457b_is_governmental: !!w.plan457b_is_governmental, statutory_employee: !!w.statutory_employee, third_party_sick_pay: !!w.third_party_sick_pay,
    })),
    interest_reports: (r.interest_reports ?? []).map((i) => ({
      filer: i.filer, has_1099: i.has_1099,
      ...Object.fromEntries(Object.values(INT_BOXES).map((k) => [k, 0])),
      ...Object.fromEntries(Object.entries(INT_BOXES).map(([k, v]) => [v, cents(i[k])])),
      state_is_different_state: !!i.state_is_different, facta_filing_required: !!i.facta_filing_required,
    })),
    has_foreign_accounts_or_trusts: !!d.has_foreign_accounts_or_trusts,
    combat_pay_election: d.combat_pay_election ?? 'NoCombatPay',
    primary_filer_can_be_claimed: !!p.can_be_claimed_as_dependent, secondary_filer_can_be_claimed: !!s.can_be_claimed_as_dependent,
    treat_as_mfs: d.treat_as_mfs ?? r.filing_status === 'MarriedFilingSeparately',
    primary_filer_is_blind: !!p.is_blind, primary_filer_age65_or_older: !!p.age65_or_older,
    secondary_filer_is_blind: !!s.is_blind, secondary_filer_age65_or_older: !!s.age65_or_older,
    is_widowed_in_tax_year: !!d.is_widowed_in_tax_year, mfj_deceased_spouse_reached_age65: !!d.mfj_deceased_spouse_reached_age65,
    mfs_spouse_65_or_older: !!d.mfs_spouse_65_or_older, mfs_spouse_provides_no_benefits: !!d.mfs_spouse_provides_no_benefits,
    treat_filers_as_dependents: !!d.treat_filers_as_dependents,
  };
}

// --- cases: every 200/422 request of the manifest, then seeded random ones ---
let seed = 20241031;
const rnd = () => ((seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0) / 2 ** 32);
const pick = (a) => a[Math.floor(rnd() * a.length)];
const amt = (max) => (rnd() < 0.15 ? 0 : Math.floor(rnd() * max));
const STATUSES = ['Single', 'MarriedFilingJointly', 'MarriedFilingSeparately', 'HeadOfHousehold', 'QualifyingSurvivingSpouse'];
function randomRequest() {
  const fs = pick(STATUSES), joint = fs === 'MarriedFilingJointly';
  const roles = joint ? ['PrimaryFiler', 'SecondaryFiler'] : ['PrimaryFiler'];
  const r = { api_version: 1, tax_year: 2024, filing_status: fs, w2s: [], interest_reports: [] };
  for (let i = 0, n = Math.floor(rnd() * 4); i < n; i++) {
    const wages = amt(30_000_000);
    const w = { filer: pick(roles), wages, federal_withholding: Math.floor(wages * rnd() * 0.3) };
    if (rnd() < 0.3) { w.oasdi_wages = wages; w.medicare_wages = wages; w.medicare_withholding = Math.floor(wages * 0.0145); }
    if (rnd() < 0.3) w.box12 = { [pick(['D', 'E', 'W', 'DD', 'C', 'Q', 'A', 'AA'])]: amt(2_000_000) };
    if (rnd() < 0.05) w.statutory_employee = true;
    if (rnd() < 0.05) w.allocated_tips = amt(500_000);
    r.w2s.push(w);
  }
  for (let i = 0, n = Math.floor(rnd() * 3); i < n; i++) {
    const t = { filer: pick(roles), has_1099: rnd() < 0.9, interest_income: amt(5_000_000) };
    if (rnd() < 0.1) t.federal_tax_withheld = amt(100_000);
    if (rnd() < 0.05) t.private_activity_bond_interest = amt(100_000);
    if (rnd() < 0.05) t.foreign_tax_paid = 5000;
    if (rnd() < 0.05) t.tax_exempt_interest = 7000;
    r.interest_reports.push(t);
  }
  const f = {};
  if (rnd() < 0.3) f.primary = { is_blind: rnd() < 0.5, age65_or_older: rnd() < 0.5, can_be_claimed_as_dependent: rnd() < 0.2 };
  if (joint && rnd() < 0.3) f.secondary = { is_blind: rnd() < 0.5, age65_or_older: rnd() < 0.5 };
  if (Object.keys(f).length) r.filers = f;
  const d = {};
  if (rnd() < 0.1) d.has_foreign_accounts_or_trusts = true;
  if (fs === 'MarriedFilingSeparately' && rnd() < 0.5) d.mfs_spouse_65_or_older = true;
  if (rnd() < 0.1) d.is_widowed_in_tax_year = true;
  if (Object.keys(d).length) r.filing_details = d;
  return r;
}

const requests = JSON.parse(readFileSync(join(api, 'fixtures/manifest.json'), 'utf8')).fixtures
  .filter((e) => e.method === 'POST' && e.request && (e.status === 200 || e.status === 422))
  .map((e) => ({ name: e.name, req: JSON.parse(readFileSync(join(api, e.request), 'utf8')) }));
for (let i = 0; i < N; i++) requests.push({ name: `random-${i}`, req: randomRequest() });

const run = spawnSync(cli, ['run', 'Form1040'], { input: requests.map((c) => JSON.stringify(toCatala(c.req))).join('\n') + '\n', encoding: 'utf8', maxBuffer: 1 << 28 });
if (run.status !== 0) { console.error('ustax run failed', run.stderr); process.exit(1); }
const outs = run.stdout.trim().split('\n').map((l) => JSON.parse(l));
const toCents = (s) => Math.round(parseFloat(s) * 100);
const LINES = { wages: 'wages', employer_income_subtotal: 'employer_income_subtotal', interest_income: 'interest_income',
  total_income: 'total_income', adjustments_to_income: 'adjustments_to_income', agi: 'agi',
  standard_or_itemized_deductions: 'standard_or_itemized_deductions', total_deductions: 'total_deductions',
  taxable_income: 'taxable_income', tentative_tax_from_taxable_income: 'tentative_tax_from_taxable_income',
  total_tentative_tax: 'total_tentative_tax', non_refundable_credits: 'non_refundable_credits',
  tax_less_non_refundable_credits: 'tax_less_non_refundable_credits', total_tax: 'total_tax', total_withholding: 'total_withholding',
  total_other_payments_refundable_credits: 'total_other_payments_refundable_credits', total_payments: 'total_payments',
  overpayment: 'overpayment', balance_due: 'balance_due' };

let ok = 0, bad = 0, n422 = 0;
for (let i = 0; i < requests.length; i++) {
  const { name, req } = requests[i], o = outs[i];
  const res = await fetch(base + '/calculate', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(req) });
  const body = await res.json();
  const expect422 = o.unsupported || !!req.filing_details?.has_foreign_accounts_or_trusts;
  let why = '';
  if (o.error) why = `cli error ${o.error}`;
  else if (expect422 !== (res.status === 422)) why = `status ${res.status}, cli unsupported=${o.unsupported}`;
  else if (res.status === 200) {
    for (const [k, c] of Object.entries(LINES)) if (body.lines[k] !== toCents(o[c])) { why = `${k}: server ${body.lines[k]} cli ${toCents(o[c])}`; break; }
  } else n422++;
  if (why) { bad++; console.log(`FAIL ${name}: ${why}\n  ${JSON.stringify(req).slice(0, 400)}`); } else ok++;
}
console.log(`server vs ustax run Form1040: ${ok} agree, ${bad} differ (${requests.length} cases, ${n422} knocked out)`);
process.exit(bad === 0 ? 0 : 1);
