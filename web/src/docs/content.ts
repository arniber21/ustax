import { parseFrontMatter } from './frontmatter';

/** Markdown is read at build time from the repo's docs/ folder (single source of truth, also readable on GitHub). */
const markdownFiles = import.meta.glob(['../../../docs/*.md', '../../../docs/site/*.md', '../../../docs/site/_nav.json'], {
  query: '?raw',
  import: 'default',
  eager: true,
}) as Record<string, string>;

/** Images placed next to the site pages are bundled; other images fall back to GitHub (see rewriteSrc). */
const imageFiles = import.meta.glob('../../../docs/site/**/*.{png,jpg,jpeg,gif,svg,webp}', {
  query: '?url',
  import: 'default',
  eager: true,
}) as Record<string, string>;

const repoPath = (globKey: string) => globKey.replace(/^(\.\.\/)+/, '');

export interface NavEntry {
  title: string;
  slug: string;
  source: string;
  summary?: string;
}

export interface DocPage {
  slug: string;
  title: string;
  summary: string;
  /** Repo path of the markdown file, e.g. docs/audit.md. */
  source: string;
  /** Markdown without front-matter. */
  body: string;
}

const files = new Map<string, string>(Object.entries(markdownFiles).map(([k, v]) => [repoPath(k), v]));
export const bundledImages: ReadonlyMap<string, string> = new Map(Object.entries(imageFiles).map(([k, v]) => [repoPath(k), v]));

/** Build the ordered page list from a manifest and a map of repo path to file text. Pure, so tests can feed it. */
export function buildPages(manifest: { pages: NavEntry[] }, fileMap: ReadonlyMap<string, string>): DocPage[] {
  const pages: DocPage[] = [];
  const seen = new Set<string>();
  for (const e of manifest.pages) {
    const raw = fileMap.get(e.source);
    if (raw === undefined) continue;
    const { data, body } = parseFrontMatter(raw);
    pages.push({ slug: e.slug, title: data.title ?? e.title, summary: data.summary ?? e.summary ?? '', source: e.source, body });
    seen.add(e.source);
  }
  // Unlisted docs/site/*.md files are pages too: file name = slug, ordered by front-matter `order`.
  const extra: { page: DocPage; order: number }[] = [];
  for (const [path, raw] of fileMap) {
    const m = /^docs\/site\/([^/_][^/]*)\.md$/.exec(path);
    if (!m || seen.has(path)) continue;
    const { data, body } = parseFrontMatter(raw);
    const slug = m[1]!;
    extra.push({ page: { slug, title: data.title ?? slug, summary: data.summary ?? '', source: path, body }, order: data.order ?? 1000 });
  }
  extra.sort((a, b) => a.order - b.order || a.page.title.localeCompare(b.page.title));
  return [...pages, ...extra.map((x) => x.page)];
}

const manifest = JSON.parse(files.get('docs/site/_nav.json') ?? '{"pages":[]}') as { pages: NavEntry[] };

export const NAV: readonly NavEntry[] = manifest.pages;
export const PAGES: readonly DocPage[] = buildPages(manifest, files);
export const SLUG_BY_SOURCE: ReadonlyMap<string, string> = new Map(PAGES.map((p) => [p.source, p.slug]));

export const findPage = (slug: string) => PAGES.find((p) => p.slug === slug);

/** Case-insensitive filter by title or summary. */
export function searchPages(pages: readonly DocPage[], query: string): DocPage[] {
  const q = query.trim().toLowerCase();
  if (!q) return [...pages];
  return pages.filter((p) => p.title.toLowerCase().includes(q) || p.summary.toLowerCase().includes(q));
}
