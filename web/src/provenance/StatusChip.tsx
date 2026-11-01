import { FlaskConical, ShieldCheck } from 'lucide-react';
import { cn } from '@/lib/utils';
import { STATUS_TEXT, type LineStatus } from './status';

/** The proved/tested chip for a Form 1040 line. */
export function StatusChip({ status, className, compact = false }: { status: LineStatus; className?: string; compact?: boolean }) {
  const Icon = status === 'proved' ? ShieldCheck : FlaskConical;
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full border px-1.5 py-px text-[0.6875rem] leading-4 font-semibold',
        status === 'proved' ? 'border-success/30 bg-success-soft text-success' : 'border-border bg-muted text-muted-foreground',
        className,
      )}
    >
      <Icon aria-hidden="true" className="size-3" />
      <span className={cn(compact && "max-sm:sr-only")}>{STATUS_TEXT[status].badge}</span>
    </span>
  );
}
