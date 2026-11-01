import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { App, preloadRoutes } from '../App';
import { emptyDraft, loadDraft, newW2, STORAGE_KEY } from '../draft';

beforeAll(preloadRoutes);
beforeEach(() => window.localStorage.clear());
const start = () => render(<MemoryRouter initialEntries={['/']}><App /></MemoryRouter>);
const seed = () => {
  const d = emptyDraft();
  d.filingStatus = 'Single';
  d.primary.dob = '1985-06-15';
  d.w2s = [{ ...newW2(), wages: 5_000_000 }];
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(d));
};

describe('minimal navigation and clear return', () => {
  it('uses one Docs entry in the header and a labelled footer', () => {
    start();
    const nav = screen.getByRole('navigation', { name: 'Main' });
    expect(within(nav).getAllByRole('link', { name: 'Docs' })).toHaveLength(1);
    expect(within(nav).queryByRole('link', { name: 'Verification' })).toBeNull();
    expect(within(screen.getByRole('navigation', { name: 'Footer' })).getByRole('link', { name: 'Verification' }))
      .toHaveAttribute('href', '/docs/verification');
    expect(screen.getByRole('button', { name: 'Clear return' })).toBeDisabled();
  });

  it('focuses the safe choice and restores the trigger on Escape without losing answers', async () => {
    seed();
    start();
    const trigger = screen.getByRole('button', { name: 'Clear return' });
    await userEvent.click(trigger);
    const dialog = screen.getByRole('alertdialog', { name: 'Clear this return?' });
    expect(dialog).toHaveAccessibleDescription(/removes all saved answers/i);
    await waitFor(() => expect(within(dialog).getByRole('button', { name: 'Keep my return' })).toHaveFocus());
    await userEvent.keyboard('{Escape}');
    await waitFor(() => expect(screen.queryByRole('alertdialog')).toBeNull());
    expect(trigger).toHaveFocus();
    expect(loadDraft().w2s).toHaveLength(1);
  });

  it('clears persisted answers only after confirmation and starts an empty return', async () => {
    seed();
    start();
    await userEvent.click(screen.getByRole('button', { name: 'Clear return' }));
    const dialog = screen.getByRole('alertdialog');
    await userEvent.click(within(dialog).getByRole('button', { name: 'Clear return' }));
    expect(loadDraft()).toEqual(emptyDraft());
    expect(screen.getByRole('heading', { name: 'About you' })).toBeInTheDocument();
    expect(screen.queryByRole('alertdialog')).toBeNull();
    expect(screen.getByRole('button', { name: 'Clear return' })).toBeDisabled();
  });
});
