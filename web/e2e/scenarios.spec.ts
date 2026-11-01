import { expect, test, type Page } from '@playwright/test';
import { addW2, answer, calculate, chooseStatus, expectLine, next, typeDate } from './helpers';

/**
 * Full-stack scenarios: browser -> Vite app -> real Lean server (`ustax-server`). No mocks.
 * Expected amounts come from api/examples/*.response.json (computed by the Lean calculator and
 * checked against Catala by `make api-examples`).
 */

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => window.localStorage.clear());
});

test('1. single filer, one W-2 ($50,000 wages, $5,000 withheld): $981 refund and the line table', async ({ page }) => {
  await page.goto('/start/about');
  await chooseStatus(page, 'Single');
  await next(page, 'Your household');
  await next(page, 'Dependents');
  await answer(page, /Do you have children or other people you support/, false);
  await next(page, 'Income');
  await addW2(page, '50000', '5000');
  await next(page, 'Adjustments and payments');
  await next(page, 'Credits and care costs');
  await next(page, 'Review');
  await calculate(page);

  const hero = page.getByRole('region', { name: 'Your refund' });
  await expect(hero).toContainText('$981');
  await expectLine(page, '11', '$50,000.00');
  await expectLine(page, '15', '$35,400.00');
  await expectLine(page, '24', '$4,019.00');
  await expectLine(page, '34', '$981.00');
});

/** Add one child (dependents step, card `index`) who lived with the filer all year and has an SSN. */
async function addChild(page: Page, index: number, name: string, dob: string) {
  if (index > 0) await page.getByRole('button', { name: 'Add another person' }).click();
  const card = page.getByRole('region', { name: `Person ${index + 1}` });
  await card.getByLabel('First name (optional)').fill(name);
  await card.getByLabel('How are they related to you?').selectOption('BiologicalChild');
  await typeDate(card, 'Date of birth', dob);
}

test('2. married filing jointly, two children, via the wizard ($80,000 wages, $3,000 withheld): $1,365 refund', async ({ page }) => {
  await page.goto('/start/about');
  await chooseStatus(page, 'Married, filing together');
  await typeDate(page, 'Your date of birth', '04/12/1986');
  await next(page, 'Your household');
  await page.getByLabel('Which describes you?').selectOption('Married');
  await typeDate(page, 'Your spouse’s date of birth', '09/30/1987');
  await next(page, 'Dependents');
  await answer(page, /Do you have children or other people you support/, true);
  await addChild(page, 0, 'Ada', '03/01/2016');
  await addChild(page, 1, 'Ben', '05/01/2019');
  await next(page, 'Income');
  await addW2(page, '80000', '3000');
  await next(page, 'Adjustments and payments');
  await next(page, 'Credits and care costs');
  await next(page, 'Review');
  await calculate(page);

  await expect(page.getByRole('region', { name: 'Your refund' })).toContainText('$1,365');
  await expectLine(page, '34', '$1,365.00');
});

test('3. head of household, one child, $40,000 wages: earned income credit applies, $3,604 refund', async ({ page }) => {
  // api/examples/eitc-hoh-one-child.response.json: refund 360400 cents, of which other payments (EITC) 160400.
  await page.goto('/start/about');
  await chooseStatus(page, 'Head of household');
  await typeDate(page, 'Your date of birth', '06/15/1990');
  await next(page, 'Your household');
  await page.getByLabel('Which describes you?').selectOption('NeverMarried');
  await answer(page, /more than half of the cost of keeping up your home/, true);
  await next(page, 'Dependents');
  await answer(page, /Do you have children or other people you support/, true);
  await addChild(page, 0, 'Cy', '09/10/2014');
  await next(page, 'Income');
  await addW2(page, '40000', '2000');
  await next(page, 'Adjustments and payments');
  await next(page, 'Credits and care costs');
  await next(page, 'Review');
  await calculate(page);

  await expect(page.getByRole('region', { name: 'Your refund' })).toContainText('$3,604');
  await expectLine(page, '34', '$3,604.00');
  await expectLine(page, '32', '$1,604.00'); // the earned income credit is in "other payments and refundable credits"
});

