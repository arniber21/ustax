/**
 * Calendar-date helpers for `YYYY-MM-DD` strings. Everything works on year/month/day components in the
 * local calendar; `new Date('YYYY-MM-DD')` (parsed as UTC midnight) is never used, so no time zone can
 * move a date by a day.
 */

export interface Ymd {
  y: number;
  m: number;
  d: number;
}

const pad = (n: number, w = 2) => String(n).padStart(w, '0');

function realDate(y: number, m: number, d: number): Ymd | null {
  if (y < 1 || m < 1 || m > 12 || d < 1) return null;
  const feb = y % 4 === 0 && (y % 100 !== 0 || y % 400 === 0) ? 29 : 28;
  const dim = [31, feb, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]!;
  return d <= dim ? { y, m, d } : null;
}

/** `2024-02-29` -> parts, or null when the text is not a real `YYYY-MM-DD` date. */
export function parseIso(s: string): Ymd | null {
  const t = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  return t ? realDate(+t[1]!, +t[2]!, +t[3]!) : null;
}

/** US text `4/12/1986` or `04/12/1986` -> parts, or null when it is not a real date. */
export function parseUs(s: string): Ymd | null {
  const t = /^\s*(\d{1,2})\/(\d{1,2})\/(\d{4})\s*$/.exec(s);
  return t ? realDate(+t[3]!, +t[1]!, +t[2]!) : null;
}

export const toIso = ({ y, m, d }: Ymd) => `${pad(y, 4)}-${pad(m)}-${pad(d)}`;
export const toUs = ({ y, m, d }: Ymd) => `${pad(m)}/${pad(d)}/${pad(y, 4)}`;

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
/** `April 12, 1986` */
export const toLong = ({ y, m, d }: Ymd) => `${MONTHS[m - 1]} ${d}, ${y}`;

/** Local-calendar `Date` at noon for the parts (noon keeps clear of midnight DST shifts). */
export const toLocalDate = ({ y, m, d }: Ymd) => new Date(y, m - 1, d, 12);
/** Parts of a local-calendar `Date` as shown on the calendar grid. */
export const fromLocalDate = (dt: Date): Ymd => ({ y: dt.getFullYear(), m: dt.getMonth() + 1, d: dt.getDate() });
