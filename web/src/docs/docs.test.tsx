import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { App } from '../App';
import { buildPages, findPage, NAV, PAGES, SLUG_BY_SOURCE, searchPages } from './content';
import { parseFrontMatter } from './frontmatter';
import { rewriteHref, rewriteSrc } from './links';
import { Markdown } from './Markdown';
import { tocFromElement } from './toc';

// Shiki is cosmetic and heavy; the code stays plain text in these tests.
vi.mock('./highlight', async (orig) => ({
  ...(await orig<typeof import('./highlight')>()),
  highlightDoc: vi.fn().mockRejectedValue(new Error('highlighting disabled in tests')),
}));

const repoRoot = resolve(process.cwd(), '..');

describe('_nav.json', () => {
  const manifest = JSON.parse(readFileSync(resolve(repoRoot, 'docs/site/_nav.json'), 'utf8')) as {
    pages: { title: string; slug: string; source: string }[];
  };

  it('points every entry at a file that exists', () => {
    expect(manifest.pages.length).toBeGreaterThan(0);
    for (const e of manifest.pages) {
      expect(existsSync(resolve(repoRoot, e.source)), `${e.slug}: ${e.source}`).toBe(true);
      expect(e.source.endsWith('.md')).toBe(true);
    }
  });

  it('has unique slugs and every entry is loaded into the bundle', () => {
    const slugs = manifest.pages.map((e) => e.slug);
    expect(new Set(slugs).size).toBe(slugs.length);
    for (const e of manifest.pages) expect(findPage(e.slug)?.source).toBe(e.source);
    expect(NAV.length).toBe(manifest.pages.length);
  });

  it('lists the landing page, the scaffold and the existing documents', () => {
    const sources = manifest.pages.map((e) => e.source);
    for (const s of [
      'docs/site/index.md',
      'docs/site/how-we-built-this.md',
      'docs/writeup.md',
      'docs/spec-surface.md',
      'docs/direct-file-bugs.md',
      'docs/catala-to-lean.md',
      'docs/api.md',
    ]) {
      expect(sources).toContain(s);
    }
  });

  it('appends unlisted docs/site pages, ordered by front-matter', () => {
    const files = new Map([
      ['docs/site/b.md', '---\ntitle: B page\norder: 2\n---\nb'],
      ['docs/site/a.md', '---\ntitle: A page\norder: 1\n---\na'],
      ['docs/site/_nav.json', '{}'],
      ['docs/x.md', '# listed'],
    ]);
    const pages = buildPages({ pages: [{ title: 'X', slug: 'x', source: 'docs/x.md' }] }, files);
    expect(pages.map((p) => p.slug)).toEqual(['x', 'a', 'b']);
    expect(pages[1]).toMatchObject({ title: 'A page', source: 'docs/site/a.md' });
  });
});

describe('parseFrontMatter', () => {
  it('reads title, order and summary and strips the block', () => {
    const { data, body } = parseFrontMatter('---\ntitle: "Quoted: title"\norder: 10\nsummary: One line.\nother: ignored\n---\n# Heading\n');
    expect(data).toEqual({ title: 'Quoted: title', order: 10, summary: 'One line.' });
    expect(body).toBe('# Heading\n');
  });
  it('returns the source untouched without front-matter', () => {
    expect(parseFrontMatter('# Just markdown\n')).toEqual({ data: {}, body: '# Just markdown\n' });
    expect(parseFrontMatter('text\n---\ntitle: no\n---\n').data).toEqual({});
  });
  it('handles CRLF and ignores a non-numeric order', () => {
    expect(parseFrontMatter('---\r\ntitle: T\r\norder: soon\r\n---\r\nbody').data).toEqual({ title: 'T' });
  });
  it('is applied to the real scaffold', () => {
    const p = findPage('how-we-built-this')!;
    expect(p.title).toBe('How we built this');
    expect(p.body.startsWith('---')).toBe(false);
  });
});

