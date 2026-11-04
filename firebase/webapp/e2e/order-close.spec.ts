// Fechamento da matriz da OS: what the order already did without a test, and
// what this slice added (open the customer and the device, rating, photo viewer
// and cover, catalog item from the search, the Nova OS extras). Every write is
// checked in what the server or Firestore saved.
import { expect, test, type Page } from '@playwright/test'
import { catalogNamed, makeCustomer, makeDevice, makeOrder, readOrder, updateOrderDoc } from './data'
import { login, type UserKey } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })
const drawer = (page: Page) => page.getByRole('dialog', { name: /Nova OS/ })
const status = (page: Page) => panel(page).getByTestId('order-status')

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

async function menu(page: Page, item: string | RegExp) {
  await panel(page).getByRole('button', { name: 'Mais ações' }).click()
  await page.getByRole('dialog').getByRole('button', { name: item }).click()
}

const PHOTO = (id: string) => ({ id, url: `https://firebasestorage.googleapis.com/v0/b/demo/o/${id}.png?alt=media`, storagePath: `tenants/company-alpha/orders/x/photos/${id}.png` })

test('abrir o cliente e o veículo da OS pelo menu (order.customer.open, order.device.open)', async ({ page }) => {
  const customer = await makeCustomer()
  const device = await makeDevice()
  const order = await makeOrder('admin', { customer, device, devices: [device], deviceIds: [device.id] })
  await openOrder(page, 'admin', order.id)
  await menu(page, 'Abrir cliente')
  await expect(page).toHaveURL(new RegExp(`customers\\?customer=${customer.id}`))
  await expect(page.getByTestId('customer-detail')).toContainText(customer.name)
  await page.goto(`orders?order=${order.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await menu(page, `Abrir ${device.name}`)
  await expect(page).toHaveURL(new RegExp(`devices\\?device=${device.id}`))
})

test('avaliação do cliente: estrelas, "4 de 5" e o comentário; sem nota, nada (order.rating.view, por papel)', async ({ page }) => {
  const rated = await makeOrder('admin', { status: 'done', rating: { score: 4, comment: 'Ficou ótimo', customerName: 'Cliente 02' } })
  await openOrder(page, 'supervisor', rated.id)
  const rating = panel(page).getByTestId('order-rating')
  await expect(rating).toContainText('Avaliação')
  await expect(rating).toContainText('4 de 5')
  await expect(rating).toContainText('Ficou ótimo')
  const plain = await makeOrder('admin', { status: 'done', rating: { score: 9 } })
  await page.goto(`orders?order=${plain.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await expect(panel(page).getByTestId('order-rating')).toHaveCount(0)
})

test('fotos: passar entre elas com botão e seta, e definir a capa; gerente só vê (order.photo.viewer, order.photo.cover)', async ({ page, browser }) => {
  const order = await makeOrder('admin', { photos: [PHOTO('p1'), PHOTO('p2'), PHOTO('p3')] })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Ver foto 1' }).click()
  const viewer = page.getByTestId('photo-viewer')
  await expect(viewer).toContainText('1 de 3')
  await expect(page.getByRole('button', { name: 'Definir como capa' })).toHaveCount(0)
  await page.getByRole('button', { name: 'Próxima foto' }).click()
  await expect(viewer).toContainText('2 de 3')
  await page.keyboard.press('ArrowRight')
  await expect(viewer).toContainText('3 de 3')
  await page.keyboard.press('ArrowLeft')
  await expect(viewer).toContainText('2 de 3')
  await page.getByRole('button', { name: 'Definir como capa' }).click()
  await expect(page.locator('.toast')).toContainText('Foto definida como capa')
  await expect.poll(async () => ((await readOrder(order.id))?.photos as { id: string }[]).map((p) => p.id)).toEqual(['p2', 'p1', 'p3'])
  await expect(viewer).toContainText('1 de 3')

  const context = await browser.newContext({ ...test.info().project.use })
  const manager = await context.newPage()
  await openOrder(manager, 'manager', order.id)
  await panel(manager).getByRole('button', { name: 'Ver foto 1' }).click()
  await manager.getByRole('button', { name: 'Próxima foto' }).click()
  await expect(manager.getByTestId('photo-viewer')).toContainText('2 de 3')
  await expect(manager.getByRole('button', { name: 'Definir como capa' })).toHaveCount(0)
  await context.close()
})

test('foto posta por outro aparelho aparece com a OS aberta e fica quando o web põe outra (order.attachments.merge)', async ({ page }) => {
  const order = await makeOrder('admin')
  await openOrder(page, 'admin', order.id)
  await updateOrderDoc(order.id, { photos: [PHOTO('outro')] })
  await expect(panel(page).getByRole('button', { name: 'Ver foto 1' })).toBeVisible()
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64')
  await panel(page).getByLabel('Adicionar foto').setInputFiles({ name: 'web.png', mimeType: 'image/png', buffer: png })
  await expect(panel(page).getByRole('button', { name: 'Ver foto 2' })).toBeVisible()
  await expect.poll(async () => ((await readOrder(order.id))?.photos as { id: string }[]).length).toBe(2)
  expect(((await readOrder(order.id))?.photos as { id: string }[])[0]!.id).toBe('outro')
})

test('buscar item: preço para quem vê valores e "+ Cadastrar no catálogo" põe na OS (order.item-search.price, order.item-search.create)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved' })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Adicionar serviço ou peça' }).click()
  const search = dialog(page, 'O que vai ser feito?').getByRole('combobox')
  await search.fill('Serviço 1')
  await expect(page.getByRole('option', { name: /^Serviço 1/ }).first()).toContainText('R$')
  // An existing name never offers to register it again (accents and case ignored).
  await search.fill('serviço 1')
  await expect(page.getByRole('option', { name: /no catálogo/ })).toHaveCount(0)
  // Letters only: a number in the name would match other tests' searches ("Serviço 1").
  const name = `Alinhamento ${Array.from({ length: 6 }, () => String.fromCharCode(97 + Math.floor(Math.random() * 26))).join('')}`
  await search.fill(name)
  await page.getByRole('option', { name: `+ Cadastrar “${name}” no catálogo` }).click()
  await expect(panel(page).getByTestId('order-line').filter({ hasText: name })).toBeVisible()
  await expect.poll(async () => (await catalogNamed('service', name)).length).toBe(1)
  await expect.poll(async () => ((await readOrder(order.id))?.services as { service?: { name?: string } }[]).some((line) => line.service?.name === name)).toBe(true)
})

