import { lazy, Suspense } from 'react';
import { Route, Routes } from 'react-router';
import { DraftProvider } from './draft';
import { AppShell } from './layout/AppShell';
import { Page, PageHeader } from './layout/Page';
import { WizardLayout } from './layout/WizardLayout';
import { HomePage } from './pages/HomePage';
import { StepPage } from './pages/StepPage';
import { ResultsPage } from './pages/ResultsPage';
import { UnsupportedPage } from './pages/UnsupportedPage';
import { TrustPage } from './pages/TrustPage';
import { ButtonLink } from './components';

// Docs (markdown, react-markdown, Shiki) load on first visit to /docs.
const DocsRoutes = lazy(() => import('./docs/DocsRoutes'));

function NotFound() {
  return (
    <Page narrow>
      <PageHeader eyebrow="Error 404" title="Page not found" lead="The address may be mistyped, or the page may have moved." />
      <ButtonLink to="/">Go to the home page</ButtonLink>
    </Page>
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
          <Route
            path="docs/*"
            element={
              <Suspense fallback={<p className="px-6 py-12 text-muted-foreground">Loading documentation...</p>}>
                <DocsRoutes />
              </Suspense>
            }
          />
          <Route path="*" element={<NotFound />} />
        </Route>
      </Routes>
    </DraftProvider>
  );
}
