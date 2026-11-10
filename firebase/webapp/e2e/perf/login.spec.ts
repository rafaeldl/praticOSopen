// Time from "Entrar" to the order list, on Fast 4G with CPU 4x, like list-visible.
// A first sign-in in this browser: no Firestore cache and no remembered access
// answer, so the start asks GET /v1/app/web-access (Functions emulator on).
// The provider's own page is not timed: e-mail sign-in is the same path that
// follows Google or Apple answering (hydrate, access, company, list).
// PERF_LOGIN=1 npm run e2e:perf:login
import { expect, test, type BrowserContext, type Page } from '../test'
import { PASSWORD, USERS } from '../fixtures.mjs'

test.skip(!process.env.PERF_LOGIN, 'só com PERF_LOGIN=1')
const RUNS = Number(process.env.PERF_RUNS ?? 5)
const GOAL_MS = 3000
/**
 * PERF_COLD_API_MS: the API starts from zero, like Cloud Run after a quiet
 * while (4 to 8 s in the logs of 2026-11-04). Every call waits until the
 * instance that the first call woke is up. PERF_AWAY_MS: time between opening
 * the login and the account answering (Google or Apple page, or typing).
 */
const COLD_API_MS = Number(process.env.PERF_COLD_API_MS ?? 0)
const AWAY_MS = Number(process.env.PERF_AWAY_MS ?? 0)
const STEPS = ['login:auth', 'session:token', 'session:docs', 'session:access', 'login:hydrated', 'login:enter', 'orders:query', 'list-visible'] as const

async function throttle(context: BrowserContext, page: Page) {
  const cdp = await context.newCDPSession(page)
  await cdp.send('Network.enable')
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false,
    latency: 165,
    downloadThroughput: (9 * 1024 * 1024) / 8,
    uploadThroughput: (1.5 * 1024 * 1024) / 8,
  })
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 })
}

const p75 = (values: number[]) => [...values].sort((a, b) => a - b)[Math.ceil(values.length * 0.75) - 1] as number

test('do "Entrar" à lista, primeira entrada no navegador', async ({ browser }) => {
  test.setTimeout(RUNS * 60_000)
  const runs: Record<string, number>[] = []
  const calls: number[] = []
  for (let run = 0; run < RUNS; run++) {
    const context = await browser.newContext()
    await context.addInitScript(() => localStorage.setItem('praticos.languageChosen', '1'))
    const page = await context.newPage()
    let access = 0
    page.on('request', (request) => {
      if (request.url().includes('/v1/app/web-access')) access++
    })
    if (COLD_API_MS) {
      let upAt = 0
      await page.route(/\/v1\/app\//, async (route) => {
        upAt ||= Date.now() + COLD_API_MS
        await new Promise((done) => setTimeout(done, Math.max(0, upAt - Date.now())))
        await route.continue()
      })
    }
    await throttle(context, page)
    await page.goto('login')
    if (AWAY_MS) await page.waitForTimeout(AWAY_MS)
    await page.getByRole('button', { name: 'Já tenho conta com e-mail' }).click()
    await page.getByLabel('E-mail').fill(USERS.admin.email)
    await page.getByLabel('Senha').fill(PASSWORD)
    await page.getByRole('button', { name: 'Entrar', exact: true }).click()
    await expect(page.getByTestId('orders-table')).toBeVisible({ timeout: 30_000 })
    await page.waitForFunction(() => performance.getEntriesByName('list-visible').length > 0)
    runs.push(
      await page.evaluate((steps) => {
        const start = performance.getEntriesByName('login:start')[0]?.startTime ?? 0
        return Object.fromEntries(steps.map((step) => [step, Math.round((performance.getEntriesByName(step)[0]?.startTime ?? start - 1) - start)]))
      }, STEPS as unknown as string[]),
    )
    calls.push(access)
    await context.close()
  }
  const summary = Object.fromEntries(STEPS.map((step) => [step, p75(runs.map((r) => r[step] as number))]))
  console.log(`LOGIN p75 (ms desde o clique): ${JSON.stringify(summary)}; web-access chamadas: ${JSON.stringify(calls)}`)
  expect(summary['list-visible']).toBeLessThanOrEqual(GOAL_MS)
})
