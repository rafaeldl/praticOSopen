// Fatia 05 on every screen: axe in light and dark, 320 to 2560 px without side
// scroll, text at 200%, and the three languages.
import { expect, test, type Page } from '@playwright/test'
import { makeCatalogItem } from './data'
import { expectNoAxeViolations, expectNoSideScroll, login, setTheme } from './helpers'

async function catalogScreens(page: Page, label: string) {
  await page.goto('catalog')
  await expect(page.getByTestId('catalog-table')).toBeVisible()
  await expectNoAxeViolations(page, `catálogo ${label}`)
  await page.getByTestId('new-catalog-item').click()
  await page.getByTestId('catalog-form').getByText('Foto e mais dados').click()
  await expectNoAxeViolations(page, `cadastro de serviço ${label}`)
  await page.keyboard.press('Escape')
  await expect(page.getByTestId('catalog-form')).toBeHidden()
  await page.getByTestId('kind-product').click()
  await page.getByTestId('catalog-table').getByRole('button', { name: 'Editar Peça 1' }).first().click()
  await page.getByTestId('catalog-item-menu').click()
  await expectNoAxeViolations(page, `menu do item ${label}`)
}

async function priceAndImportScreens(page: Page, label: string) {
  const stamp = `Zeta A11y ${Date.now()}`
  await makeCatalogItem('service', { name: `${stamp} A`, value: 10 })
  await makeCatalogItem('service', { name: `${stamp} B`, value: null })
  await page.goto(`catalog?q=${encodeURIComponent(stamp)}`)
  await expect(page.getByTestId('catalog-table').getByTestId('catalog-group-all').getByRole('row')).toHaveCount(2)
  await page.getByTestId('select-all').check()
  await expectNoAxeViolations(page, `seleção ${label}`)
  await page.getByTestId('change-prices').click()
  await expect(page.getByTestId('price-preview')).toBeVisible()
  await expectNoAxeViolations(page, `preços em lote ${label}`)
  await page.getByTestId('price-apply').click()
  await expectNoAxeViolations(page, `confirmar preços ${label}`)
  await page.keyboard.press('Escape')
  await page.keyboard.press('Escape')
  await page.goto('catalog/import')
  await expectNoAxeViolations(page, `importar catálogo ${label}`)
  await page.getByTestId('import-file').setInputFiles({ name: 'c.csv', mimeType: 'text/csv', buffer: Buffer.from('Nome;Tipo;Preço\nVela;Peça;20\n;Serviço;x') })
  await expect(page.getByTestId('import-map')).toBeVisible()
  await expectNoAxeViolations(page, `colunas do catálogo ${label}`)
  await page.getByTestId('import-continue').click()
  await expect(page.getByTestId('import-review')).toBeVisible()
  await expectNoAxeViolations(page, `prévia do catálogo ${label}`)
}

for (const theme of ['light', 'dark'] as const) {
  const name = theme === 'light' ? 'claro' : 'escuro'
  for (const [part, audit] of [
    ['catálogo', catalogScreens],
    ['preços e importação', priceAndImportScreens],
  ] as const) {
    test(`axe: 0 violações em ${part}, tema ${name}`, async ({ page }) => {
      await page.emulateMedia({ colorScheme: theme })
      await login(page, 'admin', 'login')
      await setTheme(page, theme)
      await audit(page, theme)
    })
  }
}

for (const [width, height] of [
  [320, 640],
  [2560, 1440],
] as const) {
  test(`${width} px sem rolagem lateral nas telas do catálogo`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await login(page, 'admin', 'catalog')
    for (const [path, testId] of [
      ['catalog', 'catalog-table'],
      ['catalog?kind=product', 'catalog-table'],
      ['catalog/import', 'import-file'],
    ] as const) {
      await page.goto(path)
      await expect(page.getByTestId(testId)).toBeAttached()
      await expectNoSideScroll(page)
    }
  })
}

for (const [width, height] of [
  [320, 640],
  [1366, 768],
] as const) {
  test(`texto a 200% em ${width} px nas telas do catálogo`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await login(page, 'admin', 'catalog')
    for (const [path, testId] of [
      ['catalog', 'catalog-table'],
      ['catalog/import', 'import-file'],
    ] as const) {
      await page.goto(path)
      await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
      await expect(page.getByTestId(testId)).toBeAttached()
      await expectNoSideScroll(page)
    }
    await page.goto('catalog')
    await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await page.getByTestId('new-catalog-item').click()
    await expect(page.getByTestId('catalog-form')).toBeVisible()
    const overflow = await page.evaluate(() => {
      const box = document.querySelector('.layer-box') as HTMLElement
      return box.scrollWidth - box.clientWidth
    })
    expect(overflow).toBeLessThanOrEqual(1)
  })
}

for (const [language, title, services, parts, newService] of [
  ['en', 'Catalog', 'Services', 'Parts', 'New service'],
  ['es', 'Catálogo', 'Servicios', 'Piezas', 'Nuevo servicio'],
] as const) {
  test(`idioma ${language}: textos do catálogo e rótulo do segmento`, async ({ page }) => {
    await login(page, 'admin', 'catalog')
    await page.evaluate((value) => localStorage.setItem('praticos.prefs', JSON.stringify({ language: value })), language)
    await page.reload()
    await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
    await expect(page.getByTestId('kind-service')).toHaveText(new RegExp(`^${services} \\(\\d+\\)$`))
    await expect(page.getByTestId('kind-product')).toHaveText(new RegExp(`^${parts} \\(\\d+\\)$`))
    await expect(page.getByTestId('new-catalog-item')).toHaveText(newService)
  })
}
