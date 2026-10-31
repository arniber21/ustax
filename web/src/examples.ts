import type { CalculateRequest } from './api';
import refund from '../../api/examples/refund-single-w2-50k.request.json';
import owe from '../../api/examples/balance-due-single-w2-50k.request.json';
import bonds from '../../api/examples/knocked-out-bond-interest.request.json';

/** Canned requests (api/examples) used by the shell until the wizard collects real answers. */
export const EXAMPLES = {
  /** Single, $50,000 W-2, $5,000 withheld: a refund. */
  refund: refund as CalculateRequest,
  /** Same wages, $3,000 withheld: a balance due. */
  owe: owe as CalculateRequest,
  /** Bond interest: a knockout. */
  bonds: bonds as CalculateRequest,
};
