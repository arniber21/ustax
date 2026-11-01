export interface FrontMatter {
  title?: string;
  order?: number;
  summary?: string;
}

/**
 * Tiny front-matter reader: a leading `---` block of `key: value` lines (title, order, summary).
 * No YAML library: values are single-line strings, optionally quoted; `order` is a number.
 * Returns the fields and the body without the block. Unknown keys are ignored.
 */
export function parseFrontMatter(src: string): { data: FrontMatter; body: string } {
  if (src.charCodeAt(0) === 0xfeff) src = src.slice(1); // byte-order mark
  const m = /^---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/.exec(src);
  if (!m) return { data: {}, body: src };
  const data: FrontMatter = {};
  for (const line of (m[1] ?? '').split(/\r?\n/)) {
    const kv = /^([A-Za-z_][\w-]*)\s*:\s*(.*)$/.exec(line);
    if (!kv) continue;
    const key = kv[1]!;
    let value = kv[2]!.trim();
    const quoted = /^(["'])(.*)\1$/.exec(value);
    if (quoted) value = quoted[2]!;
    if (key === 'title' || key === 'summary') data[key] = value;
    else if (key === 'order' && value !== '' && Number.isFinite(Number(value))) data.order = Number(value);
  }
  return { data, body: src.slice(m[0].length) };
}
