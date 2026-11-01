/** Code blocks in docs: Shiki with the same themes and Catala grammar as the provenance viewer. */
export interface DocTok {
  text: string;
  style: Record<string, string>;
}

/** Fence info string to Shiki language id. Anything not listed (mermaid, text, ...) stays plain. */
const ALIASES: Record<string, string> = {
  catala: 'catala_en',
  catala_en: 'catala_en',
  lean: 'lean4',
  lean4: 'lean4',
  ts: 'typescript',
  typescript: 'typescript',
  tsx: 'typescript',
  bash: 'bash',
  sh: 'bash',
  shell: 'bash',
  json: 'json',
  yaml: 'yaml',
  yml: 'yaml',
};

export const shikiLang = (fence: string | undefined): string | null => (fence ? (ALIASES[fence.toLowerCase()] ?? null) : null);

async function makeHighlighter() {
  const [{ createHighlighterCore }, { createJavaScriptRegexEngine }, light, dark, lean, ts, bash, json, yaml, catala] = await Promise.all([
    import('shiki/core'),
    import('shiki/engine/javascript'),
    import('@shikijs/themes/github-light'),
    import('@shikijs/themes/github-dark'),
    import('@shikijs/langs/lean4'),
    import('@shikijs/langs/typescript'),
    import('@shikijs/langs/bash'),
    import('@shikijs/langs/json'),
    import('@shikijs/langs/yaml'),
    import('../../../third_party/catala-grammar/catala_en.tmLanguage.json'),
  ]);
  return createHighlighterCore({
    themes: [light.default, dark.default],
    langs: [lean.default, ts.default, bash.default, json.default, yaml.default, { ...(catala.default as object), name: 'catala_en' } as never],
    engine: createJavaScriptRegexEngine({ forgiving: true }),
  });
}

let hl: ReturnType<typeof makeHighlighter> | null = null;

/** Tokenize `code` in Shiki language `lang` (one array of tokens per line). Loads Shiki on first use. */
export async function highlightDoc(code: string, lang: string): Promise<DocTok[][]> {
  hl ??= makeHighlighter();
  const h = await hl;
  const { tokens } = h.codeToTokens(code, { lang, themes: { light: 'github-light', dark: 'github-dark' }, defaultColor: false });
  return tokens.map((line) => line.map((t) => ({ text: t.content, style: (t.htmlStyle ?? {}) as Record<string, string> })));
}
