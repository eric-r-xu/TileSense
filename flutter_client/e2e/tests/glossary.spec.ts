import { expect, test } from '@playwright/test';
import { byId, openApp } from '../helpers';

test('glossary opens and accepts a search', async ({ page }) => {
  await openApp(page);
  await byId(page, 'glossaryLink').click();
  await expect(byId(page, 'glossarySearch')).toBeAttached();
  await byId(page, 'glossarySearch').click();
  // Flutter mirrors the focused text field into a real <input>; typing before
  // it has focus drops the first keystrokes.
  const input = page.locator('input[data-semantics-role="text-field"]');
  await expect(input).toBeFocused();
  await page.keyboard.type('chow');
  await expect(input).toHaveValue('chow');
});
