// The last lines of the matrix (feat/webapp-close-last): the assistant on the
// Nova OS and its money card, photos and segment fields of the Nova OS, the
// device picker, the customer's ✓, Próxima cobrança and resuming a first access.
// The assistant's model and the Financeiro numbers are simulated with page.route.
import { expect, test, type Page, type Route } from '@playwright/test'
import { countCustomersNamed, makeCustomer, makeOrder, readCompany, readOrder, readUser, writeDoc } from './data'
import { login, type UserKey } from './helpers'

const drawer = (page: Page) => page.getByRole('dialog', { name: 'Nova OS' })
const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGP8z8DAwMDAxMDAwMDAAAANHQEDasKb6QAAAABJRU5ErkJggg==', 'base64')

/** The assistant on, and its presentation already seen (only the intro test wants it). */
async function assistantOn(page: Page, answers: ((body: Record<string, unknown>) => Record<string, unknown>)[] = [], seen = true) {
  if (seen) await page.addInitScript(() => localStorage.setItem('praticos.aiIntroSeen.v1', '1'))
  await page.route(/\/v1\/app\/ai\/status/, (route) => route.fulfill({ json: { success: true, data: { enabled: true, usage: { used: 10, limit: 100 } } } }))
  let call = 0
  await page.route(/\/v1\/app\/ai\/order-assist/, (route: Route) => {
    const body = JSON.parse(route.request().postData() ?? '{}') as Record<string, unknown>
    const answer = answers[Math.min(call++, answers.length - 1)]?.(body) ?? {}
    return route.fulfill({ json: { success: true, data: { customer: null, device: null, items: [], changes: [], notes: null, dueDate: null, actions: null, usage: { used: 11, limit: 100 }, ...answer } } })
  })
}

async function newOrder(page: Page, user: UserKey = 'admin') {
  await login(page, user)
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.getByTestId('new-order').click()
  await expect(drawer(page)).toBeVisible()
}

async function ask(page: Page, text: string) {
  const bar = page.getByTestId('new-order-assistant')
  await bar.getByLabel('Pedir ao assistente').fill(text)
  await bar.getByRole('button', { name: 'Enviar' }).click()
}

async function savedId(page: Page): Promise<string> {
  await expect(page).toHaveURL(/order=/)
  return new URL(page.url()).searchParams.get('order') as string
}

// ---------------------------------------------------------------------------
// Assistant on the Nova OS
// ---------------------------------------------------------------------------

test('assistente na Nova OS: cliente e veículo novos com ✦, cadastrados só no ✓ (order.ai.register-customer, register-device)', async ({ page }) => {
  const name = `Juliana IA ${Date.now()}`
  await assistantOn(page, [
    () => ({
      customer: { match: null, guess: { name, phone: '(48) 2222-2222' }, alternatives: [] },
      device: { match: null, guess: { name: 'Corsa', serial: 'mmm0099' }, alternatives: [] },
      items: [{ kind: 'service', name: 'Serviço 3', value: 150, quantity: 1, catalogId: 'service-3', description: null, alternatives: [] }],
      notes: 'barulho ao frear',
    }),
  ])
  await newOrder(page)
  await ask(page, `OS da ${name}, Corsa placa MMM0099, serviço 3`)
  await expect(page.getByTestId('new-order-assistant-note')).toHaveText('Preenchi o que está marcado. Confira e salve.')
  const d = drawer(page)
  await expect(d.getByText(name)).toBeVisible()
  await expect(d).toContainText('novo')
  await expect(d.getByText('Corsa')).toBeVisible()
  await expect(d.locator('.drawer-items')).toContainText('✦')
  await expect(d.getByLabel(/O que o cliente pediu/)).toHaveValue('barulho ao frear')
  // Nothing was registered before the ✓.
  expect(await countCustomersNamed(name)).toBe(0)
  await d.getByTestId('save-order').click()
  const saved = await readOrder(await savedId(page))
  expect(await countCustomersNamed(name)).toBe(1)
  expect((saved?.customer as { name: string }).name).toBe(name)
  expect((saved?.device as { serial: string }).serial).toBe('MMM0099')
  expect((saved?.services as unknown[]).length).toBe(1)
})

