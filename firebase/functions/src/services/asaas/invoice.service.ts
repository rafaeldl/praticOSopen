/**
 * NFS-e (nota fiscal de serviço) through the company's Asaas account.
 * See docs/NFSE_ASAAS.md.
 *
 * - One invoice per order by default; several orders of the same customer in
 *   one invoice when the user picks them ("uma nota com várias OS").
 * - The invoice is "avulsa" (tied to the Asaas customer, not to a payment):
 *   the nota belongs to the order, whatever way it was paid.
 * - Only the services of the order go into the nota (products are not NFS-e).
 *   Value rule (see `invoiceValueOfOrder`): services total minus the order
 *   discount in proportion to the services share of the items.
 * - companies/{cid}/invoices/{id} is written only here and by the webhook.
 *   One active invoice per order is guaranteed by the lock docs
 *   companies/{cid}/private/nfse/orders/{orderId} (server-only), read and
 *   written in the same transaction as the new invoice.
 * - A create whose answer was lost (timeout, 5xx, network) may still have
 *   created the nota on Asaas: the invoice stays 'creating' and locked until
 *   it is reconciled with Asaas (`reconcileInvoice`, by the externalReference),
 *   on the next preview/emit/cancel touching the order or by the webhook.
 * - The customer must have e-mail and address with CEP on Asaas
 *   (invoice-customer.service); an issue Asaas refuses after the create is
 *   canceled there and kept as 'error' with the reason (`giveUpRefusedInvoice`).
 * - The nota PDF/XML live only on the invoice doc; the order `documents`
 *   array belongs to the app (saved whole) and is never written here.
 */

import { db } from '../firestore.service';
import { Customer, Order, UserAggr } from '../../models/types';
import {
  AsaasConnectionDoc,
  AsaasCreateInvoiceInput,
  AsaasCustomerContact,
  AsaasEnvironment,
  AsaasInvoice,
  CreateInvoiceInput,
  InvoiceOrderPart,
  InvoiceStatus,
  NfseAutoIssue,
  NfseInvoice,
  NfseServiceSettings,
  PaymentSettingsDoc,
} from '../../models/asaas.types';
import { AsaasApiError, AsaasClient } from './asaas-client';
import { asaasConnectionRef, getAsaasCredentialProvider } from './credential-provider';
import { AsaasServiceError, asaasErrorDescription, asaasErrorLog } from './errors';
import { getPaymentSettings } from './connection.service';
import { hasNfseWebhookEvents } from './webhook-events';
import { findOrCreateAsaasCustomer, resolveTaxId, roundMoney, todayInSaoPaulo, addDays } from './charge.service';
import {
  cleanCustomerContact,
  ensureInvoiceCustomer,
  InvoiceCustomerField,
  invoiceCustomerData,
  saveContactOnCustomer,
} from './invoice-customer.service';

export const MAX_INVOICE_ORDERS = 50;
/** Tag of the invoice externalReference `{companyId}:nf:{invoiceId}`. */
export const INVOICE_REF_TAG = 'nf';
/**
 * A non-final invoice untouched for this long is checked against Asaas before
 * deciding (lost answer of the create, missed webhook). Long enough for an
 * in-flight create (20 s timeout) to have finished.
 */
export const RECONCILE_AFTER_MS = 3 * 60 * 1000;
/** Statuses that may still change without us hearing (checked by `reconcileInvoice`). */
const RECONCILE_STATUSES: InvoiceStatus[] = ['creating', 'scheduled', 'synchronized', 'processingCancellation'];
/** Asaas answers that prove the invoice was not created (anything else: unknown). */
const DEFINITIVE_REJECTIONS = [400, 401, 403, 404, 422];
const MAX_DESCRIPTION = 2000;
/**
 * Asaas refuses a longer municipalServiceName (400 invalid_name, sandbox
 * 2026-10-29); the city list has longer names (14.01.01 has 297 characters).
 */
export const MAX_MUNICIPAL_SERVICE_NAME = 250;
const MAX_OBSERVATIONS = 500;
/** Furthest future date accepted for the issue date. */
const MAX_FUTURE_DAYS = 60;
export const DEFAULT_DESCRIPTION_TEMPLATE = '{servicos}';

/** Statuses that no longer count as "the order has a nota". */
const INACTIVE_STATUSES: InvoiceStatus[] = ['canceled', 'error'];
/** Statuses the user can ask to cancel. */
const CANCELABLE_STATUSES: InvoiceStatus[] = ['scheduled', 'authorized', 'cancellationDenied'];

function companyRef(companyId: string) {
  return db.collection('companies').doc(companyId);
}

export function invoicesRef(companyId: string) {
  return companyRef(companyId).collection('invoices');
}

export function nfseSettingsRef(companyId: string) {
  return companyRef(companyId).collection('settings').doc('nfse');
}

function orderLockRef(companyId: string, orderId: string) {
  return companyRef(companyId).collection('private').doc('nfse').collection('orders').doc(orderId);
}

export function invoiceExternalReference(companyId: string, invoiceId: string): string {
  return `${companyId}:${INVOICE_REF_TAG}:${invoiceId}`;
}

export function parseInvoiceReference(ref?: string | null): { companyId: string; invoiceId: string } | null {
  if (!ref) return null;
  const parts = ref.split(':');
  if (parts.length !== 3 || parts.some((p) => !p) || parts[1] !== INVOICE_REF_TAG) return null;
  return { companyId: parts[0], invoiceId: parts[2] };
}

// ----------------------------------------------------------------------------
// Value rule
// ----------------------------------------------------------------------------

