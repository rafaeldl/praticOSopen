// Fatia 06: notas fiscais. The list is the seeded notas of this month (seed.mjs
// seedFinance). No nota is ever issued: the Asaas side of /v1/app/nfse/* is
// answered here, as receive.spec does with charges, and the documents the
// server would write are written by the test.
import { randomUUID } from 'node:crypto'
import { expect, test, type Page, type Route } from './test'
import { makeOrder, writeDoc } from './data'
import { chooseCompany, expectNoAxeViolations, expectNoSideScroll, login, setTheme, type UserKey } from './helpers'

const today = () => new Date().toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
const monthName = () => new Intl.DateTimeFormat('pt-BR', { timeZone: 'America/Sao_Paulo', month: 'long' }).format(new Date())
const panel = (page: Page) => page.getByTestId('nfse-panel')

async function openInvoices(page: Page, user: UserKey = 'admin', path = 'invoices') {
  await login(page, user, path)
  if (user === 'owner') await chooseCompany(page, 'Oficina Alfa')
  await expect(page.getByTestId('invoices')).toBeVisible()
  await expect(page.getByText('Carregando…')).toHaveCount(0)
}

/** A nota of company A only this test touches. */
async function makeNota(data: Record<string, unknown>) {
  const id = `nf-${randomUUID().slice(0, 8)}`
  const name = `Freguês Nota ${id.slice(3)}`
  await writeDoc(`invoices/${id}`, {
    status: 'scheduled', customer: { id: `c-${id}`, name }, value: 90, effectiveDate: today(), orderIds: [`o-${id}`],
    orders: [{ orderId: `o-${id}`, orderNumber: 8101, value: 90 }], createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(), ...data,
  })
  return { id, name }
}

const ok = (route: Route, data: unknown, status = 200) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify({ success: true, data }) })
const refuse = (route: Route, status: number, code: string, detail?: string) =>
  route.fulfill({ status, contentType: 'application/json', body: JSON.stringify({ success: false, error: { code, message: code, ...(detail ? { detail } : {}) } }) })

const preview = (orderId: string, number: number, over: Record<string, unknown> = {}) => ({
  value: 270,
  orders: [{ orderId, orderNumber: number, value: 270, servicesTotal: 300, productsTotal: 100, discount: 40 }],
  hasProducts: true,
  serviceDescription: `Serviços da OS ${number}`,
  observations: String(number),
  effectiveDate: today(),
  customer: { id: 'customer-2', name: 'Cliente 02', hasTaxId: true, contact: { email: null }, missingData: ['email'] },
  invoicedOrders: {},
  municipalServiceName: '14.01 Lubrificação, limpeza e revisão',
  ...over,
})

test('lista do mês: frase com o que saiu, o que precisa de atenção no topo e o rodapé de serviços (nfse.list.view, nfse.list.attention, nfse.list.rules)', async ({ page }) => {
  await openInvoices(page)
  await expect(page.getByTestId('page-answer')).toHaveText(`Em ${monthName()} saiu 1 nota, de R$ 270,00.`)
  await expect(page.getByText(/Só os serviços entram na nota/)).toBeVisible()
  const attention = page.getByTestId('nfse-attention')
  await expect(attention.getByRole('heading')).toHaveText('Precisa de atenção')
  await expect(attention).toContainText('Cliente 07')
  await expect(attention).toContainText('CEP do cliente é inválido.')
  const row = page.getByTestId('nfse-row').filter({ hasText: 'Nota 4521' })
  await expect(row).toContainText('Cliente 06')
  await expect(row).toContainText('OS 504')
  await expect(row).toContainText('Emitida · nº 4521')
  await expect(row).toContainText('R$ 270,00')
  // With ten notas or fewer there is no search (the app's rule).
  await expect(page.getByTestId('nfse-search')).toHaveCount(0)
})

