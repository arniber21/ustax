#!/usr/bin/env node
// Copies exactly the files listed in api/provenance.json#files (Catala and Lean sources) into a directory,
// keeping their repo-relative paths, so the web viewer can fetch them.
//   node scripts/export_sources.mjs --out web/public/sources
// Does nothing without --out. The copies are build output: never commit them. Verifies each sha256 against the index.
import { copyFileSync, mkdirSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const i = process.argv.indexOf('--out');
if (i < 0 || !process.argv[i + 1]) {
  console.error('usage: node scripts/export_sources.mjs --out <dir>   (copies api/provenance.json#files; nothing is written without --out)');
  process.exit(i < 0 ? 0 : 2);
}
const out = resolve(process.argv[i + 1]);
const { files } = JSON.parse(readFileSync(join(root, 'api/provenance.json'), 'utf8'));
for (const f of files) {
  const src = join(root, f.path);
  const sha = createHash('sha256').update(readFileSync(src)).digest('hex');
  if (sha !== f.sha256) { console.error(`${f.path} changed since api/provenance.json was generated: run node scripts/gen_provenance.mjs`); process.exit(1); }
  const dst = join(out, f.path);
  mkdirSync(dirname(dst), { recursive: true });
  copyFileSync(src, dst);
}
console.log(`copied ${files.length} files to ${out}`);
