import { useEffect, useRef, useState, type ReactNode } from 'react';
import { Link, NavLink, Outlet, Route, Routes, useLocation, useOutletContext, useParams } from 'react-router';
import { ArrowLeft, ArrowRight, Pencil, Search } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Page } from '@/layout/Page';
import { ButtonLink } from '@/components';
import { cn } from '@/lib/utils';
import { findPage, PAGES, searchPages, type DocPage } from './content';
import { githubBlobUrl } from './config';
import { docRoute } from './links';
import { Markdown } from './Markdown';
import { activeHeading, tocFromElement, type TocItem } from './toc';

interface Ctx {
  query: string;
}

const PAGE_TITLE = 'Documentation';

function useDocumentTitle(title: string) {
  useEffect(() => {
    const prev = document.title;
    document.title = `${title} | US Tax`;
    return () => {
      document.title = prev;
    };
  }, [title]);
}

function Sidebar({ query, onQuery }: { query: string; onQuery: (q: string) => void }) {
  const shown = searchPages(PAGES, query);
  return (
    <aside className="lg:sticky lg:top-6 lg:self-start">
      <div className="relative">
        <Search aria-hidden="true" className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground" />
        <label htmlFor="docs-search" className="sr-only">
          Search documentation by title or summary
        </label>
        <Input
          id="docs-search"
          type="search"
          value={query}
          onChange={(e) => onQuery(e.target.value)}
          placeholder="Search pages"
          autoComplete="off"
          className="pl-9"
        />
      </div>
      <nav aria-label="Documentation" className="mt-4">
        {shown.length === 0 ? (
          <p role="status" className="m-0 px-3 text-sm text-muted-foreground">
            No page matches "{query}".
          </p>
        ) : (
          <ul className="m-0 list-none space-y-0.5 p-0">
            {shown.map((p) => (
              <li key={p.slug}>
                <NavLink
                  to={docRoute(p.slug)}
                  end
                  className={({ isActive }) =>
                    cn(
                      'block rounded-md px-3 py-1.5 text-sm no-underline hover:bg-accent',
                      isActive ? 'bg-accent font-medium text-foreground' : 'text-muted-foreground hover:text-foreground',
                    )
                  }
                >
                  {p.title}
                </NavLink>
              </li>
            ))}
          </ul>
        )}
      </nav>
    </aside>
  );
}

function DocsLayout() {
  const [query, setQuery] = useState('');
  return (
    <Page className="max-w-7xl">
      <div className="grid gap-8 lg:grid-cols-[15rem_minmax(0,1fr)] lg:gap-12">
        <Sidebar query={query} onQuery={setQuery} />
        <Outlet context={{ query } satisfies Ctx} />
      </div>
    </Page>
  );
}

function EditLink({ source }: { source: string }) {
  return (
    <a
      href={githubBlobUrl(source)}
      target="_blank"
      rel="noreferrer noopener"
      className="inline-flex items-center gap-1.5 text-sm text-muted-foreground"
    >
      <Pencil aria-hidden="true" className="size-3.5" />
      Edit this page on GitHub
    </a>
  );
}

