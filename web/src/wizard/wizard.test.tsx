import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { fireEvent, render, screen, within } from '@testing-library/react';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { App, preloadRoutes } from '../App';

beforeAll(preloadRoutes);
import { contractProblems } from '../api/validate';
import { STORAGE_KEY, buildRequest, emptyDraft, emptyFlags, loadDraft, newDependent, newW2, useDraft, type Draft } from '../draft';

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
    expect(saved().primary).toMatchObject({ age65: true, blind: true, canBeClaimed: false });
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

  it('asks the marital and home questions that credits need', async () => {
    seed({ filingStatus: 'HeadOfHousehold' });
    at('/start/household');
    await userEvent.selectOptions(screen.getByLabelText('Which describes you?'), 'Divorced');
    await userEvent.click(within(screen.getByRole('group', { name: /more than half of the cost of keeping up your home/ })).getByRole('radio', { name: 'Yes' }));
    expect(saved()).toMatchObject({ maritalStatus: 'Divorced', paidHomeUpkeep: true });
    expect(screen.queryByLabelText('Did you live with your spouse in 2024?')).not.toBeInTheDocument();
  });

  it('asks married people filing separately whether they lived together', async () => {
    seed({ filingStatus: 'MarriedFilingSeparately' });
    at('/start/household');
    await userEvent.selectOptions(screen.getByLabelText('Did you live with your spouse in 2024?'), 'LivedApartAllYear');
    expect(buildRequest(saved()).filing_answers).toEqual({ spouse_lived_together_months: 'LivedApartAllYear' });
  });

  it('takes the spouse’s date of birth and hides the 65 box once it is known', async () => {
    seed({ filingStatus: 'MarriedFilingJointly' });
    at('/start/household');
    expect(screen.getByRole('checkbox', { name: 'My spouse is 65 or older' })).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText('Your spouse’s date of birth'), { target: { value: '09/30/1987' } });
    expect(screen.queryByRole('checkbox', { name: 'My spouse is 65 or older' })).not.toBeInTheDocument();
    expect(buildRequest(saved()).filers).toEqual({ secondary: { date_of_birth: '1987-09-30' } });
  });

  it('rejects a spouse date of birth after the tax year', async () => {
    seed({ filingStatus: 'MarriedFilingJointly', spouse: { ...emptyFlags(), dob: '2025-02-01' } });
    at('/start/household');
    await next('Dependents');
    expect(screen.getByRole('alert')).toHaveTextContent(/cannot be after December 31, 2024/);
  });

  it('records the screening answers and warns about digital assets', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/household');
    await userEvent.click(within(screen.getByRole('group', { name: /sell, trade or otherwise dispose/ })).getByRole('radio', { name: 'Yes' }));
    expect(screen.getByText(/may not be able to finish your return/)).toBeInTheDocument();
    expect(buildRequest(saved()).screening).toEqual({ disposed_digital_assets: true });
  });
});

describe('About step details', () => {
  it('collects date of birth, citizenship and the rest, and sends them', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/about');
    fireEvent.change(screen.getByLabelText('Your date of birth'), { target: { value: '06/15/1990' } });
    // shadcn/ui Select: open the listbox, pick the option.
    await userEvent.click(screen.getByRole('combobox', { name: 'Your citizenship' }));
    await userEvent.click(await screen.findByRole('option', { name: /I was a resident alien all of 2024/ }));
    await userEvent.click(screen.getByRole('checkbox', { name: /I have a Social Security number/ }));
    await userEvent.click(screen.getByRole('checkbox', { name: /full-time student/ }));
    expect(screen.queryByRole('checkbox', { name: /I am 65 or older/ })).not.toBeInTheDocument();
    expect(buildRequest(saved()).filers).toEqual({
      primary: { date_of_birth: '1990-06-15', is_us_citizen_full_year: false, noncitizen_resident_full_year: true, is_student: true, tin: { tin_is_ssn: false } },
    });
  });
});

/** `2014-09-10` -> `09/10/2014`, the way people type a date into the date picker. */
const usDate = (iso: string) => `${iso.slice(5, 7)}/${iso.slice(8)}/${iso.slice(0, 4)}`;

