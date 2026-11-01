import { useEffect, useMemo, useState } from 'react';
import { Link, useLocation } from 'react-router';
import { ArrowLeft, ChevronRight } from 'lucide-react';
import { Page } from '@/layout/Page';
import { Select } from '@/components';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';
import { Inline } from './Inline';
import { SchemaTree } from './SchemaTree';
import { CopyButton, Snippet } from './Snippet';
import { TryIt } from './TryIt';
import {
  baseUrl,
  curlSnippet,
  doc,
  fetchSnippet,
  listOperations,
  SCHEMA_NAMES,
  schemaAnchor,
  type ExampleObject,
  type Operation,
  type ResponseObject,
} from './openapi';
import { METHOD_CLASS, statusVariant } from './status';
import '../docs.css';

const OPERATIONS = listOperations();
const TAGS = doc.tags.map((t) => ({ ...t, ops: OPERATIONS.filter((o) => o.tag === t.name) }));
const SECTION_IDS = [...OPERATIONS.map((o) => o.anchor), ...SCHEMA_NAMES.map(schemaAnchor)];
const DEFAULT_EXAMPLE = 'single-w2-50k';

export function MethodBadge({ method, className }: { method: string; className?: string }) {
  return (
    <span
      className={cn('inline-flex min-w-[3.25rem] shrink-0 justify-center rounded-md border px-1.5 py-0.5 font-mono text-[0.6875rem] font-bold tracking-wide', METHOD_CLASS[method], className)}
    >
      {method}
    </span>
  );
}

