import { defineConfig, devices } from '@playwright/test';

const PORT = 4173;

// The app is a fixed 1600x820 canvas behind a landscape gate, so pin the
// viewport to it. Build first: `npm run build` (flutter build web).
export default defineConfig({
  testDir: './tests',
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['html', { open: 'never' }], ['list']] : 'list',
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    viewport: { width: 1600, height: 820 },
    locale: 'en-US',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'], viewport: { width: 1600, height: 820 } } }],
  webServer: {
    command: `npx serve ../build/web -l ${PORT} --no-clipboard`,
    url: `http://127.0.0.1:${PORT}`,
    reuseExistingServer: !process.env.CI,
  },
});
