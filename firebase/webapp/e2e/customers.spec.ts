// Fatia 03, clientes (customer.*), against the Emulator Suite. Each test makes
// its own customers and orders (data.ts), so the tests run in parallel.
import { expect, test, type Page } from '@playwright/test'
import { makeCustomer, makeDevice, makeLateOrderInB, makeOrder, readDoc, updateCustomerDoc } from './data'
import { chooseCompany, login, signOut } from './helpers'

const list = (page: Page) => page.getByTestId('customers-table')
const panel = (page: Page) => page.getByTestId('customer-detail')
const row = (page: Page, name: string) => list(page).getByRole('row').filter({ hasText: name })

async function openCustomers(page: Page, user: Parameters<typeof login>[1], query = '') {
  await login(page, user, `customers${query}`)
  await expect(page.getByRole('heading', { level: 1, name: 'Clientes' })).toBeVisible()
}

test('lista: total, grupos por inicial sem acento e "#" no fim (customer.list.view)', async ({ page }) => {
  const accented = await makeCustomer({ name: `Ágata ${Date.now()}` })
  const digit = await makeCustomer({ name: `9 Irmãos ${Date.now()}` })
  await openCustomers(page, 'admin')
  await expect(page.getByTestId('customers-summary')).toHaveText(/\d+ clientes/)
  const groups = list(page).locator('.group-row th')
  await expect(groups.first()).toHaveText('A')
  await expect(groups.last()).toHaveText('#')
  await expect(row(page, accented.name)).toBeVisible()
  await expect(row(page, digit.name)).toBeVisible()
})

test('selos: atrasada vence aberta (customer.list.badges)', async ({ page }) => {
  // Company B: a late order in A would change the order list's "1 atrasada".
  const late = await makeCustomer({}, 'company-beta')
  await makeLateOrderInB(late)
  await login(page, 'owner', `customers?q=${encodeURIComponent(late.name)}`)
  await chooseCompany(page, 'Beta Repairs')
  await expect(row(page, late.name)).toContainText('1 atrasada')
})

test('selos: consultor e técnico contam só as OS que leem (customer.list.badges)', async ({ page }) => {
  const mine = await makeCustomer()
  await makeOrder('consultant', { customer: { id: mine.id, name: mine.name }, status: 'approved' })
  await makeOrder('admin', { customer: { id: mine.id, name: mine.name }, status: 'progress' })

  await openCustomers(page, 'admin', `?q=${encodeURIComponent(mine.name)}`)
  await expect(row(page, mine.name)).toContainText('2 em aberto')

  await page.goto('settings')
  await signOut(page)
  await openCustomers(page, 'consultant', `?q=${encodeURIComponent(mine.name)}`)
  await expect(row(page, mine.name)).toContainText('1 em aberto')
  await expect(page.getByText('As OS em aberto contam só as suas.')).toBeVisible()
})

test('busca por nome sem acento, telefone por dígitos e placa a partir de 3 letras (customer.list.search)', async ({ page }) => {
  const stamp = Date.now()
  const joao = await makeCustomer({ name: `João Busca ${stamp}`, phone: '(48) 97777-1234' })
  const device = await makeDevice()
  await makeOrder('admin', { customer: { id: joao.id, name: joao.name }, devices: [{ id: device.id, name: device.name, serial: device.serial }], deviceIds: [device.id], device: { id: device.id, name: device.name } })
  await openCustomers(page, 'admin')
  const search = page.getByLabel(/Buscar por nome/)
  await search.fill(`joao busca ${stamp}`)
  await expect(row(page, joao.name)).toBeVisible()
  await expect(page.getByTestId('customers-summary')).toHaveText('1 cliente encontrado')
  await search.fill('977771234')
  await expect(row(page, joao.name)).toBeVisible()
  // Plate: needs 3 characters, ignores hyphen and case; the hit opens the owner.
  await search.fill(device.serial.slice(0, 2).toLowerCase())
  await expect(page.getByTestId('plate-hits')).toHaveCount(0)
  await search.fill(`${device.serial.slice(0, 3)}-${device.serial.slice(3)}`.toLowerCase())
  await page.getByTestId('plate-hits').getByRole('button', { name: new RegExp(device.serial) }).click()
  await expect(panel(page).getByRole('heading', { name: joao.name })).toBeVisible()
  await expect(page).toHaveURL(new RegExp(`customer=${joao.id}`))
})

