import { Route, Routes } from 'react-router';
import { DraftProvider } from './draft';
import { AppShell } from './layout/AppShell';
import { WizardLayout } from './layout/WizardLayout';
import { HomePage } from './pages/HomePage';
import { StepPage } from './pages/StepPage';
import { ResultsPage } from './pages/ResultsPage';
import { UnsupportedPage } from './pages/UnsupportedPage';
import { TrustPage } from './pages/TrustPage';
import { ButtonLink, Card } from './components';

function NotFound() {
  return (
    <div className="container narrow">
      <Card>
        <h1>That page wandered off.</h1>
        <p>Let’s get you back on track.</p>
        <ButtonLink to="/">Go home</ButtonLink>
      </Card>
    </div>
  );
}

/** Route table. Router itself is provided by main.tsx (or MemoryRouter in tests). */
export function App() {
  return (
    <DraftProvider>
    <Routes>
      <Route element={<AppShell />}>
        <Route index element={<HomePage />} />
        <Route path="start/:step" element={<WizardLayout />}>
          <Route index element={<StepPage />} />
        </Route>
        <Route path="results" element={<ResultsPage />} />
        <Route path="cant-do-yet" element={<UnsupportedPage />} />
        <Route path="trust" element={<TrustPage />} />
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
    </DraftProvider>
  );
}
