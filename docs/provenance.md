# Provenance index

`api/provenance.json` gives, for every key of the API `lines` object, a machine-readable trail from the number to the law:
Form 1040 line, the Catala rule that computes it, the statute / regulation / IRS-instruction citations behind it (with public
URLs and local `sources/` files), the Lean implementation, the Lean theorems that cover it, and the differential tests that
check it. It is the data side of a future "click a number, read the law" viewer in `web/`.

Files: `api/provenance.json` (generated, committed), `api/provenance.schema.json` (JSON Schema 2020-12),
`scripts/gen_provenance.mjs` (generator and checker), `scripts/export_sources.mjs` (copies sources for the viewer),
`third_party/catala-grammar/` (TextMate grammar, see its README).

## Honesty rules (the viewer must keep them)

| Field | What it is | Allowed wording |
|---|---|---|
| `rule` | Catala source. A readable specification of the line, validated by differential testing against Direct File. | "rule", "specification". **Never "proved" or "verified".** |
| `proofs` | Lean theorems, machine-checked (axioms `propext`, `Classical.choice`, `Quot.sound`; `docs/spec-surface.md`). Each has a `covers` sentence saying exactly what it states about this line. | "proved", only together with `covers`. |
| `tests` | Differential tests (`difftest/mappings/*`): Catala/Lean outputs agree with Direct File on scenarios. Scenario counts are not stored. `report_only` mappings never fail the build. | "tested", "checked against Direct File". Never "proved". |
| `citations[].origin` | `catala`: the citation text occurs in the Catala headings/comments (`found_in` gives file:line). `curated`: added by hand in `scripts/gen_provenance.mjs` (`CURATED_STATUTES`), for review. | Show curated ones as "statutory basis (editorial)". |

A line without theorems has `proofs.theorems: []`; the viewer must say "no Lean theorem covers this line", not hide it.
Most lines are covered only by tests. A line's theorems say nothing about whether the Catala matches the law.

## Generation

`node scripts/gen_provenance.mjs` (or `make provenance`) reads `api/line-catalog.json` (line keys, Catala output, DF fact),
`catala/form_1040.catala_en` and the module files it calls (`catala/*.catala_en`, never `catala/tests` for rules),
`lean/UsTax/Form1040.lean` and the theorem files, `difftest/mappings/*.mjs`, `lean/comparator.json` and `sources/`. It is
deterministic, offline and has no timestamps. `make provenance-check` (needs `cd api && npm ci`) regenerates in memory and
fails if `api/provenance.json` differs (any change to a referenced Catala/Lean file changes its `sha256`, so commit the
regenerated file with the change), validates against the schema, checks the keys equal `line-catalog.json`, that every line
has a legal citation, and that every `files[].sha256` matches the disk.

How it finds things:

- **Definition block**: the `definition <variable>` in scope `Form1040` (1-based `start`/`end`; `comment_start` is the first
  line of the `#` comment directly above). `heading` is the nearest enclosing markdown heading and its section;
  `statute_heading` the nearest enclosing heading that itself cites a statute or reg (often `null` in `form_1040`).
- **Feeds**: sub-scope calls in the definition (`w2.wages`, `std_deduction.standard_deduction`, `tax_table....`) are resolved
  through `> Using` and the scope declaration to the module file and its definition. Other lines it reads are in
  `depends_on.lines`; plug-in slots (default $0, filled by later modules; the API leaves unwired ones at $0) in `depends_on.slots`.
- **Citations**: regular expressions over the definition's comments and its heading section (and, for feeds, the feed
  definition's comments plus the module's statute headings): `IRC 63(c)`, `26 U.S.C. § 1(j)(2)`, `Treas. Reg. 1.152-4`,
  `Rev. Proc. 2023-34 § 3.15`, `Notice 2023-75`, and `file--2024.pdf p N`. URLs: govinfo for the Code
  (`https://www.govinfo.gov/link/uscode/26/<section>?year=2024&type=usc&link-type=html`; the link is per section, the
  subsection is in the label), `https://www.ecfr.gov/on/2024-12-31/title-26/section-<n>` for regs, irs.gov `irs-prior`
  / `irs-drop` PDFs (`#page=N`) for forms and revenue procedures, as in `sources/INDEX.md`. `local` is the `sources/` file
  (and PDF page) when present.
- **Direct File fact**: from the `# Line n, DF: /fact` comment above the `output` declaration, cross-checked against the catalog.
- **Lean**: the `let` binding in `form1040` (UsTax/Form1040.lean) and the `Form1040Out` field; `lean.feeds` are the module
  definitions called (`formW2s`, `interest`, `standardDeduction`, `tentativeTax`).
