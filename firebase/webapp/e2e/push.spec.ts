// Browser notifications (order.offer.notifications, auth.gate.notification-open).
// The emulator does not deliver real pushes: the E2E build gets a fixed token
// (lib/push/token.ts), and what the service worker hands the page is sent the
// way it sends it (a message on navigator.serviceWorker). The worker itself is
// tested in tests/push.test.ts.
import { expect, test, type Page } from '@playwright/test'
import { makeCustomer, makeOrder, readUser, writeDoc } from './data'
import { COMPANY_A, COMPANY_B, USERS } from './fixtures.mjs'
import { login, signOut } from './helpers'

const offer = (page: Page) => page.getByRole('dialog', { name: 'Avisos do PraticOS' })
const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const ADMIN = USERS.admin.uid

/**
 * A browser that has not answered yet (headless Chromium says "denied" by
 * itself); its own question answers "Permitir" and is counted.
 */
async function undecidedBrowser(page: Page) {
  await page.context().grantPermissions(['notifications'])
  await page.addInitScript(() => {
    let answer: NotificationPermission = 'default'
    Object.defineProperty(Notification, 'permission', { get: () => answer, configurable: true })
    const ask = Notification.requestPermission.bind(Notification)
    const w = window as unknown as { asked: number }
    w.asked = 0
    Notification.requestPermission = async () => {
      w.asked++
      answer = await ask()
      return answer
    }
  })
}

type Entry = { token?: string; deviceId?: string; platform?: string; createdAt?: string; lastUsedAt?: string }
const device = (page: Page) => page.evaluate(() => localStorage.getItem('praticos.push.device'))
async function entriesOf(page: Page): Promise<Entry[]> {
  const id = await device(page)
  const tokens = ((await readUser(ADMIN))?.fcmTokens as Entry[] | undefined) ?? []
  return id ? tokens.filter((entry) => entry.deviceId === id) : []
}

/** What public/firebase-messaging-sw.js posts to an open tab. */
const fromWorker = (page: Page, message: Record<string, unknown>) =>
  page.evaluate((data) => navigator.serviceWorker.dispatchEvent(new MessageEvent('message', { data })), message)

test('depois de salvar a OS: explica, o navegador pergunta uma vez, o token vai para a conta e sai ao sair', async ({ page }) => {
  await undecidedBrowser(page)
  const customer = await makeCustomer()
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  // Never on the entry screen nor on opening the app.
  await expect(offer(page)).toHaveCount(0)

  await page.getByTestId('new-order').click()
  await page.getByRole('combobox', { name: 'Cliente' }).fill(customer.name)
  await expect(page.getByRole('option', { name: new RegExp(`^${customer.name}`) })).toBeVisible()
  await page.keyboard.press('Enter')
  await page.getByRole('combobox', { name: 'O que vai ser feito?' }).fill('Serviço 1')
  await expect(page.getByRole('option', { name: /^Serviço 1/ })).toBeVisible()
  await page.keyboard.press('Enter')
  await page.getByTestId('save-order').click()
  await expect(panel(page)).toBeVisible()

  await expect(offer(page)).toBeVisible()
  await expect(offer(page)).toContainText('O navegador vai perguntar se pode mandar esses avisos.')
  await offer(page).getByRole('button', { name: 'Continuar' }).click()
  await expect(offer(page)).toHaveCount(0)
  expect(await page.evaluate(() => (window as unknown as { asked: number }).asked)).toBe(1)

  // Same place and shape as the app (users/{uid}.fcmTokens), marked as web.
  await expect.poll(async () => (await entriesOf(page)).length).toBe(1)
  const [entry] = await entriesOf(page)
  expect(entry).toMatchObject({ platform: 'web', token: expect.stringMatching(/^e2e-web-token-web-/) })
  expect(Number.isNaN(Date.parse(entry!.createdAt ?? ''))).toBe(false)

  // Once: a visit marked later does not ask again.
  await panel(page).locator('.od-head').click()
  await page.keyboard.press('d')
  const visit = page.getByRole('dialog', { name: 'Agendar dia e hora' })
  await visit.getByLabel('Visita').fill('2030-05-09T08:30')
  await visit.getByRole('button', { name: 'Salvar' }).click()
  await expect(panel(page)).toContainText('09/05, 08:30')
  await expect(offer(page)).toHaveCount(0)

  // Signing out takes this browser off the account.
  const id = await device(page)
  await page.goto('settings')
  await signOut(page)
  await expect
    .poll(async () => (((await readUser(ADMIN))?.fcmTokens as Entry[] | undefined) ?? []).filter((t) => t.deviceId === id).length)
    .toBe(0)
})

