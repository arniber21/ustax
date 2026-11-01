// TEST-ONLY, UNTRUSTED: run the Catala scope ApiCalculator on an API request and produce the API response
// (docs/api-mapping.md). Decode: scripts/api_decode.mjs. Encode: lines dollars -> cents, outcome and category
// constructors -> wire strings, reason `code` = the innermost constructor name.
//
//   node scripts/api_catala.mjs <request.json> [--out response.json]
// needs `clerk` on PATH (export PATH=$HOME/.opam/default/bin:$PATH).
import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { decodeRequest } from './api_decode.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const CATALA_FILE = join(root, 'catala/api_calculator.catala_en');
const reasonsCatalog = JSON.parse(readFileSync(join(root, 'api/knockout-reasons.json'), 'utf8'));
const byCode = new Map(reasonsCatalog.reasons.map((r) => [r.code, r]));

const snake = (s) => s.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();
const human = (s) => s.replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/^\w/, (x) => x.toUpperCase());
const cents = (s) => {
  const m = /^(-?)\$([\d,]+)\.(\d\d)$/.exec(s.trim());
  if (!m) throw new Error(`not a money value: ${s}`);
  return Number(`${m[1]}${m[2].replace(/,/g, '')}${m[3]}`);
};

/** Parse the `[RESULT]` block printed by `clerk run` for ApiCalculator. */
export function parseResult(text) {
  const lines = text.split('\n').filter((l) => l.startsWith('│ ')).map((l) => l.slice(2));
  const body = lines.join('\n');
  const supported = /^supported = (true|false)$/m.exec(body)?.[1];
  const outcome = /^outcome = (\w+)$/m.exec(body)?.[1];
  if (supported === undefined || outcome === undefined) throw new Error('no RESULT block:\n' + text.slice(-800));
  const linesBlock = /^lines =\n([\s\S]*?)\n\s*\}/m.exec(body)?.[1] ?? '';
  const lineItems = {};
  for (const m of linesBlock.matchAll(/-- (\w+): (-?\$[\d,.]+)/g)) lineItems[m[1]] = cents(m[2]);
  const reasonsText = /^reasons =([\s\S]*?)(?=^lines =)/m.exec(body)?.[1] ?? '';
  const reasons = [];
  for (const m of reasonsText.matchAll(/-- code: ([\w ]+?)\s+-- category: (\w+)/g)) {
    const code = m[1].replace(/^(?:IncomeOrHsa|Household) content /, '').trim();
    reasons.push({ code, category: snake(m[2]) });
  }
  return { supported: supported === 'true', outcome: { Refund: 'refund', BalanceDue: 'balance_due', Even: 'even' }[outcome], lines: lineItems, reasons };
}

/** The API response (200 body or 422 body) for a parsed Catala result. */
export function toResponse(r) {
  const base = { api_version: 1, tax_year: 2024, supported: r.supported };
  if (!r.supported) {
    return { ...base, reasons: r.reasons.map(({ code, category }) => ({ code, category, message: byCode.get(code)?.message ?? human(code) })) };
  }
  return { ...base, reasons: [], outcome: r.outcome, lines: r.lines };
}

export function runCatalaRequest(req, name = 'request') {
  const dir = join(root, '_build/api');
  mkdirSync(dir, { recursive: true });
  const inFile = join(dir, `${name}.input.json`);
  writeFileSync(inFile, JSON.stringify({ request: decodeRequest(req) }, null, 1) + '\n');
  const r = spawnSync('clerk', ['run', '-s', 'ApiCalculator', `--input=${inFile}`, '--color=never', CATALA_FILE], { cwd: root, encoding: 'utf8' });
  return parseResult((r.stdout || '') + '\n' + (r.stderr || ''));
}

if (process.argv[1] === fileURLToPath(import.meta.url) && process.argv[2]) {
  const file = process.argv[2];
  const res = toResponse(runCatalaRequest(JSON.parse(readFileSync(file, 'utf8')), 'cli'));
  const i = process.argv.indexOf('--out');
  const text = JSON.stringify(res, null, 2) + '\n';
  if (i > 0) writeFileSync(process.argv[i + 1], text); else process.stdout.write(text);
}
