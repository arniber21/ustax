import { lazy, type ComponentType } from 'react';

export type Preloadable<P> = ComponentType<P> & { preload: () => Promise<void> };

/**
 * `React.lazy` with a `preload()`: once the module is in, the component renders synchronously (no
 * Suspense fallback). The app preloads the wizard when the browser is idle; tests preload in beforeAll.
 */
export function lazyRoute<P extends object>(factory: () => Promise<ComponentType<P>>): Preloadable<P> {
  let loaded: ComponentType<P> | null = null;
  let pending: Promise<void> | null = null;
  const load = () =>
    (pending ??= factory().then((c) => {
      loaded = c;
    }));
  const Lazy = lazy(() => load().then(() => ({ default: loaded! })));
  const Route = ((props: P) => {
    const C = loaded;
    return C ? <C {...props} /> : <Lazy {...props} />;
  }) as Preloadable<P>;
  Route.preload = load;
  return Route;
}
