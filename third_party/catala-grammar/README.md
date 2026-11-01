# Catala TextMate grammar (English)

Vendored for the provenance viewer (`docs/provenance.md`): syntax highlighting of `catala/*.catala_en`.

| File | What | Origin |
|---|---|---|
| `en.xml` | The Catala (English) TextMate grammar, `scopeName` `source.catala_en`, Apple plist XML. **Byte-for-byte upstream.** | `syntaxes/en.xml` in https://github.com/CatalaLang/catala-language-server |
| `LICENSE.txt` | Apache License 2.0, byte-for-byte upstream (`LICENSE.txt` at the repo root) | same repository and commit |
| `catala_en.tmLanguage.json` | `en.xml` converted to JSON (Shiki and vscode-textmate load JSON, not plist). **Derived**, not upstream. | `node third_party/catala-grammar/plist2json.mjs` |
| `plist2json.mjs` | The converter (structural only, no grammar edits, no network) | this repo |

- Upstream repository: https://github.com/CatalaLang/catala-language-server (the "Catala VSCode extension and LSP server"), licence Apache-2.0.
- Upstream commit: `ff047381bc37d7d1705e6104e0782f98cf4faee4` (2026-10-29), fetched with
  `gh api "repos/CatalaLang/catala-language-server/contents/syntaxes/en.xml?ref=<commit>"` on 2026-10-31.
- The compiler repository (https://github.com/CatalaLang/catala, `syntax_highlighting/`) only ships Pygments, Vim and Emacs
  highlighters; the VS Code extension repository above holds the TextMate files. `en.xml` says "Generated via Iro":
  upstream generates it from an Iro definition. It has no licence header of its own; the repository licence applies.
- Not committed: `sources/reference-catala/` (gitignored) was absent when this was vendored.

## Check that it is the Catala grammar (Shiki)

Loaded in Shiki (`npm i --no-save shiki`; `createHighlighter({ langs: [{ ...JSON.parse(catala_en.tmLanguage.json), name: 'catala_en' }] })`)
and run over `catala/tax_rates.catala_en`:

| Source text | Scope |
|---|---|
| `scope`, `definition`, `equals`, `declaration` | `keyword.other.catala_en` |
| `# Tax rate schedules ...` and `## 26 U.S.C. § 1(j)(2): ...` | `markup.heading.title.catala_en` |
| `## One row of a rate table ...` (doc comment inside `catala-metadata`), `# ...` comments in code | `comment.line.catala_en` |
| `Bracket` (type names) | `entity.name.class.catala_en` |
| `money`, `decimal` | `support.type.catala_en` |

Other scopes the grammar emits on that file: `entity.law.catala_en`, `entity.name.function.catala_en`,
`keyword.control.catala_en`, `keyword.operator.catala_en`, `constant.numeric.catala_en`, `meta.variable_id.catala_en`,
`punctuation.catala_en`, `comment.block.documentation.catala_en`.

## Updating

Pick a newer upstream commit, re-download `syntaxes/en.xml` and `LICENSE.txt` at that commit, run
`node third_party/catala-grammar/plist2json.mjs`, and update the commit above.
