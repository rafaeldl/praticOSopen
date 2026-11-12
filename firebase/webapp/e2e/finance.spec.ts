// Fatia 06: Financeiro > Resumo and Receber. Every number comes from the API
// (GET /v1/app/finance/*): the tests check the server's answer on screen and
// that the browser never reads the orders for it. March 2026 is a closed month
// seeded with known numbers (seed.mjs seedFinance), in São Paulo.
import { expect, test, type Page } from './test'
import { chooseCompany, expectNoAxeViolations, expectNoSideScroll, login, setTheme, type UserKey } from './helpers'

const MARCH = 'finance?month=2026-03'

async function openFinance(page: Page, user: UserKey, path = MARCH) {
  await login(page, user, path)
  if (user === 'owner') await chooseCompany(page, 'Oficina Alfa')
  await expect(page.getByTestId('finance-summary')).toBeVisible()
  await expect(page.getByText('Carregando…')).toHaveCount(0)
}

/** Today's month on the company's calendar, as the screen names it. */
function currentMonthYear(): string {
  return new Intl.DateTimeFormat('pt-BR', { timeZone: 'America/Sao_Paulo', month: 'long', year: 'numeric' }).format(new Date())
}

test('março de 2026: recebido pela data do pagamento, vendido sem orçamento, último dia e fuso (fin.tab.view, fin.tab.received, fin.tab.sold, fin.summary.rules)', async ({ page }) => {
  const summary = page.waitForResponse((response) => /\/v1\/app\/finance\/summary\?month=2026-03/.test(response.url()))
  await openFinance(page, 'admin')
  expect((await summary).status()).toBe(200)
  // Short title like Início and Clientes; the sentence answers under it.
  await expect(page.getByRole('heading', { level: 1 })).toHaveText('Financeiro')
  await expect(page.getByTestId('page-answer')).toHaveText('Em março entraram R$ 380,00')
  // Received: 300 paid in March and 80 of a February order paid in March.
  await expect(page.getByTestId('fin-card-received')).toContainText('R$ 380,00')
  await expect(page.getByTestId('fin-card-received')).toContainText('2 OS com pagamento')
  const list = page.getByTestId('fin-list')
  await expect(list.getByRole('heading')).toHaveText('Recebido em março')
  await expect(list.getByTestId('fin-row')).toHaveText([/Ana Financeiro.*OS 9101.*R\$\s300,00/, /Bia Financeiro.*OS 9102.*R\$\s80,00/])
  // Sold: the order of 31/03 23:30 (written by the app, no zone) counts; 01/04 00:00 and the quote do not.
  await expect(page.getByTestId('fin-card-sold')).toContainText('R$ 350,00')
  await page.getByTestId('fin-card-sold').click()
  await expect(page).toHaveURL(/list=sold/)
  await expect(list.getByRole('heading')).toHaveText('Vendido em março')
  await expect(list.getByTestId('fin-row')).toHaveText([/OS 9103.*31\/03.*R\$\s50,00/, /OS 9101.*10\/03.*R\$\s300,00/])
  await expect(list).not.toContainText('9104')
  await expect(list).not.toContainText('9105')
})

test('mês: o seguinte para no mês atual e o rótulo volta para hoje; resposta atrasada não troca o mês (fin.tab.month)', async ({ page }) => {
  await openFinance(page, 'admin', 'finance')
  await expect(page.getByTestId('fin-month')).toHaveText(currentMonthYear())
  await expect(page.getByTestId('fin-next')).toBeDisabled()
  await expect(page.getByTestId('fin-month')).toBeDisabled()
  await page.getByTestId('fin-prev').click()
  await expect(page).toHaveURL(/month=\d{4}-\d{2}/)
  await expect(page.getByTestId('fin-next')).toBeEnabled()
  // The label of a past month takes the screen back to today.
  await page.getByTestId('fin-month').click()
  await expect(page).not.toHaveURL(/month=/)
  await expect(page.getByTestId('fin-month')).toHaveText(currentMonthYear())
  // A slow answer for a month already left is dropped.
  await page.goto(MARCH)
  await expect(page.getByTestId('page-answer')).toHaveText('Em março entraram R$ 380,00')
  let release: () => void = () => undefined
  await page.route('**/v1/app/finance/summary?month=2026-02*', async (route) => {
    await new Promise<void>((resolve) => (release = resolve))
    await route.continue()
  })
  await page.getByTestId('fin-prev').click()
  await expect(page).toHaveURL(/month=2026-02/)
  await page.getByTestId('fin-next').click()
  await expect(page).toHaveURL(/month=2026-03/)
  release()
  await page.waitForTimeout(500)
  await expect(page.getByTestId('page-answer')).toHaveText('Em março entraram R$ 380,00')
  // Arrows change the month too, outside fields.
  await page.getByRole('heading', { level: 1 }).click()
  await page.keyboard.press('ArrowLeft')
  await expect(page).toHaveURL(/month=2026-02/)
})

