// Fatia 03 on every screen: axe in light and dark, 320 to 2560 px without side
// scroll, text at 200%, and the three languages.
import { expect, test, type Page } from '@playwright/test'
import { makeCustomer, makeDevice, makeOrder } from './data'
import { expectNoAxeViolations, expectNoSideScroll, login, setTheme } from './helpers'

async function seedOne() {
  const customer = await makeCustomer({ phone: '(48) 98408-7801', email: 'a11y@exemplo.test', taxId: '52998224725', address: 'Rua A, 1' })
  const device = await makeDevice({ status: 'active' })
  await makeOrder('admin', { customer: { id: customer.id, name: customer.name }, devices: [{ id: device.id, name: device.name, serial: device.serial }], deviceIds: [device.id], status: 'done', total: 100, paidAmount: 0 })
  return { customer, device }
}

async function customerScreens(page: Page, label: string, ids: Awaited<ReturnType<typeof seedOne>>) {
  await page.goto('customers')
  await expect(page.getByTestId('customers-table')).toBeVisible()
  await expectNoAxeViolations(page, `clientes ${label}`)
  await page.goto(`customers?customer=${ids.customer.id}`)
  await expect(page.getByTestId('customer-contact')).toBeVisible()
  await expectNoAxeViolations(page, `cliente ${label}`)
  await page.getByTestId('customer-menu').click()
  await expectNoAxeViolations(page, `menu do cliente ${label}`)
  await page.getByRole('button', { name: 'Editar cliente' }).click()
  await page.getByTestId('customer-form').getByText('Mais dados').click()
  await expectNoAxeViolations(page, `cadastro de cliente ${label}`)
}

async function deviceAndImportScreens(page: Page, label: string, ids: Awaited<ReturnType<typeof seedOne>>) {
  await page.goto(`devices?device=${ids.device.id}`)
  await expect(page.getByTestId('device-detail')).toBeVisible()
  await expect(page.getByTestId('devices-table')).toBeVisible()
  await expectNoAxeViolations(page, `veículos ${label}`)
  await page.getByTestId('maintenance-set').click()
  await expectNoAxeViolations(page, `próxima manutenção ${label}`)
  await page.keyboard.press('Escape')
  await page.getByTestId('device-menu').click()
  await page.getByRole('button', { name: 'Editar', exact: true }).click()
  await expect(page.getByTestId('device-form')).toBeVisible()
  await expectNoAxeViolations(page, `cadastro de veículo ${label}`)
  await page.keyboard.press('Escape')
  await page.goto('customers/import')
  await expectNoAxeViolations(page, `importar ${label}`)
  await page.getByTestId('import-file').setInputFiles({ name: 'c.csv', mimeType: 'text/csv', buffer: Buffer.from('Nome;Telefone\nAna;(48) 3222-3344') })
  await expect(page.getByTestId('import-map')).toBeVisible()
  await expectNoAxeViolations(page, `colunas ${label}`)
  await page.getByTestId('import-continue').click()
  await expect(page.getByTestId('import-review')).toBeVisible()
  await expectNoAxeViolations(page, `prévia ${label}`)
}

// Two tests per theme, inside the 30 s budget (each axe run takes about 1 s on CI).
for (const theme of ['light', 'dark'] as const) {
  const name = theme === 'light' ? 'claro' : 'escuro'
  for (const [part, audit] of [
    ['clientes', customerScreens],
    ['veículos e importação', deviceAndImportScreens],
  ] as const) {
    test(`axe: 0 violações em ${part}, tema ${name}`, async ({ page }) => {
      const ids = await seedOne()
      await page.emulateMedia({ colorScheme: theme })
      await login(page, 'admin', 'login')
      await setTheme(page, theme)
      await audit(page, theme, ids)
    })
  }
}

