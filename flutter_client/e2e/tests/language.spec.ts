import { expect, test } from '@playwright/test';
import { byId, openApp } from '../helpers';

test('switching language relabels the welcome screen', async ({ page }) => {
  await openApp(page);
  const before = await byId(page, 'glossaryLink').innerText();
  await byId(page, 'languageButton').click();
  // Menu items are CheckedPopupMenuItems; pick the first non-checked one.
  await page.getByRole('menuitemcheckbox', { checked: false }).first().click();
  await expect(byId(page, 'glossaryLink')).not.toHaveText(before);
});
