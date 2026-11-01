// TEST-ONLY, UNTRUSTED: convert one oracle scenario (oracle/facts.csv writable facts) into an API request
// (api/schema.json `CalculateRequest`, 1.2.0) so that difftest/mappings/api_calculator.mjs can run the API-facing
// Catala scope on every scenario. It reuses the oracle -> Calculator mapping of difftest/mappings/calculator.mjs
// (`buildInput`) and renames the result into API shape (docs/api-mapping.md), converts dollars to cents, and drops
// every value equal to the documented default (so the decoder's defaults are exercised too).
//
// A scenario the API shape cannot express is reported (never silently altered): `toApiRequest` returns
// `{ request, inexpressible: [reason, ...] }`; a non-empty list means the request would be rejected by the
// contract (schema or the semantic rules of docs/api.md "Validation policy") or would change meaning.
//
//   node scripts/oracle_to_api_request.mjs <scenario> [oracle.csv]   print the request
//   node scripts/oracle_to_api_request.mjs --all                     list inexpressible scenarios
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadOracle, isKnockedOut, buildInput } from '../difftest/lib.mjs';
import calcMapping from '../difftest/mappings/calculator.mjs';
import { schema, decode, UNSPECIFIED_PROPS } from './api_decode.mjs';
import { BOX12, INT_RENAME, G_RENAME, MISC_RENAME, R_RENAME, W2_RENAME, DEP } from './api_wire_tables.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const defs = schema.$defs;

// ---- Calculator JSON (dollars, Catala names) -> API shape (dollars, API names) ------------------
const invert = (o) => Object.fromEntries(Object.entries(o).map(([a, c]) => [c, a]));
const strip = (n) => n.replace(/^writ(able|eable)_/, '');
function renameForm(item, rename) {
  const inv = invert(rename);
  return Object.fromEntries(Object.entries(item).map(([k, v]) => [inv[k] ?? strip(k), v]));
}
const CODE_OF = { Code2: '2', Code4: '4', Code7: '7', CodeB: 'B', CodeG: 'G', CodeH: 'H', OtherCode: 'Other' };
function w2(item) {
  const box12Of = invert(BOX12);
  const out = { box12: {} };
  for (const [k, v] of Object.entries(item)) {
    if (box12Of[k]) out.box12[box12Of[k]] = v;
    else out[invert(W2_RENAME)[k] ?? strip(k)] = v;
  }
  return out;
}
function get(obj, path) { return path.split('.').reduce((o, k) => o[k], obj); }
function dependent(m, i, c) {
  const out = {};
  for (const [api, path] of Object.entries(DEP)) out[api] = get(m, path);
  out.deceased = c.screening.member_vitals[i].deceased;
  return out;
}
function filer(fa, extra) {
  return {
    is_blind: fa.is_blind, date_of_birth: fa.date_of_birth, can_be_claimed_as_dependent: fa.can_be_claimed,
    will_be_claimed: fa.will_be_claimed, potential_claimer_must_file: fa.potential_claimer_must_file,
    potential_claimer_did_file: fa.potential_claimer_did_file, is_us_citizen_full_year: fa.is_us_citizen_full_year,
    citizen_at_end_of_tax_year: fa.writable_citizen_at_end_of_tax_year,
    noncitizen_resident_full_year: fa.writable_is_noncitizen_resident_full_year, is_national: fa.writable_is_national,
    is_student: extra.is_student, tin: extra.tin, disability: extra.disability, hsa: extra.hsa, cdcc: extra.cdcc,
  };
}

