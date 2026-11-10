import { defineConfig, devices } from '@playwright/test'

// E2E_PORT_OFFSET in e2e/run.mjs moves it when another worktree uses 4183.
const PORT = Number(process.env.PW_PORT ?? 4183)

export default defineConfig({
  testDir: 'e2e',
  testIgnore: process.env.E2E_PERF ? undefined : ['perf/**'],
  // PRs that don't touch styles skip the dark-theme axe pass (E2E_SKIP_DARK_AXE
  // from webapp_check.yml); the light pass and dark-mode behavior tests still run.
  grepInvert: process.env.E2E_SKIP_DARK_AXE ? /axe.*(tema escuro|\(dark\))/ : undefined,
  // A test makes several 15 s waits (expect below): 30 s cut slow-but-right runs.
  timeout: process.env.E2E_PERF ? 180_000 : 60_000,
  // 3 workers next to the emulators: Firestore listeners can take over 8 s,
  // on the CI runner (#552) and on a busy laptop running the whole suite.
  expect: { timeout: 15_000 },
  fullyParallel: !process.env.E2E_PERF,
  // PW_WORKERS sets it; 2 by default on a dev machine shared with other runs, 3 on CI.
  workers: process.env.E2E_PERF ? 1 : Number(process.env.PW_WORKERS) || (process.env.CI ? 3 : 2),
  retries: 0,
  forbidOnly: !!process.env.CI,
  reporter: [['list']],
  use: {
    ...devices['Desktop Chrome'],
    baseURL: `http://127.0.0.1:${PORT}/web/`,
    locale: 'pt-BR',
    timezoneId: 'America/Sao_Paulo',
    trace: 'retain-on-failure',
  },
  webServer: {
    command: `node e2e/serve.mjs ${PORT}`,
    url: `http://127.0.0.1:${PORT}/web/`,
    reuseExistingServer: false,
  },
})
