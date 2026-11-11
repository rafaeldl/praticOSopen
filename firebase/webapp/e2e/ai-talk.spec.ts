// Falar no assistente (order.ai.talk, .cancel-talk, .stop-fill, .speech-engine,
// order.new.assistant-bar): Chromium's fake microphone records, the model is
// simulated with page.route, and the test checks the audio went in the body.
import { expect, test, type Page, type Route } from './test'
import { makeOrder } from './data'
import { login } from './helpers'

test.use({
  launchOptions: { args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'] },
  permissions: ['microphone'],
})

const panel = (page: Page) => page.getByRole('complementary', { name: 'OS aberta' })
const drawer = (page: Page) => page.getByRole('dialog', { name: 'Nova OS' })

/** The assistant on; returns the bodies it received. */
async function assistantOn(page: Page, answer: Record<string, unknown> = {}) {
  await page.addInitScript(() => localStorage.setItem('praticos.aiIntroSeen.v1', '1'))
  await page.route(/\/v1\/app\/ai\/status/, (route) => route.fulfill({ json: { success: true, data: { enabled: true, usage: { used: 10, limit: 100 } } } }))
  const bodies: Record<string, unknown>[] = []
  await page.route(/\/v1\/app\/ai\/order-assist/, (route: Route) => {
    bodies.push(JSON.parse(route.request().postData() ?? '{}'))
    return route.fulfill({
      json: { success: true, data: { customer: null, device: null, items: [], changes: [], notes: null, dueDate: null, actions: null, transcript: 'serviço 3', usage: { used: 11, limit: 100 }, ...answer } },
    })
  })
  return bodies
}

const SERVICE_3 = { items: [{ kind: 'service', name: 'Serviço 3', value: 150, quantity: 1, catalogId: 'service-3', description: null, alternatives: [] }] }

async function openOrder(page: Page) {
  const order = await makeOrder('admin', { status: 'approved' })
  await login(page, 'admin', `orders?order=${order.id}`)
  await expect(panel(page)).toBeVisible()
  await expect(panel(page).getByText('Carregando…')).toHaveCount(0)
  return panel(page).getByTestId('assistant')
}

/** Falar, wait until the microphone heard something, then "Parar e preencher". */
async function speak(bar: ReturnType<Page['getByTestId']>) {
  await bar.getByRole('button', { name: 'Falar' }).click()
  const listening = bar.getByTestId('assistant-listening')
  await expect(listening).toContainText('Ouvindo…')
  await expect(listening.locator('[data-heard="true"]')).toBeVisible()
  await expect(bar.getByLabel('Pedir ao assistente')).toBeHidden()
  await listening.getByRole('button', { name: 'Parar e preencher a OS' }).click()
}

function expectAudio(body: Record<string, unknown> | undefined) {
  const audio = body?.audio as { mimeType: string; data: string } | undefined
  expect(audio?.mimeType).toBe('audio/webm')
  expect(audio?.data.length).toBeGreaterThan(100)
  expect(audio?.data).toMatch(/^[A-Za-z0-9+/]+={0,2}$/)
  expect(body?.text).toBeUndefined()
}

test('OS aberta: Falar, Parar e preencher manda o áudio e põe na OS com ✦ e Desfazer (order.ai.talk, order.ai.stop-fill, order.ai.speech-engine)', async ({ page }) => {
  const bodies = await assistantOn(page, SERVICE_3)
  const bar = await openOrder(page)
  await speak(bar)
  const line = panel(page).getByTestId('order-line').filter({ hasText: 'Serviço 3' })
  await expect(line).toContainText('✦')
  expect(bodies).toHaveLength(1)
  expectAudio(bodies[0])
  await expect(bar).toContainText('Coloquei na OS o que está marcado. Confira.')
  await page.locator('.toast').getByRole('button', { name: 'Desfazer' }).click()
  await expect(line).toHaveCount(0)
})

test('OS aberta: Cancelar descarta a fala e não manda nada (order.ai.cancel-talk)', async ({ page }) => {
  const bodies = await assistantOn(page, SERVICE_3)
  const bar = await openOrder(page)
  await bar.getByRole('button', { name: 'Falar' }).click()
  await expect(bar.getByTestId('assistant-listening')).toBeVisible()
  await bar.getByRole('button', { name: 'Cancelar' }).click()
  await expect(bar.getByTestId('assistant-listening')).toHaveCount(0)
  await expect(bar.getByLabel('Pedir ao assistente')).toBeVisible()
  await expect(bar.getByRole('button', { name: 'Falar' })).toBeFocused()
  await page.waitForTimeout(500)
  expect(bodies).toHaveLength(0)
})

test('Nova OS: barra com Falar preenche o formulário com ✦ e Desfazer (order.new.assistant-bar)', async ({ page }) => {
  const bodies = await assistantOn(page, { ...SERVICE_3, notes: 'barulho ao frear' })
  await login(page, 'admin')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.getByTestId('new-order').click()
  await expect(drawer(page)).toBeVisible()
  const bar = page.getByTestId('new-order-assistant')
  await speak(bar)
  await expect(page.getByTestId('new-order-assistant-note')).toHaveText('Preenchi o que está marcado. Confira e salve.')
  await expect(drawer(page).getByLabel(/O que o cliente pediu/)).toHaveValue('barulho ao frear')
  expect(bodies).toHaveLength(1)
  expectAudio(bodies[0])
  await page.getByTestId('new-order-assistant-undo').click()
  await expect(drawer(page).getByLabel(/O que o cliente pediu/)).toHaveValue('')
})

test('microfone bloqueado: aviso de como liberar no navegador, a caixa de texto continua', async ({ page }) => {
  await page.addInitScript(() => {
    navigator.mediaDevices.getUserMedia = () => Promise.reject(new DOMException('blocked', 'NotAllowedError'))
  })
  const bodies = await assistantOn(page)
  const bar = await openOrder(page)
  await bar.getByRole('button', { name: 'Falar' }).click()
  await expect(bar.getByRole('status').first()).toContainText('cadeado ao lado do endereço do site')
  await expect(bar.getByLabel('Pedir ao assistente')).toBeVisible()
  expect(bodies).toHaveLength(0)
})

test('parar sem ter ouvido nada: avisa e não manda', async ({ page }) => {
  // A silent microphone.
  await page.addInitScript(() => {
    navigator.mediaDevices.getUserMedia = async () => new AudioContext().createMediaStreamDestination().stream
  })
  const bodies = await assistantOn(page)
  const bar = await openOrder(page)
  await bar.getByRole('button', { name: 'Falar' }).click()
  await expect(bar.getByTestId('assistant-listening')).toBeVisible()
  await page.waitForTimeout(800)
  await bar.getByRole('button', { name: 'Parar e preencher a OS' }).click()
  await expect(bar).toContainText('Não ouvi nada. Toque em Falar e tente de novo.')
  expect(bodies).toHaveLength(0)
})

test('navegador que não grava: sem Falar, só a caixa de texto', async ({ page }) => {
  await page.addInitScript(() => {
    delete (window as { MediaRecorder?: unknown }).MediaRecorder
  })
  await assistantOn(page)
  const bar = await openOrder(page)
  await expect(bar.getByLabel('Pedir ao assistente')).toBeVisible()
  await expect(bar.getByRole('button', { name: 'Falar' })).toHaveCount(0)
})
