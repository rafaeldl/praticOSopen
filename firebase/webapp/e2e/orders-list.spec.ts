// Início: list, filters, rows, search, selection, board and live updates.
// Seeded scenario orders (seed.mjs seedScenario) give the late, today, on hold,
// owed and old quote rows; tests that write make their own orders (data.ts).
import { expect, test, type Page } from '@playwright/test'
import { makeOrder, updateOrderDoc } from './data'
import { chooseCompany, login, type UserKey } from './helpers'

const table = (page: Page) => page.getByTestId('orders-table')
const row = (page: Page, number: number) => table(page).locator('tbody tr').filter({ has: page.locator('.c-num', { hasText: new RegExp(`^${number}$`) }) })

async function openHome(page: Page, user: UserKey, path = './') {
  await login(page, user, path)
  if (user === 'owner') await chooseCompany(page, 'Oficina Alfa')
  await expect(page.getByRole('heading', { level: 1, name: /Início|Ordens de Serviço/ })).toBeVisible()
}

test.describe('lista por papel (home.list.load, home.view.default-technician)', () => {
  const cases: { user: UserKey; filter: string; money: boolean; sees: number[]; hides: number[] }[] = [
    { user: 'owner', filter: 'Em aberto', money: true, sees: [501, 502, 503], hides: [504] },
    { user: 'admin', filter: 'Em aberto', money: true, sees: [501, 502, 503, 506], hides: [504] },
    { user: 'manager', filter: 'Em aberto', money: true, sees: [501, 502], hides: [504] },
    // Supervisor does not see values: API projection, no money column.
    { user: 'supervisor', filter: 'Em aberto', money: false, sees: [501, 506], hides: [504] },
    // Consultant reads only what they created (rules and API).
    { user: 'consultant', filter: 'Em aberto', money: true, sees: [505], hides: [501, 506] },
    // Technician: "Minhas" by default: assigned to them, created by anyone (508 is the admin's).
    { user: 'technician', filter: 'Minhas', money: false, sees: [506, 508], hides: [507, 501] },
  ]
  for (const { user, filter, money, sees, hides } of cases) {
    test(`${user}: abre em ${filter}`, async ({ page }) => {
      await openHome(page, user)
      await expect(page.getByRole('button', { name: filter, pressed: true })).toBeVisible()
      await expect(table(page)).toBeVisible()
      for (const number of sees) await expect(row(page, number)).toHaveCount(1)
      for (const number of hides) await expect(row(page, number)).toHaveCount(0)
      await expect(table(page).getByRole('columnheader', { name: 'Total' })).toHaveCount(money ? 1 : 0)
      await expect(table(page).locator('td.c-money').first()).toHaveCount(money ? 1 : 0)
    })
  }
})

test('linha: atraso, visita, entrega, parada e valor (home.row.*)', async ({ page }) => {
  await openHome(page, 'admin')
  await expect(row(page, 501)).toContainText('Atrasada 3 dias')
  await expect(row(page, 501).locator('.dot--danger')).toHaveCount(1)
  // The plate after the device (P3 17 of the user tests of #515).
  await expect(row(page, 501)).toContainText('Veículo 3 · TST0003 · Serviço 2')
  // Wide screen: "Quando" is a column; the status column keeps only the status.
  await expect(table(page).getByRole('columnheader', { name: 'Quando' })).toBeVisible()
  await expect(row(page, 502).getByTestId('row-when')).toHaveText(/^Entrega (hoje|amanhã|\d{2}\/\d{2})/)
  await expect(row(page, 502)).not.toContainText('Na oficina · entrega')
  await expect(row(page, 501).getByTestId('row-when')).toHaveClass(/c-when/)
  await expect(row(page, 501).getByTestId('row-when').locator('.is-late')).toHaveCount(1)
  await expect(row(page, 503)).toContainText('Esperando peça · Parada há 2 dias')
  await expect(row(page, 506).getByTestId('row-when')).toHaveText(/^Visita /)
  await expect(row(page, 501).locator('td.c-money')).toHaveText('R$ 100,00')
  // Late first, then today (home.rules.groups).
  const numbers = await table(page).locator('tbody td.c-num').allTextContents()
  expect(numbers.indexOf('501')).toBeLessThan(numbers.indexOf('502'))
  expect(numbers.indexOf('502')).toBeLessThan(numbers.indexOf('503'))
  // Once the whole open list is loaded, the sentence answers the screen (home.summary.count).
  await loadAll(page)
  await expect(page.getByTestId('summary')).toHaveText(/\d+ em aberto · 1 atrasada/)
})

