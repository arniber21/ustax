// TEST-ONLY, UNTRUSTED: recompute the response of every 200/422 `POST /calculate` entry of
// api/fixtures/manifest.json with the Catala scope ApiCalculator (scripts/api_catala.mjs) and compare it with
// the committed response file. The numbers of api/examples are therefore the Catala reference's, not hand-typed.
//   node scripts/api_check_examples.mjs            fail if any committed response differs (make api-examples)
//   node scripts/api_check_examples.mjs --write    rewrite the response files that differ
// Needs `clerk` on PATH (export PATH=$HOME/.opam/default/bin:$PATH); about 8 seconds per entry.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { runCatalaRequest, toResponse } from './api_catala.mjs';

const api = join(resolve(dirname(fileURLToPath(import.meta.url)), '..'), 'api');
const write = process.argv.includes('--write');
const manifest = JSON.parse(readFileSync(join(api, 'fixtures/manifest.json'), 'utf8')).fixtures;
let bad = 0, n = 0;
for (const e of manifest) {
  if (!(e.status === 200 || e.status === 422) || !e.request || e.path !== '/calculate') continue;
  n++;
  const want = JSON.parse(readFileSync(join(api, e.response), 'utf8'));
  const got = toResponse(runCatalaRequest(JSON.parse(readFileSync(join(api, e.request), 'utf8')), e.name));
  if (JSON.stringify(want) === JSON.stringify(got)) { console.log(`same  ${e.name}`); continue; }
  console.log(`DIFF  ${e.name}`);
  if (write) writeFileSync(join(api, e.response), JSON.stringify(got, null, 2) + '\n');
  else { bad++; console.log('  committed:', JSON.stringify(want)); console.log('  catala:   ', JSON.stringify(got)); }
}
console.log(`${n} responses checked, ${bad} differ`);
process.exit(bad ? 1 : 0);
