import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { App } from '../../App';
import ApiReference from './ApiReference';
import { SchemaNode } from './SchemaTree';
import { curlSnippet, doc, fetchSnippet, listOperations, operationAnchor } from './openapi';

vi.mock('../highlight', async (orig) => ({
  ...(await orig<typeof import('../highlight')>()),
  highlightDoc: vi.fn().mockRejectedValue(new Error('highlighting disabled in tests')),
}));

const renderPage = () =>
  render(
    <MemoryRouter initialEntries={['/docs/api']}>
      <ApiReference />
    </MemoryRouter>,
  );

afterEach(() => vi.unstubAllGlobals());

describe('api/openapi.json', () => {
  it('is the file on disk', () => {
    const disk = JSON.parse(readFileSync(resolve(process.cwd(), '../api/openapi.json'), 'utf8'));
    expect(doc.info.title).toBe(disk.info.title);
    expect(doc.openapi).toBe('3.1.0');
  });
});

describe('API reference page', () => {
  it('renders every operation with its method badge and a deep-link id', () => {
    const { container } = renderPage();
    const ops = listOperations();
    expect(ops.map((o) => `${o.method} ${o.path}`)).toEqual(['POST /calculate', 'GET /health', 'GET /version']);
    for (const o of ops) {
      const card = container.querySelector(`section#${o.anchor}`);
      expect(card, o.anchor).not.toBeNull();
      expect(within(card as HTMLElement).getByRole('heading', { level: 2, name: o.path })).toBeInTheDocument();
      expect(within(card as HTMLElement).getAllByText(o.method).length).toBeGreaterThan(0);
    }
    expect(operationAnchor('post', '/calculate')).toBe('operation-postcalculate');
  });

  it('renders every schema in the file', () => {
    const { container } = renderPage();
    const names = Object.keys(doc.components.schemas);
    expect(names.length).toBeGreaterThan(40);
    for (const n of names) expect(container.querySelector(`article#schema-${n}`), n).not.toBeNull();
  });

  it('lists every response status of every operation', () => {
    renderPage();
    for (const o of listOperations()) {
      const card = document.getElementById(o.anchor) as HTMLElement;
      for (const status of Object.keys(o.op.responses)) {
        expect(within(card).getAllByText(status, { selector: 'span' }).length, `${o.path} ${status}`).toBeGreaterThan(0);
      }
    }
  });

  it('shows required badges for required request fields and expands nested objects', async () => {
    renderPage();
    const body = document.querySelector('#operation-postcalculate') as HTMLElement;
    const filingStatus = within(body).getAllByText('filing_status')[0]!.closest('li') as HTMLElement;
    expect(within(filingStatus).getByText('required')).toBeInTheDocument();
    const w2s = within(body).getAllByText('w2s')[0]!.closest('li') as HTMLElement;
    expect(within(w2s).getByText('optional')).toBeInTheDocument();
    expect(within(w2s).getByText('maxItems 20')).toBeInTheDocument();
    await userEvent.click(within(w2s).getByRole('button', { name: 'w2s' }));
    const wages = within(w2s).getByText('wages').closest('li') as HTMLElement;
    expect(within(wages).getByText('required')).toBeInTheDocument();
    expect(within(wages).getByText('min 0')).toBeInTheDocument();
  });

  it('shows enum chips and defaults', () => {
    render(<SchemaNode name="filing_status" schema={{ $ref: '#/components/schemas/FilingStatus' }} required />);
    expect(screen.getByLabelText('Allowed values')).toHaveTextContent('"Single"');
  });

  it('changing the request example changes the curl snippet', async () => {
    renderPage();
    const card = document.querySelector('#operation-postcalculate') as HTMLElement;
    const select = within(card).getByLabelText('Request example') as HTMLSelectElement;
    expect(select.value).toBe('single-w2-50k');
    expect(within(card).getByLabelText('Copy curl')).toBeInTheDocument();
    const before = card.querySelector('figure pre')!.textContent!;
    expect(before).toContain('"wages":5000000');
    await userEvent.selectOptions(select, 'family-mfj-two-kids');
    const after = card.querySelector('figure pre')!.textContent!;
    expect(after).not.toBe(before);
    expect(after).toContain('MarriedFilingJointly');
    expect(after).toContain('curl -X POST http://localhost:8080/calculate');
  });

  it('builds curl and fetch snippets', () => {
    expect(curlSnippet('http://x', 'POST', '/calculate', { a: "it's" })).toBe(
      "curl -X POST http://x/calculate \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"a\":\"it'\\''s\"}'",
    );
    expect(fetchSnippet('http://x', 'GET', '/health')).toContain("fetch('http://x/health')");
  });

  it('Try it sends the selected example and shows status, latency and body', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ api_version: 1, ok: true }), { status: 200, statusText: 'OK' }));
    vi.stubGlobal('fetch', fetchMock);
    renderPage();
    const card = document.querySelector('#operation-postcalculate') as HTMLElement;
    const tryIt = within(card).getByTestId('try-it');
    const textarea = within(tryIt).getByLabelText('Request body (JSON)') as HTMLTextAreaElement;
    expect(JSON.parse(textarea.value).filing_status).toBe('Single');
    await userEvent.click(within(tryIt).getByRole('button', { name: 'Send' }));
    await waitFor(() => expect(within(tryIt).getByTestId('try-it-status')).toHaveTextContent('200'));
    expect(within(tryIt).getByTestId('try-it-latency')).toHaveTextContent(/\d+ ms/);
    expect(tryIt).toHaveTextContent('"ok": true');
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('http://localhost:8080/calculate');
    expect(init.method).toBe('POST');
    expect((init.headers as Record<string, string>)['Content-Type']).toBe('application/json');
    expect(JSON.parse(init.body as string)).toEqual(JSON.parse(textarea.value));
  });

  it('Try it sends an edited body', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response('{"error":1}', { status: 400, statusText: 'Bad Request' }));
    vi.stubGlobal('fetch', fetchMock);
    renderPage();
    const tryIt = within(document.querySelector('#operation-postcalculate') as HTMLElement).getByTestId('try-it');
    const textarea = within(tryIt).getByLabelText('Request body (JSON)');
    await userEvent.clear(textarea);
    await userEvent.type(textarea, 'not json');
    expect(within(tryIt).getByRole('status')).toHaveTextContent('Not valid JSON');
    await userEvent.click(within(tryIt).getByRole('button', { name: 'Send' }));
    await waitFor(() => expect(within(tryIt).getByTestId('try-it-status')).toHaveTextContent('400'));
    expect((fetchMock.mock.calls[0] as [string, RequestInit])[1].body).toBe('not json');
  });

  it('Try it explains a network error', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')));
    renderPage();
    const tryIt = within(document.querySelector('#operation-postcalculate') as HTMLElement).getByTestId('try-it');
    await userEvent.click(within(tryIt).getByRole('button', { name: 'Send' }));
    expect(await within(tryIt).findByRole('alert')).toHaveTextContent(/No response from http:\/\/localhost:8080\/calculate.*Failed to fetch/);
  });
});

describe('navigation', () => {
  it('has a sidebar with operations and schemas, and a select for small screens', () => {
    renderPage();
    const nav = screen.getByRole('navigation', { name: 'API reference' });
    expect(within(nav).getByRole('link', { name: /POST\s*\/calculate/ })).toHaveAttribute('href', '#operation-postcalculate');
    expect(within(nav).getByRole('link', { name: 'FormW2' })).toHaveAttribute('href', '#schema-FormW2');
    expect(screen.getByLabelText('Jump to')).toBeInTheDocument();
  });

  it('is routed at /docs/api and listed in the docs navigation', async () => {
    render(
      <MemoryRouter initialEntries={['/docs']}>
        <App />
      </MemoryRouter>,
    );
    const nav = await screen.findByRole('navigation', { name: 'Documentation' }, { timeout: 15000 });
    const link = within(nav).getByRole('link', { name: 'API reference' });
    expect(link).toHaveAttribute('href', '/docs/api');
    await userEvent.click(link);
    expect(await screen.findByRole('heading', { level: 1, name: 'US Tax API' }, { timeout: 15000 })).toBeInTheDocument();
  }, 30000);
});
