// Entry rows of docs/web-app/parity-matrix.yaml: the login screen, sign-up
// refused, the first users/{uid} and the account's language, the invite code
// of the first access, accepting and refusing invites without a company,
// "Tentar de novo" when the account does not load, Avaliações, the plan note
// for who is not an administrator and the company options as the app reads them.
import { expect, test, type Page } from './test'
import { COMPANY_B, COMPANY_M, USERS } from './fixtures.mjs'
import { expectNoAxeViolations, login, signOut } from './helpers'
import { readPath } from './settings-data'

const openEmail = async (page: Page) => {
  await page.goto('login')
  await page.getByRole('button', { name: 'Já tenho conta com e-mail' }).click()
}

test('vindo do "Criar conta" do site: a mesma entrada, falando com quem é novo', async ({ page }) => {
  await page.goto('login?signup=1')
  await expect(page.getByRole('heading', { level: 1, name: 'Criar sua conta' })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
  await expect(page.getByTestId('login-legal').getByRole('link', { name: 'Termos de Uso' })).toBeVisible()
})

test('tela de entrada: e-mail validado antes de enviar, senha que se mostra, aviso de conta nova e Política de Privacidade (auth.login.view, auth.login.open-email, auth.email.signin, auth.email.toggle-password, auth.email.new-account-hint, auth.login.privacy)', async ({ page }) => {
  await page.goto('login')
  await expect(page.getByRole('heading', { level: 1, name: 'Entrar ou criar conta' })).toBeVisible()
  // Talks to who is new too (launch for everyone), not only to who has the phone app.
  await expect(page.getByText('Novo no PraticOS? Continue com o Google ou a Apple')).toBeVisible()
  const privacy = page.getByRole('link', { name: 'Política de Privacidade' })
  await expect(privacy).toHaveAttribute('href', '/privacy.html')
  await expect(privacy).toHaveAttribute('target', '_blank')
  const terms = page.getByTestId('login-legal').getByRole('link', { name: 'Termos de Uso' })
  await expect(terms).toHaveAttribute('href', '/terms.html')
  await expect(terms).toHaveAttribute('target', '_blank')
  await page.getByRole('button', { name: 'Já tenho conta com e-mail' }).click()
  await expect(page.getByTestId('new-account-hint')).toBeVisible()

  // E-mail without a dot: said on the screen, nothing sent to Auth.
  const signIns: string[] = []
  page.on('request', (request) => /accounts:signInWithPassword/.test(request.url()) && signIns.push(request.url()))
  await page.getByLabel('E-mail').fill('ana@oficina')
  await page.getByLabel('Senha').fill('qualquer')
  await page.getByRole('button', { name: 'Entrar', exact: true }).click()
  await expect(page.getByRole('alert')).toHaveText('Esse e-mail não parece certo. Confira.')
  expect(signIns).toEqual([])

  const password = page.getByLabel('Senha')
  await expect(password).toHaveAttribute('type', 'password')
  await page.getByRole('button', { name: 'Mostrar senha' }).click()
  await expect(password).toHaveAttribute('type', 'text')
  await expect(page.getByRole('button', { name: 'Ocultar senha' })).toHaveAttribute('aria-pressed', 'true')
  await page.getByRole('button', { name: 'Ocultar senha' }).click()
  await expect(password).toHaveAttribute('type', 'password')
  await expectNoAxeViolations(page, 'entrada com e-mail')
})

test('esqueceu a senha com o e-mail vazio ou errado diz no campo e não manda nada (auth.email.forgot)', async ({ page }) => {
  await openEmail(page)
  const resets: string[] = []
  page.on('request', (request) => /accounts:sendOobCode/.test(request.url()) && resets.push(request.url()))
  await page.getByRole('button', { name: 'Esqueceu a senha?' }).click()
  const dialog = page.getByRole('dialog')
  await dialog.getByRole('button', { name: 'Enviar' }).click()
  await expect(dialog.getByRole('alert')).toHaveText('Escreva o seu e-mail.')
  await expect(dialog.getByLabel('E-mail')).toHaveAttribute('aria-invalid', 'true')
  await dialog.getByLabel('E-mail').fill('ana')
  await dialog.getByRole('button', { name: 'Enviar' }).click()
  await expect(dialog.getByRole('alert')).toHaveText('Esse e-mail não parece certo. Confira.')
  expect(resets).toEqual([])
  await expect(dialog).toBeVisible()
})

/** The Auth emulator's sign-in page, in the same tab. Its form appears after its own script runs, so retry the click. */
async function signInOnEmulatorPage(tab: Page, email: string) {
  await tab.waitForLoadState('domcontentloaded')
  const add = tab.getByText('Add new account')
  const field = tab.getByLabel('Email')
  await expect(async () => {
    if (await add.isVisible()) await add.click()
    await expect(field).toBeVisible({ timeout: 1000 })
  }).toPass({ timeout: 20_000 })
  await field.fill(email)
  await tab.getByRole('button', { name: /Sign in with/ }).click()
}

test('cadastro recusado pelo servidor tem frase própria, não a do Google (auth.signup.blocked)', async ({ page }) => {
  test.setTimeout(60_000)
  await page.goto('login')
  await page.getByRole('button', { name: 'Continuar com Google' }).click()
  // Listed in config/signup.blockedEmails (seed.mjs): blockSuspiciousSignups refuses it.
  await signInOnEmulatorPage(page, 'robo.12345@gmail.com')
  await expect(page.getByRole('alert')).toHaveText(
    'O cadastro não foi aceito. Se você já tem conta, entre com ela; se não, fale com o suporte do PraticOS.',
    { timeout: 20_000 },
  )
  await expect(page.locator('.shell')).toHaveCount(0)
})

test('primeira entrada no web cria users/{uid} sem empresa e com o idioma do navegador (auth.session.user-bootstrap)', async ({ page }) => {
  expect(await readPath(`users/${USERS.fresh.uid}`)).toBeUndefined()
  await login(page, 'fresh')
  await expect(page.getByRole('heading', { level: 1, name: 'Qual é o seu ramo?' })).toBeVisible()
  await expect.poll(async () => readPath(`users/${USERS.fresh.uid}`)).toMatchObject({
    id: USERS.fresh.uid,
    email: USERS.fresh.email,
    companies: [],
    preferredLanguage: 'pt-BR',
  })
})

test('o idioma da conta vale num navegador onde ninguém escolheu (reminders.language)', async ({ page }) => {
  await login(page, 'polyglot', './', { followAccountLanguage: true })
  await expect(page.getByRole('heading', { level: 1, name: '¿Cuál es tu rubro?' })).toBeVisible()
})

test('trocar o idioma grava na conta, como o app (reminders.language)', async ({ page }) => {
  await login(page, 'gTech', 'settings')
  await page.getByLabel('Idioma').selectOption('en')
  await expect(page.getByRole('heading', { level: 1, name: 'Settings' })).toBeVisible()
  await expect.poll(async () => (await readPath(`users/${USERS.gTech.uid}`))?.preferredLanguage).toBe('en-US')
  await page.getByLabel('Language').selectOption('pt')
  await expect.poll(async () => (await readPath(`users/${USERS.gTech.uid}`))?.preferredLanguage).toBe('pt-BR')
})

test('primeiro acesso: "Recebi um código de convite", código errado, buscar outro e entrar (onboarding.segment.have-invite, onboarding.code.lookup, onboarding.code.search-again, onboarding.code.accept, onboarding.invites.error-map)', async ({ page }) => {
  test.setTimeout(60_000)
  await login(page, 'codeNew')
  await expect(page.getByRole('heading', { level: 1, name: 'Qual é o seu ramo?' })).toBeVisible()
  await page.getByRole('button', { name: 'Recebi um código de convite' }).click()
  const dialog = page.getByRole('dialog', { name: 'Qual é o código do convite?' })
  await dialog.getByTestId('code-submit').click()
  await expect(dialog.getByTestId('code-error')).toHaveText('Digite o código do convite')
  await dialog.getByLabel('Digite o código do convite').fill('naoexiste')
  await page.keyboard.press('Enter')
  await expect(dialog.getByTestId('code-error')).toHaveText('Código não encontrado ou já usado. Confira com quem mandou.')
  // Lower case and without INV_: the same code.
  await dialog.getByLabel('Digite o código do convite').fill(' e2e_code_new ')
  await page.keyboard.press('Enter')
  const join = page.getByRole('dialog', { name: 'Entrar na equipe de Beta Repairs?' })
  await expect(join).toContainText('Você entra como Técnico.')
  await join.getByRole('button', { name: 'Buscar outro código' }).click()
  await expect(dialog.getByLabel('Digite o código do convite')).toHaveValue('')
  await dialog.getByLabel('Digite o código do convite').fill('INV_E2E_CODE_NEW')
  await page.keyboard.press('Enter')
  await join.getByRole('button', { name: 'Aceitar' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible({ timeout: 30_000 })
  await expect.poll(async () => (await readPath(`companies/${COMPANY_B}/memberships/${USERS.codeNew.uid}`))?.role).toBe('technician')
})

test('sem empresa: aceitar o convite da lista entra direto na empresa (onboarding.invites.list, onboarding.invites.detail, onboarding.invites.accept, auth.gate.after-invite)', async ({ page }) => {
  test.setTimeout(60_000)
  await login(page, 'firstAccept')
  const invites = page.getByRole('region', { name: 'Convites Pendentes' })
  await expect(invites.getByText('Beta Repairs')).toBeVisible()
  await expect(invites.getByText('Técnico · Convidado por Olivia Dona')).toBeVisible()
  await invites.getByRole('button', { name: 'Aceitar' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible({ timeout: 30_000 })
  await expect(page.getByRole('complementary', { name: 'Navegação' })).toContainText('Beta Repairs')
})

test('recusar convite pergunta com o nome da empresa e só some depois de gravar (onboarding.invites.reject)', async ({ page }) => {
  await login(page, 'rejecter')
  const invites = page.getByRole('region', { name: 'Convites Pendentes' })
  await invites.getByRole('button', { name: 'Recusar Convite' }).click()
  const confirm = page.getByRole('dialog', { name: 'Tem certeza que deseja recusar o convite de Beta Repairs?' })
  await confirm.getByRole('button', { name: 'Voltar' }).click()
  await expect(invites.getByText('Beta Repairs')).toBeVisible()
  expect((await readPath('links/invites/tokens/INV_E2E_REJECT_B'))?.status).toBe('pending')
  await invites.getByRole('button', { name: 'Recusar Convite' }).click()
  await confirm.getByRole('button', { name: 'Recusar' }).click()
  await expect(page.getByText('Convite recusado')).toBeVisible()
  await expect(page.getByRole('region', { name: 'Convites Pendentes' })).toHaveCount(0)
  expect((await readPath('links/invites/tokens/INV_E2E_REJECT_B'))?.status).toBe('rejected')
})

test('com convite pendente, "Tenho outro código" abre o código (onboarding.invites.other-code)', async ({ page }) => {
  await login(page, 'newcomer')
  await expect(page.getByRole('region', { name: 'Convites Pendentes' })).toBeVisible()
  await page.getByRole('button', { name: 'Tenho outro código' }).click()
  await expect(page.getByRole('dialog', { name: 'Qual é o código do convite?' })).toBeVisible()
  await expectNoAxeViolations(page, 'código do convite')
})

test('a conta não carregou: "Tentar de novo" lê de novo e segue, nunca cria empresa sozinha (auth.gate.retry)', async ({ page }) => {
  let failed = false
  await page.route('**/documents:batchGet**', (route) => {
    if (!failed && (route.request().postData() ?? '').includes(`users/${USERS.noCompany.uid}`)) {
      failed = true
      return route.abort()
    }
    return route.fallback()
  })
  await login(page, 'noCompany')
  await expect(page.getByRole('alert')).toHaveText('Algo deu errado. Tente de novo em instantes.')
  await page.getByTestId('account-retry').click()
  await expect(page.getByRole('heading', { level: 1, name: 'Qual é o seu ramo?' })).toBeVisible()
})

test('Início no celular: o filtro escolhido aparece na linha que rola de lado (home.filter.scroll)', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 800 })
  await login(page, 'admin', './?f=done')
  const row = page.getByRole('group', { name: 'Filtros' })
  const chosen = row.getByRole('button', { name: 'Concluídas', pressed: true })
  await expect(chosen).toBeVisible()
  await expect(async () => {
    const [box, area] = await Promise.all([chosen.boundingBox(), row.boundingBox()])
    expect(box && area && box.x >= area.x - 1 && box.x + box.width <= area.x + area.width + 1).toBe(true)
  }).toPass()
  expect(await row.evaluate((element) => element.scrollWidth > element.clientWidth)).toBe(true)
})

test('Início no celular: o botão do perfil abre Clientes, Catálogo, Equipe e Ajustes (home.profile.open)', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 800 })
  await login(page, 'admin')
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
  await page.getByTestId('profile-button').click()
  await expect(page.getByRole('heading', { level: 1, name: 'Configurações' })).toBeVisible()
  for (const id of ['settings-customers', 'settings-catalog', 'settings-team', 'settings-company']) await expect(page.getByTestId(id)).toBeVisible()
  await page.getByTestId('settings-customers').click()
  await expect(page).toHaveURL(/\/web\/customers$/)
})

