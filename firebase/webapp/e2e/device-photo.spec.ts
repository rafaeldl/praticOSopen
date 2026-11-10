// Foto do aparelho (device.form.photo) against the Emulator Suite, with the
// Storage emulator and its rules. Company A is automotive ("Veículo", "Placa").
// The photo goes up only after ✓ (the app creates the device on picking it),
// the button says it is uploading, and a failed upload is said.
import { expect, test, type Page } from './test'
import { makeDevice, queryDocs, readDoc } from './data'
import { login } from './helpers'

const panel = (page: Page) => page.getByTestId('device-detail')
const form = (page: Page) => page.getByTestId('device-form')
// 1x1 PNG.
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64')
const UPLOAD = /\/v0\/b\/[^/]+\/o(\?|$)/

async function openDevices(page: Page, user: Parameters<typeof login>[1], query = '') {
  await login(page, user, `devices${query}`)
  await expect(page.getByRole('heading', { level: 1, name: 'Veículos' })).toBeVisible()
}

test('supervisor cadastra veículo com foto: sobe só depois do ✓, na pasta do aparelho, e aparece na ficha (device.form.photo)', async ({ page }) => {
  const model = `Zeta Foto ${Date.now()}`
  await openDevices(page, 'supervisor')
  await page.getByTestId('new-device').click()
  await form(page).getByLabel('Modelo').fill(model)
  await form(page).getByText('Mais dados').click()
  await form(page).getByTestId('device-photo-file').setInputFiles({ name: 'foto.png', mimeType: 'image/png', buffer: PNG })
  await expect(form(page).getByTestId('device-photo-preview')).toBeVisible()
  // Nothing saved yet: the photo waits in the browser.
  expect(await queryDocs('devices', 'name', model)).toHaveLength(0)
  await form(page).getByTestId('save-device').click()
  await expect(panel(page).getByRole('heading', { name: model })).toBeVisible()
  await expect(panel(page).getByTestId('device-detail-photo')).toBeVisible()
  const [saved] = await queryDocs('devices', 'name', model)
  expect(String(saved?.photo)).toContain(encodeURIComponent(`tenants/company-alpha/devices/${saved?.id}/photo.jpg`))
})

test('fechar com foto escolhida não cria o veículo (Não copiar do app) e pergunta antes', async ({ page }) => {
  const model = `Zeta Cancela ${Date.now()}`
  await openDevices(page, 'admin')
  await page.getByTestId('new-device').click()
  await form(page).getByLabel('Modelo').fill(model)
  await form(page).getByText('Mais dados').click()
  await form(page).getByTestId('device-photo-file').setInputFiles({ name: 'foto.png', mimeType: 'image/png', buffer: PNG })
  page.once('dialog', (dialog) => void dialog.accept())
  await page.keyboard.press('Escape')
  await expect(form(page)).toBeHidden()
  expect(await queryDocs('devices', 'name', model)).toHaveLength(0)
})

test('trocar a foto de um veículo existente; sem opção de tirar (device.form.photo)', async ({ page }) => {
  const device = await makeDevice()
  await openDevices(page, 'admin', `?device=${device.id}`)
  await expect(panel(page).getByTestId('device-detail-photo')).toHaveCount(0)
  await panel(page).getByTestId('device-menu').click()
  await page.getByRole('dialog', { name: device.name }).getByRole('button', { name: 'Editar', exact: true }).click()
  await form(page).getByText('Mais dados').click()
  await expect(form(page).getByText('Escolher foto')).toBeVisible()
  await form(page).getByTestId('device-photo-file').setInputFiles({ name: 'foto.png', mimeType: 'image/png', buffer: PNG })
  await expect(form(page).getByText('Trocar foto')).toBeVisible()
  await expect(form(page).getByRole('button', { name: /Tirar/ })).toHaveCount(0)
  await form(page).getByTestId('save-device').click()
  await expect(panel(page).getByTestId('device-detail-photo')).toBeVisible()
  expect(String((await readDoc(`devices/${device.id}`))?.photo)).toContain(encodeURIComponent(`devices/${device.id}/photo.jpg`))
})

test('envio da foto falha: o veículo fica salvo e um aviso diz que a foto não foi', async ({ page }) => {
  const model = `Zeta Falha ${Date.now()}`
  await openDevices(page, 'supervisor')
  await page.route(UPLOAD, (route) =>
    route.request().method() === 'POST' ? route.fulfill({ status: 403, json: { error: { code: 403, message: 'Permission denied.' } } }) : route.continue(),
  )
  await page.getByTestId('new-device').click()
  await form(page).getByLabel('Modelo').fill(model)
  await form(page).getByText('Mais dados').click()
  await form(page).getByTestId('device-photo-file').setInputFiles({ name: 'foto.png', mimeType: 'image/png', buffer: PNG })
  await form(page).getByTestId('save-device').click()
  await expect(page.locator('.toast')).toContainText('Cadastro salvo, mas a foto não subiu')
  await expect(panel(page).getByRole('heading', { name: model })).toBeVisible()
  const [saved] = await queryDocs('devices', 'name', model)
  expect(saved?.photo ?? null).toBeNull()
})

test('arquivo que não é imagem é recusado no formulário', async ({ page }) => {
  await openDevices(page, 'admin')
  await page.getByTestId('new-device').click()
  await form(page).getByText('Mais dados').click()
  await form(page).getByTestId('device-photo-file').setInputFiles({ name: 'nota.txt', mimeType: 'text/plain', buffer: Buffer.from('oi') })
  await expect(form(page).getByRole('alert')).toHaveText('Esse arquivo não é uma imagem.')
})
