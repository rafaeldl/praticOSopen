// Fatia 07, Integrações: MCP connections (real API in the emulator) and the
// Asaas connection (the routes that reach Asaas are answered by the test: no
// Asaas account exists in the emulator). Owner and admin only.
import { expect, test, type Page } from './test'
import { COMPANY_G } from './fixtures.mjs'
import { login, newPersonPage } from './helpers'
import { listPath } from './settings-data'

test.describe.configure({ mode: 'serial' })

const toast = (page: Page) => page.locator('.toast')
const tokensOf = async () => (await listPath('apiKeys')).filter((key) => key.companyId === COMPANY_G && key.type === 'mcp')

test('Só dono e admin abrem Integrações (integrations.list, advanced.integrations)', async ({ browser }) => {
  for (const [user, allowed] of [
    ['gManager', false],
    ['gTech', false],
    ['gOwner', true],
  ] as const) {
    const page = await newPersonPage(browser)
    await login(page, user, 'settings/integrations')
    if (allowed) await expect(page.getByRole('heading', { level: 1, name: 'Integrações' })).toBeVisible()
    else await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
    await page.context().close()
  }
})

test('Nova conexão: o endereço aparece uma vez só, copiar, e desligar pede confirmação (integrations.new, integrations.copy, integrations.revoke)', async ({ page, context }) => {
  await context.grantPermissions(['clipboard-read', 'clipboard-write'])
  await login(page, 'gAdmin', 'settings/integrations')
  await expect(page.getByTestId('mcp-empty')).toBeVisible()
  await page.getByTestId('mcp-new').click()
  const dialog = page.getByRole('dialog', { name: 'Nova conexão' })
  await dialog.getByTestId('mcp-create').click()
  await expect(dialog.getByText('Dê um nome para a conexão.')).toBeVisible()
  await dialog.getByLabel('Nome').fill('Meu Claude')
  await dialog.getByTestId('mcp-create').click()
  const shown = page.getByTestId('mcp-url')
  await expect(shown).toContainText('Copie esta URL agora. Ela não será exibida novamente.')
  const url = (await shown.locator('.code-box').textContent())!.trim()
  expect(url).toMatch(/\/mcp\/t\/mcp_[0-9a-f]{48}$/)
  await page.getByTestId('mcp-copy').click()
  await expect(toast(page)).toContainText('URL copiada')
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(url)
  await page.keyboard.press('Escape')
  const list = page.getByTestId('mcp-list')
  await expect(list).toContainText('Meu Claude')
  await expect(list).toContainText('Nunca usada')
  // Never again: not in the list, not after a reload.
  await expect(page.getByText(url)).toHaveCount(0)
  await page.reload()
  await expect(page.getByTestId('mcp-list')).toContainText('Meu Claude')
  await expect(page.getByText(url)).toHaveCount(0)

  await page.getByRole('button', { name: 'Desligar a conexão Meu Claude' }).click()
  const confirm = page.getByRole('dialog', { name: 'Meu Claude' })
  await expect(confirm).toContainText('Quem estiver usando esta URL perde o acesso.')
  await confirm.getByRole('button', { name: 'Desligar conexão' }).click()
  await expect(toast(page)).toContainText('Conexão desligada')
  await expect(page.getByTestId('mcp-empty')).toBeVisible()
  expect((await tokensOf()).every((key) => key.active === false)).toBe(true)
})

test('Erro ao ler as conexões tem "Tentar de novo" (integrations.list)', async ({ page }) => {
  await login(page, 'gAdmin', 'settings')
  await page.route('**/v1/app/integrations/tokens', (route) => route.fulfill({ status: 500, contentType: 'application/json', body: '{"success":false,"error":{"code":"INTERNAL_ERROR"}}' }))
  await page.getByTestId('settings-integrations').click()
  await expect(page.getByRole('button', { name: 'Tentar de novo' })).toBeVisible()
  await page.unroute('**/v1/app/integrations/tokens')
  await page.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(page.getByTestId('mcp-empty')).toBeVisible()
})

test('Asaas: conectar com a chave, chave recusada, conta e ambiente, abrir o painel e desconectar com confirmação (asaas.section, asaas.connect, asaas.status, asaas.open-panel, asaas.disconnect)', async ({ page }) => {
  let answer: 'bad' | 'ok' = 'bad'
  const sent: unknown[] = []
  await page.route('**/v1/app/payments/asaas/connect', async (route) => {
    if (route.request().method() === 'DELETE') return route.fulfill({ status: 200, contentType: 'application/json', body: '{"success":true}' })
    sent.push(route.request().postDataJSON())
    if (answer === 'bad') return route.fulfill({ status: 400, contentType: 'application/json', body: JSON.stringify({ success: false, error: { code: 'ASAAS_INVALID_API_KEY', message: 'x' } }) })
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ success: true, data: { asaasEnabled: true, asaasConnected: true, asaasAccountName: 'Oficina Gama LTDA', asaasEnvironment: 'sandbox' } }),
    })
  })
  await login(page, 'gOwner', 'settings/integrations')
  const section = page.getByTestId('asaas-section')
  await expect(section.getByTestId('asaas-status')).toHaveText('Não conectado')
  await expect(section.getByTestId('asaas-panel')).toHaveAttribute('href', 'https://www.asaas.com/customerConfigIntegrations/index')
  await expect(section.getByTestId('asaas-panel')).toHaveAttribute('target', '_blank')
  await section.getByTestId('asaas-connect').click()
  await expect(section.getByTestId('asaas-error')).toHaveText('Cole a chave de API do Asaas.')
  await section.getByLabel('Chave de API').fill('$aact_chave_errada')
  await section.getByTestId('asaas-connect').click()
  await expect(section.getByTestId('asaas-error')).toHaveText('Chave de API inválida. Confira e tente de novo.')
  answer = 'ok'
  await section.getByLabel('Chave de API').fill('$aact_chave_boa')
  await section.getByTestId('asaas-connect').click()
  await expect(section.getByTestId('asaas-status')).toHaveText('Conectado')
  await expect(section).toContainText('Oficina Gama LTDA')
  await expect(section.getByTestId('asaas-environment')).toHaveText('Teste')
  expect(sent).toEqual([{ apiKey: '$aact_chave_errada' }, { apiKey: '$aact_chave_boa' }])
  // The key is never on screen again.
  await expect(page.getByLabel('Chave de API')).toHaveCount(0)

  await section.getByTestId('asaas-disconnect').click()
  const confirm = page.getByRole('dialog', { name: 'Desconectar' })
  await expect(confirm).toContainText('As cobranças em aberto continuam no Asaas')
  await confirm.getByRole('button', { name: 'Cancelar' }).click()
  await expect(section.getByTestId('asaas-status')).toHaveText('Conectado')
  await section.getByTestId('asaas-disconnect').click()
  await page.getByRole('dialog', { name: 'Desconectar' }).getByRole('button', { name: 'Desconectar' }).click()
  await expect(toast(page)).toContainText('Conta Asaas desconectada')
  await expect(section.getByTestId('asaas-status')).toHaveText('Não conectado')
})

test('Sem o piloto do Asaas, Pagamentos não aparece (asaas.section)', async ({ page }) => {
  await login(page, 'tAdmin', 'settings/integrations')
  await expect(page.getByTestId('mcp-empty')).toBeVisible()
  await expect(page.getByTestId('asaas-section')).toHaveCount(0)
})
