// Fatia 04: mandar ao cliente, receber e cobrar. Every write goes through the
// API and the tests check what the server saved. WhatsApp is never opened (the
// tests read the link) and Asaas is simulated: the charge routes are answered
// here and the charge documents written as the server would.
import { expect, test, type Page, type Route } from '@playwright/test'
import { makeCustomer, makeOrder, queryDocs, readOrder, readShareToken, updateOrderDoc, writeDoc } from './data'
import { chooseCompany, expectNoAxeViolations, expectNoSideScroll, login, setTheme, type UserKey } from './helpers'

test.use({ permissions: ['clipboard-read', 'clipboard-write'] })

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  if (user === 'owner') await chooseCompany(page, 'Oficina Alfa')
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

const done = (customer: { id: string; name: string }, total: number, extra: Record<string, unknown> = {}) =>
  makeOrder('admin', { customer, status: 'done', total, paidAmount: 0, payment: 'unpaid', services: [{ service: { id: 'service-1', name: 'Serviço 1' }, value: total }], ...extra })

// ---------------------------------------------------------------------------
// Mandar ao cliente
// ---------------------------------------------------------------------------

test('mandar ao cliente: link da API, texto da situação e WhatsApp com o telefone do cadastro (order.share-sheet.view, whatsapp, message)', async ({ page }) => {
  const customer = await makeCustomer({ phone: '+5511990001234' })
  const order = await makeOrder('admin', { customer: { id: customer.id, name: customer.name, phone: '+5511900000000' }, status: 'done' })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByTestId('share-open').click()
  const sheet = dialog(page, 'Mandar para o cliente')
  await expect(sheet.getByTestId('share-who')).toContainText(`${customer.name} abre a OS pelo link, aprova e comenta.`)
  const url = await sheet.getByTestId('share-url').textContent()
  expect(url).toMatch(/\/q\/[A-Za-z0-9_-]+$/)
  await expect(sheet.getByTestId('share-text')).toHaveValue(new RegExp(`Olá, ${customer.name}! Serviço concluído: OS ${order.number}\\.`))
  await expect(sheet.getByTestId('share-text')).toHaveValue(/Oficina Alfa$/)
  const href = await sheet.getByTestId('share-whatsapp').getAttribute('href')
  // The number of the customer's record, not the old copy inside the order (defect 80).
  expect(href).toContain('https://wa.me/5511990001234?text=')
  expect(decodeURIComponent(href!.split('text=')[1]!)).toContain(url!)
  expect(await sheet.getByTestId('share-whatsapp').getAttribute('target')).toBe('_blank')
})

test('copiar o link e trocar o que o cliente pode fazer desativa o link anterior (order.share-sheet.copy, permissions, expiry)', async ({ page }) => {
  const order = await makeOrder('admin')
  await openOrder(page, 'admin', order.id)
  const sheet = dialog(page, 'Mandar para o cliente')
  // The page moves focus to its title once after loading; a key pressed in that instant is lost.
  // Single-key shortcuts stop while a layer is open, so pressing again never opens two.
  await expect(async () => {
    await page.keyboard.press('m')
    await expect(sheet).toBeVisible({ timeout: 1000 })
  }).toPass()
  const first = (await sheet.getByTestId('share-url').textContent())!
  await sheet.getByTestId('share-copy').click()
  await expect(page.locator('.toast')).toContainText('Link copiado')
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(first)

  await sheet.getByLabel('O que o cliente pode fazer').selectOption('view')
  await expect(sheet.getByTestId('share-url')).not.toHaveText(first)
  await expect(sheet.getByTestId('share-who')).toContainText('Cliente 02 abre a OS pelo link.')
  const old = await readShareToken(first.split('/q/')[1]!)
  expect(old?.revokedAt).toBeTruthy()

  const second = (await sheet.getByTestId('share-url').textContent())!
  await sheet.getByLabel('Vale por quanto tempo?').selectOption('30')
  await expect(sheet.getByTestId('share-url')).not.toHaveText(second)
  await expect(sheet.getByLabel('Vale por quanto tempo?')).toHaveValue('30')
  const current = await readShareToken((await sheet.getByTestId('share-url').textContent())!.split('/q/')[1]!)
  expect(current?.permissions).toEqual(['view'])
  expect(Date.parse(String(current?.expiresAt)) - Date.now()).toBeGreaterThan(29 * 86_400_000)

  // "Gerar link novo" keeps the rules and turns the previous link off (order.share-sheet.regenerate).
  const third = (await sheet.getByTestId('share-url').textContent())!
  await sheet.getByRole('button', { name: 'Gerar link novo' }).click()
  await expect(sheet.getByTestId('share-url')).not.toHaveText(third)
  expect((await readShareToken(third.split('/q/')[1]!))?.revokedAt).toBeTruthy()
})

test('desativar o link pergunta antes e o link deixa de abrir (order.share-sheet.revoke)', async ({ page }) => {
  const order = await makeOrder('admin')
  await openOrder(page, 'admin', order.id)
  await panel(page).getByTestId('share-open').click()
  const sheet = dialog(page, 'Mandar para o cliente')
  const token = (await sheet.getByTestId('share-url').textContent())!.split('/q/')[1]!
  await sheet.getByRole('button', { name: 'Desativar o link' }).click()
  await dialog(page, 'Desativar o link').getByRole('button', { name: 'Desativar o link' }).click()
  await expect(page.locator('.toast')).toContainText('Link desativado')
  // DELETE removes the token: /q/{token} no longer opens.
  expect(await readShareToken(token)).toBeUndefined()
})

