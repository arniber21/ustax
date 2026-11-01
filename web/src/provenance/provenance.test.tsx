import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import Ajv2020 from 'ajv/dist/2020';
import { useState } from 'react';
import { formatCents, type Lines } from '../api';
import { HowCalculated, LineWalk } from '../results/LineWalk';
import { WALK } from '../results/walkData';
import { NO_THEOREM, ProvenanceDrawer, RULE_LABEL, describeDifftest } from './ProvenanceDrawer';
import { ProvenanceProvider } from './ProvenanceProvider';
import { resetProvenanceCache } from './load';
import type { Provenance } from './types';

const repo = resolve(__dirname, '../../..');
const read = (rel: string) => readFileSync(resolve(repo, rel), 'utf8');
const prov = JSON.parse(read('api/provenance.json')) as Provenance;
const KEYS = Object.keys(prov.lines);

/** Serves /provenance.json and /sources/<path> from the repository, like the build step's web/public copies. */
function stubFetch(opts: { omit?: string[]; fail?: boolean } = {}) {
  const data = structuredClone(prov);
  for (const k of opts.omit ?? []) delete data.lines[k];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string) => {
      if (opts.fail) return new Response('nope', { status: 404 });
      if (url.endsWith('/provenance.json')) return new Response(JSON.stringify(data));
      const m = /\/sources\/(.+)$/.exec(url);
      return m ? new Response(read(m[1]!)) : new Response('', { status: 404 });
    }),
  );
}

beforeEach(() => {
  resetProvenanceCache();
  stubFetch();
});
afterEach(() => vi.unstubAllGlobals());

const openDrawer = (key: string) => render(<ProvenanceDrawer lineKey={key} onOpenChange={() => {}} />);

describe('provenance data', () => {
  it('validates against api/provenance.schema.json and covers the walk', () => {
    const ajv = new Ajv2020({ allErrors: true, strict: false });
    const validate = ajv.compile(JSON.parse(read('api/provenance.schema.json')));
    expect(validate(prov), JSON.stringify(validate.errors?.slice(0, 3))).toBe(true);
    expect(KEYS).toHaveLength(19);
    expect(WALK.flatMap((g) => g.lines.map((l) => l.key)).sort()).toEqual([...KEYS].sort());
  });

  it('describes difftests in plain English without proof language', () => {
    const t = prov.lines.taxable_income!.tests.difftest[0]!;
    expect(describeDifftest(t)).toMatch(/Direct File/);
    expect(describeDifftest(t)).not.toMatch(/proved|verified/i);
  });
});

