import { expect, type Locator, type Page } from '@playwright/test';

/** Type a date into the date picker input of a field (MM/DD/YYYY). */
export async function typeDate(page: Page, label: string | RegExp, value: string) {
  const input = page.getByLabel(label, { exact: typeof label === 'string' });
  await input.fill(value);
  await input.blur();
}

/** Pick a filing status card by its title (the radio itself is visually hidden, so click its label). */
export async function chooseStatus(page: Page, title: string) {
  await page.locator('label').filter({ has: page.getByText(title, { exact: true }) }).click();
  await expect(page.getByRole('radio', { name: new RegExp(`^${title}`) })).toBeChecked();
}

/** The "Next: X" button of the wizard footer. */
export function nextButton(page: Page, label?: string) {
  return page.getByRole('button', { name: new RegExp(`^Next${label ? `: ${label}` : ''}`) });
}

export async function next(page: Page, label: string) {
  await nextButton(page, label).click();
}

/** Yes/No radio inside a group whose accessible name matches. */
export async function answer(page: Page, group: RegExp, yes = true) {
  await page.getByRole('group', { name: group }).locator('label').filter({ hasText: new RegExp(`^${yes ? 'Yes' : 'No'}$`) }).click();
}

/** Steps 1 to 3 and the W-2 on step 4 for a return with one W-2; leaves the page on Adjustments. */
export async function addW2(page: Page, wages: string, withheld: string) {
  await page.getByRole('button', { name: /^Add a W-2$/ }).click();
  const w2 = page.getByRole('region', { name: 'W-2 1' });
  await w2.getByLabel(/Box 1: wages/).fill(wages);
  await w2.getByLabel(/Box 2: federal income tax withheld/).fill(withheld);
}

/** Click "Calculate my return" on the Review step. */
export async function calculate(page: Page) {
  await page.getByRole('button', { name: /Calculate my return/ }).click();
}

/** The Form 1040 line table row with this line number, as `[description, amount]`. */
export function lineRow(page: Page, line: string): Locator {
  return page.getByRole('row').filter({ has: page.getByRole('cell', { name: line, exact: true }) });
}

export async function expectLine(page: Page, line: string, amount: string) {
  await expect(lineRow(page, line).getByRole('cell').last()).toHaveText(amount);
}
