// Documents of the order (order.media.add-document, order.media.document-type,
// order.document.open, order.media.document-view, order.document.delete,
// order.media.document-delete): add with the type asked first, open in a new
// tab, take out asked first; per role where it changes.
import { expect, test, type Page } from '@playwright/test'
import { makeOrder, readOrder } from './data'
import { expectNoAxeViolations, login, setTheme, type UserKey } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const dialog = (page: Page, name: string | RegExp) => page.getByRole('dialog', { name })
const PDF = Buffer.from('%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n')

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

test('anexar documento: pergunta o tipo, aparece com o link e sai com confirmação (order.media.add-document, order.document.delete)', async ({ page }) => {
  const order = await makeOrder('admin')
  await openOrder(page, 'admin', order.id)
  const docs = panel(page).getByTestId('order-documents')
  await expect(docs).toContainText('Nenhum documento')
  // Something the Storage would refuse is said before uploading.
  await docs.getByTestId('document-input').setInputFiles({ name: 'planilha.zip', mimeType: 'application/zip', buffer: Buffer.from('x') })
  await expect(docs.getByRole('alert')).toHaveText('Escolha uma imagem, um PDF ou um documento do Word.')
  await docs.getByTestId('document-input').setInputFiles({ name: 'garantia.pdf', mimeType: 'application/pdf', buffer: PDF })
  const type = dialog(page, 'Que documento é este?')
  await expect(type).toContainText('garantia.pdf')
  await type.getByRole('button', { name: 'Garantia' }).click()
  await expect(page.locator('.toast')).toContainText('Documento adicionado')
  const row = docs.getByTestId('document-row')
  await expect(row).toContainText('Garantia')
  const link = row.getByRole('link', { name: 'garantia.pdf' })
  await expect(link).toHaveAttribute('target', '_blank')
  const saved = ((await readOrder(order.id))?.documents as { type: string; storagePath: string; url: string; fileName: string }[])[0]!
  expect(saved).toMatchObject({ type: 'warranty', fileName: 'garantia.pdf' })
  expect(saved.storagePath).toMatch(new RegExp(`^tenants/company-alpha/orders/${order.id}/documents/`))
  expect(await fetch(saved.url).then((response) => response.status)).toBe(200)

  await row.getByRole('button', { name: 'Excluir garantia.pdf' }).click()
  await dialog(page, 'Excluir Documento').getByRole('button', { name: 'Excluir' }).click()
  await expect(docs.getByTestId('document-row')).toHaveCount(0)
  await expect.poll(async () => ((await readOrder(order.id))?.documents as unknown[]).length).toBe(0)
  await expect.poll(() => fetch(saved.url).then((response) => response.status)).not.toBe(200)
})

test('quem não vê valores abre o documento, sem o comprovante de pagamento; gerente não exclui (order.document.open, order.media.document-view, por papel)', async ({ page, browser }) => {
  const order = await makeOrder('admin', {
    status: 'done',
    documents: [
      { id: 'nf', url: 'https://firebasestorage.googleapis.com/v0/b/demo/o/nota.pdf?alt=media', fileName: 'nota.pdf', type: 'invoice', contentType: 'application/pdf', fileSize: 3000 },
      { id: 'pr', url: 'https://firebasestorage.googleapis.com/v0/b/demo/o/prova.pdf?alt=media', fileName: 'prova.pdf', type: 'receipt', linkedTransactionId: 'tx1' },
    ],
  })
  await openOrder(page, 'supervisor', order.id)
  const docs = panel(page).getByTestId('order-documents')
  await expect(docs.getByRole('link', { name: 'nota.pdf' })).toHaveAttribute('href', /nota\.pdf/)
  await expect(docs).toContainText('Nota Fiscal · 3 KB')
  await expect(docs.getByText('prova.pdf')).toHaveCount(0)

  const context = await browser.newContext({ ...test.info().project.use })
  const manager = await context.newPage()
  await openOrder(manager, 'manager', order.id)
  await expect(panel(manager).getByTestId('order-documents').getByRole('link', { name: 'nota.pdf' })).toBeVisible()
  await expect(panel(manager).getByTestId('order-documents').getByRole('button', { name: /Excluir/ })).toHaveCount(0)
  await expect(panel(manager).getByRole('button', { name: 'Adicionar Documento' })).toHaveCount(0)
  await context.close()
})

for (const theme of ['light', 'dark'] as const) {
  test(`axe sem violações com documentos (${theme})`, async ({ page }) => {
    const order = await makeOrder('admin', { documents: [{ id: 'nf', url: 'https://firebasestorage.googleapis.com/v0/b/demo/o/nota.pdf?alt=media', fileName: 'nota.pdf', type: 'invoice' }] })
    await openOrder(page, 'admin', order.id)
    await setTheme(page, theme)
    await expect(panel(page).getByTestId('document-row')).toBeVisible()
    await expectNoAxeViolations(page, `documentos ${theme}`)
  })
}

test('"Comprovante" só é oferecido a quem vê valores (B1, por papel)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved' })
  await openOrder(page, 'supervisor', order.id)
  const docs = panel(page).getByTestId('order-documents')
  await docs.getByTestId('document-input').setInputFiles({ name: 'contrato.pdf', mimeType: 'application/pdf', buffer: PDF })
  const type = dialog(page, 'Que documento é este?')
  await expect(type.getByRole('button', { name: 'Contrato' })).toBeVisible()
  await expect(type.getByRole('button', { name: 'Comprovante' })).toHaveCount(0)
})
