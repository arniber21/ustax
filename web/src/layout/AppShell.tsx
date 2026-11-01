import { useEffect } from 'react';
import { Link, NavLink, Outlet, useLocation } from 'react-router';
import { ThemeToggle } from '../components';
import { cn } from '@/lib/utils';

/** Product name, used in the header, title and copy. */
export const PRODUCT_NAME = 'US Tax';
export const TAGLINE = 'A formally verified income tax calculator';

/** Wordmark: a plain ledger mark and the name. The mark is decorative; the text carries the name. */
export function Logo() {
  return (
    <Link to="/" className="inline-flex items-center gap-2.5 text-foreground no-underline" aria-label={`${PRODUCT_NAME} home`}>
      <svg width="24" height="24" viewBox="0 0 32 32" aria-hidden="true" className="shrink-0">
        <rect width="32" height="32" rx="6" className="fill-primary" />
        <path d="M8 11h16M8 16h16M8 21h10" className="stroke-primary-foreground" strokeWidth="2.5" strokeLinecap="round" />
      </svg>
      <span className="text-[1.0625rem] font-semibold tracking-tight">{PRODUCT_NAME}</span>
    </Link>
  );
}

const navClass = ({ isActive }: { isActive: boolean }) =>
  cn(
    'rounded-md px-3 py-2 text-sm font-medium no-underline transition-colors hover:bg-accent',
    isActive ? 'text-foreground' : 'text-muted-foreground hover:text-foreground',
  );

/** Page chrome: skip link, notice banner, header, main landmark, footer. */
export function AppShell() {
  const { pathname } = useLocation();
  // A new page starts at the top, as a full page load would.
  useEffect(() => {
    document.documentElement.scrollTop = 0;
  }, [pathname]);
  return (
    <>
      <a
        className="absolute -top-16 left-3 z-50 rounded-md bg-foreground px-4 py-2 text-background no-underline focus:top-3"
        href="#main"
      >
        Skip to content
      </a>
      <div className="border-b bg-muted text-xs text-muted-foreground">
        <div className="mx-auto max-w-6xl px-4 py-1.5 sm:px-6">
          An independent research project. Not affiliated with the IRS. Nothing is filed.
        </div>
      </div>
      <header className="border-b bg-background">
        <div className="mx-auto flex h-16 max-w-6xl items-center gap-4 px-4 sm:px-6">
          <Logo />
          <span className="hidden border-l pl-4 text-sm text-muted-foreground md:inline">{TAGLINE}</span>
          <nav aria-label="Main" className="ml-auto flex items-center gap-1">
            <NavLink to="/start/about" className={({ isActive }) => cn(navClass({ isActive }), 'hidden sm:inline-flex')}>
              Start a return
            </NavLink>
            <NavLink to="/trust" className={navClass}>
              Verification
            </NavLink>
            <NavLink to="/docs" className={navClass}>
              Docs
            </NavLink>
          </nav>
          <ThemeToggle />
        </div>
      </header>
      <main id="main" tabIndex={-1} className="flex-1 outline-none">
        <div key={pathname.split('/')[1] ?? ''} className="animate-in fade-in-0 duration-300">
          <Outlet />
        </div>
      </main>
      <footer className="mt-16 border-t bg-muted">
        <div className="mx-auto grid max-w-6xl gap-2 px-4 py-8 text-sm text-muted-foreground sm:px-6">
          <p className="m-0">
            <span className="font-semibold text-foreground">{PRODUCT_NAME}</span>: {TAGLINE.toLowerCase()}. Tax year 2024,
            federal income tax only.
          </p>
          <p className="m-0">
            A student research project, not tax advice. It does not file anything, and your answers stay in this browser
            except when sent to the calculator. <Link to="/trust">What is verified</Link>
            {' · '}
            <Link to="/docs">Docs</Link>
          </p>
        </div>
      </footer>
    </>
  );
}