test('abrir a nota: situação, PDF e XML só da emitida, OS que abre (nfse.list.open, nfse.invoice.view, open-pdf, open-xml)', async ({ page }) => {
  await openInvoices(page)
  await page.getByTestId('nfse-row').filter({ hasText: 'Nota 4521' }).click()
  await expect(page).toHaveURL(/invoice=nf-ok/)
  await expect(panel(page).getByTestId('nfse-status')).toHaveText('Emitida · nº 4521')
  await expect(panel(page)).toContainText('A nota foi emitida.')
  await expect(panel(page).getByTestId('nfse-pdf')).toHaveAttribute('href', 'https://sandbox.asaas.test/nota-4521.pdf')
  await expect(panel(page).getByTestId('nfse-pdf')).toHaveAttribute('target', '_blank')
  await expect(panel(page).getByTestId('nfse-xml')).toHaveAttribute('href', 'https://sandbox.asaas.test/nota-4521.xml')
  await panel(page).getByRole('link', { name: 'OS 504' }).click()
  await expect(page).toHaveURL(/order=scn-owed/)
})

test('cancelar: confirmação com "Manter nota" no foco, servidor responde e a lista muda (nfse.invoice.cancel)', async ({ page }) => {
  // Scheduled, not issued: the list test counts the issued notas of the month.
  const nota = await makeNota({ status: 'scheduled' })
  await openInvoices(page, 'manager', `invoices?invoice=${nota.id}`)
  let body: unknown = null
  let answer!: () => void
  const answered = new Promise<void>((resolve) => (answer = resolve))
  await page.route(`**/v1/app/nfse/invoices/${nota.id}/cancel`, async (route) => {
    body = route.request().postDataJSON()
    await answered
    // What the server would write after Asaas accepted.
    await writeDoc(`invoices/${nota.id}`, { status: 'canceled' }, true)
    await ok(route, { id: nota.id, status: 'canceled' })
  })
  await panel(page).getByTestId('nfse-cancel').click()
  const confirm = page.getByRole('dialog', { name: 'Cancelar a nota de R$ 90,00?' })
  await expect(confirm.getByRole('button', { name: 'Manter nota' })).toBeFocused()
  await confirm.getByRole('button', { name: 'Cancelar nota' }).click()
  // While the server works the panel says so (the tap gets an answer at once).
  await expect(panel(page).getByTestId('nfse-progress')).toHaveText('Cancelando a nota…')
  answer()
  await expect(page.locator('.toast')).toContainText('Nota cancelada')
  await expect(panel(page).getByTestId('nfse-progress')).toHaveCount(0)
  expect(body).toEqual({})
  await expect(panel(page).getByTestId('nfse-status')).toHaveText('Cancelada')
  await expect(panel(page).getByTestId('nfse-cancel')).toHaveCount(0)
})

test('prefeitura que não cancela por aqui: "Já cancelei na prefeitura" cancela só no Asaas (nfse.invoice.manual-cancel)', async ({ page }) => {
  const nota = await makeNota({ status: 'scheduled' })
  await openInvoices(page, 'admin', `invoices?invoice=${nota.id}`)
  const bodies: unknown[] = []
  await page.route(`**/v1/app/nfse/invoices/${nota.id}/cancel`, async (route) => {
    const body = route.request().postDataJSON()
    bodies.push(body)
    if (!(body as { onlyOnAsaas?: boolean }).onlyOnAsaas) return refuse(route, 409, 'CANCEL_NOT_SUPPORTED')
    await writeDoc(`invoices/${nota.id}`, { status: 'canceled' }, true)
    return ok(route, { id: nota.id, status: 'canceled' })
  })
  await panel(page).getByTestId('nfse-cancel').click()
  await page.getByRole('dialog', { name: /Cancelar a nota/ }).getByRole('button', { name: 'Cancelar nota' }).click()
  const atCity = page.getByRole('dialog', { name: 'Cancele no site da prefeitura' })
  await atCity.getByRole('button', { name: 'Já cancelei na prefeitura' }).click()
  await expect(page.locator('.toast')).toContainText('Nota cancelada')
  expect(bodies).toEqual([{}, { onlyOnAsaas: true }])
})

