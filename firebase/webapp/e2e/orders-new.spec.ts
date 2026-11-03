// Nova OS (order.new.*, order.route.new): keyboard only, timed, per role.
import { expect, test, type Page } from '@playwright/test'
import { readOrder } from './data'
import { chooseCompany, login, type UserKey } from './helpers'

const drawer = (page: Page) => page.getByRole('dialog', { name: 'Nova OS' })
const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })

async function home(page: Page, user: UserKey) {
  await login(page, user)
  if (user === 'owner') await chooseCompany(page, 'Oficina Alfa')
  await expect(page.getByTestId('orders-table')).toBeVisible()
}

/** The id of the order on the panel after saving (the URL carries it). */
async function savedId(page: Page): Promise<string> {
  await expect(page).toHaveURL(/order=/)
  return new URL(page.url()).searchParams.get('order') as string
}

test('Nova OS só com teclado: cliente, veículo, item e valor em menos de 45 s', async ({ page }) => {
  await home(page, 'admin')
  await page.locator('h1').click()
  const started = Date.now()
  await page.keyboard.press('n')
  await expect(drawer(page)).toBeVisible()
  await expect(page.getByRole('combobox', { name: 'Cliente' })).toBeFocused()
  await page.keyboard.type('Cliente 03')
  await page.keyboard.press('Enter')
  // The customer's only vehicle comes in by itself; otherwise Enter takes the suggestion.
  const item = page.getByRole('combobox', { name: 'O que vai ser feito?' })
  const focused = () => page.evaluate(() => document.activeElement?.id ?? '')
  await expect.poll(focused).toMatch(/^no-(device|item)$/)
  if ((await focused()) === 'no-device') await page.keyboard.press('Enter')
  await expect(item).toBeFocused()
  await page.keyboard.type('Serviço 2')
  await page.keyboard.press('Enter')
  await page.keyboard.press('Tab')
  await expect(page.getByRole('textbox', { name: 'Valor de Serviço 2' })).toBeFocused()
  await page.keyboard.type('180')
  await page.keyboard.press('ControlOrMeta+Enter')
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByRole('heading', { level: 2 })).toHaveText('Cliente 03')
  const elapsed = Date.now() - started
  console.log(`Nova OS por teclado: ${elapsed} ms`)
  expect(elapsed).toBeLessThan(45_000)

  const saved = await readOrder(await savedId(page))
  expect(saved?.customer).toMatchObject({ id: 'customer-3' })
  expect((saved?.device as { id: string }).id).toBe('device-3')
  expect(saved?.total).toBe(180)
  expect((saved?.services as { value: number }[])[0]?.value).toBe(180)
  await expect(panel(page).getByTestId('order-totals')).toContainText('R$ 180,00')
})

for (const user of ['owner', 'supervisor', 'consultant'] as const) {
  test(`${user} cria OS pelo botão, com o pedido do cliente`, async ({ page }) => {
    await home(page, user)
    await page.getByTestId('new-order').click()
    await page.getByRole('combobox', { name: 'Cliente' }).fill('Cliente 01')
    await expect(page.getByRole('option', { name: /^Cliente 01/ })).toBeVisible()
    await page.keyboard.press('Enter')
    await expect(drawer(page).getByRole('button', { name: 'Trocar' }).first()).toBeVisible()
    await page.getByRole('combobox', { name: 'O que vai ser feito?' }).fill('Peça 1')
    await expect(page.getByRole('option', { name: /^Peça 1/ })).toBeVisible()
    await page.keyboard.press('Enter')
    await expect(drawer(page).getByRole('list', { name: 'O que vai ser feito' })).toContainText('Peça 1')
    // Who does not see values never sees a price here.
    if (user === 'supervisor') await expect(drawer(page).getByText('R$')).toHaveCount(0)
    else await expect(drawer(page).getByText('R$').first()).toBeVisible()
    await drawer(page).getByLabel('O que o cliente pediu').fill('Barulho ao frear')
    await page.getByTestId('save-order').click()
    await expect(page.locator('.toast')).toContainText(/OS \d+ criada/)
    const id = await savedId(page)
    await expect(panel(page)).toContainText('Cliente 01')
    await expect(panel(page).getByTestId('comments')).toContainText('Barulho ao frear')
    const saved = await readOrder(id)
    expect((saved?.createdBy as { id: string }).id).toBe(`e2e-${user}`)
    expect((saved?.products as unknown[]).length).toBe(1)
  })
}

