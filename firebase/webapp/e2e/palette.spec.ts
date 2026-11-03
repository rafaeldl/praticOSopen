// ⌘K from any screen (web.search.global): orders, customers, devices, catalog
// and actions in one field, each group only for who may open it.
import { expect, test, type Page } from '@playwright/test'
import { login, type UserKey } from './helpers'

const field = (page: Page) => page.getByRole('combobox', { name: /Buscar/ })
const group = (page: Page, name: string) => page.getByRole('listbox').getByRole('group', { name })

async function palette(page: Page, user: UserKey, path: string, query: string) {
  await login(page, user, path)
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
  // Under load the shortcut can arrive before the shell registers it: press again until the palette opens.
  await expect(async () => {
    if (!(await field(page).isVisible())) await page.keyboard.press('ControlOrMeta+k')
    await expect(field(page)).toBeVisible({ timeout: 1000 })
  }).toPass({ timeout: 15_000 })
  await field(page).fill(query)
}

test('admin, na Agenda: acha a OS pelo número e abre (web.search.global)', async ({ page }) => {
  await palette(page, 'admin', 'schedule', '501')
  const option = group(page, 'OS').getByRole('option', { name: /OS 501 · Cliente 03/ })
  await expect(option).toBeVisible()
  await field(page).press('Enter')
  await expect(page).toHaveURL(/order=scn-late/)
  await expect(page.getByRole('complementary', { name: 'OS aberta' })).toBeVisible()
})

test('admin: cliente, veículo pela placa, catálogo com preço e ações, cada um no seu grupo', async ({ page }) => {
  await palette(page, 'admin', 'schedule', 'Cliente 04')
  await expect(group(page, 'Clientes').getByRole('option', { name: /Cliente 04/ })).toBeVisible()
  await field(page).fill('TST0007')
  await expect(group(page, 'Veículos').getByRole('option', { name: /TST0007/ })).toBeVisible()
  await field(page).fill('Serviço 3')
  await expect(group(page, 'Catálogo').getByRole('option', { name: /Serviço 3.*R\$ 150,00/ })).toBeVisible()
  await field(page).fill('Peça 2')
  await expect(group(page, 'Catálogo').getByRole('option', { name: /Peça 2/ })).toBeVisible()
  await field(page).fill('notas')
  await expect(group(page, 'Ações').getByRole('option', { name: /Notas fiscais/ })).toBeVisible()
  await field(page).fill('TST0007')
  await group(page, 'Veículos').getByRole('option', { name: /TST0007/ }).click()
  await expect(page).toHaveURL(/devices\?.*device=device-7/)
})

test('admin: escolher um cliente abre a tela dele; uma ação leva à tela', async ({ page }) => {
  await palette(page, 'admin', 'schedule', 'Cliente 05')
  await group(page, 'Clientes').getByRole('option', { name: /Cliente 05/ }).click()
  await expect(page).toHaveURL(/customers\?.*customer=customer-5/)
  await page.keyboard.press('ControlOrMeta+k')
  await field(page).fill('catálogo')
  await field(page).press('ArrowDown')
  await group(page, 'Ações').getByRole('option', { name: /Catálogo/ }).click()
  await expect(page).toHaveURL(/\/catalog/)
})

test('supervisor: catálogo sem preço', async ({ page }) => {
  await palette(page, 'supervisor', 'schedule', 'Serviço 3')
  const option = group(page, 'Catálogo').getByRole('option', { name: /Serviço 3/ })
  await expect(option).toBeVisible()
  await expect(option).not.toContainText('R$')
})

test('técnico: sem catálogo, sem Financeiro e sem Notas fiscais', async ({ page }) => {
  await palette(page, 'technician', './', 'Serviço 3')
  await expect(page.getByRole('listbox')).toBeVisible()
  await expect(group(page, 'Catálogo')).toHaveCount(0)
  await field(page).fill('financeiro')
  await expect(page.getByRole('option', { name: /Financeiro/ })).toHaveCount(0)
  await field(page).fill('notas')
  await expect(page.getByRole('option', { name: /Notas fiscais/ })).toHaveCount(0)
  await field(page).fill('agenda')
  await expect(group(page, 'Ações').getByRole('option', { name: /Agenda/ })).toBeVisible()
})