test('item sem valor fica fora do total e a OS diz quantos (order.item.no-price)', async ({ page }) => {
  const order = await makeOrder('admin', { services: [{ service: { id: 'service-1', name: 'Serviço 1' }, value: 50 }, { service: { id: 'service-2', name: 'Serviço 2' }, value: null }], total: 50 })
  await openOrder(page, 'admin', order.id)
  await expect(panel(page).getByText('1 item sem valor, fora do total')).toBeVisible()
  await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 50,00')
})

test('concluir tira a marca de parada (order.hold.clear)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'progress', onHold: { reason: 'waitingPart', since: new Date().toISOString() } })
  await openOrder(page, 'admin', order.id)
  await expect(panel(page).getByTestId('hold-line')).toBeVisible()
  await menu(page, 'Mudar a situação')
  await dialog(page, 'Qual a situação?').getByRole('button', { name: /Concluíd/ }).click()
  await expect(panel(page).getByTestId('hold-line')).toHaveCount(0)
  await expect.poll(async () => (await readOrder(order.id))?.onHold ?? null, { timeout: 15_000 }).toBeNull()
})

test('técnico começa direto o próprio orçamento; cancelar zera a cobrança e reabrir recalcula (order.status.start-from-quote, order.status.payment-sync)', async ({ page, browser }) => {
  const own = await makeOrder('technician', { status: 'quote', payment: null })
  await openOrder(page, 'technician', own.id)
  await menu(page, 'Mudar a situação')
  await dialog(page, 'Qual a situação?').getByRole('button', { name: 'Na oficina' }).click()
  await expect(status(page)).toHaveText('Na oficina')
  await expect.poll(async () => (await readOrder(own.id))?.status).toBe('progress')

  const paid = await makeOrder('admin', { status: 'done', total: 50, paidAmount: 50, payment: 'paid', paid: true })
  const context = await browser.newContext({ ...test.info().project.use })
  const admin = await context.newPage()
  await openOrder(admin, 'admin', paid.id)
  await menu(admin, /Cancelar OS/)
  await dialog(admin, /Cancelar/).getByRole('button', { name: /Cancelar OS/ }).click()
  await expect.poll(async () => (await readOrder(paid.id))?.status).toBe('canceled')
  expect((await readOrder(paid.id))?.payment ?? null).toBeNull()
  expect((await readOrder(paid.id))?.paid).toBe(false)
  // The screen has the canceled version before the next change (a change over the old one is refused: 409).
  await expect(status(admin)).toHaveText(/Cancelad/)
  await expect(admin.locator('.toast')).toHaveCount(0)
  await menu(admin, 'Mudar a situação')
  await dialog(admin, 'Qual a situação?').getByRole('button', { name: /Concluíd/ }).click()
  await expect(status(admin)).toHaveText('Concluído')
  await expect.poll(async () => (await readOrder(paid.id))?.status).toBe('done')
  expect((await readOrder(paid.id))?.payment).toBe('paid')
  await context.close()
})

