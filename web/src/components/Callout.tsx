import type { ReactNode } from 'react';
import { CircleAlert, CircleCheck, Info } from 'lucide-react';
import { Alert, AlertDescription, AlertTitle } from './ui/alert';

export type CalloutTone = 'info' | 'good' | 'warn';

const variant = { info: 'default', good: 'success', warn: 'warning' } as const;
const Icon = { info: Info, good: CircleCheck, warn: CircleAlert };

export interface CalloutProps {
  tone?: CalloutTone;
  title?: string;
  children: ReactNode;
  className?: string;
}

/** A non-urgent notice (shadcn/ui Alert with role="note"). Use `Alert` directly for urgent messages. */
export function Callout({ tone = 'info', title, children, className }: CalloutProps) {
  const I = Icon[tone];
  return (
    <Alert variant={variant[tone]} role="note" className={className}>
      <I aria-hidden="true" />
      {title && <AlertTitle>{title}</AlertTitle>}
      <AlertDescription>{children}</AlertDescription>
    </Alert>
  );
}