describe('Dependents step', () => {
  const add = async (rel: string, dob: string, index = 0) => {
    const card = screen.getAllByRole('region', { name: /^Person \d/ })[index]!;
    await userEvent.selectOptions(within(card).getByLabelText('How are they related to you?'), rel);
    fireEvent.change(within(card).getByLabelText('Date of birth'), { target: { value: usDate(dob) } });
    return card;
  };

  it('starts with a gate and shows no cards until you say yes', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/dependents');
    expect(screen.queryByRole('region', { name: /^Person/ })).not.toBeInTheDocument();
    await userEvent.click(within(screen.getByRole('group', { name: /children or other people you support/ })).getByRole('radio', { name: 'Yes' }));
    expect(screen.getByRole('region', { name: 'Person 1' })).toBeInTheDocument();
    expect(saved().hasDependents).toBe(true);
  });

  it('adds, fills and removes people, and builds the contract shape', async () => {
    seed({ filingStatus: 'HeadOfHousehold', paidHomeUpkeep: true });
    at('/start/dependents');
    await userEvent.click(within(screen.getByRole('group', { name: /children or other people you support/ })).getByRole('radio', { name: 'Yes' }));
    await add('BiologicalChild', '2014-09-10');
    await userEvent.click(screen.getByRole('button', { name: 'Add another person' }));
    expect(screen.getByRole('region', { name: 'Person 2' })).toBeInTheDocument();
    await add('Parent', '1950-01-01', 1);
    const second = screen.getByRole('region', { name: 'Person 2' });
    await userEvent.selectOptions(within(second).getByLabelText('How long did they live with you in 2024?'), 'SixToElevenMonths');
    await userEvent.selectOptions(within(second).getByLabelText('How many months?'), '9');
    await userEvent.click(within(second).getByRole('checkbox', { name: /I paid for more than half/ }));
    expect(buildRequest(saved()).dependents).toEqual([
      { relationship: 'BiologicalChild', date_of_birth: '2014-09-10', tin_type: 'Ssn', tp_paid_most_of_home_upkeep: true },
      {
        relationship: 'Parent', date_of_birth: '1950-01-01', tin_type: 'Ssn', residency_duration: 'SixToElevenMonths',
        months_lived_with_tp_in_us: 9, qr_support_test: true, tp_paid_most_of_home_upkeep: true,
      },
    ]);
    expect(contractProblems('CalculateRequest', buildRequest(saved()))).toEqual([]);

    await userEvent.click(screen.getByRole('button', { name: 'Remove Person 1' }));
    expect(saved().dependents).toHaveLength(1);
    expect(saved().dependents[0]?.relationship).toBe('Parent');
  });

  it('names are kept on screen and never sent', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/dependents');
    await userEvent.click(within(screen.getByRole('group', { name: /children or other people you support/ })).getByRole('radio', { name: 'Yes' }));
    await userEvent.type(screen.getByLabelText('First name (optional)'), 'Maya');
    await add('BiologicalChild', '2019-05-01');
    expect(saved().dependents[0]?.name).toBe('Maya');
    expect(JSON.stringify(buildRequest(saved()))).not.toContain('Maya');
  });

  it('needs a relationship and date of birth before moving on', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/dependents');
    await userEvent.click(within(screen.getByRole('group', { name: /children or other people you support/ })).getByRole('radio', { name: 'Yes' }));
    await next('Income');
    const summary = screen.getByRole('group', { name: 'There are 2 problems' });
    expect(within(summary).getByRole('link', { name: /related to you/ })).toBeInTheDocument();
    expect(within(summary).getByRole('link', { name: /date of birth/ })).toBeInTheDocument();
    expect(screen.getAllByRole('alert').length).toBeGreaterThan(0);
  });

  it('every control in a card has an accessible name', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/dependents');
    await userEvent.click(within(screen.getByRole('group', { name: /children or other people you support/ })).getByRole('radio', { name: 'Yes' }));
    const card = screen.getByRole('region', { name: 'Person 1' });
    for (const el of within(card).getAllByRole('combobox')) expect(el).toHaveAccessibleName();
    for (const el of within(card).getAllByRole('checkbox')) expect(el).toHaveAccessibleName();
    for (const el of within(card).getAllByRole('textbox')) expect(el).toHaveAccessibleName();
    expect(within(card).getByRole('button', { name: 'Remove Person 1' })).toBeInTheDocument();
  });

  it('answering No hides the list but keeps nothing in the request', async () => {
    seed({ filingStatus: 'Single', hasDependents: true, dependents: [{ ...newDependent(), relationship: 'BiologicalChild', dob: '2018-01-01' }] });
    at('/start/dependents');
    await userEvent.click(within(screen.getByRole('group', { name: /children or other people you support/ })).getByRole('radio', { name: 'No' }));
    expect(screen.queryByRole('region', { name: /^Person/ })).not.toBeInTheDocument();
    expect(buildRequest(saved()).dependents).toBeUndefined();
  });

  it('the family flow builds exactly api/examples/family-mfj-two-kids', async () => {
    const family = JSON.parse(readFileSync(join(__dirname, '../../../api/examples/family-mfj-two-kids.request.json'), 'utf8'));
    seed({
      filingStatus: 'MarriedFilingJointly',
      w2s: [{ ...newW2(), wages: 8000000, withholding: 300000 }],
    });
    at('/start/about');
    fireEvent.change(screen.getByLabelText('Your date of birth'), { target: { value: '04/12/1986' } });
    await next('Your household');
    await userEvent.selectOptions(screen.getByLabelText('Which describes you?'), 'Married');
    fireEvent.change(screen.getByLabelText('Your spouse’s date of birth'), { target: { value: '09/30/1987' } });
    await next('Dependents');
    await userEvent.click(within(screen.getByRole('group', { name: /children or other people you support/ })).getByRole('radio', { name: 'Yes' }));
    await add('BiologicalChild', '2016-03-01');
    await userEvent.click(screen.getByRole('button', { name: 'Add another person' }));
    await add('BiologicalChild', '2019-05-01', 1);
    expect(buildRequest(saved())).toEqual(family);
    await next('Income');
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Income');
  });
});

