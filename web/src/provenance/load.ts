import type { Provenance } from './types';

/** Where the build step puts the copies (web/package.json `prebuild`/`predev`: scripts/sync-provenance.mjs). */
const base = () => `${import.meta.env.BASE_URL ?? '/'}`.replace(/\/?$/, '/');

let indexPromise: Promise<Provenance> | null = null;
const sourcePromises = new Map<string, Promise<string>>();

/** Fetches provenance.json once. A failure is not cached, so closing and reopening the drawer retries. */
export function loadProvenance(): Promise<Provenance> {
  indexPromise ??= fetch(`${base()}provenance.json`)
    .then((r) => {
      if (!r.ok) throw new Error(`provenance.json: HTTP ${r.status}`);
      return r.json() as Promise<Provenance>;
    })
    .catch((e: unknown) => {
      indexPromise = null;
      throw e;
    });
  return indexPromise;
}

/** Fetches one source file by its repo-relative path (e.g. `catala/form_1040.catala_en`). */
export function loadSource(path: string): Promise<string> {
  let p = sourcePromises.get(path);
  if (!p) {
    p = fetch(`${base()}sources/${path}`)
      .then((r) => {
        if (!r.ok) throw new Error(`${path}: HTTP ${r.status}`);
        return r.text();
      })
      .catch((e: unknown) => {
        sourcePromises.delete(path);
        throw e;
      });
    sourcePromises.set(path, p);
  }
  return p;
}

/** For tests. */
export function resetProvenanceCache() {
  indexPromise = null;
  sourcePromises.clear();
}
