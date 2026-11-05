// Fatia 03, aparelhos (device.*), against the Emulator Suite. Company A has
// useDeviceManagement on and the automotive segment ("Veículo", "Placa").
import { expect, test, type Page } from '@playwright/test'
import { makeCustomer, makeDevice, makeOrder, readDoc } from './data'
import { login, signOut } from './helpers'

const table = (page: Page) => page.getByTestId('devices-table')
const panel = (page: Page) => page.getByTestId('device-detail')
const row = (page: Page, text: string) => table(page).getByRole('row').filter({ hasText: text })

async function openDevices(page: Page, user: Parameters<typeof login>[1], query = '') {
  await login(page, user, `devices${query}`)
  await expect(page.getByRole('heading', { level: 1, name: 'Veículos' })).toBeVisible()
}

test('lista com situação e busca pela placa sem hífen (device.list.view, device.list.search, device.list.status)', async ({ page }) => {
  const device = await makeDevice({ status: 'maintenance', manufacturer: 'Fiat' })
  await openDevices(page, 'technician')
  await expect(page.getByTestId('devices-summary')).toHaveText(/\d+ veículos/)
  await expect(table(page).getByRole('columnheader', { name: 'Situação' })).toBeVisible()
  const search = page.getByLabel(/Buscar por modelo/)
  await search.fill(`${device.serial.slice(0, 3)}-${device.serial.slice(3)}`.toLowerCase())
  await expect(row(page, device.serial)).toContainText('Em manutenção')
  await search.fill('fiat')
  await expect(row(page, device.serial)).toBeVisible()
  // Tabs: Clientes | Veículos.
  await page.getByTestId('customers-tab').click()
  await expect(page.getByRole('heading', { level: 1, name: 'Clientes' })).toBeVisible()
})

test('cadastrar: série em maiúsculas com a máscara e sugestão de modelo que traz a marca (device.list.create, device.form.save, device.form.autocomplete, device.form.serial-rules)', async ({ page }) => {
  const model = `Yaris Cross ${Date.now()}`
  await makeDevice({ name: model, manufacturer: 'Fiat', category: 'Picape' })
  await openDevices(page, 'supervisor')
  await page.getByTestId('new-device').click()
  const form = page.getByTestId('device-form')
  await form.getByTestId('save-device').click()
  await expect(form.getByRole('alert')).toHaveText('Preencha modelo ou placa para salvar.')
  await form.getByLabel('Modelo').fill(model.slice(0, 10))
  await form.getByTestId('model-suggestions').getByRole('option', { name: new RegExp(model) }).click()
  await expect(form.getByLabel('Marca')).toHaveValue('Fiat')
  const serial = `QWE${Math.floor(1000 + Math.random() * 8999)}`
  await form.getByLabel('Placa').pressSequentially(serial.toLowerCase())
  await expect(form.getByLabel('Placa')).toHaveValue(`${serial.slice(0, 3)}-${serial.slice(3)}`)
  await form.getByTestId('save-device').click()
  await expect(panel(page).getByRole('heading', { name: model })).toBeVisible()
  await expect(panel(page).getByTestId('device-owner')).toContainText(`${serial.slice(0, 3)}-${serial.slice(3)}`)
})

test('consultor, gerente e técnico não editam nem apagam; consultor abre o aparelho com as OS dele (device.detail.view, device.detail.edit)', async ({ page }) => {
  const device = await makeDevice()
  const customer = await makeCustomer()
  const own = await makeOrder('consultant', { customer: { id: customer.id, name: customer.name }, devices: [{ id: device.id, name: device.name, serial: device.serial }], deviceIds: [device.id] })
  const other = await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, devices: [{ id: device.id, name: device.name, serial: device.serial }], deviceIds: [device.id] })
  await openDevices(page, 'consultant', `?device=${device.id}`)
  await expect(panel(page).getByRole('heading', { name: device.name })).toBeVisible()
  await expect(panel(page).getByTestId('device-orders')).toContainText(String(own.number))
  await expect(panel(page).getByTestId('device-orders')).not.toContainText(String(other.number))
  await expect(panel(page).getByText('Mostrando só as OS que você pode ver.')).toBeVisible()
  await expect(page.getByTestId('new-device')).toHaveCount(0)
  await expect(page.getByTestId('device-menu')).toHaveCount(0)
  await expect(table(page).getByRole('button', { name: /^Editar / })).toHaveCount(0)
})

