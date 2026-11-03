// The open order (order.detail.*, order.status.*, order.item.*, order.hold.*,
// dates, person in charge, money, comments, photos, print, delete, assistant).
// Every write goes through /v1/app/orders; tests check what the server saved.
import { expect, test, type Page } from '@playwright/test'
import { makeOrder, readOrder, updateOrderDoc } from './data'
import { chooseCompany, login, type UserKey, signOut } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  if (user === 'owner') await chooseCompany(page, 'Oficina Alfa')
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

async function menu(page: Page, item: string | RegExp) {
  await panel(page).getByRole('button', { name: 'Mais ações' }).click()
  await page.getByRole('dialog').getByRole('button', { name: item }).click()
}

const status = (page: Page) => panel(page).getByTestId('order-status')
const nextStep = (page: Page) => panel(page).getByTestId('next-step')

test('cabeçalho: cliente, veículo, situação, frase do prazo e totais (order.detail.view)', async ({ page }) => {
  await openOrder(page, 'admin', 'scn-late')
  await expect(panel(page).getByRole('heading', { level: 2 })).toHaveText('Cliente 03')
  await expect(panel(page)).toContainText('Veículo 3 · TST0003')
  await expect(status(page)).toHaveText('Atrasada')
  await expect(panel(page).getByRole('button', { name: /Era para ficar pronto/ })).toBeVisible()
  await expect(nextStep(page)).toHaveText('Começar serviço')
  await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 100,00')
  await expect(panel(page).getByTestId('order-totals')).toContainText('Falta receber')
  await expect(panel(page)).toContainText('OS 501')
})

test('do orçamento ao recebido, pelo botão azul (approve, start, finish, receive)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'quote', payment: null })
  await openOrder(page, 'admin', order.id)
  await expect(nextStep(page)).toHaveText('Aprovar orçamento')
  await nextStep(page).click()
  await expect(status(page)).toHaveText('Aprovado')
  await nextStep(page).click()
  await expect(status(page)).toHaveText('Na oficina')
  await expect(nextStep(page)).toHaveText('Concluir serviço')
  await nextStep(page).click()
  await expect(status(page)).toHaveText('Concluído')
  await expect(nextStep(page)).toHaveText('Receber R$ 50,00')
  await nextStep(page).click()
  const receive = dialog(page, 'Receber')
  await expect(receive.getByLabel('Quanto recebeu')).toHaveValue('50,00')
  await receive.getByLabel(/Como foi pago/).selectOption('pix')
  await receive.getByRole('button', { name: 'Marcar como recebido' }).click()
  await expect(panel(page).getByTestId('order-totals')).toContainText('Tudo pago')
  await expect(nextStep(page)).toHaveCount(0)
  const saved = await readOrder(order.id)
  expect(saved?.status).toBe('done')
  expect(saved?.paidAmount).toBe(50)
  const transactions = saved?.transactions as { id: string; type: string; paymentMethod?: string }[]
  expect(transactions).toHaveLength(1)
  // The client's transaction id (a uuid) is the id the server stored.
  expect(transactions[0]?.id).toMatch(/^[0-9a-f-]{36}$/)
})

test('desconto com id da transação e limite do que falta (order.discount.give)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'done', total: 100, services: [{ service: { id: 'service-2', name: 'Serviço 2' }, value: 100 }] })
  await openOrder(page, 'manager', order.id)
  await menu(page, 'Desconto')
  const box = dialog(page, 'Dar desconto')
  await box.getByLabel('Desconto').fill('150')
  await box.getByLabel('Desconto').blur()
  await expect(box.getByRole('alert')).toContainText('não pode passar do que falta receber')
  await box.getByLabel('Desconto').fill('30')
  await box.getByLabel('Desconto').blur()
  await expect(box).toContainText('O total passa de R$ 100,00 para R$ 70,00')
  await box.getByRole('button', { name: 'Dar desconto' }).click()
  await expect(panel(page).getByTestId('order-totals')).toContainText('− R$ 30,00')
  await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 70,00')
  const saved = await readOrder(order.id)
  expect(saved?.discount).toBe(30)
  expect((saved?.transactions as { id: string }[])[0]?.id).toMatch(/^[0-9a-f-]{36}$/)
})

