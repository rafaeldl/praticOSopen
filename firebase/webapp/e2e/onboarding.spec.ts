// First access on the web (docs/ONBOARDING.md, fatia 01): Ramo → [Especialidades]
// → Para o cliente → Início, the company created with the app's batch and the
// segment's checklists and samples by the server. Each test that creates a
// company has its own account (fixtures.mjs: founder*).
import { expect, test, type Page } from '@playwright/test'
import { companiesOwnedBy } from './data'
import { expectNoAxeViolations, expectNoSideScroll, login, setTheme, signOut } from './helpers'

const heading = (page: Page, name: string) => page.getByRole('heading', { level: 1, name })

test('primeiro acesso com exemplos: ramo, especialidades, para o cliente e Início com as OS de exemplo', async ({ page }) => {
  test.setTimeout(90_000)
  await login(page, 'founder')
  await expect(heading(page, 'Qual é o seu ramo?')).toBeVisible()
  await expect(page).toHaveURL(/\/start$/)
  const list = page.getByRole('list', { name: 'Qual é o seu ramo?' })
  await expect(list.getByRole('button')).toHaveText([/Eletrônica/, /Mecânica/])
  await expect(page.getByText('Ramo desligado')).toHaveCount(0)

  await list.getByRole('button', { name: /Mecânica/ }).click()
  await expect(heading(page, 'O que você atende?')).toBeVisible()
  await expect(page.getByRole('checkbox', { name: 'Mecânica geral' })).toBeChecked()
  await expect(page.getByRole('checkbox', { name: 'Funilaria' })).toBeChecked()
  await page.getByRole('checkbox', { name: 'Funilaria' }).uncheck()
  await page.getByRole('button', { name: 'Continuar' }).click()

  await expect(heading(page, 'Para o cliente')).toBeVisible()
  await expect(page.getByRole('switch', { name: 'Valores e cobrança' })).toBeChecked()
  // The browser's Back goes one step back and keeps what was chosen (onboarding.flow.back).
  await page.goBack()
  await expect(heading(page, 'O que você atende?')).toBeVisible()
  await expect(page.getByRole('checkbox', { name: 'Funilaria' })).not.toBeChecked()
  await page.getByRole('button', { name: 'Continuar' }).click()

  await page.getByLabel('Nome que aparece na OS').fill('Oficina do Fábio')
  await page.getByLabel('Telefone (opcional)').pressSequentially('11987654321')
  await expect(page.getByLabel('Telefone (opcional)')).toHaveValue('(11) 98765-4321')
  await page.getByRole('button', { name: 'Criar meu PraticOS' }).click()
  await expect(page.getByText('Preparando seu PraticOS…')).toBeVisible()

  await expect(heading(page, 'Início')).toBeVisible({ timeout: 45_000 })
  await expect(page.getByTestId('orders-table').getByText('Cliente (Exemplo)').first()).toBeVisible({ timeout: 15_000 })
  await expect(page.getByTestId('company-initials')).toHaveText('OF')

  const [company, ...others] = await companiesOwnedBy('founder')
  expect(others).toEqual([])
  expect(company!.data).toMatchObject({
    name: 'Oficina do Fábio',
    phone: '(11) 98765-4321',
    segment: 'automotive',
    subspecialties: ['mechanical'],
    useScheduling: true,
    fieldService: true,
    useFinancial: true,
    country: 'BR',
    termsOfService: 'Garantia de 90 dias.',
  })
  // Checklists of the segment, samples only of the picked specialty, four orders.
  // (The checklist tests may add ready-made ones to the segment meanwhile.)
  expect(company!.forms).toEqual(expect.arrayContaining(['seg-entrada', 'seg-final', 'seg-import']))
  expect(company!.services).toEqual(['Troca de óleo (exemplo)'])
  expect(company!.customers).toEqual(['Cliente (Exemplo)'])
  expect(company!.orders).toBe(4)
})

test('começar sem exemplos: só os checklists, e a Início abre em "Comece por aqui"', async ({ page }) => {
  test.setTimeout(90_000)
  await login(page, 'founderLean')
  await page.getByRole('list', { name: 'Qual é o seu ramo?' }).getByRole('button', { name: /Eletrônica/ }).click()
  // No specialties in this segment: straight to the last step, values off as the segment says.
  await expect(heading(page, 'Para o cliente')).toBeVisible()
  await expect(page.getByRole('switch', { name: 'Valores e cobrança' })).not.toBeChecked()
  // Name left blank: the person's own name goes on the order.
  await page.getByRole('button', { name: 'Começar sem exemplos' }).click()

  await expect(heading(page, 'Início')).toBeVisible({ timeout: 45_000 })
  const firstRun = page.getByTestId('first-run')
  await expect(firstRun.getByRole('heading', { name: 'Comece por aqui' })).toBeVisible()
  await expect(firstRun.getByText('Escolha o cliente')).toBeVisible()
  await firstRun.getByRole('button', { name: 'Nova OS' }).click()
  await expect(page.getByRole('dialog')).toBeVisible()

  const [company] = await companiesOwnedBy('founderLean')
  expect(company!.data).toMatchObject({ name: 'Lia Sem Exemplos', segment: 'electronics', subspecialties: null, useFinancial: false })
  expect(company!.data.phone).toBeUndefined()
  expect(company!.services).toEqual([])
  expect(company!.orders).toBe(0)
})