test('dono = cliente da OS mais recente, com link; Nova OS leva cliente e veículo (device.detail.owner, device.detail.customer, device.detail.new-order)', async ({ page }) => {
  const device = await makeDevice()
  const old = await makeCustomer()
  const owner = await makeCustomer()
  await makeOrder('admin', { customer: { id: old.id, name: old.name }, devices: [{ id: device.id, name: device.name }], deviceIds: [device.id], createdAt: '2026-01-01T10:00:00.000Z' })
  await makeOrder('admin', { customer: { id: owner.id, name: owner.name }, devices: [{ id: device.id, name: device.name }], deviceIds: [device.id] })
  await openDevices(page, 'admin', `?device=${device.id}`)
  await expect(panel(page).getByTestId('device-owner')).toContainText(`de ${owner.name}`)
  await panel(page).getByTestId('device-new-order').click()
  const drawer = page.getByTestId('new-order-drawer')
  await expect(drawer.locator('.chosen').nth(0)).toContainText(owner.name)
  await expect(drawer.locator('.chosen').nth(1)).toContainText(device.name)
  page.once('dialog', (dialog) => void dialog.accept())
  await page.keyboard.press('Escape')
  await expect(drawer).toHaveCount(0)
  await page.getByTestId('device-owner').getByRole('link', { name: owner.name }).click()
  await expect(page.getByTestId('customer-detail').getByRole('heading', { name: owner.name })).toBeVisible()
})

test('OS do aparelho com valores só para quem vê valores (device.detail.orders, device.detail.price)', async ({ page }) => {
  const device = await makeDevice()
  const order = await makeOrder('admin', { devices: [{ id: device.id, name: device.name }], deviceIds: [device.id], total: 345 })
  await openDevices(page, 'manager', `?device=${device.id}`)
  await expect(panel(page).getByTestId('device-orders')).toContainText(`OS ${order.number}`)
  await expect(panel(page).getByTestId('device-orders')).toContainText('R$ 345,00')
  await page.goto('settings')
  await signOut(page)
  await openDevices(page, 'supervisor', `?device=${device.id}`)
  await expect(panel(page).getByTestId('device-orders')).toContainText(`OS ${order.number}`)
  await expect(panel(page).getByTestId('device-orders')).not.toContainText('R$')
})

test('supervisor marca, muda e tira a próxima manutenção; técnico só vê (device.detail.maintenance*)', async ({ page }) => {
  const device = await makeDevice()
  const customer = await makeCustomer()
  await makeOrder('admin', { status: 'done', customer: { id: customer.id, name: customer.name }, devices: [{ id: device.id, name: device.name }], deviceIds: [device.id], services: [{ service: { id: 'service-1', name: 'Troca de óleo' }, value: 50 }] })
  await openDevices(page, 'supervisor', `?device=${device.id}`)
  const block = panel(page).getByTestId('device-maintenance')
  await block.getByTestId('maintenance-set').click()
  const dialog = page.getByRole('dialog', { name: 'Quando é a próxima manutenção?' })
  await dialog.getByLabel('Dia da próxima manutenção').fill('2099-06-15')
  await dialog.getByTestId('maintenance-save').click()
  await expect(block).toContainText('Próxima manutenção: 15 de junho de 2099')
  await expect(block).toContainText('Última: Troca de óleo')
  const saved = await readDoc(`devices/${device.id}`)
  expect(saved).toMatchObject({ nextMaintenanceDate: '2099-06-15', nextMaintenanceCustomer: { id: customer.id, name: customer.name } })
  await block.getByTestId('maintenance-remove').click()
  await page.getByRole('dialog', { name: 'Tirar a próxima manutenção?' }).getByRole('button', { name: 'Tirar' }).click()
  await expect(block.getByTestId('maintenance-set')).toBeVisible()
  expect((await readDoc(`devices/${device.id}`))?.nextMaintenanceDate).toBeUndefined()
})

