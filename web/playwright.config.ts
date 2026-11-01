import { defineConfig, devices } from '@playwright/test';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

/**
 * End-to-end tests against the REAL stack: the compiled Lean server (`ustax-server`) and the Vite dev
 * server. Playwright starts both and stops both (webServer), so nothing is left running.
 *
 * Environment (all optional):
 *   E2E_API_PORT      Lean server port (default 8190)
 *   E2E_WEB_PORT      Vite port (default 5190)
 *   USTAX_SERVER_BIN  path to the ustax-server binary (default ../lean/.lake/build/bin/ustax-server)
 *   E2E_CHANNEL       browser channel, e.g. `chrome` to use the installed Google Chrome instead of the
 *                     Playwright Chromium (`npx playwright install chromium`)
 */
const apiPort = process.env.E2E_API_PORT ?? '8190';
const webPort = process.env.E2E_WEB_PORT ?? '5190';
const apiUrl = `http://localhost:${apiPort}`;
const webUrl = `http://localhost:${webPort}`;
const serverBin = resolve(process.env.USTAX_SERVER_BIN ?? '../lean/.lake/build/bin/ustax-server');
const channel = process.env.E2E_CHANNEL || undefined;

if (!existsSync(serverBin)) {
  throw new Error(`ustax-server not found at ${serverBin}. Run \`make e2e\` (builds it) or set USTAX_SERVER_BIN.`);
}

export default defineConfig({
  testDir: './e2e',
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list']],
  use: { baseURL: webUrl, channel, actionTimeout: 10_000, trace: 'retain-on-failure', screenshot: 'only-on-failure' },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], channel, viewport: { width: 1280, height: 900 } }, testIgnore: /mobile\.spec\.ts/ },
    { name: 'mobile', use: { ...devices['Pixel 7'], channel }, testMatch: /mobile\.spec\.ts/ },
  ],
  webServer: [
    {
      command: serverBin,
      env: { PORT: apiPort, ALLOW_ORIGIN: webUrl },
      url: `${apiUrl}/health`,
      reuseExistingServer: false,
      timeout: 30_000,
    },
    {
      command: `node scripts/sync-provenance.mjs && npx vite --port ${webPort} --strictPort`,
      env: { VITE_API_URL: apiUrl },
      url: webUrl,
      reuseExistingServer: false,
      timeout: 60_000,
    },
  ],
});
