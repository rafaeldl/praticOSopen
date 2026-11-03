// Fatia 07, Sua empresa: data, logo, terms, segment and the switches of
// company gamma (fixtures COMPANY_G), in order. Values and billing is switched
// off and on here, so no other test reads money in this company.
import { expect, test, type Page } from '@playwright/test'
import { COMPANY_G } from './fixtures.mjs'
import { login, newPersonPage } from './helpers'
import { readPath, writePath } from './settings-data'

test.describe.configure({ mode: 'serial' })

// 1x1 PNG.
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64')
const company = () => readPath(`companies/${COMPANY_G}`)
const toast = (page: Page) => page.locator('.toast')
const nav = (page: Page) => page.getByRole('navigation', { name: 'Principal' })

async function openCompany(page: Page, user: 'gAdmin' | 'gOwner' = 'gAdmin') {
  await login(page, user, 'settings/company')
  await expect(page.getByRole('heading', { level: 1, name: 'Sua empresa' })).toBeVisible()
  await expect(page.getByTestId('company-data')).toBeVisible()
}

test('Sua empresa: só dono e admin; carregando e erro com "Tentar de novo" (company.settings.view, settings.open-company)', async ({ page, browser }) => {
  for (const user of ['gManager', 'gTech'] as const) {
    const other = await newPersonPage(browser)
    await login(other, user, 'settings/company')
    await expect(other.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
    await other.goto('settings')
    await expect(other.getByTestId('settings-plan')).toBeVisible()
    await expect(other.getByTestId('settings-company')).toHaveCount(0)
    await other.context().close()
  }
  await login(page, 'gAdmin', 'settings')
  // The company read waits, then fails: loading, then the error; retry reads it.
  let release: () => void = () => {}
  const gate = new Promise<void>((resolve) => (release = resolve))
  await page.route('**/documents:batchGet**', async (route) => {
    await gate
    await route.abort()
  })
  await page.getByTestId('settings-company').click()
  await expect(page.getByText('Carregando…')).toBeVisible()
  release()
  await expect(page.getByRole('button', { name: 'Tentar de novo' })).toBeVisible()
  await page.unroute('**/documents:batchGet**')
  await page.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(page.getByTestId('company-data')).toContainText('Oficina Gama')
})

test('Nome, logo e contato: confere, máscara pelo país escolhido, logo só ao salvar e pergunta antes de descartar (company.data.edit, company.data.logo, company.data.country, company.data.discard)', async ({ page }) => {
  await openCompany(page)
  await page.getByTestId('company-data').click()
  const form = page.getByTestId('company-form')
  await expect(form.getByLabel('Nome', { exact: true })).toHaveValue('Oficina Gama')
  await form.getByLabel('Nome', { exact: true }).fill('')
  await form.getByTestId('save-company').click()
  await expect(form.getByText('Escreva o nome que aparece na OS').first()).toBeVisible()
  await form.getByLabel('Nome', { exact: true }).fill('Oficina Gama Nova')
  if (!(await form.locator('details.more-options').evaluate((details) => (details as HTMLDetailsElement).open))) await form.getByText('Mais dados (e-mail, site, país)').click()
  await form.getByLabel('E-mail').fill('contato@')
  await form.getByLabel('Site').fill('nao tem')
  await form.getByTestId('save-company').click()
  await expect(form.locator('.field-error', { hasText: 'Email inválido' })).toBeVisible()
  await expect(form.locator('.field-error', { hasText: 'Confira o site, por exemplo www.empresa.com.br' })).toBeVisible()
  await form.getByLabel('E-mail').fill('contato@gama.test')
  await form.getByLabel('Site').fill('www.gama.test')
  // The mask follows the country picked here, translated and complete.
  // Only countries with a money format and a zone (B2 of the #528 review): no Germany, Angola yes.
  await expect(form.getByTestId('company-country').locator('option', { hasText: /^Alemanha$/ })).toHaveCount(0)
  await expect(form.getByTestId('company-country').locator('option', { hasText: /^Angola$/ })).toHaveCount(1)
  await form.getByTestId('company-country').selectOption('US')
  await form.getByLabel('Telefone').fill('2125550100')
  await expect(form.getByLabel('Telefone')).toHaveValue('(212) 555-0100')
  // The logo waits for Salvar.
  await form.getByTestId('company-logo-file').setInputFiles({ name: 'logo.png', mimeType: 'image/png', buffer: PNG })
  await expect(form.getByTestId('company-logo')).toBeVisible()
  expect((await company())?.logo).toBeUndefined()

  // Leaving with changes asks; staying keeps everything typed.
  page.once('dialog', (dialog) => dialog.dismiss())
  await page.keyboard.press('Escape')
  await expect(form).toBeVisible()
  await expect(form.getByLabel('Nome', { exact: true })).toHaveValue('Oficina Gama Nova')

  await form.getByTestId('save-company').click()
  await expect(toast(page)).toContainText('Salvo')
  await expect(form).toBeHidden()
  await expect.poll(async () => (await company())?.name).toBe('Oficina Gama Nova')
  const saved = (await company())!
  expect(saved).toMatchObject({ email: 'contato@gama.test', site: 'www.gama.test', country: 'US', phone: '(212) 555-0100', updatedBy: { name: 'Gil Admin' } })
  expect(String(saved.logo)).toContain('logo.jpg')
  await expect(page.getByTestId('company-data')).toContainText('Oficina Gama Nova')

  // Discarding: nothing is written.
  await page.getByTestId('company-data').click()
  await form.getByLabel('Nome', { exact: true }).fill('Nome descartado')
  page.once('dialog', (dialog) => dialog.accept())
  await page.keyboard.press('Escape')
  await expect(form).toBeHidden()
  expect((await company())?.name).toBe('Oficina Gama Nova')
  await writePath(`companies/${COMPANY_G}`, { name: 'Oficina Gama', country: 'BR' })
})

test('Dados da empresa: grava só o que mudou e não grava por cima de quem salvou depois (company.data.edit, B1 da revisão do #528)', async ({ page }) => {
  await openCompany(page)
  await page.getByTestId('company-data').click()
  const form = page.getByTestId('company-form')
  await form.getByLabel('Nome', { exact: true }).fill('Gama Conflito')
  // Someone saves from the app while the form is open.
  await writePath(`companies/${COMPANY_G}`, { address: 'Rua do App, 1', updatedAt: new Date().toISOString() })
  await form.getByTestId('save-company').click()
  await expect(form.getByRole('alert')).toHaveText('Alguém salvou os dados da empresa depois que você abriu. Feche e abra de novo para ver o que mudou.')
  expect((await company())?.name).toBe('Oficina Gama')
  expect((await company())?.address).toBe('Rua do App, 1')
  page.once('dialog', (dialog) => dialog.accept())
  await form.getByLabel('Nome', { exact: true }).focus()
  await page.keyboard.press('Escape')
  // Opened again: the new version; saving the name keeps the app's address.
  await page.getByTestId('company-data').click()
  await expect(form.getByLabel('Endereço')).toHaveValue('Rua do App, 1')
  await form.getByLabel('Nome', { exact: true }).fill('Oficina Gama')
  await form.getByLabel('Endereço').fill('Rua do App, 1')
  await form.getByTestId('save-company').click()
  await expect(form).toBeHidden()
  expect((await company())?.address).toBe('Rua do App, 1')
})

test('Termos para o cliente: texto padrão do ramo só com o campo vazio; vazio grava nulo (company.terms.edit, company.terms.default)', async ({ page }) => {
  await openCompany(page)
  await page.getByTestId('company-terms').click()
  const form = page.getByTestId('terms-form')
  await form.getByTestId('terms-default').click()
  await expect(form.getByLabel('Garantia e condições')).toHaveValue('Garantia de 90 dias para o serviço.')
  await expect(form.getByTestId('terms-default')).toHaveCount(0)
  await form.getByTestId('save-terms').click()
  await expect(form).toBeHidden()
  await expect.poll(async () => (await company())?.termsOfService).toBe('Garantia de 90 dias para o serviço.')
  await page.getByTestId('company-terms').click()
  await form.getByLabel('Garantia e condições').fill('   ')
  await form.getByTestId('save-terms').click()
  await expect(form).toBeHidden()
  await expect.poll(async () => (await company())?.termsOfService).toBeNull()
})

test('Especialidades e ramo: trocar o ramo pergunta antes e tira as especialidades (company.settings.subspecialties, company.settings.segment)', async ({ page }) => {
  await openCompany(page)
  await expect(page.getByTestId('company-segment')).toContainText('Mecânica')
  await page.getByTestId('company-specialties').click()
  await page.getByTestId('specialty-list').getByLabel('Carros').check()
  await page.getByTestId('specialties-save').click()
  await expect(page.getByTestId('company-specialties')).toContainText('Carros')
  await expect.poll(async () => (await company())?.subspecialties).toEqual(['cars'])
  await expect(page.getByTestId('company-useDeviceManagement')).toContainText('Controle de veículos')

  await page.getByTestId('company-segment').click()
  await page.getByTestId('segment-list').getByLabel('Eletrônica').check()
  await page.getByTestId('segment-save').click()
  const confirm = page.getByRole('dialog', { name: 'Trocar o ramo?' })
  await expect(confirm).toContainText('As especialidades marcadas saem.')
  await confirm.getByRole('button', { name: 'Trocar o ramo' }).click()
  await expect(toast(page)).toContainText('Ramo trocado')
  await expect(page.getByTestId('company-segment')).toContainText('Eletrônica')
  await expect(page.getByTestId('company-specialties')).toHaveCount(0)
  const saved = (await company())!
  expect(saved.segment).toBe('electronics')
  expect(saved.subspecialties).toBeNull()

  await page.getByTestId('company-segment').click()
  await page.getByTestId('segment-list').getByLabel('Mecânica').check()
  await page.getByTestId('segment-save').click()
  await page.getByRole('dialog', { name: 'Trocar o ramo?' }).getByRole('button', { name: 'Trocar o ramo' }).click()
  await expect(page.getByTestId('company-segment')).toContainText('Mecânica')
})

test('Interruptores mudam na hora e voltam com aviso se a gravação falhar (company.settings.scheduling, company.settings.field-service, company.settings.contracts, company.settings.devices, company.settings.revert-on-fail)', async ({ page }) => {
  await openCompany(page)
  const sw = (feature: string) => page.getByTestId(`company-${feature}`).getByRole('switch')
  await expect(sw('useScheduling')).toBeChecked()
  await sw('useScheduling').uncheck()
  await expect.poll(async () => (await company())?.useScheduling).toBe(false)
  await sw('fieldService').check()
  await expect.poll(async () => (await company())?.fieldService).toBe(true)
  await sw('useContracts').check()
  await expect.poll(async () => (await company())?.useContracts).toBe(true)
  await sw('useDeviceManagement').check()
  await expect.poll(async () => (await company())?.useDeviceManagement).toBe(true)
  // Device control on: Configurações shows the devices list.
  await page.goto('settings')
  await expect(page.getByTestId('settings-devices')).toHaveText(/Veículos/)
  await page.goto('settings/company')

  // A refused write: the switch goes back and says so.
  await page.evaluate(() => sessionStorage.setItem('praticos.e2e.failCompanyWrite', '1'))
  await sw('useScheduling').click()
  await expect(toast(page)).toContainText('Não deu para salvar. Confira a internet e tente de novo.')
  await expect(sw('useScheduling')).not.toBeChecked()
  expect((await company())?.useScheduling).toBe(false)
  await page.evaluate(() => sessionStorage.removeItem('praticos.e2e.failCompanyWrite'))
  await sw('useScheduling').check()
  await expect.poll(async () => (await company())?.useScheduling).toBe(true)
})

test('Valores e cobrança desligado em outro lugar (app ou outra aba) some do web aberto na hora (company.settings.financial, M3 da revisão do #528)', async ({ page }) => {
  await login(page, 'gOwner')
  await page.evaluate(() => ((window as unknown as { stayed: boolean }).stayed = true))
  await expect(nav(page).getByRole('link', { name: 'Financeiro' })).toBeVisible()
  await writePath(`companies/${COMPANY_G}`, { useFinancial: false })
  await expect(nav(page).getByRole('link', { name: 'Financeiro' })).toHaveCount(0, { timeout: 15_000 })
  await writePath(`companies/${COMPANY_G}`, { useFinancial: true })
  await expect(nav(page).getByRole('link', { name: 'Financeiro' })).toBeVisible({ timeout: 15_000 })
  expect(await page.evaluate(() => (window as unknown as { stayed?: boolean }).stayed)).toBe(true)
})

test('Valores e cobrança: desligar pergunta e some na hora para todos, sem recarregar; religar volta (company.settings.financial)', async ({ page, browser }) => {
  await page.setViewportSize({ width: 1440, height: 900 })
  await openCompany(page, 'gOwner')
  await page.evaluate(() => ((window as unknown as { stayed: boolean }).stayed = true))
  await expect(nav(page).getByRole('link', { name: 'Financeiro' })).toBeVisible()
  const values = page.getByTestId('company-useFinancial').getByRole('switch')
  await values.click()
  const confirm = page.getByRole('dialog', { name: 'Desligar valores e cobrança?' })
  await confirm.getByRole('button', { name: 'Cancelar' }).click()
  await expect(values).toBeChecked()
  expect((await company())?.useFinancial).not.toBe(false)

  await values.click()
  await page.getByRole('dialog', { name: 'Desligar valores e cobrança?' }).getByRole('button', { name: 'Desligar' }).click()
  await expect(nav(page).getByRole('link', { name: 'Financeiro' })).toHaveCount(0)
  expect(await page.evaluate(() => (window as unknown as { stayed?: boolean }).stayed)).toBe(true)
  await expect.poll(async () => (await company())?.useFinancial).toBe(false)
  // The table of roles marks the money permissions as off.
  await page.getByRole('link', { name: 'Equipe' }).first().click()
  await expect(page.getByTestId('permission-table').getByRole('row', { name: /Ver preços e totais/ }).getByRole('cell').first()).toContainText('Desligado em Valores e cobrança')
  // The manager (a money role) sees no Financeiro either.
  const manager = await newPersonPage(browser)
  await login(manager, 'gManager')
  await expect(nav(manager).getByRole('link', { name: 'Início' })).toBeVisible()
  await expect(nav(manager).getByRole('link', { name: 'Financeiro' })).toHaveCount(0)
  await manager.goto('finance')
  await expect(manager.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
  await manager.context().close()

  await page.goto('settings/company')
  await page.getByTestId('company-useFinancial').getByRole('switch').check()
  await expect(nav(page).getByRole('link', { name: 'Financeiro' })).toBeVisible()
  await expect.poll(async () => (await company())?.useFinancial).toBe(true)
})
