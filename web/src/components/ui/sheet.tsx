import * as React from 'react';
import { Dialog } from '@base-ui/react/dialog';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';

export const Sheet = Dialog.Root;
export const SheetClose = Dialog.Close;

export function SheetTrigger({ asChild = false, children, ...props }: Dialog.Trigger.Props & { asChild?: boolean }) {
  return <Dialog.Trigger render={asChild ? React.Children.only(children) as React.ReactElement : undefined} {...props}>{asChild ? undefined : children}</Dialog.Trigger>;
}

/** Base UI supplies modal focus management, Escape dismissal and accessible naming. */
export function SheetContent({ className, children, side = 'right', ...props }:
  Omit<Dialog.Popup.Props, 'className'> & { className?: string; side?: 'right' | 'bottom' }) {
  return (
    <Dialog.Portal>
      <Dialog.Backdrop data-slot="sheet-overlay" className="prov-overlay fixed inset-0 z-50 bg-foreground/25 backdrop-blur-[2px] data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0" />
      <Dialog.Popup
        data-slot="sheet-content"
        data-side={side}
        className={cn(
          'fixed z-50 flex flex-col gap-0 bg-background shadow-xl outline-none duration-200 data-open:animate-in data-closed:animate-out',
          side === 'right' && 'prov-sheet inset-y-0 right-0 h-full w-full border-l data-closed:slide-out-to-right data-open:slide-in-from-right sm:max-w-2xl',
          side === 'bottom' && 'inset-x-0 bottom-0 max-h-[85vh] rounded-t-xl border-t data-closed:slide-out-to-bottom data-open:slide-in-from-bottom',
          className,
        )}
        {...props}
      >
        {children}
        <Dialog.Close className="prov-noprint absolute top-4 right-4 rounded-md p-2 text-muted-foreground hover:bg-accent hover:text-foreground focus-visible:outline-2 focus-visible:outline-ring" aria-label="Close">
          <X aria-hidden="true" className="size-4" />
        </Dialog.Close>
      </Dialog.Popup>
    </Dialog.Portal>
  );
}

export function SheetTitle({ className, ...props }: Omit<Dialog.Title.Props, 'className'> & { className?: string }) {
  return <Dialog.Title data-slot="sheet-title" className={cn('text-lg font-semibold tracking-tight', className)} {...props} />;
}

export function SheetDescription({ className, ...props }: Omit<Dialog.Description.Props, 'className'> & { className?: string }) {
  return <Dialog.Description data-slot="sheet-description" className={cn('text-sm text-muted-foreground', className)} {...props} />;
}
