import { createContext, useContext, useRef, useState, type ReactNode } from 'react';
import { AlertDialog } from '@base-ui/react/alert-dialog';
import { useNavigate } from 'react-router';
import { RotateCcw } from 'lucide-react';
import { toast } from 'sonner';
import { emptyDraft, useDraft } from '../draft';
import { Button } from './ui/button';

const ClearReturnContext = createContext<(() => void) | null>(null);

export function useClearReturn() {
  const show = useContext(ClearReturnContext);
  if (!show) throw new Error('useClearReturn requires ClearReturnProvider');
  return show;
}

/** One confirmation shared by the header, review page and command palette. */
export function ClearReturnProvider({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const cancel = useRef<HTMLButtonElement>(null);
  const cleared = useRef(false);
  const { reset } = useDraft();
  const navigate = useNavigate();
  const show = () => { cleared.current = false; setOpen(true); };
  const clear = () => {
    cleared.current = true;
    reset();
    setOpen(false);
    navigate('/start/about');
    toast.success('Return cleared', { description: 'Your saved answers have been removed from this browser.' });
  };
  return (
    <ClearReturnContext.Provider value={show}>
      {children}
      <AlertDialog.Root open={open} onOpenChange={setOpen}>
        <AlertDialog.Portal>
          <AlertDialog.Backdrop className="fixed inset-0 z-[70] bg-foreground/20 backdrop-blur-[2px]" />
          <AlertDialog.Popup
            initialFocus={cancel}
            finalFocus={() => cleared.current ? document.getElementById('main') : true}
            className="fixed top-1/2 left-1/2 z-[70] w-[calc(100%-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-xl border bg-background p-6 shadow-xl outline-none"
          >
            <AlertDialog.Title className="m-0 text-xl font-semibold tracking-tight">Clear this return?</AlertDialog.Title>
            <AlertDialog.Description className="mt-3 mb-6 text-sm leading-relaxed text-muted-foreground">
              This removes all saved answers and results from this browser. You will start with an empty return. This cannot be undone.
            </AlertDialog.Description>
            <div className="flex flex-wrap justify-end gap-2">
              <AlertDialog.Close render={<Button ref={cancel} variant="outline" />}>Keep my return</AlertDialog.Close>
              <Button variant="destructive" onClick={clear}>Clear return</Button>
            </div>
          </AlertDialog.Popup>
        </AlertDialog.Portal>
      </AlertDialog.Root>
    </ClearReturnContext.Provider>
  );
}

export function ClearReturnButton({ compact = false }: { compact?: boolean }) {
  const show = useClearReturn();
  const { draft } = useDraft();
  const hasAnswers = JSON.stringify(draft) !== JSON.stringify(emptyDraft());
  return (
    <Button variant="ghost" size="sm" onClick={show} disabled={!hasAnswers} className="text-muted-foreground" aria-label="Clear return" title="Clear return">
      <RotateCcw aria-hidden="true" />
      <span className={compact ? 'hidden lg:inline' : ''}>Clear return</span>
    </Button>
  );
}
