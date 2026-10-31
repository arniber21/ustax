# web/src/api: typed client for the JSON contract (#74)

- `types.gen.ts` is generated from `api/schema.json`: `npm run gen:api`. `npm run gen:api:check` fails if it is stale (run it in CI).
- `calculate(request)` posts to `${VITE_API_URL ?? http://localhost:8080}/calculate` and returns
  `{kind:'ok'|'knockout'|'error'}`. Responses are validated with ajv against the schema; drift becomes
  `error.type === 'contract'` (and a `console.error`).
- `VITE_API_MOCK=1` serves `api/fixtures` (`mock.ts`) instead of calling the server. A request must equal a fixture request.
- `money.ts`: money is integer cents end to end; `formatCents`, `parseDollars`, `centsToDollarString`, no float arithmetic.
- `npm test`, `npm run typecheck`, `npm run lint`.
