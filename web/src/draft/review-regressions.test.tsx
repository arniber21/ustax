import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import {
  buildRequest, draftFromRequest, DraftProvider, emptyDraft, isDraftValid,
  loadDraft, newSsa, newW2, useDraft, validateStep, type Draft,
} from '.';

const ready = (): Draft => {
  const d = emptyDraft();
  d.filingStatus = 'Single';
  d.primary.dob = '2004-06-15';
  d.healthScreening = { marketplace: false, hsaWithdrawals: false };
  d.w2s = [{ ...newW2(), wages: 1_000_000 }];
  return d;
};

function RequestStatus() {
  return <p>{useDraft().request === null ? 'No calculation' : 'Ready to calculate'}</p>;
}

function expectBlocked(d: Draft) {
  render(<DraftProvider initial={d}><RequestStatus /></DraftProvider>);
  expect(screen.getByText('No calculation')).toBeInTheDocument();
}

describe('review regressions', () => {
  it('requires actual birth dates instead of allowing the age-dependent $632 refund default', () => {
    const d = ready();
    expect(isDraftValid(d)).toBe(true);
    d.primary.dob = '';
    expect(validateStep(d, 'about')['primary.dob']).toBeDefined();
    expectBlocked(d);
  });

  it('requires the spouse birth date on joint returns', () => {
    const d = ready();
    d.filingStatus = 'MarriedFilingJointly';
    expect(validateStep(d, 'household')['spouse.dob']).toBeDefined();
    expectBlocked(d);
  });

  it.each(['marketplace', 'hsaWithdrawals'] as const)('refuses %s before any estimate or final calculation', (field) => {
    const d = ready();
    d.healthScreening[field] = true;
    expect(validateStep(d, 'credits')[`healthScreening.${field}`]).toMatch(/cannot calculate/i);
    expectBlocked(d);
  });

  it('requires explicit health screening answers on saved drafts too', () => {
    const d = loadDraft({ getItem: () => JSON.stringify({ version: 1, filingStatus: 'Single' }) });
    expect(d.healthScreening).toEqual({ marketplace: null, hsaWithdrawals: null });
    expect(validateStep(d, 'credits')).toHaveProperty(['healthScreening.marketplace']);
  });

  it('preserves SSA box 6 payments, including positions with no withholding', () => {
    const d = ready();
    d.ssa = [
      { ...newSsa(), netBenefits: 1_000_000 },
      { ...newSsa(), netBenefits: 1_000_000, withheld: 100_000 },
    ];
    const request = buildRequest(d);
    expect(request.social_security?.federal_tax_withheld).toEqual([0, 100_000]);
    expect(buildRequest(draftFromRequest(request)).social_security).toEqual(request.social_security);
    const overCap = { ...newSsa(), netBenefits: 1, withheld: 10_000_000_000_001 };
    expect(validateStep({ ...d, ssa: [overCap] }, 'income')).toHaveProperty([`ssa.${overCap.id}.withheld`]);
  });
});
