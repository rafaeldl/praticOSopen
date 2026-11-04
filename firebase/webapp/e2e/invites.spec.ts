// Accepting an invite on the web: API route, then the token gets the new company.
import { expect, test } from '@playwright/test'
import { chooseCompany, login } from './helpers'

test('quem já trabalha numa empresa aceita convite de outra e entra nela', async ({ page }) => {
  test.setTimeout(60_000)
  await login(page, 'invitee', 'settings')
  const invites = page.getByRole('region', { name: 'Convites Pendentes' })
  await expect(invites.getByText('Beta Repairs')).toBeVisible()
  await expect(invites.getByText('Supervisor')).toBeVisible()
  await invites.getByRole('button', { name: 'Aceitar' }).click()
  await expect(page.getByLabel('Empresa')).toHaveValue('company-beta', { timeout: 30_000 })
  await expect(invites).toHaveCount(0)
})

// Accepting a first invite without a company: e2e/entry.spec.ts (the API takes it since
// bearerAuthAllowingNoCompany, app-invites.mount.ts).
test('quem não tem empresa vê o convite pendente', async ({ page }) => {
  await login(page, 'newcomer')
  const invites = page.getByRole('region', { name: 'Convites Pendentes' })
  await expect(invites.getByText('Oficina Alfa')).toBeVisible()
  await expect(invites.getByText('Técnico · Convidado por Olivia Dona')).toBeVisible()
})

test('dono com duas empresas escolhe antes de entrar', async ({ page }) => {
  await login(page, 'owner', 'orders')
  await chooseCompany(page, 'Oficina Alfa')
  await expect(page).toHaveURL(/\/orders$/)
  await expect(page.getByTestId('orders-table')).toBeVisible()
})
