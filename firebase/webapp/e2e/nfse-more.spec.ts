// Notas fiscais, the rest of the slice: setting the nota up (nfse.setup.*),
// the nota inside the order and the customer (order.nfse.*, customer.detail.nfse-*,
// nfse.list.customer, nfse.orders.pick) and "falta configurar" (nfse.access.not-ready).
// Asaas is never called: /v1/app/nfse/* is answered here and the invoice
// documents the server would write are written by the test.
import { randomUUID } from 'node:crypto'
import { expect, test, type Page, type Route } from '@playwright/test'
import { makeCustomer, makeOrder, writeDoc } from './data'
import { expectNoAxeViolations, login, setTheme, type UserKey } from './helpers'

const today = () => new Date().toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
const ok = (route: Route, data: unknown, status = 200) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify({ success: true, data }) })
const refuse = (route: Route, status: number, code: string) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify({ success: false, error: { code, message: code } }) })
const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

async function makeNota(data: Record<string, unknown>) {
  const id = `nf-${randomUUID().slice(0, 8)}`
  await writeDoc(`invoices/${id}`, { status: 'authorized', value: 50, effectiveDate: today(), createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(), ...data })
  return id
}

const preview = (orders: { id: string; number: number }[], customer = { id: 'customer-2', name: 'Cliente 02' }) => ({
  value: 50 * orders.length,
  orders: orders.map((o) => ({ orderId: o.id, orderNumber: o.number, value: 50, servicesTotal: 50, productsTotal: 0, discount: 0 })),
  hasProducts: false,
  serviceDescription: 'Serviços',
  observations: '',
  effectiveDate: today(),
  customer: { ...customer, hasTaxId: true, contact: { email: 'c@exemplo.test' }, missingData: [] },
  invoicedOrders: {},
  municipalServiceName: '14.01',
})

const PAID = { status: 'done', total: 50, paidAmount: 50, payment: 'paid', paid: true }

// ---------------------------------------------------------------------------
// Configurar a nota
// ---------------------------------------------------------------------------

