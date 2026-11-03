// Fatia 07 (checklists) on every screen: axe in light and dark, 320 to 2560 px
// without side scroll, text at 200%, and the three languages.
import { expect, test, type Page } from '@playwright/test'
import { makeOrder, makeOrderForm } from './data'
import { expectNoAxeViolations, expectNoSideScroll, login, startWithPrefs } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
// 1x1 PNG.
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64')

const ITEMS = [
  { id: 'b', label: 'Pneus bons?', type: 'boolean', required: true },
  { id: 's', label: 'Óleo', type: 'select', options: ['Bom', 'Baixo'] },
  { id: 'c', label: 'Itens', type: 'checklist', options: ['Estepe', 'Macaco'] },
  { id: 't', label: 'Observação', type: 'text' },
  { id: 'p', label: 'Foto da frente', type: 'photo_only' },
]

const THEMES = [
  ['light', 'claro'],
  ['dark', 'escuro'],
] as const

/** Logs in straight on `path`, with the theme set before the app starts (one page load). */
async function start(page: Page, theme: 'light' | 'dark', path: string) {
  await page.emulateMedia({ colorScheme: theme })
  await startWithPrefs(page, { theme })
  await login(page, 'admin', path)
}

/** A fresh order with two devices and a checklist with 1 of 5 answered, for one test. */
async function orderWithChecklist() {
  const order = await makeOrder('admin', {
    devices: [
      { id: 'device-2', name: 'Veículo 2', serial: 'TST0002' },
      { id: 'device-5', name: 'Veículo 5', serial: 'TST0005' },
    ],
  })
  await makeOrderForm(order.id, { items: ITEMS, deviceId: 'device-2', responses: [{ itemId: 's', value: 'Bom', photoUrls: [] }], status: 'in_progress' })
  return order
}

/** The order's checklists come live: wait for the row with its progress, not just the panel. */
async function expectOrderChecklists(page: Page) {
  await expect(panel(page).getByTestId('order-forms')).toContainText('1 de 5 respondidas')
}

// One screen, or two that open from each other, per test: each test logs in and
// makes its own data, so a slow axe run never eats the time of the next screen.
for (const [theme, name] of THEMES) {
  test(`axe: 0 violações na lista de checklists e no pronto, tema ${name}`, async ({ page }) => {
    await start(page, theme, 'checklists')
    await expect(page.getByTestId('checklists-list')).toBeVisible()
    await expect(page.getByTestId('ready-list').getByRole('button', { name: 'Ver Teste final' })).toBeVisible()
    await expectNoAxeViolations(page, `checklists ${theme}`)
    await page.getByTestId('ready-list').getByRole('button', { name: 'Ver Teste final' }).click()
    await expect(page.getByTestId('ready-preview')).toBeVisible()
    await expectNoAxeViolations(page, `pronto ${theme}`)
  })

  test(`axe: 0 violações no editor do modelo e na pergunta, tema ${name}`, async ({ page }) => {
    await start(page, theme, 'checklists')
    await page.getByRole('button', { name: 'Abrir Vistoria de entrada' }).click()
    await expect(page.getByTestId('template-editor').getByRole('button', { name: /Pergunta 2/ })).toBeVisible()
    await expectNoAxeViolations(page, `editor ${theme}`)
    await page.getByTestId('template-editor').getByRole('button', { name: /Pergunta 2/ }).click()
    await expect(page.getByTestId('question-dialog')).toBeVisible()
    await expectNoAxeViolations(page, `pergunta ${theme}`)
  })

  test(`axe: 0 violações nos checklists da OS, tema ${name}`, async ({ page }) => {
    const order = await orderWithChecklist()
    await start(page, theme, `orders?order=${order.id}`)
    await expectOrderChecklists(page)
    await expectNoAxeViolations(page, `checklists na OS ${theme}`)
  })

  test(`axe: 0 violações ao preencher o checklist e ver a foto, tema ${name}`, async ({ page }) => {
    const order = await orderWithChecklist()
    await start(page, theme, `orders?order=${order.id}`)
    await expectOrderChecklists(page)
    await panel(page).getByRole('button', { name: 'Abrir o checklist Vistoria de entrada' }).click()
    await expect(page.getByTestId('form-fill')).toBeVisible()
    await page.getByTestId('photo-input-p').setInputFiles({ name: 'f.png', mimeType: 'image/png', buffer: PNG })
    await expect(page.getByRole('button', { name: /Ver foto 1/ })).toBeVisible()
    await expectNoAxeViolations(page, `preencher ${theme}`)
    await page.getByRole('button', { name: /Ver foto 1/ }).click()
    await expect(page.getByTestId('fill-viewer')).toBeVisible()
    await expectNoAxeViolations(page, `foto ${theme}`)
  })

  test(`axe: 0 violações ao adicionar checklist na OS (qual veículo e qual checklist), tema ${name}`, async ({ page }) => {
    const order = await orderWithChecklist()
    await start(page, theme, `orders?order=${order.id}`)
    await expectOrderChecklists(page)
    await panel(page).getByTestId('add-checklist').click()
    await expect(page.getByRole('dialog').getByRole('button', { name: 'Geral' })).toBeVisible()
    await expectNoAxeViolations(page, `qual veículo ${theme}`)
    await page.getByRole('dialog').getByRole('button', { name: 'Geral' }).click()
    await expect(page.getByTestId('checklist-picker').getByRole('button', { name: /Vistoria de entrada/ })).toBeVisible()
    await expectNoAxeViolations(page, `qual checklist ${theme}`)
  })
}

