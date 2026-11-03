// Order pickers (customer.picker.recents, customer.picker.plate, customer.picker.choose,
// device.list.pick, device.list.pick-none, order.device.change, order.item-search.most-used):
// "Recentes" from the orders this role reads, the plate that brings customer and
// device together, "Nenhum …" when changing a device, "Mais usados" of the catalog.
import { expect, test, type Page } from '@playwright/test'
import { deleteOrderDocs, makeCustomer, makeDevice, makeOrder, readOrder } from './data'
import { login, type UserKey } from './helpers'

const drawer = (page: Page) => page.getByRole('dialog', { name: 'Nova OS' })
const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const group = (page: Page, name: string) => page.getByRole('listbox').getByRole('group', { name })

const made: { id: string; company: 'A' }[] = []
test.afterEach(async () => {
  await deleteOrderDocs(made.splice(0))
})
// Newest of the company for a moment (the seed scenario sits 5 years ahead), so "Recentes" has it.
async function recentOrder(author: UserKey, data: Record<string, unknown>) {
  const order = await makeOrder(author, { createdAt: new Date(Date.now() + 6 * 365 * 86_400_000).toISOString(), ...data })
  made.push({ id: order.id, company: 'A' })
  return order
}

async function newOrder(page: Page, user: UserKey) {
  await login(page, user)
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.locator('h1').click()
  await page.keyboard.press('n')
  await expect(drawer(page)).toBeVisible()
}

test('Nova OS: Recentes no topo do cliente, some com busca; Mais usados no item (customer.picker.recents, order.item-search.most-used)', async ({ page }) => {
  const customer = await makeCustomer({ name: 'Recente Rafaela' })
  await recentOrder('admin', { customer: { id: customer.id, name: customer.name } })
  await newOrder(page, 'admin')
  const field = page.getByRole('combobox', { name: 'Cliente' })
  await field.click()
  await expect(group(page, 'Recentes').getByRole('option', { name: /Recente Rafaela/ })).toBeVisible()
  await expect(group(page, 'Recentes').getByRole('option')).toHaveCount(5)
  await field.fill('Cliente 0')
  await expect(group(page, 'Recentes')).toHaveCount(0)
  await field.fill('')
  await group(page, 'Recentes').getByRole('option', { name: /Recente Rafaela/ }).click()
  await expect(drawer(page)).toContainText('Recente Rafaela')

  const item = page.getByRole('combobox', { name: 'O que vai ser feito?' })
  await item.click()
  await expect(group(page, 'Mais usados').getByRole('option').first()).toBeVisible()
  await item.fill('Serv')
  await expect(group(page, 'Mais usados')).toHaveCount(0)
})

test('Nova OS: a placa traz o dono e o veículo juntos (customer.picker.plate)', async ({ page }) => {
  const customer = await makeCustomer({ name: 'Dono da Placa' })
  const device = await makeDevice({ serial: 'PLK4E21', name: 'Onix Placa' })
  await recentOrder('admin', { customer: { id: customer.id, name: customer.name }, device: { id: device.id, name: device.name, serial: device.serial }, devices: [{ id: device.id, name: device.name, serial: device.serial }], deviceIds: [device.id] })
  await newOrder(page, 'admin')
  await page.getByRole('combobox', { name: 'Cliente' }).fill('plk-4e')
  await group(page, 'Pela placa ou série').getByRole('option', { name: /PLK4E21 · Onix Placa/ }).click()
  await expect(drawer(page)).toContainText('Dono da Placa')
  await expect(drawer(page)).toContainText('Onix Placa')
  await expect(page.getByRole('combobox', { name: 'O que vai ser feito?' })).toBeFocused()
})

