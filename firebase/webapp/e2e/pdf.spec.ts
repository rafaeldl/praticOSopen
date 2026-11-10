// PDF of the order and of several (order.pdf.view, order.pdf.viewer, order.pdf.close,
// order.pdf.batch): made in the browser like the app's, read back here as text.
import { readFileSync } from 'node:fs'
import { expect, test, type Page } from './test'
import { getApps, initializeApp } from 'firebase-admin/app'
import { getFirestore } from 'firebase-admin/firestore'
import { randomUUID } from 'node:crypto'
import { COMPANY_A, COMPANY_C, PROJECT_ID } from './fixtures.mjs'
import { makeOrder } from './data'
import { chooseCompany, login, type UserKey } from './helpers'
import { pdfPageCount, pdfText } from '../tests/pdf-text'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
// 1x1 PNG: a photo the browser downloads without Storage.
const PHOTO = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='

function db() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('só no emulador')
  return getFirestore(getApps()[0] ?? initializeApp({ projectId: PROJECT_ID }))
}

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  if (user === 'owner') await chooseCompany(page, 'Oficina Alfa')
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

async function openMenu(page: Page) {
  await panel(page).getByRole('button', { name: 'Mais ações' }).click()
  return page.getByRole('dialog')
}

async function download(page: Page): Promise<Uint8Array> {
  const dialog = page.getByTestId('pdf-dialog')
  await expect(dialog).toContainText('está pronto', { timeout: 20_000 })
  const [file] = await Promise.all([page.waitForEvent('download'), page.getByTestId('pdf-download').click()])
  return new Uint8Array(readFileSync((await file.path()) as string))
}

test('admin: PDF da OS com valores, fotos, link e checklist; abrir e fechar (order.pdf.view, order.pdf.viewer, order.pdf.close)', async ({ page }) => {
  const order = await makeOrder('admin', {
    address: 'Rua do Teste, 42',
    photos: [{ id: 'p1', url: PHOTO }, { id: 'p2', url: 'http://127.0.0.1:9/nao-existe.jpg' }],
    shareLink: { token: 'tok-pdf-e2e', permissions: ['view'] },
    assignedTo: { id: 'e2e-technician', name: 'Tiago Tecnico' },
  })
  await db()
    .doc(`companies/${COMPANY_A}/orders/${order.id}/forms/f-${randomUUID().slice(0, 6)}`)
    .set({
      formDefinitionId: 'tpl',
      title: 'Entrada do veículo',
      status: 'completed',
      startedAt: new Date().toISOString(),
      items: [{ id: 'i1', label: 'Pneus bons?', type: 'boolean' }],
      responses: [{ itemId: 'i1', value: true, photoUrls: [PHOTO] }],
    })
  await openOrder(page, 'admin', order.id)
  await (await openMenu(page)).getByRole('button', { name: 'Ver PDF' }).click()
  const dialog = page.getByRole('dialog', { name: `PDF da OS ${order.number}` })
  await expect(dialog).toBeVisible()
  const bytes = await download(page)
  const text = pdfText(bytes)
  for (const expected of [`#${order.number}`, 'Oficina Alfa', 'Cliente 02', 'Veículo 2', 'TST0002', 'Serviço 1', 'R$ 50,00', 'TOTAL', 'Técnico: Tiago Tecnico', 'Rua do Teste, 42', 'FOTOS ANEXADAS (1)', 'Fotos disponíveis no sistema digital', 'Acompanhe online', 'https://praticos.app/q/tok-pdf-e2e', 'ENTRADA DO VEÍCULO', 'X SIM', 'Página 1 de 1']) {
    expect(text, expected).toContain(expected)
  }
  expect(pdfPageCount(bytes)).toBe(2)
  await expect(page.getByTestId('pdf-open')).toHaveAttribute('href', /^blob:/)
  await expect(page.getByTestId('pdf-open')).toHaveAttribute('target', '_blank')
  await page.keyboard.press('Escape')
  await expect(dialog).toBeHidden()
})

for (const user of ['supervisor', 'technician'] as const) {
  test(`${user}: com valores ligados, não recebe o PDF (canShareOrderPdf)`, async ({ page }) => {
    const order = await makeOrder('admin', user === 'technician' ? { assignedTo: { id: 'e2e-technician', name: 'Tiago Tecnico' } } : {})
    await openOrder(page, user, order.id)
    const menu = await openMenu(page)
    await expect(menu).toBeVisible()
    await expect(menu.getByRole('button', { name: 'Ver PDF' })).toHaveCount(0)
    await expect(menu.getByRole('button', { name: 'Imprimir ou salvar PDF' })).toHaveCount(0)
  })
}

test('empresa sem valores: o dono baixa o PDF sem nenhum valor', async ({ page }) => {
  const id = `t-${randomUUID().slice(0, 8)}`
  const now = new Date().toISOString()
  await db()
    .doc(`companies/${COMPANY_C}/orders/${id}`)
    .set({
      number: 4242,
      status: 'approved',
      company: { id: COMPANY_C, name: 'Gama Sem Valores' },
      customer: { id: 'c-gamma', name: 'Cliente Gama' },
      services: [{ service: { id: 's1', name: 'Revisão' }, value: 321 }],
      products: [],
      total: 321,
      paidAmount: 0,
      createdAt: now,
      createdBy: { id: 'e2e-novalues', name: 'Vera Sem Valores' },
      updatedAt: now,
    })
  await login(page, 'noValues', `orders?order=${id}`)
  await expect(panel(page)).toBeVisible()
  await (await openMenu(page)).getByRole('button', { name: 'Ver PDF' }).click()
  const text = pdfText(await download(page))
  expect(text).toContain('Revisão')
  expect(text).toContain('Cliente Gama')
  expect(text).not.toMatch(/R\$|321/)
  expect(text).not.toContain('RESUMO')
})

test('várias OS selecionadas num PDF só, cada uma nas suas páginas (order.pdf.batch)', async ({ page }) => {
  const a = await makeOrder('admin', { customer: { id: 'customer-2', name: 'Cliente Lote PDF' } })
  const b = await makeOrder('admin', { customer: { id: 'customer-2', name: 'Cliente Lote PDF' } })
  await login(page, 'admin', `orders?f=all&q=${encodeURIComponent('Cliente Lote PDF')}`)
  await page.getByLabel(`Selecionar OS ${a.number}`).check()
  await page.getByLabel(`Selecionar OS ${b.number}`).check()
  await page.getByTestId('batch-pdf').click()
  await expect(page.getByRole('dialog', { name: 'PDF de 2 OS' })).toBeVisible()
  const bytes = await download(page)
  const text = pdfText(bytes)
  expect(text).toContain(`#${a.number}`)
  expect(text).toContain(`#${b.number}`)
  expect(text.match(/Página 1 de 1/g)?.length).toBe(2)
  expect(pdfPageCount(bytes)).toBe(2)
})

test('B4: caractere fora do Latin-1 sai pela fonte de reserva, não como "?"', async ({ page }) => {
  const order = await makeOrder('admin', { services: [{ service: { id: 's-mu', name: 'Capacitor 35μF' }, value: 10 }] })
  await openOrder(page, 'admin', order.id)
  await (await openMenu(page)).getByRole('button', { name: 'Ver PDF' }).click()
  const bytes = await download(page)
  expect(Buffer.from(bytes).toString('latin1')).toContain('/FontFile2')
  expect(pdfText(bytes)).not.toContain('35?F')
})
