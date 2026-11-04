// Fixes from the red team (revisao-pr515) and the simulated users (usuarios-pr515).
// Each test names the item it covers.
import { expect, test, type Page } from '@playwright/test'
import { addCommentDoc, countOrders, makeOrder, readComments, readOrder, updateCustomerDoc, updateOrderDoc, writeOrderFieldsRaw } from './data'
import { login, setTheme, signOut } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })
const drawer = (page: Page) => page.getByRole('dialog', { name: 'Nova OS' })
const table = (page: Page) => page.getByTestId('orders-table')
const row = (page: Page, number: number) => table(page).locator('tbody tr').filter({ has: page.locator('.c-num', { hasText: new RegExp(`^${number}$`) }) })

async function openOrder(page: Page, user: 'admin' | 'supervisor' | 'consultant' | 'manager', id: string) {
  await login(page, user, `orders?order=${id}`)
  await expect(panel(page).getByTestId('order-detail')).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

test.describe('dinheiro', () => {
  test('A1: Receber nunca passa do que falta, como no app', async ({ page }) => {
    const order = await makeOrder('admin', { status: 'done' })
    await openOrder(page, 'admin', order.id)
    await panel(page).getByTestId('next-step').click()
    const box = dialog(page, 'Receber')
    await box.getByLabel('Quanto recebeu').fill('500')
    await box.getByLabel('Quanto recebeu').blur()
    await expect(box.getByRole('alert')).toContainText('Não dá para receber mais do que falta (R$ 50,00)')
    await expect(box.getByRole('button', { name: 'Marcar como recebido' })).toBeDisabled()
    expect((await readOrder(order.id))?.paidAmount).toBe(0)
  })

  test('A2: outro aparelho recebe com o diálogo aberto: o saldo segue e não grava em dobro; manda expectedUpdatedAt', async ({ page }) => {
    const order = await makeOrder('admin', { status: 'done' })
    await openOrder(page, 'admin', order.id)
    await panel(page).getByTestId('next-step').click()
    const box = dialog(page, 'Receber')
    await expect(box.getByLabel('Quanto recebeu')).toHaveValue('50,00')
    // The app books the whole balance meanwhile.
    await updateOrderDoc(order.id, { paidAmount: 50, payment: 'paid', paid: true, transactions: [{ id: 'app-1', type: 'payment', amount: 50, createdAt: new Date().toISOString() }] })
    await expect(box).toContainText('Falta receber: R$ 0,00')
    await expect(box.getByRole('button', { name: 'Marcar como recebido' })).toBeDisabled()
    expect((await readOrder(order.id))?.paidAmount).toBe(50)
  })

  test('A2: resposta 409 PAYMENT_EXCEEDS_BALANCE diz o que houve e relê a OS; pagamento leva expectedUpdatedAt', async ({ page }) => {
    const order = await makeOrder('admin', { status: 'done' })
    let sent: Record<string, unknown> = {}
    await page.route(/\/payments$/, async (route) => {
      sent = route.request().postDataJSON()
      await route.fulfill({ status: 409, json: { success: false, error: { code: 'PAYMENT_EXCEEDS_BALANCE', message: 'x' } } })
    })
    await openOrder(page, 'admin', order.id)
    await panel(page).getByTestId('next-step').click()
    await dialog(page, 'Receber').getByRole('button', { name: 'Marcar como recebido' }).click()
    await expect(page.locator('.toast')).toContainText('O que falta receber mudou enquanto você recebia')
    expect(sent.expectedUpdatedAt).toBeTruthy()
    expect(sent.clientTransactionId).toMatch(/^[0-9a-f-]{36}$/)
  })
})

test('A4: quem não vê valores também acha pelo número a OS que a lista não carregou (API projetada)', async ({ page }) => {
  // An order of its own, older than the whole seed, so it is never on the first
  // page, whatever other tests add (the seed's OS 2 was only off it when they had).
  const old = await makeOrder('admin', { createdAt: '2020-01-15T15:00:00.000Z', updatedAt: '2020-01-15T15:00:00.000Z' })
  const asked: string[] = []
  page.on('request', (request) => {
    if (new RegExp(`/v1/app/orders\\?number=${old.number}\\b`).test(request.url())) asked.push(request.url())
  })
  await login(page, 'supervisor', './?f=all')
  await expect(table(page).locator('tbody tr[data-order]').first()).toBeVisible()
  // By id: the test numbers are random, so another test's recent order may share this one's number.
  const row = table(page).locator(`tbody tr[data-order="${old.id}"]`)
  await expect(row).toHaveCount(0)
  await page.getByRole('searchbox', { name: /Buscar OS/ }).fill(String(old.number))
  await expect(row.locator('td.c-num')).toHaveText(String(old.number))
  expect(asked.length).toBeGreaterThan(0)
  await expect(table(page).getByRole('columnheader', { name: 'Total' })).toHaveCount(0)
})

// revisao-pr515-3 A1: the app saves updatedAt as local time without a zone. The browser runs in
// another zone than the server (Tokyo here), so reading it as an instant would refuse every write.
test.describe('OS salva pelo app (updatedAt sem fuso)', () => {
  test.use({ timezoneId: 'Asia/Tokyo' })
  test('A1: recebe em duas vezes, sem 409, mandando a versão como veio', async ({ page }) => {
    const LOCAL = '2026-10-01T09:00:00.123456'
    await writeOrderFieldsRaw('scn-app-saved', { updatedAt: LOCAL, paidAmount: 0, payment: 'unpaid', paid: false, transactions: [] })
    const sent: unknown[] = []
    page.on('request', (request) => {
      if (/\/payments$/.test(request.url()) && request.method() === 'POST') sent.push(request.postDataJSON().expectedUpdatedAt)
    })
    await openOrder(page, 'admin', 'scn-app-saved')
    await panel(page).getByTestId('next-step').click()
    const box = dialog(page, 'Receber')
    await box.getByLabel('Quanto recebeu').fill('30')
    await box.getByRole('button', { name: 'Marcar como recebido' }).click()
    await expect(box).toHaveCount(0)
    await expect.poll(async () => (await readOrder('scn-app-saved'))?.paidAmount).toBe(30)
    await expect(panel(page).getByTestId('next-step')).toHaveText('Receber R$ 50,00')
    await panel(page).getByTestId('next-step').click()
    await dialog(page, 'Receber').getByRole('button', { name: 'Marcar como recebido' }).click()
    await expect.poll(async () => (await readOrder('scn-app-saved'))?.paidAmount).toBe(80)
    expect(sent[0]).toBe(LOCAL)
    expect(sent).toHaveLength(2)
  })
})

test('M3: fechar "E o veículo?" com Esc não troca o cliente', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'quote', payment: null })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Trocar o cliente Cliente 02' }).click()
  await dialog(page, 'Quem é o cliente?').getByRole('combobox').fill('Cliente 04')
  await page.keyboard.press('Enter')
  await expect(dialog(page, 'E o veículo?')).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(dialog(page, 'E o veículo?')).toHaveCount(0)
  await expect(panel(page).getByRole('heading', { level: 2 })).toHaveText('Cliente 02')
  const saved = await readOrder(order.id)
  expect((saved?.customer as { id: string }).id).toBe('customer-2')
  expect(saved?.deviceIds).toEqual(['device-2'])
})