test('corrigir e emitir: prévia do servidor, trava pelo motivo e recusa que abre os dados do cliente (nfse.invoice.fix, nfse.issue.*)', async ({ page }) => {
  const nota = await makeNota({ status: 'error', statusDescription: 'E-mail do cliente incompleto.', number: null })
  await openInvoices(page, 'admin', `invoices?invoice=${nota.id}`)
  await expect(panel(page).getByTestId('nfse-reason')).toHaveText('E-mail do cliente incompleto.')
  const orderId = `o-${nota.id}`
  let previews = 0
  await page.route('**/v1/app/nfse/invoices/preview', async (route) => {
    previews++
    expect(route.request().postDataJSON()).toEqual({ orderIds: [orderId], customerId: `c-${nota.id}` })
    await ok(route, preview(orderId, 8101))
  })
  const sent: Record<string, unknown>[] = []
  let answer!: () => void
  const answered = new Promise<void>((resolve) => (answer = resolve))
  await page.route('**/v1/app/nfse/invoices', async (route) => {
    const body = route.request().postDataJSON()
    sent.push(body)
    if (sent.length === 1) return refuse(route, 400, 'CUSTOMER_DATA_REQUIRED', 'CEP do cliente é inválido.')
    await answered
    await writeDoc(`invoices/${nota.id}-2`, { status: 'scheduled', customer: { id: `c-${nota.id}`, name: nota.name }, value: 270, effectiveDate: today(), orderIds: [orderId], orders: [{ orderId, orderNumber: 8101, value: 270 }], createdAt: new Date().toISOString() })
    return ok(route, { id: `${nota.id}-2`, status: 'scheduled' }, 201)
  })
  await panel(page).getByTestId('nfse-fix').click()
  const sheet = page.getByRole('dialog', { name: 'Emitir nota fiscal' })
  await expect(sheet.getByTestId('nfse-value')).toHaveText('R$ 270,00')
  await expect(sheet).toContainText('Só os serviços entram na nota. Peças e produtos ficam de fora.')
  await expect(sheet).toContainText('O desconto foi repartido entre serviços e peças.')
  await expect(sheet).toContainText('Serviço da prefeitura: 14.01 Lubrificação, limpeza e revisão')
  await expect(sheet.getByLabel('O que aparece na nota')).toHaveValue('Serviços da OS 8101')
  // The e-mail is missing: "Emitir" stays grey and says why.
  await expect(sheet.getByTestId('nfse-blocker')).toHaveText('Falta o e-mail ou o endereço do cliente')
  await expect(sheet.getByTestId('nfse-send')).toBeDisabled()
  await sheet.getByLabel('E-mail').fill('cliente@exemplo.test')
  await sheet.getByLabel('O que aparece na nota').fill('Revisão completa, OS 8101')
  await expect(sheet.getByTestId('nfse-send')).toBeEnabled()
  await sheet.getByTestId('nfse-send').click()
  // The city also wants the address: every contact field opens and the text typed stays.
  await expect(sheet.getByTestId('nfse-refusal')).toContainText('A prefeitura pede o e-mail e o endereço completo do cliente')
  await expect(sheet.getByTestId('nfse-refusal')).toContainText('CEP do cliente é inválido.')
  await expect(sheet.getByLabel('O que aparece na nota')).toHaveValue('Revisão completa, OS 8101')
  expect(previews).toBe(2)
  await sheet.getByLabel('CEP').fill('88010-000')
  await sheet.getByLabel('Rua').fill('Rua das Flores')
  await sheet.getByLabel('Número').fill('10')
  await sheet.getByLabel('Bairro').fill('Centro')
  await sheet.getByTestId('nfse-send').click()
  await expect(sheet.getByTestId('nfse-issuing')).toHaveText('Emitindo a nota… pode levar alguns segundos.')
  answer()
  await expect(page.locator('.toast')).toContainText('Nota enviada para a prefeitura')
  await expect(sheet).toBeHidden()
  expect(sent[1]).toEqual({
    orderIds: [orderId],
    customerId: 'customer-2',
    serviceDescription: 'Revisão completa, OS 8101',
    customerData: { email: 'cliente@exemplo.test', postalCode: '88010-000', address: 'Rua das Flores', addressNumber: '10', province: 'Centro' },
  })
})