test.describe('situação por papel (order.status.change)', () => {
  test('técnico: aprova e começa a própria; não recebe nem vê valores', async ({ page }) => {
    const order = await makeOrder('technician', { status: 'quote', payment: null })
    await openOrder(page, 'technician', order.id)
    await expect(panel(page).getByTestId('order-totals')).toHaveCount(0)
    await expect(nextStep(page)).toHaveText('Aprovar orçamento')
    await nextStep(page).click()
    await expect(status(page)).toHaveText('Aprovado')
    await expect(nextStep(page)).toHaveText('Começar serviço')
  })

  test('supervisor: orçamento de outra pessoa não tem botão azul; aprovada começa', async ({ page }) => {
    const quote = await makeOrder('admin', { status: 'quote', payment: null })
    await openOrder(page, 'supervisor', quote.id)
    await expect(status(page)).toHaveText('Orçamento')
    await expect(nextStep(page)).toHaveCount(0)
    const approved = await makeOrder('admin', { status: 'approved' })
    await page.goto(`orders?order=${approved.id}`)
    await expect(nextStep(page)).toHaveText('Começar serviço')
  })

  test('consultor: aprova o próprio orçamento e cancela com confirmação', async ({ page }) => {
    const order = await makeOrder('consultant', { status: 'quote', payment: null })
    await openOrder(page, 'consultant', order.id)
    await menu(page, 'Cancelar OS')
    const confirm = dialog(page, `Cancelar OS ${order.number}?`)
    await expect(confirm).toContainText('Ela vai para as canceladas e pode ser reaberta.')
    await expect(confirm.getByRole('button', { name: 'Manter' })).toBeFocused()
    await confirm.getByRole('button', { name: 'Cancelar OS' }).click()
    await expect(status(page)).toHaveText('Cancelado')
    expect((await readOrder(order.id))?.status).toBe('canceled')
    // Consultant cannot reopen: no status change offered.
    await panel(page).getByRole('button', { name: 'Mais ações' }).click()
    await expect(page.getByRole('dialog').getByRole('button', { name: 'Mudar a situação' })).toHaveCount(0)
  })

  test('admin: lista com a atual marcada; reabre a cancelada (order.status.reopen)', async ({ page }) => {
    const order = await makeOrder('admin', { status: 'canceled', payment: null })
    await openOrder(page, 'admin', order.id)
    await page.locator('.od-head').click()
    await page.keyboard.press('s')
    const picker = dialog(page, 'Qual a situação?')
    await expect(picker.getByRole('button', { name: /Cancelado/ })).toHaveAttribute('aria-current', 'true')
    await picker.getByRole('button', { name: 'Aprovado' }).click()
    await expect(status(page)).toHaveText('Aprovado')
  })

  test('gerente marca como parada com observação e retoma (order.hold.*)', async ({ page }) => {
    const order = await makeOrder('admin', { status: 'progress' })
    await openOrder(page, 'manager', order.id)
    await panel(page).getByRole('button', { name: 'Marcar como parada' }).click()
    const hold = dialog(page, 'Por que parou?')
    await hold.getByLabel('Observação (opcional)').fill('Sem a peça')
    await hold.getByRole('button', { name: 'Esperando peça' }).click()
    await expect(panel(page).getByTestId('hold-line')).toContainText('Esperando peça · Parada desde hoje')
    await expect(panel(page).getByTestId('hold-line')).toContainText('Sem a peça')
    await expect(nextStep(page)).toHaveText('Retomar serviço')
    await nextStep(page).click()
    await expect(panel(page).getByTestId('hold-line')).toHaveCount(0)
    expect((await readOrder(order.id))?.onHold ?? null).toBeNull()
  })
})