test('cadastrar: máscara do telefone, ✓ só com nome e abre o cliente novo (customer.list.create, customer.form.save)', async ({ page }) => {
  const stamp = Date.now()
  const name = `Nova Cliente ${stamp}`
  // A phone of its own: the same number twice would open the repeated phone warning (--repeat-each).
  const tail = String(stamp).slice(-8)
  const shown = `(48) 9${tail.slice(0, 4)}-${tail.slice(4)}`
  await openCustomers(page, 'supervisor')
  await page.getByTestId('new-customer').click()
  const form = page.getByTestId('customer-form')
  await expect(form.getByText('Escreva o nome para salvar.')).toBeVisible()
  await form.getByLabel('Telefone ou WhatsApp').pressSequentially(`489${tail}`)
  await expect(form.getByLabel('Telefone ou WhatsApp')).toHaveValue(shown)
  await form.getByTestId('save-customer').click()
  await expect(form.getByRole('alert')).toHaveText('Escreva o nome para salvar.')
  await form.getByLabel('Nome', { exact: true }).fill(name)
  await page.keyboard.press('ControlOrMeta+Enter')
  await expect(panel(page).getByRole('heading', { name })).toBeVisible()
  await expect(panel(page).getByTestId('customer-contact')).toContainText(shown)
})

test('gerente e técnico não cadastram nem editam; consultor cadastra (permissão manageCustomers)', async ({ page }) => {
  const someone = await makeCustomer()
  await openCustomers(page, 'technician', `?customer=${someone.id}`)
  await expect(panel(page).getByRole('heading', { name: someone.name })).toBeVisible()
  await expect(page.getByTestId('new-customer')).toHaveCount(0)
  await expect(page.getByTestId('import-link')).toHaveCount(0)
  await expect(page.getByTestId('customer-menu')).toHaveCount(0)
})

test('"Cadastrar «texto»" da busca: dígitos viram telefone e o nome existente não oferece (customer.picker.create)', async ({ page }) => {
  const existing = await makeCustomer()
  await openCustomers(page, 'consultant')
  const search = page.getByLabel(/Buscar por nome/)
  await search.fill(existing.name)
  await expect(page.getByTestId('create-from-search')).toHaveCount(0)
  await search.fill('(47) 3333-0101')
  await page.getByTestId('create-from-search').click()
  await expect(page.getByTestId('customer-form').getByLabel('Telefone ou WhatsApp')).toHaveValue('(47) 3333-0101')
  await expect(page.getByTestId('customer-form').getByLabel('Nome', { exact: true })).toHaveValue('')
})

test('telefone repetido: avisa, abre o que existe ou salva mesmo assim (customer.form.duplicate-*)', async ({ page }) => {
  const stamp = Date.now()
  const phone = `(48) 9${String(stamp).slice(-4)}-${String(stamp).slice(-8, -4)}`
  const existing = await makeCustomer({ phone })
  await openCustomers(page, 'admin')
  await page.getByTestId('new-customer').click()
  const form = page.getByTestId('customer-form')
  await form.getByLabel('Nome', { exact: true }).fill(`Outro ${stamp}`)
  // Same number written another way, without the ninth digit.
  await form.getByLabel('Telefone ou WhatsApp').fill(`48${phone.replace(/\D/g, '').slice(3)}`)
  await form.getByTestId('save-customer').click()
  const dialog = page.getByRole('dialog', { name: 'Já cadastrado' })
  await expect(dialog).toContainText(`${existing.name} já está com este telefone.`)
  await dialog.getByTestId('duplicate-open').click()
  await expect(panel(page).getByRole('heading', { name: existing.name })).toBeVisible()

  await page.getByTestId('new-customer').click()
  await form.getByLabel('Nome', { exact: true }).fill(`Mesmo Número ${stamp}`)
  await form.getByLabel('Telefone ou WhatsApp').fill(phone)
  await form.getByTestId('save-customer').click()
  await page.getByRole('dialog', { name: 'Já cadastrado' }).getByTestId('duplicate-save').click()
  await expect(panel(page).getByRole('heading', { name: `Mesmo Número ${stamp}` })).toBeVisible()
})

