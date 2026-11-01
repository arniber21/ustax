import { useEffect } from 'react';
import { Route, Routes } from 'react-router';
import { Compass } from 'lucide-react';
import { DraftProvider } from './draft';
import { AppShell } from './layout/AppShell';
import { Page } from './layout/Page';
import { HomePage } from './pages/HomePage';
import { ButtonLink } from './components/Button';
import { lazyRoute } from '@/lib/lazyRoute';

// Every page but Home loads on first visit (AppShell's Suspense shows a skeleton meanwhile). The wizard is
// preloaded when the browser is idle, so "Start your return" is instant.
const WizardLayout = lazyRoute(() => import('./layout/WizardLayout').then((m) => m.WizardLayout));
const StepPage = lazyRoute(() => import('./pages/StepPage').then((m) => m.StepPage));
const ResultsPage = lazyRoute(() => import('./pages/ResultsPage').then((m) => m.ResultsPage));
const TrustPage = lazyRoute(() => import('./pages/TrustPage').then((m) => m.TrustPage));
const UnsupportedPage = lazyRoute(() => import('./pages/UnsupportedPage').then((m) => m.UnsupportedPage));
const DocsRoutes = lazyRoute(() => import('./docs/DocsRoutes').then((m) => m.default));

/** Load every lazy page now (tests call this in beforeAll so routes render synchronously). */
export const preloadRoutes = () =>
  Promise.all([WizardLayout, StepPage, ResultsPage, TrustPage, UnsupportedPage, DocsRoutes].map((r) => r.preload())).then(() => undefined);

export function NotFound() {
  return (
    <Page narrow>
      <div className="grid justify-items-center gap-4 py-12 text-center">
        <span aria-hidden="true" className="grid size-12 place-items-center rounded-full bg-muted text-muted-foreground">
          <Compass className="size-6" />
        </span>
        <p className="m-0 text-xs font-semibold tracking-wide text-primary uppercase">Error 404</p>
        <h1 className="m-0 text-3xl font-semibold tracking-tight">Page not found</h1>
        <p className="m-0 max-w-md text-muted-foreground">The address may be mistyped, or the page may have moved.</p>
        <div className="mt-2 flex flex-wrap justify-center gap-2">
          <ButtonLink to="/">Go to the home page</ButtonLink>
          <ButtonLink variant="secondary" to="/docs">
            Read the docs
          </ButtonLink>
        </div>
      </div>
    </Page>
  );
}

/** Route table. Router itself is provided by main.tsx (or MemoryRouter in tests). */
export function App() {
  useEffect(() => {
    const warm = () => void Promise.all([WizardLayout.preload(), StepPage.preload()]);
    if (typeof window.requestIdleCallback === 'function') {
      const id = window.requestIdleCallback(warm, { timeout: 4000 });
      return () => window.cancelIdleCallback(id);
    }
    const t = setTimeout(warm, 2000);
    return () => clearTimeout(t);
  }, []);
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
          <Route path="docs/*" element={<DocsRoutes />} />
          <Route path="*" element={<NotFound />} />
        </Route>
      </Routes>
    </DraftProvider>
  );
}
