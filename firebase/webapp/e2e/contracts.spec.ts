// Fatia 07, contratos (contract.*, order.contract.*, order.new.repeat), against
// the Emulator Suite. The contract lives in the order (isContract + contract,
// OrderContract.toJson) and the web writes it in the app's shape: dates as the
// company's local time without a zone. The web never creates the orders of a
// contract: no test here expects one. Each test makes the contracts it uses;
// company A has Contratos on, company C has it off.
import { expect, test, type Page } from './test'
import { brShown, brWall, makeContract, makeOrder, readCompany, readOrder, setCompanyFields, writeOrderFieldsRaw } from './data'
import { COMPANY_C } from './fixtures.mjs'
import { login, signOut, type UserKey } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const editor = (page: Page) => page.getByTestId('contract-editor')
const row = (page: Page, id: string) => page.locator(`[data-contract="${id}"]`)
const contractOf = async (id: string) => (await readOrder(id))?.contract as Record<string, unknown>

async function openContracts(page: Page, user: UserKey) {
  await login(page, user, 'contracts')
  await expect(page.getByRole('heading', { level: 1, name: 'Contratos' })).toBeVisible()
  await expect(page.getByText('Carregando…')).toHaveCount(0)
}

test('Ajustes leva a Contratos: ativos e encerrados, linha com cliente, frequência, aparelho e próxima OS (settings.open-contracts, contract.list.view, contract.list.switch, contract.list.row, contract.title.label)', async ({ page }) => {
  const active = await makeContract('admin', { frequency: 'weekly', interval: 2, nextDueDate: brWall(5) })
  const ended = await makeContract('admin', { active: false, endDate: brWall(-3) })
  await login(page, 'admin', 'settings')
  await page.getByTestId('settings-contracts').click()
  await expect(page.getByRole('heading', { level: 1, name: 'Contratos' })).toBeVisible()
  await expect(row(page, active.id)).toContainText(active.customer)
  await expect(row(page, active.id)).toContainText('A cada 2 semanas · Veículo 2')
  await expect(row(page, active.id)).toContainText(`Próxima OS em ${brShown(brWall(5))}`)
  await expect(row(page, ended.id)).toHaveCount(0)
  await page.getByTestId('contracts-tab-ended').click()
  await expect(row(page, ended.id)).toContainText(`Encerrado em ${brShown(brWall(-3))}`)
  await expect(row(page, active.id)).toHaveCount(0)
})

test('próxima OS que passou do dia diz que nasce quando alguém abrir o app; o web não cria (contract.generate.startup)', async ({ page }) => {
  const late = await makeContract('admin', { nextDueDate: brWall(-2) })
  await openContracts(page, 'admin')
  await expect(row(page, late.id)).toContainText(`Próxima OS prevista para ${brShown(brWall(-2))}. Ela nasce quando alguém da equipe abrir o app.`)
  // Nothing was created from it.
  expect((await contractOf(late.id)).generatedCount).toBe(0)
  expect((await contractOf(late.id)).nextDueDate).toBe(brWall(-2))
})

test('a linha abre a OS ao lado com o contrato, as OS criadas por ele e o caminho de volta (contract.list.open, order.contract.card, order.contract.children, order.contract.open-parent)', async ({ page }) => {
  const template = await makeContract('admin', { nextDueDate: brWall(12) })
  const child = await makeOrder('admin', { status: 'quote', contract: { parentOrderId: template.id, parentOrderNumber: template.number } })
  await openContracts(page, 'admin')
  await row(page, template.id).getByRole('button', { name: new RegExp(`^${template.customer}`) }).click()
  const card = panel(page).getByTestId('order-contract')
  await expect(card).toContainText('Todo mês')
  await expect(card).toContainText(`Próxima OS em ${brShown(brWall(12))}`)
  await expect(card.getByTestId('order-contract-generated')).toContainText(`OS ${child.number}`)
  await card.getByRole('button', { name: `OS ${child.number}` }).click()
  await expect(page).toHaveURL(new RegExp(`order=${child.id}`))
  await panel(page).getByTestId('order-contract-parent').click()
  await expect(page).toHaveURL(new RegExp(`order=${template.id}`))
  await expect(panel(page).getByTestId('order-contract')).toContainText('Todo mês')
})