test('itens: adicionar, mudar quantidade, tirar e desfazer (order.item.*)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved' })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Adicionar serviço ou peça' }).click()
  await dialog(page, 'O que vai ser feito?').getByRole('combobox').fill('Peça 2')
  await page.keyboard.press('Enter')
  const lines = panel(page).getByTestId('order-line')
  await expect(lines).toHaveCount(2)
  await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 100,00')

  await panel(page).getByRole('button', { name: 'Mudar Peça 2' }).click()
  const item = dialog(page, 'Peça 2')
  await item.getByRole('button', { name: 'Mais um' }).click()
  await item.getByRole('button', { name: 'Salvar' }).click()
  await expect(lines.filter({ hasText: 'Peça 2' })).toContainText('2 unidades')
  await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 150,00')

  await panel(page).getByRole('button', { name: 'Mudar Peça 2' }).click()
  await dialog(page, 'Peça 2').getByRole('button', { name: 'Tirar da OS' }).click()
  await expect(lines).toHaveCount(1)
  const toast = page.locator('.toast')
  await expect(toast).toContainText('Peça 2 saiu')
  await toast.getByRole('button', { name: 'Desfazer' }).click()
  await expect(lines).toHaveCount(2)
  const saved = await readOrder(order.id)
  expect((saved?.products as { quantity: number }[])[0]?.quantity).toBe(2)
  expect(saved?.total).toBe(150)
})

test('supervisor: itens só no orçamento; aprovada fica só leitura; técnico e consultor sem marca de parada', async ({ page }) => {
  const approved = await makeOrder('admin', { status: 'approved' })
  await openOrder(page, 'supervisor', approved.id)
  await expect(panel(page).getByRole('button', { name: 'Adicionar serviço ou peça' })).toHaveCount(0)
  await expect(panel(page).getByRole('button', { name: /^Mudar / })).toHaveCount(0)
  await expect(panel(page).getByRole('button', { name: 'Trocar o cliente Cliente 02' })).toHaveCount(0)
  const quote = await makeOrder('admin', { status: 'quote', payment: null })
  await page.goto(`orders?order=${quote.id}`)
  await expect(panel(page).getByRole('button', { name: 'Adicionar serviço ou peça' })).toBeVisible()
  await page.goto('settings')
  await signOut(page)
  const own = await makeOrder('consultant', { status: 'approved' })
  await openOrder(page, 'consultant', own.id)
  await expect(panel(page).getByRole('button', { name: 'Marcar como parada' })).toHaveCount(0)
})

test('OS mudada em outro aparelho: a gravação é recusada e a versão nova aparece (expectedUpdatedAt)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'quote', payment: null })
  await openOrder(page, 'supervisor', order.id)
  await expect(panel(page).getByTestId('order-line')).toHaveCount(1)
  // Someone else adds a line; this screen (API projection) still shows the old one.
  await updateOrderDoc(order.id, {
    services: [{ service: { id: 'service-1', name: 'Serviço 1' }, value: 50 }, { service: { id: 'service-4', name: 'Serviço 4' }, value: 200 }],
  })
  await panel(page).getByRole('button', { name: 'Adicionar serviço ou peça' }).click()
  await dialog(page, 'O que vai ser feito?').getByRole('combobox').fill('Serviço 2')
  await page.keyboard.press('Enter')
  await expect(page.locator('.toast')).toContainText('Isso mudou enquanto você mexia')
  await expect(panel(page).getByTestId('order-line')).toHaveCount(2)
  await expect(panel(page)).toContainText('Serviço 4')
})

test('datas: entrega e visita, tirar a data; responsável (order.due.set, order.schedule.*, order.responsible.pick)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved' })
  await openOrder(page, 'admin', order.id)
  const details = panel(page).getByRole('region', { name: 'Detalhes' })
  await details.getByRole('button', { name: 'Sem data' }).first().click()
  const due = dialog(page, 'Data de entrega')
  await due.getByLabel('Fica pronto').fill('2030-05-10T17:00')
  await due.getByRole('button', { name: 'Salvar' }).click()
  await expect(panel(page).getByRole('button', { name: /Fica pronto 10\/05, 17:00/ })).toBeVisible()
  expect((await readOrder(order.id))?.dueDate).toBeTruthy()
  await panel(page).getByRole('button', { name: /Fica pronto/ }).click()
  await dialog(page, 'Data de entrega').getByRole('button', { name: 'Tirar a data' }).click()
  await expect(panel(page).getByRole('button', { name: /Fica pronto/ })).toHaveCount(0)
  await expect.poll(async () => (await readOrder(order.id))?.dueDate ?? null).toBeNull()

  await page.locator('.od-head').click()
  await page.keyboard.press('d')
  const visit = dialog(page, 'Agendar dia e hora')
  await visit.getByLabel('Visita').fill('2030-05-09T08:30')
  await visit.getByRole('button', { name: 'Salvar' }).click()
  await expect(details).toContainText('09/05, 08:30')
  // As the app writes it: the company's local time, without a zone (M1).
  await expect.poll(async () => (await readOrder(order.id))?.scheduledDate).toBe('2030-05-09T08:30:00.000')

  await details.getByRole('button', { name: 'Ninguém' }).click()
  await dialog(page, 'Quem é o responsável?').getByRole('button', { name: 'Tiago Tecnico' }).click()
  await expect(details.getByRole('button', { name: 'Tiago Tecnico' })).toBeVisible()
  await expect.poll(async () => ((await readOrder(order.id))?.assignedTo as { id?: string } | null)?.id).toBe('e2e-technician')
})