test('OS sem cliente: diz o que falta, sem erro genérico (order.share-sheet.no-customer)', async ({ page }) => {
  const order = await makeOrder('admin', { customer: null })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByTestId('share-open').click()
  await expect(dialog(page, 'Mandar para o cliente').getByTestId('share-no-customer')).toContainText('Esta OS ainda não tem cliente')
})

test('técnico também manda o link da OS dele, pelo menu (order.share.open, por papel)', async ({ page }) => {
  const order = await makeOrder('technician', { customer: { id: 'customer-3', name: 'Cliente 03' } })
  await openOrder(page, 'technician', order.id)
  await panel(page).getByRole('button', { name: 'Mais ações' }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Mandar para o cliente' }).click()
  await expect(dialog(page, 'Mandar para o cliente').getByTestId('share-url')).toHaveText(/\/q\//)
})

// ---------------------------------------------------------------------------
// Receber de uma OS
// ---------------------------------------------------------------------------

test('receber com forma e dia, ver no histórico e remover com confirmação (pay.order.mark-received, pay.widget.date, pay.order.remove-transaction)', async ({ page }) => {
  const order = await done({ id: 'customer-4', name: 'Cliente 04' }, 200, { createdAt: new Date(Date.now() - 10 * 86_400_000).toISOString() })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByTestId('next-step').click()
  const sheet = dialog(page, 'Receber')
  // Nothing comes chosen: who paid cash would have to change it (REVISAO-UX 14).
  await expect(sheet.getByLabel(/Como foi pago/)).toHaveValue('')
  await sheet.getByLabel('Quanto recebeu').fill('80')
  await sheet.getByLabel(/Como foi pago/).selectOption('cash')
  const day = new Date(Date.now() - 2 * 86_400_000).toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
  await sheet.getByLabel('Quando').fill(day)
  await sheet.getByRole('button', { name: 'Marcar como recebido' }).click()
  const history = panel(page).getByTestId('payment-history')
  await expect(history.getByTestId('payment-row')).toHaveCount(1)
  await expect(history).toContainText('R$ 80,00 · Dinheiro')
  await expect(history).toContainText('por Alberto Admin')
  const saved = await readOrder(order.id)
  const tx = (saved?.transactions as Record<string, unknown>[])[0]!
  expect(tx.paymentMethod).toBe('cash')
  expect(String(tx.paidAt).slice(0, 10)).toBe(day)

  await history.getByRole('button', { name: 'Remover R$ 80,00' }).click()
  await dialog(page, 'Remover pagamento?').getByRole('button', { name: 'Remover' }).click()
  await expect(history).toHaveCount(0)
  expect((await readOrder(order.id))?.paidAmount).toBe(0)
})

test('desfazer pagamentos: financeiro sim, consultor não; parte de recebimento bloqueia (pay.order.undo-all, por papel)', async ({ page }) => {
  const tx = (id: string, amount: number, extra = {}) => ({ id, type: 'payment', amount, createdAt: new Date().toISOString(), createdBy: { id: 'e2e-admin', name: 'Alberto Admin' }, ...extra })
  const order = await done({ id: 'customer-5', name: 'Cliente 05' }, 100, { transactions: [tx('m1', 30), tx('asaas_pay_1_0', 20, { billingType: 'PIX' })], paidAmount: 50 })
  await openOrder(page, 'admin', order.id)
  const history = panel(page).getByTestId('payment-history')
  await expect(history).toContainText('Pix pelo link')
  // The Asaas payment never offers Remover (409 ASAAS_LOCKED).
  await expect(history.getByRole('button', { name: /Remover/ })).toHaveCount(1)
  await history.getByTestId('undo-all').click()
  await dialog(page, 'Desfazer pagamentos').getByRole('button', { name: 'Desfazer pagamentos' }).click()
  await expect(history.getByTestId('payment-row')).toHaveCount(1)
  const saved = await readOrder(order.id)
  expect((saved?.transactions as { id: string }[]).map((t) => t.id)).toEqual(['asaas_pay_1_0'])

  const shared = await makeOrder('admin', { status: 'done', total: 100, paidAmount: 30, transactions: [tx('r9_0', 30, { receiptGroupId: 'r9' })] })
  await page.goto(`orders?order=${shared.id}`)
  await expect(panel(page).getByTestId('payment-history')).toContainText('Parte de um recebimento de várias OS')
  await expect(panel(page).getByTestId('undo-all')).toHaveCount(0)
  await expect(panel(page).getByTestId('payment-history').getByRole('button', { name: /Remover/ })).toHaveCount(0)
})

test('consultor remove o pagamento da OS dele, mas não desfaz todos (pay.order.remove-transaction, por papel)', async ({ page }) => {
  const own = await makeOrder('consultant', {
    customer: { id: 'customer-6', name: 'Cliente 06' },
    status: 'done',
    total: 100,
    paidAmount: 30,
    transactions: [{ id: 'c1', type: 'payment', amount: 30, createdAt: new Date().toISOString() }],
  })
  await openOrder(page, 'consultant', own.id)
  const history = panel(page).getByTestId('payment-history')
  await expect(history.getByRole('button', { name: 'Remover R$ 30,00' })).toBeVisible()
  await expect(history.getByText('Desfazer pagamentos')).toHaveCount(0)
  await history.getByRole('button', { name: 'Remover R$ 30,00' }).click()
  await dialog(page, 'Remover pagamento?').getByRole('button', { name: 'Remover' }).click()
  await expect(history).toHaveCount(0)
  expect((await readOrder(own.id))?.paidAmount).toBe(0)
})

test('OS cancelada: só o histórico, sem ações (pay.order.blocked-status)', async ({ page }) => {
  const order = await makeOrder('admin', {
    status: 'canceled',
    payment: null,
    total: 100,
    paidAmount: 40,
    transactions: [{ id: 'k1', type: 'payment', amount: 40, createdAt: new Date().toISOString() }],
  })
  await openOrder(page, 'admin', order.id)
  await expect(panel(page).getByTestId('blocked-status')).toContainText('não recebe pagamento')
  await expect(panel(page).getByTestId('payment-history')).toContainText('R$ 40,00')
  await expect(panel(page).getByTestId('payment-history').getByRole('button')).toHaveCount(0)
})

// ---------------------------------------------------------------------------
// Receber de um cliente em várias OS
// ---------------------------------------------------------------------------

async function openCustomer(page: Page, user: UserKey, id: string) {
  await login(page, user, `customers?customer=${id}`)
  await expect(page.getByTestId('customer-detail').getByText('Carregando…')).toHaveCount(0)
}

test('receber de um cliente em várias OS: divisão da mais antiga, total antes de gravar e confirmação (pay.customer.view, pick-orders, mark-received)', async ({ page }) => {
  const customer = await makeCustomer()
  const older = await done(customer, 100, { createdAt: new Date(Date.now() - 5 * 86_400_000).toISOString() })
  const newer = await done(customer, 50, { createdAt: new Date(Date.now() - 2 * 86_400_000).toISOString() })
  await openCustomer(page, 'admin', customer.id)
  await page.getByTestId('customer-receive').click()
  const drawer = page.getByTestId('receive-customer')
  await expect(drawer.getByTestId('receive-order')).toHaveCount(2)
  await expect(drawer.getByTestId('receive-total')).toContainText('Recebe R$ 150,00 em 2 OS')
  await drawer.getByLabel('Quanto recebeu').fill('120')
  await drawer.getByLabel('Quanto recebeu').blur()
  await expect(drawer.getByTestId('receive-total')).toContainText(`Quita OS ${older.number}. Paga R$ 20,00 da OS ${newer.number}. Ficam R$ 30,00.`)
  await drawer.getByLabel(/Como foi pago/).selectOption('pix')
  await drawer.getByTestId('receive-customer-save').click()
  const confirm = dialog(page, `Receber R$ 120,00 de ${customer.name}?`)
  await expect(confirm).toContainText('Forma: Pix.')
  await confirm.getByRole('button', { name: 'Confirmar recebimento' }).click()
  await expect(page.locator('.toast')).toContainText(`Recebido R$ 120,00 de ${customer.name}`)
  expect((await readOrder(older.id))?.paidAmount).toBe(100)
  expect((await readOrder(newer.id))?.paidAmount).toBe(20)
  const [receipt] = await queryDocs('receipts', 'customer.id', customer.id)
  expect(receipt?.amount).toBe(120)
  expect(receipt?.paymentMethod).toBe('pix')
})

test('saldo mudou enquanto a tela estava aberta: avisa e não grava (pay.customer.balance-check)', async ({ page }) => {
  const customer = await makeCustomer()
  const a = await done(customer, 100)
  await done(customer, 60)
  await openCustomer(page, 'manager', customer.id)
  await page.getByTestId('customer-receive').click()
  const drawer = page.getByTestId('receive-customer')
  await expect(drawer.getByTestId('receive-total')).toContainText('R$ 160,00')
  await updateOrderDoc(a.id, { paidAmount: 100, payment: 'paid', paid: true })
  await drawer.getByTestId('receive-customer-save').click()
  await dialog(page, /Receber R\$ 160,00/).getByRole('button', { name: 'Confirmar recebimento' }).click()
  await expect(page.locator('.toast')).toContainText('Os valores mudaram desde que a tela abriu.')
  expect(await queryDocs('receipts', 'customer.id', customer.id)).toHaveLength(0)
  await expect(drawer.getByTestId('receive-order')).toHaveCount(1)
})

test('recebimentos do cliente: imprimir recibo e desfazer com confirmação (customer.detail.receipts, receipt.detail.undo, receipt.share.pdf)', async ({ page }) => {
  const customer = await makeCustomer()
  const a = await done(customer, 70)
  const b = await done(customer, 30)
  await openCustomer(page, 'admin', customer.id)
  await page.getByTestId('customer-receive').click()
  await page.getByTestId('receive-customer-save').click()
  await dialog(page, /Receber R\$ 100,00/).getByRole('button', { name: 'Confirmar recebimento' }).click()
  await expect(page.locator('.toast')).toContainText(`Recebido R$ 100,00 de ${customer.name}`)

  await page.getByTestId('customer-receipts').click()
  const list = page.getByTestId('receipts')
  await expect(list.getByTestId('receipt-row')).toHaveCount(1)
  await expect(list).toContainText('R$ 100,00')
  await page.evaluate(() => (window.print = () => window.dispatchEvent(new Event('afterprint'))))
  const printed = page.waitForFunction(() => document.querySelector('[data-testid="receipt-print"]')?.textContent?.includes('Recebemos de'))
  await list.getByRole('button', { name: 'Imprimir recibo' }).click()
  await printed

  await list.getByRole('button', { name: 'Desfazer recebimento' }).click()
  await dialog(page, 'Desfazer o recebimento de R$ 100,00?').getByRole('button', { name: 'Desfazer recebimento' }).click()
  await expect(page.locator('.toast')).toContainText('Recebimento desfeito')
  expect((await readOrder(a.id))?.paidAmount).toBe(0)
  expect((await readOrder(b.id))?.paidAmount).toBe(0)
})

// ---------------------------------------------------------------------------
// Financeiro > Receber
// ---------------------------------------------------------------------------

test('Financeiro > Receber: por cliente, marcar OS de um cliente e receber junto (fin.tab.receivable, fin.tab.pick-order)', async ({ page }) => {
  const customer = await makeCustomer()
  const a = await done(customer, 90)
  const b = await done(customer, 10)
  await login(page, 'manager', 'finance')
  const view = page.getByTestId('finance-receive')
  await expect(page.getByRole('heading', { level: 1 })).toContainText('para receber de')
  await view.getByLabel(`Marcar tudo de ${customer.name}`).check()
  await expect(view.getByRole('region')).toContainText('2 OS marcadas: R$ 100,00')
  await view.getByTestId('finance-receive-picked').click()
  await page.getByTestId('receive-customer-save').click()
  await dialog(page, /Receber R\$ 100,00/).getByRole('button', { name: 'Confirmar recebimento' }).click()
  await expect(view.getByLabel(`Marcar tudo de ${customer.name}`)).toHaveCount(0)
  expect((await readOrder(a.id))?.payment).toBe('paid')
  expect((await readOrder(b.id))?.payment).toBe('paid')
})

test('Financeiro: OS de dois clientes não recebem juntas; consultor não entra (por papel)', async ({ page }) => {
  const one = await makeCustomer()
  const two = await makeCustomer()
  const a = await done(one, 15)
  const b = await done(two, 25)
  await login(page, 'admin', 'finance')
  const view = page.getByTestId('finance-receive')
  await view.getByLabel(`Marcar OS ${a.number}`).check()
  await view.getByLabel(`Marcar OS ${b.number}`).check()
  await expect(view.getByText('Para receber junto, marque OS de um cliente só.')).toBeVisible()
  await expect(view.getByTestId('finance-receive-picked')).toHaveCount(0)

  const consultant = await page.context().browser()!.newContext()
  const other = await consultant.newPage()
  await login(other, 'consultant', 'finance')
  await expect(other).toHaveURL(/forbidden/)
  await consultant.close()
})

// ---------------------------------------------------------------------------
// Imprimir várias OS (tela grande)
// ---------------------------------------------------------------------------

test('imprimir várias OS selecionadas, uma por página (order.pdf.batch)', async ({ page }) => {
  const customer = await makeCustomer()
  const a = await done(customer, 11)
  const b = await done(customer, 12)
  // Never the real print dialog: stubbed before the app loads, so a reload or a navigation keeps it.
  await page.addInitScript(() => (window.print = () => undefined))
  await login(page, 'admin', `orders?f=all&q=${encodeURIComponent(customer.name)}`)
  await page.getByLabel(`Selecionar OS ${a.number}`).check()
  await page.getByLabel(`Selecionar OS ${b.number}`).check()
  await page.getByTestId('batch-print').click()
  const sheets = page.getByTestId('print-sheet')
  await expect(sheets).toHaveCount(2)
  await expect(sheets.filter({ hasText: `OS ${a.number}` })).toHaveCount(1)
  await expect(sheets.filter({ hasText: `OS ${b.number}` })).toHaveCount(1)
})

// ---------------------------------------------------------------------------
// Cobrança (Asaas simulado)
// ---------------------------------------------------------------------------

/** Answers the charge routes like the server, writing the charge document it would write. */
async function simulateAsaas(page: Page, orderId: string) {
  const calls: Record<string, unknown>[] = []
  await page.route(`**/v1/app/orders/${orderId}/charges**`, async (route: Route) => {
    const request = route.request()
    if (request.method() === 'POST') {
      const body = request.postDataJSON() as Record<string, unknown>
      calls.push(body)
      const id = `ch-${calls.length}`
      const charge = { status: 'pending', value: body.value, dueDate: body.dueDate, mode: body.mode, installmentCount: body.installmentCount ?? null, invoiceUrl: `https://sandbox.asaas.com/i/${id}`, paidAsaasPaymentIds: [], createdAt: new Date().toISOString() }
      await writeDoc(`orders/${orderId}/charges/${id}`, charge)
      return route.fulfill({ status: 201, contentType: 'application/json', body: JSON.stringify({ success: true, data: { id, ...charge } }) })
    }
    if (request.method() === 'DELETE') {
      const id = request.url().split('/charges/')[1]!.split('?')[0]!
      await writeDoc(`orders/${orderId}/charges/${id}`, { status: 'canceled' }, true)
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ success: true, data: { id, status: 'canceled' } }) })
    }
    return route.continue()
  })
  return calls
}

