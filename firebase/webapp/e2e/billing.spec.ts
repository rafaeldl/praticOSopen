// Assinar plano pela web (issue #664, docs/WEB_CHECKOUT.md). The server owns
// the switch, prices, guard and Asaas: here /v1/app/billing is answered by the
// test, so the screen is checked with the switch on and off without Asaas.
// BILLING_SHOTS=<folder> saves the screens for review.
import { expect, test, type Page } from './test'
import { login } from './helpers'

const SHOTS = process.env.BILLING_SHOTS
const shot = async (page: Page, name: string) => {
  if (SHOTS) await page.screenshot({ path: `${SHOTS}/${name}.png`, fullPage: true })
}

const OFFER = {
  plans: [
    { plan: 'starter', prices: { monthly: 59.9, yearly: 599 } },
    { plan: 'pro', prices: { monthly: 119, yearly: 1190 } },
    { plan: 'business', prices: { monthly: 249, yearly: 2490 } },
  ],
  cycles: ['monthly', 'yearly'],
  billingTypes: { monthly: ['CREDIT_CARD'], yearly: ['PIX', 'BOLETO', 'CREDIT_CARD'] },
  guaranteeDays: 7,
}
const ACTIVE = {
  status: 'active',
  plan: 'pro',
  cycle: 'monthly',
  billingType: 'CREDIT_CARD',
  value: 119,
  paidUntil: '2026-12-19T03:00:00.000Z',
  nextDueDate: '2026-12-13',
  checkoutUrl: null,
  refundEligible: true,
}

async function billing(page: Page, data: Record<string, unknown>) {
  await page.route(/\/v1\/app\/billing$/, (route) => route.fulfill({ json: { success: true, data } }))
}

test('chave desligada: Plano não mostra compra e diz que só consulta', async ({ page }) => {
  await billing(page, { enabled: false, offer: null, block: null, subscription: null })
  await login(page, 'gOwner', 'settings/plan')
  await expect(page.getByTestId('plan-header')).toBeVisible()
  await expect(page.getByTestId('plan-billing')).toHaveCount(0)
  await expect(page.getByTestId('plan-where')).toHaveText('Para mudar de plano, use o app PraticOS no celular, na tela Plano.')
})

test('quem assina na loja: "use o app", sem botão de compra', async ({ page }) => {
  await billing(page, { enabled: true, offer: OFFER, block: 'STORE_SUBSCRIPTION_ACTIVE', subscription: null })
  await login(page, 'gOwner', 'settings/plan')
  await expect(page.getByTestId('plan-billing-store')).toHaveText('Você assina pela App Store ou pelo Google Play. Para mudar de plano, use o app.')
  await expect(page.getByTestId('plan-billing-buy')).toHaveCount(0)
  await page.goto('settings/plan/subscribe')
  await expect(page.getByTestId('billing-store')).toBeVisible()
  await expect(page.getByTestId('billing-form')).toHaveCount(0)
})

test('empresa fora do Brasil: assina pelo app, sem formulário nem compra', async ({ page }) => {
  await billing(page, { enabled: true, offer: OFFER, block: 'OUTSIDE_BRAZIL', subscription: null })
  await login(page, 'gOwner', 'settings/plan')
  await expect(page.getByTestId('plan-billing-app')).toContainText('Fora do Brasil, a assinatura é feita pelo app do PraticOS no celular.')
  await expect(page.getByTestId('plan-billing-app').getByRole('link', { name: 'App Store' })).toHaveAttribute('href', /apps\.apple\.com/)
  await expect(page.getByTestId('plan-billing-app').getByRole('link', { name: 'Google Play' })).toHaveAttribute('href', /play\.google\.com/)
  await expect(page.getByTestId('plan-billing-buy')).toHaveCount(0)
  await expect(page.getByTestId('plan-where')).toHaveCount(0)
  await shot(page, 'plano-fora-do-brasil')
  await page.goto('settings/plan/subscribe')
  await expect(page.getByTestId('billing-app')).toBeVisible()
  await expect(page.getByTestId('billing-form')).toHaveCount(0)
})

