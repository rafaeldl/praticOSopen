// Preços em lote (desk extra of fatia 05): select rows, raise or lower by a
// percentage, see every item before and after, confirm, and undo. The server
// changes all or none; each change carries the price the person saw.
import { expect, test, type Page } from '@playwright/test'
import { makeCatalogItem, readCatalogItem, updateCatalogItem } from './data'
import { login } from './helpers'

const table = (page: Page) => page.getByTestId('catalog-table')
const dialog = (page: Page) => page.getByTestId('price-dialog')

async function selectStamp(page: Page, stamp: string) {
  await login(page, 'admin', 'catalog')
  await expect(table(page)).toBeVisible()
  await page.getByLabel('Buscar pelo nome').fill(stamp)
  await expect(table(page).getByTestId('catalog-group-all').getByRole('row')).toHaveCount(3)
  await page.getByTestId('select-all').check()
  await expect(page.getByTestId('catalog-batch')).toContainText('3 itens')
  await page.getByTestId('change-prices').click()
  await expect(dialog(page).getByRole('heading', { name: 'Mudar o preço de 3 itens' })).toBeVisible()
}

test('aumentar 10%: antes e depois, confirmação, grava e Desfazer volta (catalog.list.bulk-price)', async ({ page }) => {
  const stamp = `Zeta Lote ${Date.now()}`
  const a = await makeCatalogItem('service', { name: `${stamp} A`, value: 100 })
  const b = await makeCatalogItem('service', { name: `${stamp} B`, value: 35.5 })
  const c = await makeCatalogItem('service', { name: `${stamp} C`, value: null })
  await selectStamp(page, stamp)
  const preview = dialog(page).getByTestId('price-preview')
  await expect(preview.getByRole('row').filter({ hasText: `${stamp} A` })).toContainText(/R\$\s100,00.*R\$\s110,00/)
  await expect(preview.getByRole('row').filter({ hasText: `${stamp} B` })).toContainText(/R\$\s35,50.*R\$\s39,05/)
  await expect(dialog(page)).toContainText('1 item sem preço fica como está.')
  // Lowering more than 100% is refused before anything is sent.
  await page.getByTestId('price-down').click()
  await dialog(page).getByLabel('Porcentagem').fill('150')
  await expect(dialog(page)).toContainText('Escreva uma porcentagem de 0 a 100.')
  await page.getByTestId('price-up').click()
  await dialog(page).getByLabel('Porcentagem').fill('10')
  await page.getByTestId('price-apply').click()
  // Nothing is saved before the confirmation.
  expect((await readCatalogItem('service', a.id))?.value).toBe(100)
  const confirm = page.getByRole('dialog', { name: 'Mudar o preço de 2 itens?' })
  await expect(confirm).toContainText('As OS já feitas não mudam.')
  await confirm.getByRole('button', { name: 'Mudar preços' }).click()
  await expect(page.locator('.toast')).toContainText('Preço de 2 itens mudou')
  expect((await readCatalogItem('service', a.id))?.value).toBe(110)
  expect((await readCatalogItem('service', b.id))?.value).toBe(39.05)
  expect((await readCatalogItem('service', c.id))?.value).toBeNull()
  await expect(table(page).getByRole('row').filter({ hasText: `${stamp} A` })).toContainText('R$ 110,00')
  await page.locator('.toast').getByRole('button', { name: 'Desfazer' }).click()
  await expect(page.locator('.toast')).toContainText('Preços de volta ao que eram')
  expect((await readCatalogItem('service', a.id))?.value).toBe(100)
  expect((await readCatalogItem('service', b.id))?.value).toBe(35.5)
})

test('arredondar para inteiro', async ({ page }) => {
  const stamp = `Zeta Redondo ${Date.now()}`
  const a = await makeCatalogItem('service', { name: `${stamp} A`, value: 49.9 })
  await makeCatalogItem('service', { name: `${stamp} B`, value: 10 })
  await makeCatalogItem('service', { name: `${stamp} C`, value: 20 })
  await selectStamp(page, stamp)
  await dialog(page).getByLabel('Porcentagem').fill('0')
  await page.getByTestId('price-round').check()
  await expect(dialog(page).getByTestId('price-preview').getByRole('row').filter({ hasText: `${stamp} A` })).toContainText(/R\$\s49,90.*R\$\s50,00/)
  await page.getByTestId('price-apply').click()
  await page.getByRole('dialog', { name: 'Mudar o preço de 1 item?' }).getByRole('button', { name: 'Mudar preços' }).click()
  await expect(page.locator('.toast')).toContainText('Preço de 1 item mudou')
  expect((await readCatalogItem('service', a.id))?.value).toBe(50)
})

