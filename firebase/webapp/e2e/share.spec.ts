// Sending on the web where the app opens its share sheet (lib/share,
// ShareButtons): WhatsApp to the customer's record phone, copy, and the
// browser's own sheet (Web Share API). WhatsApp never opens and no sheet is
// shown: window.open and navigator.share are replaced here and the tests read
// what they got (the link, the text, the file).
import { randomUUID } from 'node:crypto'
import { expect, test, type Page } from '@playwright/test'
import { makeCustomer, makeOrder, readOrder, writeDoc } from './data'
import { chooseCompany, login, type UserKey } from './helpers'

test.use({ permissions: ['clipboard-read', 'clipboard-write'] })

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })
// 1x1 PNG: a photo the browser reads without Storage.
const PHOTO = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='

type Shared = { title?: string; text?: string; files: { name: string; type: string; size: number }[] }

/** navigator.share records instead of showing; canShare takes files unless told not to; window.open records the URL. */
async function stubShare(page: Page, files = true) {
  await page.addInitScript((takesFiles) => {
    const w = window as unknown as { __shared: unknown[]; __opened: string[] }
    w.__shared = []
    w.__opened = []
    Object.defineProperty(Navigator.prototype, 'share', {
      configurable: true,
      value: async (data: ShareData) => {
        w.__shared.push({ title: data.title, text: data.text, files: (data.files ?? []).map((f) => ({ name: f.name, type: f.type, size: f.size })) })
      },
    })
    Object.defineProperty(Navigator.prototype, 'canShare', { configurable: true, value: (data: ShareData) => takesFiles || !data?.files?.length })
    window.open = ((url: string) => {
      w.__opened.push(String(url))
      return {} as Window
    }) as typeof window.open
  }, files)
}
const shared = (page: Page) => page.evaluate(() => (window as unknown as { __shared: Shared[] }).__shared)
const opened = (page: Page) => page.evaluate(() => (window as unknown as { __opened: string[] }).__opened)

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  if (user === 'owner') await chooseCompany(page, 'Oficina Alfa')
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

/**
 * "Começar serviço". Under load the order's first write can be refused as
 * changed elsewhere (a trigger touches the new order); then it is clicked again.
 */
async function startService(page: Page) {
  const step = panel(page).getByTestId('next-step')
  await expect(async () => {
    if ((await step.textContent())?.trim() === 'Começar serviço' && (await step.isEnabled())) await step.click()
    await expect(step).toHaveText('Concluir serviço', { timeout: 5000 })
  }).toPass({ timeout: 25_000 })
}

test('avisar o cliente depois de mudar a situação: nota com "Avisar", WhatsApp com o link e o texto da situação, uma vez por OS (order.status.notify, order.share.native)', async ({ page }) => {
  await stubShare(page)
  const customer = await makeCustomer({ phone: '+5511990007001' })
  const order = await makeOrder('admin', { customer: { id: customer.id, name: customer.name, phone: '+5511900000000' }, status: 'approved' })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByTestId('next-step').click()
  const note = panel(page).getByTestId('notify-note')
  await expect(note).toContainText(`Avisar ${customer.name}?`)
  await expect(note).toHaveAttribute('role', 'status')
  await note.getByTestId('notify-now').click()
  // Straight to WhatsApp with the order's link: the number of the customer's record, the words of "em andamento".
  await expect.poll(async () => (await opened(page)).length).toBe(1)
  const [url] = await opened(page)
  expect(url).toMatch(/^https:\/\/wa\.me\/5511990007001\?text=/)
  const text = decodeURIComponent(url!.split('text=')[1]!)
  expect(text).toContain(`Começamos o serviço: OS ${order.number}.`)
  expect(text).toMatch(/\/q\/[A-Za-z0-9_-]+/)
  await expect(dialog(page, 'Mandar para o cliente')).toHaveCount(0)
  // Once per order on this screen: concluding does not ask again. The button
  // turns into "Concluir serviço" only after "em andamento" is saved; a click
  // before that is lost (CI).
  const step = panel(page).getByTestId('next-step')
  await expect(step).toHaveText('Concluir serviço', { timeout: 15_000 })
  await expect(step).toBeEnabled()
  await step.click()
  // Saved as done (the maintenance question depends on the shared vehicle, so it is not waited for).
  await expect.poll(async () => (await readOrder(order.id))?.status).toBe('done')
  await expect(panel(page).getByTestId('notify-note')).toHaveCount(0)
})

test('sem telefone, a nota não aparece (order.status.notify)', async ({ page }) => {
  const noPhone = await makeOrder('admin', { customer: { id: 'customer-2', name: 'Cliente 02' }, status: 'approved' })
  await openOrder(page, 'admin', noPhone.id)
  await startService(page)
  await expect(panel(page).getByTestId('notify-note')).toHaveCount(0)
})

