import { fireEvent } from '@testing-library/react';
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { App, preloadRoutes } from './App';

beforeAll(preloadRoutes);
import { STORAGE_KEY, draftFromRequest } from './draft';
import { EXAMPLES } from './examples';

// Unit tests run the typed client against the api/fixtures mock, same as VITE_API_MOCK=1.
beforeAll(() => vi.stubEnv('VITE_API_MOCK', '1'));
beforeEach(() => window.localStorage.clear());

const at = (path: string) =>
  render(
    <MemoryRouter initialEntries={[path]}>
      <App />
    </MemoryRouter>,
  );

describe('routing', () => {
  it('home links into the wizard', () => {
    at('/');
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('A formally verified income tax calculator');
    expect(screen.getByRole('link', { name: /Start your return/ })).toHaveAttribute('href', '/start/about');
    for (const a of screen.getAllByRole('link', { name: 'What is verified' })) expect(a).toHaveAttribute('href', '/docs/verification');
  });

  it('wizard walks through all seven steps', async () => {
    at('/start/about');
    await userEvent.click(screen.getByRole('radio', { name: /^Single/ }));
    fireEvent.change(screen.getByLabelText('Your date of birth'), { target: { value: '06/15/1985' } });
    const titles = ['Your household', 'Dependents', 'Income', 'Adjustments and payments', 'Credits and care costs', 'Review your answers'];
    const labels = ['Your household', 'Dependents', 'Income', 'Adjustments and payments', 'Credits and care costs', 'Review'];
    for (const [n, label] of labels.entries()) {
      if (label === 'Review') {
        for (const name of [/Marketplace health insurance/, /HSA withdrawals, rollovers/]) {
          await userEvent.click(within(screen.getByRole('group', { name })).getByRole('radio', { name: 'No' }));
        }
      }
      await userEvent.click(screen.getByRole('button', { name: new RegExp(`Next: ${label}`) }));
      expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(titles[n]!);
    }
    expect(screen.getByRole('button', { name: /Calculate my return/ })).toBeInTheDocument();
  });

  it('Next waits for a filing status and says why', async () => {
    at('/start/about');
    await userEvent.click(screen.getByRole('button', { name: /Next: Your household/ }));
    expect(screen.getAllByRole('alert').some((e) => /Pick the option that fits/.test(e.textContent ?? ''))).toBe(true);
    const summary = screen.getByRole('group', { name: 'There are 2 problems' });
    expect(summary).toHaveFocus();
    expect(within(summary).getByRole('link', { name: /Pick the option that fits/ })).toBeInTheDocument();
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('About you');
  });

  it('unknown wizard step redirects to the first', () => {
    at('/start/nope');
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('About you');
  });

  it('trust page lists the verification story', async () => {
    at('/trust');
    expect(await screen.findByRole('heading', { level: 1, name: /What is verified/ })).toBeInTheDocument();
    for (const h of ['Proved in Lean', 'Tested, not proved', 'Trusted base', 'Not covered', 'Bugs we found in the IRS reference implementation']) {
      expect(screen.getByRole('heading', { level: 2, name: h })).toBeInTheDocument();
    }
    expect(screen.getByText('refund_balanceDue_consistent')).toBeInTheDocument();
    expect(screen.getByText('eitc_within_bounds')).toBeInTheDocument();
    expect(screen.getByText('DF-BUG-8')).toBeInTheDocument();
    expect(screen.getByText(/tested, not proved/)).toBeInTheDocument();
  });

  it('unknown route shows a 404 page', () => {
    at('/zzz');
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Page not found');
  });
});

describe('results (mock mode, $50,000 single)', () => {
  it('shows the refund hero and the line walk from the fixture', async () => {
    const d = draftFromRequest(EXAMPLES.refund);
    d.primary.dob = '1985-06-15';
    d.healthScreening = { marketplace: false, hsaWithdrawals: false };
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(d));
    at('/results');
    const summary = await screen.findByRole('region', { name: 'Your refund' });
    expect(summary.querySelector('.result-amount')).toHaveTextContent('$981.00');
    const table = screen.getByRole('table', { name: /Form 1040, line by line/ });
    expect(within(table).getByRole('row', { name: /15 Taxable income/ })).toHaveTextContent('$35,400.00');
  });
});

describe('results without answers', () => {
  it('sends a first-time visitor back to the start of the wizard', async () => {
    at('/results');
    expect(await screen.findByRole('heading', { level: 1, name: 'About you' })).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Your refund' })).not.toBeInTheDocument();
  });
});

describe('unsupported page (mock mode)', () => {
  it('explains the knockout reasons without raw errors', async () => {
    at('/cant-do-yet');
    expect(await screen.findByRole('heading', { level: 1 })).toHaveTextContent(/can’t be calculated yet/);
    expect(screen.getByRole('heading', { name: 'What US Tax can calculate' })).toBeInTheDocument();
    expect(screen.getByRole('row', { name: 'Interest and investments' })).toBeInTheDocument();
  });
});
