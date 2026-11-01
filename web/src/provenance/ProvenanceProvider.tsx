import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { Scale } from 'lucide-react';
import { formatCents, type Lines } from '../api';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { ProvenanceDrawer } from './ProvenanceDrawer';
import { loadProvenance } from './load';
import { STATUS_TEXT, statusIndex, type LineStatus } from './status';
import { StatusChip } from './StatusChip';

export { StatusChip };

interface Ctx {
  open: (key: string) => void;
  status: Record<string, LineStatus> | null;
}

const Context = createContext<Ctx | null>(null);

/** Opens the provenance drawer for an API line key; null outside a ProvenanceProvider (callers then render no button). */
export const useOpenProvenance = () => useContext(Context)?.open ?? null;

/** Holds the one drawer for the page, and the proved/tested status of each line (from provenance.json). */
export function ProvenanceProvider({ lines, children }: { lines?: Lines; children: ReactNode }) {
  const [key, setKey] = useState<string | null>(null);
  const [status, setStatus] = useState<Record<string, LineStatus> | null>(null);
  const open = useCallback((k: string) => setKey(k), []);
  useEffect(() => {
    let live = true;
    loadProvenance()
      .then((p) => live && setStatus(statusIndex(p)))
      .catch(() => undefined); // no badges; the drawer reports the failure if opened
    return () => {
      live = false;
    };
  }, []);
  const value = useMemo(() => ({ open, status }), [open, status]);
  const amount = key && lines && key in lines ? formatCents((lines as Record<string, number>)[key] ?? 0) : undefined;
  return (
    <Context.Provider value={value}>
      {children}
      <ProvenanceDrawer lineKey={key} amount={amount} onOpenChange={(o) => !o && setKey(null)} />
    </Context.Provider>
  );
}

/**
 * "Law & proof" for one line: a labelled button with a scales icon and a chip saying whether a Lean
 * theorem covers the line ("Proved") or tests do ("Tested"). Opens the provenance drawer: the law, the
 * Catala rule, the proofs and the tests. Renders nothing outside a provider.
 */
export function ProvenanceButton({
  lineKey,
  lineName,
  className,
  compact = false,
  highlight = false,
}: {
  lineKey: string;
  lineName: string;
  className?: string;
  /** Icon and chip only on small screens. */
  compact?: boolean;
  /** Draw attention to it (the first-visit tour). */
  highlight?: boolean;
}) {
  const ctx = useContext(Context);
  if (!ctx) return null;
  const status = ctx.status?.[lineKey];
  const name = `Law & proof for ${lineName}${status ? `: ${STATUS_TEXT[status].badge}` : ''}`;
  return (
    <Button
      type="button"
      variant="outline"
      size="sm"
      data-tour={highlight ? 'on' : undefined}
      className={cn(
        'prov-noprint h-7 gap-1.5 rounded-full border-border px-2 text-xs font-medium text-foreground shadow-none hover:border-primary/50 hover:bg-primary/5 hover:text-primary',
        highlight && 'prov-tour border-primary text-primary',
        className,
      )}
      onClick={() => ctx.open(lineKey)}
      aria-label={name}
      title={`See the law, the rule and the proof behind ${lineName}`}
    >
      <Scale aria-hidden="true" className="size-3.5" />
      <span className={cn(compact && 'max-sm:sr-only')}>Law &amp; proof</span>
      {status && <StatusChip status={status} compact={compact} />}
    </Button>
  );
}
