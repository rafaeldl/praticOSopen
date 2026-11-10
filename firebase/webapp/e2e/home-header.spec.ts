// Head of Início (home.header.*): the bell, Lista | Quadro and Nova OS stay on one
// row, at the same place in both views, with or without text in the search; the
// search is also on the board and asks the server (number, customer, vehicle),
// so an order far from the loaded pages shows. Company paging (seed.mjs
// seedPaging): order 900, of Zeca Antiguidades with the Fusca OLD1970, is the
// oldest of 140, out of what the board loads.
import { expect, test, type Page } from './test'
import { expectNoSideScroll, login, type UserKey } from './helpers'

type Box = { x: number; y: number; width: number; height: number }
const box = async (page: Page, selector: string): Promise<Box> => {
  const found = await page.locator(selector).first().boundingBox()
  expect(found, selector).not.toBeNull()
  return found as Box
}

/** Bell, Lista | Quadro and Nova OS (when shown) of the head. */
async function controls(page: Page, withNew = true) {
  const result: Record<string, Box> = {
    bell: await box(page, '[data-testid="bell"]'),
    tabs: await box(page, '.page-head .tabs'),
  }
  if (withNew) result.newOrder = await box(page, '[data-testid="new-order"]')
  return result
}

function expectSameRow(boxes: Record<string, Box>) {
  const tops = Object.values(boxes).map((b) => Math.round(b.y))
  const centers = Object.values(boxes).map((b) => Math.round(b.y + b.height / 2))
  expect(Math.max(...tops) - Math.min(...tops), `topo ${tops}`).toBeLessThanOrEqual(1)
  expect(Math.max(...centers) - Math.min(...centers), `centro ${centers}`).toBeLessThanOrEqual(1)
}

function expectSamePlace(a: Record<string, Box>, b: Record<string, Box>) {
  for (const key of Object.keys(a)) {
    expect(Math.abs((a[key] as Box).x - (b[key] as Box).x), `${key} x`).toBeLessThanOrEqual(1)
    expect(Math.abs((a[key] as Box).y - (b[key] as Box).y), `${key} y`).toBeLessThanOrEqual(1)
  }
}

const search = (page: Page) => page.locator('#orders-search')
const board = (page: Page) => page.getByTestId('board')
const card = (page: Page, number: number) => board(page).locator('.card').filter({ has: page.locator('.card-top .num', { hasText: new RegExp(`^${number}$`) }) })

async function openHome(page: Page, user: UserKey, path = './') {
  await login(page, user, path)
  await expect(page.getByRole('heading', { level: 1, name: /Início|Ordens de Serviço/ })).toBeVisible()
}

for (const width of [1280, 1366, 1920]) {
  test(`${width} px: sino, Lista | Quadro e Nova OS na mesma linha e no mesmo lugar nas duas vistas, com e sem busca`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 })
    await openHome(page, 'admin')
    await expect(page.getByTestId('orders-table')).toBeVisible()
    const list = await controls(page)
    expectSameRow(list)

    await search(page).fill('Cliente 03')
    await expect(page).toHaveURL(/q=Cliente/)
    const listSearching = await controls(page)
    expectSamePlace(list, listSearching)
    const searchOnList = await box(page, '#orders-search')

    await page.getByRole('button', { name: 'Quadro' }).click()
    await expect(board(page)).toBeVisible()
    const boardSearching = await controls(page)
    expectSameRow(boardSearching)
    expectSamePlace(list, boardSearching)
    // The search keeps its text and its place.
    await expect(search(page)).toHaveValue('Cliente 03')
    const searchOnBoard = await box(page, '#orders-search')
    expect(Math.abs(searchOnBoard.x - searchOnList.x)).toBeLessThanOrEqual(1)
    expect(Math.abs(searchOnBoard.y - searchOnList.y)).toBeLessThanOrEqual(1)

    await search(page).fill('')
    await expect(board(page)).toBeVisible()
    expectSamePlace(list, await controls(page))

    // Nova OS is the yellow main button in both views while no order is open beside them.
    await expect(page.getByTestId('new-order')).toHaveClass(/btn--primary/)
    const yellow = await page.getByTestId('new-order').evaluate((element) => getComputedStyle(element).backgroundColor)
    const marker = await page.evaluate(() => {
      const probe = document.createElement('div')
      probe.style.background = 'var(--color-marker)'
      document.body.append(probe)
      const color = getComputedStyle(probe).backgroundColor
      probe.remove()
      return color
    })
    expect(yellow).toBe(marker)
    await page.getByRole('button', { name: 'Lista' }).click()
    await expect(page.getByTestId('new-order')).toHaveClass(/btn--primary/)
  })
}

