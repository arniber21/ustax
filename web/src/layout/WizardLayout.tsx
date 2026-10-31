import { Navigate, Outlet, useParams } from 'react-router';
import { ButtonLink, Stepper } from '../components';
import { WIZARD_STEPS, stepIndex, stepPath } from './steps';

/** Wizard frame: progress on top, the step (an <Outlet/>) in the middle, Back/Next at the bottom. */
export function WizardLayout() {
  const { step } = useParams();
  const i = stepIndex(step);
  if (i < 0) return <Navigate to={stepPath('about')} replace />;

  const prev = WIZARD_STEPS[i - 1];
  const next = WIZARD_STEPS[i + 1];
  return (
    <div className="container wizard">
      <Stepper steps={WIZARD_STEPS} current={i} />
      <div className="wizard__body" key={step}>
        <Outlet />
      </div>
      <div className="wizard__nav">
        {prev ? (
          <ButtonLink variant="ghost" to={stepPath(prev.id)}>
            ← Back
          </ButtonLink>
        ) : (
          <ButtonLink variant="ghost" to="/">
            ← Home
          </ButtonLink>
        )}
        {next ? (
          <ButtonLink size="lg" to={stepPath(next.id)}>
            Next: {next.label} →
          </ButtonLink>
        ) : (
          <ButtonLink size="lg" to="/results">
            See my result →
          </ButtonLink>
        )}
      </div>
    </div>
  );
}