test('configurar: passos na ordem, dados fiscais, acesso à prefeitura, serviço buscado e quando emitir (nfse.setup.*)', async ({ page }) => {
  const base = { ready: false, fiscalInfo: null, municipalOptions: null, service: null }
  let setup: Record<string, unknown> = { ...base, missing: ['fiscalInfo', 'service'] }
  const city = { authenticationType: 'CERTIFICATE', supportsCancellation: false, usesSpecialTaxRegimes: true, specialTaxRegimesList: [{ label: 'Microempresa municipal', value: 'ME' }], usesServiceListItem: true }
  const sent: Record<string, unknown>[] = []
  const searches: string[] = []
  await page.route('**/v1/app/nfse/setup**', async (route) => {
    const url = new URL(route.request().url())
    const method = route.request().method()
    if (url.pathname.endsWith('/municipal-services')) {
      searches.push(url.searchParams.get('q') ?? '')
      return ok(route, [{ id: 'ms-1', description: '14.01 Lubrificação e revisão', issTax: 2 }, { id: 'ms-2', description: '14.02 Assistência técnica', issTax: 3 }])
    }
    if (method === 'POST') {
      sent.push({ fiscal: route.request().postDataJSON() })
      setup = { ...setup, fiscalInfo: { email: 'nota@oficina.test', simplesNacional: true }, municipalOptions: city, missing: ['cityAccess', 'service'] }
    }
    if (method === 'PUT') {
      const body = route.request().postDataJSON() as Record<string, unknown>
      sent.push({ service: body })
      setup = { ...setup, service: { ...body, autoIssue: body.autoIssue ?? 'manual' }, missing: (setup.missing as string[]).filter((m) => m !== 'service') }
      setup.ready = !(setup.missing as string[]).length
    }
    return ok(route, setup)
  })
  await login(page, 'admin', 'invoices')
  await page.getByTestId('nfse-setup-link').click()
  const screen = page.getByTestId('nfse-setup')
  await expect(screen).toContainText('Faltam 2 passos para emitir notas.')
  await expect(page.getByTestId('nfse-city-text')).toHaveText('Preencha primeiro os dados fiscais: aí dá para saber o que a prefeitura pede.')

  await page.getByTestId('nfse-setup-next').click()
  const fiscal = page.getByRole('dialog', { name: 'Dados fiscais da empresa' })
  await expect(fiscal.getByTestId('nfse-fiscal-save')).toBeDisabled()
  await fiscal.getByLabel('E-mail para receber as notas').fill('nota@oficina')
  await expect(fiscal).toContainText('Escreva um e-mail válido para salvar.')
  await fiscal.getByLabel('E-mail para receber as notas').fill('nota@oficina.test')
  await expect(fiscal.getByLabel('Empresa do Simples Nacional')).toBeChecked()
  await fiscal.getByTestId('nfse-fiscal-save').click()
  await expect(page.locator('.toast')).toContainText('Dados fiscais salvos')
  expect(sent[0]).toEqual({ fiscal: { email: 'nota@oficina.test', simplesNacional: true } })

  // The city asks for the certificate: the panel (sandbox account) and "conferir de novo".
  await expect(page.getByTestId('nfse-city-text')).toContainText('certificado digital')
  await expect(screen).toContainText('não deixa cancelar')
  await expect(page.getByTestId('nfse-open-panel')).toHaveAttribute('href', 'https://sandbox.asaas.com/')
  setup = { ...setup, missing: ['service'] }
  await page.getByTestId('nfse-recheck').click()
  await expect(page.getByTestId('nfse-open-panel')).toHaveCount(0)
  await expect(page.getByTestId('nfse-step-city')).toContainText('Pronto')

  // Special regime and service list item only because this city uses them.
  await page.getByTestId('nfse-step-fiscal').click()
  await expect(fiscal.getByLabel('Qual é o regime especial?')).toBeVisible()
  await expect(fiscal.getByLabel('Item da lista de serviço')).toBeVisible()
  await fiscal.getByRole('button', { name: 'Fechar' }).click()

  await page.getByTestId('nfse-setup-next').click()
  const service = page.getByRole('dialog', { name: 'Serviço da nota' })
  await expect(service.getByRole('button', { name: '14.01 Lubrificação e revisão' })).toBeVisible()
  await service.getByLabel('Busque pelo nome, ex.: manutenção').fill('assist')
  await expect.poll(() => searches.at(-1)).toBe('assist')
  await service.getByRole('button', { name: '14.02 Assistência técnica' }).click()
  await expect(service.getByLabel('ISS (%)')).toHaveValue('3')
  await service.getByLabel('O cliente retém o ISS').check()
  await service.getByText('Outros impostos (%)').click()
  await service.getByLabel('PIS').fill('0,65')
  await service.getByTestId('nfse-service-save').click()
  await expect(page.locator('.toast')).toContainText('Serviço da nota salvo')
  expect(sent[1]).toEqual({
    service: {
      municipalServiceId: 'ms-2',
      municipalServiceCode: null,
      municipalServiceName: '14.02 Assistência técnica',
      taxes: { retainIss: true, iss: 3, pis: 0.65, cofins: 0, csll: 0, inss: 0, ir: 0 },
      descriptionTemplate: '{servicos}',
    },
  })
  await expect(screen).toContainText('Tudo pronto.')
  await expect(page.getByTestId('nfse-setup-next')).toHaveCount(0)

  await page.getByTestId('nfse-auto-issue').getByLabel(/Quando a OS for paga/).check()
  await expect.poll(() => (sent[2] as { service?: { autoIssue?: string } } | undefined)?.service?.autoIssue).toBe('paid')

  // Typed code and name instead of the city's list.
  await page.getByTestId('nfse-step-service').click()
  await service.getByTestId('nfse-service-toggle').click()
  await service.getByLabel('Código do serviço na prefeitura').fill('1401')
  await expect(service.getByTestId('nfse-service-save')).toBeDisabled()
  await service.getByLabel('Nome do serviço').fill('Revisão')
  await service.getByTestId('nfse-service-save').click()
  await expect.poll(() => (sent[3] as { service?: Record<string, unknown> } | undefined)?.service).toMatchObject({ municipalServiceId: null, municipalServiceCode: '1401', municipalServiceName: 'Revisão' })
})

test('configurar é do dono e do admin: gerente não vê o link nem entra (nfse.list.setup, por papel)', async ({ page }) => {
  await login(page, 'manager', 'invoices')
  await expect(page.getByTestId('invoices')).toBeVisible()
  await expect(page.getByText('Carregando…')).toHaveCount(0)
  await expect(page.getByTestId('nfse-setup-link')).toHaveCount(0)
  await page.goto('invoices/setup')
  await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
})

