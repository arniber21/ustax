import { Component, lazy, Suspense, useCallback, useEffect, useState, type ErrorInfo, type ReactNode } from 'react';
import { Link, NavLink, Outlet, useLocation } from 'react-router';
import { FlaskConical, Menu, Search, ShieldCheck, TriangleAlert } from 'lucide-react';
import { GithubMark } from '../components/GithubMark';
import { ButtonLink } from '../components/Button';
import { ThemeToggle } from '../components/ThemeToggle';
import { Button } from '../components/ui/button';
import { Kbd } from '../components/ui/kbd';
import { Sheet, SheetContent, SheetDescription, SheetTitle, SheetTrigger } from '../components/ui/sheet';
import { Skeleton } from '../components/ui/skeleton';
import { Toaster } from '../components/ui/sonner';
import { REPO_URL } from '../docs/config';
import { useDraft } from '../draft';
import { AS_OF, CATALA, EXTRA, MAIN, TESTED } from '../trust/facts';
import { cn } from '@/lib/utils';

/** Product name, used in the header, title and copy. */
export const PRODUCT_NAME = 'US Tax';
export const TAGLINE = 'A formally verified income tax calculator';

// cmdk and the palette load on the first ⌘K, not with the app.
const CommandPalette = lazy(() => import('../command/CommandPalette'));

/** Wordmark: a plain ledger mark and the name. The mark is decorative; the text carries the name. */
export function Logo() {
  return (
    <Link to="/" className="inline-flex items-center gap-2.5 rounded-md text-foreground no-underline" aria-label={`${PRODUCT_NAME} home`}>
      <svg width="26" height="26" viewBox="0 0 32 32" aria-hidden="true" className="shrink-0">
        <rect width="32" height="32" rx="7" className="fill-primary" />
        <path d="M8 11h16M8 16h16M8 21h10" className="stroke-primary-foreground" strokeWidth="2.5" strokeLinecap="round" />
      </svg>
      <span className="text-[1.0625rem] font-semibold tracking-tight">{PRODUCT_NAME}</span>
    </Link>
  );
}

const navClass = ({ isActive }: { isActive: boolean }) =>
  cn(
    'relative rounded-md px-3 py-2 text-sm font-medium no-underline transition-colors hover:bg-accent',
    isActive ? 'text-foreground after:absolute after:inset-x-3 after:-bottom-[13px] after:h-0.5 after:rounded-full after:bg-primary' : 'text-muted-foreground hover:text-foreground',
  );

const isMac = () => typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);

/** Open/close state of the ⌘K palette, with the global shortcut (⌘K / Ctrl+K, and "/" outside text fields). */
export function useCommandShortcut() {
  const [open, setOpen] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const show = useCallback(() => {
    setLoaded(true);
    setOpen(true);
  }, []);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const typing = e.target instanceof HTMLElement && (e.target.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName));
      if ((e.key === 'k' || e.key === 'K') && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setLoaded(true);
        setOpen((o) => !o);
      } else if (e.key === '/' && !typing && !e.metaKey && !e.ctrlKey && !e.altKey) {
        e.preventDefault();
        show();
      }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [show]);
  return { open, setOpen, loaded, show };
}

function SearchButton({ onClick }: { onClick: () => void }) {
  return (
    <>
      <Button
        variant="outline"
        onClick={onClick}
        className="hidden h-9 w-56 justify-start gap-2 border-border bg-muted/50 px-3 font-normal text-muted-foreground shadow-none hover:bg-accent md:inline-flex lg:w-64"
        aria-label="Search and jump to (Command K)"
      >
        <Search aria-hidden="true" />
        <span className="flex-1 text-left">Jump to…</span>
        <Kbd className="bg-background shadow-xs" aria-hidden="true">
          {isMac() ? '⌘' : 'Ctrl'} K
        </Kbd>
      </Button>
      <Button variant="ghost" size="icon" onClick={onClick} className="md:hidden" aria-label="Search and jump to">
        <Search aria-hidden="true" />
      </Button>
    </>
  );
}