test('assistente na Nova OS: "Qual Juliene?", "Cadastrar" o veículo (order.ai.ask-customer, ask-device)', async ({ page }) => {
  await assistantOn(page, [
    () => ({
      customer: { match: null, guess: { name: 'Juliene' }, alternatives: [{ id: 'customer-3', name: 'Cliente 03', phone: '+5511990000003' }] },
      device: { match: null, guess: { name: 'Super Classic' }, alternatives: [{ id: 'device-4', name: 'Veículo 4', serial: 'TST0004' }] },
    }),
  ])
  await newOrder(page)
  await ask(page, 'OS da Juliene, Super Classic')
  await page.getByTestId('assist-ask-customer').click()
  const which = dialog(page, 'Qual Juliene?')
  await expect(which.getByRole('button', { name: /Cadastrar Juliene como cliente novo/ })).toBeVisible()
  await expect(which.getByRole('button', { name: 'Outro cliente' })).toBeVisible()
  await which.getByRole('button', { name: /Cliente 03/ }).click()
  const d = drawer(page)
  await expect(d.getByText('Cliente 03')).toBeVisible()
  await page.getByTestId('assist-ask-device').click()
  const device = dialog(page, 'Qual Super Classic?')
  await expect(device.getByRole('button', { name: 'Outro veículo' })).toBeVisible()
  await device.getByRole('button', { name: 'Cadastrar Super Classic' }).click()
  await expect(d.getByText('Super Classic')).toBeVisible()
  await expect(d).toContainText('novo')
})

test('assistente na Nova OS: muda valor, pergunta qual linha e tira só o pedido; Desfazer volta (order.ai.change-lines, ask-line)', async ({ page }) => {
  await assistantOn(page, [
    () => ({
      items: [
        { kind: 'service', name: 'Serviço 1', value: 50, quantity: 1, catalogId: 'service-1', description: null, alternatives: [] },
        { kind: 'service', name: 'Serviço 1', value: 50, quantity: 1, catalogId: 'service-1', description: null, alternatives: [] },
        { kind: 'service', name: 'Serviço 2', value: 100, quantity: 1, catalogId: 'service-2', description: null, alternatives: [] },
      ],
    }),
    (body) => {
      // The lines on screen go along, in order (the answer points at them by index).
      expect((body.order as { services: unknown[] }).services).toHaveLength(3)
      return { changes: [{ action: 'update', line: null, candidates: [{ kind: 'service', index: 0 }, { kind: 'service', index: 1 }], name: 'Serviço 1', value: 300 }] }
    },
    () => ({ changes: [{ action: 'remove', line: { kind: 'service', index: 2 }, candidates: [], name: 'Serviço 2' }] }),
  ])
  await newOrder(page)
  await ask(page, 'dois serviço 1 e um serviço 2')
  const lines = drawer(page).locator('.drawer-items li')
  await expect(lines).toHaveCount(3)
  await ask(page, 'o serviço 1 é 300')
  const which = dialog(page, 'Qual Serviço 1?')
  await which.getByRole('button', { name: /Serviço 1/ }).nth(1).click()
  await expect(lines.nth(1).getByRole('textbox')).toHaveValue(/300/)
  await expect(lines.nth(0).getByRole('textbox')).toHaveValue(/50/)
  await expect(page.getByTestId('new-order-assistant-note')).toHaveText('Mudei a OS como você pediu. Confira.')
  await ask(page, 'tira o serviço 2')
  await expect(lines).toHaveCount(2)
  await page.getByTestId('new-order-assistant-undo').click()
  await expect(lines).toHaveCount(3)
})

