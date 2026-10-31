/**
 * Money helpers. The wire format is integer cents (docs/api.md, "Money: integer cents").
 * All arithmetic stays in integer cents; a float dollar value is never produced or consumed.
 * Display strings are built from integer division and remainder only.
 */

/** Integer number of cents. */
export type Cents = number;

export const isCents = (v: unknown): v is Cents => typeof v === 'number' && Number.isSafeInteger(v);

/** Cents -> plain dollar string with exactly two decimals, e.g. 123456 -> "1234.56", -5 -> "-0.05". */
export function centsToDollarString(cents: Cents): string {
  if (!isCents(cents)) throw new RangeError(`not an integer cent amount: ${cents}`);
  const sign = cents < 0 ? '-' : '';
  const abs = Math.abs(cents);
  const dollars = Math.floor(abs / 100);
  const rem = abs % 100;
  return `${sign}${dollars}.${rem.toString().padStart(2, '0')}`;
}

/** Cents -> display string with `$` and thousands separators, e.g. 5000000 -> "$50,000.00". */
export function formatCents(cents: Cents, opts: { showCents?: boolean } = {}): string {
  const plain = centsToDollarString(cents);
  const neg = plain.startsWith('-');
  const [whole = '0', frac = '00'] = (neg ? plain.slice(1) : plain).split('.');
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  const body = opts.showCents === false ? grouped : `${grouped}.${frac}`;
  return `${neg ? '-' : ''}$${body}`;
}

/**
 * User-typed dollars -> cents. Accepts "1234", "1,234.5", "$1,234.56", "-12.30", ".5".
 * Returns null for anything else, including more than two decimals (never rounds silently),
 * exponents, and values outside the safe integer range.
 */
export function parseDollars(input: string): Cents | null {
  const m = /^\s*(-)?\s*\$?\s*(\d{1,3}(?:,\d{3})+|\d+)?(?:\.(\d{1,2}))?\s*$/.exec(input);
  if (!m) return null;
  const [, neg, whole, frac] = m;
  if (whole === undefined && frac === undefined) return null;
  const dollars = Number((whole ?? '0').replace(/,/g, ''));
  const cents = dollars * 100 + Number((frac ?? '').padEnd(2, '0') || '0');
  if (!Number.isSafeInteger(cents)) return null;
  return neg ? (cents === 0 ? 0 : -cents) : cents;
}

/** Whole dollars -> cents (integer input only). */
export function dollarsToCents(dollars: number): Cents {
  if (!Number.isSafeInteger(dollars)) throw new RangeError(`not a whole dollar amount: ${dollars}`);
  const cents = dollars * 100;
  if (!Number.isSafeInteger(cents)) throw new RangeError('amount out of range');
  return cents;
}

/** Exact integer sum of cent amounts. */
export function sumCents(values: readonly Cents[]): Cents {
  let total = 0;
  for (const v of values) {
    if (!isCents(v)) throw new RangeError(`not an integer cent amount: ${v}`);
    total += v;
    if (!Number.isSafeInteger(total)) throw new RangeError('sum out of range');
  }
  return total;
}
