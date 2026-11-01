import { useState } from 'react';
import { Moon, Sun } from 'lucide-react';
import { Button } from './ui/button';

type Theme = 'light' | 'dark';
export const THEME_KEY = 'ustax-theme';

const systemTheme = (): Theme =>
  typeof window.matchMedia === 'function' && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';

const current = (): Theme => {
  const pinned = document.documentElement.dataset.theme;
  return pinned === 'light' || pinned === 'dark' ? pinned : systemTheme();
};

/** Light/dark switch. Persists the choice; with no choice the OS setting applies. */
export function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>(current);
  const next: Theme = theme === 'dark' ? 'light' : 'dark';
  const Icon = theme === 'dark' ? Sun : Moon;
  return (
    <Button
      type="button"
      variant="ghost"
      size="icon"
      aria-label={`Switch to ${next} mode`}
      onClick={() => {
        document.documentElement.dataset.theme = next;
        try {
          localStorage.setItem(THEME_KEY, next);
        } catch {
          /* private mode: the choice just won't persist */
        }
        setTheme(next);
      }}
    >
      <Icon aria-hidden="true" />
    </Button>
  );
}
