import { createContext, useContext } from 'react';
import type { StepErrors } from '../draft';

interface Value {
  errors: StepErrors;
  /** Errors stay quiet until the person tries to continue. */
  attempted: boolean;
}

export const StepErrorsContext = createContext<Value>({ errors: {}, attempted: false });

/** The message for a field path, only after the person tried to move on. */
export function useStepError(path: string | undefined): string | undefined {
  const { errors, attempted } = useContext(StepErrorsContext);
  return attempted && path ? errors[path] : undefined;
}