for (const [width, height] of [
  [320, 640],
  [2560, 1440],
] as const) {
  test(`${width} px sem rolagem lateral nos checklists`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    const order = await makeOrder('admin')
    await makeOrderForm(order.id, { items: ITEMS })
    await login(page, 'admin', 'checklists')
    await expect(page.getByTestId('checklists-list')).toBeVisible()
    await expectNoSideScroll(page)
    await page.getByRole('button', { name: 'Abrir Vistoria de entrada' }).click()
    await expect(page.getByTestId('template-editor')).toBeVisible()
    await expectNoSideScroll(page)
    await page.goto(`orders?order=${order.id}`)
    await page.getByRole('button', { name: 'Abrir o checklist Vistoria de entrada' }).click()
    await expect(page.getByTestId('form-fill')).toBeVisible()
    const overflow = await page.evaluate(() => {
      const box = document.querySelector('.layer--drawer .layer-box') as HTMLElement
      return box.scrollWidth - box.clientWidth
    })
    expect(overflow).toBeLessThanOrEqual(1)
  })
}

for (const [width, height] of [
  [320, 640],
  [1366, 768],
] as const) {
  test(`texto a 200% em ${width} px nos checklists`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    const order = await makeOrder('admin')
    await makeOrderForm(order.id, { items: ITEMS })
    await login(page, 'admin', 'checklists')
    await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await expect(page.getByTestId('checklists-list')).toBeVisible()
    await expectNoSideScroll(page)
    for (const path of ['checklists?checklist=seg-entrada', `orders?order=${order.id}`]) {
      await page.goto(path)
      await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
      if (path.startsWith('orders')) await page.getByRole('button', { name: 'Abrir o checklist Vistoria de entrada' }).click()
      const drawer = page.locator('.layer--drawer .layer-box')
      await expect(drawer).toBeVisible()
      const overflow = await drawer.evaluate((box) => box.scrollWidth - box.clientWidth)
      expect(overflow).toBeLessThanOrEqual(1)
    }
  })
}

for (const [language, title, yours, ready, add] of [
  ['en', 'Checklists', 'Your checklists', 'Ready to use', 'Add checklist'],
  ['es', 'Checklists', 'Tus checklists', 'Listos para usar', 'Agregar checklist'],
] as const) {
  test(`idioma ${language}: textos da tela de checklists`, async ({ page }) => {
    await startWithPrefs(page, { language })
    await login(page, 'admin', 'checklists')
    await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
    await expect(page.getByRole('heading', { level: 2, name: yours })).toBeVisible()
    await expect(page.getByRole('heading', { level: 2, name: ready })).toBeVisible()
  })

  test(`idioma ${language}: checklists na OS`, async ({ page }) => {
    const order = await makeOrder('admin')
    await startWithPrefs(page, { language })
    await login(page, 'admin', `orders?order=${order.id}`)
    await expect(page.getByTestId('add-checklist')).toHaveText(`+ ${add}`)
  })
}