test('sem nome na conta o nome é obrigatório; a falha volta ao formulário e tentar de novo não cria outra empresa', async ({ page }) => {
  test.setTimeout(120_000)
  await login(page, 'founderNoName')
  await page.getByRole('list', { name: 'Qual é o seu ramo?' }).getByRole('button', { name: /Mecânica/ }).click()
  await page.getByRole('button', { name: 'Continuar' }).click()
  await page.getByRole('button', { name: 'Criar meu PraticOS' }).click()
  await expect(page.getByText('Escreva o nome que aparece na OS.')).toBeVisible()
  await expect(page.getByLabel('Nome que aparece na OS')).toBeFocused()
  await page.getByLabel('Nome que aparece na OS').fill('Oficina Sem Nome')

  // The server does not answer: the company is saved, the samples are not.
  await page.route('**/v1/app/onboarding/seed', (route) => route.abort())
  await page.getByRole('button', { name: 'Criar meu PraticOS' }).click()
  await expect(page.getByText('Não deu para terminar. Confira a internet e tente de novo.')).toBeVisible({ timeout: 45_000 })
  // Back goes to the form with what was typed, not to the previous step.
  await page.getByRole('button', { name: '‹ Para o cliente' }).click()
  await expect(page.getByLabel('Nome que aparece na OS')).toHaveValue('Oficina Sem Nome')
  await page.getByRole('button', { name: 'Criar meu PraticOS' }).click()
  await expect(page.getByRole('button', { name: 'Tentar de novo' })).toBeVisible({ timeout: 45_000 })

  await page.unroute('**/v1/app/onboarding/seed')
  await page.getByRole('button', { name: 'Tentar de novo' }).click()
  await expect(heading(page, 'Início')).toBeVisible({ timeout: 45_000 })
  const companies = await companiesOwnedBy('founderNoName')
  expect(companies).toHaveLength(1)
  expect(companies[0]!.data.name).toBe('Oficina Sem Nome')
  expect(companies[0]!.orders).toBe(4)
})

test('com convite pendente, o convite vem antes; "Começar sem convite" abre o primeiro acesso e "Sair" sai', async ({ page }) => {
  await login(page, 'newcomer')
  await expect(page.getByRole('region', { name: 'Convites Pendentes' }).getByText('Oficina Alfa')).toBeVisible()
  await expect(page).toHaveURL(/no-company$/)
  await page.getByTestId('start-without-invite').click()
  await expect(heading(page, 'Qual é o seu ramo?')).toBeVisible()
  await signOut(page)
})

test('fora da lista de acesso, sem empresa, não chega ao primeiro acesso', async ({ page }) => {
  await login(page, 'strangerNew')
  await expect(heading(page, 'O PraticOS no computador ainda não foi liberado para você')).toBeVisible()
  await page.goto('start')
  await expect(heading(page, 'O PraticOS no computador ainda não foi liberado para você')).toBeVisible()
  expect(await companiesOwnedBy('strangerNew')).toEqual([])
})

async function steps(page: Page, check: (label: string) => Promise<void>) {
  await expect(heading(page, 'Qual é o seu ramo?')).toBeVisible()
  await expect(page.getByRole('list', { name: 'Qual é o seu ramo?' })).toBeVisible()
  await check('ramo')
  await page.getByRole('list', { name: 'Qual é o seu ramo?' }).getByRole('button', { name: /Mecânica/ }).click()
  await expect(heading(page, 'O que você atende?')).toBeVisible()
  await check('especialidades')
  await page.getByRole('button', { name: 'Continuar' }).click()
  await expect(heading(page, 'Para o cliente')).toBeVisible()
  await check('para o cliente')
}

for (const theme of ['light', 'dark'] as const) {
  test(`axe: 0 violações no primeiro acesso, tema ${theme === 'light' ? 'claro' : 'escuro'}`, async ({ page }) => {
    await page.emulateMedia({ colorScheme: theme })
    await login(page, 'noCompany')
    await setTheme(page, theme)
    await steps(page, (label) => expectNoAxeViolations(page, `${label} ${theme}`))
  })
}

for (const [width, height, zoom] of [
  [320, 640, false],
  [2560, 1440, false],
  [320, 640, true],
  [1366, 768, true],
] as const) {
  test(`${width} px${zoom ? ' e texto a 200%' : ''}: primeiro acesso sem rolagem lateral`, async ({ page }) => {
    await page.setViewportSize({ width, height })
    await login(page, 'noCompany')
    await steps(page, async () => {
      if (zoom) await page.addStyleTag({ content: 'html { font-size: 200% !important; }' })
      await expectNoSideScroll(page)
    })
  })
}

for (const [language, title, specialties, business, create] of [
  ['en', "What's your line of work?", 'What do you work on?', 'For your customers', 'Create my PraticOS'],
  ['es', '¿Cuál es tu rubro?', '¿Qué atiendes?', 'Para tus clientes', 'Crear mi PraticOS'],
] as const) {
  test(`idioma ${language}: textos do primeiro acesso`, async ({ page }) => {
    await login(page, 'noCompany')
    await page.evaluate((value) => localStorage.setItem('praticos.prefs', JSON.stringify({ language: value })), language)
    await page.reload()
    await expect(heading(page, title)).toBeVisible()
    await page.getByRole('list', { name: title }).getByRole('button', { name: language === 'en' ? /Auto repair/ : /Mecánica/ }).click()
    await expect(heading(page, specialties)).toBeVisible()
    await expect(page.getByRole('checkbox', { name: language === 'en' ? 'Bodywork' : 'Chapa' })).toBeChecked()
    await page.getByRole('button', { name: language === 'en' ? 'Continue' : 'Continuar' }).click()
    await expect(heading(page, business)).toBeVisible()
    await expect(page.getByRole('button', { name: create })).toBeVisible()
  })
}
