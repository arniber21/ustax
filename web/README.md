# Sumsure web

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
| `/start/:step` | Wizard: `about`, `household`, `income`, `adjustments`, `review` | #76 to #78 replace `pages/StepPage.tsx` per step |
| `/results` | Refund / you-owe hero, runs the $50,000 single example through the client | #79 |
| `/cant-do-yet` | Friendly knockout page (`UnsupportedView` takes `reasons`) | #80 |
| `/trust` | "Why you can trust this" stub | #82 |

Add a step body by routing `start/:step` children (see `src/App.tsx`); `WizardLayout` supplies progress and Back/Next from `src/layout/steps.ts`.

## Design system

- Tokens: `src/styles/tokens.css` (color, type scale, spacing, radii). Dark mode follows the OS, or `<html data-theme="light|dark">` pins it (`ThemeToggle` persists it).
- Use tokens, never raw hex, in new CSS. Focus rings are global (`:focus-visible`); do not remove outlines.
- Fonts: Fraunces (display) and Nunito (body), bundled via `@fontsource-variable`.
- Motion respects `prefers-reduced-motion`.

## Components (`src/components`, import from `'../components'`)

```tsx
<Button variant="primary|secondary|ghost" size="md|lg" onClick={...}>Save</Button>
<ButtonLink to="/results">See my result</ButtonLink>   {/* router link, same look */}

<Field label="Name" hint="As on your ID" error={err}>
  {(control) => <input {...control} className="input" />}   {/* spread control for a11y wiring */}
</Field>

<MoneyInput label="Wages" hint="Box 1 of your W-2" value={cents} onChange={setCents} />
{/* value/onChange are integer cents (number | null); parsing uses api/money parseDollars; bad text => null + message */}

<Select label="Filing status" value={v} options={[{ value: 'Single', label: 'Single' }]} onChange={setV} />

<Stepper steps={[{ id, label }]} current={0} />   <ProgressBar value={1} max={4} label="..." />
<Card tone="plain|sun|brand">...</Card>
<Callout tone="info|good|warn" title="...">...</Callout>
<Badge tone="neutral|good|warn|sun">Proven</Badge>
<Tooltip content="Plain-language meaning">jargon word</Tooltip>   {/* keyboard + touch friendly */}
<StatGroup><Stat label="Taxable income" cents={3540000} /></StatGroup>   {/* formatCents */}
```

Other pieces: `useCalculation(request)` (hook around `calculate`, keeps the previous result while loading), `ResultsHero` (pages/), `src/examples.ts` (canned requests from `api/examples`).

## Tests

`vitest` with jsdom and testing-library (`src/test/setup.ts`). Component tests live in `src/components/components.test.tsx`; route-level tests in `src/App.test.tsx` run against the fixture mock.
