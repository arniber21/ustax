import type { ReactNode } from 'react';

export interface BadgeProps {
  tone?: 'neutral' | 'good' | 'warn' | 'sun';
  children: ReactNode;
}

/** A small status pill, e.g. "Proven" or "Coming soon". */
export function Badge({ tone = 'neutral', children }: BadgeProps) {
  return <span className={`badge badge--${tone}`}>{children}</span>;
}