test('local abre no mapa pelo endereço (order.address.map)', async ({ page }) => {
  const order = await makeOrder('admin', { address: 'Rua das Flores, 100, Florianópolis' })
  await openOrder(page, 'admin', order.id)
  const link = panel(page).getByTestId('order-address').getByRole('link', { name: 'Abrir no Mapa' })
  await expect(link).toHaveAttribute('href', `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent('Rua das Flores, 100, Florianópolis')}`)
  await expect(link).toHaveAttribute('target', '_blank')
})

test('assistente: desligado some; a partir de 80% do mês diz quantos restam (order.ai.status, order.ai.uses-left)', async ({ page }) => {
  let enabled = false
  await page.route(/\/v1\/app\/ai\/status/, (route) => route.fulfill({ json: { success: true, data: { enabled, usage: { used: 85, limit: 100 } } } }))
  const order = await makeOrder('admin', { status: 'approved' })
  await openOrder(page, 'admin', order.id)
  await expect(panel(page).getByTestId('order-line').first()).toBeVisible()
  await expect(panel(page).getByLabel('Pedir ao assistente')).toHaveCount(0)
  enabled = true
  const other = await makeOrder('admin', { status: 'approved' })
  // The answer is kept 5 minutes per company: a new page reads it again.
  await page.reload()
  await page.goto(`orders?order=${other.id}`)
  await expect(panel(page).getByLabel('Pedir ao assistente')).toBeVisible()
  await expect(panel(page).getByTestId('assistant')).toContainText('Restam 15 usos do assistente este mês.')
})

