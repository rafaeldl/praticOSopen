/**
 * Web checkout end to end against the Asaas SANDBOX and RevenueCat (issue #664,
 * docs/WEB_CHECKOUT.md "Teste ponta a ponta no sandbox"). Touches no Firestore.
 *
 *   npm run e2e:web-checkout
 *
 * Reads ~/.praticos-sandbox.env (outside the repo; KEY=value lines):
 *   ASAAS_BILLING_API_KEY      sandbox key of Rafsoft's Asaas test account, must start with $aact_hmlg
 *   REVENUECAT_SECRET_API_KEY  sk_ key of RevenueCat (REVENUECAT_SECRET_KEY also read)
 *   RC_TEST_APP_USER_ID        optional, app user that receives the promotional (default
 *                              e2e-web-checkout-script). Never a real company id: the script
 *                              refuses an app user with any store purchase, and revokes every
 *                              promotional it may have left at the end, even after a failure.
 *
 * Steps (each prints OK or FAIL):
 *   1. find-or-create the test customer (externalReference praticos-web-checkout-e2e, test CPF)
 *   2. subscription Pro monthly (POST /subscriptions, same shape as startCheckout) and its first charge
 *   3. pay it with POST /sandbox/payment/{id}/confirm and wait for CONFIRMED/RECEIVED
 *   4. webhook rule for PAYMENT_RECEIVED → grant promotional `pro` until next due + 5 days
 *   5. RevenueCat state → plan pro, store 'web' (same functions the sync uses)
 *   6. 7-day guarantee: refund the charge, revoke the promotional → plan free
 *   7. cancel: DELETE /subscriptions/{id}
 *
 * Never prints a key. Uses only test data.
 */

import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { AsaasClient } from '../src/services/asaas/asaas-client';
import { fetchSubscriber } from '../src/services/revenuecat.client';
import { resolveSubscriptionState } from '../src/services/subscription-plans';
import { grantPromotional, revokePromotionals } from '../src/services/web-billing/revenuecat-promotional';
import {
  WEB_PRICES,
  applyWebOrigin,
  decideBillingAction,
  saoPauloDate,
  type WebBillingRecord,
} from '../src/services/web-billing/web-billing-rules';

const ENV_FILE = path.join(os.homedir(), '.praticos-sandbox.env');
const SANDBOX_BASE = 'https://api-sandbox.asaas.com/v3';
const CUSTOMER_REF = 'praticos-web-checkout-e2e';
const TEST_CPF = '24971563792'; // test CPF from the Asaas docs
const PAID = ['CONFIRMED', 'RECEIVED'];

