import { Children, isValidElement, useEffect, useMemo, useState, type ComponentProps, type ReactElement, type ReactNode } from 'react';
import ReactMarkdown, { type Components } from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeSlug from 'rehype-slug';
import rehypeAutolinkHeadings from 'rehype-autolink-headings';
import { Link } from 'react-router';
import { Callout, type CalloutTone } from '@/components/Callout';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { bundledImages, SLUG_BY_SOURCE } from './content';
import { highlightDoc, shikiLang, type DocTok } from './highlight';
import { rewriteHref, rewriteSrc } from './links';
import { remarkCallouts, type CalloutKind } from './remarkCallouts';
import './docs.css';

const CALLOUT: Record<CalloutKind, { tone: CalloutTone; title: string }> = {
  note: { tone: 'info', title: 'Note' },
  tip: { tone: 'good', title: 'Tip' },
  important: { tone: 'info', title: 'Important' },
  warning: { tone: 'warn', title: 'Warning' },
  caution: { tone: 'warn', title: 'Caution' },
};

/** A fenced code block. Plain text first; tokens swap in once Shiki has loaded (mermaid and unknown languages stay plain). */
export function CodeBlock({ code, fence }: { code: string; fence?: string }) {
  const lang = shikiLang(fence);
  const [lines, setLines] = useState<{ key: string; toks: DocTok[][] } | null>(null);
  const key = `${lang}\0${code}`;
  useEffect(() => {
    if (!lang) return;
    let live = true;
    highlightDoc(code, lang).then(
      (toks) => live && setLines({ key, toks }),
      () => undefined, // highlighting is cosmetic; the plain text stays
    );
    return () => {
      live = false;
    };
  }, [code, lang, key]);
  const toks = lines?.key === key ? lines.toks : null;
  return (
    <pre className="doc-code" tabIndex={0} data-lang={fence || undefined}>
      <code>
        {toks
          ? toks.map((line, i) => (
              <span key={i}>
                {line.map((t, j) => (
                  <span key={j} data-tok style={t.style}>
                    {t.text}
                  </span>
                ))}
                {i < toks.length - 1 ? '\n' : ''}
              </span>
            ))
          : code}
      </code>
    </pre>
  );
}

/** Renders one doc page. `source` is the repo path of the file, used to resolve relative links and images. */
export function Markdown({ body, source }: { body: string; source: string }) {
  const components = useMemo<Components>(
    () => ({
      a({ href = '', children, node: _node, ...rest }) {
        void _node;
        const to = rewriteHref(href, source, SLUG_BY_SOURCE);
        if (to.startsWith('/docs')) return <Link to={to}>{children}</Link>;
        const external = /^https?:\/\//.test(to);
        return (
          <a href={to} {...(external ? { target: '_blank', rel: 'noreferrer noopener' } : {})} {...rest}>
            {children}
          </a>
        );
      },
      img({ src = '', alt = '', node: _node }) {
        void _node;
        return <img src={rewriteSrc(String(src), source, bundledImages)} alt={alt} loading="lazy" />;
      },
      pre({ children }) {
        const child = Children.toArray(children)[0];
        if (isValidElement(child)) {
          const { className, children: text } = (child as ReactElement<{ className?: string; children?: ReactNode }>).props;
          const fence = /language-([\w+-]+)/.exec(className ?? '')?.[1];
          return <CodeBlock code={String(text ?? '').replace(/\n$/, '')} fence={fence} />;
        }
        return <pre>{children}</pre>;
      },
      blockquote({ children, node: _node, ...rest }) {
        void _node;
        const kind = (rest as Record<string, unknown>)['data-callout'] as CalloutKind | undefined;
        if (kind && kind in CALLOUT) {
          const c = CALLOUT[kind];
          return (
            <Callout tone={c.tone} title={c.title}>
              {children}
            </Callout>
          );
        }
        return <blockquote className="border-l-4 pl-4 text-muted-foreground">{children}</blockquote>;
      },
      table: ({ children }) => (
        <div className="doc-table">
          <Table>{children}</Table>
        </div>
      ),
      thead: ({ children }) => <TableHeader>{children}</TableHeader>,
      tbody: ({ children }) => <TableBody>{children}</TableBody>,
      tr: ({ children }) => <TableRow>{children}</TableRow>,
      th: ({ children, style }: ComponentProps<'th'>) => <TableHead style={style}>{children}</TableHead>,
      td: ({ children, style }: ComponentProps<'td'>) => <TableCell style={style}>{children}</TableCell>,
    }),
    [source],
  );
  return (
    <div className="doc-prose">
      <ReactMarkdown
        remarkPlugins={[remarkGfm, remarkCallouts]}
        rehypePlugins={[rehypeSlug, [rehypeAutolinkHeadings, { behavior: 'wrap' }]]}
        components={components}
        skipHtml
      >
        {body}
      </ReactMarkdown>
    </div>
  );
}
