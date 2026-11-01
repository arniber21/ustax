import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

/** Standard page width and vertical rhythm. `narrow` is for reading pages. */
export function Page({ narrow = false, className, children }: { narrow?: boolean; className?: string; children: ReactNode }) {
  return (
    <div className={cn('mx-auto px-4 py-10 sm:px-6 sm:py-12', narrow ? 'max-w-3xl' : 'max-w-6xl', className)}>{children}</div>
  );
}

/** Page title block: small context line, one h1, an optional lead paragraph. */
export function PageHeader({ eyebrow, title, lead, children }: { eyebrow?: string; title: ReactNode; lead?: ReactNode; children?: ReactNode }) {
  return (
    <header className="mb-8">
      {eyebrow && <p className="m-0 mb-2 text-sm font-medium text-muted-foreground">{eyebrow}</p>}
      <h1 className="m-0 text-3xl leading-tight font-semibold tracking-tight sm:text-[2rem]">{title}</h1>
      {lead && <p className="mt-3 mb-0 max-w-2xl text-base leading-relaxed text-muted-foreground sm:text-lg">{lead}</p>}
      {children}
    </header>
  );
}

/** A titled section of a page. */
export function PageSection({ id, title, intro, className, children }: { id: string; title: string; intro?: ReactNode; className?: string; children: ReactNode }) {
  return (
    <section aria-labelledby={id} className={cn('mt-12 first-of-type:mt-0', className)}>
      <h2 id={id} className="m-0 text-xl font-semibold tracking-tight">
        {title}
      </h2>
      {intro && <p className="mt-2 mb-0 max-w-2xl text-sm text-muted-foreground">{intro}</p>}
      <div className="mt-5">{children}</div>
    </section>
  );
}
