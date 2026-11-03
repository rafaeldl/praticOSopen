// Batch on the selected orders (home.batch.*): each action asks first, says how
// many orders change, writes through the API and offers Undo when it can. The
// assistant over several orders (order.ai.batch) proposes, lists and applies only
// after the person confirms; the model is simulated, Asaas too.
import { expect, test, type Page, type Route } from '@playwright/test'
import { makeCustomer, makeOrder, readOrder, writeDoc } from './data'
import { login, type UserKey } from './helpers'

const bar = (page: Page) => page.getByRole('region', { name: 'Ações nas OS selecionadas' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })
const toast = (page: Page) => page.locator('.toast')

async function select(page: Page, user: UserKey, search: string, numbers: number[]) {
  await login(page, user, `orders?f=all&q=${encodeURIComponent(search)}`)
  for (const number of numbers) await page.getByLabel(`Selecionar OS ${number}`).check()
  await expect(bar(page)).toContainText(`${numbers.length} selecionada`)
}

test('mudar situação em lote: pergunta, diz quantas mudam, grava e desfaz (home.batch.status)', async ({ page }) => {
  const name = `Lote Situação ${Date.now()}`
  const customer = { id: 'customer-2', name }
  const a = await makeOrder('admin', { customer, status: 'approved' })
  const b = await makeOrder('admin', { customer, status: 'approved' })
  const c = await makeOrder('admin', { customer, status: 'progress' })
  await select(page, 'admin', name, [a.number, b.number, c.number])
  await bar(page).getByRole('button', { name: 'Mudar a situação' }).click()
  await dialog(page, 'Qual a situação?').getByRole('button', { name: 'Na oficina' }).click()
  const confirm = dialog(page, /Mudar 2 OS para Na oficina\?/)
  await expect(confirm).toContainText(`OS ${a.number}`)
  await expect(confirm).toContainText(`OS ${b.number}`)
  await expect(confirm).toContainText('1 já está assim')
  await confirm.getByRole('button', { name: 'Mudar 2 OS' }).click()
  await expect(toast(page)).toContainText('2 atualizadas')
  await expect.poll(async () => (await readOrder(a.id))?.status).toBe('progress')
  await expect.poll(async () => (await readOrder(b.id))?.status).toBe('progress')
  await toast(page).getByRole('button', { name: 'Desfazer' }).click()
  await expect.poll(async () => (await readOrder(a.id))?.status).toBe('approved')
  await expect.poll(async () => (await readOrder(b.id))?.status).toBe('approved')
  expect((await readOrder(c.id))?.status).toBe('progress')
})

test('responsável em lote: pergunta com o nome, grava e desfaz para o que era (home.batch.assignee)', async ({ page }) => {
  const name = `Lote Resp ${Date.now()}`
  const customer = { id: 'customer-2', name }
  const a = await makeOrder('admin', { customer })
  const b = await makeOrder('admin', { customer, assignedTo: { id: 'e2e-manager', name: 'Marta Gerente' } })
  await select(page, 'admin', name, [a.number, b.number])
  await bar(page).getByRole('button', { name: 'Responsável' }).click()
  await dialog(page, 'Quem é o responsável?').getByRole('button', { name: 'Tiago Tecnico' }).click()
  const confirm = dialog(page, /Pôr Tiago Tecnico como responsável de 2 OS\?/)
  await confirm.getByRole('button', { name: 'Mudar 2 OS' }).click()
  await expect(toast(page)).toContainText('2 atualizadas')
  await expect.poll(async () => ((await readOrder(a.id))?.assignedTo as { id?: string } | null)?.id).toBe('e2e-technician')
  await expect.poll(async () => ((await readOrder(b.id))?.assignedTo as { id?: string } | null)?.id).toBe('e2e-technician')
  await toast(page).getByRole('button', { name: 'Desfazer' }).click()
  await expect.poll(async () => ((await readOrder(a.id))?.assignedTo as { id?: string } | null)?.id ?? null).toBe(null)
  await expect.poll(async () => ((await readOrder(b.id))?.assignedTo as { id?: string } | null)?.id).toBe('e2e-manager')
})

