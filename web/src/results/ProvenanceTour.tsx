import { useEffect, useState } from 'react';
import { Scale, Sparkles, X } from 'lucide-react';
import { Button } from '../components/ui/button';
import { useOpenProvenance } from '../provenance';
import { TOUR_LINE } from './LineWalk';

export const TOUR_KEY = 'ustax.provenanceTour.v1';
/** How long the tour highlight stays on the line 15 button. */
export const TOUR_MS = 5000;

const seen = () => {
  try {
    return localStorage.getItem(TOUR_KEY) === 'done';
  } catch {
    return true;
  }
};
const markSeen = () => {
  try {
    localStorage.setItem(TOUR_KEY, 'done');
  } catch {
    /* ignore */
  }
};

/**
 * First-visit tour state: `show` (the callout is visible until dismissed) and `pulse` (the line 15
 * "Law & proof" button is highlighted for 5 seconds after the page opens or "Show me" is pressed).
 */
export function useProvenanceTour() {
  const [show, setShow] = useState(() => !seen());
  const [pulse, setPulse] = useState(show);
  useEffect(() => {
    if (!pulse) return;
    const t = setTimeout(() => setPulse(false), TOUR_MS);
    return () => clearTimeout(t);
  }, [pulse]);
  return {
    show,
    pulse,
    dismiss: () => {
      markSeen();
      setShow(false);
      setPulse(false);
    },
    replay: () => {
      setPulse(false);
      requestAnimationFrame(() => setPulse(true));
      document.querySelector('[data-tour="on"], #line-by-line')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    },
  };
}

/**
 * "See how every number was derived": the callout at the top of the results. It points at the Law & proof
 * buttons, can highlight the one on line 15, open it directly, or be dismissed for good (localStorage).
 */
export function ProvenanceCallout({ onDismiss, onShowMe }: { onDismiss: () => void; onShowMe: () => void }) {
  const open = useOpenProvenance();
  return (
    <aside
      aria-label="How every number was derived"
      className="prov-noprint relative flex flex-col gap-4 overflow-hidden rounded-xl border border-primary/25 bg-info-soft p-5 pr-12 sm:flex-row sm:items-center sm:p-6 sm:pr-14"
    >
      <span aria-hidden="true" className="grid size-10 shrink-0 place-items-center rounded-xl bg-primary text-primary-foreground shadow-sm">
        <Scale className="size-5" />
      </span>
      <div className="grid flex-1 gap-1">
        <p className="m-0 font-semibold">See how every number was derived: click any line</p>
        <p className="m-0 text-sm text-muted-foreground">
          Each line has a <span className="font-medium text-foreground">Law &amp; proof</span> button: the statute, the Catala rule
          that encodes it, the Lean theorems that are proved about it, and the tests against IRS Direct File.
        </p>
      </div>
      <div className="flex shrink-0 flex-wrap gap-2">
        <Button variant="outline" size="sm" className="bg-background" onClick={onShowMe}>
          <Sparkles aria-hidden="true" />
          Show me
        </Button>
        {open && (
          <Button size="sm" onClick={() => open(TOUR_LINE)}>
            Open line 15
          </Button>
        )}
      </div>
      <Button
        variant="ghost"
        size="icon"
        className="absolute top-2 right-2 size-8 text-muted-foreground"
        aria-label="Dismiss this tip"
        onClick={onDismiss}
      >
        <X aria-hidden="true" />
      </Button>
    </aside>
  );
}
