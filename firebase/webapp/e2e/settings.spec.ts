// Fatia 07: Configurações (rows by role), Sua conta (profile, photo, switch
// company, invite code, sign out) and Plano (read only), against the Emulator Suite.
import { expect, test, type Page } from './test'
import { COMPANY_B, COMPANY_G, USERS } from './fixtures.mjs'
import { chooseCompany, login, type UserKey } from './helpers'
import { readPath } from './settings-data'

// 1x1 PNG.
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64')
const toast = (page: Page) => page.locator('.toast')

// What each role finds in Configurações (settings.view and the settings.open-* rows).
const ROWS: Record<string, { shown: string[]; hidden: string[] }> = {
  gOwner: { shown: ['settings-account', 'settings-company', 'settings-team', 'settings-plan', 'settings-ratings', 'settings-integrations', 'settings-customers', 'settings-catalog', 'settings-checklists'], hidden: [] },
  gAdmin: { shown: ['settings-company', 'settings-team', 'settings-plan', 'settings-ratings', 'settings-integrations', 'settings-catalog', 'settings-checklists'], hidden: [] },
  gManager: { shown: ['settings-plan', 'settings-customers', 'settings-catalog'], hidden: ['settings-company', 'settings-team', 'settings-ratings', 'settings-integrations', 'settings-checklists'] },
  gTech: { shown: ['settings-account', 'settings-plan', 'settings-customers'], hidden: ['settings-company', 'settings-team', 'settings-ratings', 'settings-integrations', 'settings-catalog', 'settings-checklists'] },
  tSuper: { shown: ['settings-plan', 'settings-customers', 'settings-catalog', 'settings-checklists'], hidden: ['settings-company', 'settings-team', 'settings-ratings', 'settings-integrations'] },
}

for (const [user, { shown, hidden }] of Object.entries(ROWS)) {
  test(`${user}: Configurações mostra só o que o papel abre (settings.view, settings.open-account, settings.open-team, settings.open-plan, settings.open-catalog, settings.open-customers, settings.open-advanced)`, async ({ page }) => {
    await login(page, user as UserKey, 'settings')
    await expect(page.getByRole('heading', { level: 1, name: 'Configurações' })).toBeVisible()
    for (const id of shown) await expect(page.getByTestId(id)).toBeVisible()
    for (const id of hidden) await expect(page.getByTestId(id)).toHaveCount(0)
  })
}

test('Configurações: a linha da conta diz quem, empresa e papel, e cada linha abre a sua tela (settings.more-view, settings.more-page)', async ({ page }) => {
  await login(page, 'gAdmin', 'settings')
  await expect(page.getByTestId('settings-account')).toContainText('Gil Admin')
  await expect(page.getByTestId('settings-account')).toContainText('g-admin@praticos.test')
  await expect(page.getByTestId('settings-account')).toContainText('Oficina Gama · Administrador')
  for (const [id, title] of [
    ['settings-account', 'Sua conta'],
    ['settings-plan', 'Plano'],
    ['settings-integrations', 'Integrações'],
    ['settings-team', 'Equipe'],
    ['settings-catalog', 'Catálogo'],
  ] as const) {
    await page.goto('settings')
    await page.getByTestId(id).click()
    await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible()
  }
})

test('rodapé com a versão do web, para todos os papéis (settings.more-view)', async ({ page }) => {
  await login(page, 'gTech', 'settings')
  // Build day and commit of this build, as the app shows its version and build.
  await expect(page.getByTestId('settings-version')).toHaveText(/^PraticOS web \d{4}\.\d{2}\.\d{2} \([0-9a-z]+\)$/)
})

