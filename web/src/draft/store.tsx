import { createContext, useContext, useEffect, useMemo, useReducer, type ReactNode } from 'react';
import type { CalculateRequest } from '../api';
import { tryBuildRequest } from './buildRequest';
import { isDraftValid } from './validate';
import { emptyDraft, emptyFlags, type Draft } from './types';

export const STORAGE_KEY = 'ustax.draft.v1';

type Action =
  | { type: 'update'; fn: (d: Draft) => Draft }
  | { type: 'replace'; draft: Draft }
  | { type: 'reset' };

function reducer(state: Draft, a: Action): Draft {
  switch (a.type) {
    case 'update':
      return a.fn(state);
    case 'replace':
      return a.draft;
    case 'reset':
      return emptyDraft();
  }
}

function safeStorage(): Storage | undefined {
  try {
    return typeof window === 'undefined' ? undefined : window.localStorage;
  } catch {
    return undefined;
  }
}

/** Reads the saved draft. Anything unreadable or from another version is ignored (we start fresh). */
export function loadDraft(storage: Pick<Storage, 'getItem'> | undefined = safeStorage()): Draft {
  try {
    const raw = storage?.getItem(STORAGE_KEY);
    if (!raw) return emptyDraft();
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null || (parsed as { version?: unknown }).version !== 1) return emptyDraft();
    const p = parsed as Partial<Draft>;
    // Nested objects added after a draft was saved fall back to their defaults.
    const base = emptyDraft();
    return {
      ...base,
      ...p,
      primary: { ...emptyFlags(), ...p.primary, hsa: { ...emptyFlags().hsa, ...p.primary?.hsa } },
      spouse: { ...emptyFlags(), ...p.spouse, hsa: { ...emptyFlags().hsa, ...p.spouse?.hsa } },
      screening: { ...base.screening, ...p.screening },
      credits: { ...base.credits, ...p.credits },
      cdcc: { ...base.cdcc, ...p.cdcc },
      hsa: { ...base.hsa, ...p.hsa },
      healthScreening: { ...base.healthScreening, ...p.healthScreening },
      ssa: (p.ssa ?? []).map((s) => ({ ...s, withheld: s.withheld ?? null })),
    };
  } catch {
    return emptyDraft();
  }
}

export interface DraftApi {
  /** Everything the user has told us so far. */
  draft: Draft;
  /** Change the draft: pass a patch, or a function from the old draft to the new one. */
  update: (change: Partial<Draft> | ((d: Draft) => Draft)) => void;
  /** Throw everything away, in memory and in localStorage. */
  reset: () => void;
  /** Replace the whole draft (for example with an example scenario). */
  replace: (d: Draft) => void;
  /** The API request, or null until required answers are complete and the wizard supports the return. */
  request: CalculateRequest | null;
}

const Ctx = createContext<DraftApi | null>(null);

export function DraftProvider({ children, initial }: { children: ReactNode; initial?: Draft }) {
  const [draft, dispatch] = useReducer(reducer, initial, (i) => i ?? loadDraft());

  useEffect(() => {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(draft));
    } catch {
      /* private mode or quota: the wizard still works, it just will not survive a reload */
    }
  }, [draft]);

  const api = useMemo<DraftApi>(
    () => ({
      draft,
      update: (change) =>
        dispatch({ type: 'update', fn: typeof change === 'function' ? change : (d) => ({ ...d, ...change }) }),
      reset: () => {
        try {
          window.localStorage.removeItem(STORAGE_KEY);
        } catch {
          /* ignore */
        }
        dispatch({ type: 'reset' });
      },
      replace: (d) => dispatch({ type: 'replace', draft: d }),
      request: isDraftValid(draft) ? tryBuildRequest(draft) : null,
    }),
    [draft],
  );
  return <Ctx.Provider value={api}>{children}</Ctx.Provider>;
}

/** The wizard draft. Must be used under `DraftProvider` (App provides it). */
export function useDraft(): DraftApi {
  const api = useContext(Ctx);
  if (!api) throw new Error('useDraft must be used inside <DraftProvider>');
  return api;
}
