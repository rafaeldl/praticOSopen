// "Manutenções chegando" on Início (home.maintenance.*), company D of the seed:
// late, today, in 2 days and in 7 days show; in 8 days and the one under an
// active contract do not (the technician cannot read contracts, so for him the
// contract one shows, as in the app).
import { expect, test, type Page } from './test'
import { expectNoAxeViolations, expectNoSideScroll, login, setTheme } from './helpers'

const section = (page: Page) => page.getByRole('region', { name: 'Manutenções chegando' })

test('dono vê as manutenções até 7 dias e as atrasadas, 3 de cada vez', async ({ page }) => {
  await login(page, 'maintOwner')
  const list = section(page)
  await expect(list.getByRole('button', { name: /Uno Atrasado/ })).toBeVisible()
  await expect(list.getByRole('button')).toHaveText([/Uno Atrasado/, /Palio Hoje/, /Gol Chegando/, /Ver mais 1/])
  await expect(list.getByRole('button', { name: /Uno Atrasado/ })).toContainText('Ana Lima · Última: Troca de óleo')
  await expect(list.getByTestId('maintenance-late')).toHaveCount(1)
  await list.getByRole('button', { name: 'Ver mais 1' }).click()
  await expect(list.getByRole('button')).toHaveText([/Uno Atrasado/, /Palio Hoje/, /Gol Chegando/, /Fox Semana/])
  await expect(list.getByText('Celta Longe')).toHaveCount(0)
  await expect(list.getByText('Corsa Contrato')).toHaveCount(0)
  // Only on the open lists, never while searching.
  await page.getByRole('button', { name: 'Concluídas', exact: true }).click()
  await expect(section(page)).toHaveCount(0)
  await page.getByRole('button', { name: 'Em aberto', exact: true }).click()
  await expect(section(page)).toBeVisible()
  await page.locator('#orders-search').fill('Gol')
  await expect(section(page)).toHaveCount(0)
})

test('chamar o cliente abre o WhatsApp com a mensagem pronta; sem cliente não oferece; cliente apagado avisa', async ({ page }) => {
  await login(page, 'maintOwner')
  await section(page).getByRole('button', { name: /Gol Chegando/ }).click()
  const sheet = page.getByRole('dialog', { name: 'Gol Chegando' })
  await expect(sheet).toContainText('Bia Souza ·')
  const call = sheet.getByRole('link', { name: 'Chamar cliente' })
  await expect(call).toHaveAttribute('href', /^https:\/\/wa\.me\/5511990001111\?text=/)
  const text = decodeURIComponent((await call.getAttribute('href'))!.split('text=')[1]!)
  expect(text).toMatch(/^Olá, Bia! Está chegando a manutenção de Gol Chegando, prevista para .+ de \d{4}\. Podemos combinar um dia\?$/)
  await sheet.getByRole('button', { name: 'Cancelar' }).click()

  await section(page).getByRole('button', { name: /Palio Hoje/ }).click()
  const today = page.getByRole('dialog', { name: 'Palio Hoje' })
  await expect(today.getByRole('button', { name: 'Ver Veículo' })).toBeVisible()
  await expect(today.getByText('Chamar cliente')).toHaveCount(0)
  await today.getByRole('button', { name: 'Cancelar' }).click()

  await section(page).getByRole('button', { name: 'Ver mais 1' }).click()
  await section(page).getByRole('button', { name: /Fox Semana/ }).click()
  await page.getByRole('dialog', { name: 'Fox Semana' }).getByRole('button', { name: 'Chamar cliente' }).click()
  await expect(page.getByText('Esse cliente foi apagado. Mude ou tire a manutenção no veículo.')).toBeVisible()
})

test('ver o veículo abre a tela dele, e abrir OS traz cliente, veículo e o serviço da última OS', async ({ page }) => {
  await login(page, 'maintOwner')
  await section(page).getByRole('button', { name: /Gol Chegando/ }).click()
  await page.getByRole('dialog', { name: 'Gol Chegando' }).getByRole('button', { name: 'Ver Veículo' }).click()
  await expect(page).toHaveURL(/\/devices\?device=d-soon/)
  await expect(page.getByTestId('device-maintenance')).toBeVisible()

  await page.goto('./')
  await section(page).getByRole('button', { name: /Gol Chegando/ }).click()
  await page.getByRole('dialog', { name: 'Gol Chegando' }).getByRole('button', { name: 'Abrir OS' }).click()
  const drawer = page.getByRole('dialog', { name: /Nova OS/ })
  await expect(drawer).toContainText('Bia Souza')
  await expect(drawer).toContainText('Gol Chegando')
  await expect(drawer).toContainText('Troca de óleo')
  await expect(drawer).toContainText('150,00')
})

test('técnico não lê contratos: vê a do contrato e não tem "Abrir OS"', async ({ page }) => {
  await login(page, 'maintTech')
  const list = section(page)
  await expect(list.getByRole('button', { name: /Ver mais 2/ })).toBeVisible()
  await list.getByRole('button', { name: 'Ver mais 2' }).click()
  await expect(list.getByRole('button', { name: /Corsa Contrato/ })).toBeVisible()
  await list.getByRole('button', { name: /Gol Chegando/ }).click()
  const sheet = page.getByRole('dialog', { name: 'Gol Chegando' })
  await expect(sheet.getByRole('link', { name: 'Chamar cliente' })).toBeVisible()
  await expect(sheet.getByRole('button', { name: 'Abrir OS' })).toHaveCount(0)
})

for (const theme of ['light', 'dark'] as const) {
  test(`axe: 0 violações nas manutenções, tema ${theme === 'light' ? 'claro' : 'escuro'}`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: theme })
    await login(page, 'maintOwner', 'login')
    await setTheme(page, theme)
    await expect(section(page)).toBeVisible()
    await expectNoAxeViolations(page, `manutenções ${theme}`)
    await section(page).getByRole('button', { name: /Gol Chegando/ }).click()
    await expect(page.getByRole('dialog', { name: 'Gol Chegando' })).toBeVisible()
    await expectNoAxeViolations(page, `ações da manutenção ${theme}`)
  })
}

test('320 px e texto a 200%: manutenções sem rolagem lateral', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await login(page, 'maintOwner')
  await expect(section(page)).toBeVisible()
  await expectNoSideScroll(page)
  await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
  await expectNoSideScroll(page)
})

test('técnico: "Agora" com a próxima visita de hoje, e Minhas com a hora no lugar do valor', async ({ page }) => {
  await login(page, 'maintTech')
  const now = page.getByTestId('next-visit')
  await expect(now).toContainText('Agora')
  await expect(now).toContainText('Próximo: Bia, Gol Chegando, às 23:30.')
  // The visit of "Agora" is not repeated in the list; the one already started shows its hour.
  const table = page.getByTestId('orders-table')
  await expect(table.locator('[data-order="d-visit-next"]')).toHaveCount(0)
  await expect(table.locator('[data-order="d-visit-started"]').getByTestId('visit-time')).toHaveText('08:00')
  await now.getByRole('button', { name: 'Abrir OS 3' }).click()
  await expect(page).toHaveURL(/order=d-visit-next/)
  // Searching hides it.
  await page.locator('#orders-search').fill('Ana')
  await expect(page.getByTestId('next-visit')).toHaveCount(0)
})
