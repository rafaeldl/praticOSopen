// Analytics of the web (auth.analytics.events, nav.tabs.analytics-names,
// order.ai.funnel, share.analytics). The e2e build never talks to Google: a spy
// (lib/analytics.ts) takes the events, and only the tests that ask for it
// (praticos.analyticsE2E) see the notice. Checks the app's names, that nothing
// leaves before "Aceitar" or after "Recusar", and that no name, phone or e-mail goes.
import { expect, test, type Page } from '@playwright/test'
import { makeCustomer, makeOrder } from './data'
import { USERS } from './fixtures.mjs'
import { expectNoAxeViolations, login } from './helpers'

test.use({ permissions: ['clipboard-read', 'clipboard-write'] })

type Sent = { name?: string; params?: Record<string, unknown>; identify?: { userId: string } | null; page?: string }

async function withSpy(page: Page) {
  await page.addInitScript(() => localStorage.setItem('praticos.analyticsE2E', '1'))
}
const sent = (page: Page) => page.evaluate(() => ((window as unknown as { __analytics?: unknown[] }).__analytics ?? []) as Sent[])
const names = async (page: Page) => (await sent(page)).filter((item) => item.name).map((item) => item.name)
const notice = (page: Page) => page.getByRole('region', { name: 'Estatísticas de uso' })

test('Aceitar: a entrada, as telas e o compartilhar saem com os nomes do app, sem dado pessoal', async ({ page }) => {
  const customer = await makeCustomer({ phone: '+5511990004321' })
  const order = await makeOrder('admin', { customer: { id: customer.id, name: customer.name, phone: '+5511990004321' }, status: 'done' })
  await withSpy(page)
  await login(page, 'admin')
  await expect(notice(page)).toBeVisible({ timeout: 10_000 })
  await expectNoAxeViolations(page, 'aviso de estatísticas')
  // Nothing leaves before the answer.
  expect(await sent(page)).toEqual([])

  await notice(page).getByRole('button', { name: 'Aceitar' }).click()
  await expect(notice(page)).toBeHidden()
  await expect.poll(() => names(page)).toEqual(expect.arrayContaining(['login', 'screen_view']))
  const events = await sent(page)
  expect(events.find((item) => item.name === 'login')?.params).toEqual({ method: 'email', has_company: 'true' })
  expect(events.filter((item) => item.name === 'screen_view').map((item) => item.params)).toContainEqual({ firebase_screen: '/home', firebase_screen_class: '/home' })
  expect(events.find((item) => item.identify)?.identify).toMatchObject({ userId: USERS.admin.uid, companyId: 'company-alpha', userRole: 'admin' })

  // Tabs with the app's names (TabRoutes).
  await page.getByRole('navigation', { name: 'Principal' }).getByRole('link', { name: 'Agenda' }).click()
  await expect.poll(async () => (await sent(page)).filter((item) => item.name === 'screen_view').map((item) => item.params?.firebase_screen)).toContain('/agenda')
  expect((await sent(page)).filter((item) => item.page).map((item) => item.page)).toContain('/schedule')

  const firstPage = JSON.stringify(await sent(page))
  for (const personal of [USERS.admin.email, USERS.admin.name, '@']) expect(firstPage).not.toContain(personal)

  // Sharing an order: share with method clipboard, content_type order.
  await page.goto(`orders?order=${order.id}`)
  const panel = page.getByRole('complementary', { name: 'OS aberta' })
  await expect(panel).toBeVisible()
  await panel.getByTestId('share-open').click()
  const sheet = page.getByRole('dialog', { name: 'Mandar para o cliente' })
  await sheet.getByTestId('share-copy').click()
  await expect(page.locator('.toast')).toContainText('Link copiado')
  // A new page: the answer stays, the client loads again after the first screen.
  await expect.poll(async () => (await sent(page)).filter((item) => item.name === 'share').map((item) => item.params), { timeout: 10_000 }).toEqual([
    { method: 'clipboard', content_type: 'order', item_id: '' },
  ])

  const all = JSON.stringify(await sent(page))
  for (const personal of [USERS.admin.email, USERS.admin.name, customer.name, '990004321', '@']) expect(all).not.toContain(personal)
  expect(all).not.toContain(order.id)
})

test('Recusar: nada sai e o aviso não volta; Configurações liga e desliga', async ({ page }) => {
  await withSpy(page)
  await login(page, 'admin')
  await notice(page).getByRole('button', { name: 'Recusar' }).click()
  await expect(notice(page)).toBeHidden()
  await page.getByRole('navigation', { name: 'Principal' }).getByRole('link', { name: 'Agenda' }).click()
  await page.waitForTimeout(3000)
  expect(await sent(page)).toEqual([])

  await page.goto('settings')
  const box = page.getByTestId('settings-analytics')
  await expect(box).not.toBeChecked()
  await expect(notice(page)).toBeHidden()
  await box.check()
  await expect.poll(() => sent(page)).not.toEqual([])
  await box.uncheck()
  await expect.poll(async () => (await sent(page)).some((item) => 'stop' in item)).toBe(true)
  const before = (await sent(page)).length
  await page.getByRole('navigation', { name: 'Principal' }).getByRole('link', { name: 'Agenda' }).click()
  await page.waitForTimeout(500)
  expect((await sent(page)).length).toBe(before)
})

test('sem o pedido do teste (como produção sem measurementId) não há aviso nem envio', async ({ page }) => {
  await login(page, 'admin')
  await page.waitForTimeout(3500)
  await expect(notice(page)).toHaveCount(0)
  expect(await page.evaluate(() => (window as unknown as { __analytics?: unknown }).__analytics)).toBeUndefined()
})
