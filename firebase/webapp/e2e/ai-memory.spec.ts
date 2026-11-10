// The assistant corrects what it put itself and remembers what was said
// (issue #631, docs/AI_ORDER_ASSIST.md): the model is simulated with
// page.route, one answer per message, and the test reads what each request sent.
import { expect, test, type Page, type Route } from '@playwright/test'
import { makeOrder } from './data'
import { login } from './helpers'

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const drawer = (page: Page) => page.getByRole('dialog', { name: 'Nova OS' })
const EMPTY = { customer: null, device: null, items: [], changes: [], notes: null, dueDate: null, actions: null, usage: { used: 11, limit: 100 } }

/** The assistant on, answering in order; returns the bodies it received. */
async function assistantOn(page: Page, answers: Record<string, unknown>[]) {
  await page.addInitScript(() => localStorage.setItem('praticos.aiIntroSeen.v1', '1'))
  await page.route(/\/v1\/app\/ai\/status/, (route) => route.fulfill({ json: { success: true, data: { enabled: true, usage: { used: 10, limit: 100 } } } }))
  const bodies: Record<string, unknown>[] = []
  await page.route(/\/v1\/app\/ai\/order-assist/, (route: Route) => {
    bodies.push(JSON.parse(route.request().postData() ?? '{}'))
    return route.fulfill({ json: { success: true, data: { ...EMPTY, ...(answers[bodies.length - 1] ?? {}) } } })
  })
  return bodies
}

async function say(bar: ReturnType<Page['getByTestId']>, text: string, bodies: unknown[], count: number) {
  await bar.getByLabel('Pedir ao assistente').fill(text)
  await bar.getByLabel('Pedir ao assistente').press('Enter')
  await expect.poll(() => bodies.length).toBe(count)
  await expect(bar.getByLabel('Pedir ao assistente')).toBeEnabled()
}

test('Nova OS: corrige a placa e o relato que a IA pôs, manda o histórico e Desfazer volta (#631)', async ({ page }) => {
  const bodies = await assistantOn(page, [
    {
      customer: { match: { id: 'customer-2', name: 'Cliente 02' }, guess: null, alternatives: [] },
      device: { match: null, guess: { name: 'Gol', serial: 'ABC1234' }, alternatives: [] },
      notes: 'Barulho na suspensão',
    },
    { device: { match: null, guess: { name: 'Gol', serial: 'ABC1D23' }, alternatives: [], replaces: 0 }, notes: 'Barulho no freio' },
    { notes: 'Outro relato' },
  ])
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.getByTestId('new-order').click()
  await expect(drawer(page)).toBeVisible()
  const bar = page.getByTestId('new-order-assistant')
  const request = drawer(page).getByLabel(/O que o cliente pediu/)

  await say(bar, 'Gol placa ABC1234, barulho na suspensão', bodies, 1)
  await expect(drawer(page)).toContainText('ABC1234')
  expect(bodies[0]?.history).toBeUndefined()

  await say(bar, 'não, a placa é ABC1D23 e o barulho é no freio', bodies, 2)
  await expect(drawer(page)).toContainText('ABC1D23')
  await expect(drawer(page)).not.toContainText('ABC1234')
  await expect(request).toHaveValue('Barulho no freio')
  expect(bodies[1]?.history).toEqual(['Gol placa ABC1234, barulho na suspensão'])
  expect(JSON.stringify(bodies[1]?.context)).not.toContain('Cliente 02')
  expect(bodies[1]?.context).toMatchObject({
    customer: { chosen: true, fromAi: true },
    devices: [{ name: 'Gol', serial: 'ABC1234', fromAi: true }],
    request: { text: 'Barulho na suspensão', fromAi: true },
  })

  // Desfazer goes back to what the assistant had put before, and forgets the message.
  await page.getByTestId('new-order-assistant-undo').click()
  await expect(drawer(page)).toContainText('ABC1234')
  await expect(request).toHaveValue('Barulho na suspensão')

  // Typed by the person: the assistant no longer touches it.
  await request.fill('Cliente pediu revisão')
  await say(bar, 'o relato é outro', bodies, 3)
  await expect(request).toHaveValue('Cliente pediu revisão')
  expect(bodies[2]?.history).toEqual(['Gol placa ABC1234, barulho na suspensão'])
  expect(bodies[2]?.context).toMatchObject({ request: { text: 'Cliente pediu revisão', fromAi: false } })
})

test('OS aberta: troca o prazo que a IA pôs e manda o contexto sem o nome do cliente (#631)', async ({ page }) => {
  const bodies = await assistantOn(page, [{ dueDate: '2026-12-11' }, { dueDate: '2026-12-14' }, {}])
  const order = await makeOrder('admin', { status: 'approved' })
  await login(page, 'admin', `orders?order=${order.id}`)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  const bar = panel(page).getByTestId('assistant')

  // The context is built from the order the listener shows: wait for the new
  // deadline there before the next message, or it may still carry the old one.
  const due = (day: string) => expect(panel(page).getByRole('button', { name: new RegExp(`^${day}`) })).toBeVisible()
  await say(bar, 'pronto sexta', bodies, 1)
  expect(bodies[0]?.context).toMatchObject({ customer: { chosen: true, fromAi: false } })
  expect(JSON.stringify(bodies[0]?.context)).not.toContain('Cliente 02')
  await due('11/12')
  await say(bar, 'não, o prazo é segunda', bodies, 2)
  expect(bodies[1]?.history).toEqual(['pronto sexta'])
  expect(bodies[1]?.context).toMatchObject({ due: { date: '2026-12-11T18:00', fromAi: true } })
  await due('14/12')
  await say(bar, 'ok', bodies, 3)
  expect(bodies[2]?.history).toEqual(['pronto sexta', 'não, o prazo é segunda'])
  expect(bodies[2]?.context).toMatchObject({ due: { date: '2026-12-14T18:00', fromAi: true } })
})
