// Fatia 07, "Apagar minha conta": DELETE /v1/app/account on the accountApi
// function of the Emulator Suite (never a real project). Strong confirmation,
// the server's refusal when the owner has a team, re-authentication with the
// password when the server asks for a recent sign-in, and the real deletion.
import { expect, test, type Page } from './test'
import { COMPANY_A, COMPANY_D, PASSWORD, USERS } from './fixtures.mjs'
import { chooseCompany, login } from './helpers'
import { authUserExists, readPath } from './settings-data'

async function startDelete(page: Page, email: string) {
  await page.getByTestId('account-delete').click()
  await expect(page.getByTestId('delete-warn')).toContainText('Esta ação é permanente e não pode ser desfeita.')
  await page.getByTestId('delete-continue').click()
  const confirm = page.getByTestId('delete-confirm')
  await expect(confirm).toContainText('Esta é sua última chance de cancelar.')
  await expect(page.getByTestId('delete-final')).toBeDisabled()
  await confirm.getByLabel(`Para confirmar, escreva o seu e-mail: ${email}`).fill('outro@praticos.test')
  await expect(page.getByTestId('delete-final')).toBeDisabled()
  await confirm.getByLabel(`Para confirmar, escreva o seu e-mail: ${email}`).fill(email.toUpperCase())
  await expect(page.getByTestId('delete-final')).toBeEnabled()
}

test('Dono de empresa com equipe: o servidor recusa e nada é apagado (account.delete, account.deletion.flow)', async ({ page }) => {
  await login(page, 'owner')
  await chooseCompany(page, 'Oficina Alfa')
  await page.goto('settings/account')
  await startDelete(page, USERS.owner.email)
  await page.getByTestId('delete-final').click()
  await expect(page.getByTestId('delete-error')).toHaveText(/Você é dono de uma empresa com outras pessoas na equipe/)
  expect(await authUserExists(USERS.owner.uid)).toBe(true)
  expect(await readPath(`companies/${COMPANY_A}`)).toBeDefined()
  // Cancelar closes without deleting.
  await page.getByRole('button', { name: 'Cancelar' }).click()
  await expect(page.getByTestId('delete-confirm')).toHaveCount(0)
})

test('Login antigo: pede a senha, senha errada avisa, depois confirma de novo e apaga (account.deletion.reauth, account.deletion.password)', async ({ page }) => {
  test.setTimeout(60_000)
  let asked = 0
  // The answer the server gives to a sign-in older than 5 minutes, to the first
  // request and to the client's retry with a fresh token (lib/api.ts).
  await page.route('**/accountApi/v1/app/account', async (route) => {
    if (asked < 2 && route.request().method() === 'DELETE') {
      asked++
      return route.fulfill({ status: 401, contentType: 'application/json', body: JSON.stringify({ success: false, error: { code: 'REQUIRES_RECENT_LOGIN', message: 'x' } }) })
    }
    return route.continue()
  })
  await login(page, 'dAlone', 'settings/account')
  await expect(page.getByTestId('account-profile')).toBeVisible()
  await startDelete(page, USERS.dAlone.email)
  await page.getByTestId('delete-final').click()
  const reauth = page.getByTestId('delete-reauth')
  await expect(reauth).toContainText('você precisa fazer login novamente antes de deletar sua conta')
  await reauth.getByLabel('Senha').fill('senha-errada')
  await page.getByTestId('reauth-submit').click()
  await expect(page.getByTestId('reauth-error')).toHaveText('E-mail ou senha não conferem. Confira e tente de novo.')
  await reauth.getByLabel('Senha').fill(PASSWORD)
  await page.getByTestId('reauth-submit').click()
  // As the app: the final confirmation again, then the real deletion.
  await expect(page.getByTestId('delete-confirm')).toBeVisible()
  await page.getByTestId('delete-confirm').getByRole('textbox').fill(USERS.dAlone.email)
  const reloaded = page.waitForEvent('load')
  await page.getByTestId('delete-final').click()
  await reloaded
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
  await expect.poll(() => authUserExists(USERS.dAlone.uid), { timeout: 20_000 }).toBe(false)
  expect(await readPath(`users/${USERS.dAlone.uid}`)).toBeUndefined()
})

test('Dono sozinho: a conta e a empresa são apagadas no servidor e o navegador sai (account.delete)', async ({ page }) => {
  test.setTimeout(60_000)
  await login(page, 'dOwner', 'settings/account')
  await expect(page.getByTestId('account-company')).toHaveText('Delta Sozinha · Proprietário')
  await startDelete(page, USERS.dOwner.email)
  const reloaded = page.waitForEvent('load')
  await page.getByTestId('delete-final').click()
  await reloaded
  await expect(page.getByRole('button', { name: 'Continuar com Google' })).toBeVisible()
  await expect.poll(() => authUserExists(USERS.dOwner.uid), { timeout: 30_000 }).toBe(false)
  expect(await readPath(`companies/${COMPANY_D}`)).toBeUndefined()
})
