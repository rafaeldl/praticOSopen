// Modals, drawers and sheets fit the screen: no sideways scroll inside them,
// and the box stays inside the window, on common notebook and desktop sizes
// and at 200% zoom (half the CSS width). The cause in "Mandar para o cliente"
// was a long link that never wrapped and widened the body's grid column.
import { expect, test, type Page } from './test'
import { makeCustomer, makeOrder } from './data'
import { login, type UserKey } from './helpers'

const SIZES = [
  { name: '1366x768', width: 1366, height: 768 },
  { name: '1280x720', width: 1280, height: 720 },
  { name: '1920x1080', width: 1920, height: 1080 },
  // 1366x768 at 200% zoom: the page lays out in half the CSS pixels.
  { name: '1366x768 a 200%', width: 683, height: 384 },
]

// The order's link comes from the functions emulator: the first call after it starts is slow.
test.describe.configure({ timeout: 60_000 })

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })

async function orderReady(page: Page) {
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

/** What does not fit in each open layer: a body (or any scroller) wider than itself, or a box outside the window. */
async function overflows(page: Page): Promise<string[]> {
  return page.evaluate(() =>
    [...document.querySelectorAll<HTMLElement>('.layer-box')].flatMap((box) => {
      const label = box.getAttribute('aria-label')
      const problems: string[] = []
      for (const element of [box, ...box.querySelectorAll<HTMLElement>('*')]) {
        const style = getComputedStyle(element)
        const scrolls = /auto|scroll/.test(style.overflowX) || element.classList.contains('layer-body')
        if (scrolls && element.scrollWidth > element.clientWidth + 1) {
          problems.push(`${label}: ${element.className} rola para o lado (${element.scrollWidth} > ${element.clientWidth})`)
        }
      }
      const rect = box.getBoundingClientRect()
      if (rect.left < -1 || rect.top < -1 || rect.right > innerWidth + 1 || rect.bottom > innerHeight + 1) {
        problems.push(`${label}: fora da janela (${Math.round(rect.right)}x${Math.round(rect.bottom)} em ${innerWidth}x${innerHeight})`)
      }
      return problems
    }),
  )
}

async function expectFitsAtEverySize(page: Page) {
  await expect(page.locator('.layer-box').last()).toBeVisible()
  for (const size of SIZES) {
    await page.setViewportSize({ width: size.width, height: size.height })
    await expect.poll(() => overflows(page), { message: size.name }).toEqual([])
  }
}

type Case = { name: string; user: UserKey; path: (ids: { quote: string; done: string }) => string; open: (page: Page) => Promise<unknown> }

const CASES: Case[] = [
  {
    name: 'Mandar para o cliente',
    user: 'admin',
    path: (ids) => `orders?order=${ids.quote}`,
    open: async (page) => {
      await orderReady(page)
      await panel(page).getByTestId('share-open').click()
      // The link comes from the API (functions emulator), slower than Firestore.
      await expect(page.getByTestId('share-url')).toBeVisible({ timeout: 20_000 })
    },
  },
  {
    name: 'menu da OS',
    user: 'admin',
    path: (ids) => `orders?order=${ids.quote}`,
    open: async (page) => {
      await orderReady(page)
      await panel(page).getByRole('button', { name: 'Mais ações' }).click()
    },
  },
  {
    name: 'item da OS',
    user: 'admin',
    path: (ids) => `orders?order=${ids.quote}`,
    open: async (page) => {
      await orderReady(page)
      await panel(page).getByRole('button', { name: 'Adicionar serviço ou peça' }).click()
    },
  },
  {
    name: 'Receber',
    user: 'admin',
    path: (ids) => `orders?order=${ids.done}`,
    open: async (page) => {
      await orderReady(page)
      await panel(page).getByTestId('next-step').click()
      await expect(page.getByRole('dialog', { name: 'Receber' })).toBeVisible()
    },
  },
  { name: 'Nova OS', user: 'admin', path: () => 'orders', open: (page) => page.getByTestId('new-order').click() },
  { name: 'cliente novo', user: 'admin', path: () => 'customers', open: (page) => page.getByTestId('new-customer').click() },
  { name: 'item novo do catálogo', user: 'admin', path: () => 'catalog', open: (page) => page.getByTestId('new-catalog-item').click() },
  { name: 'checklist novo', user: 'admin', path: () => 'checklists', open: (page) => page.getByTestId('new-checklist').click() },
  { name: 'contrato novo', user: 'admin', path: () => 'contracts', open: (page) => page.getByTestId('contract-new').click() },
  { name: 'período do financeiro', user: 'admin', path: () => 'finance', open: (page) => page.getByTestId('fin-other-period').click() },
  { name: 'dados da empresa', user: 'admin', path: () => 'settings/company', open: (page) => page.getByTestId('company-data').click() },
  { name: 'convite da equipe', user: 'tOwner', path: () => 'team', open: (page) => page.getByTestId('team-resend').click() },
]

for (const item of CASES) {
  test(`${item.name} cabe na tela sem rolar para o lado`, async ({ page }) => {
    let ids = { quote: '', done: '' }
    // Only the order's layers need an order of their own (a long name, a phone for WhatsApp).
    if (item.path(ids).startsWith('orders?')) {
      const customer = await makeCustomer({ name: 'Cliente Com Um Nome Bem Comprido Para Testar', phone: '+5511990001234' })
      const who = { id: customer.id, name: customer.name }
      ids = {
        quote: (await makeOrder('admin', { customer: who, status: 'quote' })).id,
        done: (await makeOrder('admin', { customer: who, status: 'done', total: 50 })).id,
      }
    }
    await page.setViewportSize({ width: 1366, height: 768 })
    await login(page, item.user, item.path(ids))
    await item.open(page)
    await expectFitsAtEverySize(page)
  })
}