test('consultor: Recentes só das OS que ele lê (customer.picker.recents, por papel)', async ({ page }) => {
  const mine = await makeCustomer({ name: 'Recente do Consultor' })
  const other = await makeCustomer({ name: 'Recente de Outro' })
  await recentOrder('admin', { customer: { id: other.id, name: other.name } })
  await recentOrder('consultant', { customer: { id: mine.id, name: mine.name } })
  await newOrder(page, 'consultant')
  await page.getByRole('combobox', { name: 'Cliente' }).click()
  await expect(group(page, 'Recentes').getByRole('option', { name: /Recente do Consultor/ })).toBeVisible()
  await expect(group(page, 'Recentes').getByRole('option', { name: /Recente de Outro/ })).toHaveCount(0)
})

test('OS: trocar o veículo com ✓ no atual e Nenhum para tirar; placa no seletor de cliente (order.device.change, device.list.pick-none, customer.picker.choose)', async ({ page }) => {
  const a = await makeDevice({ serial: 'TRC1A11', name: 'Troca Um' })
  const b = await makeDevice({ serial: 'TRC2B22', name: 'Troca Dois' })
  const order = await recentOrder('admin', { device: { id: a.id, name: a.name, serial: a.serial }, devices: [{ id: a.id, name: a.name, serial: a.serial }], deviceIds: [a.id] })
  await login(page, 'admin', `orders?order=${order.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await panel(page).getByRole('button', { name: 'Trocar Troca Um · TRC1A11' }).click()
  const picker = page.getByRole('dialog', { name: 'Escolher veículo' })
  await expect(picker.getByRole('option', { name: /Troca Um/ })).toHaveAttribute('aria-selected', 'true')
  await picker.getByRole('combobox').fill('TRC2')
  await picker.getByRole('option', { name: /Troca Dois/ }).click()
  await expect.poll(async () => ((await readOrder(order.id))?.devices as { id: string }[]).map((d) => d.id)).toEqual([b.id])

  await panel(page).getByRole('button', { name: 'Trocar Troca Dois · TRC2B22' }).click()
  await page.getByRole('dialog', { name: 'Escolher veículo' }).getByRole('option', { name: 'Nenhum veículo' }).click()
  await expect.poll(async () => ((await readOrder(order.id))?.devices as unknown[]).length).toBe(0)
  expect((await readOrder(order.id))?.device ?? null).toBeNull()

  // The customer picker marks the current one and finds by plate.
  await panel(page).getByRole('button', { name: 'Trocar o cliente Cliente 02' }).click()
  const customers = page.getByRole('dialog', { name: 'Quem é o cliente?' })
  await expect(customers.getByRole('option', { name: /Cliente 02/ })).toHaveAttribute('aria-selected', 'true')
  await customers.getByRole('combobox').fill('trc1a')
  await expect(customers.getByRole('group', { name: 'Pela placa ou série' }).getByRole('option', { name: /TRC1A11 · Troca Um/ })).toBeVisible()
})

test('a placa mostra o nome do dono; Mais usados também no Adicionar da OS (customer.picker.plate, order.item-search.most-used)', async ({ page }) => {
  const customer = await makeCustomer({ name: 'Dona Placa Nome' })
  const device = await makeDevice({ serial: 'NMD5F55', name: 'Kwid Nome' })
  const order = await recentOrder('admin', { customer: { id: customer.id, name: customer.name }, device: { id: device.id, name: device.name, serial: device.serial }, devices: [{ id: device.id, name: device.name, serial: device.serial }], deviceIds: [device.id] })
  await newOrder(page, 'admin')
  await page.getByRole('combobox', { name: 'Cliente' }).fill('nmd5')
  await expect(group(page, 'Pela placa ou série').getByRole('option', { name: /NMD5F55 · Kwid Nome/ })).toContainText('Dona Placa Nome')
  await page.keyboard.press('Escape')
  await page.goto(`orders?order=${order.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await panel(page).getByRole('button', { name: 'Adicionar serviço ou peça' }).click()
  await expect(page.getByRole('dialog', { name: 'O que vai ser feito?' }).getByRole('group', { name: 'Mais usados' }).getByRole('option').first()).toBeVisible()
})
