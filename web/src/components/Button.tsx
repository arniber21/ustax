import type { ButtonHTMLAttributes, ReactNode } from 'react';
import { Link, type LinkProps } from 'react-router';
import { Button as UiButton, buttonVariants } from './ui/button';
import { cn } from '@/lib/utils';

type Variant = 'primary' | 'secondary' | 'ghost';
type Size = 'md' | 'lg';

interface Common {
  variant?: Variant;
  size?: Size;
  children: ReactNode;
}

const ui = { primary: 'default', secondary: 'outline', ghost: 'ghost' } as const;
const sizes = { md: 'default', lg: 'lg' } as const;

/** A button (shadcn/ui). Use `ButtonLink` when the action is navigation. Defaults to type="button". */
export function Button({ variant = 'primary', size = 'md', type = 'button', ...rest }: Common & ButtonHTMLAttributes<HTMLButtonElement>) {
  return <UiButton type={type} variant={ui[variant]} size={sizes[size]} {...rest} />;
}

/** Same look as Button, rendered as a router link. */
export function ButtonLink({ variant = 'primary', size = 'md', className, ...rest }: Common & LinkProps) {
  return <Link className={cn(buttonVariants({ variant: ui[variant], size: sizes[size] }), className)} {...rest} />;
}
