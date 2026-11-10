// Proof of a payment (pay.order.attach-proof, pay.order.view-proof,
// pay.widget.proof-picker, pay.widget.sheet): attach while receiving, replace
// and take out from "Já recebido". The file goes to the Storage emulator and the
// server checks it (validateReceiptFile accepts the emulator's http URL only
// inside the Functions emulator).
import { expect, test, type Page } from './test'
import { getApps, initializeApp } from 'firebase-admin/app'
import { getStorage } from 'firebase-admin/storage'
import { makeOrder, readOrder } from './data'
import { PROJECT_ID } from './fixtures.mjs'
import { expectNoAxeViolations, login, setTheme, type UserKey } from './helpers'

const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64')
const PDF = Buffer.from('%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n')

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

const done = (author: UserKey, total: number, extra: Record<string, unknown> = {}) =>
  makeOrder(author, {
    customer: { id: 'customer-4', name: 'Cliente 04' },
    status: 'done',
    total,
    paidAmount: 0,
    payment: 'unpaid',
    services: [{ service: { id: 'service-1', name: 'Serviço 1' }, value: total }],
    ...extra,
  })

type Doc = { id: string; url: string; storagePath: string; fileName?: string; contentType?: string }
type Tx = { id: string; receiptDocumentId?: string }

async function proofOf(orderId: string): Promise<Doc | null> {
  const saved = await readOrder(orderId)
  const tx = ((saved?.transactions ?? []) as Tx[])[0]
  if (!tx?.receiptDocumentId) return null
  return ((saved?.documents ?? []) as Doc[]).find((doc) => doc.id === tx.receiptDocumentId) ?? null
}

/** Picks a file through the button, as a person does (the file chooser opens). */
async function choose(page: Page, button: ReturnType<Page['getByRole']>, file: { name: string; mimeType: string; buffer: Buffer }) {
  const chooser = page.waitForEvent('filechooser')
  await button.click()
  await (await chooser).setFiles(file)
}

/** Whether the Storage emulator still has the file (admin SDK, emulator only). */
async function storageHas(path: string): Promise<boolean> {
  if (!process.env.FIREBASE_STORAGE_EMULATOR_HOST) throw new Error('só no emulador')
  const app = getApps()[0] ?? initializeApp({ projectId: PROJECT_ID })
  const [exists] = await getStorage(app).bucket(`${PROJECT_ID}.appspot.com`).file(path).exists()
  return exists
}

const fileStatus = (url: string) => fetch(url).then((response) => response.status)

test('anexar ao receber, ver, trocar e tirar o comprovante (pay.order.attach-proof, pay.widget.sheet, pay.order.view-proof)', async ({ page }) => {
  const order = await done('admin', 150)
  await openOrder(page, 'admin', order.id)
  await panel(page).getByTestId('next-step').click()
  const sheet = dialog(page, 'Receber')
  // Wrong kind of file: a sentence, nothing attached.
  await sheet.getByTestId('receive-proof-input').setInputFiles({ name: 'nota.txt', mimeType: 'text/plain', buffer: Buffer.from('x') })
  await expect(sheet.getByRole('alert')).toContainText('O comprovante precisa ser uma imagem ou um PDF.')
  await sheet.getByTestId('receive-proof-input').setInputFiles({ name: 'pix.png', mimeType: 'image/png', buffer: PNG })
  await expect(sheet.getByTestId('receive-proof')).toContainText('pix.png')
  await sheet.getByRole('button', { name: 'Marcar como recebido' }).click()
  await expect(sheet).toHaveCount(0)

  const history = panel(page).getByTestId('payment-history')
  await expect(history.getByRole('link', { name: 'Ver comprovante' })).toBeVisible()
  const first = await proofOf(order.id)
  expect(first?.storagePath).toMatch(new RegExp(`^tenants/company-alpha/orders/${order.id}/payments/[^/]+/receipt_\\d+\\.png$`))
  expect(first?.contentType).toBe('image/png')
  expect(first?.fileName).toBe('pix.png')
  expect(await history.getByRole('link', { name: 'Ver comprovante' }).getAttribute('href')).toBe(first!.url)
  expect(await fileStatus(first!.url)).toBe(200)

  // Replace: a new file, the old one leaves the Storage.
  await choose(page, history.getByRole('button', { name: 'Trocar comprovante de R$ 150,00' }), { name: 'recibo.pdf', mimeType: 'application/pdf', buffer: PDF })
  await expect(page.locator('.toast')).toContainText('Comprovante guardado')
  await expect.poll(async () => (await proofOf(order.id))?.fileName).toBe('recibo.pdf')
  const second = (await proofOf(order.id))!
  expect(second.contentType).toBe('application/pdf')
  await expect.poll(() => fileStatus(first!.url)).not.toBe(200)

  // Take out: asks first; the payment stays, the file goes.
  await history.getByRole('button', { name: 'Tirar comprovante de R$ 150,00' }).click()
  await dialog(page, 'Tirar o comprovante?').getByRole('button', { name: 'Tirar comprovante' }).click()
  await expect(history.getByRole('link', { name: 'Ver comprovante' })).toHaveCount(0)
  await expect(history.getByRole('button', { name: 'Anexar comprovante a R$ 150,00' })).toBeVisible()
  const saved = await readOrder(order.id)
  expect((saved?.transactions as Tx[]).length).toBe(1)
  expect((saved?.transactions as Tx[])[0]!.receiptDocumentId).toBeUndefined()
  expect(saved?.paidAmount).toBe(150)
  await expect.poll(() => fileStatus(second.url)).not.toBe(200)
})

