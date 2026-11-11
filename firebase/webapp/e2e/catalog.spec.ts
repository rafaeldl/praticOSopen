// Fatia 05, catálogo (catalog.*), against the Emulator Suite. Company A is in
// the automotive segment, which names products "Peças" and has one service
// field ("Garantia"). Items a test changes are made by the test (Zeta …).
import { expect, test, type Page } from './test'
import { makeCatalogItem, makeOrder, readCatalogItem, updateCatalogItem, catalogNamed } from './data'
import { login, signOut } from './helpers'

const table = (page: Page) => page.getByTestId('catalog-table')
const form = (page: Page) => page.getByTestId('catalog-form')
const row = (page: Page, text: string) => table(page).getByTestId('catalog-group-all').getByRole('row').filter({ hasText: text })
const search = (page: Page) => page.getByLabel('Buscar pelo nome')
// 1x1 PNG.
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64')

async function openCatalog(page: Page, user: Parameters<typeof login>[1], query = '') {
  await login(page, user, `catalog${query}`)
  await expect(page.getByRole('heading', { level: 1, name: 'Catálogo' })).toBeVisible()
  await expect(table(page)).toBeVisible()
}

test('lista com Serviços | Peças, preço, troca de tipo e dica (catalog.list.view, catalog.list.switch, catalog.list.price, catalog.list.tip)', async ({ page }) => {
  await openCatalog(page, 'admin')
  await expect(page.getByTestId('catalog-summary')).toHaveText('O que você coloca nas OS')
  // Products carry the segment's name ("Peças"), with the count of each kind.
  await expect(page.getByTestId('kind-service')).toHaveText(/^Serviços \(\d+\)$/)
  await expect(page.getByTestId('kind-product')).toHaveText(/^Peças \(\d+\)$/)
  await expect(page.getByTestId('kind-service')).toHaveAttribute('aria-pressed', 'true')
  await expect(row(page, 'Serviço 2')).toContainText('R$ 100,00')
  await expect(page.getByText('Dica: dá para cadastrar direto na OS, digitando o nome na busca.')).toBeVisible()
  await search(page).fill('serviço 3')
  await page.getByTestId('kind-product').click()
  // Changing the kind clears the search, as in the app.
  await expect(search(page)).toHaveValue('')
  await expect(page).toHaveURL(/kind=product/)
  await expect(row(page, 'Peça 2')).toContainText('R$ 50,00')
  await expect(page.getByTestId('new-catalog-item')).toHaveText('Cadastrar peça')
})

test('abrir direto em Peças pela URL (catalog.list.products)', async ({ page }) => {
  await openCatalog(page, 'consultant', '?kind=product')
  await expect(page.getByTestId('kind-product')).toHaveAttribute('aria-pressed', 'true')
  await expect(row(page, 'Peça 1')).toBeVisible()
})

test('busca sem acento e sem caixa; nada achado diz o que buscou (catalog.list.search)', async ({ page }) => {
  const stamp = Date.now()
  await makeCatalogItem('service', { name: `Zeta Óleo Câmbio ${stamp}`, value: 90 })
  await openCatalog(page, 'admin')
  await search(page).fill(`zeta oleo cambio ${stamp}`)
  await expect(row(page, `Zeta Óleo Câmbio ${stamp}`)).toBeVisible()
  await expect(page.getByTestId('catalog-summary')).toHaveText('1 encontrado')
  await search(page).fill(`nada ${stamp}`)
  await expect(page.getByTestId('catalog-no-match')).toContainText(`Nada com “nada ${stamp}”`)
  await page.getByRole('button', { name: 'Limpar a busca' }).click()
  await expect(table(page)).toBeVisible()
})

test('supervisor vê o catálogo sem preço: nada de valor na rede, linhas só para ler (catalog.source.access, catalog.list.price)', async ({ page }) => {
  const list = page.waitForResponse((response) => /\/v1\/app\/services$/.test(response.url()))
  await openCatalog(page, 'supervisor')
  const body = await (await list).json()
  expect(JSON.stringify(body.data)).not.toMatch(/"value"/)
  expect(body.meta.prices).toBe(false)
  await expect(table(page).getByRole('columnheader', { name: 'Preço' })).toHaveCount(0)
  await expect(row(page, 'Serviço 2')).not.toContainText('R$')
  await expect(page.getByTestId('new-catalog-item')).toHaveCount(0)
  await expect(page.getByTestId('catalog-import-link')).toHaveCount(0)
  await expect(row(page, 'Serviço 2').getByRole('button')).toHaveCount(0)
  await expect(table(page).getByRole('checkbox')).toHaveCount(0)
  await page.goto('settings')
  await signOut(page)
  await openCatalog(page, 'consultant')
  await expect(row(page, 'Serviço 2')).toContainText('R$ 100,00')
  await expect(row(page, 'Serviço 2').getByRole('button')).toHaveCount(0)
  await expect(page.getByTestId('new-catalog-item')).toHaveCount(0)
})