export interface OrderInvoiceValue {
  servicesTotal: number;
  productsTotal: number;
  discount: number;
  /** Services total minus the services share of the discount. */
  value: number;
}

/**
 * Value of the nota for one order, mirroring the app's order total
 * (OrderStore.updateTotal): services sum `value`, products `total` or
 * `value * quantity`, items without a price count as zero. The order discount
 * applies to the whole order, so the nota takes the services share of it:
 *   value = services - discount * services / (services + products)
 * rounded to cents. Example: services 300, products 100, discount 40 →
 * 300 - 40 * 0.75 = 270.
 */
export function invoiceValueOfOrder(order: Pick<Order, 'services' | 'products' | 'discount'>): OrderInvoiceValue {
  const servicesTotal = roundMoney(
    (order.services ?? []).reduce((sum, s) => sum + (Number(s?.value) || 0), 0),
  );
  const productsTotal = roundMoney(
    (order.products ?? []).reduce((sum, p) => {
      const line = p as unknown as { value?: number; quantity?: number; total?: number };
      if (line?.value === undefined || line?.value === null) return sum;
      const total = line.total ?? (Number(line.value) || 0) * (line.quantity ?? 1);
      return sum + (Number(total) || 0);
    }, 0),
  );
  const gross = servicesTotal + productsTotal;
  const discount = Math.min(Math.max(Number(order.discount) || 0, 0), Math.max(gross, 0));
  const share = gross > 0 ? servicesTotal / gross : 0;
  const value = Math.max(roundMoney(servicesTotal - discount * share), 0);
  return { servicesTotal, productsTotal, discount: roundMoney(discount), value };
}

function serviceLine(service: NonNullable<Order['services']>[number]): string {
  const name = (service?.service?.name || '').trim();
  const description = (service?.description || '').trim();
  if (name && description && description !== name) return `${name} - ${description}`;
  return name || description;
}

/** Service names of the orders: one line per order when there are several. */
export function describeServices(orders: Array<Pick<Order, 'number' | 'services'>>): string {
  const linesOf = (order: Pick<Order, 'services'>) =>
    (order.services ?? []).map(serviceLine).filter((line) => line.length > 0).join('; ');
  if (orders.length === 1) return linesOf(orders[0]);
  return orders
    .map((order) => {
      const lines = linesOf(order);
      return order.number !== undefined && order.number !== null ? `OS ${order.number}: ${lines}` : lines;
    })
    .join('\n');
}

/** "OS 182" / "OS 182, 190" (capped so it fits the observations field). */
export function describeOrderNumbers(numbers: Array<number | null | undefined>): string {
  const known = numbers.filter((n): n is number => n !== undefined && n !== null);
  if (known.length === 0) return '';
  let text = `OS ${known[0]}`;
  for (let i = 1; i < known.length; i++) {
    const next = `${text}, ${known[i]}`;
    if (next.length > MAX_OBSERVATIONS - 20) return `${text} e mais ${known.length - i}`;
    text = next;
  }
  return text;
}

/** The service name as Asaas accepts it (cut with "…" past 250 characters). */
export function municipalServiceNameForAsaas(name: string): string {
  const trimmed = (name || '').trim();
  if (trimmed.length <= MAX_MUNICIPAL_SERVICE_NAME) return trimmed;
  return `${trimmed.slice(0, MAX_MUNICIPAL_SERVICE_NAME - 1).trimEnd()}…`;
}

export function applyDescriptionTemplate(template: string | undefined, services: string, orderNumbers: string): string {
  const base = (template || DEFAULT_DESCRIPTION_TEMPLATE).trim() || DEFAULT_DESCRIPTION_TEMPLATE;
  return base.replace(/\{servicos\}/g, services).replace(/\{os\}/g, orderNumbers).trim().slice(0, MAX_DESCRIPTION);
}

// ----------------------------------------------------------------------------
// Status rules
// ----------------------------------------------------------------------------

const ASAAS_STATUS: Record<string, InvoiceStatus> = {
  SCHEDULED: 'scheduled',
  SYNCHRONIZED: 'synchronized',
  AUTHORIZED: 'authorized',
  PROCESSING_CANCELLATION: 'processingCancellation',
  CANCELED: 'canceled',
  CANCELLATION_DENIED: 'cancellationDenied',
  ERROR: 'error',
};

const EVENT_STATUS: Record<string, InvoiceStatus> = {
  INVOICE_CREATED: 'scheduled',
  INVOICE_SYNCHRONIZED: 'synchronized',
  INVOICE_AUTHORIZED: 'authorized',
  INVOICE_PROCESSING_CANCELLATION: 'processingCancellation',
  INVOICE_CANCELED: 'canceled',
  INVOICE_CANCELLATION_DENIED: 'cancellationDenied',
  INVOICE_ERROR: 'error',
};

/** Our status for an Asaas invoice (its `status`, else the event name). */
export function mapInvoiceStatus(asaasStatus?: string | null, eventName?: string): InvoiceStatus | null {
  if (asaasStatus && ASAAS_STATUS[asaasStatus]) return ASAAS_STATUS[asaasStatus];
  if (eventName && EVENT_STATUS[eventName]) return EVENT_STATUS[eventName];
  return null;
}

const RANK: Record<InvoiceStatus, number> = {
  creating: 0,
  scheduled: 1,
  synchronized: 2,
  error: 2,
  authorized: 3,
  processingCancellation: 4,
  cancellationDenied: 4,
  canceled: 5,
};

/**
 * Whether `to` may replace `from`. Status only moves forward (late or
 * repeated events never undo an issued or canceled nota); 'canceled' is
 * final; 'error' may move anywhere (the nota was fixed and rescheduled on Asaas).
 */
