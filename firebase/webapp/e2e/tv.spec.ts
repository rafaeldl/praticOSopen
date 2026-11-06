// Modo TV (#627): the board alone, big, live and without values.
import { expect, test } from '@playwright/test'
import { makeOrder, readOrder, updateOrderDoc, writeOrderFieldsRaw } from './data'
import { login } from './helpers'

const unique = (prefix: string) => `${prefix} ${Date.now()}-${Math.round(Math.random() * 1e4)}`

test('abre pelo quadro, sem valores, e acompanha as mudanças sozinho', async ({ page }) => {
  const name = unique('TV')
  const order = await makeOrder('admin', { status: 'approved', customer: { id: 'customer-1', name }, total: 4321 })
  await login(page, 'admin', './?view=board')
  await page.getByTestId('open-tv').click()
  await expect(page).toHaveURL(/\/tv$/)
  const tv = page.getByTestId('tv')
  // No menu of the app: only the board.
  await expect(page.getByRole('navigation')).toHaveCount(0)
  await expect(page.getByTestId('tv-col-approved').getByText(name)).toBeVisible()
  await expect(tv).not.toContainText('R$')
  // Changed somewhere else: the card moves without reloading.
  await updateOrderDoc(order.id, { status: 'progress' })
  await expect(page.getByTestId('tv-col-progress').getByText(name)).toBeVisible()
  await expect(page.getByTestId('tv-col-approved').getByText(name)).toHaveCount(0)
  // Done now: in "Concluídas hoje".
  await updateOrderDoc(order.id, { status: 'done', completedAt: new Date().toISOString() })
  await expect(page.getByTestId('tv-col-done').getByText(name)).toBeVisible()
  await expect(page.getByTestId('tv-col-done')).toContainText('Concluídas hoje')
  // "Sair" goes back to the board.
  await page.getByTestId('tv-exit').click()
  await expect(page).toHaveURL(/view=board/)
})

test('concluída antes de hoje não aparece', async ({ page }) => {
  const name = unique('Ontem')
  // The server stamps completedAt when the order becomes done; wait for it, then make it 3 days old.
  const order = await makeOrder('admin', { status: 'approved', customer: { id: 'customer-1', name } })
  await updateOrderDoc(order.id, { status: 'done' })
  await expect.poll(async () => (await readOrder(order.id))?.completedAt, { timeout: 15_000 }).toBeTruthy()
  await writeOrderFieldsRaw(order.id, { completedAt: new Date(Date.now() - 3 * 86_400_000).toISOString() })
  await login(page, 'admin', 'tv')
  await expect(page.getByTestId('tv-col-quote')).toBeVisible()
  await expect(page.getByTestId('tv-col-approved').locator('li').first()).toBeVisible()
  await expect(page.getByTestId('tv-col-done').getByText(name)).toHaveCount(0)
})

test('quem não vê valores também usa (pela API)', async ({ page }) => {
  await login(page, 'supervisor', 'tv')
  await expect(page.getByTestId('tv-col-approved').locator('li').first()).toBeVisible()
  await expect(page.getByTestId('tv')).not.toContainText('R$')
})

test('só para quem vê todas as OS', async ({ page }) => {
  await login(page, 'technician', 'tv')
  await expect(page).toHaveURL(/forbidden/)
})