test('técnico vê a data da manutenção, sem mudar (device.detail.maintenance)', async ({ page }) => {
  const device = await makeDevice({ nextMaintenanceDate: '2099-01-10' })
  await openDevices(page, 'technician', `?device=${device.id}`)
  const block = panel(page).getByTestId('device-maintenance')
  await expect(block).toContainText('10 de janeiro de 2099')
  await expect(block.getByRole('button')).toHaveCount(0)
})

test('situação pela lista de escolher, campos do segmento e editar pelo botão da linha (device.form.status, device.form.custom-fields, device.list.edit-swipe)', async ({ page }) => {
  const device = await makeDevice({ status: 'active' })
  await openDevices(page, 'admin', `?q=${device.serial}`)
  await row(page, device.serial).getByRole('button', { name: `Editar ${device.name}` }).click()
  const form = page.getByTestId('device-form')
  await form.getByTestId('device-status').getByLabel('Inativo').check()
  await form.getByText('Mais dados').click()
  await form.getByLabel('Quilometragem').fill('98000')
  await form.getByLabel('Combustível').selectOption('Diesel')
  await form.getByTestId('save-device').click()
  await expect(row(page, device.serial)).toContainText('Inativo')
  await expect(await readDoc(`devices/${device.id}`)).toMatchObject({ status: 'inactive', customData: { mileage: 98000, fuel: 'Diesel' } })
  await row(page, device.serial).getByRole('button', { name: device.name, exact: true }).click()
  // The reading (odometer) sits next to the serial, not in the custom fields (docs/DEVICE_READING.md)
  await expect(panel(page).getByTestId('device-reading')).toContainText('98.000')
  await expect(panel(page).getByTestId('device-custom')).toContainText('Diesel')
})

test('apagar pelo botão da linha só sai quando o servidor confirma (device.list.delete, device.detail.delete)', async ({ page }) => {
  const device = await makeDevice()
  await openDevices(page, 'supervisor', `?q=${device.serial}`)
  await row(page, device.serial).getByRole('button', { name: `Apagar ${device.name}` }).click()
  await page.getByRole('dialog', { name: `Apagar ${device.name}?` }).getByRole('button', { name: 'Apagar' }).click()
  await expect(page.locator('.toast')).toContainText(`${device.name} apagado`)
  await expect(page.getByTestId('devices-no-match')).toBeVisible()
  expect(await readDoc(`devices/${device.id}`)).toBeUndefined()
})

test('apagar pelo menu da tela do veículo volta à lista (device.detail.delete)', async ({ page }) => {
  const device = await makeDevice()
  await openDevices(page, 'admin', `?device=${device.id}`)
  await panel(page).getByTestId('device-menu').click()
  await page.getByRole('dialog', { name: device.name }).getByRole('button', { name: 'Apagar', exact: true }).click()
  await page.getByRole('dialog', { name: `Apagar ${device.name}?` }).getByRole('button', { name: 'Apagar' }).click()
  await expect(page.locator('.toast')).toContainText(`${device.name} apagado`)
  await expect(panel(page)).toHaveCount(0)
  expect(await readDoc(`devices/${device.id}`)).toBeUndefined()
})

test('aparelho que não existe mais (device.detail.view not_found)', async ({ page }) => {
  await openDevices(page, 'admin', '?device=nope-device')
  await expect(page.getByTestId('device-not-found')).toContainText('Este Veículo não está mais aqui')
})

test('cadastrar outro veículo pela tela do cliente (customer.detail.add-device)', async ({ page }) => {
  const customer = await makeCustomer()
  await login(page, 'supervisor', `customers?customer=${customer.id}`)
  await page.getByTestId('customer-add-device').click()
  const form = page.getByTestId('device-form')
  await form.getByLabel('Modelo').fill(`Xsara ${Date.now()}`)
  await form.getByTestId('save-device').click()
  await expect(panel(page)).toBeVisible()
  await expect(page).toHaveURL(/devices\?device=/)
})