export function canMoveInvoiceStatus(from: InvoiceStatus, to: InvoiceStatus): boolean {
  if (from === to) return true;
  if (from === 'canceled') return false;
  if (from === 'error') return true;
  return RANK[to] >= RANK[from];
}

/**
 * Counts as "the order has a nota". A 'creating' one stays active however old
 * (it may exist on Asaas): only `reconcileInvoice` frees it. A `conflict` nota
 * never holds the orders' locks.
 */
export function isActiveInvoice(invoice: Pick<NfseInvoice, 'status' | 'createdAt' | 'conflict'>): boolean {
  if (INACTIVE_STATUSES.includes(invoice.status)) return false;
  return invoice.conflict !== true;
}

// ----------------------------------------------------------------------------
// Preconditions and order loading
// ----------------------------------------------------------------------------

export interface NfseContext {
  settings: PaymentSettingsDoc;
  connection: AsaasConnectionDoc;
}

/**
 * NFS-e is available: server flag on, Asaas connected, and the connection's
 * webhook receives the INVOICE_* events (connections made before NFS-e must
 * reconnect, or a city rejection would never arrive and the order stay locked).
 */
export async function assertNfseEnabled(companyId: string): Promise<NfseContext> {
  const settings = await getPaymentSettings(companyId);
  if (!settings.nfseEnabled) {
    throw new AsaasServiceError('NFSE_NOT_ENABLED', 'NFS-e is not enabled for this company');
  }
  const snap = settings.asaasConnected ? await asaasConnectionRef(companyId).get() : null;
  const connection = snap?.exists ? (snap.data() as AsaasConnectionDoc) : undefined;
  if (!connection) {
    throw new AsaasServiceError('ASAAS_NOT_CONNECTED', 'Asaas account is not connected');
  }
  if (!hasNfseWebhookEvents(connection.webhookEvents)) {
    throw new AsaasServiceError('NFSE_RECONNECT_NEEDED', 'Reconnect the Asaas account to receive the nota events');
  }
  return { settings, connection };
}

export interface AsaasAccountStamp {
  asaasEnvironment: AsaasEnvironment;
  asaasWalletId: string | null;
}

/** Identity of the connected Asaas account, stored on settings/nfse and on each invoice. */
export function accountStampOf(connection: Pick<AsaasConnectionDoc, 'environment' | 'walletId'>): AsaasAccountStamp {
  return { asaasEnvironment: connection.environment, asaasWalletId: connection.walletId ?? null };
}

/** Whether a stamped doc belongs to the connected account (unstamped: no). */
export function isSameAccount(
  stamped: { asaasEnvironment?: AsaasEnvironment; asaasWalletId?: string | null },
  connection: Pick<AsaasConnectionDoc, 'environment' | 'walletId'>,
): boolean {
  const current = accountStampOf(connection);
  return stamped.asaasEnvironment === current.asaasEnvironment && (stamped.asaasWalletId ?? null) === current.asaasWalletId;
}

export async function getNfseServiceSettings(companyId: string): Promise<NfseServiceSettings | null> {
  const snap = await nfseSettingsRef(companyId).get();
  return snap.exists ? (snap.data() as NfseServiceSettings) : null;
}

/**
 * The default service, ready for notas: setup checked (`nfseReady`) and saved
 * on the connected Asaas account (settings/nfse survives an account change).
 */
async function requireReadyService(companyId: string, ctx: NfseContext): Promise<NfseServiceSettings> {
  const service = await getNfseServiceSettings(companyId);
  if (!service || !ctx.settings.nfseReady) {
    throw new AsaasServiceError('NFSE_NOT_READY', 'Set up the nota service first');
  }
  if (!isSameAccount(service, ctx.connection)) {
    throw new AsaasServiceError('NFSE_SETUP_NEEDED', 'The nota service was set up on another Asaas account');
  }
  return service;
}

interface LoadedOrders {
  orders: Order[];
  parts: Array<InvoiceOrderPart & OrderInvoiceValue>;
  customerId: string;
  customerName: string | null;
  value: number;
}

function uniqueIds(ids: string[]): string[] {
  return [...new Set(ids)];
}

/** Loads the orders, checks they can go into one nota and computes the value. */
export async function loadInvoiceOrders(
  companyId: string,
  orderIds: string[],
  expectedCustomerId?: string,
): Promise<LoadedOrders> {
  const ids = uniqueIds(orderIds);
  if (ids.length === 0 || ids.length > MAX_INVOICE_ORDERS) {
    throw new AsaasServiceError('ORDER_NOT_FOUND', 'Pick between 1 and 50 orders');
  }
  const snaps = await Promise.all(ids.map((id) => companyRef(companyId).collection('orders').doc(id).get()));
  const orders = snaps.map((snap) => {
    if (!snap.exists) throw new AsaasServiceError('ORDER_NOT_FOUND', 'Order not found');
    return { ...(snap.data() as Order), id: snap.id };
  });

  const customerId = expectedCustomerId ?? orders[0].customer?.id;
  if (!customerId) throw new AsaasServiceError('CUSTOMER_REQUIRED', 'Order has no customer');
  for (const order of orders) {
    if (order.customer?.id !== customerId) {
      throw new AsaasServiceError('ORDER_NOT_OF_CUSTOMER', 'All orders must belong to the same customer');
    }
    if (order.status === 'quote' || order.status === 'canceled') {
      throw new AsaasServiceError('NFSE_ORDER_NOT_ALLOWED', 'Quotes and canceled orders cannot have a nota');
    }
  }

  // Oldest first, so the description reads in order.
  orders.sort((a, b) => (Number(a.number) || 0) - (Number(b.number) || 0));
  const parts = orders.map((order) => {
    const computed = invoiceValueOfOrder(order);
    if (computed.value <= 0) {
      throw new AsaasServiceError('NO_SERVICES', 'The order has no service value for a nota');
    }
    return { orderId: order.id, orderNumber: order.number ?? null, ...computed };
  });
  const value = roundMoney(parts.reduce((sum, p) => sum + p.value, 0));
  return { orders, parts, customerId, customerName: orders[0].customer?.name ?? null, value };
}

