import { beforeEach, describe, expect, it } from 'vitest';
import { render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { App } from '../App';
import { contractProblems } from '../api';
import { STORAGE_KEY, buildRequest, emptyDraft, loadDraft, newW2, useDraft, type Draft } from '../draft';

const seed = (d: Partial<Draft>) => window.localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...emptyDraft(), ...d }));
const at = (path: string) =>
  render(
    <MemoryRouter initialEntries={[path]}>
      <App />
    </MemoryRouter>,
  );
const saved = () => loadDraft(window.localStorage);
const next = (label: string) => userEvent.click(screen.getByRole('button', { name: new RegExp(`Next: ${label}`) }));

beforeEach(() => window.localStorage.clear());

describe('About step', () => {
  it('lists every filing status with an explanation and saves the pick', async () => {
    at('/start/about');
    for (const name of ['Single', 'Married, filing together', 'Married, filing separately', 'Head of household', 'Qualifying surviving spouse']) {
      expect(screen.getByRole('radio', { name: new RegExp(name) })).toBeInTheDocument();
    }
    await userEvent.click(screen.getByRole('radio', { name: /Head of household/ }));
    expect(saved().filingStatus).toBe('HeadOfHousehold');
  });

  it('records age, blindness and dependent flags', async () => {
    at('/start/about');
    await userEvent.click(screen.getByRole('checkbox', { name: /65 or older/ }));
    await userEvent.click(screen.getByRole('checkbox', { name: /I am blind/ }));
    expect(saved().primary).toEqual({ age65: true, blind: true, canBeClaimed: false });
  });

  it('warns about the surviving spouse rules', async () => {
    at('/start/about');
    await userEvent.click(screen.getByRole('radio', { name: /Qualifying surviving spouse/ }));
    expect(screen.getByText(/Double-check this one/)).toBeInTheDocument();
  });

  it('restores a saved draft after a reload', () => {
    seed({ filingStatus: 'MarriedFilingJointly' });
    at('/start/about');
    expect(screen.getByRole('radio', { name: /Married, filing together/ })).toBeChecked();
  });
});

describe('Household step', () => {
  it('shows spouse questions only for joint returns', () => {
    seed({ filingStatus: 'Single' });
    const { unmount } = at('/start/household');
    expect(screen.queryByText('Your spouse')).not.toBeInTheDocument();
    unmount();
    seed({ filingStatus: 'MarriedFilingJointly' });
    at('/start/household');
    expect(screen.getByRole('heading', { name: 'Your spouse' })).toBeInTheDocument();
  });

  it('asks about the surviving-spouse year only after saying yes', async () => {
    seed({ filingStatus: 'MarriedFilingJointly' });
    at('/start/household');
    expect(screen.queryByText(/turned 65/)).not.toBeInTheDocument();
    await userEvent.click(within(screen.getByRole('group', { name: /pass away in 2024/ })).getByRole('radio', { name: 'Yes' }));
    expect(screen.getByText(/turned 65/)).toBeInTheDocument();
    expect(saved().spouseDiedThisYear).toBe(true);
  });

  it('is honest that dependents are not in the math yet', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/household');
    await userEvent.click(within(screen.getByRole('group', { name: /child or another relative/ })).getByRole('radio', { name: 'Yes' }));
    expect(screen.getByText(/Dependents aren’t in our math yet/)).toBeInTheDocument();
  });
});