test('Nova OS fica secundário só com uma OS aberta ao lado (um botão amarelo por tela)', async ({ page }) => {
  await page.setViewportSize({ width: 1366, height: 900 })
  await openHome(page, 'admin')
  await page.getByTestId('orders-table').locator('tbody tr .row-btn').first().click()
  await expect(page.locator('aside.panel')).toBeVisible()
  await expect(page.getByTestId('new-order')).not.toHaveClass(/btn--primary/)
  await page.locator('aside.panel').getByRole('button', { name: 'Fechar' }).first().click()
  await expect(page.locator('aside.panel')).toHaveCount(0)
  await expect(page.getByTestId('new-order')).toHaveClass(/btn--primary/)
})

test('celular (375 px): sino e Lista | Quadro no mesmo lugar nas duas vistas', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 })
  await openHome(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  const list = await controls(page, false)
  expectSameRow(list)
  await search(page).fill('Cliente 03')
  expectSamePlace(list, await controls(page, false))
  await page.getByRole('button', { name: 'Quadro' }).click()
  await expect(board(page)).toBeVisible()
  expectSamePlace(list, await controls(page, false))
  await expect(search(page)).toBeVisible()
  await expectNoSideScroll(page, ['.board-wrap', '.board'])
})

test('320 px, texto a 200%: cabeçalho e busca sem rolagem lateral nas duas vistas', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await openHome(page, 'admin')
  await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
  await expect(search(page)).toBeVisible()
  await expectNoSideScroll(page)
  await page.getByRole('button', { name: 'Quadro' }).click()
  await expect(board(page)).toBeVisible()
  await expect(search(page)).toBeVisible()
  await expectNoSideScroll(page, ['.board-wrap', '.board'])
})

test('busca no Quadro: número, cliente e veículo vêm do servidor e só ficam os achados', async ({ page }) => {
  await page.setViewportSize({ width: 1366, height: 900 })
  await openHome(page, 'pOwner', './?view=board')
  await expect(board(page)).toBeVisible()
  // The board reads every open order: 900, the oldest of all, is there too.
  await expect(card(page, 101)).toHaveCount(1)
  await expect(card(page, 900)).toHaveCount(1)

  for (const text of ['Zeca', 'OLD1970', 'fusca', '900']) {
    await search(page).fill(text)
    await expect(card(page, 900)).toHaveCount(1)
    // Only what the search found: the other cards leave the columns.
    await expect(board(page).locator('.card')).toHaveCount(1)
    await expect(board(page).locator('.col').filter({ has: page.getByRole('heading', { name: /Na oficina/ }) }).locator('.card')).toHaveCount(1)
  }
  await search(page).fill('Ninguém Com Esse Nome')
  await expect(page.getByTestId('board-no-match')).toBeVisible()
  await search(page).fill('')
  await expect(card(page, 900)).toHaveCount(1)
  await expect(card(page, 101)).toHaveCount(1)
})

test('busca na Lista: a OS fora da primeira página aparece pelo cliente', async ({ page }) => {
  await openHome(page, 'pOwner', './?f=all')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await search(page).fill('Zeca')
  await expect(page.getByTestId('orders-table').locator('tbody tr').filter({ hasText: 'Zeca Antiguidades' })).toHaveCount(1)
})

test('papéis: o técnico não acha no Quadro a OS que não é dele; o supervisor (pela API) acha pelo cliente', async ({ page, browser }) => {
  await openHome(page, 'pTech', './?view=board')
  await expect(board(page)).toBeVisible()
  await search(page).fill('Zeca')
  await expect(page.getByTestId('board-no-match')).toBeVisible()
  await expect(card(page, 900)).toHaveCount(0)

  const context = await browser.newContext({ baseURL: test.info().project.use.baseURL, locale: 'pt-BR', timezoneId: 'America/Sao_Paulo' })
  const other = await context.newPage()
  await openHome(other, 'pSuper', './?view=board')
  await expect(board(other)).toBeVisible()
  await search(other).fill('Zeca')
  await expect(card(other, 900)).toHaveCount(1)
  await context.close()
})
