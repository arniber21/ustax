import { Fragment, type ReactNode } from 'react';
import { Link } from 'react-router';
import { Breadcrumb, BreadcrumbItem, BreadcrumbLink, BreadcrumbList, BreadcrumbPage, BreadcrumbSeparator } from '@/components/ui/breadcrumb';
import { cn } from '@/lib/utils';

/** Standard page width and vertical rhythm. `narrow` is for reading pages. */
export function Page({ narrow = false, className, children }: { narrow?: boolean; className?: string; children: ReactNode }) {
  return (
    <div className={cn('mx-auto px-4 py-8 sm:px-6 sm:py-10', narrow ? 'max-w-3xl' : 'max-w-6xl', className)}>{children}</div>
  );
}

export interface Crumb {
  label: string;
  /** Omit for the current page. */
  to?: string;
}

/** shadcn/ui Breadcrumb from a list; the last crumb is the current page. */
export function Crumbs({ items, className }: { items: readonly Crumb[]; className?: string }) {
  return (
    <Breadcrumb className={className}>
      <BreadcrumbList>
        {items.map((c, i) => (
          <Fragment key={`${c.label}-${i}`}>
            {i > 0 && <BreadcrumbSeparator />}
            <BreadcrumbItem>
              {c.to && i < items.length - 1 ? (
                <BreadcrumbLink asChild>
                  <Link to={c.to} className="text-muted-foreground no-underline hover:text-foreground">
                    {c.label}
                  </Link>
                </BreadcrumbLink>
              ) : (
                <BreadcrumbPage>{c.label}</BreadcrumbPage>
              )}
            </BreadcrumbItem>
          </Fragment>
        ))}
      </BreadcrumbList>
    </Breadcrumb>
  );
}

/** Page title block: breadcrumbs or a small context line, one h1, an optional lead, actions on the right. */
export function PageHeader({
  eyebrow,
  title,
  lead,
  crumbs,
  actions,
  children,
}: {
  eyebrow?: string;
  title: ReactNode;
  lead?: ReactNode;
  crumbs?: readonly Crumb[];
  actions?: ReactNode;
  children?: ReactNode;
}) {
  return (
    <header className="mb-8">
      {crumbs && <Crumbs items={crumbs} className="mb-4" />}
      <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-4">
        <div className="min-w-0">
          {eyebrow && <p className="m-0 mb-2 text-xs font-semibold tracking-wide text-primary uppercase">{eyebrow}</p>}
          <h1 className="m-0 text-3xl leading-tight font-semibold tracking-tight sm:text-[2rem]">{title}</h1>
          {lead && <p className="mt-3 mb-0 max-w-2xl text-base leading-relaxed text-muted-foreground sm:text-lg">{lead}</p>}
        </div>
        {actions && <div className="prov-noprint flex flex-wrap gap-2">{actions}</div>}
      </div>
      {children}
    </header>
  );
}

/** A titled section of a page. */
export function PageSection({
  id,
  title,
  intro,
  badge,
  className,
  children,
}: {
  id: string;
  title: string;
  intro?: ReactNode;
  /** Shown after the heading (e.g. a verification tier). */
  badge?: ReactNode;
  className?: string;
  children: ReactNode;
}) {
  return (
    <section aria-labelledby={id} className={cn('mt-12 scroll-mt-24 first-of-type:mt-0', className)}>
      <div className="flex flex-wrap items-center gap-3">
        <h2 id={id} className="m-0 text-xl font-semibold tracking-tight">
          {title}
        </h2>
        {badge}
      </div>
      {intro && <p className="mt-2 mb-0 max-w-2xl text-sm text-muted-foreground">{intro}</p>}
      <div className="mt-5">{children}</div>
    </section>
  );
}
