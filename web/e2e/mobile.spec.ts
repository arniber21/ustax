import { expect, test } from '@playwright/test';
import { addW2, answer, calculate, chooseStatus, next, typeDate } from './helpers';

/** Mobile smoke (Pixel 7 viewport): the whole path works and nothing scrolls sideways. */
test('mobile: single filer, $50,000 wages -> $981 refund, no horizontal overflow', async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => window.localStorage.clear());
  await page.goto('/start/about');
  await chooseStatus(page, 'Single');
  await typeDate(page, 'Your date of birth', '06/15/1985');
  await next(page, 'Your household');
  await next(page, 'Dependents');
  await answer(page, /Do you have children or other people you support/, false);
  await next(page, 'Income');
  await addW2(page, '50000', '5000');
  await next(page, 'Adjustments and payments');
  await next(page, 'Credits and care costs');
  await answer(page, /Marketplace health insurance/, false);
  await answer(page, /HSA withdrawals, rollovers/, false);
  await next(page, 'Review');
  await calculate(page);
  await expect(page.getByRole('region', { name: 'Your refund' })).toContainText('$981');
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  expect(overflow).toBeLessThanOrEqual(1);
  await page.goto('/trust');
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(1);
});
