import { useEffect, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, CircleAlert } from 'lucide-react';
import { Navigate, Outlet, useNavigate, useParams } from 'react-router';
import { Button, ButtonLink, Stepper } from '../components';
import { useDraft, validateDraft, validateStep, type StepErrors } from '../draft';
import { StepErrorsContext } from '../wizard/stepErrors';
import { WIZARD_STEPS, stepIndex, stepPath } from './steps';

/** Move focus to the field for `path` (opening a collapsed <details> if needed). */
function focusField(path: string) {
  const box = document.querySelector<HTMLElement>(`[data-path="${CSS.escape(path)}"]`);
  if (!box) return;
  const details = box.closest('details');
  if (details) details.open = true;
  const control = box.querySelector<HTMLElement>('input, select, button, textarea');
  box.scrollIntoView?.({ block: 'center' });
  control?.focus();
}

/** GOV.UK-style error summary: every problem on the step, each one a link to its field. */
function ErrorSummary({ errors }: { errors: StepErrors }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    ref.current?.focus();
    ref.current?.scrollIntoView?.({ block: 'start' });
  }, []);
  const entries = Object.entries(errors);
  return (
    <div
      ref={ref}
      tabIndex={-1}
      aria-labelledby="error-summary-h"
      role="group"
      className="mb-8 scroll-mt-6 rounded-md border-2 border-destructive bg-background px-5 py-4 outline-none focus-visible:outline-2 focus-visible:outline-ring"
    >
      <h2 id="error-summary-h" className="m-0 flex items-center gap-2 text-base font-semibold">
        <CircleAlert aria-hidden="true" className="size-5 text-destructive" />
        {entries.length === 1 ? 'There is a problem' : `There are ${entries.length} problems`}
      </h2>
      <ul className="mt-2 mb-0 grid list-disc gap-1 pl-12 text-sm marker:text-destructive">
        {entries.map(([path, msg]) => (
          <li key={path}>
            <a
              href={`#${path}`}
              className="font-medium text-destructive"
              onClick={(e) => {
                e.preventDefault();
                focusField(path);
              }}
            >
              {msg}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}

/** Wizard frame: step list on the left (top on phones), the step (an <Outlet/>) on the right, Back/Next below. */
export function WizardLayout() {
  const { step } = useParams();
  const navigate = useNavigate();
  const { draft } = useDraft();
  const [attempt, setAttempt] = useState<{ step: string; n: number } | null>(null);
  const i = stepIndex(step);
  if (i < 0) return <Navigate to={stepPath('about')} replace />;

  const current = WIZARD_STEPS[i]!;
  const prev = WIZARD_STEPS[i - 1];
  const next = WIZARD_STEPS[i + 1];
  const errors = validateStep(draft, current.id);
  const attempted = attempt?.step === current.id;
  const showSummary = attempted && Object.keys(errors).length > 0;

  const goNext = () => {
    if (Object.keys(errors).length > 0) {
      setAttempt({ step: current.id, n: (attempt?.n ?? 0) + 1 });
      return;
    }
    navigate(next ? stepPath(next.id) : '/results');
  };

  // On the last step, "Calculate" is only allowed once every earlier step is in order.
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
    <div className="mx-auto grid max-w-6xl gap-8 px-4 py-8 sm:px-6 lg:grid-cols-[13rem_minmax(0,1fr)] lg:gap-16 lg:py-12">
      <aside className="lg:sticky lg:top-8 lg:self-start">
        <Stepper steps={WIZARD_STEPS} current={i} hrefFor={(id) => stepPath(id as (typeof WIZARD_STEPS)[number]['id'])} />
      </aside>
      <div className="min-w-0 max-w-2xl">
        {showSummary && <ErrorSummary key={attempt?.n} errors={errors} />}
        <StepErrorsContext.Provider value={{ errors, attempted }}>
          <div key={step} className="animate-in fade-in-0 duration-300">
            <Outlet />
          </div>
        </StepErrorsContext.Provider>
        <div className="mt-10 flex flex-wrap-reverse items-center justify-between gap-3 border-t pt-6">
          {prev ? (
            <ButtonLink variant="ghost" to={stepPath(prev.id)}>
              <ArrowLeft aria-hidden="true" />
              Back
            </ButtonLink>
          ) : (
            <ButtonLink variant="ghost" to="/">
              <ArrowLeft aria-hidden="true" />
              Home
            </ButtonLink>
          )}
          {next ? (
            <Button size="lg" onClick={goNext}>
              Next: {next.label}
              <ArrowRight aria-hidden="true" />
            </Button>
          ) : (
            <Button size="lg" onClick={goResult}>
              Calculate my return
              <ArrowRight aria-hidden="true" />
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}