test('consultor só escolhe orçamento ou aprovada; nunca cancelada (order.new.status-pick)', async ({ page }) => {
  await home(page, 'consultant')
  await page.getByTestId('new-order').click()
  await drawer(page).getByText('Mais opções').click()
  const options = await drawer(page).getByLabel('Situação').locator('option').allTextContents()
  expect(options).toEqual(['Orçamento', 'Aprovado'])
})

for (const user of ['technician', 'manager'] as const) {
  test(`${user} não cria OS: sem botão e N não abre (order.route.new)`, async ({ page }) => {
    await login(page, user)
    await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
    await expect(page.getByTestId('new-order')).toHaveCount(0)
    await page.locator('h1').click()
    await page.keyboard.press('n')
    await expect(drawer(page)).toHaveCount(0)
  })
}

test('salvar sem cliente diz o que falta; sair com algo preenchido pergunta (order.new.save, order.new.discard)', async ({ page }) => {
  await home(page, 'admin')
  await page.getByTestId('new-order').click()
  await page.getByRole('combobox', { name: 'O que vai ser feito?' }).fill('Serviço 1')
  await page.keyboard.press('Enter')
  // The line is on screen (on a slow runner the catalog may still be loading: the Enter waits for it).
  await expect(drawer(page).getByRole('list', { name: 'O que vai ser feito' })).toContainText('Serviço 1')
  await page.keyboard.press('ControlOrMeta+Enter')
  await expect(drawer(page).getByRole('alert')).toHaveText('Escolha o cliente para salvar.')
  await expect(page.getByRole('combobox', { name: 'Cliente' })).toBeFocused()
  // Esc with an item: asks, and "Cancelar" keeps it open.
  page.once('dialog', (dialog) => dialog.dismiss())
  await page.keyboard.press('Escape')
  await page.keyboard.press('Escape')
  await expect(drawer(page)).toBeVisible()
  // The browser's Voltar asks too.
  page.once('dialog', (dialog) => dialog.accept())
  await page.goBack()
  await expect(drawer(page)).toHaveCount(0)
  // Nothing filled: closes without asking.
  await page.getByTestId('new-order').click()
  await expect(drawer(page)).toBeVisible()
  await drawer(page).getByRole('button', { name: 'Fechar' }).click()
  await expect(drawer(page)).toHaveCount(0)
})

test('Nova OS em inglês e espanhol, com o rótulo do ramo', async ({ page }) => {
  await login(page, 'admin', 'settings')
  await page.getByLabel('Idioma').selectOption('en')
  await page.goto('./')
  await page.getByTestId('new-order').click()
  const english = page.getByRole('dialog', { name: 'New WO' })
  await expect(english).toBeVisible()
  await page.getByRole('combobox', { name: 'Customer' }).fill('Cliente 03')
  await page.keyboard.press('Enter')
  await expect(english).toContainText('Vehicle')
  page.once('dialog', (dialog) => dialog.accept())
  await english.getByRole('button', { name: 'Close' }).click()
  await expect(english).toHaveCount(0)
  await page.goto('settings')
  await page.getByLabel('Language').selectOption('es')
  await page.goto('./')
  await page.getByTestId('new-order').click()
  await expect(page.getByRole('dialog', { name: 'Nueva OS' })).toContainText('¿Qué se va a hacer?')
})