test('falta configurar: admin vai para Configurar, gerente pede ao dono (nfse.access.not-ready, por papel)', async ({ page, browser }) => {
  const order = await makeOrder('admin', { ...PAID, total: 80, paidAmount: 0, payment: 'unpaid', paid: false })
  await page.route('**/v1/app/nfse/invoices/preview', (route) => refuse(route, 409, 'NFSE_NOT_READY'))
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Mais ações' }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Emitir nota fiscal' }).click()
  const hint = page.getByTestId('nfse-setup-hint')
  await expect(hint).toContainText('preencha os dados fiscais')
  await page.route('**/v1/app/nfse/setup', (route) => ok(route, { ready: false, missing: ['fiscalInfo'], fiscalInfo: null, municipalOptions: null, service: null }))
  await hint.getByRole('button', { name: 'Configurar' }).click()
  await expect(page.getByTestId('nfse-setup')).toBeVisible()

  const context = await browser.newContext({ ...test.info().project.use })
  const manager = await context.newPage()
  await manager.route('**/v1/app/nfse/invoices/preview', (route) => refuse(route, 409, 'NFSE_NOT_READY'))
  await openOrder(manager, 'manager', order.id)
  await panel(manager).getByRole('button', { name: 'Mais ações' }).click()
  await manager.getByRole('dialog').getByRole('button', { name: 'Emitir nota fiscal' }).click()
  await expect(manager.getByTestId('nfse-setup-hint')).toHaveText('Peça ao dono da empresa para configurar a nota fiscal em Integrações, Asaas.')
  await context.close()
})

// ---------------------------------------------------------------------------
// A nota na OS
// ---------------------------------------------------------------------------

test('OS concluída e paga: emitir é o botão azul; com nota, a linha diz a situação e abre a nota (order.nfse.next-step, order.nfse.row)', async ({ page }) => {
  const order = await makeOrder('admin', PAID)
  let sent: Record<string, unknown> | null = null
  await page.route('**/v1/app/nfse/invoices/preview', (route) => ok(route, preview([{ id: order.id, number: order.number }])))
  await page.route('**/v1/app/nfse/invoices', async (route) => {
    sent = route.request().postDataJSON()
    await writeDoc(`invoices/nf-${order.id}`, { status: 'authorized', number: '4321', value: 50, effectiveDate: today(), orderIds: [order.id], orders: [{ orderId: order.id, orderNumber: order.number, value: 50 }], customer: { id: 'customer-2', name: 'Cliente 02' }, createdAt: new Date().toISOString() })
    await ok(route, { id: `nf-${order.id}`, status: 'scheduled' }, 201)
  })
  await openOrder(page, 'admin', order.id)
  const next = panel(page).getByTestId('next-step')
  await expect(next).toHaveText('Emitir nota fiscal')
  await next.click()
  const sheet = page.getByRole('dialog', { name: 'Emitir nota fiscal' })
  await sheet.getByTestId('nfse-send').click()
  await expect(page.locator('.toast')).toContainText('Nota enviada para a prefeitura')
  expect(sent).toMatchObject({ orderIds: [order.id] })
  const row = panel(page).getByTestId('order-nfse')
  await expect(row).toContainText('Emitida · nº 4321')
  await expect(next).toHaveCount(0)
  // With an active nota the menu no longer offers a second one.
  await panel(page).getByRole('button', { name: 'Mais ações' }).click()
  await expect(page.getByRole('dialog').getByRole('button', { name: 'Emitir nota fiscal' })).toHaveCount(0)
  await page.keyboard.press('Escape')
  await row.getByRole('link').click()
  await expect(page).toHaveURL(new RegExp(`invoices\\?invoice=nf-${order.id}`))
  await expect(page.getByTestId('nfse-panel')).toContainText('Cliente 02')
})