/** DOM changes in `ms` with nobody touching the page: a screen that keeps rendering shows here. */
async function mutationsWhileIdle(page: Page, ms: number): Promise<number> {
  return page.evaluate(
    (wait) =>
      new Promise<number>((done) => {
        let count = 0
        const observer = new MutationObserver((list) => (count += list.length))
        observer.observe(document.body, { subtree: true, childList: true, attributes: true, characterData: true })
        setTimeout(() => {
          observer.disconnect()
          done(count)
        }, wait)
      }),
    ms,
  )
}

test('nenhuma tela fica renderizando sem parar', async ({ page }) => {
  const ids = await seedOne()
  await login(page, 'admin', 'orders')
  for (const [path, testId] of [
    ['orders', 'orders-table'],
    ['orders?order=scn-owed', 'order-detail'],
    ['customers', 'customers-table'],
    [`customers?customer=${ids.customer.id}`, 'customer-contact'],
    [`devices?device=${ids.device.id}`, 'device-detail'],
    ['customers/import', 'import-file'],
  ] as const) {
    await page.goto(path)
    await expect(page.getByTestId(testId)).toBeAttached()
    // The first reads still land after the content shows (list behind the panel,
    // segment labels, the announcement). A screen that settles has a quiet window
    // within a few seconds; one that keeps rendering never does. (Not networkidle:
    // Firestore's live connection never goes quiet.)
    const windows: number[] = []
    for (let i = 0; i < 6 && windows.at(-1) !== 0; i++) windows.push(await mutationsWhileIdle(page, 700))
    expect(windows.at(-1), `${path} sem parar: ${windows.join(', ')}`).toBe(0)
  }
})

for (const [width, height] of [
  [320, 640],
  [2560, 1440],
] as const) {
  test(`${width} px sem rolagem lateral nas telas de clientes e veículos`, async ({ page }) => {
    const ids = await seedOne()
    await page.setViewportSize({ width, height })
    await login(page, 'admin', 'customers')
    for (const [path, testId] of [
      ['customers', 'customers-table'],
      [`customers?customer=${ids.customer.id}`, 'customer-detail'],
      ['devices', 'devices-table'],
      [`devices?device=${ids.device.id}`, 'device-detail'],
      ['customers/import', 'import-file'],
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
  test(`texto a 200% em ${width} px nas telas de clientes e veículos`, async ({ page }) => {
    const ids = await seedOne()
    await page.setViewportSize({ width, height })
    await login(page, 'admin', 'customers')
    for (const [path, testId] of [
      ['customers', 'customers-table'],
      [`customers?customer=${ids.customer.id}`, 'customer-detail'],
      [`devices?device=${ids.device.id}`, 'device-detail'],
      ['customers/import', 'import-file'],
    ] as const) {
      await page.goto(path)
      await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
      await expect(page.getByTestId(testId)).toBeAttached()
      await expectNoSideScroll(page)
    }
    await page.goto('customers')
    await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await page.getByTestId('new-customer').click()
    const overflow = await page.evaluate(() => {
      const box = document.querySelector('.layer-box') as HTMLElement
      return box.scrollWidth - box.clientWidth
    })
    expect(overflow).toBeLessThanOrEqual(1)
  })
}

for (const [language, title, newCustomer, devices] of [
  ['en', 'Customers', 'New customer', 'Vehicles'],
  ['es', 'Clientes', 'Nuevo cliente', 'Vehículos'],
] as const) {
  test(`idioma ${language}: textos da fatia e rótulo do segmento`, async ({ page }) => {
    await login(page, 'admin', 'customers')
    await page.evaluate((value) => localStorage.setItem('praticos.prefs', JSON.stringify({ language: value })), language)
    await page.reload()
    await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
    await expect(page.getByTestId('new-customer')).toHaveText(newCustomer)
    await expect(page.getByTestId('devices-tab')).toHaveText(devices)
    await page.getByTestId('devices-tab').click()
    await expect(page.getByRole('heading', { level: 1, name: devices })).toBeVisible()
  })
}
