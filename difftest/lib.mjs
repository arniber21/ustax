// Core of the differential test runner (see catala/DIFFTEST.md). No dependencies; node >= 18.
// Pure functions live here so selftest.mjs can test them without invoking Catala.

import { readFileSync } from 'node:fs';

// ---------------------------------------------------------------------------------------------
// Oracle CSV: scenario,path,value,completeness (RFC 4180 quoting, "" escapes).
// ---------------------------------------------------------------------------------------------

export function parseCsv(text) {
  const rows = [];
  let row = [], field = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) {
      if (c === '"') { if (text[i + 1] === '"') { field += '"'; i++; } else q = false; }
      else field += c;
    } else if (c === '"') q = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field); field = '';
      rows.push(row); row = [];
    } else field += c;
  }
  if (field !== '' || row.length) { row.push(field); rows.push(row); }
  return rows;
}

/** Load oracle CSV into Map<scenario, Map<path, {value, completeness}>> (file order kept). */
export function loadOracle(file) {
  const rows = parseCsv(readFileSync(file, 'utf8'));
  const [header, ...body] = rows;
  if (header.join(',') !== 'scenario,path,value,completeness') throw new Error(`unexpected CSV header: ${header}`);
  const out = new Map();
  for (const r of body) {
    if (r.length !== 4) continue; // blank trailing line
    const [s, p, v, c] = r;
    if (!out.has(s)) out.set(s, new Map());
    out.get(s).set(p, { value: v, completeness: c });
  }
  return out;
}

// ---------------------------------------------------------------------------------------------
// Knock-out policy (oracle/README.md): flowIsKnockedOut = true (Complete) is out of scope.
// `false` is only ever `Placeholder` for 157/161 scenarios and means "not knocked out".
// ---------------------------------------------------------------------------------------------

export function isKnockedOut(facts) {
  const k = facts.get('/flowIsKnockedOut');
  return !!k && k.value === 'true';
}

// ---------------------------------------------------------------------------------------------
// Typed values. All comparisons go through canonical forms:
//   money -> integer cents (bigint), int -> bigint, bool -> boolean, string -> string.
// ---------------------------------------------------------------------------------------------

/** Parse an oracle CSV string value ("39674.00", "true", ...) as `type`. */
export function parseOracleValue(type, s) {
  switch (type) {
    case 'money': return parseMoney(s);
    case 'int': if (!/^-?\d+$/.test(s)) throw new Error(`bad int ${JSON.stringify(s)}`); return BigInt(s);
    case 'bool': if (s !== 'true' && s !== 'false') throw new Error(`bad bool ${JSON.stringify(s)}`); return s === 'true';
    case 'string': return s;
    default: throw new Error(`unknown type ${type}`);
  }
}

/** "39674.00", "-5", "$1,234.50", "-$5.00" -> bigint cents. Rejects more than 2 decimals. */
export function parseMoney(s) {
  const m = /^(-?)\$?(-?)([\d,]+)(?:\.(\d{1,2}))?$/.exec(s.trim());
  if (!m) throw new Error(`bad money ${JSON.stringify(s)}`);
  const neg = (m[1] + m[2]) !== '';
  const cents = BigInt(m[3].replace(/,/g, '')) * 100n + BigInt((m[4] ?? '').padEnd(2, '0') || '0');
  return neg ? -cents : cents;
}

export function showValue(type, v) {
  if (type === 'money') {
    const neg = v < 0n, a = neg ? -v : v;
    return `${neg ? '-' : ''}${a / 100n}.${String(a % 100n).padStart(2, '0')}`;
  }
  return String(v);
}

/** Format a typed value as a Catala JSON input literal. */
export function toCatalaJson(type, v) {
  switch (type) {
    case 'money': return Number(showValue('money', v)); // two decimals, exact in a double
    case 'int': return Number(v);
    default: return v;
  }
}

