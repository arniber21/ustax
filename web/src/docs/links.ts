import { REPO_BLOB, REPO_RAW, REPO_TREE } from './config';

const SCHEME = /^[a-z][a-z0-9+.-]*:|^\/\//i;

/** Resolve `rel` against the directory of the repo path `fromPath`. Returns null if it leaves the repo. */
export function resolveRepoPath(fromPath: string, rel: string): string | null {
  const parts = fromPath.split('/').slice(0, -1);
  for (const seg of rel.split('/')) {
    if (seg === '' || seg === '.') continue;
    if (seg === '..') {
      if (parts.length === 0) return null;
      parts.pop();
    } else parts.push(seg);
  }
  return parts.join('/');
}

/** Route of a doc page: `index` is the landing page. */
export const docRoute = (slug: string) => (slug === 'index' ? '/docs' : `/docs/${slug}`);

/**
 * Where a markdown link should point on the website.
 * - external, mailto and in-page (#) links are unchanged;
 * - links to a page in the docs set become /docs/<slug> (hash kept);
 * - any other repo file or folder becomes a GitHub blob/tree URL.
 */
export function rewriteHref(href: string, fromPath: string, slugBySource: ReadonlyMap<string, string>): string {
  if (!href || href.startsWith('#') || SCHEME.test(href)) return href;
  const m = /^([^?#]*)(\?[^#]*)?(#.*)?$/.exec(href);
  const path = m?.[1] ?? href;
  const hash = m?.[3] ?? '';
  const target = path.startsWith('/') ? path.replace(/^\/+/, '') : resolveRepoPath(fromPath, path);
  if (target === null) return href;
  const slug = slugBySource.get(target);
  if (slug !== undefined) return docRoute(slug) + hash;
  const isDir = path.endsWith('/') || !/\.[^/]+$/.test(target.split('/').pop() ?? '');
  return `${isDir ? REPO_TREE : REPO_BLOB}/${target}${hash}`;
}

/**
 * Where an image should load from. `bundled` maps repo paths to built asset URLs; anything else
 * falls back to raw.githubusercontent.com so it still shows.
 */
export function rewriteSrc(src: string, fromPath: string, bundled: ReadonlyMap<string, string>): string {
  if (!src || SCHEME.test(src) || src.startsWith('data:')) return src;
  const target = src.startsWith('/') ? src.replace(/^\/+/, '') : resolveRepoPath(fromPath, src);
  if (target === null) return src;
  return bundled.get(target) ?? `${REPO_RAW}/${target}`;
}