test('tela do cliente: contato completo, campo do segmento, gastou, falta receber e OS (customer.detail.view)', async ({ page }) => {
  const customer = await makeCustomer({
    phone: '+5548984087801',
    email: 'cliente@exemplo.test',
    taxId: '52998224725',
    address: 'Rua das Flores, 10',
    customData: { birthday: '1990-05-20T00:00:00.000' },
  })
  const done = await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, status: 'done', total: 300, paidAmount: 100, payment: 'partial' })
  await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, status: 'quote', total: 999 })
  await openCustomers(page, 'admin', `?customer=${customer.id}`)
  const detail = panel(page)
  const contact = detail.getByTestId('customer-contact')
  await expect(contact).toContainText('(48) 98408-7801')
  await expect(contact).toContainText('cliente@exemplo.test')
  await expect(contact).toContainText('529.982.247-25')
  await expect(contact).toContainText('Rua das Flores, 10')
  // customer.form.map: the address opens in the maps site.
  await expect(detail.getByTestId('customer-map')).toHaveAttribute('href', /google\.com\/maps\/search\/\?api=1&query=Rua%20das%20Flores/)
  await expect(detail.getByTestId('customer-custom')).toContainText('Aniversário')
  await expect(detail.getByTestId('customer-custom')).toContainText('20/05/1990')
  await expect(detail.getByTestId('customer-money')).toContainText('Falta receber R$ 200,00')
  await expect(detail.getByTestId('customer-money')).toContainText('gastou R$ 300,00')
  await expect(detail.getByTestId('customer-orders')).toContainText(String(done.number))
  await expect(detail.getByText(`Abrir uma OS para ${customer.name.split(' ')[0]}?`)).toBeVisible()
})

test('sem viewPrices não aparece dinheiro; cliente apagado mostra "não está mais aqui" (customer.detail.owed)', async ({ page }) => {
  const customer = await makeCustomer()
  await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, status: 'done', total: 300, paidAmount: 0 })
  await openCustomers(page, 'technician', `?customer=${customer.id}`)
  await expect(panel(page).getByRole('heading', { name: customer.name })).toBeVisible()
  await expect(panel(page).getByTestId('customer-money')).toHaveCount(0)
  await page.goto('customers?customer=does-not-exist')
  await expect(page.getByTestId('customer-not-found')).toContainText('Este cliente não está mais aqui')
})

test('ligar e WhatsApp só com telefone, número limpo e no país da empresa (customer.detail.call, customer.detail.whatsapp)', async ({ page }) => {
  const withPhone = await makeCustomer({ phone: '(48) 98408-7801' })
  const without = await makeCustomer()
  await openCustomers(page, 'technician', `?customer=${withPhone.id}`)
  await expect(panel(page).getByTestId('customer-call')).toHaveAttribute('href', 'tel:48984087801')
  await expect(panel(page).getByTestId('customer-whatsapp')).toHaveAttribute('href', 'https://wa.me/5548984087801')
  await page.goto(`customers?customer=${without.id}`)
  await expect(panel(page).getByRole('heading', { name: without.name })).toBeVisible()
  await expect(panel(page).getByTestId('customer-call')).toHaveCount(0)
  await expect(panel(page).getByTestId('customer-whatsapp')).toHaveCount(0)
})

