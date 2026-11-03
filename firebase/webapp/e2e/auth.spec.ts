import { expect, test } from '@playwright/test'
import { PASSWORD, USERS } from './fixtures.mjs'
import { login } from './helpers'

test('entra com e-mail e vê a casca', async ({ page }) => {
  await login(page, 'admin')
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
  await expect(page.getByRole('complementary', { name: 'Navegação' })).toBeVisible()
  await expect(page.getByText('Oficina Alfa')).toBeVisible()
  await expect(page).toHaveTitle(/Início · PraticOS/)
})

test('senha errada explica sem mostrar erro técnico', async ({ page }) => {
  await page.goto('./')
  await page.getByLabel('E-mail').fill(USERS.admin.email)
  await page.getByLabel('Senha').fill(`${PASSWORD}-errada`)
  await page.getByRole('button', { name: 'Entrar' }).click()
  await expect(page.getByRole('alert')).toHaveText('E-mail ou senha não conferem.')
  await expect(page.locator('body')).not.toContainText('auth/')
})

test('sem entrar, URL direta pede login e volta para onde ia', async ({ page }) => {
  await page.goto('customers')
  await expect(page).toHaveURL(/login\?next=\/customers/)
  await page.getByLabel('E-mail').fill(USERS.admin.email)
  await page.getByLabel('Senha').fill(PASSWORD)
  await page.getByRole('button', { name: 'Entrar' }).click()
  await expect(page).toHaveURL(/\/app\/customers$/)
})

test('next externo não sai do app', async ({ page }) => {
  await page.goto('login?next=//example.test/x')
  await page.getByLabel('E-mail').fill(USERS.admin.email)
  await page.getByLabel('Senha').fill(PASSWORD)
  await page.getByRole('button', { name: 'Entrar' }).click()
  await expect(page).toHaveURL(/127\.0\.0\.1:\d+\/app\/$/)
})

test('conta sem empresa vê a explicação e pode sair', async ({ page }) => {
  await login(page, 'noCompany')
  await expect(page.getByRole('heading', { level: 1, name: 'Sua conta ainda não está em uma empresa' })).toBeVisible()
  await expect(page).toHaveURL(/no-company/)
  await page.getByRole('button', { name: 'Sair' }).click()
  await expect(page.getByLabel('E-mail')).toBeVisible()
})

test('dono de duas empresas troca, e a moeda segue a empresa', async ({ page }) => {
  await login(page, 'owner', 'dev/components')
  await expect(page.getByTestId('money-value')).toHaveText('90')
  await expect(page.locator('.money-symbol')).toHaveText('R$')
  await page.getByLabel('Empresa').selectOption({ label: 'Beta Repairs' })
  await expect(page.locator('.money-symbol')).toHaveText('$')
  await expect(page.getByLabel('Preço')).toHaveValue('90.00')
})

test('sair limpa a sessão', async ({ page }) => {
  await login(page, 'admin', 'settings')
  await page.getByRole('button', { name: 'Sair' }).click()
  await expect(page.getByLabel('E-mail')).toBeVisible()
  await page.goto('orders')
  await expect(page).toHaveURL(/login/)
})
