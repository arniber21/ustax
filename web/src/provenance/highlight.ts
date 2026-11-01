/** One highlighted token: text, CSS variables for light/dark colours, and the TextMate scope that matched. */
export interface Tok {
  text: string;
  style: Record<string, string>;
  /** Deepest scope of the token, e.g. `keyword.other.catala_en` (Catala grammar) or `keyword.lean`. */
  scope: string;
}
export type Lang = 'catala' | 'lean';

export const langOf = (path: string): Lang => (path.endsWith('.lean') ? 'lean' : 'catala');

async function makeHighlighter() {
  const [{ createHighlighterCore }, { createJavaScriptRegexEngine }, light, dark, lean, catala] = await Promise.all([
    import('shiki/core'),
    import('shiki/engine/javascript'),
    import('@shikijs/themes/github-light'),
    import('@shikijs/themes/github-dark'),
    import('@shikijs/langs/lean4'),
    import('../../../third_party/catala-grammar/catala_en.tmLanguage.json'),
  ]);
  return createHighlighterCore({
    themes: [light.default, dark.default],
    // Catala grammar from third_party/catala-grammar (Apache-2.0), scope source.catala_en.
    langs: [lean.default, { ...(catala.default as object), name: 'catala_en' } as never],
    engine: createJavaScriptRegexEngine({ forgiving: true }),
  });
}

let hl: ReturnType<typeof makeHighlighter> | null = null;
const cache = new Map<string, Promise<Tok[][]>>();

/** Shiki, both themes, the Lean grammar and the Catala grammar are dynamic imports (separate chunks, loaded on first use). */
export function highlight(key: string, code: string, lang: Lang): Promise<Tok[][]> {
  let p = cache.get(key);
  if (!p) {
    hl ??= makeHighlighter();
    p = hl.then((h) => {
      // The grammar is stateful across lines, so the whole file is tokenized at once.
      const { tokens } = h.codeToTokens(code, {
        lang: lang === 'lean' ? 'lean4' : 'catala_en',
        themes: { light: 'github-light', dark: 'github-dark' },
        defaultColor: false,
        includeExplanation: true,
      });
      return tokens.map((line) =>
        line.map((t) => {
          const scopes = t.explanation?.[0]?.scopes ?? [];
          return { text: t.content, style: (t.htmlStyle ?? {}) as Record<string, string>, scope: scopes[scopes.length - 1]?.scopeName ?? '' };
        }),
      );
    });
    p.catch(() => cache.delete(key));
    cache.set(key, p);
  }
  return p;
}
