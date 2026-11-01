import * as React from 'react';
import { Dialog as BaseDialog } from '@base-ui/react/dialog';
import { X } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from './button';

export const Dialog = BaseDialog.Root;
export const DialogPortal = BaseDialog.Portal;

export function DialogTrigger({ asChild = false, children, ...props }: BaseDialog.Trigger.Props & { asChild?: boolean }) {
  return <BaseDialog.Trigger data-slot="dialog-trigger" render={asChild ? React.Children.only(children) as React.ReactElement : undefined} {...props}>{asChild ? undefined : children}</BaseDialog.Trigger>;
}

export function DialogClose({ asChild = false, children, ...props }: BaseDialog.Close.Props & { asChild?: boolean }) {
  return <BaseDialog.Close data-slot="dialog-close" render={asChild ? React.Children.only(children) as React.ReactElement : undefined} {...props}>{asChild ? undefined : children}</BaseDialog.Close>;
}

export function DialogOverlay({ className, ...props }: Omit<BaseDialog.Backdrop.Props, 'className'> & { className?: string }) {
  return <BaseDialog.Backdrop data-slot="dialog-overlay" className={cn('fixed inset-0 z-50 bg-foreground/25 backdrop-blur-[2px] data-open:animate-in data-closed:animate-out data-open:fade-in-0 data-closed:fade-out-0', className)} {...props} />;
}

export function DialogContent({ className, children, showCloseButton = true, ...props }: Omit<BaseDialog.Popup.Props, 'className'> & { className?: string; showCloseButton?: boolean }) {
  return (
    <DialogPortal>
      <DialogOverlay />
      <BaseDialog.Popup data-slot="dialog-content" className={cn('fixed top-1/2 left-1/2 z-50 grid w-[calc(100%-2rem)] max-w-lg -translate-x-1/2 -translate-y-1/2 gap-4 rounded-xl border bg-background p-6 shadow-xl outline-none duration-150 data-open:animate-in data-closed:animate-out data-open:fade-in-0 data-closed:fade-out-0 data-open:zoom-in-95 data-closed:zoom-out-95', className)} {...props}>
        {children}
        {showCloseButton && (
          <BaseDialog.Close data-slot="dialog-close" aria-label="Close" className="absolute top-4 right-4 rounded-md p-1.5 text-muted-foreground hover:bg-accent focus-visible:outline-2 focus-visible:outline-ring">
            <X aria-hidden="true" className="size-4" />
          </BaseDialog.Close>
        )}
      </BaseDialog.Popup>
    </DialogPortal>
  );
}

export function DialogHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return <div data-slot="dialog-header" className={cn('flex flex-col gap-2 text-left', className)} {...props} />;
}

export function DialogFooter({ className, showCloseButton = false, children, ...props }: React.ComponentProps<'div'> & { showCloseButton?: boolean }) {
  return (
    <div data-slot="dialog-footer" className={cn('flex flex-col-reverse gap-2 sm:flex-row sm:justify-end', className)} {...props}>
      {children}
      {showCloseButton && <BaseDialog.Close render={<Button variant="outline" />}>Close</BaseDialog.Close>}
    </div>
  );
}

export function DialogTitle({ className, ...props }: Omit<BaseDialog.Title.Props, 'className'> & { className?: string }) {
  return <BaseDialog.Title data-slot="dialog-title" className={cn('text-lg leading-snug font-semibold', className)} {...props} />;
}

export function DialogDescription({ className, ...props }: Omit<BaseDialog.Description.Props, 'className'> & { className?: string }) {
  return <BaseDialog.Description data-slot="dialog-description" className={cn('text-sm text-muted-foreground', className)} {...props} />;
}