describe('link rewriting', () => {
  const slugs = new Map([
    ['docs/audit.md', 'audit'],
    ['docs/site/index.md', 'index'],
  ]);
  it('turns links between docs into site routes, keeping the hash', () => {
    expect(rewriteHref('../audit.md', 'docs/site/index.md', slugs)).toBe('/docs/audit');
    expect(rewriteHref('audit.md#what-make-audit-checks', 'docs/writeup.md', slugs)).toBe('/docs/audit#what-make-audit-checks');
    expect(rewriteHref('index.md', 'docs/site/how-we-built-this.md', slugs)).toBe('/docs');
  });
  it('sends other repo files to GitHub blob URLs and folders to tree URLs', () => {
    expect(rewriteHref('../../lean/UsTax/Audit.lean', 'docs/site/x.md', slugs)).toBe(
      'https://github.com/arniber21/ustax/blob/main/lean/UsTax/Audit.lean',
    );
    expect(rewriteHref('../api/schema.json#x', 'docs/api.md', slugs)).toBe('https://github.com/arniber21/ustax/blob/main/api/schema.json#x');
    expect(rewriteHref('screenshots/', 'docs/writeup.md', slugs)).toBe('https://github.com/arniber21/ustax/tree/main/docs/screenshots');
    expect(rewriteHref('/STATUS.md', 'docs/writeup.md', slugs)).toBe('https://github.com/arniber21/ustax/blob/main/STATUS.md');
  });
  it('leaves external, mailto and in-page links alone', () => {
    for (const h of ['https://catala-lang.org', 'mailto:a@b.c', '#section', '//cdn.example/x']) {
      expect(rewriteHref(h, 'docs/audit.md', slugs)).toBe(h);
    }
  });
  it('resolves images from the bundle, else from GitHub raw', () => {
    const bundled = new Map([['docs/site/img/a.png', '/assets/a-123.png']]);
    expect(rewriteSrc('img/a.png', 'docs/site/x.md', bundled)).toBe('/assets/a-123.png');
    expect(rewriteSrc('../screenshots/home.png', 'docs/writeup.md', bundled)).toBe(
      'https://raw.githubusercontent.com/arniber21/ustax/main/screenshots/home.png',
    );
    expect(rewriteSrc('screenshots/home.png', 'docs/writeup.md', bundled)).toBe(
      'https://raw.githubusercontent.com/arniber21/ustax/main/docs/screenshots/home.png',
    );
    expect(rewriteSrc('https://x.test/i.png', 'docs/a.md', bundled)).toBe('https://x.test/i.png');
  });
  it('knows every nav source', () => {
    for (const p of PAGES) expect(SLUG_BY_SOURCE.get(p.source)).toBe(p.slug);
  });
});

describe('Markdown rendering', () => {
  const md = [
    '# Title',
    '',
    '## First section',
    '',
    '### Sub *section*',
    '',
    '## Second section',
    '',
    '> [!WARNING]',
    '> Careful here.',
    '',
    '| a | b |',
    '|---|---|',
    '| 1 | 2 |',
    '',
    '[other](../catala-to-lean.md) and [lean](../../lean/UsTax/Audit.lean)',
    '',
    '```lean4',
    'theorem t : True := trivial',
    '```',
  ].join('\n');

  it('builds the table of contents from h2 and h3 headings', () => {
    const { container } = render(
      <MemoryRouter>
        <Markdown body={md} source="docs/site/x.md" />
      </MemoryRouter>,
    );
    expect(tocFromElement(container)).toEqual([
      { id: 'first-section', text: 'First section', level: 2 },
      { id: 'sub-section', text: 'Sub section', level: 3 },
      { id: 'second-section', text: 'Second section', level: 2 },
    ]);
  });

  it('renders callouts, tables, rewritten links and code', () => {
    render(
      <MemoryRouter>
        <Markdown body={md} source="docs/site/x.md" />
      </MemoryRouter>,
    );
    const note = screen.getByRole('note');
    expect(note).toHaveTextContent('Warning');
    expect(note).toHaveTextContent('Careful here.');
    expect(note).not.toHaveTextContent('[!WARNING]');
    expect(within(screen.getByRole('table')).getByRole('columnheader', { name: 'a' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'other' })).toHaveAttribute('href', '/docs/catala-to-lean');
    expect(screen.getByRole('link', { name: 'lean' })).toHaveAttribute('href', 'https://github.com/arniber21/ustax/blob/main/lean/UsTax/Audit.lean');
    expect(screen.getByText('theorem t : True := trivial').closest('pre')).toHaveAttribute('data-lang', 'lean4');
  });
});