function Toc({ items, active }: { items: TocItem[]; active: string | null }) {
  if (items.length < 2) return null;
  return (
    <nav aria-label="On this page" className="hidden min-w-0 break-words xl:sticky xl:top-6 xl:block xl:max-h-[calc(100vh-3rem)] xl:self-start xl:overflow-y-auto [overflow-wrap:anywhere]">
      <p className="m-0 mb-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase">On this page</p>
      <ul className="m-0 list-none space-y-1 border-l p-0">
        {items.map((it) => (
          <li key={it.id}>
            <a
              href={`#${it.id}`}
              aria-current={active === it.id ? 'location' : undefined}
              className={cn(
                '-ml-px block border-l-2 py-0.5 text-sm no-underline hover:text-foreground',
                it.level === 3 ? 'pl-6' : 'pl-3',
                active === it.id ? 'border-primary font-medium text-foreground' : 'border-transparent text-muted-foreground',
              )}
            >
              {it.text}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  );
}

function PrevNext({ page }: { page: DocPage }) {
  const i = PAGES.findIndex((p) => p.slug === page.slug);
  const prev = PAGES[i - 1];
  const next = PAGES[i + 1];
  if (!prev && !next) return null;
  return (
    <nav aria-label="Previous and next pages" className="mt-12 grid gap-3 border-t pt-6 sm:grid-cols-2">
      {prev ? (
        <Link rel="prev" to={docRoute(prev.slug)} className="rounded-md border p-3 no-underline hover:bg-accent">
          <span className="flex items-center gap-1 text-xs text-muted-foreground">
            <ArrowLeft aria-hidden="true" className="size-3.5" /> Previous
          </span>
          <span className="font-medium text-foreground">{prev.title}</span>
        </Link>
      ) : (
        <span />
      )}
      {next && (
        <Link rel="next" to={docRoute(next.slug)} className="rounded-md border p-3 text-right no-underline hover:bg-accent sm:col-start-2">
          <span className="flex items-center justify-end gap-1 text-xs text-muted-foreground">
            Next <ArrowRight aria-hidden="true" className="size-3.5" />
          </span>
          <span className="font-medium text-foreground">{next.title}</span>
        </Link>
      )}
    </nav>
  );
}

function PageList({ pages }: { pages: DocPage[] }) {
  return (
    <ul className="m-0 mt-4 list-none space-y-3 p-0">
      {pages
        .filter((p) => p.slug !== 'index')
        .map((p) => (
          <li key={p.slug} className="rounded-md border p-4">
            <Link to={docRoute(p.slug)} className="font-medium">
              {p.title}
            </Link>
            {p.summary && <p className="m-0 mt-1 text-sm text-muted-foreground">{p.summary}</p>}
          </li>
        ))}
    </ul>
  );
}

function DocArticle({ page, children }: { page: DocPage; children?: ReactNode }) {
  const articleRef = useRef<HTMLElement>(null);
  const [toc, setToc] = useState<TocItem[]>([]);
  const [active, setActive] = useState<string | null>(null);
  const { hash } = useLocation();
  useDocumentTitle(page.slug === 'index' ? PAGE_TITLE : page.title);

  useEffect(() => {
    const items = articleRef.current ? tocFromElement(articleRef.current) : [];
    setToc(items);
    setActive(items[0]?.id ?? null);
    const onScroll = () => setActive(activeHeading(items));
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, [page]);

  // A link to /docs/x#section lands on the section once the markdown is in the DOM.
  useEffect(() => {
    if (hash) document.getElementById(decodeURIComponent(hash.slice(1)))?.scrollIntoView();
  }, [hash, page]);

  return (
    <div className="grid gap-10 xl:grid-cols-[minmax(0,44rem)_13rem]">
      <article ref={articleRef} aria-label={page.title} className="min-w-0">
        <Markdown body={page.body} source={page.source} />
        {children}
        <div className="mt-10">
          <EditLink source={page.source} />
        </div>
        <PrevNext page={page} />
      </article>
      <Toc items={toc} active={active} />
    </div>
  );
}

function DocsLanding() {
  const { query } = useOutletContext<Ctx>();
  const page = findPage('index');
  const results = searchPages(PAGES, query).filter((p) => p.slug !== 'index');
  if (!page) return null;
  return (
    <DocArticle page={page}>
      <section aria-labelledby="all-pages" className="mt-10">
        <h2 id="all-pages" className="m-0 text-xl font-semibold tracking-tight">
          {query.trim() ? `Pages matching "${query.trim()}"` : 'All pages'}
        </h2>
        {results.length ? (
          <PageList pages={results} />
        ) : (
          <p role="status" className="mt-4 text-sm text-muted-foreground">
            No page matches "{query}".
          </p>
        )}
      </section>
    </DocArticle>
  );
}

function DocRoute() {
  const { slug = '' } = useParams();
  const page = findPage(slug);
  if (!page || slug === 'index') return <DocNotFound slug={slug} />;
  return <DocArticle page={page} />;
}

function DocNotFound({ slug }: { slug: string }) {
  useDocumentTitle('Page not found');
  return (
    <div className="min-w-0">
      <h1 className="m-0 text-3xl font-semibold tracking-tight">Page not found</h1>
      <p className="mt-3 text-muted-foreground">
        There is no documentation page called <code>{slug}</code>. Pick one from the list, or go back to the overview.
      </p>
      <ButtonLink to="/docs">Documentation overview</ButtonLink>
    </div>
  );
}

/** `/docs` and `/docs/:slug`. Loaded lazily from App so the markdown, react-markdown and Shiki stay out of the main bundle. */
export default function DocsRoutes() {
  return (
    <Routes>
      <Route element={<DocsLayout />}>
        <Route index element={<DocsLanding />} />
        <Route path=":slug" element={<DocRoute />} />
      </Route>
    </Routes>
  );
}