test('B2: o resumo do cliente gravado na OS leva e-mail e CPF/CNPJ', async ({ page }) => {
  await updateCustomerDoc('customer-9', { email: 'cliente9@praticos.test', taxId: '00000000000' })
  const order = await makeOrder('admin', { status: 'quote', payment: null, devices: [], deviceIds: [], device: null })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Trocar o cliente Cliente 02' }).click()
  await dialog(page, 'Quem é o cliente?').getByRole('combobox').fill('Cliente 09')
  await page.keyboard.press('Enter')
  await expect(panel(page).getByRole('heading', { level: 2 })).toHaveText('Cliente 09')
  await expect.poll(async () => (await readOrder(order.id))?.customer).toMatchObject({ id: 'customer-9', email: 'cliente9@praticos.test', taxId: '00000000000' })
})

test('B3: Desfazer devolve o item com a descrição e no mesmo lugar', async ({ page }) => {
  const order = await makeOrder('admin', {
    status: 'approved',
    services: [
      { service: { id: 'service-1', name: 'Serviço 1' }, value: 50, description: 'Lado esquerdo' },
      { service: { id: 'service-2', name: 'Serviço 2' }, value: 100 },
    ],
    total: 150,
  })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Mudar Serviço 1' }).click()
  await dialog(page, 'Serviço 1').getByRole('button', { name: 'Tirar da OS' }).click()
  await expect(panel(page).getByTestId('order-line')).toHaveCount(1)
  await page.locator('.toast').getByRole('button', { name: 'Desfazer' }).click()
  await expect(panel(page).getByTestId('order-line').first()).toContainText('Lado esquerdo')
  const services = (await readOrder(order.id))?.services as { description?: string }[]
  expect(services).toHaveLength(2)
  expect(services[0]?.description).toBe('Lado esquerdo')
  // Without Desfazer, the next action sends the removal.
  await panel(page).getByRole('button', { name: 'Mudar Serviço 2' }).click()
  await dialog(page, 'Serviço 2').getByRole('button', { name: 'Tirar da OS' }).click()
  await page.locator('.toast').getByRole('button', { name: 'Fechar' }).click()
  await expect.poll(async () => ((await readOrder(order.id))?.services as unknown[]).length).toBe(1)
})

