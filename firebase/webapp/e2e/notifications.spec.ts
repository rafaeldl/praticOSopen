// The bell on Início and Avisos (home.notifications.*, notifications.*), company D:
// what notification.service.ts writes, for each person only their own.
import { expect, test, type Page } from '@playwright/test'
import { expectNoAxeViolations, expectNoSideScroll, login, setTheme } from './helpers'

const bell = (page: Page) => page.getByTestId('bell')
const heading = (page: Page, name: string) => page.getByRole('heading', { level: 1, name })

test('sino com 3 novos abre os avisos; abrir um vai à OS e marcar todos zera o sino', async ({ page }) => {
  await login(page, 'bellUser')
  await expect(bell(page)).toHaveAccessibleName('Avisos, 3 novos')
  await expect(page.getByTestId('bell-count')).toHaveText('3')
  await bell(page).click()
  await expect(heading(page, 'Avisos')).toBeVisible()
  await expect(page).toHaveURL(/\/notifications$/)
  await expect(page.getByText('3 novos')).toBeVisible()

  const fresh = page.getByRole('region', { name: 'Novos' })
  await expect(fresh.getByRole('button')).toHaveText([
    /Ana aprovou o orçamento\s*OS 1 · há \d+ minutos/,
    /Carlos comentou: “Pode trocar o filtro\?”\s*OS 1 · há 2 horas/,
    /Pagamento de R\$ 150,00 recebido\s*OS 1 · há 2 dias/,
  ])
  // Older than a month: the date. A maintenance has no order.
  const before = page.getByRole('region', { name: 'Antes' })
  await expect(before.getByRole('button')).toHaveText([/Manutenção chegando: Gol Chegando em 05\/11\s*\d{2}\/\d{2}\/\d{4}/])
  await expect(page.getByText('Outra pessoa aprovou')).toHaveCount(0)

  await fresh.getByRole('button', { name: /Ana aprovou/ }).click()
  await expect(page).toHaveURL(/\?order=d-order-gol/)
  await expect(page.getByRole('complementary', { name: 'OS aberta' })).toBeVisible()
  await expect(bell(page)).toHaveAccessibleName('Avisos, 2 novos')

  await bell(page).click()
  await expect(page.getByRole('region', { name: 'Antes' }).getByRole('button', { name: /Ana aprovou/ })).toBeVisible()
  await page.getByRole('button', { name: 'Marcar todos como lidos' }).click()
  await expect(page.getByRole('region', { name: 'Novos' })).toHaveCount(0)
  await expect(page.getByRole('region', { name: 'Antes' }).getByRole('button')).toHaveCount(4)
  await page.goto('./')
  await expect(bell(page)).toHaveAccessibleName('Avisos')
})

test('acima de 99 novos o sino mostra 99+', async ({ page }) => {
  await login(page, 'bellBusy')
  await expect(page.getByTestId('bell-count')).toHaveText('99+')
  await expect(bell(page)).toHaveAccessibleName('Avisos, 120 novos')
})

test('sem avisos, a tela explica o que aparece ali', async ({ page }) => {
  await login(page, 'maintTech', 'notifications')
  await expect(heading(page, 'Avisos')).toBeVisible()
  await expect(page.getByText('Nenhum aviso por enquanto.')).toBeVisible()
  await expect(page.getByText(/Aqui aparece o que acontece nas suas OS/)).toBeVisible()
})

for (const theme of ['light', 'dark'] as const) {
  test(`axe: 0 violações no sino e nos avisos, tema ${theme === 'light' ? 'claro' : 'escuro'}`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: theme })
    await login(page, 'bellBusy', 'login')
    await setTheme(page, theme)
    await expect(page.getByTestId('bell-count')).toHaveText('99+')
    await expectNoAxeViolations(page, `sino ${theme}`)
    await bell(page).click()
    await expect(page.getByRole('region', { name: 'Novos' })).toBeVisible()
    await expectNoAxeViolations(page, `avisos ${theme}`)
  })
}

test('320 px e texto a 200%: avisos sem rolagem lateral', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await login(page, 'bellBusy', 'notifications')
  await expect(page.getByRole('region', { name: 'Novos' })).toBeVisible()
  await expectNoSideScroll(page)
  await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
  await expectNoSideScroll(page)
})