describe('Income step', () => {
  it('adds, fills, and removes multiple W-2s', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/income');
    await userEvent.click(screen.getByRole('button', { name: 'Add a W-2' }));
    await userEvent.click(screen.getByRole('button', { name: 'Add another W-2' }));
    const first = screen.getByRole('region', { name: 'W-2 1' });
    const second = screen.getByRole('region', { name: 'W-2 2' });
    await userEvent.type(within(first).getByLabelText(/^Box 1:/), '50000');
    await userEvent.type(within(first).getByLabelText(/^Box 2:/), '5000');
    await userEvent.type(within(second).getByLabelText(/^Box 1:/), '1,000.50');
    expect(saved().w2s.map((w) => [w.wages, w.withholding])).toEqual([
      [5000000, 500000],
      [100050, null],
    ]);
    expect(screen.getByText('$51,000.50')).toBeInTheDocument(); // running total
    await userEvent.click(screen.getByRole('button', { name: 'Remove W-2 1' }));
    expect(saved().w2s).toHaveLength(1);
    expect(saved().w2s[0]!.wages).toBe(100050);
  });

  it('picks a box 12 code and keeps it in the request', async () => {
    seed({ filingStatus: 'Single', w2s: [{ ...newW2(), wages: 5000000 }] });
    at('/start/income');
    await userEvent.click(screen.getByRole('button', { name: 'Add a box 12 entry' }));
    const row = screen.getByRole('group', { name: 'Box 12 entry 1' });
    await userEvent.selectOptions(within(row).getByLabelText('Code'), 'D');
    await userEvent.type(within(row).getByLabelText('Amount'), '6000');
    const req = buildRequest(saved());
    expect(req.w2s?.[0]?.box12).toEqual({ D: 600000 });
    expect(contractProblems('CalculateRequest', req)).toEqual([]);
  });

  it('offers the spouse as the owner of a form only on joint returns', async () => {
    seed({ filingStatus: 'MarriedFilingJointly', w2s: [{ ...newW2(), wages: 100 }] });
    at('/start/income');
    await userEvent.selectOptions(screen.getByLabelText('Whose form is this?'), 'SecondaryFiler');
    expect(saved().w2s[0]!.filer).toBe('SecondaryFiler');
  });

  it('does not offer a spouse on a single return', () => {
    seed({ filingStatus: 'Single', w2s: [{ ...newW2(), wages: 100 }] });
    at('/start/income');
    expect(screen.queryByLabelText('Whose form is this?')).not.toBeInTheDocument();
  });

  it('collects 1099-INT, 1099-G, 1099-R and SSA-1099', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/income');
    await userEvent.click(screen.getByRole('button', { name: 'Add a 1099-INT' }));
    await userEvent.type(screen.getByLabelText(/Box 1: interest income/), '1000');
    await userEvent.click(screen.getByRole('button', { name: 'Add a 1099-G' }));
    await userEvent.type(screen.getByLabelText(/Box 1: unemployment/), '2000');
    await userEvent.click(screen.getByRole('button', { name: 'Add a 1099-R' }));
    await userEvent.click(screen.getByRole('checkbox', { name: /^7: Normal/ }));
    await userEvent.type(screen.getByLabelText(/Box 1: gross/), '3000');
    await userEvent.type(screen.getByLabelText(/^Box 2a:/), '2500');
    await userEvent.click(screen.getByRole('button', { name: 'Add a SSA-1099' }));
    await userEvent.type(screen.getByLabelText(/Box 5/), '-100');
    const req = buildRequest(saved());
    expect(req.interest_reports?.[0]?.interest_income).toBe(100000);
    expect(req.form_1099g?.[0]?.unemployment_compensation).toBe(200000);
    expect(req.form_1099r?.[0]).toMatchObject({ distribution_code: ['7'], gross_distribution: 300000, taxable_amount: 250000 });
    expect(req.social_security?.net_benefits).toEqual([-10000]);
    expect(contractProblems('CalculateRequest', req)).toEqual([]);
  });

  it('stops Next with plain-language errors, then lets you through', async () => {
    seed({ filingStatus: 'Single', w2s: [newW2()] });
    at('/start/income');
    await next('Adjustments');
    expect(screen.getByRole('alert')).toHaveTextContent(/Box 1 is the heart/);
    await userEvent.type(screen.getByLabelText(/^Box 1:/), '0');
    await next('Adjustments');
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Adjustments and payments');
  });

  it('caps each list at the contract limit', () => {
    seed({ filingStatus: 'Single', ssa: Array.from({ length: 4 }, (_, n) => ({ id: `s${n}`, netBenefits: 1 })) });
    at('/start/income');
    expect(screen.getByRole('button', { name: 'Add another SSA-1099' })).toBeDisabled();
  });

  it('explains where to find a box as visible help text tied to the field', () => {
    seed({ filingStatus: 'Single', w2s: [newW2()] });
    at('/start/income');
    const wages = screen.getByLabelText(/^Box 1:/);
    expect(wages).toHaveAccessibleDescription(/Where to find it: Box 1 is the first dollar box/);
    expect(screen.queryByRole('tooltip')).toBeNull();
  });

  it('error summary links jump to the field', async () => {
    seed({ filingStatus: 'Single', w2s: [newW2()] });
    at('/start/income');
    await next('Adjustments');
    const summary = screen.getByRole('group', { name: 'There is a problem' });
    await userEvent.click(within(summary).getByRole('link', { name: /Box 1 is the heart/ }));
    expect(screen.getByLabelText(/^Box 1:/)).toHaveFocus();
  });
});

