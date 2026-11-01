/** GitHub-style callouts: `> [!NOTE]` as the first line of a blockquote. */
export const CALLOUT_KINDS = ['note', 'tip', 'important', 'warning', 'caution'] as const;
export type CalloutKind = (typeof CALLOUT_KINDS)[number];

interface MNode {
  type: string;
  value?: string;
  children?: MNode[];
  data?: { hProperties?: Record<string, unknown> };
}

const MARKER = /^\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\][ \t]*\r?\n?/i;

function walk(node: MNode) {
  if (node.type === 'blockquote') {
    const para = node.children?.[0];
    const text = para?.type === 'paragraph' ? para.children?.[0] : undefined;
    const m = text?.type === 'text' ? MARKER.exec(text.value ?? '') : null;
    if (para && text && m) {
      text.value = (text.value ?? '').slice(m[0].length);
      if (text.value === '') para.children!.shift();
      if (para.children!.length === 0) node.children!.shift();
      node.data = { ...node.data, hProperties: { ...node.data?.hProperties, 'data-callout': m[1]!.toLowerCase() } };
    }
  }
  node.children?.forEach(walk);
}

/** remark plugin: marks callout blockquotes with `data-callout="<kind>"` and removes the marker text. */
export function remarkCallouts() {
  return (tree: MNode) => walk(tree);
}
