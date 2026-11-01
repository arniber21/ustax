// Mapping for catala/api_calculator.catala_en (scope ApiCalculator), issue #38: the API-facing scope. Run:
//   make difftest SCOPE=api_calculator
//
// Every scenario's oracle facts are converted into an API request (`CalculateRequest`, api/schema.json 1.2.0) by
// scripts/oracle_to_api_request.mjs (test-only, untrusted), decoded by scripts/api_decode.mjs into the scope's
// input (cents -> dollars, schema defaults), and the response fields (the 19 `lines`, `supported`) are compared
// with the oracle. A scenario whose request the API shape cannot express is skipped and listed with the reason
// (never silently dropped): today there is none. The expected values are the same as `calculator.mjs`, so the
// known divergences are the same (CONVENTIONS section 8).
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { toApiRequest } from '../../scripts/oracle_to_api_request.mjs';
import { decodeRequest } from '../../scripts/api_decode.mjs';
import { knownDivergence } from './calculator.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const catalog = JSON.parse(readFileSync(join(root, 'api/line-catalog.json'), 'utf8')).lines;

// Where Catala knocks the return out but Direct File computes it (`/flowIsKnockedOut` divergences inherited from
// calculator.mjs), the API answers 422 and returns no `lines` (all $0 in the scope), so every line of those two
// scenarios differs from the oracle by design.
const koScenarios = [...new Set(knownDivergence.filter((d) => d.path === '/flowIsKnockedOut').map((d) => d.scenario))];
const noLines = koScenarios.flatMap((scenario) => catalog.map((l) => ({
  scenario, path: l.df_fact, bug: 'API: unsupported returns no lines (HTTP 422); Catala knocks out, DF does not',
})));
const allKnown = [...knownDivergence, ...noLines];

export { allKnown as knownDivergence };

export default {
  name: 'api_calculator',
  scope: 'ApiCalculator',
  file: 'catala/api_calculator.catala_en',
  knownDivergence: allKnown,
  appliesTo: (facts) => {
    const { inexpressible } = toApiRequest(facts);
    return inexpressible.length === 0 ? true : `API cannot express: ${inexpressible.join('; ')}`;
  },
  inputs: { request: (facts) => decodeRequest(toApiRequest(facts).request) },
  // Lean (`make lean-difftest SCOPE=api_calculator`) reads the API request itself, through the server's
  // strict reader (Api.parseRequest) and mapping (Api.toCalculatorInput): the same request the Catala
  // input above is decoded from, so the decode script is checked too.
  leanInput: (facts) => toApiRequest(facts).request,
  outputs: [
    ...catalog.map((l) => ({ oracle: l.df_fact, catala: `lines.${l.key}`, type: 'money' })),
    // `supported` is NOT /flowIsKnockedOut (a Placeholder `false` of the oracle means "not knocked out")
    { oracle: '/flowIsKnockedOut', catala: 'supported', type: 'bool', placeholderFalse: true, invert: true },
  ],
};
