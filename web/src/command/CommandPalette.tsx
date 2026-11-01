import { useMemo } from 'react';
import { BookOpen, ClipboardCopy, FileText, ListChecks, Moon, RotateCcw, type LucideIcon } from 'lucide-react';
import { useNavigate } from 'react-router';
import { toast } from 'sonner';
import { CommandDialog, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList, CommandSeparator } from '@/components/ui/command';
import { Kbd } from '@/components/ui/kbd';
import { resolvedTheme, setTheme } from '@/lib/theme';
import { useDraft } from '../draft';
import { useClearReturn } from '../components/ClearReturn';
import { buildCommands, type CommandGroupId, type PaletteCommand } from './commands';

const ICON: Record<CommandGroupId, LucideIcon> = { Return: ListChecks, Pages: FileText, Documentation: BookOpen, Actions: Moon };
const ACTION_ICON: Record<NonNullable<PaletteCommand['action']>, LucideIcon> = { 'toggle-theme': Moon, 'copy-link': ClipboardCopy, 'start-over': RotateCcw };
const GROUPS: CommandGroupId[] = ['Return', 'Pages', 'Documentation', 'Actions'];

/** The ⌘K palette (shadcn/ui Command in a Dialog, cmdk). Lazy-loaded on first open. */
export default function CommandPalette({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  const navigate = useNavigate();
  const { request } = useDraft();
  const clearReturn = useClearReturn();
  const commands = useMemo(() => buildCommands({ hasReturn: request !== null }), [request]);

  const run = (c: PaletteCommand) => {
    onOpenChange(false);
    if (c.to) return void navigate(c.to);
    if (c.action === 'toggle-theme') setTheme(resolvedTheme() === 'dark' ? 'light' : 'dark');
    if (c.action === 'copy-link') {
      navigator.clipboard?.writeText(window.location.href).then(
        () => toast.success('Link copied'),
        () => toast.error('Could not copy the link'),
      );
    }
    if (c.action === 'start-over') {
      requestAnimationFrame(clearReturn);
    }
  };

  return (
    <CommandDialog open={open} onOpenChange={onOpenChange} title="Go to" description="Jump to a step, a page or the documentation" className="top-[14vh] translate-y-0 sm:max-w-xl">
      <CommandInput placeholder="Jump to a step, page or doc…" />
      <CommandList className="max-h-[min(24rem,60vh)]">
        <CommandEmpty>Nothing matches.</CommandEmpty>
        {GROUPS.map((g, gi) => {
          const items = commands.filter((c) => c.group === g);
          if (items.length === 0) return null;
          return (
            <div key={g}>
              {gi > 0 && <CommandSeparator />}
              <CommandGroup heading={g === 'Return' ? 'Your return' : g}>
                {items.map((c) => {
                  const Icon = c.action ? ACTION_ICON[c.action] : ICON[c.group];
                  return (
                    <CommandItem key={c.id} value={`${c.label} ${c.id}`} keywords={c.keywords} onSelect={() => run(c)}>
                      <Icon aria-hidden="true" className="text-muted-foreground" />
                      <span className="truncate">{c.label}</span>
                      {c.hint && <span className="ml-auto text-xs text-muted-foreground">{c.hint}</span>}
                    </CommandItem>
                  );
                })}
              </CommandGroup>
            </div>
          );
        })}
      </CommandList>
      <div className="flex items-center gap-4 border-t bg-muted/50 px-3 py-2 text-xs text-muted-foreground" aria-hidden="true">
        <span className="inline-flex items-center gap-1">
          <Kbd>↑</Kbd>
          <Kbd>↓</Kbd> move
        </span>
        <span className="inline-flex items-center gap-1">
          <Kbd>↵</Kbd> open
        </span>
        <span className="inline-flex items-center gap-1">
          <Kbd>esc</Kbd> close
        </span>
      </div>
    </CommandDialog>
  );
}
