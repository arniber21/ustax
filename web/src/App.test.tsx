import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { App } from './App';
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
    expect(screen.getByRole('link', { name: 'Let’s start' })).toHaveAttribute('href', '/start/about');
  });

  it('wizard walks through all five steps', async () => {
    at('/start/about');
    await userEvent.click(screen.getByRole('radio', { name: /^Single/ }));
    const titles = [/who’s in your household/, /What money came in/, /shrinks your bill/, /what you told us/];
    const labels = ['Household', 'Income', 'Adjustments & credits', 'Review'];
    for (const [n, label] of labels.entries()) {
      await userEvent.click(screen.getByRole('button', { name: new RegExp(`Next: ${label}`) }));
      expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(titles[n]!);
    }
    expect(screen.getByRole('button', { name: /See my result/ })).toBeInTheDocument();
  });

  it('Next waits for a filing status and says why', async () => {
    at('/start/about');
    await userEvent.click(screen.getByRole('button', { name: /Next: Household/ }));
    expect(screen.getByRole('alert')).toHaveTextContent(/Pick the option that fits/);
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(/how will you be filing/);
  });

  it('unknown wizard step redirects to the first', () => {
    at('/start/nope');
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(/how will you be filing/);
  });

  it('trust page lists the verification story', () => {
    at('/trust');
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(/on faith/);
    expect(screen.getByText('What we do not verify')).toBeInTheDocument();
  });

  it('unknown route shows a friendly 404', () => {
    at('/zzz');
    expect(screen.getByText(/wandered off/)).toBeInTheDocument();
  });
});

describe('results (mock mode, $50,000 single)', () => {
  it('shows the refund hero and the line walk from the fixture', async () => {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(draftFromRequest(EXAMPLES.refund)));
    at('/results');
    expect(await screen.findByText(/Your refund is/)).toBeInTheDocument();
    expect(screen.getByRole('img', { name: '$981.00' })).toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: 'Walk me through it' }));
    expect(screen.getByText('$35,400.00')).toBeInTheDocument(); // taxable income
  });
});

describe('results without answers', () => {
  it('sends a first-time visitor back to the start of the wizard', () => {
    at('/results');
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(/./);
    expect(screen.queryByText(/Your refund is/)).not.toBeInTheDocument();
  });
});

describe('unsupported page (mock mode)', () => {
  it('explains the knockout reasons without raw errors', async () => {
    at('/cant-do-yet');
    expect(await screen.findByRole('heading', { level: 1 })).toHaveTextContent(/beyond what we can do/);
    expect(screen.getByText('What we can do')).toBeInTheDocument();
    expect(screen.getByText('Interest and investments')).toBeInTheDocument();
  });
});
