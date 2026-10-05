/**
 * Asaas sandbox end-to-end check. See docs/ASAAS_INTEGRATION.md ("E2E no sandbox").
 *
 * Asaas-only flow (default, does not touch PraticOS data):
 *   npm run e2e:asaas
 *
 *   1. GET /myAccount/commercialInfo (same endpoint as connectAsaas), /myAccount as fallback
 *   2. find-or-create a fixed test customer (externalReference "praticos-e2e")
 *   3. single charge: POST /payments billingType UNDEFINED (same shape as charge.service)
 *   4. POST /sandbox/payment/{id}/confirm and poll until RECEIVED/CONFIRMED
 *   5. card installments: POST /payments CREDIT_CARD + installmentCount/totalValue,
 *      list the installment payments and compare their invoiceUrls, then delete the plan
 *   6. alphanumeric CNPJ: does Asaas accept a customer with cpfCnpj 12ABC34501DE35?
 *   7. GET /webhooks (read only): what a webhook object looks like
 *
 * Full flow against a PraticOS API that WRITES a charge on a real order. Point it only at
 * the Functions emulator (or a tunnel to it) or at a dedicated test company connected to
 * the Asaas SANDBOX (Integrações > Asaas, same sandbox key); never at a customer's company.
 * The order must have a remaining balance and a share link. The target host must be
 * confirmed explicitly with PRATICOS_E2E_ALLOW_BASE:
 *   npm run e2e:asaas -- --with-api
 *
 * Env (firebase/functions/.env.local is loaded when present; it is gitignored):
 *   ASAAS_SANDBOX_API_KEY   required, must start with $aact_hmlg
 *   PRATICOS_API_BASE       --with-api, e.g. http://127.0.0.1:5001/<project>/southamerica-east1/api (emulator)
 *   PRATICOS_E2E_ALLOW_BASE --with-api, must equal the host of PRATICOS_API_BASE (e.g. 127.0.0.1)
 *   PRATICOS_ID_TOKEN       --with-api, Firebase ID token of an owner/admin/manager
 *   PRATICOS_COMPANY_ID     --with-api
 *   PRATICOS_ORDER_ID       --with-api
 *   PRATICOS_SHARE_TOKEN    --with-api, token of the order share link (/q/{token})
 *
 * Never prints the API key, the ID token, the share token or request bodies.
 * Uses only test data (fixed test customer, valid test CPF, official sample CNPJ).
 */

import * as fs from 'fs';
import * as path from 'path';

const ASAAS_SANDBOX_BASE = 'https://api-sandbox.asaas.com/v3';
const USER_AGENT = 'praticos-e2e';
const E2E_CUSTOMER_REF = 'praticos-e2e';
const E2E_CUSTOMER_CPF = '24971563792'; // test CPF used in the Asaas docs (check digits OK)
const E2E_ALNUM_CNPJ = '12ABC34501DE35'; // official sample of the alphanumeric CNPJ (Receita Federal)
const E2E_ALNUM_CUSTOMER_REF = 'praticos-e2e-cnpj-alnum';
const E2E_PAYMENT_VALUE = 10;
const E2E_INSTALLMENT_COUNT = 3;
const E2E_INSTALLMENT_TOTAL = 30;
const PAID_STATUSES = ['RECEIVED', 'CONFIRMED'];
const POLL_INTERVAL_MS = 3000;
const API_POLL_INTERVAL_MS = 5000; // public API allows 30 req/min per link
const ASAAS_POLL_TIMEOUT_MS = 60_000;
const API_POLL_TIMEOUT_MS = 120_000;
const REQUEST_TIMEOUT_MS = 20_000;

type HttpMethod = 'GET' | 'POST' | 'DELETE';

