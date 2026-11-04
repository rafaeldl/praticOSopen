// "O que o cliente pediu" on the open order (order.request.edit): the segment's
// field service_order.observation, the same one the app reads and writes. The
// request the old web Nova OS saved as a comment shows while the field is empty.
import { expect, test, type Page } from '@playwright/test'
import { addCommentDoc, makeOrder, readComments, readOrder } from './data'
import { login, type UserKey } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const section = (page: Page) => panel(page).getByTestId('order-request')
const sheet = (page: Page) => page.getByRole('dialog', { name: 'O que o cliente pediu' })
const observation = async (id: string) => ((await readOrder(id))?.customData as { observation?: string } | undefined)?.observation

async function openOrder(page: Page, user: UserKey, id: string) {
  await login(page, user, `orders?order=${id}`)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
}

async function openMenu(page: Page) {
  await panel(page).getByRole('button', { name: 'Mais ações' }).click()
  return page.getByRole('dialog')
}

test('mostra e muda o pedido no campo do ramo, sem mexer nos outros campos (order.request.edit)', async ({ page }) => {
  const order = await makeOrder('admin', { customData: { observation: 'Barulho no motor', mileageIn: 1000 } })
  await openOrder(page, 'admin', order.id)
  await expect(section(page)).toContainText('O que o cliente pediu')
  await expect(section(page)).toContainText('Barulho no motor')
  await section(page).getByRole('button', { name: 'Mudar o que o cliente pediu' }).click()
  await sheet(page).getByLabel('O que o cliente pediu').fill('Barulho no motor\ne luz do óleo acesa')
  await sheet(page).getByRole('button', { name: 'Salvar' }).click()
  await expect(section(page)).toContainText('luz do óleo acesa')
  await expect.poll(() => observation(order.id)).toBe('Barulho no motor\ne luz do óleo acesa')
  expect(((await readOrder(order.id))?.customData as { mileageIn: number }).mileageIn).toBe(1000)
})

test('vazio: escreve pelo menu "…", e o app lê no mesmo campo (order.request.edit)', async ({ page }) => {
  const order = await makeOrder('admin')
  await openOrder(page, 'admin', order.id)
  await expect(section(page)).toHaveCount(0)
  await (await openMenu(page)).getByRole('button', { name: 'Escrever o que o cliente pediu' }).click()
  await sheet(page).getByLabel('O que o cliente pediu').fill('Trocar pastilhas')
  await sheet(page).getByRole('button', { name: 'Salvar' }).click()
  await expect(section(page)).toContainText('Trocar pastilhas')
  await expect.poll(() => observation(order.id)).toBe('Trocar pastilhas')
  // Filled: the menu no longer offers to write it.
  await expect((await openMenu(page)).getByRole('button', { name: 'Escrever o que o cliente pediu' })).toHaveCount(0)
})

test('pedido antigo gravado como comentário aparece; ao mudar vai para o campo e o comentário fica (order.request.edit)', async ({ page }) => {
  const created = new Date()
  const order = await makeOrder('admin', { createdAt: created.toISOString() })
  await addCommentDoc(order.id, {
    text: 'Pedido antigo: freio chiando',
    authorType: 'internal',
    author: { name: 'Admin', email: 'admin@praticos.test', userId: 'e2e-admin' },
    source: 'web',
    isInternal: true,
    createdAt: new Date(created.getTime() + 2000).toISOString(),
  })
  await openOrder(page, 'admin', order.id)
  await expect(section(page)).toContainText('Pedido antigo: freio chiando')
  expect(await observation(order.id)).toBeUndefined()
  await section(page).getByRole('button', { name: 'Mudar o que o cliente pediu' }).click()
  await expect(sheet(page).getByLabel('O que o cliente pediu')).toHaveValue('Pedido antigo: freio chiando')
  await sheet(page).getByLabel('O que o cliente pediu').fill('Freio chiando na frente')
  await sheet(page).getByRole('button', { name: 'Salvar' }).click()
  await expect(section(page)).toContainText('Freio chiando na frente')
  await expect.poll(() => observation(order.id)).toBe('Freio chiando na frente')
  expect((await readComments(order.id)).some((c) => c.text === 'Pedido antigo: freio chiando')).toBe(true)
})

test('técnico muda no orçamento que criou; fora do orçamento só lê; supervisor também (order.request.edit, por papel)', async ({ browser }) => {
  const quote = await makeOrder('technician', { status: 'quote', customData: { observation: 'Revisão' } })
  const approved = await makeOrder('technician', { status: 'approved', customData: { observation: 'Revisão aprovada' } })
  const empty = await makeOrder('admin', { status: 'approved' })

  const techContext = await browser.newContext({ ...test.info().project.use })
  const tech = await techContext.newPage()
  await openOrder(tech, 'technician', quote.id)
  await section(tech).getByRole('button', { name: 'Mudar o que o cliente pediu' }).click()
  await sheet(tech).getByLabel('O que o cliente pediu').fill('Revisão completa')
  await sheet(tech).getByRole('button', { name: 'Salvar' }).click()
  await expect.poll(() => observation(quote.id)).toBe('Revisão completa')
  await tech.goto(`orders?order=${approved.id}`)
  await expect(section(tech)).toContainText('Revisão aprovada')
  await expect(section(tech).getByRole('button', { name: 'Mudar o que o cliente pediu' })).toHaveCount(0)
  await techContext.close()

  const superContext = await browser.newContext({ ...test.info().project.use })
  const supervisor = await superContext.newPage()
  await openOrder(supervisor, 'supervisor', approved.id)
  await expect(section(supervisor)).toContainText('Revisão aprovada')
  await expect(section(supervisor).getByRole('button', { name: 'Mudar o que o cliente pediu' })).toHaveCount(0)
  await supervisor.goto(`orders?order=${empty.id}`)
  await expect(panel(supervisor).getByText('Carregando…')).toHaveCount(0)
  await expect((await openMenu(supervisor)).getByRole('button', { name: 'Escrever o que o cliente pediu' })).toHaveCount(0)
  await superContext.close()
})
