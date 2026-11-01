import type { Provenance, ProvLine } from './types';

/**
 * How a Form 1040 line is backed, for the badge next to its "Law & proof" button:
 * - `proved`: api/provenance.json lists at least one Lean theorem for the line (machine-checked).
 * - `tested`: no theorem covers it; the line is checked by differential tests against IRS Direct File.
 * Never `proved` for the Catala rule alone: Catala is a readable specification, validated by testing.
 */
export type LineStatus = 'proved' | 'tested';

export function lineStatus(line: ProvLine | undefined): LineStatus | null {
  if (!line) return null;
  return line.proofs.theorems.length > 0 ? 'proved' : 'tested';
}

/** Status of every line in the provenance index. */
export function statusIndex(p: Provenance): Record<string, LineStatus> {
  const out: Record<string, LineStatus> = {};
  for (const [k, l] of Object.entries(p.lines)) out[k] = lineStatus(l)!;
  return out;
}

export const STATUS_TEXT: Record<LineStatus, { badge: string; long: string }> = {
  proved: { badge: 'Proved', long: 'proved in Lean' },
  tested: { badge: 'Tested', long: 'checked by tests, not proved' },
};
