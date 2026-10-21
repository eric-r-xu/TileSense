import { expect, test } from '@playwright/test';
import { byId, openApp } from '../helpers';

test('boots to the welcome screen', async ({ page }) => {
  await openApp(page);
  await expect(page.locator('flutter-view, flt-glass-pane').first()).toBeAttached();
  await expect(byId(page, 'learnTile')).toBeAttached();
  await expect(byId(page, 'rulesTile')).toBeAttached();
  await byId(page, 'learnTile').click();
  await expect(byId(page, 'glossaryLink')).toBeAttached();
  await expect(byId(page, 'practiceLink')).toBeAttached();
});
