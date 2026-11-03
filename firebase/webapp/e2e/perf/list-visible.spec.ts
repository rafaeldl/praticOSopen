// Time until the order list shows, on Fast 4G with CPU 4x, like ADR-001.
// Run with npm run e2e:perf (10 thousand orders in the seed).
import { expect, test, type BrowserContext, type Page } from '@playwright/test'
import { login } from '../helpers'

const RUNS = 7
/** ADR-001: 1,5 s is the goal; the prototype measured 1.690 ms on a first visit. */
const GOAL_FIRST_VISIT_MS = 1500
/** A number above this means something broke, not a slow day. */
const FAIL_FIRST_VISIT_MS = 4000

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
  return cdp
}

async function measure(page: Page): Promise<number> {
  await page.goto('orders')
  await expect(page.getByTestId('orders-table')).toBeVisible({ timeout: 30_000 })
  await page.waitForFunction(() => performance.getEntriesByName('list-visible').length > 0)
  return page.evaluate(() => performance.getEntriesByName('list-visible')[0]?.startTime ?? -1)
}

const p75 = (values: number[]) => [...values].sort((a, b) => a - b)[Math.ceil(values.length * 0.75) - 1] as number

test('lista visível em Fast 4G + CPU 4x', async ({ browser }) => {
  const login_ = await browser.newContext()
  const loginPage = await login_.newPage()
  await login(loginPage, 'admin', 'orders')
  await expect(loginPage.getByTestId('orders-table')).toBeVisible()
  const rows = await loginPage.getByTestId('orders-table').locator('tbody tr').count()
  const state = await login_.storageState()
  await login_.close()

  const first: number[] = []
  const repeat: number[] = []
  for (let run = 0; run < RUNS; run++) {
    const context = await browser.newContext({ storageState: state })
    const page = await context.newPage()
    await throttle(context, page)
    first.push(await measure(page))
    repeat.push(await measure(page))
    await context.close()
  }

  const result = { rows, firstVisitP75: Math.round(p75(first)), returnP75: Math.round(p75(repeat)), first, repeat }
  console.log(`list-visible: ${JSON.stringify(result)}, meta 1ª visita ${GOAL_FIRST_VISIT_MS} ms`)
  expect(result.firstVisitP75).toBeLessThan(FAIL_FIRST_VISIT_MS)
})