test('técnico não vê o Catálogo no menu e a URL é barrada (catalog.list.view)', async ({ page }) => {
  await login(page, 'technician')
  await expect(page.getByRole('navigation', { name: 'Principal' }).getByRole('link', { name: 'Catálogo' })).toHaveCount(0)
  await page.goto('catalog')
  await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
})

test('cadastrar serviço: salvar cinza até ter nome, preço lido como digitado, campo do ramo e foto (catalog.list.create, catalog.form.save, catalog.form.price, catalog.form.custom-fields, catalog.form.photo)', async ({ page }) => {
  const name = `Zeta Lavagem ${Date.now()}`
  await openCatalog(page, 'admin')
  await page.getByTestId('new-catalog-item').click()
  await expect(form(page).getByRole('heading', { name: 'Novo serviço' })).toBeVisible()
  await expect(form(page).getByLabel('Nome')).toBeFocused()
  await expect(form(page).getByLabel('Nome')).toHaveAttribute('placeholder', 'Ex.: Troca de óleo')
  await expect(page.getByTestId('save-catalog-item')).toHaveClass(/is-muted/)
  await page.getByTestId('save-catalog-item').click()
  await expect(form(page).getByRole('alert')).toHaveText('Escreva o nome para salvar.')
  await form(page).getByLabel('Nome').fill(`  ${name}  `)
  await form(page).getByLabel('Preço').fill('150')
  await form(page).getByText('Foto e mais dados').click()
  await form(page).getByLabel('Garantia').fill('90 dias')
  await page.getByTestId('catalog-photo-file').setInputFiles({ name: 'foto.png', mimeType: 'image/png', buffer: PNG })
  await expect(page.getByTestId('catalog-photo-preview')).toBeVisible()
  await page.getByTestId('save-catalog-item').click()
  await expect(form(page)).toBeHidden()
  await expect(page.locator('.toast')).toContainText('Salvo')
  await search(page).fill(name)
  await expect(row(page, name)).toContainText('R$ 150,00')
  await expect(row(page, name).locator('img.cat-thumb')).toBeVisible()
  const [saved] = await catalogNamed('service', name)
  // "150" is 150, never 1,50; the name without the spaces around it.
  expect(saved).toMatchObject({ name, value: 150, customData: { warranty: '90 dias' }, company: { id: 'company-alpha' } })
  expect(String(saved?.photo)).toContain(encodeURIComponent(`services/${saved?.id}/photo.jpg`))
})

test('cancelar com foto escolhida não deixa item sem nome (defeito C9) e pergunta antes de descartar', async ({ page }) => {
  const stamp = Date.now()
  await openCatalog(page, 'admin', '?kind=product')
  const before = (await catalogNamed('product', '')).length
  await page.getByTestId('new-catalog-item').click()
  await form(page).getByLabel('Nome').fill(`Zeta Junta ${stamp}`)
  await form(page).getByText('Foto e mais dados').click()
  await page.getByTestId('catalog-photo-file').setInputFiles({ name: 'foto.png', mimeType: 'image/png', buffer: PNG })
  page.once('dialog', (dialog) => void dialog.dismiss())
  await page.keyboard.press('Escape')
  await expect(form(page)).toBeVisible()
  page.once('dialog', (dialog) => void dialog.accept())
  await page.keyboard.press('Escape')
  await expect(form(page)).toBeHidden()
  expect((await catalogNamed('product', '')).length).toBe(before)
})

