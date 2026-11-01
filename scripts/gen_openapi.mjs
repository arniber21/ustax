// Generate api/openapi.json (OpenAPI 3.1) from api/schema.json + api/examples + api/fixtures.
// No schema is copied by hand: every $defs entry becomes components/schemas/<Name>.
//   node scripts/gen_openapi.mjs           write api/openapi.json
//   node scripts/gen_openapi.mjs --check   fail if api/openapi.json is stale
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const api = join(dirname(fileURLToPath(import.meta.url)), '..', 'api');
const read = (p) => JSON.parse(readFileSync(join(api, p), 'utf8'));
const schema = read('schema.json');
const manifest = read('fixtures/manifest.json').fixtures;
const schemaVersion = read('fixtures/version.response.json').schema_version;

// $defs refs become components refs; the draft-2020-12 vocabulary is what OpenAPI 3.1 uses.
const rewrite = (v) => {
  if (Array.isArray(v)) return v.map(rewrite);
  if (v && typeof v === 'object') {
    return Object.fromEntries(
      Object.entries(v).map(([k, x]) => [k, k === '$ref' && typeof x === 'string' ? x.replace('#/$defs/', '#/components/schemas/') : rewrite(x)]),
    );
  }
  return v;
};
const schemas = rewrite(schema.$defs);

const SUMMARY = (name) => name.replace(/^(error|knocked-out)-/, '').replace(/-/g, ' ');

const exampleOf = (e) => ({ summary: SUMMARY(e.name), value: read(e.response) });
const responseExamples = (pred) => Object.fromEntries(manifest.filter(pred).map((e) => [e.name, exampleOf(e)]));
const json = (ref, examples) => ({ 'application/json': { schema: { $ref: ref }, examples } });
const err = (description, pred) => ({
  description,
  content: json('#/components/schemas/ErrorResponse', responseExamples(pred)),
});

const calcPost = (e) => e.method === 'POST' && e.path === '/calculate';
const requestExamples = Object.fromEntries(
  manifest
    .filter((e) => calcPost(e) && e.request && !e.content_type && ![415, 500].includes(e.status))
    .map((e) => [
      e.name,
      {
        summary: SUMMARY(e.name),
        description: `Answered with HTTP ${e.status}.`,
        value: read(e.request),
        'x-expected-status': e.status,
      },
    ]),
);

const calcResponses = {
  200: {
    description: 'Calculated. Every money value is integer cents; `warnings` lists non-fatal notes.',
    content: json('#/components/schemas/CalculateSuccess', responseExamples((e) => calcPost(e) && e.status === 200)),
  },
  400: err(
    'The body is not valid JSON, breaks the schema, has an unknown field, or fails a cross-field rule. `details` lists each problem by JSON pointer.',
    (e) => calcPost(e) && e.status === 400,
  ),
  404: err('No such path.', (e) => e.status === 404),
  405: err('Wrong method for the path (`GET /calculate`).', (e) => e.status === 405),
  413: err('Body larger than 256 KiB.', (e) => e.status === 413),
  415: err('Content-Type is not `application/json`.', (e) => e.status === 415),
  422: {
    description: 'The request is valid but uses something the calculator does not support yet. No tax is computed; `reasons` says why.',
    content: json('#/components/schemas/CalculateUnsupported', responseExamples((e) => calcPost(e) && e.status === 422)),
  },
  500: err('Server fault. Not reproducible from the request.', (e) => e.status === 500),
};

const simpleGet = (name, ref, summary, description) => ({
  get: {
    operationId: name,
    tags: ['Service'],
    summary,
    description,
    responses: {
      200: {
        description: 'OK',
        content: json(ref, responseExamples((e) => e.method === 'GET' && e.path === `/${name}` && e.status === 200)),
      },
      500: err('Server fault.', (e) => e.status === 500),
    },
  },
});

const doc = {
  openapi: '3.1.0',
  info: {
    title: 'US Tax API',
    version: schemaVersion,
    summary: 'Tax year 2024 federal return calculator.',
    description:
      'JSON API in front of the Lean calculator. Every money value is an integer number of cents. ' +
      'There is no authentication. Bodies are limited to 256 KiB. ' +
      'The contract is `api/schema.json`; this document is generated from it by `scripts/gen_openapi.mjs`.',
  },
  servers: [{ url: 'http://localhost:8080', description: 'Local server (`make server`)' }],
  tags: [
    { name: 'Calculator', description: 'Compute a federal return.' },
    { name: 'Service', description: 'Liveness and version.' },
  ],
  paths: {
    '/calculate': {
      post: {
        operationId: 'calculate',
        tags: ['Calculator'],
        summary: 'Calculate a federal return',
        description:
          "Takes the filer's facts and answers 200 with every Form 1040 line, 422 when something in the request is outside what the calculator supports, or an error body.",
        requestBody: {
          required: true,
          content: { 'application/json': { schema: { $ref: '#/components/schemas/CalculateRequest' }, examples: requestExamples } },
        },
        responses: calcResponses,
      },
    },
    '/health': simpleGet('health', '#/components/schemas/HealthResponse', 'Liveness check', 'Answers 200 `{"status":"ok"}` when the server is up.'),
    '/version': simpleGet('version', '#/components/schemas/VersionResponse', 'Contract and build version', 'Schema semver, tax year and the git commit of the calculator build.'),
  },
  components: { schemas },
};

const out = JSON.stringify(doc, null, 2) + '\n';
const file = join(api, 'openapi.json');
if (process.argv.includes('--check')) {
  let cur = '';
  try {
    cur = readFileSync(file, 'utf8');
  } catch {
    /* missing */
  }
  if (cur !== out) {
    console.error('api/openapi.json is stale: run `node scripts/gen_openapi.mjs`');
    process.exit(1);
  }
  console.log('api/openapi.json is up to date');
} else {
  writeFileSync(file, out);
  console.log(`wrote api/openapi.json (${out.length} bytes)`);
}
