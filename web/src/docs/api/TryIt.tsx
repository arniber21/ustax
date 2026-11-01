import { useEffect, useId, useState } from 'react';
import { Loader2, Send } from 'lucide-react';
import { mockFetch } from '@/api';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Snippet } from './Snippet';
import { baseUrl } from './openapi';
import { statusVariant } from './status';

interface Outcome {
  status: number;
  statusText: string;
  ms: number;
  body: string;
  lang: 'json' | 'text';
}

/** Send the request for real (or from api/fixtures when VITE_API_MOCK=1) and show status, latency and body. */
export function TryIt({ method, path, initialBody }: { method: string; path: string; initialBody?: string }) {
  const id = useId();
  const [text, setText] = useState(initialBody ?? '');
  const [busy, setBusy] = useState(false);
  const [outcome, setOutcome] = useState<Outcome | null>(null);
  const [failure, setFailure] = useState<string | null>(null);
  const url = `${baseUrl()}${path}`;
  const mock = import.meta.env.VITE_API_MOCK === '1';
  const hasBody = initialBody !== undefined;

  // Choosing another example above replaces the editor content and clears the old answer.
  useEffect(() => {
    setText(initialBody ?? '');
    setOutcome(null);
    setFailure(null);
  }, [initialBody]);

  let jsonProblem: string | null = null;
  if (hasBody) {
    try {
      JSON.parse(text);
    } catch (e) {
      jsonProblem = e instanceof Error ? e.message : 'not JSON';
    }
  }

  async function send() {
    setBusy(true);
    setOutcome(null);
    setFailure(null);
    const t0 = performance.now();
    try {
      const doFetch: typeof fetch = mock ? mockFetch : (i, o) => fetch(i, o);
      const res = await doFetch(url, {
        method,
        headers: hasBody ? { 'Content-Type': 'application/json', Accept: 'application/json' } : { Accept: 'application/json' },
        ...(hasBody ? { body: text } : {}),
      });
      const raw = await res.text();
      const ms = Math.round(performance.now() - t0);
      let body = raw;
      let lang: Outcome['lang'] = 'text';
      try {
        body = JSON.stringify(JSON.parse(raw), null, 2);
        lang = 'json';
      } catch {
        /* not JSON: show as is */
      }
      setOutcome({ status: res.status, statusText: res.statusText, ms, body, lang });
    } catch (e) {
      const why = e instanceof Error ? e.message : String(e);
      setFailure(
        `No response from ${url} (${why}). Is the server running (make server) and does it allow this origin (ALLOW_ORIGIN)? Set VITE_API_URL to point at another server, or VITE_API_MOCK=1 to use the fixtures.`,
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="rounded-lg border" data-testid="try-it">
      <div className="flex flex-wrap items-center justify-between gap-2 border-b bg-muted/50 px-4 py-2">
        <h4 className="m-0 text-sm font-semibold">Try it</h4>
        <span className="font-mono text-xs break-all text-muted-foreground">
          {method} {url}
          {mock && ' (mock: api/fixtures)'}
        </span>
      </div>
      <div className="space-y-3 p-4">
        {hasBody && (
          <div>
            <label htmlFor={id} className="mb-1 block text-sm font-medium">
              Request body (JSON)
            </label>
            <textarea
              id={id}
              value={text}
              onChange={(e) => setText(e.target.value)}
              spellCheck={false}
              rows={12}
              aria-invalid={jsonProblem ? true : undefined}
              className="block w-full rounded-md border border-input bg-background p-3 font-mono text-xs leading-relaxed text-foreground focus-visible:border-ring focus-visible:outline-2 focus-visible:outline-ring"
            />
            {jsonProblem && (
              <p role="status" className="m-0 mt-1 text-xs text-warning">
                Not valid JSON ({jsonProblem}). It is sent as typed, so you can see the 400.
              </p>
            )}
          </div>
        )}
        <Button type="button" size="sm" onClick={() => void send()} disabled={busy}>
          {busy ? <Loader2 aria-hidden="true" className="animate-spin" /> : <Send aria-hidden="true" />}
          {busy ? 'Sending' : 'Send'}
        </Button>
        {failure && (
          <p role="alert" className="m-0 rounded-md border border-destructive/30 bg-destructive-soft p-3 text-sm text-destructive">
            {failure}
          </p>
        )}
        {outcome && (
          <div className="space-y-2" role="region" aria-label="Response">
            <div className="flex flex-wrap items-center gap-2 text-sm">
              <Badge variant={statusVariant(outcome.status)} data-testid="try-it-status">
                {outcome.status} {outcome.statusText}
              </Badge>
              <span className="text-muted-foreground" data-testid="try-it-latency">
                {outcome.ms} ms
              </span>
            </div>
            <Snippet title="Response body" code={outcome.body} lang={outcome.lang === 'json' ? 'json' : 'text'} />
          </div>
        )}
      </div>
    </div>
  );
}