function shape(c) {
  const f = c.filers;
  const filingAnswers = {
    marital_status: f.marital_status, year_of_spouse_death: f.year_of_spouse_death,
    secondary_filer_date_of_death: f.secondary_filer_date_of_death,
    primary_filer_potential_claimer_filed_only_for_refund: f.primary_filer_potential_claimer_filed_only_for_refund,
    mfj_required_to_file: f.mfj_required_to_file, mfj_dependents_filing_for_credits: f.mfj_dependents_filing_for_credits,
    lived_together_all_year_with_spouse: f.lived_together_all_year_with_spouse,
    spouse_lived_together_months: f.spouse_lived_together_months,
    lived_apart_last_six_months: f.writable_lived_apart_last_six_months, separation_agreement: f.writable_separation_agreement,
    can_file_jointly_year_of_spouse_death: f.can_file_jointly_year_of_spouse_death,
    in_registered_domestic_partnership: f.in_registered_domestic_partnership, residence_state: f.filer_residence_and_income_state,
    spouse_itemizes: f.spouse_itemizes, mfs_living_spouse_filing_return: f.mfs_living_spouse_filing_return,
    mfs_deceased_spouse_filing_return: f.mfs_deceased_spouse_filing_return, mfs_spouse_has_gross_income: f.mfs_spouse_has_gross_income,
  };
  const mfj = c.filing_status === 'MarriedFilingJointly';
  return {
    filing_status: c.filing_status,
    filers: { primary: filer(f.primary_filer, c.primary_extra), ...(mfj ? { secondary: filer(f.secondary_filer, c.secondary_extra) } : {}) },
    filing_details: {
      mfs_spouse_65_or_older: f.mfs_spouse_65_or_older, combat_pay_election: c.income.combat_pay_election,
      combat_pay_election_made: c.income.combat_pay_election_made,
    },
    filing_answers: filingAnswers,
    dependents: c.household.map((m, i) => dependent(m, i, c)),
    w2s: c.income.w2s.map(w2),
    interest_reports: c.income.interest_reports.map((x) => renameForm(x, INT_RENAME)),
    form_1099g: c.income.form_1099gs.map((x) => renameForm(x, G_RENAME)),
    form_1099misc: c.income.form_1099miscs.map((x) => renameForm(x, MISC_RENAME)),
    form_1099r: c.income.form_1099rs.map((x) => {
      const r = renameForm(x, R_RENAME);
      return { ...r, distribution_code: r.distribution_code.map((k) => CODE_OF[k]) };
    }),
    social_security: { net_benefits: c.income.ssa_net_benefits, federal_tax_withheld: c.income.ssa_federal_tax_withheld, lived_apart_all_year: false },
    adjustments: {
      educator_expenses: { was_k12_educators: c.adjustments.was_k12_educators, primary_expenses: c.adjustments.primary_educator_expenses_writable, secondary_expenses: c.adjustments.secondary_educator_expenses_writable },
      student_loan_interest: { had_payments: c.adjustments.had_student_loan_interest_payments, loans_qualify: c.adjustments.student_loans_qualify, interest_amount: c.adjustments.student_loan_interest_amount },
      hsa: c.adjustments.hsa,
    },
    estimated_payments: {
      paid_estimated_taxes_or_from_last_year: c.payments.paid_estimated_taxes_or_from_last_year, amount: c.payments.estimated_tax_payment_writable,
      paid_under_different_name: c.payments.paid_estimated_taxes_or_from_last_year_under_different_name,
      paid_with_former_spouse: c.payments.paid_estimated_taxes_with_former_spouse,
    },
    credits: c.credits, cdcc: c.cdcc_answers, premium_tax_credit: c.ptc_answers,
    screening: Object.fromEntries(Object.entries(c.screening).filter(([k]) => k !== 'member_vitals')),
  };
}