describe('Adjustments step', () => {
  it('reveals follow-ups only after yes', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/adjustments');
    expect(screen.queryByLabelText(/How much did you spend/)).not.toBeInTheDocument();
    await userEvent.click(within(screen.getByRole('group', { name: /K-12 teacher/ })).getByRole('radio', { name: 'Yes' }));
    await userEvent.type(screen.getByLabelText(/How much did you spend/), '250');
    expect(buildRequest(saved()).adjustments?.educator_expenses).toEqual({ was_k12_educators: 'TpDid', primary_expenses: 25000 });
  });

  it('asks about a teacher spouse only on joint returns', () => {
    seed({ filingStatus: 'Single' });
    const { unmount } = at('/start/adjustments');
    expect(screen.queryByText(/Is your spouse a K-12/)).not.toBeInTheDocument();
    unmount();
    seed({ filingStatus: 'MarriedFilingJointly' });
    at('/start/adjustments');
    expect(screen.getByText(/Is your spouse a K-12/)).toBeInTheDocument();
  });

  it('collects student loan interest and estimated payments', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/adjustments');
    await userEvent.click(within(screen.getByRole('group', { name: /interest on a student loan/ })).getByRole('radio', { name: 'Yes' }));
    await userEvent.click(screen.getByRole('checkbox', { name: /college costs/ }));
    await userEvent.type(screen.getByLabelText('Interest you paid'), '1200');
    await userEvent.click(within(screen.getByRole('group', { name: /send the IRS any tax payments/ })).getByRole('radio', { name: 'Yes' }));
    await userEvent.type(screen.getByLabelText('Total you paid'), '4000');
    const req = buildRequest(saved());
    expect(req.adjustments?.student_loan_interest).toEqual({ had_payments: true, loans_qualify: true, interest_amount: 120000 });
    expect(req.estimated_payments).toEqual({ paid_estimated_taxes_or_from_last_year: true, amount: 400000 });
  });

  it('requires the amount once you say yes', async () => {
    seed({ filingStatus: 'Single', estimated: { paid: true, amount: null, differentName: false } });
    at('/start/adjustments');
    await next('Review');
    expect(screen.getByRole('alert')).toHaveTextContent(/How much did you pay/);
  });
});

describe('Review step', () => {
  it('summarises the draft with edit links', () => {
    seed({
      filingStatus: 'Single',
      w2s: [{ ...newW2(), wages: 5000000, withholding: 500000 }],
      studentLoan: { hadPayments: true, loansQualify: true, interest: 120000 },
    });
    at('/start/review');
    expect(screen.getByText('Single')).toBeInTheDocument();
    expect(screen.getByText('$50,000 wages, $5,000 withheld')).toBeInTheDocument();
    expect(screen.getByText('$1,200')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Edit Income' })).toHaveAttribute('href', '/start/income');
    expect(screen.getByRole('link', { name: 'Edit About you' })).toHaveAttribute('href', '/start/about');
    expect(screen.queryByText(/need your attention/)).not.toBeInTheDocument();
  });

  it('flags missing answers with a link to fix them', () => {
    at('/start/review');
    expect(screen.getByText(/need your attention/)).toBeInTheDocument();
  });

  it('sends you to the first problem instead of the results', async () => {
    seed({ filingStatus: 'Single', w2s: [newW2()] });
    at('/start/review');
    await userEvent.click(screen.getByRole('button', { name: /Calculate my return/ }));
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Income');
  });

  it('start over clears the draft', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/review');
    await userEvent.click(screen.getByRole('button', { name: 'Start over' }));
    expect(saved().filingStatus).toBeNull();
  });
});

describe('useDraft', () => {
  it('throws a clear error without a provider', () => {
    function Probe() {
      useDraft();
      return null;
    }
    expect(() => render(<Probe />)).toThrow(/DraftProvider/);
  });
});