function readEnvFile(file: string): Record<string, string> {
  if (!fs.existsSync(file)) {
    throw new Error(`${file} not found. See docs/WEB_CHECKOUT.md "Teste ponta a ponta no sandbox".`);
  }
  const out: Record<string, string> = {};
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const match = /^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/.exec(line);
    if (match) out[match[1]] = match[2].replace(/^['"]|['"]$/g, '');
  }
  return out;
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
let failures = 0;
let cleanup: (() => Promise<void>) | null = null;
function step(name: string, ok: boolean, detail = '') {
  if (!ok) failures++;
  console.log(`${ok ? 'OK  ' : 'FAIL'} ${name}${detail ? ` — ${detail}` : ''}`);
}

async function main() {
  const env = readEnvFile(ENV_FILE);
  const asaasKey = env.ASAAS_BILLING_API_KEY?.trim();
  const rcKey = (env.REVENUECAT_SECRET_API_KEY ?? env.REVENUECAT_SECRET_KEY)?.trim();
  const appUserId = env.RC_TEST_APP_USER_ID?.trim() || 'e2e-web-checkout-script';
  if (!asaasKey?.startsWith('$aact_hmlg')) throw new Error('ASAAS_BILLING_API_KEY must be a SANDBOX key ($aact_hmlg...)');
  if (!rcKey?.startsWith('sk_')) throw new Error('REVENUECAT_SECRET_API_KEY must be a secret key (sk_...)');

  // Guard: only an app user with no store purchase (a test one) is touched.
  const before = await fetchSubscriber(appUserId, rcKey);
  const storeSubs = Object.values(before.subscriptions ?? {}).filter((s) => (s.store ?? '').toLowerCase() !== 'promotional');
  if (storeSubs.length) throw new Error(`${appUserId} has store purchases: not a test app user`);
  cleanup = async () => {
    for (const plan of ['starter', 'pro', 'business'] as const) await revokePromotionals(appUserId, plan, rcKey).catch(() => undefined);
    const after = resolveSubscriptionState(await fetchSubscriber(appUserId, rcKey), new Date());
    console.log(`limpeza: promocionais de ${appUserId} revogados, plano ${after.plan}`);
  };

  const asaas = new AsaasClient({ apiKey: asaasKey, environment: 'sandbox' });
  const sandboxPost = async (p: string) => {
    const response = await fetch(`${SANDBOX_BASE}${p}`, {
      method: 'POST',
      headers: { access_token: asaasKey, 'User-Agent': 'praticos-e2e', accept: 'application/json' },
    });
    if (!response.ok) throw new Error(`sandbox ${p.split('/').slice(0, 3).join('/')} HTTP ${response.status}`);
  };

  // 1. Customer
  const customer =
    (await asaas.findCustomerByExternalReference(CUSTOMER_REF)) ??
    (await asaas.createCustomer({
      name: 'PraticOS teste web checkout',
      cpfCnpj: TEST_CPF,
      externalReference: CUSTOMER_REF,
      notificationDisabled: true,
    }));
  step('1. cliente de teste', !!customer.id);

  // 2. Subscription (Pix so the sandbox can confirm it without a card form)
  const subscription = await asaas.createSubscription({
    customer: customer.id,
    billingType: 'PIX',
    value: WEB_PRICES.pro.monthly,
    nextDueDate: saoPauloDate(new Date()),
    cycle: 'MONTHLY',
    description: 'PraticOS Pro (mensal) — teste',
    externalReference: appUserId,
  });
  const [first] = await asaas.listSubscriptionPayments(subscription.id);
  step('2. assinatura e primeira cobrança', !!first?.invoiceUrl, first ? `fatura ${first.invoiceUrl}` : 'sem cobrança');
  if (!first) return;

  // 3. Pay in the sandbox
  await sandboxPost(`/sandbox/payment/${encodeURIComponent(first.id)}/confirm`);
  let paid = await asaas.getPayment(first.id);
  for (let i = 0; i < 20 && !PAID.includes(paid.status); i++) {
    await sleep(3000);
    paid = await asaas.getPayment(first.id);
  }
  step('3. pagamento confirmado no sandbox', PAID.includes(paid.status), paid.status);
  const afterPay = await asaas.listSubscriptionPayments(subscription.id);
  console.log(`     cobranças da assinatura depois do 1º pagamento: ${afterPay.map((p) => `${p.dueDate}/${p.status}`).join(', ')}`);

  // 4. Webhook rule
  const record: WebBillingRecord = {
    status: 'active',
    plan: 'pro',
    cycle: 'monthly',
    billingType: 'PIX',
    value: WEB_PRICES.pro.monthly,
    environment: 'sandbox',
    asaasCustomerId: customer.id,
    asaasSubscriptionId: subscription.id,
    createdAt: new Date().toISOString(),
    createdBy: 'e2e',
  };
  const action = decideBillingAction(
    { id: 'e2e', event: 'PAYMENT_RECEIVED', payment: { id: paid.id, subscription: subscription.id, value: paid.value, dueDate: paid.dueDate } },
    record,
  );
  step('4. regra do webhook → grant', action.kind === 'grant', action.kind === 'grant' ? `até ${new Date(action.endMs).toISOString()}` : action.kind);
  if (action.kind !== 'grant') return;
  await grantPromotional(appUserId, 'pro', action.endMs, rcKey);

  // 5. State the sync would write
  const granted = await fetchSubscriber(appUserId, rcKey);
  const state = applyWebOrigin(resolveSubscriptionState(granted, new Date()), granted, record);
  step('5. RevenueCat → plano pro, origem web', state.plan === 'pro' && state.store === 'web', `${state.plan}/${state.store}/${state.expiresAt}`);

  // 6. Guarantee: refund + revoke
  await asaas.refundPayment(paid.id, 'Teste da garantia de 7 dias');
  await revokePromotionals(appUserId, 'pro', rcKey);
  const revoked = resolveSubscriptionState(await fetchSubscriber(appUserId, rcKey), new Date());
  const refunded = await asaas.getPayment(paid.id);
  step('6. reembolso e plano de volta ao Free', revoked.plan === 'free', `Asaas ${refunded.status}, plano ${revoked.plan}`);

  // 7. Cancel
  await asaas.deleteSubscription(subscription.id);
  step('7. assinatura cancelada no Asaas', true);
}

main()
  .finally(async () => {
    if (cleanup) await cleanup().catch((error) => console.error('limpeza falhou:', error instanceof Error ? error.message : 'unknown'));
  })
  .then(() => {
    console.log(failures ? `\n${failures} passo(s) falharam` : '\nTudo certo no sandbox.');
    process.exit(failures ? 1 : 0);
  })
  .catch((error) => {
    console.error('Erro:', error instanceof Error ? error.message : 'unknown');
    process.exit(1);
  });
