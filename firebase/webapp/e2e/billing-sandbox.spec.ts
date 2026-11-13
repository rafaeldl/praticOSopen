// Web checkout against the REAL Asaas sandbox and RevenueCat (issue #664,
// docs/WEB_CHECKOUT.md "Teste ponta a ponta no sandbox"). Skipped unless
// E2E_BILLING_SANDBOX=1, which makes e2e/run.mjs load ~/.praticos-sandbox.env:
//
//   E2E_BILLING_SANDBOX=1 PW_ARGS=e2e/billing-sandbox.spec.ts npm run e2e
//
// The Functions emulator runs the real code with the sandbox keys. Asaas cannot
// reach localhost, so the test posts to /webhooks/asaas-billing what Asaas would
// send, built from the real payment it reads back from the sandbox. The only
// RevenueCat app user touched is COMPANY_W (a test id); its promotionals are
// revoked at the end, even after a failure. BILLING_SHOTS=<folder> saves screens.
import { getApps, initializeApp } from 'firebase-admin/app'
import { getFirestore } from 'firebase-admin/firestore'
import { expect, test, type Page } from './test'
import { login } from './helpers'
import { COMPANY_W, PASSWORD, PROJECT_ID, USERS } from './fixtures.mjs'

const ON = process.env.E2E_BILLING_SANDBOX === '1'
const ASAAS = 'https://api-sandbox.asaas.com/v3'
const RC = 'https://api.revenuecat.com/v1'
const API = process.env.E2E_API_BASE ?? 'http://127.0.0.1:15001/demo-praticos/southamerica-east1/api'
const SHOTS = process.env.BILLING_SHOTS
const PLANS = ['starter', 'pro', 'business']

