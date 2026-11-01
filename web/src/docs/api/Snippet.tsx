import { useEffect, useState } from 'react';
import { Check, Copy } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { CodeBlock } from '../Markdown';

export function CopyButton({ text, label }: { text: string; label: string }) {
  const [done, setDone] = useState(false);
  useEffect(() => {
    if (!done) return;
    const t = setTimeout(() => setDone(false), 1500);
    return () => clearTimeout(t);
  }, [done]);
  return (
    <Button
      type="button"
      variant="ghost"
      size="sm"
      aria-label={label}
      className="h-7 gap-1 px-2 text-xs text-muted-foreground"
      onClick={() => {
        void navigator.clipboard?.writeText(text).then(() => setDone(true), () => undefined);
      }}
    >
      {done ? <Check aria-hidden="true" /> : <Copy aria-hidden="true" />}
      <span aria-live="polite">{done ? 'Copied' : 'Copy'}</span>
    </Button>
  );
}

/** A highlighted code block with a title bar and a copy button. Shiki loads lazily inside CodeBlock. */
export function Snippet({ title, code, lang }: { title: string; code: string; lang: string }) {
  return (
    <figure className="m-0 overflow-hidden rounded-lg border">
      <figcaption className="flex items-center justify-between border-b bg-muted/50 py-1 pr-2 pl-4 text-xs font-medium text-muted-foreground">
        {title}
        <CopyButton text={code} label={`Copy ${title}`} />
      </figcaption>
      <div className="[&_.doc-code]:m-0 [&_.doc-code]:max-h-96 [&_.doc-code]:rounded-none [&_.doc-code]:border-0">
        <CodeBlock code={code} fence={lang} />
      </div>
    </figure>
  );
}
