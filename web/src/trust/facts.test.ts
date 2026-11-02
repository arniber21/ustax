import { describe, expect, it } from 'vitest';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { AS_OF, BUGS, CATALA, EXTRA, MAIN, OTHER_PROOFS, STATUS_CLAIMS, TESTED, type ProofSet } from './facts';

/**
 * The trust page cannot drift silently: every theorem it lists is in the Comparator config in the
 * repository (and the other way round), is written in the statement file and proved in the proof file,
 * and the counts match the files they come from.
 */
const root = join(dirname(fileURLToPath(import.meta.url)), '../../..');
const read = (p: string) => readFileSync(join(root, p), 'utf8');
const names = (cfg: string): string[] => (JSON.parse(read(cfg)) as { theorem_names: string[] }).theorem_names;
const short = (n: string) => n.slice(n.lastIndexOf('.') + 1);
const hasTheorem = (src: string, n: string) => new RegExp(`theorem ${short(n)}\\b`).test(src);

describe.each([
  ['main', MAIN],
  ['additional', EXTRA],
] as [string, ProofSet][])('%s theorem list', (_label, set) => {
  it('equals the theorem_names of its comparator config, exactly', () => {
    const listed = set.theorems.map((t) => t.name);
    expect(new Set(listed).size).toBe(listed.length);
    expect([...listed].sort()).toEqual([...names(set.config)].sort());
  });

  it('points at files that exist, with each statement written and proved there', () => {
    for (const f of [set.config, set.statementsFile, set.proofsFile]) expect(existsSync(join(root, f)), f).toBe(true);
    const statements = read(set.statementsFile);
    const proofs = read(set.proofsFile);
    for (const t of set.theorems) {
      expect(hasTheorem(statements, t.name), `${t.name} in ${set.statementsFile}`).toBe(true);
      expect(hasTheorem(proofs, t.name), `${t.name} in ${set.proofsFile}`).toBe(true);
      expect(t.says.length, t.name).toBeGreaterThan(20);
    }
  });

  it('uses the namespace its config module uses', () => {
    const module = (JSON.parse(read(set.config)) as { challenge_module: string }).challenge_module;
    const ns = module.includes('Extra') ? 'UsTax.Extra.' : 'UsTax.Main.';
    for (const t of set.theorems) expect(t.name.startsWith(ns), t.name).toBe(true);
  });
});

describe('other proofs', () => {
  it('exist in the files named', () => {
    for (const p of OTHER_PROOFS) expect(hasTheorem(read(p.file), p.name), `${p.name} in ${p.file}`).toBe(true);
  });
  it('are not in either comparator list (so the page does not double-count)', () => {
    const all = new Set([...names(MAIN.config), ...names(EXTRA.config)]);
    for (const p of OTHER_PROOFS) expect(all.has(p.name)).toBe(false);
  });
});

describe('Direct File bug counts', () => {
  const rows = read(BUGS.file)
    .split('\n')
    .filter((l) => /^\| DF-BUG-\d+ \|/.test(l))
    .map((l) => l.split('|').map((c) => c.trim()));
  const status = (r: string[]) => r[2] ?? '';

  it('match docs/direct-file-bugs.md', () => {
    expect(rows.length).toBe(BUGS.total);
    expect(rows.filter((r) => status(r).startsWith('confirmed')).length).toBe(BUGS.confirmed);
    expect(rows.filter((r) => status(r).startsWith('fixed')).length).toBe(BUGS.fixed);
    expect(rows.filter((r) => status(r) === 'candidate').length).toBe(BUGS.candidates);
    expect(BUGS.confirmed + BUGS.fixed + BUGS.candidates).toBe(BUGS.total);
  });

  it('highlights exist with the status the log gives them, and DF-BUG-8 is confirmed', () => {
    for (const h of BUGS.highlights) {
      const row = rows.find((r) => r[1] === h.id);
      expect(row, h.id).toBeDefined();
      const word = h.status.split(' ')[0]!;
      expect(status(row!).startsWith(word), `${h.id}: ${status(row!)} vs ${h.status}`).toBe(true);
    }
    expect(status(rows.find((r) => r[1] === 'DF-BUG-8')!)).toBe('confirmed');
  });
});