- **Theorems**: a hand-curated table (`THEOREMS`) names them; the generator finds each by name, so a rename or deletion
  fails generation. `statement` is the Lean text, `in_comparator_set` is read from `lean/comparator.json`.
- **Tests**: a mapping counts when its Catala file is the line's file, `calculator.catala_en` or a feed's file and its
  `outputs` mention the Catala variable.

`files` lists every referenced Catala/Lean file with repo-relative `path`, `sha256` and `lines`.
`node scripts/export_sources.mjs --out web/public/sources` copies exactly those files (nothing happens without `--out`;
it refuses if a hash differs). Do not commit the copies; the web build calls it.

## How the viewer should render

1. Row per line item: Form 1040 line + `label`, `description`, three clearly separated badges: **Rule** (Catala, "spec,
   tested"), **Proofs** (count, or "none"), **Tests** (mapping names).
2. Source pane: fetch `sources/<rule.file>`, highlight with the Catala grammar (`third_party/catala-grammar/catala_en.tmLanguage.json`,
   scope `source.catala_en`; load in Shiki with `{...grammar, name: 'catala_en'}`), scroll to `rule.definition.start`, mark
   `definition.start..end`, and show `rule.heading` as the section. Same for each `rule.feeds[]` and for Lean
   (`lean.binding`, `proofs.theorems[].start..end`). Check the fetched file's length against `files[].lines`.
3. Citations: group by kind; link `url`; show `local.path` + `local.page` when present; `found_in` jumps to the Catala line;
   mark `origin: curated`.
4. Never present `rule` or `tests` with proof language; show `proofs.theorems[].covers` verbatim next to each theorem.

## Coverage (current)

19 line items. Catala rule: 19/19. DF fact (from Catala comments, equal to the catalog): 19/19. Difftest (non-report-only
mapping): 19/19. Legal citation of any origin: 19/19. **Legal citation found in the Catala text: 2/19** (`standard_or_itemized_deductions`,
`tentative_tax_from_taxable_income`); the other 17 rest on `curated` statutory citations because `form_1040.catala_en` quotes
the form lines and Direct File facts but cites no Code section. Fix is to add citations to the Catala headings (`catala/` is
not edited by this change); the generator then picks them up. Lean theorems: 9/19.

| line item | 1040 line | legal citations: found in Catala / total | Lean theorems | difftest mappings |
|---|---|---|---|---|
| `wages` | 1a | 0/1 | 0 | 4 |
| `employer_income_subtotal` | 1z | 0/1 | 0 | 3 |
| `interest_income` | 2b | 0/1 | 0 | 4 |
| `total_income` | 9 | 0/1 | 0 | 3 |
| `adjustments_to_income` | 10 | 0/1 | 0 | 3 |
| `agi` | 11 | 0/1 | 0 | 3 |
| `standard_or_itemized_deductions` | 12 | 2/2 | 0 | 3 |
| `total_deductions` | 14 | 0/1 | 0 | 3 |
| `taxable_income` | 15 | 0/2 | 1 | 3 |
| `tentative_tax_from_taxable_income` | 16 | 1/1 | 5 | 4 |
| `total_tentative_tax` | 18 | 0/2 | 1 | 3 |
| `non_refundable_credits` | 21 | 0/2 | 1 | 3 |
| `tax_less_non_refundable_credits` | 22 | 0/1 | 2 | 3 |
| `total_tax` | 24 | 0/1 | 3 | 3 |
| `total_withholding` | 25d | 0/1 | 0 | 3 |
| `total_other_payments_refundable_credits` | 32 | 0/3 | 0 | 3 |
| `total_payments` | 33 | 0/3 | 1 | 3 |
| `overpayment` | 34 | 0/2 | 3 | 3 |
| `balance_due` | 37 | 0/1 | 3 | 3 |

Why lines lack Lean theorems: no property is stated about them yet. The six main theorems (`docs/spec-surface.md`) concern
lines 16, 18/21/22, 24, 33, 34 and 37; `taxableIncome_nonneg` covers line 15. Income lines (1a to 11), deductions (12, 14) and
payments (25d, 32) are checked only by tests. Counts of theorems and mappings are as of generation; the table is not
regenerated automatically (`api/provenance.json#coverage` is).

Caveats: the API wires only W-2, 1099-INT, standard deduction and Tax Table (`lean/UsTax/Api/Bridge.lean`); lines 21 and 32 and
others fed by plug-in slots are $0 in the API today even though their Catala slots are filled in `Calculator`. The Catala
`rule` is the `Form1040` scope that the API mirrors, not `Calculator`.