interface AsaasAccount { name?: string; companyName?: string; tradingName?: string }
interface AsaasList<T> { data: T[]; totalCount?: number }
interface AsaasCustomer { id: string; name: string }
interface AsaasPayment {
  id: string;
  status: string;
  value: number;
  dueDate: string;
  invoiceUrl: string;
  billingType?: string;
  installment?: string | null;
  installmentNumber?: number | null;
  deleted?: boolean;
}
interface ApiEnvelope<T> { success: boolean; data?: T; error?: { code: string; message: string } }
interface PublicOrderData {
  order: { number: number; remainingBalance: number; paidAmount: number };
  charge?: { status: string; value: number; invoiceUrl: string } | null;
}
interface CreatedCharge { id?: string; chargeId?: string; invoiceUrl?: string; status?: string }

class AsaasHttpError extends Error {
  constructor(
    readonly status: number,
    readonly codes: string[],
    message: string,
  ) {
    super(message);
  }
}

function loadLocalEnv(): void {
  const envPath = path.resolve(__dirname, '..', '.env.local');
  if (fs.existsSync(envPath)) process.loadEnvFile(envPath);
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing env var ${name}`);
  return value;
}

/** Refuses anything that is not the Asaas sandbox (key prefix and API host). */
function assertSandbox(apiKey: string): void {
  if (!apiKey.trim().startsWith('$aact_hmlg')) {
    throw new Error('ASAAS_SANDBOX_API_KEY is not a sandbox key ($aact_hmlg...). Aborting.');
  }
  const host = new URL(ASAAS_SANDBOX_BASE).hostname;
  if (!host.endsWith('sandbox.asaas.com')) {
    throw new Error(`Asaas base host ${host} is not the sandbox. Aborting.`);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isoDatePlusDays(days: number): string {
  const date = new Date();
  date.setTime(date.getTime() + days * 24 * 60 * 60 * 1000);
  // Calendar date in America/Sao_Paulo, like charge.service; toISOString() would use UTC
  // and turn "yesterday" into "today" after 21:00 BRT.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(date);
}

function hostOf(url: string | undefined): string {
  if (!url) return '(none)';
  try {
    return new URL(url).hostname;
  } catch {
    return '(invalid url)';
  }
}

async function readJson(res: Response): Promise<unknown> {
  const text = await res.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    return {};
  }
}

async function asaas<T>(apiKey: string, method: HttpMethod, pathname: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = {
    access_token: apiKey.trim(),
    'User-Agent': USER_AGENT,
    accept: 'application/json',
  };
  if (body !== undefined) headers['content-type'] = 'application/json';
  const res = await fetch(`${ASAAS_SANDBOX_BASE}${pathname}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  const json = await readJson(res);
  if (!res.ok) {
    const errors = (json as { errors?: { code: string; description: string }[] }).errors ?? [];
    const detail = errors.map((e) => `${e.code}: ${e.description}`).join('; ');
    // Path without query string.
    throw new AsaasHttpError(
      res.status,
      errors.map((e) => e.code),
      `Asaas ${method} ${pathname.split('?')[0]} -> HTTP ${res.status} ${detail}`.trim(),
    );
  }
  return json as T;
}