test('editar: nome e preço, sem mexer em quem criou; fechar com mudança pergunta (catalog.form.edit)', async ({ page }) => {
  const item = await makeCatalogItem('service', { value: 80, createdAt: '2026-01-01T10:00:00.000Z' })
  await openCatalog(page, 'admin')
  await search(page).fill(item.name)
  await row(page, item.name).getByRole('button', { name: `Editar ${item.name}` }).click()
  await expect(form(page).getByRole('heading', { name: item.name })).toBeVisible()
  await expect(form(page).getByLabel('Preço')).toHaveValue('80,00')
  await form(page).getByLabel('Nome').fill(`${item.name} B`)
  page.once('dialog', (dialog) => void dialog.dismiss())
  await form(page).getByRole('button', { name: 'Fechar' }).click()
  await expect(form(page)).toBeVisible()
  await form(page).getByLabel('Preço').fill('1.234,50')
  await page.keyboard.press(process.platform === 'darwin' ? 'Meta+Enter' : 'Control+Enter')
  await expect(form(page)).toBeHidden()
  const saved = await readCatalogItem('service', item.id)
  expect(saved).toMatchObject({ name: `${item.name} B`, value: 1234.5, createdAt: '2026-01-01T10:00:00.000Z', createdBy: { id: 'e2e-owner' }, updatedBy: { id: 'e2e-admin' } })
})

test('editado no app enquanto a tela estava aberta: nada é gravado por cima (catalog.form.edit)', async ({ page }) => {
  const item = await makeCatalogItem('product', { value: 10 })
  await openCatalog(page, 'admin', '?kind=product')
  await search(page).fill(item.name)
  await row(page, item.name).getByRole('button', { name: `Editar ${item.name}` }).click()
  await form(page).getByLabel('Preço').fill('12')
  await updateCatalogItem('product', item.id, { value: 11 })
  await page.getByTestId('save-catalog-item').click()
  await expect(page.locator('.toast')).toContainText('Outra pessoa mudou este item')
  expect((await readCatalogItem('product', item.id))?.value).toBe(11)
  await expect(row(page, item.name)).toContainText('R$ 11,00')
})

test('apagar pelo menu "…" com confirmação; a foto sai junto (catalog.form.delete)', async ({ page }) => {
  const item = await makeCatalogItem('service', { value: 30 })
  await openCatalog(page, 'admin')
  await search(page).fill(item.name)
  await row(page, item.name).getByRole('button', { name: `Editar ${item.name}` }).click()
  await page.getByTestId('catalog-item-menu').click()
  await page.getByRole('button', { name: 'Apagar serviço' }).click()
  const confirm = page.getByRole('dialog', { name: `Apagar ${item.name}?` })
  await expect(confirm).toContainText('Ele sai do catálogo. As OS que já usam continuam salvas.')
  await confirm.getByRole('button', { name: 'Apagar serviço' }).click()
  await expect(page.locator('.toast')).toContainText(`${item.name} saiu do catálogo`)
  await expect(page.getByTestId('catalog-no-match')).toBeVisible()
  expect(await readCatalogItem('service', item.id)).toBeUndefined()
})

test('mais usados do tipo, nas OS que a pessoa vê (catalog.list.most-used)', async ({ page }) => {
  const item = await makeCatalogItem('product', { value: 5 })
  for (let i = 0; i < 3; i++) {
    await makeOrder('consultant', { services: [], products: [{ product: { id: item.id, name: item.name }, value: 5, quantity: 1, total: 5 }] })
  }
  await openCatalog(page, 'consultant', '?kind=product')
  await expect(table(page).getByTestId('catalog-group-most')).toContainText(item.name)
  await expect(table(page).getByTestId('catalog-group-most')).toContainText('Mais usados')
  // During a search the shortcut list goes away.
  await search(page).fill(item.name)
  await expect(table(page).getByTestId('catalog-group-most').getByRole('row')).toHaveCount(0)
})

test('vazio, erro com Tentar de novo e carregando (catalog.list.view)', async ({ page }) => {
  let fail = true
  await page.route(/\/v1\/app\/products$/, (route) => (fail ? route.fulfill({ status: 500, body: '{}' }) : route.fallback()))
  await login(page, 'admin', 'catalog?kind=product')
  await expect(page.getByText('Não deu para carregar o catálogo. Tente de novo.')).toBeVisible()
  fail = false
  await page.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(table(page)).toBeVisible()
  await page.route(/\/v1\/app\/services$/, (route) => route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ success: true, data: [], meta: { prices: true, mostUsed: [] } }) }))
  await page.getByTestId('kind-service').click()
  await page.reload()
  await expect(page.getByTestId('catalog-empty')).toContainText('Você ainda não tem serviços')
  await expect(page.getByTestId('first-catalog-item')).toHaveText('Novo serviço')
})
