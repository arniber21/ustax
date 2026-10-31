import type { ButtonHTMLAttributes, ReactNode } from 'react';
import { Link, type LinkProps } from 'react-router';

type Variant = 'primary' | 'secondary' | 'ghost';
type Size = 'md' | 'lg';

interface Common {
  variant?: Variant;
  size?: Size;
  children: ReactNode;
}

const cls = (v: Variant, s: Size) => `btn btn--${v} btn--${s}`;

/** A pill button. Use `ButtonLink` when the action is navigation. */
export function Button({
  variant = 'primary',
  size = 'md',
  type = 'button',
  className,
  ...rest
}: Common & ButtonHTMLAttributes<HTMLButtonElement>) {
  return <button type={type} className={`${cls(variant, size)} ${className ?? ''}`} {...rest} />;
}

/** Same look as Button, rendered as a router link. */
export function ButtonLink({ variant = 'primary', size = 'md', className, ...rest }: Common & LinkProps) {
  return <Link className={`${cls(variant, size)} ${className ?? ''}`} {...rest} />;
}