test('B1 e B6: comentário sem a chave é visível ao cliente; o que se escolhe é o que se grava', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved' })
  await addCommentDoc(order.id, { text: 'Comentário antigo', authorType: 'internal', author: { name: 'App', userId: 'x' }, source: 'app' })
  await openOrder(page, 'admin', order.id)
  const comments = panel(page).getByRole('region', { name: 'Comentários' })
  await expect(comments.getByRole('listitem').filter({ hasText: 'Comentário antigo' })).not.toContainText('só a equipe')
  await comments.getByLabel('Quem vê o comentário').selectOption({ label: 'O cliente também vê, pelo link da OS' })
  await comments.getByLabel('Escrever comentário').fill('Pode buscar amanhã')
  await comments.getByRole('button', { name: 'Enviar' }).click()
  await expect(comments).toContainText('Pode buscar amanhã')
  await expect.poll(async () => (await readComments(order.id)).find((c) => c.text === 'Pode buscar amanhã')?.isInternal).toBe(false)
})

test('B6: retomar grava o comentário interno com os dias', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'progress', onHold: { reason: 'part', since: new Date(Date.now() - 2 * 86400000).toISOString() } })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByTestId('next-step').click()
  await expect(panel(page).getByTestId('hold-line')).toHaveCount(0)
  await expect.poll(async () => (await readComments(order.id)).some((c) => c.isInternal === true && /Retomada/.test(String(c.text)))).toBe(true)
})

test('M1: quem não vê valores recebe o catálogo sem preço na rede e fora do cache do disco', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'quote', payment: null })
  const bodies: string[] = []
  page.on('response', async (response) => {
    if (/documents\/companies\/[^/]+\/(services|products)/.test(response.url())) bodies.push(`${response.url()} ${await response.text()}`)
  })
  await openOrder(page, 'supervisor', order.id)
  await panel(page).getByRole('button', { name: 'Adicionar serviço ou peça' }).click()
  await expect(dialog(page, 'O que vai ser feito?').getByRole('combobox')).toBeVisible()
  await dialog(page, 'O que vai ser feito?').getByRole('combobox').fill('Peça')
  await expect(page.getByRole('option', { name: /Peça 1/ })).toBeVisible()
  expect(bodies.length).toBeGreaterThan(0)
  expect(bodies.every((body) => body.includes('mask.fieldPaths=name') && !/"value"/.test(body))).toBe(true)
  const cached = await page.evaluate(async () => {
    const names = (await indexedDB.databases()).map((d) => d.name ?? '').filter((name) => name.includes('firestore'))
    let hits = 0
    for (const name of names) {
      const db = await new Promise<IDBDatabase>((resolve, reject) => {
        const request = indexedDB.open(name)
        request.onsuccess = () => resolve(request.result)
        request.onerror = () => reject(request.error)
      })
      for (const store of [...db.objectStoreNames].filter((s) => s.startsWith('remoteDocuments'))) {
        const all = await new Promise<unknown[]>((resolve) => {
          const request = db.transaction(store).objectStore(store).getAll()
          request.onsuccess = () => resolve(request.result)
        })
        hits += all.filter((doc) => /\/(services|products)\//.test(JSON.stringify(doc))).length
      }
      db.close()
    }
    return hits
  })
  expect(cached).toBe(0)
})