test('técnico: lote sem responsável e só com as situações que pode (home.batch.*)', async ({ page }) => {
  const name = `Lote Tec ${Date.now()}`
  const a = await makeOrder('technician', { customer: { id: 'customer-2', name }, status: 'approved' })
  await select(page, 'technician', name, [a.number])
  await expect(bar(page).getByRole('button', { name: 'Responsável' })).toHaveCount(0)
  await expect(bar(page).getByRole('button', { name: 'Mandar cobrança' })).toHaveCount(0)
  await expect(bar(page).getByRole('button', { name: /assistente/ })).toHaveCount(0)
})

test('mandar cobrança em lote: um link por cliente, quem não tem CPF fica de fora, mandar e desfazer (home.batch.charge)', async ({ page }) => {
  const tag = Date.now()
  const ana = await makeCustomer({ name: `Lote Cobra Ana ${tag}`, phone: '+5511990007001', taxId: '52998224725' })
  const bia = await makeCustomer({ name: `Lote Cobra Bia ${tag}`, phone: '+5511990007002', taxId: '52998224725' })
  const caio = await makeCustomer({ name: `Lote Cobra Caio ${tag}`, phone: null })
  const owing = (customer: { id: string; name: string }, total: number) =>
    makeOrder('admin', { customer, status: 'done', total, paidAmount: 0, payment: 'unpaid', services: [{ service: { id: 'service-1', name: 'Serviço 1' }, value: total }] })
  const a1 = await owing(ana, 40)
  const a2 = await owing(ana, 60)
  const b1 = await owing(bia, 90)
  const c1 = await owing(caio, 30)
  const created: { path: string; body: Record<string, unknown> }[] = []
  const canceled: string[] = []
  await page.route(/\/v1\/app\/(orders|customers)\/[^/]+\/charges/, async (route: Route) => {
    const request = route.request()
    const path = new URL(request.url()).pathname
    if (request.method() === 'POST') {
      const body = request.postDataJSON() as Record<string, unknown>
      created.push({ path, body })
      const id = `bc-${created.length}`
      const charge = { status: 'pending', value: body.value, dueDate: body.dueDate, mode: 'single', invoiceUrl: `https://sandbox.asaas.com/i/${id}`, paidAsaasPaymentIds: [], createdAt: new Date().toISOString() }
      if (path.includes('/orders/')) await writeDoc(`orders/${path.split('/')[4]}/charges/${id}`, charge)
      return route.fulfill({ status: 201, json: { success: true, data: { id, ...charge } } })
    }
    canceled.push(path)
    return route.fulfill({ status: 200, json: { success: true, data: { status: 'canceled' } } })
  })
  await select(page, 'admin', `Lote Cobra`, [a1.number, a2.number, b1.number, c1.number])
  await bar(page).getByRole('button', { name: 'Mandar cobrança' }).click()
  const sheet = dialog(page, 'Mandar cobrança de 3 OS')
  await expect(sheet).toContainText(ana.name)
  await expect(sheet).toContainText('R$ 100,00')
  await expect(sheet).toContainText(bia.name)
  await expect(sheet).toContainText('R$ 90,00')
  await expect(sheet.getByTestId('batch-charge-left-out')).toContainText(caio.name)
  await expect(sheet.getByTestId('batch-charge-left-out')).toContainText('sem CPF ou CNPJ')
  await sheet.getByRole('button', { name: 'Criar 2 links' }).click()
  await expect(sheet.getByRole('heading', { name: 'Links de pagamento prontos' })).toBeVisible()
  expect(created).toHaveLength(2)
  const toAna = created.find((call) => call.path.includes(`/customers/${ana.id}/`))
  expect(toAna?.body).toMatchObject({ value: 100 })
  expect((toAna?.body.orderIds as string[]).sort()).toEqual([a1.id, a2.id].sort())
  const toBia = created.find((call) => call.path.includes(`/orders/${b1.id}/`))
  expect(toBia?.body).toMatchObject({ value: 90, mode: 'single' })
  const whatsapp = sheet.getByTestId('batch-charge-whatsapp')
  await expect(whatsapp).toHaveCount(2)
  expect(decodeURIComponent((await whatsapp.first().getAttribute('href'))!)).toMatch(/wa\.me\/55119900070\d\d\?text=[\s\S]*https:\/\/sandbox\.asaas\.com\/i\/bc-/)
  await sheet.getByRole('button', { name: 'Desfazer' }).click()
  await dialog(page, /Cancelar os 2 links\?/).getByRole('button', { name: 'Cancelar os links' }).click()
  await expect(toast(page)).toContainText('2 links cancelados')
  expect(canceled).toHaveLength(2)
})

