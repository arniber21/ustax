import type { Draft } from '../draft';

/** Draft list keys behind the id-based paths used by validation and the error summary. */
const LISTS: Record<string, keyof Draft> = {
  w2: 'w2s',
  interest: 'interest',
  unemployment: 'unemployment',
  retirement: 'retirement',
  ssa: 'ssa',
  dep: 'dependents',
};

const indexOf = (items: unknown, id: string | undefined): number =>
  Array.isArray(items) ? items.findIndex((x: { id?: string }) => x?.id === id) : -1;

/**
 * The react-hook-form field name (index-based, e.g. `w2s.0.box12.1.amount`) for a draft path
 * (id-based, e.g. `w2.<id>.box12.<rowId>.amount`, as used by `validateStep` and the error summary).
 * Null when an id is not in the draft (the item was just removed).
 */
export function formName(path: string, draft: Draft): string | null {
  const parts = path.split('.');
  const [head, a, b, c, d] = parts;
  if (head === 'hsa' && (a === 'primary' || a === 'spouse') && b) return `${a}.hsa.${b}`;
  const listKey = head ? LISTS[head] : undefined;
  if (!listKey) return path;
  const items = draft[listKey];
  const i = indexOf(items, a);
  if (i < 0 || !b) return null;
  if (listKey === 'w2s' && b === 'box12' && c && d) {
    const j = indexOf(draft.w2s[i]?.box12, c);
    return j < 0 ? null : `w2s.${i}.box12.${j}.${d}`;
  }
  return `${listKey}.${i}.${parts.slice(2).join('.')}`;
}
