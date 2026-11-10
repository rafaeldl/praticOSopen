// Importar catálogo de planilha (desk extra of fatia 05): CSV and XLSX,
// columns guessed and confirmed, repeated names out, prices read as typed,
// nothing saved before "Importar", and a retry that never doubles a line.
import { resolve } from 'node:path'
import { expect, test } from './test'
import { catalogNamed } from './data'
import { login } from './helpers'

test('CSV: prévia com tipo e preço; repetidos, sem nome, tipo e preço ruins ficam de fora; só grava ao confirmar (catalog.list.import)', async ({ page }) => {
  const stamp = `Zeta Imp ${Date.now()}`
  const csv = [
    'Descrição;Tipo;Preço;Obs',
    `${stamp} Polimento;Serviço;150;`,
    `${stamp} Filtro;Peça;R$ 1.234,56;`,
    `${stamp} Junta;peça;;sem preço`,
    'Serviço 1;serviço;50;já está no catálogo',
    `${stamp} polimento;servico;160;mesmo nome da linha 2`,
    `;Serviço;10;sem nome`,
    `${stamp} Brinde;Brinde;1;tipo desconhecido`,
    `${stamp} Caro;Serviço;muito;preço ruim`,
    `${stamp} Avulso;;80;sem tipo vira serviço`,
  ].join('\n')
  await login(page, 'admin', 'catalog')
  await page.getByTestId('catalog-import-link').click()
  await expect(page.getByRole('heading', { level: 1, name: 'Traga seu catálogo de uma planilha' })).toBeVisible()
  await page.getByTestId('import-file').setInputFiles({ name: 'catalogo.csv', mimeType: 'text/csv', buffer: Buffer.from(csv) })
  await expect(page.getByRole('heading', { level: 1, name: 'O que tem em cada coluna?' })).toBeVisible()
  await expect(page.getByLabel('O que tem na coluna Descrição')).toHaveValue('name')
  await expect(page.getByLabel('O que tem na coluna Tipo')).toHaveValue('kind')
  await expect(page.getByLabel('O que tem na coluna Preço')).toHaveValue('value')
  await expect(page.getByLabel('O que tem na coluna Obs')).toHaveValue('')
  await page.getByLabel('O que tem na coluna Descrição').selectOption('')
  await expect(page.getByText('Escolha a coluna do nome para continuar.')).toBeVisible()
  await page.getByLabel('O que tem na coluna Descrição').selectOption('name')
  await page.getByTestId('import-continue').click()
  await expect(page.getByRole('heading', { level: 1, name: '4 itens prontos para entrar' })).toBeVisible()
  const review = page.getByTestId('import-review')
  await expect(review.locator('tr[data-state="duplicate"]')).toContainText('já está no catálogo')
  await expect(review.locator('tr[data-state="repeated"]')).toContainText('mesmo nome da linha 2')
  await expect(review.locator('tr[data-state="noName"]')).toContainText('sem nome')
  await expect(review.locator('tr[data-state="badKind"]')).toContainText('tipo não é serviço nem peça')
  await expect(review.locator('tr[data-state="badPrice"]')).toContainText('preço que não deu para ler')
  await expect(review.getByRole('row').filter({ hasText: `${stamp} Filtro` })).toContainText('R$ 1.234,56')
  await expect(page.getByTestId('import-sub')).toHaveText('5 linhas ficam de fora.')
  // Nothing saved yet.
  expect(await catalogNamed('service', stamp)).toHaveLength(0)
  await page.getByTestId('import-finish').click()
  await expect(page.locator('.toast')).toContainText('4 itens importados')
  await expect(page.getByRole('heading', { level: 1, name: 'Catálogo' })).toBeVisible()
  const services = await catalogNamed('service', stamp)
  const products = await catalogNamed('product', stamp)
  expect(services.map((item) => [item.name, item.value]).sort()).toEqual([
    [`${stamp} Avulso`, 80],
    [`${stamp} Polimento`, 150],
  ])
  // "R$ 1.234,56" is 1234.56: read as typed, never 100 times smaller.
  expect(products.map((item) => [item.name, item.value]).sort()).toEqual([
    [`${stamp} Filtro`, 1234.56],
    [`${stamp} Junta`, null],
  ])
  expect(services[0]).toMatchObject({ createdBy: { id: 'e2e-admin' }, company: { id: 'company-alpha' } })
})

test('falha no meio e Importar de novo: nenhuma linha entra duas vezes', async ({ page }) => {
  const stamp = `Zeta Lote Imp ${Date.now()}`
  // 250 services (two parts of 200 + 50) and 10 parts; the second call fails the first time.
  const lines = [
    ...Array.from({ length: 250 }, (_, i) => `${stamp} S${String(i).padStart(3, '0')};Serviço;${i + 1}`),
    ...Array.from({ length: 10 }, (_, i) => `${stamp} P${i};Peça;${i + 1},50`),
  ]
  await login(page, 'admin', 'catalog/import')
  await page.getByTestId('import-file').setInputFiles({ name: 'lote.csv', mimeType: 'text/csv', buffer: Buffer.from(['Nome;Tipo;Valor', ...lines].join('\n')) })
  await page.getByTestId('import-continue').click()
  await expect(page.getByRole('heading', { level: 1, name: '260 itens prontos para entrar' })).toBeVisible()
  let calls = 0
  await page.route(/\/v1\/app\/(services|products)\/import$/, async (route) => {
    calls++
    if (calls === 2) return route.abort()
    return route.fallback()
  })
  await page.getByTestId('import-finish').click()
  await expect(page.getByTestId('import-message')).toContainText('Parou no meio', { timeout: 20_000 })
  await page.getByTestId('import-finish').click()
  await expect(page.locator('.toast')).toContainText('260 itens importados', { timeout: 20_000 })
  expect(await catalogNamed('service', stamp)).toHaveLength(250)
  const products = await catalogNamed('product', stamp)
  expect(products).toHaveLength(10)
  expect(products.find((item) => item.name === `${stamp} P0`)?.value).toBe(1.5)
})

test('XLSX: lê a primeira aba e mostra a prévia', async ({ page }) => {
  await login(page, 'admin', 'catalog/import')
  await page.getByTestId('import-file').setInputFiles(resolve(import.meta.dirname, 'fixtures/clientes.xlsx'))
  await expect(page.getByTestId('import-map')).toContainText('Planilha Um')
  await page.getByTestId('import-continue').click()
  await expect(page.getByTestId('import-review')).toBeVisible()
})

test('quem não cadastra no catálogo não chega à importação pela URL', async ({ page }) => {
  await login(page, 'manager', 'catalog/import')
  await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
})