test('M2 (home.filter.mine): o técnico vê em Minhas a OS que o admin criou e atribuiu a ele, e abre', async ({ page }) => {
  await login(page, 'technician')
  await expect(page.getByRole('button', { name: 'Minhas', pressed: true })).toBeVisible()
  await expect(row(page, 508)).toHaveCount(1)
  await row(page, 508).getByRole('button', { name: 'Cliente 10' }).click()
  await expect(panel(page).getByRole('heading', { level: 2 })).toHaveText('Cliente 10')
  await expect(panel(page).getByText('OS não está mais aqui')).toHaveCount(0)
})

test('N1: a OS atribuída ao técnico aparece também em Paradas e Todas, sem valores', async ({ page }) => {
  const order = await makeOrder('admin', {
    status: 'progress',
    assignedTo: { id: 'e2e-technician', name: 'Tiago Tecnico' },
    onHold: { reason: 'part', since: new Date(Date.now() - 86400000).toISOString() },
  })
  const lists: string[] = []
  page.on('response', async (response) => {
    if (/\/v1\/app\/orders\?/.test(response.url())) lists.push(await response.text())
  })
  await login(page, 'technician')
  await page.getByRole('button', { name: 'Paradas' }).click()
  await expect(row(page, order.number)).toHaveCount(1)
  await page.getByRole('button', { name: 'Todas' }).click()
  await expect(row(page, order.number)).toHaveCount(1)
  // Once each, and no money in the projection (N3).
  await expect(table(page).locator('td.c-num', { hasText: new RegExp(`^${order.number}$`) })).toHaveCount(1)
  expect(lists.length).toBeGreaterThan(0)
  for (const body of lists) expect(JSON.stringify(JSON.parse(body).data)).not.toMatch(/"(total|paidAmount|payment|value)"/)
})

test('M2 (order.responsible.pick): o admin escolhe o técnico e a OS aparece em Minhas dele', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved' })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('region', { name: 'Detalhes' }).getByRole('button', { name: 'Ninguém' }).click()
  await dialog(page, 'Quem é o responsável?').getByRole('button', { name: 'Tiago Tecnico' }).click()
  await expect.poll(async () => ((await readOrder(order.id))?.assignedTo as { id?: string } | undefined)?.id).toBe('e2e-technician')
  await page.goto('settings')
  await signOut(page)
  await login(page, 'technician')
  await expect(page.getByRole('button', { name: 'Minhas', pressed: true })).toBeVisible()
  await expect(row(page, order.number)).toHaveCount(1)
})

// Decision (Rafael, 2026-11-03): the consultant picks the technician on the
// orders they created, never on someone else's (canAssign in order-permissions.json).
test('order.responsible.pick: o consultor indica o técnico só na OS que criou', async ({ page }) => {
  const own = await makeOrder('consultant', { status: 'approved' })
  const others = await makeOrder('admin', { status: 'approved' })
  await openOrder(page, 'consultant', own.id)
  await panel(page).getByRole('region', { name: 'Detalhes' }).getByRole('button', { name: 'Ninguém' }).click()
  await dialog(page, 'Quem é o responsável?').getByRole('button', { name: 'Tiago Tecnico' }).click()
  await expect.poll(async () => ((await readOrder(own.id))?.assignedTo as { id?: string } | undefined)?.id).toBe('e2e-technician')
  // Someone else's order: the consultant does not even open it.
  await page.goto(`orders?order=${others.id}`)
  await expect(panel(page).getByRole('button', { name: 'Ninguém' })).toHaveCount(0)
  expect((await readOrder(others.id))?.assignedTo ?? null).toBeNull()
})