test('com link ativo, a nota não aparece (order.status.notify)', async ({ page }) => {
  const linked = await makeOrder('admin', {
    customer: { id: 'customer-2', name: 'Cliente 02', phone: '+5511990007002' },
    status: 'approved',
    shareLink: { token: `tok-${randomUUID().slice(0, 6)}`, expiresAt: new Date(Date.now() + 5 * 86_400_000).toISOString(), permissions: ['view'] },
  })
  await openOrder(page, 'admin', linked.id)
  await startService(page)
  await expect(panel(page).getByTestId('notify-note')).toHaveCount(0)
})

test('mandar de outro jeito: a folha do navegador com o texto e o link (order.share-sheet.other)', async ({ page }) => {
  await stubShare(page)
  const customer = await makeCustomer({ phone: '+5511990007003' })
  const order = await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, status: 'done' })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByTestId('share-open').click()
  const sheet = dialog(page, 'Mandar para o cliente')
  const url = (await sheet.getByTestId('share-url').textContent())!
  await sheet.getByTestId('share-other').click()
  await expect.poll(async () => (await shared(page)).length).toBe(1)
  const [data] = await shared(page)
  expect(data!.title).toBe(`OS ${order.number}`)
  expect(data!.text).toContain(url)
  expect(data!.text).toContain(`Olá, ${customer.name}!`)
})

test('sem a folha do navegador, "Mandar de outro jeito" não aparece (order.share-sheet.other)', async ({ page }) => {
  await page.addInitScript(() => Object.defineProperty(Navigator.prototype, 'share', { configurable: true, value: undefined }))
  const order = await makeOrder('admin', { status: 'done' })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByTestId('share-open').click()
  const sheet = dialog(page, 'Mandar para o cliente')
  await expect(sheet.getByTestId('share-copy')).toBeVisible()
  await expect(sheet.getByTestId('share-other')).toHaveCount(0)
})

test('PDF da OS: compartilhar o arquivo e mandar pelo WhatsApp baixa o PDF e manda o link (order.pdf.share)', async ({ page }) => {
  await stubShare(page)
  const customer = await makeCustomer({ phone: '+5511990007004' })
  const order = await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, status: 'done' })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Mais ações' }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Ver PDF' }).click()
  const pdf = dialog(page, `PDF da OS ${order.number}`)
  await expect(pdf.getByTestId('pdf-dialog')).toContainText('está pronto', { timeout: 20_000 })
  await pdf.getByTestId('pdf-share').click()
  await expect.poll(async () => (await shared(page)).length).toBe(1)
  const [data] = await shared(page)
  expect(data!.files).toHaveLength(1)
  expect(data!.files[0]!.name).toMatch(/\.pdf$/)
  expect(data!.files[0]!.type).toBe('application/pdf')
  expect(data!.files[0]!.size).toBeGreaterThan(1000)

  const [file] = await Promise.all([page.waitForEvent('download'), pdf.getByTestId('pdf-whatsapp').click()])
  expect(file.suggestedFilename()).toMatch(/\.pdf$/)
  await expect(page.locator('.toast')).toContainText('PDF baixado')
  await expect.poll(async () => (await opened(page)).length).toBe(1)
  const [url] = await opened(page)
  expect(url).toMatch(/^https:\/\/wa\.me\/5511990007004\?text=/)
  expect(decodeURIComponent(url!)).toMatch(/\/q\/[A-Za-z0-9_-]+/)
})

test('PDF sem a folha do navegador para arquivos: sem "Compartilhar", Baixar fica (order.pdf.share)', async ({ page }) => {
  await stubShare(page, false)
  const order = await makeOrder('admin', { status: 'done' })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Mais ações' }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Ver PDF' }).click()
  const pdf = dialog(page, `PDF da OS ${order.number}`)
  await expect(pdf.getByTestId('pdf-dialog')).toContainText('está pronto', { timeout: 20_000 })
  await expect(pdf.getByTestId('pdf-download')).toBeVisible()
  await expect(pdf.getByTestId('pdf-whatsapp')).toBeVisible()
  await expect(pdf.getByTestId('pdf-share')).toHaveCount(0)
})

