import { describe, expect, it } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import multi from '../../../api/fixtures/knocked-out-multiple-reasons.response.json';
import type { UnsupportedReason } from '../api';
import { UnsupportedView, groupReasons } from './UnsupportedView';

const reasons = multi.reasons as UnsupportedReason[];
const view = (r: UnsupportedReason[]) =>
  render(
    <MemoryRouter>
      <UnsupportedView reasons={r} />
    </MemoryRouter>,
  );

describe('UnsupportedView', () => {
  it('groups reasons by category with what it means and what to do', () => {
    view(reasons);
    expect(groupReasons(reasons).map((g) => g.category)).toEqual(['interest', 'w2', 'income']);
    const interest = screen.getByRole('region', { name: 'Interest and investments' });
    expect(within(interest).getByText(/Foreign tax was paid/)).toBeInTheDocument();
    expect(within(interest).getByText('What this means')).toBeInTheDocument();
    expect(within(interest).getByText('What to do instead')).toBeInTheDocument();
    expect(screen.getByText(/irs\.gov\/freefile/)).toBeInTheDocument();
  });

  it('is never a dead end', () => {
    view(reasons);
    expect(screen.getByRole('link', { name: /Change my answers/ })).toHaveAttribute('href', '/start/about');
    expect(screen.getByRole('button', { name: /Copy this list/ })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Home' })).toBeInTheDocument();
  });

  it('renders an unknown code with fallback wording', () => {
    view([{ code: 'BrandNew', category: 'credits', message: 'Brand New' }]);
    expect(screen.getByText(/isn’t supported yet/)).toBeInTheDocument();
    expect(screen.queryByText('BrandNew')).toBeNull();
  });
});