test.describe('Nova OS (usuários)', () => {
  test('P0: cadastra cliente e veículo novos ali mesmo', async ({ page }) => {
    await login(page, 'admin')
    await page.getByTestId('new-order').click()
    const name = `Cliente Novo ${Date.now()}`
    await page.getByRole('combobox', { name: 'Cliente' }).fill(name)
    await expect(page.getByRole('option', { name: `+ Cadastrar “${name}”` })).toBeVisible()
    await page.keyboard.press('Enter')
    await expect(drawer(page)).toContainText(name)
    const device = page.getByRole('combobox', { name: /Veículo, se tiver/ })
    await expect(device).toBeFocused()
    await device.fill('Gol Branco')
    await page.getByRole('option', { name: '+ Cadastrar “Gol Branco”' }).click()
    await expect(drawer(page)).toContainText('Gol Branco')
    await page.getByRole('combobox', { name: 'O que vai ser feito?' }).fill('Serviço 1')
    await expect(page.getByRole('option', { name: /^Serviço 1/ })).toBeVisible()
    await page.keyboard.press('Enter')
    // The list does not reopen over the line just added.
    await expect(drawer(page).getByRole('listbox')).toHaveCount(0)
    await page.keyboard.press('ControlOrMeta+Enter')
    await expect(panel(page)).toContainText(name)
    const saved = await readOrder(new URL(page.url()).searchParams.get('order') as string)
    expect((saved?.customer as { name: string }).name).toBe(name)
    expect((saved?.device as { name: string }).name).toBe('Gol Branco')
    // P1: the number follows the company counter, not 100000.
    expect(saved?.number as number).toBeLessThan(100000)
  })

  test('P1: consultor vê os veículos; texto não escolhido não some; Enter no veículo vai para o item', async ({ page }) => {
    await login(page, 'consultant')
    await page.getByTestId('new-order').click()
    await page.getByRole('combobox', { name: 'Cliente' }).fill('Cliente 06')
    await expect(page.getByRole('option', { name: /^Cliente 06/ })).toBeVisible()
    await page.keyboard.press('Enter')
    const device = page.getByRole('combobox', { name: /Veículo, se tiver/ })
    await expect(device).toBeFocused()
    // The company's vehicles are listed even when the consultant's own orders have none of this customer.
    // The company's, in the app's name order: devices made by other tests may come before the seeded "Veículo N".
    const listed = page.getByRole('listbox', { name: /Veículo, se tiver/ }).getByRole('option')
    await expect(listed.first()).toBeVisible()
    const names = (await listed.allTextContents()).map((text) => text.trim())
    expect(names.some((name) => name.startsWith('Cadastrar'))).toBe(false)
    // Enter with nothing typed goes on to the item.
    await page.keyboard.press('Enter')
    const item = page.getByRole('combobox', { name: 'O que vai ser feito?' })
    await expect(item).toBeFocused()
    // Typed in the vehicle and not picked: saving says so, nothing is created.
    await device.fill('Gol')
    await item.fill('Serviço 1')
    await expect(page.getByRole('option', { name: /^Serviço 1/ })).toBeVisible()
    await page.keyboard.press('Enter')
    const before = await countOrders('customer.id', 'customer-6')
    await page.keyboard.press('ControlOrMeta+Enter')
    await expect(drawer(page).getByRole('alert')).toContainText('Você digitou “Gol” em Veículo e não escolheu')
    await expect(device).toBeFocused()
    expect(await countOrders('customer.id', 'customer-6')).toBe(before)
  })
})