test('emitir pela OS: "Emitir nota fiscal" no menu, OS já com nota trava, data e CPF (nfse.issue.send, nfse.issue.date, nfse.issue.fix-customer)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'done', payment: 'paid', paidAmount: 50, paid: true })
  const settingsRead = page.waitForResponse((response) => !!response.request().postData()?.includes('settings/payments'))
  await login(page, 'admin', `orders?order=${order.id}`)
  const orderPanel = page.getByRole('complementary', { name: 'OS aberta' })
  await expect(orderPanel.getByText('Carregando…')).toHaveCount(0)
  await settingsRead
  let first = true
  await page.route('**/v1/app/nfse/invoices/preview', async (route) => {
    const over = first
      ? { invoicedOrders: { [order.id]: 'nf-old' } }
      : { customer: { id: 'customer-2', name: 'Cliente 02', hasTaxId: false, contact: { email: 'c2@exemplo.test' }, missingData: [] } }
    first = false
    await ok(route, preview(order.id, order.number, over))
  })
  let sent: Record<string, unknown> | null = null
  await page.route('**/v1/app/nfse/invoices', async (route) => {
    sent = route.request().postDataJSON()
    await ok(route, { id: 'nf-new', status: 'scheduled' }, 201)
  })
  await orderPanel.getByRole('button', { name: 'Mais ações' }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Emitir nota fiscal' }).click()
  const sheet = page.getByRole('dialog', { name: 'Emitir nota fiscal' })
  await expect(sheet.getByTestId('nfse-blocker')).toHaveText(`A OS ${order.number} já tem nota`)
  await expect(sheet.getByTestId('nfse-send')).toBeDisabled()
  await page.keyboard.press('Escape')
  await expect(sheet).toBeHidden()
  await orderPanel.getByRole('button', { name: 'Mais ações' }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Emitir nota fiscal' }).click()
  await expect(sheet.getByTestId('nfse-blocker')).toHaveText('Falta o CPF ou CNPJ do cliente')
  await sheet.getByLabel('CPF ou CNPJ do cliente').fill('529.982.247-25')
  const later = new Date(Date.now() + 5 * 86_400_000).toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
  await sheet.getByLabel('Data da nota').fill(later)
  await sheet.getByTestId('nfse-send').click()
  await expect(page.locator('.toast')).toContainText('Nota enviada para a prefeitura')
  expect(sent).toEqual({ orderIds: [order.id], customerId: 'customer-2', serviceDescription: `Serviços da OS ${order.number}`, effectiveDate: later, customerTaxId: '52998224725' })
})

test('quem não emite não vê "Emitir nota fiscal" na OS; orçamento também não', async ({ page }) => {
  const quote = await makeOrder('admin', { status: 'quote', payment: null })
  const settingsRead = page.waitForResponse((response) => !!response.request().postData()?.includes('settings/payments'))
  await login(page, 'admin', `orders?order=${quote.id}`)
  const orderPanel = page.getByRole('complementary', { name: 'OS aberta' })
  await expect(orderPanel.getByText('Carregando…')).toHaveCount(0)
  await settingsRead
  await orderPanel.getByRole('button', { name: 'Mais ações' }).click()
  await expect(page.getByRole('dialog').getByRole('button', { name: 'Imprimir ou salvar PDF' })).toBeVisible()
  await expect(page.getByRole('dialog').getByRole('button', { name: 'Emitir nota fiscal' })).toHaveCount(0)
})

test('supervisor: OS sem "Emitir nota fiscal" e lista barrada', async ({ page }) => {
  await login(page, 'supervisor', 'orders?order=scn-late')
  const orderPanel = page.getByRole('complementary', { name: 'OS aberta' })
  await expect(orderPanel.getByText('Carregando…')).toHaveCount(0)
  await orderPanel.getByRole('button', { name: 'Mais ações' }).click()
  await expect(page.getByRole('dialog').getByRole('button').first()).toBeVisible()
  await expect(page.getByRole('dialog').getByRole('button', { name: 'Emitir nota fiscal' })).toHaveCount(0)
  await page.keyboard.press('Escape')
  await page.goto('invoices')
  await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
})

test('mês: busca só com mais de 10 notas, sem acento e por número da OS; trocar de mês limpa (nfse.list.month, nfse.list.search)', async ({ page }) => {
  // Eleven scheduled notas a month ahead (a nota can be scheduled up to 60 days).
  const ahead = new Date(Date.now() + 35 * 86_400_000).toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
  const tag = randomUUID().slice(0, 6)
  for (let i = 0; i < 11; i++) {
    await makeNota({ effectiveDate: ahead, customer: { id: `c-${tag}-${i}`, name: i === 0 ? `João Ávila ${tag}` : `Outro ${tag} ${i}` }, orders: [{ orderId: `o-${tag}-${i}`, orderNumber: 8300 + i, value: 10 }] })
  }
  await openInvoices(page)
  await page.getByTestId('nfse-next').click()
  await expect(page).toHaveURL(new RegExp(`month=${ahead.slice(0, 7)}`))
  await expect(page.getByTestId('nfse-row').filter({ hasText: tag })).toHaveCount(11)
  await page.getByTestId('nfse-search').fill(`joao avila ${tag}`)
  await expect(page.getByTestId('nfse-row')).toHaveCount(1)
  await page.getByTestId('nfse-search').fill('8305')
  await expect(page.getByTestId('nfse-row')).toHaveText([/OS 8305/])
  await page.getByTestId('nfse-prev').click()
  await expect(page).not.toHaveURL(/q=/)
})

test('nota desligada na empresa: a tela diz, sem rodar para sempre (D23)', async ({ page }) => {
  await login(page, 'owner')
  await chooseCompany(page, 'Beta Repairs')
  await page.goto('invoices')
  await expect(page.getByTestId('nfse-off')).toContainText('A nota fiscal não está ligada para esta empresa.')
})

test('erro na leitura: tentar de novo', async ({ page }) => {
  await login(page, 'admin', 'settings')
  // Only the read of the notas fails.
  const runQuery = (url: URL) => url.href.includes(':runQuery')
  await page.route(runQuery, (route) => (route.request().postData()?.includes('invoices') ? route.abort() : route.continue()))
  await page.goto('invoices')
  await expect(page.getByRole('alert')).toContainText('Tentar de novo')
  await page.unroute(runQuery)
  await page.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(page.getByTestId('nfse-row').first()).toBeVisible()
})

for (const theme of ['light', 'dark'] as const) {
  test(`axe: notas, nota aberta e emitir, tema ${theme === 'light' ? 'claro' : 'escuro'}`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: theme })
    await login(page, 'admin', 'login')
    await setTheme(page, theme)
    await page.goto('invoices?invoice=nf-refused')
    await expect(panel(page)).toBeVisible()
    await expectNoAxeViolations(page, `notas ${theme}`)
    await page.route('**/v1/app/nfse/invoices/preview', (route) => ok(route, preview('scn-quote-old', 505)))
    await panel(page).getByTestId('nfse-fix').click()
    await expect(page.getByRole('dialog', { name: 'Emitir nota fiscal' }).getByTestId('nfse-value')).toBeVisible()
    await expectNoAxeViolations(page, `emitir nota ${theme}`)
  })
}

