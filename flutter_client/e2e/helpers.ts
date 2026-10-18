import { expect, type Locator, type Page } from '@playwright/test';

/** Flutter's semantics identifier, set by `e2eId` in lib/ui/e2e_id.dart. */
export const byId = (page: Page, id: string): Locator =>
  page.locator(`[flt-semantics-identifier="${id}"]`);

/**
 * Loads the app, waits for the first frame, then turns on Flutter's semantics
 * tree (CanvasKit has no per-widget DOM until it is enabled).
 */
export async function openApp(page: Page): Promise<void> {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto('/');
  await expect(page.locator('#ts-loading')).toHaveCount(0, { timeout: 60_000 });
  // The placeholder is visually hidden, so dispatch the click directly.
  await page.locator('flt-semantics-placeholder').dispatchEvent('click');
  await expect(page.locator('flt-semantics').first()).toBeAttached();
  expect(errors).toEqual([]);
}