async function praticos<T>(
  base: string,
  method: 'GET' | 'POST' | 'DELETE',
  pathname: string,
  opts: { idToken?: string; companyId?: string; body?: unknown; label?: string } = {},
): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (opts.idToken) headers.Authorization = `Bearer ${opts.idToken}`;
  if (opts.companyId) headers['X-Company-Id'] = opts.companyId;
  const res = await fetch(`${base}${pathname}`, {
    method,
    headers,
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
  const json = (await readJson(res)) as ApiEnvelope<T>;
  if (!res.ok || !json.success || json.data === undefined) {
    throw new Error(
      `PraticOS ${method} ${opts.label ?? pathname} -> HTTP ${res.status} ${json.error?.code ?? ''} ${json.error?.message ?? ''}`.trim(),
    );
  }
  return json.data;
}

async function getAccount(apiKey: string): Promise<{ name: string; endpoint: string }> {
  try {
    const info = await asaas<AsaasAccount>(apiKey, 'GET', '/myAccount/commercialInfo');
    return { name: info.tradingName || info.companyName || info.name || '', endpoint: '/myAccount/commercialInfo' };
  } catch (error) {
    console.log(`  /myAccount/commercialInfo failed (${(error as Error).message}); trying /myAccount`);
    const account = await asaas<AsaasAccount>(apiKey, 'GET', '/myAccount');
    return { name: account.name ?? '', endpoint: '/myAccount' };
  }
}

async function findCustomerByRef(apiKey: string, ref: string): Promise<AsaasCustomer | null> {
  const query = new URLSearchParams({ externalReference: ref, limit: '1' });
  const found = await asaas<AsaasList<AsaasCustomer>>(apiKey, 'GET', `/customers?${query.toString()}`);
  return found.data[0] ?? null;
}

async function findOrCreateCustomer(apiKey: string): Promise<{ customer: AsaasCustomer; reused: boolean }> {
  const existing = await findCustomerByRef(apiKey, E2E_CUSTOMER_REF);
  if (existing) return { customer: existing, reused: true };
  const customer = await asaas<AsaasCustomer>(apiKey, 'POST', '/customers', {
    name: 'Cliente E2E PraticOS',
    cpfCnpj: E2E_CUSTOMER_CPF,
    externalReference: E2E_CUSTOMER_REF,
    notificationDisabled: true,
  });
  return { customer, reused: false };
}

async function confirmAndWait(apiKey: string, paymentId: string): Promise<AsaasPayment> {
  await asaas<AsaasPayment>(apiKey, 'POST', `/sandbox/payment/${paymentId}/confirm`, {});
  const deadline = Date.now() + ASAAS_POLL_TIMEOUT_MS;
  for (;;) {
    const payment = await asaas<AsaasPayment>(apiKey, 'GET', `/payments/${paymentId}`);
    console.log(`  payment ${paymentId}: ${payment.status}`);
    if (PAID_STATUSES.includes(payment.status)) return payment;
    if (Date.now() > deadline) {
      throw new Error(`Payment ${paymentId} not paid after ${ASAAS_POLL_TIMEOUT_MS / 1000}s (last: ${payment.status})`);
    }
    await sleep(POLL_INTERVAL_MS);
  }
}

/** Best-effort cleanup; returns a short outcome for the summary. */
async function tryCleanup(label: string, action: () => Promise<unknown>): Promise<string> {
  try {
    await action();
    return `${label}: removed`;
  } catch (error) {
    return `${label}: kept (${(error as Error).message})`;
  }
}

async function runAsaasOnly(apiKey: string) {
  const cleanup: string[] = [];
  const facts: string[] = [];

  console.log('1/7 account');
  const account = await getAccount(apiKey);
  console.log(`  account: ${account.name || '(no name)'} via ${account.endpoint}`);

  console.log('2/7 customer (find-or-create by externalReference)');
  const { customer, reused } = await findOrCreateCustomer(apiKey);
  console.log(`  customer: ${customer.id} (${reused ? 'reused' : 'created'})`);

  console.log('3/7 POST /payments (single, billingType UNDEFINED)');
  const created = await asaas<AsaasPayment>(apiKey, 'POST', '/payments', {
    customer: customer.id,
    billingType: 'UNDEFINED',
    value: E2E_PAYMENT_VALUE,
    dueDate: isoDatePlusDays(3),
    description: 'PraticOS E2E',
    externalReference: `praticos-e2e:${Date.now()}`,
  });
  console.log(`  payment: ${created.id} (${created.status}) ${created.invoiceUrl}`);
  facts.push(`invoiceUrl host (single): ${hostOf(created.invoiceUrl)}`);

  let paid: AsaasPayment;
  try {
    console.log('4/7 POST /sandbox/payment/{id}/confirm + poll GET /payments/{id}');
    paid = await confirmAndWait(apiKey, created.id);
  } catch (error) {
    cleanup.push(await tryCleanup(`payment ${created.id}`, () => asaas(apiKey, 'DELETE', `/payments/${created.id}`)));
    console.log(`  cleanup: ${cleanup.join('; ')}`);
    throw error;
  }
  // A received payment cannot be deleted; try anyway and report.
  cleanup.push(await tryCleanup(`payment ${paid.id}`, () => asaas(apiKey, 'DELETE', `/payments/${paid.id}`)));

  // An overdue charge cannot be produced on demand: creation with a past dueDate is rejected.
  try {
    const pastDue = await asaas<AsaasPayment>(apiKey, 'POST', '/payments', {
      customer: customer.id, billingType: 'UNDEFINED', value: E2E_PAYMENT_VALUE, dueDate: isoDatePlusDays(-1),
    });
    facts.push(`past dueDate on creation (${pastDue.dueDate}): accepted, status ${pastDue.status}`);
    cleanup.push(await tryCleanup(`payment ${pastDue.id}`, () => asaas(apiKey, 'DELETE', `/payments/${pastDue.id}`)));
  } catch (error) {
    if (!(error instanceof AsaasHttpError)) throw error;
    facts.push(`past dueDate on creation: rejected (${error.codes.join(', ') || error.status})`);
  }

  console.log('5/7 card installments (CREDIT_CARD, installmentCount + totalValue)');
  const first = await asaas<AsaasPayment>(apiKey, 'POST', '/payments', {
    customer: customer.id,
    billingType: 'CREDIT_CARD',
    installmentCount: E2E_INSTALLMENT_COUNT,
    totalValue: E2E_INSTALLMENT_TOTAL,
    dueDate: isoDatePlusDays(3),
    description: 'PraticOS E2E parcelado',
    externalReference: `praticos-e2e-inst:${Date.now()}`,
  });
  const installmentId = first.installment ?? '';
  console.log(
    `  first payment: ${first.id} #${first.installmentNumber ?? '?'} value ${first.value}, installment ${installmentId || '(none)'}`,
  );
  console.log(`  first invoiceUrl: ${first.invoiceUrl}`);
  facts.push(`invoiceUrl host (installment): ${hostOf(first.invoiceUrl)}`);
  if (installmentId) {
    try {
      const parts = await asaas<AsaasList<AsaasPayment>>(apiKey, 'GET', `/installments/${installmentId}/payments?limit=100`);
      for (const p of parts.data) {
        console.log(`  #${p.installmentNumber ?? '?'} ${p.id} ${p.value} due ${p.dueDate} ${p.status} ${p.invoiceUrl}`);
      }
      const urls = new Set(parts.data.map((p) => p.invoiceUrl));
      facts.push(
        `installment plan: ${parts.data.length} payments, ${urls.size} distinct invoiceUrl(s); ` +
        `first invoiceUrl ${urls.size === 1 ? 'is shared by all installments' : 'is per installment'}`,
      );
      const plan = await asaas<Record<string, unknown>>(apiKey, 'GET', `/installments/${installmentId}`);
      facts.push(`installment object fields: ${Object.keys(plan).sort().join(', ')}`);
      // Informational only: a failure here must not fail the run.
      try {
        const page = await fetch(first.invoiceUrl, { signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS) });
        const html = await page.text();
        // Does the first installment's invoice present the whole plan (total + "Parcelado em N x")?
        const needles = [`R$ ${E2E_INSTALLMENT_TOTAL},00`, `Parcelado em ${E2E_INSTALLMENT_COUNT} x`, `1 de ${E2E_INSTALLMENT_COUNT}`];
        const mentions = needles.filter((needle) => html.includes(needle));
        facts.push(`first invoice page HTTP ${page.status}, shows: ${mentions.length ? mentions.map((m) => `"${m}"`).join(', ') : '(none)'}`);
      } catch (error) {
        console.warn(`  warning: could not inspect the invoice page (${(error as Error).message})`);
        facts.push('first invoice page: not inspected (fetch failed)');
      }
    } finally {
      cleanup.push(await tryCleanup(`installment ${installmentId}`, () => asaas(apiKey, 'DELETE', `/installments/${installmentId}`)));
    }
  } else {
    cleanup.push(await tryCleanup(`payment ${first.id}`, () => asaas(apiKey, 'DELETE', `/payments/${first.id}`)));
  }

  console.log('6/7 alphanumeric CNPJ customer');
  let alnum = await findCustomerByRef(apiKey, E2E_ALNUM_CUSTOMER_REF);
  if (alnum) {
    facts.push(`alphanumeric CNPJ ${E2E_ALNUM_CNPJ}: accepted (customer already existed)`);
  } else {
    try {
      alnum = await asaas<AsaasCustomer>(apiKey, 'POST', '/customers', {
        name: 'Empresa E2E CNPJ Alfanumerico',
        cpfCnpj: E2E_ALNUM_CNPJ,
        externalReference: E2E_ALNUM_CUSTOMER_REF,
        notificationDisabled: true,
      });
      facts.push(`alphanumeric CNPJ ${E2E_ALNUM_CNPJ}: accepted`);
    } catch (error) {
      if (!(error instanceof AsaasHttpError)) throw error;
      facts.push(`alphanumeric CNPJ ${E2E_ALNUM_CNPJ}: rejected (${error.message})`);
    }
  }
  if (alnum) {
    const id = alnum.id;
    cleanup.push(await tryCleanup(`customer ${id}`, () => asaas(apiKey, 'DELETE', `/customers/${id}`)));
  }

  console.log('7/7 GET /webhooks (read only)');
  const hooks = await asaas<AsaasList<Record<string, unknown>>>(apiKey, 'GET', '/webhooks?limit=10');
  const fields = new Set<string>();
  hooks.data.forEach((h) => Object.keys(h).forEach((k) => fields.add(k)));
  facts.push(
    `webhooks: ${hooks.totalCount ?? hooks.data.length} configured; object fields: ` +
    `${fields.size ? [...fields].sort().join(', ') : '(none configured)'}`,
  );

  return {
    accountName: account.name,
    accountEndpoint: account.endpoint,
    customerId: customer.id,
    paymentId: paid.id,
    status: paid.status,
    value: paid.value,
    invoiceUrl: created.invoiceUrl,
    facts,
    cleanup,
  };
}