test('assistente: dinheiro dito na Nova OS abre "Confere?" depois do ✓ e grava pela API (order.ai.money-card, money-plan, money-run)', async ({ page }) => {
  await assistantOn(page, [
    () => ({
      customer: { match: { id: 'customer-4', name: 'Cliente 04' }, guess: { name: 'Cliente 04' }, alternatives: [] },
      items: [{ kind: 'service', name: 'Serviço 2', value: 100, quantity: 1, catalogId: 'service-2', description: null, alternatives: [] }],
      actions: { payment: { kind: 'full', value: null, method: 'pix', paidDate: null }, discount: null, status: null },
    }),
  ])
  await newOrder(page)
  await ask(page, 'cliente 04, serviço 2, pagou tudo no pix')
  await expect(page.getByTestId('new-order-assistant-note')).toHaveText('Ao salvar, vou pedir para você conferir.')
  await drawer(page).getByTestId('save-order').click()
  const id = await savedId(page)
  const card = dialog(page, 'Confere?')
  await expect(card.getByTestId('ai-step-approve')).toContainText('Marcar como aprovado')
  await expect(card.getByTestId('ai-step-payment')).toContainText('Receber R$ 100,00')
  // Nothing saved before Confirmar.
  expect((await readOrder(id))?.paidAmount ?? 0).toBe(0)
  await card.getByTestId('ai-confirm').click()
  await expect.poll(async () => (await readOrder(id))?.paidAmount).toBe(100)
  expect((await readOrder(id))?.status).toBe('approved')
  await expect(page.locator('.toast')).toContainText('Recebido R$ 100,00')
})

test('assistente sem a chave do dinheiro: nada de cartão, só o que foi posto (financeActions desligada)', async ({ page }) => {
  await assistantOn(page, [() => ({ customer: { match: { id: 'customer-5', name: 'Cliente 05' }, guess: null, alternatives: [] }, actions: null })])
  await newOrder(page)
  await ask(page, 'cliente 05 pagou tudo')
  await drawer(page).getByTestId('save-order').click()
  await savedId(page)
  await expect(panel(page)).toBeVisible()
  await expect(dialog(page, 'Confere?')).toHaveCount(0)
})