test('tela estreita: sem a coluna Quando, as datas voltam à linha da situação (home.row.status-line)', async ({ page }) => {
  await page.setViewportSize({ width: 900, height: 800 })
  await openHome(page, 'admin')
  await expect(table(page).getByRole('columnheader', { name: 'Quando' })).toHaveCount(0)
  await expect(row(page, 502)).toContainText(/Na oficina · entrega \d{2}\/\d{2}/)
  await expect(row(page, 506)).toContainText(/visita \d{2}\/\d{2}/)
})

async function loadAll(page: Page) {
  const more = page.getByRole('button', { name: 'Mostrar mais' })
  for (let i = 0; i < 20 && (await more.count()); i++) {
    // The infinite scroll can load the last page and take the button away between count and click.
    await more.click({ timeout: 3000 }).catch(() => {})
    await page.waitForTimeout(300)
  }
}

test('filtros do app: orçamentos, paradas, concluídas e todas por mês (home.filter.*)', async ({ page }) => {
  await openHome(page, 'admin')
  await page.getByRole('button', { name: 'Orçamentos' }).click()
  await expect(page).toHaveURL(/f=quotes/)
  await expect(row(page, 505)).toHaveCount(1)
  await expect(row(page, 501)).toHaveCount(0)
  await loadAll(page)
  await expect(page.getByTestId('summary')).toHaveText(/orçamentos? sem resposta/)

  await page.getByRole('button', { name: 'Paradas' }).click()
  await expect(row(page, 503)).toHaveCount(1)
  await expect(table(page).locator('tbody tr')).toHaveCount(1)
  await expect(page.getByTestId('summary')).toHaveText('1 parada')

  await page.getByRole('button', { name: 'Concluídas' }).click()
  await expect(row(page, 504)).toContainText('falta receber R$ 200,00')
  await expect(row(page, 501)).toHaveCount(0)

  await page.getByRole('button', { name: 'Todas' }).click()
  await expect(table(page).getByRole('rowheader', { name: /^\w+ de 20\d\d$/i }).first()).toBeVisible()
  // A shared link keeps the filter.
  await page.reload()
  await expect(page.getByRole('button', { name: 'Todas', pressed: true })).toBeVisible()
})

test('vazio de cada filtro, com Ver todas (home.empty.views)', async ({ page }) => {
  await openHome(page, 'technician')
  await page.getByRole('button', { name: 'Paradas' }).click()
  await expect(page.getByRole('heading', { name: 'Nenhum serviço parado.' })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Ver todas' })).toHaveCount(0)
})

test('busca por número, cliente, situação e placa, sem acento (home.search.run)', async ({ page }) => {
  await openHome(page, 'admin')
  const search = page.getByRole('searchbox', { name: /Buscar OS, cliente ou veículo/ })
  await page.keyboard.press('/')
  await expect(search).toBeFocused()
  await search.fill('tst0003')
  await expect(row(page, 501)).toHaveCount(1)
  await expect(row(page, 502)).toHaveCount(0)
  await search.fill('na oficina')
  await expect(row(page, 502)).toHaveCount(1)
  await expect(page).toHaveURL(/q=na/)
  await search.fill('zzzz')
  await expect(page.getByRole('heading', { name: 'Nada com “zzzz”' })).toBeVisible()
  await page.getByRole('button', { name: 'Limpar a busca' }).click()
  await expect(table(page)).toBeVisible()
})

test('mais OS ao chegar no fim (home.list.load-more)', async ({ page }) => {
  await openHome(page, 'admin', './?f=all')
  await expect(table(page).locator('tbody tr[data-order]')).toHaveCount(30)
  // Reaching the end of the list brings the next page by itself.
  await page.locator('.more-rows').scrollIntoViewIfNeeded()
  await expect.poll(() => table(page).locator('tbody tr[data-order]').count()).toBeGreaterThan(30)
})

test('abrir a OS pela linha e andar com J/K (home.list.open-order)', async ({ page }) => {
  await openHome(page, 'admin')
  await row(page, 501).getByRole('button', { name: 'Cliente 03' }).click()
  const panel = page.getByRole('complementary', { name: 'OS aberta' })
  await expect(panel).toBeVisible()
  await expect(panel.getByRole('heading', { level: 2 })).toHaveText('Cliente 03')
  await page.locator('h1').click()
  await page.keyboard.press('j')
  await expect(panel.getByRole('heading', { level: 2 })).not.toHaveText('Cliente 03')
  await page.keyboard.press('k')
  await expect(panel.getByRole('heading', { level: 2 })).toHaveText('Cliente 03')
  await page.keyboard.press('Escape')
  await expect(panel).toHaveCount(0)
})

test('outra pessoa muda a OS e a linha atualiza sem recarregar (home.list.reload-on-return)', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved' })
  await openHome(page, 'admin')
  await expect(row(page, order.number)).toContainText('Aprovado')
  await table(page).evaluate((element) => ((element as HTMLElement).dataset.marker = 'same'))
  // Another device saves: the row follows, the table is the same element (no reload).
  await updateOrderDoc(order.id, { status: 'progress' })
  await expect(row(page, order.number)).toContainText('Na oficina')
  await expect(table(page)).toHaveAttribute('data-marker', 'same')
})

