import { beforeAll, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { App } from './App';

// Unit tests run the typed client against the api/fixtures mock, same as VITE_API_MOCK=1.
beforeAll(() => vi.stubEnv('VITE_API_MOCK', '1'));

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
    for (const label of ['Household', 'Income', 'Adjustments & credits', 'Review']) {
      await userEvent.click(screen.getByRole('link', { name: new RegExp(`Next: ${label}`) }));
      expect(screen.getByRole('heading', { level: 1, name: label })).toBeInTheDocument();
    }
    expect(screen.getByRole('link', { name: /See my result/ })).toHaveAttribute('href', '/results');
  });

  it('unknown wizard step redirects to the first', () => {
    at('/start/nope');
    expect(screen.getByRole('heading', { level: 1, name: 'About you' })).toBeInTheDocument();
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
  it('shows the refund hero from the fixture', async () => {
    at('/results');
    expect(await screen.findByText(/Your refund is/)).toBeInTheDocument();
    expect(screen.getByText('$981', { exact: false })).toBeInTheDocument();
    expect(screen.getByText('$35,400')).toBeInTheDocument(); // taxable income
  });

  it('switches to the balance-due example', async () => {
    at('/results');
    await screen.findByText(/Your refund is/);
    await userEvent.click(screen.getByRole('button', { name: '$3,000 withheld' }));
    expect(await screen.findByText(/You’ll owe/)).toBeInTheDocument();
    expect(screen.getByText('$1,019', { exact: false })).toBeInTheDocument();
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