describe('Credits step', () => {
  const kid = { ...newDependent(), name: 'Maya', relationship: 'BiologicalChild' as const, dob: '2019-05-01' };

  it('refuses unsupported health coverage instead of showing a result', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/credits');
    await userEvent.click(within(screen.getByRole('group', { name: /Marketplace health insurance/ })).getByRole('radio', { name: 'Yes' }));
    expect(screen.getByText('This return can’t be calculated in this wizard')).toBeInTheDocument();
    expect(saved().healthScreening.marketplace).toBe(true);
    await next('Review');
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Credits and care costs');
  });

  it('collects care costs per person, then asks who provided the care', async () => {
    seed({ filingStatus: 'Single', hasDependents: true, dependents: [kid] });
    at('/start/credits');
    await userEvent.click(within(screen.getByRole('group', { name: /pay someone to care for a child under 13/ })).getByRole('radio', { name: 'Yes' }));
    await userEvent.type(screen.getByLabelText('What did you pay to care for Maya?'), '2500');
    await userEvent.click(screen.getByRole('radio', { name: /Someone else/ }));
    expect(buildRequest(saved()).dependents?.[0]?.cdcc).toEqual({
      has_dependent_care_expenses: true, expenses_paid_to_qualifying_provider: true, writable_qualifying_expense_amount: 250000,
    });
  });

  it('will not continue with care costs but no answer about the provider', async () => {
    seed({ filingStatus: 'Single', hasDependents: true, dependents: [{ ...kid, careExpenses: 100000 }], cdcc: { paid: true, totalQualified: null } });
    at('/start/credits');
    await next('Review');
    expect(screen.getAllByRole('alert')[0]).toHaveTextContent(/person who provided the care/);
  });

  it('sends you to the dependents step when there is nobody to attach care costs to', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/credits');
    await userEvent.click(within(screen.getByRole('group', { name: /pay someone to care for a child under 13/ })).getByRole('radio', { name: 'Yes' }));
    expect(screen.getByRole('link', { name: 'Dependents step' })).toHaveAttribute('href', '/start/dependents');
  });

  it('collects HSA answers for each spouse on a joint return', async () => {
    seed({ filingStatus: 'MarriedFilingJointly' });
    at('/start/credits');
    await userEvent.click(within(screen.getByRole('group', { name: /HSA activity that is not on a W-2/ })).getByRole('radio', { name: 'Yes' }));
    await userEvent.click(within(screen.getByRole('group', { name: /Did you put money into an HSA directly/ })).getByRole('radio', { name: 'Yes' }));
    await userEvent.selectOptions(screen.getByLabelText('Your high-deductible health plan in 2024'), 'HdhpAllYear');
    await userEvent.type(screen.getByLabelText('Total you put in directly'), '1500');
    await userEvent.click(within(screen.getByRole('group', { name: /Did your spouse put money into an HSA/ })).getByRole('radio', { name: 'Yes' }));
    const req = buildRequest(saved());
    expect(req.adjustments?.hsa).toEqual({
      some_filer_had_non_w2_hsa_activity: true,
      writable_primary_filer_had_non_w2_hsa_activity: true,
      writable_secondary_filer_had_non_w2_hsa_activity: true,
    });
    expect(req.filers?.primary?.hsa).toMatchObject({ hsa_hdhp_coverage_status: 'HdhpAllYear', writable_hsa_nonemployer_contributions_tax_year: 150000 });
    expect(req.filers?.secondary?.hsa).toEqual({ writable_secondary_filer_has_made_contributions_to_hsa: true });
    expect(contractProblems('CalculateRequest', req)).toEqual([]);
  });

  it('records the credit screening answers', async () => {
    seed({ filingStatus: 'Single' });
    at('/start/credits');
    await userEvent.click(screen.getByRole('checkbox', { name: /disallowed my earned income credit/ }));
    expect(buildRequest(saved()).credits).toEqual({ eitc_had_improper_claims: true });
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
    // Combobox: open it, type to filter, pick.
    await userEvent.click(within(row).getByRole('combobox', { name: 'Code' }));
    await userEvent.type(await screen.findByRole('combobox', { name: 'Search code' }, { timeout: 5000 }), '401');
    await userEvent.click(await screen.findByRole('option', { name: /^D: 401\(k\)/ }));
    expect(within(row).getByRole('combobox', { name: 'Code' })).toHaveTextContent('D: 401(k) contributions');
    await userEvent.type(within(row).getByLabelText('Amount'), '6000');
    const req = buildRequest(saved());
    expect(req.w2s?.[0]?.box12).toEqual({ D: 600000 });
    expect(contractProblems('CalculateRequest', req)).toEqual([]);
  });

  it('offers the spouse as the owner of a form only on joint returns', async () => {
    seed({ filingStatus: 'MarriedFilingJointly', w2s: [{ ...newW2(), wages: 100 }] });
    at('/start/income');
    await userEvent.click(within(screen.getByRole('group', { name: 'Whose form is this?' })).getByRole('radio', { name: 'My spouse’s' }));
    expect(saved().w2s[0]!.filer).toBe('SecondaryFiler');
  });

  it('does not offer a spouse on a single return', () => {
    seed({ filingStatus: 'Single', w2s: [{ ...newW2(), wages: 100 }] });
    at('/start/income');
    expect(screen.queryByRole('group', { name: 'Whose form is this?' })).not.toBeInTheDocument();
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
    seed({ filingStatus: 'Single', primary: { ...emptyFlags(), dob: '1985-06-15' }, w2s: [newW2()] });
    at('/start/income');
    await next('Adjustments');
    expect(screen.getByRole('alert')).toHaveTextContent(/Box 1 is the heart/);
    await userEvent.type(screen.getByLabelText(/^Box 1:/), '0');
    await next('Adjustments');
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Adjustments and payments');
  });

  it('caps each list at the contract limit', () => {
    seed({ filingStatus: 'Single', ssa: Array.from({ length: 4 }, (_, n) => ({ id: `s${n}`, netBenefits: 1, withheld: null })) });
    at('/start/income');
    expect(screen.getByRole('button', { name: 'Add another SSA-1099' })).toBeDisabled();
  });

  it('explains where to find a box as visible help text tied to the field', () => {
    seed({ filingStatus: 'Single', primary: { ...emptyFlags(), dob: '1985-06-15' }, w2s: [newW2()] });
    at('/start/income');
    const wages = screen.getByLabelText(/^Box 1:/);
    expect(wages).toHaveAccessibleDescription(/Where to find it: Box 1 is the first dollar box/);
    expect(screen.queryByRole('tooltip')).toBeNull();
  });

  it('error summary links jump to the field', async () => {
    seed({ filingStatus: 'Single', primary: { ...emptyFlags(), dob: '1985-06-15' }, w2s: [newW2()] });
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
    await next('Credits and care costs');
    expect(screen.getByRole('alert')).toHaveTextContent(/How much did you pay/);
  });
});