/**
 * Active invoice ids covering each order (via the lock docs), after checking
 * stale non-final ones against Asaas.
 */
async function activeInvoicesOf(
  companyId: string,
  orderIds: string[],
  client: AsaasClient,
): Promise<Record<string, string>> {
  const result: Record<string, string> = {};
  const checked = new Map<string, NfseInvoice | null>();
  for (const orderId of orderIds) {
    const lock = await orderLockRef(companyId, orderId).get();
    const invoiceId = lock.data()?.invoiceId as string | undefined;
    if (!invoiceId) continue;
    if (!checked.has(invoiceId)) {
      const snap = await invoicesRef(companyId).doc(invoiceId).get();
      const invoice = snap.exists ? { ...(snap.data() as NfseInvoice), id: snap.id } : null;
      checked.set(invoiceId, invoice ? await reconcileInvoice(companyId, invoice, client) : null);
    }
    const invoice = checked.get(invoiceId);
    if (invoice && isActiveInvoice(invoice)) result[orderId] = invoiceId;
  }
  return result;
}

function validEffectiveDate(input: string | undefined): string {
  const today = todayInSaoPaulo();
  const date = input ?? today;
  const isCalendar = /^\d{4}-\d{2}-\d{2}$/.test(date) && addDays(date, 0) === date;
  if (!isCalendar || date < today || date > addDays(today, MAX_FUTURE_DAYS)) {
    throw new AsaasServiceError('INVALID_EFFECTIVE_DATE', 'effectiveDate must be between today and 60 days ahead');
  }
  return date;
}

// ----------------------------------------------------------------------------
// Preview
// ----------------------------------------------------------------------------

export interface InvoicePreview {
  value: number;
  orders: Array<InvoiceOrderPart & OrderInvoiceValue>;
  hasProducts: boolean;
  serviceDescription: string;
  observations: string;
  effectiveDate: string;
  customer: {
    id: string;
    name: string | null;
    hasTaxId: boolean;
    /** E-mail and address the nota needs, as known (to fill the sheet). */
    contact: AsaasCustomerContact;
    /** What the sheet must ask before the nota can go. */
    missingData: InvoiceCustomerField[];
  };
  /** Orders that already have an active nota (orderId → invoiceId). */
  invoicedOrders: Record<string, string>;
  municipalServiceName: string;
}

export async function previewInvoice(
  companyId: string,
  orderIds: string[],
  expectedCustomerId?: string,
): Promise<InvoicePreview> {
  const ctx = await assertNfseEnabled(companyId);
  const service = await requireReadyService(companyId, ctx);

  const loaded = await loadInvoiceOrders(companyId, orderIds, expectedCustomerId);
  const client = await getAsaasCredentialProvider().getClient(companyId);
  const customerSnap = await companyRef(companyId).collection('customers').doc(loaded.customerId).get();
  const customer = customerSnap.data() as Customer | undefined;
  const numbers = describeOrderNumbers(loaded.orders.map((o) => o.number));
  const contactData = await invoiceCustomerData(client, companyId, loaded.customerId, customer);
  return {
    value: loaded.value,
    orders: loaded.parts,
    hasProducts: loaded.parts.some((p) => p.productsTotal > 0),
    serviceDescription: applyDescriptionTemplate(service.descriptionTemplate, describeServices(loaded.orders), numbers),
    observations: numbers,
    effectiveDate: todayInSaoPaulo(),
    customer: {
      id: loaded.customerId,
      name: customer?.name ?? loaded.customerName,
      hasTaxId: !!customer?.taxId,
      contact: contactData.contact,
      missingData: contactData.missing,
    },
    invoicedOrders: await activeInvoicesOf(companyId, loaded.orders.map((o) => o.id), client),
    municipalServiceName: service.municipalServiceName,
  };
}

// ----------------------------------------------------------------------------
// Create
// ----------------------------------------------------------------------------

/** Applies the Asaas invoice fields to our doc, respecting the status rules. */
export function invoiceUpdateFrom(
  current: NfseInvoice,
  asaas: AsaasInvoice,
  eventName?: string,
): Partial<NfseInvoice> | null {
  const status = mapInvoiceStatus(asaas.status, eventName) ?? current.status;
  if (!canMoveInvoiceStatus(current.status, status)) return null;
  // A nota PraticOS gave up on (issue refused, canceled on Asaas) keeps its
  // reason: the late events of that Asaas nota do not bring it back.
  if (current.status === 'error' && current.errorCode) return null;
  const now = new Date().toISOString();
  const update: Partial<NfseInvoice> = { status, updatedAt: now };
  if (asaas.id && !current.asaasInvoiceId) update.asaasInvoiceId = asaas.id;
  if (asaas.pdfUrl) update.pdfUrl = asaas.pdfUrl;
  if (asaas.xmlUrl) update.xmlUrl = asaas.xmlUrl;
  if (asaas.number) update.number = asaas.number;
  if (asaas.validationCode) update.validationCode = asaas.validationCode;
  if (status === 'error' || status === 'cancellationDenied') {
    update.statusDescription = asaas.statusDescription ?? null;
  } else if (status !== current.status) {
    // Same status: a reason PraticOS recorded (refused issue) stays.
    update.statusDescription = null;
    if (current.errorCode) update.errorCode = null;
  }
  if (status === 'authorized' && !current.authorizedAt) update.authorizedAt = now;
  if (status === 'canceled' && !current.canceledAt) update.canceledAt = now;
  return update;
}