for (const [width, height] of [
  [320, 640],
  [2560, 1440],
] as const) {
  test(`${width} px sem rolagem lateral nas notas`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await login(page, 'admin', 'invoices')
    await expect(page.getByTestId('nfse-row').first()).toBeVisible()
    await expectNoSideScroll(page)
    await page.goto('invoices?invoice=nf-ok')
    await expect(panel(page)).toBeVisible()
    await expectNoSideScroll(page)
  })
}

for (const [width, height] of [
  [320, 640],
  [1366, 768],
] as const) {
  test(`texto a 200% em ${width} px nas notas`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await login(page, 'admin', 'invoices?invoice=nf-refused')
    await expect(panel(page)).toBeVisible()
    await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await expectNoSideScroll(page)
  })
}

for (const [language, attention, issued] of [
  ['en', 'Needs attention', 'Issued'],
  ['es', 'Necesita atención', 'Emitida'],
] as const) {
  test(`idioma ${language}: notas`, async ({ page }) => {
    await login(page, 'admin', 'invoices')
    await page.evaluate((value) => localStorage.setItem('praticos.prefs', JSON.stringify({ language: value })), language)
    await page.reload()
    await expect(page.getByTestId('nfse-attention').getByRole('heading')).toHaveText(attention)
    await expect(page.getByTestId('nfse-row').filter({ hasText: '4521' })).toContainText(issued)
  })
}
