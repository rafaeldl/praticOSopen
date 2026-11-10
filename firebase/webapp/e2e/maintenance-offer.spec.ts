// "Quando é a próxima manutenção?" after the order is done (device.maintenance.offer,
// device.maintenance.answer, device.maintenance.no-repeat, device.maintenance.limit),
// per role: only who manages devices is asked. The question sits inside the order
// (not over it), so going on needs no dismissal; "Agora não" is the refusal.
import { expect, test, type Page } from './test'
import { makeContract, makeCustomer, makeDevice, makeOrder, readDoc } from './data'
import { login, type UserKey } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const question = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' }).getByTestId('maintenance-offer')

const today = () => new Date().toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
function addMonths(day: string, months: number): string {
  const [y, m, d] = day.split('-').map(Number) as [number, number, number]
  const first = new Date(Date.UTC(y, m - 1 + months, 1))
  const last = new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 1, 0)).getUTCDate()
  return `${first.getUTCFullYear()}-${String(first.getUTCMonth() + 1).padStart(2, '0')}-${String(Math.min(d, last)).padStart(2, '0')}`
}

async function orderInProgress(author: UserKey, extra: Record<string, unknown> = {}) {
  const device = await makeDevice(extra.device as Record<string, unknown> | undefined)
  const aggr = { id: device.id, name: device.name, serial: device.serial }
  const order = await makeOrder(author, { status: 'progress', device: aggr, devices: [aggr], deviceIds: [device.id], ...extra, ...(extra.device ? { device: aggr } : {}) })
  return { order, device }
}

async function finish(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await panel(page).getByTestId('next-step').click()
}

test('ao concluir, o dono marca a próxima manutenção do veículo (device.maintenance.offer, device.maintenance.answer)', async ({ page }) => {
  const { order, device } = await orderInProgress('admin')
  await finish(page, 'admin', order.id)
  await expect(question(page)).toBeVisible()
  await expect(question(page)).toContainText(device.name)
  await question(page).getByRole('button', { name: /6 meses/ }).click()
  await expect(question(page)).toHaveCount(0)
  await expect.poll(async () => (await readDoc(`devices/${device.id}`))?.nextMaintenanceDate).toBe(addMonths(today(), 6))
  // The server keeps for whom (the order's customer).
  expect((await readDoc(`devices/${device.id}`))?.nextMaintenanceCustomer).toMatchObject({ id: 'customer-2' })
})

test('Não repetir tira só a data que esta OS cumpriu; a distante fica (device.maintenance.no-repeat)', async ({ page }) => {
  const near = await orderInProgress('admin', { device: { nextMaintenanceDate: today() } })
  await finish(page, 'admin', near.order.id)
  await question(page).getByRole('button', { name: 'Não repetir' }).click()
  await expect.poll(async () => (await readDoc(`devices/${near.device.id}`))?.nextMaintenanceDate ?? null).toBeNull()

  const far = await orderInProgress('admin', { device: { nextMaintenanceDate: '2099-01-10' } })
  await page.goto(`orders?order=${far.order.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await panel(page).getByTestId('next-step').click()
  await question(page).getByRole('button', { name: 'Não repetir' }).click()
  await expect(question(page)).toHaveCount(0)
  expect((await readDoc(`devices/${far.device.id}`))?.nextMaintenanceDate).toBe('2099-01-10')
})

test('três recusas seguidas param a pergunta (device.maintenance.limit)', async ({ page }) => {
  const first = await orderInProgress('admin')
  await finish(page, 'admin', first.order.id)
  for (let round = 0; round < 3; round++) {
    if (round) {
      const next = await orderInProgress('admin')
      await page.goto(`orders?order=${next.order.id}`)
      await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
      await panel(page).getByTestId('next-step').click()
    }
    await expect(question(page)).toBeVisible()
    await question(page).getByRole('button', { name: 'Agora não' }).click()
    await expect(question(page)).toHaveCount(0)
  }
  const last = await orderInProgress('admin')
  await page.goto(`orders?order=${last.order.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await panel(page).getByTestId('next-step').click()
  await expect(panel(page).getByTestId('order-status')).toContainText('Concluído')
  await expect(question(page)).toHaveCount(0)
})

test('técnico conclui sem a pergunta (não gerencia aparelhos) (device.maintenance.offer, por papel)', async ({ page }) => {
  const { order } = await orderInProgress('technician')
  await finish(page, 'technician', order.id)
  await expect(panel(page).getByTestId('order-status')).toContainText('Concluído')
  await expect(question(page)).toHaveCount(0)
})

test('aparelho com contrato ativo: contratos na ficha, próxima pelo contrato e sem a pergunta ao concluir (device.detail.contracts, device.detail.maintenance-contract)', async ({ page }) => {
  const { order, device } = await orderInProgress('admin')
  const aggr = { id: device.id, name: device.name, serial: device.serial }
  const contract = await makeContract('admin', {}, { device: aggr, devices: [aggr], deviceIds: [device.id] })
  await login(page, 'admin', `devices?device=${device.id}`)
  const detail = page.getByTestId('device-detail')
  const list = detail.getByTestId('device-contracts')
  await expect(list).toContainText(`${contract.number}`)
  await expect(detail.getByTestId('device-maintenance')).toContainText('Pelo contrato')
  await expect(detail.getByTestId('maintenance-set')).toHaveCount(0)
  await list.getByRole('link').first().click()
  await expect(page).toHaveURL(new RegExp(`order=${contract.id}`))

  await page.goto(`orders?order=${order.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await panel(page).getByTestId('next-step').click()
  await expect(panel(page).getByTestId('order-status')).toContainText('Concluído')
  await expect(question(page)).toHaveCount(0)
})

test('Nova OS salva já concluída, com veículo, faz a pergunta (device.maintenance.offer)', async ({ page }) => {
  const device = await makeDevice()
  await makeCustomer({ name: 'Concluída Na Hora' })
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.locator('h1').click()
  await page.keyboard.press('n')
  const drawer = page.getByRole('dialog', { name: 'Nova OS' })
  await page.getByRole('combobox', { name: 'Cliente' }).fill('Concluída Na Hora')
  await page.keyboard.press('Enter')
  await page.getByRole('combobox', { name: /Veículo/ }).fill(device.serial)
  await page.getByRole('option', { name: new RegExp(device.name) }).click()
  await drawer.locator('summary', { hasText: 'Mais opções' }).focus()
  await page.keyboard.press('Enter')
  await expect(drawer.getByLabel('Situação')).toBeVisible()
  await drawer.getByLabel('Situação').selectOption({ label: 'Concluído' })
  await page.keyboard.press('ControlOrMeta+Enter')
  await expect(question(page)).toBeVisible()
  await question(page).getByRole('button', { name: /3 meses/ }).click()
  await expect.poll(async () => (await readDoc(`devices/${device.id}`))?.nextMaintenanceDate).toBe(addMonths(today(), 3))
})