test('mandar cobrança: CPF pedido e conferido, criar e mandar num passo, cancelar (charge.order.form, charge.order.tax-id, pay.order.send-charge, pay.order.cancel-link)', async ({ page }) => {
  const customer = await makeCustomer({ phone: '+5511990005678' })
  const order = await done({ ...customer, phone: '+5511990005678' } as { id: string; name: string }, 300)
  const calls = await simulateAsaas(page, order.id)
  await openOrder(page, 'admin', order.id)
  await panel(page).getByTestId('charge-new').click()
  const sheet = dialog(page, 'Mandar cobrança')
  await expect(sheet.getByLabel('Valor')).toHaveValue('300,00')
  await sheet.getByLabel('Parcelar no cartão?').selectOption('3')
  await sheet.getByLabel('CPF ou CNPJ do cliente').fill('111.111.111-11')
  await expect(sheet.getByTestId('charge-problem')).toHaveText('Esse CPF ou CNPJ não confere.')
  await expect(sheet.getByTestId('charge-create')).toBeDisabled()
  await sheet.getByLabel('CPF ou CNPJ do cliente').fill('529.982.247-25')
  await sheet.getByTestId('charge-create').click()
  await expect(sheet.getByRole('heading', { name: 'Link de pagamento pronto' })).toBeVisible()
  expect(calls[0]).toMatchObject({ value: 300, mode: 'cardInstallments', installmentCount: 3, customerTaxId: '52998224725' })
  const href = await sheet.getByTestId('charge-whatsapp').getAttribute('href')
  expect(href).toContain('https://wa.me/5511990005678?text=')
  expect(decodeURIComponent(href!)).toContain('https://sandbox.asaas.com/i/ch-1')
  await sheet.getByRole('button', { name: 'Fechar' }).click()

  const card = panel(page).getByTestId('order-charge')
  await expect(card.getByTestId('charge-state')).toHaveText(`Esperando ${customer.name} pagar`)
  await expect(card).toContainText('3x no cartão')
  // "Mandar de novo" sends the same Asaas link as the customer screen (defect 7); copy copies it.
  expect(decodeURIComponent((await card.getByTestId('charge-resend').getAttribute('href'))!)).toContain('https://sandbox.asaas.com/i/ch-1')
  await card.getByRole('button', { name: 'Copiar link' }).click()
  await expect(page.locator('.toast')).toContainText('Link copiado')
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe('https://sandbox.asaas.com/i/ch-1')
  await card.getByTestId('charge-cancel').click()
  await dialog(page, /Cancelar o link de R\$ 300,00/).getByRole('button', { name: 'Cancelar cobrança' }).click()
  await expect(card.getByTestId('charge-new')).toBeVisible()
})