describe('test counts', () => {
  const status = read('README.md');
  const fmt = (n: number) => n.toLocaleString('en-US');

  it('appear in README.md', () => {
    expect(status).toContain(`${fmt(TESTED.calculator.factChecks)}`);
    expect(status).toContain(`${fmt(TESTED.apiCalculator.factChecks)}`);
    expect(status).toContain(`${fmt(TESTED.audit.declarations)} declarations`);
    expect(status).toContain(`${TESTED.calculator.scenarios}`);
  });

  it('are consistent: 161 shipped, 4 rejected, 157 run', () => {
    expect(TESTED.scenarios.shipped - TESTED.scenarios.rejected).toBe(TESTED.scenarios.runnable);
    expect(TESTED.calculator.scenarios).toBe(TESTED.scenarios.runnable);
    const text = TESTED.items.join(' ');
    expect(text).toContain(fmt(TESTED.calculator.factChecks));
    expect(text).toContain(fmt(TESTED.apiCalculator.factChecks));
    expect(text).toContain(fmt(TESTED.audit.declarations));
  });

  it('table and rate counts match lean/README.md', () => {
    const lean = read('lean/README.md');
    expect(lean).toContain(fmt(TESTED.taxTable.checks));
    expect(lean).toContain(fmt(TESTED.rates.incomesPerStatus));
  });
});

describe('Catala tier (verified by testing, not proved)', () => {
  const count = (dir: string, ext: string) => readdirSync(join(root, dir)).filter((f) => f.endsWith(ext)).length;

  it('file counts match the repository', () => {
    expect(count('catala', '.catala_en')).toBe(CATALA.moduleFiles);
    expect(count('catala/tests', '.catala_en')).toBe(CATALA.testFiles);
    expect(count('difftest/mappings', '.mjs')).toBe(CATALA.mappings);
    expect(CATALA.discrepancies).toBe(BUGS.total);
  });

  it('every item names a Catala file and a difftest mapping that exist, and the scope is in the file or mapping', () => {
    for (const it of CATALA.items) {
      expect(existsSync(join(root, it.file)), it.file).toBe(true);
      const mapping = `difftest/mappings/${it.mapping}.mjs`;
      expect(existsSync(join(root, mapping)), mapping).toBe(true);
      const where = read(it.file) + read(mapping);
      expect(where.includes(it.scope), `${it.scope} in ${it.file} or ${mapping}`).toBe(true);
    }
  });

  it('the whole-return counts appear in README.md, and the drawer lines exist in provenance.json', () => {
    expect(read('README.md')).toContain(TESTED.calculator.factChecks.toLocaleString('en-US'));
    const lines = (JSON.parse(read('api/provenance.json')) as { lines: Record<string, unknown> }).lines;
    for (const it of CATALA.items) if ('line' in it && it.line) expect(lines[it.line], it.line).toBeDefined();
  });

  it('never calls itself a proof', () => {
    expect(CATALA.legend).toMatch(/not a proof/);
    const words = [CATALA.legend, CATALA.caveat, ...CATALA.checks, ...CATALA.items.map((i) => `${i.title} ${i.result}`)].join(' ');
    // "proved" may only refer to the Lean side, never to a Catala rule.
    expect(words).not.toMatch(/catala[^.;]*\bproved\b/i);
    const tier2 = STATUS_CLAIMS.find((c) => c.status === 'tested')!;
    expect(tier2.title).toMatch(/verified against the IRS engine/i);
    expect(tier2.detail).toMatch(/not a proof/i);
  });
});

describe('home page panel', () => {
  it('is built from the same module and never calls the Catala link proved', () => {
    expect(STATUS_CLAIMS[0]!.title).toContain(String(MAIN.theorems.length));
    expect(STATUS_CLAIMS[1]!.title).toContain(String(EXTRA.theorems.length));
    const tested = STATUS_CLAIMS.find((c) => c.status === 'tested')!;
    expect(tested.detail).toMatch(/not a proof/i);
  });
});
