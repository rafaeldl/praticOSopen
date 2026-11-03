// Fatia 06: Financeiro > Relatório. Period, filters, rankings and the extras of a
// large screen (CSV, XLSX, print), over the seeded March 2026 (seed.mjs seedFinance).
import { readFileSync } from 'node:fs'
import { expect, test, type Page } from '@playwright/test'
import { expectNoAxeViolations, expectNoSideScroll, login, setTheme } from './helpers'

const MARCH = 'finance/report?from=2026-03-01&to=2026-03-31'
const h1 = (page: Page) => page.getByRole('heading', { level: 1 })

async function openReport(page: Page, path = MARCH) {
  await login(page, 'admin', path)
  await expect(page.getByTestId('finance-report')).toBeVisible()
  await expect(page.getByText('Carregando…')).toHaveCount(0)
}

/** Sunday to Saturday of today's week in São Paulo, as dd/mm. */
function thisWeek(offsetWeeks = 0): string {
  const today = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
  const day = new Date(`${today}T12:00:00Z`)
  const sunday = new Date(day.getTime() - (day.getUTCDay() - 7 * offsetWeeks) * 86_400_000)
  const saturday = new Date(sunday.getTime() + 6 * 86_400_000)
  const short = (date: Date) => date.toLocaleDateString('pt-BR', { timeZone: 'UTC', day: '2-digit', month: '2-digit' })
  return `${short(sunday)} a ${short(saturday)}`
}

test('totais, composição, rankings e OS do período (fin.report.view, composition, rankings, orders, fin.report.rules)', async ({ page }) => {
  await openReport(page)
  await expect(h1(page)).toHaveText('Faturou R$ 350,00 de 01/03/2026 a 31/03/2026')
  await expect(page.getByTestId('report-revenue')).toHaveText('R$ 350,00')
  await expect(page.getByTestId('report-paid')).toContainText('R$ 300,00')
  await expect(page.getByTestId('report-unpaid')).toContainText('R$ 50,00')
  await expect(page.getByText('Média por OS')).toBeVisible()
  const mix = page.getByRole('region', { name: 'Composição' })
  await expect(mix).toContainText('Serviços')
  await expect(mix).toContainText('R$ 250,00')
  await expect(mix).toContainText('R$ 100,00')
  const customers = page.getByTestId('report-customers')
  await expect(customers.getByRole('button')).toHaveText([/Ana Financeiro.*R\$\s300,00/, /Bia Financeiro.*a receber R\$\s50,00.*R\$\s50,00/])
  await expect(page.getByRole('region', { name: 'Serviços que mais venderam' })).toContainText('Revisão completa')
  await expect(page.getByRole('region', { name: 'Peças e produtos que mais venderam' })).toContainText('Filtro de óleo · 2 unidades')
  await expect(page.getByTestId('report-order')).toHaveText([/OS 9103 · 31\/03\/2026 · Pendente\s*Bia Financeiro\s*R\$\s50,00/, /OS 9101 · 10\/03\/2026 · Pago\s*Ana Financeiro\s*R\$\s300,00/])
  await expect(page.getByTestId('report-orders')).not.toContainText('9104')
  await expect(page.getByTestId('report-orders')).not.toContainText('9105')
  // The order opens beside the list.
  await page.getByTestId('report-order').first().click()
  await expect(page).toHaveURL(/order=fin-last-day/)
})

test('o último dia do período entra (defeito 60 do app) (fin.report.custom)', async ({ page }) => {
  await openReport(page, 'finance/report?from=2026-03-31&to=2026-03-31')
  await expect(h1(page)).toHaveText('Faturou R$ 50,00 em 31/03/2026')
  await expect(page.getByTestId('report-order')).toHaveText([/OS 9103/])
  await expect(page.getByTestId('report-label')).toHaveText('31/03/2026 a 31/03/2026')
  // The label with the calendar reopens the dates, which start where they were.
  await page.getByTestId('report-label').click()
  const dialog = page.getByRole('dialog', { name: 'Que período?' })
  await expect(dialog.getByLabel('Começa')).toHaveValue('2026-03-31')
  // A start after the end pulls the end along.
  await dialog.getByLabel('Começa').fill('2026-03-01')
  await dialog.getByLabel('Termina').fill('2026-02-15')
  await expect(dialog.getByLabel('Começa')).toHaveValue('2026-02-15')
  await page.keyboard.press('Escape')
})