/** Parse the textual value Catala's interpreter prints (`$1,234.50`, `true`, `42`, enum name). */
export function parseCatalaValue(type, s) {
  s = s.trim();
  switch (type) {
    case 'money': return parseMoney(s);
    case 'int': return BigInt(s);
    case 'bool': if (s !== 'true' && s !== 'false') throw new Error(`bad bool ${s}`); return s === 'true';
    default: return s;
  }
}

/** Extract `name = value` outputs from the `[RESULT]` block of `clerk run` / `catala interpret`. */
export function parseCatalaResult(text) {
  const clean = text.replace(/\x1b\[[0-9;]*m/g, '');
  const out = new Map();
  let inResult = false;
  for (const line of clean.split('\n')) {
    if (/^┌─\[RESULT\]/.test(line)) { inResult = true; continue; }
    if (!inResult) continue;
    if (line.startsWith('└')) break;
    const m = /^│ ([A-Za-z_][A-Za-z0-9_]*) = (.*)$/.exec(line);
    if (m) out.set(m[1], m[2]);
  }
  return out;
}

// ---------------------------------------------------------------------------------------------
// Input-mapping helpers (used by difftest/mappings/*.mjs). Each returns a function
// facts:Map<path,{value,completeness}> -> JSON value for one Catala input.
// ---------------------------------------------------------------------------------------------

/** Item ids of a Collection fact (`/formW2s` value is ids joined by ';'), in oracle order. */
export function collectionIds(facts, collectionPath) {
  const c = facts.get(collectionPath);
  return c && c.value !== '' ? c.value.split(';') : [];
}

/**
 * Catala `list of T` built from a per-item writable fact of a collection.
 * `missing` is the value used when the item has no row for `field` (Direct File: an unanswered
 * optional fact; pass `null` to drop the item instead).
 */
export function listFromCollection(collectionPath, field, { type = 'money', missing = null } = {}) {
  return (facts) => {
    const vals = [];
    for (const id of collectionIds(facts, collectionPath)) {
      const r = facts.get(`${collectionPath}/#${id}/${field}`);
      if (r && r.completeness === 'Complete') vals.push(toCatalaJson(type, parseOracleValue(type, r.value)));
      else if (missing !== null) vals.push(toCatalaJson(type, parseOracleValue(type, missing)));
    }
    return vals;
  };
}

/** Catala scalar input from one top-level fact; `missing` (string) if absent/Incomplete, else error. */
export function scalar(path, { type = 'money', missing } = {}) {
  return (facts) => {
    const r = facts.get(path);
    if (r && r.completeness !== 'Incomplete') return toCatalaJson(type, parseOracleValue(type, r.value));
    if (missing === undefined) throw new Error(`scenario has no value for ${path}`);
    return toCatalaJson(type, parseOracleValue(type, missing));
  };
}

// ---------------------------------------------------------------------------------------------
// Comparison. Returns one result record per mapped output.
// ---------------------------------------------------------------------------------------------

/**
 * status: 'pass' | 'fail' | 'unchecked' (oracle row not Complete, so there is no confirmed
 * expected value; never counted as pass) | 'error' (Catala produced no value for the output).
 */
export function compareOutputs(mapping, facts, catalaOut) {
  const results = [];
  for (const o of mapping.outputs) {
    const exp = facts.get(o.oracle);
    const base = { path: o.oracle, catala: o.catala };
    if (!exp || exp.completeness !== 'Complete') {
      results.push({ ...base, status: 'unchecked', expected: exp ? `<${exp.completeness}>` : '<no row>', actual: catalaOut.get(o.catala) ?? '<none>' });
      continue;
    }
    const expected = parseOracleValue(o.type, exp.value);
    if (!catalaOut.has(o.catala)) {
      results.push({ ...base, status: 'error', expected: showValue(o.type, expected), actual: '<no output>' });
      continue;
    }
    const actual = parseCatalaValue(o.type, catalaOut.get(o.catala));
    results.push({ ...base, status: actual === expected ? 'pass' : 'fail',
      expected: showValue(o.type, expected), actual: showValue(o.type, actual) });
  }
  return results;
}