test('consultor anexa na OS dele; gerente vê o comprovante, mas não anexa nem troca (pay.order.attach-proof, por papel)', async ({ page }) => {
  const own = await done('consultant', 100, { paidAmount: 30, transactions: [{ id: 'cproof1', type: 'payment', amount: 30, createdAt: new Date().toISOString() }] })
  await openOrder(page, 'consultant', own.id)
  const history = panel(page).getByTestId('payment-history')
  await choose(page, history.getByRole('button', { name: 'Anexar comprovante a R$ 30,00' }), { name: 'pix.png', mimeType: 'image/png', buffer: PNG })
  await expect(history.getByRole('link', { name: 'Ver comprovante' })).toBeVisible()
  expect((await proofOf(own.id))?.storagePath).toContain(`/orders/${own.id}/payments/cproof1/`)

  const other = await done('admin', 100, { paidAmount: 30, transactions: [{ id: 'mproof1', type: 'payment', amount: 30, createdAt: new Date().toISOString() }] })
  const context = await page.context().browser()!.newContext({ ...test.info().project.use })
  const manager = await context.newPage()
  await openOrder(manager, 'manager', other.id)
  const managerHistory = panel(manager).getByTestId('payment-history')
  await expect(managerHistory.getByTestId('payment-row')).toHaveCount(1)
  await expect(managerHistory.getByRole('button', { name: /comprovante/ })).toHaveCount(0)
  await expect(managerHistory.getByTestId('proof-input')).toHaveCount(0)
  await context.close()
})

for (const theme of ['light', 'dark'] as const) {
  test(`axe sem violações em Receber com comprovante (${theme})`, async ({ page }) => {
    const order = await done('admin', 90)
    await openOrder(page, 'admin', order.id)
    await setTheme(page, theme)
    await panel(page).getByTestId('next-step').click()
    const sheet = dialog(page, 'Receber')
    await sheet.getByTestId('receive-proof-input').setInputFiles({ name: 'pix.png', mimeType: 'image/png', buffer: PNG })
    await expect(sheet.getByTestId('receive-proof')).toBeVisible()
    await expectNoAxeViolations(page, `receber com comprovante ${theme}`)
  })
}

test('a API recusa depois do envio: o arquivo que subiu é apagado (comprovante órfão)', async ({ page }) => {
  const order = await done('admin', 70, { paidAmount: 10, transactions: [{ id: 'orph1', type: 'payment', amount: 10, createdAt: new Date().toISOString() }] })
  await openOrder(page, 'admin', order.id)
  const uploads: string[] = []
  page.on('request', (request) => {
    const match = /\/o\?name=([^&]+)/.exec(request.url()) ?? /\/o\/([^?]+)\?/.exec(request.url())
    if (request.method() === 'POST' && match && decodeURIComponent(match[1]!).includes('/payments/orph1/')) uploads.push(decodeURIComponent(match[1]!))
  })
  await page.route(/\/payments\/orph1\/receipt/, (route) =>
    route.fulfill({ status: 409, contentType: 'application/json', body: JSON.stringify({ success: false, error: { code: 'ORDER_STATUS', message: 'no' } }) }),
  )
  const history = panel(page).getByTestId('payment-history')
  await choose(page, history.getByRole('button', { name: 'Anexar comprovante a R$ 10,00' }), { name: 'pix.png', mimeType: 'image/png', buffer: PNG })
  await expect.poll(() => uploads.length).toBeGreaterThan(0)
  await expect.poll(() => storageHas(uploads[0]!)).toBe(false)
  expect((await readOrder(order.id))?.documents ?? []).toEqual([])
})
