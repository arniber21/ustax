import { useEffect, useId, useRef, useState } from 'react';
import { Check, Copy } from 'lucide-react';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { highlight, langOf, type Tok } from './highlight';
import { loadSource } from './load';
import './provenance.css';

export interface SourcePaneProps {
  /** Repo-relative path, e.g. `catala/form_1040.catala_en`. */
  path: string;
  /** 1-based lines to mark and scroll to. */
  mark: { start: number; end: number };
  /** Lines shown first (1-based, inclusive); the rest of the file is behind "Show whole file". */
  window?: { start: number; end: number };
  /** Expected line count from provenance.json `files[]`, to detect a changed copy. */
  expectedLines?: number;
  /** Accessible name of the code region. */
  label: string;
}

/** The lines shown first: the section around a definition, or a few lines of context. */
export function windowAround(mark: { start: number; end: number }, section?: { start: number; end: number } | null, context = 3) {
  if (section && section.end - section.start <= 120) return { start: Math.min(section.start, mark.start), end: Math.max(section.end, mark.end) };
  return { start: Math.max(1, mark.start - (section ? 30 : context)), end: mark.end + (section ? 30 : context) };
}

/** A read-only source viewer: line numbers, the marked lines highlighted, Shiki colours (Catala or Lean grammar) once loaded. */
export function SourcePane({ path, mark, window: win, expectedLines, label }: SourcePaneProps) {
  const [code, setCode] = useState<string[] | null>(null);
  const [toks, setToks] = useState<Tok[][] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [whole, setWhole] = useState(false);
  const [copied, setCopied] = useState(false);
  const scroller = useRef<HTMLDivElement>(null);
  const id = useId();

  useEffect(() => {
    let live = true;
    loadSource(path)
      .then((text) => {
        if (!live) return;
        const lines = text.replace(/\n$/, '').split('\n');
        setCode(lines);
        highlight(path, text, langOf(path))
          .then((t) => live && setToks(t))
          .catch(() => undefined); // plain text stays on screen
      })
      .catch((e: unknown) => live && setError(e instanceof Error ? e.message : String(e)));
    return () => {
      live = false;
    };
  }, [path]);

  const first = whole || !win ? 1 : win.start;
  const last = code ? (whole || !win ? code.length : Math.min(code.length, win.end)) : 0;

  useEffect(() => {
    const box = scroller.current;
    const row = box?.querySelector<HTMLElement>(`[data-line="${mark.start}"]`);
    if (box && row) box.scrollTop = Math.max(0, row.offsetTop - 24);
  }, [code, toks, whole, mark.start]);

  const ref = `${path}:${mark.start}${mark.end > mark.start ? `-${mark.end}` : ''}`;
  const copy = () => {
    void navigator.clipboard?.writeText(ref).then(
      () => {
        setCopied(true);
        toast.success('Path copied', { description: ref });
        setTimeout(() => setCopied(false), 1500);
      },
      () => toast.error('Could not copy the path'),
    );
  };

  return (
    <div className="overflow-hidden rounded-md border bg-card">
      <div className="flex items-center justify-between gap-2 border-b bg-muted px-3 py-1.5">
        <code className="min-w-0 truncate text-xs" title={ref}>
          {ref}
        </code>
        <Button type="button" variant="ghost" size="sm" className="prov-noprint h-7 shrink-0 px-2 text-xs" onClick={copy} aria-label={`Copy path ${ref}`}>
          {copied ? <Check aria-hidden="true" /> : <Copy aria-hidden="true" />}
          {copied ? 'Copied' : 'Copy path'}
        </Button>
      </div>
      {error ? (
        <p role="alert" className="m-0 p-3 text-sm text-destructive">
          Could not load this source file ({error}).
        </p>
      ) : !code ? (
        <p className="m-0 p-3 text-sm text-muted-foreground">Loading source…</p>
      ) : (
        <>
          {expectedLines !== undefined && expectedLines !== code.length && (
            <p role="note" className="m-0 border-b bg-warning-soft px-3 py-1.5 text-xs text-warning">
              This copy has {code.length} lines but the index expects {expectedLines}. Line numbers may be off.
            </p>
          )}
          <div
            ref={scroller}
            role="region"
            tabIndex={0}
            aria-label={label}
            aria-describedby={id}
            className="prov-code prov-scroll relative max-h-72 overflow-auto py-1 outline-none focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-ring"
          >
            {code.slice(first - 1, last).map((text, i) => {
              const n = first + i;
              const marked = n >= mark.start && n <= mark.end;
              const line = toks?.[n - 1];
              return (
                <div key={n} className="prov-line flex" data-line={n} data-hl={marked} aria-current={n === mark.start ? 'location' : undefined}>
                  <span aria-hidden="true" className="w-12 shrink-0 pr-3 text-right text-muted-foreground select-none">
                    {n}
                  </span>
                  <span className="min-w-0 pr-3 break-words whitespace-pre-wrap">
                    {line && line.length > 0
                      ? line.map((t, j) => (
                          <span key={j} data-scope={t.scope} style={t.style}>
                            {t.text}
                          </span>
                        ))
                      : text || ' '}
                  </span>
                </div>
              );
            })}
          </div>
          <div className="flex items-center justify-between gap-2 border-t px-3 py-1.5 text-xs text-muted-foreground">
            <span id={id}>
              Lines {first} to {last} of {code.length}. Highlighted: {mark.start === mark.end ? `line ${mark.start}` : `lines ${mark.start} to ${mark.end}`}.
            </span>
            {win && (
              <Button type="button" variant="ghost" size="sm" className="prov-noprint h-7 px-2 text-xs" onClick={() => setWhole((w) => !w)}>
                {whole ? 'Show less' : 'Show whole file'}
              </Button>
            )}
          </div>
        </>
      )}
    </div>
  );
}
