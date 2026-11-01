import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { act, render, renderHook, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import type { CalculateRequest } from '../api';
import manifest from '../../../api/fixtures/manifest.json';
import catalog from '../../../api/line-catalog.json';
import refundRes from '../../../api/examples/refund-single-w2-50k.response.json';
import oweRes from '../../../api/examples/balance-due-single-w2-50k.response.json';
import err500 from '../../../api/fixtures/error-500-internal.response.json';
import { EXAMPLES } from '../examples';
import { ResultsView, WarningsAlert } from './ResultsView';
import { useLiveCalculation } from './useLiveCalculation';
import { WALK } from './walkData';

beforeAll(() => vi.stubEnv('VITE_API_MOCK', '1'));
afterEach(() => {
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

const files = import.meta.glob('../../../api/{examples,fixtures}/*.json', { eager: true, import: 'default' }) as Record<string, unknown>;
const load = (rel: string) => Object.entries(files).find(([k]) => k.endsWith(`/api/${rel}`))![1];

const view = (ui: React.ReactElement) => render(<MemoryRouter>{ui}</MemoryRouter>);
const reduceMotion = (reduce: boolean) =>
  vi.stubGlobal('matchMedia', (q: string) => ({ matches: reduce, media: q, addEventListener() {}, removeEventListener() {} }));
/** The large result figure inside the summary named by its label ("Your refund", "Amount you owe"). */
const figure = async (name: string | RegExp) => (await screen.findByRole('region', { name })).querySelector('.result-amount');
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

describe('every calculate fixture renders', () => {
  const cases = manifest.fixtures.filter(
    (f) => f.path === '/calculate' && f.method === 'POST' && 'request' in f && ![415, 500].includes(f.status),
  ) as { name: string; status: number; request: string }[];

  it('covers the 200, 422 and 400 states', () => {
    expect(new Set(cases.map((c) => c.status))).toEqual(new Set([200, 400, 422]));
  });

  for (const c of cases) {
    it(`${c.name} (${c.status})`, async () => {
      view(<ResultsView request={load(c.request) as CalculateRequest} />);
      if (c.status === 200) {
        expect(await figure(/^(Your refund|Amount you owe|No refund and nothing owed)$/)).toHaveTextContent(/^\$[\d,]+\.\d\d$/);
        expect(screen.getByRole('table', { name: /Form 1040/ })).toBeInTheDocument();
        expect(screen.getByRole('link', { name: /what is verified/i })).toHaveAttribute('href', '/trust');
      } else if (c.status === 422) {
        expect(await screen.findByRole('heading', { level: 1, name: /can’t be calculated yet/ })).toBeInTheDocument();
        expect(screen.getByRole('link', { name: /Change my answers/ })).toBeInTheDocument();
        expect(screen.queryByText(/FlowKnockout|Knockout/)).toBeNull();
      } else {
        expect(await screen.findByRole('alert')).toHaveTextContent(/answers/);
        expect(screen.getByRole('link', { name: 'Check my answers' })).toBeInTheDocument();
      }
    });
  }

  it('shows a balance due as "Amount you owe"', async () => {
    view(<ResultsView request={EXAMPLES.owe} />);
    expect(await figure('Amount you owe')).toHaveTextContent('$1,019.00');
    expect(screen.queryByRole('region', { name: 'Your refund' })).toBeNull();
  });
});

describe('error and offline states', () => {
  it('500 offers to try again, and retry recovers', async () => {
    const fetchMock = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(json(500, err500))
      .mockResolvedValue(json(200, refundRes));
    view(<ResultsView request={EXAMPLES.refund} client={{ fetch: fetchMock }} />);
    expect(await screen.findByRole('alert')).toHaveTextContent(/Something went wrong on our end/);
    expect(screen.queryByText(/500|internal_error/)).toBeNull();
    await userEvent.click(screen.getByRole('button', { name: 'Try again' }));
    expect(await figure('Your refund')).toHaveTextContent('$981.00');
    expect(screen.queryByRole('alert')).toBeNull();
  });

  it('a network failure reads as offline-friendly and never throws', async () => {
    vi.spyOn(navigator, 'onLine', 'get').mockReturnValue(false);
    const fetchMock = vi.fn<typeof fetch>().mockRejectedValue(new TypeError('Failed to fetch'));
    view(<ResultsView request={EXAMPLES.refund} client={{ fetch: fetchMock }} />);
    expect(await screen.findByRole('alert')).toHaveTextContent(/offline/);
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument();
  });
});

describe('no decorative motion', () => {
  for (const reduce of [true, false]) {
    it(`shows the exact final amount at once (prefers-reduced-motion: ${reduce})`, async () => {
      reduceMotion(reduce);
      view(<ResultsView request={EXAMPLES.refund} />);
      expect(await figure('Your refund')).toHaveTextContent('$981.00');
    });
  }
});

describe('warnings', () => {
  it('lists sections the calculator accepted but did not use', () => {
    render(
      <WarningsAlert
        warnings={[
          { code: 'section_not_used', path: '/form_1099g', message: 'Form 1099-G' },
          { code: 'section_not_used', path: '/estimated_payments', message: 'Estimated tax payments' },
          { code: 'something_new', path: '/x', message: 'A new kind of note.' },
        ]}
      />,
    );
    const note = screen.getByRole('note');
    expect(note).toHaveTextContent(/not used in this result/);
    expect(within(note).getByText('Unemployment (Form 1099-G)')).toBeInTheDocument();
    expect(within(note).getByText('Estimated tax payments')).toBeInTheDocument();
    expect(within(note).getByText('A new kind of note.')).toBeInTheDocument();
  });

  it('appears on the results page when the response carries warnings', async () => {
    const withWarn = { ...refundRes, warnings: [{ code: 'section_not_used', path: '/form_1099r', message: 'Form 1099-R' }] };
    const fetchMock = vi.fn<typeof fetch>(async () => json(200, withWarn));
    view(<ResultsView request={EXAMPLES.refund} client={{ fetch: fetchMock }} />);
    await figure('Your refund');
    expect(screen.getAllByRole('note')[0]).toHaveTextContent('Retirement distributions (Form 1099-R)');
  });

  it('is absent when every section was used', async () => {
    view(<ResultsView request={EXAMPLES.refund} />);
    await figure('Your refund');
    expect(screen.queryByText(/not used in this result/)).toBeNull();
  });
});

describe('useLiveCalculation', () => {
  const other = { ...EXAMPLES.owe } as CalculateRequest;

  it('cancels the stale request and ignores its late answer', async () => {
    const pending: { signal: AbortSignal | null | undefined; resolve: (r: Response) => void }[] = [];
    const fetchMock = vi.fn<typeof fetch>(
      (_u, init) =>
        new Promise<Response>((resolve) => {
          pending.push({ signal: init?.signal, resolve });
        }),
    );
    const { result, rerender } = renderHook(({ req }) => useLiveCalculation(req, { debounceMs: 5, client: { fetch: fetchMock } }), {
      initialProps: { req: EXAMPLES.refund },
    });
    await waitFor(() => expect(pending).toHaveLength(1)); // first call is immediate
    rerender({ req: other });
    await waitFor(() => expect(pending).toHaveLength(2));
    expect(pending[0]!.signal?.aborted).toBe(true);
    expect(pending[1]!.signal?.aborted).toBe(false);

    await act(async () => pending[1]!.resolve(json(200, oweRes)));
    await act(async () => pending[0]!.resolve(json(200, refundRes))); // late answer to the old request
    expect(result.current.state).toMatchObject({ status: 'ok', data: { outcome: 'balance_due' } });
  });

  it('debounces rapid changes into one call', async () => {
    const fetchMock = vi.fn<typeof fetch>(async () => json(200, refundRes));
    const { rerender } = renderHook(({ req }) => useLiveCalculation(req, { debounceMs: 40, client: { fetch: fetchMock } }), {
      initialProps: { req: EXAMPLES.refund },
    });
    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(1));
    for (let i = 0; i < 4; i++) rerender({ req: { ...EXAMPLES.refund } });
    await new Promise((r) => setTimeout(r, 150));
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('keeps the previous answer while recalculating', async () => {
    let release: (r: Response) => void = () => {};
    const fetchMock = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(json(200, refundRes))
      .mockImplementation(() => new Promise<Response>((r) => (release = r)));
    const { result, rerender } = renderHook(({ req }) => useLiveCalculation(req, { debounceMs: 1, client: { fetch: fetchMock } }), {
      initialProps: { req: EXAMPLES.refund },
    });
    await waitFor(() => expect(result.current.state.status).toBe('ok'));
    rerender({ req: other });
    await waitFor(() => expect(result.current.state).toMatchObject({ status: 'loading', previous: { outcome: 'refund' } }));
    await act(async () => release(json(200, oweRes)));
    expect(result.current.state.status).toBe('ok');
  });
});

describe('Form 1040 table and explanations', () => {
  it('lists every Form 1040 line from the API catalog exactly once', () => {
    const keys = WALK.flatMap((g) => g.lines.map((l) => l.key));
    expect([...keys].sort()).toEqual(catalog.lines.map((l) => l.key).sort());
    for (const g of WALK) for (const l of g.lines) expect(l.line).toBe(catalog.lines.find((c) => c.key === l.key)!.line);
  });

  it('shows every line in a grouped table, and explains key lines on demand', async () => {
    view(<ResultsView request={EXAMPLES.refund} />);
    await figure('Your refund');
    const table = screen.getByRole('table', { name: /Form 1040/ });
    for (const title of ['Income', 'Adjustments', 'Deductions', 'Tax', 'Credits', 'Payments', 'Refund or amount owed']) {
      expect(within(table).getByRole('columnheader', { name: title })).toBeInTheDocument();
    }
    const rows = within(table).getAllByRole('row');
    expect(rows).toHaveLength(1 + WALK.length + catalog.lines.length); // header, group rows, one row per line
    expect(within(table).getByRole('row', { name: /^34 Overpayment \(refund\)/ })).toHaveTextContent('$981.00');
    const why = screen.getAllByRole('button', { name: /^Line \d+/ });
    expect(why.length).toBeGreaterThanOrEqual(5);
    expect(screen.queryByText(/AGI is your total income/)).toBeNull();
    await userEvent.click(screen.getByRole('button', { name: /^Line 11 Adjusted gross income/ }));
    expect(screen.getByText(/AGI is your total income/)).toBeVisible();
  });
});

describe('what-if (mock mode)', () => {
  const slide = (v: number) => {
    const s = screen.getByRole('slider') as HTMLInputElement;
    act(() => {
      // jsdom: set the value through the native setter so React sees the change
      Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(s, String(v));
      s.dispatchEvent(new Event('input', { bubbles: true }));
    });
  };

  it('recomputes when a fixture exists for the scenario', async () => {
    view(<ResultsView request={EXAMPLES.refund} />);
    await figure('Your refund');
    slide(-2000);
    expect(await screen.findByText(/You’d owe \$1,019/)).toBeInTheDocument();
  });

  it('degrades gracefully when there is no fixture', async () => {
    view(<ResultsView request={EXAMPLES.refund} />);
    await figure('Your refund');
    slide(1000);
    expect(await screen.findByText(/only has a few ready-made scenarios/)).toBeInTheDocument();
    expect(await figure('Your refund')).toHaveTextContent('$981.00'); // the real result is untouched
  });

  it('is replaced by a hint when there is no W-2 to shift', async () => {
    const noW2 = { ...EXAMPLES.refund, w2s: [] } as CalculateRequest;
    const fetchMock = vi.fn<typeof fetch>(async () => json(200, refundRes));
    view(<ResultsView request={noW2} client={{ fetch: fetchMock }} />);
    await figure('Your refund');
    expect(screen.queryByRole('slider')).toBeNull();
    expect(screen.getByText(/Add a W-2/)).toBeInTheDocument();
  });
});