test('cobrança de várias OS do cliente: um link só, copiar e cancelar (pay.customer.send-charge, copy-link, cancel-link, charge.customer.form)', async ({ page }) => {
  const customer = await makeCustomer({ phone: '+5511990004321', taxId: '52998224725' })
  await done(customer, 40)
  await done(customer, 60)
  const calls: Record<string, unknown>[] = []
  await page.route(`**/v1/app/customers/${customer.id}/charges**`, async (route: Route) => {
    if (route.request().method() === 'POST') {
      const body = route.request().postDataJSON() as Record<string, unknown>
      calls.push(body)
      const charge = { customer: { id: customer.id, name: customer.name }, status: 'pending', value: body.value, dueDate: body.dueDate, orderIds: body.orderIds, invoiceUrl: 'https://sandbox.asaas.com/i/cc-1', paidAsaasPaymentIds: [], createdAt: new Date().toISOString() }
      await writeDoc('customerCharges/cc-1', charge)
      return route.fulfill({ status: 201, contentType: 'application/json', body: JSON.stringify({ success: true, data: { id: 'cc-1', ...charge } }) })
    }
    await writeDoc('customerCharges/cc-1', { status: 'canceled' }, true)
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ success: true, data: { id: 'cc-1', status: 'canceled' } }) })
  })
  await openCustomer(page, 'admin', customer.id)
  await page.getByTestId('customer-receive').click()
  await page.getByTestId('customer-charge-new').click()
  const sheet = dialog(page, 'Mandar cobrança')
  // One link for several orders: no installments, and the CPF of the record is used.
  await expect(sheet.getByLabel('Parcelar no cartão?')).toHaveCount(0)
  await expect(sheet.getByLabel('CPF ou CNPJ do cliente')).toHaveCount(0)
  await sheet.getByTestId('charge-create').click()
  await expect(sheet.getByRole('heading', { name: 'Link de pagamento pronto' })).toBeVisible()
  expect(calls[0]).toMatchObject({ value: 100 })
  expect((calls[0]!.orderIds as string[]).length).toBe(2)
  await sheet.getByRole('button', { name: 'Fechar' }).click()
  const open = page.getByTestId('customer-charge')
  await expect(open).toContainText('Link aberto de R$ 100,00')
  await open.getByRole('button', { name: 'Copiar link' }).click()
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe('https://sandbox.asaas.com/i/cc-1')
  await open.getByRole('button', { name: 'Cancelar cobrança' }).click()
  await dialog(page, /Cancelar o link de R\$ 100,00/).getByRole('button', { name: 'Cancelar cobrança' }).click()
  await expect(page.locator('.toast')).toContainText('Link cancelado')
  await expect(open).toHaveCount(0)
})

