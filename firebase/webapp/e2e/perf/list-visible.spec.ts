// Time until the order list shows, on Fast 4G with CPU 4x, like ADR-001.
// Run with npm run e2e:perf (10 thousand orders in the seed). Prints the p75 of
// every startup step, so a regression shows where the time went.
import { expect, test, type BrowserContext, type Page } from '@playwright/test'
import { login } from '../helpers'

const RUNS = Number(process.env.PERF_RUNS ?? 7)
/** ADR-001 goal for a first visit. */
const GOAL_FIRST_VISIT_MS = Number(process.env.PERF_GOAL_MS ?? 1500)
const STEPS = ['responseEnd', 'session:auth', 'session:token', 'orders:query', 'session:docs', 'list-visible'] as const

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

async function measure(page: Page): Promise<Record<string, number>> {
  await page.goto('orders')
  await expect(page.getByTestId('orders-table')).toBeVisible({ timeout: 30_000 })
  await page.waitForFunction(() => performance.getEntriesByName('list-visible').length > 0)
  return page.evaluate((steps) => {
    const result: Record<string, number> = {}
    const navigation = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming | undefined
    for (const step of steps) {
      result[step] = step === 'responseEnd' ? (navigation?.responseEnd ?? -1) : (performance.getEntriesByName(step)[0]?.startTime ?? -1)
    }
    return result
  }, STEPS as unknown as string[])
}

const p75 = (values: number[]) => [...values].sort((a, b) => a - b)[Math.ceil(values.length * 0.75) - 1] as number
const summary = (runs: Record<string, number>[]) =>
  Object.fromEntries(STEPS.map((step) => [step, Math.round(p75(runs.map((run) => run[step] as number)))]))

test('lista visível em Fast 4G + CPU 4x', async ({ browser }) => {
  const setup = await browser.newContext()
  // Perf runs without the Functions emulator (10 thousand triggers would skew the
  // numbers), so the access list answer is the remembered "yes" every allowed
  // person has after the first visit.
  await setup.addInitScript(() => localStorage.setItem('praticos.webAccess.e2e-admin', String(Date.now())))
  const setupPage = await setup.newPage()
  await login(setupPage, 'admin', 'orders')
  await expect(setupPage.getByTestId('orders-table')).toBeVisible()
  const state = await setup.storageState()
  await setup.close()

  const first: Record<string, number>[] = []
  const back: Record<string, number>[] = []
  for (let run = 0; run < RUNS; run++) {
    // A new context has empty HTTP and Firestore caches: a first visit with a saved login.
    const context = await browser.newContext({ storageState: state })
    const page = await context.newPage()
    await throttle(context, page)
    first.push(await measure(page))
    back.push(await measure(page))
    await context.close()
  }

  const result = { firstVisit: summary(first), returnVisit: summary(back) }
  console.log(`list-visible p75 (ms): ${JSON.stringify(result)}; meta ${GOAL_FIRST_VISIT_MS} ms`)
  expect(result.firstVisit['list-visible']).toBeLessThanOrEqual(GOAL_FIRST_VISIT_MS)
})
