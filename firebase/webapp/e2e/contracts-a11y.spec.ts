// Fatia 07 (contratos) on every screen: axe in light and dark, 320 to 2560 px
// without side scroll, text at 200%, and the three languages.
import { expect, test, type Page } from '@playwright/test'
import { makeContract, makeOrder, setCompanyFields } from './data'
import { COMPANY_C } from './fixtures.mjs'
import { expectNoAxeViolations, expectNoSideScroll, login, setTheme } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })

async function screens(page: Page, label: string) {
  const item = await makeContract('admin', { nextDueDate: '2020-01-01T00:00:00.000' })
  await makeContract('admin', { active: false, pausedAt: '2026-11-01T09:00:00.000' })
  await makeOrder('admin', { status: 'quote', contract: { parentOrderId: item.id, parentOrderNumber: item.number } })
  await page.goto('contracts')
  await expect(page.getByTestId('contracts-list')).toBeVisible()
  await expectNoAxeViolations(page, `contratos ${label}`)
  await page.locator(`[data-contract="${item.id}"]`).getByRole('button', { name: /Ajustar/ }).click()
  await expect(page.getByTestId('contract-editor')).toBeVisible()
  await expectNoAxeViolations(page, `ajustar ${label}`)
  await page.getByTestId('contract-stop').click()
  await expectNoAxeViolations(page, `parar ${label}`)
  await page.keyboard.press('Escape')
  await page.keyboard.press('Escape')
  await page.locator(`[data-contract="${item.id}"]`).getByRole('button', { name: new RegExp(`^${item.customer}`) }).click()
  await expect(panel(page).getByTestId('order-contract-generated')).toBeVisible()
  await expectNoAxeViolations(page, `contrato na OS ${label}`)
  await page.goto('contracts?order=')
  await page.getByTestId('contract-new').click()
  await expect(page.getByTestId('new-order-repeat')).toBeVisible()
  await expectNoAxeViolations(page, `novo contrato ${label}`)
}

for (const theme of ['light', 'dark'] as const) {
  const name = theme === 'light' ? 'claro' : 'escuro'
  test(`axe: 0 violações em contratos, tema ${name}`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: theme })
    await login(page, 'admin', 'login')
    await setTheme(page, theme)
    await screens(page, theme)
  })
}

test('axe: 0 violações em Contratos desligado', async ({ page }) => {
  await setCompanyFields(COMPANY_C, { useContracts: false })
  await login(page, 'noValues', 'contracts')
  await expect(page.getByTestId('contracts-off')).toBeVisible()
  await expectNoAxeViolations(page, 'contratos desligado')
})

for (const [width, height] of [
  [320, 640],
  [2560, 1440],
] as const) {
  test(`${width} px sem rolagem lateral em contratos`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    const item = await makeContract('admin')
    await login(page, 'admin', 'contracts')
    await expect(page.getByTestId('contracts-list')).toBeVisible()
    await expectNoSideScroll(page)
    await page.locator(`[data-contract="${item.id}"]`).getByRole('button', { name: /Ajustar/ }).click()
    const drawer = page.locator('.layer--drawer .layer-box')
    await expect(drawer).toBeVisible()
    expect(await drawer.evaluate((box) => box.scrollWidth - box.clientWidth)).toBeLessThanOrEqual(1)
  })
}

for (const [width, height] of [
  [320, 640],
  [1366, 768],
] as const) {
  test(`texto a 200% em ${width} px em contratos`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    const item = await makeContract('admin')
    await login(page, 'admin', 'contracts')
    await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await expect(page.getByTestId('contracts-list')).toBeVisible()
    await expectNoSideScroll(page)
    await page.locator(`[data-contract="${item.id}"]`).getByRole('button', { name: /Ajustar/ }).click()
    const drawer = page.locator('.layer--drawer .layer-box')
    await expect(drawer).toBeVisible()
    expect(await drawer.evaluate((box) => box.scrollWidth - box.clientWidth)).toBeLessThanOrEqual(1)
  })
}

for (const [language, title, active, ended, every] of [
  ['en', 'Contracts', 'Active', 'Ended', 'Every month'],
  ['es', 'Contratos', 'Activos', 'Terminados', 'Todos los meses'],
] as const) {
  test(`idioma ${language}: textos de contratos`, async ({ page }) => {
    const item = await makeContract('admin')
    await login(page, 'admin', 'contracts')
    await page.evaluate((value) => localStorage.setItem('praticos.prefs', JSON.stringify({ language: value })), language)
    await page.reload()
    await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
    await expect(page.getByTestId('contracts-tab-active')).toContainText(active)
    await expect(page.getByTestId('contracts-tab-ended')).toContainText(ended)
    await expect(page.locator(`[data-contract="${item.id}"]`)).toContainText(every)
  })
}
