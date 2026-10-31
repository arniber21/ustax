import { useEffect, useId, useState, type ReactNode } from 'react';

export interface TooltipProps {
  /** Plain-language explanation shown on hover, focus or tap. */
  content: ReactNode;
  /** Visible trigger text, e.g. the jargon word being explained. */
  children: ReactNode;
}

/**
 * Explains jargon in place. The trigger is a real button (keyboard and touch friendly);
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
    <span className="tip" onMouseEnter={() => setOpen(true)} onMouseLeave={() => setOpen(false)}>
      <button
        type="button"
        className="tip__trigger"
        aria-describedby={id}
        aria-expanded={open}
        onClick={() => setOpen(true)}
        onFocus={() => setOpen(true)}
        onBlur={() => setOpen(false)}
      >
        {children}
      </button>
      <span role="tooltip" id={id} className="tip__bubble" hidden={!open}>
        {content}
      </span>
    </span>
  );
}