async function runWithApi(apiKey: string) {
  const base = requireEnv('PRATICOS_API_BASE').replace(/\/$/, '');
  const idToken = requireEnv('PRATICOS_ID_TOKEN');
  const companyId = requireEnv('PRATICOS_COMPANY_ID');
  const orderId = requireEnv('PRATICOS_ORDER_ID');
  const shareToken = requireEnv('PRATICOS_SHARE_TOKEN');
  const allowHost = requireEnv('PRATICOS_E2E_ALLOW_BASE').trim();
  const publicLabel = '/public/orders/{token}';

  // Nothing else ties this mode to a non-production target: the operator must name the host.
  const targetHost = new URL(base).host;
  if (allowHost !== targetHost && allowHost !== new URL(base).hostname) {
    throw new Error(`PRATICOS_E2E_ALLOW_BASE (${allowHost}) does not match the PRATICOS_API_BASE host (${targetHost}). Aborting.`);
  }
  console.log(`--with-api target: host ${targetHost}, company ${companyId}, order ${orderId}`);

  console.log('A/5 GET /public/orders/{token} (remaining balance)');
  const before = await praticos<PublicOrderData>(base, 'GET', `/public/orders/${shareToken}`, { label: publicLabel });
  const balance = before.order.remainingBalance;
  if (!(balance > 0)) throw new Error(`Order #${before.order.number} has no remaining balance`);
  console.log(`  order #${before.order.number}, remaining ${balance}`);

  console.log('B/5 POST /v1/app/orders/{orderId}/charges');
  const created = await praticos<CreatedCharge>(base, 'POST', `/v1/app/orders/${orderId}/charges`, {
    idToken,
    companyId,
    body: { value: balance, mode: 'single' },
  });
  const chargeId = created.id ?? created.chargeId;
  if (!chargeId) throw new Error('Charge response without id');
  console.log(`  charge: ${chargeId}`);

  let paymentId: string;
  try {
    console.log('C/5 find the Asaas payment by externalReference');
    const ref = `${companyId}:${orderId}:${chargeId}`;
    const list = await asaas<AsaasList<AsaasPayment>>(
      apiKey, 'GET', `/payments?externalReference=${encodeURIComponent(ref)}`,
    );
    if (list.data.length === 0) {
      throw new Error(`No Asaas payment with externalReference ${ref}. Is the company connected with the same sandbox key?`);
    }
    paymentId = list.data[0].id;

    console.log('D/5 confirm in the sandbox');
    await confirmAndWait(apiKey, paymentId);
  } catch (error) {
    // Not paid yet: best-effort cancel so no open charge is left on the order.
    try {
      await praticos<unknown>(base, 'DELETE', `/v1/app/orders/${orderId}/charges/${chargeId}`, { idToken, companyId });
      console.log(`  cleanup: charge ${chargeId} canceled`);
    } catch (cancelError) {
      console.warn(`  cleanup: could not cancel charge ${chargeId} (${(cancelError as Error).message})`);
    }
    throw error;
  }

  console.log('E/5 poll /public/orders/{token} until the webhook marks the order paid');
  const deadline = Date.now() + API_POLL_TIMEOUT_MS;
  for (;;) {
    const after = await praticos<PublicOrderData>(base, 'GET', `/public/orders/${shareToken}`, { label: publicLabel });
    console.log(`  charge: ${after.charge?.status ?? 'none'}, remaining ${after.order.remainingBalance}`);
    if (after.charge?.status === 'paid' && after.order.remainingBalance <= 0.005) {
      return { orderNumber: after.order.number, chargeId, paymentId, paidAmount: after.order.paidAmount };
    }
    if (Date.now() > deadline) {
      throw new Error('Order not marked paid in time: check webhook delivery (ASAAS_WEBHOOK_BASE_URL, tunnel, function logs)');
    }
    await sleep(API_POLL_INTERVAL_MS);
  }
}

