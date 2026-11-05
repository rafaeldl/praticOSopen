// Início filters as server queries (home.filter.server): company paging has more
// orders per filter than the first page (30), seeded by seed.mjs seedPaging.
// A filter that looked only at the loaded rows missed the ones further down;
// now each filter is its own query, paged with "Mostrar mais" and counted by
// the server. Nothing here writes, so the numbers are fixed.
import { expect, test, type Page } from '@playwright/test'
import { login, type UserKey } from './helpers'

const table = (page: Page) => page.getByTestId('orders-table')
const rows = (page: Page) => table(page).locator('tbody tr:not(.group-row)')
const row = (page: Page, number: number) => rows(page).filter({ has: page.locator('.c-num', { hasText: new RegExp(`^${number}$`) }) })
const chip = (page: Page, name: RegExp) => page.getByRole('group', { name: 'Filtros' }).getByRole('button', { name })
const more = (page: Page) => page.locator('.more-rows').getByRole('button', { name: 'Mostrar mais' })

async function openHome(page: Page, user: UserKey, path = './') {
  await login(page, user, path)
  await expect(page.getByRole('heading', { level: 1, name: /Início|Ordens de Serviço/ })).toBeVisible()
}

/** Every page, until the end of the list is gone. */
async function loadAll(page: Page) {
  await expect(table(page)).toBeVisible()
  const end = page.locator('.more-rows')
  await expect(async () => {
    if (await more(page).count()) await more(page).click({ timeout: 1000 }).catch(() => {})
    await expect(end).toHaveCount(0, { timeout: 1000 })
  }).toPass()
}

test('Atrasadas: a primeira página tem 30, "Mostrar mais" traz o resto (home.filter.server)', async ({ page }) => {
  await openHome(page, 'pOwner', './?f=late')
  await expect(chip(page, /^Atrasadas$/)).toHaveAttribute('aria-pressed', 'true')
  // Same promise for all 35: the id breaks the tie, so 131..135 are on the second page.
  await expect(rows(page)).toHaveCount(30)
  await expect(row(page, 101)).toHaveCount(1)
  await expect(row(page, 135)).toHaveCount(0)
  await more(page).click()
  await expect(rows(page)).toHaveCount(35)
  await expect(row(page, 135)).toHaveCount(1)
  await expect(page.locator('.more-rows')).toHaveCount(0)
  // Only late orders came: none of the done, quotes or assigned ones.
  await expect(row(page, 1)).toHaveCount(0)
  await expect(row(page, 401)).toHaveCount(0)
})

test('Paradas: a OS parada fora da primeira página de Em aberto aparece, também ao trocar e voltar', async ({ page }) => {
  await openHome(page, 'pOwner')
  await expect(chip(page, /^Em aberto$/)).toHaveAttribute('aria-pressed', 'true')
  await expect(rows(page)).toHaveCount(30)
  // 900 is the oldest open order: far from the first page of Em aberto.
  await expect(row(page, 900)).toHaveCount(0)
  // The sentence counts on the server, before the other pages come.
  await expect(page.getByTestId('summary')).toHaveText(/^70 em aberto · 35 atrasadas/)

  await chip(page, /^Paradas$/).click()
  await expect(row(page, 900)).toHaveCount(1)
  await expect(rows(page)).toHaveCount(1)
  await expect(page.getByTestId('summary')).toHaveText('1 parada')

  await chip(page, /^Em aberto$/).click()
  await expect(row(page, 900)).toHaveCount(0)
  await chip(page, /^Paradas$/).click()
  await expect(row(page, 900)).toHaveCount(1)

  // The count was the real total: every page of Em aberto has 70 rows.
  await chip(page, /^Em aberto$/).click()
  await loadAll(page)
  await expect(rows(page)).toHaveCount(70)
  await expect(row(page, 900)).toHaveCount(1)
})

test('Sem receber: o número do filtro e a frase vêm do servidor e batem com a lista', async ({ page }) => {
  await openHome(page, 'pOwner')
  await expect(chip(page, /^Sem receber\s*33$/)).toBeVisible()
  await chip(page, /^Sem receber/).click()
  await expect(page.getByTestId('summary')).toHaveText('33 para receber · R$ 1.980,00')
  await expect(rows(page)).toHaveCount(30)
  await loadAll(page)
  await expect(rows(page)).toHaveCount(33)
  await expect(row(page, 1)).toHaveCount(0)
  await expect(row(page, 233)).toContainText('falta receber R$ 60,00')
})

test('consultor: só as OS dele em cada filtro, e a contagem também (papel restrito)', async ({ page }) => {
  await openHome(page, 'pConsultant')
  await expect(rows(page)).toHaveCount(2)
  await expect(page.getByTestId('summary')).toHaveText(/^2 em aberto/)
  await chip(page, /^Orçamentos$/).click()
  await expect(page.getByTestId('summary')).toHaveText('2 orçamentos sem resposta')
  await expect(row(page, 301)).toHaveCount(1)
  await expect(row(page, 302)).toHaveCount(1)
  await chip(page, /^Atrasadas$/).click()
  await expect(page.getByTestId('orders-empty')).toBeVisible()
  await chip(page, /^Paradas$/).click()
  await expect(page.getByTestId('orders-empty')).toBeVisible()
})

test('técnico: Minhas pela atribuição, contada no servidor, com "Mostrar mais" (papel restrito)', async ({ page }) => {
  await openHome(page, 'pTech')
  await expect(chip(page, /^Minhas$/)).toHaveAttribute('aria-pressed', 'true')
  await expect(page.getByTestId('summary')).toHaveText('32 com você')
  await expect(rows(page)).toHaveCount(30)
  await more(page).click()
  await expect(rows(page)).toHaveCount(32)
  await expect(page.getByTestId('summary')).toHaveText('32 com você')
  // The stopped order was neither created by nor given to them.
  await chip(page, /^Paradas$/).click()
  await expect(page.getByTestId('orders-empty')).toBeVisible()
  await expect(row(page, 900)).toHaveCount(0)
})

test('supervisor (sem valores, pela API): Atrasadas por página e Paradas acha a OS antiga', async ({ page }) => {
  await openHome(page, 'pSuper', './?f=late')
  await expect(rows(page)).toHaveCount(30)
  await more(page).click()
  await expect(rows(page)).toHaveCount(35)
  await chip(page, /^Paradas$/).click()
  await expect(row(page, 900)).toHaveCount(1)
  await chip(page, /^Orçamentos$/).click()
  await expect(page.getByTestId('summary')).toHaveText('2 orçamentos sem resposta')
})
