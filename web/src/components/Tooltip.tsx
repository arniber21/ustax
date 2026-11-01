import { useState, type ReactNode } from 'react';
import { Tooltip as UiTooltip, TooltipContent, TooltipTrigger } from './ui/tooltip';

export interface TooltipProps {
  /** Supplementary explanation shown on hover, focus or tap. Never put essential information only here. */
  content: ReactNode;
  /** Visible trigger text, e.g. the term being explained. */
  children: ReactNode;
}

/**
 * Explains a term in place (shadcn/ui Tooltip). The trigger is a real button with a dotted underline:
 * hover or keyboard focus opens it, a tap toggles it on touch screens, Escape closes it.
 */
export function Tooltip({ content, children }: TooltipProps) {
  const [open, setOpen] = useState(false);
  return (
    <UiTooltip open={open} onOpenChange={setOpen}>
      <TooltipTrigger asChild>
        <button
          type="button"
          className="cursor-help border-0 border-b border-dotted border-current bg-transparent p-0 text-inherit [font:inherit]"
          // Radix closes on pointer down; a tap should toggle instead (touch has no hover).
          onPointerDown={(e) => e.preventDefault()}
          onClick={(e) => {
            e.preventDefault();
            setOpen((o) => !o);
          }}
        >
          {children}
        </button>
      </TooltipTrigger>
      <TooltipContent>{content}</TooltipContent>
    </UiTooltip>
  );
}
