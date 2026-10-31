import { ButtonLink, Callout } from '../components';
import { UnsupportedView } from '../knockout/UnsupportedView';
import { EXAMPLES } from '../examples';
import { useLiveCalculation } from '../results/useLiveCalculation';

export { UnsupportedView };

/**
 * Route /cant-do-yet. The results page shows the same view inline when a calculation is a knockout; this
 * route is the standalone, linkable version. Until the wizard feeds real answers it explains the bond-interest example.
 */
export function UnsupportedPage() {
  const { state } = useLiveCalculation(EXAMPLES.bonds, { debounceMs: 0 });
  if (state.status === 'knockout') return <UnsupportedView reasons={state.reasons} />;
  if (state.status === 'loading') {
    return (
      <p role="status" className="container">
        Checking…
      </p>
    );
  }
  return (
    <div className="container narrow">
      <Callout tone="good" title="Nothing to explain">
        We have no unsupported situation to show right now.
      </Callout>
      <ButtonLink to="/results">See my result</ButtonLink>
    </div>
  );
}
