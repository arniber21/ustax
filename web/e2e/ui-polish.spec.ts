import { expect, test } from '@playwright/test';
import { addW2, chooseStatus, typeDate } from './helpers';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => localStorage.clear());
  await page.reload();
});

test('minimal shell has one Docs entry, a useful footer, and no mobile overflow', async ({ page }) => {
  const mainNav = page.getByRole('navigation', { name: 'Main', exact: true });
  await expect(mainNav.getByRole('link', { name: 'Docs', exact: true })).toHaveCount(1);
  await expect(mainNav.getByRole('link', { name: 'Verification', exact: true })).toHaveCount(0);
  const footer = page.getByRole('navigation', { name: 'Footer' });
  await expect(footer.getByRole('link', { name: 'API', exact: true })).toBeVisible();
  await page.screenshot({ path: '/tmp/ustax-ui-home-desktop.png', fullPage: true, animations: 'disabled' });
  await page.setViewportSize({ width: 390, height: 844 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth - innerWidth)).toBeLessThanOrEqual(1);
  await page.screenshot({ path: '/tmp/ustax-ui-home-mobile.png', fullPage: false, animations: 'disabled' });
  await page.getByRole('button', { name: 'Menu', exact: true }).click();
  const menu = page.getByRole('dialog');
  await expect(menu.getByRole('link', { name: 'Docs', exact: true })).toBeVisible();
  await menu.getByRole('link', { name: 'Docs', exact: true }).click();
  await expect(page).toHaveURL(/\/docs$/);
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await page.getByRole('navigation', { name: 'Documentation', exact: true }).getByRole('link', { name: 'Verification', exact: true }).click();
  await expect(page).toHaveURL(/\/docs\/verification$/);
  await expect(page.getByRole('heading', { name: 'What is verified, and what is not' })).toBeVisible();
});

test('Base UI clear dialog traps focus, cancels safely, then clears persisted answers', async ({ page }) => {
  await page.goto('/start/about');
  await chooseStatus(page, 'Single');
  await typeDate(page, 'Your date of birth', '06/15/1985');
  await page.goto('/start/income');
  await addW2(page, '50000', '5000');
  const trigger = page.getByRole('button', { name: 'Clear return', exact: true });
  await trigger.click();
  const dialog = page.getByRole('alertdialog', { name: 'Clear this return?' });
  const keep = dialog.getByRole('button', { name: 'Keep my return', exact: true });
  const clear = dialog.getByRole('button', { name: 'Clear return', exact: true });
  await expect(keep).toBeFocused();
  await page.keyboard.press('Shift+Tab');
  await expect(clear).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(keep).toBeFocused();
  await page.keyboard.press('Escape');
  await expect(dialog).toHaveCount(0);
  await expect(trigger).toBeFocused();
  await expect(page.getByLabel(/Box 1: wages/)).toHaveValue('50,000.00');
  await trigger.click();
  await page.screenshot({ path: '/tmp/ustax-ui-clear-dialog.png' });
  await page.evaluate(() => { document.documentElement.dataset.theme = 'dark'; });
  const contrast = await clear.evaluate((el) => {
    const style = getComputedStyle(el);
    const luminance = (color: string) => {
      const channels = color.match(/[\d.]+/g)!.slice(0, 3).map(Number).map((n) => n / 255)
        .map((n) => n <= 0.04045 ? n / 12.92 : ((n + 0.055) / 1.055) ** 2.4);
      return channels[0]! * 0.2126 + channels[1]! * 0.7152 + channels[2]! * 0.0722;
    };
    const fg = luminance(style.color);
    const bg = luminance(style.backgroundColor);
    return (Math.max(fg, bg) + 0.05) / (Math.min(fg, bg) + 0.05);
  });
  expect(contrast).toBeGreaterThanOrEqual(4.5);
  await page.screenshot({ path: '/tmp/ustax-ui-clear-dialog-dark.png' });
  await clear.click();
  await expect(page).toHaveURL(/\/start\/about$/);
  await expect(page.getByLabel('Your date of birth', { exact: true })).toHaveValue('');
  await expect(trigger).toBeDisabled();
  await page.reload();
  await expect(page.getByLabel('Your date of birth', { exact: true })).toHaveValue('');
  expect(await page.evaluate(() => JSON.parse(localStorage.getItem('ustax.draft.v1')!).w2s)).toEqual([]);
});

test('legacy verification URLs redirect into Docs with their section intact', async ({ page }) => {
  await page.goto('/trust#trusted');
  await expect(page).toHaveURL(/\/docs\/verification#trusted$/);
  await expect(page.getByRole('heading', { name: 'Trusted base', exact: true })).toBeVisible();
});

test('Base UI selection indicators stay centered with pointer and keyboard input', async ({ page }) => {
  await page.goto('/start/about');
  await chooseStatus(page, 'Head of household');
  const student = page.getByRole('checkbox', { name: /full-time student in 2024/ });
  await student.click();
  const controls = page.locator('[data-slot="radio-group-item"][data-checked], [data-slot="checkbox"][data-checked]');
  expect(await controls.count()).toBeGreaterThanOrEqual(3);
  const offsets = await controls.evaluateAll((items) => items.map((item) => {
    const root = item.getBoundingClientRect();
    const mark = item.querySelector('[data-slot$="indicator"] > *')!.getBoundingClientRect();
    return { x: Math.abs((root.left + root.width / 2) - (mark.left + mark.width / 2)),
      y: Math.abs((root.top + root.height / 2) - (mark.top + mark.height / 2)) };
  }));
  for (const offset of offsets) {
    expect(offset.x, 'indicator horizontal centering').toBeLessThanOrEqual(0.5);
    expect(offset.y, 'indicator vertical centering').toBeLessThanOrEqual(0.5);
  }
  await page.locator('[data-path="filingStatus"]').screenshot({ path: '/tmp/ustax-ui-filing-status.png', animations: 'disabled' });
  await page.getByRole('region', { name: 'You', exact: true }).screenshot({ path: '/tmp/ustax-ui-checkboxes.png', animations: 'disabled' });
  await student.focus();
  await page.keyboard.press('Space');
  await expect(student).not.toBeChecked();
  await page.getByRole('radio', { name: /^Head of household/ }).focus();
  await page.keyboard.press('ArrowUp');
  await expect(page.getByRole('radio', { name: /^Married, filing separately/ })).toBeChecked();
});
