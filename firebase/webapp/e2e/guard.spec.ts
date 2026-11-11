import { expect, test } from './test'
import { chooseCompany, login, type UserKey, signOut } from './helpers'

// Same matrix as app-permissions.json, read by URL.
const MATRIX: Record<string, { allowed: string[]; denied: string[] }> = {
  owner: { allowed: ['settings/ratings', 'contracts', 'schedule', 'finance', 'finance/report', 'finance/receive', 'team', 'checklists', 'catalog', 'catalog/import', 'customers', 'customers/import', 'devices', 'invoices'], denied: [] },
  admin: { allowed: ['settings/ratings', 'contracts', 'schedule', 'finance', 'finance/report', 'finance/receive', 'team', 'checklists', 'catalog', 'catalog/import', 'customers', 'customers/import', 'devices', 'invoices'], denied: [] },
  manager: { allowed: ['contracts', 'schedule', 'finance', 'finance/report', 'finance/receive', 'catalog', 'customers', 'devices', 'invoices'], denied: ['settings/ratings', 'team', 'checklists', 'customers/import', 'catalog/import'] },
  supervisor: { allowed: ['contracts', 'schedule', 'checklists', 'catalog', 'customers', 'customers/import', 'devices', 'orders'], denied: ['settings/ratings', 'finance', 'finance/report', 'finance/receive', 'team', 'invoices', 'catalog/import'] },
  consultant: { allowed: ['contracts', 'schedule', 'catalog', 'customers', 'customers/import', 'devices', 'orders'], denied: ['settings/ratings', 'finance', 'finance/report', 'finance/receive', 'team', 'checklists', 'invoices', 'catalog/import'] },
  technician: { allowed: ['contracts', 'schedule', 'customers', 'devices', 'orders'], denied: ['settings/ratings', 'finance', 'finance/report', 'finance/receive', 'team', 'checklists', 'catalog', 'catalog/import', 'invoices', 'customers/import'] },
}

for (const [role, { allowed, denied }] of Object.entries(MATRIX)) {
  test(`${role}: URL direta respeita o papel`, async ({ page }) => {
    await login(page, role as UserKey)
    if (role === 'owner') await chooseCompany(page, 'Oficina Alfa')
    await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
    for (const path of allowed) {
      await page.goto(path)
      await expect(page).toHaveURL(new RegExp(`/web/${path}$`))
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
  await expect(nav.getByRole('link', { name: 'Início' })).toBeVisible()
  await expect(nav.getByRole('link', { name: 'Financeiro' })).toHaveCount(0)
  await expect(nav.getByRole('link', { name: 'Equipe' })).toHaveCount(0)
})

test('quem vê valores lê o Firestore; quem não vê usa a projeção da API, sem valores', async ({ page }) => {
  await login(page, 'admin', 'orders')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await expect(page.getByTestId('orders-table').getByRole('columnheader', { name: 'Total' })).toBeVisible()
  await page.goto('settings')
  await signOut(page)
  const apiList = page.waitForResponse((response) => /\/v1\/app\/orders\?/.test(response.url()))
  await login(page, 'supervisor', 'orders')
  const body = await (await apiList).json()
  // No money in any field of the projection.
  expect(JSON.stringify(body.data)).not.toMatch(/"(total|paidAmount|value|payment)"/)
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await expect(page.getByTestId('orders-table').getByRole('columnheader', { name: 'Total' })).toHaveCount(0)
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
  await expect(page).toHaveURL(/\/web\/$/)
  await expect(page.getByRole('navigation', { name: 'Principal' }).getByRole('link', { name: 'Equipe' })).toHaveCount(0)
})
