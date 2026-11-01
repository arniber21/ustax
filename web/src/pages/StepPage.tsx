import { useParams } from 'react-router';
import { AboutStep } from '../wizard/AboutStep';
import { AdjustmentsStep } from '../wizard/AdjustmentsStep';
import { HouseholdStep } from '../wizard/HouseholdStep';
import { IncomeStep } from '../wizard/IncomeStep';
import { ReviewStep } from '../wizard/ReviewStep';

/** Chooses the body for `/start/:step`. Progress and Back/Next live in `WizardLayout`. */
export function StepPage() {
  const { step } = useParams();
  switch (step) {
    case 'about':
      return <AboutStep />;
    case 'household':
      return <HouseholdStep />;
    case 'income':
      return <IncomeStep />;
    case 'adjustments':
      return <AdjustmentsStep />;
    case 'review':
      return <ReviewStep />;
    default:
      return null;
  }
}