test('filtro de pagamento: a receber lista também parcial e sem situação; totais não mudam (fin.report.payment-filter)', async ({ page }) => {
  await openReport(page)
  await page.getByTestId('report-unpaid').click()
  await expect(page).toHaveURL(/payment=unpaid/)
  await expect(page.getByTestId('report-unpaid')).toHaveAttribute('aria-pressed', 'true')
  await expect(page.getByRole('heading', { name: 'Clientes a receber' })).toBeVisible()
  await expect(page.getByTestId('report-customers').getByRole('button')).toHaveText([/Bia Financeiro.*R\$\s50,00/])
  await expect(page.getByRole('heading', { name: 'OS a receber' })).toBeVisible()
  await expect(page.getByTestId('report-order')).toHaveText([/OS 9103/])
  await expect(page.getByTestId('report-revenue')).toHaveText('R$ 350,00')
  await page.getByTestId('report-paid').click()
  await expect(page.getByTestId('report-order')).toHaveText([/OS 9101/])
  await page.getByTestId('report-paid').click()
  await expect(page).not.toHaveURL(/payment=/)
})

test('cliente escolhido: números só dele, ranking continua com todos; escolher de novo limpa (fin.report.customer-ranking)', async ({ page }) => {
  await openReport(page)
  await page.getByTestId('report-customers').getByRole('button', { name: /Ana Financeiro/ }).click()
  await expect(page).toHaveURL(/customer=fin-ana/)
  await expect(page.getByTestId('report-revenue')).toHaveText('R$ 300,00')
  await expect(page.getByText('Só de Ana Financeiro.')).toBeVisible()
  await expect(page.getByTestId('report-customers').getByRole('button')).toHaveCount(2)
  await expect(page.getByTestId('report-customers').getByRole('button', { name: /Ana Financeiro/ })).toHaveAttribute('aria-pressed', 'true')
  await page.getByTestId('report-customers').getByRole('button', { name: /Ana Financeiro/ }).click()
  await expect(page).not.toHaveURL(/customer=/)
  await expect(page.getByTestId('report-revenue')).toHaveText('R$ 350,00')
})

test('período: semana de domingo a sábado, passo para trás, próximo travado e rótulo que volta e limpa (fin.report.period, step, reset-period)', async ({ page }) => {
  await openReport(page, 'finance/report')
  await expect(page.getByTestId('report-label')).toHaveText('Mês atual')
  await expect(page.getByTestId('report-next')).toBeDisabled()
  await page.getByTestId('report-kind').selectOption('week')
  await expect(page).toHaveURL(/kind=week/)
  await expect(page.getByTestId('report-label')).toHaveText(thisWeek())
  await page.getByTestId('report-prev').click()
  await expect(page).toHaveURL(/offset=-1/)
  await expect(page.getByTestId('report-label')).toHaveText(thisWeek(-1))
  // The label goes back to this week and drops the filters.
  await page.goto('finance/report?kind=week&offset=-1&payment=unpaid&customer=fin-ana')
  await page.getByTestId('report-label').click()
  await expect(page).toHaveURL(/kind=week$/)
  await expect(page.getByTestId('report-label')).toHaveText(thisWeek())
  await page.getByTestId('report-kind').selectOption('year')
  await expect(page.getByTestId('report-label')).toHaveText('Ano atual')
  await page.getByTestId('report-kind').selectOption('day')
  await expect(page.getByTestId('report-label')).toHaveText('Hoje')
})

test('ver todos e ver menos (fin.report.see-all)', async ({ page }) => {
  // The seed's October orders and the ones the tests make are this year: more than five.
  await openReport(page, 'finance/report?kind=year')
  await expect(page.getByTestId('report-order').first()).toBeVisible()
  const orders = page.getByTestId('report-orders')
  await expect(page.getByTestId('report-order')).toHaveCount(5)
  await orders.getByRole('button', { name: /Ver todos \(\d+\)/ }).click()
  expect(await page.getByTestId('report-order').count()).toBeGreaterThan(5)
  await orders.getByRole('button', { name: 'Ver menos' }).click()
  await expect(page.getByTestId('report-order')).toHaveCount(5)
})

test('exportar CSV e planilha com o que o servidor deu', async ({ page }) => {
  await openReport(page)
  const [csv] = await Promise.all([page.waitForEvent('download'), page.getByTestId('report-csv').click()])
  expect(csv.suggestedFilename()).toBe('relatorio-financeiro-2026-03-01-2026-03-31.csv')
  const text = readFileSync((await csv.path())!, 'utf8')
  expect(text.charCodeAt(0)).toBe(0xfeff)
  const lines = text.slice(1).trim().split('\r\n')
  expect(lines[0]).toBe('OS;Data;Cliente;Aparelho;Situação;Pagamento;Total;Já pago;A receber')
  expect(lines).toContain('9101;10/03/2026;Ana Financeiro;;Concluído;Pago;300;300;0')
  expect(lines).toContain('9103;31/03/2026;Bia Financeiro;;Aprovado;Pendente;50;0;50')
  expect(lines).toHaveLength(3)

  const [xlsx] = await Promise.all([page.waitForEvent('download'), page.getByTestId('report-xlsx').click()])
  expect(xlsx.suggestedFilename()).toBe('relatorio-financeiro-2026-03-01-2026-03-31.xlsx')
  const file = readFileSync((await xlsx.path())!)
  // A zip (PK) with the sheets stored as XML: the numbers are numbers.
  expect(file.subarray(0, 2).toString()).toBe('PK')
  const body = file.toString('utf8')
  expect(body).toContain('<sheet name="Resumo"')
  expect(body).toContain('<sheet name="OS"')
  expect(body).toContain('<t xml:space="preserve">Ana Financeiro</t>')
  expect(body).toContain('<v>350</v>')
  expect(body).toContain('Filtro de óleo')
})