test('Em andamento e A receber são de hoje; a linha abre a OS (fin.tab.progress, fin.tab.open-order, fin.tab.receivable)', async ({ page }) => {
  await openFinance(page, 'manager')
  await page.getByTestId('fin-card-progress').click()
  await expect(page).toHaveURL(/list=progress/)
  const list = page.getByTestId('fin-list')
  await expect(list.getByRole('heading')).toHaveText('Em andamento')
  await expect(list.getByTestId('fin-row').filter({ hasText: 'OS 9103' })).toContainText('R$ 50,00')
  await list.getByTestId('fin-row').filter({ hasText: 'OS 9103' }).click()
  await expect(page).toHaveURL(/\/finance\?.*order=fin-last-day/)
  await expect(page.getByRole('complementary', { name: 'OS aberta' })).toBeVisible()
  // Beside the list, as in the other screens: the Financeiro stays (B6 of #525).
  await expect(page.getByTestId('finance-summary')).toBeVisible()
  await page.getByRole('complementary', { name: 'OS aberta' }).getByRole('button', { name: 'Fechar' }).click()
  await expect(page).not.toHaveURL(/order=/)
  await expect(page.getByTestId('fin-list')).toBeVisible()

  // A receber: the done order with a balance, by customer; the customer opens "Receber de".
  await page.goto(`${MARCH}&list=receivable`)
  await expect(page.getByTestId('fin-card-receivable')).toContainText(/De \d+ clientes?/)
  const debtor = page.getByTestId('fin-list').getByRole('link', { name: /Cliente 06/ })
  await expect(debtor).toContainText('R$ 200,00')
  await debtor.click()
  await expect(page).toHaveURL(/finance\/receive\?customer=customer-6/)
  await expect(page.getByRole('dialog', { name: /Receber de Cliente 06/ })).toBeVisible()
})

test('Receber lê do servidor, não das OS no navegador (residual do #518)', async ({ page }) => {
  const firestoreOrders: string[] = []
  page.on('request', (request) => {
    if (/documents:runQuery|Firestore\/Listen/.test(request.url()) && /payment/.test(request.postData() ?? '')) firestoreOrders.push(request.url())
  })
  const answer = page.waitForResponse((response) => /\/v1\/app\/finance\/receivable/.test(response.url()))
  await openFinance(page, 'admin', 'finance')
  await page.getByRole('link', { name: 'Receber', exact: true }).click()
  expect((await answer).status()).toBe(200)
  await expect(page.getByTestId('finance-receive')).toBeVisible()
  await expect(page.getByTestId('finance-row').filter({ hasText: 'OS 504' })).toContainText('R$ 200,00')
  expect(firestoreOrders).toEqual([])
})

test('Receber cortado: o aviso diz que algumas OS podem faltar, sem prometer quais (B3 do #525)', async ({ page }) => {
  await page.route('**/v1/app/finance/receivable**', async (route) => {
    const response = await route.fetch()
    const body = await response.json()
    await route.fulfill({ response, json: { ...body, data: { ...body.data, truncated: true } } })
  })
  await openFinance(page, 'admin', 'finance')
  await page.getByRole('link', { name: 'Receber', exact: true }).click()
  await expect(page.getByTestId('finance-receive')).toBeVisible()
  await expect(page.getByRole('note')).toHaveText('Há mais OS sem receber do que dá para ler de uma vez: algumas podem faltar aqui.')
})

test('Notas fiscais do mês na aba: só a contagem, nunca dinheiro (fin.tab.nfse-row)', async ({ page }) => {
  await openFinance(page, 'admin', 'finance')
  const row = page.getByTestId('fin-nfse-row')
  await expect(row).toContainText('Notas fiscais · 1')
  await expect(row).toContainText(/\d+ precisa(m)? de atenção/)
  await expect(row).not.toContainText('R$')
  await row.click()
  await expect(page).toHaveURL(/\/invoices$/)
})

test('relatório e outro período pelo Resumo (fin.tab.report, fin.tab.other-period)', async ({ page }) => {
  await openFinance(page, 'admin')
  await page.getByTestId('fin-report').click()
  await expect(page).toHaveURL(/finance\/report\?from=2026-03-01&to=2026-03-31/)
  await expect(page.getByTestId('page-answer')).toHaveText('Faturou R$ 350,00 de 01/03/2026 a 31/03/2026')
  await page.goto(MARCH)
  await page.getByTestId('fin-other-period').click()
  const dialog = page.getByRole('dialog', { name: 'Que período?' })
  await expect(dialog).toBeVisible()
  await dialog.getByLabel('Começa').fill('2026-03-31')
  await dialog.getByLabel('Termina').fill('2026-03-31')
  await dialog.getByTestId('period-apply').click()
  await expect(page).toHaveURL(/from=2026-03-31&to=2026-03-31/)
  await expect(page.getByTestId('page-answer')).toHaveText('Faturou R$ 50,00 em 31/03/2026')
})

