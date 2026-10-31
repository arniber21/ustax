import type { CalculateRequest } from '../api';
import { EXAMPLES } from '../examples';

/**
 * The request the results page calculates. Adapter so this page does not depend on the wizard.
 * TODO(after the wizard PR and this PR both merge): replace the body with `return buildRequest(useDraft());` from '../draft'.
 */
export function useCurrentRequest(): CalculateRequest {
  return EXAMPLES.refund;
}
