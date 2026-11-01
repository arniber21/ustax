import { createContext, useCallback, useContext, useState, type ReactNode } from 'react';
import { HelpCircle } from 'lucide-react';
import { formatCents, type Lines } from '../api';
import { Button } from '@/components/ui/button';
import { ProvenanceDrawer } from './ProvenanceDrawer';

const Ctx = createContext<((key: string) => void) | null>(null);

/** Opens the provenance drawer for an API line key; null outside a ProvenanceProvider (callers then render no button). */
export const useOpenProvenance = () => useContext(Ctx);

/** Holds the one drawer for the page. `lines` is only used to show the amount in the drawer header. */
export function ProvenanceProvider({ lines, children }: { lines?: Lines; children: ReactNode }) {
  const [key, setKey] = useState<string | null>(null);
  const open = useCallback((k: string) => setKey(k), []);
  const amount = key && lines && key in lines ? formatCents((lines as Record<string, number>)[key] ?? 0) : undefined;
  return (
    <Ctx.Provider value={open}>
      {children}
      <ProvenanceDrawer lineKey={key} amount={amount} onOpenChange={(o) => !o && setKey(null)} />
    </Ctx.Provider>
  );
}

/** The "How was this calculated?" button for one line. Renders nothing outside a provider. */
export function ProvenanceButton({ lineKey, lineName, className }: { lineKey: string; lineName: string; className?: string }) {
  const open = useOpenProvenance();
  if (!open) return null;
  return (
    <Button
      type="button"
      variant="link"
      size="sm"
      className={`prov-noprint h-auto p-0 text-xs ${className ?? ''}`}
      onClick={() => open(lineKey)}
      aria-label={`How was ${lineName} calculated?`}
    >
      <HelpCircle aria-hidden="true" className="size-3.5" />
      How was this calculated?
    </Button>
  );
}
