import { expect, test, type Page } from '@playwright/test'
import { expectNoAxeViolations, expectNoSideScroll, login, setTheme } from './helpers'

async function auditScreens(page: Page, theme: 'light' | 'dark') {
  await page.emulateMedia({ colorScheme: theme })
  await page.goto('login')
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
  await expectNoAxeViolations(page, `login ${theme}`)
  await login(page, 'admin', 'login')
  await setTheme(page, theme)

  for (const [path, title] of [
    ['./', 'Início'],
    ['orders', 'Ordens de Serviço'],
    ['settings', 'Configurações'],
    ['dev/components', 'Componentes'],
    ['nope', 'Página não encontrada'],
  ] as const) {
    await page.goto(path)
    await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
    await expect(page.getByText('Carregando…')).toHaveCount(path === 'dev/components' ? 1 : 0)
    await expectNoAxeViolations(page, `${path} ${theme}`)
  }

  await page.goto('orders?order=order-1')
  await expect(page.getByRole('complementary', { name: 'OS aberta' })).toBeVisible()
  await expectNoAxeViolations(page, `painel ${theme}`)

  await page.goto('dev/components')
  await page.getByRole('button', { name: 'Diálogo' }).click()
  await expectNoAxeViolations(page, `diálogo ${theme}`)
  await page.keyboard.press('Escape')
  await page.getByRole('button', { name: 'Painel lateral' }).click()
  await expectNoAxeViolations(page, `drawer ${theme}`)
  await page.keyboard.press('Escape')
  await page.getByRole('button', { name: 'Mostrar aviso' }).click()
  await page.getByRole('combobox', { name: 'Escolher' }).focus()
  await expectNoAxeViolations(page, `toast e combobox ${theme}`)
  await page.keyboard.press('ControlOrMeta+k')
  await expect(page.getByRole('dialog', { name: 'Buscar e comandos' })).toBeVisible()
  await expectNoAxeViolations(page, `paleta ${theme}`)
}

test('axe: 0 violações no tema claro', async ({ page }) => {
  await auditScreens(page, 'light')
})

test('axe: 0 violações no tema escuro', async ({ page }) => {
  await auditScreens(page, 'dark')
})

test('foco visível nos links da navegação', async ({ page }) => {
  await login(page, 'admin')
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
  await page.getByRole('link', { name: 'Clientes' }).first().focus()
  await page.keyboard.press('Shift+Tab')
  const outline = await page.evaluate(() => getComputedStyle(document.activeElement as Element).outlineStyle)
  expect(outline).toBe('solid')
})

test.describe('larguras e texto', () => {
  for (const [width, height] of [
    [320, 640],
    [390, 844],
    [820, 1180],
    [1366, 768],
    [2560, 1440],
  ] as const) {
    test(`${width} px sem rolagem lateral`, async ({ page }) => {
      await page.setViewportSize({ width, height })
      await login(page, 'admin', 'orders')
      await expect(page.getByTestId('orders-table')).toBeVisible()
      await expectNoSideScroll(page)
      await page.goto('settings')
      await expect(page.getByLabel('Tema')).toBeVisible()
      await expectNoSideScroll(page)
    })
  }

  test('celular usa abas embaixo', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 })
    await login(page, 'admin')
    await expect(page.getByRole('navigation', { name: 'Abas' })).toBeVisible()
    await expect(page.getByRole('complementary', { name: 'Navegação' })).toBeHidden()
    await page.getByRole('button', { name: 'Mais' }).click()
    await page.getByRole('link', { name: 'Clientes' }).click()
    await expect(page.getByRole('heading', { level: 1, name: 'Clientes' })).toBeVisible()
    await expect(page.getByRole('dialog')).toHaveCount(0)
  })

  for (const [width, height] of [
    [320, 640],
    [1366, 768],
  ] as const) {
    test(`texto a 200% em ${width} px: nada corta nem transborda`, async ({ page }) => {
      await page.setViewportSize({ width, height })
      await login(page, 'admin')
      await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
      for (const path of ['orders', 'settings', 'dev/components']) {
        await page.goto(path)
        await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
        await expect(page.locator('h1')).toBeVisible()
        await expectNoSideScroll(page)
      }
    })
  }
})

test.describe('preferências do sistema', () => {
  test.use({ reducedMotion: 'reduce' })
  test('movimento reduzido desliga transições', async ({ page }) => {
    await login(page, 'admin')
    const duration = await page.evaluate(() => getComputedStyle(document.querySelector('.nav-item') as Element).transitionDuration)
    expect(duration).toBe('0s')
  })
})

test('cores forçadas: situação continua visível', async ({ page }) => {
  await page.emulateMedia({ forcedColors: 'active' })
  await login(page, 'admin', 'dev/components')
  const background = await page.locator('.dot--success').first().evaluate((dot) => getComputedStyle(dot).backgroundColor)
  expect(background).not.toBe('rgba(0, 0, 0, 0)')
  await expect(page.locator('.status').first()).toBeVisible()
})

test('mais contraste é aplicado', async ({ page }) => {
  await page.emulateMedia({ contrast: 'more' })
  await login(page, 'admin', 'dev/components')
  const [muted, ink] = await page.evaluate(() => {
    const style = getComputedStyle(document.documentElement)
    return [style.getPropertyValue('--color-muted'), style.getPropertyValue('--color-ink')]
  })
  expect(muted?.trim()).toBe(ink?.trim())
})

test.describe('toque', () => {
  test.use({ hasTouch: true, isMobile: true, viewport: { width: 820, height: 1180 } })
  test('alvos de 44 px e sem dica de teclado', async ({ page }) => {
    await login(page, 'admin')
    await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
    const heights = await page.locator('.nav-item').evaluateAll((items) => items.map((item) => item.getBoundingClientRect().height))
    expect(Math.min(...heights)).toBeGreaterThanOrEqual(44)
    await expect(page.locator('.side-search kbd')).toBeHidden()
  })
})
