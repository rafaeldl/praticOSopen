// Faster by keyboard and by fewer decisions (docs/web-app/timed-comparison.md):
// P (next step), W (WhatsApp), - (discount), a digit (order by number), arrows and
// first letter in "Qual a situação?", typed dates in Remarcar, the suggested
// payment method, ⌘K actions before records and "Cadastrar cliente «…»", and the
// next-maintenance question inside the order instead of over it. axe on each.
import { expect, test, type Page } from '@playwright/test'
import { makeDevice, makeOrder, readOrder } from './data'
import { expectNoAxeViolations, login } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })
const palette = (page: Page) => page.getByRole('combobox', { name: /Buscar/ })

/**
 * The order is on screen: its status shows only once the order is read, and the
 * panel registers its keys before that. ("Carregando…" gone is not enough: right
 * after a navigation nothing is on screen yet, so it passes at once.)
 */
async function orderReady(page: Page) {
  await expect(panel(page).getByTestId('order-status')).toBeVisible()
}

async function openOrder(page: Page, id: string) {
  await login(page, 'admin', `orders?order=${id}`)
  await orderReady(page)
}

// E2E_CPU_THROTTLE=4: a slower machine (Chromium's CPU throttling), to catch races like CI's.
test.beforeEach(async ({ page }) => {
  const rate = Number(process.env.E2E_CPU_THROTTLE ?? 0)
  if (rate > 1) await (await page.context().newCDPSession(page)).send('Emulation.setCPUThrottlingRate', { rate })
})

const pad = (n: number) => String(n).padStart(2, '0')
/** Today + days on the company's clock (São Paulo), as yyyy-mm-dd. */
function dayFromToday(days: number): string {
  const today = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
  const [y, m, d] = today.split('-').map(Number) as [number, number, number]
  const at = new Date(Date.UTC(y, m - 1, d + days))
  return `${at.getUTCFullYear()}-${pad(at.getUTCMonth() + 1)}-${pad(at.getUTCDate())}`
}

test('Nova OS: com o campo vazio, Enter escolhe o primeiro cliente sugerido', async ({ page }) => {
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.locator('h1').click()
  await page.keyboard.press('n')
  const field = page.getByRole('combobox', { name: 'Cliente' })
  await expect(field).toBeFocused()
  // The recent customers arrive a moment later and go on top.
  await expect(page.getByRole('dialog', { name: 'Nova OS' }).getByRole('group', { name: 'Recentes' })).toBeVisible()
  const first = page.getByRole('dialog', { name: 'Nova OS' }).getByRole('option').first()
  await expect(first).toBeVisible()
  const name = ((await first.locator('strong').textContent()) ?? '').trim()
  await expect(field).toHaveAttribute('aria-activedescendant', 'no-customer-opt-0')
  await page.keyboard.press('Enter')
  await expect(page.getByTestId('new-order-drawer').locator('.chosen').first()).toContainText(name)
})

/**
 * An order with a vehicle of its own. The seed's Veículo 2 (makeOrder's default) is
 * put under an active contract by the contract tests (makeContract), and a device
 * with an active contract is never asked about (device.detail.maintenance-contract).
 */
async function orderWithOwnDevice(status: string) {
  const device = await makeDevice()
  const aggr = { id: device.id, name: device.name, serial: device.serial }
  return makeOrder('admin', { status, device: aggr, devices: [aggr], deviceIds: [device.id] })
}

test('Situação: S, a primeira letra e Enter; a pergunta da manutenção fica na OS, sem diálogo', async ({ page }) => {
  const order = await orderWithOwnDevice('approved')
  await openOrder(page, order.id)
  await page.keyboard.press('s')
  const picker = dialog(page, 'Qual a situação?')
  await expect(picker).toBeVisible()
  await page.keyboard.press('c')
  await expect(picker.getByRole('button', { name: /^Concluído/ })).toBeFocused()
  await page.keyboard.press('ArrowUp')
  await expect(picker.getByRole('button', { name: /^Na oficina/ })).toBeFocused()
  await page.keyboard.press('ArrowDown')
  await page.keyboard.press('Enter')
  await expect(panel(page).getByTestId('order-status')).toHaveText('Concluído')
  const offer = panel(page).getByTestId('maintenance-offer')
  await expect(offer).toBeVisible()
  await expect(offer).toContainText('Quando é a próxima manutenção?')
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expectNoAxeViolations(page, 'pergunta da manutenção na OS')
})

