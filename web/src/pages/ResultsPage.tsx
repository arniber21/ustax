import { ResultsView } from '../results/ResultsView';
import { useCurrentRequest } from '../results/useCurrentRequest';

/** Route /results: calculates whatever request the app currently has (see useCurrentRequest). */
export function ResultsPage() {
  return <ResultsView request={useCurrentRequest()} />;
}
