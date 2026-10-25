import { expect, test } from '@playwright/test';
import { byId, openApp } from '../helpers';

for (const viewport of [{ width: 1600, height: 820 }, { width: 844, height: 390 }]) {
  test(`native rules search and return at ${viewport.width}px`, async ({ page }, testInfo) => {
    await page.setViewportSize(viewport);
    await openApp(page);
    await byId(page, 'rulesTile').click();
    await page.getByRole('button', { name: 'Read rules', exact: true }).first().click();
    await expect(byId(page, 'rulesSearch')).toBeAttached();
    await expect(page.getByText('Tiles and the goal', { exact: true })).toBeAttached();
    await page.screenshot({ path: testInfo.outputPath('rules-reader.png') });
    await byId(page, 'rulesSearch').click();
    const input = page.locator('input[data-semantics-role="text-field"]');
    await expect(input).toBeFocused();
    // Focus first lands on Flutter's semantics placeholder. Wait for the
    // editing input (TextField's default autocorrect setting) before typing.
    await expect(input).toHaveAttribute('autocorrect', 'on');
    await input.fill('furiten');
    await expect(input).toHaveValue('furiten');
    await page.screenshot({ path: testInfo.outputPath('rules-search.png') });
    await expect(page.getByText('Winning: yaku and furiten', { exact: true })).toBeAttached();
    await expect(page.getByText('Tiles and the goal', { exact: true })).toHaveCount(0);
    await page.getByRole('button', { name: 'Clear search', exact: true }).click();
    await expect(page.getByText('Tiles and the goal', { exact: true })).toBeAttached();
    await page.getByRole('button', { name: 'Back', exact: true }).click();
    await expect(byId(page, 'rulesSearch')).toHaveCount(0);
    await expect(page.getByRole('button', { name: 'Riichi rules (PDF)', exact: true })).toBeAttached();
  });
}