test('assistente em várias OS: propõe, mostra a lista e só aplica depois de confirmar; desfaz (order.ai.batch)', async ({ page }) => {
  const name = `Lote IA ${Date.now()}`
  const customer = { id: 'customer-2', name }
  const a = await makeOrder('admin', { customer, status: 'approved' })
  const b = await makeOrder('admin', { customer, status: 'approved' })
  let asked = 0
  await page.route(/\/v1\/app\/ai\/status/, (route) => route.fulfill({ json: { success: true, data: { enabled: true, usage: { used: 10, limit: 100 } } } }))
  await page.route(/\/v1\/app\/ai\/order-assist/, (route) => {
    asked++
    return route.fulfill({
      json: {
        success: true,
        data: {
          items: [{ kind: 'service', name: 'Serviço 3', value: 150, quantity: 1, catalogId: 'service-3', description: null, alternatives: [] }],
          changes: [],
          usage: { used: 10 + asked, limit: 100 },
        },
      },
    })
  })
  await select(page, 'admin', name, [a.number, b.number])
  await bar(page).getByRole('button', { name: /Pedir ao assistente/ }).click()
  const sheet = dialog(page, 'Pedir ao assistente em 2 OS')
  await sheet.getByLabel('O que fazer nessas OS?').fill('pôr o serviço 3')
  await sheet.getByRole('button', { name: 'Preparar' }).click()
  await expect(sheet.getByTestId('ai-batch-plan')).toContainText(`OS ${a.number}`)
  await expect(sheet.getByTestId('ai-batch-plan')).toContainText('+ Serviço 3')
  // Nothing written before confirming.
  expect(((await readOrder(a.id))?.services as unknown[]).length).toBe(1)
  await sheet.getByRole('button', { name: 'Aplicar em 2 OS' }).click()
  await expect(toast(page)).toContainText('2 atualizadas')
  const names = async (id: string) => ((await readOrder(id))?.services as { service?: { name?: string } }[]).map((s) => s.service?.name)
  await expect.poll(() => names(a.id)).toContain('Serviço 3')
  await expect.poll(() => names(b.id)).toContain('Serviço 3')
  expect(asked).toBe(2)
  await toast(page).getByRole('button', { name: 'Desfazer' }).click()
  await expect.poll(() => names(a.id)).not.toContain('Serviço 3')
  await expect.poll(() => names(b.id)).not.toContain('Serviço 3')
})

test('assistente em lote respeita a cota: pede menos OS quando faltam pedidos no mês (order.ai.batch)', async ({ page }) => {
  const name = `Lote IA Cota ${Date.now()}`
  const customer = { id: 'customer-2', name }
  const a = await makeOrder('admin', { customer, status: 'approved' })
  const b = await makeOrder('admin', { customer, status: 'approved' })
  let asked = 0
  await page.route(/\/v1\/app\/ai\/status/, (route) => route.fulfill({ json: { success: true, data: { enabled: true, usage: { used: 99, limit: 100 } } } }))
  await page.route(/\/v1\/app\/ai\/order-assist/, (route) => {
    asked++
    return route.fulfill({ status: 500, json: {} })
  })
  await select(page, 'admin', name, [a.number, b.number])
  await bar(page).getByRole('button', { name: /Pedir ao assistente/ }).click()
  const sheet = dialog(page, 'Pedir ao assistente em 2 OS')
  await expect(sheet).toContainText('Falta 1 pedido ao assistente neste mês')
  await expect(sheet.getByRole('button', { name: 'Preparar' })).toBeDisabled()
  expect(asked).toBe(0)
})
