// Cadastro rápido de dentro da OS (docs/QUICK_REGISTER.md): pedir o essencial na
// hora e completar depois sem sair da OS (order.quick.*).
import { expect, test, type Page } from './test'
import { makeCustomer, makeDevice, makeOrder, readDoc, readOrder } from './data'
import { login, type UserKey } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const drawer = (page: Page) => page.getByRole('dialog', { name: /Nova OS/ })

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

test('Nova OS: telefone de outro cliente oferece usar esse (order.quick.customer)', async ({ page }) => {
  const stamp = Date.now()
  const phone = `(49) 9${String(stamp).slice(-4)}-${String(stamp).slice(-8, -4)}`
  const existing = await makeCustomer({ phone })
  await login(page, 'admin')
  await page.getByTestId('new-order').click()
  await page.getByRole('combobox', { name: 'Cliente' }).fill(`Pessoa Nova ${stamp}`)
  await page.getByRole('option', { name: `+ Cadastrar “Pessoa Nova ${stamp}”` }).click()
  const quick = page.getByTestId('quick-customer')
  await quick.getByLabel('Telefone ou WhatsApp').fill(phone.replace(/\D/g, ''))
  await expect(quick.getByTestId('quick-duplicate')).toContainText(existing.name)
  await quick.getByRole('button', { name: `Usar ${existing.name}` }).click()
  await expect(drawer(page)).toContainText(existing.name)
  await expect(page.getByRole('combobox', { name: /Veículo, se tiver/ })).toBeFocused()
})

test('Nova OS: "Mais dados" leva o que foi digitado ao cadastro completo e volta escolhido (order.quick.customer)', async ({ page }) => {
  const name = `Completa ${Date.now()}`
  await login(page, 'admin')
  await page.getByTestId('new-order').click()
  await page.getByRole('combobox', { name: 'Cliente' }).fill(name)
  await page.getByRole('option', { name: `+ Cadastrar “${name}”` }).click()
  await page.getByTestId('quick-customer').getByLabel('Telefone ou WhatsApp').fill('47 3333 0202')
  await page.getByTestId('quick-customer-more').click()
  const form = page.getByTestId('customer-form')
  await expect(form.getByLabel('Nome', { exact: true })).toHaveValue(name)
  await expect(form.getByLabel('Telefone ou WhatsApp')).toHaveValue('(47) 3333-0202')
  await form.getByText('Mais dados').click()
  await form.getByLabel('Endereço').fill('Rua das Flores, 10')
  await form.getByTestId('save-customer').click()
  await expect(drawer(page)).toContainText(name)
  await expect(page.getByRole('combobox', { name: /Veículo, se tiver/ })).toBeFocused()
})

test('Nova OS: Esc no bloco volta para a busca e salvar com cadastro aberto avisa (order.quick.customer)', async ({ page }) => {
  await login(page, 'admin')
  await page.getByTestId('new-order').click()
  await page.getByRole('combobox', { name: 'Cliente' }).fill('Quase Cliente')
  await page.getByRole('option', { name: '+ Cadastrar “Quase Cliente”' }).click()
  await page.keyboard.press('ControlOrMeta+Enter')
  await expect(drawer(page).getByRole('alert')).toContainText('Termine ou cancele o cadastro aberto')
  await page.getByTestId('quick-customer').getByLabel('Telefone ou WhatsApp').focus()
  await page.keyboard.press('Escape')
  await expect(page.getByTestId('quick-customer')).toHaveCount(0)
  await expect(page.getByRole('combobox', { name: 'Cliente' })).toBeFocused()
})

test('OS salva: "+ WhatsApp" e "+ Placa" completam o cadastro sem sair da OS e a OS acompanha (order.quick.complete)', async ({ page }) => {
  const customer = await makeCustomer({ name: `Sem Fone ${Date.now()}` })
  const device = await makeDevice({ name: 'Onix Sem Placa', serial: null })
  const onOrder = { id: device.id, name: device.name }
  const order = await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, device: onOrder, devices: [onOrder], deviceIds: [device.id] })
  await openOrder(page, 'admin', order.id)
  const missing = panel(page).getByTestId('order-missing')
  await missing.getByRole('button', { name: '+ WhatsApp' }).click()
  const form = page.getByTestId('customer-form')
  await form.getByLabel('Telefone ou WhatsApp').fill('47977776666')
  await form.getByTestId('save-customer').click()
  await expect.poll(async () => ((await readOrder(order.id))?.customer as { phone?: string }).phone).toBe('(47) 97777-6666')
  expect((await readDoc(`customers/${customer.id}`))?.phone).toBe('(47) 97777-6666')
  await expect(missing.getByRole('button', { name: '+ WhatsApp' })).toHaveCount(0)
  // Still on the order: nothing navigated away.
  await expect(panel(page)).toContainText(customer.name)

  await missing.getByRole('button', { name: '+ Placa' }).click()
  await page.getByTestId('device-form').getByLabel('Placa').pressSequentially('onx2b34')
  await page.getByTestId('save-device').click()
  await expect.poll(async () => ((await readOrder(order.id))?.devices as { serial?: string }[])[0]?.serial).toBe('ONX2B34')
  await expect(panel(page).getByTestId('order-missing')).toHaveCount(0)
})

test('OS salva: menu "…" abre os dados do cliente por cima da OS (order.quick.complete)', async ({ page }) => {
  const customer = await makeCustomer({ phone: '(47) 3333-0303' })
  const order = await makeOrder('admin', { customer: { id: customer.id, name: customer.name, phone: '(47) 3333-0303' } })
  await openOrder(page, 'admin', order.id)
  await expect(panel(page).getByTestId('order-missing')).toHaveCount(0)
  await panel(page).getByRole('button', { name: 'Mais ações' }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Dados do cliente' }).click()
  const form = page.getByTestId('customer-form')
  await form.getByLabel('Nome', { exact: true }).fill(`${customer.name} Silva`)
  await form.getByTestId('save-customer').click()
  await expect.poll(async () => ((await readOrder(order.id))?.customer as { name?: string }).name).toBe(`${customer.name} Silva`)
  await expect(page).toHaveURL(new RegExp(`order=${order.id}`))
})