/** The id of the section nearest the top of the viewport (scroll-spy). */
function useActiveSection(): string | null {
  const [active, setActive] = useState<string | null>(SECTION_IDS[0] ?? null);
  useEffect(() => {
    const onScroll = () => {
      let cur: string | null = SECTION_IDS[0] ?? null;
      for (const id of SECTION_IDS) {
        const el = document.getElementById(id);
        if (el && el.getBoundingClientRect().top <= 140) cur = id;
      }
      setActive(cur);
    };
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);
  return active;
}

function navLinkClass(active: boolean) {
  return cn(
    'flex items-center gap-2 rounded-md px-2 py-1.5 text-sm no-underline hover:bg-accent',
    active ? 'bg-accent font-medium text-foreground' : 'text-muted-foreground hover:text-foreground',
  );
}

function Sidebar({ active }: { active: string | null }) {
  return (
    <aside className="hidden lg:sticky lg:top-6 lg:block lg:max-h-[calc(100vh-3rem)] lg:self-start lg:overflow-y-auto lg:pr-2">
      <nav aria-label="API reference">
        {TAGS.map((t) => (
          <div key={t.name} className="mb-4">
            <p className="m-0 mb-1 px-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase">{t.name}</p>
            <ul className="m-0 list-none space-y-0.5 p-0">
              {t.ops.map((o) => (
                <li key={o.anchor}>
                  <a href={`#${o.anchor}`} aria-current={active === o.anchor ? 'location' : undefined} className={navLinkClass(active === o.anchor)}>
                    <MethodBadge method={o.method} className="min-w-[2.75rem] text-[0.625rem]" />
                    <span className="font-mono text-xs">{o.path}</span>
                  </a>
                </li>
              ))}
            </ul>
          </div>
        ))}
        <p className="m-0 mb-1 px-2 text-xs font-semibold tracking-wide text-muted-foreground uppercase">Schemas</p>
        <ul className="m-0 list-none space-y-0.5 p-0">
          {SCHEMA_NAMES.map((n) => {
            const id = schemaAnchor(n);
            return (
              <li key={n}>
                <a href={`#${id}`} aria-current={active === id ? 'location' : undefined} className={navLinkClass(active === id)}>
                  <span className="font-mono text-xs">{n}</span>
                </a>
              </li>
            );
          })}
        </ul>
      </nav>
    </aside>
  );
}

/** Below lg the sidebar collapses to one select. */
function MobileNav({ active, onJump }: { active: string | null; onJump: (id: string) => void }) {
  return (
    <div className="lg:hidden">
      <label htmlFor="api-jump" className="mb-1 block text-sm font-medium">
        Jump to
      </label>
      <select
        id="api-jump"
        value={active ?? ''}
        onChange={(e) => onJump(e.target.value)}
        className="h-10 w-full cursor-pointer rounded-md border border-input bg-background px-3 text-base text-foreground focus-visible:outline-2 focus-visible:outline-ring"
      >
        {TAGS.map((t) => (
          <optgroup key={t.name} label={t.name}>
            {t.ops.map((o) => (
              <option key={o.anchor} value={o.anchor}>
                {o.method} {o.path}
              </option>
            ))}
          </optgroup>
        ))}
        <optgroup label="Schemas">
          {SCHEMA_NAMES.map((n) => (
            <option key={n} value={schemaAnchor(n)}>
              {n}
            </option>
          ))}
        </optgroup>
      </select>
    </div>
  );
}

function Intro() {
  const server = doc.servers[0];
  const rows: [string, React.ReactNode][] = [
    ['Base URL', <code key="b">{server?.url}</code>],
    ['Content type', <><code>application/json</code> in and out. Bodies are limited to 256 KiB.</>],
    ['Money', <>Always an integer number of <strong>cents</strong> (<code>5000000</code> is $50,000.00). No decimals, no strings.</>],
    ['Versioning', <>Every body carries <code>api_version</code> (now 1). The schema file is semver (<code>{doc.info.version}</code>): patch is docs, minor is additive, major is breaking.</>],
    ['Errors', <>Anything but 200 and 422 answers <code>{'{ "api_version", "error": { "code", "message", "details?" } }'}</code>. 422 is not an error: the request is fine but unsupported.</>],
    ['Authentication', <>None. The server holds no user data and keeps nothing between calls.</>],
  ];
  return (
    <section aria-labelledby="api-intro" className="space-y-4">
      <div>
        <p className="m-0 text-sm font-medium text-primary">API reference</p>
        <h1 id="api-intro" className="m-0 mt-1 text-3xl font-semibold tracking-tight">
          {doc.info.title}
        </h1>
        <p className="mt-2 mb-0 text-muted-foreground">
          {doc.info.summary} <Badge variant="secondary">v{doc.info.version}</Badge> <Badge variant="outline">OpenAPI {doc.openapi}</Badge>
        </p>
      </div>
      <p className="m-0 max-w-3xl text-muted-foreground"><Inline text={doc.info.description ?? ''} /></p>
      <dl className="m-0 divide-y rounded-lg border bg-card text-sm">
        {rows.map(([k, v]) => (
          <div key={k} className="grid gap-1 px-4 py-2.5 sm:grid-cols-[9rem_minmax(0,1fr)] sm:gap-4">
            <dt className="font-medium">{k}</dt>
            <dd className="m-0 text-muted-foreground [&_code]:rounded [&_code]:bg-muted [&_code]:px-1 [&_code]:py-0.5 [&_code]:text-xs">{v}</dd>
          </div>
        ))}
      </dl>
      <p className="m-0 mt-4 text-sm text-muted-foreground">
        The machine-readable document is <code>api/openapi.json</code>, generated from <code>api/schema.json</code>. The prose version is{' '}
        <a href="https://github.com/arniber21/ustax/blob/main/docs/api.md">docs/api.md</a>.
      </p>
    </section>
  );
}

const pretty = (v: unknown) => JSON.stringify(v, null, 2);

function ResponseRow({ status, res, requestKey }: { status: string; res: ResponseObject; requestKey: string }) {
  const [open, setOpen] = useState(status === '200');
  const [picked, setPicked] = useState<string | null>(null);
  const media = res.content?.['application/json'];
  const examples = media?.examples ?? {};
  const keys = Object.keys(examples);
  const key = picked && examples[picked] ? picked : examples[requestKey] ? requestKey : keys[0];
  const ex: ExampleObject | undefined = key ? examples[key] : undefined;
  return (
    <li className="py-1">
      <button
        type="button"
        aria-expanded={open}
        onClick={() => setOpen(!open)}
        className="flex w-full cursor-pointer items-start gap-3 rounded-md border-0 bg-transparent px-2 py-2 text-left hover:bg-accent focus-visible:outline-2 focus-visible:outline-ring"
      >
        <ChevronRight aria-hidden="true" className={cn('mt-0.5 size-4 shrink-0 text-muted-foreground transition-transform', open && 'rotate-90')} />
        <Badge variant={statusVariant(status)} className="font-mono">
          {status}
        </Badge>
        <span className="min-w-0 text-sm">
          <Inline text={res.description} />
        </span>
      </button>
      {open && media && (
        <div className="space-y-3 px-2 pt-2 pb-3 sm:pl-9">
          <div>
            <p className="m-0 mb-1 text-xs font-medium tracking-wide text-muted-foreground uppercase">Schema</p>
            <SchemaTree schema={media.schema} />
          </div>
          {ex && key && (
            <div className="space-y-2">
              {keys.length > 1 && (
                <Select
                  label="Example"
                  value={key}
                  options={keys.map((k) => ({ value: k, label: examples[k]?.summary ?? k }))}
                  onChange={setPicked}
                />
              )}
              <Snippet title={`${status} response${keys.length > 1 ? `: ${ex.summary ?? key}` : ''}`} code={pretty(ex.value)} lang="json" />
            </div>
          )}
        </div>
      )}
    </li>
  );
}

function OperationCard({ o }: { o: Operation }) {
  const body = o.op.requestBody?.content['application/json'];
  const examples = body?.examples ?? {};
  const keys = Object.keys(examples);
  const [key, setKey] = useState(keys.includes(DEFAULT_EXAMPLE) ? DEFAULT_EXAMPLE : (keys[0] ?? ''));
  const [lang, setLang] = useState<'curl' | 'fetch'>('curl');
  const ex = examples[key];
  const base = baseUrl();
  const code = lang === 'curl' ? curlSnippet(base, o.method, o.path, ex?.value) : fetchSnippet(base, o.method, o.path, ex?.value);
  const sample = useMemo(() => (ex ? pretty(ex.value) : undefined), [ex]);
  return (
    <section id={o.anchor} aria-labelledby={`${o.anchor}-title`} className="scroll-mt-6 rounded-xl border bg-card text-card-foreground">
      <header className="flex flex-wrap items-center gap-3 border-b px-4 py-3 sm:px-6">
        <MethodBadge method={o.method} />
        <h2 id={`${o.anchor}-title`} className="m-0 font-mono text-lg font-semibold">
          {o.path}
        </h2>
        <span className="ml-auto text-xs text-muted-foreground">
          <code>{o.op.operationId}</code>
        </span>
      </header>
      <div className="space-y-8 px-4 py-5 sm:px-6">
        <div>
          <p className="m-0 text-base font-medium">{o.op.summary}</p>
          {o.op.description && (
            <p className="mt-1 mb-0 text-muted-foreground">
              <Inline text={o.op.description} />
            </p>
          )}
        </div>

        {body && (
          <div className="space-y-3">
            <h3 className="m-0 text-base font-semibold">
              Request body <Badge variant="destructive">required</Badge> <span className="font-mono text-xs font-normal text-muted-foreground">application/json</span>
            </h3>
            <SchemaTree schema={body.schema} />
          </div>
        )}

        <div className="space-y-3">
          <h3 className="m-0 text-base font-semibold">Request samples</h3>
          {keys.length > 0 && (
            <Select
              label="Request example"
              hint={ex?.description}
              value={key}
              options={keys.map((k) => ({ value: k, label: `${examples[k]?.summary ?? k} (${examples[k]?.['x-expected-status'] ?? ''})` }))}
              onChange={setKey}
            />
          )}
          <div className="flex items-center gap-1" role="tablist" aria-label="Sample language">
            {(['curl', 'fetch'] as const).map((l) => (
              <button
                key={l}
                type="button"
                role="tab"
                aria-selected={lang === l}
                onClick={() => setLang(l)}
                className={cn(
                  'cursor-pointer rounded-md border px-3 py-1 text-sm focus-visible:outline-2 focus-visible:outline-ring',
                  lang === l ? 'border-primary bg-primary text-primary-foreground' : 'bg-background text-muted-foreground hover:bg-accent',
                )}
              >
                {l === 'curl' ? 'curl' : 'JavaScript (fetch)'}
              </button>
            ))}
          </div>
          <Snippet title={lang === 'curl' ? 'curl' : 'fetch'} code={code} lang={lang === 'curl' ? 'bash' : 'ts'} />
          {sample && (
            <details className="rounded-lg border">
              <summary className="cursor-pointer px-4 py-2 text-sm font-medium">Request body JSON</summary>
              <div className="border-t p-3">
                <div className="mb-2 flex justify-end">
                  <CopyButton text={sample} label="Copy request body" />
                </div>
                <Snippet title={ex?.summary ?? 'request'} code={sample} lang="json" />
              </div>
            </details>
          )}
        </div>

        <div className="space-y-2">
          <h3 className="m-0 text-base font-semibold">Responses</h3>
          <ul className="m-0 list-none divide-y rounded-lg border p-1">
            {Object.entries(o.op.responses).map(([status, res]) => (
              <ResponseRow key={status} status={status} res={res} requestKey={key} />
            ))}
          </ul>
        </div>

        <TryIt method={o.method} path={o.path} initialBody={sample} />
      </div>
    </section>
  );
}

function SchemasSection() {
  return (
    <section aria-labelledby="schemas-title" className="space-y-4">
      <div>
        <h2 id="schemas-title" className="m-0 text-2xl font-semibold tracking-tight">
          Schemas
        </h2>
        <p className="mt-1 mb-0 text-muted-foreground">
          Every model in <code>components/schemas</code> ({SCHEMA_NAMES.length}). Types link here; expand an object to see its fields.
        </p>
      </div>
      <div className="space-y-4">
        {SCHEMA_NAMES.map((n) => (
          <article key={n} id={schemaAnchor(n)} aria-label={`Schema ${n}`} className="scroll-mt-6">
            <h3 className="m-0 mb-2 font-mono text-base font-semibold">
              <a href={`#${schemaAnchor(n)}`} className="text-foreground no-underline hover:underline">
                {n}
              </a>
            </h3>
            <SchemaTree schema={{ $ref: `#/components/schemas/${n}` }} name={n} />
          </article>
        ))}
      </div>
    </section>
  );
}

/** `/docs/api`: the OpenAPI reference, rendered with the site's own components. */
export default function ApiReference() {
  const active = useActiveSection();
  const { hash } = useLocation();

  useEffect(() => {
    const prev = document.title;
    document.title = 'API reference | US Tax';
    return () => {
      document.title = prev;
    };
  }, []);

  // A link to /docs/api#operation-postcalculate lands on the card once it is in the DOM.
  useEffect(() => {
    if (hash) document.getElementById(decodeURIComponent(hash.slice(1)))?.scrollIntoView();
  }, [hash]);

  const jump = (id: string) => {
    window.history.replaceState(null, '', `#${id}`);
    document.getElementById(id)?.scrollIntoView();
  };

  return (
    <Page className="max-w-7xl">
      <Link to="/docs" className="mb-6 inline-flex items-center gap-1.5 text-sm text-muted-foreground no-underline hover:text-foreground">
        <ArrowLeft aria-hidden="true" className="size-4" /> Documentation
      </Link>
      <div className="grid gap-8 lg:grid-cols-[16rem_minmax(0,1fr)] lg:gap-10">
        <Sidebar active={active} />
        <div className="min-w-0 space-y-10">
          <MobileNav active={active} onJump={jump} />
          <Intro />
          <div className="space-y-8">
            {OPERATIONS.map((o) => (
              <OperationCard key={o.anchor} o={o} />
            ))}
          </div>
          <SchemasSection />
        </div>
      </div>
    </Page>
  );
}
