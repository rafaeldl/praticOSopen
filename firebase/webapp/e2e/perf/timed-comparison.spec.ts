// Timed comparison (docs/web-app/timed-comparison.md): the 10 most frequent tasks,
// keyboard only, on the production build against the emulators. Counts every key
// (a shortcut with a modifier counts 2, each letter 1) and every click, and times
// from the first key to the end state. Prints one "CMP {json}" line per run, with
// the KLM time: 0.24 s per step and 1.2 s per decision (start the task, and each
// field or option the person has to choose; a suggestion confirmed with Enter or a
// direct key is not a choice). The decisions of each path are written by the test.
// Needs the default seed (scenario orders), so it only runs when asked:
// CMP=1 E2E_PERF=1 PW_ARGS=e2e/perf/timed-comparison npm run e2e  (or with the suite up: CMP=1 E2E_PERF=1 npx playwright test e2e/perf/timed-comparison --workers=1)
import { expect, test, type Locator, type Page } from '@playwright/test'
import { makeOrder, readOrder } from '../data'
import { login } from '../helpers'

const RUNS = Number(process.env.CMP_RUNS ?? 5)
test.skip(!process.env.CMP, 'comparação cronometrada: rode com CMP=1')
test.use({ launchOptions: { args: ['--lang=pt-BR'] } })
const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })
/** "Joana Teste" in length (11 letters), new every run: an existing name is never offered again. */
const newName = () => `Joana ${'T' + Array.from({ length: 4 }, () => 'abcdefghijklmnopqrstuvwxyz'[Math.floor(Math.random() * 26)]).join('')}`

class Steps {
  keys = 0
  letters = 0
  clicks = 0
  started = 0
  idle = 0
  constructor(private page: Page) {}
  get total() {
    return this.keys + this.letters + this.clicks
  }
  start() {
    this.started = performance.now()
  }
  async press(key: string, times = 1) {
    for (let i = 0; i < times; i++) {
      this.keys += key.split('+').length
      await this.page.keyboard.press(key)
    }
  }
  async type(text: string) {
    for (const char of text) {
      this.letters++
      await this.page.keyboard.type(char)
    }
  }
  async click(target: Locator) {
    this.clicks++
    await target.click()
  }
  /** Tab until the target has focus (counts each Tab). */
  async tabTo(target: Locator, max = 30, key = 'Tab') {
    await expect(target).toBeVisible()
    for (let i = 0; i < max; i++) {
      if (await target.evaluate((el) => el === document.activeElement)) return
      await this.press(key)
    }
    throw new Error('alvo não recebeu foco com Tab')
  }
  /** Types the target's letters until it is among the first 4 options, then ↓ and Enter. */
  async pick(options: Locator, target: RegExp, text: string) {
    const position = async () => (await options.allTextContents()).findIndex((name) => target.test(name.trim()))
    for (let i = 0; i <= text.length; i++) {
      if (i > 0) await this.type(text[i - 1]!)
      // Results may come from the API: give them up to 1.5 s to arrive before typing more (a person reads too).
      let index = -1
      const until = Date.now() + 1500
      do {
        await this.page.waitForTimeout(100)
        this.idle += 100
        index = await position()
      } while ((index < 0 || index >= 4) && Date.now() < until)
      if (index >= 0 && index < 4) {
        // ↓ until the active option (aria-activedescendant) is the target, then Enter.
        for (let k = 0; k < 6; k++) {
          const active = await this.page.evaluate(() => {
            const id = document.activeElement?.getAttribute('aria-activedescendant')
            return id ? (document.getElementById(id)?.textContent ?? '').trim() : ''
          })
          if (target.test(active)) break
          await this.press('ArrowDown')
        }
        await this.press('Enter')
        return
      }
    }
    throw new Error(`não achou ${target}`)
  }
  done(task: string, decisions: number, extra: Record<string, unknown> = {}) {
    const ms = Math.round(performance.now() - this.started)
    const klm = Math.round((0.24 * this.total + 1.2 * decisions) * 100) / 100
    console.log(`CMP ${JSON.stringify({ task, steps: this.total, keys: this.keys, letters: this.letters, clicks: this.clicks, decisions, klm, ms, idleMs: this.idle, ...extra })}`)
  }
}

async function startOnHome(page: Page) {
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.waitForTimeout(600)
  await page.locator('h1').click()
}