test('foto: compartilhar o arquivo, baixar, copiar o link e WhatsApp com o telefone do cadastro (order.photo.share)', async ({ page }) => {
  await stubShare(page)
  const customer = await makeCustomer({ phone: '(11) 99000-7005' })
  const order = await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, photos: [{ id: 'p1', url: PHOTO }] })
  await openOrder(page, 'admin', order.id)
  await panel(page).getByRole('button', { name: 'Ver foto 1' }).click()
  const viewer = page.getByTestId('photo-viewer').locator('..')
  // Without "+", the company's country code (Brazil) goes first.
  await expect.poll(() => viewer.getByTestId('photo-share-whatsapp').getAttribute('href')).toMatch(/^https:\/\/wa\.me\/5511990007005\?text=/)
  const href = (await viewer.getByTestId('photo-share-whatsapp').getAttribute('href'))!
  expect(decodeURIComponent(href)).toContain(`Foto da OS ${order.number}: ${PHOTO}`)
  expect(await viewer.getByTestId('photo-share-whatsapp').getAttribute('target')).toBe('_blank')

  await viewer.getByTestId('photo-share-sheet').click()
  await expect.poll(async () => (await shared(page)).length).toBe(1)
  expect((await shared(page))[0]!.files[0]!.type).toBe('image/png')

  await viewer.getByTestId('photo-share-copy').click()
  await expect(page.locator('.toast')).toContainText('Link copiado')
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(PHOTO)

  const [file] = await Promise.all([page.waitForEvent('download'), viewer.getByTestId('photo-download').click()])
  expect(file.suggestedFilename()).toMatch(/\.jpg$/)
})

test('recibo: mandar pelo WhatsApp com as palavras do recibo para o telefone do cadastro (receipt.share.pdf)', async ({ page }) => {
  await stubShare(page)
  const customer = await makeCustomer({ phone: '+5511990007006' })
  // Two orders: one order alone opens that order's "Receber".
  for (const total of [50, 30])
    await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, status: 'done', total, paidAmount: 0, payment: 'unpaid', services: [{ service: { id: 'service-1', name: 'Serviço 1' }, value: total }] })
  await login(page, 'admin', `customers?customer=${customer.id}`)
  await expect(page.getByTestId('customer-detail').getByText('Carregando…')).toHaveCount(0)
  await page.getByTestId('customer-receive').click()
  await page.getByTestId('receive-customer-save').click()
  await dialog(page, /Receber R\$ 80,00/).getByRole('button', { name: 'Confirmar recebimento' }).click()
  await expect(page.locator('.toast')).toContainText(`Recebido R$ 80,00 de ${customer.name}`)
  await page.getByTestId('customer-receipts').click()
  const list = page.getByTestId('receipts')
  await expect(list.getByTestId('receipt-row')).toHaveCount(1)
  const whatsapp = list.getByTestId('receipt-share-whatsapp')
  await expect.poll(() => whatsapp.getAttribute('href')).toMatch(/^https:\/\/wa\.me\/5511990007006\?text=/)
  const text = decodeURIComponent((await whatsapp.getAttribute('href'))!.split('text=')[1]!)
  // Money comes with a no-break space after "R$".
  expect(text).toMatch(new RegExp(`Recebemos de ${customer.name} a quantia de R\\$\\s80,00`))
  expect(text).toContain('Oficina Alfa')
  await list.getByTestId('receipt-share-sheet').click()
  await expect.poll(async () => (await shared(page)).length).toBe(1)
  expect((await shared(page))[0]!.text).toContain('Recebemos de')
})

test('nota fiscal: compartilhar cai no link quando o PDF não baixa; WhatsApp com o link para o telefone do cadastro (nfse.invoice.share-pdf)', async ({ page }) => {
  await stubShare(page)
  const customer = await makeCustomer({ phone: '+5511990007007' })
  const id = `nf-${randomUUID().slice(0, 8)}`
  const today = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
  await writeDoc(`invoices/${id}`, {
    status: 'authorized', number: '7788', customer: { id: customer.id, name: customer.name }, value: 90, effectiveDate: today, orderIds: [`o-${id}`],
    orders: [{ orderId: `o-${id}`, orderNumber: 8102, value: 90 }], pdfUrl: 'https://sandbox.asaas.test/nota-7788.pdf', xmlUrl: 'https://sandbox.asaas.test/nota-7788.xml',
    createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
  })
  await page.route('https://sandbox.asaas.test/**', (route) => route.abort())
  await login(page, 'admin', `invoices?invoice=${id}`)
  const nota = page.getByTestId('nfse-panel')
  await expect(nota.getByTestId('nfse-status')).toContainText('7788')
  const whatsapp = nota.getByTestId('nfse-share-whatsapp')
  await expect.poll(() => whatsapp.getAttribute('href')).toMatch(/^https:\/\/wa\.me\/5511990007007\?text=/)
  expect(decodeURIComponent((await whatsapp.getAttribute('href'))!)).toContain(`Olá, ${customer.name}! Segue a nota fiscal 7788:\nhttps://sandbox.asaas.test/nota-7788.pdf`)
  await nota.getByTestId('nfse-share-sheet').click()
  await expect.poll(async () => (await shared(page)).length).toBe(1)
  const [data] = await shared(page)
  expect(data!.files).toHaveLength(0)
  expect(data!.text).toContain('https://sandbox.asaas.test/nota-7788.pdf')
  await nota.getByTestId('nfse-share-copy').click()
  expect(await page.evaluate(() => navigator.clipboard.readText())).toBe('https://sandbox.asaas.test/nota-7788.pdf')
})
