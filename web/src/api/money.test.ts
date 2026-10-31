import { describe, expect, it } from 'vitest';
import { centsToDollarString, dollarsToCents, formatCents, parseDollars, sumCents } from './money';

describe('centsToDollarString', () => {
  it.each([
    [0, '0.00'],
    [5, '0.05'],
    [100, '1.00'],
    [123456, '1234.56'],
    [5000000, '50000.00'],
    [-5, '-0.05'],
    [-12345, '-123.45'],
    [10000000000000, '100000000000.00'],
  ])('%i -> %s', (c, s) => expect(centsToDollarString(c)).toBe(s));
  it('rejects non-integers', () => {
    expect(() => centsToDollarString(1.5)).toThrow(RangeError);
    expect(() => centsToDollarString(NaN)).toThrow(RangeError);
  });
});

describe('formatCents', () => {
  it.each([
    [5000000, '$50,000.00'],
    [401900, '$4,019.00'],
    [0, '$0.00'],
    [99, '$0.99'],
    [-12345, '-$123.45'],
    [100000000, '$1,000,000.00'],
  ])('%i -> %s', (c, s) => expect(formatCents(c)).toBe(s));
  it('can hide cents', () => expect(formatCents(401900, { showCents: false })).toBe('$4,019'));
});

describe('parseDollars', () => {
  it.each([
    ['0', 0],
    ['1234', 123400],
    ['1,234.56', 123456],
    ['$50,000', 5000000],
    ['$ 12.3', 1230],
    ['.5', 50],
    ['-12.30', -1230],
    ['-0', 0],
    ['0.10', 10],
    ['19.99', 1999],
    ['  7.00 ', 700],
  ])('%j -> %i', (s, c) => expect(parseDollars(s)).toBe(c));
  it.each(['', '.', '-', 'abc', '1.234', '1e3', '1,23', '12,34,567', '1.2.3', '99999999999999999999'])(
    'rejects %j',
    (s) => expect(parseDollars(s)).toBeNull(),
  );
  it('has no float rounding error (0.1 + 0.2 style)', () => {
    expect(parseDollars('0.29')).toBe(29);
    expect(parseDollars('1.15')).toBe(115);
    expect(parseDollars('4.35')).toBe(435);
  });
  it('round-trips with centsToDollarString', () => {
    for (const c of [0, 1, 29, 115, 435, 99999, -7, 123456789]) {
      expect(parseDollars(centsToDollarString(c))).toBe(c);
    }
  });
});

describe('dollarsToCents / sumCents', () => {
  it('whole dollars', () => expect(dollarsToCents(50000)).toBe(5000000));
  it('rejects fractional dollars', () => expect(() => dollarsToCents(0.1)).toThrow(RangeError));
  it('sums exactly', () => {
    expect(sumCents([10, 20])).toBe(30);
    expect(sumCents([])).toBe(0);
    expect(() => sumCents([1.5])).toThrow(RangeError);
  });
});