async function main(): Promise<void> {
  loadLocalEnv();
  const apiKey = requireEnv('ASAAS_SANDBOX_API_KEY');
  assertSandbox(apiKey);

  const started = Date.now();
  const asaasSummary = await runAsaasOnly(apiKey);
  const apiSummary = process.argv.includes('--with-api') ? await runWithApi(apiKey) : null;

  console.log('\n=== Asaas sandbox E2E: OK ===');
  console.log(`Account:      ${asaasSummary.accountName} (${asaasSummary.accountEndpoint})`);
  console.log(`Customer:     ${asaasSummary.customerId}`);
  console.log(`Payment:      ${asaasSummary.paymentId} -> ${asaasSummary.status} (${asaasSummary.value})`);
  console.log(`Invoice:      ${asaasSummary.invoiceUrl}`);
  console.log('Facts:');
  asaasSummary.facts.forEach((f) => console.log(`  - ${f}`));
  console.log('Cleanup:');
  asaasSummary.cleanup.forEach((c) => console.log(`  - ${c}`));
  if (apiSummary) {
    console.log(`Order:        #${apiSummary.orderNumber} paid (paidAmount ${apiSummary.paidAmount})`);
    console.log(`Charge:       ${apiSummary.chargeId} / ${apiSummary.paymentId}`);
  } else {
    console.log('API check:    skipped (run with -- --with-api)');
  }
  console.log(`Elapsed:      ${Math.round((Date.now() - started) / 1000)}s`);
}

main().catch((error: unknown) => {
  console.error(`E2E failed: ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