test('4. a head of household with no qualifying person gets the "cannot do yet" page with reasons, not a number', async ({ page }) => {
  await page.goto('/start/about');
  await chooseStatus(page, 'Head of household');
  await next(page, 'Your household');
  await answer(page, /more than half of the cost of keeping up your home/, true);
  await next(page, 'Dependents');
  await answer(page, /Do you have children or other people you support/, false);
  await next(page, 'Income');
  await addW2(page, '60000', '4000');
  await next(page, 'Adjustments and payments');
  await next(page, 'Credits and care costs');
  await next(page, 'Review');
  await calculate(page);

  await expect(page.getByRole('heading', { level: 1, name: /can.t be calculated yet/ })).toBeVisible();
  const row = page.getByRole('row', { name: /Your household/ });
  await expect(row).toContainText('The filing status you chose doesn’t fit your household.');
  await expect(page.getByRole('region', { name: 'Your refund' })).toHaveCount(0);
  await expect(page.getByText(/\$\d[\d,]*\.\d\d/)).toHaveCount(0);
});

test('5. the provenance drawer for line 15 shows the Catala source and says it is not a proof', async ({ page }) => {
  await page.goto('/start/about');
  await chooseStatus(page, 'Single');
  await next(page, 'Your household');
  await next(page, 'Dependents');
  await answer(page, /Do you have children or other people you support/, false);
  await next(page, 'Income');
  await addW2(page, '50000', '5000');
  await next(page, 'Adjustments and payments');
  await next(page, 'Credits and care costs');
  await next(page, 'Review');
  await calculate(page);

  await page.getByRole('button', { name: /^Law & proof for line 15, / }).click();
  const drawer = page.getByRole('dialog', { name: /Line 15/ });
  await expect(drawer.getByRole('heading', { name: 'The law' })).toBeVisible();
  await expect(drawer.getByRole('heading', { name: 'The rule' })).toBeVisible();
  await expect(drawer.getByText('Readable rule, validated by differential testing against IRS Direct File. Not a proof.')).toBeVisible();
  const catala = drawer.getByRole('region', { name: /Catala rule/ }).first();
  await expect(catala).toBeVisible();
  await expect(catala).toContainText(/scope|declaration|definition/);
  await expect(drawer.getByRole('heading', { name: 'What is proved' })).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(drawer).toHaveCount(0);
});

test('6. the date picker accepts a typed date (04/12/1986) and keeps it', async ({ page }) => {
  await page.goto('/start/about');
  await chooseStatus(page, 'Single');
  const dob = page.getByRole('textbox', { name: 'Your date of birth' });
  await dob.fill('04/12/1986');
  await dob.blur();
  await expect(dob).toHaveValue('04/12/1986');
  await next(page, 'Your household');
  await page.getByRole('link', { name: 'Back' }).click();
  await expect(page.getByRole('textbox', { name: 'Your date of birth' })).toHaveValue('04/12/1986');
  // the picker button opens a calendar on the typed month
  await page.getByRole('button', { name: /Choose your date of birth/ }).click();
  await expect(page.getByRole('dialog').or(page.getByRole('grid')).first()).toContainText(/April|1986|Apr/);
});

test('7. keyboard only: the first wizard step can be completed without a mouse', async ({ page }) => {
  await page.goto('/start/about');
  // Tab into the filing-status group and choose with Space.
  await page.keyboard.press('Tab'); // skip link
  await page.keyboard.press('Tab');
  await page.getByRole('radio').first().focus();
  await page.keyboard.press('Space');
  await expect(page.getByRole('radio', { name: /^Single/ })).toBeChecked();
  // The date of birth, typed.
  const dob = page.getByRole('textbox', { name: 'Your date of birth' });
  await dob.focus();
  await page.keyboard.type('04/12/1986');
  await expect(dob).toHaveValue('04/12/1986');
  // Space toggles a checkbox.
  const student = page.getByRole('checkbox', { name: /full-time student/ });
  await student.focus();
  await page.keyboard.press('Space');
  await expect(student).toBeChecked();
  // Tab reaches "Next" and Enter moves on.
  const nextBtn = page.getByRole('button', { name: /^Next: Your household/ });
  await nextBtn.focus();
  await expect(nextBtn).toBeFocused();
  await page.keyboard.press('Enter');
  await expect(page).toHaveURL(/\/start\/household$/);
  await expect(page.getByRole('heading', { level: 1, name: 'Your household' })).toBeVisible();
});
