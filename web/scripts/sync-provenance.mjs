#!/usr/bin/env node
// Web `prebuild` / `predev` step for the provenance viewer (docs/provenance.md):
//   1. fails loudly if api/provenance.json is stale (same check as `make provenance-check`),
//   2. copies api/provenance.json to web/public/provenance.json,
//   3. copies the Catala/Lean sources it references to web/public/sources (scripts/export_sources.mjs --out).
// The copies are gitignored build output. Set USTAX_SKIP_PROVENANCE_CHECK=1 to skip step 1 (copies are still verified by sha256).
import { copyFileSync, existsSync, mkdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const web = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const root = resolve(web, '..');
const fail = (msg) => {
  console.error(`\nsync-provenance: ${msg}\n`);
  process.exit(1);
};
const run = (cmd, args, cwd) => spawnSync(cmd, args, { cwd, stdio: 'inherit' });

if (process.env.USTAX_SKIP_PROVENANCE_CHECK !== '1') {
  if (!existsSync(join(root, 'api/node_modules'))) {
    console.log('sync-provenance: installing api/ dependencies (needed by the provenance check)');
    if (run('npm', ['ci', '--ignore-scripts', '--no-audit', '--no-fund'], join(root, 'api')).status !== 0) fail('npm ci in api/ failed');
  }
  if (run('node', ['scripts/gen_provenance.mjs', '--check'], root).status !== 0) {
    fail('api/provenance.json is stale or invalid. Run `make provenance` and commit the result (see docs/provenance.md).');
  }
}

mkdirSync(join(web, 'public'), { recursive: true });
copyFileSync(join(root, 'api/provenance.json'), join(web, 'public/provenance.json'));
if (run('node', ['scripts/export_sources.mjs', '--out', join(web, 'public/sources')], root).status !== 0) {
  fail('could not export sources (a referenced file changed since api/provenance.json was generated)');
}