test('Novo contrato: Nova OS com Repetir ligado grava o contrato no formato do app (contract.list.new, order.new.repeat, contract.config.defaults)', async ({ page }) => {
  await openContracts(page, 'admin')
  await page.getByTestId('contract-new').click()
  const drawer = page.getByTestId('new-order-drawer')
  await expect(drawer.getByRole('heading', { level: 2, name: 'Novo contrato' })).toBeVisible()
  await page.getByRole('combobox', { name: 'Cliente' }).fill('Cliente 01')
  await expect(page.getByRole('option', { name: /^Cliente 01/ })).toBeVisible()
  await page.keyboard.press('Enter')
  await expect(drawer.getByTestId('no-next')).toHaveText(/^Próxima OS em \d{2}\/\d{2}\/\d{4}$/)
  await drawer.getByLabel('Com que frequência?').selectOption({ label: 'A cada 3 meses' })
  await page.getByTestId('save-order').click()
  await expect(page).toHaveURL(/\/contracts\?order=/)
  const id = new URL(page.url()).searchParams.get('order') as string
  await expect.poll(async () => (await readOrder(id))?.isContract).toBe(true)
  const contract = await contractOf(id)
  expect(contract).toMatchObject({
    frequency: 'monthly',
    interval: 3,
    startDate: brWall(0),
    endDate: null,
    lastGeneratedDate: null,
    generatedCount: 0,
    autoGenerate: true,
    active: true,
    reminderDaysBefore: 3,
    parentOrderId: null,
  })
  expect(contract.nextDueDate).toMatch(/^\d{4}-\d{2}-\d{2}T00:00:00\.000$/)
  expect('pausedAt' in contract).toBe(false)
  await expect(page.locator(`[data-contract="${id}"]`)).toContainText('A cada 3 meses')
  await expect(panel(page).getByTestId('order-contract')).toContainText('A cada 3 meses')
})

test('Ajustar grava só o que mudou: frequência, término e criar sozinha (contract.config.frequency, contract.config.dates, contract.config.auto)', async ({ page }) => {
  const item = await makeContract('admin', { reminderDaysBefore: 7, generatedCount: 4, lastGeneratedDate: `${brWall(-10).slice(0, 10)}T02:00:00.000` })
  await openContracts(page, 'admin')
  await row(page, item.id).getByRole('button', { name: `Ajustar o contrato de ${item.customer}` }).click()
  await expect(editor(page)).toBeVisible()
  await editor(page).getByLabel('Com que frequência?').selectOption({ label: 'Toda semana' })
  await editor(page).getByTestId('ce-no-end').uncheck()
  await editor(page).getByRole('textbox', { name: 'Termina', exact: true }).fill(brWall(60).slice(0, 10))
  await editor(page).getByTestId('ce-auto').uncheck()
  await expect(editor(page).getByTestId('ce-next')).toHaveText('Não cria a OS sozinho')
  await editor(page).getByTestId('contract-save').click()
  await expect(page.locator('.toast')).toContainText('Contrato salvo')
  const contract = await contractOf(item.id)
  expect(contract).toMatchObject({ frequency: 'weekly', interval: 1, endDate: brWall(60), autoGenerate: false, reminderDaysBefore: 7, generatedCount: 4, active: true })
  expect(contract.nextDueDate).toMatch(/T00:00:00\.000$/)
  expect(String(contract.nextDueDate) > brWall(-1)).toBe(true)
  await expect(row(page, item.id)).toContainText('Toda semana')
  await expect(row(page, item.id)).toContainText('Não cria a OS sozinho')
})

test('parar de repetir sem apagar o contrato; sem Pausar nem Retomar até o app reler o modelo (contract.config.stop)', async ({ page }) => {
  const item = await makeContract('admin', { nextDueDate: brWall(3) })
  await openContracts(page, 'admin')
  await row(page, item.id).getByRole('button', { name: `Ajustar o contrato de ${item.customer}` }).click()
  await expect(editor(page)).toBeVisible()
  // A1 of the #527 review: the app, reading its cache, would create an order of a paused contract and turn it back on.
  await expect(editor(page).getByTestId('contract-pause')).toHaveCount(0)
  await expect(editor(page).getByTestId('contract-resume')).toHaveCount(0)
  await expect(editor(page).getByText('Pausar', { exact: true })).toHaveCount(0)
  await editor(page).getByTestId('contract-stop').click()
  await page.getByRole('dialog', { name: 'Parar de repetir?' }).getByRole('button', { name: 'Parar de repetir' }).click()
  await expect(page.locator('.toast')).toContainText('O contrato fica em Encerrados')
  await expect.poll(async () => (await contractOf(item.id)).active).toBe(false)
  const stopped = await readOrder(item.id)
  expect(stopped?.isContract).toBe(true)
  const contract = stopped?.contract as Record<string, unknown>
  expect(contract.endDate).toBe(brWall(0))
  expect(contract.frequency).toBe('monthly')
  expect('pausedAt' in contract).toBe(false)
  await page.getByTestId('contracts-tab-ended').click()
  await expect(row(page, item.id)).toContainText(`Encerrado em ${brShown(brWall(0))}`)
})