/**
 * Writes the Asaas state to the invoice doc in a transaction (never moves the
 * status back). A nota leaving 'error' for a live status while one of its
 * orders already has another nota (the lock points elsewhere) is recorded
 * but marked `conflict`: it does not take the orders back.
 */
export async function syncInvoice(
  companyId: string,
  invoiceId: string,
  asaas: AsaasInvoice,
  eventName?: string,
): Promise<{ before: NfseInvoice; after: NfseInvoice } | null> {
  const ref = invoicesRef(companyId).doc(invoiceId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const before = { ...(snap.data() as NfseInvoice), id: snap.id };
    if (before.asaasInvoiceId && asaas.id && before.asaasInvoiceId !== asaas.id) return null;
    const update = invoiceUpdateFrom(before, asaas, eventName);
    if (!update) return { before, after: before };
    const revived = before.status === 'error' && !INACTIVE_STATUSES.includes(update.status as InvoiceStatus);
    if (revived && !before.conflict) {
      const locks = await Promise.all(before.orderIds.map((id) => tx.get(orderLockRef(companyId, id))));
      const taken = locks.filter((lock) => lock.data()?.invoiceId !== invoiceId).map((lock) => lock.id);
      if (taken.length > 0) {
        update.conflict = true;
        console.error('[NFS-e] ALERT nota with error came back while its orders have another nota', {
          companyId, invoiceId, status: update.status, orders: taken,
        });
      }
    }
    tx.update(ref, update as Record<string, unknown>);
    return { before, after: { ...before, ...update } as NfseInvoice };
  });
}

/**
 * Checks a non-final invoice untouched for RECONCILE_AFTER_MS against Asaas:
 * by its Asaas id, or by the externalReference when the create answer was
 * lost. A 'creating' one Asaas does not know never got there and is removed
 * (orders freed). Asaas unreachable: left as is (still locks). Returns the
 * current invoice, or null when it was removed.
 */
export async function reconcileInvoice(
  companyId: string,
  invoice: NfseInvoice,
  client: AsaasClient,
  now: number = Date.now(),
): Promise<NfseInvoice | null> {
  if (!RECONCILE_STATUSES.includes(invoice.status)) return invoice;
  const last = Date.parse(invoice.updatedAt || invoice.createdAt || '');
  if (Number.isFinite(last) && now - last < RECONCILE_AFTER_MS) return invoice;
  try {
    let asaas: AsaasInvoice | null;
    if (invoice.asaasInvoiceId) {
      asaas = await client.getInvoice(invoice.asaasInvoiceId);
    } else {
      const found = await client.listInvoicesByExternalReference(invoiceExternalReference(companyId, invoice.id));
      if (found.length > 1) {
        console.error('[NFS-e] ALERT several Asaas notas for one PraticOS invoice', {
          companyId, invoiceId: invoice.id, asaasIds: found.map((f) => f.id),
        });
      }
      asaas = found[0] ?? null;
    }
    if (!asaas) {
      if (invoice.status !== 'creating') return invoice;
      await releaseInvoice(companyId, invoice.id, invoice.orderIds);
      console.warn(`[NFS-e] Invoice ${invoice.id} of company ${companyId} never reached Asaas; orders freed`);
      return null;
    }
    const result = await syncInvoice(companyId, invoice.id, asaas);
    return result ? { ...result.after, id: invoice.id } : invoice;
  } catch (error) {
    const status = error instanceof AsaasApiError ? error.status : 'unknown';
    console.warn(`[NFS-e] Could not reconcile invoice ${invoice.id} of company ${companyId} (status ${status})`);
    return invoice;
  }
}

/** Removes an invoice that never reached Asaas and frees its orders. */
async function releaseInvoice(companyId: string, invoiceId: string, orderIds: string[]): Promise<void> {
  await db.runTransaction(async (tx) => {
    const locks = await Promise.all(orderIds.map((id) => tx.get(orderLockRef(companyId, id))));
    locks.forEach((lock, i) => {
      if (lock.data()?.invoiceId === invoiceId) tx.delete(orderLockRef(companyId, orderIds[i]));
    });
    tx.delete(invoicesRef(companyId).doc(invoiceId));
  });
}

