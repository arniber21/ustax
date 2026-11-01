import * as React from 'react';
import { Button as BaseButton } from '@base-ui/react/button';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

export const buttonVariants = cva(
  "inline-flex shrink-0 items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium no-underline transition-all outline-none focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary-hover',
        destructive: 'bg-destructive text-white hover:bg-destructive/90 dark:bg-red-700 dark:hover:bg-red-800',
        outline: 'border border-input/60 bg-background text-foreground hover:bg-accent hover:border-input',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/70',
        ghost: 'text-foreground hover:bg-accent',
        link: 'text-primary underline underline-offset-4 hover:decoration-2',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-8 px-3 text-sm',
        lg: 'h-11 px-6 text-base',
        icon: 'size-10',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
);

export type ButtonProps = Omit<BaseButton.Props, 'className'> & VariantProps<typeof buttonVariants> & { className?: string; asChild?: boolean };

export function Button({ className, variant, size, asChild = false, children, ...props }: ButtonProps) {
  return (
    <BaseButton
      data-slot="button"
      className={cn(buttonVariants({ variant, size, className }))}
      nativeButton={!asChild}
      render={asChild ? React.Children.only(children) as React.ReactElement : undefined}
      {...props}
    >
      {asChild ? undefined : children}
    </BaseButton>
  );
}
