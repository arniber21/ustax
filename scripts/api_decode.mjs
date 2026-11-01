// TEST-ONLY, UNTRUSTED: decodes an API request (api/schema.json, `CalculateRequest`) into the JSON input of the
// Catala scope `ApiCalculator` (catala/api_calculator.catala_en), and encodes its outputs into an API response.
// The specification of both steps is docs/api-mapping.md ("Decoding"); this file is one implementation of it
// (the Lean server, #51/#52, is the other). The decoder is driven by api/schema.json: every absent property gets
// the schema `default` (else false, 0, [], the first enum value), money divides by 100 (cents -> dollars), and the
// few renames below are applied.
//
//   node scripts/api_decode.mjs <request.json>      print the Catala input JSON
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const schema = JSON.parse(readFileSync(join(root, 'api/schema.json'), 'utf8'));
const defs = schema.$defs;
const MONEY = new Set(['#/$defs/Money', '#/$defs/NonNegMoney']);

// Properties with no schema default that the Catala side reads together with a `<name>_given` flag.
const OPTIONAL_DATES = { FilerFlags: { date_of_birth: '1985-06-15' }, Form1099R: { recipient_date_of_birth: '1980-01-01' } };
// Enum defaults that are not constructors of the wire enum (Catala: `Unspecified`).
const UNSPECIFIED = { FilingAnswers: ['marital_status', 'year_of_spouse_death'] };
export const UNSPECIFIED_PROPS = UNSPECIFIED;
const CODE_CHAR = { 2: 'Code2', 4: 'Code4', 7: 'Code7', B: 'CodeB', G: 'CodeG', H: 'CodeH', Other: 'OtherCode' };

const refName = (node) => (node.$ref ? node.$ref.replace('#/$defs/', '') : undefined);

function defaultOf(node, name) {
  if (node.default !== undefined) return node.default;
  if (node.$ref) return MONEY.has(node.$ref) ? 0 : defaultOf(defs[refName(node)], refName(node));
  if (node.enum) return node.enum[0];
  switch (node.type) {
    case 'boolean': return false;
    case 'integer': return 0;
    case 'array': return [];
    case 'string': return '';
    case 'object': return decodeObject({}, node, name);
    default: throw new Error('no default for ' + JSON.stringify(node));
  }
}

function decodeObject(value, node, name) {
  const out = {};
  const props = node.properties ?? {};
  if (name === 'W2Box12') {
    for (const k of Object.keys(props)) out[`code_${k.toLowerCase()}`] = value[k] === undefined ? 0 : value[k] / 100;
    return out;
  }
  for (const [k, prop] of Object.entries(props)) {
    const present = value[k] !== undefined;
    if (OPTIONAL_DATES[name]?.[k]) {
      out[`${k}_given`] = present;
      out[k] = present ? value[k] : OPTIONAL_DATES[name][k];
    } else if (UNSPECIFIED[name]?.includes(k)) {
      out[k] = present ? value[k] : 'Unspecified';
    } else if (name === 'Form1099R' && k === 'distribution_code') {
      out[k] = (value[k] ?? []).map((c) => CODE_CHAR[c]);
    } else {
      out[k] = decode(value[k], prop);
    }
  }
  return out;
}

export function decode(value, node) {
  if (node.$ref && MONEY.has(node.$ref)) return value === undefined ? (node.default ?? 0) : value / 100;
  if (value === undefined) return defaultOf(node);
  const name = refName(node);
  const target = name ? defs[name] : node;
  if (target.type === 'object') return decodeObject(value, target, name);
  if (target.type === 'array') return value.map((x) => decode(x, target.items));
  return value;
}

/** API request -> JSON input of the Catala scope ApiCalculator (`{ request: ... }` is the scope input). */
export function decodeRequest(req) {
  const node = defs.CalculateRequest;
  const out = {};
  for (const [k, prop] of Object.entries(node.properties)) {
    if (k === 'api_version' || k === 'tax_year') continue;
    out[k] = k === 'filing_status' ? req[k] : decode(req[k], prop);
  }
  // social_security.federal_tax_withheld is padded with $0 to the length of net_benefits
  const ss = out.social_security;
  while (ss.federal_tax_withheld.length < ss.net_benefits.length) ss.federal_tax_withheld.push(0);
  return out;
}

if (process.argv[1] === fileURLToPath(import.meta.url) && process.argv[2]) {
  console.log(JSON.stringify(decodeRequest(JSON.parse(readFileSync(process.argv[2], 'utf8'))), null, 1));
}