test('o app mudou o mesmo contrato: nada é gravado por cima; mudou outra coisa da OS: grava (contract.config.frequency)', async ({ page }) => {
  const item = await makeContract('admin')
  await openContracts(page, 'admin')
  await row(page, item.id).getByRole('button', { name: `Ajustar o contrato de ${item.customer}` }).click()
  await editor(page).getByLabel('Com que frequência?').selectOption({ label: 'Todo ano' })
  // The app saves the whole order meanwhile, with another frequency.
  await writeOrderFieldsRaw(item.id, { 'contract.frequency': 'daily', updatedAt: '2026-11-03T10:00:00.000' })
  await editor(page).getByTestId('contract-save').click()
  await expect(editor(page).getByTestId('contract-error')).toContainText('Alguém mudou este contrato')
  expect((await contractOf(item.id)).frequency).toBe('daily')
  await expect(editor(page).getByLabel('Com que frequência?')).toHaveValue('daily:1')

  // Only an unrelated field changed: the save goes on over the new version.
  await editor(page).getByLabel('Com que frequência?').selectOption({ label: 'Todo ano' })
  await writeOrderFieldsRaw(item.id, { 'customer.name': `${item.customer} Ltda` })
  await editor(page).getByTestId('contract-save').click()
  await expect(page.locator('.toast')).toContainText('Contrato salvo')
  const saved = await readOrder(item.id)
  expect((saved?.contract as Record<string, unknown>).frequency).toBe('yearly')
  expect((saved?.customer as { name: string }).name).toBe(`${item.customer} Ltda`)
})

test('Repetir esta OS a partir da OS (order.contract.enable)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'quote' })
  await login(page, 'admin', `orders?order=${order.id}`)
  const card = panel(page).getByTestId('order-contract')
  await card.getByTestId('order-contract-enable').click()
  await expect(editor(page)).toBeVisible()
  await editor(page).getByLabel('Com que frequência?').selectOption({ label: 'Toda semana' })
  await editor(page).getByTestId('contract-save').click()
  await expect(page.locator('.toast')).toContainText('Agora ela se repete')
  await expect.poll(async () => (await readOrder(order.id))?.isContract).toBe(true)
  expect(await contractOf(order.id)).toMatchObject({ frequency: 'weekly', interval: 1, active: true, generatedCount: 0, startDate: brWall(0) })
  await expect(card).toContainText('Toda semana')
})

test('por papel: técnico vê só os seus e não cria; gerente vê todos, ajusta e não cria; consultor cria (contract.list.view, contract.list.new)', async ({ page }) => {
  const mine = await makeContract('technician', {}, { status: 'quote' })
  const admins = await makeContract('admin')
  await openContracts(page, 'technician')
  await expect(row(page, mine.id)).toBeVisible()
  await expect(row(page, admins.id)).toHaveCount(0)
  await expect(page.getByTestId('contract-new')).toHaveCount(0)
  // Technician edits in quote, like the order's main fields.
  await expect(row(page, mine.id).getByRole('button', { name: /Ajustar/ })).toBeVisible()
  await page.goto('settings')
  await signOut(page)

  await openContracts(page, 'manager')
  await expect(row(page, admins.id)).toBeVisible()
  await expect(row(page, mine.id)).toBeVisible()
  await expect(page.getByTestId('contract-new')).toHaveCount(0)
  await row(page, admins.id).getByRole('button', { name: /Ajustar/ }).click()
  await editor(page).getByTestId('ce-auto').uncheck()
  await editor(page).getByTestId('contract-save').click()
  await expect(page.locator('.toast')).toContainText('Contrato salvo')
  expect((await contractOf(admins.id)).autoGenerate).toBe(false)
  await page.goto('settings')
  await signOut(page)

  await openContracts(page, 'consultant')
  await expect(row(page, admins.id)).toHaveCount(0)
  await expect(page.getByTestId('contract-new')).toBeVisible()
})

test('supervisor (sem valores): a lista vem sem nenhum valor da OS (contract.list.view)', async ({ page }) => {
  const item = await makeContract('admin')
  const bodies: string[] = []
  page.on('response', async (response) => {
    if (response.url().includes(':runQuery')) bodies.push(await response.text().catch(() => ''))
  })
  await openContracts(page, 'supervisor')
  await expect(row(page, item.id)).toBeVisible()
  expect(bodies.length).toBeGreaterThan(0)
  for (const body of bodies) expect(body).not.toMatch(/"(total|paidAmount|services|products|transactions|payment)"/)
})

test('erro ao carregar mostra Tentar de novo; vazio de encerrados sem botão (contract.list.view)', async ({ page }) => {
  await login(page, 'admin', 'settings')
  await page.route(/:runQuery/, (route) => route.abort())
  await page.getByTestId('settings-contracts').click()
  await expect(page.getByText('Não deu para carregar os contratos.')).toBeVisible()
  await page.unroute(/:runQuery/)
  await page.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(page.getByTestId('contracts-list').or(page.getByTestId('contracts-empty'))).toBeVisible()
})

test('Contratos desligado: o dono vê para que serve e liga (contract.off.view, contract.off.turn-on)', async ({ page }) => {
  await setCompanyFields(COMPANY_C, { useContracts: false })
  await login(page, 'noValues', 'contracts')
  await expect(page.getByTestId('contracts-off')).toContainText('Tem cliente fixo ou manutenção que se repete?')
  await page.getByTestId('contracts-turn-on').click()
  await expect(page.locator('.toast')).toContainText('Contratos ligado')
  await expect.poll(async () => (await readCompany(COMPANY_C))?.useContracts).toBe(true)
  await expect(page.getByTestId('contracts-empty')).toContainText('Nenhum contrato')
  await expect(page.getByTestId('contract-new')).toBeVisible()
  await setCompanyFields(COMPANY_C, { useContracts: false })
})