test('a OS mudou de valor depois do link: avisa e "Manter" fica guardado (pay.widget.charge-changed, pay.order.charge-keep)', async ({ page }) => {
  const order = await done({ id: 'customer-7', name: 'Cliente 07' }, 50)
  await writeDoc(`orders/${order.id}/charges/old`, { status: 'pending', value: 80, dueDate: '2099-01-01', mode: 'single', invoiceUrl: 'https://sandbox.asaas.com/i/old', paidAsaasPaymentIds: [], createdAt: new Date().toISOString() })
  await openOrder(page, 'admin', order.id)
  const card = panel(page).getByTestId('order-charge')
  await expect(card.getByTestId('charge-changed')).toContainText('Agora falta R$ 50,00, mas o link ainda cobra R$ 80,00.')
  await card.getByRole('button', { name: 'Manter o link de R$ 80,00' }).click()
  await expect(card.getByTestId('charge-changed')).toHaveCount(0)
  await page.reload()
  await expect(panel(page).getByTestId('order-charge')).toContainText('Cobrança de R$ 80,00')
  await expect(panel(page).getByTestId('charge-changed')).toHaveCount(0)
})

test('consultor não vê cobrança (sem chargeOrder), mas recebe na OS dele (por papel)', async ({ page }) => {
  const order = await makeOrder('consultant', { customer: { id: 'customer-8', name: 'Cliente 08' }, status: 'done', total: 40, paidAmount: 0 })
  await openOrder(page, 'consultant', order.id)
  await expect(panel(page).getByTestId('next-step')).toHaveText('Receber R$ 40,00')
  await expect(panel(page).getByTestId('order-charge')).toHaveCount(0)
})