describe('ProvenanceDrawer', () => {
  it.each(KEYS)('opens for %s with the law, the honest rule label, the proofs section and the tests', async (key) => {
    const line = prov.lines[key]!;
    openDrawer(key);
    const dialog = await screen.findByRole('dialog', { name: new RegExp(`Line ${line.form.line}:`) });
    for (const h of ['The law', 'The rule', 'What is proved', 'How it is tested', 'Direct File fact']) {
      expect(await within(dialog).findByRole('heading', { name: h })).toBeInTheDocument();
    }
    expect(within(dialog).getByText(RULE_LABEL)).toBeInTheDocument();
    expect(await within(dialog).findByRole('region', { name: /Catala rule/ })).toBeInTheDocument();
    for (const c of line.citations) expect(within(dialog).getByRole('link', { name: new RegExp(c.label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')) })).toBeInTheDocument();
    for (const t of line.proofs.theorems) expect(within(dialog).getAllByText(t.name).length).toBeGreaterThan(0);
    if (line.proofs.theorems.length === 0) expect(within(dialog).getByText(NO_THEOREM)).toBeInTheDocument();
    const fact = within(dialog).getByRole('heading', { name: 'Direct File fact' }).closest('section')!;
    expect(within(fact).getByText(line.direct_file_fact!.path)).toBeInTheDocument();
  }, 30_000);

  it('never calls the Catala rule proved', async () => {
    openDrawer('taxable_income');
    const rule = (await screen.findByRole('heading', { name: 'The rule' })).closest('section')!;
    expect(rule.textContent).not.toMatch(/proved|verified/i);
    expect(rule.textContent).toMatch(/Not a proof/);
  });

  it('links citations to the public URL in a new tab with rel=noopener and shows the local path as plain text', async () => {
    openDrawer('taxable_income');
    const law = (await screen.findByRole('heading', { name: 'The law' })).closest('section')!;
    const link = within(law).getAllByRole('link')[0]!;
    expect(link).toHaveAttribute('href', expect.stringMatching(/^https:\/\//));
    expect(link).toHaveAttribute('target', '_blank');
    expect(link.getAttribute('rel')).toContain('noopener');
    const local = prov.lines.taxable_income!.citations.find((c) => c.local)!.local!.path;
    expect(within(law).getAllByText(local)[0]!.closest('a')).toBeNull();
  });

  it('marks curated citations as editorial', async () => {
    openDrawer('wages');
    expect((await screen.findAllByText('statutory basis (editorial)')).length).toBeGreaterThan(0);
  });

  it('highlights the Catala source with the Catala grammar and marks the definition lines', async () => {
    openDrawer('tentative_tax_from_taxable_income');
    const pane = await screen.findByRole('region', { name: /Catala rule for/ });
    await waitFor(() => expect(pane.querySelector('[data-scope^="keyword.other"]')).not.toBeNull(), { timeout: 20_000 });
    const keywords = [...pane.querySelectorAll('[data-scope^="keyword.other"]')].map((e) => e.textContent!.trim());
    expect(keywords).toEqual(expect.arrayContaining(['scope', 'definition']));
    expect(pane.querySelector('[data-scope="keyword.other.catala_en"]')).not.toBeNull();
    const def = prov.lines.tentative_tax_from_taxable_income!.rule.definition;
    const marked = [...pane.querySelectorAll('[data-hl="true"]')].map((e) => Number(e.getAttribute('data-line')));
    expect(marked[0]).toBe(def.start);
    expect(marked.at(-1)).toBe(def.end);
    expect(pane.querySelector(`[data-line="${def.start}"]`)).toHaveAttribute('aria-current', 'location');
  }, 30_000);

  it('shows a Lean theorem with its meaning, file:line and a highlighted Lean snippet', async () => {
    openDrawer('taxable_income');
    const t = prov.lines.taxable_income!.proofs.theorems[0]!;
    const proved = (await screen.findByRole('heading', { name: 'What is proved' })).closest('section')!;
    expect(within(proved).getByText(t.covers)).toBeInTheDocument();
    expect(within(proved).getByText(`${t.file}:${t.start}`)).toBeInTheDocument();
    expect(within(proved).queryByText(NO_THEOREM)).toBeNull();
    const pane = await within(proved).findByRole('region', { name: `Lean source of ${t.name}` });
    await waitFor(() => expect(pane.querySelector('[data-scope]')).not.toBeNull(), { timeout: 20_000 });
    expect(pane.textContent).toContain('theorem taxableIncome_nonneg');
  }, 30_000);

  it('says no theorem covers a line without proofs', async () => {
    openDrawer('wages');
    const proved = (await screen.findByRole('heading', { name: 'What is proved' })).closest('section')!;
    expect(within(proved).getByText(NO_THEOREM)).toBeInTheDocument();
    expect(within(proved).queryByText('proved in Lean')).toBeNull();
  });

  it('falls back when the line has no provenance entry', async () => {
    stubFetch({ omit: ['agi'] });
    openDrawer('agi');
    expect(await screen.findByText(/No source trail is recorded for this line yet/)).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: 'The rule' })).toBeNull();
  });

  it('falls back when provenance.json cannot be loaded', async () => {
    stubFetch({ fail: true });
    openDrawer('agi');
    expect(await screen.findByRole('alert')).toHaveTextContent(/could not be loaded/);
  });

  it('closes on Escape and returns focus to the button that opened it', async () => {
    const user = userEvent.setup();
    function Host() {
      const [k, setK] = useState<string | null>(null);
      return (
        <>
          <button onClick={() => setK('agi')}>open</button>
          <ProvenanceDrawer lineKey={k} onOpenChange={(o) => !o && setK(null)} />
        </>
      );
    }
    render(<Host />);
    await user.click(screen.getByRole('button', { name: 'open' }));
    await screen.findByRole('dialog');
    await user.keyboard('{Escape}');
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
    expect(screen.getByRole('button', { name: 'open' })).toHaveFocus();
  });
});

describe('opening from the results page', () => {
  const lines = Object.fromEntries(KEYS.map((k, i) => [k, (i + 1) * 100_00])) as unknown as Lines;
  const page = () =>
    render(
      <ProvenanceProvider lines={lines}>
        <LineWalk lines={lines} />
        <HowCalculated lines={lines} />
      </ProvenanceProvider>,
    );

  it('has a button on every line row that opens the drawer for that line, with its amount', async () => {
    const user = userEvent.setup();
    page();
    const walk = screen.getByRole('table');
    expect(within(walk).getAllByRole('button', { name: /How was .* calculated\?/ })).toHaveLength(19);
    await user.click(within(walk).getByRole('button', { name: 'How was line 15, Taxable income calculated?' }));
    const dialog = await screen.findByRole('dialog', { name: /Line 15: / });
    expect(dialog).toHaveTextContent(`Your amount: ${formatCents(lines.taxable_income)}`);
  });

  it('keeps the explanation accordion and adds the same button inside it', async () => {
    const user = userEvent.setup();
    page();
    await user.click(screen.getByRole('button', { name: /Line 15\s+Taxable income/ }));
    expect(screen.getByText(/This is the only part of your income that actually gets taxed/)).toBeInTheDocument();
    const buttons = screen.getAllByRole('button', { name: 'How was line 15, Taxable income calculated?' });
    expect(buttons).toHaveLength(2);
    await user.click(buttons[1]!);
    expect(await screen.findByRole('dialog')).toBeInTheDocument();
  });

  it('renders no provenance buttons without a provider', () => {
    render(<LineWalk lines={lines} />);
    expect(screen.queryByRole('button')).toBeNull();
  });
});