const shot = async (page: Page, name: string) => {
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/${name}.png`, fullPage: true })
}
const db = () => getFirestore(getApps()[0] ?? initializeApp({ projectId: PROJECT_ID }))

async function asaas(method: string, path: string) {
  const response = await fetch(`${ASAAS}${path}`, {
    method,
    headers: { access_token: process.env.ASAAS_BILLING_API_KEY ?? '', 'User-Agent': 'praticos-e2e', accept: 'application/json' },
  })
  if (!response.ok) throw new Error(`Asaas ${method} ${path.split('?')[0]} HTTP ${response.status}`)
  return response.json()
}

async function rc(method: string, path: string) {
  const response = await fetch(`${RC}${path}`, {
    method,
    headers: { Authorization: `Bearer ${process.env.REVENUECAT_SECRET_API_KEY ?? ''}`, 'Content-Type': 'application/json' },
  })
  if (!response.ok) throw new Error(`RevenueCat ${method} ${path.split('/').slice(0, 3).join('/')} HTTP ${response.status}`)
  return response.json()
}

const subscriber = async () => (await rc('GET', `/subscribers/${COMPANY_W}`)).subscriber
const activeEntitlements = async () => {
  const entitlements = (await subscriber()).entitlements ?? {}
  return Object.entries(entitlements)
    .filter(([, e]) => !(e as { expires_date?: string }).expires_date || Date.parse((e as { expires_date: string }).expires_date) > Date.now())
    .map(([name, e]) => ({ name, expires: (e as { expires_date?: string }).expires_date ?? null }))
}

async function webhook(event: string, payment: Record<string, unknown>, suffix = '') {
  const response = await fetch(`${API}/webhooks/asaas-billing`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'asaas-access-token': process.env.ASAAS_BILLING_WEBHOOK_TOKEN ?? '' },
    body: JSON.stringify({ id: `evt_e2e_${payment.id}_${event}${suffix}_${Date.now()}`, event, dateCreated: new Date().toISOString(), payment }),
  })
  expect(response.status, `webhook ${event}`).toBe(200)
  return (await response.json()).result as string
}

const record = async () => (await db().doc(`companies/${COMPANY_W}/private/webBilling`).get()).data() ?? {}
const companySubscription = async () => (await db().doc(`companies/${COMPANY_W}`).get()).get('subscription') ?? {}

test.describe('assinatura pela web no sandbox do Asaas', () => {
  test.skip(!ON, 'só com E2E_BILLING_SANDBOX=1 (chaves em ~/.praticos-sandbox.env)')
  test.setTimeout(6 * 60_000)

  test.beforeAll(async () => {
    // Only a test app user, never a real company: refuse one with store purchases.
    const subs = Object.values((await subscriber()).subscriptions ?? {}) as { store?: string }[]
    if (subs.some((s) => (s.store ?? '').toLowerCase() !== 'promotional')) throw new Error(`${COMPANY_W} tem compra de loja`)
    // NFS-e of the sandbox account: the "Licenciamento" service Asaas lists for its city.
    const [service] = (await asaas('GET', '/invoices/municipalServices?description=Licenciamento&limit=1')).data ?? []
    if (!service) throw new Error('sandbox sem serviço municipal de licenciamento')
    await db().doc('config/webCheckout').set({
      enabled: true,
      yearlyEnabled: true,
      invoice: { municipalServiceId: service.id, municipalServiceName: service.description, iss: 2 },
      // Pix in the monthly plan too, so the sandbox can confirm the payment without a card form.
      billingTypes: { monthly: ['CREDIT_CARD', 'PIX'], yearly: ['PIX', 'BOLETO', 'CREDIT_CARD'] },
    })
  })

  test.afterAll(async () => {
    for (const plan of PLANS) {
      await rc('POST', `/subscribers/${COMPANY_W}/entitlements/${plan}/revoke_promotionals`).catch(() => undefined)
    }
    const id = (await record()).asaasSubscriptionId as string | undefined
    if (id) await asaas('DELETE', `/subscriptions/${id}`).catch(() => undefined)
    await db().doc('config/webCheckout').delete()
    expect(await activeEntitlements()).toEqual([])
  })

  test('assinar, liberar, renovar, bloquear a segunda compra e devolver o dinheiro', async ({ page }) => {
    // 1. Checkout on the web → real subscription in the Asaas sandbox.
    await login(page, 'wOwner', 'settings/plan')
    await page.getByTestId('plan-billing-buy').click()
    await expect(page.getByTestId('billing-guarantee')).toContainText('Garantia de 7 dias')
    await page.getByTestId('billing-plan-pro').click()
    await page.getByTestId('billing-method-PIX').click()
    await page.getByTestId('billing-name').fill('Oficina Teste Sandbox')
    await page.getByTestId('billing-taxid').fill('11.222.333/0001-81')
    await page.getByTestId('billing-email').fill('sandbox@example.com')
    await page.getByTestId('billing-cep').fill('88015-100')
    await page.getByTestId('billing-number').fill('100')
    await shot(page, 'sandbox-1-checkout')
    await page.getByTestId('billing-pay').click()
    await page.waitForURL(/sandbox\.asaas\.com\/i\//, { timeout: 60_000 })
    await page.waitForLoadState('networkidle').catch(() => undefined)
    await shot(page, 'sandbox-2-fatura-asaas')

    const pending = await record()
    expect(pending).toMatchObject({ status: 'pending', plan: 'pro', cycle: 'monthly', billingType: 'PIX', environment: 'sandbox', value: 119.9 })
    const subscriptionId = pending.asaasSubscriptionId as string
    const subscription = await asaas('GET', `/subscriptions/${subscriptionId}`)
    expect(subscription).toMatchObject({ value: 119.9, cycle: 'MONTHLY', billingType: 'PIX', externalReference: COMPANY_W })
    // Rafsoft's NFS-e is set on the subscription, issued when each charge is paid.
    expect(pending.invoiceSettings).toBe('ok')
    expect(await asaas('GET', `/subscriptions/${subscriptionId}/invoiceSettings`)).toMatchObject({ invoiceCreationPeriod: 'ON_PAYMENT_CONFIRMATION' })

    // 2. Pay in the sandbox; the webhook grants Pro (promotional) and the sync writes store 'web'.
    const [first] = (await asaas('GET', `/subscriptions/${subscriptionId}/payments`)).data
    await asaas('POST', `/sandbox/payment/${first.id}/confirm`)
    let paid = await asaas('GET', `/payments/${first.id}`)
    for (let i = 0; i < 20 && !['CONFIRMED', 'RECEIVED'].includes(paid.status); i++) {
      await new Promise((resolve) => setTimeout(resolve, 3000))
      paid = await asaas('GET', `/payments/${first.id}`)
    }
    expect(['CONFIRMED', 'RECEIVED']).toContain(paid.status)
    expect(await webhook('PAYMENT_RECEIVED', paid)).toBe('done')
    expect(await webhook('PAYMENT_RECEIVED', paid, '_retry')).toBe('done') // same payment again: no harm
    const firstEnd = (await record()).paidUntil as string
    expect(await companySubscription()).toMatchObject({ plan: 'pro', store: 'web', status: 'active' })
    expect((await activeEntitlements()).map((e) => e.name)).toEqual(['pro'])

    // 3. Renewal. The sandbox creates the next charge only near its due date, so the
    //    event of the next month is built from the real payment with the next due date.
    const nextDue = (await record()).nextDueDate as string
    expect(await webhook('PAYMENT_RECEIVED', { ...paid, id: `${paid.id}-renewal`, dueDate: nextDue }, '_renewal')).toBe('done')
    const renewedEnd = (await record()).paidUntil as string
    expect(Date.parse(renewedEnd)).toBeGreaterThan(Date.parse(firstEnd))
    const pro = (await activeEntitlements()).find((e) => e.name === 'pro')
    expect(pro?.expires && Math.abs(Date.parse(pro.expires) - Date.parse(renewedEnd))).toBeLessThan(60_000)

    // 4. Double purchase: the screen shows the subscription, not the form, and the API refuses.
    await page.goto('./settings/plan')
    await page.getByTestId('plan-billing-subscription').click()
    await expect(page.getByTestId('billing-current')).toContainText('Plano Pro ativo')
    await expect(page.getByTestId('billing-form')).toHaveCount(0)
    await shot(page, 'sandbox-3-assinatura-ativa')
    const authPort = 19099 + Number(process.env.E2E_FIRESTORE_PORT ?? 18080) - 18080
    const signIn = await fetch(
      `http://127.0.0.1:${authPort}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: USERS.wOwner.email, password: PASSWORD, returnSecureToken: true }) },
    )
    const token = (await signIn.json()).idToken as string
    {
      const again = await fetch(`${API}/v1/app/billing/checkout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}`, 'X-Company-Id': COMPANY_W },
        body: JSON.stringify({ plan: 'business', cycle: 'monthly', billingType: 'PIX', name: 'Oficina Teste Sandbox', taxId: '11222333000181', email: 'sandbox@example.com', postalCode: '88015100', addressNumber: '100' }),
      })
      expect(again.status).toBe(409)
      expect((await again.json()).error.code).toBe('WEB_SUBSCRIPTION_ACTIVE')
    }

    // 5. 7-day guarantee: refund on the web → Asaas refund, promotional revoked, Free.
    await page.getByTestId('billing-refund').click()
    const dialog = page.getByRole('dialog', { name: 'Receber o dinheiro de volta?' })
    await dialog.getByRole('button', { name: 'Cancelar e receber o dinheiro de volta' }).click()
    await expect(page.getByTestId('billing-refunded')).toBeVisible({ timeout: 60_000 })
    await shot(page, 'sandbox-4-reembolso')
    expect(await record()).toMatchObject({ status: 'refunded' })
    expect(await activeEntitlements()).toEqual([])
    expect(await companySubscription()).toMatchObject({ plan: 'free' })
    const refunded = await asaas('GET', `/payments/${first.id}`)
    expect(['REFUNDED', 'REFUND_REQUESTED', 'REFUND_IN_PROGRESS', 'RECEIVED']).toContain(refunded.status)
    const gone = await asaas('GET', `/subscriptions/${subscriptionId}`)
    expect(gone.deleted).toBe(true)

    // The events Asaas sends next change nothing: the plan stays Free.
    expect(await webhook('PAYMENT_REFUNDED', refunded)).toBe('done')
    expect(await webhook('SUBSCRIPTION_DELETED', { ...refunded, subscription: subscriptionId })).not.toBe('duplicate')
    expect(await activeEntitlements()).toEqual([])
    const invoices = (await asaas('GET', `/invoices?payment=${first.id}`)).data ?? []
    console.log(`sandbox: assinatura ${subscriptionId}, cobrança ${first.id} ${refunded.status} após o reembolso; notas: ${invoices.map((i: { status: string }) => i.status).join(',') || 'nenhuma'}`)
  })
})