// ---------------------------------------------------------------------------
// Acessibilidade e telas pequenas
// ---------------------------------------------------------------------------

for (const theme of ['light', 'dark'] as const) {
  test(`axe sem violações em Mandar para o cliente (${theme})`, async ({ page }) => {
    const customer = await makeCustomer({ phone: '+5511990009999' })
    const order = await done(customer, 45)
    await openOrder(page, 'admin', order.id)
    await setTheme(page, theme)
    await panel(page).getByTestId('share-open').click()
    await expect(dialog(page, 'Mandar para o cliente').getByTestId('share-url')).toBeVisible()
    await expectNoAxeViolations(page, `mandar (${theme})`)
  })

  test(`axe sem violações em Receber de vários e no Financeiro (${theme})`, async ({ page }) => {
    const customer = await makeCustomer()
    await done(customer, 45)
    await done(customer, 55)
    await login(page, 'admin', 'finance')
    await expect(page.getByTestId('finance-row').first()).toBeVisible()
    await setTheme(page, theme)
    await expectNoAxeViolations(page, `financeiro (${theme})`)
    await page.goto(`customers?customer=${customer.id}`)
    await page.getByTestId('customer-receive').click()
    await expect(page.getByTestId('receive-order')).toHaveCount(2)
    await expectNoAxeViolations(page, `receber de vários (${theme})`)
  })
}

test('sem rolagem lateral em 320 px: Receber de vários e Financeiro', async ({ page }) => {
  const customer = await makeCustomer()
  await done(customer, 45)
  await done(customer, 55)
  await page.setViewportSize({ width: 320, height: 800 })
  await login(page, 'admin', 'finance')
  await expect(page.getByTestId('finance-row').first()).toBeVisible()
  await expectNoSideScroll(page, ['.recv'])
  await page.goto(`customers?customer=${customer.id}`)
  await page.getByTestId('customer-receive').click()
  await expect(page.getByTestId('receive-order')).toHaveCount(2)
  await expectNoSideScroll(page)
})

// ---------------------------------------------------------------------------
// Revisão do #518
// ---------------------------------------------------------------------------

test('R2: RECEIPT_EXISTS relê e mostra o que foi gravado, nunca o valor digitado', async ({ page }) => {
  const customer = await makeCustomer()
  const a = await done(customer, 100, { createdAt: new Date(Date.now() - 3 * 86_400_000).toISOString() })
  await done(customer, 50)
  // The server saves R$ 40 (another try got there first), and this answer says the receipt already exists.
  await page.route(`**/v1/app/customers/${customer.id}/receipts`, async (route: Route) => {
    if (route.request().method() !== 'POST') return route.continue()
    const body = route.request().postDataJSON() as Record<string, unknown>
    await route.fetch({ postData: JSON.stringify({ ...body, allocations: [{ orderId: a.id, amount: 40 }] }) })
    return route.fulfill({ status: 409, contentType: 'application/json', body: JSON.stringify({ success: false, error: { code: 'RECEIPT_EXISTS', message: 'x' } }) })
  })
  await openCustomer(page, 'admin', customer.id)
  await page.getByTestId('customer-receive').click()
  await page.getByTestId('receive-customer-save').click()
  await dialog(page, /Receber R\$ 150,00/).getByRole('button', { name: 'Confirmar recebimento' }).click()
  await expect(page.locator('.toast')).toContainText(`Recebido R$ 40,00 de ${customer.name}`)
})