test('visita marcada numa OS salva: explica; "Agora não" não pergunta ao navegador nem volta', async ({ page }) => {
  await undecidedBrowser(page)
  const order = await makeOrder('admin', { status: 'approved' })
  await login(page, 'admin', `orders?order=${order.id}`)
  await expect(panel(page)).toBeVisible()
  await expect(offer(page)).toHaveCount(0)

  const schedule = async (when: string) => {
    await panel(page).locator('.od-head').click()
    await page.keyboard.press('d')
    const visit = page.getByRole('dialog', { name: 'Agendar dia e hora' })
    await visit.getByLabel('Visita').fill(when)
    await visit.getByRole('button', { name: 'Salvar' }).click()
  }
  await schedule('2030-05-09T08:30')
  await expect(offer(page)).toBeVisible()
  await offer(page).getByRole('button', { name: 'Agora não' }).click()
  await expect(offer(page)).toHaveCount(0)
  expect(await page.evaluate(() => (window as unknown as { asked: number }).asked)).toBe(0)
  expect(await entriesOf(page)).toEqual([])

  await schedule('2030-05-10T09:00')
  await expect(panel(page)).toContainText('10/05, 09:00')
  await expect(offer(page)).toHaveCount(0)
})

test('tocar no aviso abre a OS da empresa em uso; de outra empresa, fica no Início', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved' })
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()

  // A tab already open: the worker focuses it and tells it what to open.
  await fromWorker(page, { type: 'praticos:notice-open', link: `/app/?order=${order.id}&company=${COMPANY_A}` })
  await expect(panel(page)).toBeVisible()
  await expect(page).toHaveURL(new RegExp(`/app/\\?order=${order.id}$`))

  // An order of another company is ignored, as in the app.
  await fromWorker(page, { type: 'praticos:notice-open', link: `/app/?order=other-order&company=${COMPANY_B}` })
  await expect(page).toHaveURL(/\/app\/$/)
  await expect(panel(page)).toHaveCount(0)

  // No tab open: the worker opens the server's link.
  await page.goto(`./?order=${order.id}&company=${COMPANY_A}`)
  await expect(panel(page)).toBeVisible()
  await expect(page).toHaveURL(new RegExp(`/app/\\?order=${order.id}$`))
})

test('aviso com a página na tela aparece dentro dela e o sino conta de novo', async ({ page }) => {
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  const bell = page.getByTestId('bell')
  const before = (await page.getByTestId('bell-count').count()) ? Number(await page.getByTestId('bell-count').textContent()) : 0

  const id = `push-${Date.now()}`
  await writeDoc(`notifications/${id}`, {
    title: 'Orçamento Aprovado! ✅',
    body: 'Ana aprovou o orçamento da OS #1',
    type: 'order_approved',
    recipientId: ADMIN,
    read: false,
    createdAt: new Date(),
    company: { id: COMPANY_A },
  })
  await fromWorker(page, {
    type: 'praticos:notice',
    title: 'Orçamento Aprovado! ✅',
    body: 'Ana aprovou o orçamento da OS #1',
    data: { type: 'order_approved', orderId: 'x', companyId: COMPANY_A },
  })
  await expect(page.locator('.toast')).toContainText('Ana aprovou o orçamento')
  await expect(bell).toHaveAccessibleName(new RegExp(`Avisos, ${before + 1} novos?`))
  await writeDoc(`notifications/${id}`, { read: true }, true)
})

test('computador compartilhado: quem entra depois nunca herda o token de quem não saiu', async ({ page }) => {
  // The last person (another account) left this browser without "Sair"; notifications already allowed.
  await page.context().grantPermissions(['notifications'])
  await page.addInitScript(() => {
    Object.defineProperty(Notification, 'permission', { get: () => 'granted', configurable: true })
    if (!sessionStorage.getItem('seeded')) {
      sessionStorage.setItem('seeded', '1')
      localStorage.setItem('praticos.push.device', 'web-left-behind')
      localStorage.setItem('praticos.push.owner', 'e2e-someone-else')
    }
  })
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()

  // Signed in with permission: this browser joins the account, under a new id and token.
  await expect.poll(async () => (await entriesOf(page)).length).toBe(1)
  const [entry] = await entriesOf(page)
  expect(entry?.deviceId).not.toBe('web-left-behind')
  expect(entry?.token).not.toContain('web-left-behind')
  expect(await page.evaluate(() => localStorage.getItem('praticos.push.owner'))).toBe(ADMIN)
  const all = ((await readUser(ADMIN))?.fcmTokens as Entry[] | undefined) ?? []
  expect(all.filter((t) => t.deviceId === 'web-left-behind')).toEqual([])
})