test('P faz o próximo passo; depois de ir de Aprovado a Concluído, P já sugere Concluir', async ({ page }) => {
  const first = await makeOrder('admin', { status: 'approved' })
  await openOrder(page, first.id)
  await expect(panel(page).getByTestId('next-step')).toHaveText('Começar serviço')
  await page.keyboard.press('p')
  await expect.poll(async () => (await readOrder(first.id))?.status).toBe('progress')
  // The next P once the screen shows the new step (a P while saving is not taken as two).
  await expect(panel(page).getByTestId('next-step')).toHaveText('Concluir serviço')
  await expect(panel(page).getByTestId('next-step')).toBeEnabled()
  await page.keyboard.press('p')
  await expect.poll(async () => (await readOrder(first.id))?.status).toBe('done')

  // Straight from Aprovado to Concluído once: the step remembers it, even when the
  // page is left before the server's answer arrives (CI #538): the answer comes late here.
  const second = await makeOrder('admin', { status: 'approved' })
  await page.route('**/v1/app/orders/*', async (route) => {
    if (route.request().method() !== 'PATCH') return route.fallback()
    const response = await route.fetch().catch(() => null)
    if (!response) return
    await new Promise((resolve) => setTimeout(resolve, 3000))
    await route.fulfill({ response }).catch(() => {})
  })
  await page.goto(`orders?order=${second.id}`)
  await orderReady(page)
  await page.keyboard.press('s')
  await expect(dialog(page, 'Qual a situação?')).toBeVisible()
  await page.keyboard.press('c')
  await expect(dialog(page, 'Qual a situação?').getByRole('button', { name: /^Concluído/ })).toBeFocused()
  await page.keyboard.press('Enter')
  await expect.poll(async () => (await readOrder(second.id))?.status).toBe('done')

  const third = await makeOrder('admin', { status: 'approved' })
  // Leave while the answer is still held back (the race of CI #538), then stop holding answers.
  await page.goto(`orders?order=${third.id}`)
  await page.unrouteAll({ behavior: 'ignoreErrors' })
  await orderReady(page)
  await expect(panel(page).getByTestId('next-step')).toHaveText('Concluir serviço')
  await page.keyboard.press('p')
  await expect.poll(async () => (await readOrder(third.id))?.status).toBe('done')
})

test('M abre com o foco em Mandar pelo WhatsApp; W abre o WhatsApp direto', async ({ page, context }) => {
  await context.route('https://wa.me/**', (route) => route.fulfill({ body: 'wa' }))
  const order = await makeOrder('admin', { status: 'done' })
  await openOrder(page, order.id)
  await page.keyboard.press('m')
  const sheet = dialog(page, 'Mandar para o cliente')
  await expect(sheet.getByTestId('share-whatsapp')).toBeFocused()
  await expectNoAxeViolations(page, 'mandar com foco no WhatsApp')
  let popup = context.waitForEvent('page')
  await page.keyboard.press('Enter')
  await (await popup).close()
  await page.bringToFront()
  await page.keyboard.press('Escape')
  await expect(sheet).toHaveCount(0)

  popup = context.waitForEvent('page')
  await page.keyboard.press('w')
  const opened = await popup
  expect(opened.url()).toMatch(/^https:\/\/wa\.me\//)
  await expect(sheet).toHaveCount(0)
})

test('Receber: R e Enter, com a forma do último pagamento da OS já escolhida', async ({ page }) => {
  const order = await makeOrder('admin', {
    status: 'done', total: 300, paidAmount: 100,
    services: [{ service: { id: 'service-4', name: 'Serviço 4' }, value: 300 }],
    transactions: [{ id: 'tx-1', type: 'payment', amount: 100, paymentMethod: 'pix', createdAt: new Date().toISOString() }],
  })
  await openOrder(page, order.id)
  await page.keyboard.press('r')
  const box = dialog(page, 'Receber')
  await expect(box.getByLabel('Quanto recebeu')).toHaveValue('200,00')
  await expect(box.getByLabel(/Como foi pago/)).toHaveValue('pix')
  await page.keyboard.press('Enter')
  await expect(panel(page).getByTestId('order-totals')).toContainText('Tudo pago')
})

test('- abre Dar desconto; ⌘K "desc" mostra a ação antes de tudo', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'done', total: 100, services: [{ service: { id: 'service-2', name: 'Serviço 2' }, value: 100 }] })
  await openOrder(page, order.id)
  await page.keyboard.press('-')
  await expect(dialog(page, 'Dar desconto').getByLabel('Desconto')).toBeFocused()
  await page.keyboard.press('Escape')
  await page.keyboard.press('ControlOrMeta+k')
  await expect(palette(page)).toBeFocused()
  await page.keyboard.type('desc')
  await expect(page.getByRole('listbox').getByRole('option').first()).toContainText('Dar desconto')
  await page.keyboard.press('Enter')
  const box = dialog(page, 'Dar desconto')
  await expect(box.getByLabel('Desconto')).toBeFocused()
  await page.keyboard.type('20')
  await page.keyboard.press('Enter')
  await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 80,00')
})

