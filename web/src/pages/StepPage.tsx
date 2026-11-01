import { useParams } from 'react-router';
import { AboutStep } from '../wizard/AboutStep';
import { AdjustmentsStep } from '../wizard/AdjustmentsStep';
import { CreditsStep } from '../wizard/CreditsStep';
import { DependentsStep } from '../wizard/DependentsStep';
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
    case 'dependents':
      return <DependentsStep />;
    case 'income':
      return <IncomeStep />;
    case 'adjustments':
      return <AdjustmentsStep />;
    case 'credits':
      return <CreditsStep />;
    case 'review':
      return <ReviewStep />;
    default:
      return null;
  }
}
