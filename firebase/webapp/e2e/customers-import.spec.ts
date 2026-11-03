// Importar clientes de planilha (desk extra of fatia 03): CSV and XLSX, columns
// guessed and confirmed, repeated phones out, nothing saved before "Importar".
import { resolve } from 'node:path'
import { expect, test } from '@playwright/test'
import { makeCustomer } from './data'
import { login } from './helpers'

test('CSV: prévia, colunas, telefone repetido e sem nome ficam de fora, e só grava ao confirmar', async ({ page }) => {
  const stamp = Date.now()
  const known = await makeCustomer({ phone: `(47) 9${String(stamp).slice(-4)}-0001` })
  const csv = [
    'Nome;Celular;E-mail;Observação',
    `Rita ${stamp};(47) 9${String(stamp).slice(-4)}-1101;rita@exemplo.test;antiga`,
    `Igual ${stamp};47 9${String(stamp).slice(-4)}0001;;`,
    `;(47) 9${String(stamp).slice(-4)}-1106;;sem nome`,
    `Rita F ${stamp};(47) 9${String(stamp).slice(-4)}-1101;;mesmo número da primeira`,
    `Paulo ${stamp};;;`,
  ].join('\n')
  await login(page, 'consultant', 'customers')
  await page.getByTestId('import-link').click()
  await expect(page.getByRole('heading', { level: 1, name: 'Traga seus clientes de uma planilha' })).toBeVisible()
  await page.getByTestId('import-file').setInputFiles({ name: 'clientes.csv', mimeType: 'text/csv', buffer: Buffer.from(csv) })
  await expect(page.getByRole('heading', { level: 1, name: 'O que tem em cada coluna?' })).toBeVisible()
  await expect(page.getByLabel('O que tem na coluna Nome')).toHaveValue('name')
  await expect(page.getByLabel('O que tem na coluna Celular')).toHaveValue('phone')
  await expect(page.getByLabel('O que tem na coluna Observação')).toHaveValue('')
  // Without the name column, no way forward.
  await page.getByLabel('O que tem na coluna Nome').selectOption('')
  await expect(page.getByText('Escolha a coluna do nome para continuar.')).toBeVisible()
  await page.getByLabel('O que tem na coluna Nome').selectOption('name')
  await page.getByTestId('import-continue').click()
  await expect(page.getByRole('heading', { level: 1, name: '2 clientes prontos para entrar' })).toBeVisible()
  const review = page.getByTestId('import-review')
  await expect(review.locator('tr[data-state="duplicate"]')).toContainText(`telefone já é de ${known.name}`)
  await expect(review.locator('tr[data-state="noName"]')).toContainText('sem nome')
  await expect(review.locator('tr[data-state="repeated"]')).toContainText('mesmo telefone da linha 2')
  await expect(page.getByTestId('import-sub')).toHaveText('3 linhas ficam de fora.')
  // Nothing saved yet.
  await page.goto(`customers?q=${encodeURIComponent(`Paulo ${stamp}`)}`)
  await expect(page.getByTestId('customers-no-match')).toBeVisible()
})

test('CSV: confirmar grava os que entram e volta à lista', async ({ page }) => {
  const stamp = Date.now()
  await login(page, 'admin', 'customers/import')
  await page.getByTestId('import-file').setInputFiles({
    name: 'c.csv',
    mimeType: 'text/csv',
    buffer: Buffer.from(`nome,telefone,cpf\nImportada ${stamp},,529.982.247-25\nOutra ${stamp},,`),
  })
  await page.getByTestId('import-continue').click()
  await page.getByTestId('import-finish').click()
  await expect(page.locator('.toast')).toContainText('2 clientes importados')
  await expect(page.getByRole('heading', { level: 1, name: 'Clientes' })).toBeVisible()
  await page.getByLabel(/Buscar por nome/).fill(`Importada ${stamp}`)
  await page.getByTestId('customers-table').getByRole('button', { name: `Importada ${stamp}` }).click()
  await expect(page.getByTestId('customer-contact')).toContainText('529.982.247-25')
})

test('XLSX: lê a primeira aba e mostra a prévia', async ({ page }) => {
  await login(page, 'supervisor', 'customers/import')
  await page.getByTestId('import-file').setInputFiles(resolve(import.meta.dirname, 'fixtures/clientes.xlsx'))
  await expect(page.getByTestId('import-map')).toContainText('Planilha Um')
  await page.getByTestId('import-continue').click()
  await expect(page.getByTestId('import-review').locator('tr[data-state="noName"]')).toHaveCount(1)
})

test('arquivo que não dá para ler e quem não cadastra não importa', async ({ page }) => {
  await login(page, 'admin', 'customers/import')
  await page.getByTestId('import-file').setInputFiles({ name: 'velho.xls', mimeType: 'application/vnd.ms-excel', buffer: Buffer.from('x') })
  await expect(page.getByTestId('import-message')).toContainText('formato antigo do Excel')
})

test('gerente não chega à importação pela URL', async ({ page }) => {
  await login(page, 'manager', 'customers/import')
  await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
})