test('R2: resposta perdida, saldo mudou: avisa e o próximo recebimento usa outro id', async ({ page }) => {
  const customer = await makeCustomer()
  await done(customer, 100, { createdAt: new Date(Date.now() - 3 * 86_400_000).toISOString() })
  await done(customer, 50)
  let first = true
  await page.route(`**/v1/app/customers/${customer.id}/receipts`, async (route: Route) => {
    if (route.request().method() !== 'POST' || !first) return route.continue()
    first = false
    await route.fetch()
    return route.abort('failed')
  })
  await openCustomer(page, 'admin', customer.id)
  await page.getByTestId('customer-receive').click()
  const drawer = page.getByTestId('receive-customer')
  await drawer.getByLabel('Quanto recebeu').fill('100')
  await drawer.getByLabel('Quanto recebeu').blur()
  await drawer.getByTestId('receive-customer-save').click()
  await dialog(page, /Receber R\$ 100,00/).getByRole('button', { name: 'Confirmar recebimento' }).click()
  await expect(page.locator('.toast')).toContainText('Sem conexão')
  await drawer.getByTestId('receive-customer-save').click()
  await dialog(page, /Receber R\$ 100,00/).getByRole('button', { name: 'Confirmar recebimento' }).click()
  await expect(page.locator('.toast')).toContainText('Os valores mudaram')
  await expect(drawer.getByTestId('receive-order')).toHaveCount(1)
  await drawer.getByTestId('receive-customer-save').click()
  await dialog(page, /Receber R\$ 50,00/).getByRole('button', { name: 'Confirmar recebimento' }).click()
  await expect(page.locator('.toast')).toContainText(`Recebido R$ 50,00 de ${customer.name}`)
  const receipts = await queryDocs('receipts', 'customer.id', customer.id)
  expect(receipts.map((r) => r.amount).sort()).toEqual([100, 50].sort())
})

test('R3: Financeiro > Receber traz OS aberta com sinal, da mais antiga, e o total bate (fin.tab.receivable)', async ({ page }) => {
  const older = await makeCustomer()
  const newer = await makeCustomer()
  const signal = await makeOrder('admin', { customer: older, status: 'approved', total: 100, paidAmount: 30, payment: 'unpaid', createdAt: new Date(Date.now() - 400 * 86_400_000).toISOString() })
  const progress = await makeOrder('admin', { customer: newer, status: 'progress', total: 80, paidAmount: 0, payment: 'unpaid' })
  await done(newer, 20)
  await login(page, 'admin', 'finance')
  const view = page.getByTestId('finance-receive')
  // The one with a down payment owes R$ 70; an open order with nothing paid is not owed yet.
  await expect(view.getByLabel(`Marcar OS ${signal.number}`)).toBeVisible()
  await expect(view.getByLabel(`Marcar OS ${progress.number}`)).toHaveCount(0)
  await expect(view.getByTestId('finance-row').filter({ hasText: `OS ${signal.number}` })).toContainText('R$ 70,00')
  // Oldest debt first.
  const groups = await view.locator('.recv-group th').allTextContents()
  expect(groups.findIndex((g) => g.includes(older.name))).toBeLessThan(groups.findIndex((g) => g.includes(newer.name)))
})

test('R4: consultor vê o link aberto só para ler; Receber não fica azul e avisa (pay.widget.charge-section)', async ({ page }) => {
  const order = await makeOrder('consultant', { customer: { id: 'customer-9', name: 'Cliente 09' }, status: 'done', total: 60, paidAmount: 0 })
  await writeDoc(`orders/${order.id}/charges/open1`, { status: 'pending', value: 60, dueDate: '2099-01-01', mode: 'single', invoiceUrl: 'https://sandbox.asaas.com/i/open1', paidAsaasPaymentIds: [], createdAt: new Date().toISOString() })
  await openOrder(page, 'consultant', order.id)
  const card = panel(page).getByTestId('order-charge')
  await expect(card.getByTestId('charge-state')).toHaveText('Esperando Cliente 09 pagar')
  await expect(card.getByTestId('charge-cancel')).toHaveCount(0)
  await expect(panel(page).getByTestId('next-step')).not.toHaveClass(/btn--primary/)
  await panel(page).getByTestId('next-step').click()
  await expect(dialog(page, 'Receber')).toContainText('A cobrança aberta se ajusta sozinha, sem avisar Cliente 09.')
})

test('R4 com o canal ao vivo travado: o link aberto aparece mesmo assim (leitura avulsa)', async ({ page }) => {
  const order = await makeOrder('consultant', { customer: { id: 'customer-9', name: 'Cliente 09' }, status: 'done', total: 60, paidAmount: 0 })
  await writeDoc(`orders/${order.id}/charges/open1`, { status: 'pending', value: 60, dueDate: '2099-01-01', mode: 'single', invoiceUrl: 'https://sandbox.asaas.com/i/open1', paidAsaasPaymentIds: [], createdAt: new Date().toISOString() })
  await page.route('**/google.firestore.v1.Firestore/Listen/**', () => {})
  await login(page, 'consultant', `orders?order=${order.id}`)
  const card = panel(page).getByTestId('order-charge')
  await expect(card.getByTestId('charge-state')).toHaveText('Esperando Cliente 09 pagar', { timeout: 20_000 })
  await expect(panel(page).getByTestId('next-step')).not.toHaveClass(/btn--primary/)
})