test('busca nas mais antigas traz a OS que não estava carregada (home.search.older)', async ({ page }) => {
  await login(page, 'admin', './?f=all')
  await expect(page.getByTestId('orders-table')).toBeVisible()
  await page.getByLabel(/^Buscar OS/).fill('9101')
  const row = page.getByTestId('orders-table').locator('.c-num', { hasText: /^9101$/ })
  const older = page.getByRole('button', { name: 'Buscar nas mais antigas' })
  // The end of the list in view also loads the next page by itself (watchListEnd): the
  // order can arrive while the button is being clicked, and the button then leaves the
  // screen. Click it only while the order is not there yet, and never wait on a button gone.
  await expect(async () => {
    if (!(await row.isVisible()) && (await older.isEnabled().catch(() => false))) await older.click({ timeout: 1000 }).catch(() => {})
    await expect(row).toBeVisible({ timeout: 1000 })
  }).toPass()
})

test.describe('Avaliações', () => {
  test('média, últimas primeiro e a linha abre a OS (settings.open-ratings, ratings.view, ratings.open)', async ({ page }) => {
    await login(page, 'maintOwner', 'settings')
    await page.getByTestId('settings-ratings').click()
    await expect(page.getByRole('heading', { level: 1, name: 'Avaliações' })).toBeVisible()
    await expect(page.getByTestId('ratings-summary')).toContainText('4,5 de 5')
    await expect(page.getByTestId('ratings-summary')).toContainText('média de 2 avaliações')
    const rows = page.getByTestId('ratings-list').locator('li')
    await expect(rows).toHaveCount(2)
    await expect(rows.nth(0)).toContainText('Rui Avaliador')
    await expect(rows.nth(0)).toContainText('Sem comentário · OS 9302')
    await expect(rows.nth(1)).toContainText('Rui A.')
    await expect(rows.nth(1)).toContainText('“Serviço rápido” · OS 9301')
    await expectNoAxeViolations(page, 'avaliações')
    await rows.nth(1).getByRole('button').click()
    await expect(page).toHaveURL(/\/web\/\?order=rated-5/)
    await expect(page.getByRole('complementary', { name: 'OS aberta' })).toContainText('9301')
  })

  test('sem avaliação explica de onde ela vem', async ({ page }) => {
    await login(page, 'gOwner', 'settings/ratings')
    await expect(page.getByTestId('ratings-empty')).toContainText('Nenhuma avaliação ainda')
    await expect(page.getByTestId('ratings-empty')).toContainText('pelo link da OS')
  })

  test('quem não administra não vê a linha nem abre pela URL', async ({ page }) => {
    await login(page, 'maintTech', 'settings')
    await expect(page.getByRole('heading', { level: 1, name: 'Configurações' })).toBeVisible()
    await expect(page.getByTestId('settings-ratings')).toHaveCount(0)
    await page.goto('settings/ratings')
    await expect(page.getByRole('heading', { name: 'Você não tem acesso a esta tela' })).toBeVisible()
  })
})

