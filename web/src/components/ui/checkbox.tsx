import * as React from 'react';
import { Checkbox as CheckboxPrimitive } from '@base-ui/react/checkbox';
import { Check } from 'lucide-react';
import { cn } from '@/lib/utils';

export function Checkbox({ className, ...props }: Omit<React.ComponentProps<typeof CheckboxPrimitive.Root>, 'className'> & { className?: string }) {
  return (
    <CheckboxPrimitive.Root
      data-slot="checkbox"
      className={cn(
        'peer inline-flex size-5 shrink-0 items-center justify-center p-0 rounded-[4px] border border-input bg-background transition-shadow outline-none focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring disabled:cursor-not-allowed disabled:opacity-50 data-checked:border-primary data-checked:bg-primary data-checked:text-primary-foreground aria-invalid:border-destructive',
        className,
      )}
      {...props}
    >
      <CheckboxPrimitive.Indicator data-slot="checkbox-indicator" className="flex size-full items-center justify-center text-current data-unchecked:hidden">
        <Check className="size-3.5" strokeWidth={3} aria-hidden="true" />
      </CheckboxPrimitive.Indicator>
    </CheckboxPrimitive.Root>
  );
}