test('assinar: plano, anual com Pix, garantia de 7 dias e ida para a página do Asaas', async ({ page }) => {
  await billing(page, { enabled: true, offer: OFFER, block: null, subscription: null })
  let sent: Record<string, unknown> | null = null
  await page.route(/\/v1\/app\/billing\/checkout$/, async (route) => {
    sent = route.request().postDataJSON()
    await route.fulfill({ json: { success: true, data: { checkoutUrl: 'https://sandbox.asaas.com/i/test-checkout' } } })
  })
  await page.route('https://sandbox.asaas.com/**', (route) => route.fulfill({ contentType: 'text/html', body: '<h1>Fatura Asaas (sandbox)</h1>' }))

  await login(page, 'gOwner', 'settings/plan')
  // With the purchase on the web, the "use the app" note goes away.
  await expect(page.getByTestId('plan-where')).toHaveCount(0)
  await page.getByTestId('plan-billing-buy').click()
  await expect(page.getByRole('heading', { level: 1, name: 'Assinar plano' })).toBeVisible()
  await expect(page.getByTestId('billing-guarantee')).toContainText('Garantia de 7 dias')
  await expect(page.getByTestId('billing-plan-pro')).toContainText('R$ 119,00 por mês')
  // Monthly: card only.
  await expect(page.getByTestId('billing-method-CREDIT_CARD')).toBeVisible()
  await expect(page.getByTestId('billing-method-PIX')).toHaveCount(0)
  await shot(page, '1-assinar-mensal')

  await page.getByTestId('billing-cycle-yearly').check()
  await expect(page.getByTestId('billing-plan-business')).toContainText('R$ 2.490,00 por ano')
  await page.getByTestId('billing-plan-business').click()
  await page.getByTestId('billing-method-PIX').click()

  // Required fields are checked before going to Asaas.
  await page.getByTestId('billing-taxid').fill('123')
  await page.getByTestId('billing-pay').click()
  await expect(page.getByText('Esse CPF ou CNPJ não está certo.')).toBeVisible()
  await page.getByTestId('billing-name').fill('Oficina Gama Ltda')
  await page.getByTestId('billing-taxid').fill('11.222.333/0001-81')
  await page.getByTestId('billing-email').fill('financeiro@example.com')
  await shot(page, '2-assinar-anual-pix')

  await page.getByTestId('billing-pay').click()
  await expect(page.getByRole('heading', { name: 'Fatura Asaas (sandbox)' })).toBeVisible()
  expect(sent).toEqual({
    plan: 'business',
    cycle: 'yearly',
    billingType: 'PIX',
    name: 'Oficina Gama Ltda',
    taxId: '11222333000181',
    email: 'financeiro@example.com',
  })
})

test('assinatura web ativa: próxima cobrança, cancelar e dinheiro de volta na garantia', async ({ page }) => {
  let refund: boolean | null = null
  let current: Record<string, unknown> = { enabled: true, offer: OFFER, block: 'WEB_SUBSCRIPTION_ACTIVE', subscription: ACTIVE }
  await page.route(/\/v1\/app\/billing$/, (route) => route.fulfill({ json: { success: true, data: current } }))
  await page.route(/\/v1\/app\/billing\/cancel$/, async (route) => {
    refund = route.request().postDataJSON().refund
    current = { enabled: true, offer: OFFER, block: null, subscription: { ...ACTIVE, status: 'refunded', refundEligible: false } }
    await route.fulfill({ json: { success: true, data: { status: 'refunded' } } })
  })

  await login(page, 'gOwner', 'settings/plan')
  await page.getByTestId('plan-billing-subscription').click()
  await expect(page.getByTestId('billing-current')).toContainText('Plano Pro ativo. Próxima cobrança de R$ 119,00 em 13/12/2026.')
  await expect(page.getByTestId('billing-form')).toHaveCount(0)
  await shot(page, '3-assinatura-ativa')

  await page.getByTestId('billing-refund').click()
  const dialog = page.getByRole('dialog', { name: 'Receber o dinheiro de volta?' })
  await expect(dialog).toContainText('o plano Pro acaba agora')
  await shot(page, '4-reembolso')
  await dialog.getByRole('button', { name: 'Cancelar e receber o dinheiro de volta' }).click()
  await expect(page.getByTestId('billing-refunded')).toHaveText('Devolvemos o dinheiro. O plano voltou para o Free.')
  expect(refund).toBe(true)
  await expect(page.getByTestId('billing-form')).toBeVisible()
})

test('técnico não abre a compra', async ({ page }) => {
  await billing(page, { enabled: true, offer: OFFER, block: null, subscription: null })
  await login(page, 'gTech', 'settings/plan')
  await expect(page.getByTestId('plan-header')).toBeVisible()
  await expect(page.getByTestId('plan-billing')).toHaveCount(0)
})
