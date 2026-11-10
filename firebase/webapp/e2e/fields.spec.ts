// One look for every field (web.fields.*): a select is as tall as the inputs
// beside it, a filled date reads in the text colour (not the placeholder's),
// and the search hint of Início fits its box at any width and text size.
import { expect, test, type Locator, type Page } from './test'
import { login, startWithPrefs } from './helpers'

const height = (locator: Locator) => locator.evaluate((element) => element.getBoundingClientRect().height)
const color = (locator: Locator) => locator.evaluate((element) => getComputedStyle(element).color)

test('Nova OS: Situação e Responsável têm a altura de Visita e Entrega; data preenchida na cor do texto', async ({ page }) => {
  await login(page, 'admin')
  await page.getByTestId('new-order').click()
  const drawer = page.getByRole('dialog', { name: 'Nova OS' })
  await drawer.getByText('Mais opções').click()
  const status = drawer.locator('#no-status')
  const visit = drawer.locator('#no-visit')
  const due = drawer.locator('#no-due')
  await expect(status).toBeVisible()
  const base = await height(visit)
  expect(Math.abs((await height(status)) - base)).toBeLessThanOrEqual(1)
  expect(Math.abs((await height(due)) - base)).toBeLessThanOrEqual(1)
  const assignee = drawer.locator('#no-assignee')
  if (await assignee.count()) expect(Math.abs((await height(assignee)) - base)).toBeLessThanOrEqual(1)

  // Empty: the placeholder colour. Filled: the text colour, like any value.
  await expect(visit).toHaveAttribute('data-empty', 'true')
  const empty = await color(visit)
  await visit.fill('2026-11-05T12:30')
  await expect(visit).not.toHaveAttribute('data-empty', /.*/)
  const filled = await color(visit)
  expect(filled).not.toBe(empty)
  expect(filled).toBe(await color(drawer.locator('#no-request')))
  // The value's own parts follow the field (no tinted digits).
  const parts = await visit.evaluate((element) => getComputedStyle(element, '::-webkit-datetime-edit').color)
  expect(parts).toBe(filled)
})

test('Configurações da empresa: o país (select) tem a altura do nome e do telefone', async ({ page }) => {
  await login(page, 'pOwner', 'settings/company')
  await page.getByTestId('company-data').click()
  const country = page.getByTestId('company-country')
  await expect(country).toBeVisible()
  const name = await height(page.locator('#cf-name'))
  expect(Math.abs((await height(country)) - name)).toBeLessThanOrEqual(1)
  expect(Math.abs((await height(page.locator('#cf-phone'))) - name)).toBeLessThanOrEqual(1)
})

/** The hint's width in the box's own font, against the room inside it. */
async function hintFits(page: Page) {
  const search = page.locator('#orders-search')
  await expect(search).toBeVisible()
  return search.evaluate((element) => {
    const input = element as HTMLInputElement
    const style = getComputedStyle(input)
    const context = document.createElement('canvas').getContext('2d') as CanvasRenderingContext2D
    context.font = style.font
    const room = input.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight)
    return { text: input.placeholder, width: context.measureText(input.placeholder).width, room, fits: input.scrollWidth <= input.clientWidth }
  })
}

for (const [language, full] of [
  ['pt', 'Buscar OS, cliente ou veículo'],
  ['en', 'Search orders, customers or vehicle'],
  ['es', 'Buscar OS, cliente o vehículo'],
] as const) {
  test(`busca do Início: a dica inteira cabe na tela grande (${language})`, async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 })
    await startWithPrefs(page, { language })
    await login(page, 'admin')
    const fit = await hintFits(page)
    expect(fit.text, JSON.stringify(fit)).toBe(full)
    expect(fit.width).toBeLessThanOrEqual(fit.room)
    expect(fit.fits).toBe(true)
  })
}

for (const zoom of [false, true]) {
  test(`busca do Início em 320 px${zoom ? ', texto a 200%' : ''}: a dica não é cortada`, async ({ page }) => {
    await page.setViewportSize({ width: 320, height: 640 })
    await login(page, 'admin')
    if (zoom) await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await expect(async () => {
      const fit = await hintFits(page)
      expect(fit.width).toBeLessThanOrEqual(fit.room)
      expect(fit.fits).toBe(true)
    }).toPass()
    // The label keeps the whole hint for who uses a screen reader.
    await expect(page.getByLabel('Buscar OS, cliente ou veículo')).toBeVisible()
  })
}
