import { useEffect, useRef, useState } from 'react';
import { ArrowLeft, ArrowRight, CircleAlert } from 'lucide-react';
import { Navigate, Outlet, useNavigate, useParams } from 'react-router';
import { toast } from 'sonner';
import { Button, ButtonLink, Stepper } from '../components';
import { useDraft, validateDraft, validateStep, type StepErrors } from '../draft';
import { DraftForm } from '../forms/DraftForm';
import { StepErrorsContext } from '../wizard/stepErrors';
import { LiveSummaryBar, LiveSummaryCard, useEstimate } from '../wizard/LiveSummary';
import { WIZARD_STEPS, stepIndex, stepPath } from './steps';

/** Move focus to the field for `path` (opening a collapsed "More" section if needed). */
export function focusField(path: string) {
  const box = document.querySelector<HTMLElement>(`[data-path="${CSS.escape(path)}"]`);
  if (!box) return;
  const go = () => {
    const control = box.querySelector<HTMLElement>('input, select, button, textarea');
    box.scrollIntoView?.({ block: 'center' });
    control?.focus();
  };
  const details = box.closest('details');
  if (details) details.open = true;
  const more = box.closest<HTMLElement>('[data-more][data-state="closed"]');
  if (more) {
    more.querySelector<HTMLElement>('button')?.click();
    requestAnimationFrame(go);
    return;
  }
  go();
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
      className="mb-8 scroll-mt-24 animate-in rounded-xl border border-destructive/50 bg-destructive-soft px-5 py-4 shadow-xs outline-none fade-in-0 slide-in-from-top-1 focus-visible:outline-2 focus-visible:outline-ring"
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

const SAVED_KEY = 'ustax.savedToast';

/** Tell people once per session that their answers persist (and where). */
function useSavedToast() {
  return () => {
    try {
      if (sessionStorage.getItem(SAVED_KEY)) return;
      sessionStorage.setItem(SAVED_KEY, '1');
    } catch {
      return;
    }
    toast.success('Progress saved', { description: 'Your answers are kept in this browser only. Nothing is filed.' });
  };
}

/**
 * Wizard frame: the stepper on the left, the step (an <Outlet/> inside the step's form) in the middle,
 * the running estimate on the right (a bottom bar below 1280px), Back/Next under the step.
 */
export function WizardLayout() {
  const { step } = useParams();
  const navigate = useNavigate();
  const { draft } = useDraft();
  const [attempt, setAttempt] = useState<{ step: string; n: number } | null>(null);
  const estimate = useEstimate();
  const savedToast = useSavedToast();
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
    savedToast();
    navigate(next ? stepPath(next.id) : '/results');
  };

  // On the last step, "Calculate" is only allowed once every earlier step is in order.
  const goResult = () => {
    const all = validateDraft(draft);
    const firstBad = WIZARD_STEPS.find((s) => Object.keys(all[s.id]).length > 0);
    if (firstBad) {
      toast.error(`Check “${firstBad.label}”`, { description: 'Something there needs an answer before we can calculate.' });
      navigate(stepPath(firstBad.id));
      return;
    }
    navigate('/results');
  };

  return (
    <div className="mx-auto grid max-w-6xl gap-8 px-4 py-8 pb-28 sm:px-6 lg:grid-cols-[13rem_minmax(0,1fr)] lg:gap-10 lg:py-10 xl:grid-cols-[13rem_minmax(0,1fr)_17rem] xl:pb-12">
      <aside className="lg:sticky lg:top-24 lg:self-start">
        <Stepper steps={WIZARD_STEPS} current={i} hrefFor={(id) => stepPath(id as (typeof WIZARD_STEPS)[number]['id'])} />
      </aside>
      <div className="min-w-0 max-w-3xl">
        {showSummary && <ErrorSummary key={attempt?.n} errors={errors} />}
        <DraftForm>
          <StepErrorsContext.Provider value={{ errors, attempted }}>
            <div key={step} className="animate-in fade-in-0 slide-in-from-bottom-1 duration-300">
              <Outlet />
            </div>
          </StepErrorsContext.Provider>
        </DraftForm>
        <div className="mt-4 flex flex-wrap-reverse items-center justify-between gap-3 border-t pt-6">
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
      <aside aria-label="Running estimate" className="hidden xl:sticky xl:top-24 xl:block xl:self-start">
        <LiveSummaryCard e={estimate} />
      </aside>
      <LiveSummaryBar e={estimate} />
    </div>
  );
}
