// Proves the suite really runs: the app's API call and the claims trigger go
// through the emulated Functions, not through mocks.
import { expect, test } from '@playwright/test'
import { getApps, initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { getFirestore } from 'firebase-admin/firestore'
import { COMPANY_A, PROJECT_ID } from './fixtures.mjs'
import { login } from './helpers'

const admin = () => getApps()[0] ?? initializeApp({ projectId: PROJECT_ID })

test('API responde pelo emulador, com Bearer e empresa, e o erro vira texto de i18n', async ({ page }) => {
  await login(page, 'admin', 'dev/components')
  await page.getByRole('button', { name: 'Chamar API' }).click()
  await expect(page.getByTestId('api-result')).toHaveText('Não encontramos isso. Pode ter sido apagado.')
})

test('gatilho de usuários grava o claim roles como no servidor', async () => {
  test.skip(!process.env.FIREBASE_AUTH_EMULATOR_HOST, 'só dentro do emulador')
  test.setTimeout(60_000)
  const auth = getAuth(admin())
  const db = getFirestore(admin())
  const uid = 'e2e-trigger-check'
  await auth.createUser({ uid, email: 'trigger@praticos.test' })
  await db.doc(`companies/${COMPANY_A}/private/membership`).set({ members: { [uid]: 'technician' } }, { merge: true })
  await db.doc(`users/${uid}`).set({ companies: [{ company: { id: COMPANY_A, name: 'Oficina Alfa' }, role: 'admin' }] })
  await expect
    .poll(async () => (await auth.getUser(uid)).customClaims?.roles, { timeout: 45_000, intervals: [500] })
    // The role comes from the server-only map, not from the user's own entry.
    .toEqual({ [COMPANY_A]: 'technician' })
})