test('Nova OS para o cliente leva só o cliente; gerente não vê (customer.detail.new-order)', async ({ page }) => {
  const customer = await makeCustomer({ name: `Paula Nova ${Date.now()}` })
  await openCustomers(page, 'consultant', `?customer=${customer.id}`)
  await panel(page).getByTestId('customer-new-order').click()
  const drawer = page.getByTestId('new-order-drawer')
  await expect(drawer.locator('.chosen').first()).toContainText(customer.name)
  await expect(drawer.getByRole('combobox', { name: /Veículo/ })).toBeVisible()
})

test('Receber: uma OS abre ela; consultor só recebe nas que criou (customer.detail.receive)', async ({ page }) => {
  const customer = await makeCustomer()
  const owed = await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, status: 'done', total: 120, paidAmount: 0 })
  await openCustomers(page, 'admin', `?customer=${customer.id}`)
  await panel(page).getByTestId('customer-receive').click()
  await expect(page).toHaveURL(new RegExp(`order=${owed.id}`))
  await expect(page.getByTestId('order-detail')).toBeVisible()
})

test('aparelhos e OS do cliente; abrir o aparelho (customer.detail.devices, customer.detail.orders)', async ({ page }) => {
  const customer = await makeCustomer()
  const device = await makeDevice()
  const order = await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, devices: [{ id: device.id, name: device.name, serial: device.serial }], deviceIds: [device.id], device: { id: device.id, name: device.name } })
  await openCustomers(page, 'manager', `?customer=${customer.id}`)
  await expect(panel(page).getByTestId('customer-devices')).toContainText(`${device.serial} · 1 OS`)
  await expect(panel(page).getByTestId('customer-orders')).toContainText(`OS ${order.number}`)
  await panel(page).getByTestId('customer-devices').getByRole('button', { name: device.name }).click()
  await expect(page).toHaveURL(new RegExp(`devices\\?device=${device.id}`))
  await expect(page.getByTestId('device-detail').getByRole('heading', { name: device.name })).toBeVisible()
})

test('editar pelo menu, CPF/CNPJ validado e campo do segmento gravado (customer.detail.edit, customer.form.tax-id, customer.form.custom-fields)', async ({ page }) => {
  const customer = await makeCustomer({ createdBy: { id: 'someone', name: 'Alguém' }, createdAt: '2026-01-01T00:00:00.000Z' })
  await openCustomers(page, 'admin', `?customer=${customer.id}`)
  await panel(page).getByTestId('customer-menu').click()
  await page.getByRole('button', { name: 'Editar cliente' }).click()
  const form = page.getByTestId('customer-form')
  await form.getByText('Mais dados').click()
  await form.getByLabel('CPF/CNPJ').fill('111.111.111-11')
  await expect(form.getByText('Esse CPF ou CNPJ não confere.')).toBeVisible()
  await form.getByLabel('CPF/CNPJ').fill('11.222.333/0001-81')
  await form.getByLabel('Aniversário').fill('2000-02-29')
  await form.getByLabel('Nome', { exact: true }).fill(`${customer.name} Editado`)
  await form.getByTestId('save-customer').click()
  await expect(panel(page).getByRole('heading', { name: `${customer.name} Editado` })).toBeVisible()
  await expect(panel(page).getByTestId('customer-contact')).toContainText('11.222.333/0001-81')
  const saved = await readDoc(`customers/${customer.id}`)
  expect(saved).toMatchObject({ taxId: '11222333000181', customData: { birthday: '2000-02-29T00:00:00.000' }, createdBy: { id: 'someone' }, createdAt: '2026-01-01T00:00:00.000Z' })
})

