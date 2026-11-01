/**
 * Tests for the polish pass: money typing, the stepper, the running estimate, the ⌘K palette, the
 * provenance badge logic, the money-flow chart, the form layer (react-hook-form + zod), and the drift
 * guard between the zod schema and api/schema.json.
 */
import { beforeAll, describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { MemoryRouter } from 'react-router';
import schema from '../../api/schema.json';
import refundRes from '../../api/examples/refund-single-w2-50k.response.json';
import oweRes from '../../api/examples/balance-due-single-w2-50k.response.json';
import prov from '../../api/provenance.json';
import { MoneyInput, Stepper } from './components';
import { stepState } from './components/Stepper';
import { groupDollarString, regroupTyping } from './lib/moneyText';
import { DraftProvider, emptyDraft, newW2, useDraft, type Cents, type Draft } from './draft';
import { headline, toEstimate, LiveSummaryCard, useEstimate } from './wizard/LiveSummary';
import { buildCommands } from './command/commands';
import CommandPalette from './command/CommandPalette';
import { lineStatus, statusIndex } from './provenance/status';
import type { Provenance } from './provenance';
import { barPercent, flowSteps } from './results/MoneyFlow';
import { summaryText } from './results/summaryText';
import { formName } from './forms/formName';
import { draftSchema, FILING_STATUSES, TOO_BIG } from './forms/draftSchema';
import { DraftForm } from './forms/DraftForm';
import { MoneyField } from './wizard/fields';
import { BOX12_CODES, LIMITS } from './draft';
import { App, preloadRoutes } from './App';
import type { CalculateSuccess } from './api';

const refund = refundRes as unknown as CalculateSuccess;
const owe = oweRes as unknown as CalculateSuccess;
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

describe('money typing (thousands separators while typing)', () => {
  it('groups the whole-dollar part and drops a typed $', () => {
    expect(regroupTyping('1234').text).toBe('1,234');
    expect(regroupTyping('1234567.5').text).toBe('1,234,567.5');
    expect(regroupTyping('$50000').text).toBe('50,000');
    expect(regroupTyping('12,34').text).toBe('1,234');
    expect(regroupTyping('-1234').text).toBe('-1,234');
    expect(regroupTyping('').text).toBe('');
  });

  it('leaves text that is not number-shaped alone, so the parser can say why', () => {
    expect(regroupTyping('12a').text).toBe('12a');
    expect(regroupTyping('1.2.3').text).toBe('1.2.3');
  });

  it('keeps the caret after the same digit', () => {
    // "1234|" -> "1,234|"
    expect(regroupTyping('1234', 4)).toEqual({ text: '1,234', caret: 5 });
    // typing a 9 between 1 and 2 of "1,234": "19,234" raw with caret after the 9 -> "19,234", caret 2
    expect(regroupTyping('19,234', 2)).toEqual({ text: '19,234', caret: 2 });
    // "1,2345" (caret after the 5) -> "12,345", caret at the end
    expect(regroupTyping('1,2345', 6)).toEqual({ text: '12,345', caret: 6 });
    // deleting the comma's neighbour: "1,34" caret 2 -> "134" caret 1
    expect(regroupTyping('1,34', 2)).toEqual({ text: '134', caret: 1 });
  });

  it('formats the blurred value', () => {
    expect(groupDollarString('1234567.50')).toBe('1,234,567.50');
    expect(groupDollarString('-5.00')).toBe('-5.00');
  });

  function Money() {
    const [v, setV] = useState<Cents | null>(null);
    return (
      <>
        <MoneyInput label="Wages" value={v} onChange={setV} />
        <output data-testid="cents">{v === null ? 'null' : v}</output>
      </>
    );
  }

  it('shows separators while typing, and reports integer cents underneath', async () => {
    render(<Money />);
    const input = screen.getByLabelText('Wages');
    await userEvent.type(input, '1234567.8');
    expect(input).toHaveValue('1,234,567.8');
    expect(screen.getByTestId('cents')).toHaveTextContent('123456780');
    await userEvent.tab();
    expect(input).toHaveValue('1,234,567.80');
  });

  it('accepts a trailing decimal point mid-typing without an error', async () => {
    render(<Money />);
    await userEvent.type(screen.getByLabelText('Wages'), '12.');
    expect(screen.queryByRole('alert')).toBeNull();
    expect(screen.getByTestId('cents')).toHaveTextContent('1200');
  });
});

describe('Stepper', () => {
  const steps = [
    { id: 'a', label: 'One', blurb: 'First' },
    { id: 'b', label: 'Two', blurb: 'Second' },
    { id: 'c', label: 'Three', blurb: 'Third' },
  ];

  it('marks steps complete, current and upcoming', () => {
    expect([0, 1, 2].map((i) => stepState(i, 1))).toEqual(['complete', 'current', 'upcoming']);
    render(
      <MemoryRouter>
        <Stepper steps={steps} current={1} hrefFor={(id) => `/s/${id}`} />
      </MemoryRouter>,
    );
    const items = within(screen.getByRole('list')).getAllByRole('listitem');
    expect(items.map((li) => li.dataset.state)).toEqual(['complete', 'current', 'upcoming']);
    expect(items[1]).toHaveAttribute('aria-current', 'step');
    expect(items[1]).toHaveTextContent('Second'); // the current step shows its blurb
  });

  it('links every step except the current one (any step can be opened, in any order)', () => {
    render(
      <MemoryRouter>
        <Stepper steps={steps} current={1} hrefFor={(id) => `/s/${id}`} />
      </MemoryRouter>,
    );
    expect(screen.getByRole('link', { name: /One.*completed/ })).toHaveAttribute('href', '/s/a');
    expect(screen.queryByRole('link', { name: /Two/ })).toBeNull();
    const three = screen.getByRole('link', { name: /Three/ });
    expect(three).toHaveAttribute('href', '/s/c');
    expect(three).not.toHaveTextContent('completed');
    expect(screen.getByRole('progressbar', { name: 'Progress through your return' })).toBeInTheDocument();
  });
});

describe('running estimate (summary sidebar)', () => {
  it('maps the live state to what the card shows', () => {
    const req = { filing_status: 'Single' } as never;
    expect(toEstimate(null, { status: 'loading', previous: null }).kind).toBe('empty');
    expect(toEstimate(req, { status: 'loading', previous: null }).kind).toBe('loading');
    expect(toEstimate(req, { status: 'loading', previous: refund })).toMatchObject({ kind: 'ok', updating: true });
    expect(toEstimate(req, { status: 'ok', data: refund })).toMatchObject({ kind: 'ok', updating: false, stale: false });
    expect(toEstimate(req, { status: 'error', error: { type: 'network', message: 'x' }, previous: refund })).toMatchObject({ kind: 'ok', stale: true });
    expect(toEstimate(req, { status: 'error', error: { type: 'network', message: 'x' }, previous: null }).kind).toBe('unavailable');
    expect(toEstimate(req, { status: 'knockout', reasons: [] }).kind).toBe('knockout');
  });

  it('labels a refund and a balance due', () => {
    expect(headline(refund)).toEqual({ label: 'Estimated refund so far', cents: 98100, tone: 'good' });
    expect(headline(owe)).toMatchObject({ label: 'Estimated amount owed so far', tone: 'bad' });
  });

  it('shows a skeleton first, then the refund and running totals from POST /calculate', async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => json(200, refundRes));
    function Host() {
      const e = useEstimate({ client: { fetch: fetchMock }, debounceMs: 0 });
      return <LiveSummaryCard e={e} />;
    }
    const draft: Draft = { ...emptyDraft(), filingStatus: 'Single', w2s: [{ ...newW2(), wages: 5000000, withholding: 500000 }] };
    render(
      <DraftProvider initial={draft}>
        <Host />
      </DraftProvider>,
    );
    const card = screen.getByTestId('live-summary');
    expect(card.querySelector('[data-slot="skeleton"]')).not.toBeNull();
    expect(await within(card).findByText('$981')).toBeInTheDocument();
    expect(within(card).getByRole('heading', { name: 'Estimated refund so far' })).toBeInTheDocument();
    expect(within(card).getByText('Taxable income').nextSibling).toHaveTextContent('$35,400');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('asks for a filing status before estimating, and calls nothing', () => {
    const fetchMock = vi.fn<typeof fetch>();
    function Host() {
      return <LiveSummaryCard e={useEstimate({ client: { fetch: fetchMock } })} />;
    }
    render(
      <DraftProvider initial={emptyDraft()}>
        <Host />
      </DraftProvider>,
    );
    expect(screen.getByText(/Choose a filing status/)).toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

describe('command palette', () => {
  it('offers every wizard step, the pages, the docs and the actions', () => {
    const cmds = buildCommands({ hasReturn: false });
    expect(cmds.filter((c) => c.group === 'Return').map((c) => c.to)).toEqual([
      '/start/about',
      '/start/household',
      '/start/dependents',
      '/start/income',
      '/start/adjustments',
      '/start/credits',
      '/start/review',
    ]);
    expect(cmds.some((c) => c.to === '/results')).toBe(false);
    expect(buildCommands({ hasReturn: true }).some((c) => c.to === '/results')).toBe(true);
    expect(cmds.some((c) => c.to === '/trust')).toBe(true);
    expect(cmds.some((c) => c.to === '/docs')).toBe(true);
    expect(cmds.filter((c) => c.group === 'Actions').map((c) => c.action)).toEqual(['toggle-theme', 'copy-link', 'start-over']);
    expect(new Set(cmds.map((c) => c.id)).size).toBe(cmds.length);
  });

  it('filters as you type and navigates on Enter', async () => {
    function Host() {
      const [open, setOpen] = useState(true);
      return (
        <DraftProvider initial={emptyDraft()}>
          <CommandPalette open={open} onOpenChange={setOpen} />
        </DraftProvider>
      );
    }
    render(
      <MemoryRouter>
        <Host />
      </MemoryRouter>,
    );
    const dialog = screen.getByRole('dialog', { name: 'Go to' });
    await userEvent.type(within(dialog).getByRole('combobox'), 'income');
    const options = within(dialog).getAllByRole('option');
    expect(options[0]).toHaveTextContent('Income');
    await userEvent.keyboard('{Enter}');
    expect(screen.queryByRole('dialog')).toBeNull();
  });

  it('opens with Ctrl+K (or ⌘K) anywhere in the app', async () => {
    await preloadRoutes();
    render(
      <MemoryRouter initialEntries={['/']}>
        <App />
      </MemoryRouter>,
    );
    expect(screen.queryByRole('dialog', { name: 'Go to' })).toBeNull();
    fireEvent.keyDown(document, { key: 'k', ctrlKey: true });
    expect(await screen.findByRole('dialog', { name: 'Go to' })).toBeInTheDocument();
    expect(screen.getByRole('option', { name: /Verification|What is verified/ })).toBeInTheDocument();
  });
});

describe('provenance badge logic', () => {
  const p = prov as unknown as Provenance;
  it('is "proved" exactly when provenance.json lists a Lean theorem for the line', () => {
    const idx = statusIndex(p);
    for (const [k, line] of Object.entries(p.lines)) expect(idx[k]).toBe(line.proofs.theorems.length > 0 ? 'proved' : 'tested');
    expect(idx.taxable_income).toBe('proved');
    expect(idx.wages).toBe('tested');
    expect(lineStatus(undefined)).toBeNull();
  });
  it('agrees with the coverage summary in provenance.json', () => {
    const idx = statusIndex(p);
    const tested = Object.keys(idx).filter((k) => idx[k] === 'tested').sort();
    expect(tested).toEqual([...(prov as { coverage: { without_lean_theorem: string[] } }).coverage.without_lean_theorem].sort());
  });
});

describe('where your money went', () => {
  it('runs income -> deductions -> tax -> payments -> result, skipping zero reductions', () => {
    const steps = flowSteps(refund.lines, refund.outcome);
    expect(steps.map((s) => s.key)).toEqual(['total_income', 'total_deductions', 'taxable_income', 'total_tentative_tax', 'total_tax', 'total_payments', 'overpayment']);
    expect(steps.at(-1)).toMatchObject({ kind: 'result-good', cents: 98100 });
    expect(flowSteps(owe.lines, owe.outcome).at(-1)).toMatchObject({ key: 'balance_due', kind: 'result-bad' });
  });
  it('scales bars to the largest figure and keeps small non-zero values visible', () => {
    expect(barPercent(50, 100)).toBe(50);
    expect(barPercent(0, 100)).toBe(0);
    expect(barPercent(1, 10000)).toBe(1.5);
  });
  it('copy summary text has the outcome and key lines', () => {
    const t = summaryText(refund, 'Single');
    expect(t).toContain('Your refund: $981.00');
    expect(t).toContain('Line 15, Taxable income: $35,400.00');
    expect(t).toContain('Filing status: Single');
  });
});

describe('form layer (react-hook-form + zod over the draft)', () => {
  it('maps draft paths to form field names', () => {
    const w = { ...newW2(), box12: [{ id: 'r1', code: 'D', amount: 1 }] };
    const d: Draft = { ...emptyDraft(), w2s: [newW2(), w] };
    expect(formName(`w2.${w.id}.wages`, d)).toBe('w2s.1.wages');
    expect(formName(`w2.${w.id}.box12.r1.amount`, d)).toBe('w2s.1.box12.0.amount');
    expect(formName('hsa.spouse.directContributions', d)).toBe('spouse.hsa.directContributions');
    expect(formName('primary.dob', d)).toBe('primary.dob');
    expect(formName('w2.gone.wages', d)).toBeNull();
  });

  it('accepts an empty and a full draft, and rejects contract violations', () => {
    expect(draftSchema.safeParse(emptyDraft()).success).toBe(true);
    const big = { ...emptyDraft(), w2s: [{ ...newW2(), wages: LIMITS.maxCents + 1 }] };
    const r = draftSchema.safeParse(big);
    expect(r.success).toBe(false);
    expect(r.error!.issues[0]!.path).toEqual(['w2s', 0, 'wages']);
    expect(r.error!.issues[0]!.message).toBe(TOO_BIG);
    expect(draftSchema.safeParse({ ...emptyDraft(), filingStatus: 'Nope' }).success).toBe(false);
  });

  it('shows the contract error as soon as the field is left, not only after Next', async () => {
    const w = newW2();
    function Wages() {
      const { draft, update } = useDraft();
      return (
        <MoneyField
          label="Wages"
          path={`w2.${w.id}.wages`}
          value={draft.w2s[0]!.wages}
          onChange={(wages) => update((d) => ({ ...d, w2s: [{ ...d.w2s[0]!, wages }] }))}
        />
      );
    }
    render(
      <DraftProvider initial={{ ...emptyDraft(), w2s: [w] }}>
        <DraftForm>
          <Wages />
        </DraftForm>
      </DraftProvider>,
    );
    const input = screen.getByLabelText('Wages');
    await userEvent.type(input, '200000000000');
    expect(screen.queryByText(TOO_BIG)).toBeNull(); // quiet while typing
    await userEvent.tab();
    expect(await screen.findByText(TOO_BIG)).toBeInTheDocument();
    expect(input).toBeInvalid();
  });
});

describe('zod schema derives from api/schema.json', () => {
  const defs = (schema as { $defs: Record<string, { maximum?: number; enum?: string[]; properties?: Record<string, { maxItems?: number }> }> }).$defs;
  it('money cap, filing statuses, box 12 codes and list limits match the contract', () => {
    expect(defs.Money!.maximum).toBe(LIMITS.maxCents);
    expect([...FILING_STATUSES].sort()).toEqual([...defs.FilingStatus!.enum!].sort());
    expect(BOX12_CODES.map((c) => c.code).sort()).toEqual(Object.keys(defs.W2Box12!.properties!).sort());
    expect(defs.CalculateRequest!.properties!.w2s!.maxItems).toBe(LIMITS.maxItems);
  });
});

beforeAll(() => {
  window.localStorage.clear();
});