test.describe('Início (usuários)', () => {
  test('P1: Sem receber com contagem; Atrasadas e Para hoje', async ({ page }) => {
    await login(page, 'admin')
    const unpaid = page.getByRole('button', { name: /^Sem receber \d+$/ })
    await expect(unpaid).toBeVisible()
    await unpaid.click()
    await expect(row(page, 504)).toContainText('falta receber R$ 200,00')
    // The sentence waits for the whole list: with the parallel tests' orders (and the Financeiro's seed) it can pass one page.
    const more = page.getByRole('button', { name: 'Mostrar mais' })
    for (let i = 0; i < 20 && (await more.count()); i++) {
      await more.click({ timeout: 3000 }).catch(() => {})
      await page.waitForTimeout(300)
    }
    await expect(page.getByTestId('summary')).toHaveText(/para receber · R\$/)
    await page.getByRole('button', { name: 'Atrasadas' }).click()
    await expect(row(page, 501)).toHaveCount(1)
    await expect(row(page, 502)).toHaveCount(0)
    await page.getByRole('button', { name: 'Para hoje' }).click()
    await expect(row(page, 502)).toHaveCount(1)
    await expect(row(page, 501)).toHaveCount(0)
  })

  test('P2: busca oferece procurar em todas, com o número exato primeiro, e mostra quantas achou', async ({ page }) => {
    await login(page, 'admin')
    const search = page.getByRole('searchbox', { name: /Buscar OS/ })
    await page.getByRole('button', { name: 'Paradas' }).click()
    await search.fill('504')
    await expect(page.getByRole('heading', { name: 'Nada com “504”' })).toBeVisible()
    await page.getByRole('button', { name: 'Procurar em todas' }).click()
    await expect(row(page, 504)).toHaveCount(1)
    await search.fill('1')
    await expect(table(page).locator('tbody tr[data-order] td.c-num').first()).toHaveText('1')
    await expect(page.getByTestId('summary')).toHaveText(/\d+ OS/)
  })

  test('P2: ⌘K acha OS pelo número e cliente', async ({ page }) => {
    await login(page, 'admin')
    await expect(table(page)).toBeVisible()
    await page.keyboard.press('ControlOrMeta+k')
    const palette = dialog(page, 'Buscar e comandos')
    await palette.getByRole('combobox').fill('503')
    await expect(palette.getByRole('option', { name: /OS 503 · Cliente 05/ })).toBeVisible()
    await page.keyboard.press('Enter')
    await expect(panel(page).getByRole('heading', { level: 2 })).toHaveText('Cliente 05')
    await page.keyboard.press('ControlOrMeta+k')
    await palette.getByRole('combobox').fill('Cliente 07')
    await expect(palette.getByRole('option', { name: /^Cliente 07 · Cliente$/ })).toBeVisible()
  })

  test('P2: fechar a OS devolve o foco à linha; menu "…" preso ao botão; situações na ordem do serviço', async ({ page }) => {
    await login(page, 'admin', 'orders?order=scn-late')
    await expect(panel(page).getByTestId('order-detail')).toBeVisible()
    const more = panel(page).getByRole('button', { name: 'Mais ações' })
    await more.click()
    // Measured after the opening animation: the box sits 4 px under the button.
    await expect.poll(async () => {
      const menuBox = await page.getByRole('dialog', { name: 'OS 501' }).boundingBox()
      const button = await more.boundingBox()
      return Math.abs((menuBox?.y ?? 0) - ((button?.y ?? 0) + (button?.height ?? 0)))
    }).toBeLessThan(12)
    await page.getByRole('dialog', { name: 'OS 501' }).getByRole('button', { name: 'Mudar a situação' }).click()
    const labels = await dialog(page, 'Qual a situação?').locator('.opt-main > span:first-child').allTextContents()
    expect(labels).toEqual(['Orçamento', 'Aprovado', 'Na oficina', 'Concluído'])
    await page.keyboard.press('Escape')
    await panel(page).getByRole('button', { name: 'Fechar' }).click()
    await expect(row(page, 501).getByRole('button', { name: 'Cliente 03' })).toBeFocused()
  })

  test('P2: tela baixa a 200%: o cabeçalho rola junto e sobra espaço para a lista', async ({ page }) => {
    await page.setViewportSize({ width: 640, height: 400 })
    await login(page, 'admin')
    await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await expect(table(page)).toBeVisible()
    await page.locator('.main').evaluate((main) => main.scrollTo(0, (document.querySelector('.toolbar') as HTMLElement).getBoundingClientRect().bottom))
    const rowsInView = await table(page).locator('tbody tr[data-order]').evaluateAll((rows) => rows.filter((r) => {
      const box = r.getBoundingClientRect()
      return box.top >= 0 && box.bottom <= window.innerHeight
    }).length)
    expect(rowsInView).toBeGreaterThanOrEqual(2)
  })
})

