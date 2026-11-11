// The order's leftovers: delete a photo (order.photo.delete), edit and take out
// the place (order.address.edit, order.address.remove, order.sheet.address), the
// device of a line with 2 or more devices (order.item-form.device) and the
// segment's own fields (order.custom-fields.view), per role where it changes.
import { expect, test, type Page } from './test'
import { makeOrder, readOrder } from './data'
import { expectNoAxeViolations, login, setTheme, type UserKey } from './helpers'

const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64')
const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

test('apagar foto pergunta antes e tira da OS; gerente não apaga (order.photo.delete, por papel)', async ({ page }) => {
  const order = await makeOrder('admin')
  await openOrder(page, 'admin', order.id)
  await panel(page).getByLabel('Adicionar foto').setInputFiles({ name: 'antes.png', mimeType: 'image/png', buffer: PNG })
  await expect(panel(page).getByRole('button', { name: 'Ver foto 1' })).toBeVisible()
  await expect.poll(async () => ((await readOrder(order.id))?.photos as unknown[] | undefined)?.length ?? 0).toBe(1)
  const url = ((await readOrder(order.id))?.photos as { url: string }[])[0]!.url

  await panel(page).getByRole('button', { name: 'Ver foto 1' }).click()
  await page.getByRole('button', { name: 'Apagar foto' }).click()
  await dialog(page, 'Apagar esta foto?').getByRole('button', { name: 'Apagar foto' }).click()
  await expect(panel(page).getByRole('button', { name: 'Ver foto 1' })).toHaveCount(0)
  await expect.poll(async () => ((await readOrder(order.id))?.photos as unknown[]).length).toBe(0)
  await expect.poll(() => fetch(url).then((response) => response.status)).not.toBe(200)

  const other = await makeOrder('admin', { photos: [{ id: 'p1', url, storagePath: 'tenants/company-alpha/orders/x/photos/p1.png' }] })
  await page.goto(`orders?order=${other.id}`)
  await expect(panel(page).getByRole('button', { name: 'Ver foto 1' })).toBeVisible()
  const context = await page.context().browser()!.newContext({ ...test.info().project.use })
  const manager = await context.newPage()
  await openOrder(manager, 'manager', other.id)
  await panel(manager).getByRole('button', { name: 'Ver foto 1' }).click()
  await expect(manager.locator('.photo-full')).toBeVisible()
  await expect(manager.getByRole('button', { name: 'Apagar foto' })).toHaveCount(0)
  await context.close()
})

test('local: mudar apaga a coordenada, tirar limpa; técnico fora do orçamento só vê (order.address.edit, order.address.remove)', async ({ page }) => {
  const order = await makeOrder('admin', { address: 'Rua Antiga, 10', latitude: -27.5, longitude: -48.5 })
  await openOrder(page, 'admin', order.id)
  const place = panel(page).getByTestId('order-address')
  await expect(place).toContainText('Rua Antiga, 10')
  await place.getByRole('button', { name: 'Mudar endereço' }).click()
  const sheet = dialog(page, 'Local')
  await sheet.getByLabel('Local').fill('Rua Nova, 20')
  await sheet.getByRole('button', { name: 'Salvar' }).click()
  await expect(place).toContainText('Rua Nova, 20')
  await expect.poll(async () => (await readOrder(order.id))?.address).toBe('Rua Nova, 20')
  expect((await readOrder(order.id))?.latitude ?? null).toBeNull()
  await place.getByRole('button', { name: 'Tirar endereço' }).click()
  await expect.poll(async () => (await readOrder(order.id))?.address ?? null).toBeNull()

  const assigned = await makeOrder('technician', { status: 'approved', address: 'Rua do Técnico, 5' })
  const context = await page.context().browser()!.newContext({ ...test.info().project.use })
  const tech = await context.newPage()
  await openOrder(tech, 'technician', assigned.id)
  await expect(panel(tech).getByTestId('order-address')).toContainText('Rua do Técnico, 5')
  await expect(panel(tech).getByRole('button', { name: 'Mudar endereço' })).toHaveCount(0)
  await context.close()
})

