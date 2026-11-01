import { FlaskConical, ShieldCheck } from 'lucide-react';
import { cn } from '@/lib/utils';
import { CATALA, type ClaimStatus } from './facts';

/**
 * The two verification tiers, styled apart so nobody reads one as the other:
 * "Proved" (green, shield) is a Lean theorem; "Verified (tested)" (blue, flask) is Catala agreeing with
 * IRS Direct File on every scenario we have, which is evidence, not a proof.
 */
export function TierBadge({ status, className }: { status: ClaimStatus; className?: string }) {
  const proved = status === 'proven';
  const Icon = proved ? ShieldCheck : FlaskConical;
  return (
    <span
      className={cn(
        'inline-flex w-fit shrink-0 items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-semibold whitespace-nowrap',
        proved ? 'border-success/30 bg-success-soft text-success' : 'border-primary/25 bg-info-soft text-primary',
        className,
      )}
    >
      <Icon aria-hidden="true" className="size-3.5" />
      {proved ? 'Proved' : 'Verified (tested)'}
    </span>
  );
}

/** One line under any list that uses both badges. */
export function TierLegend({ className }: { className?: string }) {
  return (
    <p className={cn('m-0 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs leading-relaxed text-muted-foreground', className)}>
      <TierBadge status="proven" />
      <TierBadge status="tested" />
      <span>{CATALA.legend}</span>
    </p>
  );
}
