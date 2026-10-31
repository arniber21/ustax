import { useParams } from 'react-router';
import { Badge, Card } from '../components';
import { WIZARD_STEPS, stepIndex } from '../layout/steps';

/** Which issue builds each step. Placeholder until those land. */
const BUILT_BY: Record<string, string> = {
  about: '#76',
  household: '#76',
  income: '#77',
  adjustments: '#78',
  review: '#78',
};

/** Placeholder step route. The next agents replace the body per step id. */
export function StepPage() {
  const { step } = useParams();
  const s = WIZARD_STEPS[stepIndex(step)];
  if (!s) return null;
  return (
    <Card>
      <Badge tone="sun">Coming soon</Badge>
      <h1>{s.label}</h1>
      <p>{s.blurb}</p>
      <p className="muted">
        This step is a placeholder. The questions land with {BUILT_BY[s.id] ?? 'a later issue'}; the layout, progress
        and navigation around it already work.
      </p>
    </Card>
  );
}
