import { describe, expect, it } from 'vitest';
import reasons from '../../../api/knockout-reasons.json';
import { CATEGORY_COPY, GENERIC_COPY, REASON_COPY, categoryCopy, friendlyReason } from './reasonCopy';
import type { ReasonCategory } from '../api';

describe('knockout reason copy', () => {
  it('has friendly wording for every code in api/knockout-reasons.json', () => {
    expect(reasons.reasons.length).toBeGreaterThan(0);
    const missing = reasons.reasons.filter((r) => !REASON_COPY[r.code]).map((r) => r.code);
    expect(missing).toEqual([]);
  });

  it('has no copy for codes that do not exist (typos)', () => {
    const known = new Set(reasons.reasons.map((r) => r.code));
    expect(Object.keys(REASON_COPY).filter((c) => !known.has(c))).toEqual([]);
  });

  it('has category copy for every category', () => {
    for (const c of reasons.categories) {
      const copy = CATEGORY_COPY[c as ReasonCategory];
      expect(copy?.title && copy.means && copy.todo, c).toBeTruthy();
    }
  });

  it('every line reads like a sentence, not a code', () => {
    for (const [code, text] of Object.entries(REASON_COPY)) {
      expect(text, code).toMatch(/^[A-Z].*\.$/);
      expect(text, code).not.toMatch(/Knockout|Flow[A-Z]/);
      expect(text.length, code).toBeGreaterThan(15);
    }
  });

  it('falls back to category wording for an unknown code', () => {
    const f = friendlyReason('SomeBrandNewKnockout', 'hsa');
    expect(f.fallback).toBe(true);
    expect(f.what).toContain('health savings accounts');
    expect(f.what).not.toContain('SomeBrandNew');
  });

  it('tolerates an unknown category', () => {
    expect(categoryCopy('from_the_future')).toBe(GENERIC_COPY);
    expect(friendlyReason('X', 'from_the_future' as ReasonCategory).what.length).toBeGreaterThan(10);
  });
});