test('gerente vê os números', async ({ page }) => {
  await openFinance(page, 'manager')
  await expect(page.getByTestId('page-answer')).toHaveText('Em março entraram R$ 380,00')
})

for (const user of ['supervisor', 'consultant', 'technician'] as const) {
  test(`${user}: não chega ao Financeiro nem pede os números`, async ({ page }) => {
    const asked: string[] = []
    page.on('request', (request) => /\/v1\/app\/finance\//.test(request.url()) && asked.push(request.url()))
    await login(page, user, 'finance/report?from=2026-03-01&to=2026-03-31')
    await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
    for (const path of ['finance', 'finance/receive']) {
      await page.goto(path)
      await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
    }
    expect(asked).toEqual([])
  })
}

test('"Valores e cobrança" desligado: nem o dono vê o Financeiro, o relatório ou as notas', async ({ page }) => {
  await login(page, 'noValues')
  await expect(page.getByRole('navigation', { name: 'Principal' }).getByRole('link', { name: 'Financeiro' })).toHaveCount(0)
  for (const path of ['finance', 'finance/report', 'finance/receive', 'invoices']) {
    await page.goto(path)
    await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
  }
})

test('erro e tentar de novo; carregando antes da resposta', async ({ page }) => {
  await login(page, 'admin', 'settings')
  let fail = true
  await page.route('**/v1/app/finance/summary**', async (route) => {
    if (fail) return route.fulfill({ status: 503, contentType: 'application/json', body: JSON.stringify({ success: false, error: { code: 'UNAVAILABLE' } }) })
    await new Promise((resolve) => setTimeout(resolve, 400))
    return route.continue()
  })
  await page.goto(MARCH)
  await expect(page.getByRole('alert')).toContainText('Tentar de novo')
  fail = false
  await page.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(page.getByRole('status').filter({ hasText: 'Carregando' })).toBeVisible()
  await expect(page.getByTestId('page-answer')).toHaveText('Em março entraram R$ 380,00')
})

test('vazio do mês: nada entrou e o texto da lista (fin.list.view)', async ({ page }) => {
  await openFinance(page, 'admin', 'finance?month=2020-01')
  await expect(page.getByTestId('page-answer')).toHaveText('Nada entrou em janeiro')
  await expect(page.getByTestId('fin-empty')).toHaveText('Nenhum pagamento em janeiro.')
  await page.getByTestId('fin-card-sold').click()
  await expect(page.getByTestId('fin-empty')).toHaveText('Nenhuma OS em janeiro.')
})

for (const theme of ['light', 'dark'] as const) {
  test(`axe: Resumo e Receber, tema ${theme === 'light' ? 'claro' : 'escuro'}`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: theme })
    await login(page, 'admin', 'login')
    await setTheme(page, theme)
    await page.goto(MARCH)
    await expect(page.getByTestId('fin-list')).toBeVisible()
    await expectNoAxeViolations(page, `resumo ${theme}`)
    await page.goto(`${MARCH}&list=receivable`)
    await expect(page.getByTestId('fin-list').getByRole('link').first()).toBeVisible()
    await expectNoAxeViolations(page, `a receber ${theme}`)
    await page.goto('finance/receive')
    await expect(page.getByTestId('finance-row').first()).toBeVisible()
    await expectNoAxeViolations(page, `receber ${theme}`)
  })
}

for (const [width, height] of [
  [320, 640],
  [2560, 1440],
] as const) {
  test(`${width} px sem rolagem lateral no Resumo e no Receber`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await login(page, 'admin', MARCH)
    await expect(page.getByTestId('fin-list')).toBeVisible()
    await expectNoSideScroll(page)
    await page.goto('finance/receive')
    await expect(page.getByTestId('finance-row').first()).toBeVisible()
    await expectNoSideScroll(page)
  })
}

for (const [width, height] of [
  [320, 640],
  [1366, 768],
] as const) {
  test(`texto a 200% em ${width} px no Resumo`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await login(page, 'admin', MARCH)
    await expect(page.getByTestId('fin-list')).toBeVisible()
    await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
    await expectNoSideScroll(page)
  })
}

for (const [language, received, sold, words] of [
  ['en', 'Received', 'Sold', 'came in'],
  ['es', 'Recibido', 'Vendido', 'entraron'],
] as const) {
  test(`idioma ${language}: Resumo`, async ({ page }) => {
    await login(page, 'admin', MARCH)
    await page.evaluate((value) => localStorage.setItem('praticos.prefs', JSON.stringify({ language: value })), language)
    await page.reload()
    await expect(page.getByTestId('fin-card-received')).toContainText(received)
    await expect(page.getByTestId('fin-card-sold')).toContainText(sold)
    // Money and dates follow the company's country (Brazil), words the language.
    await expect(page.getByTestId('page-answer')).toContainText(words)
    await expect(page.getByTestId('page-answer')).toContainText('R$ 380,00')
  })
}
