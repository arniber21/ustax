# US Tax web

US Tax: a formally verified income tax calculator. The web app asks the questions and shows the result; it holds no tax logic.

React + TypeScript + Vite frontend. Talks to the calculator through the typed client in `src/api` (see `src/api/README.md`).

```
make web-dev     # dev server on the api/fixtures mock (VITE_API_MOCK=1)
make web-test    # vitest + testing-library
make web-build   # lint, typecheck, production build
make e2e         # Playwright end-to-end tests on the REAL stack (see below)
```

Without `VITE_API_MOCK=1` the client calls `VITE_API_URL` (default `http://localhost:8080`).

## Routes

| Path | What | Filled in by |
| --- | --- | --- |
| `/` | Welcome | shell |
| `/start/:step` | Wizard: `about`, `household`, `dependents`, `income`, `adjustments`, `credits`, `review` | `src/wizard/*Step.tsx` (#76 to #78), chosen by `pages/StepPage.tsx` |
| `/results` | Result summary (refund or amount owed), Form 1040 line table, "How this was calculated" accordion, `warnings` alert, what-if slider, error/offline states (`src/results/`). Request comes from `useCurrentRequest` (the wizard draft) | #79 |
| `/cant-do-yet` | Knockout page: alert plus a table of reasons by category (`src/knockout/`: per-code copy in `reasonCopy.ts`, a test fails if a code in `api/knockout-reasons.json` has none). Also shown inline on `/results` | #80 |
| `/docs/verification` (`/trust` redirects) | Two tiers, styled apart: "Proved" (40 Comparator-checked Lean theorems) and "Verified (tested)" (the Catala rules agree with IRS Direct File; not a proof), then tested, trusted, not covered, bugs found in Direct File. All data lives in `src/trust/facts.ts`; `facts.test.ts` fails if it drifts from `lean/comparator*.json`, `docs/direct-file-bugs.md`, `STATUS.md` or the `catala/` and `difftest/mappings/` file counts | #82 |

Add a step body by routing `start/:step` children (see `src/App.tsx`); `WizardLayout` supplies progress and Back/Next from `src/layout/steps.ts`.

## Design system

- [Base UI](https://base-ui.com) powers shared buttons, checkboxes, radio groups, dialogs, sheets and the clear-return confirmation. Existing shadcn-style wrappers retain their public interfaces. Other primitives still use [shadcn/ui](https://ui.shadcn.com) (Radix + Tailwind CSS v4), configured in `components.json`. Primitives are copied into `src/components/ui/` (added with the shadcn CLI, versions pinned, no CDN); edit them there. Long lists stay native selects (styled like shadcn's NativeSelect) for phones; short explained choices use shadcn Select (`ChoiceSelect`), coded lists a Combobox (W-2 box 12), yes/no and "whose form" a segmented RadioGroup.
- Forms: react-hook-form + zod (shadcn Form/Field). `forms/DraftForm.tsx` wraps each step; its values follow the draft store (still the single source of truth, `buildRequest` and `validateStep` unchanged). A field is bound by its draft `path` (`forms/formName.ts` maps it to the form name); once left, the zod schema (`forms/draftSchema.ts`: contract caps, enums and list sizes, checked against `api/schema.json` in `polish.test.tsx`) reports inline. Step errors after Next, and the error summary, work as before.
- Money inputs: shadcn InputGroup with `$` and `USD`, right-aligned tabular figures, thousands separators while typing (`lib/moneyText.ts`, caret kept in place), integer cents underneath.
- Feedback: Sonner toasts (saved progress, copied summary or path, calculator unreachable), Skeletons while loading, designed empty states, a ⌘K / Ctrl+K / `/` command palette (`src/command/`, lazy chunk).
- Tokens: CSS variables in `src/index.css` (neutral slate, one blue accent `--primary`, `--success`/`--destructive` only for refund/owe and status). Dark mode follows the OS, or `<html data-theme="light|dark">` pins it (`ThemeToggle`, key `ustax-theme`).
- Font: Inter, bundled with `@fontsource-variable/inter` (no CDN). Numbers use `tabular-nums`.
- Focus rings are global (`:focus-visible`); do not remove outlines. No decorative motion; `prefers-reduced-motion` is honoured.
- Help text is always visible under the label; never put essential information only in a tooltip.

## Components (`src/components`, import from `'../components'`)

```tsx
<Button variant="primary|secondary|ghost" size="md|lg" onClick={...}>Save</Button>
<ButtonLink to="/results">See my result</ButtonLink>   {/* router link, same look */}

<Field label="Name" hint="As on your ID" error={err} path="draft.path">
  {(control) => <Input {...control} />}   {/* spread control for a11y wiring */}
</Field>

<MoneyInput label="Wages" hint="Box 1 of your W-2" value={cents} onChange={setCents} />
{/* value/onChange are integer cents (number | null); parsing uses api/money parseDollars; bad text => null + message */}

<Select label="Filing status" value={v} options={[{ value: 'Single', label: 'Single' }]} onChange={setV} />

<Stepper steps={[{ id, label }]} current={0} hrefFor={(id) => ...} />   <ProgressBar value={1} max={4} label="..." />
<Card tone="plain|muted">...</Card>
<Callout tone="info|good|warn" title="...">...</Callout>   {/* shadcn Alert, role="note" */}
<Badge tone="neutral|good|warn|sun">Proven</Badge>
<StatGroup><Stat label="Taxable income" cents={3540000} /></StatGroup>   {/* formatCents */}
```

Wizard pieces (`src/wizard/ui.tsx`): `StepHeader`, `FormSection` (card with icon), `YesNo`, `Check`, `Toggle` (Switch), `ChoiceCards`, `WhoSelect`, `Repeater` (with empty state), `More` (Collapsible), `Where`; `W2Help.tsx` is the "Where do I find this on my W-2?" diagram. `LiveSummary.tsx` is the running estimate: POST /calculate on the draft, debounced 700 ms, a sticky card from 1280px and a bottom bar with a details sheet below. `WizardLayout` shows a GOV.UK-style error summary (each message jumps to its field via `data-path`) when Next is pressed with problems.

Other pieces: `useCalculation(request)` (hook around `calculate`, keeps the previous result while loading), `ResultsHero` (pages/), `src/examples.ts` (canned requests from `api/examples`).

Screenshots: `docs/screenshots/`.

## Tests

`vitest` with jsdom and testing-library (`src/test/setup.ts`). Component tests live in `src/components/components.test.tsx`; route-level tests in `src/App.test.tsx` run against the fixture mock.

## Wizard draft (`src/draft`, import from `'../draft'`)

```tsx
const { draft, update, reset, request } = useDraft();   // React context + reducer, persisted to localStorage (`ustax.draft.v1`)
buildRequest(draft)      // pure Draft -> CalculateRequest (throws DraftIncompleteError without a filing status)
tryBuildRequest(draft)   // conversion only, or null without a filing status
request                 // useDraft(): null until all required answers are valid and supported
validateStep(draft, 'income') / validateDraft(draft)   // plain-language errors keyed by field path
draftFromRequest(req)    // inverse, used for api/examples round-trip tests
```

The wizard collects dependents, credits, HSA contributions and supported income, including SSA-1099
box 6 withholding. Birth dates are required for every filer. Explicit health screening answers are
required: Marketplace coverage and HSA withdrawals, rollovers or excess contributions stop calculation
because the wizard does not collect those forms. Incomplete or unsupported answers suppress both
the running estimate and final results; opening `/results` directly returns to the first problem.
Older saved drafts keep their answers and must complete the new screening questions.

## Provenance viewer (`src/provenance/`)

Each Form 1040 line on `/results` has a "Law & proof" button with a chip, "Proved" when `api/provenance.json` lists a Lean theorem for the line and "Tested" otherwise (`provenance/status.ts`); it is also inside the "How this was calculated" accordion. A first-visit callout (dismissible, `localStorage` key `ustax.provenanceTour.v1`) points at it and highlights line 15 for 5 seconds. The button opens a sheet: the law (citations), the Catala rule (Shiki, vendored Catala grammar, definition lines marked), what is proved (Lean theorems from `proofs.theorems`, or "No theorem covers this line yet"), how it is tested, and the Direct File fact. Data: `api/provenance.json` (docs/provenance.md). Catala is shown as a readable rule validated by tests, never as proved.

`npm run dev` and `npm run build` first run `scripts/sync-provenance.mjs`: it fails if `api/provenance.json` is stale (same check as `make provenance-check`; run `make provenance` and commit), then copies it and the referenced sources to `public/provenance.json` and `public/sources/` (gitignored). Running `npx vite` directly skips this: run `node scripts/sync-provenance.mjs` once. Shiki, its grammars and themes are dynamic imports (separate chunks).

## End-to-end tests (`make e2e`)

Playwright drives the browser against the real Lean server (`lean/.lake/build/bin/ustax-server`) and the Vite dev server, no mocks. Playwright starts both (`webServer` in `playwright.config.ts`) on ports 8190 and 5190 and stops both when the run ends, so nothing is left running and the usual 8080/5173 stay free. Specs: `e2e/scenarios.spec.ts` (single filer, MFJ with two children via the wizard, head of household with the earned income credit, a knockout, the provenance drawer, the date picker, keyboard-only) and `e2e/mobile.spec.ts` (Pixel 7 smoke). Expected amounts come from `api/examples/*.response.json`.

- Browser: `make e2e` runs `npx playwright install chromium` (about 150 MB, cached in `~/Library/Caches/ms-playwright`). To use the installed Google Chrome instead: `E2E_CHANNEL=chrome make e2e`.
- `SKIP_LEAN_BUILD=1` skips `lake build ustax-server`; `USTAX_SERVER_BIN=<path>` uses another binary; `E2E_API_PORT` / `E2E_WEB_PORT` change the ports; `ARGS="-g keyboard"` filters tests.
- Works with `USTAX_NO_DEVBOX=1`. The demo script is `scripts/demo.md`.

## Navigation and clearing a return

The header has one Docs entry, with Verification in its sidebar. The footer links to Docs,
Verification, the API and source code. Clear return is available in the header, review page and
command palette; all use the same Base UI alert dialog. The safe option receives initial focus,
Escape cancels, and confirmation resets the draft and starts an empty return.