test.describe('Rodada 2 (usuários)', () => {
  test('P2 #7: a Início abre o dia com o que falta receber', async ({ page }) => {
    await login(page, 'admin')
    // With every open order loaded: "N em aberto · R$ X para receber"; otherwise only what is left to receive.
    await expect(page.getByTestId('summary')).toHaveText(/(em aberto.* · )?R\$\s[\d.,]+ para receber$/)
  })

  test('P1 #5: em Sem receber, buscar o cliente mostra quanto ele deve', async ({ page }) => {
    await login(page, 'admin')
    await page.getByRole('button', { name: /^Sem receber/ }).click()
    await expect(row(page, 504)).toBeVisible()
    await page.getByRole('searchbox', { name: /Buscar OS/ }).fill('Cliente 06')
    await expect(page.getByTestId('summary')).toHaveText(/^\d+ para receber · R\$\s[\d.,]+$/)
    await expect(row(page, 504)).toContainText('falta receber R$ 200,00')
  })

  test('P2 #10: o próximo passo usa o nome da situação', async ({ page }) => {
    const order = await makeOrder('admin', { status: 'progress' })
    await openOrder(page, 'admin', order.id)
    await expect(panel(page).getByTestId('next-step')).toHaveText('Concluir serviço')
  })

  test('P3 #15 e #16: telefone legível na lista de clientes; o total segue o valor enquanto digita', async ({ page }) => {
    await login(page, 'admin')
    await page.getByTestId('new-order').click()
    await page.getByRole('combobox', { name: 'Cliente' }).fill('Cliente 01')
    await expect(page.getByRole('option', { name: /^Cliente 01/ })).toContainText('(11) 99000-0001')
    await page.keyboard.press('Enter')
    await page.getByRole('combobox', { name: 'O que vai ser feito?' }).fill('Serviço 1')
    await expect(page.getByRole('option', { name: /^Serviço 1/ })).toBeVisible()
    await page.keyboard.press('Enter')
    const price = drawer(page).getByLabel('Valor de Serviço 1')
    await price.focus()
    await price.fill('180')
    await expect(price).toBeFocused()
    await expect(drawer(page).locator('.drawer-foot')).toContainText('Total R$ 180,00')
  })

  test('P3 #20: no escuro os controles nativos seguem o tema', async ({ page }) => {
    await login(page, 'admin')
    await setTheme(page, 'dark')
    expect(await page.evaluate(() => getComputedStyle(document.documentElement).colorScheme)).toBe('dark')
  })
})

// #516 (pagamento até o saldo, clientOrderId e item avulso), on with writes.API_516.
test.describe('Rotas do #516', () => {
  test('P0 #2 (order.new.add-item): serviço fora do catálogo entra na Nova OS e na OS aberta', async ({ page }) => {
    await login(page, 'admin')
    await page.getByTestId('new-order').click()
    await page.getByRole('combobox', { name: 'Cliente' }).fill('Cliente 01')
    await expect(page.getByRole('option', { name: /^Cliente 01/ })).toBeVisible()
    await page.keyboard.press('Enter')
    await page.getByRole('combobox', { name: 'O que vai ser feito?' }).fill('Troca de óleo')
    await page.getByRole('option', { name: '+ Usar “Troca de óleo” nesta OS' }).click()
    await drawer(page).getByLabel('Valor de Troca de óleo').fill('120')
    await page.keyboard.press('ControlOrMeta+Enter')
    await expect(panel(page).getByTestId('order-line').filter({ hasText: 'Troca de óleo' })).toHaveCount(1)
    const id = new URL(page.url()).searchParams.get('order') as string
    await expect.poll(async () => (await readOrder(id))?.services).toEqual([expect.objectContaining({ service: null, description: 'Troca de óleo', value: 120 })])
    // On the open order too.
    await panel(page).getByRole('button', { name: 'Adicionar serviço ou peça' }).click()
    await dialog(page, 'O que vai ser feito?').getByRole('combobox').fill('Alinhamento')
    await page.getByRole('option', { name: '+ Usar “Alinhamento” nesta OS' }).click()
    await expect(panel(page).getByTestId('order-line').filter({ hasText: 'Alinhamento' })).toHaveCount(1)
  })

  test('B4 (order.new.save): Salvar de novo depois de a rede cair não cria outra OS (clientOrderId)', async ({ page }) => {
    await login(page, 'admin')
    let first = true
    const ids: string[] = []
    await page.route(/\/v1\/app\/orders$/, async (route) => {
      ids.push(String(route.request().postDataJSON().clientOrderId))
      // The server creates the order, but the answer never arrives.
      const response = await route.fetch()
      if (first) {
        first = false
        await route.abort('internetdisconnected')
        return
      }
      await route.fulfill({ response })
    })
    await page.getByTestId('new-order').click()
    await page.getByRole('combobox', { name: 'Cliente' }).fill('Cliente 08')
    await expect(page.getByRole('option', { name: /^Cliente 08/ })).toBeVisible()
    await page.keyboard.press('Enter')
    const before = await countOrders('customer.id', 'customer-8')
    await drawer(page).getByTestId('save-order').click()
    await expect(drawer(page).getByRole('alert')).toBeVisible()
    await drawer(page).getByTestId('save-order').click()
    await expect(panel(page)).toContainText('Cliente 08')
    expect(new Set(ids).size).toBe(1)
    expect(await countOrders('customer.id', 'customer-8')).toBe(before + 1)
  })
})