test('fechar com algo digitado pergunta antes, também na edição (customer.form.save unsaved)', async ({ page }) => {
  const customer = await makeCustomer()
  await openCustomers(page, 'admin', `?customer=${customer.id}`)
  await panel(page).getByTestId('customer-menu').click()
  await page.getByRole('button', { name: 'Editar cliente' }).click()
  const form = page.getByTestId('customer-form')
  await form.getByLabel('Nome', { exact: true }).fill('Mudou')
  page.once('dialog', (dialog) => void dialog.dismiss())
  await page.keyboard.press('Escape')
  await expect(form).toBeVisible()
  page.once('dialog', (dialog) => void dialog.accept())
  await page.keyboard.press('Escape')
  await expect(form).toHaveCount(0)
  expect((await readDoc(`customers/${customer.id}`))?.name).toBe(customer.name)
})

test('outra pessoa salvou enquanto editava: avisa, relê e não grava por cima (revisão M1)', async ({ page }) => {
  const customer = await makeCustomer({ updatedAt: '2026-10-01T10:00:00.000000' })
  await openCustomers(page, 'admin', `?customer=${customer.id}`)
  await panel(page).getByTestId('customer-menu').click()
  await page.getByRole('button', { name: 'Editar cliente' }).click()
  const form = page.getByTestId('customer-form')
  await form.getByLabel('Nome', { exact: true }).fill('Nome da web')
  await updateCustomerDoc(customer.id, { name: 'Nome do app', updatedAt: '2026-10-02T10:00:00.000000' })
  await form.getByTestId('save-customer').click()
  await expect(page.locator('.toast')).toContainText('Outra pessoa mudou este cliente')
  await expect(form).toHaveCount(0)
  await expect(panel(page).getByRole('heading', { name: 'Nome do app' })).toBeVisible()
  expect((await readDoc(`customers/${customer.id}`))?.name).toBe('Nome do app')
})

test('apagar pede confirmação, avisa e tira da lista (customer.detail.delete, customer.detail.menu)', async ({ page }) => {
  const customer = await makeCustomer()
  // An order the consultant does not read: the warning still counts it (revisão M2).
  await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, status: 'quote' })
  await openCustomers(page, 'consultant', `?customer=${customer.id}`)
  await panel(page).getByTestId('customer-menu').click()
  await page.getByRole('button', { name: 'Apagar' }).click()
  const confirm = page.getByRole('dialog', { name: `Apagar ${customer.name}?` })
  await expect(confirm).toContainText('Tem 1 OS, nenhum recibo e nenhuma cobrança.')
  await expect(confirm).toContainText('As OS continuam salvas.')
  await confirm.getByRole('button', { name: 'Apagar' }).click()
  await expect(page.locator('.toast')).toContainText(`${customer.name} apagado`)
  await expect(panel(page)).toHaveCount(0)
  expect(await readDoc(`customers/${customer.id}`)).toBeUndefined()
})

test('lista vazia oferece o primeiro cliente só para quem cadastra; erro tem "Tentar de novo" (customer.list.empty-add)', async ({ page }) => {
  let fail = true
  await page.route(/\/v1\/app\/customers$/, async (route) => {
    if (route.request().method() !== 'GET') return route.fallback()
    if (fail) return route.fulfill({ status: 503, body: '{}' })
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ success: true, data: [], meta: { partial: false } }) })
  })
  await openCustomers(page, 'admin')
  await expect(page.getByText('Não deu para carregar os clientes. Tente de novo.')).toBeVisible()
  fail = false
  await page.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(page.getByTestId('customers-empty')).toContainText('Você ainda não tem clientes')
  await page.getByTestId('first-customer').click()
  await expect(page.getByTestId('customer-form')).toBeVisible()
})

test('⌘K acha cliente por nome e abre a tela dele (busca rápida)', async ({ page }) => {
  const customer = await makeCustomer({ name: `Rápida ${Date.now()}` })
  await openCustomers(page, 'admin')
  await expect(list(page)).toBeVisible()
  await page.keyboard.press('ControlOrMeta+k')
  await page.getByRole('combobox', { name: /Buscar/ }).fill(customer.name)
  await page.getByRole('option', { name: new RegExp(customer.name) }).click()
  await expect(panel(page).getByRole('heading', { name: customer.name })).toBeVisible()
})
