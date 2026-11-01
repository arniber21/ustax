import { formatCents, type CalculateSuccess } from '../api';
import { KEY_FIGURES, outcomeLabel } from '../pages/ResultsHero';

/** The plain-text summary behind "Copy summary". */
export function summaryText(data: CalculateSuccess, filingStatus?: string): string {
  const { lines, outcome } = data;
  const amount = outcome === 'refund' ? lines.overpayment : outcome === 'balance_due' ? lines.balance_due : 0;
  return [
    'US Tax: 2024 federal income tax (Form 1040)',
    ...(filingStatus ? [`Filing status: ${filingStatus}`] : []),
    `${outcomeLabel(outcome)}: ${formatCents(amount)}`,
    '',
    ...KEY_FIGURES.map((f) => `Line ${f.line}, ${f.label}: ${formatCents(lines[f.key] ?? 0)}`),
    '',
    'An estimate from a research calculator. Not tax advice; nothing was filed.',
  ].join('\n');
}
