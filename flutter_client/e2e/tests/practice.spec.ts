import { expect, test } from '@playwright/test';
import { byId, openApp } from '../helpers';

// One per drill kind: discard (practiceTile_i), winning tile (practiceOption_*)
// and claim (practiceClaim_*).
const ANSWER = [
  '[flt-semantics-identifier^="practiceTile_"]',
  '[flt-semantics-identifier^="practiceOption_"]',
  '[flt-semantics-identifier^="practiceClaim_"]',
].join(', ');

test('practice hands: pick an answer, see a verdict, move on', async ({ page }) => {
  await openApp(page);
  await byId(page, 'practiceLink').click();

  const answers = page.locator(ANSWER);
  await expect(answers.first()).toBeAttached();
  await expect(byId(page, 'practiceVerdict')).toHaveCount(0);

  await answers.first().click();
  await expect(byId(page, 'practiceVerdict')).toBeAttached();

  // Moving on clears the verdict and shows the next question's answers.
  await byId(page, 'practiceNext').click();
  await expect(byId(page, 'practiceVerdict')).toHaveCount(0);
  await expect(answers.first()).toBeAttached();
});
