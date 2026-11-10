// Quick light/dark switch in the sidebar: one click flips the screen and the
// choice stays after reloading (Configurações › Neste navegador shows it).
import { expect, test } from './test'
import { login } from './helpers'

test('botão Modo escuro / Modo claro na barra lateral', async ({ page }) => {
  await page.emulateMedia({ colorScheme: 'light' })
  await login(page, 'admin')
  const html = page.locator('html')
  await expect(html).toHaveAttribute('data-theme', 'light')
  await page.getByTestId('theme-toggle').click()
  await expect(html).toHaveAttribute('data-theme', 'dark')
  await expect(page.getByTestId('theme-toggle')).toHaveText('Modo claro')
  await page.reload()
  await expect(html).toHaveAttribute('data-theme', 'dark')
  await page.getByTestId('theme-toggle').click()
  await expect(html).toHaveAttribute('data-theme', 'light')
  await expect(page.getByTestId('theme-toggle')).toHaveText('Modo escuro')
})
