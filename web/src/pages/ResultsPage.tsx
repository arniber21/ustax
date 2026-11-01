import { Navigate } from 'react-router';
import { useDraft, validateDraft } from '../draft';
import { WIZARD_STEPS, stepPath } from '../layout/steps';
import { ResultsView } from '../results/ResultsView';
import { useCurrentRequest } from '../results/useCurrentRequest';

/** Route /results: calculates the request the wizard has built (see useCurrentRequest). */
export function ResultsPage() {
  const request = useCurrentRequest();
  const { draft } = useDraft();
  if (request === null) {
    const problems = validateDraft(draft);
    const firstBad = WIZARD_STEPS.find((step) => Object.keys(problems[step.id]).length > 0);
    return <Navigate to={stepPath(firstBad?.id ?? 'about')} replace />;
  }
  return <ResultsView request={request} />;
}
