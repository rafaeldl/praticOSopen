import { defineConfig, devices } from '@playwright/test'

// E2E_PORT_OFFSET in e2e/run.mjs moves it when another worktree uses 4183.
const PORT = Number(process.env.PW_PORT ?? 4183)

export default defineConfig({
  testDir: 'e2e',
  testIgnore: process.env.E2E_PERF ? undefined : ['perf/**'],
  timeout: process.env.E2E_PERF ? 180_000 : 30_000,
  expect: { timeout: 8_000 },
  fullyParallel: !process.env.E2E_PERF,
  workers: process.env.E2E_PERF ? 1 : 3,
  retries: 0,
  forbidOnly: !!process.env.CI,
  reporter: [['list']],
  use: {
    ...devices['Desktop Chrome'],
    baseURL: `http://127.0.0.1:${PORT}/app/`,
    locale: 'pt-BR',
    timezoneId: 'America/Sao_Paulo',
    trace: 'retain-on-failure',
  },
  webServer: {
    command: `node e2e/serve.mjs ${PORT}`,
    url: `http://127.0.0.1:${PORT}/app/`,
    reuseExistingServer: false,
  },
})