test('lote: mudar a situação de duas OS de uma vez', async ({ page }) => {
  const a = await makeOrder('admin', { status: 'approved' })
  const b = await makeOrder('admin', { status: 'approved' })
  await openHome(page, 'admin')
  await row(page, a.number).getByRole('checkbox').check()
  await row(page, b.number).getByRole('checkbox').check()
  const batch = page.getByRole('region', { name: 'Ações nas OS selecionadas' })
  await expect(batch).toContainText('2 selecionadas')
  await batch.getByRole('button', { name: 'Mudar a situação' }).click()
  await page.getByRole('dialog', { name: 'Qual a situação?' }).getByRole('button', { name: 'Na oficina' }).click()
  // Asks first, with the count (home.batch.status).
  await page.getByRole('dialog', { name: 'Mudar 2 OS para Na oficina?' }).getByRole('button', { name: 'Mudar 2 OS' }).click()
  await expect(page.locator('.toast')).toContainText('2 atualizadas')
  await expect(row(page, a.number)).toContainText('Na oficina')
  await expect(row(page, b.number)).toContainText('Na oficina')
})

test('quadro como aba da lista: mover pelo botão e por Shift+seta', async ({ page }) => {
  const order = await makeOrder('admin', { status: 'approved', customer: { id: 'customer-1', name: 'Quadro Teste' } })
  await openHome(page, 'admin')
  await page.getByRole('button', { name: 'Quadro', exact: true }).click()
  await expect(page).toHaveURL(/view=board/)
  const board = page.getByTestId('board')
  const approved = board.getByRole('region', { name: /^Aprovado/ })
  await expect(approved.getByText('Quadro Teste')).toBeVisible()
  await approved.getByRole('button', { name: `Mover OS ${order.number}` }).click()
  await page.getByRole('dialog', { name: 'Mover para onde?' }).getByRole('button', { name: 'Na oficina' }).click()
  const progress = board.getByRole('region', { name: /^Na oficina/ })
  await expect(progress.getByText('Quadro Teste')).toBeVisible()
  await progress.locator(`#card-${order.id}`).focus()
  await page.keyboard.press('Shift+ArrowRight')
  await expect(board.getByRole('region', { name: /^Concluído/ }).getByText('Quadro Teste')).toBeVisible()
})

test('idiomas: filtros em inglês e espanhol, moeda continua do Brasil', async ({ page }) => {
  await login(page, 'admin', 'settings')
  await page.getByLabel('Idioma').selectOption('en')
  await page.goto('./')
  await expect(page.getByRole('button', { name: 'Open', pressed: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Quotes' })).toBeVisible()
  await expect(row(page, 501)).toContainText('R$ 100,00')
  await expect(row(page, 501)).toContainText('Overdue 3 days')
  await page.goto('settings')
  await page.getByLabel('Language').selectOption('es')
  await page.goto('./')
  await expect(page.getByRole('button', { name: 'Abiertas', pressed: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'En espera' })).toBeVisible()
})
