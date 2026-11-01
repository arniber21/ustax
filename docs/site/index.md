---
title: Documentation
order: 0
summary: What these pages are and how to edit them.
---

# Documentation

This section collects the project's write-ups. Every page is a plain markdown file in the
repository, so you can read and edit it on GitHub, and the same file is shown on the website
at `/docs`.

## The pages

- **[How we built this](how-we-built-this.md)**: the author's own account of how Catala and Lean
  were used, and future directions. Written by the author; sections still marked `TODO(you)` are
  not written yet.
- **Existing project documents**, shown here without being moved: the draft
  [write-up](../writeup.md), the [spec surface](../spec-surface.md),
  [Catala to Lean](../catala-to-lean.md), the [Direct File bug log](../direct-file-bugs.md),
  [Comparator](../comparator.md), the [proof audit](../audit.md), the
  [provenance index](../provenance.md) and the [API contract](../api.md).

The full list, in order, is in the sidebar on the website and in [`_nav.json`](_nav.json).

## How to edit a page

1. Open the file under `docs/site/` (or the existing document) on GitHub, or in your editor.
2. Edit the markdown. Every page on the website has an "Edit this page on GitHub" link.
3. Commit. The website reads these same files when it is built, so there is no second copy.

## How to add a page

1. Create `docs/site/<name>.md`. The file name is the page: `docs/site/roadmap.md` becomes
   `/docs/roadmap`.
2. Start it with a front-matter block:

   ```yaml
   ---
   title: Roadmap
   order: 30
   summary: One line shown in the sidebar search and on this page.
   ---
   ```

   `title` is the page title, `order` sorts pages that are not listed in `_nav.json`, and
   `summary` is the one-line description used by the search box.
3. Optionally add the page to [`_nav.json`](_nav.json) to put it at a fixed place in the order.
   Pages in `docs/site/` that are not listed there are appended automatically.

To show a document that lives elsewhere in the repo (for example `docs/audit.md`), add an entry
to `_nav.json` with its `title`, `slug`, `source` path and `summary`. That file needs no
front-matter.

## What you can use in a page

- Relative links to other pages (`../audit.md`) work on GitHub and become `/docs/audit` on the site.
  Links to other repository files (for example `../../lean/UsTax/Audit.lean`) open the file on GitHub.
- Tables, task lists and fenced code blocks. Code is highlighted for `catala`, `lean4`, `ts`,
  `bash` and `json`; `mermaid` blocks show as plain code.
- GitHub-style callouts:

  > [!NOTE]
  > This is a note. `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]` and `[!CAUTION]` also work.