function MobileMenu({ startLabel }: { startLabel: string }) {
  const [open, setOpen] = useState(false);
  const { pathname } = useLocation();
  useEffect(() => setOpen(false), [pathname]);
  const link = 'rounded-md px-3 py-2.5 text-base font-medium text-foreground no-underline hover:bg-accent';
  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger asChild>
        <Button variant="ghost" size="icon" className="sm:hidden" aria-label="Menu">
          <Menu aria-hidden="true" />
        </Button>
      </SheetTrigger>
      <SheetContent className="max-w-xs" aria-describedby="menu-desc">
        <div className="grid gap-1 border-b px-5 py-4 pr-12">
          <SheetTitle className="text-base">{PRODUCT_NAME}</SheetTitle>
          <SheetDescription id="menu-desc">{TAGLINE}</SheetDescription>
        </div>
        <nav aria-label="Mobile" className="grid gap-1 p-3">
          <Link className={link} to="/start/about">
            {startLabel}
          </Link>
          <Link className={link} to="/trust">
            Verification
          </Link>
          <Link className={link} to="/docs">
            Docs
          </Link>
          <a className={link} href={REPO_URL} target="_blank" rel="noopener noreferrer">
            GitHub
          </a>
        </nav>
      </SheetContent>
    </Sheet>
  );
}

/** Catches a render error on one page and shows a designed message instead of a blank screen. */
export class ErrorBoundary extends Component<{ children: ReactNode; resetKey?: string }, { error: Error | null; key?: string }> {
  state: { error: Error | null; key?: string } = { error: null, key: this.props.resetKey };
  static getDerivedStateFromError(error: Error) {
    return { error };
  }
  static getDerivedStateFromProps(props: { resetKey?: string }, state: { error: Error | null; key?: string }) {
    return props.resetKey !== state.key ? { error: null, key: props.resetKey } : null;
  }
  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Page crashed:', error, info.componentStack);
  }
  render() {
    if (!this.state.error) return this.props.children;
    return (
      <div className="mx-auto grid max-w-xl justify-items-center gap-4 px-4 py-20 text-center">
        <span className="grid size-12 place-items-center rounded-full bg-destructive-soft text-destructive">
          <TriangleAlert aria-hidden="true" className="size-6" />
        </span>
        <h1 className="m-0 text-2xl font-semibold tracking-tight">Something went wrong on this page</h1>
        <p className="m-0 text-muted-foreground">
          Your answers are saved in this browser. Reload the page, or go back to the start; nothing you entered is lost.
        </p>
        <div className="flex flex-wrap justify-center gap-2">
          <Button onClick={() => window.location.reload()}>Reload the page</Button>
          <ButtonLink variant="secondary" to="/">
            Home
          </ButtonLink>
        </div>
      </div>
    );
  }
}

/** Shown while a lazily loaded page arrives. Same rhythm as a page header, so nothing jumps. */
export function RouteFallback() {
  return (
    <div className="mx-auto grid max-w-6xl gap-4 px-4 py-10 sm:px-6" role="status" aria-label="Loading">
      <Skeleton className="h-4 w-40" />
      <Skeleton className="h-9 w-80 max-w-full" />
      <Skeleton className="h-4 w-full max-w-xl" />
      <Skeleton className="mt-6 h-48 w-full rounded-xl" />
    </div>
  );
}

