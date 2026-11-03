import { expect, test, type Page } from '@playwright/test'
import { expectNoAxeViolations, expectNoSideScroll, login, setTheme } from './helpers'

// The audit is split in four tests per theme (screens, open order, order lists, components):
// one test had grown to ~29 s of the 30 s budget on CI, and each axe run adds up.
type Theme = 'light' | 'dark'

async function start(page: Page, theme: Theme) {
  await page.emulateMedia({ colorScheme: theme })
  await page.goto('login')
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
  await expectNoAxeViolations(page, `login ${theme}`)
  await login(page, 'admin', 'login')
  await setTheme(page, theme)
}

async function auditScreens(page: Page, theme: Theme) {
  await start(page, theme)

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
}

async function auditOrderScreens(page: Page, theme: Theme) {
  await start(page, theme)
  // The order screens: open order with money, its menu and dialogs, Nova OS, board, batch.
  await page.goto('./?order=scn-owed')
  const panel = page.getByRole('complementary', { name: 'OS aberta' })
  await expect(panel.getByTestId('order-totals')).toBeVisible()
  await expectNoAxeViolations(page, `OS concluída ${theme}`)
  await panel.getByRole('button', { name: 'Mais ações' }).click()
  await expectNoAxeViolations(page, `menu da OS ${theme}`)
  await page.keyboard.press('Escape')
  await panel.getByTestId('next-step').click()
  await expect(page.getByRole('dialog', { name: 'Receber' })).toBeVisible()
  await expectNoAxeViolations(page, `receber ${theme}`)
  await page.keyboard.press('Escape')
  await panel.getByRole('button', { name: /^Mudar / }).first().click()
  await expectNoAxeViolations(page, `item ${theme}`)
  await page.keyboard.press('Escape')
}

/**
 * The list side of the order screens (held order, Nova OS, batch, board, months).
 * Its own test: with the open order and its dialogs it passed 30 s on CI, where
 * the sign-in alone took 5.5 s and each axe run about 1 s (#517).
 */
async function auditOrderLists(page: Page, theme: Theme) {
  await start(page, theme)
  await page.goto('./?order=scn-hold')
  await expect(page.getByTestId('hold-line')).toBeVisible()
  await expectNoAxeViolations(page, `OS parada ${theme}`)
  await page.goto('./')
  await page.getByTestId('new-order').click()
  await page.getByRole('combobox', { name: 'Cliente' }).fill('Cliente')
  await expectNoAxeViolations(page, `nova OS ${theme}`)
  await page.keyboard.press('Escape')
  await page.keyboard.press('Escape')
  await expect(page.getByRole('dialog', { name: 'Nova OS' })).toHaveCount(0)
  await page.getByTestId('orders-table').getByRole('checkbox').first().check()
  await expect(page.getByRole('region', { name: 'Ações nas OS selecionadas' })).toBeVisible()
  await expectNoAxeViolations(page, `lote ${theme}`)
  await page.goto('./?view=board')
  await expect(page.getByTestId('board')).toBeVisible()
  await expectNoAxeViolations(page, `quadro ${theme}`)
  await page.goto('./?f=all')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await expectNoAxeViolations(page, `todas por mês ${theme}`)
}

async function auditComponents(page: Page, theme: Theme) {
  await start(page, theme)
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

for (const [theme, name] of [['light', 'claro'], ['dark', 'escuro']] as const) {
  test(`axe: 0 violações no tema ${name}: telas`, async ({ page }) => {
    await auditScreens(page, theme)
  })

  test(`axe: 0 violações no tema ${name}: OS aberta`, async ({ page }) => {
    await auditOrderScreens(page, theme)
  })

  test(`axe: 0 violações no tema ${name}: lista, quadro e Nova OS`, async ({ page }) => {
    await auditOrderLists(page, theme)
  })

  test(`axe: 0 violações no tema ${name}: componentes`, async ({ page }) => {
    await auditComponents(page, theme)
  })
}

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
      await page.goto('orders?order=scn-late')
      await expect(page.getByTestId('order-detail')).toBeVisible()
      await expectNoSideScroll(page)
      await page.goto('orders?view=board')
      await expect(page.getByTestId('board')).toBeVisible()
      await expectNoSideScroll(page, ['.board'])
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
    await page.getByRole('button', { name: 'Mais', exact: true }).click()
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
      for (const path of ['orders', 'orders?order=scn-owed', 'settings', 'dev/components']) {
        await page.goto(path)
        await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
        // An open order takes the whole phone screen, without the page title.
        // The open order is measured with its totals in (they arrive after the header).
        await expect(path.includes('order=') ? page.getByTestId('order-totals') : page.locator('h1')).toBeVisible()
        await expectNoSideScroll(page)
      }
      // Nova OS with text at 200%: the drawer neither clips nor scrolls sideways.
      await page.goto('orders')
      await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
      await page.getByRole('button', { name: /Nova OS/ }).filter({ visible: true }).first().click()
      await expect(page.getByRole('dialog', { name: 'Nova OS' })).toBeVisible()
      const overflow = await page.evaluate(() => {
        const box = document.querySelector('.layer-box') as HTMLElement
        return box.scrollWidth - box.clientWidth
      })
      expect(overflow).toBeLessThanOrEqual(1)
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
