// Fixes from the red team (revisao-pr515) and the simulated users (usuarios-pr515).
// Each test names the item it covers.
import { expect, test, type Page } from '@playwright/test'
import { addCommentDoc, countOrders, makeOrder, readComments, readOrder, updateCustomerDoc, updateOrderDoc } from './data'
import { login } from './helpers'

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

test.fixme('M2: o técnico vê em Minhas a OS que o admin criou e atribuiu a ele (depende do #514)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved', assignedTo: { id: 'e2e-technician', name: 'Tiago Tecnico' } })
  await login(page, 'technician')
  await expect(page.getByRole('button', { name: 'Minhas', pressed: true })).toBeVisible()
  await expect(row(page, order.number)).toHaveCount(1)
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
    await expect(page.getByRole('option', { name: /Veículo/ }).first()).toBeVisible()
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
    const menuBox = await page.getByRole('dialog', { name: 'OS 501' }).boundingBox()
    const button = await more.boundingBox()
    expect(Math.abs((menuBox?.y ?? 0) - ((button?.y ?? 0) + (button?.height ?? 0)))).toBeLessThan(12)
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
