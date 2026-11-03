// Extras de tela grande on every layer: axe in light and dark, 320 px to a large
// screen without side scroll, text at 200%, the three languages and print.
import { expect, test, type Page } from '@playwright/test'
import { makeCustomer, makeOrder } from './data'
import { expectNoAxeViolations, expectNoSideScroll, login, setTheme } from './helpers'

const bar = (page: Page) => page.getByRole('region', { name: /Ações nas OS selecionadas|Actions on the selected orders|Acciones en las órdenes seleccionadas/ })
const AI_ON = { json: { success: true, data: { enabled: true, usage: { used: 1, limit: 100 } } } }

async function selected(page: Page, path = 'login') {
  const tag = `A11y Lote ${Date.now()}-${Math.round(Math.random() * 1e4)}`
  const customer = await makeCustomer({ name: tag, phone: '+5511990008001', taxId: '52998224725' })
  const a = await makeOrder('admin', { customer, status: 'done', total: 50, paidAmount: 0, payment: 'unpaid' })
  const b = await makeOrder('admin', { customer, status: 'done', total: 50, paidAmount: 0, payment: 'unpaid' })
  await page.route(/\/v1\/app\/ai\/status/, (route) => route.fulfill(AI_ON))
  await login(page, 'admin', path)
  return { tag, a, b }
}

async function select(page: Page, tag: string, numbers: number[]) {
  await page.goto(`orders?f=all&q=${encodeURIComponent(tag)}`)
  for (const number of numbers) await page.locator(`input[type=checkbox][aria-label$=" ${number}"]`).first().check()
  await expect(bar(page)).toBeVisible()
}

for (const theme of ['light', 'dark'] as const) {
  test(`axe: 0 violações na paleta, no lote, na cobrança, no assistente e no PDF, tema ${theme === 'light' ? 'claro' : 'escuro'}`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: theme })
    const { tag, a, b } = await selected(page)
    await setTheme(page, theme)
    await page.goto('schedule')
    await page.keyboard.press('ControlOrMeta+k')
    await page.getByRole('combobox', { name: /Buscar/ }).fill('Cliente 0')
    await expect(page.getByRole('listbox').getByRole('group').first()).toBeVisible()
    await expectNoAxeViolations(page, `paleta ${theme}`)
    await page.keyboard.press('Escape')
    await select(page, tag, [a.number, b.number])
    await expectNoAxeViolations(page, `barra do lote ${theme}`)
    await bar(page).getByRole('button', { name: 'Mudar a situação' }).click()
    await page.getByRole('dialog', { name: 'Qual a situação?' }).getByRole('button', { name: 'Na oficina' }).click()
    await expect(page.getByRole('dialog', { name: /Mudar 2 OS/ })).toBeVisible()
    await expectNoAxeViolations(page, `confirmar lote ${theme}`)
    await page.keyboard.press('Escape')
    await bar(page).getByTestId('batch-charge').click()
    await expect(page.getByRole('dialog', { name: /Mandar cobrança de 2 OS/ })).toBeVisible()
    await expectNoAxeViolations(page, `cobrança em lote ${theme}`)
    await page.keyboard.press('Escape')
    await bar(page).getByTestId('batch-ai').click()
    await expect(page.getByRole('dialog', { name: 'Pedir ao assistente em 2 OS' })).toBeVisible()
    await expectNoAxeViolations(page, `assistente em lote ${theme}`)
    await page.keyboard.press('Escape')
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
    const { tag, a, b } = await selected(page)
    await select(page, tag, [a.number, b.number])
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
  test(`320 px${zoom ? ', texto a 200%' : ''}: paleta e PDF da OS sem rolagem lateral`, async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 640 })
    const { a } = await selected(page)
    await page.goto(`orders?order=${a.id}`)
    if (zoom) await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    const panel = page.getByRole('complementary', { name: 'OS aberta' }).or(page.getByRole('dialog', { name: 'OS aberta' }))
    await panel.getByRole('button', { name: 'Mais ações' }).click()
    await page.getByRole('dialog').getByRole('button', { name: 'Ver PDF' }).click()
    await expect(page.getByTestId('pdf-download')).toBeVisible({ timeout: 20_000 })
    expect(await layerOverflow(page)).toBeLessThanOrEqual(1)
    await expectNoSideScroll(page)
    await page.keyboard.press('Escape')
    // The list behind (the Agenda at 320 px and 200% is wider than the screen before this slice).
    await page.goto('./')
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
  test(`idioma ${language}: paleta, lote e PDF`, async ({ page }) => {
    const { tag, a, b } = await selected(page)
    await page.evaluate((value) => localStorage.setItem('praticos.prefs', JSON.stringify({ language: value })), language)
    await page.goto('schedule')
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
    await page.keyboard.press('ControlOrMeta+k')
    await page.getByRole('combobox').fill('501')
    await expect(page.getByRole('listbox').getByRole('group', { name: orders })).toBeVisible()
    await page.getByRole('combobox').fill(language === 'en' ? 'catalog' : 'catálogo')
    await expect(page.getByRole('listbox').getByRole('group', { name: actions }).getByRole('option', { name: new RegExp(goTo) })).toBeVisible()
    await page.keyboard.press('Escape')
    await select(page, tag, [a.number, b.number])
    await bar(page).getByRole('button').first().click()
    await page.getByRole('dialog').getByRole('button').nth(1).click()
    await expect(page.getByRole('dialog', { name: confirm })).toBeVisible()
  })
}

test('imprimir várias: folha própria, sem a barra do lote nem diálogos', async ({ page }) => {
  const { tag, a, b } = await selected(page)
  await page.addInitScript(() => (window.print = () => undefined))
  await page.evaluate(() => (window.print = () => undefined))
  await select(page, tag, [a.number, b.number])
  await bar(page).getByTestId('batch-print').click()
  await expect(page.getByTestId('print-sheet')).toHaveCount(2)
  await page.emulateMedia({ media: 'print' })
  await expect(page.getByTestId('print-sheet').first()).toBeVisible()
  await expect(bar(page)).toBeHidden()
})