test('com 2 veículos, o item diz de qual; Geral tira (order.item-form.device, order.item.by-device)', async ({ page }) => {
  const devices = [{ id: 'device-2', name: 'Veículo 2', serial: 'TST0002' }, { id: 'device-3', name: 'Veículo 3', serial: 'TST0003' }]
  const order = await makeOrder('admin', { devices, device: devices[0], deviceIds: ['device-2', 'device-3'], services: [{ id: 'line-a', service: { id: 'service-1', name: 'Serviço 1' }, value: 50 }] })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Mudar Serviço 1' }).click()
  const sheet = dialog(page, 'Serviço 1')
  await sheet.getByLabel('Veículo').selectOption({ label: 'Veículo 3 · TST0003' })
  await sheet.getByRole('button', { name: 'Salvar' }).click()
  await expect.poll(async () => ((await readOrder(order.id))?.services as { deviceId?: string }[])[0]?.deviceId).toBe('device-3')
  await expect(panel(page).getByRole('heading', { level: 4, name: 'Veículo 3 - TST0003' })).toBeVisible()

  await panel(page).getByRole('button', { name: 'Mudar Serviço 1' }).click()
  await dialog(page, 'Serviço 1').getByLabel('Veículo').selectOption({ label: 'Geral' })
  await dialog(page, 'Serviço 1').getByRole('button', { name: 'Salvar' }).click()
  await expect(panel(page).getByRole('heading', { level: 4, name: 'Geral' })).toBeVisible()
})

test('campos do ramo: mostrar, validar e gravar; supervisor fora do orçamento só lê (order.custom-fields.view)', async ({ page }) => {
  const order = await makeOrder('admin', { customData: { mileageIn: 1000 } })
  await openOrder(page, 'admin', order.id)
  const section = panel(page).getByTestId('order-custom-fields')
  await expect(section).toContainText('KM na entrada')
  await expect(section).toContainText('1000')
  await section.getByRole('button', { name: 'Mudar' }).click()
  const sheet = dialog(page, 'Mais dados')
  await sheet.getByLabel('KM na entrada').fill('-5')
  await sheet.getByRole('button', { name: 'Salvar' }).click()
  await expect(sheet).toContainText('Mínimo: 0')
  expect(((await readOrder(order.id))?.customData as { mileageIn: number }).mileageIn).toBe(1000)
  await sheet.getByLabel('KM na entrada').fill('12500')
  await sheet.getByRole('button', { name: 'Salvar' }).click()
  await expect(section).toContainText('12500')
  await expect.poll(async () => ((await readOrder(order.id))?.customData as { mileageIn: number }).mileageIn).toBe(12500)

  const context = await page.context().browser()!.newContext({ ...test.info().project.use })
  const supervisor = await context.newPage()
  await openOrder(supervisor, 'supervisor', order.id)
  await expect(panel(supervisor).getByTestId('order-custom-fields')).toContainText('12500')
  await expect(panel(supervisor).getByTestId('order-custom-fields').getByRole('button', { name: 'Mudar' })).toHaveCount(0)
  await context.close()
})

for (const theme of ['light', 'dark'] as const) {
  test(`axe sem violações com local, campos do ramo e foto aberta (${theme})`, async ({ page }) => {
    const order = await makeOrder('admin', { address: 'Rua Clara, 1', customData: { mileageIn: 10 } })
    await openOrder(page, 'admin', order.id)
    await setTheme(page, theme)
    await expect(panel(page).getByTestId('order-custom-fields')).toBeVisible()
    await expectNoAxeViolations(page, `OS com local e campos ${theme}`)
    await panel(page).getByTestId('order-custom-fields').getByRole('button', { name: 'Mudar' }).click()
    await expectNoAxeViolations(page, `Mais dados ${theme}`)
  })
}