test.describe('Nova OS', () => {
  test('entrega, visita e responsável; o endereço do cliente vem com a coordenada (order.new.delivery, order.new.more-options, order.customer.address-from-customer)', async ({ page }) => {
    const customer = await makeCustomer({ address: 'Rua do Cliente, 5', latitude: -27.6, longitude: -48.5 })
    await login(page, 'admin')
    await page.getByTestId('new-order').click()
    await page.getByRole('combobox', { name: 'Cliente' }).fill(customer.name)
    await page.getByRole('option', { name: new RegExp(`^${customer.name}`) }).click()
    await drawer(page).getByLabel('Fica pronto, se já souber').fill('2099-05-10T14:30')
    await drawer(page).getByText('Mais opções').click()
    await drawer(page).getByLabel('Visita').fill('2099-05-09T09:00')
    await drawer(page).getByLabel('Responsável').selectOption({ label: 'Tiago Tecnico' })
    await expect(drawer(page).locator('summary')).toContainText('Visita · Tiago Tecnico')
    await page.getByTestId('save-order').click()
    await expect(page.locator('.toast')).toContainText(/OS \d+ criada/)
    const id = new URL(page.url()).searchParams.get('order') as string
    await expect.poll(async () => (await readOrder(id))?.address).toBe('Rua do Cliente, 5')
    const saved = await readOrder(id)
    expect(saved?.dueDate).toBe('2099-05-10T14:30:00.000')
    expect(saved?.scheduledDate).toBe('2099-05-09T09:00:00.000')
    expect(saved?.latitude).toBe(-27.6)
    await expect.poll(async () => ((await readOrder(id))?.assignedTo as { id?: string } | null)?.id).toBe('e2e-technician')
  })

  test('cliente com um veículo só já vem com ele (customer.picker.auto-device)', async ({ page }) => {
    const customer = await makeCustomer()
    const device = await makeDevice()
    await makeOrder('admin', { customer, device, devices: [device], deviceIds: [device.id] })
    await login(page, 'admin')
    await page.getByTestId('new-order').click()
    await page.getByRole('combobox', { name: 'Cliente' }).fill(customer.name)
    await page.getByRole('option', { name: new RegExp(`^${customer.name}`) }).click()
    await expect(drawer(page)).toContainText(device.name)
    await expect(page.getByRole('combobox', { name: 'O que vai ser feito?' })).toBeFocused()
  })

  test('placa digitada vira veículo novo com a placa em maiúsculas (device.list.pick-create)', async ({ page }) => {
    const other = await makeCustomer()
    await login(page, 'admin')
    await page.getByTestId('new-order').click()
    await page.getByRole('combobox', { name: 'Cliente' }).fill(other.name)
    await page.getByRole('option', { name: new RegExp(`^${other.name}`) }).click()
    const plate = `QW${String.fromCharCode(65 + Math.floor(Math.random() * 26))}${Math.floor(1 + Math.random() * 8)}A${Math.floor(10 + Math.random() * 89)}`
    const input = page.getByRole('combobox', { name: /Veículo, se tiver/ })
    await input.fill(plate.toLowerCase())
    await page.getByRole('option', { name: `+ Cadastrar “${plate.toLowerCase()}”` }).click()
    await expect(drawer(page)).toContainText(plate)
    await page.getByTestId('save-order').click()
    await expect(page.locator('.toast')).toContainText(/OS \d+ criada/)
    const saved = await readOrder(new URL(page.url()).searchParams.get('order') as string)
    expect((saved?.device as { serial?: string }).serial).toBe(plate)
  })
})

test('outro veículo na OS: do cliente primeiro, ✓ nos que já estão, placa nova cadastrada e já posta (device.list.pick, device.list.pick-create)', async ({ page }) => {
  const customer = await makeCustomer()
  const a = await makeDevice({ name: 'Pick Um' })
  const b = await makeDevice({ name: 'Pick Dois' })
  // b came with this customer before; the order has a.
  await makeOrder('admin', { customer, device: b, devices: [b], deviceIds: [b.id] })
  const order = await makeOrder('admin', { customer, device: a, devices: [a], deviceIds: [a.id] })
  await openOrder(page, 'admin', order.id)
  await menu(page, 'Outro veículo')
  const picker = page.getByRole('dialog', { name: 'Escolher veículo' })
  const own = picker.getByRole('group', { name: `De ${customer.name}` })
  await expect(own.getByRole('option', { name: /Pick Dois/ })).toBeVisible()
  await expect(own.getByRole('option', { name: /Pick Um/ })).toHaveAttribute('aria-selected', 'true')
  const plate = `PK${String.fromCharCode(65 + Math.floor(Math.random() * 26))}${Math.floor(1 + Math.random() * 8)}B${Math.floor(10 + Math.random() * 89)}`
  await picker.getByRole('combobox').fill(plate)
  await picker.getByRole('option', { name: `+ Cadastrar “${plate}”` }).click()
  await expect.poll(async () => ((await readOrder(order.id))?.devices as { serial?: string }[]).map((d) => d.serial)).toEqual([a.serial, plate])
})

test('Nova OS: "+ Cadastrar" some quando já há cliente com o mesmo nome (customer.picker.create)', async ({ page }) => {
  const customer = await makeCustomer({ name: `Joana Ávila ${Date.now()}` })
  await login(page, 'admin')
  await page.getByTestId('new-order').click()
  const input = page.getByRole('combobox', { name: 'Cliente' })
  await input.fill(customer.name.replace('Á', 'a').toLocaleLowerCase())
  await expect(page.getByRole('option', { name: new RegExp(customer.name) })).toBeVisible()
  await expect(page.getByRole('option', { name: /\+ Cadastrar/ })).toHaveCount(0)
  await input.fill(`${customer.name} Filha`)
  await expect(page.getByRole('option', { name: `+ Cadastrar “${customer.name} Filha”` })).toBeVisible()
})