test('Remarcar: D, "+7 8:30" e Enter; setas mudam o dia', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved', scheduledDate: `${dayFromToday(1)}T14:00:00.000` })
  await openOrder(page, order.id)
  await page.keyboard.press('d')
  const box = dialog(page, 'Agendar dia e hora')
  const quick = box.getByLabel('Digite o dia e a hora')
  await expect(quick).toBeFocused()
  await page.keyboard.press('ArrowUp')
  await expect(box.getByLabel('Visita')).toHaveValue(`${dayFromToday(2)}T14:00`)
  await page.keyboard.press('Shift+ArrowUp')
  await expect(box.getByLabel('Visita')).toHaveValue(`${dayFromToday(2)}T14:30`)
  await page.keyboard.type('+7 8:30')
  await expect(box.getByLabel('Visita')).toHaveValue(`${dayFromToday(7)}T08:30`)
  await expectNoAxeViolations(page, 'remarcar com data digitada')
  await page.keyboard.press('Enter')
  await expect.poll(async () => (await readOrder(order.id))?.scheduledDate).toBe(`${dayFromToday(7)}T08:30:00.000`)
})

test('Um número na tela abre a busca com ele; ⌘K cadastra o cliente digitado', async ({ page }) => {
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.locator('h1').click()
  await page.keyboard.press('5')
  await expect(palette(page)).toBeFocused()
  await expect(palette(page)).toHaveValue('5')
  await page.keyboard.type('01')
  await expect(page.getByRole('listbox').getByRole('option', { name: /OS 501/ }).first()).toBeVisible()
  await page.keyboard.press('Escape')

  await page.keyboard.press('ControlOrMeta+k')
  await page.keyboard.type('cli')
  await expect(page.getByRole('listbox').getByRole('group').first()).toHaveAccessibleName('Ações')
  await palette(page).fill('')
  const name = `Teclado ${Date.now()}`
  await page.keyboard.type(name)
  const create = page.getByRole('option', { name: `Cadastrar cliente «${name}»` })
  await expect(create).toBeVisible()
  await expect(palette(page)).toHaveAttribute('aria-activedescendant', (await create.getAttribute('id')) as string)
  await page.keyboard.press('Enter')
  const form = page.getByTestId('customer-form')
  await expect(form.getByLabel('Nome', { exact: true })).toHaveValue(name)
  await expect(form.getByLabel('Telefone ou WhatsApp')).toBeFocused()
  await page.keyboard.type(`119${String(10000000 + Math.floor(Math.random() * 89999999))}`)
  await page.keyboard.press('Enter')
  await expect(page.getByRole('complementary').getByRole('heading', { name })).toBeVisible()
})

test('"?" lista os atalhos novos', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'done' })
  await openOrder(page, order.id)
  await page.keyboard.press('?')
  const help = dialog(page, 'Atalhos do teclado')
  for (const [label, key] of [['Próximo passo (o botão azul)', 'P'], ['Mandar pelo WhatsApp', 'W'], ['Dar desconto', '-'], ['Achar a OS pelo número', '0–9'], ['Receber', 'R']] as const) {
    await expect(help.getByText(label, { exact: true })).toBeVisible()
    await expect(help.locator('.cheat > div', { has: page.getByText(label, { exact: true }) }).locator('kbd')).toHaveText(key)
  }
  await expectNoAxeViolations(page, 'atalhos')
})
