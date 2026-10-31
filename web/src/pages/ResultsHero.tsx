import { formatCents } from '../api';
import type { Lines, Outcome } from '../api';

export interface ResultsHeroProps {
  outcome: Outcome;
  lines: Lines;
  /** Dim the numbers while a fresh calculation is in flight. */
  stale?: boolean;
}

/** The big number: what the filer gets back, or owes. Always integer cents underneath. */
export function ResultsHero({ outcome, lines, stale = false }: ResultsHeroProps) {
  const refund = outcome === 'refund';
  const owe = outcome === 'balance_due';
  const amount = refund ? lines.overpayment : owe ? lines.balance_due : 0;
  const eyebrow = refund ? 'Good news. Your refund is' : owe ? 'You’ll owe' : 'You’re all square';
  const sub = refund
    ? 'That’s what the IRS sends back to you, because you paid in more than your tax came to.'
    : owe
      ? 'That’s what’s left to pay by April 15 after what your employer already sent in.'
      : 'You paid in exactly what you owe. Nothing to send, nothing to get back.';
  return (
    <section
      className={`hero hero--${refund ? 'refund' : owe ? 'owe' : 'even'}${stale ? ' is-stale' : ''}`}
      aria-labelledby="hero-eyebrow"
      aria-busy={stale}
    >
      <p className="hero__eyebrow" id="hero-eyebrow">
        {eyebrow}
      </p>
      <p className="hero__amount num" aria-live="polite">
        {formatCents(amount, { showCents: false })}
        <span className="hero__cents">.{(amount % 100).toString().padStart(2, '0')}</span>
      </p>
      <p className="hero__sub">{sub}</p>
    </section>
  );
}
