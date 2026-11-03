// npm run lhci: Lighthouse on the login screen of dist-e2e, with Playwright's
// Chromium, so CI and every machine measure with the same browser.
import { spawnSync } from 'node:child_process'
import { existsSync } from 'node:fs'
import { resolve } from 'node:path'
import { chromium } from '@playwright/test'

const webapp = resolve(import.meta.dirname, '..')
if (!existsSync(resolve(webapp, 'dist-e2e/index.html'))) {
  console.error('Rode antes: npm run build:e2e')
  process.exit(1)
}
const result = spawnSync('npx', ['lhci', 'autorun', '--config=lighthouserc.json'], {
  cwd: webapp,
  stdio: 'inherit',
  env: { ...process.env, CHROME_PATH: chromium.executablePath() },
})
process.exit(result.status ?? 1)
