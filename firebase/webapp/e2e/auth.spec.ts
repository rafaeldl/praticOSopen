import { expect, test, type Page } from '@playwright/test'
import { PASSWORD, USERS } from './fixtures.mjs'
import { chooseCompany, login } from './helpers'

test('entra com e-mail e vê a casca', async ({ page }) => {
  await login(page, 'admin')
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
  await expect(page.getByRole('complementary', { name: 'Navegação' })).toBeVisible()
  await expect(page.getByText('Oficina Alfa')).toBeVisible()
  await expect(page).toHaveTitle(/Início · PraticOS/)
})

test('senha errada explica sem mostrar erro técnico', async ({ page }) => {
  await page.goto('./')
  await page.getByRole('button', { name: 'Já tenho conta com e-mail' }).click()
  await page.getByLabel('E-mail').fill(USERS.admin.email)
  await page.getByLabel('Senha').fill(`${PASSWORD}-errada`)
  await page.getByRole('button', { name: 'Entrar', exact: true }).click()
  await expect(page.getByRole('alert')).toHaveText('E-mail ou senha não conferem. Confira e tente de novo.')
  await expect(page.locator('body')).not.toContainText('auth/')
})

test('sem entrar, URL direta pede login e volta para onde ia', async ({ page }) => {
  await page.goto('customers')
  await expect(page).toHaveURL(/login\?next=\/customers/)
  await expect(page.locator('.shell')).toHaveCount(0)
  await page.getByRole('button', { name: 'Já tenho conta com e-mail' }).click()
  await page.getByLabel('E-mail').fill(USERS.admin.email)
  await page.getByLabel('Senha').fill(PASSWORD)
  await page.getByRole('button', { name: 'Entrar', exact: true }).click()
  await expect(page).toHaveURL(/\/app\/customers$/)
})

test('next externo não sai do app', async ({ page }) => {
  await page.goto('login?next=//example.test/x')
  await page.getByRole('button', { name: 'Já tenho conta com e-mail' }).click()
  await page.getByLabel('E-mail').fill(USERS.admin.email)
  await page.getByLabel('Senha').fill(PASSWORD)
  await page.getByRole('button', { name: 'Entrar', exact: true }).click()
  await expect(page).toHaveURL(/127\.0\.0\.1:\d+\/app\/$/)
})

test('conta sem empresa vê a explicação e pode sair', async ({ page }) => {
  await login(page, 'noCompany')
  await expect(page.getByRole('heading', { level: 1, name: 'Sua conta ainda não está em uma empresa' })).toBeVisible()
  await expect(page).toHaveURL(/no-company/)
  await page.getByRole('button', { name: 'Sair' }).click()
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
})

test('dono de duas empresas troca, e a moeda segue a empresa', async ({ page }) => {
  await login(page, 'owner', 'dev/components')
  await chooseCompany(page, 'Oficina Alfa')
  await expect(page).toHaveURL(/dev\/components$/)
  await expect(page.getByTestId('money-value')).toHaveText('90')
  await expect(page.locator('.money-symbol')).toHaveText('R$')
  await page.getByLabel('Empresa').selectOption({ label: 'Beta Repairs' })
  await expect(page.locator('.money-symbol')).toHaveText('$')
  await expect(page.getByLabel('Preço')).toHaveValue('90.00')
})

test('escolha de empresa fica lembrada neste navegador', async ({ page }) => {
  await login(page, 'owner')
  await chooseCompany(page, 'Beta Repairs')
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
  await expect(page.getByLabel('Empresa')).toHaveValue('company-beta')
  await page.reload()
  await expect(page.getByRole('heading', { level: 1, name: 'Início' })).toBeVisible()
  await expect(page.getByLabel('Empresa')).toHaveValue('company-beta')
})

test('esqueceu a senha manda o e-mail pelo Auth', async ({ page }) => {
  await page.goto('login')
  await page.getByRole('button', { name: 'Já tenho conta com e-mail' }).click()
  await page.getByLabel('E-mail').fill(USERS.admin.email)
  await page.getByRole('button', { name: 'Esqueceu a senha?' }).click()
  await page.getByRole('dialog').getByRole('button', { name: 'Enviar' }).click()
  await expect(page.getByText('E-mail enviado. Verifique sua caixa de entrada para redefinir sua senha.')).toBeVisible()
})

/** The Auth emulator's sign-in page. Its form appears after its own script runs, so retry the click. */
async function signInOnEmulatorPopup(popup: Page, email: string) {
  await popup.waitForLoadState('domcontentloaded')
  const add = popup.getByText('Add new account')
  const field = popup.getByLabel('Email')
  await expect(async () => {
    if (await add.isVisible()) await add.click()
    await expect(field).toBeVisible({ timeout: 1000 })
  }).toPass({ timeout: 20_000 })
  await field.fill(email)
  await popup.getByRole('button', { name: /Sign in with/ }).click()
}

test('Google pelo popup do emulador cria a conta e cai na lista de acesso', async ({ page }) => {
  test.setTimeout(60_000)
  await page.goto('login')
  const popupPromise = page.waitForEvent('popup')
  await page.getByRole('button', { name: 'Continuar com Google' }).click()
  await signInOnEmulatorPopup(await popupPromise, 'novo-google@praticos.test')
  await expect(page.getByRole('heading', { level: 1, name: /ainda não foi liberado/ })).toBeVisible()
  await expect(page.locator('.shell')).toHaveCount(0)
})

test('Apple pelo popup do emulador', async ({ page }) => {
  test.setTimeout(60_000)
  await page.goto('login')
  const popupPromise = page.waitForEvent('popup')
  await page.getByRole('button', { name: 'Continuar com Apple' }).click()
  await signInOnEmulatorPopup(await popupPromise, 'novo-apple@praticos.test')
  await expect(page.getByRole('heading', { level: 1, name: /ainda não foi liberado/ })).toBeVisible()
})

test('fechar o popup não é erro', async ({ page }) => {
  await page.goto('login')
  const popupPromise = page.waitForEvent('popup')
  await page.getByRole('button', { name: 'Continuar com Google' }).click()
  await (await popupPromise).close()
  // Firebase notices the closed window by polling, a few seconds later.
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeEnabled({ timeout: 20_000 })
  await expect(page.getByRole('alert')).toHaveCount(0)
})

test('fora da lista de acesso: tela simples, sem casca nem dados', async ({ page }) => {
  await login(page, 'outsider', 'orders')
  await expect(page.getByRole('heading', { level: 1, name: 'O PraticOS no computador ainda não foi liberado para você' })).toBeVisible()
  await expect(page.locator('.shell')).toHaveCount(0)
  await page.goto('settings')
  await expect(page).toHaveURL(/not-allowed/)
})

test('sair limpa a sessão', async ({ page }) => {
  await login(page, 'admin', 'settings')
  await page.getByRole('button', { name: 'Sair' }).click()
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
  // The guard may redirect to /login while the navigation is still loading,
  // which aborts goto(); the URL check below is what matters.
  await page.goto('orders').catch((error: Error) => {
    if (!error.message.includes('ERR_ABORTED')) throw error
  })
  await expect(page).toHaveURL(/login/)
})

test('na lista, mas sem confirmar o e-mail: a tela diz o que falta', async ({ page }) => {
  await login(page, 'unverified')
  await expect(page.getByRole('heading', { level: 1, name: 'Falta confirmar o seu e-mail' })).toBeVisible()
  await page.getByRole('button', { name: 'Mandar o e-mail de novo' }).click()
  await expect(page.getByText('E-mail de confirmação enviado')).toBeVisible()
})