test('assistente na OS salva: foto entra na OS e é lida; valor muda pela API (order.ai.photo, order.ai.change-lines)', async ({ page }) => {
  let sentPhotos = 0
  await assistantOn(page, [
    (body) => {
      sentPhotos = (body.photos as unknown[] | undefined)?.length ?? 0
      return { changes: [{ action: 'update', line: { kind: 'service', index: 0 }, candidates: [], name: 'Serviço 1', value: 80 }] }
    },
  ])
  const order = await makeOrder('admin', { status: 'approved' })
  await login(page, 'admin', `orders?order=${order.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await panel(page).getByTestId('assistant-photo').setInputFiles({ name: 'placa.png', mimeType: 'image/png', buffer: PNG })
  await expect(panel(page).getByTestId('assistant')).toContainText('Mudei a OS como você pediu. Confira.')
  expect(sentPhotos).toBe(1)
  const saved = await readOrder(order.id)
  expect((saved?.photos as unknown[]).length).toBe(1)
  expect((saved?.services as { value: number }[])[0]?.value).toBe(80)
})

test('apresentação do assistente: uma vez por navegador; "Experimentar agora" abre a Nova OS no assistente (order.ai.intro, intro-try, intro-later)', async ({ page }) => {
  await assistantOn(page, [], false)
  await login(page, 'admin')
  const intro = dialog(page, 'Crie sua próxima OS escrevendo')
  await expect(intro).toBeVisible()
  await intro.getByRole('button', { name: 'Experimentar agora' }).click()
  await expect(drawer(page)).toBeVisible()
  await expect(page.getByTestId('new-order-assistant').getByLabel('Pedir ao assistente')).toBeFocused()
  await page.keyboard.press('Escape')
  await page.reload()
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.waitForTimeout(800)
  await expect(intro).toHaveCount(0)
})

// ---------------------------------------------------------------------------
// Nova OS: photos and segment fields
// ---------------------------------------------------------------------------

test('Nova OS: fotos antes do ✓, Remover Foto, e sobem depois do id (order.new.photos)', async ({ page }) => {
  await newOrder(page)
  const d = drawer(page)
  await d.getByRole('combobox', { name: 'Cliente' }).fill('Cliente 06')
  await page.keyboard.press('Enter')
  const input = d.getByTestId('new-order-photo-input')
  await input.setInputFiles([{ name: 'a.png', mimeType: 'image/png', buffer: PNG }, { name: 'b.png', mimeType: 'image/png', buffer: PNG }])
  const photos = d.getByTestId('new-order-photos').locator('button.photo')
  await expect(photos).toHaveCount(2)
  // The vehicle's list is still open after the customer: leave it first, as a person would.
  await d.getByLabel(/O que o cliente pediu/).click()
  await photos.first().click()
  await dialog(page, 'Remover Foto').getByRole('button', { name: 'Remover Foto' }).click()
  await expect(photos).toHaveCount(1)
  await d.getByTestId('save-order').click()
  const id = await savedId(page)
  await expect.poll(async () => ((await readOrder(id))?.photos as unknown[] | undefined)?.length ?? 0).toBe(1)
  const [photo] = (await readOrder(id))?.photos as { storagePath: string }[]
  expect(photo?.storagePath).toMatch(new RegExp(`^tenants/company-alpha/orders/${id}/photos/`))
})

test('Nova OS: campos do ramo conferidos antes do ✓ e gravados com a OS (order.new.custom-fields)', async ({ page }) => {
  await newOrder(page)
  const d = drawer(page)
  await d.getByRole('combobox', { name: 'Cliente' }).fill('Cliente 07')
  await page.keyboard.press('Enter')
  const field = d.getByTestId('new-order-custom-fields').getByLabel('KM na entrada')
  await field.fill('-5')
  await d.getByTestId('save-order').click()
  await expect(d.getByRole('alert')).toHaveText('Confira os campos marcados antes de salvar.')
  await expect(drawer(page)).toBeVisible()
  await field.fill('12500')
  await d.getByTestId('save-order').click()
  const id = await savedId(page)
  await expect.poll(async () => ((await readOrder(id))?.customData as { mileageIn?: number } | undefined)?.mileageIn).toBe(12500)
})

// ---------------------------------------------------------------------------
// The order: device picker and the customer's ✓
// ---------------------------------------------------------------------------

test('item em OS com dois veículos: "Em quais veículos?", Geral ou todos (order.device-picker.one, order.device-picker.multi)', async ({ page }) => {
  const devices = [{ id: 'device-2', name: 'Veículo 2', serial: 'TST0002' }, { id: 'device-3', name: 'Veículo 3', serial: 'TST0003' }]
  const order = await makeOrder('admin', { status: 'approved', devices, deviceIds: devices.map((d) => d.id) })
  await login(page, 'admin', `orders?order=${order.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  const add = async (name: string) => {
    await panel(page).getByRole('button', { name: 'Adicionar serviço ou peça' }).click()
    const search = page.getByRole('dialog', { name: 'O que vai ser feito?' })
    await search.getByRole('combobox').fill(name)
    // Enter takes the first result: wait for this search, not the last one's list.
    await expect(search.getByRole('option').first()).toContainText(name)
    await page.keyboard.press('Enter')
  }
  await add('Serviço 4')
  const picker = dialog(page, 'Em quais veículos?')
  await expect(picker.getByTestId('device-picker-confirm')).toBeDisabled()
  await picker.getByTestId('device-picker-all').check()
  await picker.getByTestId('device-picker-confirm').click()
  await expect.poll(async () => ((await readOrder(order.id))?.services as { deviceId?: string; service?: { id: string } }[]).filter((s) => s.service?.id === 'service-4').map((s) => s.deviceId).sort()).toEqual(['device-2', 'device-3'])
  await add('Serviço 5')
  await dialog(page, 'Em quais veículos?').getByLabel('Veículo 3').check()
  await dialog(page, 'Em quais veículos?').getByTestId('device-picker-confirm').click()
  await expect.poll(async () => ((await readOrder(order.id))?.services as { deviceId?: string; service?: { id: string } }[]).filter((s) => s.service?.id === 'service-5').map((s) => s.deviceId)).toEqual(['device-3'])
})

test('"Qual cliente?": ✓ no cliente antigo sem id, por nome e telefone (customer.picker.choose)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved', customer: { name: 'Cliente 08', phone: '+5511990000008' } })
  await login(page, 'admin', `orders?order=${order.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await panel(page).getByRole('button', { name: 'Trocar o cliente Cliente 08' }).click()
  const option = page.getByRole('option', { name: /Cliente 08/ })
  await expect(option).toHaveAttribute('aria-selected', 'true')
})

// ---------------------------------------------------------------------------
// Próxima cobrança
// ---------------------------------------------------------------------------

/** The Financeiro summary with the debtors this test controls (real orders, so the links can be read). */
async function summaryWith(page: Page, debtors: { key: string; customer: { id: string; name: string }; since: string; orders: { id: string; number: number }[]; amount: number }[]) {
  await page.route(/\/v1\/app\/finance\/summary/, (route) =>
    route.fulfill({
      json: {
        success: true,
        data: {
          month: '', zone: 'America/Sao_Paulo', from: '', to: '', truncated: false,
          received: { total: 0, orders: [] }, sold: { total: 0, orders: [] }, progress: { total: 0, orders: [] },
          receivable: {
            total: debtors.reduce((s, d) => s + d.amount, 0), owed: 0, depositOwed: 0, customers: debtors.length, deposits: [],
            debtors: debtors.map((d) => ({
              ...d,
              orders: d.orders.map((o) => ({ id: o.id, number: o.number, status: 'done', customer: d.customer, device: null, total: d.amount / d.orders.length, paid: 0, open: d.amount / d.orders.length, createdAt: d.since, amount: d.amount / d.orders.length })),
            })),
          },
        },
      },
    }),
  )
}
const daysAgo = (n: number) => new Date(Date.now() - n * 86_400_000).toISOString()
const done = (customer: { id: string; name: string }, total: number) =>
  makeOrder('admin', { customer, status: 'done', total, paidAmount: 0, payment: 'unpaid', services: [{ service: { id: 'service-1', name: 'Serviço 1' }, value: total }] })

test('próxima cobrança: a mais antiga dos 90 dias; "Agora não" fica neste navegador (fin.tab.next-charge, next-charge-snooze)', async ({ page }) => {
  const a = await makeCustomer()
  const b = await makeCustomer()
  const oa = await done(a, 100)
  const ob = await done(b, 80)
  await summaryWith(page, [
    { key: b.id, customer: b, since: daysAgo(5), orders: [ob], amount: 80 },
    { key: a.id, customer: a, since: daysAgo(10), orders: [oa], amount: 100 },
  ])
  await login(page, 'admin', 'finance')
  const next = page.getByTestId('next-charge')
  await expect(next).toContainText(a.name)
  await expect(next).toContainText('R$ 100,00')
  await next.getByRole('button').click()
  const sheet = dialog(page, 'Próxima cobrança')
  await expect(sheet).toContainText(`${a.name} deve R$ 100,00 desde`)
  await sheet.getByRole('button', { name: 'Agora não' }).click()
  await expect(next).toContainText(b.name)
  await page.reload()
  await expect(page.getByTestId('next-charge')).toContainText(b.name)
})

test('próxima cobrança: quem já tem link aberto fica de fora; uma OS abre a cobrança da OS (fin.tab.next-charge-send)', async ({ page }) => {
  const a = await makeCustomer()
  const b = await makeCustomer()
  const oa = await done(a, 100)
  const ob = await done(b, 80)
  await writeDoc(`orders/${oa.id}/charges/open-${oa.id}`, { status: 'pending', value: 100, dueDate: '2099-01-01', createdAt: new Date().toISOString() })
  await summaryWith(page, [
    { key: a.id, customer: a, since: daysAgo(10), orders: [oa], amount: 100 },
    { key: b.id, customer: b, since: daysAgo(5), orders: [ob], amount: 80 },
  ])
  await login(page, 'admin', 'finance')
  const next = page.getByTestId('next-charge')
  await expect(next).toContainText(b.name)
  await next.getByRole('button').click()
  await dialog(page, 'Próxima cobrança').getByRole('button', { name: 'Mandar cobrança' }).click()
  await expect(page.getByRole('dialog').filter({ hasText: 'R$ 80,00' }).last()).toBeVisible()
})

test('próxima cobrança com várias OS e Asaas: abre a cobrança do cliente já na folha (pay.customer.start-charge)', async ({ page }) => {
  const a = await makeCustomer()
  const o1 = await done(a, 100)
  const o2 = await done(a, 50)
  await summaryWith(page, [{ key: a.id, customer: a, since: daysAgo(3), orders: [o1, o2], amount: 150 }])
  await login(page, 'admin', 'finance')
  await page.getByTestId('next-charge').getByRole('button').click()
  await dialog(page, 'Próxima cobrança').getByRole('button', { name: 'Mandar cobrança' }).click()
  await expect(page.getByTestId('receive-customer')).toBeVisible()
  // The charge sheet opens by itself, over the two orders.
  await expect(page.getByRole('dialog').last()).toContainText('R$ 150,00')
})

test('cobrança de várias OS sobre link de uma OS: a linha diz e pede confirmação (pay.customer.replace-single)', async ({ page }) => {
  const a = await makeCustomer()
  const o1 = await done(a, 100)
  await done(a, 50)
  await writeDoc(`orders/${o1.id}/charges/single-${o1.id}`, { status: 'overdue', value: 100, dueDate: '2026-10-20', createdAt: new Date().toISOString() })
  await login(page, 'admin', `customers?customer=${a.id}`)
  await expect(page.getByTestId('customer-detail').getByText('Carregando…')).toHaveCount(0)
  await page.getByTestId('customer-receive').click()
  const d = page.getByTestId('receive-customer')
  await expect(d.getByTestId('order-link')).toContainText('Venceu em 20/10')
  await d.getByTestId('customer-charge-new').click()
  const confirm = dialog(page, 'Já existe uma cobrança em aberto')
  await expect(confirm).toContainText('Gerar uma nova cobrança cancela a anterior no Asaas.')
  await confirm.getByRole('button', { name: 'Gerar nova' }).click()
  await expect(dialog(page, 'Já existe uma cobrança em aberto')).toHaveCount(0)
})

// ---------------------------------------------------------------------------
// Primeiro acesso de empresa sem ramo
// ---------------------------------------------------------------------------

test('empresa sem ramo: o primeiro acesso volta com o nome e o telefone dela e completa a mesma empresa (auth.gate.resume-company)', async ({ page }) => {
  await login(page, 'resumer')
  await expect(page).toHaveURL(/\/start/)
  await page.getByRole('button', { name: /Mecânica/ }).click()
  await page.getByRole('button', { name: 'Continuar' }).click()
  await expect(page.getByLabel('Nome que aparece na OS')).toHaveValue('Retoma Sem Ramo')
  await expect(page.getByLabel('Telefone (opcional)')).toHaveValue('(48) 3333-4444')
  await expect(page.getByTestId('onboarding-invite-code')).toHaveCount(0)
  await page.getByRole('button', { name: 'Criar meu PraticOS' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible({ timeout: 45_000 })
  // An old company: the segment is saved, samples and checklists do not come, and the screen says so (B5).
  await expect(page.locator('.toast')).toContainText('Exemplos e checklists prontos só entram em empresa nova')
  const company = await readCompany('company-resume')
  expect(company).toMatchObject({ name: 'Retoma Sem Ramo', segment: 'automotive', useScheduling: true })
  // The same company: nothing new was created for this person.
  expect(((await readUser('e2e-resumer'))?.companies as unknown[]).length).toBe(1)
})

// ---------------------------------------------------------------------------
// Revisão do #543
// ---------------------------------------------------------------------------

test('B1: dinheiro dito na Nova OS sem passo possível não abre "Confere?" (empresa sem valores)', async ({ page }) => {
  await assistantOn(page, [
    () => ({
      customer: { match: { id: 'customer-1', name: 'Cliente 01' }, guess: null, alternatives: [] },
      actions: { payment: { kind: 'full', value: null, method: 'pix', paidDate: null }, discount: null, status: null },
    }),
  ])
  await login(page, 'noValues')
  await page.getByTestId('new-order').click()
  await ask(page, 'cliente 01 pagou tudo')
  await drawer(page).getByTestId('save-order').click()
  await savedId(page)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByTestId('assistant')).toBeVisible()
  await page.waitForTimeout(500)
  await expect(dialog(page, 'Confere?')).toHaveCount(0)
})

test('B3: erro no meio guarda o Desfazer; tirar só vai ao servidor quando o aviso sai', async ({ page }) => {
  await assistantOn(page, [
    () => ({
      changes: [
        { action: 'remove', line: { kind: 'service', index: 0 }, candidates: [], name: 'Serviço 1' },
        { action: 'remove', line: { kind: 'service', index: 0 }, candidates: [], name: 'Serviço 1' },
      ],
      items: [{ kind: 'service', name: 'Serviço 3', value: 150, quantity: 1, catalogId: 'service-3', description: null, alternatives: [] }],
    }),
  ])
  const order = await makeOrder('admin', { status: 'approved' })
  const deletes: string[] = []
  page.on('request', (r) => r.method() === 'DELETE' && r.url().includes('/items/') && deletes.push(r.url()))
  await page.route(/\/v1\/app\/orders\/[^/]+\/items$/, (route) => (route.request().method() === 'POST' ? route.fulfill({ status: 500, json: { success: false, error: { code: 'INTERNAL_ERROR' } } }) : route.continue()))
  await login(page, 'admin', `orders?order=${order.id}`)
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  await panel(page).getByLabel('Pedir ao assistente').fill('tira o serviço 1 e põe o 3')
  await panel(page).getByTestId('assistant').getByRole('button', { name: 'Enviar' }).click()
  const line = panel(page).getByTestId('order-line').filter({ hasText: 'Serviço 1' })
  await expect(line).toHaveCount(0)
  await page.locator('.toast').getByRole('button', { name: 'Desfazer' }).click()
  await expect(line).toHaveCount(1)
  expect(deletes).toEqual([])
  expect(((await readOrder(order.id))?.services as unknown[]).length).toBe(1)
})

test('B4: sem editar preço, o valor dito à IA não aparece na Nova OS (consultor)', async ({ page }) => {
  await assistantOn(page, [() => ({ items: [{ kind: 'service', name: 'Serviço 3', value: 999, quantity: 1, catalogId: 'service-3', description: null, alternatives: [] }] })])
  await newOrder(page, 'consultant')
  await ask(page, 'serviço 3 por 999')
  const items = drawer(page).locator('.drawer-items')
  await expect(items).toContainText('Serviço 3')
  await expect(items).toContainText('R$ 150,00')
  await expect(items).not.toContainText('999')
})

test('B2: sem ler os links das OS, a gaveta avisa e não oferece a cobrança', async ({ page }) => {
  const a = await makeCustomer()
  await done(a, 100)
  await done(a, 50)
  let fail = true
  await page.route(/\/orders\/[^/:]+:runQuery/, (route) => (fail ? route.abort() : route.continue()))
  await login(page, 'admin', `customers?customer=${a.id}`)
  await expect(page.getByTestId('customer-detail').getByText('Carregando…')).toHaveCount(0)
  await page.getByTestId('customer-receive').click()
  const d = page.getByTestId('receive-customer')
  await expect(d.getByTestId('customer-links-failed')).toBeVisible()
  await expect(d.getByTestId('customer-charge-new')).toHaveCount(0)
  fail = false
  await d.getByTestId('customer-links-failed').getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(d.getByTestId('customer-links-failed')).toHaveCount(0)
  await expect(d.getByTestId('customer-charge-new')).toBeVisible()
})