test('trocar o cliente pergunta pelo veículo do anterior; escolher veículo (order.customer.pick, order.device.add)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'quote', payment: null })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Trocar o cliente Cliente 02' }).click()
  await dialog(page, 'Quem é o cliente?').getByRole('combobox').fill('Cliente 04')
  await page.keyboard.press('Enter')
  const ask = dialog(page, 'E o veículo?')
  await expect(ask).toContainText('Veículo 2 é do cliente anterior')
  await ask.getByRole('button', { name: 'Tirar' }).click()
  await expect(panel(page).getByRole('heading', { level: 2 })).toHaveText('Cliente 04')
  await panel(page).getByRole('button', { name: 'Escolher veículo' }).click()
  await dialog(page, 'Escolher veículo').getByRole('combobox').fill('Veículo 5')
  await page.keyboard.press('Enter')
  await expect(panel(page)).toContainText('Veículo 5 · TST0005')
  // The screen shows the local write first; the server copy follows.
  await expect.poll(async () => (await readOrder(order.id))?.deviceIds).toEqual(['device-5'])
  expect(((await readOrder(order.id))?.customer as { id: string }).id).toBe('customer-4')
})

test('comentários: prévia, escrever e quem vê (order.comment.*, order.comments.*)', async ({ page }) => {
  await openOrder(page, 'supervisor', 'scn-hold')
  const comments = panel(page).getByRole('region', { name: 'Comentários' })
  await expect(comments).toContainText('Pedi a peça ao fornecedor')
  await expect(comments.getByLabel('Quem vê o comentário')).toHaveValue('true')
  await comments.getByLabel('Escrever comentário').fill('Peça chegou')
  await comments.getByRole('button', { name: 'Enviar' }).click()
  await expect(comments).toContainText('Você')
  await expect(comments).toContainText('Peça chegou')
})

test('fotos: anexar e ver (order.photo.add-gallery, order.photo.view, order.upload.progress)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved' })
  await openOrder(page, 'admin', order.id)
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64')
  await panel(page).getByLabel('Adicionar Foto').setInputFiles({ name: 'carro.png', mimeType: 'image/png', buffer: png })
  await expect(page.locator('.toast')).toContainText('Foto anexada')
  await panel(page).getByRole('button', { name: 'Ver foto 1' }).click()
  await expect(dialog(page, 'Fotos').getByRole('img')).toBeVisible()
  expect(((await readOrder(order.id))?.photos as unknown[]).length).toBe(1)
})

test('imprimir ou salvar PDF: folha própria; supervisor com valores ligados não imprime (order.pdf.view)', async ({ page }) => {
  await page.addInitScript(() => {
    window.print = () => {
      ;(window as unknown as { printed: number }).printed = ((window as unknown as { printed?: number }).printed ?? 0) + 1
    }
  })
  await openOrder(page, 'admin', 'scn-late')
  await menu(page, 'Imprimir ou salvar PDF')
  await expect.poll(() => page.evaluate(() => (window as unknown as { printed?: number }).printed ?? 0)).toBe(1)
  const sheet = page.getByTestId('print-sheet')
  await expect(sheet).toContainText('OS 501')
  await expect(sheet).toContainText('Serviço 2')
  await page.emulateMedia({ media: 'print' })
  await expect(sheet).toBeVisible()
  await expect(page.locator('#app')).toBeHidden()
})

