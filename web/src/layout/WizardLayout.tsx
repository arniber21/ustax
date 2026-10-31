import { useState } from 'react';
import { Navigate, Outlet, useNavigate, useParams } from 'react-router';
import { Button, ButtonLink, Stepper } from '../components';
import { useDraft, validateDraft, validateStep } from '../draft';
import { StepErrorsContext } from '../wizard/stepErrors';
import { WIZARD_STEPS, stepIndex, stepPath } from './steps';

/** Bring the first problem into view so nobody has to hunt for what is wrong. */
function revealFirstProblem() {
  setTimeout(() => {
    const el = document.querySelector('.field__error');
    (el as HTMLElement | null)?.scrollIntoView?.({ block: 'center', behavior: 'smooth' });
  }, 0);
}

/** Wizard frame: progress on top, the step (an <Outlet/>) in the middle, Back/Next at the bottom. */
export function WizardLayout() {
  const { step } = useParams();
  const navigate = useNavigate();
  const { draft } = useDraft();
  const [attemptedStep, setAttemptedStep] = useState<string | null>(null);
  const i = stepIndex(step);
  if (i < 0) return <Navigate to={stepPath('about')} replace />;

  const current = WIZARD_STEPS[i]!;
  const prev = WIZARD_STEPS[i - 1];
  const next = WIZARD_STEPS[i + 1];
  const errors = validateStep(draft, current.id);

  const goNext = () => {
    if (Object.keys(errors).length > 0) {
      setAttemptedStep(current.id);
      revealFirstProblem();
      return;
    }
    navigate(next ? stepPath(next.id) : '/results');
  };

  // On the last step, "See my result" is only allowed once every earlier step is in order.
  const goResult = () => {
    const all = validateDraft(draft);
    const firstBad = WIZARD_STEPS.find((s) => Object.keys(all[s.id]).length > 0);
    if (firstBad) {
      navigate(stepPath(firstBad.id));
      return;
    }
    navigate('/results');
  };

  return (
    <div className="container wizard">
      <Stepper steps={WIZARD_STEPS} current={i} />
      <StepErrorsContext.Provider value={{ errors, attempted: attemptedStep === current.id }}>
        <div className="wizard__body" key={step}>
          <Outlet />
        </div>
      </StepErrorsContext.Provider>
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
          <Button size="lg" onClick={goNext}>
            Next: {next.label} →
          </Button>
        ) : (
          <Button size="lg" onClick={goResult}>
            See my result →
          </Button>
        )}
      </div>
    </div>
  );
}
