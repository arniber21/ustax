#!/usr/bin/env node
// Converts the vendored TextMate grammar (Apple plist XML, as shipped by CatalaLang/catala-language-server)
// into the JSON form that Shiki / vscode-textmate load. Pure structural conversion, no grammar edits.
//   node third_party/catala-grammar/plist2json.mjs [in.xml] [out.json]
// Defaults: en.xml -> catala_en.tmLanguage.json (next to this script). Deterministic, no network.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const inFile = process.argv[2] ?? join(here, 'en.xml');
const outFile = process.argv[3] ?? join(here, 'catala_en.tmLanguage.json');
const xml = readFileSync(inFile, 'utf8');

const unescape = (s) => s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'")
  .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(+n)).replace(/&amp;/g, '&');

// Tokens: <dict>, </dict>, <array>, </array>, <key>..</key>, <string>..</string> | <string/>, <integer>, <true/>, <false/>
const re = /<(\/?)(dict|array)\s*>|<key>([\s\S]*?)<\/key>|<string>([\s\S]*?)<\/string>|<string\s*\/>|<integer>(\d+)<\/integer>|<(true|false)\s*\/>/g;
const body = xml.slice(xml.indexOf('<dict>'));
const stack = [];
let root, key = null;
const put = (v) => {
  const top = stack[stack.length - 1];
  if (!top) { root = v; return; }
  if (Array.isArray(top)) top.push(v);
  else { top[key] = v; key = null; }
};
for (let m; (m = re.exec(body));) {
  if (m[2]) {
    if (m[1]) { stack.pop(); continue; }
    const c = m[2] === 'dict' ? {} : [];
    put(c); stack.push(c);
  } else if (m[3] !== undefined) key = unescape(m[3]);
  else if (m[4] !== undefined) put(unescape(m[4]));
  else if (m[5] !== undefined) put(Number(m[5]));
  else if (m[6]) put(m[6] === 'true');
  else put('');
}
writeFileSync(outFile, JSON.stringify(root, null, 2) + '\n');