function Footer() {
  const proved = MAIN.theorems.length + EXTRA.theorems.length;
  return (
    <footer className="prov-noprint mt-20 border-t bg-muted/60">
      <div className="mx-auto grid max-w-6xl gap-8 px-4 py-10 text-sm text-muted-foreground sm:px-6 md:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
        <div className="grid content-start gap-3">
          <Logo />
          <p className="m-0 max-w-md">
            {TAGLINE}. Tax year 2024, federal income tax only. A student research project, not tax advice. It does not file
            anything, and your answers stay in this browser except when sent to the calculator.
          </p>
        </div>
        <div className="grid content-start gap-3">
          <p className="m-0 text-xs font-semibold tracking-wide text-foreground uppercase">Verification status</p>
          <ul className="m-0 grid list-none gap-2 p-0">
            <li className="flex items-start gap-2">
              <ShieldCheck aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-success" />
              <span>
                <span className="font-medium text-foreground">{proved} theorems proved in Lean</span>, checked by Comparator
              </span>
            </li>
            <li className="flex items-start gap-2">
              <FlaskConical aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-primary" />
              <span>
                <span className="font-medium text-foreground">{CATALA.moduleFiles} Catala rule files</span> agree with IRS Direct File on{' '}
                {TESTED.calculator.scenarios} scenarios (verified by testing, not a proof)
              </span>
            </li>
          </ul>
          <p className="m-0 text-xs">As of {AS_OF}.</p>
          <div className="flex flex-wrap gap-x-4 gap-y-1">
            <Link to="/trust">What is verified</Link>
            <Link to="/docs">Docs</Link>
            <a href={REPO_URL} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1">
              <GithubMark className="size-3.5" />
              GitHub
              <span className="sr-only">(opens in a new tab)</span>
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}

/** Page chrome: skip link, notice banner, sticky header, main landmark, footer, toasts and the ⌘K palette. */
export function AppShell() {
  const { pathname } = useLocation();
  const { draft } = useDraft();
  const palette = useCommandShortcut();
  // A new page starts at the top, as a full page load would.
  useEffect(() => {
    document.documentElement.scrollTop = 0;
  }, [pathname]);
  const startLabel = draft.filingStatus ? 'Continue your return' : 'Start a return';
  const section = pathname.split('/')[1] ?? '';
  return (
    <>
      <a
        className="absolute -top-16 left-3 z-[60] rounded-md bg-foreground px-4 py-2 text-background no-underline focus:top-3"
        href="#main"
      >
        Skip to content
      </a>
      <div className="prov-noprint border-b bg-muted text-xs text-muted-foreground">
        <div className="mx-auto max-w-6xl px-4 py-1.5 sm:px-6">An independent research project. Not affiliated with the IRS. Nothing is filed.</div>
      </div>
      <header className="prov-noprint sticky top-0 z-40 border-b bg-background/90 backdrop-blur supports-[backdrop-filter]:bg-background/75">
        <div className="mx-auto flex h-16 max-w-6xl items-center gap-3 px-4 sm:px-6">
          <Logo />
          <nav aria-label="Main" className="ml-4 hidden items-center gap-1 sm:flex">
            <NavLink to="/start/about" className={({ isActive }) => navClass({ isActive: isActive || section === 'start' })}>
              {startLabel}
            </NavLink>
            <NavLink to="/trust" className={navClass}>
              Verification
            </NavLink>
            <NavLink to="/docs" className={navClass}>
              Docs
            </NavLink>
          </nav>
          <div className="ml-auto flex items-center gap-1.5">
            <SearchButton onClick={palette.show} />
            <Button variant="ghost" size="icon" asChild className="hidden sm:inline-flex">
              <a href={REPO_URL} target="_blank" rel="noopener noreferrer" aria-label="GitHub repository (opens in a new tab)" className="text-foreground">
                <GithubMark />
              </a>
            </Button>
            <ThemeToggle />
            <MobileMenu startLabel={startLabel} />
          </div>
        </div>
      </header>
      <main id="main" tabIndex={-1} className="flex-1 outline-none">
        <ErrorBoundary resetKey={pathname}>
          <Suspense fallback={<RouteFallback />}>
            <div key={section} className="animate-in fade-in-0 duration-300">
              <Outlet />
            </div>
          </Suspense>
        </ErrorBoundary>
      </main>
      <Footer />
      <Toaster position="bottom-right" closeButton />
      {palette.loaded && (
        <Suspense fallback={null}>
          <CommandPalette open={palette.open} onOpenChange={palette.setOpen} />
        </Suspense>
      )}
    </>
  );
}
