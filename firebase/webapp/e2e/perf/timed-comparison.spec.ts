// Timed comparison (docs/web-app/timed-comparison.md): the 10 most frequent tasks,
// keyboard only, on the production build against the emulators. Counts every key
// (a shortcut with a modifier counts 2, each letter 1) and every click, and times
// from the first key to the end state. Prints one "CMP {json}" line per run.
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
  done(task: string, extra: Record<string, unknown> = {}) {
    const ms = Math.round(performance.now() - this.started)
    console.log(`CMP ${JSON.stringify({ task, steps: this.total, keys: this.keys, letters: this.letters, clicks: this.clicks, ms, idleMs: this.idle, ...extra })}`)
  }
}

async function startOnHome(page: Page) {
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.waitForTimeout(600)
  await page.locator('h1').click()
}

async function openOrder(page: Page, id: string) {
  await login(page, 'admin', `orders?order=${id}`)
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
      s.done('T1')
    })

    test('T2 Achar a OS 501', async ({ page }) => {
      await startOnHome(page)
      const s = new Steps(page)
      s.start()
      await s.press('ControlOrMeta+k')
      await expect(page.getByRole('combobox', { name: /Buscar/ })).toBeFocused()
      await s.pick(page.getByRole('listbox').getByRole('option'), /OS 501/, '501')
      await expect(page).toHaveURL(/order=scn-late/)
      await expect(panel(page)).toContainText('OS 501')
      s.done('T2')
    })

    test('T3 Mudar a situação para Concluído', async ({ page }) => {
      const order = await makeOrder('admin', { status: 'approved' })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      await s.press('s')
      const picker = dialog(page, 'Qual a situação?')
      await s.tabTo(picker.getByRole('button', { name: /^Concluído/ }))
      await s.press('Enter')
      await expect(dialog(page, 'Quando é a próxima manutenção?')).toBeVisible()
      await s.press('Escape')
      await expect(panel(page).getByTestId('order-status')).toHaveText('Concluído')
      await expect.poll(async () => (await readOrder(order.id))?.status).toBe('done')
      s.done('T3')
    })

    test('T4 Receber o que falta em Pix', async ({ page }) => {
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
      s.done('T4')
    })

    test('T5 Mandar pelo WhatsApp', async ({ page, context }) => {
      await context.route('https://wa.me/**', (route) => route.fulfill({ body: 'wa' }))
      const order = await makeOrder('admin', { status: 'done' })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      await s.press('m')
      const sheet = dialog(page, 'Mandar para o cliente')
      await expect(sheet.getByTestId('share-url')).toHaveText(/\/q\//)
      const popup = context.waitForEvent('page')
      await s.tabTo(sheet.getByTestId('share-whatsapp'))
      await s.press('Enter')
      await popup
      s.done('T5')
    })

    test('T6 Cadastrar cliente', async ({ page }) => {
      await startOnHome(page)
      const phone = `119${String(10000000 + Math.floor(Math.random() * 89999999))}`
      const name = newName()
      const s = new Steps(page)
      s.start()
      await s.press('ControlOrMeta+k')
      await s.pick(page.getByRole('listbox').getByRole('option'), /^Ir para Clientes/, 'clientes')
      await expect(page).toHaveURL(/\/customers/)
      const search = page.getByLabel(/Buscar por nome/)
      await expect(search).toBeVisible()
      await s.press('/')
      await expect(search).toBeFocused()
      await s.type(name)
      const create = page.getByTestId('create-from-search')
      await s.tabTo(create)
      await s.press('Enter')
      const form = page.getByTestId('customer-form')
      await expect(form.getByLabel('Nome', { exact: true })).toHaveValue(name)
      await s.tabTo(form.getByLabel('Telefone ou WhatsApp'))
      await s.type(phone)
      await s.press('ControlOrMeta+Enter')
      await expect(page.getByRole('complementary').getByRole('heading', { name })).toBeVisible()
      s.done('T6')
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
      await s.press('ControlOrMeta+Enter')
      await expect(page.getByRole('complementary').getByRole('heading', { name })).toBeVisible()
      s.done('T6m')
    })

    test('T7 Remarcar a visita', async ({ page }) => {
      const order = await makeOrder('admin', { status: 'approved', scheduledDate: '2030-05-02T14:00:00.000' })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      await s.press('d')
      const field = dialog(page, 'Agendar dia e hora').getByLabel('Visita')
      await expect(field).toBeFocused()
      // Chromium's datetime-local (pt-BR with --lang): dd mm yyyy, then → to the time (the year takes 6 digits), hh mm.
      await s.type('09052030')
      await s.press('ArrowRight')
      await s.type('0830')
      await expect(field).toHaveValue('2030-05-09T08:30')
      await s.press('Enter')
      await expect.poll(async () => (await readOrder(order.id))?.scheduledDate).toBe('2030-05-09T08:30:00.000')
      s.done('T7')
    })

    test('T8 Quanto falta receber', async ({ page }) => {
      const started = performance.now()
      await login(page, 'admin')
      await expect(page.getByTestId('summary')).toContainText('para receber')
      const answer = await page.getByTestId('summary').textContent()
      console.log(`CMP ${JSON.stringify({ task: 'T8', steps: 0, keys: 0, letters: 0, clicks: 0, ms: 0, loginToAnswerMs: Math.round(performance.now() - started), answer })}`)
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
      s.done('T9')
    })

    test('T10 Desconto de R$ 20', async ({ page }) => {
      const order = await makeOrder('admin', { status: 'done', total: 100, services: [{ service: { id: 'service-2', name: 'Serviço 2' }, value: 100 }] })
      await openOrder(page, order.id)
      const s = new Steps(page)
      s.start()
      // "Mais ações" sits above the title: back with Shift+Tab.
      await s.tabTo(panel(page).getByRole('button', { name: 'Mais ações' }), 30, 'Shift+Tab')
      await s.press('Enter')
      const item = page.getByRole('dialog').getByRole('button', { name: 'Desconto' })
      await s.tabTo(item)
      await s.press('Enter')
      const box = dialog(page, 'Dar desconto')
      await expect(box.getByLabel('Desconto')).toBeFocused()
      await s.type('20')
      await s.press('Enter')
      await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 80,00')
      s.done('T10')
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
      s.done('T10m')
    })
  })
}