test('OS concluída com saldo: "Emitir" na linha; nota recusada vira "Corrigir e emitir" no azul (order.nfse.issue-row)', async ({ page }) => {
  const owing = await makeOrder('admin', { ...PAID, paidAmount: 0, payment: 'unpaid', paid: false })
  await page.route('**/v1/app/nfse/invoices/preview', (route) => ok(route, preview([{ id: owing.id, number: owing.number }])))
  await openOrder(page, 'admin', owing.id)
  const row = panel(page).getByTestId('order-nfse-issue-row')
  await expect(row).toContainText('Nota fiscal')
  await row.getByRole('button', { name: 'Emitir' }).click()
  await expect(page.getByRole('dialog', { name: 'Emitir nota fiscal' })).toBeVisible()
  await page.keyboard.press('Escape')

  const refused = await makeOrder('admin', PAID)
  await makeNota({ status: 'error', errorCode: 'NO_SERVICES', orderIds: [refused.id], orders: [{ orderId: refused.id, orderNumber: refused.number, value: 50 }], customer: { id: 'customer-2', name: 'Cliente 02' } })
  await page.goto(`orders?order=${refused.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await expect(panel(page).getByTestId('order-nfse')).toContainText('Erro na prefeitura')
  await expect(panel(page).getByTestId('next-step')).toHaveText('Corrigir e emitir')
  await expect(panel(page).getByTestId('order-nfse-issue-row')).toContainText('Não emitida')
})

// ---------------------------------------------------------------------------
// As notas do cliente
// ---------------------------------------------------------------------------

test('cliente: notas emitidas abrem "Notas de X"; uma nota com várias OS escolhidas (customer.detail.nfse-list, nfse.list.customer, customer.detail.nfse-several, nfse.orders.pick)', async ({ page }) => {
  const customer = await makeCustomer()
  const a = await makeOrder('admin', { ...PAID, customer })
  const b = await makeOrder('admin', { ...PAID, customer })
  const c = await makeOrder('admin', { ...PAID, customer })
  await makeNota({ number: '777', orderIds: [c.id], orders: [{ orderId: c.id, orderNumber: c.number, value: 50 }], customer: { id: customer.id, name: customer.name } })
  let asked: Record<string, unknown> | null = null
  await page.route('**/v1/app/nfse/invoices/preview', async (route) => {
    asked = route.request().postDataJSON()
    await ok(route, preview([{ id: a.id, number: a.number }, { id: b.id, number: b.number }], customer))
  })
  await login(page, 'admin', `customers?customer=${customer.id}`)
  const nfse = page.getByTestId('customer-nfse')
  await expect(nfse.getByTestId('customer-nfse-list')).toHaveText('Notas fiscais · 1 emitida')

  await nfse.getByTestId('customer-nfse-several').click()
  const pick = page.getByRole('dialog', { name: 'Quais OS entram na nota?' })
  // The order that already has a nota is not offered.
  await expect(pick.getByLabel(new RegExp(`OS ${c.number}`))).toHaveCount(0)
  await expect(pick.getByTestId('nfse-pick-ok')).toBeDisabled()
  await pick.getByLabel(new RegExp(`OS ${a.number}`)).check()
  await pick.getByLabel(new RegExp(`OS ${b.number}`)).check()
  await pick.getByTestId('nfse-pick-ok').click()
  await expect(page.getByRole('dialog', { name: 'Emitir nota fiscal' })).toContainText('R$ 100,00')
  expect((asked as unknown as { orderIds: string[]; customerId: string }).orderIds.sort()).toEqual([a.id, b.id].sort())
  expect((asked as unknown as { customerId: string }).customerId).toBe(customer.id)
  await page.keyboard.press('Escape')

  await nfse.getByTestId('customer-nfse-list').click()
  await expect(page).toHaveURL(new RegExp(`invoices\\?customer=${customer.id}`))
  await expect(page.getByRole('heading', { level: 1 })).toHaveText(`Notas de ${customer.name}`)
  await expect(page.getByTestId('nfse-table')).toContainText('777')
  await expect(page.getByTestId('nfse-setup-link')).toHaveCount(0)
})

for (const theme of ['light', 'dark'] as const) {
  test(`axe: configurar a nota (${theme})`, async ({ page }) => {
    await page.route('**/v1/app/nfse/setup', (route) =>
      ok(route, { ready: true, missing: [], fiscalInfo: { email: 'a@b.test' }, municipalOptions: { authenticationType: null }, service: { municipalServiceId: 'ms-1', municipalServiceName: '14.01', taxes: { retainIss: false, iss: 2, pis: 0, cofins: 0, csll: 0, inss: 0, ir: 0 }, descriptionTemplate: '{servicos}', autoIssue: 'manual' } }),
    )
    await login(page, 'admin', 'invoices/setup')
    await setTheme(page, theme)
    await expect(page.getByTestId('nfse-auto-issue')).toBeVisible()
    await expectNoAxeViolations(page, `configurar nota ${theme}`)
  })
}