test('alguém mudou um preço enquanto a prévia estava aberta: nada é gravado', async ({ page }) => {
  const stamp = `Zeta Conflito ${Date.now()}`
  const a = await makeCatalogItem('product', { name: `${stamp} A`, value: 100 })
  const b = await makeCatalogItem('product', { name: `${stamp} B`, value: 200 })
  await makeCatalogItem('product', { name: `${stamp} C`, value: 300 })
  await login(page, 'admin', 'catalog?kind=product')
  await page.getByLabel('Buscar pelo nome').fill(stamp)
  await expect(table(page).getByTestId('catalog-group-all').getByRole('row')).toHaveCount(3)
  await page.getByTestId('select-all').check()
  await page.getByTestId('change-prices').click()
  await updateCatalogItem('product', b.id, { value: 250 })
  await page.getByTestId('price-apply').click()
  await page.getByRole('dialog', { name: 'Mudar o preço de 3 itens?' }).getByRole('button', { name: 'Mudar preços' }).click()
  // 409: the preview closes and the list shows the new prices (revisão A1).
  await expect(page.locator('.toast')).toContainText('Alguém mudou algum desses preços')
  await expect(page.getByTestId('price-dialog')).toBeHidden()
  await expect(page.getByTestId('catalog-batch')).toHaveCount(0)
  await expect(table(page).getByRole('row').filter({ hasText: `${stamp} B` })).toContainText('R$ 250,00')
  expect((await readCatalogItem('product', a.id))?.value).toBe(100)
  expect((await readCatalogItem('product', b.id))?.value).toBe(250)
})

test('a resposta se perde depois de gravar: Tentar de novo manda o mesmo lote e não aplica duas vezes (revisão A1)', async ({ page }) => {
  const stamp = `Zeta Perdida ${Date.now()}`
  const a = await makeCatalogItem('service', { name: `${stamp} A`, value: 100 })
  const b = await makeCatalogItem('service', { name: `${stamp} B`, value: 200 })
  await makeCatalogItem('service', { name: `${stamp} C`, value: null })
  await selectStamp(page, stamp)
  const bodies: unknown[] = []
  await page.route(/\/v1\/app\/services\/prices$/, async (route) => {
    bodies.push(route.request().postDataJSON())
    if (bodies.length === 1) {
      // The server saves; the answer never reaches the browser.
      await route.fetch()
      return route.abort('failed')
    }
    return route.fallback()
  })
  await page.getByTestId('price-apply').click()
  await page.getByRole('dialog', { name: 'Mudar o preço de 2 itens?' }).getByRole('button', { name: 'Mudar preços' }).click()
  await expect(page.getByTestId('price-error')).toContainText('Tentar de novo manda o mesmo pedido')
  expect((await readCatalogItem('service', a.id))?.value).toBe(110)
  // The preview keeps what was sent, never recalculated from the saved prices.
  await expect(dialog(page).getByTestId('price-preview').getByRole('row').filter({ hasText: `${stamp} A` })).toContainText(/R\$\s100,00.*R\$\s110,00/)
  await page.getByTestId('price-apply').click()
  await expect(page.locator('.toast')).toContainText('Preço de 2 itens mudou')
  expect(bodies).toHaveLength(2)
  expect(bodies[1]).toEqual(bodies[0])
  expect((await readCatalogItem('service', a.id))?.value).toBe(110)
  expect((await readCatalogItem('service', b.id))?.value).toBe(220)
})

test('consultor e supervisor não selecionam linhas para mudar preço', async ({ page }) => {
  await login(page, 'consultant', 'catalog')
  await expect(table(page)).toBeVisible()
  await expect(page.getByTestId('select-all')).toHaveCount(0)
  await expect(table(page).getByRole('checkbox')).toHaveCount(0)
})