test('cobranças sem resposta (canal travado e leitura com erro): erro com Tentar de novo e Receber nunca azul (M1 do #518)', async ({ page }) => {
  const order = await makeOrder('consultant', { customer: { id: 'customer-9', name: 'Cliente 09' }, status: 'done', total: 60, paidAmount: 0 })
  await writeDoc(`orders/${order.id}/charges/open1`, { status: 'pending', value: 60, dueDate: '2099-01-01', mode: 'single', invoiceUrl: 'https://sandbox.asaas.com/i/open1', paidAsaasPaymentIds: [], createdAt: new Date().toISOString() })
  await page.route('**/google.firestore.v1.Firestore/Listen/**', () => {})
  const chargesRead = (url: URL) => url.pathname.endsWith(`/orders/${order.id}:runQuery`)
  await page.route(chargesRead, (route) => route.abort())
  await login(page, 'consultant', `orders?order=${order.id}`)
  // Before anything is known, and after the read fails, Receber is never the blue button.
  await expect(panel(page).getByTestId('next-step')).toBeVisible({ timeout: 20_000 })
  await expect(panel(page).getByTestId('next-step')).not.toHaveClass(/btn--primary/)
  const error = panel(page).getByTestId('charge-error')
  await expect(error).toBeVisible({ timeout: 20_000 })
  await expect(panel(page).getByTestId('next-step')).not.toHaveClass(/btn--primary/)
  await page.unroute(chargesRead)
  await error.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(panel(page).getByTestId('order-charge').getByTestId('charge-state')).toHaveText('Esperando Cliente 09 pagar', { timeout: 20_000 })
  await expect(panel(page).getByTestId('next-step')).not.toHaveClass(/btn--primary/)
})

test('R5: prévia do Receber: "Ficam R$ X" e "Quita a OS" (pay.widget.sheet)', async ({ page }) => {
  const order = await done({ id: 'customer-10', name: 'Cliente 10' }, 50)
  await openOrder(page, 'admin', order.id)
  await panel(page).getByTestId('next-step').click()
  const sheet = dialog(page, 'Receber')
  await expect(sheet.getByTestId('receive-preview')).toHaveText('Quita a OS.')
  await sheet.getByLabel('Quanto recebeu').fill('30')
  await sheet.getByLabel('Quanto recebeu').blur()
  await expect(sheet.getByTestId('receive-preview')).toHaveText('Ficam R$ 20,00.')
})

test('R5: cada linha do recebimento diz quitada ou quanto falta (receipt.detail.view)', async ({ page }) => {
  const customer = await makeCustomer()
  const a = await done(customer, 100, { createdAt: new Date(Date.now() - 3 * 86_400_000).toISOString() })
  const b = await done(customer, 50)
  await openCustomer(page, 'admin', customer.id)
  await page.getByTestId('customer-receive').click()
  const drawer = page.getByTestId('receive-customer')
  await drawer.getByLabel('Quanto recebeu').fill('120')
  await drawer.getByLabel('Quanto recebeu').blur()
  await drawer.getByTestId('receive-customer-save').click()
  await dialog(page, /Receber R\$ 120,00/).getByRole('button', { name: 'Confirmar recebimento' }).click()
  await expect(page.locator('.toast')).toContainText('Recebido R$ 120,00')
  await page.getByTestId('customer-receipts').click()
  const list = page.getByTestId('receipts')
  await expect(list).toContainText(`OS ${a.number} · R$ 100,00 · quitada`)
  await expect(list).toContainText(`OS ${b.number} · R$ 20,00 · falta R$ 30,00`)
})

test('R6: cobrança não passa do saldo na tela; Mandar de novo usa o telefone do cadastro', async ({ page }) => {
  const customer = await makeCustomer({ phone: '+5511990001111', taxId: '52998224725' })
  const order = await done({ ...customer, phone: '+5511900000000' } as { id: string; name: string }, 300)
  await writeDoc(`orders/${order.id}/charges/c0`, { status: 'pending', value: 300, dueDate: '2099-01-01', mode: 'single', invoiceUrl: 'https://sandbox.asaas.com/i/c0', paidAsaasPaymentIds: [], createdAt: new Date().toISOString() })
  await openOrder(page, 'admin', order.id)
  const card = panel(page).getByTestId('order-charge')
  await expect.poll(async () => card.getByTestId('charge-resend').getAttribute('href')).toContain('https://wa.me/5511990001111?text=')

  const fresh = await done(customer, 300)
  await page.goto(`orders?order=${fresh.id}`)
  await panel(page).getByTestId('charge-new').click()
  const sheet = dialog(page, 'Mandar cobrança')
  await sheet.getByLabel('Valor').fill('300,01')
  await sheet.getByLabel('Valor').blur()
  await expect(sheet.getByTestId('charge-problem')).toContainText('Não dá para receber mais do que falta')
  await expect(sheet.getByTestId('charge-create')).toBeDisabled()
})

test('R6: gaveta do cliente com link aberto: Mandar de novo e Receber sem azul', async ({ page }) => {
  const customer = await makeCustomer({ phone: '+5511990002222' })
  await done(customer, 40)
  await done(customer, 60)
  await writeDoc(`customerCharges/cc-${customer.id}`, { customer: { id: customer.id, name: customer.name }, status: 'pending', value: 100, dueDate: '2099-01-01', invoiceUrl: 'https://sandbox.asaas.com/i/ccx', paidAsaasPaymentIds: [], createdAt: new Date().toISOString() })
  await openCustomer(page, 'admin', customer.id)
  await page.getByTestId('customer-receive').click()
  const open = page.getByTestId('customer-charge')
  const href = await open.getByRole('link', { name: 'Mandar de novo pelo WhatsApp' }).getAttribute('href')
  expect(decodeURIComponent(href!)).toContain('wa.me/5511990002222?text=')
  await expect(page.getByTestId('receive-customer-save')).not.toHaveClass(/btn--primary/)
})
