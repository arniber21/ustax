import type { CalculateRequest } from '../api';
import { useDraft } from '../draft';

/**
 * The request the results page calculates: whatever the wizard has collected so far.
 * Returns null until required answers are complete and the wizard supports the return.
 */
export function useCurrentRequest(): CalculateRequest | null {
  return useDraft().request;
}
