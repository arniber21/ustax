import { Navigate } from 'react-router';
import { ResultsView } from '../results/ResultsView';
import { useCurrentRequest } from '../results/useCurrentRequest';

/** Route /results: calculates the request the wizard has built (see useCurrentRequest). */
export function ResultsPage() {
  const request = useCurrentRequest();
  if (request === null) return <Navigate to="/start/about" replace />;
  return <ResultsView request={request} />;
}
