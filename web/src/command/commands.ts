import nav from '../../../docs/site/_nav.json';
import { WIZARD_STEPS, stepPath } from '../layout/steps';
import { docRoute } from '../docs/links';

export type CommandGroupId = 'Return' | 'Pages' | 'Documentation' | 'Actions';

export interface PaletteCommand {
  id: string;
  group: CommandGroupId;
  label: string;
  /** Extra words cmdk matches on. */
  keywords?: string[];
  /** Navigate here, or run `action`. */
  to?: string;
  action?: 'toggle-theme' | 'start-over' | 'copy-link';
  hint?: string;
}

/** Everything the ⌘K palette offers. Pure (the palette renders it; tests check it). */
export function buildCommands({ hasReturn }: { hasReturn: boolean }): PaletteCommand[] {
  const steps: PaletteCommand[] = WIZARD_STEPS.map((s, i) => ({
    id: `step-${s.id}`,
    group: 'Return',
    label: s.label,
    hint: `Step ${i + 1}`,
    keywords: [s.blurb, 'wizard', 'step'],
    to: stepPath(s.id),
  }));
  const pages: PaletteCommand[] = [
    { id: 'home', group: 'Pages', label: 'Home', to: '/', keywords: ['start', 'welcome'] },
    ...(hasReturn ? [{ id: 'results', group: 'Pages' as const, label: 'Your result', to: '/results', keywords: ['refund', 'owe', 'form 1040', 'lines'] }] : []),
    { id: 'cant', group: 'Pages', label: 'What we can’t calculate yet', to: '/cant-do-yet', keywords: ['knockout', 'unsupported'] },
  ];
  const docs: PaletteCommand[] = (nav as { pages: { title: string; slug: string; summary?: string }[] }).pages.map((p) => ({
    id: `doc-${p.slug}`,
    group: 'Documentation',
    label: p.title,
    keywords: p.summary ? [p.summary] : [],
    to: docRoute(p.slug),
  }));
  const actions: PaletteCommand[] = [
    { id: 'theme', group: 'Actions', label: 'Toggle light or dark mode', action: 'toggle-theme', keywords: ['theme', 'dark', 'light'] },
    { id: 'copy', group: 'Actions', label: 'Copy link to this page', action: 'copy-link', keywords: ['share', 'url'] },
    { id: 'reset', group: 'Actions', label: 'Start over (clear my answers)', action: 'start-over', keywords: ['reset', 'clear', 'new'] },
  ];
  return [...steps, ...pages, ...docs, ...actions];
}
