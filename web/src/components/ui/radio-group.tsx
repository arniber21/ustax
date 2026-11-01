import * as React from 'react';
import { RadioGroup as BaseRadioGroup } from '@base-ui/react/radio-group';
import { Radio } from '@base-ui/react/radio';
import { cn } from '@/lib/utils';

export function RadioGroup({ className, ...props }: Omit<BaseRadioGroup.Props<string>, 'className'> & { className?: string }) {
  return <BaseRadioGroup data-slot="radio-group" className={cn('grid gap-3', className)} {...props} />;
}

export function RadioGroupItem({ className, ...props }: Omit<React.ComponentProps<typeof Radio.Root>, 'className'> & { className?: string }) {
  return (
    <Radio.Root
      data-slot="radio-group-item"
      className={cn(
        'peer inline-flex aspect-square size-5 shrink-0 items-center justify-center p-0 rounded-full border border-input bg-background transition-[color,box-shadow] outline-none focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring disabled:cursor-not-allowed disabled:opacity-50 data-checked:border-primary aria-invalid:border-destructive',
        className,
      )}
      {...props}
    >
      <Radio.Indicator data-slot="radio-group-indicator" className="flex size-full items-center justify-center data-unchecked:hidden">
        <span className="size-2.5 rounded-full bg-primary" />
      </Radio.Indicator>
    </Radio.Root>
  );
}