export async function createInvoice(
  companyId: string,
  input: CreateInvoiceInput,
  user: UserAggr,
  expectedCustomerId?: string,
  options: { auto?: boolean } = {},
): Promise<NfseInvoice> {
  const ctx = await assertNfseEnabled(companyId);
  const service = await requireReadyService(companyId, ctx);

  const effectiveDate = validEffectiveDate(input.effectiveDate);
  const loaded = await loadInvoiceOrders(companyId, input.orderIds, expectedCustomerId);
  const orderIds = loaded.orders.map((o) => o.id);

  const customerSnap = await companyRef(companyId).collection('customers').doc(loaded.customerId).get();
  if (!customerSnap.exists) throw new AsaasServiceError('CUSTOMER_REQUIRED', 'Order customer not found');
  const customer = { ...(customerSnap.data() as Customer), id: customerSnap.id };
  if (!customer.name) customer.name = loaded.customerName || '';
  const taxId = await resolveTaxId(companyId, customer, input.customerTaxId);

  const client = await getAsaasCredentialProvider().getClient(companyId);
  // Stale notas of these orders are checked with Asaas first (lost create
  // answer, missed city rejection), so the reservation below sees the truth.
  const invoiced = await activeInvoicesOf(companyId, orderIds, client);
  if (Object.keys(invoiced).length > 0) {
    throw new AsaasServiceError('ORDER_HAS_INVOICE', 'An order already has an active nota');
  }
  const typedContact = cleanCustomerContact(input.customerData);
  const asaasCustomerId = await findOrCreateAsaasCustomer(client, companyId, customer, taxId, typedContact);
  // The city refuses a nota without the customer's e-mail and address with CEP.
  await ensureInvoiceCustomer(client, asaasCustomerId, customer, typedContact);
  await saveContactOnCustomer(companyId, customer, typedContact);

  const numbers = describeOrderNumbers(loaded.orders.map((o) => o.number));
  const serviceDescription =
    (input.serviceDescription || '').trim().slice(0, MAX_DESCRIPTION) ||
    applyDescriptionTemplate(service.descriptionTemplate, describeServices(loaded.orders), numbers);

  // 1. Reserve the orders: one active nota per order.
  const invoiceRef = invoicesRef(companyId).doc();
  const now = new Date().toISOString();
  const invoice: NfseInvoice = {
    id: invoiceRef.id,
    status: 'creating',
    customer: { id: customer.id, name: customer.name || null },
    orderIds,
    orders: loaded.parts.map((p) => ({ orderId: p.orderId, orderNumber: p.orderNumber, value: p.value })),
    value: loaded.value,
    serviceDescription,
    observations: numbers,
    effectiveDate,
    municipalServiceName: service.municipalServiceName,
    createdBy: { id: user.id, name: user.name },
    createdAt: now,
    ...(options.auto ? { auto: true } : {}),
    ...accountStampOf(ctx.connection),
  };
  await db.runTransaction(async (tx) => {
    const locks = await Promise.all(orderIds.map((id) => tx.get(orderLockRef(companyId, id))));
    const lockedIds = locks.map((lock) => lock.data()?.invoiceId as string | undefined);
    const existing = await Promise.all(
      lockedIds.map((id) => (id ? tx.get(invoicesRef(companyId).doc(id)) : Promise.resolve(null))),
    );
    for (const snap of existing) {
      if (snap?.exists && isActiveInvoice(snap.data() as NfseInvoice)) {
        throw new AsaasServiceError('ORDER_HAS_INVOICE', 'An order already has an active nota');
      }
    }
    tx.set(invoiceRef, invoice as unknown as Record<string, unknown>);
    for (const id of orderIds) tx.set(orderLockRef(companyId, id), { invoiceId: invoiceRef.id, updatedAt: now });
  });

  // 2. Schedule it on Asaas (avulsa: tied to the customer, not to a payment).
  const payload: AsaasCreateInvoiceInput = {
    customer: asaasCustomerId,
    serviceDescription,
    observations: numbers,
    externalReference: invoiceExternalReference(companyId, invoiceRef.id),
    value: loaded.value,
    deductions: 0,
    effectiveDate,
    municipalServiceName: municipalServiceNameForAsaas(service.municipalServiceName),
    taxes: service.taxes,
  };
  // Asaas: send the id OR the code, never both.
  if (service.municipalServiceId) payload.municipalServiceId = service.municipalServiceId;
  else payload.municipalServiceCode = service.municipalServiceCode ?? null;

  let created: AsaasInvoice;
  try {
    created = await client.createInvoice(payload);
  } catch (error) {
    if (error instanceof AsaasApiError && DEFINITIVE_REJECTIONS.includes(error.status)) {
      // Asaas refused it: nothing was created, the orders are free again.
      console.warn(`[NFS-e] create of invoice ${invoiceRef.id} of company ${companyId} refused (${asaasErrorLog(error)})`);
      await releaseInvoice(companyId, invoiceRef.id, orderIds).catch(() => {
        console.error(`[NFS-e] Could not release invoice ${invoiceRef.id} of company ${companyId}`);
      });
      throw refusalError(error);
    } else {
      // No clear answer (timeout, 408, 5xx, network): Asaas may have created
      // it. Kept 'creating' and locked; reconcileInvoice or the webhook finds out.
      const status = error instanceof AsaasApiError ? error.status : 'no answer';
      console.warn(`[NFS-e] create of invoice ${invoiceRef.id} of company ${companyId} unknown (${status}); kept locked`);
    }
    throw error;
  }

  // Asaas id first, before anything else can fail: the nota exists there.
  invoice.asaasInvoiceId = created.id;
  let result: NfseInvoice = invoice;
  try {
    await invoiceRef.update({ asaasInvoiceId: created.id, updatedAt: new Date().toISOString() });
    result = (await syncInvoice(companyId, invoiceRef.id, created))?.after ?? invoice;
  } catch (error) {
    console.error(`[NFS-e] ALERT invoice ${invoiceRef.id} of company ${companyId} created on Asaas (${created.id}) but not saved`, error);
    return { ...invoice, id: invoiceRef.id };
  }

  // 3. Issue now when the date is today (otherwise Asaas issues it on the date).
  if (effectiveDate === todayInSaoPaulo() && created.status === 'SCHEDULED') {
    try {
      const authorized = await client.authorizeInvoice(created.id);
      result = (await syncInvoice(companyId, invoiceRef.id, authorized))?.after ?? result;
    } catch (error) {
      if (error instanceof AsaasApiError && DEFINITIVE_REJECTIONS.includes(error.status)) {
        await giveUpRefusedInvoice(companyId, invoiceRef.id, created.id, error, client);
        throw refusalError(error);
      }
      // No clear answer: the nota stays scheduled (Asaas issues it on the date).
      const status = error instanceof AsaasApiError ? error.status : 'unknown';
      console.warn(`[NFS-e] authorize of invoice ${invoiceRef.id} failed (status ${status}); left scheduled`);
    }
  }

  console.log(`[NFS-e] Invoice ${invoiceRef.id} created for ${orderIds.length} order(s) of company ${companyId}`);
  return { ...result, id: invoiceRef.id };
}

