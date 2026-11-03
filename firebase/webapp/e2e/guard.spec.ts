import { expect, test } from '@playwright/test'
import { chooseCompany, login, type UserKey } from './helpers'

// Same matrix as app-permissions.json, read by URL.
const MATRIX: Record<string, { allowed: string[]; denied: string[] }> = {
  owner: { allowed: ['finance', 'team', 'catalog', 'customers', 'invoices'], denied: [] },
  admin: { allowed: ['finance', 'team', 'catalog', 'customers', 'invoices'], denied: [] },
  manager: { allowed: ['finance', 'catalog', 'customers', 'invoices'], denied: ['team'] },
  supervisor: { allowed: ['customers', 'orders'], denied: ['finance', 'team', 'invoices'] },
  consultant: { allowed: ['customers', 'orders'], denied: ['finance', 'team', 'invoices'] },
  technician: { allowed: ['customers', 'orders'], denied: ['finance', 'team', 'catalog', 'invoices'] },
}

for (const [role, { allowed, denied }] of Object.entries(MATRIX)) {
  test(`${role}: URL direta respeita o papel`, async ({ page }) => {
    await login(page, role as UserKey)
    if (role === 'owner') await chooseCompany(page, 'Oficina Alfa')
    await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
    for (const path of allowed) {
      await page.goto(path)
      await expect(page).toHaveURL(new RegExp(`/app/${path}$`))
      await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeHidden()
    }
    for (const path of denied) {
      await page.goto(path)
      await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
      await expect(page).toHaveURL(/forbidden/)
    }
  })
}

test('quem não pode não vê o link', async ({ page }) => {
  await login(page, 'technician')
  const nav = page.getByRole('navigation', { name: 'Principal' })
  await expect(nav.getByRole('link', { name: 'Ordens de Serviço' })).toBeVisible()
  await expect(nav.getByRole('link', { name: 'Financeiro' })).toHaveCount(0)
  await expect(nav.getByRole('link', { name: 'Equipe' })).toHaveCount(0)
})

test('dono vê a lista; quem não vê valores não lê a OS direto', async ({ page }) => {
  await login(page, 'admin', 'orders')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.goto('settings')
  await page.getByRole('button', { name: 'Sair' }).click()
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
  await login(page, 'supervisor', 'orders')
  await expect(page.getByRole('heading', { name: 'Esta tela ainda está sendo feita' })).toBeVisible()
  await expect(page.getByTestId('orders-table')).toHaveCount(0)
})

test('rota que não existe', async ({ page }) => {
  await login(page, 'admin', 'not-a-route')
  await expect(page.getByRole('heading', { name: 'Este endereço não existe' })).toBeVisible()
})

test('trocar de empresa passa pela guarda: admin em A, técnico em B, sai da Equipe', async ({ page }) => {
  await login(page, 'mixed', 'team')
  await chooseCompany(page, 'Oficina Alfa')
  await expect(page).toHaveURL(/\/team$/)
  await expect(page.getByRole('heading', { level: 1, name: 'Equipe' })).toBeVisible()
  await page.getByLabel('Empresa').selectOption({ label: 'Beta Repairs' })
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
  await expect(page).toHaveURL(/\/app\/$/)
  await expect(page.getByRole('navigation', { name: 'Principal' }).getByRole('link', { name: 'Equipe' })).toHaveCount(0)
})