test('apagar: confirma e some da lista; quem não pode não vê (order.delete)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'quote', payment: null })
  await openOrder(page, 'admin', order.id)
  await menu(page, 'Apagar OS')
  await dialog(page, `Apagar OS ${order.number}?`).getByRole('button', { name: 'Apagar OS' }).click()
  await expect(page.locator('.toast')).toContainText(`OS ${order.number} apagada`)
  await expect(panel(page)).toHaveCount(0)
  await expect.poll(async () => (await readOrder(order.id)) ?? null).toBeNull()
})

test('OS que não existe ou sem acesso: diz isso, nunca abre vazia (order.route.open)', async ({ page }) => {
  await openOrder(page, 'admin', 'nao-existe')
  await expect(panel(page).getByRole('heading', { name: 'OS não está mais aqui' })).toBeVisible()
  await page.goto('settings')
  await signOut(page)
  await openOrder(page, 'technician', 'scn-late')
  await expect(panel(page).getByRole('heading', { name: 'OS não está mais aqui' })).toBeVisible()
})

test('supervisor vê a OS pela projeção, sem nenhum valor', async ({ page }) => {
  const response = page.waitForResponse((r) => /\/v1\/app\/orders\/scn-late$/.test(r.url()))
  await openOrder(page, 'supervisor', 'scn-late')
  const body = await (await response).json()
  expect(JSON.stringify(body.data)).not.toMatch(/"(total|paidAmount|value|remainingBalance)"/)
  await expect(panel(page).getByTestId('order-totals')).toHaveCount(0)
  await expect(panel(page).getByText('R$')).toHaveCount(0)
})

test('assistente: lê o pedido, põe na OS com ✦ e desfaz (order.ai.type, order.ai.marked, order.ai.undo)', async ({ page }) => {
  await page.route(/\/v1\/app\/ai\/status/, (route) => route.fulfill({ json: { success: true, data: { enabled: true, usage: { used: 10, limit: 100 } } } }))
  await page.route(/\/v1\/app\/ai\/order-assist/, (route) =>
    route.fulfill({
      json: {
        success: true,
        data: {
          items: [{ kind: 'service', name: 'Serviço 3', value: 150, quantity: 1, catalogId: 'service-3', description: null, alternatives: [] }],
          changes: [],
          usage: { used: 11, limit: 100 },
        },
      },
    }),
  )
  const order = await makeOrder('admin', { status: 'approved' })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByLabel('Pedir ao assistente').fill('fazer o serviço 3')
  await panel(page).getByTestId('assistant').getByRole('button', { name: 'Enviar' }).click()
  const line = panel(page).getByTestId('order-line').filter({ hasText: 'Serviço 3' })
  await expect(line).toContainText('✦')
  await expect(panel(page).getByTestId('assistant')).toContainText('Coloquei na OS o que está marcado. Confira.')
  await page.locator('.toast').getByRole('button', { name: 'Desfazer' }).click()
  await expect(line).toHaveCount(0)
})

// B6: the live channel stuck must never leave the order in "Carregando…".
const LISTEN = '**/google.firestore.v1.Firestore/Listen/**'

test('canal ao vivo travado: a OS abre por leitura avulsa (B6)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved' })
  await page.route(LISTEN, () => {})
  await login(page, 'admin', `orders?order=${order.id}`)
  await expect(panel(page).getByRole('heading', { level: 2 })).toHaveText('Cliente 02', { timeout: 20_000 })
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
})

test('canal travado e leitura com erro: mostra o erro com Tentar de novo (B6)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved' })
  await page.route(LISTEN, () => {})
  // Only the one-off read of this order fails; the session reads go through.
  const reads = '**/documents:batchGet**'
  await page.route(reads, (route) => (route.request().postData()?.includes(order.id) ? route.abort() : route.continue()))
  await login(page, 'admin', `orders?order=${order.id}`)
  const error = panel(page).getByRole('alert')
  await expect(error).toBeVisible({ timeout: 20_000 })
  await page.unroute(reads)
  await error.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(panel(page).getByRole('heading', { level: 2 })).toHaveText('Cliente 02', { timeout: 20_000 })
})
