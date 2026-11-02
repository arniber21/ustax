#!/usr/bin/env node
// Build docs/pdf/ustax-docs.pdf from the markdown docs listed in docs/site/_nav.json (same order as the website).
// Needs `typst` and the Scala Sans font: FONT_PATH=/dir/with/ScalaSans*.ttf node docs/pdf/build.mjs
// (the font is not in this repo; without it Typst falls back to its default font). Needs network once for @preview/cmarker.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const out = join(root, 'docs/pdf/.build');
mkdirSync(out, { recursive: true });
const nav = JSON.parse(readFileSync(join(root, 'docs/site/_nav.json'), 'utf8')).pages.filter((p) => p.slug !== 'verification'); // 'verification' is a live dashboard on the site
const strip = (s) => s.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, '');
let body = '';
nav.forEach((p, i) => {
  const md = strip(readFileSync(join(root, p.source), 'utf8'))
    .replace(/\[([^\]]+)\]\((?!https?:|#|mailto:)[^)]*\)/g, '$1'); // links to repo files/other pages are plain text in the PDF
  writeFileSync(join(out, `p${i}.md`), md);
  body += `#render-page(${JSON.stringify(p.title)}, read("p${i}.md"))\n`;
});
const typ = `
#import "@preview/cmarker:0.1.6"
#let ink = rgb("#0f1b3d")
#let red = rgb("#b3202e")
#set document(title: "US Tax: a formally verified income tax calculator", author: "Arnab Ghosh")
#set page(paper: "us-letter", margin: (x: 1in, y: 1in), numbering: "1", footer-descent: 30%)
#set text(font: ("ScalaSansCompPro", "Helvetica Neue"), size: 10.5pt, fill: rgb("#1a1a1a"))
#set par(justify: false, leading: 0.68em, spacing: 1em)
#show raw: set text(font: ("Menlo", "DejaVu Sans Mono"), size: 8.5pt)
#show raw.where(block: true): it => block(fill: rgb("#f4f5f8"), inset: 8pt, radius: 3pt, width: 100%, it)
#show raw.where(block: false): set text(fill: ink)
#show link: set text(fill: rgb("#1b4fb0"))
#show heading.where(level: 1): it => { pagebreak(weak: true); v(0.5em); text(size: 22pt, weight: "bold", fill: ink, it.body); v(0.2em); line(length: 100%, stroke: 1.2pt + red); v(0.6em) }
#show heading.where(level: 2): it => { v(0.9em); text(size: 14pt, weight: "bold", fill: ink, it.body); v(0.3em) }
#show heading.where(level: 3): it => { v(0.6em); text(size: 11.5pt, weight: "bold", fill: ink, it.body); v(0.2em) }
#show table: set text(size: 8.5pt)
#set table(stroke: 0.4pt + rgb("#c9cdd8"), inset: 5pt)
#show table.cell.where(y: 0): set text(weight: "bold", fill: ink)
#show quote: set block(inset: (left: 10pt), stroke: (left: 2pt + red))

#let render-page(title, src) = {
  pagebreak(weak: true)
  cmarker.render(src, h1-level: 1, raw-typst: false, smart-punctuation: true,
    scope: (:))
}

#page(numbering: none, footer: none)[
  #v(2.2in)
  #text(size: 38pt, weight: "bold", fill: ink)[US Tax]
  #v(0.1in)
  #line(length: 3in, stroke: 2pt + red)
  #v(0.15in)
  #text(size: 17pt, fill: ink)[A formally verified income tax calculator]
  #v(0.2in)
  #text(size: 11pt)[Catala rules, Lean implementation and proofs, Lean HTTP server, React frontend. Tax year 2024, US federal.]
  #v(1fr)
  #text(size: 10pt)[Arnab Ghosh \\ Hackathon submission, November 2026 \\ #link("https://github.com/arniber21/ustax")[github.com/arniber21/ustax]]
]
#set page(numbering: "i")
#outline(title: "Contents", depth: 1)
#set page(numbering: "1")
#counter(page).update(1)
${body}
`;
writeFileSync(join(out, 'main.typ'), typ);
const args = ['compile', '--root', root, join(out, 'main.typ'), join(root, 'docs/pdf/ustax-docs.pdf')];
if (process.env.FONT_PATH) args.splice(1, 0, '--font-path', process.env.FONT_PATH);
execFileSync('typst', args, { stdio: 'inherit' });
console.log('wrote docs/pdf/ustax-docs.pdf');
