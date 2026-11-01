#!/usr/bin/env node
// Builds api/provenance.json: for every API line item, the trail from the number to the law.
//   node scripts/gen_provenance.mjs            write api/provenance.json
//   node scripts/gen_provenance.mjs --check    regenerate in memory, fail if the committed file differs,
//                                              and validate it against api/provenance.schema.json (ajv from api/node_modules)
// Deterministic, no network, no timestamps. Reads only files of this repository. See docs/provenance.md.
import { readFileSync, writeFileSync, existsSync, readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const rd = (p) => readFileSync(join(root, p), 'utf8');
const exists = (p) => existsSync(join(root, p));
const OUT = 'api/provenance.json';
const fail = (m) => { console.error(`gen_provenance: ${m}`); process.exit(1); };

// ---------------------------------------------------------------- curated tables (reviewed by humans)
const FORM_PDF = 'sources/forms-instructions/f1040--2024.pdf';

/** Plain-English description of each line. */
const DESCRIPTION = {
  wages: 'Total of Form W-2 box 1 wages of the filer(s), each rounded to whole dollars.',
  employer_income_subtotal: 'Line 1z: sum of the employer-income lines 1a to 1h (here W-2 wages plus taxable dependent care benefits), rounded to whole dollars.',
  interest_income: 'Taxable interest from Forms 1099-INT (and the Schedule B threshold rule), rounded to whole dollars.',
  total_income: 'Line 9: employer income, interest, pensions, Social Security, unemployment and other income added together.',
  adjustments_to_income: 'Line 10: Schedule 1 adjustments (student loan interest, educator expenses, HSA deduction) added together.',
  agi: 'Line 11: adjusted gross income, total income minus adjustments.',
  standard_or_itemized_deductions: 'Line 12: the standard deduction for the filing status, age and blindness (itemized deductions are out of scope).',
  total_deductions: 'Line 14: total deductions. Direct File reproduces line 12 only (the qualified business income deduction is a $0 stub).',
  taxable_income: 'Line 15: AGI minus total deductions, never below zero.',
  tentative_tax_from_taxable_income: 'Line 16: tax on taxable income from the Tax Table (income under $100,000, row midpoint) or the rate schedules.',
  total_tentative_tax: 'Line 18: line 16 plus line 17 (excess advance premium tax credit repayment).',
  non_refundable_credits: 'Line 21: child tax credit / credit for other dependents (line 19) plus Schedule 3 non-refundable credits (line 20).',
  tax_less_non_refundable_credits: 'Line 22: line 18 minus line 21, never below zero.',
  total_tax: 'Line 24: total tax. Equals line 22 (line 23, other taxes, is $0 and not added; QUIRK Q3).',
  total_withholding: 'Line 25d: federal income tax withheld from Forms W-2 and 1099.',
  total_other_payments_refundable_credits: 'Line 32: earned income credit, additional child tax credit, American opportunity credit and other refundable credits.',
  total_payments: 'Line 33: withholding, estimated tax payments and refundable credits added together.',
  overpayment: 'Line 34: the amount overpaid (refund) when payments exceed total tax, else $0.',
  balance_due: 'Line 37: the amount owed when total tax exceeds payments, else $0.',
};

/** Statutory spine, curated: sections the line rests on that the Catala text does not (always) cite. origin "curated". */
const CURATED_STATUTES = {
  wages: [['61', '(a)(1)']],
  employer_income_subtotal: [['61', '(a)(1)']],
  interest_income: [['61', '(a)(4)']],
  total_income: [['61', '(a)']],
  adjustments_to_income: [['62', '(a)']],
  agi: [['62', '(a)']],
  standard_or_itemized_deductions: [['63', '(c)']],
  total_deductions: [['63', '(b)']],
  taxable_income: [['63', '(a)'], ['63', '(b)']],
  tentative_tax_from_taxable_income: [['1', '(j)(2)']],
  total_tentative_tax: [['1', '(j)'], ['36B', '(f)(2)']],
  non_refundable_credits: [['24', '(a)'], ['26', '(a)']],
  tax_less_non_refundable_credits: [['26', '(a)']],
  total_tax: [['26', '(a)']],
  total_withholding: [['31', '(a)(1)']],
  total_other_payments_refundable_credits: [['32', '(a)'], ['24', '(d)'], ['6401', '(b)']],
  total_payments: [['31', '(a)(1)'], ['6315', ''], ['6401', '(b)(1)']],
  overpayment: [['6401', '(b)(1)'], ['6402', '(a)']],
  balance_due: [['6151', '(a)']],
};

const MAIN = 'lean/UsTax/Proofs/Main.lean';
/** Lean theorems that cover a line, with what each one says about it (honest scope). Located by name at generation time. */
const T = {
  nonneg_monotone: [MAIN, 'tentativeTax_nonneg_monotone', 'main', 'Line 16 as a function of taxable income is nonnegative and monotone, for each filing status.'],
  matches_table: [MAIN, 'line16_matches_tax_table', 'main', 'On every return, line 16 equals the printed 2024 Tax Table amount of the row containing line 15. Covers taxable income below $100,000 only; vacuous above.'],
  matches_table_fn: [MAIN, 'tentativeTax_matches_tax_table', 'main', 'The line 16 function equals the printed Tax Table amount for every filing status and income in a table row.'],
  eq_spec: ['lean/UsTax/TaxRates/Spec.lean', 'tentativeTaxFor_eq_taxSpec', 'lemma', 'The line 16 function equals the rate-schedule specification `taxSpec` up to the $1-trillion sentinel. Not in the comparator set.'],
  rows_cover: ['lean/UsTax/Proofs/TaxTable.lean', 'rows_cover', 'lemma', 'Every cent of taxable income in [$0, $100,000) lies in some Tax Table row, so the table theorem is not vacuous there.'],
  ti_nonneg: ['lean/UsTax/Form1040/Lemmas.lean', 'taxableIncome_nonneg', 'lemma', 'Line 15 is never negative.'],
  credits: [MAIN, 'credits_within_liability', 'main', 'Line 22 = max 0 (line 18 - line 21): credits never exceed the tax and line 22 is never negative. Holds for whatever values line 21 takes.'],
  l22_eq: ['lean/UsTax/Proofs/Form1040.lean', 'taxLessNonRefundableCredits_eq', 'lemma', 'Line 22 as computed equals max 0 (line 18 - line 21).'],
  tax_nonneg: [MAIN, 'totalTax_nonneg', 'main', 'Line 24 is never negative.'],
  tax_eq: ['lean/UsTax/Proofs/Form1040.lean', 'totalTax_eq', 'lemma', 'Line 24 equals line 22 (line 23 is not added).'],
  refund: [MAIN, 'refund_balanceDue_consistent', 'main', 'Lines 34 and 37 are nonnegative, at most one is nonzero, and line 34 - line 37 = line 33 - line 24 (a full specification of both lines).'],
  over_eq: ['lean/UsTax/Proofs/Form1040.lean', 'overpayment_eq', 'lemma', 'Line 34 as computed equals max 0 (line 33 - line 24).'],
  owe_eq: ['lean/UsTax/Proofs/Form1040.lean', 'balanceDue_eq', 'lemma', 'Line 37 as computed equals max 0 (line 24 - line 33).'],
  over_nonneg: ['lean/UsTax/Form1040/Lemmas.lean', 'overpayment_nonneg', 'lemma', 'Line 34 is never negative.'],
  owe_nonneg: ['lean/UsTax/Form1040/Lemmas.lean', 'balanceDue_nonneg', 'lemma', 'Line 37 is never negative.'],
};
const THEOREMS = {
  tentative_tax_from_taxable_income: ['nonneg_monotone', 'matches_table', 'matches_table_fn', 'eq_spec', 'rows_cover'],
  taxable_income: ['ti_nonneg'],
  total_tentative_tax: ['credits'],
  non_refundable_credits: ['credits'],
  tax_less_non_refundable_credits: ['credits', 'l22_eq'],
  total_tax: ['tax_nonneg', 'tax_eq', 'refund'],
  total_payments: ['refund'],
  overpayment: ['refund', 'over_eq', 'over_nonneg'],
  balance_due: ['refund', 'owe_eq', 'owe_nonneg'],
};

/** Catala sub-scope instance name -> Lean module file and definition. */
const LEAN_SUB = {
  w2: ['lean/UsTax/FormW2s.lean', 'formW2s'],
  interest: ['lean/UsTax/Interest.lean', 'interest'],
  interest_ko: ['lean/UsTax/Interest.lean', 'interest'],
  std_deduction: ['lean/UsTax/StandardDeduction.lean', 'standardDeduction'],
  tax_table: ['lean/UsTax/TaxRates.lean', 'tentativeTax'],
};

// ---------------------------------------------------------------- Catala parsing
const catalaCache = new Map();
function parseCatala(path) {
  if (catalaCache.has(path)) return catalaCache.get(path);
  const lines = rd(path).split('\n');
  if (lines[lines.length - 1] === '') lines.pop();
  const inCode = [];
  let fence = false;
  lines.forEach((l, i) => { if (/^```/.test(l)) { inCode[i] = true; fence = !fence; } else inCode[i] = fence; });
  const headings = [];
  lines.forEach((l, i) => {
    if (inCode[i]) return;
    const m = /^(#{1,6})\s+(\S.*)$/.exec(l);
    if (m) headings.push({ level: m[1].length, title: m[2].trim(), start: i + 1 });
  });
  headings.forEach((h, k) => {
    let e = lines.length;
    for (let j = k + 1; j < headings.length; j++) if (headings[j].level <= h.level) { e = headings[j].start - 1; break; }
    h.end = e;
    const nx = headings[k + 1];
    h.ownEnd = nx ? nx.start - 1 : lines.length;
  });
  // definitions / rules, with their scope
  const defs = [];
  let scope = null;
  lines.forEach((l, i) => {
    if (!inCode[i]) return;
    const sm = /^\s*(?:declaration\s+)?scope\s+([A-Za-z0-9_]+)\s*:/.exec(l);
    if (sm) scope = sm[1];
    if (/^```/.test(l)) return;
    const dm = /^(\s*)(definition|rule)\s+([a-z_][A-Za-z0-9_.]*)/.exec(l);
    if (!dm) return;
    const ind = dm[1].length;
    let e = i;
    while (e + 1 < lines.length && inCode[e + 1] && lines[e + 1].trim() !== '' && !/^```/.test(lines[e + 1]) &&
      (lines[e + 1].length - lines[e + 1].trimStart().length) > ind) e++;
    let c = i;
    while (c > 0 && inCode[c - 1] && lines[c - 1].trim().startsWith('#') && (lines[c - 1].length - lines[c - 1].trimStart().length) === ind) c--;
    defs.push({ kind: dm[2], name: dm[3], scope, start: i + 1, end: e + 1, commentStart: c + 1 });
  });
  // declarations of a scope: output/input/context/internal NAME, sub-scopes, with the DF comment above
  const decls = [];
  lines.forEach((l, i) => {
    if (!inCode[i]) return;
    const m = /^\s+(output|input|context|internal)\s+([a-z_][A-Za-z0-9_]*)\s+(content|condition)(.*)$/.exec(l);
    if (m) {
      let df = null;
      for (let j = i - 1; j >= 0 && /^\s*#/.test(lines[j]); j--) {
        const d = /DF:.*?(\/[A-Za-z0-9_/]+)/.exec(lines[j]);
        if (d) { df = d[1]; break; }
      }
      decls.push({ role: m[1], name: m[2], line: i + 1, df });
    }
  });
  const subscopes = {};
  const aliases = {};
  lines.forEach((l) => {
    const u = /^>\s*Using\s+([A-Za-z0-9_]+)(?:\s+as\s+([A-Za-z0-9_]+))?/.exec(l);
    if (u) aliases[u[2] ?? u[1]] = u[1];
    const s = /^\s+([a-z_][A-Za-z0-9_]*)\s+scope\s+(?:([A-Za-z0-9_]+)\.)?([A-Za-z0-9_]+)\s*$/.exec(l);
    if (s) subscopes[s[1]] = { alias: s[2] ?? null, scope: s[3] };
  });
  const res = { path, lines, inCode, headings, defs, decls, subscopes, aliases };
  catalaCache.set(path, res);
  return res;
}
function nearestHeading(f, line) {
  let best = null;
  for (const h of f.headings) if (h.start <= line && line <= h.end && (!best || h.start >= best.start)) best = h;
  return best;
}
const CITE_HEAD = /(IRC|I\.R\.C\.|U\.S\.C\.|Treas\. ?Reg\.|Rev\. ?Proc\.|Notice \d{4}-\d+)/;
function statuteHeading(f, line) {
  let best = null;
  for (const h of f.headings) if (h.start <= line && line <= h.end && CITE_HEAD.test(h.title) && (!best || h.start >= best.start)) best = h;
  return best;
}
/** Line range scanned for citations around a definition: its comments, plus its nearest heading's section (own text only for level 1). */
function scanRange(f, def) {
  const h = nearestHeading(f, def.start);
  let from = def.commentStart, to = def.end;
  if (h) {
    const hi = h.level === 1 || h.end - h.start > 160 ? h.ownEnd : h.end;
    from = Math.min(from, h.start); to = Math.max(to, Math.min(hi, h.end));
  }
  return [from, to];
}

// ---------------------------------------------------------------- citations
const sourceFileIndex = () => {
  const m = new Map();
  for (const d of ['forms-instructions', 'pubs', 'revproc', 'statute', 'regs']) {
    for (const f of readdirSync(join(root, 'sources', d))) m.set(f, `sources/${d}/${f}`);
  }
  return m;
};
const SRC = sourceFileIndex();
const govinfo = (sec) => `https://www.govinfo.gov/link/uscode/26/${sec}?year=2024&type=usc&link-type=html`;

function statuteCite(sec, sub, origin, where) {
  const id = `usc:26:${sec}${sub}`;
  const local = SRC.get(`irc-${sec}.html`);
  return { id, kind: 'statute', label: `26 U.S.C. § ${sec}${sub}`, url: govinfo(sec), local: local ? { path: local } : null, origin, found_in: where ? [where] : [] };
}
function regCite(sec, sub, where) {
  const local = SRC.get(`cfr-${sec}.xml`);
  return { id: `cfr:26:${sec}${sub}`, kind: 'regulation', label: `Treas. Reg. § ${sec}${sub}`,
    url: `https://www.ecfr.gov/on/2024-12-31/title-26/section-${sec}`, local: local ? { path: local } : null, origin: 'catala', found_in: [where] };
}
function docCite(file, p1, p2, where) {
  let kind = 'irs_publication', base = 'https://www.irs.gov/pub/irs-prior/';
  if (/^rp-/.test(file)) { kind = 'revenue_procedure'; base = 'https://www.irs.gov/pub/irs-drop/'; }
  else if (/^n-/.test(file)) { kind = 'notice'; base = 'https://www.irs.gov/pub/irs-drop/'; }
  else if (/^i[0-9a-z]+--/.test(file)) kind = 'irs_instructions';
  else if (/^f[0-9a-z]+(--|\.)/.test(file)) { kind = 'irs_form'; if (file === 'f8332.pdf') base = 'https://www.irs.gov/pub/irs-pdf/'; }
  const lp = SRC.get(file);
  const pg = p1 ? (p2 ? `pp ${p1} to ${p2}` : `p ${p1}`) : '';
  const local = lp ? (p1 ? { path: lp, page: p1, ...(p2 ? { page_end: p2 } : {}) } : { path: lp }) : null;
  return { id: `doc:${file}${p1 ? `#p${p1}${p2 ? `-${p2}` : ''}` : ''}`, kind, label: `${file}${pg ? ` ${pg}` : ''}`,
    url: base + file + (p1 ? `#page=${p1}` : ''), local, origin: 'catala', found_in: [where] };
}
function revProcCite(yr, n, sec, where) {
  const file = `rp-${yr.slice(2)}-${n}.pdf`;
  const lp = SRC.get(file);
  return { id: `revproc:${yr}-${n}${sec ? `#${sec}` : ''}`, kind: 'revenue_procedure', label: `Rev. Proc. ${yr}-${n}${sec ? ` § ${sec}` : ''}`,
    url: `https://www.irs.gov/pub/irs-drop/${file}`, local: lp ? { path: lp } : null, origin: 'catala', found_in: [where] };
}
function noticeCite(yr, n, where) {
  const file = `n-${yr.slice(2)}-${n}.pdf`;
  const lp = SRC.get(file);
  return { id: `notice:${yr}-${n}`, kind: 'notice', label: `Notice ${yr}-${n}`, url: `https://www.irs.gov/pub/irs-drop/${file}`,
    local: lp ? { path: lp } : null, origin: 'catala', found_in: [where] };
}

/** Citations in lines [from, to] (1-based) of a Catala file. A line is joined with the next one so a wrapped citation is found. */
function scanCitations(f, from, to) {
  const out = [];
  for (let n = from; n <= to; n++) {
    const text = f.lines[n - 1] + ' ' + (f.lines[n] ?? '').trim();
    const cut = f.lines[n - 1].length; // only matches that start on this line
    const where = { file: f.path, line: n };
    const each = (re, fn) => { for (const m of text.matchAll(re)) if (m.index < cut) { const c = fn(m); if (c) out.push(c); } };
    each(/(?:\bIRC|\bI\.R\.C\.|\b26 U\.S\.C\.)\s*§?\s*(\d+[A-Z]?)((?:\([A-Za-z0-9]+\))*)/g, (m) => statuteCite(m[1], m[2], 'catala', where));
    each(/Treas\. ?Reg\.\s*§?\s*(1\.\d+[A-Z]?-\d+)((?:\([A-Za-z0-9]+\))*)/g, (m) => SRC.has(`cfr-${m[1]}.xml`) || true ? regCite(m[1], m[2], where) : null);
    each(/Rev\. ?Proc\.\s*(\d{4})-(\d+)(?:\s*§\s*(\d+(?:\.\d+)*))?/g, (m) => revProcCite(m[1], m[2], m[3] ?? '', where));
    each(/\bNotice\s+(\d{4})-(\d+)/g, (m) => noticeCite(m[1], m[2], where));
    each(/([a-z0-9]+(?:--2024)?\.pdf)`?(?:[,\s]*(?:PDF\s+)?pp?\s*(\d+)(?:\s*(?:to|-|–)\s*(\d+))?)?/g, (m) => docCite(m[1], m[2] ? +m[2] : 0, m[3] ? +m[3] : 0, where));
  }
  return out;
}
function mergeCites(list) {
  const byId = new Map();
  for (const c of list) {
    const e = byId.get(c.id);
    if (!e) byId.set(c.id, { ...c, found_in: [...c.found_in] });
    else {
      if (c.origin === 'catala' && e.origin !== 'catala') e.origin = 'catala';
      for (const w of c.found_in) if (!e.found_in.some((x) => x.file === w.file && x.line === w.line)) e.found_in.push(w);
    }
  }
  const order = { statute: 0, regulation: 1, revenue_procedure: 2, notice: 3, irs_form: 4, irs_instructions: 5, irs_publication: 6 };
  const arr = [...byId.values()];
  for (const c of arr) { c.found_in.sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line); c.found_in = c.found_in.slice(0, 6); }
  return arr.sort((a, b) => order[a.kind] - order[b.kind] || a.id.localeCompare(b.id, 'en', { numeric: true }));
}
const LEGAL = new Set(['statute', 'regulation', 'revenue_procedure', 'notice']);

// ---------------------------------------------------------------- Lean parsing
const leanCache = new Map();
function lean(path) {
  if (!leanCache.has(path)) {
    const lines = rd(path).split('\n'); if (lines[lines.length - 1] === '') lines.pop();
    leanCache.set(path, lines);
  }
  return leanCache.get(path);
}
/** Namespace in effect at 1-based `line` (single-line `namespace A.B` / `end A.B` only). */
function nsAt(lines, line) {
  const st = [];
  for (let i = 0; i < line; i++) {
    const m = /^namespace\s+(\S+)/.exec(lines[i]); if (m) st.push(m[1]);
    const e = /^end\s+(\S+)/.exec(lines[i]); if (e && st[st.length - 1] === e[1]) st.pop();
  }
  return st.join('.');
}
function blockEnd(lines, i0) { // 0-based start -> 1-based end of a top-level declaration
  let e = i0;
  while (e + 1 < lines.length && !/^(\/--|\/-|def |theorem |lemma |structure |inductive |namespace |end |open |private |instance |#|example |section |abbrev |@\[)/.test(lines[e + 1])) e++;
  while (e > i0 && lines[e].trim() === '') e--;
  return e + 1;
}
function leanDecl(path, kw, name) {
  const lines = lean(path);
  const re = new RegExp(`^(?:private\\s+|protected\\s+)?${kw}\\s+${name}\\b`);
  const i = lines.findIndex((l) => re.test(l));
  if (i < 0) fail(`${path}: no ${kw} ${name}`);
  let ds = i;
  if (i > 0 && /-\/\s*$/.test(lines[i - 1])) { let j = i - 1; while (j > 0 && !/^\/--/.test(lines[j])) j--; ds = j; }
  return { i, start: i + 1, end: blockEnd(lines, i), docStart: ds + 1, ns: nsAt(lines, i + 1) };
}
function leanTheorem(path, name, role, covers) {
  const lines = lean(path);
  const d = leanDecl(path, '(?:theorem|lemma)', name);
  let s = ''; let k = d.i;
  while (k < lines.length) { s += (s ? ' ' : '') + lines[k].trim(); if (/:=/.test(lines[k]) || /:\s*$/.test(lines[k]) && false) break; k++; }
  const statement = s.replace(/\s*:=.*$/, '').replace(/\s+/g, ' ').trim();
  const qualified = `${d.ns}.${name}`;
  const cmp = JSON.parse(rd('lean/comparator.json')).theorem_names;
  return { name, qualified, file: path, start: d.start, end: d.end, kind: role, in_comparator_set: cmp.includes(qualified), statement, covers };
}
const camel = (s) => s.replace(/_([a-z0-9])/g, (_, c) => c.toUpperCase());

// ---------------------------------------------------------------- difftest mappings
function testMappings() {
  const dir = 'difftest/mappings';
  const inputsOutputs = (() => {
    const t = rd('difftest/form_1040_inputs.mjs');
    const i = t.indexOf('export const outputs');
    return t.slice(i, t.indexOf('.map(', i));
  })();
  return readdirSync(join(root, dir)).filter((f) => f.endsWith('.mjs')).sort().map((f) => {
    const t = rd(`${dir}/${f}`);
    const name = /name:\s*'([^']+)'/.exec(t)?.[1];
    const scope = /scope:\s*'([^']+)'/.exec(t)?.[1];
    const file = /file:\s*'([^']+)'/.exec(t)?.[1];
    const oi = t.search(/\boutputs\b\s*[:,]/);
    const quoted = new Set([...(oi >= 0 ? t.slice(oi) : '').matchAll(/'([A-Za-z0-9_/]+)'/g)].map((m) => m[1]));
    if (/from '\.\.\/form_1040_inputs\.mjs'/.test(t) && /\boutputs\b/.test(t)) for (const m of inputsOutputs.matchAll(/'([A-Za-z0-9_/]+)'/g)) quoted.add(m[1]);
    return { path: `${dir}/${f}`, name, scope, file, quoted, reportOnly: /reportOnly:\s*true/.test(t) };
  }).filter((m) => m.name);
}

// ---------------------------------------------------------------- main build
function build() {
  const catalog = JSON.parse(rd('api/line-catalog.json')).lines;
  const schema = JSON.parse(rd('api/schema.json'));
  const schemaKeys = schema.$defs.Lines.required;
  if (JSON.stringify([...schemaKeys].sort()) !== JSON.stringify(catalog.map((l) => l.key).sort())) fail('schema Lines.required differs from api/line-catalog.json');
  const FORM = 'catala/form_1040.catala_en';
  const f = parseCatala(FORM);
  const mappings = testMappings();
  const calcTests = ['catala/tests/test_form_1040.catala_en', 'catala/tests/test_calculator.catala_en'].filter(exists);
  const slotTable = new Map(); // slot name -> filled-by text
  for (const l of f.lines) {
    const m = /^\|\s*`([a-z0-9_]+)`\s*\|[^|]*\|[^|]*\|\s*([^|]+?)\s*\|\s*$/.exec(l);
    if (m) slotTable.set(m[1], m[2]);
  }
  const outputs = new Set(f.decls.filter((d) => d.role === 'output').map((d) => d.name));
  const slots = new Set(f.decls.filter((d) => d.role === 'context').map((d) => d.name));
  const headerForm = f.lines.findIndex((l) => /Form text is quoted from/.test(l)) + 1;
  const keyOfVar = new Map(catalog.map((l) => [l.catala_output.split('.').pop(), l.key]));
  const fileRefs = new Set();
  const lines = {};
  const cov = {};

  for (const ent of catalog) {
    const key = ent.key;
    const variable = ent.catala_output.split('.').pop();
    const scopeName = ent.catala_output.split('.')[1];
    const def = f.defs.find((d) => d.name === variable && d.scope === scopeName && d.kind === 'definition');
    if (!def) fail(`no Catala definition for ${ent.catala_output}`);
    const decl = f.decls.find((d) => d.name === variable && d.role === 'output');
    const heading = nearestHeading(f, def.start);
    const sh = statuteHeading(f, def.start);
    const body = f.lines.slice(def.start - 1, def.end).map((l) => l.replace(/#.*$/, '')).join('\n');

    // dependencies
    const depLines = [], depSlots = [], feeds = [];
    for (const m of new Set(body.match(/[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?/g) ?? [])) {
      if (m === variable) continue;
      if (m.includes('.')) {
        const [inst, v] = m.split('.');
        const sub = f.subscopes[inst];
        if (sub) {
          const mod = sub.alias ? f.aliases[sub.alias] : null;
          const mfile = mod ? `catala/${mod.toLowerCase()}.catala_en` : null;
          if (!mfile || !exists(mfile)) continue;
          const mf = parseCatala(mfile);
          const md = mf.defs.find((d) => d.name === v && d.scope === sub.scope) ?? mf.defs.find((d) => d.name === v);
          feeds.push({ instance: inst, file: mfile, scope: sub.scope, variable: v, definition: md ? { start: md.start, end: md.end } : null, _md: md });
        }
      } else if (outputs.has(m)) depLines.push(m);
      else if (slots.has(m)) depSlots.push(m);
    }
    feeds.sort((a, b) => a.file.localeCompare(b.file) || a.variable.localeCompare(b.variable));

    // citations
    const [rf, rt] = scanRange(f, def);
    let cites = scanCitations(f, rf, rt);
    const pg = (/^\d+/.test(ent.line) ? parseInt(ent.line, 10) : 99) <= 15 ? 1 : 2;
    cites.push(docCite('f1040--2024.pdf', pg, 0, { file: FORM, line: headerForm }));
    const feedOut = feeds.map((fd) => {
      const mf = parseCatala(fd.file);
      let sc = [];
      if (fd._md) {
        sc = scanCitations(mf, fd._md.commentStart, fd._md.end);
        // module-level legal basis: statute headings of the module
        for (const h of mf.headings) if (CITE_HEAD.test(h.title)) sc = sc.concat(scanCitations(mf, h.start, h.start));
        cites = cites.concat(sc);
      }
      const h = fd._md ? nearestHeading(mf, fd._md.start) : null;
      const sth = fd._md ? statuteHeading(mf, fd._md.start) : null;
      fileRefs.add(fd.file);
      const { _md, ...rest } = fd;
      return { ...rest, heading: h && { title: h.title, start: h.start, end: h.end }, statute_heading: sth && { title: sth.title, start: sth.start, end: sth.end } };
    });
    for (const [sec, sub] of CURATED_STATUTES[key] ?? []) cites.push(statuteCite(sec, sub, 'curated', null));
    const citations = mergeCites(cites);

    // quirks: ids in the definition comments or in prose paragraphs of its section that name the variable or DF fact
    const quirks = new Map();
    const scanQ = (a, b, needle) => {
      let para = [], pstart = a;
      const flush = () => { const t = para.join('\n'); if (!needle || needle.some((n) => t.includes(n))) for (const m of t.matchAll(/QUIRK\((Q\d+)\)/g)) if (!quirks.has(m[1])) quirks.set(m[1], pstart); para = []; };
      for (let n = a; n <= b; n++) { if (f.lines[n - 1].trim() === '') { flush(); pstart = n + 1; } else para.push(f.lines[n - 1]); }
      flush();
    };
    scanQ(def.commentStart, def.end, null);
    if (heading) scanQ(heading.start, heading.end, [`\`${decl?.df ?? '@@'}\``, `\`${variable}\``, `${decl?.df ?? '@@'}`].filter((x) => !x.includes('@@')));

    const used = THEOREMS[key] ?? [];
    const theorems = used.map((id) => leanTheorem(T[id][0], T[id][1], T[id][2], T[id][3]));
    for (const t of theorems) fileRefs.add(t.file);

    // Lean implementation
    const lf = 'lean/UsTax/Form1040.lean';
    const ll = lean(lf);
    const fn = leanDecl(lf, 'def', 'form1040');
    const cname = camel(variable);
    let li = -1, form = '';
    for (let i = fn.i; i < fn.end; i++) {
      if (new RegExp(`^\\s+let ${cname} :=`).test(ll[i])) { li = i; form = 'let'; break; }
    }
    if (li < 0) for (let i = fn.i; i < fn.end; i++) if (new RegExp(`^\\s+${cname} := `).test(ll[i])) { li = i; form = 'field'; break; }
    if (li < 0) fail(`no Lean binding for ${cname}`);
    const ind = ll[li].length - ll[li].trimStart().length;
    let le = li;
    while (le + 1 < fn.end && ll[le + 1].trim() !== '' && (ll[le + 1].length - ll[le + 1].trimStart().length) > ind) le++;
    const fieldIdx = ll.findIndex((l) => new RegExp(`^  ${cname} : `).test(l));
    fileRefs.add(lf);
    const leanFeeds = [...new Set(feeds.map((x) => x.instance))].filter((i) => LEAN_SUB[i]).map((i) => {
      const [p, n] = LEAN_SUB[i];
      const d = leanDecl(p, 'def', n);
      fileRefs.add(p);
      return { instance: i, file: p, definition: `${d.ns}.${n}`, start: d.start, end: d.end };
    });

    // tests
    const ownFiles = new Set([FORM, 'catala/calculator.catala_en', ...feeds.map((x) => x.file)]);
    const tests = mappings.filter((m) => ownFiles.has(m.file) && m.quoted.has(variable) && (m.file === FORM || m.file === 'catala/calculator.catala_en' || feeds.some((x) => x.file === m.file && x.variable === variable))).map((m) => ({
      mapping: m.name, mapping_file: m.path, catala_scope: m.scope, catala_file: m.file,
      role: m.scope === 'Form1040' || m.scope === 'Calculator' ? 'whole_return' : 'module', report_only: m.reportOnly,
    }));
    const unit = calcTests.filter((p) => new RegExp(`\\b${variable}\\b`).test(rd(p)));
    unit.forEach((p) => fileRefs.add(p));

    fileRefs.add(FORM);
    const dfPath = decl?.df ?? null;
    cov[key] = { df: !!dfPath, df_matches_catalog: dfPath === ent.df_fact, legal_catala: citations.some((c) => LEGAL.has(c.kind) && c.origin === 'catala'),
      legal_any: citations.some((c) => LEGAL.has(c.kind)), theorems: theorems.length, tests: tests.length };
    lines[key] = {
      key,
      form: { form: ent.form, line: ent.line, label: ent.label, pdf: { path: FORM_PDF, page: pg, url: `https://www.irs.gov/pub/irs-prior/f1040--2024.pdf#page=${pg}` } },
      description: DESCRIPTION[key] ?? fail(`no description for ${key}`),
      direct_file_fact: { path: dfPath, source: dfPath ? { file: FORM, line: decl.line } : null, matches_line_catalog: dfPath === ent.df_fact, line_catalog_path: ent.df_fact },
      rule: {
        kind: 'catala',
        status: 'Readable specification in Catala, validated by differential testing against the Direct File oracle. NOT a proof.',
        file: FORM, scope: scopeName, variable,
        definition: { start: def.start, end: def.end, comment_start: def.commentStart },
        heading: heading && { title: heading.title, level: heading.level, start: heading.start, end: heading.end },
        statute_heading: sh && { title: sh.title, level: sh.level, start: sh.start, end: sh.end },
        depends_on: { lines: depLines.map((v) => ({ variable: v, api_key: keyOfVar.get(v) ?? null })), slots: depSlots.map((s) => ({ slot: s, filled_by: slotTable.get(s) ?? null })) },
        feeds: feedOut,
        quirks: [...quirks].map(([id, line]) => ({ id, line })),
      },
      citations,
      proofs: {
        kind: 'lean_theorems',
        status: theorems.length
          ? 'Machine-checked Lean theorems (axioms: propext, Classical.choice, Quot.sound; see docs/spec-surface.md). They cover only what each `covers` text says.'
          : 'No Lean theorem covers this line. Its Lean value is checked only by differential tests.',
        theorems,
      },
      lean: {
        kind: 'lean_implementation',
        file: lf, module: 'UsTax.Form1040', definition: 'UsTax.Form1040.form1040', field: `Form1040Out.${cname}`,
        binding: { form, start: li + 1, end: le + 1 }, field_line: fieldIdx >= 0 ? fieldIdx + 1 : null,
        feeds: leanFeeds,
      },
      tests: {
        kind: 'differential_tests',
        status: 'Evidence, not proof: Catala (and Lean) outputs compared with the Direct File reference engine on scenarios. Scenario counts are deliberately not stored.',
        difftest: tests,
        catala_unit_tests: unit.map((p) => ({ file: p })),
      },
    };
  }

  // files index
  const files = [...fileRefs].sort().map((p) => {
    const buf = readFileSync(join(root, p));
    const text = buf.toString('utf8');
    const n = text.split('\n').length - (text.endsWith('\n') ? 1 : 0);
    return { path: p, kind: p.endsWith('.lean') ? 'lean' : p.includes('/tests/') ? 'catala_test' : 'catala', sha256: createHash('sha256').update(buf).digest('hex'), lines: n };
  });
  const N = catalog.length;
  const count = (fn) => Object.values(cov).filter(fn).length;
  const lacking = (fn) => Object.keys(cov).filter((k) => !fn(cov[k]));
  const coverage = {
    line_items: N,
    with_catala_rule: N,
    with_legal_citation_found_in_catala: count((c) => c.legal_catala),
    without_legal_citation_found_in_catala: lacking((c) => c.legal_catala),
    with_legal_citation_any_origin: count((c) => c.legal_any),
    with_direct_file_fact: count((c) => c.df),
    direct_file_fact_matches_line_catalog: count((c) => c.df_matches_catalog),
    with_lean_theorem: count((c) => c.theorems > 0),
    without_lean_theorem: lacking((c) => c.theorems > 0),
    with_difftest: count((c) => c.tests > 0),
    without_difftest: lacking((c) => c.tests > 0),
  };
  return {
    $schema: './provenance.schema.json',
    schema_version: '1.0.0',
    tax_year: 2024,
    generator: 'scripts/gen_provenance.mjs',
    sources_index: 'sources/INDEX.md',
    field_meanings: {
      rule: 'Catala source: the readable specification. Validated by differential testing. It is NOT a proof and must never be labelled as proved.',
      proofs: 'Lean theorems: machine-checked statements about the Lean implementation. Only these may be labelled proved, and only for what `covers` says.',
      tests: 'Differential tests (difftest/mappings): evidence that Catala and Lean agree with Direct File on scenarios. Not a proof.',
      citations: 'Law behind the rule. origin "catala": found in the Catala headings or comments (see found_in). origin "curated": added by hand in scripts/gen_provenance.mjs for human review.',
    },
    coverage,
    lines,
    files,
  };
}

// ---------------------------------------------------------------- run
const text = JSON.stringify(build(), null, 2) + '\n';
if (process.argv.includes('--check')) {
  if (!exists(OUT)) fail(`${OUT} is missing: run node scripts/gen_provenance.mjs`);
  if (rd(OUT) !== text) fail(`${OUT} is stale: run node scripts/gen_provenance.mjs and commit the result`);
  const req = createRequire(join(root, 'api/package.json'));
  let Ajv2020;
  try { Ajv2020 = req('ajv/dist/2020.js'); } catch { fail('ajv not found: run `cd api && npm ci`'); }
  const ajv = new (Ajv2020.default ?? Ajv2020)({ allErrors: true, strict: false });
  const validate = ajv.compile(JSON.parse(rd('api/provenance.schema.json')));
  const data = JSON.parse(text);
  if (!validate(data)) { console.error(JSON.stringify(validate.errors.slice(0, 10), null, 2)); fail('provenance.json does not match api/provenance.schema.json'); }
  const cat = JSON.parse(rd('api/line-catalog.json')).lines.map((l) => l.key);
  if (JSON.stringify(Object.keys(data.lines)) !== JSON.stringify(cat)) fail('lines differ from api/line-catalog.json');
  for (const [k, v] of Object.entries(data.lines)) {
    if (!v.citations.some((c) => ['statute', 'regulation', 'revenue_procedure', 'notice'].includes(c.kind))) fail(`${k}: no legal citation`);
  }
  for (const fl of data.files) {
    const b = readFileSync(join(root, fl.path));
    if (createHash('sha256').update(b).digest('hex') !== fl.sha256) fail(`${fl.path}: sha256 differs`);
  }
  console.log(`provenance-check: ${Object.keys(data.lines).length} line items, ${data.files.length} files, up to date and schema-valid`);
} else {
  writeFileSync(join(root, OUT), text);
  console.log(`wrote ${OUT}`);
}