// ---- schema-guided: dollars -> cents, then drop defaults -----------------------------------------
const MONEY = new Set(['#/$defs/Money', '#/$defs/NonNegMoney']);
const refName = (n) => (n.$ref ? n.$ref.replace('#/$defs/', '') : undefined);
function toCents(v, node) {
  if (node.$ref && MONEY.has(node.$ref)) return Math.round(v * 100);
  const t = node.$ref ? defs[refName(node)] : node;
  if (Array.isArray(v)) return v.map((x) => toCents(x, t.items));
  if (v && typeof v === 'object') {
    const out = {};
    for (const [k, x] of Object.entries(v)) {
      const p = t.properties?.[k];
      if (!p) throw new Error(`unknown property ${k} for ${refName(node) ?? 'object'}`);
      out[k] = toCents(x, p);
    }
    return out;
  }
  return v;
}
function prune(v, node, name) {
  const t = node.$ref ? defs[refName(node)] : node;
  const nm = refName(node) ?? name;
  if (Array.isArray(v)) return v.map((x) => prune(x, t.items));
  if (v && typeof v === 'object') {
    const out = {};
    for (const [k, x] of Object.entries(v)) {
      const p = t.properties[k];
      const px = prune(x, p, undefined);
      const keep = (t.required ?? []).includes(k) || UNSPECIFIED_PROPS[nm]?.includes(k) || k === 'date_of_birth' || k === 'recipient_date_of_birth' || k === 'filer';
      if (!keep && JSON.stringify(px) === JSON.stringify(decode(undefined, p))) continue;
      if (!keep && px && typeof px === 'object' && !Array.isArray(px) && Object.keys(px).length === 0) continue;
      out[k] = px;
    }
    return out;
  }
  return v;
}

let ajv;
function validator() {
  if (!ajv) {
    const Ajv2020 = createRequire(join(root, 'api/package.json'))('ajv/dist/2020.js');
    ajv = new Ajv2020({ strict: true, allErrors: true });
    ajv.addSchema(schema);
    ajv = { check: ajv.getSchema(`${schema.$id}#/$defs/CalculateRequest`), ajv };
  }
  return ajv;
}

/** Semantic rules of docs/api.md "Validation policy" that the schema cannot express. */
function semantic(req) {
  const problems = [];
  const mfj = req.filing_status === 'MarriedFilingJointly';
  const lists = { w2s: req.w2s, interest_reports: req.interest_reports, form_1099g: req.form_1099g, form_1099misc: req.form_1099misc, form_1099r: req.form_1099r };
  for (const [name, items] of Object.entries(lists)) {
    items?.forEach((x, i) => { if (x.filer === 'SecondaryFiler' && !mfj) problems.push(`/${name}/${i}: SecondaryFiler form on a non-joint return`); });
  }
  const ss = req.social_security;
  if (ss && ss.federal_tax_withheld?.length > ss.net_benefits.length) problems.push('/social_security/federal_tax_withheld longer than net_benefits');
  return problems;
}

export function toApiRequest(facts) {
  const c = buildInput(calcMapping, facts);
  const shaped = toCents(shape(c), defs.CalculateRequest);
  const request = { api_version: 1, tax_year: 2024, ...prune(shaped, defs.CalculateRequest, 'CalculateRequest') };
  const inexpressible = [];
  const v = validator();
  if (!v.check(request)) for (const e of v.check.errors) inexpressible.push(`schema ${e.instancePath || '/'} ${e.message}`);
  inexpressible.push(...semantic(request));
  return { request, inexpressible };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const oracle = loadOracle(resolve(root, process.argv[3] && !process.argv[3].startsWith('--') ? process.argv[3] : 'oracle/facts.csv'));
  if (process.argv[2] === '--all') {
    let n = 0, bad = 0;
    for (const [name, facts] of oracle) {
      if (isKnockedOut(facts)) continue;
      n++;
      const { inexpressible } = toApiRequest(facts);
      if (inexpressible.length) { bad++; console.log(`${name}: ${inexpressible.join('; ')}`); }
    }
    console.log(`${n} scenarios, ${bad} inexpressible`);
  } else {
    const facts = oracle.get(process.argv[2]);
    if (!facts) throw new Error('unknown scenario');
    const r = toApiRequest(facts);
    console.log(JSON.stringify(r.request, null, 2));
    if (r.inexpressible.length) console.error('INEXPRESSIBLE:', r.inexpressible);
  }
}
