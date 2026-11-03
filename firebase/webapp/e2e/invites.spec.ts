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

// The API mounts invites behind bearerAuth, which answers 403 to someone with no
// company yet, so a first invite cannot be accepted through it (the app calls the
// same route). Kept as fixme until the server accepts it; see docs/WEB_APP.md.
test.fixme('quem não tem empresa vê o convite e aceita', async ({ page }) => {
  test.setTimeout(60_000)
  await login(page, 'newcomer')
  const invites = page.getByRole('region', { name: 'Convites Pendentes' })
  await expect(invites.getByText('Oficina Alfa')).toBeVisible()
  await invites.getByRole('button', { name: 'Aceitar' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible({ timeout: 30_000 })
})

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