test('Sair pede confirmação (account.sign-out)', async ({ page }) => {
  await login(page, 'gTech', 'settings/account')
  await page.getByTestId('account-sign-out').click()
  const dialog = page.getByRole('dialog', { name: 'Deseja realmente sair?' })
  await dialog.getByRole('button', { name: 'Cancelar' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Sua conta' })).toBeVisible()
  const reloaded = page.waitForEvent('load')
  await page.getByTestId('account-sign-out').click()
  await page.getByRole('dialog', { name: 'Deseja realmente sair?' }).getByRole('button', { name: 'Sair' }).click()
  await reloaded
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
})

test('Sua conta: nome e foto só ao salvar, nome obrigatório, empresa · papel (account.view, account.edit-profile, profile.edit.save, profile.edit.photo)', async ({ page }) => {
  await login(page, 'gTech', 'settings/account')
  await expect(page.getByTestId('account-name')).toHaveText('Guto Tecnico')
  await expect(page.getByTestId('account-company')).toHaveText('Oficina Gama · Técnico')
  await page.getByTestId('account-profile').click()
  const form = page.getByTestId('profile-form')
  await expect(form).toContainText('Você entra com g-tech@praticos.test')
  await form.getByLabel('Nome', { exact: true }).fill(' ')
  await form.getByTestId('save-profile').click()
  await expect(form.getByText('Digite seu nome').first()).toBeVisible()
  await form.getByLabel('Nome', { exact: true }).fill('Guto Técnico Silva')
  await form.getByTestId('profile-photo-file').setInputFiles({ name: 'me.png', mimeType: 'image/png', buffer: PNG })
  await expect(form.getByTestId('profile-photo')).toBeVisible()
  expect((await readPath(`users/${USERS.gTech.uid}`))?.photo).toBeUndefined()
  await form.getByTestId('save-profile').click()
  await expect(toast(page)).toContainText('Perfil salvo')
  await expect(page.getByTestId('account-name')).toHaveText('Guto Técnico Silva')
  const user = (await readPath(`users/${USERS.gTech.uid}`))!
  expect(user.name).toBe('Guto Técnico Silva')
  expect(String(user.photo)).toContain(`tenants%2F${COMPANY_G}%2Fusers%2F${USERS.gTech.uid}%2Fphoto.jpg`)
  // Only the name and photo change: the companies list (the claim's source) stays.
  expect(user.companies).toEqual([{ company: { id: COMPANY_G, name: 'Oficina Gama' }, role: 'technician' }])
})

test('Sua conta: trocar de empresa não aparece com uma só (account.switch-company)', async ({ page }) => {
  await login(page, 'gManager', 'settings/account')
  await expect(page.getByTestId('account-profile')).toBeVisible()
  await expect(page.getByTestId('account-switch')).toHaveCount(0)
})

test('Dono de duas empresas troca pela conta e vai para a Início da outra (account.switch-company)', async ({ page }) => {
  await login(page, 'owner')
  await chooseCompany(page, 'Oficina Alfa')
  await page.goto('settings/account')
  await page.getByTestId('account-switch').click()
  const list = page.getByTestId('company-list')
  await expect(list.getByLabel(/Oficina Alfa/)).toBeChecked()
  await list.getByLabel(/Beta Repairs/).check()
  await page.getByTestId('switch-confirm').click()
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
  await expect(page.getByLabel('Empresa')).toHaveValue(COMPANY_B)
})

test('Entrar com código: confere o código, pergunta e entra na empresa nova (account.invite-code)', async ({ page }) => {
  test.setTimeout(60_000)
  await login(page, 'joiner', 'settings/account')
  await page.getByTestId('account-code').click()
  const dialog = page.getByRole('dialog', { name: 'Qual é o código do convite?' })
  await dialog.getByLabel('Digite o código do convite').fill('naoexiste')
  await dialog.getByTestId('code-submit').click()
  await expect(dialog.getByTestId('code-error')).toHaveText('Código não encontrado ou já usado. Confira com quem mandou.')
  // Lower case and without INV_: the same code (accept_invite_screen).
  await dialog.getByLabel('Digite o código do convite').fill('e2e_joiner_b')
  await dialog.getByTestId('code-submit').click()
  const confirm = page.getByRole('dialog', { name: 'Entrar na equipe de Beta Repairs?' })
  await expect(confirm).toContainText('Você entra como Técnico.')
  await confirm.getByRole('button', { name: 'Aceitar' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible({ timeout: 30_000 })
  await expect(page.getByLabel('Empresa')).toHaveValue(COMPANY_B)
  await expect.poll(async () => (await readPath(`companies/${COMPANY_B}/memberships/${USERS.joiner.uid}`))?.role).toBe('technician')
})

test.describe('Plano', () => {
  /** The one switch of the limits (config/paidPlans) on for this page only: other specs keep it off. */
  const paidPlansOn = (page: Page) =>
    page.route('**/documents:batchGet**', async (route) => {
      const name = /"(projects\/[^"]+\/documents\/config\/paidPlans)"/.exec(route.request().postData() ?? '')?.[1]
      if (!name) return route.fallback()
      const now = new Date().toISOString()
      await route.fulfill({
        contentType: 'application/json',
        body: JSON.stringify([{ found: { name, fields: { enabled: { booleanValue: true } }, createTime: now, updateTime: now }, readTime: now }]),
      })
    })

  test('Plano igual ao app: OS do mês, pessoas, CNPJs, aviso de 80% e o que o próximo plano dá, sem contador de IA (plan.view, plan.header-status, plan.usage-levels, #725)', async ({ page }) => {
    await paidPlansOn(page)
    await login(page, 'gManager', 'settings/plan')
    await expect(page.getByTestId('plan-header')).toHaveText(/^Starter · renova em \d{2}\/\d{2}\/\d{4}$/)
    const usage = page.getByTestId('plan-usage')
    await expect(usage.locator('li').first()).toHaveAttribute('data-usage', 'orders')
    await expect(usage.locator('[data-usage="orders"]')).toContainText('OS este mês')
    await expect(usage.locator('[data-usage="orders"]')).toContainText('45 de 50')
    await expect(usage.locator('[data-usage="orders"]')).toContainText('Quase no limite')
    // Members are recounted by the server (usersActive), above the 2 of Starter.
    await expect(usage.locator('[data-usage="people"]')).toContainText(/\d+ de 2/)
    await expect(usage.locator('[data-usage="people"]')).toContainText('No limite · conta o convite')
    await expect(usage.locator('[data-usage="taxIds"]')).toContainText('0 de 1')
    await expect(usage.locator('[data-usage="ai"]')).toHaveCount(0)
    await expect(page.getByTestId('plan-limit')).toHaveAttribute('data-notice', 'ordersNear')
    await expect(page.getByTestId('plan-limit')).toContainText('Você já abriu 45 de 50 OS este mês.')
    const next = page.getByTestId('plan-next')
    await expect(next).toContainText('O que o Pro dá a mais')
    await expect(next.locator('[data-feature="contracts"]')).toHaveText('Contratos')
    await expect(next.locator('[data-feature="workStages"]')).toHaveText('Etapas do serviço')
    // Nothing to buy and no row opens for a manager, who is told to ask (plan.non-admin-note).
    await expect(page.getByRole('button', { name: /plano/i })).toHaveCount(0)
    await expect(page.getByTestId('plan-ask-admin')).toHaveText('Peça ao administrador da conta para mudar de plano.')
    await expect(usage.getByRole('link')).toHaveCount(0)
  })

  test('Plano: dono abre Equipe pela linha de pessoas e lê onde mudar de plano (plan.open-limit)', async ({ page }) => {
    await login(page, 'gOwner', 'settings/plan')
    const usage = page.getByTestId('plan-usage')
    await expect(page.getByTestId('plan-where')).toHaveText('Para mudar de plano, use o app PraticOS no celular, na tela Plano.')
    await usage.locator('[data-usage="people"]').getByRole('link').click()
    await expect(page.getByRole('heading', { level: 1, name: 'Equipe' })).toBeVisible()
  })

  test('Plano sem limite mostra só os números; erro de leitura com "Tentar de novo" (plan.view)', async ({ page }) => {
    await login(page, 'technician', 'settings/plan')
    // Company A is on Business.
    await expect(page.getByTestId('plan-header')).toHaveText('Business')
    // Switch off (config/paidPlans): no limit, numbers only.
    await expect(page.getByTestId('plan-usage').locator('[data-usage="orders"]')).toContainText('Sem limite')
    await page.route('**/documents:batchGet**', (route) => route.abort())
    await page.getByRole('link', { name: 'Configurações' }).first().click()
    await page.getByTestId('settings-plan').click()
    await expect(page.getByRole('button', { name: 'Tentar de novo' })).toBeVisible()
  })
})