test('Plano: quem não é administrador lê "Peça ao administrador"; o dono não (plan.non-admin-note)', async ({ page }) => {
  await login(page, 'maintTech', 'settings/plan')
  await expect(page.getByTestId('plan-ask-admin')).toHaveText('Peça ao administrador da conta para mudar de plano.')
  await page.goto('settings')
  await signOut(page)
  await login(page, 'maintOwner', 'settings/plan')
  await expect(page.getByTestId('plan-usage')).toBeVisible()
  await expect(page.getByTestId('plan-ask-admin')).toHaveCount(0)
})

test('empresa sem as opções gravadas: Agenda ligada e Atendimento no local pelo ramo, como o app (auth.gate.feature-defaults)', async ({ page }) => {
  const company = await readPath(`companies/${COMPANY_M}`)
  expect(company?.useScheduling).toBeUndefined()
  expect(company?.fieldService).toBeUndefined()
  await login(page, 'maintOwner', 'settings/company')
  const sw = (feature: string) => page.getByTestId(`company-${feature}`).getByRole('switch')
  await expect(sw('useScheduling')).toBeChecked()
  // Mecânica is a workshop (segments/automotive.fieldService: false).
  await expect(sw('fieldService')).not.toBeChecked()
  await expect(sw('useContracts')).not.toBeChecked()
})
