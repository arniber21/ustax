# US Tax web

US Tax: a formally verified income tax calculator. The web app asks the questions and shows the result; it holds no tax logic.

React + TypeScript + Vite frontend. Talks to the calculator through the typed client in `src/api` (see `src/api/README.md`).

```
make web-dev     # dev server on the api/fixtures mock (VITE_API_MOCK=1)
make web-test    # vitest + testing-library
make web-build   # lint, typecheck, production build
```

Without `VITE_API_MOCK=1` the client calls `VITE_API_URL` (default `http://localhost:8080`).

## Routes

| Path | What | Filled in by |
| --- | --- | --- |
| `/` | Welcome | shell |
| `/start/:step` | Wizard: `about`, `household`, `income`, `adjustments`, `review` | `src/wizard/*Step.tsx` (#76 to #78), chosen by `pages/StepPage.tsx` |
| `/results` | Result summary (refund or amount owed), Form 1040 line table, "How this was calculated" accordion, `warnings` alert, what-if slider, error/offline states (`src/results/`). Request comes from `useCurrentRequest` (the wizard draft) | #79 |
| `/cant-do-yet` | Knockout page: alert plus a table of reasons by category (`src/knockout/`: per-code copy in `reasonCopy.ts`, a test fails if a code in `api/knockout-reasons.json` has none). Also shown inline on `/results` | #80 |
| `/trust` | What is proven (theorem names), tested, trusted, not covered. Copy lives in `src/trust/claims.ts`; keep it within docs/spec-surface.md and docs/audit.md | #82 |

Add a step body by routing `start/:step` children (see `src/App.tsx`); `WizardLayout` supplies progress and Back/Next from `src/layout/steps.ts`.

## Design system

- [shadcn/ui](https://ui.shadcn.com) (Radix primitives + Tailwind CSS v4), configured in `components.json`. Primitives are copied into `src/components/ui/` (button, input, label, card, alert, badge, table, accordion, separator, progress, checkbox, radio-group); edit them there. Selects stay native (styled like shadcn's NativeSelect) for phones and keyboard support.
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

Wizard pieces (`src/wizard/ui.tsx`): `StepHeader`, `FormSection`, `YesNo`, `Check`, `ChoiceCards`, `Repeater`, `More`, `Where`. `WizardLayout` shows a GOV.UK-style error summary (each message jumps to its field via `data-path`) when Next is pressed with problems.

Other pieces: `useCalculation(request)` (hook around `calculate`, keeps the previous result while loading), `ResultsHero` (pages/), `src/examples.ts` (canned requests from `api/examples`).

Screenshots: `docs/screenshots/`.

## Tests

`vitest` with jsdom and testing-library (`src/test/setup.ts`). Component tests live in `src/components/components.test.tsx`; route-level tests in `src/App.test.tsx` run against the fixture mock.

## Wizard draft (`src/draft`, import from `'../draft'`)

```tsx
const { draft, update, reset, request } = useDraft();   // React context + reducer, persisted to localStorage (`ustax.draft.v1`)
buildRequest(draft)      // pure Draft -> CalculateRequest (throws DraftIncompleteError without a filing status)
tryBuildRequest(draft)   // same, or null; `request` from useDraft() is this
validateStep(draft, 'income') / validateDraft(draft)   // plain-language errors keyed by field path
draftFromRequest(req)    // inverse, used for api/examples round-trip tests
```

The wizard only collects what `api/schema.json` accepts. Dependents, HSA, EITC, CDCC and the Saver's credit are not in the contract yet, so there are no questions for them (the household step just warns that child-related credits are not in the math).
