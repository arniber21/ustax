export interface TocItem {
  id: string;
  text: string;
  level: 2 | 3;
}

/** "On this page" entries: the h2 and h3 headings (with ids from rehype-slug) inside a rendered article. */
export function tocFromElement(root: ParentNode): TocItem[] {
  const out: TocItem[] = [];
  root.querySelectorAll<HTMLHeadingElement>('h2[id], h3[id]').forEach((h) => {
    const text = h.textContent?.trim();
    if (text) out.push({ id: h.id, text, level: h.tagName === 'H2' ? 2 : 3 });
  });
  return out;
}

/** The id of the last heading whose top has scrolled past `offset` px from the viewport top (first one before any has). */
export function activeHeading(items: readonly TocItem[], offset = 120): string | null {
  let active: string | null = items[0]?.id ?? null;
  for (const it of items) {
    const el = document.getElementById(it.id);
    if (el && el.getBoundingClientRect().top <= offset) active = it.id;
  }
  return active;
}
