import { useSyncExternalStore } from 'react';

export type Theme = 'light' | 'dark';
export const THEME_KEY = 'ustax-theme';

const media = () =>
  typeof window !== 'undefined' && typeof window.matchMedia === 'function' ? window.matchMedia('(prefers-color-scheme: dark)') : null;

/** The theme in effect: `<html data-theme>` when pinned, else the OS setting. */
export function resolvedTheme(): Theme {
  const pinned = typeof document !== 'undefined' ? document.documentElement.dataset.theme : undefined;
  if (pinned === 'light' || pinned === 'dark') return pinned;
  return media()?.matches ? 'dark' : 'light';
}

/** Pin a theme and remember it (key `ustax-theme`, read by the inline script in index.html). */
export function setTheme(t: Theme) {
  document.documentElement.dataset.theme = t;
  try {
    localStorage.setItem(THEME_KEY, t);
  } catch {
    /* private mode: the choice just won't persist */
  }
}

function subscribe(cb: () => void) {
  const mo = new MutationObserver(cb);
  mo.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
  const mq = media();
  mq?.addEventListener?.('change', cb);
  return () => {
    mo.disconnect();
    mq?.removeEventListener?.('change', cb);
  };
}

/** Re-renders when the theme changes, whether by the toggle, the command palette or the OS. */
export function useResolvedTheme(): Theme {
  return useSyncExternalStore(subscribe, resolvedTheme, () => 'light');
}
