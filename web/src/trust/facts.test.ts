import { describe, expect, it } from 'vitest';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { AS_OF, BUGS, EXTRA, MAIN, OTHER_PROOFS, STATUS_CLAIMS, TESTED, type ProofSet } from './facts';

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
  const status = read('STATUS.md');
  const fmt = (n: number) => n.toLocaleString('en-US');

  it('appear in STATUS.md with the date they are stated as of', () => {
    expect(status).toContain(AS_OF);
    expect(status).toContain(`${fmt(TESTED.calculator.factChecks)}`);
    expect(status).toContain(`${fmt(TESTED.apiCalculator.factChecks)}`);
    expect(status).toContain(`${fmt(TESTED.audit.declarations)} declarations`);
    expect(status).toContain(`${TESTED.calculator.scenarios}/${TESTED.calculator.scenarios}`);
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

describe('home page panel', () => {
  it('is built from the same module and never calls the Catala link proved', () => {
    expect(STATUS_CLAIMS[0]!.title).toContain(String(MAIN.theorems.length));
    expect(STATUS_CLAIMS[1]!.title).toContain(String(EXTRA.theorems.length));
    const tested = STATUS_CLAIMS.find((c) => c.status === 'tested')!;
    expect(tested.detail).toMatch(/not a proof/i);
  });
});
