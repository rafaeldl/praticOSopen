// Extras de tela grande on every layer: axe in light and dark, 320 px to a large
// screen without side scroll, text at 200%, the three languages and print.
import { expect, test, type Page } from '@playwright/test'
import { makeCustomer, makeOrder, type TestOrder } from './data'
import { expectNoAxeViolations, expectNoSideScroll, login, startWithPrefs } from './helpers'

const bar = (page: Page) => page.getByRole('region', { name: /Ações nas OS selecionadas|Actions on the selected orders|Acciones en las órdenes seleccionadas/ })
const AI_ON = { json: { success: true, data: { enabled: true, usage: { used: 1, limit: 100 } } } }

/** Two done orders of a customer of their own, so the search finds only them. */
async function twoOrders(page: Page) {
  const tag = `A11y Lote ${Date.now()}-${Math.round(Math.random() * 1e4)}`
  const customer = await makeCustomer({ name: tag, phone: '+5511990008001', taxId: '52998224725' })
  const a = await makeOrder('admin', { customer, status: 'done', total: 50, paidAmount: 0, payment: 'unpaid' })
  const b = await makeOrder('admin', { customer, status: 'done', total: 50, paidAmount: 0, payment: 'unpaid' })
  await page.route(/\/v1\/app\/ai\/status/, (route) => route.fulfill(AI_ON))
  return { tag, a, b }
}

const listOf = (tag: string) => `orders?f=all&q=${encodeURIComponent(tag)}`

/** Logs in straight on the list of the two orders (one page load) and selects both. */
async function selectBoth(page: Page) {
  const { tag, a, b } = await twoOrders(page)
  await login(page, 'admin', listOf(tag))
  await check(page, [a, b])
  return { tag, a, b }
}

async function check(page: Page, orders: TestOrder[]) {
  for (const order of orders) await page.locator(`input[type=checkbox][aria-label$=" ${order.number}"]`).first().check()
  await expect(bar(page)).toContainText(String(orders.length))
}

/** Theme set before the app starts, so the test logs in on the screen it checks. */
async function useTheme(page: Page, theme: 'light' | 'dark') {
  await page.emulateMedia({ colorScheme: theme })
  await startWithPrefs(page, { theme })
}

// One layer per test (the palette, the bar with its confirmation, the charge, the
// assistant and the PDF): each logs in and makes its data, and the PDF build or
// a slow axe run never takes the time of another layer.
for (const [theme, name] of [
  ['light', 'claro'],
  ['dark', 'escuro'],
] as const) {
  test(`axe: 0 violações na paleta, tema ${name}`, async ({ page }) => {
    await useTheme(page, theme)
    await login(page, 'admin', 'schedule')
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    await page.keyboard.press('ControlOrMeta+k')
    await page.getByRole('combobox', { name: /Buscar/ }).fill('Cliente 0')
    await expect(page.getByRole('listbox').getByRole('group').first()).toBeVisible()
    await expectNoAxeViolations(page, `paleta ${theme}`)
  })

  test(`axe: 0 violações na barra do lote e na confirmação, tema ${name}`, async ({ page }) => {
    await useTheme(page, theme)
    await selectBoth(page)
    await expectNoAxeViolations(page, `barra do lote ${theme}`)
    await bar(page).getByRole('button', { name: 'Mudar a situação' }).click()
    await page.getByRole('dialog', { name: 'Qual a situação?' }).getByRole('button', { name: 'Na oficina' }).click()
    await expect(page.getByRole('dialog', { name: /Mudar 2 OS/ })).toBeVisible()
    await expectNoAxeViolations(page, `confirmar lote ${theme}`)
  })

  test(`axe: 0 violações na cobrança em lote, tema ${name}`, async ({ page }) => {
    await useTheme(page, theme)
    await selectBoth(page)
    await bar(page).getByTestId('batch-charge').click()
    await expect(page.getByRole('dialog', { name: /Mandar cobrança de 2 OS/ })).toBeVisible()
    await expectNoAxeViolations(page, `cobrança em lote ${theme}`)
  })

  test(`axe: 0 violações no assistente em lote, tema ${name}`, async ({ page }) => {
    await useTheme(page, theme)
    await selectBoth(page)
    await bar(page).getByTestId('batch-ai').click()
    await expect(page.getByRole('dialog', { name: 'Pedir ao assistente em 2 OS' })).toBeVisible()
    await expectNoAxeViolations(page, `assistente em lote ${theme}`)
  })

  test(`axe: 0 violações no PDF em lote, tema ${name}`, async ({ page }) => {
    await useTheme(page, theme)
    await selectBoth(page)
    await bar(page).getByTestId('batch-pdf').click()
    await expect(page.getByTestId('pdf-download')).toBeVisible({ timeout: 20_000 })
    await expectNoAxeViolations(page, `PDF ${theme}`)
  })
}

