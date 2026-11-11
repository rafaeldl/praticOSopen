// Work stages on the board (docs/WORK_STAGES.md): Em andamento split into the
// company's stages, order inside a stage by keyboard and the "…" button, print
// of a stage. Company stages is its own, so no other board test sees it.
import { expect, test } from './test'
import { makeOrder, readOrder } from './data'
import { COMPANY_S } from './fixtures.mjs'
import { login } from './helpers'

const unique = (label: string) => `${label} ${Date.now()}-${Math.round(Math.random() * 1e4)}`
const service = (name: string) => ({ service: { id: name, name, value: 100 }, description: name, value: 100 })

test('etapas no quadro: começar, ordenar, passar adiante e imprimir', async ({ page }) => {
  const a = unique('Capô')
  const b = unique('Porta')
  const c = unique('Lateral')
  const first = await makeOrder('sOwner', { customer: { id: 'customer-s1', name: a }, services: [service('Pintura de capô'), service('Polimento')] }, COMPANY_S)
  // Two already in Pintura, with their places.
  await makeOrder('sOwner', { status: 'progress', stage: { id: 'paint', rank: 10, since: new Date().toISOString() }, customer: { id: 'customer-s2', name: b }, services: [service('Pintura de porta')] }, COMPANY_S)
  await makeOrder('sOwner', { status: 'progress', stage: { id: 'paint', rank: 20, since: new Date().toISOString() }, customer: { id: 'customer-s3', name: c }, services: [service('Pintura lateral'), service('Higienização')], total: 4321 }, COMPANY_S)

  await login(page, 'sOwner', './?view=board')
  const board = page.getByTestId('board')
  await expect(board.getByRole('region')).toHaveText([/^Orçamento/, /^Aprovado/, /^Pintura/, /^Polimento/, /^Concluído/])
  await expect(page.locator('.board-hint')).toContainText('Alt e seta')
  const approved = board.getByRole('region', { name: /^Aprovado/ })
  const paint = board.getByRole('region', { name: /^Pintura/ })
  const polish = board.getByRole('region', { name: /^Polimento/ })
  await expect(approved.locator('li.card').filter({ hasText: a })).toContainText('Próxima: Pintura')

  // "…" → Pintura: starts the order (Em andamento) at the end of the column.
  await approved.getByRole('button', { name: `Mover OS ${first.number}` }).click()
  await page.getByRole('dialog', { name: 'Mover para onde?' }).getByRole('button', { name: 'Pintura' }).click()
  const names = (region: typeof paint) => region.locator('li.card .who')
  await expect(names(paint)).toHaveText([new RegExp(`^1${b}`), new RegExp(`^2${c}`), new RegExp(`^3${a}`)])
  await expect.poll(async () => (await readOrder(first.id, COMPANY_S))?.status).toBe('progress')
  expect(((await readOrder(first.id, COMPANY_S))?.stage as { id: string }).id).toBe('paint')

  // Alt + ↑: one place up, between the two others, and it stays after a reload.
  await paint.locator(`#card-${first.id}`).focus()
  await page.keyboard.press('Alt+ArrowUp')
  await expect(names(paint)).toHaveText([new RegExp(b), new RegExp(a), new RegExp(c)])
  await expect.poll(async () => ((await readOrder(first.id, COMPANY_S))?.stage as { rank: number }).rank).toBe(15)
  await page.reload()
  await expect(names(paint)).toHaveText([new RegExp(b), new RegExp(a), new RegExp(c)])

  // Print of Pintura: the column's order, only its services, no values. It
  // goes to a frame holding only the sheet (Safari printed the page blank).
  await paint.getByRole('button', { name: 'Mais opções de Pintura' }).click()
  await page.getByRole('dialog', { name: 'Pintura' }).getByRole('button', { name: 'Imprimir a lista de Pintura' }).click()
  const sheet = page.frameLocator('[data-testid="print-frame"]').getByTestId('stage-print')
  await expect(sheet.locator('tbody tr')).toHaveCount(3)
  await expect(sheet.locator('tbody tr').nth(2)).toContainText('Pintura lateral')
  await expect(sheet.locator('tbody tr').nth(2)).not.toContainText('Higienização')
  await expect(sheet).not.toContainText('4.321')
  // On paper: black text on a laid-out row, whatever the app's theme.
  for (const colorScheme of ['light', 'dark'] as const) {
    await page.emulateMedia({ media: 'print', colorScheme })
    const ink = await sheet.locator('tbody td').nth(1).evaluate((el) => {
      const box = el.getBoundingClientRect()
      return { color: getComputedStyle(el).color, height: box.height }
    })
    expect(ink.color).toBe('rgb(0, 0, 0)')
    expect(ink.height).toBeGreaterThan(0)
  }
  await page.emulateMedia({ media: 'screen' })

  // Shift + →: to the next stage.
  await paint.locator(`#card-${first.id}`).focus()
  await page.keyboard.press('Shift+ArrowRight')
  await expect(polish.getByText(a)).toBeVisible()
  await expect.poll(async () => ((await readOrder(first.id, COMPANY_S))?.stage as { id: string }).id).toBe('polish')
})

test('consultor vê as etapas, mas não move nem ordena', async ({ page }) => {
  const name = unique('Consulta')
  await makeOrder('sConsultant', { status: 'progress', stage: { id: 'polish', rank: 1, since: new Date().toISOString() }, customer: { id: 'customer-s4', name } }, COMPANY_S)
  await login(page, 'sConsultant', './?view=board')
  const card = page.getByTestId('board').getByRole('region', { name: /^Polimento/ }).locator('li.card').filter({ hasText: name })
  await expect(card).toBeVisible()
  await expect(card).toHaveAttribute('draggable', 'false')
  await expect(card.getByRole('button', { name: /^Mover/ })).toHaveCount(0)
})

test('na OS, clicar na situação mostra as etapas e passa para outra', async ({ page }) => {
  const name = unique('Situação')
  const order = await makeOrder('sOwner', { status: 'progress', stage: { id: 'paint', rank: 1, since: new Date().toISOString() }, customer: { id: 'customer-s5', name } }, COMPANY_S)
  await login(page, 'sOwner', `orders?order=${order.id}`)
  const panel = page.getByRole('complementary', { name: 'OS aberta' })
  const button = panel.getByTestId('order-status-button')
  await expect(button).toHaveText(/ · Pintura$/)

  await button.click()
  const picker = page.getByRole('dialog', { name: 'Qual a situação?' })
  await expect(picker.getByRole('button', { name: / · Polimento$/ })).toBeVisible()
  await picker.getByRole('button', { name: / · Polimento$/ }).click()

  await expect(button).toHaveText(/ · Polimento$/)
  await expect.poll(async () => ((await readOrder(order.id, COMPANY_S))?.stage as { id: string }).id).toBe('polish')
})
