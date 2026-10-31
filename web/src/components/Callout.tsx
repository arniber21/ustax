import type { ReactNode } from 'react';

export type CalloutTone = 'info' | 'good' | 'warn';

const icon: Record<CalloutTone, string> = { info: 'i', good: '✓', warn: '!' };

export interface CalloutProps {
  tone?: CalloutTone;
  title?: string;
  children: ReactNode;
}

/** A friendly aside. `warn` uses role="alert" semantics via role="note" for non-urgent notices. */
export function Callout({ tone = 'info', title, children }: CalloutProps) {
  return (
    <aside className={`callout callout--${tone}`} role="note">
      <span className="callout__icon" aria-hidden="true">
        {icon[tone]}
      </span>
      <div>
        {title && <p className="callout__title">{title}</p>}
        <div className="callout__body">{children}</div>
      </div>
    </aside>
  );
}
