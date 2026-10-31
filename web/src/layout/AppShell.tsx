import { Link, NavLink, Outlet } from 'react-router';
import { ThemeToggle } from '../components';

/** Logo mark: a tick on a green tile. Decorative; the wordmark carries the name. */
export function Logo() {
  return (
    <Link to="/" className="logo" aria-label="Sumsure home">
      <svg width="34" height="34" viewBox="0 0 32 32" aria-hidden="true">
        <rect width="32" height="32" rx="9" fill="var(--brand)" />
        <path d="M9 17l5 5 9-12" stroke="var(--sun)" strokeWidth="3.5" fill="none" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      <span className="logo__word">Sumsure</span>
    </Link>
  );
}

/** Page chrome: skip link, header, main landmark, footer. */
export function AppShell() {
  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="site-header">
        <div className="container site-header__row">
          <Logo />
          <nav aria-label="Main" className="site-nav">
            <NavLink to="/start/about">Start</NavLink>
            <NavLink to="/trust">Why trust this?</NavLink>
          </nav>
          <ThemeToggle />
        </div>
      </header>
      <main id="main" tabIndex={-1} className="site-main">
        <Outlet />
      </main>
      <footer className="site-footer">
        <div className="container">
          <p>
            Tax year 2024, federal only. Sumsure is a student project, not tax advice, and it never files anything for
            you.
          </p>
        </div>
      </footer>
    </>
  );
}
