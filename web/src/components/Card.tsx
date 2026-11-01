import type { ElementType, HTMLAttributes, ReactNode } from 'react';
import { cn } from '@/lib/utils';

export interface CardProps extends HTMLAttributes<HTMLElement> {
  as?: ElementType;
  /** `muted` is a quiet grey panel; `plain` the default bordered surface. (`sun`/`brand` are kept as aliases of `muted`.) */
  tone?: 'plain' | 'muted' | 'sun' | 'brand';
  children: ReactNode;
}

/** A bordered surface (shadcn/ui Card look) that can render as any element, e.g. a <section>. */
export function Card({ as: Tag = 'section', tone = 'plain', className, ...rest }: CardProps) {
  return (
    <Tag
      className={cn(
        'rounded-lg border p-5 text-card-foreground sm:p-6',
        tone === 'plain' ? 'bg-card' : 'bg-muted',
        className,
      )}
      {...rest}
    />
  );
}