const pad = (n: number) => String(n).padStart(2, '0')
/** Today + days on the company's clock (São Paulo), as yyyy-mm-dd. */
function dayFromToday(days: number): string {
  const today = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
  const [y, m, d] = today.split('-').map(Number) as [number, number, number]
  const at = new Date(Date.UTC(y, m - 1, d + days))
  return `${at.getUTCFullYear()}-${pad(at.getUTCMonth() + 1)}-${pad(at.getUTCDate())}`
}

async function openOrder(page: Page, id: string, signIn = true) {
  if (signIn) await login(page, 'admin', `orders?order=${id}`)
  else await page.goto(`orders?order=${id}`)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  // Opened by URL the focus goes to the page title. In use the order is picked in the list,
  // and Enter takes the focus to the panel: start from there (not counted).
  await page.waitForTimeout(800)
  await panel(page).getByRole('heading', { level: 2 }).evaluate((el) => {
    el.setAttribute('tabindex', '-1')
    ;(el as HTMLElement).focus()
  })
}

for (let run = 1; run <= RUNS; run++) {
  test.describe(`rodada ${run}`, () => {
    test('T1 Nova OS completa', async ({ page }) => {
      await startOnHome(page)
      const s = new Steps(page)
      s.start()
      await s.press('n')
      const drawer = page.getByRole('dialog', { name: 'Nova OS' })
      await expect(page.getByRole('combobox', { name: 'Cliente' })).toBeFocused()
      await s.pick(drawer.getByRole('option'), /^Cliente 03/, 'Cliente 03')
      const focused = () => page.evaluate(() => document.activeElement?.id ?? '')
      await expect.poll(focused).toMatch(/^no-(device|item)$/)
      if ((await focused()) === 'no-device') await s.press('Enter')
      await expect(page.getByRole('combobox', { name: 'O que vai ser feito?' })).toBeFocused()
      await s.pick(drawer.getByRole('option'), /^Serviço 2/, 'Serviço 2')
      await s.press('Tab')
      await expect(page.getByRole('textbox', { name: 'Valor de Serviço 2' })).toBeFocused()
      await s.type('180')
      await s.press('ControlOrMeta+Enter')
      await expect(panel(page).getByRole('heading', { level: 2 })).toHaveText('Cliente 03')
      await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 180,00')
      // Start, customer, item, value.
      s.done('T1', 4)
    })

    test('T2 Achar a OS 501', async ({ page }) => {
      await startOnHome(page)
      const s = new Steps(page)
      s.start()
      // A digit on the screen opens the search with it (no ⌘K).
      await s.press('5')
      await expect(page.getByRole('combobox', { name: /Buscar/ })).toBeFocused()
      await s.pick(page.getByRole('listbox').getByRole('option'), /OS 501/, '01')
      await expect(page).toHaveURL(/order=scn-late/)
      await expect(panel(page)).toContainText('OS 501')
      // Start, the number.
      s.done('T2', 2)
    })

    test('T3 Mudar a situação para Concluído (primeira vez: S, C, Enter)', async ({ page }) => {
      const order = await makeOrder('admin', { status: 'approved' })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      await s.press('s')
      const picker = dialog(page, 'Qual a situação?')
      await expect(picker).toBeVisible()
      // First letter in the list (arrows also move).
      await s.press('c')
      await expect(picker.getByRole('button', { name: /^Concluído/ })).toBeFocused()
      await s.press('Enter')
      await expect(panel(page).getByTestId('order-status')).toHaveText('Concluído')
      // The next-maintenance question sits in the order: nothing to dismiss.
      await expect(panel(page).getByTestId('maintenance-offer')).toBeVisible()
      await expect.poll(async () => (await readOrder(order.id))?.status).toBe('done')
      // Start, Concluído.
      s.done('T3n', 2)
    })

    test('T3 Mudar a situação para Concluído (da 2ª vez: P)', async ({ page }) => {
      // Once from Aprovado straight to Concluído (not timed): the blue step remembers it.
      const before = await makeOrder('admin', { status: 'approved' })
      await openOrder(page, before.id)
      await page.keyboard.press('s')
      await expect(dialog(page, 'Qual a situação?')).toBeVisible()
      await page.keyboard.press('c')
      await expect(dialog(page, 'Qual a situação?').getByRole('button', { name: /^Concluído/ })).toBeFocused()
      await page.keyboard.press('Enter')
      await expect.poll(async () => (await readOrder(before.id))?.status).toBe('done')
      const order = await makeOrder('admin', { status: 'approved' })
      await openOrder(page, order.id, false)
      await expect(panel(page).getByTestId('next-step')).toHaveText('Concluir serviço')
      const s = new Steps(page)
      s.start()
      await s.press('p')
      await expect(panel(page).getByTestId('order-status')).toHaveText('Concluído')
      await expect(panel(page).getByTestId('maintenance-offer')).toBeVisible()
      await expect.poll(async () => (await readOrder(order.id))?.status).toBe('done')
      // Start (Concluir comes suggested).
      s.done('T3', 1)
    })

    test('T4 Receber o que falta em Pix (sinal pago em Pix: R, Enter)', async ({ page }) => {
      const order = await makeOrder('admin', {
        status: 'done', total: 300, paidAmount: 100,
        services: [{ service: { id: 'service-4', name: 'Serviço 4' }, value: 300 }],
        transactions: [{ id: 'tx-sinal', type: 'payment', amount: 100, paymentMethod: 'pix', createdAt: new Date().toISOString() }],
      })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      await s.press('r')
      const box = dialog(page, 'Receber')
      await expect(box.getByLabel('Quanto recebeu')).toHaveValue('200,00')
      // The method of the order's last payment comes chosen; Enter in the amount sends.
      await expect(box.getByLabel(/Como foi pago/)).toHaveValue('pix')
      await s.press('Enter')
      await expect(panel(page).getByTestId('order-totals')).toContainText('Tudo pago')
      // Start (amount and method suggested).
      s.done('T4', 1)
    })

    test('T4 Receber o que falta em Pix (sem pagamento anterior)', async ({ page }) => {
      const order = await makeOrder('admin', {
        status: 'done', total: 300, paidAmount: 100,
        services: [{ service: { id: 'service-4', name: 'Serviço 4' }, value: 300 }],
      })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      await s.press('r')
      const box = dialog(page, 'Receber')
      await expect(box.getByLabel('Quanto recebeu')).toHaveValue('200,00')
      const method = box.getByLabel(/Como foi pago/)
      await s.tabTo(method)
      // Typing the first letter picks it (on a Mac ↓ opens the list instead).
      await s.type('p')
      await expect(method).toHaveValue('pix')
      // A select does not submit on Enter: go to the day field (a text input) and Enter there.
      await s.press('Tab')
      await s.press('Enter')
      await expect(panel(page).getByTestId('order-totals')).toContainText('Tudo pago')
      // Start, method.
      s.done('T4n', 2)
    })

    test('T5 Mandar pelo WhatsApp (W)', async ({ page, context }) => {
      await context.route('https://wa.me/**', (route) => route.fulfill({ body: 'wa' }))
      const order = await makeOrder('admin', { status: 'done' })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      const popup = context.waitForEvent('page')
      await s.press('w')
      expect((await popup).url()).toMatch(/^https:\/\/wa\.me\//)
      // Start.
      s.done('T5', 1)
    })

    test('T5 Mandar pelo WhatsApp (M, Enter)', async ({ page, context }) => {
      await context.route('https://wa.me/**', (route) => route.fulfill({ body: 'wa' }))
      const order = await makeOrder('admin', { status: 'done' })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      await s.press('m')
      const sheet = dialog(page, 'Mandar para o cliente')
      // The focus is already on "Mandar pelo WhatsApp".
      await expect(sheet.getByTestId('share-whatsapp')).toBeFocused()
      const popup = context.waitForEvent('page')
      await s.press('Enter')
      await popup
      // Start (WhatsApp comes suggested).
      s.done('T5m', 1)
    })

    test('T6 Cadastrar cliente', async ({ page }) => {
      await startOnHome(page)
      const phone = `119${String(10000000 + Math.floor(Math.random() * 89999999))}`
      const name = newName()
      const s = new Steps(page)
      s.start()
      // ⌘K, the name, Enter on "Cadastrar cliente «…»": the form opens with the cursor on the phone.
      await s.press('ControlOrMeta+k')
      await expect(page.getByRole('combobox', { name: /Buscar/ })).toBeFocused()
      await s.type(name)
      const create = page.getByRole('option', { name: `Cadastrar cliente «${name}»` })
      await expect(create).toBeVisible()
      await expect(page.getByRole('combobox', { name: /Buscar/ })).toHaveAttribute('aria-activedescendant', (await create.getAttribute('id')) as string)
      await s.press('Enter')
      const form = page.getByTestId('customer-form')
      await expect(form.getByLabel('Nome', { exact: true })).toHaveValue(name)
      await expect(form.getByLabel('Telefone ou WhatsApp')).toBeFocused()
      await s.type(phone)
      await s.press('Enter')
      await expect(page.getByRole('complementary').getByRole('heading', { name })).toBeVisible()
      // Start, name, phone.
      s.done('T6', 3)
    })

    test('T6 Cadastrar cliente (mouse no menu e no +)', async ({ page }) => {
      await startOnHome(page)
      const phone = `119${String(10000000 + Math.floor(Math.random() * 89999999))}`
      const name = newName()
      const s = new Steps(page)
      s.start()
      await s.click(page.getByRole('navigation').getByRole('link', { name: 'Clientes' }))
      await s.click(page.getByTestId('new-customer'))
      const form = page.getByTestId('customer-form')
      await expect(form.getByLabel('Nome', { exact: true })).toBeFocused()
      await s.type(name)
      await s.tabTo(form.getByLabel('Telefone ou WhatsApp'))
      await s.type(phone)
      await s.press('Enter')
      await expect(page.getByRole('complementary').getByRole('heading', { name })).toBeVisible()
      s.done('T6m', 3)
    })

    test('T7 Remarcar a visita', async ({ page }) => {
      // Visit tomorrow 14:00, moved to a week from today at 8:30.
      const order = await makeOrder('admin', { status: 'approved', scheduledDate: `${dayFromToday(1)}T14:00:00.000` })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      await s.press('d')
      const box = dialog(page, 'Agendar dia e hora')
      await expect(box.getByLabel('Digite o dia e a hora')).toBeFocused()
      await s.type('+7 8:30')
      await expect(box.getByLabel('Visita')).toHaveValue(`${dayFromToday(7)}T08:30`)
      await s.press('Enter')
      await expect.poll(async () => (await readOrder(order.id))?.scheduledDate).toBe(`${dayFromToday(7)}T08:30:00.000`)
      // Start, day, time.
      s.done('T7', 3)
    })

    test('T8 Quanto falta receber', async ({ page }) => {
      const started = performance.now()
      await login(page, 'admin')
      await expect(page.getByTestId('summary')).toContainText('para receber')
      const answer = await page.getByTestId('summary').textContent()
      // Looking is the only decision.
      console.log(`CMP ${JSON.stringify({ task: 'T8', steps: 0, keys: 0, letters: 0, clicks: 0, decisions: 1, klm: 1.2, ms: 0, loginToAnswerMs: Math.round(performance.now() - started), answer })}`)
    })

    test('T9 Adicionar peça do catálogo', async ({ page }) => {
      const order = await makeOrder('admin', { status: 'approved' })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      await s.press('a')
      const picker = dialog(page, 'O que vai ser feito?')
      await expect(picker.getByRole('combobox')).toBeFocused()
      await s.pick(picker.getByRole('option'), /^Peça 1(?!\d)/, 'Peça 1')
      await expect(panel(page).getByTestId('order-line')).toHaveCount(2)
      await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 75,00')
      // Start, the part.
      s.done('T9', 2)
    })

    test('T10 Desconto de R$ 20', async ({ page }) => {
      const order = await makeOrder('admin', { status: 'done', total: 100, services: [{ service: { id: 'service-2', name: 'Serviço 2' }, value: 100 }] })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      // "-" opens Dar desconto.
      await s.press('-')
      const box = dialog(page, 'Dar desconto')
      await expect(box.getByLabel('Desconto')).toBeFocused()
      await s.type('20')
      await s.press('Enter')
      await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 80,00')
      // Start, value.
      s.done('T10', 2)
    })

    test('T10 Desconto de R$ 20 (mouse no menu)', async ({ page }) => {
      const order = await makeOrder('admin', { status: 'done', total: 100, services: [{ service: { id: 'service-2', name: 'Serviço 2' }, value: 100 }] })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      await s.click(panel(page).getByRole('button', { name: 'Mais ações' }))
      await s.click(page.getByRole('dialog').getByRole('button', { name: 'Desconto' }))
      const box = dialog(page, 'Dar desconto')
      await expect(box.getByLabel('Desconto')).toBeFocused()
      await s.type('20')
      await s.press('Enter')
      await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 80,00')
      // Start, Desconto in the menu, value.
      s.done('T10m', 3)
    })
  })
}