type RefusalCode = 'CUSTOMER_DATA_REQUIRED' | 'NFSE_SETUP_REJECTED' | 'ASAAS_REJECTED';

/** Asaas texts about the nota setup (service, taxes, fiscal data of the company). */
const SETUP_REFUSAL = /servi[cç]o|al[ií]quota|\biss\b|inscri[cç][aã]o municipal|cnae|regime|tribut|(informa[cç][oõ]es|dados) fisca/i;

/**
 * What a refusal is about, from Asaas's texts: the customer data (the sheet
 * asks for it), the nota setup (the app opens the setup), else unknown (the
 * app shows Asaas's text).
 */
export function refusalCode(error: AsaasApiError): RefusalCode {
  const texts = error.errors.map((e) => e.description ?? '');
  if (texts.some((t) => /cliente/i.test(t))) return 'CUSTOMER_DATA_REQUIRED';
  if (texts.some((t) => SETUP_REFUSAL.test(t))) return 'NFSE_SETUP_REJECTED';
  return 'ASAAS_REJECTED';
}

/** What the app gets for a refusal: our code with Asaas's text in `detail`, or the Asaas error. */
function refusalError(error: AsaasApiError): Error {
  const code = refusalCode(error);
  if (code === 'ASAAS_REJECTED') return error;
  const detail = asaasErrorDescription(error);
  return new AsaasServiceError(code, detail ?? 'Asaas refused the nota', detail);
}

/**
 * Asaas refused to issue a nota it had just scheduled (customer data, fiscal
 * data). A scheduled nota never reached the city, so it is canceled on Asaas
 * and recorded as 'error' with the reason: the orders are free and the user
 * fixes the data and issues again. If the cancel fails the nota stays
 * scheduled (and locked) with the reason; the user cancels it on its screen.
 */
async function giveUpRefusedInvoice(
  companyId: string,
  invoiceId: string,
  asaasInvoiceId: string,
  error: AsaasApiError,
  client: AsaasClient,
): Promise<void> {
  const update: Partial<NfseInvoice> = {
    errorCode: refusalCode(error),
    statusDescription: asaasErrorDescription(error),
    updatedAt: new Date().toISOString(),
  };
  try {
    await client.cancelInvoice(asaasInvoiceId);
    update.status = 'error';
  } catch (cancelError) {
    const status = cancelError instanceof AsaasApiError ? cancelError.status : 'unknown';
    console.error(`[NFS-e] ALERT invoice ${invoiceId} of company ${companyId} refused and not canceled (status ${status}); left scheduled`);
  }
  await invoicesRef(companyId).doc(invoiceId).update(update as Record<string, unknown>);
  console.warn(`[NFS-e] Invoice ${invoiceId} of company ${companyId} refused by Asaas (${update.errorCode}, ${asaasErrorLog(error)})`);
}

// ----------------------------------------------------------------------------
// Automatic issue (settings/nfse.autoIssue)
// ----------------------------------------------------------------------------

/** Author of the notas the server issues by itself. */
export const AUTO_ISSUE_USER: UserAggr = { id: 'system', name: 'PraticOS' };

/** Failures that are not the order's problem: nothing to record on the order. */
const AUTO_ISSUE_SILENT = ['NFSE_NOT_ENABLED', 'ASAAS_NOT_CONNECTED', 'ORDER_HAS_INVOICE', 'NFSE_ORDER_NOT_ALLOWED', 'ORDER_NOT_FOUND'];

/** Doc id of the error record of an automatic nota that failed (one per order). */
export function autoIssueErrorId(orderId: string): string {
  return `auto-${orderId}`;
}

/**
 * Issues the nota of one order without anyone asking, when the company chose
 * that moment (`autoIssue` 'paid' or 'completed'). Runs from the order trigger.
 *
 * - Only once per order: an order that ever had a nota (any status, including
 *   canceled or a failed automatic one) is left to the user.
 * - A failure the user can fix (no CPF, no e-mail/address, no services,
 *   city/Asaas rejection) is
 *   recorded as an invoice with status 'error' and `errorCode`, so the order
 *   shows "Nota fiscal · Erro" and the user can issue it by hand.
 * - No answer from Asaas: createInvoice keeps it 'creating' (reconciled later).
 */