describe('/docs routes', () => {
  const at = (path: string) =>
    render(
      <MemoryRouter initialEntries={[path]}>
        <App />
      </MemoryRouter>,
    );

  it('landing: overview, sidebar with aria-current, page list and the header link', async () => {
    at('/docs');
    expect(await screen.findByRole('heading', { level: 1, name: 'Documentation' })).toBeInTheDocument();
    expect(screen.getByRole('main')).toContainElement(screen.getByRole('article'));
    const nav = screen.getByRole('navigation', { name: 'Documentation' });
    expect(within(nav).getByRole('link', { name: 'Documentation' })).toHaveAttribute('aria-current', 'page');
    expect(within(nav).getByRole('link', { name: 'How we built this' })).toHaveAttribute('href', '/docs/how-we-built-this');
    expect(within(nav).getAllByRole('link')).toHaveLength(PAGES.length);
    expect(within(screen.getByRole('navigation', { name: 'Main' })).getByRole('link', { name: 'Docs' })).toHaveAttribute('href', '/docs');
    expect(screen.getByRole('heading', { level: 2, name: 'All pages' })).toBeInTheDocument();
  });

  it('search filters pages by title or summary', async () => {
    at('/docs');
    await screen.findByRole('heading', { level: 1, name: 'Documentation' });
    await userEvent.type(screen.getByRole('searchbox', { name: /Search documentation/ }), 'Catala');
    const nav = screen.getByRole('navigation', { name: 'Documentation' });
    const names = within(nav)
      .getAllByRole('link')
      .map((a) => a.textContent);
    expect(names).toEqual(searchPages(PAGES, 'Catala').map((p) => p.title));
    expect(names.length).toBeGreaterThan(0);
    expect(names.length).toBeLessThan(PAGES.length);
    await userEvent.clear(screen.getByRole('searchbox'));
    await userEvent.type(screen.getByRole('searchbox'), 'zzzqqq');
    expect(screen.getAllByRole('status')[0]).toHaveTextContent('No page matches');
  });

  it('renders the scaffold with prompts, the facts box, an edit link and prev/next', async () => {
    at('/docs/how-we-built-this');
    expect(await screen.findByRole('heading', { level: 1, name: 'How we built this' })).toBeInTheDocument();
    for (const h of [
      'Why formal verification for taxes',
      'How we used Catala',
      'How we used Lean',
      'Connecting Catala and Lean',
      'The reference implementation bugs we found',
      'How the agent team worked',
      'What is proved, what is tested, what is trusted',
      'Future directions',
      'Acknowledgements',
    ]) {
      expect(screen.getByRole('heading', { level: 2, name: h })).toBeInTheDocument();
    }
    expect(screen.getByText(/Facts you can cite/)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'docs/spec-surface.md' })).toHaveAttribute('href', '/docs/spec-surface');
    expect(screen.getByRole('link', { name: /Edit this page on GitHub/ })).toHaveAttribute(
      'href',
      'https://github.com/arniber21/ustax/blob/main/docs/site/how-we-built-this.md',
    );
    const toc = screen.getByRole('navigation', { name: 'On this page' });
    expect(within(toc).getByRole('link', { name: 'Future directions' })).toHaveAttribute('href', '#future-directions');
    const pn = screen.getByRole('navigation', { name: 'Previous and next pages' });
    // the page before the scaffold is 'What "verified" means here'; the one after is the write-up draft
    expect(within(pn).getByRole('link', { name: /What "verified" means here/ })).toHaveAttribute(
      'href',
      '/docs/what-verified-means',
    );
    expect(within(pn).getByRole('link', { name: /Write-up/ })).toHaveAttribute('href', '/docs/writeup');
    const sidebar = screen.getByRole('navigation', { name: 'Documentation' });
    expect(within(sidebar).getByRole('link', { name: 'How we built this' })).toHaveAttribute('aria-current', 'page');
  });

  it('renders an existing document with its table (no front-matter needed)', async () => {
    at('/docs/spec-surface');
    expect(await screen.findByRole('heading', { level: 1, name: /Spec surface/ })).toBeInTheDocument();
    expect(screen.getAllByRole('table').length).toBeGreaterThan(0);
    expect(screen.getByRole('link', { name: /Edit this page on GitHub/ })).toHaveAttribute(
      'href',
      'https://github.com/arniber21/ustax/blob/main/docs/spec-surface.md',
    );
  });

  it('shows a 404 for an unknown slug, inside the docs layout', async () => {
    at('/docs/nope');
    expect(await screen.findByRole('heading', { level: 1, name: 'Page not found' })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Documentation overview' })).toHaveAttribute('href', '/docs');
    expect(screen.getByRole('navigation', { name: 'Documentation' })).toBeInTheDocument();
  });
});
