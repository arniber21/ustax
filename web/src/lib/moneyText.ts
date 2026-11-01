/**
 * Text helpers for the money input: thousands separators while typing, with the caret kept on the
 * same digit. They only change how the text looks; the value is still parsed by `api/money`'s
 * `parseDollars` into integer cents, so nothing here does arithmetic.
 */

/** Characters that carry meaning (everything except `$`, commas and spaces). */
const SIG = /[\d.-]/;
const sigCount = (s: string) => [...s].filter((c) => SIG.test(c)).length;

/** Adds commas to a run of digits: "1234567" -> "1,234,567". */
export const groupDigits = (digits: string): string => digits.replace(/\B(?=(\d{3})+(?!\d))/g, ',');

/**
 * Regroups what the person typed: "$1234.5" -> "1,234.5", "12,34" -> "1,234". The `$` is dropped
 * because the input shows its own prefix. Text that is not number-shaped (letters, two dots, ...) is
 * returned unchanged so the parser can reject it with a message instead of the input eating keys.
 * `caret` is the cursor position in `raw`; the returned one sits after the same digit in `text`.
 */
export function regroupTyping(raw: string, caret: number = raw.length): { text: string; caret: number } {
  const m = /^\s*(-?)\s*\$?\s*([\d,]*)(?:(\.)(\d*))?\s*$/.exec(raw);
  if (!m) return { text: raw, caret };
  const [, sign = '', intPart = '', dot, frac = ''] = m;
  const digits = intPart.replace(/,/g, '');
  const text = `${sign}${groupDigits(digits)}${dot ?? ''}${frac}`;
  const want = sigCount(raw.slice(0, caret));
  let pos = 0;
  for (let seen = 0; pos < text.length && seen < want; pos++) if (SIG.test(text[pos]!)) seen++;
  return { text, caret: pos };
}

/** The text shown after leaving the field: "1234.5" (from centsToDollarString) -> "1,234.50". */
export function groupDollarString(plain: string): string {
  const neg = plain.startsWith('-');
  const [whole = '0', frac] = (neg ? plain.slice(1) : plain).split('.');
  return `${neg ? '-' : ''}${groupDigits(whole)}${frac !== undefined ? `.${frac}` : ''}`;
}
