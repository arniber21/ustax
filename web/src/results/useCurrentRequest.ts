import type { CalculateRequest } from '../api';
import { useDraft } from '../draft';

/**
 * The request the results page calculates: whatever the wizard has collected so far.
 * Returns null until the user has chosen a filing status (the page then sends them back to the start).
 */
export function useCurrentRequest(): CalculateRequest | null {
  return useDraft().request;
}
