import { expect, test } from './test'
import { login } from './helpers'

test('troca idioma e o texto muda na hora, e fica depois de recarregar', async ({ page }) => {
  await login(page, 'admin', 'settings')
  await page.getByLabel('Idioma').selectOption('en')
  await expect(page.getByRole('heading', { level: 1, name: 'Settings' })).toBeVisible()
  await expect(page.locator('html')).toHaveAttribute('lang', 'en')
  await expect(page).toHaveTitle(/Settings/)
  await page.getByLabel('Language').selectOption('es')
  await expect(page.locator('html')).toHaveAttribute('lang', 'es')
  await page.reload()
  await expect(page.getByLabel('Idioma')).toHaveValue('es')
  await expect(page.locator('html')).toHaveAttribute('lang', 'es')
})

test('o idioma não muda a moeda: Brasil em inglês continua R$', async ({ page }) => {
  await login(page, 'admin', 'settings')
  await page.getByLabel('Idioma').selectOption('en')
  await page.goto('dev/components')
  await expect(page.locator('.money-symbol')).toHaveText('R$')
  await expect(page.getByLabel('Price')).toHaveValue('90,00')
})

test('troca tema, e o escuro não pisca depois de recarregar', async ({ page }) => {
  await login(page, 'admin', 'settings')
  await page.getByLabel('Tema').selectOption('dark')
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
  await page.getByLabel('Tema').selectOption('light')
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'light')
  await page.getByLabel('Tema').selectOption('dark')
  await page.reload()
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
})

test('tema do sistema é seguido', async ({ browser }) => {
  const context = await browser.newContext({ colorScheme: 'dark' })
  const page = await context.newPage()
  await page.goto(`http://127.0.0.1:${process.env.PW_PORT ?? 4183}/web/login`)
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark')
  await context.close()
})

test('segmento troca o rótulo da situação, com i18n de reserva', async ({ page }) => {
  await login(page, 'admin', 'dev/components')
  await expect(page.locator('.status').filter({ hasText: 'Na oficina' }).first()).toBeVisible()
})

test('atalhos: paleta traz Nova OS, ? lista, e dá para desligar teclas simples', async ({ page }) => {
  await login(page, 'admin')
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
  await page.keyboard.press('ControlOrMeta+k')
  const palette = page.getByRole('dialog', { name: 'Buscar e comandos' })
  await expect(palette).toBeVisible()
  await expect(palette.getByRole('option', { name: /Nova OS/ })).toBeVisible()
  await palette.getByRole('combobox').fill('zzz')
  await expect(page.getByText('Nada encontrado.')).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await page.keyboard.press('?')
  await expect(page.getByRole('dialog', { name: 'Atalhos do teclado' })).toBeVisible()
  await page.keyboard.press('Escape')
  await page.goto('settings')
  await page.getByLabel('Usar atalhos de uma tecla').uncheck()
  await page.locator('h1').click()
  await page.keyboard.press('?')
  await expect(page.getByRole('dialog')).toHaveCount(0)
})