export async function autoIssueInvoice(companyId: string, orderId: string, moment: Exclude<NfseAutoIssue, 'manual'>): Promise<void> {
  const settings = await getPaymentSettings(companyId);
  if (!settings.nfseEnabled || !settings.nfseReady || !settings.asaasConnected) return;
  const service = await getNfseServiceSettings(companyId);
  if ((service?.autoIssue ?? 'manual') !== moment) return;

  const previous = await invoicesRef(companyId).where('orderIds', 'array-contains', orderId).limit(1).get();
  if (!previous.empty) return;

  try {
    await createInvoice(companyId, { orderIds: [orderId] }, AUTO_ISSUE_USER, undefined, { auto: true });
    console.log(`[NFS-e] Automatic nota (${moment}) of order ${orderId} of company ${companyId}`);
  } catch (error) {
    let errorCode: string;
    let statusDescription: string | null = null;
    if (error instanceof AsaasServiceError) {
      if (AUTO_ISSUE_SILENT.includes(error.code)) return;
      errorCode = error.code;
      statusDescription = error.detail ?? null;
    } else if (error instanceof AsaasApiError && DEFINITIVE_REJECTIONS.includes(error.status)) {
      errorCode = 'ASAAS_REJECTED';
      statusDescription = asaasErrorDescription(error);
    } else {
      throw error;
    }
    console.warn(`[NFS-e] Automatic nota of order ${orderId} of company ${companyId} not issued (${errorCode})`);
    // Refused after it was created: createInvoice already left the nota with its reason.
    const recorded = await invoicesRef(companyId).where('orderIds', 'array-contains', orderId).limit(1).get();
    if (!recorded.empty) return;
    await recordAutoIssueError(companyId, orderId, errorCode, statusDescription, service?.municipalServiceName ?? '');
  }
}

async function recordAutoIssueError(
  companyId: string,
  orderId: string,
  errorCode: string,
  statusDescription: string | null,
  municipalServiceName: string,
): Promise<void> {
  const snap = await companyRef(companyId).collection('orders').doc(orderId).get();
  const order = snap.data() as Order | undefined;
  const value = order ? invoiceValueOfOrder(order).value : 0;
  const now = new Date().toISOString();
  const record: NfseInvoice = {
    id: autoIssueErrorId(orderId),
    status: 'error',
    customer: { id: order?.customer?.id ?? '', name: order?.customer?.name ?? null },
    orderIds: [orderId],
    orders: [{ orderId, orderNumber: order?.number ?? null, value }],
    value,
    serviceDescription: '',
    observations: '',
    effectiveDate: todayInSaoPaulo(),
    municipalServiceName,
    statusDescription,
    errorCode,
    auto: true,
    createdBy: AUTO_ISSUE_USER,
    createdAt: now,
    updatedAt: now,
  };
  // Fixed id: a second trigger for the same order does not write it twice.
  const ref = invoicesRef(companyId).doc(record.id);
  await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return;
    tx.set(ref, record as unknown as Record<string, unknown>);
  });
}

// ----------------------------------------------------------------------------
// Cancel
// ----------------------------------------------------------------------------

export async function cancelInvoice(
  companyId: string,
  invoiceId: string,
  onlyOnAsaas = false,
): Promise<NfseInvoice> {
  const { connection } = await assertNfseEnabled(companyId);
  const snap = await invoicesRef(companyId).doc(invoiceId).get();
  if (!snap.exists) throw new AsaasServiceError('INVOICE_NOT_FOUND', 'Invoice not found');
  const stored = { ...(snap.data() as NfseInvoice), id: snap.id };
  // Notas from before the account stamp have none and stay cancelable.
  if (stored.asaasEnvironment && !isSameAccount(stored, connection)) {
    throw new AsaasServiceError('INVOICE_OTHER_ACCOUNT', 'The nota was issued on another Asaas account');
  }

  const client = await getAsaasCredentialProvider().getClient(companyId);
  const invoice = await reconcileInvoice(companyId, stored, client);
  if (!invoice || !CANCELABLE_STATUSES.includes(invoice.status) || !invoice.asaasInvoiceId) {
    throw new AsaasServiceError('INVOICE_NOT_CANCELABLE', 'This nota cannot be canceled now');
  }

  // An issued nota is canceled at the city; some cities do not allow it through the API.
  if (invoice.status !== 'scheduled' && !onlyOnAsaas) {
    const options = await client.getMunicipalOptions().catch(() => null);
    if (options && options.supportsCancellation === false) {
      throw new AsaasServiceError('CANCEL_NOT_SUPPORTED', 'The city does not cancel notas through the integration');
    }
  }

  const canceled = await client.cancelInvoice(invoice.asaasInvoiceId, onlyOnAsaas);
  const result = await syncInvoice(companyId, invoiceId, canceled);
  return { ...(result?.after ?? invoice), id: invoiceId };
}

/** Webhook entry: INVOICE_* event for this company. Acknowledged when unknown. */
export async function applyInvoiceEvent(companyId: string, eventName: string, asaas: AsaasInvoice): Promise<void> {
  let invoiceId: string | null = null;
  const parsed = parseInvoiceReference(asaas.externalReference);
  if (parsed) {
    if (parsed.companyId !== companyId) {
      console.warn('[AsaasWebhook] invoice reference belongs to another company', { companyId, event: eventName });
      return;
    }
    invoiceId = parsed.invoiceId;
  } else if (asaas.id) {
    const found = await invoicesRef(companyId).where('asaasInvoiceId', '==', asaas.id).limit(1).get();
    invoiceId = found.docs[0]?.id ?? null;
  }
  if (!invoiceId) {
    // Nota issued outside PraticOS (Asaas panel, payment-linked): not ours.
    console.log('[AsaasWebhook] invoice not from PraticOS, acknowledged', { companyId, event: eventName });
    return;
  }

  const result = await syncInvoice(companyId, invoiceId, asaas, eventName);
  if (!result) {
    // Our reference (or our Asaas id) but no matching doc: a nota exists on
    // Asaas that PraticOS lost track of. Acknowledged, but loudly.
    console.error('[AsaasWebhook] ALERT PraticOS nota without its invoice doc (or another Asaas id)', {
      companyId, invoiceId, asaasInvoiceId: asaas.id, event: eventName,
    });
  }
}