test('quem não vê valores nunca baixa o relatório: o servidor recusa', async ({ page }) => {
  // The page is denied before any request; the route itself answers 403 (app-finance.routes.test.ts).
  await login(page, 'supervisor', MARCH)
  await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
  await expect(page.getByTestId('report-csv')).toHaveCount(0)
})

test('imprimir: folha própria com todas as linhas, sem navegação', async ({ page }) => {
  await openReport(page, 'finance/report?kind=year')
  await expect(page.getByTestId('report-order').first()).toBeVisible()
  await page.evaluate(() => {
    ;(window as unknown as { printed: boolean }).printed = false
    window.print = () => ((window as unknown as { printed: boolean }).printed = true)
  })
  await page.getByTestId('report-print').click()
  await expect.poll(() => page.evaluate(() => (window as unknown as { printed: boolean }).printed)).toBe(true)
  await page.emulateMedia({ media: 'print' })
  await expect(page.locator('.side')).toBeHidden()
  await expect(page.getByTestId('report-csv')).toBeHidden()
  expect(await page.getByTestId('report-order').count()).toBeGreaterThan(5)
  await expect(page.locator('.report-print-head')).toBeVisible()
})

test('período sem OS e erro com tentar de novo', async ({ page }) => {
  await openReport(page, 'finance/report?from=2020-01-01&to=2020-01-02')
  await expect(h1(page)).toHaveText('Nenhuma OS de 01/01/2020 a 02/01/2020')
  await expect(page.getByTestId('report-empty')).toBeVisible()
  await expect(page.getByTestId('report-print')).toBeDisabled()
  await page.route('**/v1/app/finance/report**', (route) => route.abort())
  await page.goto('finance/report?from=2020-01-01&to=2020-01-03')
  await expect(page.getByRole('alert')).toContainText('Tentar de novo')
  await page.unroute('**/v1/app/finance/report**')
  await page.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(page.getByTestId('report-empty')).toBeVisible()
})

for (const theme of ['light', 'dark'] as const) {
  test(`axe: relatório e período, tema ${theme === 'light' ? 'claro' : 'escuro'}`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: theme })
    await login(page, 'admin', 'login')
    await setTheme(page, theme)
    await page.goto(MARCH)
    await expect(page.getByTestId('report-order').first()).toBeVisible()
    await expectNoAxeViolations(page, `relatório ${theme}`)
    await page.getByTestId('report-unpaid').click()
    await expect(page).toHaveURL(/payment=unpaid/)
    await expectNoAxeViolations(page, `relatório filtrado ${theme}`)
    await page.getByTestId('report-label').click()
    await expect(page.getByRole('dialog', { name: 'Que período?' })).toBeVisible()
    await expectNoAxeViolations(page, `datas ${theme}`)
  })
}

for (const [width, height] of [
  [320, 640],
  [2560, 1440],
] as const) {
  test(`${width} px sem rolagem lateral no relatório`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await login(page, 'admin', MARCH)
    await expect(page.getByTestId('report-order').first()).toBeVisible()
    await expectNoSideScroll(page)
  })
}

for (const [width, height] of [
  [320, 640],
  [1366, 768],
] as const) {
  test(`texto a 200% em ${width} px no relatório`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await login(page, 'admin', MARCH)
    await expect(page.getByTestId('report-order').first()).toBeVisible()
    await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await expectNoSideScroll(page)
  })
}

for (const [language, revenue, csv] of [
  ['en', 'Revenue', 'Export CSV'],
  ['es', 'Facturación', 'Exportar CSV'],
] as const) {
  test(`idioma ${language}: relatório`, async ({ page }) => {
    await login(page, 'admin', MARCH)
    await page.evaluate((value) => localStorage.setItem('praticos.prefs', JSON.stringify({ language: value })), language)
    await page.reload()
    await expect(page.getByText(revenue, { exact: true })).toBeVisible()
    await expect(page.getByTestId('report-csv')).toHaveText(csv)
    await expect(page.getByTestId('report-revenue')).toHaveText('R$ 350,00')
  })
}
