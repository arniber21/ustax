import type { ElementType, HTMLAttributes, ReactNode } from 'react';

export interface CardProps extends HTMLAttributes<HTMLElement> {
  as?: ElementType;
  tone?: 'plain' | 'sun' | 'brand';
  children: ReactNode;
}

/** A soft rounded surface. `tone` tints it for emphasis. */
export function Card({ as: Tag = 'section', tone = 'plain', className, ...rest }: CardProps) {
  return <Tag className={`card card--${tone} ${className ?? ''}`} {...rest} />;
}