// The batch is a large-screen extra (no selection below 48rem); the palette and the PDF of one order go down to 320 px.
for (const [width, height, zoom] of [
  [2560, 1440, false],
  [1366, 768, true],
] as const) {
  test(`${width} px${zoom ? ', texto a 200%' : ''}: lote e diálogos sem rolagem lateral`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await selectBoth(page)
    if (zoom) await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await expectNoSideScroll(page)
    for (const id of ['batch-charge', 'batch-ai', 'batch-pdf']) {
      await bar(page).getByTestId(id).click()
      await expect(page.locator('.layer-box').last()).toBeVisible()
      expect(await layerOverflow(page), id).toBeLessThanOrEqual(1)
      await expectNoSideScroll(page)
      await page.keyboard.press('Escape')
    }
  })
}

async function layerOverflow(page: Page) {
  return page.evaluate(() => {
    const box = [...document.querySelectorAll('.layer-box')].pop() as HTMLElement
    return box.scrollWidth - box.clientWidth
  })
}

for (const zoom of [false, true]) {
  test(`320 px${zoom ? ', texto a 200%' : ''}: PDF da OS sem rolagem lateral`, async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 640 })
    const { a } = await twoOrders(page)
    await login(page, 'admin', `orders?order=${a.id}`)
    if (zoom) await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    const panel = page.getByRole('complementary', { name: 'OS aberta' }).or(page.getByRole('dialog', { name: 'OS aberta' }))
    await panel.getByRole('button', { name: 'Mais ações' }).click()
    await page.getByRole('dialog').getByRole('button', { name: 'Ver PDF' }).click()
    await expect(page.getByTestId('pdf-download')).toBeVisible({ timeout: 20_000 })
    expect(await layerOverflow(page)).toBeLessThanOrEqual(1)
    await expectNoSideScroll(page)
  })

  // The list behind (the Agenda at 320 px and 200% is wider than the screen before this slice).
  test(`320 px${zoom ? ', texto a 200%' : ''}: paleta sem rolagem lateral`, async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 640 })
    await login(page, 'admin')
    if (zoom) await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    await page.getByRole('button', { name: 'Buscar' }).first().click()
    await page.getByRole('combobox', { name: /Buscar/ }).fill('Cliente 0')
    await expect(page.getByRole('listbox').getByRole('group').first()).toBeVisible()
    expect(await layerOverflow(page)).toBeLessThanOrEqual(1)
    await expectNoSideScroll(page)
  })
}

for (const [language, orders, actions, goTo, confirm] of [
  ['en', 'Orders', 'Actions', 'Go to', /Change 2 \S+ to/],
  ['es', 'OS', 'Acciones', 'Ir a', /¿Cambiar 2 \S+ a/],
] as const) {
  test(`idioma ${language}: paleta`, async ({ page }) => {
    await startWithPrefs(page, { language })
    await login(page, 'admin', 'schedule')
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    await page.keyboard.press('ControlOrMeta+k')
    await page.getByRole('combobox').fill('501')
    await expect(page.getByRole('listbox').getByRole('group', { name: orders })).toBeVisible()
    await page.getByRole('combobox').fill(language === 'en' ? 'catalog' : 'catálogo')
    await expect(page.getByRole('listbox').getByRole('group', { name: actions }).getByRole('option', { name: new RegExp(goTo) })).toBeVisible()
  })

  test(`idioma ${language}: lote`, async ({ page }) => {
    await startWithPrefs(page, { language })
    await selectBoth(page)
    await bar(page).getByRole('button').first().click()
    await page.getByRole('dialog').getByRole('button').nth(1).click()
    await expect(page.getByRole('dialog', { name: confirm })).toBeVisible()
  })
}

test('imprimir várias: folha própria, sem a barra do lote nem diálogos', async ({ page }) => {
  await page.addInitScript(() => (window.print = () => undefined))
  await selectBoth(page)
  await bar(page).getByTestId('batch-print').click()
  await expect(page.getByTestId('print-sheet')).toHaveCount(2)
  await page.emulateMedia({ media: 'print' })
  await expect(page.getByTestId('print-sheet').first()).toBeVisible()
  await expect(bar(page)).toBeHidden()
})
