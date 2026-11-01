import { Moon, Sun } from 'lucide-react';
import { setTheme, useResolvedTheme } from '@/lib/theme';
import { Button } from './ui/button';
import { Tooltip, TooltipContent, TooltipTrigger } from './ui/tooltip';

export { THEME_KEY } from '@/lib/theme';

/** Light/dark switch. Persists the choice; with no choice the OS setting applies. */
export function ThemeToggle() {
  const theme = useResolvedTheme();
  const next = theme === 'dark' ? 'light' : 'dark';
  const Icon = theme === 'dark' ? Sun : Moon;
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button type="button" variant="ghost" size="icon" aria-label={`Switch to ${next} mode`} onClick={() => setTheme(next)}>
          <Icon aria-hidden="true" />
        </Button>
      </TooltipTrigger>
      <TooltipContent>{`Switch to ${next} mode`}</TooltipContent>
    </Tooltip>
  );
}
