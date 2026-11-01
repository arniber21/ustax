import { useEffect, useId, useState, type ReactNode } from 'react';

export interface TooltipProps {
  /** Supplementary explanation shown on hover, focus or tap. Never put essential information only here. */
  content: ReactNode;
  /** Visible trigger text, e.g. the term being explained. */
  children: ReactNode;
}

/**
 * Explains a term in place. The trigger is a real button (keyboard and touch friendly);
 * the bubble is wired with aria-describedby and closes on Escape.
 */
export function Tooltip({ content, children }: TooltipProps) {
  const id = useId();
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false);
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open]);

  return (
    <span className="relative inline-block" onMouseEnter={() => setOpen(true)} onMouseLeave={() => setOpen(false)}>
      <button
        type="button"
        className="cursor-help border-0 border-b border-dotted border-current bg-transparent p-0 text-inherit"
        aria-describedby={id}
        aria-expanded={open}
        onClick={() => setOpen(true)}
        onFocus={() => setOpen(true)}
        onBlur={() => setOpen(false)}
      >
        {children}
      </button>
      <span
        role="tooltip"
        id={id}
        hidden={!open}
        className="absolute bottom-[calc(100%+6px)] left-0 z-20 w-max max-w-[min(18rem,80vw)] rounded-md bg-foreground px-3 py-2 text-xs leading-snug text-background"
      >
        {content}
      </span>
    </span>
  );
}
