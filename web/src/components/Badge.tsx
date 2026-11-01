import type { ReactNode } from 'react';
import { Badge as UiBadge } from './ui/badge';

export interface BadgeProps {
  tone?: 'neutral' | 'good' | 'warn' | 'sun';
  children: ReactNode;
  className?: string;
}

const variant = { neutral: 'secondary', good: 'success', warn: 'destructive', sun: 'warning' } as const;

/** A small status label, e.g. "Proven" or "Tested". */
export function Badge({ tone = 'neutral', children, className }: BadgeProps) {
  return (
    <UiBadge variant={variant[tone]} className={className}>
      {children}
    </UiBadge>
  );
}