describe('Review step', () => {
  it('summarises the draft with edit links', () => {
    seed({
      filingStatus: 'Single',
      primary: { ...emptyFlags(), dob: '1985-06-15' },
      healthScreening: { marketplace: false, hsaWithdrawals: false },
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

  it('lists dependents and credits answers', () => {
    seed({
      filingStatus: 'Single',
      hasDependents: true,
      dependents: [{ ...newDependent(), name: 'Maya', relationship: 'BiologicalChild', dob: '2019-05-01', careExpenses: 250000, careProviderQualifies: true }],
      cdcc: { paid: true, totalQualified: null },
    });
    at('/start/review');
    expect(screen.getByRole('region', { name: 'Dependents' })).toHaveTextContent('MayaSon or daughter, born 2019-05-01');
    expect(screen.getByRole('link', { name: 'Edit Dependents' })).toHaveAttribute('href', '/start/dependents');
    expect(screen.getByRole('region', { name: 'Credits and care costs' })).toHaveTextContent('$2,500');
    expect(screen.getAllByText('Not answered')).toHaveLength(2);
  });

  it('flags missing answers with a link to fix them', () => {
    at('/start/review');
    expect(screen.getByText(/need your attention/)).toBeInTheDocument();
  });

  it('sends you to the first problem instead of the results', async () => {
    seed({ filingStatus: 'Single', primary: { ...emptyFlags(), dob: '1985-06-15' }, w2s: [newW2()] });
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
